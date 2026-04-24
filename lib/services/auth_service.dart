import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

//handles everything auth, signup login logout and password reset
//extends ChangeNotifier so any screen listening to this can rebuild when auth state changes
class AuthService extends ChangeNotifier {
  //firebase auth handles credential stuff email password sessions
  final FirebaseAuth _auth = FirebaseAuth.instance;
  //firestore is where we store the user info (sername since firebase auth doesnt hold that
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  //getter that returns the logged in user or null if not logged in
  //used by the router redirect in main.dart to decide if user should see login or dashboard
  User? get currentUser => _auth.currentUser;

  //stream that goes whenever auth state changes login logout session expire !
  //not hooked up to the router yet which is why the redirect bug exists fix this one day
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  //signs up a new user
  //returns null on success or a string error message on failure
  //first it create the firebase auth account then write the user doc to firestore
  Future<String?> signUp({
    required String email,
    required String password,
    required String username,
  }) async {
    try {
      //check if username already exists before accounts createdd
      //firebase auth handles email uniqueness automatically but usernames are our own thing
      final usernameQuery = await _firestore
          .collection('users')
          .where('username', isEqualTo: username.trim())
          .get();

      //if the query found any docs the username is already in use
      if (usernameQuery.docs.isNotEmpty) {
        return 'Username already taken — please choose another';
      }

      //create the firebase auth account this handles password hashing internally
      //we never store the password anywhere ourselves all firebase
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      //write the user doc to firestore using the uid from firebase auth as the doc id
      //this links the auth account to the firestore user record
      await _firestore
          .collection('users')
          .doc(credential.user!.uid)
          .set({
        'userId': credential.user!.uid,
        'email': email.trim(),
        'username': username.trim(),
      });

      //null means no error signup worked
      return null;
    } on FirebaseAuthException catch (e) {
      //firebase throws these exceptions with error codes we can map to friendly messages
      //without this the user would see a scary raw error like FIREBASE_AUTH/INVALID_EMAIL think we fixed it
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

  //logs in an existing user
  //same pattern as signup null on success or error string on failure
  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      //firebase checks the email password combo and sets up a session
      //if this succeeds currentUser will have a value after this line runs
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return null;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          return 'No account found with this email';
        case 'wrong-password':
          return 'Incorrect password — please try again';
        case 'invalid-email':
          return 'Please enter a valid email address';
      //invalid credential is the newer generic error firebase uses instead of wrong password
        case 'invalid-credential':
          return 'Incorrect email or password';
        default:
          return 'Something went wrong — please try again';
      }
    }
  }

  //sends a password reset email through firebase
  //firebase handles the whole email template and reset link
  Future<String?> sendPasswordReset({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return null;
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

  //logs out the current user and clears the session
  //notifyListeners tells any widget listening to this service to rebuild
  //thats how we make sure the redirect eventually kicks in after logout
  Future<void> signOut() async {
    await _auth.signOut();
    notifyListeners();
  }
}