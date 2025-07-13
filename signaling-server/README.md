# Oodaa Signaling Server

WebRTC signaling server for Oodaa Messenger P2P communication.

## Features

- 🌐 WebSocket-based signaling for WebRTC connections
- 👥 User registration and online status tracking
- 📨 Direct message routing between peers
- 🤝 Contact request handling
- 💚 Health monitoring endpoint
- 🔄 Automatic cleanup on disconnect

## Quick Start

### 1. Install Dependencies
```bash
cd signaling-server
npm install
```

### 2. Start the Server
```bash
npm start
```

Or for development with auto-restart:
```bash
npm run dev
```

### 3. Server Info
- **Port**: 3001 (default)
- **WebSocket URL**: `ws://localhost:3001`
- **Health Check**: `http://localhost:3001/health`

## Message Types

### Client → Server

#### Register User
```json
{
  "type": "register",
  "userId": "user123",
  "userInfo": {
    "name": "John Doe",
    "avatar": "..."
  }
}
```

#### WebRTC Signaling
```json
{
  "type": "offer",
  "targetUserId": "user456",
  "offer": { ... }
}
```

#### Direct Message
```json
{
  "type": "message",
  "targetUserId": "user456",
  "messageData": {
    "text": "Hello!",
    "timestamp": "2024-01-01T12:00:00Z"
  }
}
```

### Server → Client

#### User Status Updates
```json
{
  "type": "user-status",
  "userId": "user123",
  "isOnline": true,
  "userInfo": { ... }
}
```

#### Incoming Messages
```json
{
  "type": "message",
  "fromUserId": "user123",
  "messageData": { ... }
}
```

## Environment Variables

- `PORT`: Server port (default: 3001)

## Health Monitoring

Check server status:
```bash
curl http://localhost:3001/health
```

Response:
```json
{
  "status": "healthy",
  "connectedClients": 5,
  "onlineUsers": 3,
  "uptime": 3600
}
```

## Production Deployment

For production, consider:
- Using a process manager (PM2)
- Setting up SSL/TLS
- Implementing rate limiting
- Adding authentication
- Using a load balancer for scaling
