import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kikoba_smart/features/admin/approve_loans_screen.dart';
import 'package:kikoba_smart/features/admin/view_loan_requests_screen.dart';
import 'package:kikoba_smart/features/admin/view_repayments_screen.dart';
import '../../../providers/auth_provider.dart';
import 'widgets/dashboard_card.dart';
import '../admin/add_member_screen.dart';
import '../../features/admin/manage_members_screen.dart';
import 'package:kikoba_smart/features/admin/view_contributions_screen.dart';
import '../admin/group_constitution_screen.dart';



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
  title: "Group Constitution",
  icon: Icons.article,
  onTap: () {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const GroupConstitutionScreen()),
    );
  },
),

              DashboardCard(
                title: "Add Member",
                icon: Icons.group_add,
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
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ManageMembersScreen()),
                ),
              ),
              DashboardCard(
                title: "Approve Loans",
                icon: Icons.verified,
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
                onTap: () {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const ViewContributionsScreen()),
  );
},
              ),


              DashboardCard(
  title: "Loan Requests",
  icon: Icons.list_alt,
  onTap: () {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const ViewLoanRequestsScreen()),
  );
},
              ),


              DashboardCard(
  title: "View Repayments",
  icon: Icons.payment,
  onTap: () {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ViewRepaymentsScreen()),
    );
  },
)

            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text("Error: $err")),
      ),
    );
  }
}
