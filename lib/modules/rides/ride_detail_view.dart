import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../models/join_request.dart';
import '../../models/ride_member.dart';
import '../../routes/app_routes.dart';
import '../../widgets/app_card.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/loading_overlay.dart';
import '../../widgets/status_badge.dart';
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
            _chatAction(),
            IconButton(
              tooltip: 'Share invite link',
              onPressed: controller.share,
              icon: const Icon(Icons.share_rounded),
            ),
          ],
        ),
        body: SafeArea(
          top: false, // AppBar handles top
          child: LoadingOverlay(
            isLoading: controller.busy.value,
            child: ride == null
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    children: <Widget>[
                      _codeCard(
                        context,
                        ride.code,
                        ride.destinationLabel,
                        ride.isActive,
                      ),
                      if (ride.isActive) ...<Widget>[
                        const SizedBox(height: AppSpacing.xl),
                        GradientButton(
                          label: 'Open live map',
                          icon: Icons.map_rounded,
                          onTap: () => Get.toNamed(
                            Routes.rideMap,
                            arguments: controller.rideId,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        OutlinedButton.icon(
                          onPressed: controller.sendSos,
                          icon: const Icon(
                            Icons.sos_rounded,
                            color: Colors.white,
                          ),
                          label: const Text(
                            'Send SOS',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: AppColors.sos,
                            foregroundColor: Colors.white,
                            side: BorderSide.none,
                            minimumSize: const Size.fromHeight(54),
                            elevation: 4,
                            shadowColor: AppColors.sos.withValues(alpha: 0.3),
                          ),
                        ),
                      ],
                      const SizedBox(height: 28),
                      if (controller.amHost) ...<Widget>[
                        _sectionTitle(context, 'Pending requests'),
                        Obx(
                          () => controller.requests.isEmpty
                              ? _muted(context, 'No pending requests')
                              : Column(
                                  children: controller.requests
                                      .map((r) => _RequestTile(req: r))
                                      .toList(),
                                ),
                        ),
                        const SizedBox(height: 28),
                      ],
                      Obx(
                        () => _sectionTitle(
                          context,
                          'Members (${controller.members.length})',
                        ),
                      ),
                      Obx(
                        () => Column(
                          children: <Widget>[
                            for (int i = 0; i < controller.members.length; i++)
                              _MemberTile(
                                member: controller.members[i],
                                index: i,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),
                      if (controller.amHost && ride.isActive)
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.danger,
                            side: const BorderSide(color: AppColors.danger),
                            minimumSize: const Size.fromHeight(54),
                          ),
                          onPressed: controller.endRide,
                          icon: const Icon(Icons.flag_rounded),
                          label: const Text('End ride'),
                        ),
                      if (!controller.amHost)
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.danger,
                            side: const BorderSide(color: AppColors.danger),
                            minimumSize: const Size.fromHeight(54),
                          ),
                          onPressed: controller.leave,
                          icon: const Icon(Icons.logout_rounded),
                          label: const Text('Leave ride'),
                        ),
                    ],
                  ),
          ),
        ),
      );
    });
  }

  Widget _codeCard(BuildContext ctx, String code, String dest, bool active) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppColors.brandGradient,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.primaryGlow,
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.place_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  dest,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
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
          const SizedBox(height: 20),
          Text(
            'RIDE CODE',
            style: GoogleFonts.poppins(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.5,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SelectableText(
                code,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 6,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded, color: Colors.white70),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: code));
                  Get.snackbar(
                    'Copied',
                    'Ride code copied to clipboard!',
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: Colors.black.withValues(alpha: 0.8),
                    colorText: Colors.white,
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext ctx, String t) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md, left: AppSpacing.xs),
    child: Text(t, style: AppTypography.heading(ctx)),
  );

  Widget _muted(BuildContext ctx, String t) => Padding(
    padding: const EdgeInsets.symmetric(
      vertical: AppSpacing.md,
      horizontal: AppSpacing.xs,
    ),
    child: Text(t, style: AppTypography.body(ctx)),
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

class _RequestTile extends StatelessWidget {
  final JoinRequest req;

  const _RequestTile({required this.req});

  @override
  Widget build(BuildContext context) {
    final RideDetailController c = Get.find<RideDetailController>();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          children: <Widget>[
            CircleAvatar(
              backgroundImage: req.photoUrl != null
                  ? CachedNetworkImageProvider(req.photoUrl!)
                  : null,
              child: req.photoUrl == null ? const Icon(Icons.person) : null,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                req.name,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            IconButton(
              onPressed: () => c.accept(req),
              icon: const Icon(
                Icons.check_circle,
                color: AppColors.success,
                size: 28,
              ),
            ),
            IconButton(
              onPressed: () => c.reject(req),
              icon: const Icon(Icons.cancel, color: AppColors.danger, size: 28),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  final RideMember member;
  final int index;

  const _MemberTile({required this.member, this.index = 0});

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    // Staggered fade+slide entrance, offset by list index.
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + index * 60),
      curve: Curves.easeOut,
      builder: (BuildContext context, double t, Widget? child) => Opacity(
        opacity: t.clamp(0, 1),
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 12),
          child: child,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: AppCard(
          onTap: () => showMemberDetail(
            context,
            member: member,
            rideId: Get.find<RideDetailController>().rideId,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            children: <Widget>[
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: member.color.withValues(alpha: 0.6),
                    width: 2.5,
                  ),
                ),
                child: CircleAvatar(
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
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  member.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              if (member.isHost)
                StatusBadge.label(
                  label: 'Host',
                  color: scheme.primaryContainer,
                  textColor: scheme.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
