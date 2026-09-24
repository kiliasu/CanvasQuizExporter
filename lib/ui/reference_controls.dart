import 'app_symbols.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Duration _motion(BuildContext context, bool reduced, int milliseconds) =>
    reduced || MediaQuery.disableAnimationsOf(context)
    ? Duration.zero
    : Duration(milliseconds: milliseconds);

class ReferenceSegment<T> {
  final T value;
  final String label;
  final IconData? icon;
  const ReferenceSegment({required this.value, required this.label, this.icon});
}

/// Connected button group: items 2 dp apart with rounded outer ends and 8 dp
/// inner corners; a press squeezes the neighbors. A non-expanded group shares
/// its width equally when every label fits, otherwise items keep their
/// natural widths.
class ReferenceButtonGroup<T> extends StatefulWidget {
  final List<ReferenceSegment<T>> items;
  final T selected;
  final ValueChanged<T>? onSelected;
  final double height;
  final bool expanded, reducedMotion;
  const ReferenceButtonGroup({
    super.key,
    required this.items,
    required this.selected,
    required this.onSelected,
    this.height = 40,
    this.expanded = true,
    this.reducedMotion = false,
  });

  @override
  State<ReferenceButtonGroup<T>> createState() =>
      _ReferenceButtonGroupState<T>();
}

class _ReferenceButtonGroupState<T> extends State<ReferenceButtonGroup<T>> {
  int? _pressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final duration = _motion(context, widget.reducedMotion, 350);
    final inset = widget.height <= 32 ? 12.0 : 16.0;
    double? naturalWidth;
    final naturalWidths = <double>[];
    var equalShares = widget.expanded;
    if (!widget.expanded) {
      for (final item in widget.items) {
        final text = TextPainter(
          text: TextSpan(
            text: item.label,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: 1,
        )..layout();
        final width = text.width + (item.icon == null ? 0 : 28) + 2 * inset;
        naturalWidths.add(width.ceilToDouble());
        text.dispose();
      }
      naturalWidth =
          naturalWidths.fold<double>(0, (sum, width) => sum + width) +
          2 * (widget.items.length - 1);
      // Equal shares may borrow padding, but never clip a label; otherwise
      // each item keeps its natural width.
      final share =
          (naturalWidth - 2 * (widget.items.length - 1)) / widget.items.length;
      equalShares = naturalWidths.every((width) => width - 2 * inset <= share);
    }
    final row = Row(
      children: [
        for (var i = 0; i < widget.items.length; i++) ...[
          if (i != 0) const SizedBox(width: 2),
          TweenAnimationBuilder<double>(
            tween: Tween(
              end: _pressed == i
                  ? 1.15
                  : _pressed != null && (_pressed! - i).abs() == 1
                  ? .9
                  : 1,
            ),
            duration: duration,
            curve: Curves.easeOutBack,
            builder: (context, flex, child) => Expanded(
              flex: ((equalShares ? 1000 : naturalWidths[i] * 1000) * flex)
                  .round(),
              child: child!,
            ),
            child: _Interaction(
              onTap: widget.onSelected == null
                  ? null
                  : () => widget.onSelected!(widget.items[i].value),
              onPressed: (pressed) =>
                  setState(() => _pressed = pressed ? i : null),
              semanticLabel: widget.items[i].label,
              selected: widget.items[i].value == widget.selected,
              builder: (context, state) {
                final selected = widget.items[i].value == widget.selected;
                final foreground = selected
                    ? cs.onPrimary
                    : cs.onSurfaceVariant;
                return AnimatedContainer(
                  height: widget.height,
                  duration: _motion(context, widget.reducedMotion, 200),
                  curve: Curves.easeOutCubic,
                  // Natural widths already include the padding; centered
                  // content may use it when an equal share is narrower.
                  padding: EdgeInsets.symmetric(
                    horizontal: !widget.expanded && equalShares ? 0 : inset,
                  ),
                  decoration: BoxDecoration(
                    color: Color.alphaBlend(
                      foreground.withValues(alpha: state.opacity),
                      selected ? cs.primary : cs.surfaceContainer,
                    ),
                    borderRadius: BorderRadius.horizontal(
                      left: Radius.circular(i == 0 ? widget.height / 2 : 8),
                      right: Radius.circular(
                        i == widget.items.length - 1 ? widget.height / 2 : 8,
                      ),
                    ),
                    border: state.focused
                        ? Border.all(color: cs.secondary, width: 2)
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.items[i].icon != null) ...[
                        Icon(
                          widget.items[i].icon,
                          size: 20,
                          color: foreground,
                          fill: selected ? 1 : 0,
                        ),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Text(
                          widget.items[i].label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(color: foreground),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
    return Opacity(
      opacity: widget.onSelected == null ? .38 : 1,
      child: widget.expanded ? row : SizedBox(width: naturalWidth, child: row),
    );
  }
}

class ReferenceCheckbox extends StatelessWidget {
  final bool value, reducedMotion;
  final String label;
  final String? description;
  final ValueChanged<bool>? onChanged;
  final double height;
  const ReferenceCheckbox({
    super.key,
    required this.value,
    required this.label,
    required this.onChanged,
    this.description,
    this.height = 40,
    this.reducedMotion = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = value ? cs.primary : cs.onSurfaceVariant;
    return _Interaction(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      semanticLabel: label,
      checked: value,
      builder: (context, state) => Opacity(
        opacity: onChanged == null ? .38 : 1,
        child: SizedBox(
          height: height,
          child: Row(
            children: [
              SizedBox(
                width: 48,
                height: height,
                child: Center(
                  child: AnimatedContainer(
                    width: 40,
                    height: 40,
                    duration: _motion(context, reducedMotion, 200),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withValues(alpha: state.opacity),
                    ),
                    child: Center(
                      child: AnimatedScale(
                        scale: state.pressed ? .9 : 1,
                        duration: _motion(context, reducedMotion, 350),
                        curve: Curves.easeOutBack,
                        child: AnimatedContainer(
                          width: 18,
                          height: 18,
                          duration: _motion(context, reducedMotion, 200),
                          decoration: BoxDecoration(
                            color: value ? color : Colors.transparent,
                            borderRadius: BorderRadius.circular(2),
                            border: value
                                ? null
                                : Border.all(color: color, width: 2),
                          ),
                          child: value
                              ? Icon(
                                  AppSymbols.check,
                                  color: cs.onPrimary,
                                  size: 18,
                                  weight: 700,
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              const SizedBox(width: 8),
              if (description != null) ...[
                Text(
                  description!,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class ReferenceSwitch extends StatelessWidget {
  final bool value, reducedMotion;
  final ValueChanged<bool>? onChanged;
  final String semanticLabel;
  const ReferenceSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    required this.semanticLabel,
    this.reducedMotion = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _Interaction(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      semanticLabel: semanticLabel,
      toggled: value,
      builder: (context, state) {
        final handle = state.pressed
            ? 28.0
            : value
            ? 24.0
            : 16.0;
        final left = value
            ? 52 - 4 - handle
            : handle == 16
            ? 8.0
            : 4.0;
        return Opacity(
          opacity: onChanged == null ? .38 : 1,
          child: SizedBox(
            width: 52,
            height: 32,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  width: 52,
                  height: 32,
                  duration: _motion(context, reducedMotion, 200),
                  decoration: BoxDecoration(
                    color: value ? cs.primary : cs.surfaceContainerHighest,
                    border: Border.all(
                      color: value ? Colors.transparent : cs.outline,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                AnimatedPositioned(
                  duration: _motion(context, reducedMotion, 350),
                  curve: Curves.easeOutBack,
                  left: left,
                  top: (32 - handle) / 2,
                  width: handle,
                  height: handle,
                  child: AnimatedContainer(
                    duration: _motion(context, reducedMotion, 200),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: value
                          ? state.hovered
                                ? cs.primaryContainer
                                : cs.onPrimary
                          : state.hovered
                          ? cs.onSurfaceVariant
                          : cs.outline,
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          left: -8,
                          right: -8,
                          top: -8,
                          bottom: -8,
                          child: AnimatedContainer(
                            duration: _motion(context, reducedMotion, 200),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: (value ? cs.primary : cs.onSurface)
                                  .withValues(alpha: state.opacity),
                            ),
                          ),
                        ),
                        if (value)
                          Center(
                            child: Icon(
                              AppSymbols.check,
                              size: 16,
                              weight: 600,
                              color: cs.onPrimaryContainer,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class ReferenceChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected, reducedMotion;
  final VoidCallback? onPressed;
  const ReferenceChip({
    super.key,
    required this.label,
    this.icon,
    this.selected = false,
    this.onPressed,
    this.reducedMotion = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final foreground = selected ? cs.onSecondaryContainer : cs.onSurfaceVariant;
    final leading = selected ? AppSymbols.check : icon;
    return _Interaction(
      onTap: onPressed,
      semanticLabel: label,
      selected: selected,
      builder: (context, state) => AnimatedContainer(
        duration: _motion(context, reducedMotion, 350),
        curve: Curves.easeOutCubic,
        height: 32,
        padding: EdgeInsets.only(left: leading == null ? 16 : 8, right: 16),
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            foreground.withValues(alpha: state.opacity),
            selected ? cs.secondaryContainer : Colors.transparent,
          ),
          border: Border.all(
            color: selected ? Colors.transparent : cs.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(state.pressed ? 4 : 8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[
              Icon(leading, size: 18, color: foreground),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge
                    ?.copyWith(color: foreground),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 40 dp item of a collapsed side panel. Active items become a 12 dp
/// squircle with a filled icon; a press tightens the corners to 8 dp.
class ReferenceRailButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool active, toggle, reducedMotion;
  final Color background, foreground;
  final VoidCallback? onPressed;
  const ReferenceRailButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.active,
    required this.background,
    required this.foreground,
    required this.onPressed,
    this.toggle = false,
    this.reducedMotion = false,
  });

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: _Interaction(
      onTap: onPressed,
      semanticLabel: tooltip,
      selected: toggle ? null : active,
      toggled: toggle ? active : null,
      builder: (context, state) => AnimatedContainer(
        width: 40,
        height: 40,
        duration: _motion(context, reducedMotion, 200),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            foreground.withValues(alpha: state.opacity),
            background,
          ),
          borderRadius: BorderRadius.circular(
            state.pressed
                ? 8
                : active
                ? 12
                : 20,
          ),
        ),
        child: Icon(icon, size: 24, color: foreground, fill: active ? 1 : 0),
      ),
    ),
  );
}

/// Pill counter beside panel titles, and the wider badge of collapsed rails.
class ReferenceCountBadge extends StatelessWidget {
  final String label;
  final bool active, rail, reducedMotion;
  const ReferenceCountBadge({
    super.key,
    required this.label,
    this.active = true,
    this.rail = false,
    this.reducedMotion = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: _motion(context, reducedMotion, 200),
      constraints: BoxConstraints(minWidth: rail ? 40 : 0),
      padding: EdgeInsets.symmetric(horizontal: rail ? 8 : 10, vertical: 2),
      decoration: BoxDecoration(
        color: active ? cs.secondaryContainer : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 14,
          height: 20 / 14,
          fontWeight: FontWeight.w500,
          letterSpacing: .1,
          color: active ? cs.onSecondaryContainer : cs.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _InteractionState {
  final bool hovered, pressed, focused;
  const _InteractionState(this.hovered, this.pressed, this.focused);
  double get opacity => pressed || focused
      ? .10
      : hovered
      ? .08
      : 0;
}

class _Interaction extends StatefulWidget {
  final Widget Function(BuildContext, _InteractionState) builder;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onPressed;
  final String semanticLabel;
  final bool? selected, checked, toggled;
  const _Interaction({
    required this.builder,
    required this.onTap,
    required this.semanticLabel,
    this.onPressed,
    this.selected,
    this.checked,
    this.toggled,
  });

  @override
  State<_Interaction> createState() => _InteractionStateful();
}

class _InteractionStateful extends State<_Interaction> {
  bool _hovered = false, _pressed = false, _focused = false;
  void _press(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
    widget.onPressed?.call(value);
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.semanticLabel,
    button: widget.checked == null && widget.toggled == null,
    checked: widget.checked,
    toggled: widget.toggled,
    selected: widget.selected,
    enabled: widget.onTap != null,
    onTap: widget.onTap,
    excludeSemantics: true,
    child: FocusableActionDetector(
      enabled: widget.onTap != null,
      mouseCursor: widget.onTap == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onTap?.call();
            return null;
          },
        ),
      },
      onShowHoverHighlight: (value) => setState(() => _hovered = value),
      onShowFocusHighlight: (value) => setState(() => _focused = value),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onTapDown: widget.onTap == null ? null : (_) => _press(true),
        onTapUp: widget.onTap == null ? null : (_) => _press(false),
        onTapCancel: () => _press(false),
        child: widget.builder(
          context,
          _InteractionState(_hovered, _pressed, _focused),
        ),
      ),
    ),
  );
}
