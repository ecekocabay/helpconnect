import 'dart:convert';
import 'dart:typed_data';

import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:helpconnect/amplifyconfiguration.dart';

class AuthService {
  static final AuthService instance = AuthService._internal();
  AuthService._internal();

  bool _configured = false;

  /// MUST be called before ANY Auth usage
  Future<void> configure() async {
    if (_configured) return;

    try {
      final authPlugin = AmplifyAuthCognito();
      await Amplify.addPlugin(authPlugin);
      await Amplify.configure(amplifyconfig);
      _configured = true;
      print('✅ Amplify configured');
    } catch (e) {
      if (e.toString().contains('Amplify has already been configured')) {
        _configured = true;
      } else {
        rethrow;
      }
    }
  }

  Future<void> signUp({
    required String email,
    required String password,
    String? name,
  }) async {
    await configure();
    await Amplify.Auth.signUp(
      username: email,
      password: password,
      options: SignUpOptions(
        userAttributes: {
          AuthUserAttributeKey.email: email,
          if (name != null && name.isNotEmpty) AuthUserAttributeKey.name: name,
        },
      ),
    );
  }

  /// ✅ Checks Cognito group membership from ID token
  /// Default group name: Admin
  Future<bool> isAdmin({String groupName = 'Admin'}) async {
    await configure();

    final session = await Amplify.Auth.fetchAuthSession();
    if (session is! CognitoAuthSession || !session.isSignedIn) return false;

    // Use ID token for groups
    final idToken = session.userPoolTokensResult.value.idToken.raw;

    final parts = idToken.split('.');
    if (parts.length != 3) return false;

    final payload = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    ) as Map<String, dynamic>;

    final groups = payload['cognito:groups'];

    if (groups is List) return groups.contains(groupName);
    if (groups is String) return groups == groupName;
    return false;
  }

  Future<void> confirmSignUp({
    required String email,
    required String code,
  }) async {
    await configure();
    await Amplify.Auth.confirmSignUp(
      username: email,
      confirmationCode: code,
    );
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await configure();
    await Amplify.Auth.signIn(
      username: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await configure();
    await Amplify.Auth.signOut();
  }

  Future<bool> isSignedIn() async {
    await configure();
    final session = await Amplify.Auth.fetchAuthSession();
    return session.isSignedIn;
  }

  Future<Map<String, String>> getUserAttributes() async {
    await configure();
    final attrs = await Amplify.Auth.fetchUserAttributes();
    return {for (final a in attrs) a.userAttributeKey.key: a.value};
  }

  Future<String?> getAccessToken() async {
    await configure();
    final session = await Amplify.Auth.fetchAuthSession();
    if (session is CognitoAuthSession && session.isSignedIn) {
      return session.userPoolTokensResult.value.accessToken.raw;
    }
    return null;
  }

  Future<String?> getUserSub() async {
    final token = await getAccessToken();
    if (token == null) return null;

    final parts = token.split('.');
    if (parts.length != 3) return null;

    final payload =
        jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
    return payload['sub'];
  }
}