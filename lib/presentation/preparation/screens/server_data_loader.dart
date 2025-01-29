import 'dart:convert';
import 'package:http/http.dart' as http;

class ServerDataLoader {
  static const String baseUrl = "http://ejun.kro.kr:8888/schedule/show";
  static const String token =
      "eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJBY2Nlc3NUb2tlbiIsImV4cCI6MTc3NDE3MjM3MiwiZW1haWwiOiJ1c2VyQGV4YW1wbGUuY29tIiwidXNlcklkIjoxfQ.k7nANy05Q2_iFhRYjD1PXEnJUVfIr3rLu6nAIe-rEGnE-hLkZ-hx9tupAVO2TGUKwSiVBmwbozRxbobvUOsR_g";

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
