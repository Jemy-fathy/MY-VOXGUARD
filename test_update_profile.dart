import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:dio/dio.dart' as dio_lib;

void main() async {
  final baseUrl = 'http://127.0.0.1:8000/api';
  
  // Register a test user
  final email = 'test_${DateTime.now().millisecondsSinceEpoch}@example.com';
  final password = 'password123';
  
  final regRes = await http.post(
    Uri.parse('$baseUrl/register'),
    headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
    body: jsonEncode({
      'first_name': 'Test',
      'last_name': 'User',
      'email': email,
      'phone_number': '1234567890${DateTime.now().millisecondsSinceEpoch.toString().substring(0, 3)}',
      'password': password,
      'password_confirmation': password,
    })
  );
  
  final token = jsonDecode(regRes.body)['token'];
  if (token == null) return;

  // Update profile
  final dio = dio_lib.Dio();
  try {
    final formData = dio_lib.FormData.fromMap({
      'first_name': 'Updated',
    });
    
    final updateRes = await dio.post(
      '$baseUrl/profile/update',
      data: formData,
      options: dio_lib.Options(headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      })
    );
    print('Update response: ${updateRes.data}');
  } on dio_lib.DioException catch (e) {
    print('Update error: ${e.response?.data}');
  }
}
