import 'package:flutter_test/flutter_test.dart';
import 'package:carelink/screens/post_job_screen.dart';

void main() {
  test('auto-detected location uses a default label when no manual name is supplied', () {
    expect(buildAutoLocationLabel(''), 'Current location');
    expect(buildAutoLocationLabel('   '), 'Current location');
    expect(buildAutoLocationLabel('Westlands'), 'Westlands');
  });
}
