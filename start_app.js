#!/usr/bin/env node

const { spawn } = require('child_process');
const path = require('path');
const os = require('os');

console.log('🚀 Starting Oodaa Messenger Full Stack...\n');

// Function to spawn a process with proper error handling
function spawnProcess(command, args, options = {}) {
    const defaultOptions = {
        stdio: 'inherit',
        shell: true,
        ...options
    };
    
    const child = spawn(command, args, defaultOptions);
    
    child.on('error', (error) => {
        console.error(`❌ Error starting ${command}:`, error.message);
    });
    
    return child;
}

// Start signaling server
console.log('📡 Starting signaling server...');
const signalingServer = spawnProcess('node', ['server.js'], {
    cwd: path.join(__dirname, 'signaling_server'),
    stdio: 'inherit'
});

// Wait a bit for signaling server to start
setTimeout(() => {
    console.log('\n📱 Starting Flutter app...');
    
    // Determine the correct Flutter command based on OS
    const isWindows = os.platform() === 'win32';
    const flutterCmd = isWindows ? 'flutter.bat' : 'flutter';
    
    // Start Flutter app
    const flutterApp = spawnProcess(flutterCmd, [
        'run',
        '-d', 'chrome',
        '--web-port=3000'
    ], {
        cwd: __dirname,
        stdio: 'inherit'
    });
    
    // Handle process termination
    function cleanup() {
        console.log('\n🛑 Shutting down...');
        
        if (signalingServer && !signalingServer.killed) {
            console.log('📡 Stopping signaling server...');
            signalingServer.kill('SIGTERM');
        }
        
        if (flutterApp && !flutterApp.killed) {
            console.log('📱 Stopping Flutter app...');
            flutterApp.kill('SIGTERM');
        }
        
        setTimeout(() => {
            process.exit(0);
        }, 1000);
    }
    
    // Handle various exit signals
    process.on('SIGINT', cleanup);
    process.on('SIGTERM', cleanup);
    process.on('exit', cleanup);
    
    // Handle child process exits
    signalingServer.on('exit', (code) => {
        if (code !== 0) {
            console.log(`📡 Signaling server exited with code ${code}`);
        }
    });
    
    flutterApp.on('exit', (code) => {
        if (code !== 0) {
            console.log(`📱 Flutter app exited with code ${code}`);
        }
        cleanup();
    });
    
}, 2000); // Wait 2 seconds for signaling server to start

// Keep the process alive
process.stdin.resume();

console.log('\n✨ Both services are starting...');
console.log('🌐 Signaling Server: http://localhost:3001');
console.log('📱 Flutter App: http://localhost:3000');
console.log('\n💡 Press Ctrl+C to stop all services\n');
