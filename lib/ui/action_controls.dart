import 'package:flutter/material.dart';

enum ReferenceButtonVariant { filled, tonal, outlined, text }

class ReferenceIconButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool tonal, filled;
  final double size;
  const ReferenceIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.tonal = false,
    this.filled = false,
    this.size = 40,
  });

  @override
  State<ReferenceIconButton> createState() => _ReferenceIconButtonState();
}

class _ReferenceIconButtonState extends State<ReferenceIconButton> {
  late final _states = WidgetStatesController({
    if (widget.onPressed == null) WidgetState.disabled,
  });

  @override
  void didUpdateWidget(covariant ReferenceIconButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _states.update(WidgetState.disabled, widget.onPressed == null);
    if (widget.onPressed == null) _states.update(WidgetState.pressed, false);
  }

  @override
  void dispose() {
    _states.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final duration = _motionDuration(context);
    return ValueListenableBuilder<Set<WidgetState>>(
      valueListenable: _states,
      builder: (context, states, child) => AnimatedScale(
        scale: widget.onPressed != null && states.contains(WidgetState.pressed)
            ? 1.06
            : 1,
        duration: duration,
        curve: _fastSpatial,
        child: IconButton(
          statesController: _states,
          tooltip: widget.tooltip,
          onPressed: widget.onPressed,
          icon: Icon(widget.icon, size: widget.size <= 32 ? 20 : 24),
          style:
              _style(
                cs: cs,
                background: widget.filled
                    ? cs.primary
                    : widget.tonal
                    ? cs.secondaryContainer
                    : Colors.transparent,
                foreground: widget.filled
                    ? cs.onPrimary
                    : widget.tonal
                    ? cs.onSecondaryContainer
                    : cs.onSurfaceVariant,
                filled: widget.filled || widget.tonal,
                height: widget.size,
                duration: duration,
              ).copyWith(
                fixedSize: WidgetStatePropertyAll(Size.square(widget.size)),
                padding: const WidgetStatePropertyAll(EdgeInsets.zero),
              ),
        ),
      ),
    );
  }
}

class ReferenceButton extends StatefulWidget {
  final Widget child;
  final IconData? icon;
  final VoidCallback? onPressed;
  final ReferenceButtonVariant variant;
  final double height;
  final bool fullWidth;
  const ReferenceButton({
    super.key,
    required this.child,
    this.icon,
    this.onPressed,
    this.variant = ReferenceButtonVariant.filled,
    this.height = 40,
    this.fullWidth = false,
  });

  @override
  State<ReferenceButton> createState() => _ReferenceButtonState();
}

class _ReferenceButtonState extends State<ReferenceButton> {
  late final _states = WidgetStatesController({
    if (widget.onPressed == null) WidgetState.disabled,
  });

  @override
  void didUpdateWidget(covariant ReferenceButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _states.update(WidgetState.disabled, widget.onPressed == null);
    if (widget.onPressed == null) _states.update(WidgetState.pressed, false);
  }

  @override
  void dispose() {
    _states.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), cs = theme.colorScheme;
    final small = widget.height <= 40;
    final padding = widget.height <= 32
        ? 12.0
        : small
        ? 16.0
        : 24.0;
    final duration = _motionDuration(context);
    final (background, foreground) = switch (widget.variant) {
      ReferenceButtonVariant.filled => (cs.primary, cs.onPrimary),
      ReferenceButtonVariant.tonal => (
        cs.secondaryContainer,
        cs.onSecondaryContainer,
      ),
      ReferenceButtonVariant.outlined => (
        Colors.transparent,
        cs.onSurfaceVariant,
      ),
      ReferenceButtonVariant.text => (Colors.transparent, cs.primary),
    };
    final style =
        _style(
          cs: cs,
          background: background,
          foreground: foreground,
          filled:
              widget.variant == ReferenceButtonVariant.filled ||
              widget.variant == ReferenceButtonVariant.tonal,
          outlined: widget.variant == ReferenceButtonVariant.outlined,
          height: widget.height,
          duration: duration,
        ).copyWith(
          fixedSize: WidgetStatePropertyAll(Size.fromHeight(widget.height)),
          padding: WidgetStatePropertyAll(
            EdgeInsets.only(
              left:
                  padding -
                  (widget.icon == null
                      ? 0
                      : small
                      ? 4
                      : 8),
              right: padding,
            ),
          ),
          textStyle: WidgetStatePropertyAll(
            (small ? theme.textTheme.labelLarge : theme.textTheme.titleMedium)
                ?.copyWith(
                  fontSize: small ? 14 : 16,
                  height: small ? 20 / 14 : 24 / 16,
                  fontWeight: FontWeight.w500,
                  letterSpacing: small ? .1 : .15,
                ),
          ),
        );
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.icon != null) ...[
          Icon(widget.icon, size: small ? 20 : 24),
          const SizedBox(width: 8),
        ],
        Flexible(child: widget.child),
      ],
    );
    return ValueListenableBuilder<Set<WidgetState>>(
      valueListenable: _states,
      builder: (context, states, child) => AnimatedScale(
        scale: widget.onPressed != null && states.contains(WidgetState.pressed)
            ? 1.04
            : 1,
        duration: duration,
        curve: _fastSpatial,
        child: SizedBox(
          width: widget.fullWidth ? double.infinity : null,
          height: widget.height,
          child: switch (widget.variant) {
            ReferenceButtonVariant.filled ||
            ReferenceButtonVariant.tonal => FilledButton(
              statesController: _states,
              onPressed: widget.onPressed,
              style: style,
              child: content,
            ),
            ReferenceButtonVariant.outlined => OutlinedButton(
              statesController: _states,
              onPressed: widget.onPressed,
              style: style,
              child: content,
            ),
            ReferenceButtonVariant.text => TextButton(
              statesController: _states,
              onPressed: widget.onPressed,
              style: style,
              child: content,
            ),
          },
        ),
      ),
    );
  }
}

Duration _motionDuration(BuildContext context) =>
    Duration(milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 350);

ButtonStyle _style({
  required ColorScheme cs,
  required Color background,
  required Color foreground,
  required bool filled,
  required double height,
  required Duration duration,
  bool outlined = false,
}) => ButtonStyle(
  mouseCursor: WidgetStateMouseCursor.clickable,
  animationDuration: duration,
  visualDensity: VisualDensity.standard,
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  minimumSize: WidgetStatePropertyAll(Size(height, height)),
  maximumSize: WidgetStatePropertyAll(Size(double.infinity, height)),
  elevation: const WidgetStatePropertyAll(0),
  shadowColor: const WidgetStatePropertyAll(Colors.transparent),
  splashFactory: NoSplash.splashFactory,
  foregroundColor: WidgetStateProperty.resolveWith(
    (states) => states.contains(WidgetState.disabled)
        ? cs.onSurface.withValues(alpha: .38)
        : foreground,
  ),
  backgroundColor: WidgetStateProperty.resolveWith(
    (states) => states.contains(WidgetState.disabled)
        ? filled
              ? cs.onSurface.withValues(alpha: .12)
              : Colors.transparent
        : background,
  ),
  overlayColor: WidgetStateProperty.resolveWith(
    (states) =>
        states.contains(WidgetState.pressed) ||
            states.contains(WidgetState.focused)
        ? foreground.withValues(alpha: .1)
        : states.contains(WidgetState.hovered)
        ? foreground.withValues(alpha: .08)
        : Colors.transparent,
  ),
  side: WidgetStateProperty.resolveWith(
    (states) => outlined && !states.contains(WidgetState.disabled)
        ? BorderSide(color: cs.outlineVariant)
        : BorderSide.none,
  ),
  shape: WidgetStateProperty.resolveWith(
    (states) => RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(
        states.contains(WidgetState.pressed)
            ? height <= 40
                  ? 8
                  : 12
            : height / 2,
      ),
    ),
  ),
);

class _FastSpatialCurve extends Curve {
  const _FastSpatialCurve();
  @override
  double transformInternal(double t) {
    const stops = [
      0.0,
      .318,
      .775,
      1.034,
      1.095,
      1.063,
      1.02,
      .997,
      .991,
      .995,
      1.0,
    ];
    final index = (t * 10).floor().clamp(0, 9);
    return stops[index] + (stops[index + 1] - stops[index]) * (t * 10 - index);
  }
}

const _fastSpatial = _FastSpatialCurve();
