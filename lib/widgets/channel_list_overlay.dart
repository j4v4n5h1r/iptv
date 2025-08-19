// lib/widgets/channel_list_overlay.dart
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
  late FocusNode _searchFocusNode;
  late FocusNode _closeButtonFocusNode;
  final List<FocusNode> _listFocusNodes = [];
  int _focusedIndex = -1; // -1 for search bar, 0 for close button, 1+ for list items
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _searchFocusNode = FocusNode(debugLabel: 'SearchField');
    _closeButtonFocusNode = FocusNode(debugLabel: 'CloseButton');
    _filteredChannels = widget.channels;
    _searchController.addListener(_filterChannels);
    _initFocusNodes();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
      _searchFocusNode.requestFocus();
    });
  }

  void _initFocusNodes() {
    _listFocusNodes.clear();
    _listFocusNodes.addAll(
      List.generate(_filteredChannels.length, (index) => FocusNode())
    );
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
          .where((channel) => channel.name.toLowerCase().contains(query))
          .toList();
      _initFocusNodes();
    });
  }

  void _handleKeyEvent(RawKeyEvent event) {
    if (event is! RawKeyDownEvent) return;

    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowDown:
        if (_focusedIndex < _filteredChannels.length - 1) {
          setState(() => _focusedIndex++);
          _requestFocusForCurrentIndex();
          _scrollToItem(_focusedIndex);
        }
        break;
      case LogicalKeyboardKey.arrowUp:
        if (_focusedIndex > 0) {
          setState(() => _focusedIndex--);
          _requestFocusForCurrentIndex();
          _scrollToItem(_focusedIndex);
        } else if (_focusedIndex == 0) {
          setState(() => _focusedIndex = -1);
          _searchFocusNode.requestFocus();
        }
        break;
      case LogicalKeyboardKey.select:
      case LogicalKeyboardKey.enter:
        if (_focusedIndex >= 0) {
          widget.onChannelSelected(_filteredChannels[_focusedIndex]);
        }
        break;
      case LogicalKeyboardKey.escape:
        widget.onClose();
        break;
      default:
        break;
    }
  }

  void _requestFocusForCurrentIndex() {
    if (_focusedIndex >= 0 && _focusedIndex < _listFocusNodes.length) {
      _listFocusNodes[_focusedIndex].requestFocus();
    }
  }

  void _scrollToItem(int index) {
    final double itemHeight = 72.0; // Approximate height of ListTile
    final double scrollPosition = index * itemHeight;
    
    _scrollController.animateTo(
      scrollPosition,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _closeButtonFocusNode.dispose();
    for (var node in _listFocusNodes) {
      node.dispose();
    }
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.select): const ActivateIntent(),
        LogicalKeySet(LogicalKeyboardKey.enter): const ActivateIntent(),
        LogicalKeySet(LogicalKeyboardKey.escape): const ActivateIntent(),
      },
      child: FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: Scaffold(
          backgroundColor: Colors.black.withOpacity(0.9),
          body: RawKeyboardListener(
            focusNode: FocusNode(),
            onKey: _handleKeyEvent,
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Focus(
                            focusNode: _searchFocusNode,
                            onFocusChange: (hasFocus) {
                              if (hasFocus) setState(() => _focusedIndex = -1);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: _searchFocusNode.hasFocus
                                      ? Colors.deepOrange
                                      : Colors.transparent,
                                  width: 2.0,
                                ),
                              ),
                              child: TextField(
                                controller: _searchController,
                                decoration: InputDecoration(
                                  hintText: 'Search...',
                                  hintStyle: const TextStyle(color: Colors.white54),
                                  prefixIcon: const Icon(Icons.search, color: Colors.deepOrange),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide.none,
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey[800],
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                ),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        FocusableActionDetector(
                          focusNode: _closeButtonFocusNode,
                          onShowFocusHighlight: (hasFocus) {
                            if (hasFocus) setState(() => _focusedIndex = -2);
                          },
                          actions: {
                            ActivateIntent: CallbackAction<ActivateIntent>(
                              onInvoke: (_) => widget.onClose(),
                            ),
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _closeButtonFocusNode.hasFocus
                                    ? Colors.deepOrange
                                    : Colors.transparent,
                                width: 2.0,
                              ),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.close, color: Colors.white),
                              onPressed: widget.onClose,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filteredChannels.length,
                      itemBuilder: (context, index) {
                        final channel = _filteredChannels[index];
                        return FocusableActionDetector(
                          focusNode: _listFocusNodes[index],
                          onShowFocusHighlight: (hasFocus) {
                            if (hasFocus) setState(() => _focusedIndex = index);
                          },
                          actions: {
                            ActivateIntent: CallbackAction<ActivateIntent>(
                              onInvoke: (_) => widget.onChannelSelected(channel),
                            ),
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _listFocusNodes[index].hasFocus
                                    ? Colors.deepOrange
                                    : Colors.transparent,
                                width: 2.0,
                              ),
                              color: _listFocusNodes[index].hasFocus
                                  ? Colors.deepOrange.withOpacity(0.2)
                                  : Colors.transparent,
                            ),
                            child: ListTile(
                              leading: Icon(
                                widget.isMovie ? Icons.movie : Icons.live_tv,
                                color: Colors.deepOrange,
                                size: 30,
                              ),
                              title: Text(
                                channel.name,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: _listFocusNodes[index].hasFocus ? 18 : 16,
                                  fontWeight: _listFocusNodes[index].hasFocus
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                              onTap: () => widget.onChannelSelected(channel),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}