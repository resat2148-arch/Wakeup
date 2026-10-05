import 'dart:math';

import 'package:flutter/material.dart';

import '../theme.dart';

/// Gece → gün doğumu sahnesi: yıldızlar söner, güneş tepelerin ardından
/// yükselir, ışınlar ve bulutlar belirir.
///
/// [progress] 0 iken gece, 0.3 civarında güneş ufukta, 1 iken güneş
/// gökyüzünün üst kısmında. Değişiklikler yumuşakça canlandırılır.
class SunriseBackground extends StatefulWidget {
  const SunriseBackground({
    super.key,
    required this.progress,
    this.animate = true,
    this.child,
  });

  final double progress;

  /// Işınların dönmesi, yıldızların parlaması ve bulutların kayması.
  final bool animate;
  final Widget? child;

  @override
  State<SunriseBackground> createState() => _SunriseBackgroundState();
}

class _SunriseBackgroundState extends State<SunriseBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ambient = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 90),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAmbient();
  }

  @override
  void didUpdateWidget(SunriseBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAmbient();
  }

  void _syncAmbient() {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (widget.animate && !reduceMotion) {
      if (!_ambient.isAnimating) _ambient.repeat();
    } else {
      _ambient.stop();
    }
  }

  @override
  void dispose() {
    _ambient.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: widget.progress.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 2400),
      curve: Curves.easeInOut,
      builder: (context, sun, child) => AnimatedBuilder(
        animation: _ambient,
        builder: (context, child) => CustomPaint(
          painter: SunrisePainter(sun: sun, phase: _ambient.value),
          child: child,
        ),
        child: child,
      ),
      child: widget.child,
    );
  }
}

/// Sahneyi çizen ressam. [phase] 0–1 arası döngüsel ortam animasyonudur.
class SunrisePainter extends CustomPainter {
  SunrisePainter({required this.sun, required this.phase});

  final double sun;
  final double phase;

  static final List<_Star> _stars = _makeStars();

  static List<_Star> _makeStars() {
    final rnd = Random(7);
    return List.generate(
      70,
      (_) => _Star(
        rnd.nextDouble(),
        rnd.nextDouble() * 0.65,
        rnd.nextDouble() < 0.15 ? 1.6 : 0.6 + rnd.nextDouble() * 0.6,
        rnd.nextDouble(),
      ),
    );
  }

  Color _mix(Color a, Color b) => Color.lerp(a, b, sun)!;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    _paintSky(canvas, rect);
    _paintStars(canvas, size);
    _paintHorizonGlow(canvas, size);
    _paintSun(canvas, size);
    _paintClouds(canvas, size);
    _paintHills(canvas, size);
  }

  void _paintSky(Canvas canvas, Rect rect) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          _mix(nightIndigo, const Color(0xFF2F6DB5)),
          _mix(dawnPurple, const Color(0xFFF08A5D)),
          _mix(const Color(0xFFC4573A), const Color(0xFFFFB85C)),
          _mix(sunriseOrange, sunriseGold),
        ],
        stops: const [0, 0.58, 0.78, 1],
      ).createShader(rect);
    canvas.drawRect(rect, paint);
  }

  void _paintStars(Canvas canvas, Size size) {
    final visibility = (1 - sun * 2.4).clamp(0.0, 1.0);
    if (visibility == 0) return;
    final paint = Paint();
    for (final star in _stars) {
      final twinkle =
          0.45 + 0.55 * (0.5 + 0.5 * sin((phase * 30 + star.seed) * 2 * pi));
      paint.color = Colors.white.withValues(alpha: visibility * twinkle);
      canvas.drawCircle(
        Offset(star.x * size.width, star.y * size.height),
        star.radius,
        paint,
      );
    }
  }

  void _paintHorizonGlow(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.92);
    final radius = size.height * (0.45 + sun * 0.25);
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFD678).withValues(alpha: 0.15 + sun * 0.6),
          const Color(0xFFFF9650).withValues(alpha: sun * 0.3),
          const Color(0x00FF9650),
        ],
        stops: const [0, 0.45, 1],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, paint);
  }

  /// Güneşin merkezi: sun=0'da tepelerin arkasında, 1'de üst üçte birde.
  Offset _sunCenter(Size size) =>
      Offset(size.width / 2, size.height * (0.94 - sun * 0.62));

  double _sunRadius(Size size) => min(size.shortestSide * 0.26, 130);

  void _paintSun(Canvas canvas, Size size) {
    final c = _sunCenter(size);
    final r = _sunRadius(size);

    // Işınlar
    final rayOpacity = (sun * 1.6 - 0.25).clamp(0.0, 1.0);
    if (rayOpacity > 0) {
      final rayLength = r * 3.2;
      final rayPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFECAA).withValues(alpha: 0.38 * rayOpacity),
            const Color(0x00FFECAA),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: rayLength));
      const rays = 24;
      final rotation = phase * 2 * pi;
      for (var i = 0; i < rays; i++) {
        final a = rotation + i * 2 * pi / rays;
        final halfWidth = pi / rays / 3;
        final path = Path()
          ..moveTo(c.dx, c.dy)
          ..lineTo(
            c.dx + cos(a - halfWidth) * rayLength,
            c.dy + sin(a - halfWidth) * rayLength,
          )
          ..lineTo(
            c.dx + cos(a + halfWidth) * rayLength,
            c.dy + sin(a + halfWidth) * rayLength,
          )
          ..close();
        canvas.drawPath(path, rayPaint);
      }
    }

    // Hale
    final halo = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFC864).withValues(alpha: 0.35 + sun * 0.35),
          const Color(0xFFFFAA50).withValues(alpha: 0.12 + sun * 0.15),
          const Color(0x00FFAA50),
        ],
        stops: const [0.3, 0.6, 1],
      ).createShader(Rect.fromCircle(center: c, radius: r * 2.4));
    canvas.drawCircle(c, r * 2.4, halo);

    // Güneş diski: ufukta kızıl, yükseldikçe altın sarısı
    final disc = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, -0.1),
        colors: [
          const Color(0xFFFFFBE8),
          _mix(const Color(0xFFFF7A45), const Color(0xFFFFE27A)),
          _mix(const Color(0xFFE8502C), const Color(0xFFFFC23D)),
        ],
        stops: const [0, 0.48, 1],
      ).createShader(Rect.fromCircle(center: c, radius: r));
    canvas.drawCircle(c, r, disc);
  }

  void _paintClouds(Canvas canvas, Size size) {
    final opacity = (sun * 1.1 - 0.15).clamp(0.0, 0.85);
    if (opacity == 0) return;
    final paint = Paint()
      ..color = const Color(0xFFFFF6EC).withValues(alpha: opacity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    const clouds = [
      (0.16, 150.0, 0.0),
      (0.30, 110.0, 0.45),
      (0.09, 90.0, 0.75),
    ];
    for (final (top, width, offset) in clouds) {
      final t = (phase + offset) % 1;
      final x = -width + t * (size.width + width * 2);
      final y = size.height * top;
      final h = width * 0.23;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, width, h),
          Radius.circular(h),
        ),
        paint,
      );
      canvas.drawCircle(Offset(x + width * 0.36, y + h * 0.1), h * 0.85, paint);
      canvas.drawCircle(
        Offset(x + width * 0.62, y + h * 0.25),
        h * 0.65,
        paint,
      );
    }
  }

  void _paintHills(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final base = h * 0.70;
    final band = h * 0.30;
    Path hill(List<double> ys) {
      // ys: 0..1 aralığında, bant içindeki yükseklikler (soldan sağa).
      final path = Path()..moveTo(0, base + band * ys.first);
      for (var i = 1; i < ys.length; i++) {
        final x0 = w * (i - 1) / (ys.length - 1);
        final x1 = w * i / (ys.length - 1);
        final mid = (x0 + x1) / 2;
        path.cubicTo(
          mid,
          base + band * ys[i - 1],
          mid,
          base + band * ys[i],
          x1,
          base + band * ys[i],
        );
      }
      return path
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close();
    }

    canvas.drawPath(
      hill([0.43, 0.30, 0.48, 0.36, 0.22, 0.33]),
      Paint()..color = _mix(const Color(0xFF2B2552), const Color(0xFFC0705E)),
    );
    canvas.drawPath(
      hill([0.62, 0.50, 0.62, 0.74, 0.58, 0.53]),
      Paint()..color = _mix(const Color(0xFF1D1A3C), const Color(0xFF8A4D58)),
    );
    canvas.drawPath(
      hill([0.80, 0.72, 0.78, 0.88, 0.82, 0.76]),
      Paint()..color = _mix(const Color(0xFF120F28), const Color(0xFF4E2F45)),
    );
  }

  @override
  bool shouldRepaint(SunrisePainter old) =>
      old.sun != sun || old.phase != phase;
}

class _Star {
  const _Star(this.x, this.y, this.radius, this.seed);

  final double x;
  final double y;
  final double radius;
  final double seed;
}
