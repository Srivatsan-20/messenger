const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const cors = require('cors');
const helmet = require('helmet');
const { RateLimiterMemory } = require('rate-limiter-flexible');

// TODO: Set your desired port and CORS origins
const PORT = process.env.PORT || 3001;
const CORS_ORIGINS = process.env.CORS_ORIGINS ? 
  process.env.CORS_ORIGINS.split(',') : 
  ['http://localhost:3000', 'https://your-domain.com'];

const app = express();
const server = http.createServer(app);

// Security middleware
app.use(helmet());
app.use(cors({
  origin: CORS_ORIGINS,
  credentials: true
}));

// Rate limiting
const rateLimiter = new RateLimiterMemory({
  keyGenerator: (req, res, next) => {
    return req.ip;
  },
  points: 100, // Number of requests
  duration: 60, // Per 60 seconds
});

// Socket.IO setup
const io = socketIo(server, {
  cors: {
    origin: CORS_ORIGINS,
    methods: ["GET", "POST"]
  },
  transports: ['websocket']
});

// Store connected users (no persistent storage)
const connectedUsers = new Map();
const userSockets = new Map();

// Middleware for rate limiting
io.use(async (socket, next) => {
  try {
    await rateLimiter.consume(socket.handshake.address);
    next();
  } catch (rejRes) {
    console.log(`Rate limit exceeded for ${socket.handshake.address}`);
    next(new Error('Rate limit exceeded'));
  }
});

io.on('connection', (socket) => {
  console.log(`Socket connected: ${socket.id}`);

  // Handle user registration
  socket.on('register', (data) => {
    const { userId } = data;
    
    if (!userId || typeof userId !== 'string' || userId.length > 50) {
      socket.emit('error', 'Invalid user ID');
      return;
    }

    // Check if user is already connected
    if (connectedUsers.has(userId)) {
      // Disconnect previous connection
      const oldSocket = userSockets.get(userId);
      if (oldSocket && oldSocket !== socket) {
        oldSocket.disconnect();
      }
    }

    // Register user
    connectedUsers.set(userId, {
      socketId: socket.id,
      connectedAt: new Date(),
      lastSeen: new Date()
    });
    userSockets.set(userId, socket);
    socket.userId = userId;

    console.log(`User registered: ${userId}`);

    // Notify other users about new connection
    socket.broadcast.emit('peer-connected', { peerId: userId });

    // Send list of online users to the new user
    const onlineUsers = Array.from(connectedUsers.keys()).filter(id => id !== userId);
    socket.emit('user-list', { users: onlineUsers });
  });

  // Handle WebRTC offer
  socket.on('offer', (data) => {
    const { to, from, offer } = data;
    
    if (!to || !from || !offer) {
      socket.emit('error', 'Invalid offer data');
      return;
    }

    const targetSocket = userSockets.get(to);
    if (targetSocket) {
      targetSocket.emit('offer', { from, offer });
      console.log(`Offer relayed from ${from} to ${to}`);
    } else {
      socket.emit('error', `User ${to} not found`);
    }
  });

  // Handle WebRTC answer
  socket.on('answer', (data) => {
    const { to, from, answer } = data;
    
    if (!to || !from || !answer) {
      socket.emit('error', 'Invalid answer data');
      return;
    }

    const targetSocket = userSockets.get(to);
    if (targetSocket) {
      targetSocket.emit('answer', { from, answer });
      console.log(`Answer relayed from ${from} to ${to}`);
    } else {
      socket.emit('error', `User ${to} not found`);
    }
  });

  // Handle ICE candidates
  socket.on('ice-candidate', (data) => {
    const { to, from, candidate } = data;
    
    if (!to || !from || !candidate) {
      socket.emit('error', 'Invalid ICE candidate data');
      return;
    }

    const targetSocket = userSockets.get(to);
    if (targetSocket) {
      targetSocket.emit('ice-candidate', { from, candidate });
      console.log(`ICE candidate relayed from ${from} to ${to}`);
    } else {
      socket.emit('error', `User ${to} not found`);
    }
  });

  // Handle custom signaling messages
  socket.on('custom-message', (data) => {
    const { to, from, message } = data;
    
    if (!to || !from || !message) {
      socket.emit('error', 'Invalid custom message data');
      return;
    }

    const targetSocket = userSockets.get(to);
    if (targetSocket) {
      targetSocket.emit('custom-message', { from, message });
      console.log(`Custom message relayed from ${from} to ${to}`);
    } else {
      socket.emit('error', `User ${to} not found`);
    }
  });

  // Handle request for user list
  socket.on('get-users', () => {
    const onlineUsers = Array.from(connectedUsers.keys()).filter(id => id !== socket.userId);
    socket.emit('user-list', { users: onlineUsers });
  });

  // Handle heartbeat/ping
  socket.on('ping', () => {
    if (socket.userId && connectedUsers.has(socket.userId)) {
      const userData = connectedUsers.get(socket.userId);
      userData.lastSeen = new Date();
      connectedUsers.set(socket.userId, userData);
    }
    socket.emit('pong');
  });

  // Handle disconnection
  socket.on('disconnect', (reason) => {
    console.log(`Socket disconnected: ${socket.id}, reason: ${reason}`);
    
    if (socket.userId) {
      connectedUsers.delete(socket.userId);
      userSockets.delete(socket.userId);
      
      // Notify other users about disconnection
      socket.broadcast.emit('peer-disconnected', { peerId: socket.userId });
      
      console.log(`User disconnected: ${socket.userId}`);
    }
  });

  // Handle errors
  socket.on('error', (error) => {
    console.error(`Socket error for ${socket.id}:`, error);
  });
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    connectedUsers: connectedUsers.size,
    uptime: process.uptime()
  });
});

// Stats endpoint (for monitoring)
app.get('/stats', (req, res) => {
  res.json({
    connectedUsers: connectedUsers.size,
    uptime: process.uptime(),
    memory: process.memoryUsage(),
    timestamp: new Date().toISOString()
  });
});

// Root endpoint
app.get('/', (req, res) => {
  res.json({
    name: 'Oodaa Signaling Server',
    version: '1.0.0',
    description: 'WebRTC signaling server for peer-to-peer messaging',
    endpoints: {
      health: '/health',
      stats: '/stats'
    }
  });
});

// Cleanup inactive users every 5 minutes
setInterval(() => {
  const now = new Date();
  const timeout = 5 * 60 * 1000; // 5 minutes
  
  for (const [userId, userData] of connectedUsers.entries()) {
    if (now - userData.lastSeen > timeout) {
      console.log(`Cleaning up inactive user: ${userId}`);
      
      const socket = userSockets.get(userId);
      if (socket) {
        socket.disconnect();
      }
      
      connectedUsers.delete(userId);
      userSockets.delete(userId);
    }
  }
}, 5 * 60 * 1000);

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM received, shutting down gracefully');
  server.close(() => {
    console.log('Server closed');
    process.exit(0);
  });
});

process.on('SIGINT', () => {
  console.log('SIGINT received, shutting down gracefully');
  server.close(() => {
    console.log('Server closed');
    process.exit(0);
  });
});

server.listen(PORT, () => {
  console.log(`Oodaa Signaling Server running on port ${PORT}`);
  console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
  console.log(`CORS origins: ${CORS_ORIGINS.join(', ')}`);
});

module.exports = { app, server, io };
