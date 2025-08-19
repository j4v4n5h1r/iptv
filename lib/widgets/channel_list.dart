// lib/widgets/channel_list.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../screens/player_screen.dart';
import '../models/channel.dart';

class ChannelList extends StatefulWidget {
  final List<Channel> channels;
  final bool isMovie;
  final Function(Channel channel) onFavoriteToggled;
  final FocusNode focusNode;

  const ChannelList({
    super.key,
    required this.channels,
    this.isMovie = false,
    required this.onFavoriteToggled,
    required this.focusNode,
  });

  @override
  State<ChannelList> createState() => _ChannelListState();
}

class _ChannelListState extends State<ChannelList> {
  late List<FocusNode> _itemFocusNodes;
  int _focusedIndex = 0;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _itemFocusNodes = List.generate(
      widget.channels.length,
      (index) => FocusNode(debugLabel: 'ChannelItem$index'),
    );
    widget.focusNode.addListener(_handleParentFocusChange);
  }

  @override
  void didUpdateWidget(ChannelList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.channels.length != widget.channels.length) {
      // Dispose old focus nodes
      for (var node in _itemFocusNodes) {
        node.dispose();
      }
      // Create new focus nodes
      _itemFocusNodes = List.generate(
        widget.channels.length,
        (index) => FocusNode(debugLabel: 'ChannelItem$index'),
      );
      _focusedIndex = 0;
    }
  }

  void _handleParentFocusChange() {
    if (widget.focusNode.hasFocus && _itemFocusNodes.isNotEmpty) {
      _itemFocusNodes[_focusedIndex].requestFocus();
    }
  }

  void _handleKeyEvent(RawKeyEvent event) {
    if (event is! RawKeyDownEvent) return;

    final int crossAxisCount = 4;
    int newIndex = _focusedIndex;

    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowDown:
        newIndex += crossAxisCount;
        break;
      case LogicalKeyboardKey.arrowUp:
        newIndex -= crossAxisCount;
        break;
      case LogicalKeyboardKey.arrowLeft:
        if (_focusedIndex % crossAxisCount != 0) newIndex -= 1;
        break;
      case LogicalKeyboardKey.arrowRight:
        if ((_focusedIndex + 1) % crossAxisCount != 0) newIndex += 1;
        break;
      case LogicalKeyboardKey.select:
      case LogicalKeyboardKey.enter:
        _navigateToPlayer(widget.channels[_focusedIndex]);
        return;
      default:
        return;
    }

    if (newIndex >= 0 && newIndex < widget.channels.length) {
      setState(() => _focusedIndex = newIndex);
      _itemFocusNodes[newIndex].requestFocus();
      _ensureItemVisible(newIndex);
    }
  }

  void _ensureItemVisible(int index) {
    final double itemHeight = MediaQuery.of(context).size.width / 4 * 0.9;
    final double scrollPosition = index ~/ 4 * itemHeight;
    
    _scrollController.animateTo(
      scrollPosition,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _navigateToPlayer(Channel channel) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlayerScreen(
          channel: channel,
          channels: widget.channels,
          isMovie: widget.isMovie,
          onFavoriteToggled: widget.onFavoriteToggled,
        ),
      ),
    );
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_handleParentFocusChange);
    _scrollController.dispose();
    for (var node in _itemFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          child: GridView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16.0),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 16.0,
              mainAxisSpacing: 16.0,
              childAspectRatio: 0.9,
            ),
            itemCount: widget.channels.length,
            itemBuilder: (context, index) {
              final channel = widget.channels[index];
              return FocusableActionDetector(
                focusNode: _itemFocusNodes[index],
                onShowFocusHighlight: (hasFocus) {
                  if (hasFocus) setState(() => _focusedIndex = index);
                },
                actions: {
                  ActivateIntent: CallbackAction<ActivateIntent>(
                    onInvoke: (_) => _navigateToPlayer(channel),
                  ),
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12.0),
                    border: Border.all(
                      color: _itemFocusNodes[index].hasFocus
                          ? Colors.deepOrange
                          : Colors.transparent,
                      width: 3.0,
                    ),
                    boxShadow: _itemFocusNodes[index].hasFocus
                        ? [
                            BoxShadow(
                              color: Colors.deepOrange.withOpacity(0.5),
                              spreadRadius: 2,
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            )
                          ]
                        : null,
                  ),
                  child: Material(
                    color: Colors.black.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(8.0),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8.0),
                      onTap: () => _navigateToPlayer(channel),
                      child: Stack(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: Center(
                                  child: Icon(
                                    widget.isMovie ? Icons.movie : Icons.live_tv,
                                    size: 40,
                                    color: Colors.deepOrange,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  channel.name,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: _itemFocusNodes[index].hasFocus ? 14.0 : 12.0,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: FocusableActionDetector(
                              actions: {
                                ActivateIntent: CallbackAction<ActivateIntent>(
                                  onInvoke: (_) {
                                    final updatedChannel = channel.copyWith(
                                      isFavorite: !channel.isFavorite,
                                    );
                                    widget.onFavoriteToggled(updatedChannel);
                                    return null;
                                  },
                                ),
                              },
                              child: IconButton(
                                icon: Icon(
                                  channel.isFavorite
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  color: Colors.red,
                                  size: 24,
                                ),
                                onPressed: () {
                                  final updatedChannel = channel.copyWith(
                                    isFavorite: !channel.isFavorite,
                                  );
                                  widget.onFavoriteToggled(updatedChannel);
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}