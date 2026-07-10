import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:dio/dio.dart' as dio_lib;

void main() async {
  final baseUrl = 'http://127.0.0.1:8000/api';
  
  // Register a test user
  final email = 'test_${DateTime.now().millisecondsSinceEpoch}@example.com';
  final password = 'password123';
  
  print('Registering user...');
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
  
  print('Reg response: ${regRes.statusCode} - ${regRes.body}');
  
  final token = jsonDecode(regRes.body)['token'];
  if (token == null) return;

  // Create incident
  print('Creating incident...');
  final dio = dio_lib.Dio();
  final formData = dio_lib.FormData.fromMap({
    'type': 'accident',
    'description': 'This is a test incident description.',
    'location_text': "123 Main street, Anytown", 
    'latitude': "30.0444",
    'longitude': "31.2357",
  });
  
  try {
    final createRes = await dio.post(
      '$baseUrl/incidents/create',
      data: formData,
      options: dio_lib.Options(headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      })
    );
    print('Create response: ${createRes.statusCode} - ${createRes.data}');
  } on dio_lib.DioException catch (e) {
    print('Create Error: ${e.response?.statusCode} - ${e.response?.data}');
  }
  
  // Fetch history
  print('Fetching history...');
  final histRes = await http.get(
    Uri.parse('$baseUrl/incidents/history'),
    headers: {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    }
  );
  
  print('History response: ${histRes.statusCode} - ${histRes.body}');
}
