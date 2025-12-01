require('dotenv').config();
const express = require('express');
const { Client, LocalAuth } = require('whatsapp-web.js');
const qrcode = require('qrcode-terminal');

const app = express();
app.use(express.json());

// Initialize WhatsApp client with session persistence
const whatsappClient = new Client({
    authStrategy: new LocalAuth({
        dataPath: './whatsapp-session'
    }),
    puppeteer: {
        headless: true,
//        executablePath: "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe",
        args: [
            '--no-sandbox',
            '--disable-setuid-sandbox',
            '--disable-dev-shm-usage',
            '--disable-accelerated-2d-canvas',
            '--no-first-run',
            '--no-zygote',
            '--disable-gpu'
        ]
    },
    webVersionCache: {
        type: 'remote',
        remotePath: 'https://raw.githubusercontent.com/wppconnect-team/wa-version/main/html/2.2412.54.html',
    }
});

let isWhatsAppReady = false;

// WhatsApp client events
whatsappClient.on('qr', (qr) => {
    console.log('QR Code received. Scan with WhatsApp:');
    qrcode.generate(qr, { small: true });
});

whatsappClient.on('ready', () => {
    console.log('WhatsApp client is ready!');
    isWhatsAppReady = true;
});

whatsappClient.on('authenticated', () => {
    console.log('WhatsApp authenticated successfully');
});

whatsappClient.on('auth_failure', () => {
    console.error('WhatsApp authentication failed');
});

whatsappClient.on('disconnected', (reason) => {
    console.log('WhatsApp client disconnected:', reason);
    isWhatsAppReady = false;
});

// Initialize WhatsApp
whatsappClient.initialize();

// Parse recipients from environment variable
function getRecipients() {
    const targetsString = process.env.WHATSAPP_TARGETS;
    
    if (!targetsString) {
        throw new Error('WHATSAPP_TARGETS not configured in .env');
    }
    
    // Split by comma and clean up whitespace
    const targets = targetsString.split(',').map(t => t.trim()).filter(t => t.length > 0);
    
    if (targets.length === 0) {
        throw new Error('No valid targets found in WHATSAPP_TARGETS');
    }
    
    return targets;
}

// Helper function to format recipient
function formatRecipient(target) {
    // If it already contains @, assume it's properly formatted
    if (target.includes('@')) {
        return target;
    }
    
    // Otherwise, assume it's a phone number and add @c.us
    return `${target}@c.us`;
}

// Send message to all configured recipients
async function sendToAllRecipients(message) {
    const recipients = getRecipients();
    const results = [];
    
    for (const target of recipients) {
        try {
            const recipient = formatRecipient(target);
            
            console.log(`Attempting to send to: ${recipient}`);
            
            // Try to get the chat first to verify it exists
            const chat = await whatsappClient.getChatById(recipient);
            console.log(`Chat found:`, {
                name: chat.name,
                id: chat.id._serialized,
                isGroup: chat.isGroup,
                isBroadcast: chat.isBroadcast,
                canSend: chat.canSend !== false
            });
            
            // Send the message
            const sentMessage = await whatsappClient.sendMessage(recipient, message);
            
            console.log(`✓ Message sent successfully to: ${recipient}`);
            console.log(`Message ID: ${sentMessage.id._serialized}`);
            
            results.push({
                recipient: recipient,
                chatName: chat.name,
                isBroadcast: chat.isBroadcast,
                success: true,
                messageId: sentMessage.id._serialized
            });
            
            // Small delay between messages to avoid rate limiting
            await new Promise(resolve => setTimeout(resolve, 500));
            
        } catch (error) {
            console.error(`✗ Failed to send to ${target}:`, error.message);
            console.error('Full error:', error);
            results.push({
                recipient: target,
                success: false,
                error: error.message
            });
        }
    }
    
    return results;
}

// Webhook endpoint to receive Salto alarms
app.post('/webhook/alarm', async (req, res) => {
    console.log('Received alarm webhook:', req.body);

    if (!isWhatsAppReady) {
        console.error('WhatsApp client not ready');
        return res.status(503).json({ error: 'WhatsApp not connected' });
    }

    try {
        // Parse alarm data from Salto
        const alarmData = req.body;
        
        // Format message - adjust based on Salto's payload structure
        const message = formatAlarmMessage(alarmData);
        
        // Send to all recipients
        const results = await sendToAllRecipients(message);
        
        // Count successes and failures
        const successCount = results.filter(r => r.success).length;
        const failureCount = results.filter(r => !r.success).length;
        
        console.log(`Message delivery: ${successCount} succeeded, ${failureCount} failed`);
        
        res.json({ 
            success: failureCount === 0,
            message: 'Alarm notification sent',
            delivered: successCount,
            failed: failureCount,
            results: results
        });
        
    } catch (error) {
        console.error('Error sending WhatsApp messages:', error);
        res.status(500).json({ 
            error: 'Failed to send messages', 
            details: error.message 
        });
    }
});

// Health check endpoint
app.get('/health', (req, res) => {
    let recipientCount = 0;
    try {
        recipientCount = getRecipients().length;
    } catch (e) {
        // Ignore error, will show 0 recipients
    }
    
    res.json({ 
        status: 'running',
        whatsappReady: isWhatsAppReady,
        configuredRecipients: recipientCount
    });
});

// List all chats (groups, individuals, and broadcasts)
app.get('/list-chats', async (req, res) => {
    if (!isWhatsAppReady) {
        return res.status(503).json({ error: 'WhatsApp not connected' });
    }
    
    try {
        const chats = await whatsappClient.getChats();
        const groups = chats.filter(chat => chat.isGroup);
        const broadcasts = chats.filter(chat => chat.isBroadcast);
        const individuals = chats.filter(chat => !chat.isGroup && !chat.isBroadcast);
        
        res.json({
            broadcasts: broadcasts.map(b => ({ 
                name: b.name,
                id: b.id._serialized,
                recipients: b.participants ? b.participants.length : 0
            })),
            groups: groups.map(g => ({ 
                name: g.name, 
                id: g.id._serialized,
                participants: g.participants ? g.participants.length : 0
            })),
            individuals: individuals.slice(0, 20).map(i => ({ 
                name: i.name || 'Unknown', 
                id: i.id._serialized 
            }))
        });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// List all broadcast lists with detailed info
app.get('/list-broadcasts', async (req, res) => {
    if (!isWhatsAppReady) {
        return res.status(503).json({ error: 'WhatsApp not connected' });
    }
    
    try {
        const chats = await whatsappClient.getChats();
        
        // Log all chats to see what we have
        console.log('Total chats found:', chats.length);
        
        // Try multiple ways to identify broadcasts
        const broadcasts = [];
        const possibleBroadcasts = [];
        
        for (const chat of chats) {
            console.log('Chat:', {
                name: chat.name,
                id: chat.id._serialized,
                isGroup: chat.isGroup,
                isBroadcast: chat.isBroadcast,
                type: typeof chat.id.server
            });
            
            // Explicit broadcast flag
            if (chat.isBroadcast) {
                broadcasts.push(chat);
            }
            
            // Check if ID contains 'broadcast'
            if (chat.id._serialized.includes('@broadcast')) {
                possibleBroadcasts.push(chat);
            }
        }
        
        res.json({
            explicitBroadcasts: broadcasts.map(b => ({ 
                name: b.name,
                id: b.id._serialized,
                recipients: b.participants ? b.participants.length : 0
            })),
            idBasedBroadcasts: possibleBroadcasts.map(b => ({ 
                name: b.name,
                id: b.id._serialized,
                recipients: b.participants ? b.participants.length : 0
            })),
            totalChats: chats.length
        });
    } catch (error) {
        console.error('Error listing broadcasts:', error);
        res.status(500).json({ error: error.message });
    }
});

// Test endpoint to send a test message
app.post('/test-message', async (req, res) => {
    if (!isWhatsAppReady) {
        return res.status(503).json({ error: 'WhatsApp not connected' });
    }
    
    try {
        const testMessage = req.body.message || '🧪 Test message from Salto-WhatsApp Bridge';
        const results = await sendToAllRecipients(testMessage);
        
        const successCount = results.filter(r => r.success).length;
        const failureCount = results.filter(r => !r.success).length;
        
        res.json({
            success: failureCount === 0,
            delivered: successCount,
            failed: failureCount,
            results: results
        });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Format the alarm message
function formatAlarmMessage(alarmData) {
    // Customize this based on what Salto sends
    return `🚨 *Salto Alarm Triggered*
    
Time: ${new Date().toLocaleString()}
Type: ${alarmData.type || 'Unknown'}
Location: ${alarmData.location || 'Unknown'}
Details: ${alarmData.message || 'No details provided'}`;
}

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    console.log(`Salto-WhatsApp bridge running on port ${PORT}`);
    try {
        const recipients = getRecipients();
        console.log(`Configured for ${recipients.length} recipient(s)`);
    } catch (e) {
        console.warn('Warning: No recipients configured in .env');
    }
});
