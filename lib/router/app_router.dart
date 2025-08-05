import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kikoba_smart/features/admin/approve_loans_screen.dart';
import 'package:kikoba_smart/features/admin/close_group_screen.dart';
import 'package:kikoba_smart/features/admin/group_creation_screen.dart';
import 'package:kikoba_smart/features/admin/manage_members_screen.dart';
import 'package:kikoba_smart/features/admin/view_contributions_screen.dart';
import 'package:kikoba_smart/features/admin/view_loan_requests_screen.dart';
import 'package:kikoba_smart/features/auth/login_screen.dart';
import 'package:kikoba_smart/features/auth/signup_screen.dart';
import 'package:kikoba_smart/features/dashboard/admin_dashboard.dart';
import 'package:kikoba_smart/features/dashboard/diaspora_dashboard.dart';
import 'package:kikoba_smart/features/dashboard/member_dashboard.dart';
import 'package:kikoba_smart/providers/auth_provider.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final userAsync = ref.watch(currentUserProvider);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: GoRouterRefreshStream(ref.watch(authStateProvider.stream)),
    redirect: (context, state) {
      final isLoggingIn = state.fullPath == '/login' || state.fullPath == '/signup';
      final isAuthenticated = authState.value != null;

      // 1. If still loading auth state, don't redirect
      if (authState.isLoading || userAsync.isLoading) {
        return null;
      }

      // 2. Not authenticated and not on login/signup -> go to login
      if (!isAuthenticated && !isLoggingIn) {
        return '/login';
      }

      // 3. Authenticated but on login/signup page -> redirect based on role
      if (isAuthenticated && isLoggingIn) {
        final user = userAsync.value;
        if (user == null) return null; // still loading

        switch (user.role) {
          case 'admin':
            return '/dashboard/admin';
          case 'member':
            return '/dashboard/member';
          case 'diaspora':
            return '/dashboard/diaspora';
          default:
            return '/login'; // fallback
        }
      }

      // 4. Allow navigation
      return null;
    },
    routes: [
      /// AUTH
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupScreen(),
      ),

      /// DASHBOARDS
      GoRoute(
        path: '/dashboard/admin',
        builder: (context, state) => const AdminDashboard(),
      ),
      GoRoute(
        path: '/dashboard/member',
        builder: (context, state) => const MemberDashboard(),
      ),
      GoRoute(
        path: '/dashboard/diaspora',
        builder: (context, state) => const DiasporaDashboard(),
      ),

      /// ADMIN FEATURES
      GoRoute(
        path: '/admin/contributions',
        builder: (context, state) => const ViewContributionsScreen(),
      ),
      GoRoute(
        path: '/admin/manage-members',
        builder: (context, state) => const ManageMembersScreen(),
      ),
      GoRoute(
        path: '/admin/approve-loans',
        builder: (context, state) => const ApproveLoansScreen(),
      ),
      GoRoute(
        path: '/admin/loan-requests',
        builder: (context, state) => const ViewLoanRequestsScreen(),
      ),
      GoRoute(
        path: '/group-creation',
        builder: (context, state) => const GroupCreationScreen(),
      ),
      GoRoute(
        path: '/close-group',
        builder: (context, state) => const CloseGroupScreen(),
      ),
    ],
  );
});

/// Allows GoRouter to refresh when auth state changes
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
