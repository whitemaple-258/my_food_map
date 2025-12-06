import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:my_food_map/db_helper.dart';

class ReminderScreen extends StatefulWidget {
  const ReminderScreen({super.key});

  @override
  State<ReminderScreen> createState() => _ReminderScreenState();
}

class _ReminderScreenState extends State<ReminderScreen> {
  List<Map<String, dynamic>> _reminders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReminders();
  }

  Future<void> _loadReminders() async {
    final data = await DBHelper().getReminders();
    setState(() {
      _reminders = data;
      _isLoading = false;
    });
  }

  Future<void> _addReminder() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const ReminderFormDialog(),
    );
    if (result == true) {
      _loadReminders();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("リマインドを登録しました！")));
    }
  }

  Future<void> _deleteReminder(int id) async {
    await DBHelper().deleteReminder(id);
    _loadReminders();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("削除しました")));
    }
  }

  // 残り日数を計算して色とテキストを返す
  Map<String, dynamic> _getDeadlineInfo(String deadlineStr, int alertDays) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final deadline = DateTime.parse(deadlineStr);
    final diff = deadline.difference(today).inDays;

    if (diff < 0) {
      return {
        'text': '期限切れ',
        'color': Colors.grey,
        'icon': Icons.error_outline,
      };
    } else if (diff == 0) {
      return {'text': '今日まで！', 'color': Colors.red, 'icon': Icons.warning};
    } else if (diff <= alertDays) {
      // ★修正：個別の設定日数以下なら赤
      return {
        'text': 'あと $diff 日',
        'color': Colors.redAccent,
        'icon': Icons.timer,
      };
    } else if (diff <= 7) {
      return {
        'text': 'あと $diff 日',
        'color': Colors.orange,
        'icon': Icons.timer,
      };
    } else {
      return {
        'text': 'あと $diff 日',
        'color': Colors.green,
        'icon': Icons.calendar_today,
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: const Text(
                "期間限定・クーポン管理",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const Divider(height: 1),

            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _reminders.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.event_available,
                            size: 60,
                            color: Colors.grey[300],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            "登録されたリマインドはありません",
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _reminders.length,
                      itemBuilder: (context, index) {
                        final item = _reminders[index];
                        // DBから個別の通知設定を取得（なければデフォルト3日）
                        final int alertDays = item['alert_days'] ?? 3;

                        final info = _getDeadlineInfo(
                          item['deadline'],
                          alertDays,
                        );
                        final dateStr = DateFormat(
                          'yyyy/MM/dd(E)',
                          'ja',
                        ).format(DateTime.parse(item['deadline']));

                        return Dismissible(
                          key: Key(item['id'].toString()),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            color: Colors.red,
                            child: const Icon(
                              Icons.delete,
                              color: Colors.white,
                            ),
                          ),
                          onDismissed: (_) => _deleteReminder(item['id']),
                          child: Card(
                            elevation: 3,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              leading: CircleAvatar(
                                backgroundColor: (info['color'] as Color)
                                    .withOpacity(0.1),
                                child: Icon(
                                  info['icon'] as IconData,
                                  color: info['color'] as Color,
                                ),
                              ),
                              title: Text(
                                item['title'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(
                                    "期限: $dateStr",
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  // 通知設定も表示しておくと親切
                                  Text(
                                    "通知: $alertDays日前から",
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  if (item['memo'] != null &&
                                      item['memo'].toString().isNotEmpty)
                                    Text(
                                      "📝 ${item['memo']}",
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                ],
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: (info['color'] as Color),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  info['text'],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 60),
        child: FloatingActionButton.extended(
          onPressed: _addReminder,
          label: const Text("期限を追加"),
          icon: const Icon(Icons.add_alarm),
          backgroundColor: Colors.teal[300],
        ),
      ),
    );
  }
}

// --- 登録用ダイアログ (修正版) ---
class ReminderFormDialog extends StatefulWidget {
  const ReminderFormDialog({super.key});
  @override
  State<ReminderFormDialog> createState() => _ReminderFormDialogState();
}

class _ReminderFormDialogState extends State<ReminderFormDialog> {
  final _titleController = TextEditingController();
  final _memoController = TextEditingController();
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 7));
  int _alertDays = 3; // ★追加：デフォルト3日前

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      locale: const Locale('ja'),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _save() async {
    if (_titleController.text.isEmpty) return;

    await DBHelper().insertReminder({
      'title': _titleController.text,
      'deadline': DateFormat('yyyy-MM-dd').format(_selectedDate),
      'memo': _memoController.text,
      'created_at': DateTime.now().toString(),
      'alert_days': _alertDays, // ★追加：保存
    });

    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("期限の登録"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: "内容 (例: 期間限定ラーメン)",
                icon: Icon(Icons.label),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today, color: Colors.blue),
              title: Text(
                "期限日: ${DateFormat('yyyy/MM/dd').format(_selectedDate)}",
              ),
              trailing: const Text(
                "変更",
                style: TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: _pickDate,
            ),

            // ★追加：通知タイミングの設定
            DropdownButtonFormField<int>(
              initialValue: _alertDays,
              decoration: const InputDecoration(
                icon: Icon(Icons.notifications_active),
                labelText: "いつから通知(アイコン振動)する？",
              ),
              items: const [
                DropdownMenuItem(value: 1, child: Text("1日前 (前日) から")),
                DropdownMenuItem(value: 3, child: Text("3日前から")),
                DropdownMenuItem(value: 7, child: Text("1週間前から")),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _alertDays = val);
              },
            ),

            const SizedBox(height: 8),
            TextField(
              controller: _memoController,
              decoration: const InputDecoration(
                labelText: "メモ (クーポンコードなど)",
                icon: Icon(Icons.note),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("キャンセル"),
        ),
        ElevatedButton(onPressed: _save, child: const Text("登録")),
      ],
    );
  }
}
