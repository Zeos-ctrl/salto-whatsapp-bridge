require('dotenv').config();
const express = require('express');
const { Client, LocalAuth } = require('whatsapp-web.js');
const qrcode = require('qrcode-terminal');
const fs = require('fs');
const path = require('path');

const app = express();
app.use(express.json());
// Serve static files - handle both development and production paths
const publicPath = require('path').join(__dirname, 'public');
app.use(express.static(publicPath));
console.log('Serving static files from:', publicPath);

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
let lastQRCode = null;

// WhatsApp client events
whatsappClient.on('qr', (qr) => {
    console.log('QR Code received');
    lastQRCode = qr;
    qrcode.generate(qr, { small: true });
});

whatsappClient.on('ready', () => {
    console.log('WhatsApp client is ready!');
    isWhatsAppReady = true;
    lastQRCode = null;
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

// Helper function to read targets from .env
function getTargets() {
    const targetsString = process.env.WHATSAPP_TARGETS || '';
    return targetsString.split(',')
        .map(t => t.trim())
        .filter(t => t.length > 0);
}

// Helper function to save targets to .env
function saveTargets(targets) {
    const envPath = path.join(__dirname, '..', '.env');
    
    console.log('Saving to .env at:', envPath);
    
    let envContent = '';
    
    // Read existing .env
    if (fs.existsSync(envPath)) {
        envContent = fs.readFileSync(envPath, 'utf8');
    }
    
    // Update or add WHATSAPP_TARGETS
    const targetLine = `WHATSAPP_TARGETS=${targets.join(',')}`;
    
    if (envContent.includes('WHATSAPP_TARGETS=')) {
        // Replace existing line
        envContent = envContent.replace(/WHATSAPP_TARGETS=.*/g, targetLine);
    } else {
        // Add new line
        envContent += `\n${targetLine}\n`;
    }
    
    // Write to file
    fs.writeFileSync(envPath, envContent, 'utf8');
    
    // IMPORTANT: Force reload the environment variable immediately
    process.env.WHATSAPP_TARGETS = targets.join(',');
    
    console.log(`Saved ${targets.length} targets to .env`);
}

// Helper function to format recipient
function formatRecipient(target) {
    if (target.includes('@')) {
        return target;
    }
    return `${target}@c.us`;
}

// Send message to all configured recipients
async function sendToAllRecipients(message) {
    const targets = getTargets();
    const results = [];
    
    for (const target of targets) {
        try {
            const recipient = formatRecipient(target);
            await whatsappClient.sendMessage(recipient, message);
            
            console.log(`✓ Message sent successfully to: ${recipient}`);
            results.push({
                recipient: recipient,
                success: true
            });
            
            await new Promise(resolve => setTimeout(resolve, 500));
            
        } catch (error) {
            console.error(`✗ Failed to send to ${target}:`, error.message);
            results.push({
                recipient: target,
                success: false,
                error: error.message
            });
        }
    }
    
    return results;
}

// ===== API ENDPOINTS =====

// Get service status
app.get('/api/status', (req, res) => {
    const targets = getTargets();
    
    res.json({
        whatsappConnected: isWhatsAppReady,
        needsQRCode: lastQRCode !== null,
        configuredTargets: targets.length,
        targets: targets,
        port: process.env.PORT || 3000
    });
});

// Logout endpoint - clears WhatsApp session
app.post('/api/logout', async (req, res) => {
    console.log('Logout request received');
    
    if (!isWhatsAppReady) {
        console.log('Cannot logout: WhatsApp not connected');
        return res.status(400).json({ error: 'Not connected to WhatsApp' });
    }
    
    try {
        console.log('Starting logout process...');
        
        // Destroy the WhatsApp client
        await whatsappClient.logout();
        console.log('WhatsApp client logged out');
        
        // Wait a moment for logout to complete
        await new Promise(resolve => setTimeout(resolve, 1000));
        
        // Delete session files - check both possible paths
        const sessionPath1 = path.join(__dirname, 'whatsapp-session');
        const sessionPath2 = path.join(__dirname, '..', 'whatsapp-session');
        
        let sessionDeleted = false;
        
        if (fs.existsSync(sessionPath1)) {
            console.log('Deleting session at:', sessionPath1);
            fs.rmSync(sessionPath1, { recursive: true, force: true });
            sessionDeleted = true;
        }
        
        if (fs.existsSync(sessionPath2)) {
            console.log('Deleting session at:', sessionPath2);
            fs.rmSync(sessionPath2, { recursive: true, force: true });
            sessionDeleted = true;
        }
        
        if (sessionDeleted) {
            console.log('Session files deleted');
        } else {
            console.log('No session files found to delete');
        }
        
        isWhatsAppReady = false;
        lastQRCode = null;
        
        console.log('Logout successful');
        res.json({ 
            success: true, 
            message: 'Logged out successfully. Refresh the page to reconnect.' 
        });
        
        // Reinitialize after sending response
        setTimeout(() => {
            console.log('Reinitializing WhatsApp client...');
            try {
                whatsappClient.initialize();
            } catch (error) {
                console.error('Error reinitializing:', error);
            }
        }, 2000);
        
    } catch (error) {
        console.error('Error during logout:', error);
        res.status(500).json({ 
            error: 'Failed to logout', 
            details: error.message 
        });
    }
});

// Get QR code for authentication
app.get('/api/qr-code', (req, res) => {
    if (lastQRCode) {
        res.json({ qrCode: lastQRCode });
    } else if (isWhatsAppReady) {
        res.json({ message: 'Already authenticated' });
    } else {
        res.json({ message: 'Waiting for QR code...' });
    }
});

// List all available chats
app.get('/api/chats', async (req, res) => {
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
                id: g.id._serialized,
                participants: g.participants ? g.participants.length : 0
            })),
            individuals: individuals.slice(0, 50).map(i => ({
                name: i.name || 'Unknown',
                id: i.id._serialized
            }))
        });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Get current targets
app.get('/api/targets', (req, res) => {
    const targets = getTargets();
    res.json({ targets });
});

// Add a target
app.post('/api/targets', (req, res) => {
    const { target } = req.body;
    
    if (!target) {
        return res.status(400).json({ error: 'Target is required' });
    }
    
    const targets = getTargets();
    
    if (targets.includes(target)) {
        return res.status(400).json({ error: 'Target already exists' });
    }
    
    targets.push(target);
    saveTargets(targets);
    
    res.json({ 
        success: true, 
        message: 'Target added',
        targets 
    });
});

// Remove a target
app.delete('/api/targets/:target', (req, res) => {
    const targetToRemove = decodeURIComponent(req.params.target);
    let targets = getTargets();
    
    const originalLength = targets.length;
    targets = targets.filter(t => t !== targetToRemove);
    
    if (targets.length === originalLength) {
        return res.status(404).json({ error: 'Target not found' });
    }
    
    saveTargets(targets);
    
    res.json({ 
        success: true, 
        message: 'Target removed',
        targets 
    });
});

// Test message endpoint
app.post('/api/test-message', async (req, res) => {
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

// Webhook endpoint (unchanged)
app.post('/webhook/alarm', async (req, res) => {
    console.log('Received alarm webhook:', req.body);

    if (!isWhatsAppReady) {
        console.error('WhatsApp client not ready');
        return res.status(503).json({ error: 'WhatsApp not connected' });
    }

    try {
        const alarmData = req.body;
        const message = formatAlarmMessage(alarmData);
        const results = await sendToAllRecipients(message);
        
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

// Debug endpoint to check paths
app.get('/debug/paths', (req, res) => {
    res.json({
        __dirname: __dirname,
        cwd: process.cwd(),
        publicPath: path.join(__dirname, 'public'),
        publicExists: fs.existsSync(path.join(__dirname, 'public')),
        filesInPublic: fs.existsSync(path.join(__dirname, 'public')) 
            ? fs.readdirSync(path.join(__dirname, 'public')) 
            : 'Directory not found'
    });
});

// Format the alarm message
function formatAlarmMessage(alarmData) {
    return `*Salto Alarm Triggered*
    
Time: ${new Date().toLocaleString()}
Type: ${alarmData.type || 'Unknown'}
Location: ${alarmData.location || 'Unknown'}
Details: ${alarmData.message || 'No details provided'}`;
}

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    console.log(`Salto-WhatsApp bridge running on port ${PORT}`);
    console.log(`Web interface available at: http://localhost:${PORT}`);
    const targets = getTargets();
    console.log(`Configured targets: ${targets.length}`);
});
