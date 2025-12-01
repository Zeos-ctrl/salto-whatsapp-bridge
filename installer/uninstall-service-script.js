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
