import 'dart:convert';
import 'dart:io';

import 'package:canvas_quiz_exporter/ui/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('answer-state colors match the design in every theme', () {
    final fixtures = jsonDecode(
      File('test/fixtures/reference_colors.json').readAsStringSync(),
    ) as Map;
    for (final entry in fixtures.entries) {
      final parts = (entry.key as String).split('/');
      final cs = referenceColors(parts[0] == 'dark', parts[1]);
      final actual = <String, Color>{
        'primary-container': cs.primaryContainer,
        'on-primary-container': cs.onPrimaryContainer,
        'secondary-container': cs.secondaryContainer,
        'on-secondary-container': cs.onSecondaryContainer,
      };
      for (final role in actual.entries) {
        expect(
          role.value.toARGB32(),
          0xff000000 |
              int.parse(
                (entry.value[role.key] as String).substring(1),
                radix: 16,
              ),
          reason: '${entry.key}/${role.key}',
        );
      }
    }
  });
}
