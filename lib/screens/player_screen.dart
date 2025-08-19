// lib/screens/player_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../widgets/channel_list_overlay.dart';
import '../widgets/player_controls.dart';
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
  late VideoPlayerController _controller;
  late Channel _currentChannel;
  bool _showOverlay = true;
  bool _showChannelList = false;

  final FocusNode _playerFocusNode = FocusNode();
  final FocusNode _backButtonFocusNode = FocusNode();
  final FocusNode _channelListButtonFocusNode = FocusNode();
  final FocusNode _controlsFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _currentChannel = widget.channel;
    _initializePlayer(_currentChannel.url);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
      _playerFocusNode.requestFocus();
    });
  }

  void _initializePlayer(String url) {
    _controller = VideoPlayerController.networkUrl(Uri.parse(url))
      ..initialize().then((_) {
        if (mounted) {
          setState(() {});
          _controller.play();
        }
      });
  }

  void _changeChannel(Channel newChannel) {
    _controller.dispose();
    setState(() {
      _currentChannel = newChannel;
      _showChannelList = false;
      _showOverlay = true;
    });
    _initializePlayer(newChannel.url);
  }

  void _toggleChannelList() {
    setState(() {
      _showChannelList = !_showChannelList;
      if (_showChannelList) {
        _showOverlay = false;
      }
    });
  }

  void _toggleOverlay() {
    if (!_showChannelList) {
      setState(() => _showOverlay = !_showOverlay);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.select): const ActivateIntent(),
        LogicalKeySet(LogicalKeyboardKey.enter): const ActivateIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowUp): const DirectionalFocusIntent(TraversalDirection.up),
        LogicalKeySet(LogicalKeyboardKey.arrowDown): const DirectionalFocusIntent(TraversalDirection.down),
        LogicalKeySet(LogicalKeyboardKey.arrowLeft): const DirectionalFocusIntent(TraversalDirection.left),
        LogicalKeySet(LogicalKeyboardKey.arrowRight): const DirectionalFocusIntent(TraversalDirection.right),
      },
      child: FocusTraversalGroup(
        policy: WidgetOrderTraversalPolicy(),
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              Center(
                child: Focus(
                  focusNode: _playerFocusNode,
                  autofocus: true,
                  child: GestureDetector(
                    onTap: _toggleOverlay,
                    child: _controller.value.isInitialized
                        ? AspectRatio(
                            aspectRatio: _controller.value.aspectRatio,
                            child: VideoPlayer(_controller),
                          )
                        : const Center(
                            child: CircularProgressIndicator(color: Colors.deepOrange),
                          ),
                  ),
                ),
              ),
              if (_showOverlay)
                Positioned(
                  top: 40,
                  left: 10,
                  child: FocusableActionDetector(
                    focusNode: _backButtonFocusNode,
                    onShowFocusHighlight: (value) => setState(() {}),
                    actions: <Type, Action<Intent>>{
                      ActivateIntent: CallbackAction<ActivateIntent>(
                        onInvoke: (ActivateIntent intent) => Navigator.pop(context),
                      ),
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 100),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: _backButtonFocusNode.hasFocus
                            ? Border.all(color: Colors.deepOrange, width: 2)
                            : null,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ),
                ),
              if (_showOverlay && !_showChannelList)
                PlayerControls(
                  controller: _controller,
                  channelName: _currentChannel.name,
                  onFavoriteToggle: () {
                    final updatedChannel = _currentChannel.copyWith(
                      isFavorite: !_currentChannel.isFavorite,
                    );
                    setState(() {
                      _currentChannel = updatedChannel;
                    });
                    widget.onFavoriteToggled(updatedChannel);
                  },
                  isFavorite: _currentChannel.isFavorite,
                  focusNode: _controlsFocusNode,
                ),
              if (_showChannelList)
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    height: MediaQuery.of(context).size.height,
                    width: MediaQuery.of(context).size.width,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.9),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: ChannelListOverlay(
                            channels: widget.channels,
                            onChannelSelected: _changeChannel,
                            isMovie: widget.isMovie,
                            onClose: _toggleChannelList,
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: [
                                Expanded(
                                  flex: 4,
                                  child: AspectRatio(
                                    aspectRatio: _controller.value.aspectRatio,
                                    child: VideoPlayer(_controller),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Expanded(
                                  flex: 1,
                                  child: Text(
                                    _currentChannel.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
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
                  ),
                ),
              Positioned(
                bottom: 20,
                right: 20,
                child: FocusableActionDetector(
                  focusNode: _channelListButtonFocusNode,
                  onShowFocusHighlight: (value) => setState(() {}),
                  actions: <Type, Action<Intent>>{
                    ActivateIntent: CallbackAction<ActivateIntent>(
                      onInvoke: (ActivateIntent intent) => _toggleChannelList(),
                    ),
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 100),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      border: _channelListButtonFocusNode.hasFocus
                          ? Border.all(color: Colors.white, width: 2)
                          : null,
                      boxShadow: _channelListButtonFocusNode.hasFocus
                          ? [
                              BoxShadow(
                                color: Colors.deepOrange.withOpacity(0.5),
                                spreadRadius: 2,
                                blurRadius: 5,
                                offset: const Offset(0, 0),
                              )
                            ]
                          : null,
                    ),
                    child: FloatingActionButton.extended(
                      onPressed: _toggleChannelList,
                      label: Text(widget.isMovie ? 'Movies' : 'Channels'),
                      icon: const Icon(Icons.list),
                      backgroundColor: _channelListButtonFocusNode.hasFocus
                          ? Colors.deepOrange.shade700
                          : Colors.deepOrange,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _playerFocusNode.dispose();
    _backButtonFocusNode.dispose();
    _channelListButtonFocusNode.dispose();
    _controlsFocusNode.dispose();
    super.dispose();
  }
}