# 🚀 Deployment Guide for Real-World Testing

## Option 1: Local Network (Same WiFi)

### Prerequisites
- Both devices on same WiFi network
- Windows Firewall allows connections on port 3002

### Steps
1. **Find your computer's IP address:**
   ```bash
   ipconfig
   # Look for IPv4 Address (e.g., 192.168.1.100)
   ```

2. **Update the signaling server URL in `lib/networking/webrtc_manager.dart`:**
   ```dart
   static const String signalingServerUrl = 'ws://YOUR_IP_HERE:3002';
   ```

3. **Start the signaling server:**
   ```bash
   cd signaling-server
   npm run dev
   ```

4. **Start Flutter for network access:**
   ```bash
   flutter run -d chrome --web-port 3000 --web-hostname 0.0.0.0
   ```

5. **Access from devices:**
   - Your computer: `http://localhost:3000`
   - Wife's device: `http://YOUR_IP_HERE:3000`

### Troubleshooting
- **Can't connect?** Check Windows Firewall
- **Server not accessible?** Try: `netsh advfirewall firewall add rule name="Oodaa Server" dir=in action=allow protocol=TCP localport=3002`

## Option 2: Cloud Deployment (Recommended)

### Using Railway (Free Tier)

1. **Create account at railway.app**

2. **Deploy signaling server:**
   - Connect GitHub repo
   - Deploy `signaling-server` folder
   - Railway will auto-detect Node.js

3. **Get your server URL:**
   - Railway provides: `https://your-app.railway.app`
   - Update WebRTC manager: `wss://your-app.railway.app`

4. **Deploy Flutter app:**
   - Build: `flutter build web`
   - Deploy `build/web` folder to Netlify/Vercel

### Using Heroku (Free Tier)

1. **Install Heroku CLI**

2. **Deploy signaling server:**
   ```bash
   cd signaling-server
   git init
   heroku create your-app-name
   git add .
   git commit -m "Deploy signaling server"
   git push heroku main
   ```

3. **Update Flutter app:**
   ```dart
   static const String signalingServerUrl = 'wss://your-app-name.herokuapp.com';
   ```

## Option 3: Quick Test Setup

### For immediate testing:

1. **Use ngrok (tunneling service):**
   ```bash
   # Install ngrok
   # Start your local server
   npm run dev
   
   # In another terminal
   ngrok http 3002
   # Copy the https URL (e.g., https://abc123.ngrok.io)
   ```

2. **Update Flutter app:**
   ```dart
   static const String signalingServerUrl = 'wss://abc123.ngrok.io';
   ```

3. **Deploy Flutter to GitHub Pages:**
   ```bash
   flutter build web
   # Upload build/web to GitHub Pages
   ```

## Security Notes for Real-World Use

### Current Status: ⚠️ Development Mode
- No encryption (messages sent in plain text)
- No authentication
- No message persistence on server
- Suitable for testing only

### For Production Use, Add:
- End-to-end encryption
- User authentication
- HTTPS/WSS only
- Rate limiting
- Message validation

## Testing Checklist

### Day 1: Basic Functionality
- [ ] Both can create identities
- [ ] QR code sharing works
- [ ] Contact requests work
- [ ] Real-time messaging works
- [ ] Data persists across sessions

### Day 2-3: Reliability Testing
- [ ] Works on different devices (phone, tablet, laptop)
- [ ] Handles network disconnections
- [ ] Server restarts don't break experience
- [ ] Multiple conversations work

### Day 4-7: User Experience
- [ ] Easy to use for non-technical person
- [ ] Performance is acceptable
- [ ] No major bugs or crashes
- [ ] Identify missing features

## Feedback Collection

### Questions to Ask Your Wife:
1. How easy was it to set up?
2. Is the messaging fast enough?
3. What features are missing?
4. Any confusing parts?
5. Would you use this over WhatsApp/Telegram?

### Technical Metrics to Track:
- Connection stability
- Message delivery time
- Battery usage (on mobile)
- Data usage
- Any error messages

## Next Steps Based on Testing

### If Testing Goes Well:
- Add end-to-end encryption
- Implement file sharing
- Add push notifications
- Create mobile app

### If Issues Found:
- Fix critical bugs first
- Improve user experience
- Add missing features
- Optimize performance

## Emergency Contacts

If something breaks during testing:
1. Check server logs
2. Check browser console (F12)
3. Restart signaling server
4. Clear browser data if needed
5. Use "Clear All Data" button in app
