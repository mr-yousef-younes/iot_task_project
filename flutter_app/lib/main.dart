import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() => runApp(const IoTPulseApp());

class IoTPulseApp extends StatelessWidget {
  const IoTPulseApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        home: const PulseScannerScreen(),
        theme: ThemeData(primarySwatch: Colors.blue),
      );
}

class PulseScannerScreen extends StatefulWidget {
  const PulseScannerScreen({super.key});
  @override
  State<PulseScannerScreen> createState() => _PulseScannerScreenState();
}

class _PulseScannerScreenState extends State<PulseScannerScreen> {
  String status = "اضغط للبحث عن الحساس";
  int lastValue = 0;

 
  Future<void> sendToServer(int value) async {
    final url = Uri.parse('http://localhost:3000/readings');
    try {
      await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"value": value}),
      );
      debugPrint("تم إرسال القيمة $value بنجاح");
    } catch (e) {
      debugPrint("خطأ في الاتصال بالسيرفر: $e");
    }
  }

 
  void startScan() {
    setState(() => status = "جاري البحث عن أجهزة...");
    
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));

    FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult r in results) {
        // هنا يمكنك تحديد اسم جهازك ESP32
        if (r.device.platformName == "PulseSensor") { 
          setState(() {
            status = "تم العثور على الحساس: ${r.device.platformName}";
            lastValue = 85;
          });
          sendToServer(lastValue);
          FlutterBluePlus.stopScan();
          break;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("IoT Pulse Monitor")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(status, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 20),
            Text("$lastValue BPM", style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.red)),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: startScan,
              child: const Text("ابدأ المسح (Scan)"),
            ),
          ],
        ),
      ),
    );
  }
}