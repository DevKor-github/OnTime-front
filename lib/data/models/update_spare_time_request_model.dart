class UpdateSpareTimeRequestModel {
  final int newSpareTime;

  UpdateSpareTimeRequestModel({required this.newSpareTime});

  Map<String, dynamic> toJson() => {
        'newSpareTime': newSpareTime,
      };

  factory UpdateSpareTimeRequestModel.fromDuration(Duration duration) {
    return UpdateSpareTimeRequestModel(newSpareTime: duration.inMinutes);
  }
}
