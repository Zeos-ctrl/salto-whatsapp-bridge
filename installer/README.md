# Salto-WhatsApp Bridge

Automatically forwards Salto Space alarms to WhatsApp groups and contacts.

## Features

- Receive Salto alarm webhooks and forward to WhatsApp
- Support for multiple WhatsApp groups and individual contacts
- Web-based configuration interface
- Runs as Windows Service (automatic startup)

## Installation

1. **Prerequisites:**
   - Windows Server 2016 or later
   - Node.js v18 or higher from https://nodejs.org/

2. **Extract the ZIP file** to a permanent location (e.g., C:\salto-whatsapp-bridge)

3. **Install as Windows Service:**
   - Right-click `install-service.bat`
   - Select "Run as Administrator"

4. **First-time setup:**
   - Open http://localhost:3000 in your browser
   - Scan the QR code with WhatsApp
   - Add your target groups/contacts
   - Test the connection

## Configuration

### Via Web Interface (Recommended)
1. Open http://localhost:3000
2. Click "Refresh Chats" to see available groups
3. Click on any group/contact to add as target
4. Use "Send Test" to verify

## Configure Salto Space

In Salto Space webhook settings:
- **URL:** `http://SERVER_IP:3000/webhook/alarm`
- **Method:** POST
- **Content-Type:** application/json

## Troubleshooting

### Service won't start
1. Open Services (`services.msc`)
2. Find "Salto WhatsApp Bridge"
3. Check Event Viewer for errors

### WhatsApp disconnects
1. Stop the service
2. Delete the whatsapp-session folder
3. Start the service
4. Scan QR code again

### Port 3000 in use
Edit `.env` and change `PORT=3000` to another port

## Firewall Configuration

Allow inbound TCP port 3000:
```cmd
netsh advfirewall firewall add rule name="Salto-WhatsApp Bridge" dir=in action=allow protocol=TCP localport=3000
```

## Uninstall

1. Right-click `uninstall-service.bat`
2. Select "Run as Administrator"
