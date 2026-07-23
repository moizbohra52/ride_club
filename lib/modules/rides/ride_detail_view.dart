import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/ui_helpers.dart';
import '../../models/join_request.dart';
import '../../models/ride_member.dart';
import '../../routes/app_routes.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/loading_overlay.dart';
import '../../widgets/status_badge.dart';
import '../ride_map/memories/trip_memories_view.dart';
import 'member_detail_sheet.dart';
import 'ride_detail_controller.dart';

class RideDetailView extends GetView<RideDetailController> {
  const RideDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final ride = controller.ride.value;
      return Scaffold(
        appBar: AppBar(
          title: Text(ride?.name ?? 'Ride'),
          actions: <Widget>[
            if (controller.amHost && (ride?.isActive ?? false))
              IconButton(
                tooltip: 'Edit ride',
                onPressed: controller.edit,
                icon: const Icon(Icons.edit_rounded),
              ),
            IconButton(
              tooltip: 'Trip memories',
              onPressed: () => Get.to<void>(
                () => TripMemoriesView(
                  rideId: controller.rideId,
                  isHost: controller.amHost,
                ),
              ),
              icon: const Icon(Icons.photo_album_outlined),
            ),
            _chatAction(),
            IconButton(
              tooltip: 'Share invite link',
              onPressed: controller.share,
              icon: const Icon(Icons.share_rounded),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: SafeArea(
          top: false,
          child: LoadingOverlay(
            isLoading: controller.busy.value,
            child: ride == null
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: <Widget>[
                      _codeCard(
                        context,
                        ride.code,
                        ride.destinationLabel,
                        ride.isActive,
                      ),
                      if (ride.isActive) ...<Widget>[
                        const SizedBox(height: 16),
                        _actionRow(context),
                      ],
                      const SizedBox(height: 22),
                      if (controller.amHost) ...<Widget>[
                        Obx(
                          () => controller.requests.isEmpty
                              ? const SizedBox.shrink()
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    _sectionTitle(
                                      context,
                                      'Requests',
                                      count: controller.requests.length,
                                      accent: true,
                                    ),
                                    const SizedBox(height: 10),
                                    _RequestsCard(
                                      requests: controller.requests.toList(),
                                    ),
                                    const SizedBox(height: 22),
                                  ],
                                ),
                        ),
                      ],
                      Obx(
                        () => _sectionTitle(
                          context,
                          'Members',
                          count: controller.members.length,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Obx(
                        () => _MembersCard(members: controller.members.toList()),
                      ),
                      const SizedBox(height: 24),
                      if (controller.amHost && ride.isActive) ...<Widget>[
                        _dangerButton(
                          label: 'End ride',
                          icon: Icons.flag_rounded,
                          onTap: controller.endRide,
                        ),
                        const SizedBox(height: 10),
                      ],
                      if (controller.amHost)
                        _dangerButton(
                          label: 'Delete ride',
                          icon: Icons.delete_forever_rounded,
                          onTap: controller.delete,
                        ),
                      if (!controller.amHost)
                        _dangerButton(
                          label: 'Leave ride',
                          icon: Icons.logout_rounded,
                          onTap: controller.leave,
                        ),
                    ],
                  ),
          ),
        ),
      );
    });
  }

  /// Live map (primary) + SOS (compact secondary) on one row — keeps both above
  /// the fold without two full-height stacked buttons.
  Widget _actionRow(BuildContext context) => Row(
    children: <Widget>[
      Expanded(
        child: GradientButton(
          label: 'Open live map',
          icon: Icons.map_rounded,
          height: 50,
          onTap: () =>
              Get.toNamed(Routes.rideMap, arguments: controller.rideId),
        ),
      ),
      const SizedBox(width: 10),
      _SosButton(onTap: controller.sendSos),
    ],
  );

  Widget _codeCard(BuildContext ctx, String code, String dest, bool active) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 12, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppColors.brandGradient,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.primaryGlow,
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.place_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  dest,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!active)
                StatusBadge.label(
                  label: 'Ended',
                  color: Colors.white.withValues(alpha: 0.2),
                  textColor: Colors.white,
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'RIDE CODE',
            style: GoogleFonts.poppins(
              color: Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.5,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Flexible(
                child: SelectableText(
                  code,
                  maxLines: 1,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 5,
                  ),
                ),
              ),
              _CopyChip(code: code),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Share this code so friends can join.',
            style: GoogleFonts.poppins(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 11,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(
    BuildContext ctx,
    String t, {
    int? count,
    bool accent = false,
  }) {
    final ColorScheme scheme = Theme.of(ctx).colorScheme;
    return Row(
      children: <Widget>[
        Text(t, style: AppTypography.heading(ctx)),
        if (count != null) ...<Widget>[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: accent
                  ? AppColors.sos.withValues(alpha: 0.12)
                  : scheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: GoogleFonts.poppins(
                color: accent ? AppColors.sos : scheme.primary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _dangerButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) => OutlinedButton.icon(
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.danger,
      side: BorderSide(color: AppColors.danger.withValues(alpha: 0.5)),
      minimumSize: const Size.fromHeight(48),
    ),
    onPressed: onTap,
    icon: Icon(icon, size: 20),
    label: Text(label),
  );

  Widget _chatAction() => Obx(() {
    final int n = controller.unread.value;
    return Stack(
      alignment: Alignment.center,
      children: <Widget>[
        IconButton(
          tooltip: 'Ride chat',
          onPressed: () =>
              Get.toNamed(Routes.chat, arguments: controller.rideId),
          icon: const Icon(Icons.chat_bubble_outline_rounded),
        ),
        if (n > 0)
          Positioned(right: 6, top: 6, child: StatusBadge.count(count: n)),
      ],
    );
  });
}

/// A compact copy button that lives inside the code card.
class _CopyChip extends StatelessWidget {
  final String code;
  const _CopyChip({required this.code});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.18),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {
          HapticFeedback.lightImpact();
          Clipboard.setData(ClipboardData(text: code));
          UiHelpers.success('Ride code copied to clipboard', title: 'Copied');
        },
        child: const Padding(
          padding: EdgeInsets.all(10),
          child: Icon(Icons.copy_rounded, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

/// Compact square SOS button that pairs with the primary map button.
class _SosButton extends StatelessWidget {
  final VoidCallback onTap;
  const _SosButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.sos,
      borderRadius: BorderRadius.circular(25),
      elevation: 3,
      shadowColor: AppColors.sos.withValues(alpha: 0.4),
      child: InkWell(
        borderRadius: BorderRadius.circular(25),
        onTap: () {
          HapticFeedback.mediumImpact();
          onTap();
        },
        child: SizedBox(
          height: 50,
          width: 96,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Icon(Icons.sos_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 6),
              Text(
                'SOS',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A single surface holding all pending requests as thin rows with dividers —
/// replaces the stack of separate fat cards.
class _RequestsCard extends StatelessWidget {
  final List<JoinRequest> requests;
  const _RequestsCard({required this.requests});

  @override
  Widget build(BuildContext context) {
    return _ListSurface(
      children: <Widget>[
        for (int i = 0; i < requests.length; i++) ...<Widget>[
          if (i > 0) const _RowDivider(),
          _RequestRow(req: requests[i]),
        ],
      ],
    );
  }
}

class _RequestRow extends StatelessWidget {
  final JoinRequest req;
  const _RequestRow({required this.req});

  @override
  Widget build(BuildContext context) {
    final RideDetailController c = Get.find<RideDetailController>();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 20,
            backgroundImage: req.photoUrl != null
                ? CachedNetworkImageProvider(req.photoUrl!)
                : null,
            child: req.photoUrl == null
                ? const Icon(Icons.person, size: 20)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              req.name,
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () => c.accept(req),
            icon: const Icon(
              Icons.check_circle,
              color: AppColors.success,
              size: 26,
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () => c.reject(req),
            icon: const Icon(Icons.cancel, color: AppColors.danger, size: 26),
          ),
        ],
      ),
    );
  }
}

/// All members in one surface as tappable rows with dividers.
class _MembersCard extends StatelessWidget {
  final List<RideMember> members;
  const _MembersCard({required this.members});

  @override
  Widget build(BuildContext context) {
    return _ListSurface(
      children: <Widget>[
        for (int i = 0; i < members.length; i++) ...<Widget>[
          if (i > 0) const _RowDivider(),
          _MemberRow(member: members[i], index: i),
        ],
      ],
    );
  }
}

class _MemberRow extends StatelessWidget {
  final RideMember member;
  final int index;
  const _MemberRow({required this.member, required this.index});

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 260 + index * 50),
      curve: Curves.easeOut,
      builder: (BuildContext context, double t, Widget? child) => Opacity(
        opacity: t.clamp(0, 1),
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 8),
          child: child,
        ),
      ),
      child: InkWell(
        onTap: () => showMemberDetail(
          context,
          member: member,
          rideId: Get.find<RideDetailController>().rideId,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: <Widget>[
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: member.color, width: 2),
                ),
                padding: const EdgeInsets.all(2),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: member.color.withValues(alpha: 0.15),
                  backgroundImage: member.photoUrl != null
                      ? CachedNetworkImageProvider(member.photoUrl!)
                      : null,
                  child: member.photoUrl == null
                      ? Text(
                          member.name.isNotEmpty
                              ? member.name[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            color: member.color,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  member.name,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (member.isHost)
                StatusBadge.label(
                  label: 'Host',
                  color: scheme.primary.withValues(alpha: 0.12),
                  textColor: scheme.primary,
                )
              else
                Icon(
                  Icons.chevron_right_rounded,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shared rounded surface with soft border/shadow that hosts list rows.
class _ListSurface extends StatelessWidget {
  final List<Widget> children;
  const _ListSurface({required this.children});

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark ? scheme.surfaceContainerHigh : scheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: isDark ? 0.3 : 0.15),
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(children: children),
      ),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Divider(
      height: 1,
      thickness: 1,
      indent: 12,
      endIndent: 12,
      color: scheme.outlineVariant.withValues(alpha: 0.3),
    );
  }
}
