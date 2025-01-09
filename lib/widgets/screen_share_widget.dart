import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';
import 'dart:io';

class ScreenShareWidget extends StatefulWidget {
  final String meetingId;

  const ScreenShareWidget({Key? key, required this.meetingId})
      : super(key: key);

  @override
  _ScreenShareWidgetState createState() => _ScreenShareWidgetState();
}

class _ScreenShareWidgetState extends State<ScreenShareWidget> {
  final _localRenderer = RTCVideoRenderer();
  MediaStream? _localStream;
  bool _isSharing = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _localRenderer.initialize();
    await _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await Permission.camera.request();
    await Permission.microphone.request();
    await Permission.storage.request();
  }

  Future<void> startScreenShare() async {
    try {
      if (Platform.isAndroid) {
        await _startForegroundService();
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

      _localStream =
          await navigator.mediaDevices.getDisplayMedia(mediaConstraints);

      setState(() {
        _localRenderer.srcObject = _localStream;
        _isSharing = true;
      });
    } catch (e) {
      print('Error starting screen share: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start screen sharing: $e')),
      );
    }
  }

  Future<void> _startForegroundService() async {
    const platform = MethodChannel('screen_capture_service');
    try {
      await platform.invokeMethod('startService');
    } catch (e) {
      print('Error starting foreground service: $e');
    }
  }

  Future<void> stopScreenShare() async {
    try {
      _localStream?.getTracks().forEach((track) => track.stop());
      _localRenderer.srcObject = null;

      if (Platform.isAndroid) {
        const platform = MethodChannel('screen_capture_service');
        await platform.invokeMethod('stopService');
      }

      setState(() {
        _isSharing = false;
      });
    } catch (e) {
      print('Error stopping screen share: $e');
    }
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    stopScreenShare();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await stopScreenShare();
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Screen Sharing - ${widget.meetingId}'),
        ),
        body: Column(
          children: [
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(border: Border.all()),
                child: RTCVideoView(_localRenderer),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton(
                onPressed: _isSharing ? stopScreenShare : startScreenShare,
                child: Text(_isSharing ? 'Stop Sharing' : 'Start Sharing'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
