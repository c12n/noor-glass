// Feature pages (Noor Glass 1.1.0, phase 2): Mushaf read mode
// (feature 1), full-text search (2), tafsir sheet (5), custom
// playlists (8), the Khatmah planner (7) and the full theme
// settings (theming layer). All surfaces here follow the picked
// theme through the Material color scheme, like the rest of the
// app.
//
// Copyright (c) 2026 c12n Apps.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme.dart';
import 'khatmah.dart';
import 'playlists.dart';
import 'quran_models.dart';
import 'quran_pages.dart';
import 'quran_player.dart';
import 'tafsir_service.dart';

// MARK: - Shared helpers

Future<String?> askNameDialog(
  BuildContext context, {
  required String title,
  String initial = '',
  String hint = '',
}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(hintText: hint),
        textCapitalization: TextCapitalization.sentences,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(controller.text),
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

/// Plays a surah starting at an ayah, using the same timing
/// route the lyrics page uses: per-ayah audio when the active
/// reciter supports it, otherwise the character-weighted
/// estimate seek.
void playFromAyah(BuildContext context, QuranSurah surah, int ayahIndex) {
  final player = QuranScope.of(context).player;
  final all = QuranLibrary.surahs.map((s) => s.number).toList();
  if (player.currentSurah?.number != surah.number) {
    player.play(surah.number, queue: all, contextLabel: 'All Surahs');
    // The estimate seek lands once the item has loaded; the
    // per-ayah clip can start right away (it loads its own URL).
    if (QuranLibrary.supportsPerAyahAudio(player.activeReciterId) &&
        player.audioLanguage == QuranAudioLanguage.arabic) {
      player.playAyahAudio(ayahIndex);
      return;
    }
    Future.delayed(const Duration(milliseconds: 700), () {
      final ayahs = QuranTextData.ayahsBySurah[surah.number];
      if (ayahs == null || player.duration <= 0) return;
      player.seek(quranAyahStartTime(ayahs, ayahIndex, player.duration));
    });
    return;
  }
  if (QuranLibrary.supportsPerAyahAudio(player.activeReciterId) &&
      player.audioLanguage == QuranAudioLanguage.arabic) {
    player.playAyahAudio(ayahIndex);
    return;
  }
  final ayahs = QuranTextData.ayahsBySurah[surah.number];
  if (ayahs != null && player.duration > 0) {
    player.seek(quranAyahStartTime(ayahs, ayahIndex, player.duration));
  }
}

/// The tafsir bottom sheet (feature 5): Ibn Kathir (Abridged),
/// fetched per ayah and cached (see tafsir_service.dart).
void showTafsirSheet(BuildContext context, QuranSurah surah, QuranAyahText ayah) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      maxChildSize: 0.92,
      builder: (context, controller) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tafsir | ${surah.english} ${ayah.n}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 2),
            Text(
              'Ibn Kathir (Abridged) | English',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<String?>(
                future: TafsirService.fetch(surah.number, ayah.n),
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final text = snapshot.data;
                  if (text == null) {
                    return const Center(
                      child: Text(
                        'Tafsir needs the internet the first time you '
                        'open an ayah. Ayahs you have viewed stay '
                        'available offline.',
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  return ListView(
                    controller: controller,
                    children: [
                      SelectableText(text,
                          style: const TextStyle(fontSize: 15, height: 1.55)),
                      const SizedBox(height: 16),
                      const Text(
                        'Source: Quran.com API, Tafsir Ibn Kathir '
                        '(Abridged).',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// The "add to playlist" sheet (feature 8).
void showAddToPlaylistSheet(BuildContext context, int surahNumber) {
  final scope = QuranScope.of(context);
  final playlists = scope.playlists;
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: AnimatedBuilder(
        animation: playlists,
        builder: (context, _) => ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: Text(
                  'Add ${QuranLibrary.surah(surahNumber)?.english ?? ''} to...'),
            ),
            for (final p in playlists.playlists)
              ListTile(
                leading: const Icon(Icons.playlist_play),
                title: Text(p.name),
                subtitle: Text('${p.surahNumbers.length} surahs'),
                trailing: p.surahNumbers.contains(surahNumber)
                    ? const Icon(Icons.check)
                    : null,
                onTap: () {
                  playlists.addSurah(p, surahNumber);
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Added to ${p.name}')),
                  );
                },
              ),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('New playlist'),
              onTap: () async {
                final name = await askNameDialog(
                  context,
                  title: 'New playlist',
                  hint: 'For example: Morning listening',
                );
                if (name == null || !context.mounted) return;
                final created = playlists.create(name);
                playlists.addSurah(created, surahNumber);
                if (context.mounted) Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    ),
  );
}

// MARK: - Mushaf read mode (feature 1)

class MushafPage extends StatefulWidget {
  const MushafPage({super.key});

  @override
  State<MushafPage> createState() => _MushafPageState();
}

class _MushafPageState extends State<MushafPage> {
  static const _pageKey = 'quran.mushaf.page';
  PageController? _controller;
  int _page = 1;
  bool _ready = false;
  bool _flowing = false;
  bool _showTranslation = true;

  @override
  void initState() {
    super.initState();
    final scope = QuranScope.of(context);
    () async {
      await MushafMeta.load();
      await QuranTextData.load();
      final prefs = await SharedPreferences.getInstance();
      final player = scope.player;
      var page = prefs.getInt(_pageKey) ?? 0;
      if (page < 1 || page > 604) {
        final last = player.currentSurah?.number ?? 1;
        page = MushafMeta.pageOf(last, 1);
      }
      if (!mounted) return;
      setState(() {
        _page = page;
        _controller = PageController(initialPage: page - 1);
        _ready = true;
      });
    }();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _goToPage(int page) async {
    final target = page.clamp(1, 604);
    _controller?.animateToPage(
      target - 1,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_pageKey, target);
  }

  @override
  Widget build(BuildContext context) {
    final scope = QuranScope.of(context);
    return AnimatedBuilder(
      animation: scope.player,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Mushaf'),
            actions: [
              IconButton(
                icon: Icon(_flowing ? Icons.view_agenda : Icons.subject),
                tooltip: _flowing
                    ? 'Ayah by ayah view'
                    : 'Flowing page view (read only)',
                onPressed: () => setState(() => _flowing = !_flowing),
              ),
              IconButton(
                icon: Icon(_showTranslation
                    ? Icons.translate
                    : Icons.translate_outlined),
                tooltip: 'Toggle translation',
                onPressed: () =>
                    setState(() => _showTranslation = !_showTranslation),
              ),
            ],
          ),
          body: !_ready
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    Expanded(
                      child: PageView.builder(
                        controller: _controller,
                        reverse: true,
                        itemCount: 604,
                        onPageChanged: (i) {
                          setState(() => _page = i + 1);
                          SharedPreferences.getInstance()
                              .then((p) => p.setInt(_pageKey, i + 1));
                        },
                        itemBuilder: (context, i) =>
                            _MushafPageBody(
                          page: i + 1,
                          flowing: _flowing,
                          showTranslation: _showTranslation,
                        ),
                      ),
                    ),
                    _MushafNavBar(
                      page: _page,
                      onJump: _goToPage,
                    ),
                  ],
                ),
          bottomNavigationBar: const MiniPlayerBar(),
        );
      },
    );
  }
}

class _MushafPageBody extends StatelessWidget {
  final int page;
  final bool flowing;
  final bool showTranslation;
  const _MushafPageBody({
    required this.page,
    required this.flowing,
    required this.showTranslation,
  });

  @override
  Widget build(BuildContext context) {
    final scope = QuranScope.of(context);
    final player = scope.player;
    final scheme = Theme.of(context).colorScheme;
    final refs = MushafMeta.pageAyahs(page);
    if (refs.isEmpty) {
      return const Center(child: Text('Page unavailable.'));
    }
    final firstSurah = QuranLibrary.surah(refs.first.$1);
    final juz = MushafMeta.juzOf(refs.first.$1, refs.first.$2);
    // Group consecutive ayahs by surah for banners.
    final blocks = <(QuranSurah, List<QuranAyahText>)>[];
    for (final (sn, an) in refs) {
      final surah = QuranLibrary.surah(sn);
      final ayahs = QuranTextData.ayahsBySurah[sn];
      if (surah == null || ayahs == null || an < 1 || an > ayahs.length) {
        continue;
      }
      if (blocks.isEmpty || blocks.last.$1.number != sn) {
        blocks.add((surah, [ayahs[an - 1]]));
      } else {
        blocks.last.$2.add(ayahs[an - 1]);
      }
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
      children: [
        Row(
          children: [
            Chip(
              avatar: const Icon(Icons.bookmark_outline, size: 16),
              label: Text('Page $page of 604'),
            ),
            const SizedBox(width: 8),
            Chip(label: Text('Juz $juz')),
            const Spacer(),
            if (firstSurah != null)
              Text(
                firstSurah.arabic,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        for (final (surah, ayahs) in blocks) ...[
          if (ayahs.first.n == 1)
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: scheme.secondaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'سورة ${surah.arabic} | ${surah.english}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSecondaryContainer,
                ),
              ),
            ),
          if (flowing)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text.rich(
                TextSpan(
                  style: const TextStyle(fontSize: 23, height: 2.0),
                  children: [
                    for (final a in ayahs) ...[
                      TextSpan(text: '${a.ar} '),
                      TextSpan(
                        text: '﴿${a.n}﴾ ',
                        style: TextStyle(
                          color: scheme.secondary,
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ],
                ),
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.justify,
              ),
            )
          else
            for (final a in ayahs)
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _ayahActions(context, surah, a),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '${a.ar} ﴿${a.n}﴾',
                        textDirection: TextDirection.rtl,
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 22, height: 1.95),
                      ),
                      if (showTranslation)
                        Text(
                          a.translation(player.translationLang),
                          style: TextStyle(
                            fontSize: 13.5,
                            height: 1.45,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
        ],
        const SizedBox(height: 8),
        Text(
          flowing
              ? 'Flowing view is for reading. Switch to ayah view to '
                  'play, bookmark or open tafsir for an ayah.'
              : 'Tap an ayah to play from it, bookmark it or read '
                  'its tafsir.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }

  void _ayahActions(BuildContext context, QuranSurah surah, QuranAyahText a) {
    final scope = QuranScope.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: Text('${surah.english} | Ayah ${a.n}'),
              subtitle: Text(a.translation(scope.player.translationLang),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
            ListTile(
              leading: const Icon(Icons.play_arrow),
              title: const Text('Play from this ayah'),
              onTap: () {
                Navigator.of(context).pop();
                playFromAyah(context, surah, a.n - 1);
              },
            ),
            ListTile(
              leading: Icon(scope.bookmarks.isBookmarked(surah.number, a.n)
                  ? Icons.bookmark
                  : Icons.bookmark_border),
              title: const Text('Bookmark this ayah'),
              onTap: () {
                scope.bookmarks.toggle(surah.number, a.n);
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.menu_book),
              title: const Text('Tafsir (Ibn Kathir)'),
              onTap: () {
                Navigator.of(context).pop();
                showTafsirSheet(context, surah, a);
              },
            ),
            ListTile(
              leading: const Icon(Icons.lyrics),
              title: const Text('Open in lyrics'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => QuranLyricsPage(surah: surah)));
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MushafNavBar extends StatelessWidget {
  final int page;
  final void Function(int page) onJump;
  const _MushafNavBar({required this.page, required this.onJump});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_right),
              tooltip: 'Next page',
              onPressed: page < 604 ? () => onJump(page + 1) : null,
            ),
            PopupMenuButton<int>(
              tooltip: 'Jump to juz',
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                child: Text('Juz ${MushafMeta.juzOf(
                  MushafMeta.pages[page - 1].surah,
                  MushafMeta.pages[page - 1].ayah,
                )}'),
              ),
              onSelected: (juz) {
                final anchor = MushafMeta.juzs[juz - 1];
                onJump(MushafMeta.pageOf(anchor.surah, anchor.ayah));
              },
              itemBuilder: (context) => [
                for (var j = 1; j <= 30; j++)
                  PopupMenuItem(value: j, child: Text('Juz $j')),
              ],
            ),
            Expanded(
              child: Slider(
                value: page.toDouble(),
                min: 1,
                max: 604,
                divisions: 603,
                label: 'Page $page',
                onChanged: (v) => onJump(v.round()),
              ),
            ),
            PopupMenuButton<int>(
              tooltip: 'Jump to surah',
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                child: Text('Surah'),
              ),
              onSelected: (n) => onJump(MushafMeta.pageOf(n, 1)),
              itemBuilder: (context) => [
                for (final s in QuranLibrary.surahs)
                  PopupMenuItem(
                    value: s.number,
                    child: Text('${s.number}. ${s.english}'),
                  ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.chevron_left),
              tooltip: 'Previous page',
              onPressed: page > 1 ? () => onJump(page - 1) : null,
            ),
          ],
        ),
      ),
    );
  }
}

// MARK: - Full-text search (feature 2)

/// Arabic normalization for search: strips harakat and tatweel
/// and unifies alef / ya / ta-marbuta forms so a plain query
/// matches Uthmani text.
String normalizeArabic(String input) {
  final buffer = StringBuffer();
  for (final rune in input.runes) {
    if ((rune >= 0x064B && rune <= 0x065F) ||
        rune == 0x0670 ||
        rune == 0x0640 ||
        rune == 0x06D6 ||
        rune == 0x06DC ||
        rune == 0x06DF ||
        rune == 0x06E8 ||
        rune == 0x06EA ||
        rune == 0x06ED) {
      continue;
    }
    var ch = String.fromCharCode(rune);
    if ('آأإٱ'.contains(ch)) ch = 'ا';
    if (ch == 'ى') ch = 'ي';
    if (ch == 'ة') ch = 'ه';
    buffer.write(ch);
  }
  return buffer.toString();
}

class _SearchHit {
  final QuranSurah surah;
  final QuranAyahText ayah;
  final String matchedIn; // 'Arabic', 'English' or 'French'
  const _SearchHit(this.surah, this.ayah, this.matchedIn);
}

class QuranSearchPage extends StatefulWidget {
  const QuranSearchPage({super.key});

  @override
  State<QuranSearchPage> createState() => _QuranSearchPageState();
}

class _QuranSearchPageState extends State<QuranSearchPage> {
  String _query = '';
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    QuranTextData.load().then((_) {
      if (mounted) setState(() => _ready = true);
    });
  }

  List<_SearchHit> _search(String query) {
    final q = query.trim();
    if (q.length < 2) return const [];
    final qAr = normalizeArabic(q);
    final qLow = q.toLowerCase();
    final hits = <_SearchHit>[];
    for (final surah in QuranLibrary.surahs) {
      final ayahs = QuranTextData.ayahsBySurah[surah.number] ?? const [];
      for (final a in ayahs) {
        if (qAr.length >= 2 && normalizeArabic(a.ar).contains(qAr)) {
          hits.add(_SearchHit(surah, a, 'Arabic'));
        } else if (a.en.toLowerCase().contains(qLow)) {
          hits.add(_SearchHit(surah, a, 'English'));
        } else if (a.fr.isNotEmpty && a.fr.toLowerCase().contains(qLow)) {
          hits.add(_SearchHit(surah, a, 'French'));
        }
        if (hits.length >= 300) return hits;
      }
    }
    return hits;
  }

  @override
  Widget build(BuildContext context) {
    final scope = QuranScope.of(context);
    final player = scope.player;
    final hits = _ready ? _search(_query) : const <_SearchHit>[];
    return Scaffold(
      appBar: AppBar(title: const Text('Search the Quran')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SearchBar(
              hintText: 'Search Arabic, English or French text',
              leading: const Icon(Icons.search),
              elevation: const WidgetStatePropertyAll(0),
              autoFocus: true,
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _query.trim().length < 2
                    ? 'Type at least two letters. Surah names are '
                        'searched from the library.'
                    : hits.length >= 300
                        ? 'First 300 matches shown. Refine the search.'
                        : '${hits.length} match${hits.length == 1 ? '' : 'es'}',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
          ),
          Expanded(
            child: !_ready
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 170),
                    itemCount: hits.length,
                    itemBuilder: (context, i) {
                      final hit = hits[i];
                      final translation =
                          hit.ayah.translation(player.translationLang);
                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        child: ListTile(
                          title: Text(
                            '${hit.surah.english} | Ayah ${hit.ayah.n} '
                            '| in ${hit.matchedIn}',
                            style:
                                const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                hit.ayah.ar,
                                textDirection: TextDirection.rtl,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 16, height: 1.7),
                              ),
                              Text(
                                translation,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) =>
                                    QuranLyricsPage(surah: hit.surah)),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: const MiniPlayerBar(),
    );
  }
}

// MARK: - Playlists (feature 8)

class PlaylistsPage extends StatelessWidget {
  const PlaylistsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final playlists = QuranScope.of(context).playlists;
    return AnimatedBuilder(
      animation: playlists,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('Playlists')),
          floatingActionButton: FloatingActionButton.extended(
            icon: const Icon(Icons.add),
            label: const Text('New playlist'),
            onPressed: () async {
              final name = await askNameDialog(
                context,
                title: 'New playlist',
                hint: 'For example: Bedtime',
              );
              if (name != null) playlists.create(name);
            },
          ),
          body: playlists.playlists.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'No playlists yet. Create one here, or use '
                      '"Add to playlist" in any surah menu.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 170),
                  itemCount: playlists.playlists.length,
                  itemBuilder: (context, i) {
                    final p = playlists.playlists[i];
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.playlist_play),
                        title: Text(p.name),
                        subtitle: Text('${p.surahNumbers.length} surahs'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => PlaylistDetailPage(playlist: p)),
                        ),
                      ),
                    );
                  },
                ),
          bottomNavigationBar: const MiniPlayerBar(),
        );
      },
    );
  }
}

class PlaylistDetailPage extends StatefulWidget {
  final QuranPlaylist playlist;
  const PlaylistDetailPage({super.key, required this.playlist});

  @override
  State<PlaylistDetailPage> createState() => _PlaylistDetailPageState();
}

class _PlaylistDetailPageState extends State<PlaylistDetailPage> {
  bool _editing = false;

  @override
  Widget build(BuildContext context) {
    final scope = QuranScope.of(context);
    final playlists = scope.playlists;
    final player = scope.player;
    final p = widget.playlist;
    return AnimatedBuilder(
      animation: Listenable.merge([playlists, player]),
      builder: (context, _) {
        final numbers = p.surahNumbers;
        return Scaffold(
          appBar: AppBar(
            title: Text(p.name),
            actions: [
              IconButton(
                icon: Icon(_editing ? Icons.check : Icons.edit),
                tooltip: _editing ? 'Done' : 'Edit order',
                onPressed: () => setState(() => _editing = !_editing),
              ),
              PopupMenuButton<String>(
                onSelected: (v) async {
                  switch (v) {
                    case 'rename':
                      final name = await askNameDialog(
                        context,
                        title: 'Rename playlist',
                        initial: p.name,
                      );
                      if (name != null) playlists.rename(p, name);
                    case 'delete':
                      playlists.delete(p);
                      if (context.mounted) Navigator.of(context).pop();
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'rename', child: Text('Rename')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
          body: numbers.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'This playlist is empty. Add surahs from any '
                      'surah menu: "Add to playlist".',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
                      child: Row(
                        children: [
                          FilledButton.icon(
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Play all'),
                            onPressed: () => player.play(
                              numbers.first,
                              queue: List.of(numbers),
                              contextLabel: p.name,
                            ),
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.shuffle),
                            label: const Text('Shuffle'),
                            onPressed: () {
                              player.play(
                                numbers.first,
                                queue: List.of(numbers),
                                contextLabel: p.name,
                              );
                              if (!player.shuffle) player.toggleShuffle();
                            },
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _editing
                          ? ReorderableListView.builder(
                              padding:
                                  const EdgeInsets.only(bottom: 170),
                              itemCount: numbers.length,
                              onReorderItem: (from, to) =>
                                  playlists.moveSurah(p, from, to),
                              itemBuilder: (context, i) {
                                final n = numbers[i];
                                final s = QuranLibrary.surah(n);
                                return ListTile(
                                  key: ValueKey('pl-$n-$i'),
                                  leading: const Icon(Icons.drag_handle),
                                  title: Text(
                                      '${s?.number ?? n}. ${s?.english ?? ''}'),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.remove_circle),
                                    onPressed: () =>
                                        playlists.removeSurah(p, n),
                                  ),
                                );
                              },
                            )
                          : ListView(
                              padding:
                                  const EdgeInsets.only(bottom: 170),
                              children: [
                                for (final n in numbers)
                                  if (QuranLibrary.surah(n) != null)
                                    SurahRow(
                                      surah: QuranLibrary.surah(n)!,
                                      queueNumbers: List.of(numbers),
                                      contextLabel: p.name,
                                    ),
                              ],
                            ),
                    ),
                  ],
                ),
          bottomNavigationBar: const MiniPlayerBar(),
        );
      },
    );
  }
}

// MARK: - Khatmah planner (feature 7)

class KhatmahPage extends StatelessWidget {
  const KhatmahPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = QuranScope.of(context);
    final khatmah = scope.khatmah;
    final player = scope.player;
    return AnimatedBuilder(
      animation: Listenable.merge([khatmah, player]),
      builder: (context, _) {
        final scheme = Theme.of(context).colorScheme;
        final plan = khatmah.plan;
        return Scaffold(
          appBar: AppBar(title: const Text('Khatmah planner')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 190),
            children: [
              if (plan == null) ...[
                Text(
                  'Finish the whole Quran, one plan at a time.',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Pick a target length. A surah counts toward the '
                  'khatmah when you play it to its natural end; '
                  'progress is measured against your listening '
                  'statistics from the day the plan starts. The '
                  'planner then shows the portion for each day.',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final days in [7, 30, 40, 60, 90])
                      ActionChip(
                        label: Text('$days days'),
                        onPressed: () => khatmah.start(player, days),
                      ),
                  ],
                ),
              ] else ...[
                Center(
                  child: SizedBox(
                    width: 170,
                    height: 170,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: khatmah.progress(player),
                          strokeWidth: 12,
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${(khatmah.progress(player) * 100).toStringAsFixed(1)}%',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium,
                            ),
                            const Text('of the Quran'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.calendar_today),
                  title: Text(
                      'Day ${khatmah.dayOfCycle(DateTime.now())} of ${plan.targetDays}'),
                  subtitle: Text(
                      'Target date: ${plan.targetDate.toString().split(' ').first}'),
                ),
                ListTile(
                  leading: const Icon(Icons.headphones),
                  title: Text(
                      '${khatmah.coveredAyahs(player)} of ${KhatmahStore.totalAyahs} ayahs covered'),
                  subtitle: Text(
                      '${khatmah.completedSurahs(player).length} surahs completed this cycle'),
                ),
                const Divider(),
                Text(
                  "Today's portion",
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Builder(
                  builder: (context) {
                    final portion =
                        khatmah.todaysPortion(player, DateTime.now());
                    if (portion.isEmpty) {
                      return const Text(
                          'You are on pace. Nothing is due today.');
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${portion.length} surah${portion.length == 1 ? '' : 's'} | '
                          'about ${khatmah.todaysQuotaAyahs(player, DateTime.now())} ayahs',
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 10),
                        FilledButton.icon(
                          icon: const Icon(Icons.play_arrow),
                          label: const Text("Play today's portion"),
                          onPressed: () => player.play(
                            portion.first,
                            queue: portion,
                            contextLabel: "Today's portion",
                          ),
                        ),
                        const SizedBox(height: 8),
                        for (final n in portion)
                          if (QuranLibrary.surah(n) != null)
                            SurahRow(
                              surah: QuranLibrary.surah(n)!,
                              queueNumbers: portion,
                              contextLabel: "Today's portion",
                            ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  children: [
                    OutlinedButton(
                      onPressed: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Restart the khatmah?'),
                            content: const Text(
                                'Progress restarts from today. Your '
                                'listening statistics are kept.'),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(false),
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(true),
                                child: const Text('Restart'),
                              ),
                            ],
                          ),
                        );
                        if (ok == true) {
                          khatmah.start(player, plan.targetDays);
                        }
                      },
                      child: const Text('Restart plan'),
                    ),
                    TextButton(
                      onPressed: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('End this plan?'),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(false),
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(true),
                                child: const Text('End plan'),
                              ),
                            ],
                          ),
                        );
                        if (ok == true) khatmah.clear();
                      },
                      child: const Text('End plan'),
                    ),
                  ],
                ),
              ],
            ],
          ),
          bottomNavigationBar: const MiniPlayerBar(),
        );
      },
    );
  }
}

// MARK: - Theme settings (full theming layer)

const _primarySwatches = <(String, int)>[
  ('Mosque Green', 0x0B3D2E),
  ('Midnight', 0x0F2440),
  ('Ocean', 0x083344),
  ('Royal', 0x2E1065),
  ('Rosewood', 0x571233),
  ('Bronze', 0x6B4420),
  ('Forest', 0x14532D),
  ('Charcoal', 0x171717),
];

const _iconFamilyColors = <String, int>{
  'default': 0x0B3D2E,
  'ocean': 0x083344,
  'desert': 0x6B4420,
  'emerald': 0x052E22,
  'crimson': 0x450A0A,
  'sapphire': 0x172554,
  'plum': 0x3B0764,
  'contrast': 0x000000,
};

class ThemeSettingsPage extends StatelessWidget {
  const ThemeSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = ThemeScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('Theme')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            children: [
              Text('Appearance',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(
                      value: ThemeMode.system, label: Text('System')),
                  ButtonSegment(
                      value: ThemeMode.light, label: Text('Light')),
                  ButtonSegment(
                      value: ThemeMode.dark, label: Text('Dark')),
                ],
                selected: {settings.mode},
                onSelectionChanged: (s) =>
                    settings.update(() => settings.mode = s.first),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                title: const Text('Material You dynamic color'),
                subtitle: const Text(
                    'On: your wallpaper colors the app and overrides '
                    'the preset main color. Your accent choice still '
                    'applies. Off: the app uses the preset below.'),
                value: settings.dynamicColor,
                onChanged: (v) =>
                    settings.update(() => settings.dynamicColor = v),
              ),
              const Divider(height: 32),
              Text('Theme presets',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'A preset sets the main color, the accent, the text '
                'color on colored surfaces and its light or dark mode. '
                'Every surface follows it: library, Now Playing, '
                'lyrics, Mushaf and the widgets.',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              for (final preset in noorThemePresets)
                Card(
                  color: settings.isActivePreset(preset)
                      ? scheme.secondaryContainer
                      : null,
                  child: ListTile(
                    leading: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _Dot(colorFromHex(preset.primaryHex)),
                        const SizedBox(width: 4),
                        _Dot(colorFromHex(preset.accentHex)),
                      ],
                    ),
                    title: Text(preset.name),
                    subtitle: Text(
                        preset.mode == ThemeMode.dark
                            ? 'Dark'
                            : preset.mode == ThemeMode.light
                                ? 'Light'
                                : 'System',
                        style: const TextStyle(fontSize: 12)),
                    trailing: settings.isActivePreset(preset)
                        ? const Icon(Icons.check_circle)
                        : null,
                    onTap: () => settings.applyPreset(preset),
                  ),
                ),
              const Divider(height: 32),
              Text('Main color',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (name, hex) in _primarySwatches)
                    ChoiceChip(
                      avatar: _Dot(colorFromHex(hex), small: true),
                      label: Text(name),
                      selected: settings.primaryHex == hex,
                      onSelected: (_) =>
                          settings.update(() => settings.primaryHex = hex),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Text('Accent',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (name, hex) in noorAccentPresets)
                    ChoiceChip(
                      avatar: _Dot(colorFromHex(hex), small: true),
                      label: Text(name),
                      selected: settings.accentHex == hex,
                      onSelected: (_) =>
                          settings.update(() => settings.accentHex = hex),
                    ),
                  ActionChip(
                    avatar: const Icon(Icons.colorize, size: 16),
                    label: const Text('Custom color'),
                    onPressed: () => _pickCustomAccent(context, settings),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Accents are adjusted per surface so text stays '
                'readable (brightened on dark, deepened on light).',
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
              ),
              const Divider(height: 32),
              Text('Widget colors',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'match', label: Text('Match my theme')),
                  ButtonSegment(value: 'separate', label: Text('Separate')),
                ],
                selected: {settings.widgetColorMode},
                onSelectionChanged: (s) => settings
                    .update(() => settings.widgetColorMode = s.first),
              ),
              if (settings.widgetColorMode == 'separate') ...[
                const SizedBox(height: 10),
                for (final preset in noorThemePresets)
                  ListTile(
                    dense: true,
                    leading: _Dot(colorFromHex(preset.primaryHex)),
                    title: Text(preset.name),
                    trailing: settings.homeWidgetTheme?.id == preset.id
                        ? const Icon(Icons.check)
                        : null,
                    onTap: () => settings
                        .update(() => settings.homeWidgetTheme = preset),
                  ),
                Text(
                  'The widgets pick the new colors up on their next '
                  'refresh (at most a day, usually much sooner).',
                  style:
                      TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
                ),
              ],
              const Divider(height: 32),
              Text('App icon',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final name in kNoorIconNames)
                    ChoiceChip(
                      avatar: _Dot(
                          colorFromHex(_iconFamilyColors[name] ?? 0x0B3D2E),
                          small: true),
                      label: Text(name == 'default'
                          ? 'Default (Mosque)'
                          : name[0].toUpperCase() + name.substring(1)),
                      selected: settings.appIcon == name,
                      onSelected: (_) {
                        settings.update(() => settings.appIcon = name);
                        applyLauncherIcon(name);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: settings.resetToDefaults,
                child: const Text('Reset theme to defaults'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickCustomAccent(
      BuildContext context, AppThemeSettings settings) async {
    var color = colorFromHex(settings.accentHex);
    final picked = await showDialog<Color>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final hsv = HSVColor.fromColor(color);
          return AlertDialog(
            title: const Text('Custom accent'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 54,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                const SizedBox(height: 8),
                _rgbSlider('Hue', hsv.hue, 360,
                    (v) => setState(() => color =
                        hsv.withHue(v).toColor())),
                _rgbSlider('Saturation', hsv.saturation, 1,
                    (v) => setState(() => color =
                        hsv.withSaturation(v).toColor())),
                _rgbSlider('Brightness', hsv.value, 1,
                    (v) => setState(() => color =
                        hsv.withValue(v).toColor())),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(color),
                child: const Text('Use color'),
              ),
            ],
          );
        },
      ),
    );
    if (picked != null) {
      settings.update(() => settings.accentHex = hexFromColor(picked));
    }
  }

  Widget _rgbSlider(
      String label, double value, double max, ValueChanged<double> onChanged) {
    return Row(
      children: [
        SizedBox(width: 86, child: Text(label)),
        Expanded(
          child: Slider(
            value: value.clamp(0, max),
            min: 0,
            max: max,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  final bool small;
  const _Dot(this.color, {this.small = false});

  @override
  Widget build(BuildContext context) {
    final size = small ? 16.0 : 22.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant),
      ),
    );
  }
}
