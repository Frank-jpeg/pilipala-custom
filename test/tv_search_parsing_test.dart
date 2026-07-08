import 'package:flutter_test/flutter_test.dart';
import 'package:pilipala/http/search.dart';

void main() {
  test('TV search parser accepts known response shapes and de-duplicates', () {
    final items = SearchHttp.debugParseTvSearchItems(<String, dynamic>{
      'ugc': <Map<String, dynamic>>[
        <String, dynamic>{
          'aid': 170001,
          'cid': 270001,
          'title': 'ugc item',
          'cover': '//i0.hdslb.com/ugc.jpg',
          'upper': <String, dynamic>{'name': 'up-a'},
        },
        <String, dynamic>{
          'aid': 170001,
          'cid': 270009,
          'title': 'duplicate item',
        },
      ],
      'resultall': <String, dynamic>{
        'tvugc': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 170002,
            'title': 'resultall item',
            'auto_play': <String, dynamic>{
              'cid_list': <Map<String, dynamic>>[
                <String, dynamic>{'cid': 270002, 'duration': 31},
              ],
            },
          },
        ],
      },
      'result_v2': <Map<String, dynamic>>[
        <String, dynamic>{
          'list': <Map<String, dynamic>>[
            <String, dynamic>{
              'player_args': <String, dynamic>{
                'aid': 170003,
                'cid': 270003,
              },
              'hover_title': 'result_v2 item',
              'uploader': <String, dynamic>{'uname': 'up-c'},
            },
            <String, dynamic>{
              'title': 'dropped item without ids',
            },
          ],
        },
      ],
    });

    expect(items, hasLength(3));
    expect(items[0].aid, 170001);
    expect(items[0].cid, 270001);
    expect(items[0].bvid, isNotEmpty);
    expect(items[0].pic, startsWith('https://'));
    expect(items[1].aid, 170002);
    expect(items[1].cid, 270002);
    expect(items[2].aid, 170003);
    expect(items[2].cid, 270003);
  });
}
