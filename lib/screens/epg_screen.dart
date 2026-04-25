import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/xtream_service.dart';
import '../models/channel.dart';
import 'player_screen.dart';

/// 7 günlük EPG grid + catch-up oynatma ekranı
class EpgScreen extends StatefulWidget {
  final Channel channel;

  const EpgScreen({super.key, required this.channel});

  @override
  State<EpgScreen> createState() => _EpgScreenState();
}

class _EpgScreenState extends State<EpgScreen> {
  List<EpgProgram> _programs = [];
  bool _loading = true;
  DateTime _selectedDay = DateTime.now();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.channel.streamId == null) {
      setState(() => _loading = false);
      return;
    }
    final xtream = Provider.of<XtreamService>(context, listen: false);
    final programs = await xtream.getFullEpg(widget.channel.streamId!);
    if (mounted) setState(() { _programs = programs; _loading = false; });
  }

  List<DateTime> get _days {
    final today = DateTime.now();
    return List.generate(7, (i) => today.subtract(Duration(days: 6 - i)));
  }

  List<EpgProgram> get _dayPrograms {
    return _programs.where((p) {
      return p.start.year == _selectedDay.year &&
          p.start.month == _selectedDay.month &&
          p.start.day == _selectedDay.day;
    }).toList();
  }

  void _playCatchup(EpgProgram program) {
    if (widget.channel.streamId == null) return;
    // XUI catch-up URL formatı
    final xtream = Provider.of<XtreamService>(context, listen: false);
    final startTs = program.start.millisecondsSinceEpoch ~/ 1000;
    final duration = program.end.difference(program.start).inSeconds;
    final url =
        '${xtream.serverUrl}/timeshift/${xtream.username}/${xtream.password}/$duration/$startTs/${widget.channel.streamId}.ts';

    final ch = widget.channel.copyWith(
      name: '${widget.channel.name} — ${program.title}',
      url: url,
      isMovie: true,
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          channel: ch,
          channels: [ch],
          isMovie: true,
          onFavoriteToggled: (_) {},
        ),
      ),
    );
  }

  String _dayLabel(DateTime d) {
    final now = DateTime.now();
    if (d.day == now.day) return 'Today';
    if (d.day == now.day - 1) return 'Yesterday';
    return '${d.day}/${d.month}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.channel.name,
                style: const TextStyle(color: Colors.white, fontSize: 15)),
            const Text('Programme Guide',
                style: TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Shortcuts(
        shortcuts: {
          LogicalKeySet(LogicalKeyboardKey.arrowDown): const NextFocusIntent(),
          LogicalKeySet(LogicalKeyboardKey.arrowUp): const PreviousFocusIntent(),
          LogicalKeySet(LogicalKeyboardKey.select): const ActivateIntent(),
          LogicalKeySet(LogicalKeyboardKey.enter): const ActivateIntent(),
        },
        child: Column(
          children: [
            // Day selector
            Container(
              height: 48,
              color: const Color(0xFF1A1A2E),
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                children: _days.map((d) {
                  final selected = d.day == _selectedDay.day &&
                      d.month == _selectedDay.month;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedDay = d),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: selected ? Colors.deepOrange : Colors.white12,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _dayLabel(d),
                        style: TextStyle(
                          color: selected ? Colors.white : Colors.white70,
                          fontSize: 13,
                          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            // Programme list
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.deepOrange))
                  : _dayPrograms.isEmpty
                      ? const Center(
                          child: Text('No programme data',
                              style: TextStyle(color: Colors.white38)))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _dayPrograms.length,
                          itemBuilder: (ctx, i) {
                            final p = _dayPrograms[i];
                            final isNow = p.isNow;
                            final isPast = p.end.isBefore(DateTime.now());
                            return FocusableActionDetector(
                              autofocus: i == 0,
                              actions: {ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) { if (isPast) _playCatchup(p); return null; })},
                              child: Builder(builder: (bctx) {
                                final focused = Focus.of(bctx).hasFocus;
                                return GestureDetector(
                              onTap: isPast ? () => _playCatchup(p) : null,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isNow
                                      ? Colors.deepOrange.withValues(alpha: 0.15)
                                      : focused ? Colors.white.withValues(alpha: 0.08) : Colors.transparent,
                                  border: Border(
                                      left: focused ? const BorderSide(color: Colors.white70, width: 3) : BorderSide.none,
                                      bottom: const BorderSide(color: Colors.white10)),
                                ),
                                child: Row(
                                  children: [
                                    // Time
                                    SizedBox(
                                      width: 90,
                                      child: Text(
                                        p.timeRange.split(' - ').first,
                                        style: TextStyle(
                                          color: isNow
                                              ? Colors.deepOrange
                                              : Colors.white54,
                                          fontSize: 13,
                                          fontWeight: isNow
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                    // Title + description
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(children: [
                                            if (isNow)
                                              Container(
                                                margin: const EdgeInsets.only(right: 6),
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.deepOrange,
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: const Text('NOW',
                                                    style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.bold)),
                                              ),
                                            Expanded(
                                              child: Text(
                                                p.title,
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 14,
                                                  fontWeight: isNow
                                                      ? FontWeight.bold
                                                      : FontWeight.normal,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ]),
                                          if (p.description.isNotEmpty)
                                            Text(
                                              p.description,
                                              style: const TextStyle(
                                                  color: Colors.white38,
                                                  fontSize: 12),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                        ],
                                      ),
                                    ),
                                    // Catch-up button
                                    if (isPast && widget.channel.tvArchive == true)
                                      const Padding(
                                        padding: EdgeInsets.only(left: 8),
                                        child: Icon(Icons.replay,
                                            color: Colors.deepOrange, size: 20),
                                      )
                                    else if (!isPast && !isNow)
                                      const Padding(
                                        padding: EdgeInsets.only(left: 8),
                                        child: Icon(Icons.schedule,
                                            color: Colors.white24, size: 18),
                                      ),
                                  ],
                                ),
                              ),
                                );
                              }),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
