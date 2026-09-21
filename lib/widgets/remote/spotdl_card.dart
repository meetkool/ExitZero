import 'package:flutter/material.dart';
import '../../services/spotdl_service.dart';

/// How far along one row is.
enum _Stage { idle, working, done, failed }

class _RowState {
  final _Stage stage;
  final String message;
  const _RowState(this.stage, [this.message = '']);
}

/// A browser for a spotDL server, with a download button per track.
///
/// spotDL is Python, so none of it runs on the phone. This card is the remote
/// control: it searches the server the user is already running, and when a
/// row is tapped the server fetches and converts the track and the card
/// copies it back into the device's music library — where the Player widget
/// picks it up without any extra wiring.
class SpotdlCard extends StatefulWidget {
  final double height;
  final Color accent;

  /// Where `spotdl web` is listening, e.g. `192.168.1.7:8800`.
  final String baseUrl;

  /// What the list shows before the user types anything.
  final String initialQuery;

  const SpotdlCard({
    super.key,
    this.height = 300,
    this.accent = const Color(0xFF1DB954),
    required this.baseUrl,
    this.initialQuery = '',
  });

  @override
  State<SpotdlCard> createState() => _SpotdlCardState();
}

class _SpotdlCardState extends State<SpotdlCard> {
  final TextEditingController _query = TextEditingController();

  List<SpotdlSong> _songs = const [];
  final Map<String, _RowState> _rows = {};

  bool _searching = false;
  String? _error;

  /// null while unknown, '' when unreachable, a version string when up.
  String? _serverVersion;

  @override
  void initState() {
    super.initState();
    _query.text = widget.initialQuery;
    _ping();
    if (widget.initialQuery.trim().isNotEmpty) _search();
  }

  @override
  void didUpdateWidget(SpotdlCard old) {
    super.didUpdateWidget(old);
    // The server address is a config field, so it can change under us.
    if (old.baseUrl != widget.baseUrl) {
      _serverVersion = null;
      _ping();
    }
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _ping() async {
    final version = await SpotdlService.version(widget.baseUrl);
    if (!mounted) return;
    setState(() => _serverVersion = version ?? '');
  }

  Future<void> _search() async {
    final text = _query.text.trim();
    if (text.isEmpty || _searching) return;

    // Not FocusScope.of(context): an initial query runs this straight out of
    // initState, where an inherited-widget lookup throws.
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _searching = true;
      _error = null;
    });

    try {
      final songs = await SpotdlService.search(widget.baseUrl, text);
      if (!mounted) return;
      setState(() {
        _songs = songs;
        _searching = false;
        _error = songs.isEmpty ? 'Nothing matched that.' : null;
      });
      // A successful search proves the server is up, whatever the ping said.
      if (_serverVersion == '') _ping();
    } on SpotdlException catch (e) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _error = 'Something went wrong talking to the server.';
      });
    }
  }

  Future<void> _download(SpotdlSong song) async {
    if (_rows[song.url]?.stage == _Stage.working) return;

    setState(() => _rows[song.url] = const _RowState(_Stage.working));

    try {
      final name = await SpotdlService.download(widget.baseUrl, song);
      if (!mounted) return;
      setState(() => _rows[song.url] = _RowState(_Stage.done, name));
      _toast('Saved to Music/ExitZero');
    } on SpotdlException catch (e) {
      if (!mounted) return;
      setState(() => _rows[song.url] = _RowState(_Stage.failed, e.message));
      _toast(e.message);
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _rows[song.url] = const _RowState(_Stage.failed, 'Failed.'),
      );
    }
  }

  void _toast(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 12)),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(),
          const SizedBox(height: 10),
          _searchField(),
          const SizedBox(height: 10),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _header() {
    final up = _serverVersion != null && _serverVersion!.isNotEmpty;
    final unknown = _serverVersion == null;

    return Row(
      children: [
        Icon(Icons.cloud_download, size: 16, color: widget.accent),
        const SizedBox(width: 6),
        const Text(
          'spotDL',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: _ping,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: unknown
                      ? Colors.white.withValues(alpha: 0.3)
                      : (up ? widget.accent : const Color(0xFFE05252)),
                ),
              ),
              const SizedBox(width: 5),
              Text(
                unknown
                    ? 'checking'
                    : (up ? 'v$_serverVersion' : 'server offline'),
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _searchField() {
    return SizedBox(
      height: 36,
      child: TextField(
        controller: _query,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => _search(),
        style: const TextStyle(fontSize: 12, color: Colors.white),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          hintText: 'Song, artist, or a Spotify link',
          hintStyle: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.35),
          ),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.06),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          suffixIcon: GestureDetector(
            onTap: _search,
            child: Icon(
              Icons.search,
              size: 18,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
          suffixIconConstraints: const BoxConstraints(
            minWidth: 34,
            minHeight: 34,
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_searching) {
      return Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation(widget.accent),
            backgroundColor: Colors.white.withValues(alpha: 0.1),
          ),
        ),
      );
    }

    if (_songs.isEmpty) {
      return _placeholder();
    }

    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: _songs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _songRow(_songs[i]),
    );
  }

  Widget _placeholder() {
    final offline = _serverVersion == '';
    final message = _error ??
        (offline
            ? 'No answer from ${widget.baseUrl}.\nStart it with: '
                'spotdl web --host 0.0.0.0'
            : 'Search for something, or paste a Spotify playlist link.');

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            height: 1.45,
            color: Colors.white.withValues(alpha: 0.45),
          ),
        ),
      ),
    );
  }

  Widget _songRow(SpotdlSong song) {
    final state = _rows[song.url] ?? const _RowState(_Stage.idle);

    return Row(
      children: [
        _cover(song),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                song.name.isEmpty ? 'Unknown track' : song.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                state.stage == _Stage.failed
                    ? state.message
                    : _subtitle(song, state),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  color: state.stage == _Stage.failed
                      ? const Color(0xFFE05252)
                      : Colors.white.withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _action(song, state),
      ],
    );
  }

  String _subtitle(SpotdlSong song, _RowState state) {
    if (state.stage == _Stage.working) return 'Downloading…';
    if (state.stage == _Stage.done) return 'Saved · ${song.artist}';
    final length = song.duration.inSeconds > 0
        ? ' · ${_clock(song.duration)}'
        : '';
    return '${song.artist}$length';
  }

  static String _clock(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Widget _cover(SpotdlSong song) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: 36,
        height: 36,
        child: song.coverUrl.isEmpty
            ? _coverFallback()
            : Image.network(
                song.coverUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _coverFallback(),
              ),
      ),
    );
  }

  Widget _coverFallback() {
    return Container(
      color: Colors.white.withValues(alpha: 0.08),
      child: Icon(
        Icons.music_note,
        size: 16,
        color: Colors.white.withValues(alpha: 0.3),
      ),
    );
  }

  Widget _action(SpotdlSong song, _RowState state) {
    switch (state.stage) {
      case _Stage.working:
        return SizedBox(
          width: 30,
          height: 30,
          child: Center(
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(widget.accent),
                backgroundColor: Colors.white.withValues(alpha: 0.12),
              ),
            ),
          ),
        );
      case _Stage.done:
        return SizedBox(
          width: 30,
          height: 30,
          child: Icon(Icons.check_circle, size: 20, color: widget.accent),
        );
      case _Stage.idle:
      case _Stage.failed:
        final retry = state.stage == _Stage.failed;
        return GestureDetector(
          onTap: () => _download(song),
          // The icon is small; an opaque box gives the finger something to
          // actually land on.
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            width: 30,
            height: 30,
            child: Icon(
              retry ? Icons.refresh : Icons.download_rounded,
              size: 19,
              color: retry
                  ? const Color(0xFFE05252)
                  : widget.accent.withValues(alpha: 0.9),
            ),
          ),
        );
    }
  }
}
