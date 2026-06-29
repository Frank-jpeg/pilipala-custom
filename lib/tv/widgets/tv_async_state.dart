import 'package:flutter/material.dart';

class TvAsyncState extends StatelessWidget {
  const TvAsyncState({
    super.key,
    this.loading = false,
    this.error,
    this.empty = false,
    this.emptyText = '暂无内容',
    required this.child,
  });

  final bool loading;
  final String? error;
  final bool empty;
  final String emptyText;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null) {
      return Center(
        child: Text(
          error!,
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
      );
    }
    if (empty) {
      return Center(
        child: Text(
          emptyText,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      );
    }
    return child;
  }
}
