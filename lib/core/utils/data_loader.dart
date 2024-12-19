import 'dart:convert';
import 'package:flutter/services.dart';

class DataLoader {
  static Future<List<dynamic>> loadSchedules() async {
    final String jsonString =
        await rootBundle.loadString('lib/test_data/t_schedule_data.json');
    final Map<String, dynamic> jsonData = json.decode(jsonString);
    return jsonData['schedules'];
  }
}
