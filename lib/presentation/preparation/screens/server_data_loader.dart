import 'dart:convert';
import 'package:http/http.dart' as http;

class ServerDataLoader {
  static const String baseUrl = "https://ontime.devkor.club/schedule/show";
  static const String token =
      "eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJBY2Nlc3NUb2tlbiIsImV4cCI6MTczODkzMTQxNiwiZW1haWwiOiJ1c2VyQGV4YW1wbGUuY29tIiwidXNlcklkIjoxfQ.chGqtagZf5AWsFjuLjCKibEA_Wh375PA8ifwx13sym_GyPhUXfvgNARGJFP3qknVkHgRFodXznYNvNTGrecwCg";

  static Future<List<dynamic>> loadSchedules({
    String? startDate,
    String? endDate,
  }) async {
    String url = baseUrl;

    if (startDate != null &&
        startDate.isNotEmpty &&
        endDate != null &&
        endDate.isNotEmpty) {
      url = "$baseUrl?startDate=$startDate&endDate=$endDate";
    }

    try {
      final response = await http.get(
        Uri.parse(url),
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
