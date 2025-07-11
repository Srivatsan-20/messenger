# 🔐 Oodaa Messenger

**Private P2P messaging with Signal-level encryption - no servers, no data collection**

[![Flutter](https://img.shields.io/badge/Flutter-3.10+-blue.svg)](https://flutter.dev/)
[![Node.js](https://img.shields.io/badge/Node.js-16+-green.svg)](https://nodejs.org/)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Security](https://img.shields.io/badge/Security-Signal%20Protocol-red.svg)](https://signal.org/docs/)

> **True privacy**: Your messages never touch our servers. Direct peer-to-peer communication with military-grade encryption.

## ✨ Features

### 🔒 **Privacy First**
- **Zero data collection** - No analytics, tracking, or cloud storage
- **No personal data required** - No phone numbers, emails, or real names
- **Local-only storage** - Everything stays on your device
- **No message servers** - Direct peer-to-peer communication

### 🛡️ **Signal-Level Security**
- **End-to-end encryption** with AES-256-GCM
- **Perfect forward secrecy** using Double Ratchet protocol
- **X3DH key exchange** for initial contact establishment
- **Curve25519** elliptic curve cryptography
- **Secure storage** in Android Keystore / iOS Secure Enclave

### 📱 **Modern Experience**
- **QR code contacts** - Easy contact sharing, no phone numbers
- **Offline messaging** - Bluetooth/Wi-Fi Direct for nearby communication
- **File sharing** - Encrypted media transfer over P2P connections
- **Disappearing messages** - Optional message expiration
- **Biometric lock** - PIN/fingerprint/face unlock with auto-lock

### 🌐 **Peer-to-Peer**
- **WebRTC** direct communication
- **Minimal signaling** server for peer discovery only
- **NAT traversal** with STUN/TURN support
- **Auto-reconnection** and connection recovery

## 🚀 Quick Start

### Prerequisites
- Flutter SDK (>=3.10.0)
- Node.js (>=16.0.0)
- Android Studio / Xcode

### 1. Clone & Setup
```bash
git clone https://github.com/YOUR_USERNAME/oodaa-messenger.git
cd oodaa-messenger

# Install dependencies
flutter pub get
flutter packages pub run build_runner build

# Setup signaling server
cd signaling_server && npm install && cd ..
```

### 2. Configure
```bash
# Copy configuration template
cp config.template.dart lib/config.dart

# Edit lib/config.dart with your settings
# - Signaling server URL
# - STUN/TURN servers
```

### 3. Run
```bash
# Start signaling server
cd signaling_server && npm start

# Run Flutter app (new terminal)
flutter run
```

## 📖 Documentation

- **[Setup Guide](README.md)** - Complete installation and configuration
- **[Deployment Guide](DEPLOYMENT_GUIDE.md)** - Production deployment instructions
- **[Security Architecture](docs/SECURITY.md)** - Cryptographic implementation details
- **[API Documentation](docs/API.md)** - Code structure and APIs

## 🏗️ Architecture

```
┌─────────────────┐    ┌─────────────────┐
│   Flutter App   │    │   Flutter App   │
│   (Device A)    │    │   (Device B)    │
└─────────┬───────┘    └─────────┬───────┘
          │                      │
          │    WebRTC P2P        │
          │ ◄─────────────────► │
          │                      │
          └──────┬─────────┬─────┘
                 │         │
         ┌───────▼─────────▼───────┐
         │   Signaling Server      │
         │ (Peer Discovery Only)   │
         └─────────────────────────┘
```

### Tech Stack
- **Frontend**: Flutter with Material Design 3
- **P2P**: WebRTC data channels
- **Encryption**: Signal Protocol (X3DH + Double Ratchet)
- **Storage**: Hive + Flutter Secure Storage
- **Signaling**: Node.js + Socket.IO
- **Offline**: Nearby Connections API

## 🔐 Security

### Cryptographic Guarantees
- **Message Encryption**: AES-256-GCM with unique keys per message
- **Key Exchange**: X3DH protocol for initial contact establishment
- **Forward Secrecy**: Double Ratchet ensures past messages stay secure
- **Authentication**: Ed25519 digital signatures
- **Key Derivation**: HKDF for secure key generation

### Privacy Guarantees
- **No message storage** on servers
- **No metadata collection** or analysis
- **No user tracking** or analytics
- **No social graph** construction
- **Local-only** contact lists and message history

### What Servers See
- ❌ Message content (never visible)
- ❌ User identities (only temporary connection IDs)
- ❌ Contact relationships (no social graph)
- ❌ Message metadata (no timing analysis)
- ✅ Connection requests (temporary, for peer discovery only)

## 🛠️ Development

### Project Structure
```
oodaa_messenger/
├── lib/
│   ├── auth/           # Identity management
│   ├── crypto/         # Cryptography (Signal protocol)
│   ├── webrtc/         # P2P communication
│   ├── storage/        # Local encrypted storage
│   ├── ui/             # Flutter UI components
│   └── models/         # Data models
├── signaling_server/   # Node.js signaling server
├── android/           # Android platform code
├── ios/               # iOS platform code
└── docs/              # Documentation
```

### Contributing
1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Testing
```bash
# Run Flutter tests
flutter test

# Run signaling server tests
cd signaling_server && npm test

# Test on device
flutter run
```

## 📱 Screenshots

| Setup | Contacts | Chat | Settings |
|-------|----------|------|----------|
| ![Setup](docs/screenshots/setup.png) | ![Contacts](docs/screenshots/contacts.png) | ![Chat](docs/screenshots/chat.png) | ![Settings](docs/screenshots/settings.png) |

## 🚀 Deployment

### Mobile Apps
- **Android**: Google Play Store or direct APK
- **iOS**: Apple App Store or TestFlight

### Signaling Server
- **Heroku**: One-click deployment
- **Railway**: Git-based deployment
- **DigitalOcean**: App Platform deployment
- **Self-hosted**: Docker or direct Node.js

See [Deployment Guide](DEPLOYMENT_GUIDE.md) for detailed instructions.

## 🤝 Community

- **Issues**: Report bugs and request features
- **Discussions**: Ask questions and share ideas
- **Security**: Report security issues privately
- **Contributing**: Help improve the codebase

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **Signal Foundation** - For the Signal Protocol specification
- **WebRTC Project** - For peer-to-peer communication standards
- **Flutter Team** - For the amazing cross-platform framework
- **Privacy advocates** - For inspiring truly private communication

## ⚠️ Disclaimer

This software is provided as-is for educational and research purposes. While we've implemented industry-standard cryptography, no software is 100% secure. Use at your own risk and consider having the cryptographic implementation audited before production use.

---

**Built with privacy, security, and user freedom as core principles.**

*"Privacy is not something that I'm merely entitled to, it's an absolute prerequisite." - Marlon Brando*
