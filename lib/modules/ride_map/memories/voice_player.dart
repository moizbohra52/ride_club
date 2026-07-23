import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';

import '../../../services/audio_service.dart';

/// A play/pause bar for a voice note stored at [url]. Uses the shared
/// [AudioService] player, so starting a different clip stops this one. Shows a
/// progress slider and elapsed / total time. [totalMs] (from the memory doc)
/// seeds the duration label before the audio finishes loading.
class VoicePlayer extends StatefulWidget {
  final String url;
  final int? totalMs;
  const VoicePlayer({super.key, required this.url, this.totalMs});

  @override
  State<VoicePlayer> createState() => _VoicePlayerState();
}

class _VoicePlayerState extends State<VoicePlayer> {
  final AudioService _audio = Get.find<AudioService>();

  @override
  void dispose() {
    // Stop playback if this bar is torn down while playing our clip.
    if (_audio.currentUrl == widget.url) _audio.stop();
    super.dispose();
  }

  bool get _isMine => _audio.currentUrl == widget.url;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return StreamBuilder<PlayerState>(
      stream: _audio.playerState,
      builder: (BuildContext context, AsyncSnapshot<PlayerState> stateSnap) {
        final bool playing = _isMine && (stateSnap.data?.playing ?? false);
        final bool completed = stateSnap.data?.processingState ==
            ProcessingState.completed;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: <Widget>[
              _PlayButton(
                playing: playing,
                color: scheme.primary,
                onTap: () {
                  if (playing) {
                    _audio.pause();
                  } else {
                    _audio.play(widget.url);
                  }
                },
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StreamBuilder<Duration>(
                  stream: _audio.position,
                  builder: (BuildContext context, AsyncSnapshot<Duration> ps) {
                    final Duration total = _audio.duration ??
                        Duration(milliseconds: widget.totalMs ?? 0);
                    final Duration pos = (_isMine && !completed)
                        ? (ps.data ?? Duration.zero)
                        : Duration.zero;
                    final double max = total.inMilliseconds.toDouble();
                    final double value =
                        max <= 0 ? 0 : pos.inMilliseconds.clamp(0, max).toDouble();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 3,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 6,
                            ),
                            overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 12,
                            ),
                          ),
                          child: Slider(
                            value: value,
                            max: max <= 0 ? 1 : max,
                            onChanged: max <= 0
                                ? null
                                : (double v) => _audio.seek(
                                      Duration(milliseconds: v.round()),
                                    ),
                          ),
                        ),
                        Text(
                          '${_fmt(pos)} / ${_fmt(total)}',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static String _fmt(Duration d) {
    final String m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final String s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _PlayButton extends StatelessWidget {
  final bool playing;
  final Color color;
  final VoidCallback onTap;
  const _PlayButton({
    required this.playing,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
            color: Colors.white,
            size: 22,
          ),
        ),
      ),
    );
  }
}
