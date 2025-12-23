import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  HomeScreenState createState() => HomeScreenState();
}


class HomeScreenState extends State<HomeScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();

  String? userId;
  Map<String, dynamic>? latestData;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkUserStatus();
  }

  void _checkUserStatus() async {
    String? id = await _api.getStoredUserId();
    if (id != null) {
      _loadData(id);
    } else {
      setState(() => isLoading = false);
    }
  }

  void _loadData(String id) async {
    final data = await _api.getLatestReadings(id);
    setState(() {
      userId = id;
      latestData = data;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("IoT Health Tracker"),
        actions: userId != null 
          ? [IconButton(icon: Icon(Icons.delete, color: Colors.red), onPressed: _deleteAccount)] 
          : null,
      ),
      body: isLoading 
        ? Center(child: CircularProgressIndicator())
        : userId == null ? _buildSignupUI() : _buildDashboardUI(),
    );
  }

  // واجهة التسجيل
  Widget _buildSignupUI() {
    return Padding(
      padding: EdgeInsets.all(20),
      child: Column(
        children: [
          TextField(controller: _nameController, decoration: InputDecoration(labelText: "Full Name")),
          TextField(controller: _ageController, decoration: InputDecoration(labelText: "Age"), keyboardType: TextInputType.number),
          SizedBox(height: 20),
          ElevatedButton(onPressed: _handleSignup, child: Text("Create Account"))
        ],
      ),
    );
  }

  // واجهة البيانات (Dashboard)
  Widget _buildDashboardUI() {
    if (latestData == null) return Center(child: Text("Waiting for Sensor Data..."));

    return Column(
      children: [
        // صندوق التقرير الطبي الملون
        Container(
          width: double.infinity,
          margin: EdgeInsets.all(15),
          padding: EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: latestData!['statusReport'].contains('خطر') ? Colors.red : Colors.green,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            latestData!['statusReport'],
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ),
        // عرض البيانات
        Expanded(
          child: GridView.count(
            crossAxisCount: 2,
            children: [
              _dataCard("BPM", "${latestData!['heartRate']}", Icons.favorite),
              _dataCard("SpO2", "${latestData!['spo2']}%", Icons.bloodtype),
              _dataCard("Temp", "${latestData!['tempC']}°C", FontAwesomeIcons.temperatureHigh),
              _dataCard("Heat Index", "${latestData!['heatIndex']}°C", Icons.thermostat),
            ],
          ),
        ),
      ],
    );
  }

  Widget _dataCard(String title, String value, IconData icon) {
    return Card(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [Icon(icon, size: 40), Text(title), Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))],
      ),
    );
  }

  void _handleSignup() async {
    String? id = await _api.signUp(_nameController.text, int.parse(_ageController.text), "2000-01-01");
    if (id != null) _checkUserStatus();
  }

  void _deleteAccount() async {
    bool success = await _api.deleteUser(userId!);
    if (success) setState(() { userId = null; latestData = null; });
  }
}