import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:html' as html;
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
  String? _userName;
  final _nameController = TextEditingController();
  final List<Map<String, String>> _contacts = [];
  final Map<String, List<Map<String, dynamic>>> _conversations = {};
  final StreamController<String> _messageStreamController = StreamController<String>.broadcast();
  final WebRTCManager _webrtcManager = WebRTCManager();
  bool _isConnectedToServer = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSavedData();
  }

  // Load saved data from browser storage
  Future<void> _loadSavedData() async {
    try {
      print('Loading saved data...');

      // Load identity
      final savedUserId = html.window.localStorage['oodaa_user_id'];
      final savedUserName = html.window.localStorage['oodaa_user_name'];

      if (savedUserId != null && savedUserName != null) {
        setState(() {
          _userIdentity = savedUserId;
          _userName = savedUserName;
          _nameController.text = savedUserName;
        });

        print('Loaded saved identity: $savedUserId ($savedUserName)');

        // Auto-connect to server
        await _connectToSignalingServer(savedUserId, savedUserName);
      }

      // Load contacts
      final savedContactsJson = html.window.localStorage['oodaa_contacts'];
      if (savedContactsJson != null) {
        final List<dynamic> contactsList = jsonDecode(savedContactsJson);
        setState(() {
          _contacts.clear();
          _contacts.addAll(contactsList.map((c) => Map<String, String>.from(c)));
        });
        print('Loaded ${_contacts.length} saved contacts');
      }

      // Load conversations
      final savedConversationsJson = html.window.localStorage['oodaa_conversations'];
      if (savedConversationsJson != null) {
        final Map<String, dynamic> conversationsMap = jsonDecode(savedConversationsJson);
        setState(() {
          _conversations.clear();
          conversationsMap.forEach((key, value) {
            _conversations[key] = List<Map<String, dynamic>>.from(value);
          });
        });
        print('Loaded conversations for ${_conversations.length} contacts');
      }

    } catch (error) {
      print('Error loading saved data: $error');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Save data to browser storage
  void _saveData() {
    try {
      if (_userIdentity != null && _userName != null) {
        html.window.localStorage['oodaa_user_id'] = _userIdentity!;
        html.window.localStorage['oodaa_user_name'] = _userName!;
      }

      html.window.localStorage['oodaa_contacts'] = jsonEncode(_contacts);
      html.window.localStorage['oodaa_conversations'] = jsonEncode(_conversations);

      print('Data saved to browser storage');
    } catch (error) {
      print('Error saving data: $error');
    }
  }

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
      _userName = name;
    });

    print('DEBUG: Created identity: $userId');

    // Save to browser storage
    _saveData();

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
        case 'contact_accepted':
          print('Processing contact acceptance');
          _handleContactAccepted(data);
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

      // Save data
      _saveData();

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

  void _acceptContactRequest(String userId, Map<String, dynamic> userInfo) async {
    // Add to local contacts
    setState(() {
      _contacts.add({
        'name': userInfo['name'] ?? userId,
        'id': userId,
        'addedAt': DateTime.now().toString(),
      });
    });

    // Notify the requester that we accepted
    if (_isConnectedToServer) {
      await _webrtcManager.sendContactAccepted(userId, {
        'name': _nameController.text.trim(),
        'userId': _userIdentity!,
        'timestamp': DateTime.now().toIso8601String(),
      });
    }

    // Save data
    _saveData();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added ${userInfo['name']} as contact')),
    );
  }

  void _handleContactAccepted(Map<String, dynamic> data) {
    try {
      final fromUserId = data['fromUserId'];
      final fromUserInfo = data['fromUserInfo'];

      print('Contact acceptance from $fromUserId');

      // Add the accepter to our contacts list
      setState(() {
        // Check if contact already exists
        final existingIndex = _contacts.indexWhere((contact) => contact['id'] == fromUserId);
        if (existingIndex == -1) {
          _contacts.add({
            'name': fromUserInfo['name'] ?? fromUserId,
            'id': fromUserId,
            'addedAt': DateTime.now().toString(),
          });
        }
      });

      // Save data
      _saveData();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${fromUserInfo['name']} accepted your contact request!')),
      );

      print('Contact added to local list');
    } catch (error) {
      print('Error processing contact acceptance: $error');
    }
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

              if (_isLoading) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 20),
                const Text('Loading saved data...'),
              ] else if (_userIdentity == null) ...[
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
                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _showQRCode,
                      icon: const Icon(Icons.qr_code),
                      label: const Text('Show QR'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _simulateQRScan,
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text('Scan QR'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _showContacts,
                  icon: const Icon(Icons.contacts),
                  label: Text('Contacts (${_contacts.length})'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: _clearAllData,
                  child: const Text(
                    'Clear All Data & Start Fresh',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _simulateQRScan() {
    // Simulate scanning a QR code by showing a dialog to manually add a contact
    showDialog(
      context: context,
      builder: (context) {
        final nameController = TextEditingController();
        final idController = TextEditingController();

        return AlertDialog(
          title: const Text('Add Contact'),
          content: SizedBox(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Simulate scanning a QR code:'),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Contact Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: idController,
                  decoration: const InputDecoration(
                    labelText: 'Contact ID',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final id = idController.text.trim();

                if (name.isNotEmpty && id.isNotEmpty) {
                  Navigator.pop(context);

                  if (_isConnectedToServer) {
                    // Send real contact request
                    final success = await _webrtcManager.sendContactRequest(id, {
                      'requesterName': _nameController.text.trim(),
                      'requesterId': _userIdentity!,
                      'timestamp': DateTime.now().toIso8601String(),
                    });

                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Contact request sent to $name')),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Failed to send contact request')),
                      );
                    }
                  } else {
                    // Offline mode - add directly
                    setState(() {
                      _contacts.add({
                        'name': name,
                        'id': id,
                        'addedAt': DateTime.now().toString(),
                      });
                    });

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Added contact: $name (offline mode)')),
                    );
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill all fields')),
                  );
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _showContacts() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Contacts (${_contacts.length})'),
        content: SizedBox(
          width: 400,
          height: 300,
          child: _contacts.isEmpty
              ? const Center(
                  child: Text(
                    'No contacts yet.\nUse "Scan QR" to add contacts.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: _contacts.length,
                  itemBuilder: (context, index) {
                    final contact = _contacts[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue,
                        child: Text(
                          contact['name']![0].toUpperCase(),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(contact['name']!),
                      subtitle: Text('ID: ${contact['id']}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.chat, color: Colors.green),
                        onPressed: () {
                          Navigator.pop(context);
                          _openChat(contact);
                        },
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _openChat(Map<String, String> contact) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          contact: contact,
          currentUser: _userIdentity!,
          onSendMessage: (message) => _sendMessage(contact['id']!, message),
          getMessages: () => List<Map<String, dynamic>>.from(_conversations[contact['id']] ?? []),
          messageStream: _messageStreamController.stream,
        ),
      ),
    );
  }

  void _sendMessage(String contactId, String message) async {
    final messageId = DateTime.now().millisecondsSinceEpoch.toString();
    final timestamp = DateTime.now().toIso8601String();

    // Add to local conversation immediately
    setState(() {
      if (!_conversations.containsKey(contactId)) {
        _conversations[contactId] = [];
      }

      _conversations[contactId]!.add({
        'id': messageId,
        'text': message,
        'sender': _userIdentity!,
        'timestamp': timestamp,
        'isFromMe': true,
      });
    });

    // Save data
    _saveData();

    print('Sending message to $contactId: $message');

    // Send via WebRTC if connected
    if (_isConnectedToServer) {
      final success = await _webrtcManager.sendMessage(contactId, {
        'id': messageId,
        'text': message,
        'timestamp': timestamp,
      });

      if (!success) {
        print('Failed to send message via network');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send message')),
        );
      }
    } else {
      print('Not connected to server, message stored locally only');

      // Simulate auto-reply for offline testing
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          final reply = _generateAutoReply(message);
          print('Generating offline auto-reply: $reply');

          setState(() {
            _conversations[contactId]!.add({
              'id': (DateTime.now().millisecondsSinceEpoch + 1).toString(),
              'text': reply,
              'sender': contactId,
              'timestamp': DateTime.now().toIso8601String(),
              'isFromMe': false,
            });
          });

          // Notify any listening chat screens
          _messageStreamController.add(contactId);
        }
      });
    }
  }

  String _generateAutoReply(String message) {
    final replies = [
      'Thanks for your message!',
      'Got it!',
      'Interesting point!',
      'I agree with you.',
      'Let me think about that.',
      'That sounds good!',
      'Sure thing!',
      'Absolutely!',
    ];

    if (message.toLowerCase().contains('hello') || message.toLowerCase().contains('hi')) {
      return 'Hello there!';
    }
    if (message.toLowerCase().contains('how are you')) {
      return 'I\'m doing great, thanks for asking!';
    }
    if (message.toLowerCase().contains('?')) {
      return 'That\'s a good question!';
    }

    return replies[DateTime.now().millisecond % replies.length];
  }

  void _clearAllData() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data'),
        content: const Text('This will delete your identity, contacts, and messages. Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              // Clear browser storage
              html.window.localStorage.remove('oodaa_user_id');
              html.window.localStorage.remove('oodaa_user_name');
              html.window.localStorage.remove('oodaa_contacts');
              html.window.localStorage.remove('oodaa_conversations');

              // Clear app state
              setState(() {
                _userIdentity = null;
                _userName = null;
                _nameController.clear();
                _contacts.clear();
                _conversations.clear();
                _isConnectedToServer = false;
              });

              // Disconnect from server
              _webrtcManager.disconnect();

              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('All data cleared')),
              );
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
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

// Add the ChatScreen class here
class ChatScreen extends StatefulWidget {
  final Map<String, String> contact;
  final String currentUser;
  final Function(String) onSendMessage;
  final List<Map<String, dynamic>> Function() getMessages;
  final Stream<String> messageStream;

  const ChatScreen({
    super.key,
    required this.contact,
    required this.currentUser,
    required this.onSendMessage,
    required this.getMessages,
    required this.messageStream,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  late StreamSubscription<String> _messageSubscription;

  @override
  void initState() {
    super.initState();
    _messages = widget.getMessages();

    // Listen to message stream
    _messageSubscription = widget.messageStream.listen((contactId) {
      if (contactId == widget.contact['id']) {
        _onMessageUpdate();
      }
    });

    // Scroll to bottom when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });

    print('Chat screen initialized with ${_messages.length} messages');
  }

  @override
  void dispose() {
    _messageSubscription.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onMessageUpdate() {
    if (mounted) {
      final newMessages = widget.getMessages();

      setState(() {
        _messages = newMessages;
      });

      // Auto-scroll to bottom when new message arrives
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollToBottom();
      });
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _sendMessage() {
    final message = _messageController.text.trim();
    if (message.isNotEmpty) {
      widget.onSendMessage(message);
      _messageController.clear();

      // Update local messages immediately
      setState(() {
        _messages = widget.getMessages();
      });

      // Scroll to bottom after sending
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollToBottom();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.blue,
              radius: 18,
              child: Text(
                widget.contact['name']![0].toUpperCase(),
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.contact['name']!,
                  style: const TextStyle(fontSize: 16),
                ),
                Text(
                  'Online',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green.shade600,
                  ),
                ),
              ],
            ),
          ],
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? const Center(
                    child: Text(
                      'No messages yet.\nSend a message to start the conversation!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final isFromMe = message['isFromMe'] as bool;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          mainAxisAlignment: isFromMe
                              ? MainAxisAlignment.end
                              : MainAxisAlignment.start,
                          children: [
                            Container(
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.of(context).size.width * 0.7,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: isFromMe
                                    ? Colors.blue
                                    : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    message['text'],
                                    style: TextStyle(
                                      color: isFromMe ? Colors.white : Colors.black,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatTime(DateTime.parse(message['timestamp'])),
                                    style: TextStyle(
                                      color: isFromMe
                                          ? Colors.white70
                                          : Colors.grey.shade600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 12),
                FloatingActionButton(
                  onPressed: _sendMessage,
                  backgroundColor: Colors.blue,
                  mini: true,
                  child: const Icon(Icons.send, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}
