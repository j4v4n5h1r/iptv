import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/xtream_service.dart';
import '../services/m3u_service.dart';
import '../services/app_settings.dart';
import '../services/app_localizations.dart';
import '../services/update_service.dart';
import '../models/channel.dart';
import 'player_screen.dart';
import 'series_screen.dart';
import 'settings_screen.dart';
import 'playlists_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  final String sessionType; // 'xtream' or 'm3u'

  const HomeScreen({super.key, this.sessionType = 'xtream'});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Live
  List<Category> _liveCategories = [];
  List<Channel> _liveChannels = [];
  String? _selectedLiveCatId;

  // VOD
  List<Category> _vodCategories = [];
  List<Channel> _vodChannels = [];
  String? _selectedVodCatId;

  // Series
  List<Category> _seriesCategories = [];
  List<Channel> _seriesList = [];
  String? _selectedSeriesCatId;

  // Favorites
  final Set<Channel> _favorites = {};

  // Watchlist (son izlenenler)
  final List<Channel> _watchlist = [];

  // EPG cache: streamId -> list
  final Map<String, List<EpgProgram>> _epgCache = {};

  // M3U mode: tüm kanallar + gruplar
  List<Channel> _m3uAllChannels = [];
  List<Category> _m3uGroups = [];
  String? _selectedM3uGroup;

  bool _loadingChannels = false;
  bool _loadingCategories = true;
  String _searchQuery = '';

  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  final _categoryListFocus = FocusNode();
  final _channelListFocus = FocusNode();

  bool get _isM3u => widget.sessionType == 'm3u';

  // M3U: tab 1=Favorites, 2=Recents — Xtream: tab 3=Favorites, 4=Recents
  bool get _isFavOrRecentsTab =>
      _isM3u ? (_tabIndex == 1 || _tabIndex == 2) : (_tabIndex == 3 || _tabIndex == 4);

  int _tabIndex = 0; // 0=Live/All, 1=Movies(xtream only), 2=Series(xtream only), 3=Favorites, 4=Recents

  @override
  void initState() {
    super.initState();
    final tabCount = _isM3u ? 3 : 5; // M3U: All, Favorites, Recents
    _tabController = TabController(length: tabCount, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _tabIndex = _tabController.index);
        _onTabChanged(_tabController.index);
      }
    });
    _searchController.addListener(() => setState(() => _searchQuery = _searchController.text.toLowerCase()));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
      _loadFavorites();
      _loadWatchlist();
      _loadInitial();
      _checkUpdate();
    });
  }

  Future<void> _checkUpdate() async {
    final info = await UpdateService.checkForUpdate();
    if (info == null || !mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text('Update Available  v${info.version}',
            style: const TextStyle(color: Colors.white)),
        content: Text(
          info.releaseNotes.isNotEmpty ? info.releaseNotes : 'A new version is available.',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
          maxLines: 6,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Later', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK', style: TextStyle(color: Colors.deepOrange)),
          ),
        ],
      ),
    );
  }

  Future<void> _loadInitial() async {
    if (_isM3u) {
      await _loadM3u();
      return;
    }
    final xtream = Provider.of<XtreamService>(context, listen: false);
    setState(() => _loadingCategories = true);
    final liveCats = await xtream.getLiveCategories();
    setState(() { _liveCategories = liveCats; _loadingCategories = false; });
    await _loadLiveChannels(null);
    _loadEpgForVisible();
  }

  Future<void> _loadM3u() async {
    setState(() { _loadingCategories = true; _loadingChannels = true; });
    final playlist = await M3uService.getActive();
    if (playlist == null) { setState(() { _loadingCategories = false; _loadingChannels = false; }); return; }
    final channels = await M3uService.fetchAndParse(playlist.url) ?? [];
    final groups = M3uService.getGroups(channels);
    if (mounted) {
      setState(() {
        _m3uAllChannels = channels;
        _m3uGroups = groups;
        _selectedM3uGroup = null;
        _loadingCategories = false;
        _loadingChannels = false;
      });
    }
  }

  Future<void> _onTabChanged(int index) async {
    _searchController.clear();
    if (_isM3u) return; // M3U'da lazy load yok
    final xtream = Provider.of<XtreamService>(context, listen: false);
    if (index == 1 && _vodCategories.isEmpty) {
      setState(() => _loadingCategories = true);
      final cats = await xtream.getVodCategories();
      setState(() { _vodCategories = cats; _loadingCategories = false; });
      _loadVodChannels(null);
    } else if (index == 2 && _seriesCategories.isEmpty) {
      setState(() => _loadingCategories = true);
      final cats = await xtream.getSeriesCategories();
      setState(() { _seriesCategories = cats; _loadingCategories = false; });
      _loadSeriesList(null);
    }
  }

  Future<void> _loadLiveChannels(String? catId) async {
    final xtream = Provider.of<XtreamService>(context, listen: false);
    setState(() { _loadingChannels = true; _selectedLiveCatId = catId; });
    final channels = await xtream.getLiveStreams(categoryId: catId);
    if (mounted) setState(() { _liveChannels = channels; _loadingChannels = false; });
  }

  Future<void> _loadVodChannels(String? catId) async {
    final xtream = Provider.of<XtreamService>(context, listen: false);
    setState(() { _loadingChannels = true; _selectedVodCatId = catId; });
    final channels = await xtream.getVodStreams(categoryId: catId);
    if (mounted) setState(() { _vodChannels = channels; _loadingChannels = false; });
  }

  Future<void> _loadSeriesList(String? catId) async {
    final xtream = Provider.of<XtreamService>(context, listen: false);
    setState(() { _loadingChannels = true; _selectedSeriesCatId = catId; });
    final list = await xtream.getSeriesList(categoryId: catId);
    if (mounted) setState(() { _seriesList = list; _loadingChannels = false; });
  }

  List<Channel> get _currentChannels {
    List<Channel> list;
    if (_isM3u) {
      if (_tabIndex == 1) {
        list = _favorites.toList();
      } else if (_tabIndex == 2) {
        list = _watchlist;
      } else {
        // M3U All — filtrele gruba göre
        list = _selectedM3uGroup == null
            ? _m3uAllChannels
            : _m3uAllChannels
                .where((c) => c.categoryName == _selectedM3uGroup)
                .toList();
      }
    } else {
      if (_tabIndex == 0) {
        list = _liveChannels;
      } else if (_tabIndex == 1) {
        list = _vodChannels;
      } else if (_tabIndex == 2) {
        list = _seriesList;
      } else if (_tabIndex == 3) {
        list = _favorites.toList();
      } else {
        list = _watchlist;
      }
    }
    if (_searchQuery.isEmpty) return list;
    return list.where((c) => c.name.toLowerCase().contains(_searchQuery)).toList();
  }

  List<Category> get _currentCategories {
    if (_isM3u) {
      return _tabIndex == 0 ? _m3uGroups : [];
    }
    if (_tabIndex == 0) return _liveCategories;
    if (_tabIndex == 1) return _vodCategories;
    if (_tabIndex == 2) return _seriesCategories;
    return [];
  }

  String? get _currentCatId {
    if (_isM3u) return _selectedM3uGroup;
    if (_tabIndex == 0) return _selectedLiveCatId;
    if (_tabIndex == 1) return _selectedVodCatId;
    return _selectedSeriesCatId;
  }

  void _onCategoryTap(String? catId) {
    if (catId != null) {
      final settings = Provider.of<AppSettings>(context, listen: false);
      if (settings.isCategoryLocked(catId)) {
        _showParentalPinDialog(() => _doSelectCategory(catId));
        return;
      }
    }
    _doSelectCategory(catId);
  }

  void _doSelectCategory(String? catId) {
    if (_isM3u) {
      setState(() => _selectedM3uGroup = catId);
      return;
    }
    if (_tabIndex == 0) {
      _loadLiveChannels(catId);
    } else if (_tabIndex == 1) {
      _loadVodChannels(catId);
    } else {
      _loadSeriesList(catId);
    }
  }

  void _showParentalPinDialog(VoidCallback onSuccess) {
    final settings = Provider.of<AppSettings>(context, listen: false);
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: const Text('Enter PIN', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: 4,
          autofocus: true,
          style: const TextStyle(color: Colors.white, fontSize: 22, letterSpacing: 8),
          decoration: const InputDecoration(
            counterText: '',
            hintText: '• • • •',
            hintStyle: TextStyle(color: Colors.white24),
            filled: true,
            fillColor: Color(0xFF0A0A0A),
            border: OutlineInputBorder(),
          ),
          onSubmitted: (v) {
            Navigator.pop(ctx);
            if (v == settings.parentalPin) {
              onSuccess();
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Wrong PIN')));
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (ctrl.text == settings.parentalPin) {
                onSuccess();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Wrong PIN')));
              }
            },
            child: const Text('OK', style: TextStyle(color: Colors.deepOrange))),
        ],
      ),
    );
  }

  void _onChannelTap(Channel channel) {
    // Series — bölüm browser'a yönlendir
    if (channel.streamType == 'series') {
      final xtream = Provider.of<XtreamService>(context, listen: false);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SeriesScreen(
            series: channel,
            serverUrl: xtream.serverUrl ?? '',
            username: xtream.username ?? '',
            password: xtream.password ?? '',
          ),
        ),
      );
      return;
    }
    if (channel.url.isEmpty) return;
    _addToWatchlist(channel);
    final list = _tabIndex == 2 ? _currentChannels : _currentChannels;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          channel: channel,
          channels: list,
          isMovie: channel.isMovie,
          onFavoriteToggled: _toggleFavorite,
        ),
      ),
    );
  }

  // --- EPG ---
  Future<void> _loadEpgForVisible() async {
    if (_tabIndex != 0) return;
    final xtream = Provider.of<XtreamService>(context, listen: false);
    final visible = _currentChannels.take(30).toList();
    for (final ch in visible) {
      if (ch.streamId == null) continue;
      if (_epgCache.containsKey(ch.streamId)) continue;
      final epg = await xtream.getShortEpg(ch.streamId!);
      if (mounted) setState(() => _epgCache[ch.streamId!] = epg);
    }
  }

  EpgProgram? _nowPlaying(Channel ch) {
    if (ch.streamId == null) return null;
    final list = _epgCache[ch.streamId] ?? [];
    try {
      return list.firstWhere((e) => e.isNow);
    } catch (_) {
      return list.isNotEmpty ? list.first : null;
    }
  }

  // --- Watchlist ---
  Future<void> _loadWatchlist() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('watchlist') ?? '[]';
    final List<dynamic> list = json.decode(raw);
    if (mounted) {
      setState(() {
        _watchlist.clear();
        _watchlist.addAll(list.map((e) => Channel.fromJson(e)));
      });
    }
  }

  Future<void> _saveWatchlist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('watchlist', json.encode(_watchlist.map((c) => c.toJson()).toList()));
  }

  void _addToWatchlist(Channel channel) {
    setState(() {
      _watchlist.removeWhere((c) => c.url == channel.url);
      _watchlist.insert(0, channel);
      if (_watchlist.length > 50) _watchlist.removeLast();
    });
    _saveWatchlist();
  }

  // --- Favorites ---
  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('favorites') ?? '[]';
    final List<dynamic> list = json.decode(raw);
    if (mounted) {
      setState(() {
        _favorites.clear();
        for (final item in list) {
          _favorites.add(Channel.fromJson(item));
        }
      });
    }
  }

  Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _favorites.map((c) => c.toJson()).toList();
    await prefs.setString('favorites', json.encode(list));
  }

  void _toggleFavorite(Channel channel) {
    setState(() {
      final exists = _favorites.any((c) => c.url == channel.url);
      if (exists) {
        _favorites.removeWhere((c) => c.url == channel.url);
      } else {
        _favorites.add(channel.copyWith(isFavorite: true));
      }
    });
    _saveFavorites();
  }

  void _logout() async {
    if (_isM3u) {
      await M3uService.clearActive();
    } else {
      final xtream = Provider.of<XtreamService>(context, listen: false);
      xtream.logout();
    }
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    _categoryListFocus.dispose();
    _channelListFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n(Provider.of<AppSettings>(context).language);
    return Scaffold(
      appBar: AppBar(
        leading: const Padding(
          padding: EdgeInsets.only(left: 8),
          child: Icon(Icons.connected_tv, color: Colors.deepOrange),
        ),
        title: Text(l10n.get('app_name'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.deepOrange,
          labelColor: Colors.deepOrange,
          unselectedLabelColor: Colors.white54,
          tabs: _isM3u
              ? [
                  Tab(icon: const Icon(Icons.tv), text: l10n.get('tab_channels')),
                  Tab(icon: const Icon(Icons.favorite), text: l10n.get('tab_favorites')),
                  Tab(icon: const Icon(Icons.history), text: l10n.get('tab_recents')),
                ]
              : [
                  Tab(icon: const Icon(Icons.live_tv), text: l10n.get('tab_live')),
                  Tab(icon: const Icon(Icons.movie), text: l10n.get('tab_movies')),
                  Tab(icon: const Icon(Icons.tv), text: l10n.get('tab_series')),
                  Tab(icon: const Icon(Icons.favorite), text: l10n.get('tab_favorites')),
                  Tab(icon: const Icon(Icons.history), text: l10n.get('tab_recents')),
                ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.playlist_play, color: Colors.white70),
            tooltip: 'Playlists',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PlaylistsScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white70),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ).then((_) => _loadWatchlist()),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white70),
            onPressed: _logout,
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
        child: Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Focus(
                focusNode: _searchFocus,
                child: Builder(builder: (ctx) {
                  final focused = _searchFocus.hasFocus;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 100),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: focused ? Border.all(color: Colors.deepOrange, width: 2) : null,
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: l10n.get('search'),
                        hintStyle: const TextStyle(color: Colors.white38),
                        prefixIcon: const Icon(Icons.search, color: Colors.white38),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  );
                }),
              ),
            ),
            // Body
            Expanded(
              child: _isFavOrRecentsTab
                  ? _buildChannelGrid(_currentChannels)
                  : Row(
                      children: [
                        // Left: Categories
                        SizedBox(
                          width: 170,
                          child: _loadingCategories
                              ? const Center(child: CircularProgressIndicator(color: Colors.deepOrange))
                              : _buildCategoryList(),
                        ),
                        Container(width: 1, color: Colors.white12),
                        // Right: Channels
                        Expanded(
                          child: _loadingChannels
                              ? const Center(child: CircularProgressIndicator(color: Colors.deepOrange))
                              : NotificationListener<ScrollEndNotification>(
                                  onNotification: (_) {
                                    if (_tabIndex == 0) _loadEpgForVisible();
                                    return false;
                                  },
                                  child: _buildChannelGrid(_currentChannels),
                                ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryList() {
    final cats = _currentCategories;
    return ListView.builder(
      itemCount: cats.length + 1,
      itemBuilder: (ctx, i) {
        if (i == 0) {
          return _buildCategoryItem(null, 'All', _currentCatId == null);
        }
        final cat = cats[i - 1];
        return _buildCategoryItem(cat.id, cat.name, _currentCatId == cat.id);
      },
    );
  }

  Widget _buildCategoryItem(String? id, String name, bool selected) {
    return InkWell(
      onTap: () => _onCategoryTap(id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.deepOrange.withValues(alpha: 0.2) : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: selected ? Colors.deepOrange : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Text(
          name,
          style: TextStyle(
            color: selected ? Colors.deepOrange : Colors.white70,
            fontSize: 13,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildChannelGrid(List<Channel> channels) {
    if (channels.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _tabIndex == 3 ? Icons.favorite_border : _tabIndex == 4 ? Icons.history : Icons.tv_off,
              color: Colors.white24, size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              _tabIndex == 3 ? 'No favorites yet' : _tabIndex == 4 ? 'No recent channels' : 'No content',
              style: const TextStyle(color: Colors.white38),
            ),
          ],
        ),
      );
    }

    // Live / Favorites / Recents → list view
    if (_tabIndex == 0 || _tabIndex == 3 || _tabIndex == 4) {
      return ListView.builder(
        itemCount: channels.length,
        itemBuilder: (ctx, i) => _buildLiveChannelTile(channels[i], i),
      );
    }
    // Series → grid with play icon overlay
    if (_tabIndex == 2) {
      return GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.6,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: channels.length,
        itemBuilder: (ctx, i) => _buildSeriesCard(channels[i]),
      );
    }
    // Movies → grid
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.65,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: channels.length,
      itemBuilder: (ctx, i) => _buildVodCard(channels[i]),
    );
  }

  Widget _buildLiveChannelTile(Channel channel, int index) {
    final isFav = _favorites.any((c) => c.url == channel.url);
    return InkWell(
      onTap: () => _onChannelTap(channel),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.white10)),
        ),
        child: Row(
          children: [
            // Channel number
            SizedBox(
              width: 36,
              child: Text(
                channel.num?.toString() ?? '${index + 1}',
                style: const TextStyle(color: Colors.white38, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 8),
            // Logo
            Container(
              width: 48,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(4),
              ),
              child: channel.logo != null && channel.logo!.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: CachedNetworkImage(
                        imageUrl: channel.logo!,
                        fit: BoxFit.contain,
                        placeholder: (_, __) => const Icon(Icons.live_tv, color: Colors.white24, size: 20),
                        errorWidget: (_, __, ___) => const Icon(Icons.live_tv, color: Colors.white24, size: 20),
                      ),
                    )
                  : const Icon(Icons.live_tv, color: Colors.white24, size: 20),
            ),
            const SizedBox(width: 12),
            // Name + EPG
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    channel.name,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Builder(builder: (_) {
                    final epg = _nowPlaying(channel);
                    if (epg != null) {
                      return Text(
                        '${epg.timeRange}  ${epg.title}',
                        style: const TextStyle(color: Colors.deepOrange, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      );
                    }
                    return const SizedBox.shrink();
                  }),
                ],
              ),
            ),
            // Favorite icon
            IconButton(
              icon: Icon(
                isFav ? Icons.favorite : Icons.favorite_border,
                color: isFav ? Colors.red : Colors.white24,
                size: 18,
              ),
              onPressed: () => _toggleFavorite(channel),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVodCard(Channel channel) {
    final isFav = _favorites.any((c) => c.url == channel.url);
    return InkWell(
      onTap: () => _onChannelTap(channel),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: channel.logo != null && channel.logo!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: channel.logo!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            color: Colors.grey[850],
                            child: const Icon(Icons.movie, color: Colors.white24, size: 40),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            color: Colors.grey[850],
                            child: const Icon(Icons.movie, color: Colors.white24, size: 40),
                          ),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[850],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.movie, color: Colors.white24, size: 40),
                        ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: () => _toggleFavorite(channel),
                    child: Icon(
                      isFav ? Icons.favorite : Icons.favorite_border,
                      color: isFav ? Colors.red : Colors.white54,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            channel.name,
            style: const TextStyle(color: Colors.white, fontSize: 11),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSeriesCard(Channel channel) {
    return InkWell(
      onTap: () => _onChannelTap(channel),
      borderRadius: BorderRadius.circular(6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  channel.logo != null && channel.logo!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: channel.logo!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            color: Colors.grey[850],
                            child: const Icon(Icons.tv, color: Colors.white24, size: 40),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            color: Colors.grey[850],
                            child: const Icon(Icons.tv, color: Colors.white24, size: 40),
                          ),
                        )
                      : Container(
                          color: Colors.grey[850],
                          child: const Icon(Icons.tv, color: Colors.white24, size: 40),
                        ),
                  // Play overlay
                  Center(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(6),
                      child: const Icon(Icons.play_arrow, color: Colors.white, size: 24),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            channel.name,
            style: const TextStyle(color: Colors.white, fontSize: 11),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
