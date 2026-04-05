import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import '../widgets/channel_list_overlay.dart';
import '../models/channel.dart';
import '../services/app_settings.dart';
import '../services/pip_service.dart';
import '../services/xtream_service.dart';
import 'epg_screen.dart';

class PlayerScreen extends StatefulWidget {
  final Channel channel;
  final List<Channel> channels;
  final bool isMovie;
  final Function(Channel channel) onFavoriteToggled;

  const PlayerScreen({
    super.key,
    required this.channel,
    required this.channels,
    required this.isMovie,
    required this.onFavoriteToggled,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final Player _player;
  late final VideoController _videoController;
  late final Widget _videoWidget;
  late Channel _currentChannel;

  bool _showControls = true;
  bool _showChannelList = false;
  bool _isBuffering = false;
  bool _isPlaying = false;
  bool _showOsd = false;
  bool _isTimeshifted = false;
  int _currentChannelIndex = -1;
  bool _isScrubbing = false;
  double _scrubValue = 0.0;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  StreamSubscription<bool>?     _playingSub;
  StreamSubscription<bool>?     _bufferingSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;

  Timer? _hideControlsTimer;
  Timer? _osdTimer;

  final FocusNode _playerFocusNode = FocusNode();
  final FocusNode _backFocus       = FocusNode();
  final FocusNode _epgFocus        = FocusNode();
  final FocusNode _rewindFocus     = FocusNode();
  final FocusNode _playFocus       = FocusNode();
  final FocusNode _fwdFocus        = FocusNode();

  @override
  void initState() {
    super.initState();
    _currentChannel = widget.channel;
    _currentChannelIndex = widget.channels.indexWhere((c) => c.url == widget.channel.url);

    _player = Player(
      configuration: const PlayerConfiguration(
        bufferSize: 32 * 1024 * 1024,
        logLevel: MPVLogLevel.error,
      ),
    );
    _videoController = VideoController(
      _player,
      configuration: const VideoControllerConfiguration(
        hwdec: 'auto',
      ),
    );

    // Video widget bir kez oluştur — her build'de yeniden oluşturma
    _videoWidget = RepaintBoundary(
      key: const ValueKey('video'),
      child: SizedBox.expand(
        child: Video(
          controller: _videoController,
          controls: NoVideoControls,
          fit: BoxFit.contain,
        ),
      ),
    );

    _playingSub = _player.stream.playing.listen((v) {
      if (mounted && v != _isPlaying) setState(() => _isPlaying = v);
    });
    _bufferingSub = _player.stream.buffering.listen((v) {
      if (mounted && v != _isBuffering) setState(() => _isBuffering = v);
    });

    // Position: sadece film modunda, saniyede bir güncelle
    if (widget.isMovie) {
      _positionSub = _player.stream.position.listen((pos) {
        if (!mounted || _isScrubbing) return;
        if ((pos.inSeconds - _position.inSeconds).abs() >= 1) {
          setState(() => _position = pos);
        }
      });
      _durationSub = _player.stream.duration.listen((dur) {
        if (mounted && dur != _duration) setState(() => _duration = dur);
      });
    }

    _resetHideTimer();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _openMedia(_currentChannel.url);
      _playerFocusNode.requestFocus();
    });
  }

  void _openMedia(String url) {
    final settings = Provider.of<AppSettings>(context, listen: false);
    _player.open(Media(settings.resolveStreamUrl(url)));
  }

  void _openEpg() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EpgScreen(channel: _currentChannel)),
    );
  }

  void _startTimeshift() {
    if (_currentChannel.streamId == null) return;
    final xtream = Provider.of<XtreamService>(context, listen: false);
    if (xtream.serverUrl == null) return;

    final start = DateTime.now().toUtc().subtract(const Duration(minutes: 30));
    String pad(int n) => n.toString().padLeft(2, '0');
    final startStr =
        '${start.year}-${pad(start.month)}-${pad(start.day)}:${pad(start.hour)}-${pad(start.minute)}';
    final url =
        '${xtream.serverUrl}/timeshift/${xtream.username}/${xtream.password}/60/$startStr/${_currentChannel.streamId}.ts';

    setState(() => _isTimeshifted = true);
    _player.open(Media(url));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Timeshift loading...'), duration: Duration(seconds: 2)),
    );

    Future.delayed(const Duration(seconds: 10), () {
      if (!mounted || !_isTimeshifted) return;
      if (!_player.state.playing) {
        _stopTimeshift();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Timeshift not available on this channel')),
          );
        }
      }
    });
  }

  void _stopTimeshift() {
    setState(() => _isTimeshifted = false);
    _openMedia(_currentChannel.url);
  }

  void _changeChannel(Channel channel) {
    final idx = widget.channels.indexWhere((c) => c.url == channel.url);
    setState(() {
      _currentChannel = channel;
      _currentChannelIndex = idx;
      _showChannelList = false;
      _showControls = false;
      _showOsd = true;
    });
    _openMedia(channel.url);
    _osdTimer?.cancel();
    _osdTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showOsd = false);
    });
  }

  void _resetHideTimer() {
    _hideControlsTimer?.cancel();
    if (!_showChannelList) {
      _hideControlsTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) setState(() => _showControls = false);
      });
    }
  }

  void _toggleControls() {
    if (_isScrubbing) return;
    if (_showControls) {
      _hideControlsTimer?.cancel();
      setState(() => _showControls = false);
      _playerFocusNode.requestFocus();
    } else {
      setState(() => _showControls = true);
      _resetHideTimer();
      WidgetsBinding.instance.addPostFrameCallback((_) => _playFocus.requestFocus());
    }
  }

  void _showControlsTemp() {
    if (!_showControls) {
      setState(() => _showControls = true);
      WidgetsBinding.instance.addPostFrameCallback((_) => _playFocus.requestFocus());
    }
    _resetHideTimer();
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.goBack || key == LogicalKeyboardKey.escape) {
      if (_showChannelList) {
        setState(() => _showChannelList = false);
        _playerFocusNode.requestFocus();
      } else if (_showControls) {
        _hideControlsTimer?.cancel();
        setState(() => _showControls = false);
        _playerFocusNode.requestFocus();
      } else {
        Navigator.pop(context);
      }
      return KeyEventResult.handled;
    }

    if (_showControls && !_showChannelList) {
      if (key == LogicalKeyboardKey.mediaPlayPause) {
        _player.playOrPause();
        _resetHideTimer();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    if (!_showChannelList) {
      if (key == LogicalKeyboardKey.mediaPlayPause) {
        _player.playOrPause();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowUp) {
        if (_currentChannelIndex > 0) _changeChannel(widget.channels[_currentChannelIndex - 1]);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowDown) {
        if (_currentChannelIndex < widget.channels.length - 1) _changeChannel(widget.channels[_currentChannelIndex + 1]);
        return KeyEventResult.handled;
      }
      _showControlsTemp();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _osdTimer?.cancel();
    _playingSub?.cancel();
    _bufferingSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _player.dispose();
    _playerFocusNode.dispose();
    _backFocus.dispose();
    _epgFocus.dispose();
    _rewindFocus.dispose();
    _playFocus.dispose();
    _fwdFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        focusNode: _playerFocusNode,
        autofocus: true,
        onKeyEvent: _handleKey,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: _toggleControls,
          child: Stack(
            children: [
              _videoWidget,

              if (_isBuffering)
                const Center(
                  child: CircularProgressIndicator(color: Color(0xFF60A5FA)),
                ),

              if (_showControls && !_showChannelList)
                _buildControlsOverlay(),

              if (_showOsd && !_showControls && !_showChannelList)
                _buildOsd(),

              if (_showChannelList)
                _buildChannelListOverlay(),

              if (_showControls && !_showChannelList && !widget.isMovie)
                Positioned(
                  bottom: 80,
                  right: 20,
                  child: FloatingActionButton.extended(
                    onPressed: () {
                      setState(() => _showChannelList = true);
                      _hideControlsTimer?.cancel();
                    },
                    label: const Text('Channels'),
                    icon: const Icon(Icons.list),
                    backgroundColor: const Color(0xFF60A5FA),
                  ),
                ),

              if (widget.isMovie && _showControls && !_showChannelList)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: ExcludeFocus(child: _buildProgressBar()),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlsOverlay() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.7),
            Colors.transparent,
            Colors.transparent,
            Colors.black.withValues(alpha: 0.7),
          ],
          stops: const [0.0, 0.2, 0.7, 1.0],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 16,
            left: 16,
            child: Row(
              children: [
                IconButton(
                  focusNode: _backFocus,
                  icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
                  onPressed: () => Navigator.pop(context),
                ),
                IconButton(
                  icon: const Icon(Icons.picture_in_picture_alt, color: Colors.white, size: 24),
                  onPressed: () => PipService.enterPip(),
                ),
              ],
            ),
          ),

          Positioned(
            top: 20,
            left: 110,
            right: 60,
            child: Text(
              _currentChannel.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                shadows: [Shadow(color: Colors.black, blurRadius: 6)],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          if (!widget.isMovie && _currentChannel.streamId != null)
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                focusNode: _epgFocus,
                icon: const Icon(Icons.calendar_today, color: Colors.white, size: 24),
                onPressed: _openEpg,
              ),
            ),

          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildControlBtn(Icons.fast_rewind, () {
                  _player.seek(_player.state.position - const Duration(seconds: 10));
                }, focusNode: _rewindFocus),
                const SizedBox(width: 24),
                _buildControlBtn(
                  _isPlaying ? Icons.pause_circle : Icons.play_circle,
                  _player.playOrPause,
                  size: 72,
                  focusNode: _playFocus,
                ),
                const SizedBox(width: 24),
                _buildControlBtn(Icons.fast_forward, () {
                  _player.seek(_player.state.position + const Duration(seconds: 10));
                }, focusNode: _fwdFocus),
              ],
            ),
          ),

          if (!widget.isMovie && _currentChannel.streamId != null)
            Positioned(
              bottom: 16,
              left: 16,
              child: _isTimeshifted
                  ? ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF60A5FA),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      icon: const Icon(Icons.live_tv, size: 18),
                      label: const Text('Go Live'),
                      onPressed: _stopTimeshift,
                    )
                  : OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white38),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      icon: const Icon(Icons.history, size: 18),
                      label: const Text('Timeshift'),
                      onPressed: _startTimeshift,
                    ),
            ),
        ],
      ),
    );
  }

  Widget _buildChannelListOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.92),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: ChannelListOverlay(
              channels: widget.channels,
              onChannelSelected: _changeChannel,
              isMovie: widget.isMovie,
              onClose: () => setState(() => _showChannelList = false),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Expanded(
                    flex: 4,
                    child: Video(
                      controller: _videoController,
                      controls: NoVideoControls,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _currentChannel.name,
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlBtn(IconData icon, VoidCallback onPressed,
      {double size = 52, FocusNode? focusNode}) {
    return IconButton(
      focusNode: focusNode,
      icon: Icon(icon, color: Colors.white, size: size),
      onPressed: () {
        _resetHideTimer();
        onPressed();
      },
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.15),
        shape: const CircleBorder(),
      ),
    );
  }

  Widget _buildOsd() {
    final chNum = _currentChannelIndex >= 0 ? _currentChannelIndex + 1 : null;
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black.withValues(alpha: 0.85), Colors.transparent],
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (chNum != null)
                    Text('CH $chNum',
                        style: const TextStyle(
                            color: Color(0xFF60A5FA),
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  Text(
                    _currentChannel.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      shadows: [Shadow(color: Colors.black, blurRadius: 6)],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (_isBuffering)
              const Padding(
                padding: EdgeInsets.only(left: 12),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      color: Color(0xFF60A5FA), strokeWidth: 2),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    final dur = _duration;
    final progress =
        dur.inMilliseconds > 0 ? _position.inMilliseconds / dur.inMilliseconds : 0.0;
    final displayValue = _isScrubbing ? _scrubValue : progress.clamp(0.0, 1.0);
    final displayPos = _isScrubbing && dur.inMilliseconds > 0
        ? Duration(milliseconds: (_scrubValue * dur.inMilliseconds).toInt())
        : _position;

    return GestureDetector(
      onTap: () {},
      child: Container(
        color: Colors.black.withValues(alpha: 0.6),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
              ),
              child: Slider(
                value: displayValue.clamp(0.0, 1.0),
                onChangeStart: (v) {
                  setState(() {
                    _isScrubbing = true;
                    _scrubValue = v;
                  });
                  _hideControlsTimer?.cancel();
                },
                onChanged: (v) => setState(() => _scrubValue = v),
                onChangeEnd: (v) {
                  if (dur.inMilliseconds > 0) {
                    _player.seek(
                        Duration(milliseconds: (v * dur.inMilliseconds).toInt()));
                  }
                  _isScrubbing = false;
                  _resetHideTimer();
                },
                activeColor: const Color(0xFF60A5FA),
                inactiveColor: Colors.white30,
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_fmt(displayPos),
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
                Text(_fmt(dur),
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}
