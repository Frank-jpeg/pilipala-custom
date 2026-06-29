import 'package:pilipala/models/home/rcmd/result.dart';
import 'package:pilipala/models/model_hot_video_item.dart';
import 'package:pilipala/models/search/result.dart';
import 'package:pilipala/models/user/fav_detail.dart';
import 'package:pilipala/models/user/history.dart';
import 'package:pilipala/models/video/later.dart';
import 'package:pilipala/tv/models/tv_video_card_data.dart';

class TvVideoMapper {
  static TvVideoCardData fromRcmd(RecVideoItemAppModel item) {
    return TvVideoCardData(
      title: item.title ?? '未命名视频',
      cover: item.pic ?? '',
      bvid: item.bvid ?? '',
      cid: item.cid ?? 0,
      aid: item.aid ?? 0,
      ownerName: item.owner?.name ?? '未知UP',
      duration: item.duration ?? 0,
      subtitle: item.rcmdReason,
    );
  }

  static TvVideoCardData fromSearch(SearchVideoItemModel item) {
    return TvVideoCardData(
      title: item.title ?? '未命名视频',
      cover: item.pic ?? '',
      bvid: item.bvid ?? '',
      cid: item.cid ?? 0,
      aid: item.aid ?? 0,
      ownerName: item.owner?.name ?? '未知UP',
      duration: item.duration ?? 0,
      subtitle: item.description,
      desc: item.description,
    );
  }

  static TvVideoCardData fromHistory(HisListItem item) {
    return TvVideoCardData(
      title: item.title ?? '未命名视频',
      cover: item.cover ?? '',
      bvid: item.history?.bvid ?? '',
      cid: item.history?.cid ?? 0,
      aid: item.history?.oid ?? 0,
      ownerName: item.authorName ?? '未知UP',
      duration: item.duration ?? 0,
      subtitle: item.showTitle ?? item.tagName,
      desc: item.longTitle,
    );
  }

  static TvVideoCardData fromWatchLater(HotVideoItemModel item) {
    return TvVideoCardData(
      title: item.title ?? '未命名视频',
      cover: item.pic ?? '',
      bvid: item.bvid ?? '',
      cid: item.cid ?? 0,
      aid: item.aid ?? 0,
      ownerName: item.owner?.name ?? '未知UP',
      duration: item.duration ?? 0,
      subtitle: item.rcmdReason?.content,
      desc: item.desc,
    );
  }

  static TvVideoCardData fromFavDetail(FavDetailItemData item) {
    return TvVideoCardData(
      title: item.title ?? '未命名视频',
      cover: item.pic ?? '',
      bvid: item.bvid ?? item.bvId ?? '',
      cid: item.cid ?? 0,
      aid: item.id ?? 0,
      ownerName: item.owner?.name ?? '未知UP',
      duration: item.duration ?? 0,
      subtitle: item.intro,
      desc: item.intro,
    );
  }

  static TvVideoCardData fromMedia(MediaVideoItemModel item) {
    return TvVideoCardData(
      title: item.title ?? '未命名视频',
      cover: item.cover ?? '',
      bvid: item.bvid ?? '',
      cid: item.cid ?? 0,
      aid: item.aid ?? 0,
      ownerName: item.upper?.name ?? '未知UP',
      duration: item.duration ?? 0,
      subtitle: item.intro,
      desc: item.intro,
    );
  }
}
