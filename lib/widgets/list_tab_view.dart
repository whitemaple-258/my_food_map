import 'dart:io';
import 'package:flutter/material.dart';
import 'package:my_food_map/genre_manager.dart';

class ListTabView extends StatelessWidget {
  final List<Map<String, dynamic>> filteredSpots;
  final List<Map<String, dynamic>> allSpots;
  final bool isWantToGoMode;
  final Function(Map<String, dynamic>) onTapSpot;
  final VoidCallback onFilterTap;

  // フィルタ条件の表示用
  final String filterName;
  final String? filterGenre;
  final String? filterPrefecture;
  final double? filterMinRating;
  final VoidCallback onClearFilters;
  final Function(String) onGenreTap; // チップ用
  final Function(String) onPrefectureTap; // チップ用
  final Function(double) onRatingDelete; // チップ用

  const ListTabView({
    super.key,
    required this.filteredSpots,
    required this.allSpots,
    required this.isWantToGoMode,
    required this.onTapSpot,
    required this.onFilterTap,
    required this.filterName,
    required this.filterGenre,
    required this.filterPrefecture,
    required this.filterMinRating,
    required this.onClearFilters,
    required this.onGenreTap,
    required this.onPrefectureTap,
    required this.onRatingDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 130.0),
          child: filteredSpots.isEmpty
              ? Center(
                  child: Text(
                    allSpots.isEmpty
                        ? 'データがありません\nまずは登録しましょう！'
                        : '条件に合うお店がありません',
                  ),
                )
              : ListView.builder(
                  itemCount: filteredSpots.length,
                  padding: const EdgeInsets.only(bottom: 100),
                  itemBuilder: (context, index) {
                    final item = filteredSpots[index];
                    List<String> paths = List<String>.from(
                      item['image_paths'] ?? [],
                    );

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      elevation: 2,
                      child: ListTile(
                        visualDensity: VisualDensity.comfortable,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),

                        // 画像
                        leading: SizedBox(
                          width: 60,
                          height: 60,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: (paths.isNotEmpty)
                                ? Image.file(
                                    File(paths.first),
                                    fit: BoxFit.contain, // 全体表示
                                    cacheWidth: 200,
                                    errorBuilder: (c, o, s) => Container(
                                      color: Colors.grey[200],
                                      child: const Icon(
                                        Icons.broken_image,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  )
                                : Container(
                                    color: isWantToGoMode
                                        ? Colors.blue[100]
                                        : Colors.orange[100],
                                    child: Icon(
                                      Icons.restaurant,
                                      color: isWantToGoMode
                                          ? Colors.blue
                                          : Colors.orange,
                                    ),
                                  ),
                          ),
                        ),

                        // 店名
                        title: Text(
                          item['title'],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),

                        // サブ情報
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 6),
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8.0,
                              runSpacing: 4.0,
                              children: [
                                // 評価
                                if (!isWantToGoMode)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.star,
                                        size: 14,
                                        color: Colors.amber,
                                      ),
                                      Text(
                                        " ${item['rating'] ?? '-'}",
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ],
                                  ),

                                // ジャンルタグ（複数）
                                ...(item['genre'] as String)
                                    .split(',')
                                    .where((e) => e.trim().isNotEmpty)
                                    .map(
                                      (id) => GestureDetector(
                                        onTap: () => onGenreTap(id),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.orange[50],
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                            border: Border.all(
                                              color: Colors.orange.withOpacity(
                                                0.3,
                                              ),
                                            ),
                                          ),
                                          child: Text(
                                            GenreManager().getName(id),
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.orange[800],
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    )
                                    ,

                                // 都道府県
                                GestureDetector(
                                  onTap: () {
                                    if (item['prefecture'] != null &&
                                        item['prefecture']
                                            .toString()
                                            .isNotEmpty) {
                                      onPrefectureTap(item['prefecture']);
                                    }
                                  },
                                  child: Text(
                                    item['prefecture'] ?? '',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.blueGrey,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (item['recommended_menu'] != null &&
                                item['recommended_menu'].isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text(
                                  "🏆 ${item['recommended_menu']}",
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[700],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                        ),
                        onTap: () => onTapSpot(item),
                      ),
                    );
                  },
                ),
        ),

        // ヘッダー（検索ボタン）
        SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: InkWell(
                  onTap: onFilterTap,
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Container(
                      height: 50,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Icon(
                            Icons.search,
                            color: isWantToGoMode ? Colors.blue : Colors.orange,
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              "絞り込み検索 (店名、県、ジャンル)...",
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 16,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // フィルタチップ（共通部品として切り出しても良いですが、ここでは簡略化のため直書き）
              _buildFilterChips(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChips() {
    if (filterGenre == null &&
        filterPrefecture == null &&
        filterName.isEmpty &&
        filterMinRating == null) {
      return const SizedBox.shrink();
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Text(
            "絞り込み中: ",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: [Shadow(blurRadius: 2, color: Colors.black)],
            ),
          ),
          if (filterMinRating != null)
            Chip(
              label: Text("${filterMinRating!.toStringAsFixed(0)}点以上"),
              onDeleted: () => onRatingDelete(filterMinRating!),
            ),
          if (filterPrefecture != null)
            Chip(
              label: Text(filterPrefecture!),
              onDeleted: () => onPrefectureTap(filterPrefecture!),
            ), // 削除アクションとして再利用（nullにする処理は親側）
          if (filterGenre != null)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Chip(
                label: Text(GenreManager().getName(filterGenre!)),
                onDeleted: () => onGenreTap(filterGenre!),
              ),
            ),
          if (filterName.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Chip(
                label: Text("\"$filterName\""),
                onDeleted: onClearFilters,
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: ActionChip(
              label: const Text("クリア"),
              onPressed: onClearFilters,
            ),
          ),
        ],
      ),
    );
  }
}
