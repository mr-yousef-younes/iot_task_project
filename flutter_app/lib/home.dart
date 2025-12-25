import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:iot_pulse/main.dart';
import 'package:provider/provider.dart';
import 'package:sleek_circular_slider/sleek_circular_slider.dart';
import 'dart:async';
import 'dart:typed_data';
import 'service.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

Timer? _timer;

class _DashboardPageState extends State<DashboardPage> {
  final _api = ApiService();
  final _ble = FlutterReactiveBle();
  final Uuid _envServiceUuid = Uuid.parse(
    "12345678-1234-1234-1234-1234567890ab",
  );
  final Uuid _envCharUuid = Uuid.parse("12345678-1234-1234-1234-1234567890ac");
  final Uuid _hrServiceUuid = Uuid.parse(
    "87654321-4321-4321-4321-ba0987654321",
  );
  final Uuid _hrCharUuid = Uuid.parse("87654321-4321-4321-4321-ba0987654322");
  StreamSubscription<DiscoveredDevice>? _scanSubscription;
  StreamSubscription<ConnectionStateUpdate>? _connectionSubscription;

  // متغيرات الحالة
  String? userId;
  bool isLoading = true;
  bool _isConnected = false;
  bool _isScanning = false;

  double _currentTemp = 0;
  double _currentHum = 0;
  int _currentRawHR = 0;
  Map<String, dynamic>? latestData;

  final Map<String, DiscoveredDevice> _foundDevices = {};
  StreamSubscription<List<int>>? _envSub;
  StreamSubscription<List<int>>? _hrSub;

  final _nameController = TextEditingController();
  final _ageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initApp();
    _ble.statusStream.listen((status) {
      if (status != BleStatus.ready && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("يرجى التأكد من تشغيل البلوتوث والموقع"),
          ),
        );
      }
    });
    Timer.periodic(const Duration(seconds: 5), (timer) {
      if (userId != null) _fetchLatestData();
    });
  }

  Future<void> _initApp() async {
    userId = await _api.getStoredUserId();
    if (userId != null) {
      _fetchLatestData();
    }
    setState(() => isLoading = false);
  }

  void _fetchLatestData() async {
    if (userId == null) return;
    final data = await _api.getLatestReadings(userId!);
    if (mounted) setState(() => latestData = data);
  }

  void _startScan() {
    if (_isScanning) return;
    setState(() {
      _isScanning = true;
      _foundDevices.clear();
    });

    _scanSubscription = _ble
        .scanForDevices(withServices: [])
        .listen(
          (device) {
            if (device.name.isNotEmpty) {
              setState(() => _foundDevices[device.id] = device);
            }
          },
          onError: (e) {
            debugPrint("خطأ في البحث: $e");
            _stopScan();
          },
        );

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
                  icon: const Icon(Icons.settings),
                  onPressed: () {
                    context.push('/settings');
                  },
                ),
                IconButton(
                  icon: Icon(
                    Icons.bluetooth,
                    color: _isConnected ? Colors.green : Colors.red,
                  ),
                  onPressed: _showDeviceSheet,
                ),
              ]
            : null,
      ),
      body: userId == null ? _buildSignupUI() : _buildDashboardUI(),
    );
  }

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
              onPressed: _isRegistering ? null : _handleSignup,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isRegistering
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text("إنشاء الحساب وبدء الفحص"),
            ),
          ],
        ),
      ),
    );
  }

  Color getStatusColor(String report) {
    if (report.contains('خطر')) {
      return Colors.red;
    }
    if (report.contains('تنبيه')) {
      return Colors.orange;
    }
    return Colors.green;
  }

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
          modifier: (double value) {
            if (_currentRawHR == -1) return 'لا توجد اشاره ';
            return '${value.toInt()}';
          },
          bottomLabelText: "BPM",
        ),
      ),
      min: 0,
      max: 200,
      initialValue: value,
    );
  }

  Widget _buildInfoCards() {
    final settings = Provider.of<AppSettings>(context);
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
            latestData?['tempC'] == null
                ? "جاري الاتصال..."
                : settings.isFahrenheit
                ? "${((double.tryParse(latestData!['tempC'].toString()) ?? 0) * 1.8 + 32).toStringAsFixed(1)}°F"
                : "${latestData!['tempC']}°C",
            FontAwesomeIcons.temperatureHalf,
            Colors.orange,
          ),

          _dataCard(
            "الرطوبة",
            latestData?['humidity'] == null
                ? "جاري الاتصال..."
                : "${latestData!['humidity']}%",
            FontAwesomeIcons.droplet,
            Colors.blue,
          ),

          _dataCard(
            "الأكسجين",
            (latestData?['spo2'] == null || latestData?['spo2'] == 0)
                ? "جاري الاتصال..."
                : "${latestData!['spo2']}%",
            FontAwesomeIcons.lungs,
            Colors.redAccent,
          ),

          _dataCard(
            "درجة الحرارة كأنها",
            latestData?['heatIndex'] == null
                ? "جاري الاتصال..."
                : "${latestData!['heatIndex']}°C",
            FontAwesomeIcons.sun,
            Colors.amber,
          ),
        ],
      ),
    );
  }

  Widget _dataCard(String title, String value, IconData icon, Color iconColor) {
    return FadeInUp(
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

  void _connectToDevice(String id) {
    _connectionSubscription = _ble.connectToDevice(id: id).listen((update) {
      if (update.connectionState == DeviceConnectionState.connected) {
        setState(() => _isConnected = true);
        _subscribeToData(id);
      }
    });
  }

  void _subscribeToData(String deviceId) {
    _envSub?.cancel();
    _hrSub?.cancel();
    _envSub = _ble
        .subscribeToCharacteristic(
          QualifiedCharacteristic(
            serviceId: _envServiceUuid,
            characteristicId: _envCharUuid,
            deviceId: deviceId,
          ),
        )
        .listen((data) {
          if (data.length >= 4) {
            final bytes = ByteData.sublistView(Uint8List.fromList(data));
            int rawTemp = bytes.getInt16(0, Endian.big);
            int rawHum = bytes.getInt16(2, Endian.big);
            setState(() {
              _currentTemp = (rawTemp == -999) ? -999 : rawTemp / 100.0;
              _currentHum = (rawHum == -999) ? -999 : rawHum / 100.0;
            });
            _syncToBackend();
          }
        });
    _hrSub = _ble
        .subscribeToCharacteristic(
          QualifiedCharacteristic(
            serviceId: _hrServiceUuid,
            characteristicId: _hrCharUuid,
            deviceId: deviceId,
          ),
        )
        .listen((data) {
          if (data.length >= 4) {
            final bytes = ByteData.sublistView(Uint8List.fromList(data));
            int rawHR = bytes.getInt32(0, Endian.big);
            setState(() => _currentRawHR = rawHR);
          }
        });
  }

  void _syncToBackend() {
    if (userId != null) {
      if (_currentRawHR != -1 && _currentTemp != -999) {
        _api.sendReadingToBackend(
          userId: userId!,
          heartRate: _currentRawHR.toDouble(),
          spo2: -1.0,
          temp: _currentTemp,
          humidity: _currentHum,
        );
        Future.delayed(
          const Duration(milliseconds: 750),
          () => _fetchLatestData(),
        );
      }
      _fetchLatestData();
    }
  }

  bool _isRegistering = false;

  void _handleSignup() async {
    if (_nameController.text.isEmpty || _ageController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("يرجى إكمال البيانات أولاً")),
      );
      return;
    }

    setState(() => _isRegistering = true); // ابدأ التحميل

    String? id = await _api.signUp(
      _nameController.text,
      int.parse(_ageController.text),
      "2000-01-01",
    );

    setState(() => _isRegistering = false); // توقف عن التحميل

    if (id != null) {
      setState(() => userId = id); // انتقل للداشبورد فوراً
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("فشل الاتصال بالسيرفر. تأكد من الـ IP والشبكة"),
        ),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _envSub?.cancel();
    _hrSub?.cancel();
    _scanSubscription?.cancel();
    _connectionSubscription?.cancel();
    super.dispose();
  }
}
