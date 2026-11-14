import 'dart:async';
import 'dart:io';

import 'package:bu_kampus/features/chat/chat_media.dart';
import 'package:bu_kampus/features/chat/chat_voice.dart';
import 'package:bu_kampus/features/chat/chat_voice_bubble.dart';
import 'package:bu_kampus/features/chat/message_bubble.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

// Sesli mesaj (V1): kayıt denetleyicisi (sahte kaydedici), balon çizimi ve erişilebilirlik etiketi.

class _FakeRecorder implements VoiceRecorder {
  bool permission = true;
  bool startOk = true;
  final starts = <String>[];
  int stops = 0;
  int cancels = 0;
  String? stopPath;
  final _lv = StreamController<double>.broadcast();
  final _int = StreamController<void>.broadcast();

  @override
  Stream<double> get levels => _lv.stream;
  @override
  Stream<void> get interrupted => _int.stream;
  void interrupt() => _int.add(null);

  @override
  Future<bool> hasPermission() async => permission;
  @override
  Future<bool> start(String path) async {
    starts.add(path);
    stopPath = path;
    return startOk;
  }

  @override
  Future<String?> stop() async {
    stops++;
    return stopPath;
  }

  @override
  Future<void> cancel() async => cancels++;
  @override
  Future<void> dispose() async {}
}

class _SlowRecorder extends _FakeRecorder {
  _SlowRecorder(this.gate);
  final Future<void> gate;
  @override
  Future<bool> start(String path) async {
    await gate;
    return true;
  }
}

class _GateCtl extends VideoPlayerController {
  _GateCtl(this.gate) : super.networkUrl(Uri.parse('http://x.invalid/a.mp4'));
  final Completer<void> gate;
  int plays = 0;
  int pauses = 0;
  @override
  Future<void> initialize() => gate.future;
  @override
  Future<void> setLooping(bool looping) async {}
  @override
  Future<void> setPlaybackSpeed(double speed) async {}
  @override
  Future<void> play() async => plays++;
  @override
  Future<void> pause() async => pauses++;
  @override
  Future<void> dispose() async {
    await super.dispose();
  }
}

void main() {
  setUpAll(loadTestFonts);

  late Directory tmp;
  late File file;
  var clock = DateTime(2026, 1, 1);

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('voice_test');
    file = File('${tmp.path}/a.m4a')..writeAsBytesSync([1, 2, 3]);
    clock = DateTime(2026, 1, 1);
  });
  tearDown(() async {
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  VoiceRecordController make(_FakeRecorder r) =>
      VoiceRecordController(recorder: r, tempPath: () async => file.path, now: () => clock);

  test('kayit baslarken denetleyici dispose edilirse kayit birakilir, notify patlamaz', () async {
    final gate = Completer<void>();
    final r = _SlowRecorder(gate.future);
    final c = make(r);
    final f = c.start();
    c.dispose();
    gate.complete();
    expect(await f, isFalse);
    expect(r.cancels, 1);
    expect(c.recording, isFalse);
  });

  test('1 sn altindaki kayit atilir ve dosya silinir', () async {
    final r = _FakeRecorder();
    final c = make(r);
    expect(await c.start(), isTrue);
    expect(c.recording, isTrue);
    clock = clock.add(const Duration(milliseconds: 600));
    expect(await c.finish(), isNull);
    expect(file.existsSync(), isFalse);
    expect(c.recording, isFalse);
    c.dispose();
  });

  test('yeterince uzun kayit klip olarak doner, sure olculur', () async {
    final r = _FakeRecorder();
    final c = make(r);
    await c.start();
    clock = clock.add(const Duration(seconds: 42));
    final clip = await c.finish();
    expect(clip, isNotNull);
    expect(clip!.durationMs, 42000);
    expect(file.existsSync(), isTrue);
    c.dispose();
  });

  test('iptal isaretliyken birakilan kayit gonderilmez', () async {
    final r = _FakeRecorder();
    final c = make(r);
    await c.start();
    clock = clock.add(const Duration(seconds: 5));
    c.setCancelArmed(true);
    expect(await c.finish(), isNull);
    expect(file.existsSync(), isFalse);
    c.dispose();
  });

  test('sistem kesintisi kaydi iptal eder ve haber verir', () async {
    final r = _FakeRecorder();
    final c = make(r);
    var notified = false;
    c.onInterrupted = () => notified = true;
    await c.start();
    r.interrupt();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(notified, isTrue);
    expect(c.recording, isFalse);
    expect(r.cancels, 1);
    c.dispose();
  });

  test('baslatilamazsa kayit durumuna girilmez', () async {
    final r = _FakeRecorder()..startOk = false;
    final c = make(r);
    expect(await c.start(), isFalse);
    expect(c.recording, isFalse);
    c.dispose();
  });

  test('ek turu tanima ve liste onizlemesi', () {
    expect(isAudioAttachment({'kind': 'AUDIO'}), isTrue);
    expect(isAudioAttachment({'kind': 'VIDEO'}), isFalse);
    expect(
        galleryAttachments({
          'attachments': [
            {'kind': 'AUDIO', 'url': '/x'},
            {'kind': 'IMAGE', 'url': '/y'}
          ]
        }).length,
        1);
    expect(
        attachmentPreviewLabel({
          'attachments': [
            {'kind': 'AUDIO'}
          ]
        }),
        'Sesli mesaj');
  });

  testWidgets('balon: sesli mesaj oynat dugmesi, sure ve erisilebilirlik etiketi', (tester) async {
    useScreen(tester, const Size(390, 800));
    await tester.pumpWidget(buildApp(
        Padding(
          padding: const EdgeInsets.all(8),
          child: MessageBubble(
            message: {
              'id': 9,
              'senderId': 11,
              'text': '',
              'createdAt': DateTime.now().toUtc().toIso8601String(),
              'attachments': [
                {'id': 4, 'kind': 'AUDIO', 'url': '/api/conversations/1/media/4', 'durationMs': 42000, 'contentType': 'audio/mp4'}
              ],
            },
            mine: false,
            senderName: null,
            replyName: null,
            authHeaders: const {},
            onMenu: () {},
            onRetry: () {},
            onOpenImage: (_) {},
            onReact: (_) {},
          ),
        ),
        size: kPhoneMedium));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const ValueKey('voicePlayButton')), findsOneWidget);
    expect(find.text('0:42'), findsWidgets);
    expect(find.bySemanticsLabel(RegExp('Sesli mesaj, 0:42, Oynat')), findsOneWidget);
    final size = tester.getSize(find.byKey(const ValueKey('voicePlayButton')));
    expect(size.width, greaterThanOrEqualTo(44));
    expect(size.height, greaterThanOrEqualTo(44));
    // hiz dugmesi 1x -> 1.5x -> 2x
    expect(find.text('1x'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('voiceSpeedButton')));
    await tester.pump();
    expect(find.text('1.5x'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('voiceSpeedButton')));
    await tester.pump();
    expect(find.text('2x'), findsOneWidget);
  });

  testWidgets('balon: yuklenirken ikinci dokunus yok sayilir (oynatma tek kez baslar)', (tester) async {
    useScreen(tester, const Size(390, 800));
    final gate = Completer<void>();
    final ctl = _GateCtl(gate);
    await tester.pumpWidget(buildApp(
        VoiceBubble(
            source: const VoiceSource.network('/api/conversations/1/media/4', {}),
            durationMs: 5000,
            color: Colors.black,
            controllerFactory: (_) => ctl),
        size: kPhoneMedium));
    await tester.tap(find.byKey(const ValueKey('voicePlayButton')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('voicePlayButton'))); // yüklenirken
    await tester.pump();
    gate.complete();
    await tester.pump(const Duration(milliseconds: 50));
    expect(ctl.plays, 1);
    expect(ctl.pauses, 0);
    await unmount(tester);
  });
}
