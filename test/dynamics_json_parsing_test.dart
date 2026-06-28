import 'package:flutter_test/flutter_test.dart';
import 'package:pilipala/models/dynamics/json_helper.dart';
import 'package:pilipala/models/dynamics/result.dart';
import 'package:pilipala/models/dynamics/up.dart';

void main() {
  test('dynamicString accepts primitive API drift values', () {
    expect(dynamicString(123), '123');
    expect(dynamicString(1.5), '1.5');
    expect(dynamicString(true), 'true');
    expect(dynamicString('ok'), 'ok');
    expect(dynamicString(null), isNull);
  });

  test('dynamic feed models accept numeric string fields', () {
    final DynamicsDataModel data = DynamicsDataModel.fromJson({
      'has_more': 1,
      'offset': 123,
      'items': [
        {
          'basic': {},
          'id_str': 456,
          'type': 789,
          'visible': 1,
          'modules': {
            'module_author': {
              'face': 1,
              'following': 0,
              'jump_url': 2,
              'label': 3,
              'mid': '42',
              'name': 4,
              'pub_action': 5,
              'pub_time': 6,
              'pub_ts': '0',
              'type': 7,
              'vip': {},
            },
            'module_dynamic': {
              'desc': {
                'text': 8,
                'rich_text_nodes': [
                  {
                    'orig_text': 9,
                    'text': 10,
                    'type': 11,
                    'rid': 12,
                    'emoji': {
                      'icon_url': 13,
                      'size': '1.5',
                      'text': 14,
                      'type': '1',
                    },
                  },
                ],
              },
              'major': {
                'type': 15,
                'archive': {
                  'aid': '1',
                  'bvid': 16,
                  'cover': 17,
                  'desc': 18,
                  'duration_text': 19,
                  'jump_url': 20,
                  'stat': {
                    'danmaku': 21,
                    'play': 22,
                  },
                  'title': 23,
                  'type': '1',
                },
              },
            },
            'module_stat': {
              'comment': {
                'count': 0,
                'forbidden': 0,
              },
              'forward': {
                'count': 1,
                'forbidden': 1,
              },
              'like': {
                'count': 2,
                'forbidden': 0,
                'status': 1,
              },
            },
          },
        },
      ],
    });

    final DynamicItemModel item = data.items!.single;
    final ModuleAuthorModel author = item.modules!.moduleAuthor!;
    final DynamicArchiveModel archive =
        item.modules!.moduleDynamic!.major!.archive!;

    expect(data.offset, '123');
    expect(item.idStr, '456');
    expect(item.type, '789');
    expect(author.face, '1');
    expect(author.name, '4');
    expect(archive.bvid, '16');
    expect(archive.cover, '17');
    expect(archive.desc, '18');
    expect(archive.stat!.danmaku, '21');
    expect(archive.stat!.play, '22');
  });

  test('follow up models accept numeric string fields', () {
    final FollowUpModel data = FollowUpModel.fromJson({
      'live_users': {
        'count': '1',
        'group': 2,
        'items': [
          {
            'face': 3,
            'is_reserve_recall': '0',
            'jump_url': 4,
            'mid': '5',
            'room_id': '6',
            'title': 7,
            'uname': 8,
          },
        ],
      },
      'up_list': [
        {
          'face': 9,
          'has_update': '1',
          'is_reserve_recall': 0,
          'mid': '10',
          'uname': 11,
        },
      ],
      'my_info': {
        'face': 12,
        'mid': '13',
        'name': 14,
      },
    });

    expect(data.liveUsers!.group, '2');
    expect(data.liveList!.single.face, '3');
    expect(data.liveList!.single.jumpUrl, '4');
    expect(data.liveList!.single.title, '7');
    expect(data.liveList!.single.uname, '8');
    expect(data.upList!.single.face, '9');
    expect(data.upList!.single.uname, '11');
    expect(data.myInfo!.face, '12');
    expect(data.myInfo!.name, '14');
  });
}
