import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

class SignalingClient {
  final String serverUrl;
  io.Socket? _socket;
  String? _userId;
  bool _isConnected = false;

  // Event handlers
  Function(String peerId, RTCSessionDescription offer)? onOffer;
  Function(String peerId, RTCSessionDescription answer)? onAnswer;
  Function(String peerId, RTCIceCandidate candidate)? onIceCandidate;
  Function(String peerId)? onPeerConnected;
  Function(String peerId)? onPeerDisconnected;
  Function()? onConnected;
  Function()? onDisconnected;
  Function(String error)? onError;

  SignalingClient(this.serverUrl);

  bool get isConnected => _isConnected;
  String? get userId => _userId;

  // Connect to signaling server
  Future<void> connect(String userId) async {
    try {
      _userId = userId;
      
      _socket = io.io(serverUrl, io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build());

      _socket!.onConnect((_) {
        debugPrint('Connected to signaling server');
        _isConnected = true;
        
        // Register with server
        _socket!.emit('register', {'userId': userId});
        onConnected?.call();
      });

      _socket!.onDisconnect((_) {
        debugPrint('Disconnected from signaling server');
        _isConnected = false;
        onDisconnected?.call();
      });

      _socket!.on('error', (data) {
        debugPrint('Signaling error: $data');
        onError?.call(data.toString());
      });

      // Handle signaling messages
      _socket!.on('offer', (data) {
        final peerId = data['from'];
        final offerData = data['offer'];
        final offer = RTCSessionDescription(offerData['sdp'], offerData['type']);
        onOffer?.call(peerId, offer);
      });

      _socket!.on('answer', (data) {
        final peerId = data['from'];
        final answerData = data['answer'];
        final answer = RTCSessionDescription(answerData['sdp'], answerData['type']);
        onAnswer?.call(peerId, answer);
      });

      _socket!.on('ice-candidate', (data) {
        final peerId = data['from'];
        final candidateData = data['candidate'];
        final candidate = RTCIceCandidate(
          candidateData['candidate'],
          candidateData['sdpMid'],
          candidateData['sdpMLineIndex'],
        );
        onIceCandidate?.call(peerId, candidate);
      });

      _socket!.on('peer-connected', (data) {
        final peerId = data['peerId'];
        onPeerConnected?.call(peerId);
      });

      _socket!.on('peer-disconnected', (data) {
        final peerId = data['peerId'];
        onPeerDisconnected?.call(peerId);
      });

      _socket!.on('user-list', (data) {
        final users = List<String>.from(data['users']);
        debugPrint('Online users: $users');
        // Notify about online users
        for (final user in users) {
          if (user != userId) {
            onPeerConnected?.call(user);
          }
        }
      });

      _socket!.connect();
    } catch (e) {
      debugPrint('Error connecting to signaling server: $e');
      onError?.call(e.toString());
    }
  }

  // Send offer to peer
  void sendOffer(String peerId, RTCSessionDescription offer) {
    if (!_isConnected) return;
    
    _socket!.emit('offer', {
      'to': peerId,
      'from': _userId,
      'offer': {
        'sdp': offer.sdp,
        'type': offer.type,
      },
    });
  }

  // Send answer to peer
  void sendAnswer(String peerId, RTCSessionDescription answer) {
    if (!_isConnected) return;
    
    _socket!.emit('answer', {
      'to': peerId,
      'from': _userId,
      'answer': {
        'sdp': answer.sdp,
        'type': answer.type,
      },
    });
  }

  // Send ICE candidate to peer
  void sendIceCandidate(String peerId, RTCIceCandidate candidate) {
    if (!_isConnected) return;
    
    _socket!.emit('ice-candidate', {
      'to': peerId,
      'from': _userId,
      'candidate': {
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      },
    });
  }

  // Request list of online users
  void requestUserList() {
    if (!_isConnected) return;
    _socket!.emit('get-users');
  }

  // Send custom message through signaling
  void sendSignalingMessage(String peerId, Map<String, dynamic> message) {
    if (!_isConnected) return;
    
    _socket!.emit('custom-message', {
      'to': peerId,
      'from': _userId,
      'message': message,
    });
  }

  // Disconnect from signaling server
  Future<void> disconnect() async {
    if (_socket != null) {
      _socket!.disconnect();
      _socket = null;
    }
    _isConnected = false;
    _userId = null;
  }

  // Reconnect to signaling server
  Future<void> reconnect() async {
    if (_userId != null) {
      await disconnect();
      await connect(_userId!);
    }
  }

  // Check connection status
  bool get isSocketConnected => _socket?.connected ?? false;
}
