# 食マップ (My Food Map)

行ったお店・行きたいお店を地図上に記録できる Flutter アプリです。

## 機能

- 📍 Google マップ上にお気に入りのお店をピン留め
- 🍜 ジャンル別カラーマーカー（カスタム色対応）
- ⭐ 評価・メモ・写真の記録
- 🔍 Google Places API を使ったお店検索
- 📅 再訪リマインダー機能
- ☁️ Firebase を使ったクラウドバックアップ（Google ログイン）
- 🔄 Google マップからの共有で即登録

## セットアップ

### 1. Firebase の設定

このプロジェクトは Firebase を使用しています。

1. [Firebase Console](https://console.firebase.google.com/) で新しいプロジェクトを作成
2. Android・iOS・Web アプリを登録
3. [FlutterFire CLI](https://firebase.flutter.dev/docs/cli/) を使ってファイルを生成:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

または、テンプレートを手動でコピーして編集:

```bash
cp lib/firebase_options.dart.example lib/firebase_options.dart
# firebase_options.dart を編集して自分のプロジェクトの値を設定
```

4. `android/app/google-services.json` を Firebase Console からダウンロードして配置
5. `ios/Runner/GoogleService-Info.plist` を Firebase Console からダウンロードして配置

### 2. Google Maps & Places API の設定

1. [Google Cloud Console](https://console.cloud.google.com/) で以下の API を有効化:
   - Maps SDK for Android
   - Maps SDK for iOS
   - Places API (New)

2. `.env.example` をコピーして `.env` を作成し、APIキーを設定:

```bash
cp .env.example .env
# .env を編集して GOOGLE_MAPS_API_KEY を設定
```

3. `android/local.properties` に以下を追加:

```
GOOGLE_MAPS_API_KEY=あなたのAPIキー
```

### 3. 依存パッケージのインストール

```bash
flutter pub get
```

### 4. 実行

```bash
flutter run
```

## 使用技術

- [Flutter](https://flutter.dev/)
- [Firebase](https://firebase.google.com/) (Auth, Firestore, Storage)
- [Google Maps Flutter](https://pub.dev/packages/google_maps_flutter)
- [Google Places API (New)](https://developers.google.com/maps/documentation/places/web-service/op-overview)
- [SQLite (sqflite)](https://pub.dev/packages/sqflite)

## ライセンス

MIT License
