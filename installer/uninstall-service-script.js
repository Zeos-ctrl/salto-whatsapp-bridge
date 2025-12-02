const Service = require('node-windows').Service;
const path = require('path');

const svc = new Service({
    name: 'Salto WhatsApp Bridge',
    script: path.join(__dirname, 'server.js')
});

svc.on('uninstall', function() {
    console.log('Service uninstalled successfully!');
});

svc.on('error', function(err) {
    console.error('Error uninstalling service:', err);
});

svc.on('alreadyuninstalled', function() {
    console.log('Service is not installed.');
});

console.log('Uninstalling Salto WhatsApp Bridge service...');
svc.uninstall();
