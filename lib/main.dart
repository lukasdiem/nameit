import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'data/app_store.dart';
import 'ui/screens/home_screen.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = AppStore();
  await store.load();
  runApp(ChangeNotifierProvider.value(value: store, child: const NamioApp()));
}

class NamioApp extends StatelessWidget {
  const NamioApp({super.key});

  @override
  Widget build(BuildContext context) {
    final localeSetting = context.select<AppStore, String>((s) => s.settings.locale);
    return MaterialApp(
      title: 'nameIT',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      locale: localeSetting == 'system' ? null : Locale(localeSetting),
      supportedLocales: const [Locale('de'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const HomeScreen(),
    );
  }
}
