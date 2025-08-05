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
  final Map<String, bool> _expandedUsers = {};

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      data: (user) {
        if (user?.groupId == null) {
          return const Scaffold(body: Center(child: Text("No group context.")));
        }

        final groupId = user!.groupId!;
        final isAdmin = user.role == 'admin';

        Query contributionsQuery = FirebaseFirestore.instance
            .collection('groups')
            .doc(groupId)
            .collection('contributions');

        if (_filterType != 'all') {
          contributionsQuery = contributionsQuery.where('type', isEqualTo: _filterType);
        }

        contributionsQuery = contributionsQuery
            .orderBy(_sortBy == 'date' ? 'timestamp' : 'userName', descending: _sortBy == 'date');

        return Scaffold(
          appBar: AppBar(
            title: const Text('Group Contributions'),
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
                onChanged: (value) => setState(() => _sortBy = value!),
              ),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _filterType,
                underline: const SizedBox(),
                icon: const Icon(Icons.filter_alt, color: Colors.white),
                dropdownColor: Colors.blue,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text("All Types")),
                  DropdownMenuItem(value: 'hisa', child: Text("Hisa Only")),
                  DropdownMenuItem(value: 'jamii', child: Text("Jamii Only")),
                ],
                onChanged: (value) => setState(() => _filterType = value!),
              ),
            ],
          ),
          body: StreamBuilder<QuerySnapshot>(
            stream: contributionsQuery.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(child: Text("Error loading contributions."));
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data!.docs;

              if (docs.isEmpty) {
                return const Center(child: Text("No contributions found."));
              }

              final contributionsByUser = <String, List<Map<String, dynamic>>>{};
              double totalAmount = 0;
              final typeTotals = {'hisa': 0.0, 'jamii': 0.0};

              for (var doc in docs) {
                final data = doc.data() as Map<String, dynamic>;
                final userName = data['userName'] ?? 'Unknown';
                final amount = (data['amount'] as num).toDouble();
                final type = data['type'] ?? 'unknown';

                totalAmount += amount;
                if (typeTotals.containsKey(type)) {
                  typeTotals[type] = typeTotals[type]! + amount;
                }

                contributionsByUser.putIfAbsent(userName, () => []);
                contributionsByUser[userName]!.add({...data, 'id': doc.id});
              }

              return Column(
                children: [
                  // Summary Card
                  Card(
                    margin: const EdgeInsets.all(12),
                    color: Colors.blue.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Total Contributions: TZS ${totalAmount.toStringAsFixed(0)}",
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 8),
                          Text("Hisa Total: TZS ${typeTotals['hisa']!.toStringAsFixed(0)}"),
                          Text("Jamii Total: TZS ${typeTotals['jamii']!.toStringAsFixed(0)}"),
                          const SizedBox(height: 8),
                          Text("Contributors: ${contributionsByUser.keys.length}"),
                        ],
                      ),
                    ),
                  ),

                  Expanded(
                    child: ListView(
                      children: contributionsByUser.entries.map((entry) {
                        final userName = entry.key;
                        final userContributions = entry.value;

                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          child: ExpansionTile(
                            key: PageStorageKey(userName),
                            title: Text(userName, style: const TextStyle(fontWeight: FontWeight.bold)),
                            initiallyExpanded: _expandedUsers[userName] ?? false,
                            onExpansionChanged: (expanded) {
                              setState(() {
                                _expandedUsers[userName] = expanded;
                              });
                            },
                            children: userContributions.map((data) {
                              final date = (data['timestamp'] as Timestamp).toDate().toLocal();
                              return ListTile(
                                leading: const Icon(Icons.attach_money),
                                title: Text("TZS ${data['amount']}"),
                                subtitle: Text("Type: ${data['type']} • ${date.toString().split('.').first}"),
                                trailing: isAdmin
                                    ? Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit, color: Colors.green),
                                            onPressed: () {
                                              // TODO: Implement edit logic
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text("Edit feature coming soon")),
                                              );
                                            },
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete, color: Colors.red),
                                            onPressed: () async {
                                              final confirm = await showDialog<bool>(
                                                context: context,
                                                builder: (_) => AlertDialog(
                                                  title: const Text("Confirm Delete"),
                                                  content: const Text("Delete this contribution?"),
                                                  actions: [
                                                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
                                                    TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Delete")),
                                                  ],
                                                ),
                                              );

                                              if (confirm == true) {
                                                await FirebaseFirestore.instance
                                                    .collection('groups')
                                                    .doc(groupId)
                                                    .collection('contributions')
                                                    .doc(data['id'])
                                                    .delete();

                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(content: Text("Contribution deleted")),
                                                );
                                              }
                                            },
                                          ),
                                        ],
                                      )
                                    : null,
                              );
                            }).toList(),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
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
