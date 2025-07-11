# Oodaa Signaling Server

A WebRTC signaling server for Oodaa Messenger that facilitates peer-to-peer connections without storing any messages or user data.

## Features

- **No Data Storage**: Server only facilitates initial peer discovery and WebRTC signaling
- **Rate Limiting**: Prevents abuse with configurable rate limits
- **Security**: Uses Helmet.js for security headers and CORS protection
- **Health Monitoring**: Built-in health check and stats endpoints
- **Auto Cleanup**: Automatically removes inactive users
- **Graceful Shutdown**: Handles SIGTERM and SIGINT signals properly

## Installation

```bash
cd signaling_server
npm install
```

## Configuration

Set the following environment variables:

```bash
# Server port (default: 3001)
PORT=3001

# CORS origins (comma-separated)
CORS_ORIGINS=http://localhost:3000,https://your-domain.com

# Node environment
NODE_ENV=production
```

## Running the Server

### Development
```bash
npm run dev
```

### Production
```bash
npm start
```

## API Endpoints

### Health Check
```
GET /health
```
Returns server status and basic metrics.

### Statistics
```
GET /stats
```
Returns detailed server statistics including connected users and memory usage.

## Socket.IO Events

### Client to Server

- `register` - Register user with userId
- `offer` - Send WebRTC offer to another user
- `answer` - Send WebRTC answer to another user
- `ice-candidate` - Send ICE candidate to another user
- `custom-message` - Send custom signaling message
- `get-users` - Request list of online users
- `ping` - Heartbeat to maintain connection

### Server to Client

- `peer-connected` - Notify when a peer comes online
- `peer-disconnected` - Notify when a peer goes offline
- `user-list` - List of currently online users
- `offer` - Receive WebRTC offer from another user
- `answer` - Receive WebRTC answer from another user
- `ice-candidate` - Receive ICE candidate from another user
- `custom-message` - Receive custom signaling message
- `error` - Error message
- `pong` - Response to ping

## Security Features

- Rate limiting (100 requests per minute per IP)
- CORS protection with configurable origins
- Helmet.js security headers
- Input validation for all events
- Automatic cleanup of inactive connections

## Deployment

### Docker (Recommended)

Create a `Dockerfile`:

```dockerfile
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
EXPOSE 3001
CMD ["npm", "start"]
```

Build and run:
```bash
docker build -t oodaa-signaling .
docker run -p 3001:3001 -e NODE_ENV=production oodaa-signaling
```

### Cloud Deployment

The server can be deployed to:
- Heroku
- Railway
- DigitalOcean App Platform
- AWS Elastic Beanstalk
- Google Cloud Run

## Monitoring

Monitor the server using:
- `/health` endpoint for basic health checks
- `/stats` endpoint for detailed metrics
- Server logs for connection events

## Privacy & Security

- **No Message Storage**: Server never stores or logs message content
- **No User Data**: Only temporary connection metadata is kept in memory
- **Automatic Cleanup**: All user data is removed when users disconnect
- **Rate Limiting**: Prevents abuse and DoS attacks
- **CORS Protection**: Restricts access to authorized origins only

## TODO Items for Production

1. **SSL/TLS**: Configure HTTPS with proper certificates
2. **Load Balancing**: Set up multiple server instances with Redis for scaling
3. **Monitoring**: Add proper logging and monitoring (e.g., Winston, Prometheus)
4. **Authentication**: Add optional authentication for private deployments
5. **Geolocation**: Add TURN servers for better connectivity across NATs
6. **Metrics**: Add detailed metrics collection and alerting

## License

MIT License - See LICENSE file for details.
