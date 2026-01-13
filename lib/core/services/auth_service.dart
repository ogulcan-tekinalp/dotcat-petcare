import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? get currentUser => _auth.currentUser;
  bool get isSignedIn => currentUser != null;
  
  // Check if Apple Sign In is available (iOS only)
  bool get isAppleSignInAvailable => Platform.isIOS;
  
  Future<String> getLocalUserId() async {
    final prefs = await SharedPreferences.getInstance();
    String? localId = prefs.getString('local_user_id');
    if (localId == null) {
      localId = const Uuid().v4();
      await prefs.setString('local_user_id', localId);
    }
    return localId;
  }

  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // If user is anonymous, link the account instead of signing in
      final currentUser = _auth.currentUser;
      if (currentUser != null && currentUser.isAnonymous) {
        debugPrint('Google Sign In: Linking anonymous account...');
        try {
          return await currentUser.linkWithCredential(credential);
        } catch (e) {
          debugPrint('Google Sign In: Link failed, trying regular sign in: $e');
          // If link fails (e.g., account already exists), sign in normally
          return await _auth.signInWithCredential(credential);
        }
      }

      return await _auth.signInWithCredential(credential);
    } catch (e) {
      debugPrint('Google Sign In Error: $e');
      return null;
    }
  }

  // Apple Sign In
  Future<UserCredential?> signInWithApple() async {
    try {
      // Generate nonce for security
      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);

      debugPrint('Apple Sign In: Requesting credentials...');
      
      // Request Apple credentials
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      debugPrint('Apple Sign In: Got Apple credential, identityToken: ${appleCredential.identityToken != null}');
      debugPrint('Apple Sign In: authorizationCode: ${appleCredential.authorizationCode.isNotEmpty}');

      if (appleCredential.identityToken == null) {
        debugPrint('Apple Sign In: Identity token is null!');
        return null;
      }

      // Create OAuth credential
      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
        rawNonce: rawNonce,
      );

      debugPrint('Apple Sign In: Signing in to Firebase...');

      // If user is anonymous, link the account instead of signing in
      final currentUser = _auth.currentUser;
      UserCredential userCredential;

      if (currentUser != null && currentUser.isAnonymous) {
        debugPrint('Apple Sign In: Linking anonymous account...');
        try {
          userCredential = await currentUser.linkWithCredential(oauthCredential);
        } catch (e) {
          debugPrint('Apple Sign In: Link failed, trying regular sign in: $e');
          // If link fails (e.g., account already exists), sign in normally
          userCredential = await _auth.signInWithCredential(oauthCredential);
        }
      } else {
        userCredential = await _auth.signInWithCredential(oauthCredential);
      }

      debugPrint('Apple Sign In: Firebase sign in successful!');

      // Update display name if provided (Apple only sends this on first sign-in)
      if (appleCredential.givenName != null || appleCredential.familyName != null) {
        final displayName = [
          appleCredential.givenName,
          appleCredential.familyName,
        ].where((name) => name != null && name.isNotEmpty).join(' ');
        
        if (displayName.isNotEmpty) {
          await userCredential.user?.updateDisplayName(displayName);
        }
      }

      return userCredential;
    } on SignInWithAppleAuthorizationException catch (e) {
      debugPrint('Apple Sign In Authorization Error: ${e.code} - ${e.message}');
      return null;
    } on FirebaseAuthException catch (e) {
      debugPrint('Apple Sign In Firebase Error: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Apple Sign In Error: $e');
      return null;
    }
  }

  // Generate a cryptographically secure random nonce
  String _generateNonce([int length = 32]) {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  // SHA256 hash
  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Anonymous Sign In
  Future<UserCredential?> signInAnonymously() async {
    try {
      return await _auth.signInAnonymously();
    } catch (e) {
      debugPrint('Anonymous Sign In Error: $e');
      return null;
    }
  }

  // Email/Password Sign In
  Future<UserCredential?> signInWithEmailPassword(String email, String password) async {
    try {
      // Email/password doesn't support linking anonymous accounts directly
      // Just sign in normally
      return await _auth.signInWithEmailAndPassword(email: email, password: password);
    } catch (e) {
      debugPrint('Email/Password Sign In Error: $e');
      rethrow;
    }
  }

  // Email/Password Sign Up
  Future<UserCredential?> signUpWithEmailPassword(String email, String password) async {
    try {
      final currentUser = _auth.currentUser;

      // If user is anonymous, link with email/password
      if (currentUser != null && currentUser.isAnonymous) {
        debugPrint('Email/Password Sign Up: Linking anonymous account...');
        try {
          final credential = EmailAuthProvider.credential(email: email, password: password);
          return await currentUser.linkWithCredential(credential);
        } catch (e) {
          debugPrint('Email/Password Sign Up: Link failed, trying regular sign up: $e');
          // If link fails, sign out and create new account
          await _auth.signOut();
          return await _auth.createUserWithEmailAndPassword(email: email, password: password);
        }
      }

      return await _auth.createUserWithEmailAndPassword(email: email, password: password);
    } catch (e) {
      debugPrint('Email/Password Sign Up Error: $e');
      rethrow;
    }
  }


  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      debugPrint('Sign Out Error: $e');
    }
  }

  // Delete account
  Future<bool> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      // Sign out from Google if applicable
      await _googleSignIn.signOut();
      
      // Delete user account from Firebase
      await user.delete();
      
      // Clear local preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('local_user_id');
      
      return true;
    } catch (e) {
      debugPrint('Delete Account Error: $e');
      // If requires recent login, user needs to re-authenticate
      if (e is FirebaseAuthException && e.code == 'requires-recent-login') {
        rethrow;
      }
      return false;
    }
  }
}
