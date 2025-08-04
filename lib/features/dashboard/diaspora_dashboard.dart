import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/auth_provider.dart';
import 'widgets/dashboard_card.dart';

class DiasporaDashboard extends ConsumerWidget {
  const DiasporaDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final authService = ref.read(authServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Diaspora Dashboard"),
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
                title: "Invest in Group",
                icon: Icons.attach_money,
                color: Colors.green,
                onTap: () {
                  // TODO
                },
              ),
              DashboardCard(
                title: "Monitor Group Activity",
                icon: Icons.bar_chart,
                color: Colors.blue,
                onTap: () {
                  // TODO
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
