import 'package:flutter/material.dart';
import 'package:my_food_map/genre_manager.dart';

class FilterModal extends StatefulWidget {
  final List<Map<String, dynamic>> allSpots;
  final String initialName;
  final String? initialGenre;
  final String? initialPrefecture;
  final double? initialMinRating;
  final bool showRating; // ★追加：評価フィルタを表示するか

  final Function(String name, String? genre, String? pref, double? minRating)
  onApply;
  final VoidCallback onReset;

  const FilterModal({
    super.key,
    required this.allSpots,
    required this.initialName,
    this.initialGenre,
    this.initialPrefecture,
    this.initialMinRating,
    this.showRating = true, // ★デフォルトは表示
    required this.onApply,
    required this.onReset,
  });

  @override
  State<FilterModal> createState() => _FilterModalState();
}

class _FilterModalState extends State<FilterModal> {
  late TextEditingController _nameController;
  String? _tempGenre;
  String? _tempPref;
  double _tempMinRating = 0.0;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _tempGenre = widget.initialGenre;
    _tempPref = widget.initialPrefecture;
    _tempMinRating = widget.initialMinRating ?? 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final existingPrefectures = widget.allSpots
        .map((e) => e['prefecture'] as String?)
        .where((e) => e != null && e.isNotEmpty)
        .toSet()
        .toList();
    existingPrefectures.sort();

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                const Text(
                  "登録データを検索",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),

                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: '店名 (部分一致)',
                    prefixIcon: Icon(Icons.store),
                    border: OutlineInputBorder(),
                    hintText: '例: ShinShin, スターバックス',
                  ),
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (value) {
                    widget.onApply(
                      value,
                      _tempGenre,
                      _tempPref,
                      _tempMinRating == 0.0 ? null : _tempMinRating,
                    );
                    Navigator.pop(context);
                  },
                ),
                const SizedBox(height: 15),

                DropdownButtonFormField<String>(
                  initialValue: _tempPref,
                  decoration: const InputDecoration(
                    labelText: '都道府県',
                    prefixIcon: Icon(Icons.location_on),
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('指定なし')),
                    ...existingPrefectures.map(
                      (pref) =>
                          DropdownMenuItem(value: pref, child: Text(pref!)),
                    ),
                  ],
                  onChanged: (v) {
                    FocusScope.of(context).unfocus();
                    setState(() => _tempPref = v);
                  },
                ),
                const SizedBox(height: 15),

                DropdownButtonFormField<String>(
                  initialValue: _tempGenre,
                  decoration: const InputDecoration(
                    labelText: 'ジャンル',
                    prefixIcon: Icon(Icons.restaurant),
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('指定なし')),
                    ...GenreManager().genres.map(
                      (g) => DropdownMenuItem(value: g.id, child: Text(g.name)),
                    ),
                  ],
                  onChanged: (v) {
                    FocusScope.of(context).unfocus();
                    setState(() => _tempGenre = v);
                  },
                ),

                // ★修正：showRatingがtrueの時だけ表示する
                if (widget.showRating) ...[
                  const SizedBox(height: 20),
                  const Text(
                    "最低評価の星の数",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Slider(
                          value: _tempMinRating,
                          min: 0.0,
                          max: 5.0,
                          divisions: 5,
                          label: _tempMinRating == 0.0
                              ? "全て"
                              : "${_tempMinRating.toStringAsFixed(0)}点",
                          onChanged: (v) {
                            FocusScope.of(context).unfocus();
                            setState(() => _tempMinRating = v);
                          },
                          activeColor: Colors.amber,
                          inactiveColor: Colors.grey[300],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: Text(
                          _tempMinRating == 0.0
                              ? "全て"
                              : "${_tempMinRating.toStringAsFixed(0)}点以上",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 20),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          widget.onReset();
                          Navigator.pop(context);
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                        child: const Text("リセット"),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          widget.onApply(
                            _nameController.text,
                            _tempGenre,
                            _tempPref,
                            _tempMinRating == 0.0 ? null : _tempMinRating,
                          );
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                        child: const Text("検索"),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
