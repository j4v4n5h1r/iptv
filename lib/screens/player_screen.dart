import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../widgets/channel_list_overlay.dart';
import '../models/channel.dart';

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
  late Channel _currentChannel;

  bool _showControls = true;
  bool _showChannelList = false;
  bool _isBuffering = false;
  bool _showOsd = false;        // OSD: kanal değişince kısa süre gösterim

  Timer? _hideControlsTimer;
  Timer? _osdTimer;

  final FocusNode _playerFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _currentChannel = widget.channel;
    _player = Player();
    _videoController = VideoController(_player);

    _player.stream.buffering.listen((buffering) {
      if (mounted) setState(() => _isBuffering = buffering);
    });

    _openMedia(_currentChannel.url);
    _resetHideTimer();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
      _playerFocusNode.requestFocus();
    });
  }

  void _openMedia(String url) {
    _player.open(Media(url));
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

  void _showControlsTemp() {
    setState(() => _showControls = true);
    _resetHideTimer();
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    _showControlsTemp();

    switch (event.logicalKey) {
      case LogicalKeyboardKey.goBack:
      case LogicalKeyboardKey.escape:
        if (_showChannelList) {
          setState(() => _showChannelList = false);
        } else {
          Navigator.pop(context);
        }
        return KeyEventResult.handled;

      case LogicalKeyboardKey.select:
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.mediaPlayPause:
        if (!_showChannelList) {
          _player.playOrPause();
        }
        return KeyEventResult.handled;

      case LogicalKeyboardKey.arrowLeft:
      case LogicalKeyboardKey.mediaRewind:
        if (!_showChannelList) {
          final pos = _player.state.position;
          _player.seek(pos - const Duration(seconds: 10));
        }
        return KeyEventResult.handled;

      case LogicalKeyboardKey.arrowRight:
      case LogicalKeyboardKey.mediaFastForward:
        if (!_showChannelList) {
          final pos = _player.state.position;
          _player.seek(pos + const Duration(seconds: 10));
        }
        return KeyEventResult.handled;

      case LogicalKeyboardKey.arrowUp:
        if (!_showChannelList) {
          // Channel up: previous in list
          final idx = widget.channels.indexWhere((c) => c.url == _currentChannel.url);
          if (idx > 0) _changeChannel(widget.channels[idx - 1]);
        }
        return KeyEventResult.handled;

      case LogicalKeyboardKey.arrowDown:
        if (!_showChannelList) {
          // Channel down: next in list
          final idx = widget.channels.indexWhere((c) => c.url == _currentChannel.url);
          if (idx < widget.channels.length - 1) _changeChannel(widget.channels[idx + 1]);
        }
        return KeyEventResult.handled;

      default:
        return KeyEventResult.ignored;
    }
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _osdTimer?.cancel();
    _player.dispose();
    _playerFocusNode.dispose();
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
          onTap: _showControlsTemp,
          child: Stack(
            children: [
              // Video
              SizedBox.expand(
                child: Video(
                  controller: _videoController,
                  controls: NoVideoControls,
                  fit: BoxFit.contain,
                ),
              ),

              // Buffering indicator
              if (_isBuffering)
                const Center(
                  child: CircularProgressIndicator(color: Colors.deepOrange),
                ),

              // Controls overlay
              if (_showControls && !_showChannelList)
                _buildControlsOverlay(),

              // OSD — kanal değişince kısa gösterim
              if (_showOsd && !_showControls && !_showChannelList)
                _buildOsd(),

              // Channel list
              if (_showChannelList)
                _buildChannelListOverlay(),

              // Channel list FAB (always visible)
              if (!_showChannelList)
                Positioned(
                  bottom: 20,
                  right: 20,
                  child: FloatingActionButton.extended(
                    onPressed: () {
                      setState(() => _showChannelList = true);
                      _hideControlsTimer?.cancel();
                    },
                    label: Text(widget.isMovie ? 'Movies' : 'Channels'),
                    icon: const Icon(Icons.list),
                    backgroundColor: Colors.deepOrange,
                  ),
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
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
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

          // Favorite button
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              icon: Icon(
                _currentChannel.isFavorite ? Icons.favorite : Icons.favorite_border,
                color: _currentChannel.isFavorite ? Colors.red : Colors.white,
                size: 28,
              ),
              onPressed: () {
                final updated = _currentChannel.copyWith(
                  isFavorite: !_currentChannel.isFavorite,
                );
                setState(() => _currentChannel = updated);
                widget.onFavoriteToggled(updated);
              },
            ),
          ),

          // Center play/pause controls
          Center(
            child: StreamBuilder<bool>(
              stream: _player.stream.playing,
              initialData: _player.state.playing,
              builder: (context, snapshot) {
                final isPlaying = snapshot.data ?? false;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildControlBtn(Icons.fast_rewind, () {
                      _player.seek(_player.state.position - const Duration(seconds: 10));
                    }),
                    const SizedBox(width: 24),
                    _buildControlBtn(
                      isPlaying ? Icons.pause_circle : Icons.play_circle,
                      _player.playOrPause,
                      size: 72,
                    ),
                    const SizedBox(width: 24),
                    _buildControlBtn(Icons.fast_forward, () {
                      _player.seek(_player.state.position + const Duration(seconds: 10));
                    }),
                  ],
                );
              },
            ),
          ),

          // Progress bar (for VOD)
          if (widget.isMovie)
            Positioned(
              bottom: 56,
              left: 16,
              right: 16,
              child: StreamBuilder<Duration>(
                stream: _player.stream.position,
                builder: (context, posSnap) {
                  return StreamBuilder<Duration>(
                    stream: _player.stream.duration,
                    builder: (context, durSnap) {
                      final pos = posSnap.data ?? Duration.zero;
                      final dur = durSnap.data ?? Duration.zero;
                      final progress = dur.inMilliseconds > 0
                          ? pos.inMilliseconds / dur.inMilliseconds
                          : 0.0;
                      return Column(
                        children: [
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 3,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                              overlayShape: SliderComponentShape.noOverlay,
                            ),
                            child: Slider(
                              value: progress.clamp(0.0, 1.0),
                              onChanged: (v) {
                                final seek = Duration(milliseconds: (v * dur.inMilliseconds).toInt());
                                _player.seek(seek);
                              },
                              activeColor: Colors.deepOrange,
                              inactiveColor: Colors.white30,
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_formatDuration(pos), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                              Text(_formatDuration(dur), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                            ],
                          ),
                        ],
                      );
                    },
                  );
                },
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

  Widget _buildControlBtn(IconData icon, VoidCallback onPressed, {double size = 52}) {
    return IconButton(
      icon: Icon(icon, color: Colors.white, size: size),
      onPressed: onPressed,
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
                        style: const TextStyle(color: Colors.deepOrange, fontSize: 11, fontWeight: FontWeight.bold),
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
                      color: Colors.deepOrange,
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

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}
