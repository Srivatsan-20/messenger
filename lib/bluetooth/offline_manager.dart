import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/user_identity.dart';
import '../models/message.dart';
import '../auth/identity_manager.dart';
import '../chat/message_manager.dart';

class OfflineManager extends ChangeNotifier {
  static const String _serviceId = 'com.oodaa.messenger.offline';
  
  final IdentityManager _identityManager;
  final MessageManager _messageManager;
  
  bool _isAdvertising = false;
  bool _isDiscovering = false;
  final Map<String, String> _connectedPeers = {}; // endpointId -> userId
  final Map<String, UserIdentity> _discoveredPeers = {}; // endpointId -> identity
  
  OfflineManager(this._identityManager, this._messageManager);

  bool get isAdvertising => _isAdvertising;
  bool get isDiscovering => _isDiscovering;
  List<UserIdentity> get discoveredPeers => _discoveredPeers.values.toList();
  List<String> get connectedPeerIds => _connectedPeers.values.toList();

  // Initialize offline communication
  Future<bool> initialize() async {
    try {
      // Request necessary permissions
      final permissions = await _requestPermissions();
      if (!permissions) {
        debugPrint('Permissions not granted for offline communication');
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('Error initializing offline manager: $e');
      return false;
    }
  }

  // Start advertising presence
  Future<bool> startAdvertising() async {
    if (_isAdvertising) return true;
    
    try {
      final identity = _identityManager.currentIdentity;
      if (identity == null) return false;

      final advertisingInfo = jsonEncode({
        'userId': identity.userId,
        'alias': identity.alias,
        'publicKey': identity.publicKey,
      });

      await Nearby().startAdvertising(
        identity.userId,
        Strategy.P2P_CLUSTER,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
        serviceId: _serviceId,
      );

      _isAdvertising = true;
      notifyListeners();
      debugPrint('Started advertising as ${identity.userId}');
      return true;
    } catch (e) {
      debugPrint('Error starting advertising: $e');
      return false;
    }
  }

  // Stop advertising
  Future<void> stopAdvertising() async {
    if (!_isAdvertising) return;
    
    try {
      await Nearby().stopAdvertising();
      _isAdvertising = false;
      notifyListeners();
      debugPrint('Stopped advertising');
    } catch (e) {
      debugPrint('Error stopping advertising: $e');
    }
  }

  // Start discovering nearby peers
  Future<bool> startDiscovery() async {
    if (_isDiscovering) return true;
    
    try {
      await Nearby().startDiscovery(
        _identityManager.currentIdentity?.userId ?? 'unknown',
        Strategy.P2P_CLUSTER,
        onEndpointFound: _onEndpointFound,
        onEndpointLost: _onEndpointLost,
        serviceId: _serviceId,
      );

      _isDiscovering = true;
      notifyListeners();
      debugPrint('Started discovery');
      return true;
    } catch (e) {
      debugPrint('Error starting discovery: $e');
      return false;
    }
  }

  // Stop discovery
  Future<void> stopDiscovery() async {
    if (!_isDiscovering) return;
    
    try {
      await Nearby().stopDiscovery();
      _isDiscovering = false;
      _discoveredPeers.clear();
      notifyListeners();
      debugPrint('Stopped discovery');
    } catch (e) {
      debugPrint('Error stopping discovery: $e');
    }
  }

  // Connect to discovered peer
  Future<bool> connectToPeer(String endpointId) async {
    try {
      await Nearby().requestConnection(
        _identityManager.currentIdentity?.userId ?? 'unknown',
        endpointId,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
      );
      return true;
    } catch (e) {
      debugPrint('Error connecting to peer: $e');
      return false;
    }
  }

  // Send message to connected peer
  Future<bool> sendOfflineMessage(String userId, String content) async {
    try {
      final endpointId = _getEndpointIdForUser(userId);
      if (endpointId == null) {
        debugPrint('User $userId not connected offline');
        return false;
      }

      final messageData = {
        'type': 'message',
        'content': content,
        'sender': _identityManager.currentIdentity?.userId,
        'timestamp': DateTime.now().toIso8601String(),
      };

      await Nearby().sendBytesPayload(
        endpointId,
        Uint8List.fromList(utf8.encode(jsonEncode(messageData))),
      );

      return true;
    } catch (e) {
      debugPrint('Error sending offline message: $e');
      return false;
    }
  }

  // Disconnect from peer
  Future<void> disconnectFromPeer(String endpointId) async {
    try {
      await Nearby().disconnectFromEndpoint(endpointId);
    } catch (e) {
      debugPrint('Error disconnecting from peer: $e');
    }
  }

  // Disconnect all peers
  Future<void> disconnectAll() async {
    try {
      await Nearby().stopAllEndpoints();
      _connectedPeers.clear();
      _discoveredPeers.clear();
      notifyListeners();
    } catch (e) {
      debugPrint('Error disconnecting all peers: $e');
    }
  }

  // Event handlers
  void _onEndpointFound(String endpointId, String endpointName, String serviceId) {
    debugPrint('Endpoint found: $endpointId ($endpointName)');
    
    try {
      // Parse endpoint name as identity info
      final identityData = jsonDecode(endpointName);
      final identity = UserIdentity(
        userId: identityData['userId'],
        publicKey: identityData['publicKey'],
        alias: identityData['alias'],
        createdAt: DateTime.now(),
        lastSeen: DateTime.now(),
      );
      
      _discoveredPeers[endpointId] = identity;
      notifyListeners();
    } catch (e) {
      debugPrint('Error parsing endpoint identity: $e');
    }
  }

  void _onEndpointLost(String? endpointId) {
    if (endpointId == null) return;
    debugPrint('Endpoint lost: $endpointId');
    _discoveredPeers.remove(endpointId);
    notifyListeners();
  }

  void _onConnectionInitiated(String endpointId, ConnectionInfo connectionInfo) {
    debugPrint('Connection initiated with: $endpointId');
    
    // Auto-accept connections (in production, you might want user confirmation)
    Nearby().acceptConnection(
      endpointId,
      onPayLoadRecieved: _onPayloadReceived,
    );
  }

  void _onConnectionResult(String endpointId, Status status) {
    debugPrint('Connection result for $endpointId: ${status.toString()}');
    
    if (status == Status.CONNECTED) {
      final identity = _discoveredPeers[endpointId];
      if (identity != null) {
        _connectedPeers[endpointId] = identity.userId;
        debugPrint('Connected to ${identity.userId}');
        notifyListeners();
      }
    } else {
      _connectedPeers.remove(endpointId);
      notifyListeners();
    }
  }

  void _onDisconnected(String endpointId) {
    debugPrint('Disconnected from: $endpointId');
    final userId = _connectedPeers.remove(endpointId);
    _discoveredPeers.remove(endpointId);
    
    if (userId != null) {
      debugPrint('Lost connection to $userId');
    }
    
    notifyListeners();
  }

  void _onPayloadReceived(String endpointId, Payload payload) {
    try {
      if (payload.type == PayloadType.BYTES) {
        final data = jsonDecode(utf8.decode(payload.bytes!));
        _handleReceivedData(endpointId, data);
      }
    } catch (e) {
      debugPrint('Error handling received payload: $e');
    }
  }

  void _handleReceivedData(String endpointId, Map<String, dynamic> data) {
    final type = data['type'] as String?;
    
    switch (type) {
      case 'message':
        _handleReceivedMessage(endpointId, data);
        break;
      case 'identity_exchange':
        _handleIdentityExchange(endpointId, data);
        break;
      default:
        debugPrint('Unknown offline message type: $type');
    }
  }

  void _handleReceivedMessage(String endpointId, Map<String, dynamic> data) {
    try {
      final senderId = data['sender'] as String;
      final content = data['content'] as String;
      final timestamp = DateTime.parse(data['timestamp']);
      
      // TODO: Integrate with message manager to save offline message
      debugPrint('Received offline message from $senderId: $content');
      
    } catch (e) {
      debugPrint('Error handling received message: $e');
    }
  }

  void _handleIdentityExchange(String endpointId, Map<String, dynamic> data) {
    try {
      final identity = UserIdentity.fromJson(data);
      _discoveredPeers[endpointId] = identity;
      notifyListeners();
    } catch (e) {
      debugPrint('Error handling identity exchange: $e');
    }
  }

  // Helper methods
  String? _getEndpointIdForUser(String userId) {
    for (final entry in _connectedPeers.entries) {
      if (entry.value == userId) {
        return entry.key;
      }
    }
    return null;
  }

  Future<bool> _requestPermissions() async {
    final permissions = [
      Permission.bluetooth,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.location,
      Permission.nearbyWifiDevices,
    ];

    Map<Permission, PermissionStatus> statuses = await permissions.request();
    
    return statuses.values.every((status) => 
        status == PermissionStatus.granted || 
        status == PermissionStatus.limited);
  }

  // Cleanup
  Future<void> dispose() async {
    await stopAdvertising();
    await stopDiscovery();
    await disconnectAll();
    super.dispose();
  }

  // Get connection statistics
  Map<String, dynamic> getOfflineStats() {
    return {
      'isAdvertising': _isAdvertising,
      'isDiscovering': _isDiscovering,
      'discoveredPeers': _discoveredPeers.length,
      'connectedPeers': _connectedPeers.length,
    };
  }
}
