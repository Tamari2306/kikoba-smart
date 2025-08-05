import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';

// Auth service provider
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

// Firebase user stream provider
final authStateProvider = StreamProvider<User?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges;
});

// Current user provider
final currentUserProvider = FutureProvider<UserModel?>((ref) async {
  // Watch auth state to trigger rebuild when user signs in/out
  final authState = ref.watch(authStateProvider);
  
  return authState.when(
    data: (user) async {
      if (user == null) return null;
      final authService = ref.watch(authServiceProvider);
      return await authService.getCurrentUser();
    },
    loading: () => null,
    error: (_, __) => null,
  );
});