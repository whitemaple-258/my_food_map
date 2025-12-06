import 'package:flutter/material.dart';
import 'dart:math';

class CustomTabBar extends StatefulWidget {
  final int selectedIndex;
  final bool isWantToGoMode;
  final bool showReminderAlert; // ★これが必要です
  final Function(int) onTap;
  final VoidCallback onLongPress;

  const CustomTabBar({
    super.key,
    required this.selectedIndex,
    required this.isWantToGoMode,
    required this.showReminderAlert, // ★これが必要です
    required this.onTap,
    required this.onLongPress,
  });

  @override
  State<CustomTabBar> createState() => _CustomTabBarState();
}

class _CustomTabBarState extends State<CustomTabBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    if (widget.showReminderAlert) {
      _startShaking();
    }
  }

  @override
  void didUpdateWidget(CustomTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showReminderAlert && !oldWidget.showReminderAlert) {
      _startShaking();
    } else if (!widget.showReminderAlert) {
      _controller.stop();
      _controller.reset();
    }
  }

  void _startShaking() {
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = widget.isWantToGoMode
        ? const Color(0xFF64B5F6)
        : const Color(0xFFFFB74D);

    return GestureDetector(
      onLongPress: widget.onLongPress,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          Container(
            decoration: const BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 10,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: BottomNavigationBar(
              currentIndex: widget.selectedIndex,
              onTap: widget.onTap,
              backgroundColor: themeColor,
              selectedItemColor: Colors.white,
              unselectedItemColor: Colors.white70,
              selectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
              type: BottomNavigationBarType.fixed,
              items: [
                BottomNavigationBarItem(
                  icon: const Icon(Icons.map),
                  label: widget.isWantToGoMode ? '行きたい' : '行った',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.list),
                  label: 'リスト',
                ),
                BottomNavigationBarItem(
                  icon: widget.showReminderAlert
                      ? AnimatedBuilder(
                          animation: _controller,
                          builder: (context, child) {
                            return Transform.rotate(
                              angle: sin(_controller.value * 2 * pi) * 0.1,
                              child: const Icon(
                                Icons.notifications_active,
                                color: Colors.redAccent,
                              ),
                            );
                          },
                        )
                      : const Icon(Icons.notifications_none),
                  label: '期限',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.settings),
                  label: '設定',
                ),
              ],
            ),
          ),
          if (widget.showReminderAlert)
            Positioned(
              bottom: 75,
              left: MediaQuery.of(context).size.width * 0.4,
              child: _buildBubble(),
            ),
        ],
      ),
    );
  }

  Widget _buildBubble() {
    return Column(
      // ★修正：右寄せにして、尻尾をアイコンの頭上に合わせる
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.redAccent,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: const Text(
            "期限が近いです！",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        // ★修正：尻尾の位置をパディングで微調整
        Padding(
          padding: const EdgeInsets.only(right: 24.0), // アイコンの真上に来るように調整
          child: ClipPath(
            clipper: _TriangleClipper(),
            child: Container(color: Colors.redAccent, height: 8, width: 10),
          ),
        ),
      ],
    );
  }
}

class _TriangleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, 0);
    path.lineTo(size.width / 2, size.height);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
