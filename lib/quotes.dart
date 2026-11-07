import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'state.dart';
import 'theme.dart';
import 'utils.dart';

class Quote {
  const Quote(this.text, this.author);
  final String text, author;

  /// Parses the DummyJSON shape: {"id": 62, "quote": "...", "author": "..."}.
  factory Quote.fromJson(Map<String, dynamic> j) {
    final text = (j['quote'] as String?)?.trim() ?? '';
    final author = (j['author'] as String?)?.trim() ?? '';
    if (text.isEmpty) throw const FormatException('No quote text');
    return Quote(text, author.isEmpty ? 'Unknown' : author);
  }

  Map<String, dynamic> toJson() => {'quote': text, 'author': author};
}

final QuoteService quotes = QuoteService();

/// "Thought of the day" from a public REST API (https://dummyjson.com/quotes/random).
///
/// * one anonymous GET per day (nothing about you or your diary is sent)
/// * the day's quote is cached, so reopening the app does not call the API again
/// * if you are offline, a built-in proverb is shown instead, so the card is never empty
class QuoteService {
  static final Uri _endpoint = Uri.https('dummyjson.com', '/quotes/random');

  final ValueNotifier<Quote?> current = ValueNotifier<Quote?>(null);
  final ValueNotifier<bool> loading = ValueNotifier<bool>(false);

  static const List<Quote> _fallback = [
    Quote('The unexamined life is not worth living.', 'Socrates'),
    Quote('Well begun is half done.', 'Aristotle'),
    Quote('No act of kindness, no matter how small, is ever wasted.', 'Aesop'),
    Quote('The journey of a thousand miles begins with a single step.', 'Lao Tzu'),
    Quote('Fall seven times, stand up eight.', 'Japanese proverb'),
    Quote('A small deed done is better than a great deed planned.', 'Peter Marshall'),
    Quote('Slow and steady wins the race.', 'Aesop'),
    Quote('Even the darkest night will end and the sun will rise.', 'Victor Hugo'),
  ];

  Quote _fallbackFor(int day) => _fallback[day % _fallback.length];

  /// Shows today's quote: from the cache if we already fetched one today, else the API.
  Future<void> loadToday() async {
    if (loading.value) return;
    final prefs = await SharedPreferences.getInstance();
    final today = dayNum(DateTime.now());
    if (prefs.getInt('quote_day') == today) {
      final cached = prefs.getString('quote_json');
      if (cached != null) {
        try {
          current.value = Quote.fromJson(jsonDecode(cached) as Map<String, dynamic>);
          return;
        } catch (_) {
          // fall through and fetch a fresh one
        }
      }
    }
    await _fetch(prefs, today);
  }

  /// "Another thought": asks the API again and keeps it as today's quote.
  Future<void> another() async {
    if (loading.value) return;
    final prefs = await SharedPreferences.getInstance();
    await _fetch(prefs, dayNum(DateTime.now()));
  }

  Future<void> _fetch(SharedPreferences prefs, int today) async {
    loading.value = true;
    try {
      final data = await ApiClient.getJson(_endpoint);
      final q = Quote.fromJson(data as Map<String, dynamic>);
      current.value = q;
      await prefs.setInt('quote_day', today);
      await prefs.setString('quote_json', jsonEncode(q.toJson()));
    } catch (_) {
      // Offline or the API is down: keep what we have, or show a built-in proverb.
      current.value ??= _fallbackFor(today);
    } finally {
      loading.value = false;
    }
  }
}

/// The card on the Write screen. Tap the pencil to start your entry from the quote.
class QuoteCard extends StatelessWidget {
  const QuoteCard({super.key, required this.onUse});
  final void Function(Quote quote) onUse;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        if (!app.showQuote) return const SizedBox.shrink();
        final p = Pal.of(context);
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ValueListenableBuilder<Quote?>(
            valueListenable: quotes.current,
            builder: (context, q, _) => Container(
              padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
              decoration: BoxDecoration(
                color: p.acc2.withAlpha(70),
                border: Border.all(color: p.line),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Icon(Icons.format_quote, color: p.acc, size: 26),
                  const SizedBox(width: 8),
                  Expanded(
                    child: q == null
                        ? Text(
                            'Mochi is finding a thought for you...',
                            style: TextStyle(color: p.mute, fontSize: 13),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                q.text,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontStyle: FontStyle.italic,
                                  height: 1.3,
                                ),
                              ),
                              Text(
                                '- ${q.author}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: p.mute, fontSize: 12),
                              ),
                            ],
                          ),
                  ),
                  ValueListenableBuilder<bool>(
                    valueListenable: quotes.loading,
                    builder: (context, busy, _) => IconButton(
                      tooltip: 'Another thought',
                      visualDensity: VisualDensity.compact,
                      onPressed: busy ? null : quotes.another,
                      icon: const Icon(Icons.refresh),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Write about this',
                    visualDensity: VisualDensity.compact,
                    onPressed: q == null ? null : () => onUse(q),
                    icon: Icon(Icons.edit_note, color: p.acc),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
