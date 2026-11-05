import 'dart:convert';

import 'fake_app.dart';

/// Sahte `GET/PUT /notifications/preferences` (sunucu anlamlarıyla): kısmi PUT birleştirir
/// (alt türler tek tek, `quietHours`, `hideMessagePreview`), alan yoksa eski sunucu gibi davranır.
///
/// `communities` sosyal alt türlerin ana bayrağıdır (backend `NotificationType.POST_LIKE("communities")`).
class FakeNotifPrefs {
  FakeNotifPrefs(
    FakeBackend backend, {
    bool communities = true,
    bool announcements = true,
    bool legacy = false,
    bool withHidePreview = true,
    bool withQuiet = true,
    Map<String, bool>? subtypes,
  }) {
    state = <String, dynamic>{
      'news': true,
      'announcements': announcements,
      'events': true,
      'messages': true,
      'communities': communities,
      if (!legacy) ...{
        'polls': true,
        'academicAnnouncements': true,
        'mealMenu': false,
        if (withQuiet) 'quietHours': {'enabled': false, 'start': '22:00', 'end': '07:00', 'timezone': 'Europe/Istanbul'},
        'subtypes': subtypes ?? defaultSubtypes(),
        if (withHidePreview) 'hideMessagePreview': false,
      },
    };
    backend.handlers.add((req, path) {
      if (path != '/notifications/preferences') return null;
      if (req.method == 'GET') {
        gets++;
        if (failGet) return const FakeResult.json({'code': 'SERVER_ERROR', 'message': ''}, status: 500);
        return FakeResult.json(jsonDecode(jsonEncode(state)));
      }
      if (req.method != 'PUT') return null;
      puts.add(jsonDecode(req.body) as Map<String, dynamic>);
      if (failPut) return const FakeResult.json({'code': 'SERVER_ERROR', 'message': ''}, status: 500);
      _merge(puts.last);
      return FakeResult.json(jsonDecode(jsonEncode(state)));
    });
  }

  static Map<String, bool> defaultSubtypes() => {
        'MESSAGE_DIRECT': true,
        'MESSAGE_GROUP': true,
        'EVENT_REMINDER': true,
        'EVENT_UPDATE': true,
        'EVENT_ADMISSION': true,
        'COMMUNITY_POST': true,
        'COMMUNITY_ROLE': true,
        'COMMUNITY_JOIN': true,
        'POST_LIKE': true,
        'POST_COMMENT': true,
        'COMMENT_REPLY': true,
        'POST_MENTION': true,
        'USER_FOLLOW': true,
        'FOLLOW_REQUEST': true,
        'FOLLOW_ACCEPTED': true,
      };

  late final Map<String, dynamic> state;
  final List<Map<String, dynamic>> puts = [];
  int gets = 0;
  bool failPut = false;
  bool failGet = false;

  void _merge(Map<String, dynamic> body) {
    for (final e in body.entries) {
      if (e.key == 'subtypes') {
        final cur = Map<String, dynamic>.from(state['subtypes'] as Map? ?? {});
        (e.value as Map).forEach((k, v) {
          if (!cur.containsKey(k)) throw StateError('INVALID_SUBTYPE $k'); // sunucu 400 döner
          cur[k as String] = v;
        });
        state['subtypes'] = cur;
      } else if (e.key == 'quietHours') {
        state['quietHours'] = {...(state['quietHours'] as Map? ?? {}), ...(e.value as Map)};
      } else if (state.containsKey(e.key)) {
        state[e.key] = e.value; // bilinmeyen alan eski sunucuda yok sayılır
      }
    }
  }
}
