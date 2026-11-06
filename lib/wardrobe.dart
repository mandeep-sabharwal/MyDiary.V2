import 'package:flutter/material.dart';

import 'mochi.dart';
import 'models.dart';
import 'state.dart';
import 'theme.dart';
import 'widgets.dart';

class WardrobeScreen extends StatefulWidget {
  const WardrobeScreen({super.key});
  @override
  State<WardrobeScreen> createState() => _WardrobeScreenState();
}

class _WardrobeScreenState extends State<WardrobeScreen> {
  Slot _slot = Slot.hat;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final p = Pal.of(context);
        final items = kRewards.where((r) => r.slot == _slot).toList();
        final owned = app.unlockedIds;
        final count = app.equipped.length;

        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                const TopBar(title: 'Wardrobe'),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    children: [
                      PawCard(
                        color: p.acc2,
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                              decoration: BoxDecoration(color: p.card, shape: BoxShape.circle),
                              child: Mochi(mood: app.mascotMood, size: 96, dressed: true),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Mochi, dressed up',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: app.garden ? p.ink : Pal.onAcc,
                              ),
                            ),
                            Text(
                              '$count ${count == 1 ? 'item' : 'items'} equipped',
                              style: TextStyle(color: app.garden ? p.ink : Pal.onAcc),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          for (final s in Slot.values) ...[
                            Expanded(
                              child: PawBtn(
                                selected: s == _slot,
                                padding: EdgeInsets.zero,
                                onTap: () => setState(() => _slot = s),
                                child: Text(s.label, style: const TextStyle(fontSize: 13)),
                              ),
                            ),
                            if (s != Slot.values.last) const SizedBox(width: 6),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: items.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          mainAxisExtent: 148,
                        ),
                        itemBuilder: (_, i) {
                          final r = items[i];
                          final has = owned.contains(r.achievementId);
                          final on = app.equipped[r.slot.name] == r.id;
                          final ach = kAchievements.firstWhere((a) => a.id == r.achievementId);
                          return Opacity(
                            opacity: has ? 1 : 0.7,
                            child: Material(
                              color: p.card,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(color: on ? p.acc : p.line, width: on ? 2 : 1),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: has
                                    ? () => app.toggleEquip(r)
                                    : () => toast(context, 'Unlock it with: ${ach.title}'),
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(6, 8, 6, 6),
                                  child: Column(
                                    children: [
                                      SizedBox(
                                        height: 72,
                                        child: kMochiHasArt(r.id)
                                            ? Mochi(items: [r.id], size: 58)
                                            : Icon(
                                                Icons.local_florist_outlined,
                                                size: 44,
                                                color: p.acc2,
                                              ),
                                      ),
                                      Text(
                                        r.name,
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                      Text(
                                        on ? 'Equipped' : (has ? 'Owned' : 'Locked: ${ach.title}'),
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(color: p.mute, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
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
