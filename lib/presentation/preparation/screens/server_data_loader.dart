import 'dart:convert';
import 'package:http/http.dart' as http;

class ServerDataLoader {
  static const String baseUrl = "https://ontime.devkor.club/schedule/show";
  static const String token =
      "eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJBY2Nlc3NUb2tlbiIsImV4cCI6MTczODg3MzkwOSwiZW1haWwiOiJ1c2VyQGV4YW1wbGUuY29tIiwidXNlcklkIjoxfQ.cnNiNNqtD-ZqUMyL5dl053em4-fF7LJ1sqDzxVlJtHwMoAw-IwD2OpLRp9iJ6DlXNfb7Uxv42BTre6Fi74PwHw";

  static Future<List<dynamic>> loadSchedules({
    required String startDate,
    required String endDate,
  }) async {
    final url = Uri.parse("$baseUrl?startDate=$startDate&endDate=$endDate");

    try {
      final response = await http.get(
        url,
        headers: {
          'accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);

        if (jsonResponse['status'] == 'success') {
          return jsonResponse['data'];
        } else {
          throw Exception(
              "Failed to load schedules: ${jsonResponse['message']}");
        }
      } else {
        throw Exception("Server error: ${response.statusCode}");
      }
    } catch (error) {
      throw Exception("Failed to fetch schedules: $error");
    }
  }
}
