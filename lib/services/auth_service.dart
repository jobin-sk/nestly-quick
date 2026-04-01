import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AuthService extends ChangeNotifier {
  // Firebase Auth and Firestore instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // The currently logged in user — null if not logged in
  User? get currentUser => _auth.currentUser;

  // Stream that Firebase uses to notify the app when auth state changes
  // e.g. user logs in, logs out, or session expires
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Signs up a new user with email, password, and username
  // Creates the Firebase Auth account and writes the user document to Firestore
  Future<String?> signUp({
    required String email,
    required String password,
    required String username,
  }) async {
    try {
      // Check if username is already taken in Firestore
      final usernameQuery = await _firestore
          .collection('users')
          .where('username', isEqualTo: username.trim())
          .get();

      if (usernameQuery.docs.isNotEmpty) {
        return 'Username already taken — please choose another';
      }

      // Create the Firebase Auth account
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      // Write the user document to Firestore users collection
      await _firestore
          .collection('users')
          .doc(credential.user!.uid)
          .set({
        'userId': credential.user!.uid,
        'email': email.trim(),
        'username': username.trim(),
      });

      return null; // null means success
    } on FirebaseAuthException catch (e) {
      // Return a human readable error message based on Firebase error code
      switch (e.code) {
        case 'email-already-in-use':
          return 'An account already exists with this email';
        case 'invalid-email':
          return 'Please enter a valid email address';
        case 'weak-password':
          return 'Password is too weak — use at least 6 characters';
        default:
          return 'Something went wrong — please try again';
      }
    }
  }

  // Logs in an existing user with email and password
  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return null; // null means success
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          return 'No account found with this email';
        case 'wrong-password':
          return 'Incorrect password — please try again';
        case 'invalid-email':
          return 'Please enter a valid email address';
        case 'invalid-credential':
          return 'Incorrect email or password';
        default:
          return 'Something went wrong — please try again';
      }
    }
  }

  // Sends a password reset email via Firebase
  Future<String?> sendPasswordReset({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return null; // null means success
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          return 'No account found with this email';
        case 'invalid-email':
          return 'Please enter a valid email address';
        default:
          return 'Something went wrong — please try again';
      }
    }
  }

  // Logs out the current user and clears their session
  Future<void> signOut() async {
    await _auth.signOut();
    notifyListeners();
  }
}