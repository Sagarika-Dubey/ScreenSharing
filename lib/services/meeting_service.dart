import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'dart:math';

class MeetingService {
  static final MeetingService _instance = MeetingService._internal();
  factory MeetingService() => _instance;
  MeetingService._internal();

  final Map<String, RTCPeerConnection> _meetings = {};

  String generateMeetingId() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return List.generate(10, (index) => chars[random.nextInt(chars.length)])
        .join();
  }

  Future<RTCPeerConnection> createMeeting(String meetingId) async {
    final configuration = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ],
    };

    final peerConnection = await createPeerConnection(configuration);
    _meetings[meetingId] = peerConnection;
    return peerConnection;
  }

  Future<RTCPeerConnection?> joinMeeting(String meetingId) async {
    if (!_meetings.containsKey(meetingId)) {
      return null;
    }
    return _meetings[meetingId];
  }

  void endMeeting(String meetingId) {
    _meetings[meetingId]?.close();
    _meetings.remove(meetingId);
  }
}
