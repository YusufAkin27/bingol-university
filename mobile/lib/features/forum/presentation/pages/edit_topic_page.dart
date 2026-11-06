import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/locale_controller.dart';
import '../../../../core/session.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../widgets/bu.dart';
import '../../data/forum_api.dart';
import '../../data/forum_compose_errors.dart';
import '../../data/forum_compose_rules.dart';
import '../../data/forum_models.dart';
import '../widgets/compose_widgets.dart';

/// Konu düzenleme: yalnız başlık, açıklama ve kategori (görsel/anket düzenlenemez: sözleşme). Yalnız sahip
/// düzenler (sunucu doğrular); kilitli konuda alanlar pasiftir ve nedeni yazılır. Kaydedilince güncel
/// [TopicView] ile kapanır ve "Düzenlendi" bildirimi gösterilir. Eşzamanlı silinme/kaldırma (404/409) kısa mesajla bildirilir.
class EditTopicPage extends StatefulWidget {
  const EditTopicPage({super.key, required this.session, required this.topic, this.api});

  final Session session;
  final TopicView topic;
  final ForumApi? api;

  @override
  State<EditTopicPage> createState() => _EditTopicPageState();
}

class _EditTopicPageState extends State<EditTopicPage> {
  late final ForumApi _api = widget.api ?? ForumApi(widget.session);
  late final _title = TextEditingController(text: widget.topic.title);
  late final _body = TextEditingController(text: widget.topic.body);
  final _bodyFocus = FocusNode();

  List<ForumCategory> _cats = const [];
  bool _catsLoading = true;
  bool _catsFailed = false;
  late int? _categoryId = widget.topic.category?.id;

  bool _saving = false;
  bool _gone = false;
  bool _lockedNow = false;
  String? _error;

  bool get _locked => widget.topic.locked || _lockedNow;
  bool get _editable => !_locked && !_gone && widget.topic.canEdit;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _bodyFocus.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _catsLoading = true;
      _catsFailed = false;
    });
    try {
      final c = await _api.categories();
      if (!mounted) return;
      setState(() {
        _cats = c;
        _catsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _catsLoading = false;
        _catsFailed = true;
      });
    }
  }

  bool get _changed =>
      _title.text.trim() != widget.topic.title.trim() ||
      _body.text.trim() != widget.topic.body.trim() ||
      _categoryId != widget.topic.category?.id;

  bool get _valid =>
      !isBlankText(_title.text) &&
      _title.text.trim().length <= ForumComposeLimits.titleMax &&
      !isBlankText(_body.text) &&
      _body.text.trim().length <= ForumComposeLimits.bodyMax &&
      _categoryId != null;

  bool get _canSave => _editable && !_saving && _changed && _valid;

  void _touch() => setState(() => _error = null);

  Future<void> _save() async {
    if (!_canSave) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    final t = widget.topic;
    try {
      final updated = await _api.editTopic(
        t.id,
        title: _title.text.trim() != t.title.trim() ? _title.text : null,
        body: _body.text.trim() != t.body.trim() ? _body.text : null,
        categoryId: _categoryId != t.category?.id ? _categoryId : null,
      );
      if (!mounted) return;
      final l = context.l10n;
      final nav = Navigator.of(context);
      final host = nav.context;
      nav.pop<TopicView>(updated);
      // ignore: use_build_context_synchronously
      BuToast.show(host, l.forumComposeEditSaved, kind: BuToastKind.success, duration: const Duration(seconds: 2));
    } catch (e) {
      if (!mounted) return;
      final r = forumEditErrorText(e, context.l10n);
      setState(() {
        _saving = false;
        _error = r.text;
        if (r.gone) _gone = true;
        if (r.locked) _lockedNow = true;
      });
    }
  }

  Future<void> _close() async {
    if (_saving) return;
    if (!_changed) {
      Navigator.of(context).pop();
      return;
    }
    FocusScope.of(context).unfocus();
    final l = context.l10n;
    final discard = await BuConfirmSheet.show(
      context,
      title: l.forumComposeDiscardTitle,
      confirmLabel: l.forumComposeDiscardConfirm,
      cancelLabel: l.forumComposeDiscardKeep,
      destructive: true,
    );
    if (discard && mounted) Navigator.of(context).pop();
  }

  String? _banner(AppLocalizations l) {
    if (_error != null) return _error;
    if (_gone) return l.forumComposeEditGone;
    if (_locked) return l.forumComposeEditLocked;
    if (!widget.topic.canEdit) return widget.topic.mine ? l.forumComposeEditLocked : l.forumComposeEditNotOwner;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tt = Theme.of(context).textTheme;
    final banner = _banner(l);
    final fieldsOn = _editable && !_saving;
    return PopScope(
      canPop: !_changed && !_saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_saving) _close();
      },
      child: Scaffold(
        backgroundColor: t.bg,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: Column(children: [
            SizedBox(
              height: BuSize.appBar,
              child: Row(children: [
                IconButton(
                  key: const ValueKey('forumEditClose'),
                  tooltip: l.forumComposeClose,
                  constraints: const BoxConstraints(minWidth: BuSize.touch, minHeight: BuSize.touch),
                  icon: Icon(BuIcons.x, size: 24, color: t.ink),
                  onPressed: _saving ? null : _close,
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 12),
                  child: BuButton(
                    key: const ValueKey('forumEditSave'),
                    label: l.forumComposeEditSave,
                    compact: true,
                    busy: _saving,
                    onPressed: _canSave ? _save : null,
                  ),
                ),
              ]),
            ),
            Expanded(
              child: ListView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(BuSpace.page, 4, BuSpace.page, 32),
                children: [
                  AnimatedSize(
                    duration: BuMotion.of(context, BuMotion.short),
                    curve: BuMotion.standard,
                    alignment: Alignment.topCenter,
                    child: banner == null
                        ? const SizedBox(width: double.infinity)
                        : Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Semantics(
                              liveRegion: true,
                              child: Container(
                                key: const ValueKey('forumEditBanner'),
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(color: _error != null ? t.dangerSoft : t.sf2, borderRadius: BorderRadius.circular(BuRadius.sm)),
                                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  ExcludeSemantics(
                                      child: Icon(_error != null ? BuIcons.circleAlert : (_locked ? BuIcons.lock : BuIcons.info),
                                          size: 18, color: _error != null ? t.danger : t.mut)),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(banner,
                                        style: tt.bodySmall?.copyWith(
                                            color: _error != null ? t.danger : t.mut, fontWeight: FontWeight.w400, height: 1.35)),
                                  ),
                                ]),
                              ),
                            ),
                          ),
                  ),
                  CategoryPickerRow(
                    api: _api,
                    categories: _cats,
                    selectedId: _categoryId,
                    fallbackName: widget.topic.category?.name,
                    loading: _catsLoading,
                    failed: _catsFailed,
                    enabled: fieldsOn,
                    onRetry: _loadCategories,
                    onSelected: (c) {
                      setState(() {
                        _categoryId = c.id;
                        _error = null;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    key: const ValueKey('forumEditTitle'),
                    controller: _title,
                    enabled: fieldsOn,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: ForumComposeLimits.titleMax,
                    maxLengthEnforcement: MaxLengthEnforcement.enforced,
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.sentences,
                    inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'[\r\n]'))],
                    onChanged: (_) => _touch(),
                    onSubmitted: (_) => _bodyFocus.requestFocus(),
                    style: tt.titleLarge?.copyWith(color: t.ink, fontWeight: FontWeight.w400),
                    decoration: composeInputDecoration(context, hint: l.forumComposeTitleHint, padding: const EdgeInsets.symmetric(vertical: 8))
                        .copyWith(hintStyle: tt.titleLarge?.copyWith(color: t.mut, fontWeight: FontWeight.w400)),
                  ),
                  Divider(height: 16, color: t.bd),
                  TextField(
                    key: const ValueKey('forumEditBody'),
                    controller: _body,
                    focusNode: _bodyFocus,
                    enabled: fieldsOn,
                    minLines: 6,
                    maxLines: null,
                    maxLength: ForumComposeLimits.bodyMax,
                    maxLengthEnforcement: MaxLengthEnforcement.enforced,
                    keyboardType: TextInputType.multiline,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (_) => _touch(),
                    style: tt.bodyLarge?.copyWith(color: t.ink, fontWeight: FontWeight.w400),
                    decoration: composeInputDecoration(context, hint: l.forumComposeBodyHint, padding: const EdgeInsets.symmetric(vertical: 8)),
                  ),
                  const SizedBox(height: 16),
                  Text(l.forumComposeEditNote, style: tt.bodySmall?.copyWith(color: t.mut, fontWeight: FontWeight.w400)),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
