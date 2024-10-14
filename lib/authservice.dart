import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:auth_helper/error_handler.dart';
import 'package:tuple/tuple.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ui_kosmos_v4/ui_kosmos_v4.dart';
import 'config.dart';
import 'package:crypto/crypto.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AuthService {
  static Future<bool> linkPhoneToMailAccount({
    required FToast fToast,
    required BuildContext context,
    PhoneAuthCredential? phoneAuthCredential,
    required String mailAdress,
    required String password,
  }) async {
    try {
      phoneAuthCredential != null ? await FirebaseAuth.instance.signInWithCredential(phoneAuthCredential) : null;
      final AuthCredential emailAuthCredential = EmailAuthProvider.credential(email: mailAdress, password: password);
      await FirebaseAuth.instance.currentUser!.linkWithCredential(emailAuthCredential);
      return true;
    } on FirebaseAuthException catch (e) {
      AuthResponse response = signInWithCredentialError(e);
      NotifBanner.showToast(fToast: fToast, backgroundColor: Colors.red, title: response.type.tr(), subTitle: response.message.tr(), context: context);
      return false;
    }
  }

  static Future<bool> updatePhone({
    PhoneAuthCredential? phoneAuthCredential,
    required FToast fToast,
    required BuildContext context,
  }) async {
    if (phoneAuthCredential != null) {
      try {
        await FirebaseAuth.instance.currentUser!.updatePhoneNumber(phoneAuthCredential);
        return true;
      } on FirebaseAuthException catch (e) {
        AuthResponse response = signInWithCredentialError(e);
        NotifBanner.showToast(
          fToast: fToast,
          backgroundColor: Colors.red,
          title: response.type.tr(),
          subTitle: response.message.tr(),
          context: context,
        );
        return false;
      }
    } else {
      return false;
    }
  }

  static verifPhoneNumberAndGetCredential({
    required String phone,
    required Function connexionDone,
    required Function(String verificationId, int? forecResendToken) codeSent,
    required Function redirectAfterTimeOut,
    required Function setLoading,
    void Function(FirebaseAuthException e)? verificationFailed,
    void Function(FirebaseAuthException e)? verificationError,
    required FToast fToast,
    required BuildContext context,
  }) {
    FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phone,
      timeout: const Duration(minutes: 1),
      verificationCompleted: (PhoneAuthCredential credential) async {
        try {
          await FirebaseAuth.instance.signInWithCredential(credential);
          connexionDone();
        } on FirebaseAuthException catch (e) {
          AuthResponse response = verificationErrorHandler(e);
          verificationError != null
              ? verificationError(e)
              : NotifBanner.showToast(
                  fToast: fToast,
                  backgroundColor: Colors.red,
                  title: response.type.tr(),
                  subTitle: response.message.tr(),
                  context: context,
                );
        }
      },
      verificationFailed: verificationFailed ??
          (_) {
            AuthResponse response = verificationFailedError(_);
            NotifBanner.showToast(
              fToast: fToast,
              backgroundColor: Colors.red,
              title: response.type.tr(),
              subTitle: response.message.tr(),
              context: context,
            );
          },
      codeSent: codeSent,
      codeAutoRetrievalTimeout: (String verificationId) {},
    );
  }

  static Future<bool> signInAndUpWithPhone({required FToast fToast, required BuildContext context, required PhoneAuthCredential phoneAuthCredential}) async {
    try {
      await FirebaseAuth.instance.signInWithCredential(phoneAuthCredential);
      return true;
    } on FirebaseAuthException catch (e) {
      AuthResponse response = signInWithCredentialError(e);
      NotifBanner.showToast(fToast: fToast, backgroundColor: Colors.red, title: response.type.tr(), subTitle: response.message.tr(), context: context);
      return false;
    }
  }

  static Future<AuthResponse> signUpWithEmail(String email, String password, FToast fToast, BuildContext context) async {
    try {
      UserCredential result = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email.trim(), password: password);
      return result.user != null ? AuthResponse('ok', 'connexion effectuée') : AuthResponse('error', 'Account cannot be created');
    } on FirebaseAuthException catch (e) {
      AuthResponse response = createUserWithEmailAndPasswordErrorHandler(e);
      NotifBanner.showToast(
        fToast: fToast,
        backgroundColor: Colors.red,
        title: response.type.tr(),
        subTitle: response.message.tr(),
        context: context,
      );
      return response;
    }
  }

  static Future<UserCredential?> signInWithEmail({required String email, required String password, required FToast fToast, required BuildContext context}) async {
    try {
      return await FirebaseAuth.instance.signInWithEmailAndPassword(email: email.trim(), password: password);
    } on FirebaseAuthException catch (e) {
      AuthResponse response = signInWithEmailAndPasswordErrorHandler(e);
      NotifBanner.showToast(
        fToast: fToast,
        backgroundColor: Colors.red,
        title: response.type.tr(),
        subTitle: response.message.tr(),
        context: context,
      );
      return null;
    }
  }

  static Future<IsUserExistResponse> existEmail({required String email, required String cloudfunctionsbaseurl}) async {
    var response = await http.post(
        Uri.https(
          cloudfunctionsbaseurl,
          '/existsUserWithEmail',
        ),
        body: jsonEncode({"email": email}));
    if (response.statusCode == 200) {
      return IsUserExistResponse.notExist;
    } else if (response.statusCode == 404) {
      var state = jsonDecode(response.body);
      print(state.toString());
      return IsUserExistResponse.exist;
    }
    return IsUserExistResponse.error;
  }

  static Future<Tuple2<IsUserWithPhoneExistResponse, String?>> existPhone({required String numTel, required String cloudfunctionsbaseurl}) async {
    var response = await http.post(
        Uri.https(
          cloudfunctionsbaseurl,
          '/existUserWithPhone',
        ),
        body: jsonEncode({"numTel": numTel}));
    if (response.statusCode == 200) {
      return const Tuple2(IsUserWithPhoneExistResponse.notExist, null);
    } else if (response.statusCode == 404) {
      var state = jsonDecode(response.body);
      if ((state['verified'] as bool) == true) {
        return const Tuple2(IsUserWithPhoneExistResponse.existWithValidatedEmail, null);
      } else {
        return Tuple2(IsUserWithPhoneExistResponse.existWithUvalidatedEmail, state['email']);
      }
    }
    return const Tuple2(IsUserWithPhoneExistResponse.error, null);
  }

  static Future<bool> existDocWithId(String accountType, String id) async {
    DocumentSnapshot user = await FirebaseFirestore.instance.collection(accountType).doc(id).get();
    return user.exists;
  }

  static Future<bool> existAccountWithSocialCredential({required UserCredential credential, required List<String> accountType}) async {
    if (accountType.length > 1) {
      List<Future<bool>> futures = [];
      for (var element in accountType) {
        futures.add(existDocWithId(element, credential.user!.uid));
      }
      List<bool> exist = await Future.wait(futures);
      return exist.contains(true);
    } else {
      return existDocWithId(accountType.first, credential.user!.uid);
    }
  }

  static Future<UserCredential> signInWithApple() async {
    final rawNonce = generateNonce();
    final nonce = sha256ofString(rawNonce);

    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: nonce,
    );
    final oauthCredential = OAuthProvider("apple.com").credential(
      idToken: appleCredential.identityToken,
      rawNonce: rawNonce,
    );
    return await FirebaseAuth.instance.signInWithCredential(oauthCredential);
  }

  static Future<UserCredential?> signInWithGoogle() async {
    final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

    if (googleUser != null) {
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      return await FirebaseAuth.instance.signInWithCredential(credential);
    } else {
      return null;
    }
  }

  static Future<AuthResponse> changePassword({
    required String email,
    required String oldPassword,
    required String newPassword,
  }) async {
    AuthCredential credential = EmailAuthProvider.credential(email: email, password: oldPassword);
    try {
      await FirebaseAuth.instance.currentUser?.reauthenticateWithCredential(credential);
      try {
        await FirebaseAuth.instance.currentUser?.updatePassword(newPassword);
      } on FirebaseAuthException catch (e) {
        return updatePasswordErrorHandler(e);
      }
      return AuthResponse("ok", 'ok');
    } on FirebaseAuthException catch (e) {
      return updatePasswordErrorHandler(e);
    }
  }

  static Future<AuthResponse> changeEmail({
    required String email,
    required String newEmail,
    required String password,
  }) async {
    AuthCredential credential = EmailAuthProvider.credential(email: email, password: password);
    try {
      await FirebaseAuth.instance.currentUser?.reauthenticateWithCredential(credential);
      await FirebaseAuth.instance.currentUser?.updateEmail(newEmail);
      return AuthResponse("ok", 'ok');
    } on FirebaseAuthException catch (e) {
      return updateEmailErrorHandler(e);
    }
  }
}

String generateNonce([int length = 32]) {
  const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
  final random = Random.secure();
  return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
}

/// Returns the sha256 hash of [input] in hex notation.
String sha256ofString(String input) {
  final bytes = utf8.encode(input);
  final digest = sha256.convert(bytes);
  return digest.toString();
}
