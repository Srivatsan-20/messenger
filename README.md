# Oodaa Messenger

A fully private, peer-to-peer messaging app built with Flutter. Zero cloud storage, zero server-based message routing, and no user-identifiable data collection.

## 🔐 Key Features

- **100% Private**: No phone numbers, emails, or personal data required
- **Peer-to-Peer**: Direct messaging using WebRTC with no message servers
- **End-to-End Encryption**: Signal-level security with Double Ratchet protocol
- **Offline Support**: Bluetooth/Wi-Fi Direct for nearby messaging
- **No Data Collection**: Everything stored locally on your device
- **QR Code Contacts**: Share contacts via QR codes or invite links
- **Disappearing Messages**: Optional message expiration
- **File Sharing**: Encrypted media transfer over P2P connections

## 🏗️ Architecture

### Tech Stack
- **Frontend**: Flutter (Dart)
- **P2P Communication**: flutter_webrtc
- **Local Storage**: Hive + flutter_secure_storage
- **Encryption**: AES-256-GCM, Curve25519, X3DH, Double Ratchet
- **QR Codes**: qr_flutter, qr_code_scanner
- **Offline**: Nearby Connections API (Android), Multipeer Connectivity (iOS)
- **Signaling**: Node.js + Socket.IO (temporary, no data storage)

### Security
- **Identity Keys**: Curve25519 key pairs stored in Android Keystore/iOS Secure Enclave
- **Message Encryption**: AES-256-GCM with forward secrecy via Double Ratchet
- **Key Exchange**: X3DH protocol for initial contact establishment
- **No Metadata**: No user tracking, analytics, or cloud backups

## 🚀 Quick Start

### Prerequisites
- Flutter SDK (>=3.10.0)
- Dart SDK (>=3.0.0)
- Android Studio / Xcode for mobile development
- Node.js (>=16.0.0) for signaling server

### 1. Clone and Setup Flutter App

```bash
git clone <repository-url>
cd oodaa_messenger
flutter pub get
```

### 2. Setup Signaling Server

```bash
cd signaling_server
npm install
npm start
```

The signaling server will run on `http://localhost:3001`

### 3. Configure App

Update the following files with your configuration:

#### `lib/main.dart`
```dart
// TODO: Update signaling server URL
const String SIGNALING_SERVER_URL = 'ws://your-server.com:3001';
```

#### `lib/webrtc/webrtc_manager.dart`
```dart
// TODO: Add your STUN/TURN servers
static const Map<String, dynamic> _iceServers = {
  'iceServers': [
    {'urls': 'stun:stun.l.google.com:19302'},
    // Add your TURN servers here for better connectivity
    // {
    //   'urls': 'turn:your-turn-server.com:3478',
    //   'username': 'your-username',
    //   'credential': 'your-password'
    // }
  ]
};
```

### 4. Run the App

```bash
flutter run
```

## 📱 Platform Setup

### Android
Add permissions to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
<uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
<uses-permission android:name="android.permission.CHANGE_WIFI_STATE" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.NEARBY_WIFI_DEVICES" />
```

### iOS
Add permissions to `ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>Camera access is required for QR code scanning</string>
<key>NSMicrophoneUsageDescription</key>
<string>Microphone access is required for voice messages</string>
<key>NSLocalNetworkUsageDescription</key>
<string>Local network access is required for peer-to-peer messaging</string>
<key>NSBluetoothAlwaysUsageDescription</key>
<string>Bluetooth access is required for offline messaging</string>
```

## 🔧 Configuration TODOs

### Required Configuration (Must Complete)

1. **Signaling Server URL**
   - File: `lib/main.dart`
   - Update: `SIGNALING_SERVER_URL` constant
   - Deploy signaling server and update URL

2. **STUN/TURN Servers**
   - File: `lib/webrtc/webrtc_manager.dart`
   - Add your own STUN/TURN servers for better connectivity
   - Recommended: Twilio, Xirsys, or self-hosted coturn

3. **App Icons and Branding**
   - Directory: `assets/images/`
   - Add app icons, splash screens, and branding assets
   - Update `pubspec.yaml` assets section

4. **Deep Link Scheme**
   - Files: `android/app/src/main/AndroidManifest.xml`, `ios/Runner/Info.plist`
   - Configure `oodaa://` URL scheme for invite links

### Optional Configuration

5. **Custom Fonts**
   - Directory: `assets/fonts/`
   - Add custom fonts and update `pubspec.yaml`

6. **App Store Metadata**
   - Update app name, description, and store listings
   - Configure signing certificates

7. **Analytics (Privacy-Focused)**
   - Consider privacy-focused analytics if needed
   - Ensure no PII collection

## 🏃‍♂️ Development Workflow

### Generate Hive Adapters
```bash
flutter packages pub run build_runner build
```

### Run Tests
```bash
flutter test
```

### Build Release
```bash
# Android
flutter build apk --release
flutter build appbundle --release

# iOS
flutter build ios --release
```

## 🚀 Deployment

### Signaling Server Deployment

Deploy to any cloud provider:

```bash
# Heroku
git subtree push --prefix signaling_server heroku main

# Railway
railway deploy

# Docker
docker build -t oodaa-signaling ./signaling_server
docker run -p 3001:3001 oodaa-signaling
```

### Mobile App Distribution

1. **Google Play Store**
   - Build signed APK/AAB
   - Upload to Play Console
   - Complete store listing

2. **Apple App Store**
   - Build signed IPA
   - Upload via Xcode or Transporter
   - Complete App Store Connect listing

3. **Direct Distribution**
   - Build APK for Android sideloading
   - Use TestFlight for iOS beta testing

## 🔒 Security Considerations

### Production Checklist

- [ ] Use production STUN/TURN servers
- [ ] Enable certificate pinning for signaling server
- [ ] Implement proper key backup/recovery
- [ ] Add biometric authentication
- [ ] Enable ProGuard/R8 for Android
- [ ] Use release signing keys
- [ ] Implement anti-tampering measures
- [ ] Add network security config

### Privacy Compliance

- [ ] Update privacy policy
- [ ] Ensure GDPR compliance (no data collection)
- [ ] Add data export functionality
- [ ] Implement secure deletion
- [ ] Document encryption methods

## 🛠️ Development TODOs

### High Priority
- [ ] Complete WebRTC connection management
- [ ] Implement QR code scanner/generator
- [ ] Add file sharing UI
- [ ] Implement offline messaging (Bluetooth/Wi-Fi)
- [ ] Add message status indicators
- [ ] Implement contact management UI
- [ ] Fix storage manager box name conflicts
- [ ] Complete Double Ratchet integration
- [ ] Add proper error handling throughout

### Medium Priority
- [ ] Add disappearing messages
- [ ] Implement backup/restore
- [ ] Add biometric lock
- [ ] Create settings screens
- [ ] Add notification system
- [ ] Implement search functionality
- [ ] Add proper public key derivation from private keys
- [ ] Implement BIP39 mnemonic backup

### Low Priority
- [ ] Add themes/customization
- [ ] Implement group messaging
- [ ] Add voice messages
- [ ] Create onboarding flow
- [ ] Add accessibility features
- [ ] Implement app shortcuts

### Code Quality
- [ ] Add comprehensive unit tests
- [ ] Add integration tests
- [ ] Improve error handling
- [ ] Add logging system
- [ ] Optimize performance
- [ ] Add code documentation

## 📄 License

MIT License - See LICENSE file for details.

## 🤝 Contributing

1. Fork the repository
2. Create feature branch
3. Commit changes
4. Push to branch
5. Create Pull Request

## 📞 Support

For issues and questions:
- Create GitHub issues for bugs
- Check documentation for setup help
- Review security considerations for production use

---

**Note**: This is a privacy-focused messaging app. Ensure all configurations maintain the zero-data-collection principle.
