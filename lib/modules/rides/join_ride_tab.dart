import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/loading_overlay.dart';
import '../../widgets/primary_button.dart';
import 'join_ride_controller.dart';

class JoinRideTab extends StatelessWidget {
  const JoinRideTab({super.key});

  @override
  Widget build(BuildContext context) {
    final JoinRideController c = Get.put(JoinRideController());
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Obx(() {
      if (c.myRequest.value != null) return _statusView(context, c, scheme, isDark);
      return LoadingOverlay(
        isLoading: c.submitting.value,
        message: 'Sending request…',
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // Header with icon
                Row(
                  children: <Widget>[
                    Container(
                      height: 40,
                      width: 40,
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.group_add_rounded,
                          size: 20, color: scheme.primary),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Enter ride code',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'Ask the host for their 6-character code to join the group ride.',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 32),
                PinCodeTextField(
                  appContext: context,
                  length: 6,
                  autoFocus: true,
                  textCapitalization: TextCapitalization.characters,
                  onChanged: (String v) => c.code.value = v.toUpperCase(),
                  textStyle: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface,
                  ),
                  pinTheme: PinTheme(
                    shape: PinCodeFieldShape.box,
                    borderRadius: BorderRadius.circular(12),
                    fieldHeight: 56,
                    fieldWidth: 46,
                    activeColor: scheme.primary,
                    selectedColor: scheme.primary,
                    inactiveColor: scheme.outlineVariant.withValues(alpha: 0.5),
                    activeFillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.2),
                    selectedFillColor: scheme.primaryContainer.withValues(alpha: 0.2),
                    inactiveFillColor: Colors.transparent,
                  ),
                ),
                const SizedBox(height: 32),
                PrimaryButton(
                  label: 'Request to join',
                  icon: Icons.group_add_rounded,
                  onPressed: c.submit,
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _statusView(
      BuildContext ctx, JoinRideController c, ColorScheme scheme, bool isDark) {
    final req = c.myRequest.value!;
    final IconData icon;
    final String title;
    final String sub;
    final Color statusColor;

    if (req.isAccepted) {
      icon = Icons.check_circle_rounded;
      title = "You're in!";
      sub = 'The host accepted your request. Have a safe journey!';
      statusColor = AppColors.success;
    } else if (req.isRejected) {
      icon = Icons.cancel_rounded;
      title = 'Request declined';
      sub = 'The host declined this request. Reach out to the host or try again.';
      statusColor = AppColors.danger;
    } else {
      icon = Icons.hourglass_top_rounded;
      title = 'Waiting for approval';
      sub = 'The host has been notified. We will update you once they let you in.';
      statusColor = AppColors.warning;
    }

    return SafeArea(
      top: false,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
            decoration: BoxDecoration(
              color: isDark ? scheme.surfaceContainerHigh : scheme.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: isDark ? 0.3 : 0.15),
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.3)
                      : AppColors.primaryGlow.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // Animated pulse indicator
                _AnimatedPulseIcon(icon: icon, color: statusColor),
                const SizedBox(height: 24),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  sub,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: scheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 36),
                if (req.isAccepted) ...<Widget>[
                  PrimaryButton(
                    label: 'Open ride',
                    icon: Icons.arrow_forward_rounded,
                    onPressed: c.openRide,
                  ),
                  const SizedBox(height: 12),
                ],
                if (req.isRejected || req.isAccepted)
                  TextButton(
                    onPressed: c.reset,
                    style: TextButton.styleFrom(
                      foregroundColor: scheme.primary,
                      textStyle: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: const Text('Join a different ride'),
                  )
                else
                  // Hourglass subtle spinner
                  const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedPulseIcon extends StatefulWidget {
  final IconData icon;
  final Color color;

  const _AnimatedPulseIcon({required this.icon, required this.color});

  @override
  State<_AnimatedPulseIcon> createState() => _AnimatedPulseIconState();
}

class _AnimatedPulseIconState extends State<_AnimatedPulseIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _scale = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scale,
      builder: (BuildContext context, Widget? child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Outward pulse halo
            Transform.scale(
              scale: _scale.value,
              child: Container(
                height: 72,
                width: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color.withValues(alpha: 1.0 - _pulseCtrl.value),
                ),
              ),
            ),
            child!,
          ],
        );
      },
      child: Container(
        height: 72,
        width: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color.withValues(alpha: 0.15),
        ),
        child: Icon(
          widget.icon,
          size: 40,
          color: widget.color,
        ),
      ),
    );
  }
}
