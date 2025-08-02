import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

// Expose AuthService via provider
final authServiceProvider = Provider<AuthService>((ref) => AuthService());

// Current authenticated AppUser stream
final currentUserProvider = FutureProvider<AppUser?>((ref) async {
  final authService = ref.watch(authServiceProvider);
  return await authService.getCurrentUser();
});
