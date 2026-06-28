class GoogleAuthCredential {
  const GoogleAuthCredential({required this.idToken, this.refreshToken = ''});

  final String idToken;
  final String refreshToken;
}
