import 'dart:async';
import 'package:flutter/material.dart';

void main() {
  runApp(PrepStepTileProto());
}

class PrepStepTileProto extends StatelessWidget {
  const PrepStepTileProto({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Preparation Steps',
      home: PreparationScreen(),
    );
  }
}

enum StepState { done, now, yet }

class PreparationStep {
  final String stepName;
  final Duration stepTime;
  StepState state;
  Duration elapsedTime;

  PreparationStep({
    required this.stepName,
    required this.stepTime,
    this.state = StepState.yet,
    this.elapsedTime = Duration.zero,
  });
}

class PreparationScreen extends StatefulWidget {
  const PreparationScreen({super.key});

  @override
  _PreparationScreenState createState() => _PreparationScreenState();
}

class _PreparationScreenState extends State<PreparationScreen> {
  List<PreparationStep> preparations = [
    PreparationStep(stepName: 'Step 1', stepTime: Duration(minutes: 1)),
    PreparationStep(stepName: 'Step 2', stepTime: Duration(minutes: 1)),
    PreparationStep(stepName: 'Step 3', stepTime: Duration(minutes: 1)),
  ];

  Timer? preparationTimer;
  int currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // 초기 단계 설정
    if (preparations.isNotEmpty) {
      setState(() {
        preparations[0].state = StepState.now;
      });
      startTimer();
    }
  }

  @override
  void dispose() {
    preparationTimer?.cancel();
    super.dispose();
  }

  void startTimer() {
    preparationTimer?.cancel();
    preparationTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        PreparationStep currentStep = preparations[currentIndex];
        currentStep.elapsedTime += Duration(seconds: 1);

        if (currentStep.elapsedTime >= currentStep.stepTime) {
          currentStep.state = StepState.done;
          preparationTimer?.cancel();
          moveToNextPreparation();
        }
      });
    });
  }

  void moveToNextPreparation() {
    setState(() {
      if (currentIndex + 1 < preparations.length) {
        currentIndex += 1;
        preparations[currentIndex].state = StepState.now;
        startTimer();
      } else {
        // 모든 준비 단계가 완료된 경우
        preparationTimer?.cancel();
      }
    });
  }

  void skipCurrentPreparation() {
    preparationTimer?.cancel();
    setState(() {
      PreparationStep currentStep = preparations[currentIndex];
      currentStep.state = StepState.done;
      // elapsedTime은 현재 상태의 값 유지
      moveToNextPreparation();
    });
  }

  String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return "${twoDigits(duration.inMinutes.remainder(60))}:${twoDigits(duration.inSeconds.remainder(60))}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Preparation Steps'),
      ),
      body: ListView.builder(
        itemCount: preparations.length,
        itemBuilder: (context, index) {
          PreparationStep step = preparations[index];
          return Card(
            margin: EdgeInsets.all(8.0),
            child: ListTile(
              title: Text(step.stepName),
              subtitle: Text(
                step.state == StepState.now
                    ? formatDuration(step.elapsedTime)
                    : (step.state == StepState.done
                        ? formatDuration(step.elapsedTime)
                        : formatDuration(step.stepTime)),
                style: TextStyle(
                  color: step.state == StepState.done
                      ? Colors.green
                      : (step.state == StepState.now
                          ? Colors.blue
                          : Colors.grey),
                  fontWeight: FontWeight.bold,
                ),
              ),
              trailing: step.state == StepState.now
                  ? ElevatedButton(
                      onPressed: skipCurrentPreparation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      child: Text('건너뛰기'),
                    )
                  : null,
            ),
          );
        },
      ),
    );
  }
}
