// lib/features/admin/manage_members_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../providers/user_provider.dart';

class ManageMembersScreen extends ConsumerWidget {
  const ManageMembersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const Scaffold(
        body: Center(child: Text('Something went wrong.')),
      ),
      data: (user) {
        if (user == null || user.groupId == null) {
          return const Scaffold(
            body: Center(child: Text("No group context.")),
          );
        }

        final membersQuery = FirebaseFirestore.instance
            .collection('users')
            .where('groupId', isEqualTo: user.groupId)
            .where('role', isEqualTo: 'member');

        return Scaffold(
          appBar: AppBar(title: const Text("Manage Members")),
          body: StreamBuilder<QuerySnapshot>(
            stream: membersQuery.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(child: Text("Error loading members."));
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data!.docs;

              if (docs.isEmpty) {
                return const Center(child: Text("No members found."));
              }

              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;

                  return ListTile(
                    leading: const Icon(Icons.person),
                    title: Text(data['name'] ?? 'No Name'),
                    subtitle: Text("${data['email'] ?? ''}\nPhone: ${data['phone'] ?? 'N/A'}"),
                    isThreeLine: true,
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}
