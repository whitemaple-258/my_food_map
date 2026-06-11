import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import 'package:my_food_map/genre_manager.dart';
import 'package:my_food_map/db_helper.dart';
import 'package:my_food_map/backup_helper.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback? onDataChanged;
  const SettingsScreen({super.key, this.onDataChanged});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _usageBytes = 0;
  bool _isLoadingUsage = true;
  static const int _limitBytes = 1 * 1024 * 1024 * 1024;
  static const int _warningBytes = (_limitBytes * 8) ~/ 10;

  List<Color> _customColors = [];

  final List<Map<String, dynamic>> _presetColors = [
    {'name': '黒', 'color': Colors.black},
    {'name': 'ブラウン', 'color': const Color(0xFF795548)},
    {'name': 'コーヒー', 'color': const Color(0xFF4E342E)},
    {'name': 'ラテ', 'color': const Color(0xFF8D6E63)},
    {'name': '赤', 'color': Colors.red},
    {'name': '朱色', 'color': Colors.deepOrange},
    {'name': 'オレンジ', 'color': Colors.orange},
    {'name': '山吹色', 'color': Colors.amber},
    {'name': '黄色', 'color': Colors.yellow},
    {'name': 'さくら', 'color': const Color(0xFFF48FB1)},
    {'name': 'ピーチ', 'color': const Color(0xFFFFAB91)},
    {'name': 'クリーム', 'color': const Color(0xFFFFF9C4)},
    {'name': 'ミント', 'color': const Color(0xFF80CBC4)},
    {'name': 'ソーダ', 'color': const Color(0xFF81D4FA)},
    {'name': 'ラベンダー', 'color': const Color(0xFFCE93D8)},
    {'name': '緑', 'color': Colors.green},
    {'name': '深緑', 'color': const Color(0xFF2E7D32)},
    {'name': '水色', 'color': Colors.cyan},
    {'name': '青', 'color': Colors.blue},
    {'name': '藍色', 'color': Colors.indigo},
    {'name': '紫', 'color': Colors.deepPurple},
    {'name': 'グレー', 'color': Colors.grey},
  ];

  @override
  void initState() {
    super.initState();
    _checkUsage();
    _loadCustomColors();
  }

  Future<void> _loadCustomColors() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? colorInts = prefs.getStringList('my_custom_colors');
    if (colorInts != null) {
      setState(() {
        _customColors = colorInts.map((e) => Color(int.parse(e))).toList();
      });
    }
  }

  Future<void> _saveCustomColors() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> colorInts = _customColors
        .map((c) => c.value.toString())
        .toList();
    await prefs.setStringList('my_custom_colors', colorInts);
  }

  void _openColorPicker(
    BuildContext context,
    Function(Color) onColorSelected,
    StateSetter dialogSetState,
  ) {
    Color pickerColor = Colors.blue;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('色を作成'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 50,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: pickerColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 4),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        "この色を作成",
                        style: TextStyle(
                          color:
                              ThemeData.estimateBrightnessForColor(
                                    pickerColor,
                                  ) ==
                                  Brightness.dark
                              ? Colors.white
                              : Colors.black54,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ColorPicker(
                    pickerColor: pickerColor,
                    onColorChanged: (color) =>
                        setState(() => pickerColor = color),
                    enableAlpha: false,
                    displayThumbColor: true,
                    paletteType: PaletteType.hsvWithHue,
                    labelTypes: const [],
                    pickerAreaHeightPercent: 0.7,
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                child: const Text('キャンセル'),
                onPressed: () => Navigator.of(context).pop(),
              ),
              ElevatedButton(
                child: const Text('決定'),
                onPressed: () {
                  dialogSetState(() {
                    if (!_customColors.any(
                      (c) => c.value == pickerColor.value,
                    )) {
                      _customColors.insert(0, pickerColor);
                    }
                  });
                  _saveCustomColors();
                  onColorSelected(pickerColor);
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _deleteCustomColor(Color color, StateSetter dialogSetState) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('色の削除'),
        content: const Text('この色をマイカラーから削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () {
              dialogSetState(() {
                _customColors.removeWhere((c) => c.value == color.value);
              });
              _saveCustomColors();
              Navigator.pop(context);
            },
            child: const Text('削除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _checkUsage() async {
    final size = await BackupHelper().calculateTotalSize();
    if (mounted) {
      setState(() {
        _usageBytes = size;
        _isLoadingUsage = false;
      });
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return "$bytes B";
    if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(1)} KB";
    if (bytes < 1024 * 1024 * 1024) {
      return "${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB";
    }
    return "${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB";
  }

  /* // 1つ前のバージョンからの復元処理 (緊急時用)
  Future<void> _restoreFromOldVersion() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("1つ前のバックアップから復元"),
        content: const Text("最新のバックアップより「1回前」の状態に戻します。\n\n現在のデータは上書きされますが、よろしいですか？"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("キャンセル")),
          TextButton(onPressed: () => Navigator.pop(context, true), style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text("実行")),
        ],
      ),
    );
    if (confirm != true) return;

    showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator()));

    try {
      final success = await BackupHelper().restoreFromOldVersion();
      Navigator.pop(context);
      
      if (success) {
        await GenreManager().load();
        await _loadCustomColors();
        widget.onDataChanged?.call(); 
        setState(() {}); 
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("1つ前のデータから復元しました！")));
        _checkUsage();
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("1つ前のバックアップが見つかりませんでした")));
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("エラー: $e")));
    }
  }
  */

  @override
  Widget build(BuildContext context) {
    final genres = GenreManager().genres;
    final user = FirebaseAuth.instance.currentUser;
    final double usageRate = (_usageBytes / _limitBytes).clamp(0.0, 1.0);
    final bool isWarning = usageRate > 0.8;

    return Scaffold(
      appBar: AppBar(title: const Text("設定")),
      body: ListView(
        children: [
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                const BoxShadow(color: Colors.black12, blurRadius: 4),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _isLoadingUsage
                          ? "計算中..."
                          : "使用量: ${_formatBytes(_usageBytes)}",
                    ),
                    Text("${(usageRate * 100).toStringAsFixed(1)}%"),
                  ],
                ),
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: usageRate,
                  backgroundColor: Colors.grey[200],
                  color: isWarning
                      ? Colors.red
                      : (usageRate > 0.5 ? Colors.orange : Colors.green),
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
                if (isWarning)
                  const Text(
                    "⚠️ 容量注意",
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
          const Divider(),
          if (user == null)
            ListTile(
              leading: const Icon(Icons.login, color: Colors.blue),
              title: const Text("Googleでログイン"),
              subtitle: const Text("バックアップ機能の利用に必要です"),
              onTap: () async {
                await BackupHelper().signInWithGoogle();
                setState(() {});
              },
            )
          else
            Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.check_circle, color: Colors.green),
                  title: Text("ログイン中: ${user.email}"),
                  subtitle: const Text("タップしてログアウト"),
                  onTap: () async {
                    await FirebaseAuth.instance.signOut();
                    setState(() {});
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.cloud_upload, color: Colors.blue),
                  title: const Text("今すぐクラウドに保存"),
                  onTap: _uploadToCloud,
                ),
                ListTile(
                  leading: const Icon(
                    Icons.cloud_download,
                    color: Colors.orange,
                  ),
                  title: const Text("クラウドから復元"),
                  onTap: _restoreFromCloud,
                ),
                // 緊急時用のボタンをコメントアウトして非表示に
                /*
                ListTile(
                  leading: const Icon(Icons.history, color: Colors.grey), 
                  title: const Text("1つ前のバックアップから復元"),
                  subtitle: const Text("間違って上書きしてしまった場合に"),
                  onTap: _restoreFromOldVersion,
               ),*/
              ],
            ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              "ジャンル設定",
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
            ),
          ),
          ...genres.map((genre) {
            final isProtected = (genre.id == 'other');
            return ListTile(
              leading: Icon(Icons.location_on, color: genre.color, size: 32),
              title: Text(
                genre.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () => _showEditDialog(genre),
                  ),
                  if (!isProtected)
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.grey),
                      onPressed: () => _confirmDelete(genre),
                    ),
                ],
              ),
            );
          }),
          ListTile(
            leading: const Icon(Icons.add_circle_outline),
            title: const Text("ジャンルを追加", style: TextStyle(color: Colors.blue)),
            onTap: _showAddDialog,
          ),
          const SizedBox(height: 50),
        ],
      ),
    );
  }

  void _showAddDialog() {
    final nameController = TextEditingController();
    Color selectedColor = Colors.red;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text("新しいジャンル"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: "ジャンル名"),
                  autofocus: true,
                ),
                const SizedBox(height: 20),
                _buildColorPickerUI(
                  context,
                  selectedColor,
                  (c) => setState(() => selectedColor = c),
                  setState,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("キャンセル"),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.isNotEmpty) {
                  GenreManager().addGenre(nameController.text, selectedColor);
                  this.setState(() {});
                  Navigator.pop(context);
                }
              },
              child: const Text("追加"),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(GenreData genre) {
    final nameController = TextEditingController(text: genre.name);
    Color selectedColor = genre.color;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text("編集"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: "表示名"),
                ),
                const SizedBox(height: 20),
                _buildColorPickerUI(
                  context,
                  selectedColor,
                  (c) => setState(() => selectedColor = c),
                  setState,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("キャンセル"),
            ),
            ElevatedButton(
              onPressed: () {
                GenreManager().updateGenre(
                  genre.id,
                  nameController.text,
                  selectedColor,
                );
                this.setState(() {});
                widget.onDataChanged?.call();
                Navigator.pop(context);
              },
              child: const Text("保存"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorPickerUI(
    BuildContext context,
    Color currentColor,
    Function(Color) onSelected,
    StateSetter dialogSetState,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "マイカラー",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            if (_customColors.isNotEmpty)
              const Text(
                "長押しで削除",
                style: TextStyle(fontSize: 10, color: Colors.grey),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            GestureDetector(
              onTap: () =>
                  _openColorPicker(context, onSelected, dialogSetState),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey[400]!),
                ),
                child: const Icon(Icons.add, color: Colors.black54),
              ),
            ),
            ..._customColors.map((color) {
              final isSelected = color.value == currentColor.value;
              return GestureDetector(
                onTap: () => onSelected(color),
                onLongPress: () => _deleteCustomColor(color, dialogSetState),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(color: Colors.black, width: 3)
                        : Border.all(color: Colors.grey[300]!, width: 1),
                    boxShadow: [
                      if (isSelected)
                        const BoxShadow(blurRadius: 5, color: Colors.black26),
                    ],
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white)
                      : null,
                ),
              );
            }),
          ],
        ),
        const SizedBox(height: 20),
        const Divider(),
        const Text(
          "プリセット",
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: _presetColors.map((option) {
            final color = option['color'] as Color;
            final isSelected = color.value == currentColor.value;
            return Tooltip(
              message: option['name'],
              child: GestureDetector(
                onTap: () => onSelected(color),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(color: Colors.black, width: 3)
                        : Border.all(color: Colors.grey[300]!, width: 1),
                    boxShadow: [
                      if (isSelected)
                        const BoxShadow(blurRadius: 5, color: Colors.black26),
                    ],
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white)
                      : null,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Future<void> _uploadToCloud() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator()),
    );
    try {
      await BackupHelper().uploadToCloud();
      Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("保存しました")));
      }
      _checkUsage();
    } catch (e) {
      Navigator.pop(context);
    }
  }

  Future<void> _restoreFromCloud() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("クラウド復元の確認"),
        content: const Text("現在のデータはすべて消去され、クラウド上のバックアップで上書きされます。\nよろしいですか？"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("キャンセル"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("実行"),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final success = await BackupHelper().restoreFromCloud();
      Navigator.pop(context);

      if (success) {
        await GenreManager().load();
        await _loadCustomColors(); // マイカラーも再読み込み
        widget.onDataChanged?.call();
        setState(() {});
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("クラウドから復元しました！")));
        }
        _checkUsage();
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("エラー: $e")));
    }
  }

  Future<void> _confirmDelete(GenreData genre) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("削除"),
        content: const Text("削除しますか？"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text("キャンセル"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text("削除"),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await DBHelper().changeGenre(genre.id, 'other');
      GenreManager().deleteGenre(genre.id);
      setState(() {});
      widget.onDataChanged?.call();
    }
  }
}
