import 'package:canvas_quiz_exporter/ui/app_symbols.dart';

import 'dart:ui';

import 'package:canvas_quiz_exporter/ui/app_theme.dart';
import 'package:canvas_quiz_exporter/ui/reference_controls.dart';
import 'package:canvas_quiz_exporter/ui/settings_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host(Widget child, {bool reduced = false}) => MaterialApp(
  theme: appTheme(false, 'violet'),
  home: Scaffold(
    body: MediaQuery(
      data: MediaQueryData(disableAnimations: reduced),
      child: Center(child: SizedBox(width: 306, child: child)),
    ),
  ),
);

void main() {
  testWidgets(
    'connected buttons keep their gap and squeeze neighbors on press',
    (tester) async {
      var selected = 0;
      await tester.pumpWidget(
        host(
          StatefulBuilder(
            builder: (context, setState) {
              return ReferenceButtonGroup<int>(
                items: const [
                  ReferenceSegment(value: 0, label: '原文件旁'),
                  ReferenceSegment(value: 1, label: '指定文件夹'),
                ],
                selected: selected,
                onSelected: (value) => setState(() => selected = value),
              );
            },
          ),
        ),
      );
      final surfaces = find.descendant(
        of: find.byType(ReferenceButtonGroup<int>),
        matching: find.byType(AnimatedContainer),
      );
      expect(tester.getSize(surfaces.first), const Size(152, 40));
      expect(
        tester.getTopLeft(surfaces.last).dx -
            tester.getTopRight(surfaces.first).dx,
        2,
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('指定文件夹')),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump(const Duration(milliseconds: 120));
      await tester.pump(const Duration(milliseconds: 350));
      expect(tester.getSize(surfaces.last).width, greaterThan(152));
      expect(tester.getSize(surfaces.first).width, lessThan(152));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(selected, 1);
      expect(tester.getSize(surfaces.first), const Size(152, 40));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'checkbox and switch accept keyboard activation and expose state',
    (tester) async {
      var checked = false, enabled = false;
      await tester.pumpWidget(
        host(
          StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ReferenceCheckbox(
                    value: checked,
                    label: 'PDF 文档',
                    onChanged: (value) => setState(() => checked = value),
                  ),
                  ReferenceSwitch(
                    value: enabled,
                    semanticLabel: '保存图片',
                    onChanged: (value) => setState(() => enabled = value),
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
      expect(checked, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(enabled, isTrue);
      expect(tester.getSize(find.byType(ReferenceSwitch)), const Size(52, 32));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'filled text field floats its label, grows for lines, and accepts external changes',
    (tester) async {
      var value = '';
      late StateSetter rebuild;
      await tester.pumpWidget(
        host(
          StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return SettingField(
                value: value,
                label: '每行一条 · 句子或脱敏词',
                leadingIcon: AppSymbols.filterAlt,
                multiline: true,
                onChanged: (text) => setState(() => value = text),
              );
            },
          ),
          reduced: true,
        ),
      );
      expect(tester.getSize(find.byType(SettingField)).height, 56);
      await tester.enterText(
        find.byType(TextField),
        'sentence one\nsentence two\nsentence three',
      );
      await tester.pumpAndSettle();
      expect(value, contains('sentence three'));
      expect(tester.getSize(find.byType(SettingField)).height, greaterThan(56));
      rebuild(() => value = 'replacement');
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'replacement',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('compact button group and long suggestion fit narrow content', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ReferenceButtonGroup<int>(
              items: const [
                ReferenceSegment(
                  value: 0,
                  label: '总览',
                  icon: AppSymbols.viewAgenda,
                ),
                ReferenceSegment(
                  value: 1,
                  label: 'PDF 分页',
                  icon: AppSymbols.pictureAsPdf,
                ),
              ],
              selected: 0,
              onSelected: (_) {},
              expanded: false,
              height: 32,
            ),
            ReferenceChip(
              label: 'A repeated sentence with enough words to exceed the available content width ×3',
              icon: AppSymbols.add,
              onPressed: () {},
            ),
          ],
        ),
        reduced: true,
      ),
    );
    expect(tester.getSize(find.byType(ReferenceButtonGroup<int>)).height, 32);
    expect(
      tester
          .renderObject<RenderParagraph>(find.text('PDF 分页'))
          .didExceedMaxLines,
      isFalse,
    );
    expect(
      tester.getSize(find.byType(ReferenceChip)).width,
      lessThanOrEqualTo(306),
    );
    await tester.tap(find.text('PDF 分页'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
