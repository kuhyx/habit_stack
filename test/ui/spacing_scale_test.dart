import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards design rule "every spacing value lands on the 4px scale": screens
/// must use `AppSpacing.*` tokens, never bare numeric literals.
void main() {
  test('screens use AppSpacing tokens, not numeric spacing literals', () {
    final literal = RegExp(
      r'(SizedBox\((height|width): *\d|EdgeInsets\.[a-zA-Z]+\([^)]*\b\d|'
      r'(horizontal|vertical|right|left|top|bottom): *\d)',
    );
    final offenders = <String>[];
    for (final file in Directory('lib/screens').listSync()) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (literal.hasMatch(lines[i])) {
          offenders.add('${file.path}:${i + 1}: ${lines[i].trim()}');
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
