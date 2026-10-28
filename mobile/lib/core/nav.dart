import 'package:flutter/material.dart';

/// Uygulama genelinde gezinme anahtarı: push bildirimi dokunuşu ve bağlam dışı yönlendirmeler için.
/// MaterialApp(navigatorKey: rootNavigatorKey) olarak bağlanır.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// Kabuğa "şu sekmeye geç" isteği (push yönlendirmesi): AppShell dinler, uygular ve null'a çeker.
/// Değer `AppTab` indeksidir (ör. Sohbet = 2).
final ValueNotifier<int?> shellTabRequest = ValueNotifier<int?>(null);
