const { exec } = require('child_process');
const path = require('path');

console.log('🚀 Starting Oodaa Messenger...\n');

// Start signaling server
console.log('📡 Starting signaling server...');
const signalingServer = exec('node server.js', {
    cwd: path.join(__dirname, 'signaling_server')
});

signalingServer.stdout.on('data', (data) => {
    console.log(`[Signaling] ${data}`);
});

signalingServer.stderr.on('data', (data) => {
    console.error(`[Signaling Error] ${data}`);
});

// Wait 3 seconds then start Flutter
setTimeout(() => {
    console.log('\n📱 Starting Flutter app...');
    const flutterApp = exec('flutter run -d chrome --web-port=3000');
    
    flutterApp.stdout.on('data', (data) => {
        console.log(`[Flutter] ${data}`);
    });
    
    flutterApp.stderr.on('data', (data) => {
        console.error(`[Flutter Error] ${data}`);
    });
    
    flutterApp.on('close', (code) => {
        console.log(`\n📱 Flutter app exited with code ${code}`);
        signalingServer.kill();
        process.exit(code);
    });
    
}, 3000);

// Handle cleanup
process.on('SIGINT', () => {
    console.log('\n🛑 Shutting down...');
    signalingServer.kill();
    process.exit(0);
});

console.log('\n✨ Services are starting...');
console.log('🌐 Signaling Server: http://localhost:3001');
console.log('📱 Flutter App: http://localhost:3000');
console.log('\n💡 Press Ctrl+C to stop\n');
