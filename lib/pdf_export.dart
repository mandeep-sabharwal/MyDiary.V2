import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'mochi.dart' show buildMochi;
import 'models.dart';
import 'rich.dart' show Fmt, RichController;
import 'state.dart';
import 'utils.dart';

/// Builds a PDF of the whole diary (formatting, photos and Mochi moods included)
/// and opens the Android share sheet so it can be saved or sent.
Future<void> exportDiaryPdf() async {
  final theme = await _theme();
  final doc = pw.Document(
    title: 'Pawsie Diary',
    author: app.userName.isEmpty ? null : app.userName,
  );

  final children = <pw.Widget>[
    pw.Text(
      app.userName.isEmpty ? 'My Pawsie Diary' : "${app.userName}'s Pawsie Diary",
      style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
    ),
    pw.SizedBox(height: 4),
    pw.Text(
      '${app.entries.length} ${app.entries.length == 1 ? 'entry' : 'entries'}  ·  exported ${longDate(DateTime.now())} ${DateTime.now().year}',
      style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
    ),
    pw.SizedBox(height: 10),
    pw.Divider(color: PdfColors.grey400),
  ];
  if (app.entries.isEmpty) {
    children.add(pw.Text('Nothing written yet.'));
  }
  for (final e in app.entries.reversed) {
    children.addAll(await _entryWidgets(e));
  }

  doc.addPage(
    pw.MultiPage(
      theme: theme,
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      maxPages: 5000,
      footer: (c) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          '${c.pageNumber} / ${c.pagesCount}',
          style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
        ),
      ),
      build: (_) => children,
    ),
  );

  final bytes = await doc.save();
  await Printing.sharePdf(bytes: bytes, filename: 'pawsie-diary.pdf');
}

/// Noto Sans (with Devanagari fallback) so Hindi and other scripts print. Needs
/// internet the first time; offline it falls back to the built-in Latin font.
Future<pw.ThemeData> _theme() async {
  try {
    final base = await PdfGoogleFonts.notoSansRegular();
    final bold = await PdfGoogleFonts.notoSansBold();
    final italic = await PdfGoogleFonts.notoSansItalic();
    final boldItalic = await PdfGoogleFonts.notoSansBoldItalic();
    final deva = await PdfGoogleFonts.notoSansDevanagariRegular();
    return pw.ThemeData.withFont(
      base: base,
      bold: bold,
      italic: italic,
      boldItalic: boldItalic,
      fontFallback: [deva],
    );
  } catch (_) {
    return pw.ThemeData.base();
  }
}

pw.TextStyle _style(Fmt f) => pw.TextStyle(
  fontWeight: f.b ? pw.FontWeight.bold : null,
  fontStyle: f.i ? pw.FontStyle.italic : null,
  decoration: f.u ? pw.TextDecoration.underline : null,
  color: f.color != 0 ? PdfColor.fromInt(f.color) : null,
  background: f.hl != 0 ? pw.BoxDecoration(color: PdfColor.fromInt(f.hl)) : null,
);

Future<List<pw.Widget>> _entryWidgets(Entry e) async {
  final out = <pw.Widget>[
    pw.SizedBox(height: 16),
    pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.SvgImage(svg: buildMochi(e.mood.name, const []), width: 30, height: 30),
        pw.SizedBox(width: 8),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                '${longDate(e.createdAt)} ${e.createdAt.year}  ·  ${e.mood.label}',
                style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
              ),
              pw.Text(
                e.displayTitle,
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
        ),
      ],
    ),
    pw.SizedBox(height: 6),
  ];

  var spans = <pw.InlineSpan>[];
  void flush() {
    if (spans.isEmpty) return;
    out.add(
      pw.RichText(
        text: pw.TextSpan(children: spans, style: pw.TextStyle(fontSize: 11, lineSpacing: 3)),
      ),
    );
    spans = <pw.InlineSpan>[];
  }

  final body = e.body;
  final fmts = RichController.decodeRuns(body.length, e.runs);
  var imgIdx = 0;
  var start = 0;
  for (var i = 1; i <= body.length; i++) {
    if (i == body.length || fmts[i] != fmts[start]) {
      final st = _style(fmts[start]);
      var seg = body.substring(start, i);
      while (true) {
        final k = seg.indexOf(kImgChar);
        if (k < 0) break;
        if (k > 0) spans.add(pw.TextSpan(text: seg.substring(0, k), style: st));
        flush();
        final name = imgIdx < e.photos.length ? e.photos[imgIdx] : null;
        imgIdx++;
        final bytes = name == null ? null : await app.photoBytes(name);
        pw.Widget? img;
        if (bytes != null) {
          try {
            img = pw.Image(
              pw.MemoryImage(bytes),
              height: 200,
              fit: pw.BoxFit.contain,
              alignment: pw.Alignment.centerLeft,
            );
          } catch (_) {
            img = null;
          }
        }
        out.add(
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 4),
            child:
                img ??
                pw.Text(
                  '[photo not available on this device]',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontStyle: pw.FontStyle.italic,
                    color: PdfColors.grey600,
                  ),
                ),
          ),
        );
        seg = seg.substring(k + 1);
      }
      if (seg.isNotEmpty) spans.add(pw.TextSpan(text: seg, style: st));
      start = i;
    }
  }
  flush();
  out.add(pw.SizedBox(height: 10));
  out.add(pw.Divider(color: PdfColors.grey300));
  return out;
}
