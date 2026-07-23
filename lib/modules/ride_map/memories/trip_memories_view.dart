import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/ride_memory.dart';
import '../../../services/ride_memory_service.dart';
import 'memory_detail_sheet.dart';

/// A chronological list of a ride's shared memories (pins + logs). Opened from
/// the Ride Detail app bar. Tapping a row opens the same detail sheet used on
/// the map. [isHost] lets the host delete any memory from the detail sheet.
class TripMemoriesView extends StatelessWidget {
  final String rideId;
  final bool isHost;
  const TripMemoriesView({super.key, required this.rideId, this.isHost = false});

  @override
  Widget build(BuildContext context) {
    final RideMemoryService service = Get.find<RideMemoryService>();
    return Scaffold(
      appBar: AppBar(title: const Text('Trip memories')),
      body: SafeArea(
        top: false,
        child: StreamBuilder<List<RideMemory>>(
          stream: service.watch(rideId),
          builder: (BuildContext context, AsyncSnapshot<List<RideMemory>> snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final List<RideMemory> items = snap.data ?? const <RideMemory>[];
            if (items.isEmpty) return _empty(context);
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (BuildContext context, int i) => _MemoryTile(
                memory: items[i],
                onTap: () => showMemoryDetail(
                  context,
                  memory: items[i],
                  rideId: rideId,
                  isHost: isHost,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _empty(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              height: 80,
              width: 80,
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                Icons.photo_album_rounded,
                size: 40,
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 20),
            Text('No memories yet', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Open the live map, long-press a spot to save a place, or tap '
              '“Add a memory here” to capture notes, photos, and voice notes.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _MemoryTile extends StatelessWidget {
  final RideMemory memory;
  final VoidCallback onTap;
  const _MemoryTile({required this.memory, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark ? scheme.surfaceContainerHigh : scheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: isDark ? 0.3 : 0.15),
            ),
          ),
          child: Row(
            children: <Widget>[
              _leading(scheme),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      _titleText,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 12.5,
                        color: scheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              _badges(scheme),
            ],
          ),
        ),
      ),
    );
  }

  String get _titleText {
    if (memory.title != null && memory.title!.isNotEmpty) return memory.title!;
    if (memory.note != null && memory.note!.isNotEmpty) return memory.note!;
    return memory.isPin ? 'Saved place' : 'Trip memory';
  }

  String get _subtitle => 'by ${memory.authorName}';

  Widget _leading(ColorScheme scheme) {
    if (memory.hasPhotos) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: CachedNetworkImage(
          imageUrl: memory.photoUrls.first,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          placeholder: (_, _) => Container(
            width: 48,
            height: 48,
            color: scheme.surfaceContainerHighest,
          ),
          errorWidget: (_, _, _) => _iconLeading(scheme),
        ),
      );
    }
    return _iconLeading(scheme);
  }

  Widget _iconLeading(ColorScheme scheme) => Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          memory.isPin ? Icons.push_pin_rounded : Icons.sticky_note_2_rounded,
          color: scheme.onPrimaryContainer,
          size: 22,
        ),
      );

  Widget _badges(ColorScheme scheme) {
    final List<Widget> chips = <Widget>[];
    if (memory.hasVoice) {
      chips.add(Icon(Icons.mic_rounded, size: 18, color: scheme.primary));
    }
    if (memory.photoUrls.length > 1) {
      chips.add(
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            '+${memory.photoUrls.length - 1}',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    if (chips.isEmpty) {
      return Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant);
    }
    return Row(mainAxisSize: MainAxisSize.min, children: chips);
  }
}
