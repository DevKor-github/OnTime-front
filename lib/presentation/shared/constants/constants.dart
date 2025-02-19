import 'dart:math';

const double appBarHeight = 56.0;

/// 지각 시 표시될 문구들
const List<String> lateMessages = [
  "지구의 자전이 너무 빨랐나 봐요!\n조금 늦었지만 괜찮아요!",
  "시간이 당신을 기다리지 않았지만,\n사람들은 기다려줄 거예요. 아마도요.",
  "‘시간은 금이다’고 했지만,\n오늘은 그 금을 잠시 빌려 쓴 것 같네요!",
  "지각의 달인이 되고 싶지 않다면,\n조금 더 일찍 출발해보아요!",
  "늦었다고 서두르다 넘어지면 더 늦어요.\n살짝 서둘러봐요!",
  "시공간을 뛰어넘는\n타임머신이 있었으면 좋겠어요…!",
  "조금 늦긴 했지만,\n오늘의 기분을 망칠 수는 없죠.\n어서 가보자구요!",
  "늦은 것 자체가 죄는 아니지만,\n더 나은 시간을 만드는 건 우리의 몫이죠.",
  "이미 마음은 현장에 도착해 있었는데,\n몸이 따라오질 않았네요.",
  "영화 주인공은 늦게 등장하는 법이라던가…?\n그 기분으로 출발!",
  "달력이 오늘을 운명의 날로 정해놨나 봐요.\n하지만 우린 이길 수 있어요!",
  "시간은 도망갔지만,\n당신의 열정은 따라잡을 수 있어요!",
  "오늘의 체크리스트는 완벽했지만,\n시간이 체크리스트에 없었던 건가요?",
  "오늘의 지각은 역사를 만들었군요!\n다음엔 새로운 기록을 세우지 않도록 해봐요!",
  "지각계의 마스터가 되어가고 있어요.\n하지만 이제 새로운 길을 찾아봐요!",
];

/// 일찍 준비 시, 분 단위 구간별 문구 맵
final Map<Range, List<String>> earlyMessages = {
  Range(0, 5): [
    "아슬아슬하게 지각을 피했어요!",
    "우산을 깜빡하지 않을 여유를 벌었어요.",
  ],
  Range(6, 10): [
    "택시비를 아꼈어요!",
    "심호흡 한 번 하고\n천천히 걸어갈 시간이 생겼어요.",
  ],
  Range(11, 15): [
    "즐거운 커피 한 잔의\n여유를 얻었어요.",
    "횡단보도 신호를 기다릴\n스트레스에서 벗어났어요.",
  ],
  Range(16, 20): [
    "지하철 환승을 여유롭게 할 수 있어요.",
    "친구를 만나기 전에\n간단히 메시지를 보낼 시간이 생겼어요.",
  ],
  Range(21, 30): [
    "출발 전에 잊은 물건을\n챙길 기회가 생겼어요!",
    "예정 시간보다 빠르게 도착해서\n장소를 한 바퀴 둘러볼 수 있어요.",
  ],
  Range(31, 40): [
    "부모님께 전화를 걸\n여유로운 시간을 벌었어요.",
    "조금 더 준비된 모습으로\n상대를 만날 수 있어요.",
  ],
  Range(41, 59): [
    "영화 예고편을 보며\n시간을 보낼 수 있어요!",
    "약속 장소에서\n조용히 책 몇 페이지를 읽을 수 있어요.",
  ],
  Range.openEnded(60): [
    "삶의 소소한 여유를 얻었어요!",
    "지각 걱정 없이 미리 가서\n주변을 살펴볼 수 있어요.",
  ],
};

class Range {
  final int start;
  final int? end;

  Range(this.start, [this.end]) {
    if (end != null && end! < start) {
      throw ArgumentError("end 값은 start 값보다 크거나 같아야 합니다.");
    }
  }

  Range.openEnded(this.start) : end = null;

  bool contains(int value) {
    if (end == null) {
      return value >= start;
    }
    return value >= start && value <= end!;
  }
}

String getEarlyMessage(int value) {
  for (final range in earlyMessages.keys) {
    if (range.contains(value)) {
      final list = earlyMessages[range]!;
      return list[Random().nextInt(list.length)];
    }
  }
  return "정확히 시간을 맞춰 준비했어요! 혹시 몸에 시계라도 있나요?";
}

/// 지각 시 랜덤 문구
String getLateMessage() {
  return lateMessages[Random().nextInt(lateMessages.length)];
}
