import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter/foundation.dart';

class WebRTCManager extends ChangeNotifier {
  // Server configuration - update with your computer's IP address
  static const String _serverHost = '192.168.1.100'; // Update this IP!
  static const String _serverPort = '3002';
  static String get signalingServerUrl => 'ws://$_serverHost:$_serverPort';

  WebSocketChannel? _channel;
  String? _clientId;
  String? _currentUserId;
  bool _isConnected = false;
  Timer? _keepAliveTimer;

  final Map<String, bool> _onlineUsers = {};
  final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();
  
  // Getters
  bool get isConnected => _isConnected;
  String? get currentUserId => _currentUserId;
  Map<String, bool> get onlineUsers => Map.from(_onlineUsers);
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  
  // Connect to signaling server
  Future<bool> connect() async {
    try {
      print('🌐 Connecting to signaling server at $signalingServerUrl...');

      _channel = WebSocketChannel.connect(Uri.parse(signalingServerUrl));

      // Set up a completer to wait for connection confirmation
      final connectionCompleter = Completer<bool>();
      bool connectionConfirmed = false;

      // Listen for messages
      _channel!.stream.listen(
        (data) {
          _handleMessage(data);

          // Check if this is the connection confirmation
          if (!connectionConfirmed) {
            try {
              final message = jsonDecode(data.toString());
              if (message['type'] == 'connected') {
                connectionConfirmed = true;
                connectionCompleter.complete(true);
              }
            } catch (e) {
              // Ignore parsing errors during connection
            }
          }
        },
        onError: (error) {
          print('❌ WebSocket error: $error');
          _handleDisconnection();
          if (!connectionCompleter.isCompleted) {
            connectionCompleter.complete(false);
          }
        },
        onDone: () {
          print('🔌 WebSocket connection closed');
          _handleDisconnection();
          if (!connectionCompleter.isCompleted) {
            connectionCompleter.complete(false);
          }
        },
      );

      // Wait for connection confirmation with timeout
      final connected = await connectionCompleter.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          print('⏰ Connection timeout');
          return false;
        },
      );

      if (connected) {
        print('✅ Connected to signaling server');
        _isConnected = true;
        _startKeepAlive();
        notifyListeners();
        return true;
      } else {
        print('❌ Failed to receive connection confirmation');
        _isConnected = false;
        notifyListeners();
        return false;
      }

    } catch (error) {
      print('❌ Failed to connect to signaling server: $error');
      _isConnected = false;
      notifyListeners();
      return false;
    }
  }
  
  // Register user with signaling server
  Future<bool> registerUser(String userId, Map<String, dynamic> userInfo) async {
    if (!_isConnected || _channel == null) {
      print('❌ Not connected to signaling server');
      return false;
    }
    
    try {
      _currentUserId = userId;
      
      final message = {
        'type': 'register',
        'userId': userId,
        'userInfo': userInfo,
      };
      
      _channel!.sink.add(jsonEncode(message));
      print('📝 Registered user: $userId');
      return true;
      
    } catch (error) {
      print('❌ Failed to register user: $error');
      return false;
    }
  }
  
  // Send message to another user
  Future<bool> sendMessage(String targetUserId, Map<String, dynamic> messageData) async {
    if (!_isConnected || _channel == null) {
      print('❌ Not connected to signaling server');
      return false;
    }
    
    try {
      final message = {
        'type': 'message',
        'targetUserId': targetUserId,
        'messageData': messageData,
      };
      
      _channel!.sink.add(jsonEncode(message));
      print('📤 Sent message to $targetUserId');
      return true;
      
    } catch (error) {
      print('❌ Failed to send message: $error');
      return false;
    }
  }
  
  // Send contact request
  Future<bool> sendContactRequest(String targetUserId, Map<String, dynamic> requestData) async {
    if (!_isConnected || _channel == null) {
      print('❌ Not connected to signaling server');
      return false;
    }

    try {
      final message = {
        'type': 'contact-request',
        'targetUserId': targetUserId,
        'requestData': requestData,
      };

      _channel!.sink.add(jsonEncode(message));
      print('🤝 Sent contact request to $targetUserId');
      return true;

    } catch (error) {
      print('❌ Failed to send contact request: $error');
      return false;
    }
  }

  // Send contact acceptance notification
  Future<bool> sendContactAccepted(String targetUserId, Map<String, dynamic> accepterInfo) async {
    if (!_isConnected || _channel == null) {
      print('❌ Not connected to signaling server');
      return false;
    }

    try {
      final message = {
        'type': 'contact-accepted',
        'targetUserId': targetUserId,
        'accepterInfo': accepterInfo,
      };

      _channel!.sink.add(jsonEncode(message));
      print('✅ Sent contact acceptance notification to $targetUserId');
      return true;

    } catch (error) {
      print('❌ Failed to send contact acceptance: $error');
      return false;
    }
  }
  
  // Get list of online users
  void requestOnlineUsers() {
    if (!_isConnected || _channel == null) return;
    
    final message = {'type': 'get-online-users'};
    _channel!.sink.add(jsonEncode(message));
  }
  
  // Handle incoming messages from signaling server
  void _handleMessage(dynamic data) {
    try {
      print('📨 Raw message received: $data');
      final message = jsonDecode(data.toString());
      print('📨 Parsed message: ${message['type']}');

      switch (message['type']) {
        case 'connected':
          _clientId = message['clientId'];
          print('🆔 Client ID: $_clientId');
          break;

        case 'registered':
          print('✅ Registration confirmed');
          _updateOnlineUsers(message['onlineUsers'] ?? []);
          break;

        case 'user-status':
          _handleUserStatus(message);
          break;

        case 'online-users':
          _updateOnlineUsers(message['users'] ?? []);
          break;

        case 'message':
          print('📥 Handling incoming message');
          _handleIncomingMessage(message);
          break;

        case 'contact-request':
          print('🤝 Handling contact request');
          _handleContactRequest(message);
          break;

        case 'contact-accepted':
          print('✅ Handling contact acceptance');
          _handleContactAccepted(message);
          break;

        case 'pong':
          print('🏓 Received pong response');
          break;

        case 'error':
          print('❌ Server error: ${message['message']}');
          break;

        default:
          print('❓ Unknown message type: ${message['type']}');
      }

    } catch (error) {
      print('❌ Error handling message: $error');
      print('❌ Raw data that caused error: $data');
    }
  }
  
  void _handleUserStatus(Map<String, dynamic> message) {
    final userId = message['userId'];
    final isOnline = message['isOnline'] ?? false;
    
    _onlineUsers[userId] = isOnline;
    
    print('👤 User $userId is ${isOnline ? 'online' : 'offline'}');
    notifyListeners();
  }
  
  void _updateOnlineUsers(List<dynamic> users) {
    _onlineUsers.clear();
    
    for (final user in users) {
      if (user['userId'] != _currentUserId) {
        _onlineUsers[user['userId']] = true;
      }
    }
    
    print('👥 Online users updated: ${_onlineUsers.length}');
    notifyListeners();
  }
  
  void _handleIncomingMessage(Map<String, dynamic> message) {
    try {
      final fromUserId = message['fromUserId'];
      final messageData = message['messageData'];

      print('📥 Message from $fromUserId: ${messageData['text']}');

      // Emit message to listeners
      _messageController.add({
        'type': 'incoming_message',
        'fromUserId': fromUserId,
        'messageData': messageData,
      });

      print('✅ Message emitted to listeners');
    } catch (error) {
      print('❌ Error handling incoming message: $error');
    }
  }

  void _handleContactRequest(Map<String, dynamic> message) {
    try {
      final fromUserId = message['fromUserId'];
      final fromUserInfo = message['fromUserInfo'];
      final requestData = message['requestData'];

      print('🤝 Contact request from $fromUserId');

      // Emit contact request to listeners
      _messageController.add({
        'type': 'contact_request',
        'fromUserId': fromUserId,
        'fromUserInfo': fromUserInfo,
        'requestData': requestData,
      });

      print('✅ Contact request emitted to listeners');
    } catch (error) {
      print('❌ Error handling contact request: $error');
    }
  }

  void _handleContactAccepted(Map<String, dynamic> message) {
    try {
      final fromUserId = message['fromUserId'];
      final fromUserInfo = message['fromUserInfo'];
      final accepterInfo = message['accepterInfo'];

      print('✅ Contact acceptance from $fromUserId');

      // Emit contact acceptance to listeners
      _messageController.add({
        'type': 'contact_accepted',
        'fromUserId': fromUserId,
        'fromUserInfo': fromUserInfo,
        'accepterInfo': accepterInfo,
      });

      print('✅ Contact acceptance emitted to listeners');
    } catch (error) {
      print('❌ Error handling contact acceptance: $error');
    }
  }
  
  // Start keepalive ping
  void _startKeepAlive() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_isConnected && _channel != null) {
        try {
          _channel!.sink.add(jsonEncode({'type': 'ping'}));
          print('📡 Sent keepalive ping');
        } catch (e) {
          print('❌ Failed to send keepalive: $e');
          _handleDisconnection();
        }
      }
    });
  }

  // Handle disconnection
  void _handleDisconnection() {
    print('🔌 Handling disconnection...');
    _isConnected = false;
    _keepAliveTimer?.cancel();
    notifyListeners();

    // Attempt to reconnect after 2 seconds, then retry with exponential backoff
    _attemptReconnect(1);
  }

  void _attemptReconnect(int attempt) {
    final delay = Duration(seconds: (attempt * 2).clamp(2, 30)); // 2s, 4s, 6s... max 30s

    Timer(delay, () async {
      if (!_isConnected && _currentUserId != null) {
        print('🔄 Reconnection attempt $attempt...');

        final connected = await connect();
        if (connected && _currentUserId != null) {
          // Re-register user after reconnection
          final registered = await registerUser(_currentUserId!, {
            'name': 'User', // You might want to store this
            'timestamp': DateTime.now().toIso8601String(),
          });

          if (registered) {
            print('✅ Successfully reconnected and re-registered');
            return;
          }
        }

        // If reconnection failed, try again
        if (attempt < 10) { // Max 10 attempts
          _attemptReconnect(attempt + 1);
        } else {
          print('❌ Max reconnection attempts reached');
        }
      }
    });
  }

  // Disconnect from signaling server
  void disconnect() {
    _keepAliveTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
    _isConnected = false;
    _currentUserId = null;
    _clientId = null;
    _onlineUsers.clear();

    print('🔌 Disconnected from signaling server');
    notifyListeners();
  }

  @override
  void dispose() {
    _keepAliveTimer?.cancel();
    disconnect();
    _messageController.close();
    super.dispose();
  }
}
