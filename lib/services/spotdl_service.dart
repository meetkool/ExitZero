import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One track as spotDL's API describes it.
///
/// spotDL returns its `Song` dataclass straight out of FastAPI, so the field
/// names here are its Python field names.
class SpotdlSong {
  final String name;
  final String artist;
  final String albumName;
  final String url;
  final String coverUrl;
  final Duration duration;

  const SpotdlSong({
    required this.name,
    required this.artist,
    required this.albumName,
    required this.url,
    required this.coverUrl,
    required this.duration,
  });

  factory SpotdlSong.fromJson(Map<String, dynamic> j) {
    // `artists` is the full list, `artist` the primary one. Prefer the list
    // so a feature credit is not silently dropped.
    final artists = j['artists'];
    final joined = artists is List && artists.isNotEmpty
        ? artists.map((a) => a.toString()).join(', ')
        : (j['artist'] ?? '').toString();

    return SpotdlSong(
      name: (j['name'] ?? '').toString(),
      artist: joined,
      albumName: (j['album_name'] ?? '').toString(),
      url: (j['url'] ?? '').toString(),
      coverUrl: (j['cover_url'] ?? '').toString(),
      // spotDL reports seconds.
      duration: Duration(seconds: (j['duration'] as num?)?.toInt() ?? 0),
    );
  }

  /// What the file is called once it lands in the music library.
  String get fileName {
    final base = artist.isEmpty ? name : '$artist - $name';
    return '${base.isEmpty ? 'track' : base}.mp3';
  }
}

/// Raised for anything the card should show the user verbatim.
class SpotdlException implements Exception {
  final String message;
  const SpotdlException(this.message);
  @override
  String toString() => message;
}

/// Client for a spotDL web server the user runs themselves.
///
/// spotDL is a Python program; it cannot run on the phone. What runs here is
/// a client for `spotdl web`, which exposes the search and the download over
/// HTTP. The app never touches YouTube or Spotify directly — it asks that
/// server, and copies back the file it produced.
///
/// See https://github.com/spotDL/spotify-downloader — the endpoints used are
/// `/api/version`, `/api/connect`, `/api/songs/search`, `/api/url`,
/// `/api/download/url` and `/api/download/file`.
class SpotdlService {
  SpotdlService._();

  static const MethodChannel _channel = MethodChannel(
    'exitzero/camera_capability',
  );

  static const String _clientIdKey = 'spotdl_client_id';

  /// A download is a full YouTube fetch plus an ffmpeg transcode. Minutes,
  /// not seconds.
  static const Duration _downloadTimeout = Duration(minutes: 6);
  static const Duration _shortTimeout = Duration(seconds: 15);

  /// Normalises whatever the user typed into a base URL.
  ///
  /// `192.168.1.7:8800` and `http://192.168.1.7:8800/` both have to work —
  /// nobody types a scheme into a phone keyboard willingly.
  static Uri? baseUri(String raw) {
    var text = raw.trim();
    if (text.isEmpty) return null;
    if (!text.contains('://')) text = 'http://$text';
    final uri = Uri.tryParse(text);
    if (uri == null || uri.host.isEmpty) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    return Uri(
      scheme: uri.scheme,
      host: uri.host,
      // spotDL's own default. A base URL without one almost always means it.
      port: uri.hasPort ? uri.port : (uri.scheme == 'https' ? 443 : 8800),
    );
  }

  static Uri _endpoint(Uri base, String path, Map<String, String> query) {
    // An empty map still sets a query, which leaves a bare trailing '?'.
    return query.isEmpty
        ? base.replace(path: path)
        : base.replace(path: path, queryParameters: query);
  }

  /// A client id that survives restarts.
  ///
  /// spotDL keys a download session by this, and with `web_use_output_dir`
  /// off it writes into a per-client directory, so reusing the same id keeps
  /// one session's files together.
  static Future<String> clientId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_clientIdKey);
    if (existing != null && existing.isNotEmpty) return existing;

    final rng = Random.secure();
    final id = 'exitzero-'
        '${List.generate(8, (_) => rng.nextInt(16).toRadixString(16)).join()}';
    await prefs.setString(_clientIdKey, id);
    return id;
  }

  /// The server's version, or null when it cannot be reached.
  ///
  /// This doubles as the health check: the card shows a red dot until this
  /// answers, which turns "nothing happens" into "your server is not up".
  static Future<String?> version(String rawBase) async {
    final base = baseUri(rawBase);
    if (base == null) return null;
    try {
      final response = await http
          .get(_endpoint(base, '/api/version', const {}))
          .timeout(_shortTimeout);
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      return decoded is String ? decoded : decoded.toString();
    } catch (_) {
      return null;
    }
  }

  /// Registers this client with the server.
  ///
  /// `/api/download/url` resolves its client from the registry and 404s on a
  /// client it has never seen, and the server drops idle clients, so this is
  /// called before every download rather than once at startup.
  static Future<void> _connect(Uri base, String id) async {
    try {
      await http
          .get(_endpoint(base, '/api/connect', {'client_id': id}))
          .timeout(_shortTimeout);
    } catch (_) {
      // The download call reports the real failure; a dropped connect on its
      // own is not worth a message.
    }
  }

  /// Whether a query is a Spotify link rather than free text.
  static bool isSpotifyUrl(String query) {
    final q = query.trim().toLowerCase();
    return q.startsWith('http') &&
        (q.contains('open.spotify.com') || q.startsWith('spotify:'));
  }

  /// Tracks matching a search term, or every track behind a Spotify link.
  ///
  /// A playlist, album or artist URL goes to `/api/url`, which expands it to
  /// its songs — that is what makes "list my playlist, then download it" one
  /// step instead of many.
  static Future<List<SpotdlSong>> search(String rawBase, String query) async {
    final base = baseUri(rawBase);
    if (base == null) {
      throw const SpotdlException('That server address is not a valid URL.');
    }
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    final uri = isSpotifyUrl(trimmed)
        ? _endpoint(base, '/api/url', {'url': trimmed})
        : _endpoint(base, '/api/songs/search', {'query': trimmed});

    final http.Response response;
    try {
      response = await http
          .get(uri, headers: const {'Accept': 'application/json'})
          // A cold Spotify client plus a playlist expansion is slow.
          .timeout(const Duration(seconds: 60));
    } on SocketException {
      throw SpotdlException(
        'Could not reach ${base.host}:${base.port}. Is spotdl web running, '
        'and started with --host 0.0.0.0?',
      );
    } catch (_) {
      throw const SpotdlException('The search timed out.');
    }

    if (response.statusCode != 200) {
      throw SpotdlException(_detail(response, 'Search failed'));
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw const SpotdlException('The server sent back something unexpected.');
    }

    return decoded
        .whereType<Map>()
        .map((e) => SpotdlSong.fromJson(Map<String, dynamic>.from(e)))
        .where((s) => s.url.isNotEmpty)
        .toList(growable: false);
  }

  /// Downloads one track and files it in the device's music library.
  ///
  /// Three hops: ask the server to fetch and convert it, pull the resulting
  /// file back over HTTP, then hand the bytes to MediaStore. Returns the
  /// name it was saved under.
  static Future<String> download(String rawBase, SpotdlSong song) async {
    final base = baseUri(rawBase);
    if (base == null) {
      throw const SpotdlException('That server address is not a valid URL.');
    }
    await _requestLegacyWritePermission();

    final id = await clientId();
    await _connect(base, id);

    // 1. The server does the work: match, fetch, transcode, tag.
    final http.Response started;
    try {
      started = await http
          .post(
            _endpoint(base, '/api/download/url', {
              'url': song.url,
              'client_id': id,
            }),
          )
          .timeout(_downloadTimeout);
    } on SocketException {
      throw SpotdlException('Lost the connection to ${base.host}.');
    } catch (_) {
      throw const SpotdlException(
        'The download timed out. Long tracks can take a few minutes.',
      );
    }

    if (started.statusCode != 200) {
      throw SpotdlException(
        _detail(started, 'The server could not download it'),
      );
    }

    // The endpoint answers with the absolute path it wrote, JSON-encoded.
    final decoded = jsonDecode(started.body);
    final serverPath = decoded is String ? decoded : '';
    if (serverPath.isEmpty) {
      throw const SpotdlException('The server reported no file.');
    }

    // 2. Pull the file itself. The path is handed straight back because the
    // server validates it against its own session directory.
    final http.Response file;
    try {
      file = await http
          .get(
            _endpoint(base, '/api/download/file', {
              'file': serverPath,
              'client_id': id,
            }),
          )
          .timeout(_downloadTimeout);
    } catch (_) {
      throw const SpotdlException('The file transfer failed.');
    }

    if (file.statusCode != 200) {
      throw SpotdlException(_detail(file, 'Could not fetch the file'));
    }
    if (file.bodyBytes.isEmpty) {
      throw const SpotdlException('The server sent an empty file.');
    }

    // 3. Into the music library, where every player can see it.
    return _save(song, file.bodyBytes, serverPath);
  }

  static Future<String> _save(
    SpotdlSong song,
    Uint8List bytes,
    String serverPath,
  ) async {
    if (!Platform.isAndroid) {
      throw const SpotdlException('Saving is only wired up on Android.');
    }

    // Prefer the name the server gave the file: spotDL applies the user's
    // own output template, and second-guessing it just loses their tags.
    final fromServer = serverPath.split(RegExp(r'[\\/]')).last;
    final fileName = fromServer.toLowerCase().endsWith('.mp3')
        ? fromServer
        : song.fileName;

    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'saveAudio',
        {
          'fileName': fileName,
          'bytes': bytes,
          'title': song.name,
          'artist': song.artist,
          'album': song.albumName,
        },
      );
      if (result == null || result['ok'] != true) {
        throw SpotdlException(
          (result?['error'] ?? 'Could not save the file.').toString(),
        );
      }
      return (result['name'] ?? fileName).toString();
    } on PlatformException catch (e) {
      throw SpotdlException(e.message ?? 'Could not save the file.');
    }
  }

  /// Asks for the legacy storage permission, and does not care about the
  /// answer.
  ///
  /// Only Android 9 and older need it to write a file into the public Music
  /// directory; from Android 10 MediaStore grants an app its own inserts, and
  /// from 13 this permission cannot be granted at all. Treating a refusal as
  /// fatal would therefore block every modern phone for nothing, so the save
  /// is always attempted and the media store gets to give the real verdict.
  static Future<void> _requestLegacyWritePermission() async {
    if (!Platform.isAndroid) return;
    try {
      if (await Permission.storage.isGranted) return;
      await Permission.storage.request();
    } catch (_) {
      // Not available on this version. The save will say if it matters.
    }
  }

  /// FastAPI puts the real reason in `detail`; surfacing it beats a number.
  static String _detail(http.Response response, String fallback) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['detail'] != null) {
        return decoded['detail'].toString();
      }
    } catch (_) {
      // Not JSON. The status code is all we have.
    }
    if (response.statusCode == 404) {
      return '$fallback: the server did not recognise this client. '
          'Try again — it reconnects on the next tap.';
    }
    return '$fallback (${response.statusCode}).';
  }
}
