// Tafsir on tap (Noor Glass 1.1.0, phase 2 feature 5).
//
// English Tafsir Ibn Kathir (Abridged), fetched per ayah on
// demand from the Quran.com API v4 (tafsir resource 169; the
// endpoint shape was verified 2026-11-12) and cached in
// SharedPreferences, so a viewed ayah's tafsir is available
// offline afterwards. No complete offline Ibn Kathir dataset in
// a clean per-ayah form was found, so this feature needs the
// network on first view of an ayah; the UI says so honestly.

import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

class TafsirService {
  static const _cachePrefix = 'tafsir.ibnkathir.';
  static SharedPreferences? _prefs;

  static void attachPrefs(SharedPreferences prefs) => _prefs = prefs;

  /// Strips the API's HTML down to readable plain text: headings
  /// and paragraphs become line breaks, tags and entities go.
  static String stripHtml(String html) {
    var text = html
        .replaceAll(RegExp(r'<(h\d|p|div|br|li)[^>]*>', caseSensitive: false),
            '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&rsquo;', "'")
        .replaceAll('&lsquo;', "'")
        .replaceAll('&ldquo;', '"')
        .replaceAll('&rdquo;', '"');
    text = text
        .split('\n')
        .map((line) => line.trim().replaceAll(RegExp(r'\s+'), ' '))
        .where((line) => line.isNotEmpty)
        .join('\n\n');
    return text.trim();
  }

  static String? cached(int surah, int ayah) =>
      _prefs?.getString('$_cachePrefix$surah:$ayah');

  /// The tafsir text for an ayah: cache first, then the network.
  /// Returns null when neither is available (offline, unviewed).
  static Future<String?> fetch(int surah, int ayah) async {
    final hit = cached(surah, ayah);
    if (hit != null) return hit;
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(
          'https://api.quran.com/api/v4/tafsirs/169/by_ayah/$surah:$ayah'));
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close();
      if (response.statusCode != 200) return null;
      final body = await response.transform(utf8.decoder).join();
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final raw = (decoded['tafsir'] as Map<String, dynamic>?)?['text'];
      if (raw is! String || raw.isEmpty) return null;
      final text = stripHtml(raw);
      if (text.isEmpty) return null;
      await _prefs?.setString('$_cachePrefix$surah:$ayah', text);
      return text;
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }
}
