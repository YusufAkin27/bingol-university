import 'package:flutter/material.dart';

/// Uygulama genelinde gezinme anahtarı: push bildirimi dokunuşu ve bağlam dışı yönlendirmeler için.
/// MaterialApp(navigatorKey: rootNavigatorKey) olarak bağlanır.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
