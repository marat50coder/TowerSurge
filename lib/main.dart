import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/palette.dart';
import 'core/store.dart';
import 'screens/loading_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Store.init();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: P.bottomPanel,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  // The splash may be shown in any orientation; the game itself locks portrait.
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const TowerSurgeApp());
}

class TowerSurgeApp extends StatelessWidget {
  const TowerSurgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tower Surge',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: T.family,
        scaffoldBackgroundColor: P.skyTop,
        colorScheme: ColorScheme.fromSeed(
          seedColor: P.blue,
          brightness: Brightness.dark,
        ),
      ),
      builder: (context, child) => MediaQuery.withNoTextScaling(child: child!),
      home: const LoadingScreen(),
    );
  }
}
