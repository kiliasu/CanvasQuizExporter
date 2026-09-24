import 'app_symbols.dart';

import 'dart:async';

import 'package:flutter/material.dart';

import 'motion.dart';

/// One compact notification, replaced in place by subsequent actions.
class ReferenceToast extends StatefulWidget {
  const ReferenceToast({super.key});
  @override
  State<ReferenceToast> createState() => ReferenceToastState();
}

class ReferenceToastState extends State<ReferenceToast>
    with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );
  Timer? _timer;
  String? _message;
  bool _error = false;

  void show(String message, {bool error = false}) {
    _timer?.cancel();
    setState(() {
      _message = message;
      _error = error;
    });
    if (MediaQuery.disableAnimationsOf(context)) {
      _animation.value = 1;
    } else {
      _animation.forward();
    }
    _timer = Timer(const Duration(milliseconds: 3200), hide);
  }

  Future<void> hide() async {
    _timer?.cancel();
    if (MediaQuery.disableAnimationsOf(context)) {
      _animation.value = 0;
    } else {
      await _animation.reverse();
    }
    if (mounted && _animation.isDismissed) setState(() => _message = null);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_message == null) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    return Positioned(
      left: 24,
      right: 24,
      bottom: 104,
      child: Center(
        child: AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            final value = referenceSpatialCurve.transform(_animation.value);
            return IgnorePointer(
              ignoring: _animation.status == AnimationStatus.reverse,
              child: Opacity(
                opacity: (_animation.value / .6).clamp(0, 1),
                child: Transform.translate(
                  offset: Offset(0, 16 * (1 - value)),
                  child: Transform.scale(
                    scale: .92 + .08 * value,
                    child: child,
                  ),
                ),
              ),
            );
          },
          child: Semantics(
            liveRegion: true,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(9999),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x4D000000),
                    offset: Offset(0, 1),
                    blurRadius: 3,
                  ),
                  BoxShadow(
                    color: Color(0x26000000),
                    offset: Offset(0, 4),
                    blurRadius: 8,
                    spreadRadius: 3,
                  ),
                ],
              ),
              child: Material(
                key: const ValueKey('reference-toast'),
                color: cs.surfaceContainerHigh,
                shape: const StadiumBorder(),
                child: InkWell(
                  onTap: hide,
                  mouseCursor: WidgetStateMouseCursor.clickable,
                  customBorder: const StadiumBorder(),
                  child: SizedBox(
                    height: 48,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 20, 0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: cs.primaryContainer,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _error
                                  ? AppSymbols.errorOutline
                                  : AppSymbols.check,
                              size: 18,
                              color: cs.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Text(
                              _message!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: cs.onSurface,
                                fontSize: 14,
                                height: 20 / 14,
                                fontWeight: FontWeight.w500,
                                letterSpacing: .1,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
