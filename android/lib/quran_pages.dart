// Noor Glass UI | the surah library (search, Favorites and
// Downloaded filters, collections, options), the Now Playing
// page, the lyrics page (tap to seek, bookmarks, memorization
// loop), the downloads manager, the bookmarks page, and the
// mini player. Adapted from Prayer YEG's Quran pages for the
// standalone app, styled for Material 3 Expressive: extra large
// rounded shapes, pill controls and dynamic color.
//
// Copyright (c) 2026 c12n Apps.


import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'daily_ayah.dart';
import 'feature_pages.dart';
import 'khatmah.dart';
import 'playlists.dart';
import 'quran_downloads.dart';
import 'quran_models.dart';
import 'quran_player.dart';
import 'quran_words.dart';

// MARK: - Scope

class QuranScope extends InheritedWidget {
  final QuranPlayer player;
  final QuranDownloads downloads;
  final QuranBookmarks bookmarks;
  final QuranPlaylists playlists;
  final KhatmahStore khatmah;
  final DailyReminderSettings reminder;
  const QuranScope({
    super.key,
    required this.player,
    required this.downloads,
    required this.bookmarks,
    required this.playlists,
    required this.khatmah,
    required this.reminder,
    required super.child,
  });

  static QuranScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<QuranScope>()!;

  @override
  bool updateShouldNotify(QuranScope oldWidget) =>
      player != oldWidget.player ||
      downloads != oldWidget.downloads ||
      bookmarks != oldWidget.bookmarks ||
      playlists != oldWidget.playlists ||
      khatmah != oldWidget.khatmah ||
      reminder != oldWidget.reminder;
}

// MARK: - Sleeve colors (themed Now Playing / mini player)

/// The colors of the "sleeve" surfaces (Now Playing, mini
/// player, playing ayah card accents). Since 1.1.0 these follow
/// the picked theme on every surface: with Material You dynamic
/// color active the wallpaper scheme's primary is the sleeve;
/// otherwise the preset primary is, with the preset text color
/// contrast-guarded on it. The accent is the scheme secondary,
/// which the theme builder already contrast-adjusts.
class SleeveColors {
  final List<Color> gradient;
  final Color onSleeve;
  final Color mutedOnSleeve;
  final Color accent;
  const SleeveColors({
    required this.gradient,
    required this.onSleeve,
    required this.mutedOnSleeve,
    required this.accent,
  });

  static SleeveColors of(BuildContext context) {
    final settings = ThemeScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    if (settings.dynamicColor && settings.dynamicAvailable) {
      final base = scheme.primary;
      return SleeveColors(
        gradient: [
          lightenColor(base, 0.13),
          base,
          darkenColor(base, 0.38),
        ],
        onSleeve: scheme.onPrimary,
        mutedOnSleeve: scheme.onPrimary.withValues(alpha: 0.72),
        accent: scheme.secondary,
      );
    }
    final on = onPrimaryTextColor(settings);
    return SleeveColors(
      gradient: sleeveGradient(settings),
      onSleeve: on,
      mutedOnSleeve: on.withValues(alpha: 0.72),
      accent: scheme.secondary,
    );
  }
}

// MARK: - Shared pieces

/// Deterministic per-surah colors: a golden-ratio hue walk (the
/// same palette rule as Prayer YEG and the iOS app).
Color surahColor(int surahNumber, double saturation, double brightness) {
  final hue = (surahNumber * 0.6180339887) % 1.0;
  return HSVColor.fromAHSV(1, hue * 360, saturation, brightness).toColor();
}

/// The generated cover tile: gradient + Arabic name + number.
class SurahArtwork extends StatelessWidget {
  final QuranSurah surah;
  final double size;
  final double cornerRadius;
  const SurahArtwork({
    super.key,
    required this.surah,
    required this.size,
    this.cornerRadius = 20,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(cornerRadius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            surahColor(surah.number, 0.55, 0.62),
            surahColor(surah.number, 0.65, 0.34),
          ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                surah.arabic,
                style: TextStyle(
                  fontSize: size * 0.30,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  shadows: const [
                    Shadow(
                        color: Color(0x4D000000),
                        blurRadius: 6,
                        offset: Offset(0, 3)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'SURAH ${surah.number}',
            style: TextStyle(
              fontSize: size * 0.075,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.4,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}

String listenedLabel(QuranPlayer player) {
  final total = player.totalSecondsListened.round();
  final hours = total ~/ 3600;
  final minutes = (total % 3600) ~/ 60;
  final seconds = total % 60;
  if (hours > 0) return '$hours h $minutes min listened';
  if (minutes > 0) return '$minutes min listened';
  return '$seconds sec listened';
}

String formatBytes(int bytes) {
  if (bytes >= 1 << 30) return '${(bytes / (1 << 30)).toStringAsFixed(1)} GB';
  if (bytes >= 1 << 20) return '${(bytes / (1 << 20)).toStringAsFixed(1)} MB';
  if (bytes >= 1 << 10) return '${(bytes / (1 << 10)).toStringAsFixed(0)} KB';
  return '$bytes B';
}

String collectionTitle(QuranCollection c) =>
    c.id == 'ramadan' ? 'Ramadan' : 'Eid';

String collectionSubtitle(QuranCollection c) => c.id == 'ramadan'
    ? 'Surahs for the nights of Ramadan'
    : 'Surahs for Eid morning';

// MARK: - Mini player

/// The pill bar floating over the library while a surah is
/// loaded. Tap opens Now Playing.
class MiniPlayerBar extends StatelessWidget {
  const MiniPlayerBar({super.key});

  @override
  Widget build(BuildContext context) {
    final player = QuranScope.of(context).player;
    return AnimatedBuilder(
      animation: player,
      builder: (context, _) {
        final surah = player.currentSurah;
        if (surah == null) return const SizedBox.shrink();
        final sleeve = SleeveColors.of(context);
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Material(
              color: sleeve.gradient[1],
              borderRadius: BorderRadius.circular(28),
              elevation: 6,
              child: InkWell(
                borderRadius: BorderRadius.circular(28),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const NowPlayingPage()),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Row(
                    children: [
                      SurahArtwork(surah: surah, size: 44, cornerRadius: 14),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${surah.number}. ${surah.english}',
                              style: TextStyle(
                                color: sleeve.onSleeve,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              player.currentReciter?.name ?? '',
                              style: TextStyle(
                                color: sleeve.mutedOnSleeve,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                            player.isPlaying ? Icons.pause : Icons.play_arrow,
                            color: sleeve.onSleeve),
                        onPressed: player.togglePlayPause,
                      ),
                      IconButton(
                        icon: Icon(Icons.skip_next, color: sleeve.onSleeve),
                        onPressed: player.next,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// MARK: - Library

class QuranLibraryPage extends StatefulWidget {
  /// In the app shell the library is the home tab: the shell
  /// provides the mini player, so the page drops its own.
  final bool embedded;
  const QuranLibraryPage({super.key, this.embedded = false});

  @override
  State<QuranLibraryPage> createState() => _QuranLibraryPageState();
}

class _QuranLibraryPageState extends State<QuranLibraryPage> {
  String _search = '';
  bool _favoritesOnly = false;
  bool _downloadedOnly = false;

  List<QuranSurah> _displayed(QuranScope scope) {
    var list = List.of(QuranLibrary.surahs);
    if (_favoritesOnly) {
      list = list.where((s) => scope.player.isFavorite(s.number)).toList();
    }
    if (_downloadedOnly) {
      list = list
          .where((s) => scope.downloads
              .isDownloaded(scope.player.activeReciterId, s.number))
          .toList();
    }
    final query = _search.trim().toLowerCase();
    if (query.isNotEmpty) {
      list = list
          .where((s) =>
              s.english.toLowerCase().contains(query) ||
              s.meaning.toLowerCase().contains(query) ||
              s.arabic.contains(_search.trim()) ||
              '${s.number}' == query)
          .toList();
    }
    return list;
  }

  String get _contextLabel {
    if (_favoritesOnly) return 'Favorites';
    if (_downloadedOnly) return 'Downloaded';
    return 'All Surahs';
  }

  @override
  Widget build(BuildContext context) {
    final scope = QuranScope.of(context);
    final player = scope.player;
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: Listenable.merge(
          [player, scope.downloads, scope.bookmarks, scope.playlists]),
      builder: (context, _) {
        final displayed = _displayed(scope);
        return Scaffold(
          appBar: widget.embedded
              ? null
              : AppBar(title: const Text('Noor Glass')),
          body: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.embedded) ...[
                        Text(
                          'Noor Glass',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Listen and read | 114 surahs',
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${listenedLabel(player)} | '
                          '${player.completedSurahsTotal} surahs completed',
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      SearchBar(
                        hintText: 'Search by name, meaning or number',
                        leading: const Icon(Icons.search),
                        elevation: const WidgetStatePropertyAll(0),
                        backgroundColor:
                            WidgetStatePropertyAll(scheme.surfaceContainerHigh),
                        onChanged: (v) => setState(() => _search = v),
                      ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            FilterChip(
                              label: const Text('All'),
                              selected: !_favoritesOnly && !_downloadedOnly,
                              onSelected: (_) => setState(() {
                                _favoritesOnly = false;
                                _downloadedOnly = false;
                              }),
                            ),
                            const SizedBox(width: 8),
                            FilterChip(
                              avatar: const Icon(Icons.favorite, size: 16),
                              label: const Text('Favorites'),
                              selected: _favoritesOnly,
                              onSelected: (v) => setState(() {
                                _favoritesOnly = v;
                                if (v) _downloadedOnly = false;
                              }),
                            ),
                            const SizedBox(width: 8),
                            FilterChip(
                              avatar: const Icon(Icons.download_done, size: 16),
                              label: const Text('Downloaded'),
                              selected: _downloadedOnly,
                              onSelected: (v) => setState(() {
                                _downloadedOnly = v;
                                if (v) _favoritesOnly = false;
                              }),
                            ),
                            const SizedBox(width: 8),
                            ActionChip(
                              avatar: const Icon(Icons.tune, size: 16),
                              label: const Text('Voice and options'),
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) => const QuranOptionsPage()),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ActionChip(
                              avatar: const Icon(Icons.download, size: 16),
                              label: const Text('Downloads'),
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const QuranDownloadsManagerPage()),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            ActionChip(
                              avatar: const Icon(Icons.menu_book, size: 16),
                              label: const Text('Mushaf'),
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) => const MushafPage()),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ActionChip(
                              avatar: const Icon(Icons.manage_search, size: 16),
                              label: const Text('Search text'),
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) => const QuranSearchPage()),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ActionChip(
                              avatar: const Icon(Icons.playlist_play, size: 16),
                              label: const Text('Playlists'),
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) => const PlaylistsPage()),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ActionChip(
                              avatar: const Icon(Icons.flag, size: 16),
                              label: const Text('Khatmah'),
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) => const KhatmahPage()),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_search.isEmpty &&
                          !_favoritesOnly &&
                          !_downloadedOnly) ...[
                        Text('Collections',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            for (final c in QuranCollection.collections) ...[
                              Expanded(
                                child: _CollectionCard(collection: c),
                              ),
                              if (c != QuranCollection.collections.last)
                                const SizedBox(width: 12),
                            ],
                          ],
                        ),
                        if (scope.playlists.playlists.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          Text('Your playlists',
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 10),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                for (final p in scope.playlists.playlists) ...[
                                  ActionChip(
                                    avatar: const Icon(Icons.playlist_play,
                                        size: 16),
                                    label: Text(
                                        '${p.name} | ${p.surahNumbers.length}'),
                                    onPressed: () =>
                                        Navigator.of(context).push(
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              PlaylistDetailPage(playlist: p)),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        Text('All Surahs',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 4),
                      ],
                    ],
                  ),
                ),
              ),
              if (displayed.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Text(
                        _search.isNotEmpty
                            ? 'No surah matches "$_search".'
                            : 'Nothing here yet.',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    ),
                  ),
                )
              else
                SliverList.builder(
                  itemCount: displayed.length,
                  itemBuilder: (context, i) => SurahRow(
                    surah: displayed[i],
                    queueNumbers: displayed.map((s) => s.number).toList(),
                    contextLabel: _contextLabel,
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 170)),
            ],
          ),
          bottomNavigationBar:
              widget.embedded ? null : const MiniPlayerBar(),
        );
      },
    );
  }
}

class _CollectionCard extends StatelessWidget {
  final QuranCollection collection;
  const _CollectionCard({required this.collection});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final first = collection.surahs.isEmpty ? null : collection.surahs.first;
    return Card(
      color: scheme.secondaryContainer,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
              builder: (_) => CollectionDetailPage(collection: collection)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (first != null) SurahArtwork(surah: first, size: 52),
              const SizedBox(height: 12),
              Text(collectionTitle(collection),
                  style: Theme.of(context).textTheme.titleMedium),
              Text(
                collectionSubtitle(collection),
                style: TextStyle(
                    fontSize: 12, color: scheme.onSecondaryContainer),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text('${collection.surahNumbers.length} surahs',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

// MARK: - Surah row

class SurahRow extends StatelessWidget {
  final QuranSurah surah;
  final List<int> queueNumbers;
  final String contextLabel;
  const SurahRow({
    super.key,
    required this.surah,
    required this.queueNumbers,
    required this.contextLabel,
  });

  @override
  Widget build(BuildContext context) {
    final scope = QuranScope.of(context);
    final player = scope.player;
    final downloads = scope.downloads;
    final scheme = Theme.of(context).colorScheme;
    final reciterId = player.activeReciterId;
    final downloaded = downloads.isDownloaded(reciterId, surah.number);
    final downloading = downloads.isDownloading(reciterId, surah.number);
    final duration = player.displayDuration(surah);
    final isCurrent = player.currentSurah?.number == surah.number;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Card(
        color: isCurrent ? scheme.primaryContainer : scheme.surfaceContainerLow,
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          leading: SurahArtwork(surah: surah, size: 52, cornerRadius: 16),
          title: Text(
            '${surah.number}. ${surah.english}',
            style: const TextStyle(fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${surah.meaning} | ${surah.ayahs} ayahs | ${surah.revelation}'
            '${duration != null ? ' | ${QuranLibrary.formatDuration(duration)}' : ''}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (downloading)
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    value: downloads.progress(reciterId, surah.number),
                    strokeWidth: 3,
                  ),
                )
              else if (downloaded)
                Icon(Icons.download_done, size: 20, color: scheme.secondary),
              IconButton(
                icon: Icon(
                  player.isFavorite(surah.number)
                      ? Icons.favorite
                      : Icons.favorite_border,
                  color: player.isFavorite(surah.number)
                      ? quranHeartRed
                      : null,
                ),
                onPressed: () => player.toggleFavorite(surah.number),
              ),
              PopupMenuButton<String>(
                onSelected: (v) {
                  switch (v) {
                    case 'play':
                      player.play(surah.number,
                          queue: queueNumbers, contextLabel: contextLabel);
                    case 'next':
                      player.playNext(surah.number);
                    case 'queue':
                      player.enqueue(surah.number);
                    case 'lyrics':
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => QuranLyricsPage(surah: surah)));
                    case 'download':
                      downloads.download(surah.number, reciterId);
                    case 'deleteDownload':
                      downloads.delete(surah.number, reciterId);
                    case 'playlist':
                      showAddToPlaylistSheet(context, surah.number);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                      value: 'play', child: Text('Play')),
                  const PopupMenuItem(
                      value: 'next', child: Text('Play next')),
                  const PopupMenuItem(
                      value: 'queue', child: Text('Add to queue')),
                  const PopupMenuItem(
                      value: 'lyrics', child: Text('Read lyrics')),
                  const PopupMenuItem(
                      value: 'playlist', child: Text('Add to playlist')),
                  if (!downloaded && !downloading)
                    const PopupMenuItem(
                        value: 'download', child: Text('Download')),
                  if (downloaded)
                    const PopupMenuItem(
                        value: 'deleteDownload',
                        child: Text('Delete download')),
                ],
              ),
            ],
          ),
          onTap: () => player.play(surah.number,
              queue: queueNumbers, contextLabel: contextLabel),
        ),
      ),
    );
  }
}

// MARK: - Collection detail

class CollectionDetailPage extends StatelessWidget {
  final QuranCollection collection;
  const CollectionDetailPage({super.key, required this.collection});

  @override
  Widget build(BuildContext context) {
    final player = QuranScope.of(context).player;
    final surahs = collection.surahs;
    final numbers = surahs.map((s) => s.number).toList();
    return Scaffold(
      appBar: AppBar(title: Text(collectionTitle(collection))),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 170),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(collectionSubtitle(collection),
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant)),
                const SizedBox(height: 14),
                FilledButton.icon(
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Play all'),
                  onPressed: numbers.isEmpty
                      ? null
                      : () => player.play(numbers.first,
                          queue: numbers,
                          contextLabel: collectionTitle(collection)),
                ),
              ],
            ),
          ),
          for (final s in surahs)
            SurahRow(
              surah: s,
              queueNumbers: numbers,
              contextLabel: collectionTitle(collection),
            ),
        ],
      ),
      bottomNavigationBar: const MiniPlayerBar(),
    );
  }
}

// MARK: - Options (voice, reciter, stats)

class QuranOptionsPage extends StatelessWidget {
  const QuranOptionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = QuranScope.of(context);
    final player = scope.player;
    return AnimatedBuilder(
      animation: player,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('Voice and options')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Text('Audio language',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              SegmentedButton<QuranAudioLanguage>(
                segments: const [
                  ButtonSegment(
                    value: QuranAudioLanguage.arabic,
                    icon: Icon(Icons.language),
                    label: Text('Arabic'),
                  ),
                  ButtonSegment(
                    value: QuranAudioLanguage.english,
                    icon: Icon(Icons.translate),
                    label: Text('English'),
                  ),
                ],
                selected: {player.audioLanguage},
                onSelectionChanged: (s) => player.setAudioLanguage(s.first),
              ),
              const SizedBox(height: 8),
              Text(
                player.audioLanguage == QuranAudioLanguage.english
                    ? 'English narration by Ibrahim Walk, via QuranicAudio.'
                    : 'Arabic recitation: Islamic Network CDN reciters, '
                        'plus the Sudanese recitations via mp3quran.',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              Text('Reciter',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              for (final r in QuranLibrary.reciters)
                RadioListTile<String>(
                  value: r.id,
                  groupValue: player.reciterId,
                  title: Text(r.name),
                  subtitle: Text(r.subtitle),
                  secondary: const Icon(Icons.mic),
                  onChanged: player.audioLanguage == QuranAudioLanguage.arabic
                      ? (v) {
                          if (v != null) player.setReciter(v);
                        }
                      : null,
                ),
              const SizedBox(height: 8),
              Text(
                QuranLibrary.supportsPerAyahAudio(player.reciterId)
                    ? 'This reciter also has single-ayah audio; use '
                        '"Play this ayah" in the lyrics menu.'
                    : 'Single-ayah audio is available with Mishary '
                        'Al-Afasy; other reciters play per surah.',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 13),
              ),
              const SizedBox(height: 24),
              Text('Appearance',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              ListTile(
                leading: const Icon(Icons.palette),
                title: const Text('Theme'),
                subtitle: const Text(
                    'Presets, accent, Material You, widgets and app icon'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const ThemeSettingsPage())),
              ),
              const SizedBox(height: 16),
              Text('Translation',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'en', label: Text('English')),
                  ButtonSegment(value: 'fr', label: Text('French')),
                ],
                selected: {player.translationLang},
                onSelectionChanged: (s) =>
                    player.setTranslationLang(s.first),
              ),
              const SizedBox(height: 8),
              Text(
                player.translationLang == 'fr'
                    ? 'French translation by Muhammad Hamidullah.'
                    : 'English translation: Saheeh International.',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              Text('Daily Ayah',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Builder(
                builder: (context) {
                  final daily = DailyAyah.forDate(DateTime.now());
                  final surah = QuranLibrary.surah(daily.surah);
                  final dailyAyahs = QuranTextData.ayahsBySurah[daily.surah];
                  final text = (dailyAyahs != null &&
                          daily.ayah >= 1 &&
                          daily.ayah <= dailyAyahs.length)
                      ? dailyAyahs[daily.ayah - 1]
                      : null;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (surah != null)
                        ListTile(
                          leading: const Icon(Icons.wb_sunny_outlined),
                          title: Text(
                              'Today: ${surah.english} ${daily.surah}:${daily.ayah}'),
                          subtitle: Text(
                            text?.translation(player.translationLang) ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) =>
                                    QuranLyricsPage(surah: surah)),
                          ),
                        ),
                      SwitchListTile(
                        secondary: const Icon(Icons.notifications_outlined),
                        title: const Text('Daily reminder'),
                        subtitle: Text(
                            'One notification a day with the Daily Ayah, '
                            'at ${TimeOfDay(hour: scope.reminder.hour, minute: scope.reminder.minute).format(context)}.'),
                        value: scope.reminder.enabled,
                        onChanged: (v) => scope.reminder.apply(
                          enabled: v,
                          hour: scope.reminder.hour,
                          minute: scope.reminder.minute,
                        ),
                      ),
                      if (scope.reminder.enabled)
                        ListTile(
                          leading: const Icon(Icons.schedule),
                          title: const Text('Reminder time'),
                          trailing:
                              Text(TimeOfDay(hour: scope.reminder.hour, minute: scope.reminder.minute).format(context)),
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay(hour: scope.reminder.hour, minute: scope.reminder.minute),
                            );
                            if (picked != null) {
                              scope.reminder.apply(
                                enabled: true,
                                hour: picked.hour,
                                minute: picked.minute,
                              );
                            }
                          },
                        ),
                      const Text(
                        'Add the Daily Ayah widget from your home screen '
                        'widget picker; it follows your theme.',
                        style: TextStyle(fontSize: 13),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              Text('Listening',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              ListTile(
                leading: const Icon(Icons.headphones),
                title: Text(listenedLabel(player)),
                subtitle: Text(
                    '${player.completedSurahsTotal} surahs played to the end'),
              ),
              ListTile(
                leading: const Icon(Icons.download),
                title: Text(
                    '${scope.downloads.downloadedCount} downloads | '
                    '${formatBytes(scope.downloads.totalBytes)}'),
                subtitle: const Text('Manage offline audio'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const QuranDownloadsManagerPage())),
              ),
              const SizedBox(height: 24),
              const Text(
                'Arabic text: Uthmani script. English translation: '
                'Saheeh International. French translation: Muhammad '
                'Hamidullah, via AlQuranCloud. Audio: Islamic Network '
                'CDN reciters; Noreen Mohammad Siddiq (Ad-Duri an Abi '
                'Amr) and Alzain Mohammad Ahmad (Hafs Murattal) via '
                'mp3quran; Ibrahim Walk via QuranicAudio. Word by '
                'word and Ibn Kathir tafsir: Quran.com. Mushaf page '
                'mapping: AlQuranCloud meta (Madani).',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 8),
              const Text(
                'Copyright (c) 2026 c12n Apps',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        );
      },
    );
  }
}

// MARK: - Downloads manager

class QuranDownloadsManagerPage extends StatefulWidget {
  const QuranDownloadsManagerPage({super.key});

  @override
  State<QuranDownloadsManagerPage> createState() =>
      _QuranDownloadsManagerPageState();
}

class _QuranDownloadsManagerPageState
    extends State<QuranDownloadsManagerPage> {
  String? _voiceId;

  List<QuranReciter> get _voices => [
        ...QuranLibrary.reciters,
        QuranLibrary.englishReciter,
      ];

  @override
  Widget build(BuildContext context) {
    final scope = QuranScope.of(context);
    final downloads = scope.downloads;
    final voiceId = _voiceId ?? QuranLibrary.defaultReciter?.id ?? 'english';
    return AnimatedBuilder(
      animation: downloads,
      builder: (context, _) {
        final downloadedSurahs = QuranLibrary.surahs
            .where((s) => downloads.isDownloaded(voiceId, s.number))
            .toList();
        final active = downloads.activeDownloadCount(voiceId);
        return Scaffold(
          appBar: AppBar(title: const Text('Downloads')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final v in _voices) ...[
                      ChoiceChip(
                        label: Text(v.id == QuranLibrary.englishReciterId
                            ? 'English'
                            : v.name.split(' ').take(2).join(' ')),
                        selected: voiceId == v.id,
                        onSelected: (_) => setState(() => _voiceId = v.id),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '${downloads.downloadedCountFor(voiceId)} of 114 downloaded | '
                '${formatBytes(downloads.bytesFor(voiceId))}'
                '${active > 0 ? ' | $active downloading' : ''}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    icon: const Icon(Icons.download),
                    label: const Text('Download all'),
                    onPressed: () => downloads.downloadAll(voiceId),
                  ),
                  if (active > 0)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.cancel),
                      label: const Text('Cancel all'),
                      onPressed: () => downloads.cancelAll(voiceId),
                    ),
                  if (downloadedSurahs.isNotEmpty)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete all'),
                      onPressed: () => downloads.deleteAll(voiceId),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              if (downloadedSurahs.isEmpty)
                const Text('No downloads for this voice yet.')
              else
                for (final s in downloadedSurahs)
                  ListTile(
                    leading: SurahArtwork(surah: s, size: 44, cornerRadius: 14),
                    title: Text('${s.number}. ${s.english}'),
                    subtitle: Text(s.meaning),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => downloads.delete(s.number, voiceId),
                    ),
                  ),
              const Divider(height: 32),
              Text('Not downloaded',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              for (final s in QuranLibrary.surahs
                  .where((s) => !downloads.isDownloaded(voiceId, s.number))
                  .take(114))
                ListTile(
                  dense: true,
                  leading: downloads.isDownloading(voiceId, s.number)
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            value: downloads.progress(voiceId, s.number),
                            strokeWidth: 3,
                          ),
                        )
                      : const Icon(Icons.download_outlined),
                  title: Text('${s.number}. ${s.english}'),
                  trailing: downloads.isDownloading(voiceId, s.number)
                      ? IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () =>
                              downloads.cancel(s.number, voiceId),
                        )
                      : IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () =>
                              downloads.download(s.number, voiceId),
                        ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// MARK: - Now Playing

class NowPlayingPage extends StatelessWidget {
  const NowPlayingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = QuranScope.of(context);
    final player = scope.player;
    return AnimatedBuilder(
      animation: player,
      builder: (context, _) {
        final surah = player.currentSurah;
        if (surah == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Now Playing')),
            body: const Center(child: Text('Nothing is loaded yet.')),
          );
        }
        final sleeve = SleeveColors.of(context);
        final duration = player.duration;
        final onAccent = sleeve.accent.computeLuminance() > 0.4
            ? Colors.black
            : Colors.white;
        return Scaffold(
          appBar: AppBar(
            title: Text(player.contextLabel.isEmpty
                ? 'Now Playing'
                : player.contextLabel),
          ),
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: sleeve.gradient,
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            children: [
              Center(child: SurahArtwork(surah: surah, size: 240, cornerRadius: 32)),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${surah.number}. ${surah.english}',
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(color: sleeve.onSleeve),
                        ),
                        Text(
                          '${surah.arabic} | ${surah.meaning}',
                          style: TextStyle(color: sleeve.mutedOnSleeve),
                        ),
                        Text(
                          '${player.currentReciter?.name ?? ''}'
                          '${player.currentReciter != null ? ' | ${player.currentReciter!.subtitle}' : ''}',
                          style: TextStyle(color: sleeve.mutedOnSleeve),
                        ),
                        if (player.isClipMode)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              'Ayah audio | single ayah file',
                              style: TextStyle(
                                color: sleeve.accent,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    iconSize: 30,
                    icon: Icon(
                      player.isFavorite(surah.number)
                          ? Icons.favorite
                          : Icons.favorite_border,
                      color: player.isFavorite(surah.number)
                          ? quranHeartRed
                          : sleeve.onSleeve,
                    ),
                    onPressed: () => player.toggleFavorite(surah.number),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: sleeve.accent,
                  thumbColor: sleeve.accent,
                  inactiveTrackColor: sleeve.onSleeve.withValues(alpha: 0.25),
                ),
                child: Slider(
                  value: duration > 0
                      ? player.currentTime.clamp(0.0, duration)
                      : 0,
                  max: duration > 0 ? duration : 1,
                  onChanged: duration > 0 ? (v) => player.seek(v) : null,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(QuranLibrary.formatDuration(player.currentTime),
                      style: TextStyle(color: sleeve.mutedOnSleeve)),
                  Text(QuranLibrary.formatDuration(duration),
                      style: TextStyle(color: sleeve.mutedOnSleeve)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    iconSize: 30,
                    icon: Icon(Icons.shuffle,
                        color: player.shuffle
                            ? sleeve.accent
                            : sleeve.onSleeve),
                    onPressed: player.toggleShuffle,
                  ),
                  IconButton(
                    iconSize: 40,
                    icon: Icon(Icons.skip_previous, color: sleeve.onSleeve),
                    onPressed: player.previous,
                  ),
                  FilledButton(
                    onPressed: player.togglePlayPause,
                    style: FilledButton.styleFrom(
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(20),
                      backgroundColor: sleeve.accent,
                      foregroundColor: onAccent,
                    ),
                    child: Icon(
                      player.isPlaying ? Icons.pause : Icons.play_arrow,
                      size: 36,
                    ),
                  ),
                  IconButton(
                    iconSize: 40,
                    icon: Icon(Icons.skip_next, color: sleeve.onSleeve),
                    onPressed: player.next,
                  ),
                  IconButton(
                    iconSize: 30,
                    icon: Icon(
                      player.repeatMode == QuranRepeatMode.one
                          ? Icons.repeat_one
                          : Icons.repeat,
                      color: player.repeatMode != QuranRepeatMode.off
                          ? sleeve.accent
                          : sleeve.onSleeve,
                    ),
                    onPressed: player.cycleRepeatMode,
                  ),
                ],
              ),
              if (player.ayahLoopLabel != null) ...[
                const SizedBox(height: 8),
                Chip(
                  avatar: const Icon(Icons.loop, size: 18),
                  label: Text('Looping ${player.ayahLoopLabel}'),
                  deleteIcon: const Icon(Icons.close, size: 18),
                  onDeleted: player.clearAyahLoop,
                ),
              ],
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.lyrics, size: 18),
                    label: const Text('Lyrics'),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => QuranLyricsPage(surah: surah)),
                    ),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.bedtime, size: 18),
                    label: Text(player.sleepOption.isOff
                        ? 'Sleep timer'
                        : 'Sleep: ${player.sleepOption.endOfSurah ? 'end of surah' : '${player.sleepOption.minutes} min'}'),
                    onPressed: () => _showSleepSheet(context, player),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.loop, size: 18),
                    label: const Text('Repeat ayah'),
                    onPressed: () => _showLoopSheet(context, player),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.queue_music, size: 18),
                    label: const Text('Queue'),
                    onPressed: () => _showQueueSheet(context, player),
                  ),
                ],
              ),
              if (player.upNextSurah != null) ...[
                const SizedBox(height: 24),
                Text('Up next',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: sleeve.onSleeve)),
                const SizedBox(height: 6),
                Card(
                  child: ListTile(
                    leading: SurahArtwork(
                        surah: player.upNextSurah!, size: 44, cornerRadius: 14),
                    title: Text(
                        '${player.upNextSurah!.number}. ${player.upNextSurah!.english}'),
                    subtitle: Text(player.upNextSurah!.meaning),
                    onTap: player.next,
                  ),
                ),
              ],
            ],
            ),
          ),
        );
      },
    );
  }

  void _showSleepSheet(BuildContext context, QuranPlayer player) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Sleep timer')),
            RadioListTile<bool>(
              value: true,
              groupValue: player.sleepOption.isOff,
              title: const Text('Off'),
              onChanged: (_) {
                player.setSleepOption(const QuranSleepOption.off());
                Navigator.of(context).pop();
              },
            ),
            for (final m in QuranPlayer.sleepMinutes)
              RadioListTile<int>(
                value: m,
                groupValue: player.sleepOption.minutes,
                title: Text('$m minutes'),
                onChanged: (_) {
                  player.setSleepOption(QuranSleepOption.minutes(m));
                  Navigator.of(context).pop();
                },
              ),
            RadioListTile<bool>(
              value: true,
              groupValue: player.sleepOption.endOfSurah,
              title: const Text('End of surah'),
              onChanged: (_) {
                player.setSleepOption(const QuranSleepOption.end());
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showLoopSheet(BuildContext context, QuranPlayer player) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(
              title: Text('Repeat the current ayah'),
              subtitle:
                  Text('Memorization loop. It follows the ayah playing now.'),
            ),
            for (final plays in [3, 5, 10])
              ListTile(
                leading: const Icon(Icons.loop),
                title: Text('$plays times'),
                onTap: () {
                  player.repeatCurrentAyah(plays: plays);
                  Navigator.of(context).pop();
                },
              ),
            ListTile(
              leading: const Icon(Icons.all_inclusive),
              title: const Text('Loop until stopped'),
              onTap: () {
                player.repeatCurrentAyah();
                Navigator.of(context).pop();
              },
            ),
            if (player.ayahLoopLabel != null)
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('Stop looping'),
                onTap: () {
                  player.clearAyahLoop();
                  Navigator.of(context).pop();
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showQueueSheet(BuildContext context, QuranPlayer player) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => AnimatedBuilder(
        animation: player,
        builder: (context, _) {
          return SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: [
                ListTile(
                  title: const Text('Queue'),
                  subtitle: Text(player.contextLabel),
                ),
                for (final n in player.queue)
                  ListTile(
                    leading: Icon(
                      player.currentSurah?.number == n
                          ? Icons.play_circle
                          : Icons.queue_music,
                    ),
                    title: Text('${QuranLibrary.surah(n)?.english ?? n}'),
                    subtitle: Text('Surah $n'),
                    selected: player.currentSurah?.number == n,
                    onTap: () {
                      player.playFromQueue(n);
                      Navigator.of(context).pop();
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// MARK: - Lyrics

class QuranLyricsPage extends StatefulWidget {
  final QuranSurah surah;
  const QuranLyricsPage({super.key, required this.surah});

  @override
  State<QuranLyricsPage> createState() => _QuranLyricsPageState();
}

class _QuranLyricsPageState extends State<QuranLyricsPage> {
  bool _loaded = false;
  bool _wordByWord = false;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    QuranTextData.load().then((_) {
      if (mounted) setState(() => _loaded = true);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scope = QuranScope.of(context);
    final player = scope.player;
    final scheme = Theme.of(context).colorScheme;
    final ayahs =
        QuranTextData.ayahsBySurah[widget.surah.number] ?? const <QuranAyahText>[];
    final isCurrent = player.currentSurah?.number == widget.surah.number;
    var currentIndex = -1;
    double fraction = 0;
    if (isCurrent) {
      final clipIdx = player.clipAyahIndexFor(widget.surah.number);
      if (clipIdx != null) {
        currentIndex = clipIdx;
        fraction = player.duration > 0
            ? (player.currentTime / player.duration).clamp(0.0, 1.0)
            : 0;
      } else {
        currentIndex =
            quranCurrentAyahIndex(ayahs, player.currentTime, player.duration);
        if (currentIndex >= 0 && currentIndex < ayahs.length) {
          final start =
              quranAyahStartTime(ayahs, currentIndex, player.duration);
          final end =
              quranAyahEndTime(ayahs, currentIndex, player.duration);
          fraction = end > start
              ? ((player.currentTime - start) / (end - start)).clamp(0.0, 1.0)
              : 0;
        }
      }
    }
    return AnimatedBuilder(
      animation: player,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text('${widget.surah.english} | Lyrics'),
            actions: [
              PopupMenuButton<String>(
                icon: const Icon(Icons.translate),
                tooltip: 'Translation language',
                initialValue: player.translationLang,
                onSelected: player.setTranslationLang,
                itemBuilder: (context) => [
                  CheckedPopupMenuItem(
                    value: 'en',
                    checked: player.translationLang == 'en',
                    child: const Text('English | Saheeh International'),
                  ),
                  CheckedPopupMenuItem(
                    value: 'fr',
                    checked: player.translationLang == 'fr',
                    child: const Text('French | Hamidullah'),
                  ),
                ],
              ),
              IconButton(
                icon: Icon(Icons.segment,
                    color: _wordByWord ? scheme.primary : null),
                tooltip: 'Word by word',
                onPressed: () =>
                    setState(() => _wordByWord = !_wordByWord),
              ),
              if (isCurrent)
                IconButton(
                  icon: Icon(player.isPlaying ? Icons.pause : Icons.play_arrow),
                  onPressed: player.togglePlayPause,
                ),
            ],
          ),
          body: !_loaded
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 170),
                  itemCount: ayahs.length + (_wordByWord ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (_wordByWord && i == ayahs.length) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Word timing is estimated from your position '
                          'in the audio; exact word timings are not '
                          'published for these recitations.',
                          style: TextStyle(
                              color: scheme.onSurfaceVariant, fontSize: 13),
                        ),
                      );
                    }
                    final ayah = ayahs[i];
                    final active = i == currentIndex;
                    final bookmarked =
                        scope.bookmarks.isBookmarked(widget.surah.number, ayah.n);
                    final looping = isCurrent &&
                        player.ayahLoopLabel == 'Ayah ${ayah.n}';
                    final canPlayAyahAudio = QuranLibrary.supportsPerAyahAudio(
                            player.reciterId) &&
                        player.audioLanguage == QuranAudioLanguage.arabic &&
                        isCurrent;
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 5),
                      color: active
                          ? scheme.primaryContainer
                          : scheme.surfaceContainerLow,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: active
                            ? BorderSide(color: scheme.secondary, width: 1.5)
                            : BorderSide.none,
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => playFromAyah(context, widget.surah, i),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 15,
                                    backgroundColor: scheme.primary,
                                    foregroundColor: scheme.onPrimary,
                                    child: Text('${ayah.n}',
                                        style: const TextStyle(fontSize: 13)),
                                  ),
                                  const Spacer(),
                                  if (looping)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 4),
                                      child: Icon(Icons.repeat_one,
                                          size: 20, color: scheme.primary),
                                    ),
                                  IconButton(
                                    icon: Icon(
                                      bookmarked
                                          ? Icons.bookmark
                                          : Icons.bookmark_border,
                                      size: 21,
                                    ),
                                    onPressed: () =>
                                        scope.bookmarks.toggle(
                                            widget.surah.number, ayah.n),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert, size: 21),
                                    onSelected: (v) {
                                      switch (v) {
                                        case 'ayahAudio':
                                          player.playAyahAudio(i);
                                        case 'tafsir':
                                          showTafsirSheet(
                                              context, widget.surah, ayah);
                                        case 'repeat':
                                          if (looping) {
                                            player.clearAyahLoop();
                                          } else {
                                            player.repeatAyah(i);
                                          }
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      if (canPlayAyahAudio)
                                        const PopupMenuItem(
                                          value: 'ayahAudio',
                                          child: Text('Play this ayah (ayah audio)'),
                                        ),
                                      const PopupMenuItem(
                                        value: 'tafsir',
                                        child: Text('Tafsir | Ibn Kathir'),
                                      ),
                                      const PopupMenuItem(
                                        value: 'repeat',
                                        child: Text('Repeat this ayah'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  ayah.ar,
                                  textDirection: TextDirection.rtl,
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontSize: 24,
                                    height: 1.9,
                                    color: active
                                        ? scheme.onPrimaryContainer
                                        : scheme.onSurface,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                ayah.translation(player.translationLang),
                                style: TextStyle(
                                  fontSize: 15.5,
                                  height: 1.45,
                                  color: active
                                      ? scheme.onPrimaryContainer
                                      : scheme.onSurfaceVariant,
                                ),
                              ),
                              if (_wordByWord) ...[
                                const SizedBox(height: 12),
                                _WordByWordSection(
                                  surahNumber: widget.surah.number,
                                  ayah: ayah,
                                  fraction: active ? fraction : -1,
                                ),
                              ],
                            ],
                          ),
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

class _WordByWordSection extends StatelessWidget {
  final int surahNumber;
  final QuranAyahText ayah;
  final double fraction; // -1 when this ayah is not playing
  const _WordByWordSection({
    required this.surahNumber,
    required this.ayah,
    required this.fraction,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FutureBuilder<void>(
      future: QuranWords.load(),
      builder: (context, snapshot) {
        final words = QuranWords.wordsFor(surahNumber, ayah.n);
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(
            height: 24,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        if (words.isEmpty) {
          return Text(
            'Word by word is not available for this ayah.',
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
          );
        }
        final activeWord = fraction >= 0
            ? QuranWords.estimatedWordIndex(words, fraction)
            : -1;
        return Wrap(
          alignment: WrapAlignment.end,
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var w = 0; w < words.length; w++)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: w == activeWord
                      ? scheme.secondaryContainer
                      : scheme.surfaceContainerHighest
                          .withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      words[w].ar,
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(fontSize: 18, height: 1.5),
                    ),
                    if (words[w].transliteration.isNotEmpty)
                      Text(
                        words[w].transliteration,
                        style: TextStyle(
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                            color: scheme.onSurfaceVariant),
                      ),
                    if (words[w].translation.isNotEmpty)
                      Text(
                        words[w].translation,
                        style: TextStyle(
                            fontSize: 11, color: scheme.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

// MARK: - Bookmarks

class BookmarksPage extends StatelessWidget {
  const BookmarksPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = QuranScope.of(context);
    final bookmarks = scope.bookmarks;
    final player = scope.player;
    return AnimatedBuilder(
      animation: Listenable.merge([bookmarks, player]),
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('Bookmarks')),
          body: bookmarks.bookmarks.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'No bookmarks yet. Open the lyrics of a surah and '
                      'tap the bookmark icon on any ayah.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 170),
                  itemCount: bookmarks.bookmarks.length,
                  itemBuilder: (context, i) {
                    final b = bookmarks.bookmarks[i];
                    final surah = QuranLibrary.surah(b.surah);
                    final ayahs = QuranTextData.ayahsBySurah[b.surah];
                    final text = (ayahs != null &&
                            b.ayah >= 1 &&
                            b.ayah <= ayahs.length)
                        ? ayahs[b.ayah - 1]
                        : null;
                    return Card(
                      child: ListTile(
                        leading: surah == null
                            ? const Icon(Icons.bookmark)
                            : SurahArtwork(
                                surah: surah, size: 44, cornerRadius: 14),
                        title: Text(
                            '${surah?.english ?? 'Surah ${b.surah}'} | Ayah ${b.ayah}'),
                        subtitle: text == null
                            ? null
                            : Text(
                                text.translation(player.translationLang),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => bookmarks.remove(b),
                        ),
                        onTap: () {
                          if (surah == null) return;
                          if (player.currentSurah?.number != surah.number) {
                            player.play(
                              surah.number,
                              queue: QuranLibrary.surahs
                                  .map((s) => s.number)
                                  .toList(),
                              contextLabel: 'All Surahs',
                            );
                          }
                          Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => QuranLyricsPage(surah: surah)));
                        },
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
