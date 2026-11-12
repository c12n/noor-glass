// Custom playlists (Noor Glass 1.1.0, phase 2 feature 8).
//
// User-made surah lists on top of the built-in collections,
// persisted as JSON under `quran.playlists.v1`.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class QuranPlaylist {
  final String id;
  String name;
  List<int> surahNumbers;
  QuranPlaylist({
    required this.id,
    required this.name,
    required this.surahNumbers,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'surahs': surahNumbers,
      };

  factory QuranPlaylist.fromJson(Map<String, dynamic> json) => QuranPlaylist(
        id: json['id'] as String,
        name: json['name'] as String? ?? 'Playlist',
        surahNumbers: (json['surahs'] as List? ?? [])
            .map((e) => (e as num).toInt())
            .where((n) => n >= 1 && n <= 114)
            .toList(),
      );
}

class QuranPlaylists extends ChangeNotifier {
  static const _key = 'quran.playlists.v1';
  List<QuranPlaylist> playlists = [];
  SharedPreferences? _prefs;

  Future<void> load(SharedPreferences prefs) async {
    _prefs = prefs;
    final raw = prefs.getString(_key);
    if (raw != null) {
      try {
        playlists = (jsonDecode(raw) as List)
            .map((e) => QuranPlaylist.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        playlists = [];
      }
    }
    notifyListeners();
  }

  QuranPlaylist create(String name) {
    final playlist = QuranPlaylist(
      id: 'pl${DateTime.now().millisecondsSinceEpoch}',
      name: name.trim().isEmpty ? 'Playlist' : name.trim(),
      surahNumbers: [],
    );
    playlists.add(playlist);
    _save();
    notifyListeners();
    return playlist;
  }

  void rename(QuranPlaylist playlist, String name) {
    if (name.trim().isEmpty) return;
    playlist.name = name.trim();
    _save();
    notifyListeners();
  }

  void delete(QuranPlaylist playlist) {
    playlists.removeWhere((p) => p.id == playlist.id);
    _save();
    notifyListeners();
  }

  void addSurah(QuranPlaylist playlist, int surahNumber) {
    if (playlist.surahNumbers.contains(surahNumber)) return;
    playlist.surahNumbers.add(surahNumber);
    _save();
    notifyListeners();
  }

  void removeSurah(QuranPlaylist playlist, int surahNumber) {
    playlist.surahNumbers.remove(surahNumber);
    _save();
    notifyListeners();
  }

  void moveSurah(QuranPlaylist playlist, int from, int to) {
    if (from < 0 ||
        from >= playlist.surahNumbers.length ||
        to < 0 ||
        to >= playlist.surahNumbers.length) {
      return;
    }
    final n = playlist.surahNumbers.removeAt(from);
    playlist.surahNumbers.insert(to, n);
    _save();
    notifyListeners();
  }

  void _save() {
    _prefs?.setString(
        _key, jsonEncode(playlists.map((p) => p.toJson()).toList()));
  }
}
