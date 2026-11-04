import 'package:flutter/material.dart';

/// Uygulama genelinde gezinme anahtarı: push bildirimi dokunuşu ve bağlam dışı yönlendirmeler için.
/// MaterialApp(navigatorKey: rootNavigatorKey) olarak bağlanır.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// Kabuğa "şu sekmeye geç" isteği (push yönlendirmesi): AppShell dinler, uygular ve null'a çeker.
/// Değer `AppTab` indeksidir (ör. Sohbet = 2).
final ValueNotifier<int?> shellTabRequest = ValueNotifier<int?>(null);

/// Sürükleyici (tam ekran video) mod: Reels açıkken true. Yüzen alt gezinme saydamlaşır (video engellenmez), durum
/// çubuğu örtüsü kalkar. Yalnız Reels yazar; AppShell dinler.
final ValueNotifier<bool> shellImmersive = ValueNotifier<bool>(false);
