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
  bool _showOsd = false;

  // Timeshift
  bool _isTimeshifted = false;
  bool _isScrubbing = false;
  double _scrubValue = 0.0;

  // Player pozisyonu state'de tutulur — StreamBuilder rebuild race condition'ını önler
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<bool>? _bufferingSub;
  StreamSubscription<bool>? _playingSub;

  Timer? _hideControlsTimer;
  Timer? _osdTimer;

  final FocusNode _playerFocusNode = FocusNode();
  final FocusNode _backFocus      = FocusNode();
  final FocusNode _favFocus       = FocusNode();
  final FocusNode _epgFocus       = FocusNode();
  final FocusNode _rewindFocus    = FocusNode();
  final FocusNode _playFocus      = FocusNode();
  final FocusNode _fwdFocus       = FocusNode();
  final FocusNode _timeshiftFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _currentChannel = widget.channel;
    _player = Player(
      configuration: const PlayerConfiguration(
        bufferSize: 8 * 1024 * 1024, // 8MB — daha hızlı başlangıç, düşük RAM kullanımı
        logLevel: MPVLogLevel.error,
      ),
    );
    _videoController = VideoController(
      _player,
      configuration: const VideoControllerConfiguration(
        hwdec: 'auto',           // tam donanım hızlandırma
        androidAttachSurfaceAfterVideoParameters: false,
      ),
    );
    _videoWidget = RepaintBoundary(
      child: SizedBox.expand(
        child: Video(controller: _videoController, controls: NoVideoControls, fit: BoxFit.contain),
      ),
    );

    _isPlaying = _player.state.playing;
    _playingSub = _player.stream.playing.listen((playing) {
      if (mounted && playing != _isPlaying) setState(() => _isPlaying = playing);
    });

    _bufferingSub = _player.stream.buffering.listen((buffering) {
      if (mounted && buffering != _isBuffering) setState(() => _isBuffering = buffering);
    });

    _positionSub = _player.stream.position.listen((pos) {
      if (!mounted || _isScrubbing) return;
      if (widget.isMovie) {
        final diff = (pos.inSeconds - _position.inSeconds).abs();
        if (diff >= 1) setState(() => _position = pos);
      }
    });

    _durationSub = _player.stream.duration.listen((dur) {
      if (mounted && dur != _duration) setState(() => _duration = dur);
    });

    _openMedia(_currentChannel.url);
    _resetHideTimer();

    WidgetsBinding.instance.addPostFrameCallback((_) {
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

    // 10 saniye içinde oynatma başlamazsa live'a geri dön
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
    setState(() {
      _currentChannel = channel;
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _playFocus.requestFocus();
      });
    }
  }

  void _showControlsTemp() {
    if (!_showControls) {
      setState(() => _showControls = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _playFocus.requestFocus();
      });
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

    // Controls açıkken butonlar kendi focus'larını yönetir — sadece mediaPlayPause yakala
    if (_showControls && !_showChannelList) {
      if (key == LogicalKeyboardKey.mediaPlayPause) {
        _player.playOrPause();
        _resetHideTimer();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    // Controls kapalı
    if (!_showChannelList) {
      if (key == LogicalKeyboardKey.mediaPlayPause) {
        _player.playOrPause();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowUp) {
        final idx = widget.channels.indexWhere((c) => c.url == _currentChannel.url);
        if (idx > 0) _changeChannel(widget.channels[idx - 1]);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowDown) {
        final idx = widget.channels.indexWhere((c) => c.url == _currentChannel.url);
        if (idx < widget.channels.length - 1) _changeChannel(widget.channels[idx + 1]);
        return KeyEventResult.handled;
      }
      // Diğer tuşlar controls'u aç
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
    _favFocus.dispose();
    _epgFocus.dispose();
    _rewindFocus.dispose();
    _playFocus.dispose();
    _fwdFocus.dispose();
    _timeshiftFocus.dispose();
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
              // Video — initState'de bir kez oluşturuldu, rebuild yok
              _videoWidget,

              // Buffering indicator
              if (_isBuffering)
                const Center(
                  child: CircularProgressIndicator(color: const Color(0xFF60A5FA)),
                ),

              // Controls overlay
              if (_showControls && !_showChannelList)
                _buildControlsOverlay(),

              // OSD
              if (_showOsd && !_showControls && !_showChannelList)
                _buildOsd(),

              // Channel list
              if (_showChannelList)
                _buildChannelListOverlay(),

              // Channel list FAB — controls ile birlikte göster/gizle
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

              // Progress bar — focus dışında tut
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
          // Back button
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
                  tooltip: 'Picture in Picture',
                  onPressed: () => PipService.enterPip(),
                ),
              ],
            ),
          ),

          // Channel name + favorite
          Positioned(
            top: 16,
            left: 70,
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

          // Favorite + EPG buttons
          Positioned(
            top: 8,
            right: 8,
            child: Row(
              children: [
                if (!widget.isMovie && _currentChannel.streamId != null)
                  IconButton(
                    focusNode: _epgFocus,
                    icon: const Icon(Icons.calendar_today, color: Colors.white, size: 24),
                    tooltip: 'Programme Guide',
                    onPressed: _openEpg,
                  ),
              ],
            ),
          ),

          // Center play/pause controls
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

          // Timeshift button (live only)
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
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      _currentChannel.name,
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlBtn(IconData icon, VoidCallback onPressed, {double size = 52, FocusNode? focusNode}) {
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
    final idx = widget.channels.indexWhere((c) => c.url == _currentChannel.url);
    final chNum = idx >= 0 ? idx + 1 : null;
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: AnimatedOpacity(
        opacity: _showOsd ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                Colors.black.withValues(alpha: 0.85),
                Colors.transparent,
              ],
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Channel logo
              if (_currentChannel.logo != null && _currentChannel.logo!.isNotEmpty)
                Container(
                  width: 56,
                  height: 42,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.network(
                      _currentChannel.logo!,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (chNum != null)
                      Text(
                        'CH $chNum',
                        style: const TextStyle(color: const Color(0xFF60A5FA), fontSize: 11, fontWeight: FontWeight.bold),
                      ),
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
              // Buffering dot
              if (_isBuffering)
                const Padding(
                  padding: EdgeInsets.only(left: 12),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: const Color(0xFF60A5FA),
                      strokeWidth: 2,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    // State değişkenlerini doğrudan kullan — StreamBuilder yok
    // Bu sayede: controls kapanıp açılınca sıfırlanmaz, rebuild race condition yok
    final dur = _duration;
    final playerProgress =
        dur.inMilliseconds > 0 ? _position.inMilliseconds / dur.inMilliseconds : 0.0;

    final displayValue = _isScrubbing ? _scrubValue : playerProgress.clamp(0.0, 1.0);

    final displayPos = _isScrubbing && dur.inMilliseconds > 0
        ? Duration(milliseconds: (_scrubValue * dur.inMilliseconds).toInt())
        : _position;

    return GestureDetector(
      onTap: () {}, // parent _toggleControls'u engelle
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
                  _isScrubbing = true;
                  _scrubValue = v;
                  _hideControlsTimer?.cancel();
                },
                onChanged: (v) {
                  setState(() => _scrubValue = v);
                },
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
                Text(_formatDuration(displayPos),
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
                Text(_formatDuration(dur),
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}
