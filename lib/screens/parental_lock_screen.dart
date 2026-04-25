import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/app_settings.dart';
import '../services/xtream_service.dart';
import '../models/channel.dart';

/// Hangi kategorilerin PIN korumalı olduğunu seçme ekranı.
class ParentalLockScreen extends StatefulWidget {
  const ParentalLockScreen({super.key});

  @override
  State<ParentalLockScreen> createState() => _ParentalLockScreenState();
}

class _ParentalLockScreenState extends State<ParentalLockScreen> {
  List<Category> _categories = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final xtream = Provider.of<XtreamService>(context, listen: false);
    final live = await xtream.getLiveCategories();
    final vod = await xtream.getVodCategories();
    final series = await xtream.getSeriesCategories();
    if (mounted) {
      setState(() {
        _categories = [...live, ...vod, ...series];
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Lock Categories', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.deepOrange))
          : _categories.isEmpty
              ? const Center(
                  child: Text('No categories found', style: TextStyle(color: Colors.white38)),
                )
              : Consumer<AppSettings>(
                  builder: (_, settings, __) => Shortcuts(
                    shortcuts: {
                      LogicalKeySet(LogicalKeyboardKey.arrowDown): const NextFocusIntent(),
                      LogicalKeySet(LogicalKeyboardKey.arrowUp): const PreviousFocusIntent(),
                      LogicalKeySet(LogicalKeyboardKey.select): const ActivateIntent(),
                      LogicalKeySet(LogicalKeyboardKey.enter): const ActivateIntent(),
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      itemCount: _categories.length,
                      itemBuilder: (ctx, i) {
                        final cat = _categories[i];
                        final isLocked = settings.lockedCategories.contains(cat.id);
                        final typeLabel = cat.type == 'live'
                            ? 'Live'
                            : cat.type == 'vod'
                                ? 'Movie'
                                : 'Series';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: FocusableActionDetector(
                            autofocus: i == 0,
                            actions: {ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => settings.toggleLockedCategory(cat.id))},
                            child: Builder(builder: (ctx) {
                              final focused = Focus.of(ctx).hasFocus;
                              return GestureDetector(
                                onTap: () => settings.toggleLockedCategory(cat.id),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 100),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: isLocked ? Colors.deepOrange.withValues(alpha: 0.12) : const Color(0xFF1A1A2E),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: focused ? Colors.white.withValues(alpha: 0.9) : (isLocked ? Colors.deepOrange : Colors.white12),
                                      width: focused ? 2 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        isLocked ? Icons.lock : Icons.lock_open,
                                        color: isLocked ? Colors.deepOrange : Colors.white38,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              cat.name,
                                              style: TextStyle(
                                                color: isLocked ? Colors.white : Colors.white70,
                                                fontSize: 14,
                                                fontWeight: isLocked ? FontWeight.w600 : FontWeight.normal,
                                              ),
                                            ),
                                            Text(
                                              typeLabel,
                                              style: const TextStyle(color: Colors.white38, fontSize: 11),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Switch(
                                        value: isLocked,
                                        activeThumbColor: Colors.deepOrange,
                                        onChanged: (_) => settings.toggleLockedCategory(cat.id),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ),
                        );
                      },
                    ),
                  ),
                ),
    );
  }
}
