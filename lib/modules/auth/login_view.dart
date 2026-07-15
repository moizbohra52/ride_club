import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../widgets/loading_overlay.dart';
import 'auth_controller.dart';

/// Google sign-in screen — the app's only entry point to auth.
///
/// Signature: a full-bleed "dawn horizon" gradient hero with a faint route
/// line and location pins, so the very first screen already speaks the app's
/// language of maps and journeys. The sign-in card sits calmly below it.
class LoginView extends GetView<AuthController> {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Obx(
        () => LoadingOverlay(
          isLoading: controller.busy.value,
          message: 'Signing you in…',
          child: Column(
            children: <Widget>[
              // ---- Hero: horizon gradient + route motif ----
              Expanded(flex: 5, child: _HorizonHero()),
              // ---- Sign-in card ----
              Expanded(
                flex: 4,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Text(
                          'Ride as one.',
                          style: Theme.of(context).textTheme.headlineLarge,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'See every friend on the map, chat live, and never '
                          'lose the group on the road.',
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(fontSize: 15),
                        ),
                        const Spacer(),
                        _GoogleButton(onPressed: controller.signInWithGoogle),
                        const SizedBox(height: 14),
                        Text(
                          'We only use your Google name and photo to show you '
                          'to your ride group.',
                          textAlign: TextAlign.center,
                          style: Theme.of(
                            context,
                          ).textTheme.labelSmall?.copyWith(letterSpacing: 0),
                        ),
                      ],
                    ),
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

/// The dawn-horizon gradient hero with an app wordmark, a faint dashed route,
/// and two location pins — the app's signature moment.
class _HorizonHero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppColors.brandGradient,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // Faint route + pins painted behind the wordmark.
          Positioned.fill(child: CustomPaint(painter: _RouteMotifPainter())),
          // Subtle radial glow behind content.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.3, 0.2),
                  radius: 1.2,
                  colors: <Color>[
                    Colors.white.withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        height: 46,
                        width: 46,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.35),
                          ),
                        ),
                        child: const Icon(
                          Icons.explore_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'RideClub',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                  // Big statement mark.
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Your crew,',
                        style: GoogleFonts.poppins(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 36,
                          height: 1.05,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1,
                        ),
                      ),
                      Text(
                        'on one map.',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 36,
                          height: 1.05,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Draws a faint dashed route curving across the hero with two map pins,
/// evoking a planned trip. Purely decorative, low-opacity white.
class _RouteMotifPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint route = Paint()
      ..color = Colors.white.withValues(alpha: 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final Path path = Path()
      ..moveTo(size.width * 0.12, size.height * 0.78)
      ..cubicTo(
        size.width * 0.35,
        size.height * 0.62,
        size.width * 0.30,
        size.height * 0.42,
        size.width * 0.55,
        size.height * 0.38,
      )
      ..cubicTo(
        size.width * 0.82,
        size.height * 0.33,
        size.width * 0.78,
        size.height * 0.16,
        size.width * 0.92,
        size.height * 0.10,
      );

    // Dashed stroke.
    _drawDashed(canvas, path, route, dash: 12, gap: 9);

    // Start & end pins.
    _pin(
      canvas,
      Offset(size.width * 0.12, size.height * 0.78),
      7,
      Colors.white.withValues(alpha: 0.9),
    );
    _pin(
      canvas,
      Offset(size.width * 0.92, size.height * 0.10),
      7,
      AppColors.sunset,
    );
  }

  void _pin(Canvas canvas, Offset c, double r, Color color) {
    canvas.drawCircle(
      c,
      r + 4,
      Paint()..color = Colors.white.withValues(alpha: 0.25),
    );
    canvas.drawCircle(c, r, Paint()..color = color);
  }

  void _drawDashed(
    Canvas canvas,
    Path source,
    Paint paint, {
    required double dash,
    required double gap,
  }) {
    for (final ui in source.computeMetrics()) {
      double dist = 0;
      while (dist < ui.length) {
        final double next = math.min(dist + dash, ui.length);
        canvas.drawPath(ui.extractPath(dist, next), paint);
        dist = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// A branded "Continue with Google" button (self-contained, no network asset).
class _GoogleButton extends StatefulWidget {
  final VoidCallback onPressed;
  const _GoogleButton({required this.onPressed});

  @override
  State<_GoogleButton> createState() => _GoogleButtonState();
}

class _GoogleButtonState extends State<_GoogleButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scaleCtrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: 0.96,
    ).animate(CurvedAnimation(parent: _scaleCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _scale,
      builder: (BuildContext context, Widget? child) {
        return Transform.scale(scale: _scale.value, child: child);
      },
      child: GestureDetector(
        onTapDown: (_) => _scaleCtrl.forward(),
        onTapUp: (_) {
          _scaleCtrl.reverse();
          widget.onPressed();
        },
        onTapCancel: () => _scaleCtrl.reverse(),
        child: Container(
          height: 58,
          decoration: BoxDecoration(
            color: scheme.onSurface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: scheme.onSurface.withValues(alpha: 0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const _GoogleGlyph(size: 22),
              const SizedBox(width: 12),
              Text(
                'Continue with Google',
                style: GoogleFonts.poppins(
                  color: scheme.surface,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The multicolor Google "G" drawn with a CustomPainter — no image asset, so
/// it renders identically offline and in both themes.
class _GoogleGlyph extends StatelessWidget {
  final double size;
  const _GoogleGlyph({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GoogleGlyphPainter()),
    );
  }
}

class _GoogleGlyphPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final Rect rect = Rect.fromLTWH(0, 0, w, h);
    final double stroke = w * 0.22;
    final Rect arcRect = rect.deflate(stroke / 2);
    final Paint p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    void arc(double startDeg, double sweepDeg, Color c) {
      p.color = c;
      canvas.drawArc(
        arcRect,
        startDeg * math.pi / 180,
        sweepDeg * math.pi / 180,
        false,
        p,
      );
    }

    arc(-10, -80, const Color(0xFFEA4335)); // red
    arc(-90, -80, const Color(0xFFFBBC05)); // yellow
    arc(170, -80, const Color(0xFF34A853)); // green
    arc(90, -80, const Color(0xFF4285F4)); // blue

    final Paint bar = Paint()..color = const Color(0xFF4285F4);
    canvas.drawRect(Rect.fromLTWH(w * 0.52, h * 0.42, w * 0.46, stroke), bar);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
