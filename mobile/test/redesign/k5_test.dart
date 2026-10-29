import 'dart:async';
import 'dart:io';

import 'package:bu_kampus/features/chat/chatlist_widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';

/// Gorsel hic inmeyen / hata veren ag istemcisi (avatar yedegi testi).
class _FailingClient implements HttpClient {
  @override
  bool autoUncompress = true;
  @override
  Future<HttpClientRequest> getUrl(Uri url) async => throw const SocketException('yok');
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async => throw const SocketException('yok');
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _HangingClient extends _FailingClient {
  @override
  Future<HttpClientRequest> getUrl(Uri url) => Completer<HttpClientRequest>().future;
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) => Completer<HttpClientRequest>().future;
}

void main() {
  setUpAll(loadTestFonts);

  for (final name in ['hata', 'gelmiyor']) {
    testWidgets('ChatlistAvatar: url dolu ama gorsel yuklenemez ($name) ise bas harfli tonlu kare kalir', (tester) async {
      debugNetworkImageHttpClientProvider = name == 'hata' ? () => _FailingClient() : () => _HangingClient();
      await tester.pumpWidget(buildApp(const Center(child: ChatlistAvatar(name: 'Zeynep Demir', url: '/files/p1.jpg'))));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.text('ZD'), findsOneWidget);
      expect(tester.getSize(find.byType(ChatlistAvatar)), const Size(52, 52));
      expect(tester.takeException(), isNull);
      debugNetworkImageHttpClientProvider = null;
    });
  }

  testWidgets('ChatlistAvatar: url yoksa bas harfli kare', (tester) async {
    await tester.pumpWidget(buildApp(const Center(child: ChatlistAvatar(name: 'Berkan Yildiz'))));
    await settle(tester, const Duration(milliseconds: 200));
    expect(find.text('BY'), findsOneWidget);
  });

  testWidgets('ChatlistAvatar circle: 28 dp yuvarlak bas harfli gonderen avatari', (tester) async {
    await tester.pumpWidget(buildApp(const Center(child: ChatlistAvatar(name: 'Ahmet Demir', size: 28, circle: true))));
    await settle(tester, const Duration(milliseconds: 200));
    expect(find.text('AD'), findsOneWidget);
    expect(tester.getSize(find.byType(ChatlistAvatar)), const Size(28, 28));
    final box = tester.widget<Container>(find.ancestor(of: find.text('AD'), matching: find.byType(Container)).first);
    expect((box.decoration! as BoxDecoration).borderRadius, BorderRadius.circular(14));
    expect(tester.takeException(), isNull);
  });
}
