class TvVideoCardData {
  const TvVideoCardData({
    required this.title,
    required this.cover,
    required this.bvid,
    required this.cid,
    required this.aid,
    required this.ownerName,
    required this.duration,
    this.subtitle,
    this.desc,
  });

  final String title;
  final String cover;
  final String bvid;
  final int cid;
  final int aid;
  final String ownerName;
  final int duration;
  final String? subtitle;
  final String? desc;
}
