# Salto-WhatsApp Bridge - Windows Server Installation Guide

## Prerequisites

1. **Node.js** (v18 or higher)
   - Download from: https://nodejs.org/
   - Choose "Windows Installer (.msi)" 64-bit
   - Run installer and follow prompts
   - Verify installation:
```cmd
     node --version
     npm --version
```

## Installation Steps

### 1. Create Project Directory
```cmd
cd C:\
mkdir salto-whatsapp-bridge
cd salto-whatsapp-bridge
```

### 2. Copy Files
Copy these files to `C:\salto-whatsapp-bridge\`:
- `server.js`
- `package.json`
- `.env`

### 3. Install Dependencies
```cmd
npm install
```

### 4. First-Time Setup & QR Code Scanning

Run the server manually first to authenticate:
```cmd
node server.js
```

A QR code will appear in the terminal. 

**On your phone:**
1. Open WhatsApp
2. Go to Settings → Linked Devices
3. Tap "Link a Device"
4. Scan the QR code from the terminal

Wait until you see: `WhatsApp client is ready!`

Press `Ctrl+C` to stop the server.

### 5. Find Group ID (if sending to group)

If you want to send to a WhatsApp group:

1. Start the server: `node server.js`
2. Open browser: `http://localhost:3000/list-chats`
3. Find your group name and copy its `id`
4. Update `.env`:
```
   WHATSAPP_TARGET=123456789012345678@g.us
   WHATSAPP_TARGET_TYPE=group
```

### 6. Test the Webhook

In PowerShell:
```powershell
Invoke-WebRequest -Uri http://localhost:3000/webhook/alarm `
  -Method POST `
  -ContentType "application/json" `
  -Body '{"type":"Test Alarm","location":"Test Location","message":"Testing from PowerShell"}'
```

You should receive a WhatsApp message!

### 7. Install as Windows Service

Install node-windows globally:
```cmd
npm install -g node-windows
```

Create `install-service.js` in the project directory:
```javascript
const Service = require('node-windows').Service;
const path = require('path');

// Create a new service object
const svc = new Service({
    name: 'Salto WhatsApp Bridge',
    description: 'Forwards Salto Space alarms to WhatsApp',
    script: path.join(__dirname, 'server.js'),
    nodeOptions: [
        '--harmony',
        '--max_old_space_size=4096'
    ],
    env: [
        {
            name: "NODE_ENV",
            value: "production"
        }
    ]
});

// Listen for the "install" event
svc.on('install', function() {
    console.log('Service installed successfully!');
    console.log('Starting service...');
    svc.start();
});

svc.on('alreadyinstalled', function() {
    console.log('Service is already installed.');
});

svc.on('start', function() {
    console.log(svc.name + ' started!');
    console.log('Service is now running in the background.');
});

// Install the service
svc.install();
```

**Run as Administrator:**
```cmd
node install-service.js
```

### 8. Manage the Service

The service will now run automatically on startup.

**View in Services:**
- Press `Win+R`, type `services.msc`, press Enter
- Find "Salto WhatsApp Bridge"
- Right-click to Start/Stop/Restart

**Check logs:**
Logs are stored in Windows Event Viewer:
- Open Event Viewer
- Go to: Windows Logs → Application
- Filter by source: "Salto WhatsApp Bridge"

### 9. Configure Salto Space

In Salto Space webhook settings:
- **URL:** `http://localhost:3000/webhook/alarm`
- **Method:** POST
- **Content-Type:** application/json

If Salto is on a different machine:
- Replace `localhost` with the server's IP address
- Ensure Windows Firewall allows port 3000

### 10. Uninstall Service (if needed)

Create `uninstall-service.js`:
```javascript
const Service = require('node-windows').Service;
const path = require('path');

const svc = new Service({
    name: 'Salto WhatsApp Bridge',
    script: path.join(__dirname, 'server.js')
});

svc.on('uninstall', function() {
    console.log('Service uninstalled successfully!');
});

svc.uninstall();
```

Run as Administrator:
```cmd
node uninstall-service.js
```

## Troubleshooting

### Service won't start
1. Check Event Viewer for errors
2. Ensure WhatsApp session exists (run `node server.js` manually first)
3. Verify `.env` file is properly configured

### WhatsApp disconnects
- The session may expire after extended periods
- Stop the service, delete `whatsapp-session` folder
- Run `node server.js` manually and re-scan QR code
- Restart the service

### Port 3000 already in use
- Change `PORT=3000` to another port in `.env`
- Update Salto webhook URL accordingly

### Messages not sending
- Check `/health` endpoint: `http://localhost:3000/health`
- Verify `whatsappReady` is `true`
- Check Windows Event Viewer for errors

## Firewall Configuration

If Salto is on a different machine, allow port 3000:

1. Windows Defender Firewall → Advanced Settings
2. Inbound Rules → New Rule
3. Port → TCP → 3000
4. Allow the connection
5. Apply to all profiles
6. Name: "Salto WhatsApp Bridge"

## Security Notes

- The `.env` file contains sensitive configuration - restrict access
- Only allow necessary IPs to access port 3000
- Keep Node.js and dependencies updated: `npm update`
- Regularly check Windows Event Viewer for issues
