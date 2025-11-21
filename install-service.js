const Service = require('node-windows').Service;

const svc = new Service({
    name: 'Salto WhatsApp Bridge',
    description: 'Forwards Salto alarms to WhatsApp',
    script: require('path').join(__dirname, 'server.js'),
    nodeOptions: [
        '--harmony',
        '--max_old_space_size=4096'
    ]
});

svc.on('install', () => {
    console.log('Service installed successfully!');
    svc.start();
});

svc.install();
