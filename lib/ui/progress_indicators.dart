import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'motion.dart';

/// M3 Expressive linear progress: a 4 dp gap between the active indicator and
/// the track, a stop dot at the end, and a 12 dp wavy indicator while [wavy].
/// A null [value] slides an indeterminate bar.
class ReferenceLinearProgress extends StatefulWidget {
  final double? value;
  final bool wavy, reducedMotion;
  const ReferenceLinearProgress({
    super.key,
    required this.value,
    this.wavy = false,
    this.reducedMotion = false,
  });

  @override
  State<ReferenceLinearProgress> createState() =>
      _ReferenceLinearProgressState();
}

class _ReferenceLinearProgressState extends State<ReferenceLinearProgress>
    with SingleTickerProviderStateMixin {
  late final _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  bool get _reduced =>
      widget.reducedMotion || MediaQuery.disableAnimationsOf(context);

  void _syncSweep() {
    if (widget.value == null && !_reduced) {
      if (!_sweep.isAnimating) _sweep.repeat();
    } else {
      _sweep.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncSweep();
  }

  @override
  void didUpdateWidget(covariant ReferenceLinearProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncSweep();
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final value = widget.value;
    final wavy = widget.wavy && value != null;
    CustomPaint paint(double? progress) => CustomPaint(
      painter: _LinearProgressPainter(
        value: progress,
        sweep: _sweep,
        wavy: wavy,
        active: cs.primary,
        track: cs.secondaryContainer,
      ),
    );
    return Semantics(
      value: value == null ? null : '${(value.clamp(0, 1) * 100).round()}%',
      child: SizedBox(
        height: wavy ? 12 : 4,
        width: double.infinity,
        child: value == null
            ? paint(null)
            : TweenAnimationBuilder<double>(
                tween: Tween(end: value.clamp(0, 1).toDouble()),
                duration: Duration(milliseconds: _reduced ? 0 : 500),
                curve: referenceSpatialCurve,
                builder: (context, progress, _) => paint(progress),
              ),
      ),
    );
  }
}

class _LinearProgressPainter extends CustomPainter {
  final double? value;
  final Animation<double> sweep;
  final bool wavy;
  final Color active, track;
  _LinearProgressPainter({
    required this.value,
    required this.sweep,
    required this.wavy,
    required this.active,
    required this.track,
  }) : super(repaint: value == null ? sweep : null);

  static const _emphasized = Cubic(.2, 0, 0, 1);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, top = (size.height - 4) / 2;
    final fill = Paint()..color = active;
    RRect bar(double left, double right) =>
        RRect.fromLTRBR(left, top, right, top + 4, const Radius.circular(2));
    final progress = value;
    if (progress == null) {
      final left = (-.4 + 1.4 * _emphasized.transform(sweep.value)) * w;
      canvas.save();
      canvas.clipRect(Offset.zero & size);
      canvas.drawRRect(bar(left, left + .4 * w), fill);
      canvas.restore();
    } else {
      final p = progress.clamp(0.0, 1.0);
      final trackWidth = (1 - p) * w - 2;
      if (trackWidth > 0) {
        canvas.drawRRect(bar(w - trackWidth, w), Paint()..color = track);
      }
      if (wavy) {
        // 20 waves across the track: 10-unit half-waves on a 400-unit scale.
        final unit = w / 400, end = p * 400 - 4;
        if (end > 0) {
          final wave = Path()..moveTo(0, 6);
          for (var i = 0; i < 41; i++) {
            wave.quadraticBezierTo(
              (10 * i + 5) * unit,
              i.isEven ? 0 : 12,
              (10 * i + 10) * unit,
              6,
            );
          }
          canvas.save();
          canvas.clipRect(Rect.fromLTWH(0, -4, end * unit, size.height + 8));
          canvas.drawPath(
            wave,
            Paint()
              ..color = active
              ..style = PaintingStyle.stroke
              ..strokeWidth = 4
              ..strokeCap = StrokeCap.round,
          );
          canvas.restore();
        }
      } else if (p * w - 2 > 0) {
        canvas.drawRRect(bar(0, p * w - 2), fill);
      }
    }
    canvas.drawCircle(Offset(w - 2, top + 2), 2, fill);
  }

  @override
  bool shouldRepaint(_LinearProgressPainter old) =>
      old.value != value ||
      old.wavy != wavy ||
      old.active != active ||
      old.track != track;
}

/// M3 Expressive loading indicator: a primary shape that morphs through the
/// Material shape set while it turns, optionally on a circle.
class ReferenceLoadingIndicator extends StatefulWidget {
  final double size;
  final bool contained, reducedMotion;
  final String? semanticsLabel;
  const ReferenceLoadingIndicator({
    super.key,
    this.size = 48,
    this.contained = false,
    this.reducedMotion = false,
    this.semanticsLabel,
  });

  @override
  State<ReferenceLoadingIndicator> createState() =>
      _ReferenceLoadingIndicatorState();
}

class _ReferenceLoadingIndicatorState extends State<ReferenceLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final _cycle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3500),
  );

  void _sync() {
    if (widget.reducedMotion || MediaQuery.disableAnimationsOf(context)) {
      _cycle.stop();
    } else if (!_cycle.isAnimating) {
      _cycle.repeat();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant ReferenceLoadingIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    _cycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final still =
        widget.reducedMotion || MediaQuery.disableAnimationsOf(context);
    return Semantics(
      label: widget.semanticsLabel,
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.square(widget.size),
          painter: _MorphPainter(
            cycle: _cycle,
            still: still,
            color: cs.primary,
            container: widget.contained ? cs.surfaceContainerHighest : null,
          ),
        ),
      ),
    );
  }
}

class _MorphPainter extends CustomPainter {
  final Animation<double> cycle;
  final bool still;
  final Color color;
  final Color? container;
  _MorphPainter({
    required this.cycle,
    required this.still,
    required this.color,
    required this.container,
  }) : super(repaint: cycle);

  static const _samples = 144;

  /// Polar radii of the indicator's shapes around their centre, in a unit box:
  /// star, circle, decagon, blob, diamond, egg, rounded square.
  static final List<List<double>> _shapes = [
    _polygon(const [
      Offset(.5, 0),
      Offset(.61, .35),
      Offset(.98, .35),
      Offset(.68, .57),
      Offset(.79, .91),
      Offset(.5, .7),
      Offset(.21, .91),
      Offset(.32, .57),
      Offset(.02, .35),
      Offset(.39, .35),
    ]),
    Path()..addOval(const Rect.fromLTWH(0, 0, 1, 1)),
    _polygon(const [
      Offset(.5, 0),
      Offset(.8, .1),
      Offset(1, .35),
      Offset(1, .7),
      Offset(.8, .9),
      Offset(.5, 1),
      Offset(.2, .9),
      Offset(0, .7),
      Offset(0, .35),
      Offset(.2, .1),
    ]),
    Path()..addRRect(
      RRect.fromLTRBAndCorners(
        .08,
        .08,
        .92,
        .92,
        topLeft: const Radius.elliptical(.252, .252),
        topRight: const Radius.elliptical(.588, .252),
        bottomRight: const Radius.elliptical(.588, .588),
        bottomLeft: const Radius.elliptical(.252, .588),
      ),
    ),
    _polygon(const [
      Offset(.5, 0),
      Offset(1, .5),
      Offset(.5, 1),
      Offset(0, .5),
    ]),
    Path()..addRRect(
      RRect.fromLTRBAndCorners(
        0,
        0,
        1,
        1,
        topLeft: const Radius.elliptical(.5, .6),
        topRight: const Radius.elliptical(.5, .6),
        bottomRight: const Radius.elliptical(.5, .4),
        bottomLeft: const Radius.elliptical(.5, .4),
      ),
    ),
    Path()..addRRect(
      RRect.fromLTRBR(.05, .05, .95, .95, const Radius.circular(.18)),
    ),
  ].map(_radii).toList();

  static Path _polygon(List<Offset> points) => Path()..addPolygon(points, true);

  /// Samples the outline densely and reads its radius at evenly spaced angles
  /// (every shape is star-shaped around the centre).
  static List<double> _radii(Path path) {
    const center = Offset(.5, .5);
    final polar = <(double, double)>[];
    for (final metric in path.computeMetrics()) {
      for (var i = 0; i < 1440; i++) {
        final point = metric
            .getTangentForOffset(metric.length * i / 1440)!
            .position;
        final d = point - center;
        polar.add((math.atan2(d.dy, d.dx), d.distance));
      }
    }
    polar.sort((a, b) => a.$1.compareTo(b.$1));
    double at(double angle) {
      var hi = polar.indexWhere((p) => p.$1 >= angle);
      if (hi < 0) hi = polar.length;
      final a = hi == 0 ? polar.last : polar[hi - 1];
      final b = hi == polar.length ? polar.first : polar[hi];
      var span = b.$1 - a.$1, offset = angle - a.$1;
      if (span <= 0) span += 2 * math.pi;
      if (offset < 0) offset += 2 * math.pi;
      return ui.lerpDouble(a.$2, b.$2, (offset / span).clamp(0, 1))!;
    }

    return [
      for (var k = 0; k < _samples; k++)
        at(-math.pi + 2 * math.pi * k / _samples),
    ];
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    if (container != null) {
      canvas.drawCircle(
        center,
        size.shortestSide / 2,
        Paint()..color = container!,
      );
    }
    final inner = size.shortestSide * (container == null ? 1 : .75);
    final box = inner * .8;
    final List<double> radii;
    final double turn;
    if (still) {
      radii = _shapes.last;
      turn = 0;
    } else {
      final t = cycle.value * _shapes.length;
      final index = t.floor() % _shapes.length;
      final eased = referenceSpatialCurve.transform(t - t.floor());
      final from = _shapes[index], to = _shapes[(index + 1) % _shapes.length];
      radii = [
        for (var k = 0; k < _samples; k++)
          ui.lerpDouble(from[k], to[k], eased)!,
      ];
      turn = cycle.value * 2 * math.pi;
    }
    final path = Path();
    for (var k = 0; k < _samples; k++) {
      final angle = -math.pi + 2 * math.pi * k / _samples + turn;
      final point =
          center + Offset(math.cos(angle), math.sin(angle)) * radii[k] * box;
      if (k == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(path..close(), Paint()..color = color);
  }

  @override
  bool shouldRepaint(_MorphPainter old) =>
      old.still != still || old.color != color || old.container != container;
}
