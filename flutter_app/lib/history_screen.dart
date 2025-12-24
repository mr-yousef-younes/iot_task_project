import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'service.dart';

class HistoryScreen extends StatefulWidget {
  final String userId;
  const HistoryScreen({super.key, required this.userId});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final ApiService _api = ApiService();
  bool _isLoading = true;
  List<dynamic> _history = [];

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    try {
      final data = await _api.getAllHistory(widget.userId);
      setState(() {
        _history = data ;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("خطأ في جلب السجل: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("سجل القراءات", style: GoogleFonts.cairo())),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _history.isEmpty
          ? const Center(child: Text("لا توجد سجلات بعد"))
          : ListView.builder(
              padding: const EdgeInsets.all(10),
              itemCount: _history.length,
              itemBuilder: (context, index) {
                final item = _history[index];
                // تنسيق التاريخ
                final date = DateTime.parse(
                  item['timestamp'] ?? DateTime.now().toString(),
                );
                final formattedDate = DateFormat(
                  'yyyy/MM/dd - hh:mm a',
                ).format(date);

                return Card(
                  elevation: 3,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: ListTile(
                    leading: const Icon(Icons.favorite, color: Colors.red),
                    title: Text("نبض القلب: ${item['heartRate']} BPM"),
                    subtitle: Text(
                      "حرارة: ${item['tempC']}°C | رطوبة: ${item['humidity']}%",
                    ),
                    trailing: Text(
                      formattedDate,
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
