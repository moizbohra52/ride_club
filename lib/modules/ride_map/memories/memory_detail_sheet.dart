import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/utils/ui_helpers.dart';
import '../../../models/ride_memory.dart';
import '../../../services/auth_service.dart';
import '../../../services/ride_memory_service.dart';
import 'voice_player.dart';

/// Bottom sheet showing a single [RideMemory]: title, note, photo gallery,
/// voice playback, author + time, and a delete action for the author or host.
/// [isHost] lets a ride host delete anyone's memory.
void showMemoryDetail(
  BuildContext context, {
  required RideMemory memory,
  required String rideId,
  bool isHost = false,
}) {
  final ColorScheme scheme = Theme.of(context).colorScheme;
  final String? uid = Get.find<AuthService>().uid;
  final bool canDelete = memory.canDelete(uid, isHost: isHost);

  Get.bottomSheet(
    SafeArea(
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
                  memory.isPin
                      ? Icons.push_pin_rounded
                      : Icons.place_rounded,
                  color: scheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    (memory.title != null && memory.title!.isNotEmpty)
                        ? memory.title!
                        : (memory.isPin ? 'Saved place' : 'Trip memory'),
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (canDelete)
                  IconButton(
                    tooltip: 'Delete',
                    icon: Icon(Icons.delete_outline_rounded, color: scheme.error),
                    onPressed: () => _confirmDelete(rideId, memory),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            _AuthorLine(memory: memory),

            if (memory.note != null && memory.note!.isNotEmpty) ...<Widget>[
              const SizedBox(height: 14),
              Text(
                memory.note!,
                style: GoogleFonts.poppins(fontSize: 14, height: 1.4),
              ),
            ],

            if (memory.hasPhotos) ...<Widget>[
              const SizedBox(height: 16),
              _PhotoGallery(urls: memory.photoUrls),
            ],

            if (memory.hasVoice) ...<Widget>[
              const SizedBox(height: 16),
              VoicePlayer(url: memory.voiceUrl!, totalMs: memory.voiceMs),
            ],

            const SizedBox(height: 4),
          ],
        ),
      ),
    ),
    backgroundColor: scheme.surface,
    isScrollControlled: true,
  );
}

Future<void> _confirmDelete(String rideId, RideMemory memory) async {
  final bool ok = await UiHelpers.confirm(
    title: 'Delete memory?',
    message: 'This removes it for everyone in the ride. This cannot be undone.',
    confirmText: 'Delete',
    destructive: true,
  );
  if (!ok) return;
  try {
    await Get.find<RideMemoryService>().deleteMemory(rideId, memory.id);
    Get.back(); // close the detail sheet
    UiHelpers.success('Memory deleted.', title: 'Removed');
  } catch (e) {
    UiHelpers.error(e.toString().replaceFirst('Exception: ', ''));
  }
}

class _AuthorLine extends StatelessWidget {
  final RideMemory memory;
  const _AuthorLine({required this.memory});

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Row(
      children: <Widget>[
        CircleAvatar(
          radius: 12,
          backgroundColor: scheme.primaryContainer,
          backgroundImage: memory.authorPhoto != null
              ? CachedNetworkImageProvider(memory.authorPhoto!)
              : null,
          child: memory.authorPhoto == null
              ? Text(
                  memory.authorName.isNotEmpty
                      ? memory.authorName[0].toUpperCase()
                      : '?',
                  style: TextStyle(fontSize: 11, color: scheme.onPrimaryContainer),
                )
              : null,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            memory.createdAt != null
                ? '${memory.authorName} · ${_timeAgo(memory.createdAt!)}'
                : memory.authorName,
            style: GoogleFonts.poppins(
              fontSize: 12.5,
              color: scheme.onSurfaceVariant,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  static String _timeAgo(DateTime d) {
    final Duration diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    const List<String> m = <String>[
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${m[d.month - 1]} ${d.day}, ${d.year}';
  }
}

/// A horizontally-scrolling gallery; tapping a photo opens a full-screen
/// zoomable viewer.
class _PhotoGallery extends StatelessWidget {
  final List<String> urls;
  const _PhotoGallery({required this.urls});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 160,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: urls.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (BuildContext context, int i) {
          return GestureDetector(
            onTap: () => _openViewer(context, urls, i),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: urls[i],
                width: 160,
                height: 160,
                fit: BoxFit.cover,
                placeholder: (_, _) => Container(
                  width: 160,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                errorWidget: (_, _, _) => const SizedBox(
                  width: 160,
                  child: Icon(Icons.broken_image_outlined),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _openViewer(BuildContext context, List<String> urls, int index) {
    Get.to<void>(() => _PhotoViewer(urls: urls, initialIndex: index));
  }
}

/// Full-screen, swipeable, pinch-to-zoom photo viewer.
class _PhotoViewer extends StatelessWidget {
  final List<String> urls;
  final int initialIndex;
  const _PhotoViewer({required this.urls, required this.initialIndex});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: PageView.builder(
        controller: PageController(initialPage: initialIndex),
        itemCount: urls.length,
        itemBuilder: (BuildContext context, int i) {
          return InteractiveViewer(
            minScale: 1,
            maxScale: 4,
            child: Center(
              child: CachedNetworkImage(
                imageUrl: urls[i],
                fit: BoxFit.contain,
                placeholder: (_, _) =>
                    const CircularProgressIndicator(color: Colors.white),
                errorWidget: (_, _, _) =>
                    const Icon(Icons.broken_image_outlined, color: Colors.white),
              ),
            ),
          );
        },
      ),
    );
  }
}
