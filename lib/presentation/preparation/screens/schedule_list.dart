import 'package:flutter/material.dart';
import 'package:on_time_front/core/utils/data_loader.dart';
import 'package:on_time_front/presentation/preparation/screens/schedule_start.dart';

class ScheduleList extends StatefulWidget {
  const ScheduleList({super.key});

  @override
  _ScheduleListState createState() => _ScheduleListState();
}

class _ScheduleListState extends State<ScheduleList> {
  List<dynamic> schedules = [];

  @override
  void initState() {
    super.initState();
    loadScheduleData();
  }

  // DataLoader를 사용하여 데이터 불러오기
  Future<void> loadScheduleData() async {
    final data = await DataLoader.loadSchedules();
    setState(() {
      schedules = data;
    });
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
                return Card(
                  margin: const EdgeInsets.all(12),
                  child: ListTile(
                    title: Text(schedule['scheduleName']),
                    subtitle: Text(schedule['placeName']),
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
