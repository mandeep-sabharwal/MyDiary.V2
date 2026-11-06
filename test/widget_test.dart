import 'package:flutter_test/flutter_test.dart';
import 'package:pawsie_diary/models.dart';

void main() {
  test('word counting ignores photo placeholders', () {
    expect(countWords('  a slow golden afternoon '), 4);
    expect(countWords('one $kImgChar two'), 2);
    expect(countWords(''), 0);
  });

  test('streak and achievements', () {
    final now = DateTime.now();
    final entries = [
      for (var i = 0; i < 7; i++)
        Entry(
          id: '$i',
          createdAt: now.subtract(Duration(days: i)),
          body: 'hello world',
        ),
    ];
    final s = DiaryStats.from(entries);
    expect(s.current, 7);
    expect(kAchievements.firstWhere((a) => a.id == 'streak7').progress(s), 1.0);
  });

  test('entry survives json round trip (formatting, photos, updatedAt)', () {
    final e = Entry(
      id: 'x',
      createdAt: DateTime(2026, 11, 1, 20),
      title: 't',
      body: 'hi $kImgChar',
      photos: ['p.enc'],
      runs: [
        [3, 1, 0, 0],
        [1, 0, 0, 0],
      ],
      updatedAt: 42,
    );
    final back = Entry.fromJson(e.toJson());
    expect(back.photos, ['p.enc']);
    expect(back.runs.first, [3, 1, 0, 0]);
    expect(back.updatedAt, 42);
    expect(back.plainBody, 'hi');
  });
}
