import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:go_router/go_router.dart';
import 'package:iot_pulse/main.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final ApiService _api = ApiService();
  List<Map<String, String>> _users = [];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  void _loadUsers() async {
    final users = await _api.getAllUsers();
    setState(() => _users = users);
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<AppSettings>(context);
    return Scaffold(
      appBar: AppBar(title: const Text("الإعدادات والتقارير")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: SwitchListTile(
              title: const Text("وحدة قياس الحرارة"),
              subtitle: Text(
                settings.isFahrenheit ? "فهرنهايت (°F)" : "سيليزيوس (°C)",
              ),
              secondary: const Icon(Icons.thermostat),
              value: settings.isFahrenheit,
              onChanged: (bool newValue) {
                settings.toggleUnit(newValue);
              },
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: ExpansionTile(
              leading: const Icon(Icons.group),
              title: const Text("تبديل الحساب"),
              children: [
                ..._users.map(
                  (user) => ListTile(
                    title: Text(user['name']!),
                    trailing: const Icon(Icons.login),
                    onTap: () async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setString('user_id', user['id']!);
                      settings.setUserId(user['id']!);
                      if (!context.mounted) return;
                      Navigator.pop(context);
                    },
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.add_circle, color: Colors.green),
                  title: const Text("إضافة حساب جديد"),
                  onTap: () {
                    settings.setUserId(
                      null,
                    ); // مسح المعرف الحالي من الـ Provider
                    context.go('/'); // العودة لشاشة الـ Signup
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _buildActionButton(
            title: "عرض سجل القراءات",
            icon: Icons.history,
            color: Colors.blue,
            onTap: () {
              if (settings.userId != null) {
                context.push('/history/${settings.userId}');
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("يرجى تسجيل الدخول أولاً")),
                );
              }
            },
          ),
          _buildActionButton(
            title: "تصدير التقرير الطبي (PDF)",
            icon: Icons.picture_as_pdf,
            color: Colors.red,
            onTap: () => _generatePdfReport(settings),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text(
              "حذف الحساب الحالي",
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            subtitle: const Text("سيتم مسح سجل القراءات والبيانات الشخصية"),
            onTap: () => _handleDeleteAccount(settings),
          ),
        ],
      ),
    );
  }

  Future<void> _generatePdfReport(AppSettings settings) async {
    if (settings.userId == null) return;

    final List<dynamic> history = await _api.getAllHistory(settings.userId!);

    final pdf = pw.Document();
    final arabicFont = await PdfGoogleFonts.cairoRegular();
    final arabicFontBold = await PdfGoogleFonts.cairoBold();

    final String userName = _users.firstWhere(
      (u) => u['id'] == settings.userId,
      orElse: () => {'name': 'مستخدم غير معروف'},
    )['name']!;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      "IoT Pulse Report",
                      style: pw.TextStyle(font: arabicFontBold, fontSize: 20),
                    ),
                    pw.Text(
                      "تقرير طبي ذكي",
                      style: pw.TextStyle(font: arabicFontBold, fontSize: 20),
                    ),
                  ],
                ),
                pw.Divider(),
                pw.SizedBox(height: 20),
                pw.Text(
                  "اسم المريض: $userName",
                  style: pw.TextStyle(font: arabicFont, fontSize: 16),
                ),
                pw.Text(
                  "كود المستخدم: ${settings.userId}",
                  style: pw.TextStyle(font: arabicFont, fontSize: 14),
                ),
                pw.Text(
                  "تاريخ التقرير: ${DateTime.now().toString().split(' ')[0]}",
                  style: pw.TextStyle(font: arabicFont),
                ),
                pw.SizedBox(height: 30),
                pw.TableHelper.fromTextArray(
                  context: context,
                  cellStyle: pw.TextStyle(font: arabicFont),
                  headerStyle: pw.TextStyle(
                    font: arabicFontBold,
                    color: PdfColors.white,
                  ),
                  headerDecoration: const pw.BoxDecoration(
                    color: PdfColors.deepPurple,
                  ),
                  data: <List<String>>[
                    ['التاريخ', 'الرطوبة', 'الحرارة', 'النبض'],
                    ...history.map(
                      (item) => [
                        item['timestamp'].toString().substring(0, 10),
                        '${item['humidity']}%',
                        '${item['tempC']}°C',
                        '${item['heartRate']} BPM',
                      ],
                    ),
                  ],
                ),
                pw.Spacer(),
                pw.Align(
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    "تم استخراج هذا التقرير بواسطة تطبيق IoT Pulse",
                    style: pw.TextStyle(
                      font: arabicFont,
                      fontSize: 10,
                      color: PdfColors.grey700,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Report_${settings.userId}.pdf',
    );
  }

  void _handleDeleteAccount(AppSettings settings) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("حذف الحساب"),
        content: const Text(
          "هل أنت متأكد من حذف حسابك نهائياً؟ سيتم مسح جميع بياناتك من السيرفر.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("إلغاء"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("نعم، احذف", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true && settings.userId != null) {
      bool deleted = await _api.deleteUser(settings.userId!);
      if (deleted) {
        settings.setUserId(null);
        if (mounted) {
          context.go('/');
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("فشل حذف الحساب، تأكد من الاتصال بالسيرفر"),
            ),
          );
        }
      }
    }
  }

  Widget _buildActionButton({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}
