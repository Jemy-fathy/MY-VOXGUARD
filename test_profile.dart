import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:math';

void main() async {
  final baseUrl = 'http://127.0.0.1:8000/api';
  final rnd = Random().nextInt(999999);
  
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
      'phone_number': '123$rnd${DateTime.now().millisecondsSinceEpoch.toString().substring(0, 3)}',
      'password': password,
      'password_confirmation': password,
    })
  );
  
  final token = jsonDecode(regRes.body)['token'];
  if (token == null) {
      print('Token is null');
      return;
  }

  // Fetch profile
  print('Fetching profile...');
  final getRes = await http.get(
    Uri.parse('$baseUrl/profile'),
    headers: {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    }
  );
  
  print('Profile data: ${getRes.body}');
}
