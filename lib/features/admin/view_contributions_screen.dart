import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/user_provider.dart';

class ViewContributionsScreen extends ConsumerStatefulWidget {
  const ViewContributionsScreen({super.key});

  @override
  ConsumerState<ViewContributionsScreen> createState() => _ViewContributionsScreenState();
}

class _ViewContributionsScreenState extends ConsumerState<ViewContributionsScreen> {
  String _sortBy = 'date'; // 'date' or 'user'
  String _filterType = 'all'; // 'all', 'hisa', or 'jamii'

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      data: (user) {
        if (user?.groupId == null) {
          return const Scaffold(
            body: Center(child: Text("No group context.")),
          );
        }

        final groupId = user!.groupId!;
        Query contributionsQuery = FirebaseFirestore.instance
            .collection('groups')
            .doc(groupId)
            .collection('contributions');

        // Add filter by type if needed
        if (_filterType != 'all') {
          contributionsQuery = contributionsQuery.where('type', isEqualTo: _filterType);
        }

        // Sort
        contributionsQuery = contributionsQuery
            .orderBy(_sortBy == 'date' ? 'timestamp' : 'userName', descending: _sortBy == 'date');

        return Scaffold(
          appBar: AppBar(
            title: const Text('View Contributions'),
            actions: [
              DropdownButton<String>(
                value: _sortBy,
                underline: const SizedBox(),
                icon: const Icon(Icons.sort, color: Colors.white),
                dropdownColor: Colors.blue,
                items: const [
                  DropdownMenuItem(value: 'date', child: Text("Sort by Date")),
                  DropdownMenuItem(value: 'user', child: Text("Sort by User")),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _sortBy = value;
                    });
                  }
                },
              ),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _filterType,
                underline: const SizedBox(),
                icon: const Icon(Icons.filter_alt, color: Colors.white),
                dropdownColor: Colors.blue,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text("All")),
                  DropdownMenuItem(value: 'hisa', child: Text("Hisa Only")),
                  DropdownMenuItem(value: 'jamii', child: Text("Jamii Only")),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _filterType = value;
                    });
                  }
                },
              ),
            ],
          ),
          body: StreamBuilder<QuerySnapshot>(
            stream: contributionsQuery.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(child: Text("Error loading contributions."));
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text("No contributions found."));
              }

              final docs = snapshot.data!.docs;

              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  return ListTile(
                    leading: const Icon(Icons.attach_money),
                    title: Text("TZS ${data['amount']}"),
                    subtitle: Text(
  "By: ${data['userName'] ?? 'Unknown'} | Type: ${data['type'] ?? 'N/A'}"
),

                    trailing: Text(
                      (data['timestamp'] as Timestamp).toDate().toLocal().toString().split('.').first,
                      style: const TextStyle(fontSize: 12),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, _) => Scaffold(body: Center(child: Text("Error: $err"))),
    );
  }
}
