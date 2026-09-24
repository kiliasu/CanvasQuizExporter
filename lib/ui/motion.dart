import 'dart:async';

import 'package:flutter/material.dart';

/// Reduced motion removes the size transition entirely; a zero-duration
/// AnimatedSize can re-enter layout on Flutter's Windows test renderer.
class MotionSize extends StatelessWidget {
  final Widget child;
  final Duration duration;
  final Curve curve;
  final AlignmentGeometry alignment;
  const MotionSize({
    super.key,
    required this.child,
    required this.duration,
    this.curve = Curves.linear,
    this.alignment = Alignment.center,
  });
  @override
  Widget build(BuildContext context) =>
      duration == Duration.zero || MediaQuery.disableAnimationsOf(context)
      ? child
      : AnimatedSize(
          duration: duration,
          curve: curve,
          alignment: alignment,
          child: child,
        );
}

/// Spatial spring easing, sampled at ten points, with a small overshoot.
class ReferenceSpatialCurve extends Curve {
  const ReferenceSpatialCurve();
  @override
  double transformInternal(double t) {
    const stops = [
      0.0,
      .281,
      .66,
      .891,
      .988,
      1.014,
      1.013,
      1.007,
      1.002,
      1.0,
      1.0,
    ];
    final index = (t * 10).floor().clamp(0, 9);
    return stops[index] + (stops[index + 1] - stops[index]) * (t * 10 - index);
  }
}

const referenceSpatialCurve = ReferenceSpatialCurve();

/// Effects easing for color and opacity: critically damped, no overshoot.
class ReferenceEffectsCurve extends Curve {
  const ReferenceEffectsCurve();
  @override
  double transformInternal(double t) {
    const stops = [
      0.0,
      .191,
      .475,
      .692,
      .829,
      .908,
      .952,
      .976,
      .988,
      .994,
      1.0,
    ];
    final index = (t * 10).floor().clamp(0, 9);
    return stops[index] + (stops[index + 1] - stops[index]) * (t * 10 - index);
  }
}

const referenceEffectsCurve = ReferenceEffectsCurve();

/// Opacity-only entrance.
class ReferenceFade extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final bool reducedMotion;
  const ReferenceFade({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 300),
    this.reducedMotion = false,
  });
  @override
  State<ReferenceFade> createState() => _ReferenceFadeState();
}

class _ReferenceFadeState extends State<ReferenceFade>
    with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late final _opacity = CurvedAnimation(
    parent: _animation,
    curve: referenceEffectsCurve,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.reducedMotion || MediaQuery.disableAnimationsOf(context)) {
      _animation.value = 1;
    } else if (_animation.isDismissed) {
      _animation.forward();
    }
  }

  @override
  void dispose() {
    _opacity.dispose();
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      FadeTransition(opacity: _opacity, child: widget.child);
}

class ReferenceReveal extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final bool reducedMotion, horizontal;
  const ReferenceReveal({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.reducedMotion = false,
    this.horizontal = false,
  });
  @override
  State<ReferenceReveal> createState() => _ReferenceRevealState();
}

class _ReferenceRevealState extends State<ReferenceReveal>
    with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );
  Timer? _delay;
  bool _started = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _start();
  }

  @override
  void didUpdateWidget(covariant ReferenceReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    _start();
  }

  void _start() {
    if (widget.reducedMotion || MediaQuery.disableAnimationsOf(context)) {
      _delay?.cancel();
      _animation.value = 1;
      _started = true;
    } else if (!_started) {
      _started = true;
      if (widget.delay == Duration.zero) {
        _animation.forward();
      } else {
        _delay = Timer(widget.delay, () {
          if (mounted) _animation.forward();
        });
      }
    }
  }

  @override
  void dispose() {
    _delay?.cancel();
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _animation,
    child: widget.child,
    builder: (_, child) {
      final value = referenceSpatialCurve.transform(_animation.value);
      return Opacity(
        opacity: value.clamp(0, 1),
        child: Transform.translate(
          offset: widget.horizontal
              ? Offset(-12 * (1 - value), 0)
              : Offset(0, 12 * (1 - value)),
          child: Transform.scale(
            scale: widget.horizontal ? .6 + .4 * value : .985 + .015 * value,
            child: child,
          ),
        ),
      );
    },
  );
}
