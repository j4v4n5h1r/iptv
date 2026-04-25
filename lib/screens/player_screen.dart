import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  late Channel _currentChannel;
  int _currentChannelIndex = -1;

  bool _showControls = true;
  bool _showChannelList = false;
  bool _showOsd = false;
  bool _isTimeshifted = false;
  bool _isBuffering = true;
  bool _isPlaying = false;
  bool _isScrubbing = false;
  double _scrubValue = 0.0;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  MethodChannel? _playerChannel;
  Timer? _hideControlsTimer;
  Timer? _osdTimer;
  Timer? _positionTimer;

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
    _resetHideTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _playerFocusNode.requestFocus();
    });
  }

  String _resolveUrl(String url) {
    final settings = Provider.of<AppSettings>(context, listen: false);
    return settings.resolveStreamUrl(url);
  }

  void _onPlatformViewCreated(int viewId) {
    _playerChannel = MethodChannel('com.wallyt.iptv/exoplayer_$viewId');
    _playerChannel!.setMethodCallHandler(_onPlayerEvent);
    _loadUrl(_currentChannel.url);

    if (widget.isMovie) {
      _positionTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
        if (!mounted || _isScrubbing) return;
        try {
          final pos = await _playerChannel?.invokeMethod<int>('getPosition') ?? 0;
          final dur = await _playerChannel?.invokeMethod<int>('getDuration') ?? 0;
          if (mounted) {
            setState(() {
              _position = Duration(milliseconds: pos);
              if (dur > 0) _duration = Duration(milliseconds: dur);
            });
          }
        } catch (_) {}
      });
    }
  }

  Future<dynamic> _onPlayerEvent(MethodCall call) async {
    switch (call.method) {
      case 'onState':
        final state = call.arguments['state'] as String?;
        if (mounted) {
          setState(() {
            _isBuffering = state == 'buffering';
          });
        }
        break;
      case 'onPlaying':
        final playing = call.arguments['playing'] as bool? ?? false;
        if (mounted) setState(() => _isPlaying = playing);
        break;
    }
  }

  void _loadUrl(String url) {
    final resolved = _resolveUrl(url);
    _playerChannel?.invokeMethod('load', {'url': resolved});
    setState(() { _isBuffering = true; });
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
    _loadUrl(channel.url);
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

  void _playOrPause() {
    if (_isPlaying) {
      _playerChannel?.invokeMethod('pause');
    } else {
      _playerChannel?.invokeMethod('play');
    }
    setState(() {});
  }

  void _startTimeshift() {
    if (_currentChannel.streamId == null) return;
    final xtream = Provider.of<XtreamService>(context, listen: false);
    if (xtream.serverUrl == null) return;
    final start = DateTime.now().toUtc().subtract(const Duration(minutes: 30));
    String pad(int n) => n.toString().padLeft(2, '0');
    final startStr = '${start.year}-${pad(start.month)}-${pad(start.day)}:${pad(start.hour)}-${pad(start.minute)}';
    final url = '${xtream.serverUrl}/timeshift/${xtream.username}/${xtream.password}/60/$startStr/${_currentChannel.streamId}.ts';
    setState(() => _isTimeshifted = true);
    _loadUrl(url);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Timeshift loading...'), duration: Duration(seconds: 2)),
    );
    Future.delayed(const Duration(seconds: 10), () {
      if (!mounted || !_isTimeshifted) return;
      if (!_isPlaying) {
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
    _loadUrl(_currentChannel.url);
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.goBack || key == LogicalKeyboardKey.escape) {
      if (_showChannelList) {
        setState(() => _showChannelList = false);
        _playerFocusNode.requestFocus();
      } else {
        Navigator.pop(context);
      }
      return KeyEventResult.handled;
    }

    if (_showControls && !_showChannelList) {
      if (key == LogicalKeyboardKey.mediaPlayPause) {
        _playOrPause();
        _resetHideTimer();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    if (!_showChannelList) {
      if (key == LogicalKeyboardKey.mediaPlayPause) {
        _playOrPause();
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
    _positionTimer?.cancel();
    _playerChannel?.invokeMethod('dispose');
    _playerChannel?.setMethodCallHandler(null);
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
              // Native ExoPlayer surface
              Positioned.fill(
                child: AndroidView(
                  viewType: 'com.wallyt.iptv/exoplayer_view',
                  onPlatformViewCreated: _onPlatformViewCreated,
                  creationParamsCodec: const StandardMessageCodec(),
                ),
              ),

              // Buffering indicator
              if (_isBuffering)
                const Center(
                  child: CircularProgressIndicator(color: Color(0xFF60A5FA)),
                ),

              if (_showControls && !_showChannelList)
                _buildControlsOverlay(_isPlaying),

              if (_showOsd && !_showControls && !_showChannelList)
                _buildOsd(_isBuffering),

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
                  bottom: 0, left: 0, right: 0,
                  child: ExcludeFocus(child: _buildProgressBar()),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlsOverlay(bool isPlaying) {
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
            top: 16, left: 16,
            child: Row(children: [
              IconButton(
                focusNode: _backFocus,
                icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
              IconButton(
                icon: const Icon(Icons.picture_in_picture_alt, color: Colors.white, size: 24),
                onPressed: () => PipService.enterPip(),
              ),
            ]),
          ),
          Positioned(
            top: 20, left: 110, right: 60,
            child: Text(
              _currentChannel.name,
              style: const TextStyle(color: Colors.white, fontSize: 20,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(color: Colors.black, blurRadius: 6)]),
              maxLines: 1, overflow: TextOverflow.ellipsis,
            ),
          ),
          if (!widget.isMovie && _currentChannel.streamId != null)
            Positioned(
              top: 8, right: 8,
              child: IconButton(
                focusNode: _epgFocus,
                icon: const Icon(Icons.calendar_today, color: Colors.white, size: 24),
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => EpgScreen(channel: _currentChannel))),
              ),
            ),
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildControlBtn(Icons.fast_rewind, () async {
                  final pos = await _playerChannel?.invokeMethod<int>('getPosition') ?? 0;
                  _playerChannel?.invokeMethod('seekTo', {'ms': (pos - 10000).clamp(0, 999999999)});
                }, focusNode: _rewindFocus),
                const SizedBox(width: 24),
                _buildControlBtn(
                  isPlaying ? Icons.pause_circle : Icons.play_circle,
                  _playOrPause,
                  size: 72,
                  focusNode: _playFocus,
                ),
                const SizedBox(width: 24),
                _buildControlBtn(Icons.fast_forward, () async {
                  final pos = await _playerChannel?.invokeMethod<int>('getPosition') ?? 0;
                  _playerChannel?.invokeMethod('seekTo', {'ms': pos + 10000});
                }, focusNode: _fwdFocus),
              ],
            ),
          ),
          if (!widget.isMovie && _currentChannel.streamId != null)
            Positioned(
              bottom: 16, left: 16,
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
            child: Center(
              child: Text(
                _currentChannel.name,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
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
      onPressed: () { _resetHideTimer(); onPressed(); },
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.15),
        shape: const CircleBorder(),
      ),
    );
  }

  Widget _buildOsd(bool isBuffering) {
    final chNum = _currentChannelIndex >= 0 ? _currentChannelIndex + 1 : null;
    return Positioned(
      bottom: 0, left: 0, right: 0,
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
                        style: const TextStyle(color: Color(0xFF60A5FA),
                            fontSize: 11, fontWeight: FontWeight.bold)),
                  Text(_currentChannel.name,
                      style: const TextStyle(color: Colors.white, fontSize: 18,
                          fontWeight: FontWeight.bold,
                          shadows: [Shadow(color: Colors.black, blurRadius: 6)]),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            if (isBuffering)
              const Padding(
                padding: EdgeInsets.only(left: 12),
                child: SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(color: Color(0xFF60A5FA), strokeWidth: 2)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    final dur = _duration;
    final progress = dur.inMilliseconds > 0
        ? _position.inMilliseconds / dur.inMilliseconds
        : 0.0;
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
                  setState(() { _isScrubbing = true; _scrubValue = v; });
                  _hideControlsTimer?.cancel();
                },
                onChanged: (v) => setState(() => _scrubValue = v),
                onChangeEnd: (v) {
                  if (dur.inMilliseconds > 0) {
                    final ms = (v * dur.inMilliseconds).toInt();
                    _playerChannel?.invokeMethod('seekTo', {'ms': ms});
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
                Text(_fmt(displayPos), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                Text(_fmt(dur), style: const TextStyle(color: Colors.white70, fontSize: 12)),
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
