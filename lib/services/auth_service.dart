import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthResult {
  final bool success;
  final String? message;
  final UserModel? user;

  AuthResult({required this.success, this.message, this.user});
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Get current Firebase user
  User? get currentFirebaseUser => _auth.currentUser;

  // Format phone number (Tanzania format)
  String _formatPhone(String phone) {
    // Remove all non-digit characters
    String digits = phone.replaceAll(RegExp(r'[^\d]'), '');
    
    // Handle different input formats
    if (digits.startsWith('255')) {
      return '+$digits';
    } else if (digits.startsWith('0')) {
      return '+255${digits.substring(1)}';
    } else if (digits.length == 9) {
      return '+255$digits';
    } else {
      return '+255$digits'; // Fallback - let Firebase handle validation
    }
  }

  // Sign up with email and password
  Future<AuthResult> signUpWithEmail({
  required String email,
  required String password,
  required String name,
  required String phone,
  required String role,
  String? groupId,
  String? groupName, // keep this for admin case
}) async {
  try {
    // Create Firebase user
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    if (credential.user == null) {
      return AuthResult(success: false, message: 'Failed to create user account');
    }

    // 🔥 If no groupName provided but groupId is, fetch it from Firestore
    if (groupName == null && groupId != null) {
      final groupDoc = await _firestore.collection('groups').doc(groupId).get();
      if (groupDoc.exists) {
        groupName = groupDoc.data()?['name'] ?? 'Unknown Group';
      }
    }

    // Create user document in Firestore
    final userModel = UserModel(
      id: credential.user!.uid,
      name: name.trim(),
      email: email.trim(),
      phone: _formatPhone(phone),
      role: role.toLowerCase(),
      groupId: groupId,
      groupName: groupName, // ✅ always has a value now
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _firestore.collection('users').doc(credential.user!.uid).set(
      userModel.toFirestore(),
    );

    // Update Firebase display name
    await credential.user!.updateDisplayName(name.trim());

    return AuthResult(success: true, user: userModel);
  } on FirebaseAuthException catch (e) {
    String message = 'An error occurred during sign up';
    switch (e.code) {
      case 'weak-password':
        message = 'The password provided is too weak';
        break;
      case 'email-already-in-use':
        message = 'An account already exists for that email';
        break;
      case 'invalid-email':
        message = 'The email address is not valid';
        break;
      case 'operation-not-allowed':
        message = 'Email/password accounts are not enabled';
        break;
    }
    return AuthResult(success: false, message: message);
  } catch (e) {
    return AuthResult(success: false, message: 'An unexpected error occurred: ${e.toString()}');
  }
}

  // Sign up with phone number
  Future<AuthResult> signUpWithPhone({
    required String phone,
    required String password,
    required String name,
    required String role, // Changed from UserRole to String
    String? groupId,
    String? groupName,
  }) async {
    try {
      // For phone signup, we'll use phone as email (phone@kikoba.app)
      final formattedPhone = _formatPhone(phone);
      final emailFromPhone = '${formattedPhone.replaceAll('+', '')}@kikoba.app';

      return await signUpWithEmail(
        email: emailFromPhone,
        password: password,
        name: name,
        phone: formattedPhone,
        role: role,
        groupId: groupId,
        groupName: groupName,
      );
    } catch (e) {
      return AuthResult(success: false, message: 'Failed to sign up with phone: ${e.toString()}');
    }
  }

  // Sign in with email and password
  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      if (credential.user == null) {
        return AuthResult(success: false, message: 'Failed to sign in');
      }

      // Get user data from Firestore
      final userDoc = await _firestore.collection('users').doc(credential.user!.uid).get();
      
      if (!userDoc.exists) {
        return AuthResult(success: false, message: 'User data not found');
      }

      final userModel = UserModel.fromFirestore(userDoc);
      return AuthResult(success: true, user: userModel);
    } on FirebaseAuthException catch (e) {
      String message = 'Failed to sign in';
      switch (e.code) {
        case 'user-not-found':
          message = 'No user found for that email';
          break;
        case 'wrong-password':
          message = 'Wrong password provided';
          break;
        case 'invalid-email':
          message = 'The email address is not valid';
          break;
        case 'user-disabled':
          message = 'This user account has been disabled';
          break;
        case 'too-many-requests':
          message = 'Too many failed attempts. Please try again later';
          break;
        case 'invalid-credential':
          message = 'Invalid email or password';
          break;
      }
      return AuthResult(success: false, message: message);
    } catch (e) {
      return AuthResult(success: false, message: 'An unexpected error occurred: ${e.toString()}');
    }
  }

  // Sign in with phone number
  Future<AuthResult> signInWithPhone({
    required String phone,
    required String password,
  }) async {
    try {
      final formattedPhone = _formatPhone(phone);
      final emailFromPhone = '${formattedPhone.replaceAll('+', '')}@kikoba.app';

      return await signInWithEmail(
        email: emailFromPhone,
        password: password,
      );
    } catch (e) {
      return AuthResult(success: false, message: 'Failed to sign in with phone: ${e.toString()}');
    }
  }

  // Get current user data
  Future<UserModel?> getCurrentUser() async {
    try {
      final firebaseUser = _auth.currentUser;
      if (firebaseUser == null) return null;

      final userDoc = await _firestore.collection('users').doc(firebaseUser.uid).get();
      
      if (!userDoc.exists) return null;

      return UserModel.fromFirestore(userDoc);
    } catch (e) {
      print('Error getting current user: $e');
      return null;
    }
  }

  // Update user data
  Future<AuthResult> updateUser(UserModel user) async {
    try {
      await _firestore.collection('users').doc(user.id).update(
        user.copyWith(updatedAt: DateTime.now()).toFirestore(),
      );
      return AuthResult(success: true, message: 'User updated successfully');
    } catch (e) {
      return AuthResult(success: false, message: 'Failed to update user: ${e.toString()}');
    }
  }

  // Add user to group
  Future<AuthResult> addUserToGroup(String userId, String groupId, {String? groupName}) async {
  try {
    // If groupName not provided, fetch it from Firestore
    if (groupName == null) {
      final groupDoc = await _firestore.collection('groups').doc(groupId).get();
      if (groupDoc.exists) {
        groupName = groupDoc.data()?['name'] ?? 'Unknown Group';
      } else {
        return AuthResult(success: false, message: 'Group not found');
      }
    }

    // Update user document
    await _firestore.collection('users').doc(userId).update({
      'groupId': groupId,
      'groupName': groupName,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });

    return AuthResult(success: true, message: 'User added to group successfully');
  } catch (e) {
    return AuthResult(success: false, message: 'Failed to add user to group: ${e.toString()}');
  }
}

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Reset password
  Future<AuthResult> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return AuthResult(success: true, message: 'Password reset email sent');
    } on FirebaseAuthException catch (e) {
      String message = 'Failed to send reset email';
      switch (e.code) {
        case 'user-not-found':
          message = 'No user found for that email';
          break;
        case 'invalid-email':
          message = 'The email address is not valid';
          break;
      }
      return AuthResult(success: false, message: message);
    } catch (e) {
      return AuthResult(success: false, message: 'An unexpected error occurred');
    }
  }
}