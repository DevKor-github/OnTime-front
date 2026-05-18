import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/data/models/create_schedule_request_model.dart';
import 'package:on_time_front/data/models/fcm_token_register_request_model.dart';
import 'package:on_time_front/data/models/get_place_response_model.dart';
import 'package:on_time_front/data/models/get_schedule_response_model.dart';
import 'package:on_time_front/data/models/sign_in_with_apple_request_model.dart';
import 'package:on_time_front/data/models/sign_in_with_google_request_model.dart';
import 'package:on_time_front/data/models/update_schedule_request_model.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';

void main() {
  test('toEntity maps schedule response fields and durations', () {
    final scheduleTime = DateTime(2026, 5, 15, 9, 30);
    final model = GetScheduleResponseModel(
      scheduleId: 'schedule-1',
      place: const GetPlaceResponseModel(
        placeId: 'place-1',
        placeName: 'Office',
      ),
      scheduleName: 'Morning standup',
      scheduleTime: scheduleTime,
      moveTime: 20,
      scheduleSpareTime: 5,
      scheduleNote: 'Bring laptop',
      latenessTime: 3,
      doneStatus: 'LATE',
    );

    final entity = model.toEntity();

    expect(entity.id, 'schedule-1');
    expect(entity.place.id, 'place-1');
    expect(entity.place.placeName, 'Office');
    expect(entity.scheduleName, 'Morning standup');
    expect(entity.scheduleTime, scheduleTime);
    expect(entity.moveTime, const Duration(minutes: 20));
    expect(entity.scheduleSpareTime, const Duration(minutes: 5));
    expect(entity.scheduleNote, 'Bring laptop');
    expect(entity.latenessTime, 3);
    expect(entity.doneStatus, ScheduleDoneStatus.lateEnd);
    expect(entity.isChanged, isFalse);
    expect(entity.isStarted, isFalse);
  });

  test(
    'toEntity maps server done status values and null lateness fallback',
    () {
      ScheduleDoneStatus statusFor(String? doneStatus) {
        return GetScheduleResponseModel(
          scheduleId: 'schedule-1',
          place: const GetPlaceResponseModel(
            placeId: 'place-1',
            placeName: 'Office',
          ),
          scheduleName: 'Meeting',
          scheduleTime: DateTime(2026, 5, 15),
          moveTime: 10,
          scheduleSpareTime: 0,
          scheduleNote: '',
          latenessTime: null,
          doneStatus: doneStatus,
        ).toEntity().doneStatus;
      }

      expect(statusFor('NORMAL'), ScheduleDoneStatus.normalEnd);
      expect(statusFor('ABNORMAL'), ScheduleDoneStatus.abnormalEnd);
      expect(statusFor('NOT_ENDED'), ScheduleDoneStatus.notEnded);
      expect(statusFor('unexpected'), ScheduleDoneStatus.notEnded);
      expect(statusFor(null), ScheduleDoneStatus.notEnded);
    },
  );

  test('place response model maps entity and json representations', () {
    const place = PlaceEntity(id: 'place-1', placeName: 'Office');

    final model = GetPlaceResponseModel.fromEntity(place);

    expect(model.placeId, 'place-1');
    expect(model.placeName, 'Office');
    expect(model.toEntity(), place);
    expect(model.toJson(), {'placeId': 'place-1', 'placeName': 'Office'});
    expect(GetPlaceResponseModel.fromJson(model.toJson()).toEntity(), place);
  });

  test('schedule request models trim backend constrained text fields', () {
    final entity = ScheduleEntity(
      id: 'schedule-1',
      place: const PlaceEntity(id: 'place-1', placeName: 'Office'),
      scheduleName: '  ${'Long schedule name ' * 3}',
      scheduleTime: DateTime(2026, 5, 15, 9),
      moveTime: const Duration(minutes: 20),
      isChanged: true,
      isStarted: false,
      scheduleSpareTime: const Duration(minutes: 5),
      scheduleNote: '  ${'note ' * 300}',
    );

    final create = CreateScheduleRequestModel.fromEntity(entity);
    final update = UpdateScheduleRequestModel.fromEntity(entity);

    expect(create.scheduleId, 'schedule-1');
    expect(create.placeId, 'place-1');
    expect(create.moveTime, 20);
    expect(create.isChange, isTrue);
    expect(create.scheduleSpareTime, 5);
    expect(create.scheduleName.length, 30);
    expect(create.scheduleNote.length, 1000);
    expect(update.scheduleName, create.scheduleName);
    expect(update.scheduleNote, create.scheduleNote);
    expect(update.toJson()['scheduleId'], 'schedule-1');
  });

  test('auth and notification request models serialize backend payloads', () {
    final google = SignInWithGoogleRequestModel(
      idToken: 'google-id-token',
      refreshToken: '',
    );
    final appleWithoutEmail = SignInWithAppleRequestModel(
      idToken: 'apple-id-token',
      authCode: 'auth-code',
      fullName: 'Apple User',
    );
    final fcm = FcmTokenRegisterRequestModel(
      firebaseToken: 'fcm-token',
      deviceId: 'device-1',
    );

    expect(google.toJson(), {'idToken': 'google-id-token', 'refreshToken': ''});
    expect(
      SignInWithGoogleRequestModel.fromJson(google.toJson()).idToken,
      'google-id-token',
    );
    expect(appleWithoutEmail.toJson().containsKey('email'), isFalse);
    expect(
      SignInWithAppleRequestModel.fromJson({
        ...appleWithoutEmail.toJson(),
        'email': 'apple@example.com',
      }).email,
      'apple@example.com',
    );
    expect(fcm.toJson(), {
      'firebaseToken': 'fcm-token',
      'deviceId': 'device-1',
    });
    expect(
      FcmTokenRegisterRequestModel.fromJson(fcm.toJson()).deviceId,
      'device-1',
    );
  });
}
