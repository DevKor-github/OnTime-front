String formatTime(int seconds) {
  final int hours = seconds ~/ 3600;
  final int minutes = (seconds % 3600) ~/ 60;
  final int remainingSeconds = seconds % 60;

  if (hours > 0) {
    return minutes > 0 ? '$hours시간 $minutes분' : '$hours시간';
  } else if (minutes > 0) {
    return remainingSeconds > 0 ? '$minutes분 $remainingSeconds초' : '$minutes분';
  } else if (seconds <= 0) {
    return '0초';
  } else {
    return '$remainingSeconds초';
  }
}

String formatTimeTimer(int seconds) {
  final int hours = seconds ~/ 3600;
  final int minutes = (seconds % 3600) ~/ 60;
  final int remainingSeconds = seconds % 60;

  if (hours >= 1) {
    return '${hours.toString().padLeft(2, '0')} : '
        '${minutes.toString().padLeft(2, '0')} : '
        '${remainingSeconds.toString().padLeft(2, '0')}';
  } else {
    return '${minutes.toString().padLeft(2, '0')} : '
        '${remainingSeconds.toString().padLeft(2, '0')}';
  }
}

String formatEalyLateTime(int seconds) {
  var time = seconds.abs();

  final int hours = time ~/ 3600;
  final int minutes = (time % 3600) ~/ 60;

  if (hours > 0 && minutes > 0) {
    return '$hours시간 $minutes분';
  } else {
    return '$minutes분';
  }
}
