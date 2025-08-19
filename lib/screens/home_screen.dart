import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/channel_list.dart';
import '../models/channel.dart';
import '../widgets/favorites_list_overlay.dart';
import 'settings_screen.dart';
import 'player_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Channel> _filteredList = [];
  final List<Channel> _channels = [
    Channel(name: '4tv News', url: 'http://51.254.122.232:5005/stream/tata/4tvnews/master.m3u8?u=atech&p=1491fed6b7de88547a8fd33cdb98e457a54e142527b1b59f6c0502a8a87fb6bb'),
    Channel(name: '7x Music', url: 'http://51.254.122.232:5005/stream/tata/7xmusic/master.m3u8?u=atech&p=1491fed6b7de88547a8fd33cdb98e457a54e142527b1b59f6c0502a8a87fb6bb'),
  ];
  final List<Channel> _movies = [
    Channel(name: 'Movie 1', url: 'http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4', isMovie: true),
    Channel(name: 'Movie 2', url: 'http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4', isMovie: true),
    Channel(name: 'Movie 3', url: 'http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4', isMovie: true),
    Channel(name: 'Movie 4', url: 'http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4', isMovie: true),
  ];
  final Set<Channel> _favorites = {};

  bool _isShowingMovies = false;

  // Define FocusNodes for navigation
  final FocusNode _searchFocusNode = FocusNode();
  final FocusNode _toggleListFocusNode = FocusNode();
  final FocusNode _favoritesFocusNode = FocusNode();
  final FocusNode _settingsFocusNode = FocusNode();
  final FocusNode _channelListFocusNode = FocusNode();

  void _handleFavoriteToggle(Channel channel) {
    setState(() {
      final listToUpdate = channel.isMovie ? _movies : _channels;
      final index = listToUpdate.indexWhere((c) => c == channel);
      
      if (index != -1) {
        final updatedChannel = listToUpdate[index].copyWith(
          isFavorite: !listToUpdate[index].isFavorite,
        );
        
        listToUpdate[index] = updatedChannel;
        
        if (updatedChannel.isFavorite) {
          _favorites.add(updatedChannel);
        } else {
          _favorites.remove(updatedChannel);
        }
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _filteredList = _channels;
    _searchController.addListener(_filterList);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
      _searchFocusNode.requestFocus();
    });
  }

  void _filterList() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredList = (_isShowingMovies ? _movies : _channels)
          .where((item) => item.name.toLowerCase().contains(query))
          .toList();
    });
  }

  void _toggleList() {
    setState(() {
      _isShowingMovies = !_isShowingMovies;
      _searchController.clear();
      _filteredList = _isShowingMovies ? _movies : _channels;
    });
  }

  void _removeFavorite(Channel channel) {
    setState(() {
      final listToUpdate = channel.isMovie ? _movies : _channels;
      final index = listToUpdate.indexWhere((c) => c == channel);
      if (index != -1) {
        listToUpdate[index] = listToUpdate[index].copyWith(isFavorite: false);
      }
      _favorites.removeWhere((c) => c == channel);
    });
  }

  void _navigateToFavorites() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FavoritesListOverlay(
          favorites: _favorites.toList(),
          onFavoriteSelected: (Channel channel) {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PlayerScreen(
                  channel: channel,
                  channels: channel.isMovie ? _movies : _channels,
                  isMovie: channel.isMovie,
                  onFavoriteToggled: _handleFavoriteToggle,
                ),
              ),
            );
          },
          onRemoveFavorite: _removeFavorite,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const Padding(
          padding: EdgeInsets.only(left: 8.0),
          child: Icon(Icons.connected_tv, color: Colors.deepOrange),
        ),
        title: const Text('Wallyt'),
        actions: [
          FocusableActionDetector(
            focusNode: _toggleListFocusNode,
            onShowFocusHighlight: (value) => setState(() {}),
            child: IconButton(
              icon: Icon(
                _isShowingMovies ? Icons.live_tv : Icons.movie,
                color: _toggleListFocusNode.hasFocus ? Colors.deepOrange : null,
              ),
              onPressed: _toggleList,
              style: IconButton.styleFrom(
                backgroundColor: _toggleListFocusNode.hasFocus 
                    ? Colors.deepOrange.withOpacity(0.3) 
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 8),
          FocusableActionDetector(
            focusNode: _favoritesFocusNode,
            onShowFocusHighlight: (value) => setState(() {}),
            child: IconButton(
              icon: Icon(
                Icons.favorite,
                color: _favoritesFocusNode.hasFocus ? Colors.deepOrange : null,
              ),
              onPressed: _navigateToFavorites,
              style: IconButton.styleFrom(
                backgroundColor: _favoritesFocusNode.hasFocus 
                    ? Colors.deepOrange.withOpacity(0.3) 
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 8),
          FocusableActionDetector(
            focusNode: _settingsFocusNode,
            onShowFocusHighlight: (value) => setState(() {}),
            child: IconButton(
              icon: Icon(
                Icons.settings,
                color: _settingsFocusNode.hasFocus ? Colors.deepOrange : null,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsScreen()),
                );
              },
              style: IconButton.styleFrom(
                backgroundColor: _settingsFocusNode.hasFocus 
                    ? Colors.deepOrange.withOpacity(0.3) 
                    : null,
              ),
            ),
          ),
        ],
      ),
      body: Shortcuts(
        shortcuts: {
          LogicalKeySet(LogicalKeyboardKey.arrowDown): const NextFocusIntent(),
          LogicalKeySet(LogicalKeyboardKey.arrowUp): const PreviousFocusIntent(),
          LogicalKeySet(LogicalKeyboardKey.arrowLeft): const DirectionalFocusIntent(TraversalDirection.left),
          LogicalKeySet(LogicalKeyboardKey.arrowRight): const DirectionalFocusIntent(TraversalDirection.right),
          LogicalKeySet(LogicalKeyboardKey.select): const ActivateIntent(),
          LogicalKeySet(LogicalKeyboardKey.enter): const ActivateIntent(),
        },
        child: FocusTraversalGroup(
          policy: WidgetOrderTraversalPolicy(),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Focus(
                  focusNode: _searchFocusNode,
                  child: Builder(
                    builder: (context) {
                      final hasFocus = _searchFocusNode.hasFocus;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 100),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: hasFocus
                              ? Border.all(color: Colors.deepOrange, width: 2)
                              : null,
                        ),
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search...',
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              Expanded(
                child: ChannelList(
                  channels: _filteredList,
                  isMovie: _isShowingMovies,
                  onFavoriteToggled: _handleFavoriteToggle,
                  focusNode: _channelListFocusNode,
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
    _searchController.dispose();
    _searchFocusNode.dispose();
    _toggleListFocusNode.dispose();
    _favoritesFocusNode.dispose();
    _settingsFocusNode.dispose();
    _channelListFocusNode.dispose();
    super.dispose();
  }
}