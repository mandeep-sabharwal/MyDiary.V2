import 'package:flutter/material.dart';

import 'utils.dart';

enum Mood { happy, excited, loved, calm, sleepy, sad, worried, grumpy, surprised, playful }

enum MoodGroup { happy, calm, low }

extension MoodX on Mood {
  String get label => const {
    Mood.happy: 'Happy',
    Mood.excited: 'Excited',
    Mood.loved: 'Loved',
    Mood.calm: 'Calm',
    Mood.sleepy: 'Sleepy',
    Mood.sad: 'Sad',
    Mood.worried: 'Worried',
    Mood.grumpy: 'Grumpy',
    Mood.surprised: 'Wow',
    Mood.playful: 'Playful',
  }[this]!;

  /// 1 (rough) .. 5 (great) - used for the weekly mood bars.
  int get score => const {
    Mood.excited: 5,
    Mood.loved: 5,
    Mood.happy: 4,
    Mood.playful: 4,
    Mood.calm: 3,
    Mood.surprised: 3,
    Mood.sleepy: 2,
    Mood.worried: 2,
    Mood.sad: 1,
    Mood.grumpy: 1,
  }[this]!;

  MoodGroup get group {
    switch (this) {
      case Mood.happy:
      case Mood.excited:
      case Mood.loved:
      case Mood.playful:
        return MoodGroup.happy;
      case Mood.calm:
      case Mood.surprised:
        return MoodGroup.calm;
      default:
        return MoodGroup.low;
    }
  }
}

Mood moodFromName(String? n) =>
    Mood.values.firstWhere((m) => m.name == n, orElse: () => Mood.happy);

/// Placeholder character in an entry's text where an inline photo sits.
const String kImgChar = '\uFFFC';

int countWords(String s) {
  final t = s.replaceAll(kImgChar, ' ').trim();
  return t.isEmpty ? 0 : t.split(RegExp(r'\s+')).length;
}

class Entry {
  Entry({
    required this.id,
    required this.createdAt,
    this.title = '',
    this.body = '',
    this.mood = Mood.happy,
    List<String>? photos,
    List<String>? stickers,
    this.seconds = 0,
    List<List<int>>? runs,
    int? updatedAt,
  }) : photos = photos ?? [],
       stickers = stickers ?? [],
       runs = runs ?? [],
       updatedAt = updatedAt ?? createdAt.millisecondsSinceEpoch;

  final String id;
  final DateTime createdAt;
  String title;
  String body;
  Mood mood;
  List<String> photos;
  List<String> stickers;
  int seconds;

  /// Rich-text formatting of [body]: [length, flags, colour, highlight] runs.
  List<List<int>> runs;

  /// Milliseconds since epoch; decides cloud sync conflicts (newest wins).
  int updatedAt;

  int get words => countWords(body);
  String get plainBody => body.replaceAll(kImgChar, '').trim();
  String get displayTitle => title.trim().isEmpty ? 'Untitled' : title.trim();

  Map<String, dynamic> toJson() => {
    'id': id,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'title': title,
    'body': body,
    'mood': mood.name,
    'photos': photos,
    'stickers': stickers,
    'seconds': seconds,
    'runs': runs,
    'updatedAt': updatedAt,
  };

  factory Entry.fromJson(Map<String, dynamic> j) => Entry(
    id: j['id'] as String,
    createdAt: DateTime.fromMillisecondsSinceEpoch(j['createdAt'] as int),
    title: (j['title'] as String?) ?? '',
    body: (j['body'] as String?) ?? '',
    mood: moodFromName(j['mood'] as String?),
    photos: ((j['photos'] as List?) ?? const []).cast<String>().toList(),
    stickers: ((j['stickers'] as List?) ?? const []).cast<String>().toList(),
    seconds: (j['seconds'] as int?) ?? 0,
    runs: ((j['runs'] as List?) ?? const []).map((r) => (r as List).cast<int>().toList()).toList(),
    updatedAt: j['updatedAt'] as int?,
  );
}

/// Everything the stats / achievements screens need, computed from entries.
class DiaryStats {
  DiaryStats({
    required this.entries,
    required this.words,
    required this.days,
    required this.current,
    required this.longest,
    required this.night,
    required this.moods,
    required this.avgSeconds,
  });

  final int entries, words, days, current, longest, night, moods;
  final double avgSeconds;

  factory DiaryStats.from(List<Entry> list) {
    final daySet = <int>{};
    final moodSet = <Mood>{};
    var words = 0, night = 0, secs = 0, timed = 0;
    for (final e in list) {
      daySet.add(dayNum(e.createdAt));
      moodSet.add(e.mood);
      words += e.words;
      if (e.createdAt.hour < 5) night++;
      if (e.seconds > 0) {
        secs += e.seconds;
        timed++;
      }
    }
    final sorted = daySet.toList()..sort();
    var longest = 0, run = 0;
    for (var i = 0; i < sorted.length; i++) {
      run = (i > 0 && sorted[i] == sorted[i - 1] + 1) ? run + 1 : 1;
      if (run > longest) longest = run;
    }
    final today = dayNum(DateTime.now());
    var d = daySet.contains(today) ? today : today - 1;
    var cur = 0;
    while (daySet.contains(d)) {
      cur++;
      d--;
    }
    return DiaryStats(
      entries: list.length,
      words: words,
      days: daySet.length,
      current: cur,
      longest: longest,
      night: night,
      moods: moodSet.length,
      avgSeconds: timed == 0 ? 0 : secs / timed,
    );
  }
}

double _f(num a, num b) => (a / b).clamp(0.0, 1.0).toDouble();

class Achievement {
  const Achievement({
    required this.id,
    required this.title,
    required this.desc,
    required this.icon,
    required this.rewardId,
    required this.progress,
  });
  final String id, title, desc, rewardId;
  final IconData icon;
  final double Function(DiaryStats) progress;
}

final List<Achievement> kAchievements = [
  Achievement(
    id: 'first_page',
    title: 'First page',
    desc: 'Write 1 entry',
    icon: Icons.edit_note,
    rewardId: 'party_hat',
    progress: (s) => _f(s.entries, 1),
  ),
  Achievement(
    id: 'streak7',
    title: '7-day streak',
    desc: 'Write 7 days in a row',
    icon: Icons.local_fire_department_outlined,
    rewardId: 'mint_scarf',
    progress: (s) => _f(s.longest, 7),
  ),
  Achievement(
    id: 'night_owl',
    title: 'Night owl',
    desc: 'Write after midnight',
    icon: Icons.nightlight_outlined,
    rewardId: 'night_cap',
    progress: (s) => _f(s.night, 1),
  ),
  Achievement(
    id: 'entries100',
    title: '100 entries',
    desc: 'Fill 100 pages',
    icon: Icons.menu_book_outlined,
    rewardId: 'gold_crown',
    progress: (s) => _f(s.entries, 100),
  ),
  Achievement(
    id: 'wordsmith',
    title: 'Wordsmith',
    desc: 'Write 10k words',
    icon: Icons.text_fields,
    rewardId: 'round_specs',
    progress: (s) => _f(s.words, 10000),
  ),
  Achievement(
    id: 'streak30',
    title: '30-day streak',
    desc: 'Write 30 days in a row',
    icon: Icons.star_outline,
    rewardId: 'star_aura',
    progress: (s) => _f(s.longest, 30),
  ),
  Achievement(
    id: 'rainbow',
    title: 'Mood rainbow',
    desc: 'Log 6 different moods',
    icon: Icons.palette_outlined,
    rewardId: 'pink_bow',
    progress: (s) => _f(s.moods, 6),
  ),
  Achievement(
    id: 'full_year',
    title: 'Full year',
    desc: 'Write 365 days',
    icon: Icons.calendar_month_outlined,
    rewardId: 'garden_theme',
    progress: (s) => _f(s.days, 365),
  ),
];

enum Slot { hat, face, neck, theme }

extension SlotX on Slot {
  String get label =>
      const {Slot.hat: 'Hats', Slot.face: 'Faces', Slot.neck: 'Neck', Slot.theme: 'Themes'}[this]!;
}

class Reward {
  const Reward(this.id, this.name, this.slot, this.achievementId);
  final String id, name, achievementId;
  final Slot slot;
}

const List<Reward> kRewards = [
  Reward('party_hat', 'Party hat', Slot.hat, 'first_page'),
  Reward('night_cap', 'Night cap', Slot.hat, 'night_owl'),
  Reward('gold_crown', 'Gold crown', Slot.hat, 'entries100'),
  Reward('pink_bow', 'Pink bow', Slot.hat, 'rainbow'),
  Reward('round_specs', 'Round specs', Slot.face, 'wordsmith'),
  Reward('mint_scarf', 'Mint scarf', Slot.neck, 'streak7'),
  Reward('star_aura', 'Star aura', Slot.theme, 'streak30'),
  Reward('garden_theme', 'Garden theme', Slot.theme, 'full_year'),
];

Reward? rewardById(String id) {
  for (final r in kRewards) {
    if (r.id == id) return r;
  }
  return null;
}
