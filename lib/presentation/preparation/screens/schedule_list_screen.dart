import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

import 'package:on_time_front/data/data_sources/schedule_remote_data_source.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/presentation/preparation/screens/schedule_start.dart';

class ScheduleListScreen extends StatefulWidget {
  const ScheduleListScreen({super.key});

  @override
  _ScheduleListScreenState createState() => _ScheduleListScreenState();
}

class _ScheduleListScreenState extends State<ScheduleListScreen> {
  late ScheduleRemoteDataSourceImpl scheduleRemoteDataSource;
  List<ScheduleEntity> schedules = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    scheduleRemoteDataSource = ScheduleRemoteDataSourceImpl(Dio());
    loadScheduleData();
  }

  // 서버에서 스케줄 데이터 불러오기
  Future<void> loadScheduleData() async {
    try {
      final data = await scheduleRemoteDataSource.getSchedulesByDate(
        // 여기 now로 고칠 것
        DateTime(2024, 02, 01, 00, 00),
        null, // endDate는 null 허용
      );
      setState(() {
        schedules = data;
        isLoading = false;
      });
    } catch (error) {
      print("Failed to fetch schedules: $error");
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("스케줄 목록"),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : schedules.isEmpty
              ? const Center(child: Text("스케줄이 없습니다."))
              : ListView.builder(
                  itemCount: schedules.length,
                  itemBuilder: (context, index) {
                    final schedule = schedules[index];
                    return Card(
                      margin: const EdgeInsets.all(12),
                      child: ListTile(
                        title: Text(schedule.scheduleName),
                        subtitle: Text(schedule.place.placeName),
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
