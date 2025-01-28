import 'package:flutter/material.dart';

import 'package:on_time_front/presentation/preparation/screens/schedule_start.dart';
import 'package:on_time_front/presentation/preparation/screens/server_data_loader.dart';

// 해당 컴포넌트는 스케줄 데이터를 임시로 받아오는 화면. 실재 기능에서는 사용되지 않을 예정.

class ScheduleListScreen extends StatefulWidget {
  const ScheduleListScreen({super.key});

  @override
  _ScheduleListScreenState createState() => _ScheduleListScreenState();
}

class _ScheduleListScreenState extends State<ScheduleListScreen> {
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
