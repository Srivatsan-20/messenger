import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:convert';
import 'dart:async';
import 'networking/webrtc_manager.dart';

void main() {
  print('DEBUG: Starting Oodaa Messenger');
  runApp(const OodaaMessengerApp());
}

class OodaaMessengerApp extends StatelessWidget {
  const OodaaMessengerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Oodaa Messenger',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const SimpleTestScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class SimpleTestScreen extends StatefulWidget {
  const SimpleTestScreen({super.key});

  @override
  State<SimpleTestScreen> createState() => _SimpleTestScreenState();
}

class _SimpleTestScreenState extends State<SimpleTestScreen> {
  String? _userIdentity;
  final _nameController = TextEditingController();
  final List<Map<String, String>> _contacts = [];
  final Map<String, List<Map<String, dynamic>>> _conversations = {};
  final StreamController<String> _messageStreamController = StreamController<String>.broadcast();
  final WebRTCManager _webrtcManager = WebRTCManager();
  bool _isConnectedToServer = false;

  void _createIdentity() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a name')),
      );
      return;
    }

    // Generate a simple user ID
    final userId = '${name.toLowerCase()}${DateTime.now().millisecondsSinceEpoch % 1000}';
    
    setState(() {
      _userIdentity = userId;
    });

    print('DEBUG: Created identity: $userId');
    
    // Connect to signaling server and register user
    await _connectToSignalingServer(userId, name);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Identity created: $userId')),
    );
  }

  Future<void> _connectToSignalingServer(String userId, String name) async {
    try {
      print('Connecting to signaling server...');
      
      final connected = await _webrtcManager.connect();
      if (!connected) {
        throw Exception('Failed to connect to signaling server');
      }
      
      final registered = await _webrtcManager.registerUser(userId, {
        'name': name,
        'timestamp': DateTime.now().toIso8601String(),
      });
      
      if (!registered) {
        throw Exception('Failed to register user');
      }
      
      // Listen for incoming messages
      _webrtcManager.messageStream.listen(_handleIncomingNetworkMessage);
      
      setState(() {
        _isConnectedToServer = true;
      });
      
      print('Connected and registered successfully');
      
    } catch (error) {
      print('Connection error: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connection failed: $error')),
      );
    }
  }

  void _handleIncomingNetworkMessage(Map<String, dynamic> data) {
    try {
      print('Handling network message: ${data['type']}');
      switch (data['type']) {
        case 'incoming_message':
          print('Processing incoming message');
          _handleIncomingMessage(data);
          break;
        case 'contact_request':
          print('Processing contact request');
          _handleContactRequest(data);
          break;
        default:
          print('Unknown network message type: ${data['type']}');
      }
    } catch (error) {
      print('Error handling network message: $error');
    }
  }

  void _handleIncomingMessage(Map<String, dynamic> data) {
    try {
      print('Processing incoming message data: $data');
      final fromUserId = data['fromUserId'];
      final messageData = data['messageData'];
      
      print('Message from $fromUserId: ${messageData['text']}');
      
      setState(() {
        if (!_conversations.containsKey(fromUserId)) {
          _conversations[fromUserId] = [];
        }
        
        _conversations[fromUserId]!.add({
          'id': messageData['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
          'text': messageData['text'],
          'sender': fromUserId,
          'timestamp': messageData['timestamp'] ?? DateTime.now().toIso8601String(),
          'isFromMe': false,
        });
      });
      
      // Notify chat screen if open
      _messageStreamController.add(fromUserId);
      
      print('Message processed and added to conversation');
    } catch (error) {
      print('Error processing incoming message: $error');
    }
  }

  void _handleContactRequest(Map<String, dynamic> data) {
    final fromUserId = data['fromUserId'];
    final fromUserInfo = data['fromUserInfo'];
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Contact Request'),
        content: Text('${fromUserInfo['name']} wants to add you as a contact.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Decline'),
          ),
          TextButton(
            onPressed: () {
              _acceptContactRequest(fromUserId, fromUserInfo);
              Navigator.pop(context);
            },
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }

  void _acceptContactRequest(String userId, Map<String, dynamic> userInfo) {
    setState(() {
      _contacts.add({
        'name': userInfo['name'] ?? userId,
        'id': userId,
        'addedAt': DateTime.now().toString(),
      });
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added ${userInfo['name']} as contact')),
    );
  }

  void _showQRCode() {
    // Create QR data with contact information
    final qrData = jsonEncode({
      'type': 'oodaa_contact',
      'userId': _userIdentity,
      'name': _nameController.text.trim(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Your QR Code'),
        content: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: QrImageView(
                  data: qrData,
                  version: QrVersions.auto,
                  size: 200.0,
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Scan this code to add me as a contact!',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'ID: $_userIdentity',
                style: const TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              // Copy QR data to clipboard (simplified)
              print('QR Data: $qrData');
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('QR data logged to console')),
              );
            },
            child: const Text('Copy Data'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Oodaa Messenger'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.message,
                size: 100,
                color: Colors.blue,
              ),
              const SizedBox(height: 20),
              const Text(
                'Welcome to Oodaa Messenger!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                '100% Private P2P Messaging',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 40),
              
              if (_userIdentity == null) ...[
                // Setup screen
                const Text(
                  'Create Your Identity',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Your Name',
                    border: OutlineInputBorder(),
                    hintText: 'Enter your name',
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _createIdentity,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  ),
                  child: const Text('Create My Identity'),
                ),
              ] else ...[
                // Main screen continues...
                Text(
                  'Welcome $_userIdentity!',
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _isConnectedToServer ? Colors.green : Colors.orange,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _isConnectedToServer ? 'Connected to Server' : 'Offline Mode',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // Add more UI elements here...
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _messageStreamController.close();
    _webrtcManager.dispose();
    super.dispose();
  }
}
