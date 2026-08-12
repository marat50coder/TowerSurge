import 'package:flutter_test/flutter_test.dart';
import 'package:towersurgegame/core/palette.dart';

void main() {
  test('amounts drop trailing zeros and group thousands', () {
    expect(fmtAmount(100), '100');
    expect(fmtAmount(203.5), '203.5');
    expect(fmtAmount(305.25), '305.25');
    expect(fmtAmount(100000), '100\u2009000');
  });

  test('multipliers are formatted like the results panel', () {
    expect(fmtMultiplier(1), 'x1');
    expect(fmtMultiplier(1.05), 'x1.05');
    expect(fmtMultiplier(0.65), 'x0.65');
    expect(fmtMultiplier(0), 'x0');
  });
}
