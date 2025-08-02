import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<AppUser?> getCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final doc = await _db.collection('users').doc(user.uid).get();
    if (!doc.exists) return null;

    final userData = doc.data()!;
    String? groupName;

    // If groupId exists, fetch group name
    final groupId = userData['groupId'];
    if (groupId != null && groupId is String && groupId.isNotEmpty) {
      final groupDoc = await _db.collection('groups').doc(groupId).get();
      groupName = groupDoc.data()?['name'];
    }

    return AppUser.fromMap({
      ...userData,
      'groupName': groupName,
    });
  }

  Future<void> signUp({
    required String name,
    required String email,
    required String password,
    required String role,
    String? groupId,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final user = AppUser(
      uid: cred.user!.uid,
      name: name,
      email: email,
      role: role,
      groupId: groupId,
      groupName: null, // Will be fetched later
    );

    await _db.collection('users').doc(user.uid).set(user.toMap());
  }

  Future<void> signIn(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
