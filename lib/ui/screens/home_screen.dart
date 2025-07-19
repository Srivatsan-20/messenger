
import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:oodaa_messenger/networking/webrtc_manager.dart';
import 'package:oodaa_messenger/ui/screens/chat_screen.dart';
import 'package:qr_flutter/qr_flutter.dart';

// Conditional import for dart:html
import 'package:oodaa_messenger/conditional_imports.dart' if (dart.library.html) 'dart:html' as html;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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

  Future<void> _loadSavedData() async {
    if (kIsWeb) {
      try {
        final savedUserId = html.window.localStorage['oodaa_user_id'];
        final savedUserName = html.window.localStorage['oodaa_user_name'];
        if (savedUserId != null && savedUserName != null) {
          setState(() {
            _userIdentity = savedUserId;
            _userName = savedUserName;
            _nameController.text = savedUserName;
          });
          await _connectToSignalingServer(savedUserId, savedUserName);
        }
        final savedContactsJson = html.window.localStorage['oodaa_contacts'];
        if (savedContactsJson != null) {
          final List<dynamic> contactsList = jsonDecode(savedContactsJson);
          setState(() {
            _contacts.clear();
            _contacts.addAll(contactsList.map((c) => Map<String, String>.from(c)));
          });
        }
        final savedConversationsJson = html.window.localStorage['oodaa_conversations'];
        if (savedConversationsJson != null) {
          final Map<String, dynamic> conversationsMap = jsonDecode(savedConversationsJson);
          setState(() {
            _conversations.clear();
            conversationsMap.forEach((key, value) {
              _conversations[key] = List<Map<String, dynamic>>.from(value);
            });
          });
        }
      } catch (error) {
        print('Error loading saved data: $error');
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    } else {
      // Mobile storage logic would go here. For now, we'll just start fresh.
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _saveData() {
    if (kIsWeb) {
      try {
        if (_userIdentity != null && _userName != null) {
          html.window.localStorage['oodaa_user_id'] = _userIdentity!;
          html.window.localStorage['oodaa_user_name'] = _userName!;
        }
        html.window.localStorage['oodaa_contacts'] = jsonEncode(_contacts);
        html.window.localStorage['oodaa_conversations'] = jsonEncode(_conversations);
      } catch (error) {
        print('Error saving data: $error');
      }
    }
  }

  void _createIdentity() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a name')),);
      return;
    }
    final userId = '${name.toLowerCase()}${DateTime.now().millisecondsSinceEpoch % 1000}';
    setState(() {
      _userIdentity = userId;
      _userName = name;
    });
    _saveData();
    await _connectToSignalingServer(userId, name);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Identity created: $userId')),);
  }

  Future<void> _connectToSignalingServer(String userId, String name) async {
    try {
      final connected = await _webrtcManager.connect();
      if (!connected) throw Exception('Failed to connect to signaling server');
      final registered = await _webrtcManager.registerUser(userId, {'name': name, 'timestamp': DateTime.now().toIso8601String(),});
      if (!registered) throw Exception('Failed to register user');
      _webrtcManager.messageStream.listen(_handleIncomingNetworkMessage);
      setState(() {
        _isConnectedToServer = true;
      });
    } catch (error) {
      print('Connection error: $error');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Connection failed: $error')),);
    }
  }

  void _handleIncomingNetworkMessage(Map<String, dynamic> data) {
    switch (data['type']) {
      case 'incoming_message':
        _handleIncomingMessage(data);
        break;
      case 'contact_request':
        _handleContactRequest(data);
        break;
      case 'contact_accepted':
        _handleContactAccepted(data);
        break;
    }
  }

  void _handleIncomingMessage(Map<String, dynamic> data) {
    final fromUserId = data['fromUserId'];
    final messageData = data['messageData'];
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
    _messageStreamController.add(fromUserId);
    _saveData();
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Decline'),),
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
    setState(() {
      _contacts.add({'name': userInfo['name'] ?? userId, 'id': userId, 'addedAt': DateTime.now().toString(),});
    });
    if (_isConnectedToServer) {
      await _webrtcManager.sendContactAccepted(userId, {'name': _nameController.text.trim(), 'userId': _userIdentity!, 'timestamp': DateTime.now().toIso8601String(),});
    }
    _saveData();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Added ${userInfo['name']} as contact')),);
  }

  void _handleContactAccepted(Map<String, dynamic> data) {
    final fromUserId = data['fromUserId'];
    final fromUserInfo = data['fromUserInfo'];
    setState(() {
      final existingIndex = _contacts.indexWhere((contact) => contact['id'] == fromUserId);
      if (existingIndex == -1) {
        _contacts.add({'name': fromUserInfo['name'] ?? fromUserId, 'id': fromUserId, 'addedAt': DateTime.now().toString(),});
      }
    });
    _saveData();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${fromUserInfo['name']} accepted your contact request!')),);
  }

  void _showQrCodeDialog() {
    final qrData = jsonEncode({'type': 'oodaa_contact', 'userId': _userIdentity, 'name': _nameController.text.trim(), 'timestamp': DateTime.now().millisecondsSinceEpoch,});
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900.withOpacity(0.8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0),),
        title: Text('Your QR Code', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold,), textAlign: TextAlign.center,),
        content: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8),),
                child: QrImageView(data: qrData, version: QrVersions.auto, size: 200.0,),
              ),
              const SizedBox(height: 16),
              Text('Scan this to add me as a contact!', style: GoogleFonts.outfit(color: Colors.white70, fontSize: 14,), textAlign: TextAlign.center,),
              const SizedBox(height: 8),
              Text('ID: $_userIdentity', style: GoogleFonts.outfit(color: Colors.white54, fontSize: 12,),),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Close the dialog
              if (kIsWeb) {
                _simulateQRScan();
              } else {
                final scannedData = await Navigator.push<String>(context, MaterialPageRoute(builder: (context) => const QRScannerScreen(),),);
                if (scannedData != null) {
                  _handleScannedQrCode(scannedData);
                }
              }
            },
            child: Text('Scan a Friend\'s Code', style: GoogleFonts.outfit(color: Colors.deepPurpleAccent,),),
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Close', style: GoogleFonts.outfit(color: Colors.white,),),),
        ],
      ),
    );
  }

  void _handleScannedQrCode(String qrCodeData) {
    try {
      final decodedData = jsonDecode(qrCodeData);
      if (decodedData['type'] == 'oodaa_contact') {
        final userId = decodedData['userId'];
        final userName = decodedData['name'];
        if (userId != null && userName != null) {
          _webrtcManager.sendContactRequest(userId, {
            'requesterName': _nameController.text.trim(),
            'requesterId': _userIdentity!,
            'timestamp': DateTime.now().toIso8601String(),
          }).then((success) {
            if (success) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Contact request sent to $userName')),);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to send contact request')),);
            }
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid QR Code')),);
    }
  }
  
  // ... build methods and other logic from before ...

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Background Gradient
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1a1a2e), Color(0xFF16213e)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        Scaffold(
          backgroundColor: Colors.transparent, // Make scaffold transparent
          appBar: AppBar(
            title: Text(
              'Oodaa Messenger',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
          body: Center(
            child: _isLoading
                ? const CircularProgressIndicator()
                : _userIdentity == null
                    ? _buildIdentityForm()
                    : _buildContactsList(),
          ),
          floatingActionButton: _userIdentity != null
              ? FloatingActionButton(
                  onPressed: _showQrCodeDialog,
                  backgroundColor: Colors.deepPurple,
                  child: const Icon(Icons.qr_code_scanner),
                )
              : null,
        ),
      ],
    );
  }

  Widget _buildIdentityForm() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Create Your Identity',
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Your Name',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _createIdentity,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Create My Identity'),
          ),
        ],
      ),
    );
  }

  Widget _buildContactsList() {
    return ListView.builder(
      itemCount: _contacts.length,
      itemBuilder: (context, index) {
        final contact = _contacts[index];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16.0),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16.0),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                  ),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.deepPurple,
                    child: Text(
                      contact['name']![0].toUpperCase(),
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                      ),
                    ),
                  ),
                  title: Text(
                    contact['name']!,
                    style: GoogleFonts.outfit(),
                  ),
                  subtitle: Text(
                    'ID: ${contact['id']}',
                    style: GoogleFonts.outfit(),
                  ),
                  onTap: () => _openChat(contact),
                ),
              ),
            ),
          ),
        );
      },
    );
  }


  void _simulateQRScan() {
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
                    final success =
                        await _webrtcManager.sendContactRequest(id, {
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
                        const SnackBar(
                            content: Text('Failed to send contact request')),
                      );
                    }
                  } else {
                    setState(() {
                      _contacts.add({
                        'name': name,
                        'id': id,
                        'addedAt': DateTime.now().toString(),
                      });
                    });

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text('Added contact: $name (offline mode)')),
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

  void _openChat(Map<String, String> contact) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          contact: contact,
          currentUser: _userIdentity!,
          onSendMessage: (message) => _sendMessage(contact['id']!, message),
          getMessages: () =>
              List<Map<String, dynamic>>.from(_conversations[contact['id']] ?? []),
          messageStream: _messageStreamController.stream,
        ),
      ),
    );
  }

  void _sendMessage(String contactId, String message) async {
    final messageId = DateTime.now().millisecondsSinceEpoch.toString();
    final timestamp = DateTime.now().toIso8601String();

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
    _saveData();
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
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          final reply = _generateAutoReply(message);
          setState(() {
            _conversations[contactId]!.add({
              'id': (DateTime.now().millisecondsSinceEpoch + 1).toString(),
              'text': reply,
              'sender': contactId,
              'timestamp': DateTime.now().toIso8601String(),
              'isFromMe': false,
            });
          });
          _messageStreamController.add(contactId);
        }
      });
    }
  }

  String _generateAutoReply(String message) {
    // ... same as before
    return "auto-reply";
  }

  @override
  void dispose() {
    _nameController.dispose();
    _messageStreamController.close();
    _webrtcManager.dispose();
    super.dispose();
  }
}

// QR Scanner Screen Implementation
class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final MobileScannerController _scannerController = MobileScannerController();
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: (capture) {
              if (_isProcessing) return;
              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isNotEmpty) {
                final String? code = barcodes.first.rawValue;
                if (code != null) {
                  setState(() { _isProcessing = true; });
                  Navigator.of(context).pop(code);
                }
              }
            },
          ),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.purple.withOpacity(0.5), width: 4),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }
}
