import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TvNavItem {
  const TvNavItem({
    required this.label,
    required this.icon,
    required this.onTap,
    this.badge = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool badge;
}

class TvLeftNav extends StatefulWidget {
  const TvLeftNav({
    super.key,
    required this.items,
    required this.selectedIndex,
    this.focusNodes,
    this.onItemKey,
  });

  final List<TvNavItem> items;
  final int selectedIndex;
  final List<FocusNode>? focusNodes;
  final KeyEventResult Function(int index, LogicalKeyboardKey key)? onItemKey;

  @override
  State<TvLeftNav> createState() => _TvLeftNavState();
}

class _TvLeftNavState extends State<TvLeftNav> {
  int _focusedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 180,
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 24),
      decoration: BoxDecoration(
        color: const Color(0xFF10182A),
        border: Border(
          right: BorderSide(color: Colors.white.withOpacity(0.06)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            '云视听pilipala',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 28),
          Expanded(
            child: ListView.separated(
              itemCount: widget.items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (BuildContext context, int index) {
                final TvNavItem item = widget.items[index];
                final bool selected = widget.selectedIndex == index;
                final bool focused = _focusedIndex == index;
                final FocusNode? focusNode = widget.focusNodes != null &&
                        index < widget.focusNodes!.length
                    ? widget.focusNodes![index]
                    : null;
                return Focus(
                  focusNode: focusNode,
                  onKeyEvent: (FocusNode node, KeyEvent event) {
                    if (event is KeyDownEvent &&
                        (event.logicalKey == LogicalKeyboardKey.select ||
                            event.logicalKey == LogicalKeyboardKey.enter)) {
                      item.onTap();
                      return KeyEventResult.handled;
                    }
                    if (event is KeyDownEvent && widget.onItemKey != null) {
                      return widget.onItemKey!(index, event.logicalKey);
                    }
                    return KeyEventResult.ignored;
                  },
                  onFocusChange: (bool value) {
                    setState(() {
                      _focusedIndex = value
                          ? index
                          : (_focusedIndex == index ? -1 : _focusedIndex);
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    decoration: BoxDecoration(
                      color: selected || focused
                          ? colorScheme.primary
                              .withOpacity(selected ? 0.95 : 0.78)
                          : Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: focused ? Colors.white : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: item.onTap,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 14),
                        child: Row(
                          children: <Widget>[
                            Stack(
                              clipBehavior: Clip.none,
                              children: <Widget>[
                                Icon(item.icon, color: Colors.white, size: 22),
                                if (item.badge)
                                  const Positioned(
                                    right: -3,
                                    top: -3,
                                    child: SizedBox(
                                      width: 10,
                                      height: 10,
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                item.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
