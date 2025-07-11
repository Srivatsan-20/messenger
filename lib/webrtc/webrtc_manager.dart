import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/message.dart';
import 'signaling_client.dart';

class WebRTCManager extends ChangeNotifier {
  static const Map<String, dynamic> _iceServers = {
    'iceServers': [
      // TODO: Replace with your own STUN/TURN servers
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      // Add TURN servers for better connectivity
      // {
      //   'urls': 'turn:your-turn-server.com:3478',
      //   'username': 'your-username',
      //   'credential': 'your-password'
      // }
    ]
  };

  static const Map<String, dynamic> _dataChannelConfig = {
    'ordered': true,
    'maxRetransmits': 3,
  };

  final Map<String, RTCPeerConnection> _peerConnections = {};
  final Map<String, RTCDataChannel> _dataChannels = {};
  final Map<String, Function(Map<String, dynamic>)> _messageHandlers = {};
  
  SignalingClient? _signalingClient;
  String? _myUserId;

  // Connection states
  final Map<String, RTCPeerConnectionState> _connectionStates = {};

  // Initialize WebRTC manager
  Future<void> initialize(String userId, String signalingServerUrl) async {
    _myUserId = userId;
    
    // Initialize signaling client
    _signalingClient = SignalingClient(signalingServerUrl);
    await _signalingClient!.connect(userId);
    
    // Set up signaling message handlers
    _signalingClient!.onOffer = _handleOffer;
    _signalingClient!.onAnswer = _handleAnswer;
    _signalingClient!.onIceCandidate = _handleIceCandidate;
    _signalingClient!.onPeerConnected = _handlePeerConnected;
    _signalingClient!.onPeerDisconnected = _handlePeerDisconnected;
  }

  // Create peer connection
  Future<RTCPeerConnection> _createPeerConnection(String peerId) async {
    final pc = await createPeerConnection(_iceServers);
    
    // Set up connection state change handler
    pc.onConnectionState = (state) {
      _connectionStates[peerId] = state;
      notifyListeners();
      
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        _cleanupPeerConnection(peerId);
      }
    };

    // Set up ICE candidate handler
    pc.onIceCandidate = (candidate) {
      if (candidate.candidate != null) {
        _signalingClient?.sendIceCandidate(peerId, candidate);
      }
    };

    // Set up data channel handler for incoming channels
    pc.onDataChannel = (channel) {
      _setupDataChannel(peerId, channel);
    };

    _peerConnections[peerId] = pc;
    return pc;
  }

  // Set up data channel
  void _setupDataChannel(String peerId, RTCDataChannel channel) {
    _dataChannels[peerId] = channel;
    
    channel.onMessage = (message) {
      try {
        final data = jsonDecode(message.text);
        _handleDataChannelMessage(peerId, data);
      } catch (e) {
        debugPrint('Error parsing data channel message: $e');
      }
    };

    channel.onDataChannelState = (state) {
      debugPrint('Data channel state for $peerId: $state');
      if (state == RTCDataChannelState.RTCDataChannelOpen) {
        notifyListeners();
      }
    };
  }

  // Initiate connection to peer
  Future<bool> connectToPeer(String peerId) async {
    try {
      if (_peerConnections.containsKey(peerId)) {
        debugPrint('Already connected to $peerId');
        return true;
      }

      final pc = await _createPeerConnection(peerId);
      
      // Create data channel
      final dataChannel = await pc.createDataChannel(
        'messages',
        RTCDataChannelInit()..ordered = _dataChannelConfig['ordered']
                            ..maxRetransmits = _dataChannelConfig['maxRetransmits'],
      );
      
      _setupDataChannel(peerId, dataChannel);

      // Create offer
      final offer = await pc.createOffer();
      await pc.setLocalDescription(offer);
      
      // Send offer through signaling
      _signalingClient?.sendOffer(peerId, offer);
      
      return true;
    } catch (e) {
      debugPrint('Error connecting to peer $peerId: $e');
      return false;
    }
  }

  // Handle incoming offer
  Future<void> _handleOffer(String peerId, RTCSessionDescription offer) async {
    try {
      final pc = await _createPeerConnection(peerId);
      
      await pc.setRemoteDescription(offer);
      
      // Create answer
      final answer = await pc.createAnswer();
      await pc.setLocalDescription(answer);
      
      // Send answer through signaling
      _signalingClient?.sendAnswer(peerId, answer);
    } catch (e) {
      debugPrint('Error handling offer from $peerId: $e');
    }
  }

  // Handle incoming answer
  Future<void> _handleAnswer(String peerId, RTCSessionDescription answer) async {
    try {
      final pc = _peerConnections[peerId];
      if (pc != null) {
        await pc.setRemoteDescription(answer);
      }
    } catch (e) {
      debugPrint('Error handling answer from $peerId: $e');
    }
  }

  // Handle incoming ICE candidate
  Future<void> _handleIceCandidate(String peerId, RTCIceCandidate candidate) async {
    try {
      final pc = _peerConnections[peerId];
      if (pc != null) {
        await pc.addCandidate(candidate);
      }
    } catch (e) {
      debugPrint('Error handling ICE candidate from $peerId: $e');
    }
  }

  // Handle peer connected
  void _handlePeerConnected(String peerId) {
    debugPrint('Peer connected: $peerId');
    notifyListeners();
  }

  // Handle peer disconnected
  void _handlePeerDisconnected(String peerId) {
    debugPrint('Peer disconnected: $peerId');
    _cleanupPeerConnection(peerId);
  }

  // Send message through data channel
  Future<bool> sendMessage(String peerId, Map<String, dynamic> message) async {
    final dataChannel = _dataChannels[peerId];
    if (dataChannel?.state != RTCDataChannelState.RTCDataChannelOpen) {
      debugPrint('Data channel not open for $peerId');
      return false;
    }

    try {
      final messageJson = jsonEncode(message);
      await dataChannel!.send(RTCDataChannelMessage(messageJson));
      return true;
    } catch (e) {
      debugPrint('Error sending message to $peerId: $e');
      return false;
    }
  }

  // Send file in chunks
  Future<bool> sendFile(String peerId, Uint8List fileData, String fileName, String mimeType) async {
    final dataChannel = _dataChannels[peerId];
    if (dataChannel?.state != RTCDataChannelState.RTCDataChannelOpen) {
      return false;
    }

    try {
      const chunkSize = 16384; // 16KB chunks
      final totalChunks = (fileData.length / chunkSize).ceil();
      final fileId = DateTime.now().millisecondsSinceEpoch.toString();

      // Send file metadata
      await sendMessage(peerId, {
        'type': 'file_start',
        'fileId': fileId,
        'fileName': fileName,
        'mimeType': mimeType,
        'fileSize': fileData.length,
        'totalChunks': totalChunks,
      });

      // Send file chunks
      for (int i = 0; i < totalChunks; i++) {
        final start = i * chunkSize;
        final end = (start + chunkSize < fileData.length) ? start + chunkSize : fileData.length;
        final chunk = fileData.sublist(start, end);

        await sendMessage(peerId, {
          'type': 'file_chunk',
          'fileId': fileId,
          'chunkIndex': i,
          'data': base64.encode(chunk),
          'isLast': i == totalChunks - 1,
        });

        // Small delay to prevent overwhelming the channel
        await Future.delayed(const Duration(milliseconds: 10));
      }

      return true;
    } catch (e) {
      debugPrint('Error sending file to $peerId: $e');
      return false;
    }
  }

  // Handle incoming data channel message
  void _handleDataChannelMessage(String peerId, Map<String, dynamic> data) {
    final handler = _messageHandlers[peerId];
    if (handler != null) {
      handler(data);
    } else {
      debugPrint('No message handler for peer $peerId');
    }
  }

  // Set message handler for peer
  void setMessageHandler(String peerId, Function(Map<String, dynamic>) handler) {
    _messageHandlers[peerId] = handler;
  }

  // Remove message handler
  void removeMessageHandler(String peerId) {
    _messageHandlers.remove(peerId);
  }

  // Check if connected to peer
  bool isConnectedToPeer(String peerId) {
    final dataChannel = _dataChannels[peerId];
    return dataChannel?.state == RTCDataChannelState.RTCDataChannelOpen;
  }

  // Get connection state
  RTCPeerConnectionState? getConnectionState(String peerId) {
    return _connectionStates[peerId];
  }

  // Get all connected peers
  List<String> getConnectedPeers() {
    return _dataChannels.entries
        .where((entry) => entry.value.state == RTCDataChannelState.RTCDataChannelOpen)
        .map((entry) => entry.key)
        .toList();
  }

  // Disconnect from peer
  Future<void> disconnectFromPeer(String peerId) async {
    await _cleanupPeerConnection(peerId);
  }

  // Cleanup peer connection
  Future<void> _cleanupPeerConnection(String peerId) async {
    final pc = _peerConnections.remove(peerId);
    final dc = _dataChannels.remove(peerId);
    _messageHandlers.remove(peerId);
    _connectionStates.remove(peerId);

    await dc?.close();
    await pc?.close();
    
    notifyListeners();
  }

  // Disconnect from signaling server
  Future<void> disconnect() async {
    // Close all peer connections
    for (final peerId in _peerConnections.keys.toList()) {
      await _cleanupPeerConnection(peerId);
    }

    // Disconnect from signaling server
    await _signalingClient?.disconnect();
    _signalingClient = null;
  }

  // Get connection statistics
  Map<String, dynamic> getConnectionStats() {
    return {
      'connectedPeers': getConnectedPeers().length,
      'totalPeerConnections': _peerConnections.length,
      'signalingConnected': _signalingClient?.isConnected ?? false,
    };
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
