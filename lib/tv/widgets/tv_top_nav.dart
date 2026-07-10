import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TvTopNavItem {
  const TvTopNavItem({
    required this.label,
    required this.onTap,
    this.icon,
  });

  final String label;
  final IconData? icon;
  final VoidCallback onTap;
}

class TvTopNav extends StatefulWidget {
  const TvTopNav({
    super.key,
    required this.shortcuts,
    required this.tabs,
    required this.selectedTabIndex,
    required this.shortcutFocusNodes,
    required this.tabFocusNodes,
    required this.onShortcutKey,
    required this.onTabKey,
  });

  final List<TvTopNavItem> shortcuts;
  final List<TvTopNavItem> tabs;
  final int selectedTabIndex;
  final List<FocusNode> shortcutFocusNodes;
  final List<FocusNode> tabFocusNodes;
  final KeyEventResult Function(int index, LogicalKeyboardKey key)
      onShortcutKey;
  final KeyEventResult Function(int index, LogicalKeyboardKey key) onTabKey;

  @override
  State<TvTopNav> createState() => _TvTopNavState();
}

class _TvTopNavState extends State<TvTopNav> {
  int _focusedShortcutIndex = -1;
  int _focusedTabIndex = -1;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 90,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(26, 5, 26, 3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              height: 38,
              child: Row(
                children: List<Widget>.generate(
                  widget.shortcuts.length,
                  (int index) => Padding(
                    padding: EdgeInsets.only(
                      right: index == widget.shortcuts.length - 1 ? 0 : 10,
                    ),
                    child: _ShortcutButton(
                      item: widget.shortcuts[index],
                      focusNode: widget.shortcutFocusNodes[index],
                      focused: _focusedShortcutIndex == index,
                      onKey: (LogicalKeyboardKey key) =>
                          widget.onShortcutKey(index, key),
                      onFocusChange: (bool focused) {
                        setState(() {
                          _focusedShortcutIndex = focused
                              ? index
                              : (_focusedShortcutIndex == index
                                  ? -1
                                  : _focusedShortcutIndex);
                        });
                      },
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 38,
              child: Row(
                children: List<Widget>.generate(
                  widget.tabs.length,
                  (int index) => Padding(
                    padding: EdgeInsets.only(
                      right: index == widget.tabs.length - 1 ? 0 : 28,
                    ),
                    child: _TabButton(
                      item: widget.tabs[index],
                      focusNode: widget.tabFocusNodes[index],
                      selected: widget.selectedTabIndex == index,
                      focused: _focusedTabIndex == index,
                      onKey: (LogicalKeyboardKey key) =>
                          widget.onTabKey(index, key),
                      onFocusChange: (bool focused) {
                        setState(() {
                          _focusedTabIndex = focused
                              ? index
                              : (_focusedTabIndex == index
                                  ? -1
                                  : _focusedTabIndex);
                        });
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShortcutButton extends StatelessWidget {
  const _ShortcutButton({
    required this.item,
    required this.focusNode,
    required this.focused,
    required this.onKey,
    required this.onFocusChange,
  });

  final TvTopNavItem item;
  final FocusNode focusNode;
  final bool focused;
  final KeyEventResult Function(LogicalKeyboardKey key) onKey;
  final ValueChanged<bool> onFocusChange;

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: focusNode,
      onFocusChange: onFocusChange,
      onKeyEvent: (FocusNode node, KeyEvent event) {
        if (event is! KeyDownEvent) {
          return KeyEventResult.ignored;
        }
        if (event.logicalKey == LogicalKeyboardKey.select ||
            event.logicalKey == LogicalKeyboardKey.enter) {
          item.onTap();
          return KeyEventResult.handled;
        }
        return onKey(event.logicalKey);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: 36,
        constraints: const BoxConstraints(minWidth: 92, maxWidth: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: focused
              ? Colors.white.withOpacity(0.18)
              : Colors.white.withOpacity(0.09),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: focused ? Colors.white : Colors.white.withOpacity(0.08),
            width: focused ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: item.onTap,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (item.icon != null) ...<Widget>[
                Icon(item.icon, color: Colors.white, size: 18),
                const SizedBox(width: 7),
              ],
              Flexible(
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.item,
    required this.focusNode,
    required this.selected,
    required this.focused,
    required this.onKey,
    required this.onFocusChange,
  });

  final TvTopNavItem item;
  final FocusNode focusNode;
  final bool selected;
  final bool focused;
  final KeyEventResult Function(LogicalKeyboardKey key) onKey;
  final ValueChanged<bool> onFocusChange;

  @override
  Widget build(BuildContext context) {
    const Color accent = Color(0xFFFF5C93);
    return Focus(
      focusNode: focusNode,
      onFocusChange: onFocusChange,
      onKeyEvent: (FocusNode node, KeyEvent event) {
        if (event is! KeyDownEvent) {
          return KeyEventResult.ignored;
        }
        if (event.logicalKey == LogicalKeyboardKey.select ||
            event.logicalKey == LogicalKeyboardKey.enter) {
          item.onTap();
          return KeyEventResult.handled;
        }
        return onKey(event.logicalKey);
      },
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: 38,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 120),
                style: TextStyle(
                  color: selected
                      ? accent
                      : (focused ? Colors.white : Colors.white70),
                  fontSize: 18,
                  fontWeight:
                      selected || focused ? FontWeight.w800 : FontWeight.w600,
                ),
                child: Text(item.label),
              ),
              const SizedBox(height: 3),
              AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: selected ? 28 : (focused ? 16 : 0),
                height: 3,
                decoration: BoxDecoration(
                  color: selected ? accent : Colors.white70,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
