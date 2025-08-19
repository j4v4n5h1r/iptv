// lib/widgets/favorites_list_overlay.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/channel.dart';

class FavoritesListOverlay extends StatefulWidget {
  final List<Channel> favorites;
  final Function(Channel) onFavoriteSelected;
  final Function(Channel) onRemoveFavorite;

  const FavoritesListOverlay({
    Key? key,
    required this.favorites,
    required this.onFavoriteSelected,
    required this.onRemoveFavorite,
  }) : super(key: key);

  @override
  _FavoritesListOverlayState createState() => _FavoritesListOverlayState();
}

class _FavoritesListOverlayState extends State<FavoritesListOverlay> {
  late List<Channel> _currentFavorites;
  late List<FocusNode> _itemFocusNodes;
  late FocusNode _closeButtonFocusNode;
  int _focusedIndex = -1; // -1 for close button, 0+ for items
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _currentFavorites = widget.favorites;
    _closeButtonFocusNode = FocusNode(debugLabel: 'CloseButton');
    _initializeFocusNodes();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
      if (_itemFocusNodes.isNotEmpty) {
        _itemFocusNodes[0].requestFocus();
        _focusedIndex = 0;
      } else {
        _closeButtonFocusNode.requestFocus();
        _focusedIndex = -1;
      }
    });
  }

  void _initializeFocusNodes() {
    _itemFocusNodes = List.generate(
      _currentFavorites.length,
      (index) => FocusNode(debugLabel: 'FavoriteItem$index'),
    );
  }

  @override
  void didUpdateWidget(FavoritesListOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.favorites.length != oldWidget.favorites.length) {
      setState(() {
        _currentFavorites = widget.favorites;
        _disposeFocusNodes();
        _initializeFocusNodes();
        _focusedIndex = _currentFavorites.isNotEmpty ? 0 : -1;
        if (_focusedIndex >= 0) {
          _itemFocusNodes[_focusedIndex].requestFocus();
        } else {
          _closeButtonFocusNode.requestFocus();
        }
      });
    }
  }

  void _disposeFocusNodes() {
    for (var node in _itemFocusNodes) {
      node.dispose();
    }
  }

  void _handleKeyEvent(RawKeyEvent event) {
    if (event is! RawKeyDownEvent) return;

    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowDown:
        if (_focusedIndex < _currentFavorites.length - 1) {
          setState(() => _focusedIndex++);
          _itemFocusNodes[_focusedIndex].requestFocus();
          _scrollToItem(_focusedIndex);
        }
        break;
      case LogicalKeyboardKey.arrowUp:
        if (_focusedIndex > 0) {
          setState(() => _focusedIndex--);
          _itemFocusNodes[_focusedIndex].requestFocus();
          _scrollToItem(_focusedIndex);
        } else if (_focusedIndex == 0) {
          setState(() => _focusedIndex = -1);
          _closeButtonFocusNode.requestFocus();
        }
        break;
      case LogicalKeyboardKey.select:
      case LogicalKeyboardKey.enter:
        if (_focusedIndex >= 0) {
          widget.onFavoriteSelected(_currentFavorites[_focusedIndex]);
        }
        break;
      case LogicalKeyboardKey.escape:
        Navigator.pop(context);
        break;
      default:
        break;
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
    _disposeFocusNodes();
    _closeButtonFocusNode.dispose();
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
          appBar: AppBar(
            title: Text('Favorites (${_currentFavorites.length})'),
            backgroundColor: Colors.deepOrange,
            leading: FocusableActionDetector(
              focusNode: _closeButtonFocusNode,
              onShowFocusHighlight: (hasFocus) {
                if (hasFocus) setState(() => _focusedIndex = -1);
              },
              actions: {
                ActivateIntent: CallbackAction<ActivateIntent>(
                  onInvoke: (_) => Navigator.pop(context),
                ),
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _closeButtonFocusNode.hasFocus
                        ? Colors.white
                        : Colors.transparent,
                    width: 2.0,
                  ),
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ),
          body: _currentFavorites.isEmpty
              ? const Center(
                  child: Text(
                    'No favorites added yet',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                )
              : RawKeyboardListener(
                  focusNode: FocusNode(),
                  onKey: _handleKeyEvent,
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16.0),
                    itemCount: _currentFavorites.length,
                    itemBuilder: (context, index) {
                      final channel = _currentFavorites[index];
                      return _buildFavoriteItem(channel, index);
                    },
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildFavoriteItem(Channel channel, int index) {
    return FocusableActionDetector(
      focusNode: _itemFocusNodes[index],
      onShowFocusHighlight: (hasFocus) {
        if (hasFocus) setState(() => _focusedIndex = index);
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) => widget.onFavoriteSelected(channel),
        ),
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(
              color: _itemFocusNodes[index].hasFocus
                  ? Colors.deepOrange
                  : Colors.transparent,
              width: 2.0,
            ),
            color: _itemFocusNodes[index].hasFocus
                ? Colors.deepOrange.withOpacity(0.2)
                : Colors.transparent,
          ),
          child: Row(
            children: [
              Expanded(
                child: ListTile(
                  title: Text(
                    channel.name,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: _itemFocusNodes[index].hasFocus ? 18 : 16,
                      fontWeight: _itemFocusNodes[index].hasFocus
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  leading: Icon(
                    channel.isMovie ? Icons.movie : Icons.live_tv,
                    color: Colors.deepOrange,
                    size: 30,
                  ),
                  onTap: () => widget.onFavoriteSelected(channel),
                ),
              ),
              FocusableActionDetector(
                actions: {
                  ActivateIntent: CallbackAction<ActivateIntent>(
                    onInvoke: (_) {
                      widget.onRemoveFavorite(channel);
                      return null;
                    },
                  ),
                },
                child: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red, size: 28),
                  onPressed: () => widget.onRemoveFavorite(channel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}