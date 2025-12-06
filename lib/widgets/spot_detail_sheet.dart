import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:my_food_map/genre_manager.dart';
import 'package:my_food_map/widgets/star_rating.dart';

class SpotDetailSheet extends StatelessWidget {
  final Map<String, dynamic> spot;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  // ★追加: 「行った」リストへ移行するためのコールバック
  final VoidCallback? onConvertToVisited;
  final Function(String genreId)? onGenreTap;
  final Function(String prefecture)? onPrefectureTap;

  const SpotDetailSheet({
    super.key,
    required this.spot,
    required this.onEdit,
    required this.onDelete,
    this.onConvertToVisited, // ★追加
    this.onGenreTap,
    this.onPrefectureTap,
  });

  Future<void> _openGoogleMap(BuildContext context) async {
    final lat = spot['latitude'];
    final lng = spot['longitude'];
    final title = spot['title'];
    final address = spot['address'];
    String query;
    if (title != null && title.isNotEmpty && title != '名無し') {
      if (address != null && address.isNotEmpty) {
        query = '$title $address';
      } else {
        query = title;
      }
    } else {
      query = '$lat,$lng';
    }
    final Uri url = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': query,
    });
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw 'Could not launch $url';
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("マップを開けませんでした: $e")));
      }
    }
  }

  void _shareSpot() {
    final title = spot['title'];
    final firstGenre = (spot['genre'] as String).split(',').first;
    final genreName = GenreManager().getName(firstGenre);
    final address = spot['address'] ?? '住所不明';
    final comment = spot['comment'] ?? '';
    final mapLink =
        'http://googleusercontent.com/maps.google.com/?q=${spot['latitude']},${spot['longitude']}';
    final text =
        '【$title】\nジャンル: $genreName\n住所: $address\nメモ: $comment\n\n場所を確認:\n$mapLink';
    Share.share(text);
  }

  @override
  Widget build(BuildContext context) {
    List<String> imagePaths = List<String>.from(spot['image_paths'] ?? []);
    final isWantToGo = (spot['is_want_to_go'] ?? 0) == 1;
    final genreIds = (spot['genre'] as String)
        .split(',')
        .where((e) => e.trim().isNotEmpty)
        .toList();

    return DraggableScrollableSheet(
      expand: false,
      builder: (context, scrollController) => SingleChildScrollView(
        controller: scrollController,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    spot['title'],
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            // --- ボタン列 ---
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _openGoogleMap(context),
                    icon: const Icon(Icons.map, size: 18),
                    label: const Text("マップ"),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _shareSpot,
                    icon: const Icon(Icons.share, size: 18),
                    label: const Text("共有"),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: onEdit,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: onDelete,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // ★追加: 「行ってみたい」リストの場合、「行った！」ボタンを表示
            if (isWantToGo)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onConvertToVisited,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange, // 目立つ色
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.check_circle_outline, size: 24),
                  label: const Text(
                    "このお店に行った！ (レビュー登録)",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),

            const Divider(height: 30),

            if (!isWantToGo) ...[
              Row(
                children: [
                  StarRating(rating: spot['rating'] ?? 0.0, isReadOnly: true),
                  const SizedBox(width: 8),
                  Text(
                    (spot['rating'] ?? 0.0).toString(),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],

            if (!isWantToGo && imagePaths.isNotEmpty)
              Container(
                height: 350,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: PageView.builder(
                    itemCount: imagePaths.length,
                    itemBuilder: (context, index) {
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => FullScreenImageViewer(
                                imagePaths: imagePaths,
                                initialIndex: index,
                              ),
                              fullscreenDialog: true,
                            ),
                          );
                        },
                        child: Image.file(
                          File(imagePaths[index]),
                          fit: BoxFit.contain,
                          cacheWidth: 800,
                          errorBuilder: (c, o, s) => const Center(
                            child: Icon(
                              Icons.broken_image,
                              color: Colors.grey,
                              size: 40,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

            const SizedBox(height: 20),

            Wrap(
              spacing: 8,
              children: [
                ...genreIds.map(
                  (id) => ActionChip(
                    label: Text(GenreManager().getName(id)),
                    onPressed: () => onGenreTap?.call(id),
                    backgroundColor: Colors.orange[50],
                    labelStyle: TextStyle(
                      color: Colors.orange[900],
                      fontWeight: FontWeight.bold,
                    ),
                    side: BorderSide(color: Colors.orange.withOpacity(0.3)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),

                if (spot['prefecture'] != null && spot['prefecture'].isNotEmpty)
                  ActionChip(
                    avatar: const Icon(Icons.location_on, size: 16),
                    label: Text(spot['prefecture']),
                    onPressed: () => onPrefectureTap?.call(spot['prefecture']),
                    backgroundColor: Colors.grey[200],
                    shape: const StadiumBorder(),
                  ),
              ],
            ),

            if (spot['address'] != null && spot['address'].isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  spot['address'],
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),

            const Divider(),

            if (spot['recommended_menu'] != null &&
                spot['recommended_menu'].isNotEmpty) ...[
              Text(
                isWantToGo ? "🍽️ 気になるメニュー" : "🏆 イチオシメニュー",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isWantToGo ? Colors.blue : Colors.orange,
                ),
              ),
              Text(
                spot['recommended_menu'],
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 10),
            ],

            const Text("📝 メモ", style: TextStyle(fontWeight: FontWeight.bold)),
            Text(spot['comment'] ?? '', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

class FullScreenImageViewer extends StatelessWidget {
  final List<String> imagePaths;
  final int initialIndex;
  const FullScreenImageViewer({
    super.key,
    required this.imagePaths,
    required this.initialIndex,
  });
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      extendBodyBehindAppBar: true,
      body: PageView.builder(
        itemCount: imagePaths.length,
        controller: PageController(initialPage: initialIndex),
        itemBuilder: (context, index) {
          return Center(
            child: InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.file(File(imagePaths[index]), fit: BoxFit.contain),
            ),
          );
        },
      ),
    );
  }
}
