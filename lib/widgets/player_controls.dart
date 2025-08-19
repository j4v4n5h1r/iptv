// lib/widgets/player_controls.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

class PlayerControls extends StatefulWidget {
  final VideoPlayerController controller;
  final String channelName;
  final Function() onFavoriteToggle;
  final bool isFavorite;
  final FocusNode focusNode;

  const PlayerControls({
    super.key,
    required this.controller,
    required this.channelName,
    required this.onFavoriteToggle,
    required this.isFavorite,
    required this.focusNode,
  });

  @override
  State<PlayerControls> createState() => _PlayerControlsState();
}

class _PlayerControlsState extends State<PlayerControls> {
  late List<FocusNode> _controlFocusNodes;
  late FocusNode _favoriteFocusNode;
  int _focusedIndex = 1; // Start with Play/Pause focused
  bool _showControls = true;
  final Duration _controlsHideDuration = const Duration(seconds: 3);
  Timer? _hideControlsTimer;

  @override
  void initState() {
    super.initState();
    _controlFocusNodes = [
      FocusNode(debugLabel: 'RewindButton'),
      FocusNode(debugLabel: 'PlayPauseButton'),
      FocusNode(debugLabel: 'FastForwardButton'),
    ];
    _favoriteFocusNode = FocusNode(debugLabel: 'FavoriteButton');
    _resetHideControlsTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
      _controlFocusNodes[_focusedIndex].requestFocus();
    });
  }

  void _resetHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(_controlsHideDuration, () {
      if (mounted) {
        setState(() => _showControls = false);
      }
    });
  }

  void _handleKeyEvent(RawKeyEvent event) {
    if (event is! RawKeyDownEvent) return;
    _resetHideControlsTimer();

    if (!_showControls) {
      setState(() => _showControls = true);
      return;
    }

    int newIndex = _focusedIndex;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowRight:
        newIndex++;
        break;
      case LogicalKeyboardKey.arrowLeft:
        newIndex--;
        break;
      case LogicalKeyboardKey.arrowUp:
        if (_focusedIndex >= 0 && _focusedIndex <= 2) {
          _favoriteFocusNode.requestFocus();
          _focusedIndex = -1; // -1 for favorite button
          return;
        }
        break;
      case LogicalKeyboardKey.arrowDown:
        // No action - progress bar not focusable
        return;
      case LogicalKeyboardKey.select:
      case LogicalKeyboardKey.enter:
        _executeCurrentAction();
        return;
      default:
        return;
    }

    if (newIndex >= 0 && newIndex < _controlFocusNodes.length) {
      setState(() => _focusedIndex = newIndex);
      _controlFocusNodes[newIndex].requestFocus();
    }
  }

  void _executeCurrentAction() {
    switch (_focusedIndex) {
      case 0:
        _handleRewind();
        break;
      case 1:
        _handlePlayPause();
        break;
      case 2:
        _handleFastForward();
        break;
      case -1:
        widget.onFavoriteToggle();
        break;
    }
  }

  void _handleRewind() {
    final newPosition = widget.controller.value.position - const Duration(seconds: 10);
    widget.controller.seekTo(newPosition);
  }

  void _handlePlayPause() {
    widget.controller.value.isPlaying ? widget.controller.pause() : widget.controller.play();
  }

  void _handleFastForward() {
    final newPosition = widget.controller.value.position + const Duration(seconds: 10);
    widget.controller.seekTo(newPosition);
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    for (var node in _controlFocusNodes) {
      node.dispose();
    }
    _favoriteFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_showControls) {
      return Container();
    }

    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.select): const ActivateIntent(),
        LogicalKeySet(LogicalKeyboardKey.enter): const ActivateIntent(),
      },
      child: Focus(
        focusNode: widget.focusNode,
        child: RawKeyboardListener(
          focusNode: FocusNode(),
          onKey: _handleKeyEvent,
          child: Stack(
            children: [
              // Playback controls
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildControlButton(
                      Icons.fast_rewind,
                      0,
                      _handleRewind,
                    ),
                    ValueListenableBuilder<VideoPlayerValue>(
                      valueListenable: widget.controller,
                      builder: (context, value, child) {
                        return _buildControlButton(
                          value.isPlaying ? Icons.pause : Icons.play_arrow,
                          1,
                          _handlePlayPause,
                          size: 80,
                        );
                      },
                    ),
                    _buildControlButton(
                      Icons.fast_forward,
                      2,
                      _handleFastForward,
                    ),
                  ],
                ),
              ),
              // Favorite button
              Positioned(
                top: 40,
                right: 20,
                child: FocusableActionDetector(
                  focusNode: _favoriteFocusNode,
                  onShowFocusHighlight: (hasFocus) {
                    if (hasFocus) setState(() => _focusedIndex = -1);
                  },
                  actions: {
                    ActivateIntent: CallbackAction<ActivateIntent>(
                      onInvoke: (_) => widget.onFavoriteToggle(),
                    ),
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _favoriteFocusNode.hasFocus
                            ? Colors.deepOrange
                            : Colors.transparent,
                        width: 2.0,
                      ),
                    ),
                    child: IconButton(
                      icon: Icon(
                        widget.isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: Colors.red,
                        size: 30,
                      ),
                      onPressed: widget.onFavoriteToggle,
                    ),
                  ),
                ),
              ),
              // Channel name
              Positioned(
                bottom: 20,
                left: 20,
                child: Text(
                  widget.channelName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        color: Colors.black,
                        blurRadius: 6,
                        offset: Offset(0, 0),
                      ),
                    ],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Progress bar
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: VideoProgressIndicator(
                  widget.controller,
                  allowScrubbing: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  colors: const VideoProgressColors(
                    playedColor: Colors.deepOrange,
                    bufferedColor: Colors.white54,
                    backgroundColor: Colors.white24,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlButton(IconData icon, int index, VoidCallback onPressed, {double size = 60}) {
    return FocusableActionDetector(
      focusNode: _controlFocusNodes[index],
      onShowFocusHighlight: (hasFocus) {
        if (hasFocus) setState(() => _focusedIndex = index);
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            onPressed();
            return null;
          },
        ),
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _controlFocusNodes[index].hasFocus
              ? Colors.deepOrange.withOpacity(0.3)
              : Colors.transparent,
          border: Border.all(
            color: _controlFocusNodes[index].hasFocus
                ? Colors.deepOrange
                : Colors.transparent,
            width: 2.0,
          ),
        ),
        child: IconButton(
          icon: Icon(icon),
          iconSize: size,
          color: _controlFocusNodes[index].hasFocus ? Colors.deepOrange : Colors.white,
          onPressed: onPressed,
        ),
      ),
    );
  }
}