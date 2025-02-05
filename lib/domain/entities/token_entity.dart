import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';

class TokenEntity extends Equatable {
  final String accessToken;
  final String refreshToken;

  const TokenEntity({
    required this.accessToken,
    required this.refreshToken,
  });

  static TokenEntity fromHeaders(Headers headers) {
    return TokenEntity(
      accessToken: headers.value('authorization')!,
      refreshToken: headers.value('refresh-token')!,
    );
  }

  @override
  List<Object?> get props => [accessToken, refreshToken];
}
