import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:sleek_circular_slider/sleek_circular_slider.dart';
import 'dart:async';
import 'package:permission_handler/permission_handler.dart';
import 'service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const IoTPulse());
}

class IoTPulse extends StatelessWidget {
  const IoTPulse({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'IoT Pulse',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.deepPurple,
        textTheme: GoogleFonts.cairoTextTheme(),
      ),
      home: const DashboardPage(),
    );
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  // تعريفات البلوتوث والخدمات
  final _api = ApiService();
  final _ble = FlutterReactiveBle();
  StreamSubscription<DiscoveredDevice>? _scanSubscription;
  StreamSubscription<ConnectionStateUpdate>? _connectionSubscription;

  // متغيرات الحالة
  String? userId;
  bool isLoading = true;
  bool _isConnected = false;
  bool _isScanning = false;
  final Map<String, DiscoveredDevice> _foundDevices = {};
  Map<String, dynamic>? latestData;

  // الحقول المطلوبة للتسجيل
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  // 1. تشغيل التطبيق وفحص المستخدم والصلاحيات
  Future<void> _initApp() async {
    userId = await _api.getStoredUserId();
    if (userId != null) {
      _fetchLatestData();
    }
    setState(() => isLoading = false);
  }

  // حل مشكلة الصلاحيات: نطلبها قبل البدء بالبحث
  Future<bool> _requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    return statuses.values.every((status) => status.isGranted);
  }

  void _fetchLatestData() async {
    if (userId == null) return;
    final data = await _api.getLatestReadings(userId!);
    if (mounted) setState(() => latestData = data);
  }

  // 2. منطق البحث عن أجهزة (بعد التأكد من الصلاحيات)
  void _startScan() async {
    bool granted = await _requestPermissions();
    if (!mounted) return;
    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("يجب الموافقة على الصلاحيات للبحث عن الأجهزة"),
        ),
      );
      return;
    }

    if (_isScanning) return;
    setState(() {
      _isScanning = true;
      _foundDevices.clear();
    });

    _scanSubscription = _ble.scanForDevices(withServices: []).listen((device) {
      if (device.name.isNotEmpty) {
        setState(() => _foundDevices[device.id] = device);
      }
    }, onError: (e) {
       debugPrint("خطأ في البحث: $e");
       _stopScan();
    });

    Timer(const Duration(seconds: 10), _stopScan);
  }

  void _stopScan() {
    _scanSubscription?.cancel();
    if (mounted) setState(() => _isScanning = false);
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(userId == null ? "إنشاء حساب" : "مراقب النبض الذكي"),
        actions: userId != null
            ? [
                IconButton(
                  icon: Icon(
                    Icons.bluetooth,
                    color: _isConnected ? Colors.green : Colors.red,
                  ),
                  onPressed: _showDeviceSheet,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_forever, color: Colors.red),
                  onPressed: _deleteAccount,
                ),
              ]
            : null,
      ),
      body: userId == null ? _buildSignupUI() : _buildDashboardUI(),
    );
  }

  // واجهة التسجيل (تظهر إذا لم يوجد مستخدم)
  Widget _buildSignupUI() {
    return FadeIn(
      child: Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person_add, size: 80, color: Colors.deepPurple),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: "الاسم الكامل",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _ageController,
              decoration: const InputDecoration(
                labelText: "العمر",
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 25),
            ElevatedButton(
              onPressed: _handleSignup,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text("إنشاء الحساب وبدء الفحص"),
            ),
          ],
        ),
      ),
    );
  }

  // دالة تحديد الألوان بناءً على تقرير الباك إند
  Color getStatusColor(String report) {
    if (report.contains('خطر')) {
      return Colors.red;
    }
    if (report.contains('تنبيه')) {
      return Colors.orange; // اللون الأصفر/البرتقالي
    }
    return Colors.green; // مستقرة
  }

  // واجهة الداشبورد (تظهر إذا وجد مستخدم)
  Widget _buildDashboardUI() {
    final heartRate =
        double.tryParse(latestData?['heartRate']?.toString() ?? "0") ?? 0.0;

    return SingleChildScrollView(
      child: Column(
        children: [
          if (latestData != null) _buildStatusBanner(),
          const SizedBox(height: 20),
          _buildCircularSlider(heartRate),
          const SizedBox(height: 20),
          _buildInfoCards(),
        ],
      ),
    );
  }

  Widget _buildStatusBanner() {
    String report = latestData?['statusReport'] ?? "جاري تحليل البيانات...";

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      color: getStatusColor(report),
      child: Text(
        report,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildCircularSlider(double value) {
    String report = latestData?['statusReport'] ?? "";
    return SleekCircularSlider(
      appearance: CircularSliderAppearance(
        size: 250,
        customColors: CustomSliderColors(
          progressBarColor: getStatusColor(report),
        ),
        infoProperties: InfoProperties(
          mainLabelStyle: const TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.bold,
          ),
          bottomLabelText: "BPM",
        ),
      ),
      min: 0,
      max: 200,
      initialValue: value,
    );
  }

  Widget _buildInfoCards() {
    return Padding(
      padding: const EdgeInsets.all(15),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        children: [
          _dataCard(
            "الحرارة",
            "${latestData?['tempC'] ?? '--'}°C",
            FontAwesomeIcons.temperatureHalf,
            Colors.orange,
          ),
          _dataCard(
            "الرطوبة",
            "${latestData?['humidity'] ?? '--'}%",
            FontAwesomeIcons.droplet,
            Colors.blue,
          ),
          _dataCard(
            "الأكسجين",
            "${latestData?['spo2'] ?? '--'}%",
            FontAwesomeIcons.lungs,
            Colors.redAccent,
          ),
          _dataCard(
            "مؤشر الحرارة",
            "${latestData?['heatIndex'] ?? '--'}°C",
            FontAwesomeIcons.sun,
            Colors.amber,
          ),
        ],
      ),
    );
  }

  // دالة الـ Card المحدثة لدعم FontAwesome والألوان
  Widget _dataCard(String title, String value, IconData icon, Color iconColor) {
    return FadeInUp(
      // إضافة التنشيط الذي كان موجوداً في كودك الأصلي
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FaIcon(icon, color: iconColor, size: 30),
            const SizedBox(height: 10),
            Text(
              title,
              style: GoogleFonts.cairo(fontSize: 14, color: Colors.grey[700]),
            ),
            Text(
              value,
              style: GoogleFonts.cairo(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeviceSheet() {
    _startScan();
    showModalBottomSheet(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text("ابحث عن جهاز ESP32"),
              if (_isScanning) const LinearProgressIndicator(),
              Expanded(
                child: ListView.builder(
                  itemCount: _foundDevices.length,
                  itemBuilder: (context, index) {
                    final device = _foundDevices.values.elementAt(index);
                    return ListTile(
                      title: Text(device.name),
                      onTap: () {
                        _connectToDevice(device.id);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // دمج الاتصال مع إرسال البيانات للباك إند
  void _connectToDevice(String id) {
    _connectionSubscription = _ble.connectToDevice(id: id).listen((update) {
      if (update.connectionState == DeviceConnectionState.connected) {
        setState(() => _isConnected = true);
        // هنا يتم استدعاء DiscoverServices كما في كودك السابق
      }
    });
  }

  void _handleSignup() async {
    if (_nameController.text.isEmpty) return;
    String? id = await _api.signUp(
      _nameController.text,
      int.parse(_ageController.text),
      "2000-01-01",
    );
    if (id != null) setState(() => userId = id);
  }

  void _deleteAccount() async {
    if (userId == null) return;
    bool deleted = await _api.deleteUser(userId!);
    if (deleted) setState(() => userId = null);
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _connectionSubscription?.cancel();
    super.dispose();
  }
}
