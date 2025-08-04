import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kikoba_smart/features/admin/approve_loans_screen.dart';
import 'package:kikoba_smart/features/admin/penalty_management_screen.dart';
import 'package:kikoba_smart/features/admin/view_loan_requests_screen.dart';
import 'package:kikoba_smart/features/admin/view_repayments_screen.dart';
import 'package:kikoba_smart/features/admin/close_group_screen.dart';
import '../../../providers/auth_provider.dart';
import 'widgets/dashboard_card.dart';
import '../admin/add_member_screen.dart';
import '../../features/admin/manage_members_screen.dart';
import 'package:kikoba_smart/features/admin/view_contributions_screen.dart';
import 'package:kikoba_smart/features/admin/group_creation_screen.dart';

class AdminDashboard extends ConsumerWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final authService = ref.read(authServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Dashboard"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await authService.signOut();
            },
          ),
        ],
      ),
      body: userAsync.when(
        data: (user) {
          if (user == null) {
            return const Center(child: Text("User not found."));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  title: Text("Group: ${user.groupName ?? 'N/A'}"),
                  subtitle: Text("Group ID: ${user.groupId ?? 'N/A'}"),
                  trailing: Text(user.role.toUpperCase()),
                ),
              ),
              const SizedBox(height: 16),

              DashboardCard(
                title: "Group Setup",
                icon: Icons.settings,
                color: Colors.blue,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const GroupCreationScreen()),
                  );
                },
              ),

              DashboardCard(
                title: "Add Member",
                icon: Icons.group_add,
                color: Colors.green,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AddMemberScreen()),
                  );
                },
              ),

              DashboardCard(
                title: "Manage Members",
                icon: Icons.group,
                color: Colors.orange,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ManageMembersScreen()),
                ),
              ),

              DashboardCard(
                title: "Approve Loans",
                icon: Icons.verified,
                color: Colors.purple,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ApproveLoansScreen()),
                  );
                },
              ),

              DashboardCard(
                title: "View Contributions",
                icon: Icons.receipt_long,
                color: Colors.teal,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ViewContributionsScreen()),
                  );
                },
              ),

              DashboardCard(
                title: "Loan Requests",
                icon: Icons.list_alt,
                color: Colors.indigo,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ViewLoanRequestsScreen()),
                  );
                },
              ),

              DashboardCard(
                title: "View Repayments",
                icon: Icons.payment,
                color: Colors.brown,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ViewRepaymentsScreen()),
                  );
                },
              ),

              DashboardCard(
                title: "Penalty Management",
                icon: Icons.warning,
                color: Colors.amber,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PenaltyManagementScreen()),
                  );
                },
              ),

              // Add the Close Group card
              DashboardCard(
                title: "Close Group",
                icon: Icons.close,
                color: Colors.red,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CloseGroupScreen()),
                  );
                },
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text("Error: $err")),
      ),
    );
  }
}