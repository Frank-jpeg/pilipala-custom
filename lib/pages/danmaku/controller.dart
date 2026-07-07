import 'package:pilipala/http/danmaku.dart';
import 'package:pilipala/models/danmaku/dm.pb.dart';

class PlDanmakuController {
  PlDanmakuController(this.cid, this.type);
  final int cid;
  final String type;
  Map<int, List<DanmakuElem>> dmSegMap = {};
  // 已请求的段落标记
  List<bool> requestedSeg = [];

  bool get initiated => requestedSeg.isNotEmpty;

  static int segmentLength = 60 * 6 * 1000;

  void initiate(int videoDuration, int progress) {
    if (requestedSeg.isEmpty) {
      final int currentSegment = calcSegment(progress);
      final int segCount = ((videoDuration / segmentLength).ceil())
          .clamp(currentSegment + 1, 999);
      requestedSeg = List<bool>.generate(segCount, (index) => false);
    }
    try {
      queryDanmaku(calcSegment(progress));
    } catch (e) {
      print(e);
    }
  }

  void dispose() {
    dmSegMap.clear();
    requestedSeg.clear();
  }

  int calcSegment(int progress) {
    return progress ~/ segmentLength;
  }

  void queryDanmaku(int segmentIndex) async {
    if (segmentIndex < 0) {
      return;
    }
    if (requestedSeg.length <= segmentIndex) {
      requestedSeg.addAll(
        List<bool>.generate(
            segmentIndex - requestedSeg.length + 1, (_) => false),
      );
    }
    if (!requestedSeg[segmentIndex]) {
      requestedSeg[segmentIndex] = true;
      final DmSegMobileReply result = await DanmakaHttp.queryDanmaku(
          cid: cid, segmentIndex: segmentIndex + 1);
      if (result.elems.isNotEmpty) {
        for (var element in result.elems) {
          int pos = element.progress ~/ 100; //每0.1秒存储一次
          if (dmSegMap[pos] == null) {
            dmSegMap[pos] = [];
          }
          dmSegMap[pos]!.add(element);
        }
      }
    }
  }

  List<DanmakuElem>? getCurrentDanmaku(int progress) {
    int segmentIndex = calcSegment(progress);
    if (requestedSeg.isEmpty || requestedSeg.length <= segmentIndex) {
      queryDanmaku(segmentIndex);
      return dmSegMap[progress ~/ 100];
    }
    if (!requestedSeg[segmentIndex]) {
      queryDanmaku(segmentIndex);
    }
    return dmSegMap[progress ~/ 100];
  }
}
