import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<void> showTvKeyboard(
  BuildContext context,
  TextEditingController controller,
  String label, {
  bool obscure = false,
}) async {
  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => _TvKeyboardDialog(
      controller: controller,
      label: label,
      obscure: obscure,
    ),
  );
}

class _TvKeyboardDialog extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final bool obscure;
  const _TvKeyboardDialog({required this.controller, required this.label, required this.obscure});

  @override
  State<_TvKeyboardDialog> createState() => _TvKeyboardDialogState();
}

class _TvKeyboardDialogState extends State<_TvKeyboardDialog> {
  // Tüm satırlar — Space/Caps/OK da dahil
  static const _rows = [
    ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'],
    ['q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p'],
    ['a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', '-'],
    ['z', 'x', 'c', 'v', 'b', 'n', 'm', '.', '/', ':'],
    ['@', '_', '!', '?', '=', '&', '+', '#', '⌫', '✓'],
    ['⇧', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', '✅'], // Space + Caps + OK
  ];

  late String _text;
  bool _caps = false;
  int _row = 1;
  int _col = 0;
  bool _inBottom = false; // son satırda mı
  int _bottomCol = 1; // 0=Caps, 1=Space, 2=OK

  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _text = widget.controller.text;
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _pressGrid(String key) {
    setState(() {
      if (key == '⌫') {
        if (_text.isNotEmpty) _text = _text.substring(0, _text.length - 1);
      } else if (key == '✓') {
        widget.controller.text = _text;
        Navigator.of(context).pop();
      } else {
        _text += _caps ? key.toUpperCase() : key;
      }
    });
  }

  void _pressBottom(int col) {
    setState(() {
      if (col == 0) {
        _caps = !_caps;
      } else if (col == 1) {
        _text += ' ';
      } else {
        widget.controller.text = _text;
        Navigator.of(context).pop();
      }
    });
  }

  KeyEventResult _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.arrowUp) {
      setState(() {
        if (_inBottom) {
          _inBottom = false;
          _row = _rows.length - 2; // son grid satırı
        } else if (_row > 0) {
          _row--;
          _col = _col.clamp(0, _rows[_row].length - 1);
        }
      });
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowDown) {
      setState(() {
        if (!_inBottom && _row < _rows.length - 2) {
          _row++;
          _col = _col.clamp(0, _rows[_row].length - 1);
        } else if (!_inBottom) {
          _inBottom = true;
        }
      });
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowLeft) {
      setState(() {
        if (_inBottom) {
          if (_bottomCol > 0) _bottomCol--;
        } else if (_col > 0) {
          _col--;
        }
      });
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowRight) {
      setState(() {
        if (_inBottom) {
          if (_bottomCol < 2) _bottomCol++;
        } else if (_col < _rows[_row].length - 1) {
          _col++;
        }
      });
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      if (_inBottom) {
        _pressBottom(_bottomCol);
      } else {
        _pressGrid(_rows[_row][_col]);
      }
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.backspace) {
      setState(() {
        if (_text.isNotEmpty) _text = _text.substring(0, _text.length - 1);
      });
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.goBack) {
      Navigator.of(context).pop();
      return KeyEventResult.handled;
    }

    // Fiziksel klavye desteği
    final char = event.character;
    if (char != null && char.isNotEmpty && char.codeUnitAt(0) >= 32) {
      setState(() => _text += char);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final displayText = widget.obscure ? '•' * _text.length : _text;

    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: _handleKey,
      child: Dialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 8),

              // Metin gösterimi
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[850],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.deepOrange, width: 2),
                ),
                child: Text(
                  displayText.isEmpty ? ' ' : displayText,
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 14),

              // Grid satırları (ilk 5 satır)
              for (int ri = 0; ri < _rows.length - 1; ri++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_rows[ri].length, (ci) {
                      final k = _rows[ri][ci];
                      final selected = !_inBottom && _row == ri && _col == ci;
                      final isAction = k == '⌫' || k == '✓';
                      return GestureDetector(
                        onTap: () {
                          setState(() { _inBottom = false; _row = ri; _col = ci; });
                          _pressGrid(k);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 70),
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          width: isAction ? 44 : 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: selected ? Colors.deepOrange : (isAction ? Colors.grey[700] : Colors.grey[800]),
                            borderRadius: BorderRadius.circular(6),
                            border: selected ? Border.all(color: Colors.white, width: 2) : null,
                            boxShadow: selected ? [BoxShadow(color: Colors.deepOrange.withValues(alpha: 0.5), blurRadius: 6)] : null,
                          ),
                          child: Center(
                            child: Text(
                              _caps && k.length == 1 && k.contains(RegExp(r'[a-z]')) ? k.toUpperCase() : k,
                              style: TextStyle(
                                color: selected ? Colors.white : Colors.white70,
                                fontSize: isAction ? 15 : 13,
                                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),

              const SizedBox(height: 6),

              // Alt satır: Caps + Space + OK
              Row(
                children: List.generate(3, (i) {
                  final selected = _inBottom && _bottomCol == i;
                  final labels = [_caps ? 'ABC' : 'abc', 'SPACE', 'OK'];
                  final colors = [
                    _caps ? Colors.deepOrange : Colors.grey[800]!,
                    Colors.grey[800]!,
                    Colors.green[700]!,
                  ];
                  final flex = [1, 4, 1];
                  return Expanded(
                    flex: flex[i],
                    child: GestureDetector(
                      onTap: () {
                        setState(() { _inBottom = true; _bottomCol = i; });
                        _pressBottom(i);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 70),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        height: 36,
                        decoration: BoxDecoration(
                          color: selected ? colors[i].withValues(alpha: 1.0) : colors[i],
                          borderRadius: BorderRadius.circular(6),
                          border: selected ? Border.all(color: Colors.white, width: 2) : null,
                          boxShadow: selected ? [BoxShadow(color: Colors.white.withValues(alpha: 0.3), blurRadius: 6)] : null,
                        ),
                        child: Center(
                          child: Text(
                            labels[i],
                            style: TextStyle(
                              color: selected ? Colors.white : Colors.white70,
                              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
