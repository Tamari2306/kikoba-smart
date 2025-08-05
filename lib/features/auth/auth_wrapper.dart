import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kikoba_smart/providers/auth_provider.dart';
import '../../models/user_model.dart';

class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final currentUser = ref.watch(currentUserProvider);

    return authState.when(
      data: (firebaseUser) {
        if (firebaseUser == null) {
          // User not authenticated, show login
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // User is authenticated, check if we have user data
        return currentUser.when(
          data: (user) {
            if (user == null) {
              // Firebase user exists but no Firestore data
              return const Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Inapakia taarifa za mtumiaji...'),
                    ],
                  ),
                ),
              );
            }

            // User data loaded, navigate to appropriate dashboard
            WidgetsBinding.instance.addPostFrameCallback((_) {
              switch (user.role) {
                case UserRoles.admin:
                  context.go('/admin/dashboard');
                  break;
                case UserRoles.member:
                  context.go('/member/dashboard');
                  break;
                case UserRoles.diaspora:
                  context.go('/diaspora/dashboard');
                  break;
              }
            });

            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          },
          loading: () => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
          error: (error, stack) => Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Hitilafu: $error'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.go('/login'),
                    child: const Text('Rudi kwenye ukurasa wa kuingia'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Hitilafu ya mtandao: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go('/login'),
                child: const Text('Jaribu tena'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
