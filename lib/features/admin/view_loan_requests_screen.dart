// lib/features/admin/view_loan_requests_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/user_provider.dart';

class ViewLoanRequestsScreen extends ConsumerWidget {
  const ViewLoanRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      data: (user) {
        if (user?.groupId == null) {
          return const Scaffold(
            body: Center(child: Text("No group context.")),
          );
        }

        final groupId = user!.groupId!;
        final loansQuery = FirebaseFirestore.instance
            .collection('groups')
            .doc(groupId)
            .collection('loanRequests') 
            .orderBy('createdAt', descending: true); // ✅ Fixed field name

        return Scaffold(
          appBar: AppBar(title: const Text("All Loan Requests")),
          body: StreamBuilder<QuerySnapshot>(
            stream: loansQuery.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text("Error loading loans: ${snapshot.error}"));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text("No loan requests found."));
              }

              final docs = snapshot.data!.docs;

              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final status = data['status'] ?? 'unknown';
                  final amount = data['amount'];
                  final userName = data['userName'] ?? 'Unknown';
                  final createdAt = (data['createdAt'] as Timestamp).toDate(); // ✅ Fixed field name

                  // Color coding for different statuses
                  Color statusColor;
                  IconData statusIcon;
                  switch (status.toLowerCase()) {
                    case 'approved':
                      statusColor = Colors.green;
                      statusIcon = Icons.check_circle;
                      break;
                    case 'rejected':
                      statusColor = Colors.red;
                      statusIcon = Icons.cancel;
                      break;
                    case 'pending':
                      statusColor = Colors.orange;
                      statusIcon = Icons.pending;
                      break;
                    default:
                      statusColor = Colors.grey;
                      statusIcon = Icons.help;
                  }

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: ListTile(
                      leading: Icon(statusIcon, color: statusColor),
                      title: Text("TZS ${amount?.toString() ?? '0'}"),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("User: $userName"),
                          Text(
                            "Status: ${status.toUpperCase()}", 
                            style: TextStyle(
                              color: statusColor, 
                              fontWeight: FontWeight.bold
                            ),
                          ),
                        ],
                      ),
                      trailing: Text(
                        "${createdAt.day}/${createdAt.month}/${createdAt.year}",
                        style: const TextStyle(fontSize: 12),
                      ),
                      isThreeLine: true,
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