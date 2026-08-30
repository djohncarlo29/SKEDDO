import 'package:flutter_test/flutter_test.dart';
import 'package:smart_scheduler/services/alert_sequence.dart';

void main() {
  const minutes = <String, int>{
    'None': -1,
    '1 week before': 10080,
    '1 day before': 1440,
    '1 hour before': 60,
    'At time of event': 0,
  };

  test('compacts the sequence at None and removes empty legacy values', () {
    expect(
      AlertSequence.compact([
        '1 week before',
        '1 day before',
        'None',
        '1 hour before',
      ]),
      ['1 week before', '1 day before'],
    );
    expect(AlertSequence.compact([null, '1 week before']), isEmpty);
  });

  test('validates strictly closer ordered alerts without duplicates', () {
    expect(
      AlertSequence.isValid([
        '1 week before',
        '1 day before',
        '1 hour before',
        'At time of event',
      ], minutes),
      isTrue,
    );
    expect(
      AlertSequence.isValid(['1 day before', '1 week before'], minutes),
      isFalse,
    );
    expect(
      AlertSequence.isValid(['1 day before', '1 day before'], minutes),
      isFalse,
    );
  });
}
