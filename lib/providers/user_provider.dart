import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kikoba_smart/providers/auth_provider.dart';
import '../models/user_model.dart';

final currentUserProvider = FutureProvider<UserModel?>((ref) async {
  final authService = ref.watch(authServiceProvider);
  return await authService.getCurrentUser(); // must include role
});
