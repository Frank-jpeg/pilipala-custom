import 'package:flutter/material.dart';
import 'package:pilipala/tv/models/tv_video_card_data.dart';
import 'package:pilipala/tv/widgets/tv_focusable_card.dart';

class TvPosterGrid extends StatelessWidget {
  const TvPosterGrid({
    super.key,
    required this.items,
    required this.onTap,
    this.initialAutofocus = false,
    this.crossAxisCount = 4,
    this.firstFocusNode,
  });

  final List<TvVideoCardData> items;
  final ValueChanged<TvVideoCardData> onTap;
  final bool initialAutofocus;
  final int crossAxisCount;
  final FocusNode? firstFocusNode;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 20,
        mainAxisSpacing: 28,
        childAspectRatio: 220 / 235,
      ),
      itemCount: items.length,
      itemBuilder: (BuildContext context, int index) {
        final TvVideoCardData item = items[index];
        return TvFocusableCard(
          data: item,
          autofocus: initialAutofocus && index == 0,
          focusNode: index == 0 ? firstFocusNode : null,
          onPressed: () => onTap(item),
        );
      },
    );
  }
}
