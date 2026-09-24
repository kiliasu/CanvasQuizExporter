import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/src/pdf/font/ttf_parser.dart';

void main() {
  test('every Rounded icon codepoint exists in the bundled font', () {
    final font = TtfParser(
      ByteData.sublistView(
        File('assets/fonts/material-symbols-rounded.ttf').readAsBytesSync(),
      ),
    );
    final source = File('lib/ui/app_symbols.dart').readAsStringSync();
    final icons = RegExp(
      r'IconData\(\s*0x([0-9a-f]+)',
      caseSensitive: false,
    ).allMatches(source).toList();
    expect(icons, isNotEmpty);
    for (final icon in icons) {
      final codepoint = int.parse(icon[1]!, radix: 16);
      expect(
        font.charToGlyphIndexMap[codepoint],
        isNotNull,
        reason: 'Missing Rounded glyph U+${icon[1]}',
      );
      expect(font.charToGlyphIndexMap[codepoint], isNot(0));
    }
  });
}
