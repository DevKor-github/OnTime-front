import 'package:flutter/material.dart';

import 'package:on_time_front/presentation/preparation/screens/schedule_start.dart';
import 'package:on_time_front/presentation/preparation/screens/server_data_loader.dart';

class ScheduleListTest extends StatefulWidget {
  const ScheduleListTest({super.key});

  @override
  _ScheduleListTestState createState() => _ScheduleListTestState();
}

class _ScheduleListTestState extends State<ScheduleListTest> {
  List<dynamic> schedules = [];

  @override
  void initState() {
    super.initState();
    loadScheduleData();
  }

  // DataLoader를 사용하여 데이터 불러오기 (날짜 하드코딩)
  Future<void> loadScheduleData() async {
    const String startDate = "2024-11-15T19:30:00";
    const String endDate = "2024-11-15T19:30:00";

    try {
      final data = await ServerDataLoader.loadSchedules(
        startDate: startDate,
        endDate: endDate,
      );
      setState(() {
        schedules = data;
      });
    } catch (error) {
      print("Failed to fetch schedules: $error");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("스케줄 목록"),
        centerTitle: true,
      ),
      body: schedules.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: schedules.length,
              itemBuilder: (context, index) {
                final schedule = schedules[index];
                final placeName = schedule['place']['placeName'];
                final scheduleName = schedule['scheduleName'];
                return Card(
                  margin: const EdgeInsets.all(12),
                  child: ListTile(
                    title: Text(scheduleName),
                    subtitle: Text(placeName),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ScheduleStart(
                            schedule: schedule,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}
