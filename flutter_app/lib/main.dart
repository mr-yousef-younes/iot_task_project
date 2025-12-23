import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:sleek_circular_slider/sleek_circular_slider.dart';
import 'dart:convert';
import 'dart:async';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const IoTPulseApp());
}

class IoTPulseApp extends StatelessWidget {
  const IoTPulseApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'IoT Pulse Monitor',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.redAccent,
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
  // أضف هذه الدالة كاملة لتصحيح الخطأ في onPressed
  void _showDeviceSheet() {
    _startScan(); // يبدأ البحث عند فتح القائمة
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: const EdgeInsets.all(16),
              height: 400,
              child: Column(
                children: [
                  Text(
                    "الأجهزة المكتشفة",
                    style: GoogleFonts.cairo(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_isScanning) const LinearProgressIndicator(),
                  const Divider(),
                  Expanded(
                    child: _foundDevices.isEmpty
                        ? Center(
                            child: Text(
                              "جاري البحث...",
                              style: GoogleFonts.cairo(),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _foundDevices.length,
                            itemBuilder: (context, index) {
                              final device = _foundDevices.values.elementAt(
                                index,
                              );
                              return ListTile(
                                leading: const Icon(Icons.bluetooth),
                                title: Text(
                                  device.name.isEmpty
                                      ? "جهاز مجهول"
                                      : device.name,
                                ),
                                subtitle: Text(device.id),
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
            );
          },
        );
      },
    );
  }

  final Map<String, DiscoveredDevice> _foundDevices = {};
  bool _isScanning = false;
  final _ble = FlutterReactiveBle();
  StreamSubscription<DiscoveredDevice>? _scanSubscription;
  StreamSubscription<ConnectionStateUpdate>? _connectionSubscription;
  StreamSubscription<List<int>>? _envSubscription;
  StreamSubscription<List<int>>? _hrSubscription;

  bool _isConnected = false;
  String _heartRate = "0";
  String _temp = "--";
  String _hum = "--";
  String _heatIndex = "--";

  final String _backendUrl = "http://<SERVER_IP>:3000/sensor-data";

  final Uuid envServiceUuid = Uuid.parse(
    "12345678-1234-1234-1234-1234567890ab",
  );
  final Uuid envCharUuid = Uuid.parse("12345678-1234-1234-1234-1234567890ac");
  final Uuid hrServiceUuid = Uuid.parse("87654321-4321-4321-4321-ba0987654321");
  final Uuid hrCharUuid = Uuid.parse("87654321-4321-4321-4321-ba0987654322");

  Future<void> requestPermissions() async {
    await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
      Permission.locationWhenInUse,
      Permission.locationAlways,
      Permission.bluetoothAdvertise,
    ].request();
  }

  @override
  void initState() {
    super.initState();
    requestPermissions();
  }

  void _startScan() {
    if (_isScanning) return;
    setState(() {
      _isScanning = true;
      _foundDevices.clear(); // تنظيف القائمة القديمة
    });

    // البحث وتخزين الأجهزة في الـ Map
    _scanSubscription = _ble.scanForDevices(withServices: []).listen((device) {
      if (device.name.isNotEmpty) {
        setState(() {
          _foundDevices[device.id] = device;
        });
      }
    }, onError: (e) => _stopScan());

    // مؤقت لإيقاف البحث بعد 10 ثواني
    Timer(const Duration(seconds: 10), _stopScan);
  }

  void _stopScan() {
    _scanSubscription?.cancel();
    if (mounted) setState(() => _isScanning = false);
  }

  void _connectToDevice(String deviceId) {
    _connectionSubscription = _ble
        .connectToDevice(id: deviceId)
        .listen(
          (update) {
            if (update.connectionState == DeviceConnectionState.connected) {
              setState(() => _isConnected = true);
              _discoverServices(deviceId);
            } else {
              setState(() => _isConnected = false);
            }
          },
          onError: (e) {
            setState(() => _isConnected = false);
          },
        );
  }

  void _discoverServices(String deviceId) {
    final envQualified = QualifiedCharacteristic(
      deviceId: deviceId,
      serviceId: envServiceUuid,
      characteristicId: envCharUuid,
    );
    final hrQualified = QualifiedCharacteristic(
      deviceId: deviceId,
      serviceId: hrServiceUuid,
      characteristicId: hrCharUuid,
    );

    _envSubscription = _ble
        .subscribeToCharacteristic(envQualified)
        .listen(
          (value) {
            if (value.isNotEmpty) {
              try {
                final decoded = utf8.decode(value);
                final Map<String, dynamic> j = jsonDecode(decoded);

                setState(() {
                  _temp = j['tempC'] != null ? j['tempC'].toString() : "--";
                  _hum = j['hum'] != null ? j['hum'].toString() : "--";
                  _heatIndex = j['heatIndexC'] != null
                      ? j['heatIndexC'].toString()
                      : "--";
                });

                _sendDataToBackend(
                  heart: _heartRate,
                  temp: _temp,
                  hum: _hum,
                  heatIndex: _heatIndex,
                );
              } catch (e) {
                debugPrint("Error parsing ENV data: $e");
              }
            }
          },
          onError: (e) {
            debugPrint("ENV subscription error: $e");
          },
        );

    _hrSubscription = _ble
        .subscribeToCharacteristic(hrQualified)
        .listen(
          (value) {
            if (value.isNotEmpty) {
              try {
                final decoded = utf8.decode(value);
                setState(() => _heartRate = decoded);

                _sendDataToBackend(
                  heart: _heartRate,
                  temp: _temp,
                  hum: _hum,
                  heatIndex: _heatIndex,
                );
              } catch (e) {
                debugPrint("Error parsing HR data: $e");
              }
            }
          },
          onError: (e) {
            debugPrint("HR subscription error: $e");
          },
        );
  }

  Future<void> _sendDataToBackend({
    required String heart,
    required String temp,
    required String hum,
    required String heatIndex,
  }) async {
    final payload = {
      "deviceId": "ESP32_S3_01",
      "timestamp": DateTime.now().toIso8601String(),
      "heart": heart,
      "tempC": temp,
      "hum": hum,
      "heatIndexC": heatIndex,
    };
    try {
      await http.post(
        Uri.parse(_backendUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      );
    } catch (e) {
      debugPrint("Backend send error: $e");
    }
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _connectionSubscription?.cancel();
    _envSubscription?.cancel();
    _hrSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double heartRateNum = double.tryParse(_heartRate) ?? 0;
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          "مراقب النبض الذكي",
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _showDeviceSheet,
            icon: Icon(
              _isConnected
                  ? Icons.bluetooth_connected
                  : (_isScanning ? Icons.sync : Icons.bluetooth_searching),
              color: _isConnected
                  ? Colors.green
                  : (_isScanning ? Colors.blue : Colors.red),
            ),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            FadeInDown(
              child: SleekCircularSlider(
                min: 0,
                max: 180,
                initialValue: heartRateNum,
                appearance: CircularSliderAppearance(
                  size: 260,
                  startAngle: 135,
                  angleRange: 270,
                  customColors: CustomSliderColors(
                    trackColor: Colors.grey.shade300,
                    progressBarColor: heartRateNum < 60
                        ? Colors.blue
                        : heartRateNum < 100
                        ? Colors.green
                        : Colors.red,
                    dotColor: Colors.transparent,
                  ),
                  infoProperties: InfoProperties(
                    modifier: (value) => _heartRate,
                    mainLabelStyle: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                    ),
                    bottomLabelText: 'BPM',
                    bottomLabelStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: FadeInUp(
                child: Card(
                  elevation: 5,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: ListTile(
                    leading: FaIcon(
                      FontAwesomeIcons.temperatureHalf,
                      color: _isConnected ? Colors.orange : Colors.grey,
                      size: 30,
                    ),
                    title: Text(
                      _isConnected ? "Connected" : "Searching...",
                      style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 6),
                        Text(
                          "Heart: $_heartRate BPM",
                          style: GoogleFonts.cairo(),
                        ),
                        Text("Temp: $_temp °C", style: GoogleFonts.cairo()),
                        Text("Humidity: $_hum %", style: GoogleFonts.cairo()),
                        Text(
                          "HeatIndex: $_heatIndex °C",
                          style: GoogleFonts.cairo(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (_isConnected)
              Pulse(
                infinite: true,
                duration: const Duration(milliseconds: 800),
                child: const FaIcon(
                  FontAwesomeIcons.solidHeart,
                  color: Colors.red,
                  size: 50,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
