const Service = require('node-windows').Service;
const path = require('path');

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

svc.on('install', function() {
    console.log('Service installed successfully!');
    console.log('Starting service...');
    svc.start();
});

svc.on('alreadyinstalled', function() {
    console.log('Service is already installed.');
});

svc.on('start', function() {
    console.log('Service started successfully!');
    console.log('Access the web interface at: http://localhost:3000');
});

svc.install();
