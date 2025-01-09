//import 'dart:math';

import 'package:flutter/material.dart';
import '../video_chat_screen.dart';
import '../widgets/home_meeting_button.dart';
import '../services/meeting_service.dart';

class Meeting extends StatefulWidget {
  const Meeting({super.key});

  @override
  State<Meeting> createState() => _MeetingState();
}

class _MeetingState extends State<Meeting> {
  final _meetingService = MeetingService();
  final _meetingIdController = TextEditingController();

  void _createNewMeeting() async {
    final meetingId = _meetingService.generateMeetingId();
    final connection = await _meetingService.createMeeting(meetingId);
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VideoChatScreen(
            meetingId: meetingId,
            peerConnection: connection,
            isHost: true,
          ),
        ),
      );
    }
  }

  void _joinMeeting() async {
    final meetingId = _meetingIdController.text.trim();
    if (meetingId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a meeting ID')),
      );
      return;
    }

    final connection = await _meetingService.joinMeeting(meetingId);
    if (connection != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VideoChatScreen(
            meetingId: meetingId,
            peerConnection: connection,
            isHost: false,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid meeting ID')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 30),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            HomeMeetingButton(
              onPressed: _createNewMeeting,
              text: 'New Meeting',
              icon: Icons.videocam,
            ),
            HomeMeetingButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Join Meeting'),
                    content: TextField(
                      controller: _meetingIdController,
                      decoration: const InputDecoration(
                        labelText: 'Enter Meeting ID',
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _joinMeeting();
                        },
                        child: const Text('Join'),
                      ),
                    ],
                  ),
                );
              },
              text: 'Join Meeting',
              icon: Icons.add_box_rounded,
            ),
            HomeMeetingButton(
              onPressed: () {},
              text: 'Schedule',
              icon: Icons.calendar_today,
            ),
            HomeMeetingButton(
              onPressed: () {},
              text: 'Share Screen',
              icon: Icons.arrow_upward_rounded,
            ),
          ],
        ),
        const Expanded(
          child: Center(
            child: Text(
              'Create/Join Meetings with just a click!',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _meetingIdController.dispose();
    super.dispose();
  }
}
