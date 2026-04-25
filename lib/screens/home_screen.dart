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
import 'activation_screen.dart';
import '../services/device_service.dart';

class HomeScreen extends StatefulWidget {
  final String sessionType; // 'xtream' or 'm3u'
  final String initialTab;  // 'live', 'vod', 'series'

  const HomeScreen({super.key, this.sessionType = 'xtream', this.initialTab = 'live'});

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

  // Favorites — Channel objects for list, URL set for O(1) lookup
  final Set<Channel> _favorites = {};
  final Set<String> _favoriteUrls = {};

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
  bool _categoryChosen = false; // true once user picks a category (incl. All)
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
      _loadFavorites();
      _loadWatchlist();
      _loadInitial();
      _checkUpdate();
      // initialTab'a göre doğru tab'a git
      if (!_isM3u) {
        final tabIndex = widget.initialTab == 'vod' ? 1 : widget.initialTab == 'series' ? 2 : widget.initialTab == 'favorites' ? 3 : widget.initialTab == 'recents' ? 4 : 0;
        if (tabIndex != 0) {
          _tabController.animateTo(tabIndex);
        }
      }
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
            child: const Text('OK', style: TextStyle(color: const Color(0xFF60A5FA))),
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
    if (xtream.serverUrl == null) await xtream.loadSavedPlaylist();
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
    setState(() => _categoryChosen = false);
    if (_isM3u) return; // M3U'da lazy load yok
    final xtream = Provider.of<XtreamService>(context, listen: false);
    if (index == 1 && _vodCategories.isEmpty) {
      setState(() => _loadingCategories = true);
      final cats = await xtream.getVodCategories();
      setState(() { _vodCategories = cats; _loadingCategories = false; });
    } else if (index == 2 && _seriesCategories.isEmpty) {
      setState(() => _loadingCategories = true);
      final cats = await xtream.getSeriesCategories();
      setState(() { _seriesCategories = cats; _loadingCategories = false; });
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
      setState(() { _selectedM3uGroup = catId; _categoryChosen = catId != null || true; });
      return;
    }
    // catId == null means "go back to category page" — don't reload
    if (catId == null && _categoryChosen) {
      setState(() { _categoryChosen = false; });
      return;
    }
    setState(() => _categoryChosen = true);
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
            child: const Text('OK', style: TextStyle(color: const Color(0xFF60A5FA)))),
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
    // Film/series için channel list overlay gereksiz — boş liste geç, bellek tasarrufu
    final list = channel.isMovie ? <Channel>[] : _currentChannels;
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
        _favoriteUrls.clear();
        for (final item in list) {
          final ch = Channel.fromJson(item);
          _favorites.add(ch);
          _favoriteUrls.add(ch.url);
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
      if (_favoriteUrls.contains(channel.url)) {
        _favorites.removeWhere((c) => c.url == channel.url);
        _favoriteUrls.remove(channel.url);
      } else {
        _favorites.add(channel.copyWith(isFavorite: true));
        _favoriteUrls.add(channel.url);
      }
    });
    _saveFavorites();
  }

  void _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('xtream_server');
    await prefs.remove('xtream_username');
    await prefs.remove('xtream_password');
    await prefs.remove('m3u_active_url');
    if (_isM3u) {
      await M3uService.clearActive();
    } else {
      final xtream = Provider.of<XtreamService>(context, listen: false);
      xtream.logout();
    }
    final appKey = await DeviceService.getAppKey();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => ActivationScreen(appKey: appKey)),
        (route) => false,
      );
    }
  }

  void _showSearchKeyboard(BuildContext context) {
    final temp = _searchController.text;
    showDialog(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController(text: temp);
        const keys = [
          ['q','w','e','r','t','y','u','i','o','p'],
          ['a','s','d','f','g','h','j','k','l'],
          ['z','x','c','v','b','n','m'],
          ['123',' ','⌫'],
        ];
        const nums = [
          ['1','2','3','4','5','6','7','8','9','0'],
          ['-','_','.','/','@','#','!','?'],
          ['ABC',' ','⌫'],
        ];
        bool numMode = false;

        return StatefulBuilder(builder: (ctx, setSt) {
          final rows = numMode ? nums : keys;
          return Dialog(
            backgroundColor: const Color(0xFF1A0030),
            insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Input göstergesi
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE95420), width: 1.5),
                    ),
                    child: ValueListenableBuilder(
                      valueListenable: ctrl,
                      builder: (_, v, __) => Text(
                        ctrl.text.isEmpty ? 'Search...' : ctrl.text,
                        style: TextStyle(
                          color: ctrl.text.isEmpty ? Colors.white38 : Colors.white,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Tuşlar
                  ...rows.map((row) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Wrap(
                      spacing: 6,
                      children: row.map((k) {
                        final isWide = k == ' ' || k == '123' || k == 'ABC';
                        return SizedBox(
                          width: k == ' ' ? 120 : isWide ? 70 : 38,
                          height: 44,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF280048),
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            onPressed: () {
                              if (k == '⌫') {
                                if (ctrl.text.isNotEmpty) ctrl.text = ctrl.text.substring(0, ctrl.text.length - 1);
                              } else if (k == '123') {
                                setSt(() => numMode = true);
                              } else if (k == 'ABC') {
                                setSt(() => numMode = false);
                              } else {
                                ctrl.text += k;
                              }
                            },
                            child: Text(k == ' ' ? '⎵' : k, style: const TextStyle(fontSize: 15)),
                          ),
                        );
                      }).toList(),
                    ),
                  )),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.white54, side: const BorderSide(color: Colors.white24)),
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE95420), foregroundColor: Colors.white),
                          onPressed: () {
                            setState(() => _searchController.text = ctrl.text);
                            Navigator.pop(ctx);
                          },
                          child: const Text('Search'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
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
    final sectionTitle = widget.initialTab == 'vod'
        ? l10n.get('tab_movies')
        : widget.initialTab == 'series'
            ? l10n.get('tab_series')
            : l10n.get('tab_live');

    // Favorites / Recents tabs — go straight to content
    if (_isFavOrRecentsTab) {
      return _buildContentPage(sectionTitle, l10n, showBack: true, onBack: () => Navigator.pop(context));
    }

    // Category not yet chosen → show category grid fullscreen
    if (!_categoryChosen) {
      return _buildCategoryPage(sectionTitle, l10n);
    }

    // Category chosen → show content page, back goes to categories
    return _buildContentPage(sectionTitle, l10n, showBack: true, onBack: () {
      _doSelectCategory(null);
    });
  }

  Widget _buildCategoryPage(String sectionTitle, AppL10n l10n) {
    final cats = _currentCategories;
    return Scaffold(
      backgroundColor: const Color(0xFF0B1118),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1118),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(sectionTitle,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _loadingCategories
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFF5E6D0)))
          : SafeArea(
              child: GridView.builder(
                padding: const EdgeInsets.all(20),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  childAspectRatio: 2.8,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: cats.length + 1,
                itemBuilder: (ctx, i) {
                  final isAll = i == 0;
                  final name = isAll ? 'All' : cats[i - 1].name;
                  final id = isAll ? null : cats[i - 1].id;
                  return _buildCategoryGridItem(name, id, autofocus: i == 0);
                },
              ),
            ),
    );
  }

  Widget _buildCategoryGridItem(String name, String? id, {bool autofocus = false}) {
    return FocusableActionDetector(
      autofocus: autofocus,
      actions: {ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => _onCategoryTap(id))},
      child: Builder(builder: (ctx) {
        final focused = Focus.of(ctx).hasFocus;
        return GestureDetector(
          onTap: () => _onCategoryTap(id),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColorFiltered(
                  colorFilter: ColorFilter.matrix(focused
                      ? [0.85,0,0,0,0, 0,0.85,0,0,0, 0,0,0.85,0,0, 0,0,0,1,0]
                      : [0.45,0,0,0,0, 0,0.45,0,0,0, 0,0,0.45,0,0, 0,0,0,1,0]),
                  child: Image.asset('assets/wood-tile-warm.png', fit: BoxFit.cover),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: focused ? 0.10 : 0.40),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: focused ? Colors.white.withValues(alpha: 0.9) : Colors.white.withValues(alpha: 0.15),
                      width: focused ? 2.5 : 1,
                    ),
                  ),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        name,
                        style: TextStyle(
                          color: focused ? Colors.white : const Color(0xFFF5E6D0),
                          fontSize: 13,
                          fontWeight: focused ? FontWeight.bold : FontWeight.w500,
                          shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildContentPage(String sectionTitle, AppL10n l10n,
      {required bool showBack, required VoidCallback onBack}) {
    // find selected category name for breadcrumb
    final cats = _currentCategories;
    String? catName;
    if (_currentCatId != null) {
      try {
        catName = cats.firstWhere((c) => c.id == _currentCatId).name;
      } catch (_) {}
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) onBack();
      },
      child: Scaffold(
      backgroundColor: const Color(0xFF0B1118),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1118),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white70),
          onPressed: onBack,
        ),
        title: Row(
          children: [
            const Icon(Icons.home, color: Colors.white54, size: 18),
            const _BreadcrumbArrow(),
            Text(sectionTitle,
                style: const TextStyle(color: Colors.white54, fontSize: 14)),
            if (catName != null) ...[
              const _BreadcrumbArrow(),
              Text(catName,
                  style: const TextStyle(
                      color: Color(0xFFFFD700), fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton(
              icon: const Icon(Icons.search, color: Colors.white70),
              onPressed: () => _showSearchKeyboard(context),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Shortcuts(
          shortcuts: {
            LogicalKeySet(LogicalKeyboardKey.arrowDown):  const DirectionalFocusIntent(TraversalDirection.down),
            LogicalKeySet(LogicalKeyboardKey.arrowUp):    const DirectionalFocusIntent(TraversalDirection.up),
            LogicalKeySet(LogicalKeyboardKey.arrowLeft):  const DirectionalFocusIntent(TraversalDirection.left),
            LogicalKeySet(LogicalKeyboardKey.arrowRight): const DirectionalFocusIntent(TraversalDirection.right),
            LogicalKeySet(LogicalKeyboardKey.select): const ActivateIntent(),
            LogicalKeySet(LogicalKeyboardKey.enter):  const ActivateIntent(),
          },
          child: _loadingChannels
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFF5E6D0)))
              : NotificationListener<ScrollEndNotification>(
                  onNotification: (_) {
                    if (_tabIndex == 0) _loadEpgForVisible();
                    return false;
                  },
                  child: _buildChannelGrid(_currentChannels),
                ),
        ),
      ),
    ));
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
          color: selected ? const Color(0xFF60A5FA).withValues(alpha: 0.2) : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: selected ? const Color(0xFF60A5FA) : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Text(
          name,
          style: TextStyle(
            color: selected ? const Color(0xFF60A5FA) : Colors.white70,
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

    // All tabs → poster grid
    final bool isLive = _tabIndex == 0 || _tabIndex == 3 || _tabIndex == 4 || _isM3u;
    final bool isSeries = _tabIndex == 2;

    return FocusTraversalGroup(
      policy: ReadingOrderTraversalPolicy(),
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
        addAutomaticKeepAlives: false,
        addRepaintBoundaries: false,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: isLive ? 4 : 6,
          childAspectRatio: isLive ? 2.2 : 0.65,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: channels.length,
        itemBuilder: (ctx, i) {
          if (isLive) return _buildLiveChannelCard(channels[i], autofocus: i == 0);
          if (isSeries) return _buildSeriesCard(channels[i], autofocus: i == 0);
          return _buildVodCard(channels[i], autofocus: i == 0);
        },
      ),
    );
  }

  Widget _buildLiveChannelCard(Channel channel, {bool autofocus = false}) {
    final isFav = _favoriteUrls.contains(channel.url);
    return FocusableActionDetector(
      autofocus: autofocus,
      actions: {ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => _onChannelTap(channel))},
      child: Builder(builder: (ctx) {
        final focused = Focus.of(ctx).hasFocus;
        return GestureDetector(
          onTap: () => _onChannelTap(channel),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              color: focused ? Colors.white.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: focused ? const Color(0xFFE8C47A) : Colors.white.withValues(alpha: 0.10),
                width: focused ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 52,
                  child: channel.logo != null && channel.logo!.isNotEmpty
                      ? ClipRRect(
                          borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                          child: CachedNetworkImage(
                            imageUrl: channel.logo!,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => const Icon(Icons.live_tv, color: Colors.white24, size: 20),
                            errorWidget: (_, __, ___) => const Icon(Icons.live_tv, color: Colors.white24, size: 20),
                          ),
                        )
                      : const Icon(Icons.live_tv, color: Colors.white24, size: 20),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    channel.name,
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  isFav ? Icons.favorite : Icons.favorite_border,
                  color: isFav ? Colors.red : Colors.white24,
                  size: 14,
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildLiveChannelTile(Channel channel, int index) {
    final isFav = _favoriteUrls.contains(channel.url);
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
                        style: const TextStyle(color: const Color(0xFF60A5FA), fontSize: 11),
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

  Widget _buildVodCard(Channel channel, {bool autofocus = false}) {
    final isFav = _favoriteUrls.contains(channel.url);
    return FocusableActionDetector(
      autofocus: autofocus,
      actions: {ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => _onChannelTap(channel))},
      child: Builder(builder: (ctx) {
        final focused = Focus.of(ctx).hasFocus;
        return GestureDetector(
          onTap: () => _onChannelTap(channel),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: focused ? const Color(0xFFE8C47A) : Colors.transparent,
                width: 2,
              ),
            ),
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
                // Favorite ikonu — Enter/Select ile tıklanabilir
                Positioned(
                  top: 2,
                  right: 2,
                  child: Material(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(4),
                      onTap: () => _toggleFavorite(channel),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          isFav ? Icons.favorite : Icons.favorite_border,
                          color: isFav ? Colors.red : Colors.white70,
                          size: 18,
                        ),
                      ),
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
          ),
        );
      }),
    );
  }

  Widget _buildSeriesCard(Channel channel, {bool autofocus = false}) {
    return FocusableActionDetector(
      autofocus: autofocus,
      actions: {ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => _onChannelTap(channel))},
      child: Builder(builder: (ctx) {
        final focused = Focus.of(ctx).hasFocus;
        return GestureDetector(
          onTap: () => _onChannelTap(channel),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: focused ? const Color(0xFFE8C47A) : Colors.transparent,
                width: 2,
              ),
            ),
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
          ),
        );
      }),
    );
  }

}

class _BreadcrumbArrow extends StatelessWidget {
  const _BreadcrumbArrow();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: Icon(Icons.chevron_right, color: Colors.white38, size: 16),
    );
  }
}
