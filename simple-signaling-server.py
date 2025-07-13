#!/usr/bin/env python3
"""
Simple WebSocket signaling server for Oodaa Messenger
Requires: pip install websockets
"""

import asyncio
import websockets
import json
import uuid
from datetime import datetime

# Store connected clients
clients = {}
user_sessions = {}

async def handle_client(websocket, path):
    client_id = str(uuid.uuid4())
    print(f"📱 New client connected: {client_id}")
    
    # Store client
    clients[client_id] = {
        'websocket': websocket,
        'user_id': None,
        'user_info': None,
        'is_online': False
    }
    
    # Send welcome message
    await websocket.send(json.dumps({
        'type': 'connected',
        'clientId': client_id,
        'message': 'Connected to Oodaa signaling server'
    }))
    
    try:
        async for message in websocket:
            try:
                data = json.loads(message)
                await handle_message(client_id, data)
            except json.JSONDecodeError:
                await websocket.send(json.dumps({
                    'type': 'error',
                    'message': 'Invalid JSON format'
                }))
            except Exception as e:
                print(f"❌ Error handling message: {e}")
                
    except websockets.exceptions.ConnectionClosed:
        print(f"📱 Client disconnected: {client_id}")
    except Exception as e:
        print(f"❌ Connection error: {e}")
    finally:
        # Cleanup
        client = clients.get(client_id)
        if client and client['user_id']:
            await broadcast_user_status(client['user_id'], False)
            if client['user_id'] in user_sessions:
                del user_sessions[client['user_id']]
        
        if client_id in clients:
            del clients[client_id]

async def handle_message(client_id, message):
    client = clients.get(client_id)
    if not client:
        return
    
    message_type = message.get('type')
    print(f"📨 Message from {client_id}: {message_type}")
    
    if message_type == 'register':
        await handle_register(client_id, message)
    elif message_type in ['offer', 'answer', 'ice-candidate']:
        await handle_webrtc_signaling(client_id, message)
    elif message_type == 'message':
        await handle_direct_message(client_id, message)
    elif message_type == 'contact-request':
        await handle_contact_request(client_id, message)
    elif message_type == 'get-online-users':
        await handle_get_online_users(client_id)
    else:
        print(f"❓ Unknown message type: {message_type}")

async def handle_register(client_id, message):
    client = clients[client_id]
    user_id = message.get('userId')
    user_info = message.get('userInfo')
    
    # Update client info
    client['user_id'] = user_id
    client['user_info'] = user_info
    client['is_online'] = True
    
    # Map user to client
    user_sessions[user_id] = client_id
    
    print(f"✅ User registered: {user_id}")
    
    # Send confirmation
    await client['websocket'].send(json.dumps({
        'type': 'registered',
        'userId': user_id,
        'onlineUsers': get_online_users_list()
    }))
    
    # Broadcast user status
    await broadcast_user_status(user_id, True, user_info)

async def handle_direct_message(client_id, message):
    target_user_id = message.get('targetUserId')
    message_data = message.get('messageData')
    
    target_client_id = user_sessions.get(target_user_id)
    if not target_client_id:
        print(f"📭 User {target_user_id} is offline")
        return
    
    target_client = clients.get(target_client_id)
    sender_client = clients.get(client_id)
    
    if target_client and sender_client:
        await target_client['websocket'].send(json.dumps({
            'type': 'message',
            'fromUserId': sender_client['user_id'],
            'messageData': message_data
        }))

async def handle_contact_request(client_id, message):
    target_user_id = message.get('targetUserId')
    request_data = message.get('requestData')
    
    target_client_id = user_sessions.get(target_user_id)
    if not target_client_id:
        client = clients[client_id]
        await client['websocket'].send(json.dumps({
            'type': 'error',
            'message': f'User {target_user_id} is not online'
        }))
        return
    
    target_client = clients.get(target_client_id)
    sender_client = clients.get(client_id)
    
    if target_client and sender_client:
        await target_client['websocket'].send(json.dumps({
            'type': 'contact-request',
            'fromUserId': sender_client['user_id'],
            'fromUserInfo': sender_client['user_info'],
            'requestData': request_data
        }))

async def handle_get_online_users(client_id):
    client = clients[client_id]
    await client['websocket'].send(json.dumps({
        'type': 'online-users',
        'users': get_online_users_list()
    }))

async def broadcast_user_status(user_id, is_online, user_info=None):
    status_message = {
        'type': 'user-status',
        'userId': user_id,
        'isOnline': is_online,
        'userInfo': user_info
    }
    
    # Broadcast to all connected clients except the user themselves
    for client_id, client in clients.items():
        if client['user_id'] != user_id and client['is_online']:
            try:
                await client['websocket'].send(json.dumps(status_message))
            except:
                pass  # Client might be disconnected

def get_online_users_list():
    online_users = []
    for client in clients.values():
        if client['is_online'] and client['user_id']:
            online_users.append({
                'userId': client['user_id'],
                'userInfo': client['user_info']
            })
    return online_users

async def handle_webrtc_signaling(client_id, message):
    # Placeholder for WebRTC signaling
    target_user_id = message.get('targetUserId')
    target_client_id = user_sessions.get(target_user_id)
    
    if target_client_id:
        target_client = clients.get(target_client_id)
        sender_client = clients.get(client_id)
        
        if target_client and sender_client:
            forward_message = message.copy()
            forward_message['fromUserId'] = sender_client['user_id']
            await target_client['websocket'].send(json.dumps(forward_message))

async def main():
    port = 3002
    print(f"🚀 Oodaa Signaling Server starting on port {port}")
    
    # Start WebSocket server
    server = await websockets.serve(handle_client, "localhost", port)
    print(f"🌐 WebSocket server running on ws://localhost:{port}")
    print(f"🌐 Health check: Server is running with {len(clients)} clients")
    
    # Keep server running
    await server.wait_closed()

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\n🛑 Server stopped by user")
    except Exception as e:
        print(f"❌ Server error: {e}")
