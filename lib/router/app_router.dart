import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kikoba_smart/features/admin/approve_loans_screen.dart';
import 'package:kikoba_smart/features/admin/manage_members_screen.dart';
import 'package:kikoba_smart/features/admin/view_contributions_screen.dart';
import 'package:kikoba_smart/features/admin/view_loan_requests_screen.dart';
import 'package:kikoba_smart/features/auth/login_screen.dart';
import 'package:kikoba_smart/features/auth/signup_screen.dart';
import 'package:kikoba_smart/features/dashboard/admin_dashboard.dart';
import 'package:kikoba_smart/features/dashboard/diaspora_dashboard.dart';
import 'package:kikoba_smart/features/dashboard/member_dashboard.dart';
import 'package:kikoba_smart/providers/auth_provider.dart';
import 'package:kikoba_smart/features/admin/group_constitution_screen.dart';



final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) async {
      final auth = ref.read(authStateProvider);
      final user = await ref.read(currentUserProvider.future);

      final isLoggingIn = state.fullPath == '/login' || state.fullPath == '/signup';
      if (auth.asData?.value == null && !isLoggingIn) {
        return '/login';
      }

      if (user != null) {
        switch (user.role) {
          case 'admin':
            return '/dashboard/admin';
          case 'member':
            return '/dashboard/member';
          case 'diaspora':
            return '/dashboard/diaspora';
        }
      }

      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (_, __) => const SignupScreen()),
      GoRoute(path: '/dashboard/admin', builder: (_, __) => const AdminDashboard()),
      GoRoute(path: '/dashboard/member', builder: (_, __) => const MemberDashboard()),
      GoRoute(path: '/dashboard/diaspora', builder: (_, __) => const DiasporaDashboard()),
      GoRoute(path: '/admin/contributions', builder: (_, __) => const ViewContributionsScreen()),
      GoRoute(path: '/admin/manage-members', builder: (_, __) => const ManageMembersScreen()),
      GoRoute(path: '/admin/approve-loans', builder: (_, __) => const ApproveLoansScreen()),
      GoRoute(path: '/admin/loan-requests',builder: (_, __) => const ViewLoanRequestsScreen()),
      GoRoute(path: '/group/constitution',builder: (context, state) => const GroupConstitutionScreen()),

    ],
  );
});

class KikobaApp extends ConsumerWidget {
  const KikobaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Kikoba Smart',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      routerConfig: router,
    );
  }
}
