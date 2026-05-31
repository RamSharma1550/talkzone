import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart';

const String agoraAppId = 'YOUR_AGORA_APP_ID';

class CallScreen extends StatefulWidget {
  final String userId;
  final String userName;
  final bool isVideo;

  const CallScreen({
    super.key,
    required this.userId,
    required this.userName,
    required this.isVideo,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  late RtcEngine _engine;
  bool _muted = false;
  bool _speakerOn = true;
  bool _videoOff = false;
  bool _joined = false;
  int _remoteUid = 0;
  int _seconds = 0;
  late String _channelId;

  @override
  void initState() {
    super.initState();
    final ids = [FirebaseAuth.instance.currentUser!.uid, widget.userId]..sort();
    _channelId = ids.join('_');
    _initAgora();
    _startTimer();
    _saveCallRecord();
  }

  void _startTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() => _seconds++);
        _startTimer();
      }
    });
  }

  String get _timerText {
    final m = (_seconds ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _saveCallRecord() async {
    await FirebaseFirestore.instance.collection('calls').add({
      'participants': [
        FirebaseAuth.instance.currentUser!.uid,
        widget.userId
      ],
      'callerName': widget.userName,
      'type': widget.isVideo ? 'video' : 'voice',
      'status': 'ongoing',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _initAgora() async {
    await [Permission.microphone, Permission.camera].request();
    _engine = createAgoraRtcEngine();
    await _engine.initialize(RtcEngineContext(appId: agoraAppId));

    _engine.registerEventHandler(RtcEngineEventHandler(
      onJoinChannelSuccess: (connection, elapsed) {
        setState(() => _joined = true);
      },
      onUserJoined: (connection, remoteUid, elapsed) {
        setState(() => _remoteUid = remoteUid);
      },
      onUserOffline: (connection, remoteUid, reason) {
        setState(() => _remoteUid = 0);
        _endCall();
      },
    ));

    if (widget.isVideo) {
      await _engine.enableVideo();
      await _engine.startPreview();
    }

    await _engine.joinChannel(
      token: '',
      channelId: _channelId,
      uid: 0,
      options: const ChannelMediaOptions(
        channelProfile: ChannelProfileType.channelProfileCommunication,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
      ),
    );
  }

  Future<void> _endCall() async {
    await _engine.leaveChannel();
    await _engine.release();
    if (mounted) Navigator.pop(context);
  }

  void _toggleMute() {
    setState(() => _muted = !_muted);
    _engine.muteLocalAudioStream(_muted);
  }

  void _toggleSpeaker() {
    setState(() => _speakerOn = !_speakerOn);
    _engine.setEnableSpeakerphone(_speakerOn);
  }

  void _toggleVideo() {
    setState(() => _videoOff = !_videoOff);
    _engine.muteLocalVideoStream(_videoOff);
  }

  @override
  void dispose() {
    _engine.leaveChannel();
    _engine.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      body: Stack(
        children: [
          // Video background
          if (widget.isVideo && _remoteUid != 0)
            AgoraVideoView(
              controller: VideoViewController.remote(
                rtcEngine: _engine,
                canvas: VideoCanvas(uid: _remoteUid),
                connection: RtcConnection(channelId: _channelId),
              ),
            ),

          // Dark overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.6),
                  Colors.black.withOpacity(0.3),
                  Colors.black.withOpacity(0.7),
                ],
              ),
            ),
          ),

          // Glow effect
          Positioned(
            top: 100,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF00A884).withOpacity(0.15),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 30),

                // Call status
                Text(
                  widget.isVideo ? '● Video Call' : '● Voice Call',
                  style: const TextStyle(
                    color: Color(0xFF00A884),
                    fontSize: 12,
                    letterSpacing: 2,
                  ),
                ),

                const SizedBox(height: 24),

                // Avatar
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00A884), Color(0xFF00D4A0)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00A884).withOpacity(0.3),
                        blurRadius: 30,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      widget.userName[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Name
                Text(
                  widget.userName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                // Timer
                Text(
                  _joined ? _timerText : 'Connecting...',
                  style: const TextStyle(
                    color: Color(0xFF00A884),
                    fontSize: 18,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const Spacer(),

                // Sound wave animation
                if (!widget.isVideo)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      5,
                      (i) => _WaveBar(delay: i * 100),
                    ),
                  ),

                const Spacer(),

                // Controls
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _ControlButton(
                        icon: _muted ? Icons.mic_off : Icons.mic,
                        label: _muted ? 'Unmute' : 'Mute',
                        isActive: _muted,
                        onTap: _toggleMute,
                      ),
                      _ControlButton(
                        icon: _speakerOn ? Icons.volume_up : Icons.volume_off,
                        label: 'Speaker',
                        isActive: _speakerOn,
                        onTap: _toggleSpeaker,
                      ),
                      if (widget.isVideo)
                        _ControlButton(
                          icon: _videoOff
                              ? Icons.videocam_off
                              : Icons.videocam,
                          label: 'Video',
                          isActive: !_videoOff,
                          onTap: _toggleVideo,
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // End call button
                GestureDetector(
                  onTap: _endCall,
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF4444), Color(0xFFCC0000)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.4),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.call_end,
                        color: Colors.white, size: 32),
                  ),
                ),

                const SizedBox(height: 50),
              ],
            ),
          ),

          // Local video preview (picture-in-picture)
          if (widget.isVideo)
            Positioned(
              top: 100,
              right: 16,
              child: Container(
                width: 90,
                height: 130,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFF00A884), width: 1.5),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AgoraVideoView(
                    controller: VideoViewController(
                      rtcEngine: _engine,
                      canvas: const VideoCanvas(uid: 0),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive
                  ? const Color(0xFF00A884).withOpacity(0.2)
                  : Colors.white.withOpacity(0.08),
              border: Border.all(
                color: isActive
                    ? const Color(0xFF00A884).withOpacity(0.4)
                    : Colors.transparent,
              ),
            ),
            child: Icon(icon,
                color: isActive
                    ? const Color(0xFF00A884)
                    : Colors.white70,
                size: 24),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: const TextStyle(
                  color: Colors.white38, fontSize: 11)),
        ],
      ),
    );
  }
}

class _WaveBar extends StatefulWidget {
  final int delay;
  const _WaveBar({required this.delay});

  @override
  State<_WaveBar> createState() => _WaveBarState();
}

class _WaveBarState extends State<_WaveBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 600 + widget.delay),
    )..repeat(reverse: true);
    _anim = Tween(begin: 8.0, end: 30.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: 4,
        height: _anim.value,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: const Color(0xFF00A884).withOpacity(0.6),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}
