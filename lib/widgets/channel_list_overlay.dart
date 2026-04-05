import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/channel.dart';

class ChannelListOverlay extends StatefulWidget {
  final List<Channel> channels;
  final Function(Channel channel) onChannelSelected;
  final bool isMovie;
  final Function() onClose;

  const ChannelListOverlay({
    super.key,
    required this.channels,
    required this.onChannelSelected,
    required this.isMovie,
    required this.onClose,
  });

  @override
  State<ChannelListOverlay> createState() => _ChannelListOverlayState();
}

class _ChannelListOverlayState extends State<ChannelListOverlay> {
  final TextEditingController _searchController = TextEditingController();
  List<Channel> _filteredChannels = [];
  final FocusNode _searchFocusNode = FocusNode();
  final FocusNode _keyboardFocusNode = FocusNode();
  int _focusedIndex = -1;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _filteredChannels = widget.channels;
    _searchController.addListener(_filterChannels);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _keyboardFocusNode.requestFocus();
    });
  }

  @override
  void didUpdateWidget(ChannelListOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.channels != oldWidget.channels) {
      _filterChannels();
    }
  }

  void _filterChannels() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredChannels = widget.channels
          .where((c) => c.name.toLowerCase().contains(query))
          .toList();
      _focusedIndex = _focusedIndex.clamp(-1, _filteredChannels.length - 1);
    });
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowDown:
        if (_focusedIndex < _filteredChannels.length - 1) {
          setState(() => _focusedIndex++);
          _scrollToItem(_focusedIndex);
        }
        return KeyEventResult.handled;

      case LogicalKeyboardKey.arrowUp:
        if (_focusedIndex > 0) {
          setState(() => _focusedIndex--);
          _scrollToItem(_focusedIndex);
        } else if (_focusedIndex == 0) {
          setState(() => _focusedIndex = -1);
          _searchFocusNode.requestFocus();
        }
        return KeyEventResult.handled;

      case LogicalKeyboardKey.select:
      case LogicalKeyboardKey.enter:
        if (_focusedIndex >= 0 && _focusedIndex < _filteredChannels.length) {
          widget.onChannelSelected(_filteredChannels[_focusedIndex]);
        } else {
          // Enter on search — move focus to list
          setState(() => _focusedIndex = 0);
          _scrollToItem(0);
        }
        return KeyEventResult.handled;

      case LogicalKeyboardKey.escape:
      case LogicalKeyboardKey.goBack:
        widget.onClose();
        return KeyEventResult.handled;

      default:
        return KeyEventResult.ignored;
    }
  }

  void _scrollToItem(int index) {
    const itemHeight = 56.0;
    _scrollController.animateTo(
      index * itemHeight,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _keyboardFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _keyboardFocusNode,
      onKeyEvent: _handleKey,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    focusNode: _searchFocusNode,
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search...',
                      hintStyle: const TextStyle(color: Colors.white54),
                      prefixIcon: const Icon(Icons.search, color: Colors.deepOrange),
                      filled: true,
                      fillColor: Colors.grey[850],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: widget.onClose,
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _filteredChannels.length,
              itemBuilder: (context, index) {
                final channel = _filteredChannels[index];
                final isFocused = _focusedIndex == index;
                return GestureDetector(
                  onTap: () => widget.onChannelSelected(channel),
                  child: Container(
                    height: 56,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: isFocused
                          ? Colors.deepOrange.withValues(alpha: 0.25)
                          : Colors.transparent,
                      border: Border(
                        left: BorderSide(
                          color: isFocused ? Colors.deepOrange : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          widget.isMovie ? Icons.movie : Icons.live_tv,
                          color: isFocused ? Colors.deepOrange : Colors.white38,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            channel.name,
                            style: TextStyle(
                              color: isFocused ? Colors.white : Colors.white70,
                              fontSize: 14,
                              fontWeight: isFocused ? FontWeight.bold : FontWeight.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
