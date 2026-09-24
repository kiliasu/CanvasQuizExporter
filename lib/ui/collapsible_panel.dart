import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show OverflowBoxFit;

import 'app_symbols.dart';
import 'motion.dart';

/// Width of a collapsed side panel: 40 dp rail items inside 16 dp padding.
const railPanelWidth = 72.0;

/// Animates a side column between its full width and the rail width.
class CollapsibleColumn extends StatelessWidget {
  final bool collapsed, reducedMotion;
  final double width;
  final Widget child;
  const CollapsibleColumn({
    super.key,
    required this.collapsed,
    required this.width,
    required this.child,
    this.reducedMotion = false,
  });

  @override
  Widget build(BuildContext context) {
    final reduced = reducedMotion || MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(end: collapsed ? railPanelWidth : width),
      duration: Duration(milliseconds: reduced ? 0 : 500),
      curve: referenceSpatialCurve,
      builder: (context, value, child) => SizedBox(width: value, child: child),
      child: child,
    );
  }
}

/// Swaps a panel's content for its rail. The full content stays mounted
/// (offstage) so expansion and scroll state survive, and fades back in; the
/// rail fades in when shown.
class CollapsibleContent extends StatelessWidget {
  final bool collapsed, reducedMotion;
  final double minWidth;
  final Widget rail, child;
  const CollapsibleContent({
    super.key,
    required this.collapsed,
    required this.minWidth,
    required this.rail,
    required this.child,
    this.reducedMotion = false,
  });

  @override
  Widget build(BuildContext context) {
    final reduced = reducedMotion || MediaQuery.disableAnimationsOf(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        Offstage(
          offstage: collapsed,
          child: AnimatedOpacity(
            opacity: collapsed ? 0 : 1,
            duration: Duration(milliseconds: collapsed || reduced ? 0 : 300),
            curve: referenceEffectsCurve,
            child: TickerMode(
              enabled: !collapsed,
              child: ExcludeFocus(
                excluding: collapsed,
                child: MinWidthBox(
                  minWidth: minWidth,
                  alignment: AlignmentDirectional.topStart,
                  child: child,
                ),
              ),
            ),
          ),
        ),
        if (collapsed)
          ReferenceFade(
            duration: const Duration(milliseconds: 200),
            reducedMotion: reducedMotion,
            child: MinWidthBox(
              minWidth: 40,
              alignment: Alignment.topCenter,
              child: rail,
            ),
          ),
      ],
    );
  }
}

/// Lays [child] out at least [minWidth] wide while its column is narrower, so
/// panel content keeps its layout (clipped) while the width animates.
class MinWidthBox extends StatelessWidget {
  final double minWidth;
  final AlignmentGeometry alignment;
  final Widget child;
  const MinWidthBox({
    super.key,
    required this.minWidth,
    this.alignment = AlignmentDirectional.topStart,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => OverflowBox(
      alignment: alignment,
      minWidth: minWidth,
      maxWidth: math.max(minWidth, constraints.maxWidth),
      fit: OverflowBoxFit.deferToChild,
      child: child,
    ),
  );
}

/// Collapse / expand control of a side panel; the panel icon points the other
/// way while collapsed.
class PaneToggleButton extends StatelessWidget {
  final bool collapsed, end, reducedMotion;
  final String tooltip;
  final VoidCallback? onPressed;
  const PaneToggleButton({
    super.key,
    required this.collapsed,
    required this.tooltip,
    required this.onPressed,
    this.end = false,
    this.reducedMotion = false,
  });

  @override
  Widget build(BuildContext context) {
    final reduced = reducedMotion || MediaQuery.disableAnimationsOf(context);
    return Semantics(
      expanded: !collapsed,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: AnimatedRotation(
          turns: collapsed ? .5 : 0,
          duration: Duration(milliseconds: reduced ? 0 : 500),
          curve: referenceSpatialCurve,
          child: Icon(
            end ? AppSymbols.rightPanelClose : AppSymbols.leftPanelClose,
          ),
        ),
      ),
    );
  }
}
