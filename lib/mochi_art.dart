// GENERATED from the Pawsie Diary design file (Mochi the cat). Edit with care.
// ignore_for_file: lines_longer_than_80_chars

const String kMochiBase = r'''<path d="M20 40L24 12L46 28ZM80 40L76 12L54 28Z" fill="#FFC9A8" stroke="#3B2F3F" stroke-width="3" stroke-linejoin="round"></path><circle cx="50" cy="58" r="34" fill="#FFC9A8" stroke="#3B2F3F" stroke-width="3"></circle><ellipse cx="30" cy="62" rx="6" ry="4" fill="#F59BB0"></ellipse><ellipse cx="70" cy="62" rx="6" ry="4" fill="#F59BB0"></ellipse>''';

const String kMochiGroupOpen = r'''<g fill="none" stroke="#3B2F3F" stroke-width="3" stroke-linecap="round" stroke-linejoin="round">''';

const Map<String, String> kMochiFaces = {
  'happy': r'''<circle cx="38" cy="52" r="5.5" fill="#3B2F3F" stroke="none"></circle><circle cx="62" cy="52" r="5.5" fill="#3B2F3F" stroke="none"></circle><circle cx="40" cy="50" r="1.8" fill="#fff" stroke="none"></circle><circle cx="64" cy="50" r="1.8" fill="#fff" stroke="none"></circle><path d="M43 64q7 8 14 0"></path>''',
  'excited': r'''<circle cx="38" cy="52" r="7.5" fill="#3B2F3F" stroke="none"></circle><circle cx="62" cy="52" r="7.5" fill="#3B2F3F" stroke="none"></circle><circle cx="40" cy="50" r="2.6" fill="#fff" stroke="none"></circle><circle cx="64" cy="50" r="2.6" fill="#fff" stroke="none"></circle><path d="M42 62q8 14 16 0z"></path><path d="M16 22l3 6 6 1-5 4 1 6-5-4-6 3 2-6-5-4 6-1z" fill="#FFD66B" stroke="none"></path>''',
  'loved': r'''<path d="M38 60q-10-7-6-12q4-4 6 0q2-4 6 0q4 5-6 12zM62 60q-10-7-6-12q4-4 6 0q2-4 6 0q4 5-6 12z" fill="#F0607E" stroke="none"></path><path d="M44 65q6 6 12 0"></path>''',
  'calm': r'''<path d="M32 54q6-7 12 0M56 54q6-7 12 0"></path><path d="M45 64q5 4 10 0"></path>''',
  'sleepy': r'''<path d="M32 52q6 6 12 0M56 52q6 6 12 0"></path><path d="M47 66h6"></path><path d="M72 18h8l-8 9h8"></path>''',
  'sad': r'''<circle cx="38" cy="52" r="5.5" fill="#3B2F3F" stroke="none"></circle><circle cx="62" cy="52" r="5.5" fill="#3B2F3F" stroke="none"></circle><circle cx="40" cy="50" r="1.8" fill="#fff" stroke="none"></circle><circle cx="64" cy="50" r="1.8" fill="#fff" stroke="none"></circle><path d="M30 42l12 4M70 42l-12 4"></path><path d="M43 70q7-7 14 0"></path><path d="M66 58q4 6 0 9q-4-3 0-9" fill="#8EC5FF" stroke="none"></path>''',
  'worried': r'''<circle cx="38" cy="52" r="5.5" fill="#3B2F3F" stroke="none"></circle><circle cx="62" cy="52" r="5.5" fill="#3B2F3F" stroke="none"></circle><circle cx="40" cy="50" r="1.8" fill="#fff" stroke="none"></circle><circle cx="64" cy="50" r="1.8" fill="#fff" stroke="none"></circle><path d="M30 45l12-5M70 45l-12-5"></path><path d="M43 69q3-4 6 0q3 4 6 0q3-4 6 0"></path>''',
  'grumpy': r'''<circle cx="38" cy="52" r="5" fill="#3B2F3F" stroke="none"></circle><circle cx="62" cy="52" r="5" fill="#3B2F3F" stroke="none"></circle><circle cx="40" cy="50" r="1.5" fill="#fff" stroke="none"></circle><circle cx="64" cy="50" r="1.5" fill="#fff" stroke="none"></circle><path d="M30 40l14 6M70 40l-14 6"></path><path d="M43 70q7-6 14 0"></path><path d="M80 30l4-4M84 36h5" stroke="#F0607E"></path>''',
  'surprised': r'''<circle cx="38" cy="52" r="7" fill="#3B2F3F" stroke="none"></circle><circle cx="62" cy="52" r="7" fill="#3B2F3F" stroke="none"></circle><circle cx="40" cy="50" r="2.4" fill="#fff" stroke="none"></circle><circle cx="64" cy="50" r="2.4" fill="#fff" stroke="none"></circle><path d="M46 66a4 5 0 1 0 8 0a4 5 0 1 0 -8 0"></path><path d="M30 40q8-5 14 0M56 40q8-5 14 0"></path>''',
  'playful': r'''<circle cx="38" cy="52" r="5.5" fill="#3B2F3F" stroke="none"></circle><circle cx="40" cy="50" r="1.8" fill="#fff" stroke="none"></circle><path d="M56 53q6-6 12 0"></path><path d="M42 63q8 9 16 0"></path><path d="M82 20l2 5 5 2-5 2-2 5-2-5-5-2 5-2z" fill="#FFD66B" stroke="none"></path>''',
  'wink': r'''<circle cx="38" cy="52" r="5.5" fill="#3B2F3F" stroke="none"></circle><circle cx="40" cy="50" r="1.8" fill="#fff" stroke="none"></circle><path d="M56 53q6-6 12 0"></path><path d="M42 63q8 9 16 0"></path><path d="M82 20l2 5 5 2-5 2-2 5-2-5-5-2 5-2z" fill="#FFD66B" stroke="none"></path>''',
};

const Map<String, String> kMochiAccessories = {
  'party_hat': r'''<path d="M36 26L50 -4L64 26z" fill="#8F7BD1" stroke-width="3"></path><circle cx="50" cy="-5" r="4" fill="#FFD66B"></circle>''',
  'round_specs': r'''<circle cx="38" cy="52" r="11" fill="none"></circle><circle cx="62" cy="52" r="11" fill="none"></circle><path d="M49 52h2"></path>''',
  'mint_scarf': r'''<path d="M22 84q28 14 56 0v10q-28 14-56 0z" fill="#6FC5A4"></path><path d="M64 92l4 14h-10l2-12z" fill="#6FC5A4"></path>''',
  'pink_bow': r'''<path d="M76 26l-12-8v16zM76 26l12-8v16z" fill="#F59BB0"></path><circle cx="76" cy="26" r="3.5" fill="#F0607E"></circle>''',
  'gold_crown': r'''<path d="M34 28l2-14 8 8 6-12 6 12 8-8 2 14z" fill="#FFD66B"></path>''',
  'night_cap': r'''<path d="M28 34q22-30 46-6l6 10q-28-10-52-4z" fill="#8F7BD1"></path><circle cx="82" cy="40" r="5" fill="#fff"></circle>''',
  'star_aura': r'''<path d="M14 24l2.2 5 5.4.6-4 3.6 1.2 5.3-4.8-2.8-4.8 2.8 1.2-5.3-4-3.6 5.4-.6z" fill="#FFD66B" stroke="none"></path><path d="M88 14l1.6 3.6 3.9.4-2.9 2.6.9 3.8-3.5-2-3.5 2 .9-3.8-2.9-2.6 3.9-.4z" fill="#FFD66B" stroke="none"></path><path d="M90 52l1.2 2.7 2.9.3-2.2 1.9.7 2.8-2.6-1.5-2.6 1.5.7-2.8-2.2-1.9 2.9-.3z" fill="#FFD66B" stroke="none"></path>''',
};
