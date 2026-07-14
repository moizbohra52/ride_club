import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../models/chat_message.dart';
import 'chat_controller.dart';

class ChatView extends GetView<ChatController> {
  const ChatView({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Ride chat')),
      body: Column(
        children: <Widget>[
          Expanded(
            child: Obx(() {
              final List<ChatMessage> msgs = controller.messages;
              if (msgs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer.withValues(alpha: 0.4),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.chat_bubble_outline_rounded,
                            size: 36, color: scheme.primary),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Say hi to your crew 👋',
                        style: GoogleFonts.poppins(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              }
              return ListView.builder(
                reverse: true,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: msgs.length,
                itemBuilder: (_, int i) {
                  final ChatMessage m = msgs[msgs.length - 1 - i];
                  return _Bubble(
                    msg: m,
                    mine: m.isMine(controller.uid ?? ''),
                    memberCount: controller.memberCount.value,
                  );
                },
              );
            }),
          ),
          Obx(() {
            if (controller.typingUids.isEmpty) return const SizedBox.shrink();
            return Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      height: 10,
                      width: 10,
                      child: CircularProgressIndicator(strokeWidth: 1.5),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Someone is typing…',
                      style: GoogleFonts.poppins(
                        color: scheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          _composer(context, scheme, isDark),
        ],
      ),
    );
  }

  Widget _composer(BuildContext context, ColorScheme scheme, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? scheme.surface : Colors.white,
        border: Border(
          top: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: isDark ? 0.3 : 0.15),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          child: Row(
            children: <Widget>[
              Obx(
                () => IconButton(
                  onPressed:
                      controller.sending.value ? null : controller.sendMyLocation,
                  icon: const Icon(Icons.add_location_alt_outlined),
                  color: scheme.primary,
                  tooltip: 'Send my location',
                ),
              ),
              Expanded(
                child: TextField(
                  controller: controller.input,
                  onChanged: controller.onChanged,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => controller.send(),
                  minLines: 1,
                  maxLines: 4,
                  style: GoogleFonts.poppins(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Message…',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    filled: true,
                    fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                onPressed: controller.send,
                icon: const Icon(Icons.send_rounded),
                color: Colors.white,
                style: IconButton.styleFrom(
                  backgroundColor: scheme.primary,
                  padding: const EdgeInsets.all(10),
                  elevation: 2,
                  shadowColor: AppColors.primaryGlow,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final ChatMessage msg;
  final bool mine;
  final int memberCount;
  const _Bubble({
    required this.msg,
    required this.mine,
    required this.memberCount,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final Color bg = mine ? scheme.primary : (isDark ? scheme.surfaceContainerHigh : scheme.surfaceContainerHighest.withValues(alpha: 0.8));
    final Color fg = mine ? Colors.white : scheme.onSurface;

    return Column(
      crossAxisAlignment:
          mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: <Widget>[
        if (!mine)
          Padding(
            padding: const EdgeInsets.only(left: 10, top: 8, bottom: 4),
            child: Text(
              msg.senderName,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: scheme.primary,
              ),
            ),
          ),
        Container(
          margin: const EdgeInsets.symmetric(vertical: 2),
          constraints: const BoxConstraints(maxWidth: 290),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(mine ? 16 : 4),
              bottomRight: Radius.circular(mine ? 4 : 16),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: msg.isLocation
              ? _locationContent(context, fg)
              : Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                  child: Text(
                    msg.text ?? '',
                    style: GoogleFonts.poppins(
                      color: fg,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 8, right: 8, bottom: 8, top: 2),
          child: Text(
            mine ? '${msg.timeText} · ${_seen()}' : msg.timeText,
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w400,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ),
      ],
    );
  }

  String _seen() {
    final int n = msg.seenByCount;
    if (n <= 0) return 'Sent';
    if (memberCount > 1 && n >= memberCount - 1) return 'Seen';
    return 'Seen by $n';
  }

  Widget _locationContent(BuildContext context, Color fg) {
    final LatLng point = LatLng(msg.lat ?? 0, msg.lng ?? 0);
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => _openFull(point),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 230,
            height: 140,
            child: AbsorbPointer(
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: point,
                  initialZoom: 15,
                  interactionOptions:
                      const InteractionOptions(flags: InteractiveFlag.none),
                ),
                children: <Widget>[
                  TileLayer(
                    urlTemplate: AppConstants.osmTileUrl,
                    userAgentPackageName: AppConstants.userAgentPackageName,
                  ),
                  MarkerLayer(
                    markers: <Marker>[
                      Marker(
                        point: point,
                        width: 38,
                        height: 38,
                        child: const Icon(Icons.location_on,
                            color: AppColors.sos, size: 38),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Container(
            width: 230,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: mine ? scheme.primaryContainer : scheme.surfaceContainerHighest,
            child: Row(
              children: [
                Icon(Icons.map_rounded, size: 16, color: mine ? scheme.onPrimaryContainer : scheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tap to view map',
                    style: GoogleFonts.poppins(
                      color: mine ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openFull(LatLng point) {
    Get.dialog(
      Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 440,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                FlutterMap(
                  options: MapOptions(initialCenter: point, initialZoom: 15),
                  children: <Widget>[
                    TileLayer(
                      urlTemplate: AppConstants.osmTileUrl,
                      userAgentPackageName: AppConstants.userAgentPackageName,
                    ),
                    MarkerLayer(
                      markers: <Marker>[
                        Marker(
                          point: point,
                          width: 44,
                          height: 44,
                          child: const Icon(Icons.location_on,
                              color: AppColors.sos, size: 44),
                        ),
                      ],
                    ),
                    RichAttributionWidget(
                      attributions: <SourceAttribution>[
                        TextSourceAttribution('OpenStreetMap contributors',
                            onTap: () {}),
                      ],
                    ),
                  ],
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: CircleAvatar(
                    backgroundColor: Colors.black.withValues(alpha: 0.5),
                    child: IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                      onPressed: () => Get.back(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
