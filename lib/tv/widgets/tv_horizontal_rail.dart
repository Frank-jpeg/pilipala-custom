import 'package:flutter/material.dart';
import 'package:pilipala/tv/models/tv_video_card_data.dart';
import 'package:pilipala/tv/widgets/tv_focusable_card.dart';

class TvHorizontalRail extends StatelessWidget {
  const TvHorizontalRail({
    super.key,
    required this.title,
    required this.items,
    required this.onTap,
    this.autofocusFirst = false,
  });

  final String title;
  final List<TvVideoCardData> items;
  final ValueChanged<TvVideoCardData> onTap;
  final bool autofocusFirst;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 250,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 20),
            itemBuilder: (BuildContext context, int index) {
              return TvFocusableCard(
                data: items[index],
                autofocus: autofocusFirst && index == 0,
                onPressed: () => onTap(items[index]),
              );
            },
          ),
        ),
      ],
    );
  }
}
