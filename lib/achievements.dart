import 'package:flutter/material.dart';

import 'models.dart';
import 'state.dart';
import 'theme.dart';
import 'widgets.dart';

class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final p = Pal.of(context);
        final s = app.stats;
        final progress = {for (final a in kAchievements) a.id: a.progress(s)};
        final done = progress.values.where((v) => v >= 1).length;
        final locked = kAchievements.where((a) => progress[a.id]! < 1).toList()
          ..sort((a, b) => progress[b.id]!.compareTo(progress[a.id]!));

        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                const TopBar(title: 'Achievements'),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    children: [
                      PawCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '$done of ${kAchievements.length} unlocked',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                                ),
                                Flexible(
                                  child: Text(
                                    locked.isEmpty ? 'All done!' : 'Next: ${locked.first.title}',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: p.mute, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: done / kAchievements.length,
                                minHeight: 12,
                                backgroundColor: p.bg,
                                color: p.acc,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: kAchievements.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          mainAxisExtent: 196,
                        ),
                        itemBuilder: (_, i) {
                          final a = kAchievements[i];
                          final v = progress[a.id]!;
                          final got = v >= 1;
                          final reward = rewardById(a.rewardId)?.name ?? '';
                          return Opacity(
                            opacity: got ? 1 : 0.85,
                            child: PawCard(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 52,
                                    height: 52,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: got ? p.acc : p.line,
                                    ),
                                    child: Icon(a.icon, color: got ? Pal.onAcc : p.mute, size: 26),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    a.title,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(a.desc, style: TextStyle(color: p.mute, fontSize: 12)),
                                  const Spacer(),
                                  if (!got) ...[
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(3),
                                      child: LinearProgressIndicator(
                                        value: v,
                                        minHeight: 6,
                                        backgroundColor: p.bg,
                                        color: p.acc2,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                  ],
                                  Text(
                                    'Reward: $reward',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 12, color: got ? p.acc : p.mute),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
