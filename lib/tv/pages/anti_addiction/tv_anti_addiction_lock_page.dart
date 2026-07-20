import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pilipala/tv/controllers/tv_anti_addiction_controller.dart';
import 'package:pilipala/tv/widgets/tv_focusable_button.dart';

class TvAntiAddictionLockOverlay extends StatefulWidget {
  const TvAntiAddictionLockOverlay({super.key});

  @override
  State<TvAntiAddictionLockOverlay> createState() =>
      _TvAntiAddictionLockOverlayState();
}

class _TvAntiAddictionLockOverlayState
    extends State<TvAntiAddictionLockOverlay> {
  final TvAntiAddictionController controller =
      Get.find<TvAntiAddictionController>();
  final FocusNode _lockFocusNode = FocusNode(debugLabel: 'tvAntiAddictionLock');
  Worker? _lockWorker;
  bool _pinDialogShowing = false;

  @override
  void initState() {
    super.initState();
    // autofocus 在根 scope 已有焦点子节点时会被丢弃，导致锁屏抢不到焦点、拦不住遥控器。
    // 这里在锁定生效时主动把焦点移入锁屏，确保它真正接管 DPAD/OK 输入。
    _lockWorker = ever<bool>(controller.isLocked, (bool locked) {
      if (!locked) {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && controller.isLocked.value) {
          _lockFocusNode.requestFocus();
        }
      });
    });
  }

  @override
  void dispose() {
    _lockWorker?.dispose();
    _lockFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(
      () {
        if (!controller.isLocked.value) {
          return const SizedBox.shrink();
        }
        return Positioned.fill(
          child: Focus(
            focusNode: _lockFocusNode,
            autofocus: true,
            onKeyEvent: _handleLockKey,
            child: PopScope(
              canPop: false,
              child: Material(
                color: Colors.black.withOpacity(0.92),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Padding(
                      padding: const EdgeInsets.all(36),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Icon(
                            Icons.health_and_safety_outlined,
                            color: Color(0xFFFF7BAC),
                            size: 68,
                          ),
                          const SizedBox(height: 22),
                          Text(
                            controller.lockTitle,
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .displaySmall
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            controller.lockSubtitle,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 19,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 28),
                          _LockCountdown(controller: controller),
                          const SizedBox(height: 30),
                          TvFocusableButton(
                            autofocus: true,
                            icon: Icons.pin_outlined,
                            label: '家长 PIN 解锁',
                            onPressed: _showPinDialog,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  KeyEventResult _handleLockKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final LogicalKeyboardKey key = event.logicalKey;
    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.gameButtonA) {
      if (event is KeyDownEvent) {
        _showPinDialog();
      }
      return KeyEventResult.handled;
    }
    // 锁屏期间吞掉方向键 / 返回键等其它按键，禁止焦点遍历到锁屏背后的控件。
    return KeyEventResult.handled;
  }

  Future<void> _showPinDialog() async {
    if (_pinDialogShowing) {
      return;
    }
    // 锁屏 overlay 挂在 Navigator 之外，其 context 没有 Navigator 祖先，
    // 直接用它调 showDialog 会崩；改用 GetMaterialApp 的导航 context。
    final BuildContext? dialogContext = Get.overlayContext ?? Get.context;
    if (dialogContext == null) {
      return;
    }
    _pinDialogShowing = true;
    try {
      final String? pin = await showTvPinDialog(
        dialogContext,
        title: '家长 PIN 解锁',
        confirmLabel: '解锁',
      );
      if (pin == null) {
        return;
      }
      if (!controller.verifyPin(pin)) {
        Get.snackbar('PIN 错误', '请重新输入 4 位家长 PIN');
        return;
      }
      await controller.unlockByPin();
    } finally {
      _pinDialogShowing = false;
      // PIN 错误或取消后仍处于锁定，把焦点收回锁屏。
      if (mounted && controller.isLocked.value) {
        _lockFocusNode.requestFocus();
      }
    }
  }
}

class _LockCountdown extends StatelessWidget {
  const _LockCountdown({required this.controller});

  final TvAntiAddictionController controller;

  @override
  Widget build(BuildContext context) {
    // 之前这些 Rx 读取在外层 Obx 闭包之外，休息倒计时不会逐秒刷新；用自己的 Obx 订阅。
    return Obx(() {
      if (controller.lockReason.value == TvAntiAddictionLockReason.dailyLimit) {
        return const Text(
          '今日已锁定',
          style: TextStyle(
            color: Color(0xFFFF7BAC),
            fontSize: 30,
            fontWeight: FontWeight.w900,
          ),
        );
      }
      final int seconds = controller.remainingLockSeconds.value;
      return Text(
        _formatDuration(seconds),
        style: const TextStyle(
          color: Color(0xFFFF7BAC),
          fontSize: 44,
          fontWeight: FontWeight.w900,
          letterSpacing: 1,
        ),
      );
    });
  }

  String _formatDuration(int seconds) {
    final int minutes = seconds ~/ 60;
    final int remainSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:'
        '${remainSeconds.toString().padLeft(2, '0')}';
  }
}

Future<String?> showTvPinDialog(
  BuildContext context, {
  required String title,
  String confirmLabel = '确认',
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return _TvPinDialog(title: title, confirmLabel: confirmLabel);
    },
  );
}

Future<int?> showTvNumberInputDialog(
  BuildContext context, {
  required String title,
  required int initialValue,
  required int minValue,
  required int maxValue,
  required String unit,
}) {
  return showDialog<int>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return _TvNumberInputDialog(
        title: title,
        initialValue: initialValue,
        minValue: minValue,
        maxValue: maxValue,
        unit: unit,
      );
    },
  );
}

class _TvNumberInputDialog extends StatefulWidget {
  const _TvNumberInputDialog({
    required this.title,
    required this.initialValue,
    required this.minValue,
    required this.maxValue,
    required this.unit,
  });

  final String title;
  final int initialValue;
  final int minValue;
  final int maxValue;
  final String unit;

  @override
  State<_TvNumberInputDialog> createState() => _TvNumberInputDialogState();
}

class _TvNumberInputDialogState extends State<_TvNumberInputDialog> {
  late String _digits;
  bool _replaceOnNextDigit = true;
  String? _error;

  int get _maxDigits => widget.maxValue.toString().length;

  @override
  void initState() {
    super.initState();
    _digits = widget.initialValue.toString();
  }

  void _appendDigit(String digit) {
    final String next = _replaceOnNextDigit ? digit : '$_digits$digit';
    if (next.length > _maxDigits) {
      return;
    }
    setState(() {
      _digits = next;
      _replaceOnNextDigit = false;
      _error = null;
    });
  }

  void _deleteDigit() {
    if (_digits.isEmpty) {
      return;
    }
    setState(() {
      _digits = _digits.substring(0, _digits.length - 1);
      _replaceOnNextDigit = false;
      _error = null;
    });
  }

  void _clear() {
    setState(() {
      _digits = '';
      _replaceOnNextDigit = false;
      _error = null;
    });
  }

  void _submit() {
    final int? value = int.tryParse(_digits);
    if (value == null || value < widget.minValue || value > widget.maxValue) {
      setState(() {
        _error = '请输入 ${widget.minValue}–${widget.maxValue} ${widget.unit}';
      });
      return;
    }
    Navigator.of(context).pop(value);
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    final LogicalKeyboardKey key = event.logicalKey;
    final String label = key.keyLabel;
    if (label.length == 1 && RegExp(r'\d').hasMatch(label)) {
      _appendDigit(label);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.backspace ||
        key == LogicalKeyboardKey.delete) {
      _deleteDigit();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.browserBack) {
      Navigator.of(context).pop();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF121A2B),
      title: Text(widget.title),
      content: Focus(
        onKeyEvent: _handleKey,
        child: SizedBox(
          width: 640,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        '${widget.minValue}–${widget.maxValue} ${widget.unit}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        _digits.isEmpty ? '0' : _digits,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 46,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _error ?? '方向键选择右侧数字，OK 输入。',
                        style: TextStyle(
                          color: _error == null
                              ? Colors.white54
                              : const Color(0xFFFF6B78),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 28),
              _PinNumberPad(
                onDigit: _appendDigit,
                onDelete: _deleteDigit,
                onClear: _clear,
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TvFocusableButton(
          icon: Icons.close,
          label: '取消',
          onPressed: () => Navigator.of(context).pop(),
        ),
        TvFocusableButton(
          icon: Icons.check,
          label: '保存',
          onPressed: _submit,
        ),
      ],
    );
  }
}

class _TvPinDialog extends StatefulWidget {
  const _TvPinDialog({
    required this.title,
    required this.confirmLabel,
  });

  final String title;
  final String confirmLabel;

  @override
  State<_TvPinDialog> createState() => _TvPinDialogState();
}

class _TvPinDialogState extends State<_TvPinDialog> {
  String _pin = '';

  void _appendDigit(String digit) {
    if (_pin.length >= 4) {
      return;
    }
    setState(() {
      _pin = '$_pin$digit';
    });
  }

  void _deleteDigit() {
    if (_pin.isEmpty) {
      return;
    }
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
    });
  }

  void _clearPin() {
    if (_pin.isEmpty) {
      return;
    }
    setState(() {
      _pin = '';
    });
  }

  void _submit() {
    if (_pin.length == 4) {
      Navigator.of(context).pop(_pin);
    }
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    final LogicalKeyboardKey key = event.logicalKey;
    final String label = key.keyLabel;
    if (label.length == 1 && RegExp(r'\d').hasMatch(label)) {
      _appendDigit(label);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.backspace ||
        key == LogicalKeyboardKey.delete) {
      _deleteDigit();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.browserBack) {
      Navigator.of(context).pop();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF121A2B),
      title: Text(widget.title),
      content: Focus(
        onKeyEvent: _handleKey,
        child: SizedBox(
          width: 640,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(child: _PinPreview(pinLength: _pin.length)),
              const SizedBox(width: 28),
              _PinNumberPad(
                onDigit: _appendDigit,
                onDelete: _deleteDigit,
                onClear: _clearPin,
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TvFocusableButton(
          icon: Icons.close,
          label: '取消',
          onPressed: () => Navigator.of(context).pop(),
        ),
        TvFocusableButton(
          icon: Icons.check,
          label: widget.confirmLabel,
          onPressed: _submit,
        ),
      ],
    );
  }
}

class _PinPreview extends StatelessWidget {
  const _PinPreview({required this.pinLength});

  final int pinLength;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Text(
            '家长 PIN',
            style: TextStyle(color: Colors.white70, fontSize: 17),
          ),
          const SizedBox(height: 16),
          Row(
            children: List<Widget>.generate(
              4,
              (int index) => Container(
                width: 46,
                height: 56,
                margin: EdgeInsets.only(right: index == 3 ? 0 : 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.22),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: index < pinLength
                        ? const Color(0xFFFF7BAC)
                        : Colors.white24,
                  ),
                ),
                child: Text(
                  index < pinLength ? '•' : '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            '方向键选择右侧数字，OK 输入。',
            style: TextStyle(color: Colors.white54, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _PinNumberPad extends StatelessWidget {
  const _PinNumberPad({
    required this.onDigit,
    required this.onDelete,
    required this.onClear,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onDelete;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return FocusTraversalGroup(
      child: SizedBox(
        width: 276,
        child: Column(
          children: <Widget>[
            for (final List<_PinPadKey> row in const <List<_PinPadKey>>[
              <_PinPadKey>[
                _PinPadKey('1', '1'),
                _PinPadKey('2', '2'),
                _PinPadKey('3', '3'),
              ],
              <_PinPadKey>[
                _PinPadKey('4', '4'),
                _PinPadKey('5', '5'),
                _PinPadKey('6', '6'),
              ],
              <_PinPadKey>[
                _PinPadKey('7', '7'),
                _PinPadKey('8', '8'),
                _PinPadKey('9', '9'),
              ],
              <_PinPadKey>[
                _PinPadKey('清空', 'clear'),
                _PinPadKey('0', '0'),
                _PinPadKey('删除', 'delete'),
              ],
            ]) ...<Widget>[
              Row(
                children: <Widget>[
                  for (final _PinPadKey item in row) ...<Widget>[
                    Expanded(
                      child: _PinPadButton(
                        autofocus: item.value == '1',
                        label: item.label,
                        onPressed: () {
                          switch (item.value) {
                            case 'clear':
                              onClear();
                              break;
                            case 'delete':
                              onDelete();
                              break;
                            default:
                              onDigit(item.value);
                          }
                        },
                      ),
                    ),
                    if (item != row.last) const SizedBox(width: 10),
                  ],
                ],
              ),
              if (row !=
                  const <_PinPadKey>[
                    _PinPadKey('清空', 'clear'),
                    _PinPadKey('0', '0'),
                    _PinPadKey('删除', 'delete'),
                  ])
                const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

class _PinPadKey {
  const _PinPadKey(this.label, this.value);

  final String label;
  final String value;
}

class _PinPadButton extends StatefulWidget {
  const _PinPadButton({
    required this.label,
    required this.onPressed,
    this.autofocus = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool autofocus;

  @override
  State<_PinPadButton> createState() => _PinPadButtonState();
}

class _PinPadButtonState extends State<_PinPadButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Focus(
      autofocus: widget.autofocus,
      onKeyEvent: (FocusNode node, KeyEvent event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter)) {
          widget.onPressed();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      onFocusChange: (bool value) {
        setState(() {
          _focused = value;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: 62,
        alignment: Alignment.center,
        transform: Matrix4.identity()..scale(_focused ? 1.04 : 1.0),
        decoration: BoxDecoration(
          color: _focused ? colorScheme.primary : colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _focused ? Colors.white : Colors.white12,
            width: _focused ? 2 : 1,
          ),
          boxShadow: _focused
              ? <BoxShadow>[
                  BoxShadow(
                    color: colorScheme.primary.withOpacity(0.4),
                    blurRadius: 18,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: widget.onPressed,
          child: Center(
            child: Text(
              widget.label,
              style: TextStyle(
                color: _focused ? Colors.white : colorScheme.onSurface,
                fontSize: widget.label.length == 1 ? 28 : 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 通用 TV 选项选择对话框：方向键在选项间移动，OK 选中并返回该值，返回键取消返回 null。
Future<int?> showTvOptionDialog({
  required BuildContext context,
  required String title,
  required List<int> options,
  required int current,
  required String Function(int value) labelBuilder,
}) {
  return showDialog<int>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return _TvOptionDialog(
        title: title,
        options: options,
        current: current,
        labelBuilder: labelBuilder,
      );
    },
  );
}

class _TvOptionDialog extends StatelessWidget {
  const _TvOptionDialog({
    required this.title,
    required this.options,
    required this.current,
    required this.labelBuilder,
  });

  final String title;
  final List<int> options;
  final int current;
  final String Function(int value) labelBuilder;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF121A2B),
      title: Text(title),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (final int option in options) ...<Widget>[
              Align(
                alignment: Alignment.centerLeft,
                child: TvFocusableButton(
                  autofocus: option == current,
                  icon: option == current
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  label: labelBuilder(option),
                  onPressed: () => Navigator.of(context).pop(option),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TvFocusableButton(
          icon: Icons.close,
          label: '取消',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
