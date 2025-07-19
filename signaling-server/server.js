const WebSocket = require('ws');
const { v4: uuidv4 } = require('uuid');
const http = require('http');

const PORT = process.env.PORT || 3002;

// Store connected clients
const clients = new Map();
const userSessions = new Map(); // userId -> clientId mapping

// Create HTTP server for Railway health checks
const server = http.createServer((req, res) => {
  if (req.url === '/health' || req.url === '/') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
      status: 'healthy',
      service: 'Oodaa Signaling Server',
      clients: clients.size,
      users: userSessions.size,
      timestamp: new Date().toISOString()
    }));
  } else {
    res.writeHead(404, { 'Content-Type': 'text/plain' });
    res.end('Not Found');
  }
});

// Create WebSocket server attached to HTTP server
const wss = new WebSocket.Server({
  server,
  cors: {
    origin: "*",
    methods: ["GET", "POST"]
  }
});

// Start the server
server.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 Oodaa Signaling Server running on port ${PORT}`);
  console.log(`🌐 Health check available at http://localhost:${PORT}/health`);
});

wss.on('connection', (ws) => {
  const clientId = uuidv4();
  console.log(`📱 New client connected: ${clientId}`);
  
  // Store client connection
  clients.set(clientId, {
    ws,
    userId: null,
    isOnline: false
  });

  // Send welcome message
  ws.send(JSON.stringify({
    type: 'connected',
    clientId,
    message: 'Connected to Oodaa signaling server'
  }));

  ws.on('message', (data) => {
    try {
      const message = JSON.parse(data.toString());
      handleMessage(clientId, message);
    } catch (error) {
      console.error('❌ Error parsing message:', error);
      ws.send(JSON.stringify({
        type: 'error',
        message: 'Invalid message format'
      }));
    }
  });

  ws.on('close', () => {
    console.log(`📱 Client disconnected: ${clientId}`);
    const client = clients.get(clientId);
    
    if (client && client.userId) {
      // Notify contacts that user went offline
      broadcastUserStatus(client.userId, false);
      userSessions.delete(client.userId);
    }
    
    clients.delete(clientId);
  });

  ws.on('error', (error) => {
    console.error('❌ WebSocket error:', error);
  });
});

function handleMessage(clientId, message) {
  const client = clients.get(clientId);
  if (!client) return;

  console.log(`📨 Message from ${clientId}:`, message.type);

  switch (message.type) {
    case 'register':
      handleRegister(clientId, message);
      break;
    
    case 'offer':
    case 'answer':
    case 'ice-candidate':
      handleWebRTCSignaling(clientId, message);
      break;
    
    case 'message':
      handleDirectMessage(clientId, message);
      break;
    
    case 'contact-request':
      handleContactRequest(clientId, message);
      break;

    case 'contact-accepted':
      handleContactAccepted(clientId, message);
      break;

    case 'get-online-users':
      handleGetOnlineUsers(clientId);
      break;

    case 'ping':
      handlePing(clientId);
      break;

    default:
      console.log(`❓ Unknown message type: ${message.type}`);
  }
}

function handleRegister(clientId, message) {
  const client = clients.get(clientId);
  const { userId, userInfo } = message;
  
  // Update client info
  client.userId = userId;
  client.userInfo = userInfo;
  client.isOnline = true;
  
  // Map user to client
  userSessions.set(userId, clientId);
  
  console.log(`✅ User registered: ${userId}`);
  
  // Send confirmation
  client.ws.send(JSON.stringify({
    type: 'registered',
    userId,
    onlineUsers: getOnlineUsersList()
  }));
  
  // Broadcast to all clients that this user is online
  broadcastUserStatus(userId, true, userInfo);
}

function handleWebRTCSignaling(clientId, message) {
  const { targetUserId, offer, answer, candidate } = message;
  const targetClientId = userSessions.get(targetUserId);
  
  if (!targetClientId) {
    const client = clients.get(clientId);
    client.ws.send(JSON.stringify({
      type: 'error',
      message: `User ${targetUserId} is not online`
    }));
    return;
  }
  
  const targetClient = clients.get(targetClientId);
  if (targetClient) {
    const senderClient = clients.get(clientId);
    
    targetClient.ws.send(JSON.stringify({
      type: message.type,
      fromUserId: senderClient.userId,
      offer,
      answer,
      candidate
    }));
  }
}

function handleDirectMessage(clientId, message) {
  const { targetUserId, messageData } = message;
  const targetClientId = userSessions.get(targetUserId);
  
  if (!targetClientId) {
    console.log(`📭 User ${targetUserId} is offline, message queued`);
    // TODO: Implement message queuing for offline users
    return;
  }
  
  const targetClient = clients.get(targetClientId);
  const senderClient = clients.get(clientId);
  
  if (targetClient && senderClient) {
    targetClient.ws.send(JSON.stringify({
      type: 'message',
      fromUserId: senderClient.userId,
      messageData
    }));
  }
}

function handleContactRequest(clientId, message) {
  const { targetUserId, requestData } = message;
  const targetClientId = userSessions.get(targetUserId);

  if (!targetClientId) {
    const client = clients.get(clientId);
    client.ws.send(JSON.stringify({
      type: 'error',
      message: `User ${targetUserId} is not online`
    }));
    return;
  }

  const targetClient = clients.get(targetClientId);
  const senderClient = clients.get(clientId);

  if (targetClient && senderClient) {
    targetClient.ws.send(JSON.stringify({
      type: 'contact-request',
      fromUserId: senderClient.userId,
      fromUserInfo: senderClient.userInfo,
      requestData
    }));
  }
}

function handleContactAccepted(clientId, message) {
  const { targetUserId, accepterInfo } = message;
  const targetClientId = userSessions.get(targetUserId);

  if (!targetClientId) {
    console.log(`📭 User ${targetUserId} is offline, cannot notify of contact acceptance`);
    return;
  }

  const targetClient = clients.get(targetClientId);
  const accepterClient = clients.get(clientId);

  if (targetClient && accepterClient) {
    console.log(`✅ Notifying ${targetUserId} that ${accepterClient.userId} accepted contact request`);
    targetClient.ws.send(JSON.stringify({
      type: 'contact-accepted',
      fromUserId: accepterClient.userId,
      fromUserInfo: accepterClient.userInfo,
      accepterInfo
    }));
  }
}

function handleGetOnlineUsers(clientId) {
  const client = clients.get(clientId);

  client.ws.send(JSON.stringify({
    type: 'online-users',
    users: getOnlineUsersList()
  }));
}

function handlePing(clientId) {
  const client = clients.get(clientId);
  if (client) {
    // Send pong response
    client.ws.send(JSON.stringify({
      type: 'pong',
      timestamp: Date.now()
    }));
  }
}

function broadcastUserStatus(userId, isOnline, userInfo = null) {
  const statusMessage = {
    type: 'user-status',
    userId,
    isOnline,
    userInfo
  };
  
  // Broadcast to all connected clients except the user themselves
  clients.forEach((client, clientId) => {
    if (client.userId !== userId && client.isOnline) {
      client.ws.send(JSON.stringify(statusMessage));
    }
  });
}

function getOnlineUsersList() {
  const onlineUsers = [];
  
  clients.forEach((client) => {
    if (client.isOnline && client.userId) {
      onlineUsers.push({
        userId: client.userId,
        userInfo: client.userInfo
      });
    }
  });
  
  return onlineUsers;
}

// Health check endpoint for monitoring
const http = require('http');
const server = http.createServer((req, res) => {
  if (req.url === '/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
      status: 'healthy',
      connectedClients: clients.size,
      onlineUsers: userSessions.size,
      uptime: process.uptime()
    }));
  } else {
    res.writeHead(404);
    res.end('Not found');
  }
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('🛑 Shutting down signaling server...');
  wss.close(() => {
    server.close(() => {
      process.exit(0);
    });
  });
});

console.log('🌐 Health check available at http://localhost:' + PORT + '/health');
