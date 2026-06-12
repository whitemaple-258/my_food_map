# 食マップ (My Food Map) 🍜

行ったお店・行きたいお店を地図上に記録・管理できる個人向けグルメ日記アプリです。  
Flutter 製で Android / iOS に対応しています。

---

## ✨ 主な機能

### 🗺️ マップ表示
- Google マップ上にお気に入りのお店をピン表示
- ジャンルごとにカスタムカラーのマーカーを表示
- 地図の長押しで近くのお店名を自動検索して登録

### 🔍 お店の検索・登録
- Google Places API によるキーワード検索
- 検索結果から1タップで登録フローへ
- 店名入力時にオートコンプリート候補を表示

### 📋 2つのモード
| モード | 説明 |
|--------|------|
| **行ったお店** | 実際に訪問したお店を写真・評価と一緒に記録 |
| **行ってみたいお店** | 気になるお店をウィッシュリストとして管理 |

- 「行ってみたい」→「行った」へのワンタップ変換機能
- 近くに「行ってみたい」お店がある場合、自動で通知ダイアログを表示

### 📝 お店の詳細記録
- 写真（複数枚、ドラッグで並び替え対応）
- ⭐ 5段階の星評価
- ジャンル（複数選択可）
- イチオシメニュー・メモ
- 都道府県・住所（逆ジオコーディングで自動取得）

### 🔗 Google マップからの共有
- Google マップアプリの「共有」ボタンから直接お店を登録
- URL 解析で店名を自動取得
- 画像の共有にも対応

### 🔎 フィルター・絞り込み
- 店名で検索
- ジャンルで絞り込み
- 都道府県で絞り込み
- 評価（星数）で絞り込み

### 📅 期間限定・クーポン管理
- 期限のある情報（期間限定メニュー・クーポン等）を登録
- 期限が迫ると通知音 + ポップアップでお知らせ
- 通知タイミングは 1日前 / 3日前 / 1週間前 から選択可能
- スワイプで削除

### ⚙️ ジャンル設定
- ジャンルの追加・編集・削除
- カラーピッカーでジャンルカラーをカスタマイズ（マイカラー保存対応）

### ☁️ クラウドバックアップ
- Google ログインでデータをクラウドに保存
- 機種変更時もデータを復元可能
- Firebase Storage を使用（1GB 上限、使用量をアプリ内で確認可能）

---

## 🏗️ 技術スタック

| カテゴリ | 使用技術 |
|---------|---------|
| フレームワーク | [Flutter](https://flutter.dev/) |
| データベース | [SQLite (sqflite)](https://pub.dev/packages/sqflite) |
| 地図 | [Google Maps Flutter](https://pub.dev/packages/google_maps_flutter) |
| 場所検索 | [Google Places API (New)](https://developers.google.com/maps/documentation/places/web-service/op-overview) |
| 認証 | [Firebase Auth](https://firebase.flutter.dev/docs/auth/overview) (Google サインイン) |
| バックアップ | [Firebase Storage](https://firebase.flutter.dev/docs/storage/overview) |
| 環境変数管理 | [flutter_dotenv](https://pub.dev/packages/flutter_dotenv) |

---

## 🚀 セットアップ

### 1. リポジトリのクローン

```bash
git clone https://github.com/whitemaple-258/my_food_map.git
cd my_food_map
```

### 2. Firebase の設定

このプロジェクトは Firebase を使用しています。

1. [Firebase Console](https://console.firebase.google.com/) で新しいプロジェクトを作成
2. Android・iOS・Web アプリを登録
3. [FlutterFire CLI](https://firebase.flutter.dev/docs/cli/) でファイルを自動生成（推奨）：

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

または、テンプレートを手動でコピーして編集：

```bash
cp lib/firebase_options.dart.example lib/firebase_options.dart
# firebase_options.dart を開いてご自身の Firebase プロジェクトの値を記入
```

4. Firebase Console から `google-services.json` をダウンロードして `android/app/` に配置
5. Firebase Console から `GoogleService-Info.plist` をダウンロードして `ios/Runner/` に配置

### 3. Google Maps & Places API の設定

1. [Google Cloud Console](https://console.cloud.google.com/) で以下の API を有効化：
   - Maps SDK for Android
   - Maps SDK for iOS
   - Places API (New)

2. `.env.example` をコピーして `.env` を作成し、API キーを設定：

```bash
cp .env.example .env
# .env を編集して GOOGLE_MAPS_API_KEY を設定
```

3. `android/local.properties` に以下を追記（Android ビルド用）：

```properties
GOOGLE_MAPS_API_KEY=あなたのAPIキー
```

### 4. 依存パッケージのインストールと実行

```bash
flutter pub get
flutter run
```

---

## 📁 プロジェクト構成

```
lib/
├── main.dart                    # エントリーポイント
├── constants.dart               # 定数・APIキー取得
├── db_helper.dart               # SQLite DB操作
├── backup_helper.dart           # Firebase バックアップ
├── genre_manager.dart           # ジャンル管理
├── image_helper.dart            # 画像の保存・取得
├── marker_generator.dart        # カスタムマーカー生成
├── firebase_options.dart        # Firebase設定 (要: 自分で生成)
├── screens/
│   ├── map_screen.dart          # メイン画面（地図・一覧）
│   ├── spot_form_screen.dart    # お店の登録・編集画面
│   ├── reminder_screen.dart     # 期間限定・クーポン管理
│   └── settings_screen.dart     # 設定画面
└── widgets/
    ├── spot_detail_sheet.dart   # お店詳細シート
    ├── filter_modal.dart        # 絞り込みモーダル
    ├── map_tab_view.dart        # マップタブ
    ├── list_tab_view.dart       # リストタブ
    ├── custom_tab_bar.dart      # カスタムタブバー
    └── star_rating.dart         # 星評価ウィジェット
```

---

## ⚠️ セキュリティに関する注意

以下のファイルには機密情報が含まれるため、`.gitignore` により Git 管理対象外となっています。  
各自でご用意ください：

| ファイル | 取得方法 |
|---------|---------|
| `lib/firebase_options.dart` | `flutterfire configure` で自動生成 |
| `android/app/google-services.json` | Firebase Console からダウンロード |
| `ios/Runner/GoogleService-Info.plist` | Firebase Console からダウンロード |
| `.env` | `.env.example` をコピーして API キーを設定 |
| `android/local.properties` | Android SDK パスと API キーを手動記述 |

---

## 📜 ライセンス

MIT License
