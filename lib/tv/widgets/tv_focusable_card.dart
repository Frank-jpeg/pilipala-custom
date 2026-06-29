import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pilipala/tv/models/tv_video_card_data.dart';
import 'package:pilipala/tv/utils/tv_formatters.dart';

class TvFocusableCard extends StatefulWidget {
  const TvFocusableCard({
    super.key,
    required this.data,
    required this.onPressed,
    this.width = 220,
    this.height = 164,
    this.autofocus = false,
    this.onFocused,
  });

  final TvVideoCardData data;
  final VoidCallback onPressed;
  final double width;
  final double height;
  final bool autofocus;
  final ValueChanged<bool>? onFocused;

  @override
  State<TvFocusableCard> createState() => _TvFocusableCardState();
}

class _TvFocusableCardState extends State<TvFocusableCard> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
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
        widget.onFocused?.call(value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: widget.width,
        transform: Matrix4.identity()..scale(_focused ? 1.05 : 1.0),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: widget.onPressed,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                height: widget.height,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _focused ? Colors.white : Colors.transparent,
                    width: 2,
                  ),
                  boxShadow: _focused
                      ? <BoxShadow>[
                          BoxShadow(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.35),
                            blurRadius: 22,
                          ),
                        ]
                      : null,
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    CachedNetworkImage(
                      imageUrl: widget.data.cover,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        color: const Color(0xFF1A2438),
                        alignment: Alignment.center,
                        child: const Icon(Icons.movie_outlined, size: 36),
                      ),
                    ),
                    Positioned(
                      left: 10,
                      right: 10,
                      bottom: 10,
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              widget.data.ownerName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            tvFormatDuration(widget.data.duration),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                widget.data.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: _focused ? FontWeight.w700 : FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              if ((widget.data.subtitle ?? '').isNotEmpty) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  widget.data.subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }
}
