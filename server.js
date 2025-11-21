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

// Helper function to format recipient based on target type
function formatRecipient(target, targetType) {
    if (targetType === 'group') {
        // Group IDs are already in the format: 123456789@g.us
        return target;
    } else {
        // Individual number: ensure it has @c.us suffix
        return target.includes('@') ? target : `${target}@c.us`;
    }
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
        
        // Get target from environment
        const target = process.env.WHATSAPP_TARGET;
        const targetType = process.env.WHATSAPP_TARGET_TYPE || 'individual';
        
        if (!target) {
            throw new Error('WHATSAPP_TARGET not configured');
        }
        
        const recipient = formatRecipient(target, targetType);
        
        await whatsappClient.sendMessage(recipient, message);
        
        console.log(`Message sent successfully to ${targetType}: ${recipient}`);
        res.json({ 
            success: true, 
            message: 'Alarm notification sent',
            targetType: targetType
        });
        
    } catch (error) {
        console.error('Error sending WhatsApp message:', error);
        res.status(500).json({ error: 'Failed to send message', details: error.message });
    }
});

// Health check endpoint
app.get('/health', (req, res) => {
    res.json({ 
        status: 'running',
        whatsappReady: isWhatsAppReady,
        targetType: process.env.WHATSAPP_TARGET_TYPE || 'individual'
    });
});

// List all chats (groups and individuals)
app.get('/list-chats', async (req, res) => {
    if (!isWhatsAppReady) {
        return res.status(503).json({ error: 'WhatsApp not connected' });
    }
    
    try {
        const chats = await whatsappClient.getChats();
        const groups = chats.filter(chat => chat.isGroup);
        const individuals = chats.filter(chat => !chat.isGroup);
        
        res.json({
            groups: groups.map(g => ({ 
                name: g.name, 
                id: g.id._serialized 
            })),
            individuals: individuals.slice(0, 10).map(i => ({ 
                name: i.name || 'Unknown', 
                id: i.id._serialized 
            }))
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
    console.log(`Target type: ${process.env.WHATSAPP_TARGET_TYPE || 'individual'}`);
});
