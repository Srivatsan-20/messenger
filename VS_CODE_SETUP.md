# VS Code Setup for Oodaa Messenger

This guide explains how to run the Oodaa Messenger app using VS Code's F5 functionality.

## 🚀 Quick Start (F5 Method)

### Method 1: Using VS Code Debugger (Recommended)
1. Open the project in VS Code
2. Press `F5` or go to `Run and Debug` (Ctrl+Shift+D)
3. Select "🚀 Start Oodaa Messenger (Full Stack)" from the dropdown
4. Click the play button or press F5

This will automatically:
- Start the signaling server (Node.js) on port 3001
- Start the Flutter app on Chrome at port 3000
- Open both in the VS Code integrated terminal

### Method 2: Using Tasks
1. Press `Ctrl+Shift+P` to open command palette
2. Type "Tasks: Run Task"
3. Select "🚀 Start Oodaa Messenger (Full Stack)"

### Method 3: Manual Scripts
You can also run these scripts directly:

**Windows:**
```bash
# PowerShell
./start_app.ps1

# Command Prompt
start_app.bat

# Node.js
node start_app.js
```

**Linux/Mac:**
```bash
node start_app.js
```

## 📁 Files Created

The following files have been created to support F5 functionality:

### VS Code Configuration
- `.vscode/launch.json` - Debug configurations
- `.vscode/tasks.json` - Task definitions

### Startup Scripts
- `start_app.js` - Node.js startup script (cross-platform)
- `start_app.ps1` - PowerShell script (Windows)
- `start_app.bat` - Batch file (Windows)

## 🔧 Configuration Details

### Launch Configurations Available:
1. **🚀 Start Oodaa Messenger (Full Stack)** - Starts both signaling server and Flutter app
2. **🌐 Signaling Server Only** - Starts only the Node.js signaling server

### Tasks Available:
1. **🚀 Start Oodaa Messenger (Full Stack)** - PowerShell script launcher
2. **Start Signaling Server** - Background signaling server
3. **Flutter: Run on Chrome** - Flutter app only
4. **Flutter: Clean** - Clean Flutter build
5. **Flutter: Pub Get** - Get Flutter dependencies

## 🌐 Access URLs

Once started, you can access:
- **Flutter App**: http://localhost:3000
- **Signaling Server**: http://localhost:3001

## 🛑 Stopping Services

### From VS Code:
- Press `Ctrl+C` in the integrated terminal
- Click the stop button in the debug toolbar
- Close VS Code

### From Scripts:
- **PowerShell/Batch**: Press any key when prompted
- **Node.js**: Press `Ctrl+C`

## 🔍 Troubleshooting

### Common Issues:

1. **Port already in use**
   - Make sure no other instances are running
   - Kill existing processes: `taskkill /F /IM node.exe` (Windows)

2. **Flutter not found**
   - Ensure Flutter is installed and in PATH
   - Run `flutter doctor` to verify installation

3. **Node.js not found**
   - Ensure Node.js is installed and in PATH
   - Run `node --version` to verify installation

4. **Permission errors (PowerShell)**
   - Run: `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser`

### Debug Information:
- Check VS Code's integrated terminal for error messages
- Verify both services are running in separate terminal tabs
- Check browser console for any client-side errors

## 📝 Notes

- The signaling server starts first and waits 2-3 seconds before starting Flutter
- Both services run in separate processes for better isolation
- All scripts include proper cleanup when terminated
- The setup works on Windows, Linux, and macOS

## 🎯 Default Configuration

When you press F5, it will:
1. Start the signaling server on port 3001
2. Wait for it to initialize
3. Start Flutter app targeting Chrome on port 3000
4. Open the app automatically in your default browser

This provides a seamless development experience where everything starts with a single keypress!
