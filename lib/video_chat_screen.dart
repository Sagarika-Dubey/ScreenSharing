import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';
import 'dart:io';

class VideoChatScreen extends StatefulWidget {
  final String meetingId;
  final RTCPeerConnection peerConnection;
  final bool isHost;

  const VideoChatScreen({
    super.key,
    required this.meetingId,
    required this.peerConnection,
    required this.isHost,
  });

  @override
  State<VideoChatScreen> createState() => _VideoChatScreenState();
}

class _VideoChatScreenState extends State<VideoChatScreen> {
  late RTCVideoRenderer _localRenderer;
  late RTCVideoRenderer _remoteRenderer;
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  bool _isScreenSharing = false;
  bool _isMicMuted = false;
  bool _isCameraOff = false;
  static const platform = MethodChannel('screen_capture_service');

  @override
  void initState() {
    super.initState();
    _localRenderer = RTCVideoRenderer();
    _remoteRenderer = RTCVideoRenderer();
    _peerConnection = widget.peerConnection;
    _initialize();
  }

  Future <void> _initialize() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();

    if (await _requestPermissions()) {
      _localStream = await _getUserMedia();
      _localRenderer.srcObject = _localStream;
      _peerConnection = await _createPeerConnection();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Permissions not granted.")),
      );
    }
  }

  Future<bool> _requestPermissions() async {
    final cameraPermission = await Permission.camera.request();
    final microphonePermission = await Permission.microphone.request();
    return cameraPermission.isGranted && microphonePermission.isGranted;
  }

  Future<MediaStream> _getUserMedia() async {
    final mediaConstraints = {
      'audio': true,
      'video': {
        'facingMode': 'user',
        'width': 1280,
        'height': 720,
      },
    };
    return await navigator.mediaDevices.getUserMedia(mediaConstraints);
  }

  Future<RTCPeerConnection> _createPeerConnection() async {
    final configuration = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ],
    };

    final pc = await createPeerConnection(configuration);

    pc.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        setState(() {
          _remoteStream = event.streams[0];
          _remoteRenderer.srcObject = _remoteStream;
        });
      }
    };

    _localStream?.getTracks().forEach((track) {
      pc.addTrack(track, _localStream!);
    });

    return pc;
  }

  Future<void> _startScreenSharing() async {
    try {
      // Save current camera stream before starting screen share
      final cameraStream = _localStream;

      if (Platform.isAndroid) {
        await Permission.systemAlertWindow.request();
        try {
          await platform.invokeMethod('startService');
        } catch (e) {
          print('Error starting service: $e');
        }
      }

      final mediaConstraints = <String, dynamic>{
        'audio': false,
        'video': {
          'mandatory': {
            'minWidth': '640',
            'minHeight': '480',
            'minFrameRate': '30',
          }
        }
      };

      final screenStream =
          await navigator.mediaDevices.getDisplayMedia(mediaConstraints);

      if (screenStream != null) {
        // Keep camera stream active in small window
        setState(() {
          _remoteStream = cameraStream;
          _remoteRenderer.srcObject = cameraStream;

          _localStream = screenStream;
          _localRenderer.srcObject = screenStream;
          _isScreenSharing = true;
        });

        // Replace track in peer connection if exists
        if (_peerConnection != null) {
          final senders = await _peerConnection!.getSenders();
          final screenVideoTrack = screenStream.getVideoTracks().first;
          for (var sender in senders) {
            if (sender.track?.kind == 'video') {
              await sender.replaceTrack(screenVideoTrack);
            }
          }
        }
      }
    } catch (e) {
      print('Error starting screen share: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start screen sharing: $e')),
      );
    }
  }

  Future<void> _stopScreenSharing() async {
    try {
      // Stop screen sharing tracks
      _localStream?.getTracks().forEach((track) => track.stop());

      // Get back to camera stream that we saved
      final cameraStream = _remoteStream;

      if (Platform.isAndroid) {
        try {
          await platform.invokeMethod('stopService');
        } catch (e) {
          print('Error stopping service: $e');
        }
      }

      if (cameraStream != null) {
        // Replace track in peer connection if exists
        if (_peerConnection != null) {
          final senders = await _peerConnection!.getSenders();
          final cameraVideoTrack = cameraStream.getVideoTracks().first;
          for (var sender in senders) {
            if (sender.track?.kind == 'video') {
              await sender.replaceTrack(cameraVideoTrack);
            }
          }
        }

        setState(() {
          _localStream = cameraStream;
          _localRenderer.srcObject = cameraStream;
          _remoteStream = null;
          _remoteRenderer.srcObject = null;
          _isScreenSharing = false;
        });
      } else {
        // If no camera stream, get a new one
        final newCameraStream = await _getUserMedia();
        setState(() {
          _localStream = newCameraStream;
          _localRenderer.srcObject = newCameraStream;
          _isScreenSharing = false;
        });
      }
    } catch (e) {
      print('Error stopping screen share: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to stop screen sharing: $e')),
      );
    }
  }

  void _toggleMic() {
    setState(() {
      _isMicMuted = !_isMicMuted;
      _localStream?.getAudioTracks().forEach((track) {
        track.enabled = !_isMicMuted;
      });
    });
  }

  void _toggleCamera() {
    setState(() {
      _isCameraOff = !_isCameraOff;
      // Only toggle camera tracks, not screen sharing tracks
      if (_isScreenSharing) {
        // If screen sharing, toggle camera in the small window (_remoteRenderer)
        _remoteStream?.getVideoTracks().forEach((track) {
          track.enabled = !_isCameraOff;
        });
      } else {
        // If not screen sharing, toggle camera in the main view
        _localStream?.getVideoTracks().forEach((track) {
          if (track.kind == 'video') {
            track.enabled = !_isCameraOff;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    if (_isScreenSharing) {
      _stopScreenSharing();
    }
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _localStream?.dispose();
    _remoteStream?.dispose();
    _peerConnection?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Meeting: ${widget.meetingId}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Meeting ID copied to clipboard')),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                // Main view - only for screen sharing
                Positioned.fill(
                  child: Container(
                    color: Colors.black87,
                    child: _isScreenSharing
                        ? RTCVideoView(_localRenderer,
                            mirror: false) // Screen share view
                        : const Center(
                            child: Text(
                              'No screen being shared',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ),
                  ),
                ),
                // Small video window - always shows camera feed
                Positioned(
                  bottom: 80,
                  right: 20,
                  child: Container(
                    width: 120,
                    height: 180,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: RTCVideoView(
                      _isScreenSharing ? _remoteRenderer : _localRenderer,
                      mirror: true, // Mirror camera feed
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            color: Colors.black87,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: Icon(
                    _isMicMuted ? Icons.mic_off : Icons.mic,
                    color: _isMicMuted ? Colors.red : Colors.white,
                  ),
                  onPressed: _toggleMic,
                ),
                IconButton(
                  icon: Icon(
                    _isCameraOff ? Icons.videocam_off : Icons.videocam,
                    color: _isCameraOff ? Colors.red : Colors.white,
                  ),
                  onPressed: _toggleCamera,
                ),
                IconButton(
                  icon: Icon(
                    _isScreenSharing
                        ? Icons.stop_screen_share
                        : Icons.screen_share,
                    color: _isScreenSharing ? Colors.green : Colors.white,
                  ),
                  onPressed: _isScreenSharing
                      ? _stopScreenSharing
                      : _startScreenSharing,
                ),
                IconButton(
                  icon: const Icon(Icons.call_end, color: Colors.red),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
