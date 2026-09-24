import 'package:canvas_quiz_exporter/ui/app_symbols.dart';
import 'package:canvas_quiz_exporter/ui/action_controls.dart';
import 'package:canvas_quiz_exporter/ui/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host(Widget child, {bool reducedMotion = false}) => MaterialApp(
  theme: appTheme(false, 'violet'),
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reducedMotion),
    child: Scaffold(body: Center(child: child)),
  ),
);

void main() {
  testWidgets('buttons keep keyboard activation and disabled state', (
    tester,
  ) async {
    var activations = 0;
    var enabled = true;
    late StateSetter rebuild;
    await tester.pumpWidget(
      host(
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ReferenceButton(
                  onPressed: enabled ? () => activations++ : null,
                  child: const Text('导出'),
                ),
                ReferenceIconButton(
                  icon: AppSymbols.chevronRight,
                  tooltip: '下一页',
                  onPressed: enabled ? () => activations++ : null,
                ),
              ],
            );
          },
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(activations, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(activations, 2);
    rebuild(() => enabled = false);
    await tester.pumpAndSettle();
    await tester.tap(find.text('导出'));
    await tester.tap(find.byTooltip('下一页'));
    await tester.pumpAndSettle();
    expect(activations, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'press changes scale and shape while reduced motion is immediate',
    (tester) async {
      await tester.pumpWidget(
        host(
          ReferenceButton(
            icon: AppSymbols.download,
            onPressed: () {},
            child: const Text('导出全部'),
          ),
        ),
      );
      final button = find.byType(FilledButton);
      expect(tester.getSize(button).height, 40);
      final gesture = await tester.startGesture(tester.getCenter(button));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
        1.04,
      );
      final shape =
          tester.widget<FilledButton>(button).style!.shape!.resolve({
                WidgetState.pressed,
              })!
              as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(8));
      await gesture.up();
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        host(
          ReferenceIconButton(
            icon: AppSymbols.chevronRight,
            tooltip: '下一页',
            tonal: true,
            onPressed: () {},
          ),
          reducedMotion: true,
        ),
      );
      expect(tester.getSize(find.byType(IconButton)), const Size(40, 40));
      final iconGesture = await tester.startGesture(
        tester.getCenter(find.byType(IconButton)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();
      final scale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
      expect(scale.scale, 1.06);
      expect(scale.duration, Duration.zero);
      await iconGesture.up();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
