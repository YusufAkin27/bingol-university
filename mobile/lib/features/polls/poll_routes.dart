import 'package:flutter/material.dart';

import '../../core/session.dart';
import 'poll_detail_page.dart';
import 'poll_form_page.dart';
import 'poll_list_page.dart';
import 'poll_models.dart';

export 'poll_menu_card.dart' show PollMenuCard;
export 'poll_club_section.dart' show PollClubSection;

/// Anket ekranlarına ince yönlendirme (tek giriş noktası).

/// Anket listesi (Keşfet girişi ya da tek kulüp).
Future<void> openPollList(BuildContext context, Session session, {int? communityId, String title = 'Anketler'}) =>
    Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
            builder: (_) => PollListPage(session: session, communityId: communityId, title: title)));

/// Anket detayı. Oy verildi/geri çekildi ise true döner (çağıran listeyi tazeler).
Future<bool?> openPollDetail(BuildContext context, Session session, int pollId, {Poll? initial}) =>
    Navigator.push<bool>(
        context,
        MaterialPageRoute<bool>(
            builder: (_) => PollDetailPage(session: session, pollId: pollId, initial: initial)));

/// Anket oluşturma formu (kulüp yöneticisi). Oluşturulan anketi döner.
Future<Poll?> openPollForm(BuildContext context, Session session, {required int communityId}) =>
    Navigator.push<Poll>(context,
        MaterialPageRoute<Poll>(builder: (_) => PollFormPage(session: session, communityId: communityId)));
