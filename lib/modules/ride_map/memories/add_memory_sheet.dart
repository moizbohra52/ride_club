import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/utils/logger.dart';
import '../../../core/utils/ui_helpers.dart';
import '../../../services/ride_memory_service.dart';
import 'voice_recorder.dart';

/// Opens the "add memory" bottom sheet for [point]. [kind] is `'pin'` (dropped
/// by long-press on the map) or `'log'` (captured at the user's location).
/// Saves via [RideMemoryService.addMemory] and pops on success.
Future<void> showAddMemorySheet(
  BuildContext context, {
  required String rideId,
  required LatLng point,
  required String kind,
}) {
  return Get.bottomSheet<void>(
    _AddMemorySheet(rideId: rideId, point: point, kind: kind),
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
  );
}

class _AddMemorySheet extends StatefulWidget {
  final String rideId;
  final LatLng point;
  final String kind;
  const _AddMemorySheet({
    required this.rideId,
    required this.point,
    required this.kind,
  });

  @override
  State<_AddMemorySheet> createState() => _AddMemorySheetState();
}

class _AddMemorySheetState extends State<_AddMemorySheet> {
  final RideMemoryService _memories = Get.find<RideMemoryService>();
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _title = TextEditingController();
  final TextEditingController _note = TextEditingController();

  final List<File> _photos = <File>[];
  File? _voice;
  int? _voiceMs;
  bool _saving = false;

  bool get _isPin => widget.kind == 'pin';

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _addPhotos() async {
    try {
      final List<XFile> files = await _picker.pickMultiImage(
        maxWidth: 1280,
        imageQuality: 80,
      );
      if (files.isEmpty) return;
      setState(() {
        _photos.addAll(files.map((XFile f) => File(f.path)));
      });
    } catch (e, s) {
      Log.e('pickMultiImage failed', error: e, stack: s);
      UiHelpers.error('Could not open the gallery.');
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1280,
        imageQuality: 80,
      );
      if (file == null) return;
      setState(() => _photos.add(File(file.path)));
    } catch (e, s) {
      Log.e('camera capture failed', error: e, stack: s);
      UiHelpers.error('Could not open the camera.');
    }
  }

  bool get _hasContent =>
      _title.text.trim().isNotEmpty ||
      _note.text.trim().isNotEmpty ||
      _photos.isNotEmpty ||
      _voice != null;

  Future<void> _save() async {
    if (!_hasContent) {
      UiHelpers.info('Add a note, photo, or voice note first.');
      return;
    }
    setState(() => _saving = true);
    try {
      await _memories.addMemory(
        rideId: widget.rideId,
        kind: widget.kind,
        lat: widget.point.latitude,
        lng: widget.point.longitude,
        title: _title.text,
        note: _note.text,
        photos: _photos,
        voice: _voice,
        voiceMs: _voiceMs,
      );
      Get.back();
      UiHelpers.success(
        _isPin ? 'Place saved for your ride.' : 'Memory added.',
        title: 'Saved',
      );
    } catch (e) {
      UiHelpers.error(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final double bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: <Widget>[
                  Icon(
                    _isPin ? Icons.push_pin_rounded : Icons.add_location_alt_rounded,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isPin ? 'Save a place' : 'Add a memory here',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _title,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: _isPin ? 'Place name' : 'Title (optional)',
                  prefixIcon: const Icon(Icons.label_outline_rounded),
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _note,
                minLines: 2,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),

              // --- Photos ---
              _PhotoStrip(
                photos: _photos,
                onRemove: (int i) => setState(() => _photos.removeAt(i)),
                onGallery: _addPhotos,
                onCamera: _takePhoto,
              ),
              const SizedBox(height: 16),

              // --- Voice ---
              VoiceRecorder(
                onRecorded: (File f, int ms) => setState(() {
                  _voice = f;
                  _voiceMs = ms;
                }),
                onCleared: () => setState(() {
                  _voice = null;
                  _voiceMs = null;
                }),
              ),
              const SizedBox(height: 22),

              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_rounded),
                  label: Text(_saving ? 'Saving…' : 'Save'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Horizontal strip of picked photos with add-from-gallery / camera buttons.
class _PhotoStrip extends StatelessWidget {
  final List<File> photos;
  final void Function(int) onRemove;
  final VoidCallback onGallery;
  final VoidCallback onCamera;
  const _PhotoStrip({
    required this.photos,
    required this.onRemove,
    required this.onGallery,
    required this.onCamera,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Photos',
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 84,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: <Widget>[
              _addTile(scheme, Icons.photo_library_rounded, 'Gallery', onGallery),
              const SizedBox(width: 8),
              _addTile(scheme, Icons.photo_camera_rounded, 'Camera', onCamera),
              const SizedBox(width: 8),
              for (int i = 0; i < photos.length; i++) ...<Widget>[
                _thumb(photos[i], () => onRemove(i)),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _addTile(
    ColorScheme scheme,
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 74,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, color: scheme.primary, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.poppins(fontSize: 10, color: scheme.onSurface),
            ),
          ],
        ),
      ),
    );
  }

  Widget _thumb(File file, VoidCallback onRemove) {
    return Stack(
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            file,
            width: 84,
            height: 84,
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          top: 2,
          right: 2,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(2),
              child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
            ),
          ),
        ),
      ],
    );
  }
}
