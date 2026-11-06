import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import 'theme.dart';
import 'widgets.dart';

// Official brand marks from the Simple Icons set (CC0 licence).
const String _githubPath =
    r'''M12 .297c-6.63 0-12 5.373-12 12 0 5.303 3.438 9.8 8.205 11.385.6.113.82-.258.82-.577 0-.285-.01-1.04-.015-2.04-3.338.724-4.042-1.61-4.042-1.61C4.422 18.07 3.633 17.7 3.633 17.7c-1.087-.744.084-.729.084-.729 1.205.084 1.838 1.236 1.838 1.236 1.07 1.835 2.809 1.305 3.495.998.108-.776.417-1.305.76-1.605-2.665-.3-5.466-1.332-5.466-5.93 0-1.31.465-2.38 1.235-3.22-.135-.303-.54-1.523.105-3.176 0 0 1.005-.322 3.3 1.23.96-.267 1.98-.399 3-.405 1.02.006 2.04.138 3 .405 2.28-1.552 3.285-1.23 3.285-1.23.645 1.653.24 2.873.12 3.176.765.84 1.23 1.91 1.23 3.22 0 4.61-2.805 5.625-5.475 5.92.42.36.81 1.096.81 2.22 0 1.606-.015 2.896-.015 3.286 0 .315.21.69.825.57C20.565 22.092 24 17.592 24 12.297c0-6.627-5.373-12-12-12''';
const String _leetcodePath =
    r'''M13.483 0a1.374 1.374 0 0 0-.961.438L7.116 6.226l-3.854 4.126a5.266 5.266 0 0 0-1.209 2.104 5.35 5.35 0 0 0-.125.513 5.527 5.527 0 0 0 .062 2.362 5.83 5.83 0 0 0 .349 1.017 5.938 5.938 0 0 0 1.271 1.818l4.277 4.193.039.038c2.248 2.165 5.852 2.133 8.063-.074l2.396-2.392c.54-.54.54-1.414.003-1.955a1.378 1.378 0 0 0-1.951-.003l-2.396 2.392a3.021 3.021 0 0 1-4.205.038l-.02-.019-4.276-4.193c-.652-.64-.972-1.469-.948-2.263a2.68 2.68 0 0 1 .066-.523 2.545 2.545 0 0 1 .619-1.164L9.13 8.114c1.058-1.134 3.204-1.27 4.43-.278l3.501 2.831c.593.48 1.461.387 1.94-.207a1.384 1.384 0 0 0-.207-1.943l-3.5-2.831c-.8-.647-1.766-1.045-2.774-1.202l2.015-2.158A1.384 1.384 0 0 0 13.483 0zm-2.866 12.815a1.38 1.38 0 0 0-1.38 1.382 1.38 1.38 0 0 0 1.38 1.382H20.79a1.38 1.38 0 0 0 1.38-1.382 1.38 1.38 0 0 0-1.38-1.382z''';

String _svg(String path) =>
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path d="$path"/></svg>';

/// "Find me online" cards shown at the very end of Settings.
class BrandLinks extends StatelessWidget {
  const BrandLinks({super.key});

  static const String githubUrl = 'https://github.com/mandeep-sabharwal';
  static const String leetcodeUrl = 'https://leetcode.com/u/mandeeepsingh/';

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Find me online',
            style: TextStyle(color: p.mute, fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
        _LinkCard(
          svg: _svg(_githubPath),
          tint: p.ink,
          title: 'GitHub',
          handle: '@mandeep-sabharwal',
          url: githubUrl,
        ),
        const SizedBox(height: 10),
        _LinkCard(
          svg: _svg(_leetcodePath),
          tint: const Color(0xFFFFA116),
          title: 'LeetCode',
          handle: '@mandeeepsingh',
          url: leetcodeUrl,
        ),
      ],
    );
  }
}

class _LinkCard extends StatelessWidget {
  const _LinkCard({
    required this.svg,
    required this.tint,
    required this.title,
    required this.handle,
    required this.url,
  });

  final String svg, title, handle, url;
  final Color tint;

  Future<void> _open(BuildContext context) async {
    var opened = false;
    try {
      opened = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!opened && context.mounted) {
      await Clipboard.setData(ClipboardData(text: url));
      if (context.mounted) toast(context, 'Could not open the link, so it was copied instead.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Semantics(
      button: true,
      label: 'Open $title profile',
      child: Material(
        color: p.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: p.line),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _open(context),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: tint.withAlpha(32),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: SvgPicture.string(
                    svg,
                    width: 26,
                    height: 26,
                    colorFilter: ColorFilter.mode(tint, BlendMode.srcIn),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                      Text(handle, style: TextStyle(color: p.mute, fontSize: 13)),
                    ],
                  ),
                ),
                Icon(Icons.open_in_new, size: 20, color: p.mute),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
