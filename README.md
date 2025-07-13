# 🚀 Oodaa Messenger - P2P Real-Time Messaging App

A complete peer-to-peer messaging application built with Flutter and Node.js, featuring real-time communication, persistent storage, and cross-device compatibility.

## ✨ Current Implementation Features

### 🔥 Core Features (Working)
- **Real-time P2P messaging** - Direct communication between devices via WebSocket
- **Persistent identity** - No re-registration needed across sessions
- **Bidirectional contacts** - Both users get added automatically
- **QR code sharing** - Easy contact discovery and addition
- **Cross-device support** - Works on web browsers and mobile
- **Auto-reconnection** - Handles server restarts gracefully
- **Data persistence** - Browser localStorage for contacts and messages

### 🚧 Planned Features
- **End-to-End Encryption** - Signal-level security with Double Ratchet protocol
- **Offline Support** - Bluetooth/Wi-Fi Direct for nearby messaging
- **File Sharing** - Encrypted media transfer over P2P connections
- **Disappearing Messages** - Optional message expiration

## 🏗️ Current Architecture

```
┌─────────────────┐    WebSocket    ┌─────────────────┐
│   Flutter App   │ ◄──────────────► │ Signaling Server│
│   (Client A)    │                  │   (Node.js)     │
└─────────────────┘                  └─────────────────┘
                                              ▲
                                              │ WebSocket
                                              ▼
                                     ┌─────────────────┐
                                     │   Flutter App   │
                                     │   (Client B)    │
                                     └─────────────────┘
```

### Tech Stack
- **Frontend**: Flutter (Dart) - Cross-platform UI
- **Backend**: Node.js WebSocket server - Message routing and signaling
- **Communication**: WebSocket - Real-time bidirectional communication
- **Storage**: Browser localStorage - Client-side data persistence

### 📁 Project Structure
```
messenger/
├── lib/                          # Flutter application
│   ├── main.dart                 # Main app entry point
│   ├── networking/               # WebRTC and networking
│   │   └── webrtc_manager.dart   # WebSocket connection management
│   ├── ui/                       # User interface components
│   └── storage/                  # Data persistence
├── signaling-server/             # Node.js signaling server
│   ├── server.js                 # WebSocket server
│   ├── package.json              # Node.js dependencies
│   └── node_modules/             # Server dependencies
├── android/                      # Android configuration
├── web/                          # Web deployment files
└── deploy-guide.md               # Deployment instructions
```

## 🚀 Quick Start

### Prerequisites
- **Flutter SDK** (3.0+)
- **Node.js** (16+)
- **Git**
- **Chrome/Edge** (for web testing)

### 1️⃣ Clone Repository
```bash
git clone https://github.com/Srivatsan-20/messenger.git
cd messenger
```

### 2️⃣ Start Signaling Server
```bash
cd signaling-server
npm install
npm run dev
```
Server will start on `http://localhost:3002` with auto-restart enabled.

### 3️⃣ Start Flutter App
```bash
# In project root directory
flutter pub get
flutter run -d chrome --web-port 3000
```
App will open at `http://localhost:3000`

### 4️⃣ Test P2P Messaging
1. **Open two browser windows** (regular + incognito)
2. **Create identities** in both windows
3. **Share QR codes** to add contacts
4. **Start messaging** in real-time!

## 📱 Mobile Development

### Build Android APK
```bash
# Debug APK for testing
flutter build apk --debug

# Release APK for distribution
flutter build apk --release

# Find APK at: build/app/outputs/flutter-apk/
```

### iOS Development
```bash
# Requires macOS and Xcode
flutter build ios
```

## 🌐 Deployment Options

### Local Network Testing
1. **Find your IP address**: `ipconfig` (Windows) or `ifconfig` (Mac/Linux)
2. **Update server URL** in `lib/networking/webrtc_manager.dart`
3. **Start server**: `npm run dev`
4. **Access from other devices**: `http://YOUR_IP:3000`

### Cloud Deployment
- **Railway**: Deploy signaling server automatically
- **Heroku**: Free tier available for server hosting
- **Netlify/Vercel**: Deploy Flutter web build
- **See `deploy-guide.md`** for detailed instructions

## 🛠️ Development

### Key Files to Understand
- **`lib/main.dart`** - Main app logic and UI
- **`lib/networking/webrtc_manager.dart`** - WebSocket connection handling
- **`signaling-server/server.js`** - Server-side message routing
- **`android/app/src/main/AndroidManifest.xml`** - Android permissions

### Development Workflow
1. **Start server**: `npm run dev` (auto-restarts on changes)
2. **Start Flutter**: `flutter run -d chrome`
3. **Hot reload**: Press `r` in Flutter terminal
4. **Make changes** - both server and Flutter auto-update

### Adding Features
- **New message types**: Update `webrtc_manager.dart` and `server.js`
- **UI changes**: Modify `main.dart` or create new screens
- **Storage**: Use browser localStorage or add database
- **Security**: Implement end-to-end encryption

## 🧪 Testing

### Manual Testing
```bash
# Test with multiple users
# Window 1: Regular browser
# Window 2: Incognito mode
# Window 3: Different browser/device
```

### Automated Testing
```bash
# Run Flutter tests
flutter test

# Run server tests (if added)
cd signaling-server
npm test
```

## 🐛 Troubleshooting

### Common Issues

**Server won't start**
```bash
# Check if port is in use
netstat -an | findstr :3002
# Kill process if needed
taskkill /F /PID <process_id>
```

**Flutter connection fails**
- Check server is running on port 3002
- Verify WebSocket URL in `webrtc_manager.dart`
- Check browser console for errors (F12)

**Messages not delivering**
- Check both clients are connected
- Verify contact IDs match exactly
- Check server logs for routing errors

**Data not persisting**
- Check browser localStorage isn't full
- Verify not in incognito mode (for persistence)
- Clear browser data if corrupted

## 🤝 Contributing

### Getting Started
1. **Fork the repository**
2. **Create feature branch**: `git checkout -b feature/amazing-feature`
3. **Make changes** and test thoroughly
4. **Commit**: `git commit -m 'Add amazing feature'`
5. **Push**: `git push origin feature/amazing-feature`
6. **Create Pull Request**

### Code Style
- **Flutter**: Follow Dart style guide
- **JavaScript**: Use ES6+ features
- **Comments**: Document complex logic
- **Testing**: Add tests for new features

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/Srivatsan-20/messenger/issues)
- **Discussions**: [GitHub Discussions](https://github.com/Srivatsan-20/messenger/discussions)
- **Documentation**: See `deploy-guide.md` for deployment help

---

**Built with ❤️ using Flutter and Node.js**

*Ready for real-world P2P messaging! 🚀*
