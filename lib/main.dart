import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; // ★必須
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // .env用
import 'firebase_options.dart';

import 'package:my_food_map/screens/map_screen.dart';

Future<void> main() async {
  // 1. Flutterエンジンの初期化（これをしないと非同期処理で落ちます）
  WidgetsFlutterBinding.ensureInitialized();

  // 2. .envファイルの読み込み
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    print("Warning: .env file not found. ($e)");
  }

  // 3. Firebaseの初期化
  // optionsには、flutterfire configureで生成された設定を使います
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My Food Map',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
        fontFamily: 'Hiragino Sans',
      ),

      locale: const Locale('ja', 'JP'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ja', 'JP')],

      home: const MapScreen(),
    );
  }
}
