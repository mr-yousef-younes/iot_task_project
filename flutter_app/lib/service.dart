import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  final String baseUrl = "http://192.168.1.7:3000";
  DateTime? _lastSendTime;

  Future<void> saveUserId(String id, String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_id', id);

    List<String> allUsers = prefs.getStringList('all_users_data') ?? [];
    String userData = "$id|$name";

    if (!allUsers.contains(userData)) {
      allUsers.add(userData);
      await prefs.setStringList('all_users_data', allUsers);
    }
  }

  Future<List<Map<String, String>>> getAllUsers() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> rawList = prefs.getStringList('all_users_data') ?? [];

    return rawList.map((item) {
      final split = item.split('|');
      return {'id': split[0], 'name': split[1]};
    }).toList();
  }

  Future<String?> getStoredUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_id');
  }

  Future<String?> signUp(String name, int age) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/users/signup'),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "fullName": name,
              "age": age,
            }),
          )
          .timeout(const Duration(seconds: 5));

      if ((response.statusCode == 201 || response.statusCode == 200) &&
          response.body.isNotEmpty) {
        final data = jsonDecode(response.body);

        await saveUserId(data['_id'], name);
        return data['_id'];
      } else {
        debugPrint("Server Error: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      debugPrint("Network Error: $e");
    }
    return null;
  }

  // 3. جلب آخر القراءات والتقرير الطبي
  Future<Map<String, dynamic>?> getLatestReadings(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/readings/latest?userId=$userId'),
      );

      if (response.statusCode == 200) {
        if (response.body.isNotEmpty) {
          return jsonDecode(response.body);
        } else {
          debugPrint("Server returned empty body for latest readings");
          return null; // أو {} حسب ما التطبيق محتاج
        }
      } else {
        debugPrint("Server Error: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Fetch Error: $e");
    }
    return null;
  }

  // 4. حذف المستخدم
  Future<bool> deleteUser(String userId) async {
    try {
      final response = await http.delete(Uri.parse('$baseUrl/users/$userId'));
      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('user_id');
        return true;
      }
    } catch (e) {
      debugPrint("Delete Error: $e");
    }
    return false;
  }

  Future<void> sendReadingToBackend({
    required String userId,
    required double heartRate,
    required double spo2,
    required double temp,
    required double humidity,
  }) async {
    if (_lastSendTime != null &&
        DateTime.now().difference(_lastSendTime!).inSeconds < 15) {
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/readings'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "userId": userId,
          "heartRate": heartRate,
          "spo2": spo2,
          "tempC": temp,
          "humidity": humidity,
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        _lastSendTime = DateTime.now(); // تحديث الوقت عند النجاح فقط
      }
    } catch (e) {
      debugPrint("Error sending to backend: $e");
    }
  }

  Future<List<dynamic>> getAllHistory(String userId) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/readings/all?userId=$userId'))
          .timeout(
            const Duration(seconds: 5),
          ); // إضافة وقت انتظار لتجنب التعليق

      // الحل هنا: فحص الحالة ومحتوى الاستجابة قبل التحويل
      if (response.statusCode == 200) {
        if (response.body.isNotEmpty && response.body != "null") {
          return jsonDecode(response.body);
        } else {
          debugPrint("Server returned empty list");
          return []; // إرجاع قائمة فارغة بدلاً من وقوع الخطأ
        }
      } else {
        debugPrint("Server Error: ${response.statusCode}");
        return [];
      }
    } catch (e) {
      debugPrint("Network Error: $e");
      return [];
    }
  }
}
