const Service = require('node-windows').Service;
const path = require('path');

// Use server.js if it exists, otherwise fail with clear message
const scriptPath = path.join(__dirname, 'server.js');
const fs = require('fs');

if (!fs.existsSync(scriptPath)) {
    console.error('ERROR: server.js not found in:', __dirname);
    console.error('Make sure server.js was copied during the build process.');
    process.exit(1);
}

const svc = new Service({
    name: 'Salto WhatsApp Bridge',
    description: 'Forwards Salto Space alarms to WhatsApp',
    script: scriptPath,
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

svc.on('install', function() {
    console.log('Service installed successfully!');
    console.log('Starting service...');
    svc.start();
});

svc.on('alreadyinstalled', function() {
    console.log('Service is already installed.');
    console.log('To reinstall, run uninstall-service.bat first.');
});

svc.on('start', function() {
    console.log('Service started successfully!');
    console.log('Access the web interface at: http://localhost:3000');
});

svc.on('error', function(err) {
    console.error('Error installing service:', err);
});

console.log('Installing Salto WhatsApp Bridge service...');
svc.install();
