import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kikoba_smart/features/member/repay_loan_screen.dart';
import 'package:kikoba_smart/features/member/request_loan_screen.dart';
import '../../../providers/auth_provider.dart';
import 'widgets/dashboard_card.dart';
import 'package:go_router/go_router.dart';
import 'package:kikoba_smart/features/member/make_contribution_screen.dart';


class MemberDashboard extends ConsumerWidget {
  const MemberDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.maybeWhen(
      data: (user) => Scaffold(
        appBar: AppBar(
          title: const Text("Member Dashboard"),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                await ref.read(authServiceProvider).signOut();
                ref.invalidate(currentUserProvider);
                context.go('/login');
              },
            )
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (user != null)
              Card(
                child: ListTile(
                  title: Text("Group: ${user.groupName ?? 'N/A'}"),
                  subtitle: Text("Group ID: ${user.groupId ?? 'N/A'}"),
                  trailing: Text(user.role.toUpperCase()),
                ),
              )
            else
              const Text("No user data found."),

            const SizedBox(height: 12),

            DashboardCard(
              title: "Make Contribution",
              icon: Icons.account_balance_wallet,
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MakeContributionScreen(),));
              },
            ),

            DashboardCard(
              title: "Request Loan",
              icon: Icons.request_page,
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RequestLoanScreen(),));
              },
            ),

            DashboardCard(
              title: "Repay Loan",
              icon: Icons.payments,
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RepayLoanScreen(),));
              },
            ),

          ],
        ),
      ),
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      orElse: () => const Scaffold(
        body: Center(child: Text("Something went wrong.")),
      ),
    );
  }
}
