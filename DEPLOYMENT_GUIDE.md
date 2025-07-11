# Oodaa Messenger - Complete Deployment Guide

This guide covers everything you need to deploy Oodaa Messenger from development to production.

## 📋 Prerequisites

### Development Environment
- Flutter SDK (>=3.10.0)
- Dart SDK (>=3.0.0)
- Android Studio / Xcode
- Node.js (>=16.0.0) for signaling server
- Git

### Production Requirements
- Cloud server for signaling server (Heroku, Railway, DigitalOcean, etc.)
- STUN/TURN servers (Twilio, Xirsys, or self-hosted)
- SSL certificates for signaling server
- Google Play Console / Apple Developer account

## 🚀 Quick Start

### 1. Initial Setup

```bash
# Clone the repository
git clone <repository-url>
cd oodaa_messenger

# Install Flutter dependencies
flutter pub get

# Generate Hive adapters
flutter packages pub run build_runner build

# Setup signaling server
cd signaling_server
npm install
cd ..
```

### 2. Configuration

Copy `config.template.dart` to `lib/config.dart` and update:

```dart
class AppConfig {
  static const String signalingServerUrl = 'wss://your-server.com';
  static const List<Map<String, dynamic>> iceServers = [
    {'urls': 'stun:stun.l.google.com:19302'},
    {
      'urls': 'turn:your-turn-server.com:3478',
      'username': 'your-username',
      'credential': 'your-password'
    }
  ];
}
```

### 3. Run Development

```bash
# Start signaling server
cd signaling_server
npm start

# In another terminal, run Flutter app
flutter run
```

## 🌐 Signaling Server Deployment

### Option 1: Heroku

```bash
cd signaling_server

# Create Heroku app
heroku create your-app-name

# Set environment variables
heroku config:set NODE_ENV=production
heroku config:set PORT=443
heroku config:set CORS_ORIGINS=https://your-domain.com

# Deploy
git add .
git commit -m "Deploy signaling server"
git push heroku main
```

### Option 2: Railway

```bash
cd signaling_server

# Install Railway CLI
npm install -g @railway/cli

# Login and deploy
railway login
railway init
railway up
```

### Option 3: DigitalOcean App Platform

1. Create new app in DigitalOcean
2. Connect GitHub repository
3. Set build command: `npm install`
4. Set run command: `npm start`
5. Set environment variables:
   - `NODE_ENV=production`
   - `CORS_ORIGINS=https://your-domain.com`

### Option 4: Self-Hosted with Docker

```dockerfile
# Dockerfile
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
EXPOSE 3001
CMD ["npm", "start"]
```

```bash
# Build and run
docker build -t oodaa-signaling .
docker run -p 3001:3001 -e NODE_ENV=production oodaa-signaling
```

## 📱 Mobile App Deployment

### Android Deployment

#### 1. Prepare for Release

```bash
# Create keystore
keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload

# Update android/key.properties
storePassword=<password>
keyPassword=<password>
keyAlias=upload
storeFile=<path-to-keystore>
```

#### 2. Build Release

```bash
# Build APK
flutter build apk --release

# Build App Bundle (recommended for Play Store)
flutter build appbundle --release
```

#### 3. Google Play Store

1. Create Google Play Console account
2. Create new app
3. Upload app bundle
4. Complete store listing:
   - App name: "Oodaa Messenger"
   - Description: "Private, peer-to-peer messaging with end-to-end encryption"
   - Screenshots and graphics
   - Privacy policy URL
5. Submit for review

### iOS Deployment

#### 1. Prepare for Release

```bash
# Update iOS bundle identifier
# In ios/Runner.xcodeproj, set bundle ID to com.yourcompany.oodaa

# Update version and build number
# In ios/Runner/Info.plist
```

#### 2. Build Release

```bash
# Build iOS
flutter build ios --release

# Open Xcode
open ios/Runner.xcworkspace

# Archive and upload to App Store Connect
```

#### 3. App Store

1. Create Apple Developer account
2. Create app in App Store Connect
3. Upload build via Xcode
4. Complete app information:
   - App name: "Oodaa Messenger"
   - Description: "Private, secure messaging without servers"
   - Keywords: "messaging, privacy, encryption, p2p"
   - Screenshots for all device sizes
5. Submit for review

## 🔧 Production Configuration

### 1. Security Hardening

#### Android
- Enable ProGuard/R8 obfuscation
- Use release signing keys
- Enable network security config
- Disable debugging in release builds

#### iOS
- Enable bitcode
- Use release certificates
- Configure App Transport Security
- Enable code signing

### 2. Performance Optimization

```dart
// lib/main.dart
void main() {
  if (kReleaseMode) {
    // Disable debug prints
    debugPrint = (String? message, {int? wrapWidth}) {};
  }
  
  runApp(const OodaaMessengerApp());
}
```

### 3. Monitoring and Analytics

```dart
// Add privacy-focused analytics
class PrivacyAnalytics {
  static void trackEvent(String event) {
    // Only track non-PII events
    if (kReleaseMode) {
      // Send to privacy-focused analytics service
    }
  }
}
```

## 🔒 Security Checklist

### Pre-Production
- [ ] All TODO comments addressed
- [ ] No hardcoded secrets or keys
- [ ] Proper certificate pinning
- [ ] Input validation on all user inputs
- [ ] Secure storage implementation verified
- [ ] Encryption implementation audited
- [ ] Network security configured

### Production
- [ ] HTTPS/WSS only for signaling
- [ ] TURN servers with authentication
- [ ] Rate limiting on signaling server
- [ ] Regular security updates
- [ ] Penetration testing completed
- [ ] Privacy policy published
- [ ] Terms of service published

## 📊 Monitoring and Maintenance

### Server Monitoring

```javascript
// Add to signaling server
const express = require('express');
const app = express();

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    memory: process.memoryUsage(),
    connections: getActiveConnections()
  });
});

// Metrics endpoint
app.get('/metrics', (req, res) => {
  res.json({
    activeConnections: getActiveConnections(),
    totalMessages: getTotalMessages(),
    uptime: process.uptime()
  });
});
```

### App Monitoring

```dart
// lib/utils/crash_reporting.dart
class CrashReporting {
  static void reportError(dynamic error, StackTrace stackTrace) {
    if (kReleaseMode) {
      // Report to crash reporting service
      // Ensure no PII is included
    }
  }
}
```

## 🔄 Update Strategy

### App Updates
1. Use semantic versioning (1.0.0, 1.0.1, 1.1.0)
2. Test updates thoroughly
3. Gradual rollout on app stores
4. Monitor crash reports and user feedback
5. Have rollback plan ready

### Server Updates
1. Use blue-green deployment
2. Test in staging environment
3. Monitor server metrics after deployment
4. Keep previous version ready for rollback

## 📈 Scaling Considerations

### Signaling Server Scaling
- Use load balancer with sticky sessions
- Implement Redis for session storage
- Monitor connection limits
- Auto-scaling based on CPU/memory usage

### TURN Server Scaling
- Multiple TURN servers in different regions
- Load balancing for TURN servers
- Monitor bandwidth usage
- Cost optimization for cloud TURN services

## 🆘 Troubleshooting

### Common Issues

1. **WebRTC Connection Fails**
   - Check STUN/TURN server configuration
   - Verify firewall settings
   - Test with different networks

2. **Signaling Server Disconnects**
   - Check server logs
   - Verify SSL certificate
   - Monitor server resources

3. **App Crashes on Startup**
   - Check device compatibility
   - Verify permissions
   - Review crash logs

### Debug Commands

```bash
# Flutter debugging
flutter logs
flutter analyze
flutter test

# Server debugging
npm run dev  # Development mode with detailed logs
docker logs container-name  # Docker logs
```

## 📞 Support and Maintenance

### User Support
- Create FAQ documentation
- Set up support email
- Monitor app store reviews
- Provide troubleshooting guides

### Developer Support
- Maintain detailed documentation
- Regular dependency updates
- Security patch management
- Community guidelines

---

**Remember**: This is a privacy-focused app. Always prioritize user privacy and security in all deployment decisions.
