import 'package:flutter_webrtc/flutter_webrtc.dart';

class SignalingService {
  static final SignalingService _instance = SignalingService._internal();
  factory SignalingService() => _instance;
  SignalingService._internal();

  Future<void> createOffer(RTCPeerConnection peerConnection) async {
    try {
      RTCSessionDescription description = await peerConnection.createOffer();
      await peerConnection.setLocalDescription(description);
      // Here you would send this offer to the other peer through your signaling server
    } catch (e) {
      print('Error creating offer: $e');
    }
  }

  Future<void> createAnswer(RTCPeerConnection peerConnection) async {
    try {
      RTCSessionDescription description = await peerConnection.createAnswer();
      await peerConnection.setLocalDescription(description);
      // Here you would send this answer to the other peer through your signaling server
    } catch (e) {
      print('Error creating answer: $e');
    }
  }
}
