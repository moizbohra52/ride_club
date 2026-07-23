import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/ui_helpers.dart';
import '../../../services/audio_service.dart';

/// A record-a-voice-note control for the add-memory sheet. Records to a temp
/// file via [AudioService]; when a clip exists it shows the elapsed length with
/// options to re-record or discard. Reports the finished [File] and its
/// duration in ms to the parent via [onRecorded] / [onCleared].
class VoiceRecorder extends StatefulWidget {
  final void Function(File file, int ms) onRecorded;
  final VoidCallback onCleared;
  const VoiceRecorder({
    super.key,
    required this.onRecorded,
    required this.onCleared,
  });

  @override
  State<VoiceRecorder> createState() => _VoiceRecorderState();
}

class _VoiceRecorderState extends State<VoiceRecorder> {
  final AudioService _audio = Get.find<AudioService>();

  bool _recording = false;
  File? _clip;
  int _elapsedMs = 0;
  Timer? _ticker;

  @override
  void dispose() {
    _ticker?.cancel();
    // If the sheet closes mid-recording, drop the in-progress capture.
    if (_recording) _audio.cancelRecording();
    super.dispose();
  }

  Future<void> _start() async {
    final bool ok = await _audio.startRecording();
    if (!ok) {
      UiHelpers.warning(
        'Microphone permission is needed to record a voice note.',
        title: 'Mic blocked',
      );
      return;
    }
    setState(() {
      _recording = true;
      _elapsedMs = 0;
      _clip = null;
    });
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (mounted) setState(() => _elapsedMs += 200);
    });
  }

  Future<void> _stop() async {
    _ticker?.cancel();
    final String? path = await _audio.stopRecording();
    final int ms = _elapsedMs;
    if (!mounted) return;
    setState(() => _recording = false);
    if (path == null) {
      widget.onCleared();
      return;
    }
    final File file = File(path);
    setState(() => _clip = file);
    widget.onRecorded(file, ms);
  }

  void _discard() {
    setState(() {
      _clip = null;
      _elapsedMs = 0;
    });
    widget.onCleared();
  }

  String get _timeText {
    final int secs = _elapsedMs ~/ 1000;
    final String m = (secs ~/ 60).toString().padLeft(2, '0');
    final String s = (secs % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    if (_recording) {
      return _pill(
        scheme,
        color: AppColors.sos,
        icon: Icons.stop_rounded,
        label: 'Recording  $_timeText',
        onTap: _stop,
        trailing: const _RecordingDot(),
      );
    }

    if (_clip != null) {
      return Row(
        children: <Widget>[
          Expanded(
            child: _pill(
              scheme,
              color: scheme.primary,
              icon: Icons.mic_rounded,
              label: 'Voice note  ·  $_timeText',
              onTap: _start, // tap to re-record
            ),
          ),
          IconButton(
            tooltip: 'Discard voice note',
            onPressed: _discard,
            icon: Icon(Icons.delete_outline_rounded, color: scheme.error),
          ),
        ],
      );
    }

    return _pill(
      scheme,
      color: scheme.primary,
      icon: Icons.mic_none_rounded,
      label: 'Record a voice note',
      onTap: _start,
    );
  }

  Widget _pill(
    ColorScheme scheme, {
    required Color color,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return Material(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: <Widget>[
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.poppins(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}

/// A softly pulsing red dot shown while recording.
class _RecordingDot extends StatefulWidget {
  const _RecordingDot();

  @override
  State<_RecordingDot> createState() => _RecordingDotState();
}

class _RecordingDotState extends State<_RecordingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.3, end: 1).animate(_c),
      child: Container(
        width: 10,
        height: 10,
        decoration: const BoxDecoration(
          color: AppColors.sos,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
