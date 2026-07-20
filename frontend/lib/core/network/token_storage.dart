import 'package:shared_preferences/shared_preferences.dart';

class TokenStorage {
  static const String _accessTokenKey = 'access_token';

  Future<void> saveToken(
    String token,
  ) async {
    final preferences =
        await SharedPreferences.getInstance();

    await preferences.setString(
      _accessTokenKey,
      token,
    );
  }

  Future<String?> getToken() async {
    final preferences =
        await SharedPreferences.getInstance();

    return preferences.getString(
      _accessTokenKey,
    );
  }

  Future<void> deleteToken() async {
    final preferences =
        await SharedPreferences.getInstance();

    await preferences.remove(
      _accessTokenKey,
    );
  }
}
