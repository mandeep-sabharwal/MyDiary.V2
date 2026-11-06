import 'package:flutter/material.dart';

import 'achievements.dart';
import 'mochi.dart';
import 'models.dart';
import 'state.dart';
import 'theme.dart';
import 'utils.dart';
import 'widgets.dart';

class StatsTab extends StatelessWidget {
  const StatsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final p = Pal.of(context);
        final s = app.stats;

        // Mood this week (Monday first)
        final now = DateTime.now();
        final monday = DateTime(now.year, now.month, now.day - (now.weekday - 1));
        final scores = <double?>[];
        for (var i = 0; i < 7; i++) {
          final day = DateTime(monday.year, monday.month, monday.day + i);
          final es = app.entriesOn(day);
          scores.add(
            es.isEmpty ? null : es.map((e) => e.mood.score).reduce((a, b) => a + b) / es.length / 5,
          );
        }

        // Mood mix
        final mix = {for (final g in MoodGroup.values) g: 0};
        for (final e in app.entries) {
          mix[e.mood.group] = mix[e.mood.group]! + 1;
        }
        final total = app.entries.length;
        const mixNames = {MoodGroup.happy: 'Happy', MoodGroup.calm: 'Calm', MoodGroup.low: 'Low'};
        final mixColors = {
          MoodGroup.happy: p.acc,
          MoodGroup.calm: p.acc2,
          MoodGroup.low: const Color(0xFF8EC5FF),
        };

        Widget statBox(String value, String label) => Expanded(
          child: PawCard(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                Text(label, style: TextStyle(color: p.mute, fontSize: 12)),
              ],
            ),
          ),
        );

        Widget linkRow(IconData icon, String title, String sub, Widget page) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Material(
            color: p.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: p.line),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Icon(icon),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                          ),
                          Text(sub, style: TextStyle(color: p.mute, fontSize: 12)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ),
          ),
        );

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          children: [
            const Text('Your stats', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            PawCard(
              color: p.acc2,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Mochi(
                    mood: s.current >= 3 ? Mood.excited : app.mascotMood,
                    size: 72,
                    dressed: true,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.current == 1 ? '1 day' : '${s.current} days',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            color: app.garden ? p.ink : Pal.onAcc,
                          ),
                        ),
                        Text(
                          s.current == 0
                              ? 'Write today to start a streak. Mochi is waiting!'
                              : 'Writing streak. Mochi is so proud!',
                          style: TextStyle(color: app.garden ? p.ink : Pal.onAcc),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                statBox('${s.entries}', 'Entries'),
                const SizedBox(width: 10),
                statBox(compactCount(s.words), 'Words'),
                const SizedBox(width: 10),
                statBox(s.avgSeconds == 0 ? '-' : mmss(s.avgSeconds), 'Avg. time'),
              ],
            ),
            const SizedBox(height: 10),
            PawCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Mood this week',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 120,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (final v in scores)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Container(
                                height: v == null ? 6 : 12 + v * 108,
                                decoration: BoxDecoration(
                                  color: v == null ? p.line : p.acc,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      for (final l in ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                        Expanded(
                          child: Center(
                            child: Text(l, style: TextStyle(color: p.mute, fontSize: 12)),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            PawCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Mood mix',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  if (total == 0)
                    Text(
                      'Your mood mix appears after your first entry.',
                      style: TextStyle(color: p.mute, fontSize: 13),
                    )
                  else ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Row(
                        children: [
                          for (final g in MoodGroup.values)
                            if (mix[g]! > 0)
                              Expanded(
                                flex: mix[g]!,
                                child: Container(height: 12, color: mixColors[g]),
                              ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      [
                        for (final g in MoodGroup.values)
                          if (mix[g]! > 0) '${(mix[g]! * 100 / total).round()}% ${mixNames[g]}',
                      ].join(' · '),
                      style: TextStyle(color: p.mute, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            linkRow(
              Icons.emoji_events_outlined,
              'Achievements',
              '${app.unlockedIds.length} of ${kAchievements.length} unlocked',
              const AchievementsScreen(),
            ),
          ],
        );
      },
    );
  }
}
