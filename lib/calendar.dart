import 'package:flutter/material.dart';

import 'mochi.dart';
import 'models.dart';
import 'state.dart';
import 'theme.dart';
import 'utils.dart';
import 'widgets.dart';
import 'write.dart';

class CalendarTab extends StatefulWidget {
  const CalendarTab({super.key});
  @override
  State<CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends State<CalendarTab> {
  late DateTime _month;
  late DateTime _sel;

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _month = DateTime(n.year, n.month);
    _sel = DateTime(n.year, n.month, n.day);
  }

  void _shift(int delta) => setState(() => _month = DateTime(_month.year, _month.month + delta));

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final p = Pal.of(context);
        final now = DateTime.now();
        final byDay = <int, List<Entry>>{};
        for (final e in app.entries) {
          byDay.putIfAbsent(dayNum(e.createdAt), () => []).add(e);
        }
        final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
        final lead = DateTime(_month.year, _month.month, 1).weekday % 7; // Sunday first
        final selEntries = byDay[dayNum(_sel)] ?? const <Entry>[];

        Widget cell(int day) {
          final d = DateTime(_month.year, _month.month, day);
          final es = byDay[dayNum(d)];
          final today = sameDay(d, now);
          final sel = sameDay(d, _sel);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _sel = d),
            child: Container(
              decoration: BoxDecoration(
                color: today ? p.acc : (es != null ? p.bg : Colors.transparent),
                borderRadius: BorderRadius.circular(12),
                border: sel ? Border.all(color: p.acc2, width: 2) : null,
              ),
              child: Center(
                child: es != null
                    ? Mochi(mood: es.first.mood, size: 30)
                    : Text(
                        '$day',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: today ? Pal.onAcc : p.mute,
                        ),
                      ),
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            children: [
              Row(
                children: [
                  PawBtn(onTap: () => _shift(-1), child: const Icon(Icons.chevron_left)),
                  Expanded(
                    child: Center(
                      child: Text(
                        '${kMonths[_month.month - 1]} ${_month.year}',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  PawBtn(onTap: () => _shift(1), child: const Icon(Icons.chevron_right)),
                ],
              ),
              const SizedBox(height: 14),
              PawCard(
                padding: const EdgeInsets.all(10),
                child: Column(
                  children: [
                    Row(
                      children: [
                        for (final l in ['S', 'M', 'T', 'W', 'T', 'F', 'S'])
                          Expanded(
                            child: Center(
                              child: Text(
                                l,
                                style: TextStyle(
                                  color: p.mute,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    GridView.count(
                      crossAxisCount: 7,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 6,
                      crossAxisSpacing: 6,
                      children: [
                        for (var i = 0; i < lead; i++) const SizedBox.shrink(),
                        for (var d = 1; d <= daysInMonth; d++) cell(d),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: selEntries.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Mochi(mood: Mood.sleepy, size: 56),
                            const SizedBox(height: 6),
                            Text(
                              'Nothing written on ${shortDate(_sel)}',
                              style: TextStyle(color: p.mute),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: selEntries.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final e = selEntries[i];
                          return PawCard(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Mochi(mood: e.mood, size: 48),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${shortDate(e.createdAt)} · ${e.mood.label}',
                                        style: TextStyle(color: p.mute, fontSize: 12),
                                      ),
                                      Text(
                                        e.displayTitle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      if (e.plainBody.isNotEmpty)
                                        Text(
                                          e.plainBody,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(color: p.mute, fontSize: 13),
                                        ),
                                      const SizedBox(height: 8),
                                      PawBtn(
                                        accent: true,
                                        onTap: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => EntryEditorScreen(entry: e),
                                          ),
                                        ),
                                        child: const Text('Open entry'),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
