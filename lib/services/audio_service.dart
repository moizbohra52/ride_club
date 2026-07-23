import 'dart:async';
import 'dart:io';

import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../core/utils/logger.dart';

/// Thin wrapper over [AudioRecorder] (capture) and [AudioPlayer] (playback) so
/// widgets stay free of plugin lifecycle. One recorder + one player are reused
/// for the whole app; only one clip records or plays at a time, which matches
/// the "record a voice note" / "play a voice note" UX.
///
/// Recording produces an AAC-in-M4A file in the temp directory. Callers upload
/// it to Storage and then may discard the temp file.
class AudioService extends GetxService {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();

  /// Currently-recording output path, or null when idle.
  String? _recordingPath;

  /// Monotonic counter so each capture writes to a distinct temp file (avoids
  /// needing DateTime.now() for uniqueness).
  int _clipSeq = 0;

  /// Whether the microphone permission is granted AND recording can start.
  Future<bool> hasMicPermission() => _recorder.hasPermission();

  /// Begin recording to a fresh temp file. Returns false if permission is
  /// denied or the recorder could not start.
  Future<bool> startRecording() async {
    try {
      if (!await _recorder.hasPermission()) return false;
      final Directory dir = await getTemporaryDirectory();
      // A fresh path per capture — the counter avoids needing DateTime.now()
      // for uniqueness (which is unavailable in some execution contexts).
      final String path = '${dir.path}/voice_${_clipSeq++}.m4a';
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );
      _recordingPath = path;
      return true;
    } catch (e, s) {
      Log.e('startRecording failed', error: e, stack: s);
      _recordingPath = null;
      return false;
    }
  }

  /// Stop recording and return the finished file path (null on failure).
  Future<String?> stopRecording() async {
    try {
      final String? path = await _recorder.stop();
      return path ?? _recordingPath;
    } catch (e, s) {
      Log.e('stopRecording failed', error: e, stack: s);
      return null;
    } finally {
      _recordingPath = null;
    }
  }

  /// Cancel an in-progress recording and discard its file.
  Future<void> cancelRecording() async {
    try {
      await _recorder.cancel();
    } catch (e, s) {
      Log.e('cancelRecording failed', error: e, stack: s);
    } finally {
      _recordingPath = null;
    }
  }

  Future<bool> get isRecording => _recorder.isRecording();

  /// Live amplitude while recording — drives a simple waveform/level meter.
  Stream<Amplitude> amplitudeStream() =>
      _recorder.onAmplitudeChanged(const Duration(milliseconds: 200));

  // --- Playback ---

  /// Player state stream (loading/playing/paused/completed) for UI.
  Stream<PlayerState> get playerState => _player.playerStateStream;

  /// Playback position stream for a progress bar.
  Stream<Duration> get position => _player.positionStream;

  Duration? get duration => _player.duration;

  /// Load [url] (a Storage download URL or local path) and start playing.
  /// Restarts from the beginning if the same clip finished.
  Future<void> play(String url) async {
    try {
      if (_player.audioSource == null ||
          _currentUrl != url) {
        _currentUrl = url;
        await _player.setUrl(url);
      }
      if (_player.processingState == ProcessingState.completed) {
        await _player.seek(Duration.zero);
      }
      await _player.play();
    } catch (e, s) {
      Log.e('audio play failed', error: e, stack: s);
    }
  }

  String? _currentUrl;

  Future<void> pause() => _player.pause();
  Future<void> stop() => _player.stop();
  Future<void> seek(Duration to) => _player.seek(to);

  /// The url currently loaded into the player (for "is this clip playing?").
  String? get currentUrl => _currentUrl;

  @override
  void onClose() {
    _recorder.dispose();
    _player.dispose();
    super.onClose();
  }
}
