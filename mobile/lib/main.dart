import 'package:flutter/material.dart';

import 'core/api.dart';
import 'core/session.dart';
import 'core/theme.dart';
import 'core/theme_controller.dart';
import 'features/auth/login_page.dart';
import 'features/shell/app_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final session = Session(ApiClient());
  final theme = ThemeController();
  theme.load();
  session.restore();
  runApp(BingolApp(session: session, themeController: theme));
}

class BingolApp extends StatelessWidget {
  const BingolApp({super.key, required this.session, required this.themeController});

  final Session session;
  final ThemeController themeController;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeController,
      builder: (context, _) => MaterialApp(
        title: 'BÜ Kampüs',
        debugShowCheckedModeBanner: false,
        theme: BuTheme.light(),
        darkTheme: BuTheme.dark(),
        themeMode: themeController.mode,
        home: ListenableBuilder(
          listenable: session,
          builder: (context, _) => switch (session.state) {
            SessionState.loading => const _Splash(),
            SessionState.signedOut => LoginPage(session: session),
            SessionState.signedIn => AppShell(session: session, themeController: themeController),
          },
        ),
      ),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
