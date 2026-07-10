import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class WearableService {
  /// تحديث البيانات الصحية الخاصة بالساعة الذكية (أو الجهاز القابل للارتداء)
  static Future<Map<String, dynamic>> updateHealth(Map<String, dynamic> healthData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      // التأكد من وجود توكن صالح
      if (token == null || token.isEmpty) {
        return {
          'success': false, 
          'message': 'User is not authenticated (No token found)'
        };
      }

      // إرسال الطلب للسيرفر
      final response = await http.post(
        Uri.parse(ApiConfig.updateHealth),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(healthData),
      );

      // التأكد من أن السيرفر أعاد استجابة بصيغة JSON لتجنب أخطاء الـ Parsing
      Map<String, dynamic> responseData = {};
      try {
        responseData = jsonDecode(response.body);
      } catch (e) {
        debugPrint('Could not parse response: ${response.body}');
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'data': responseData,
        };
      } else {
        return {
          'success': false,
          'message': responseData['message'] ?? 'Failed to update health data (Status: ${response.statusCode})',
        };
      }
    } catch (e) {
      debugPrint('Error updating health data: $e');
      return {
        'success': false,
        'message': 'Network error occurred while updating health data.',
      };
    }
  }
}
