// lib/features/admin/approve_loans_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../providers/user_provider.dart';

class ApproveLoansScreen extends ConsumerWidget {
  const ApproveLoansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(body: Center(child: Text("Error: $error"))),
      data: (user) {
        if (user == null || user.groupId == null) {
          return const Scaffold(body: Center(child: Text("No group context.")));
        }

        final groupId = user.groupId!;
        final loansQuery = FirebaseFirestore.instance
            .collection('groups')
            .doc(groupId)
            .collection('loanRequests')
            .where('status', isEqualTo: 'pending')
            .orderBy('createdAt', descending: true);

        return Scaffold(
          appBar: AppBar(title: const Text("Approve Loans")),
          body: StreamBuilder<QuerySnapshot>(
            stream: loansQuery.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {return Center(child: Text("Error: ${snapshot.error}"));}
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

              final docs = snapshot.data!.docs;
              if (docs.isEmpty) return const Center(child: Text("No pending loans."));

              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final loanId = docs[index].id;

                  final duration = data['durationDays'] ?? 0;
                  final dueDate = (data['dueDate'] as Timestamp?)?.toDate();

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ListTile(
                      title: Text("TZS ${data['amount']} - ${data['userName'] ?? 'Unknown'}"),
                      subtitle: Text(
                        "Duration: $duration days\nDue: ${dueDate != null ? _formatDate(dueDate) : 'N/A'}",
                      ),
                      isThreeLine: true,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.check, color: Colors.green),
                            onPressed: () async {
                              await _approveLoan(groupId, loanId, data);
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.red),
                            onPressed: () async {
                              final reason = await _getRejectionReason(context);
                              if (reason != null && reason.trim().isNotEmpty) {
                                await _rejectLoan(groupId, loanId, reason.trim());
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    return "${date.day}/${date.month}/${date.year}";
  }

  Future<void> _approveLoan(String groupId, String loanId, Map<String, dynamic> data) async {
  final requestRef = FirebaseFirestore.instance
      .collection('groups')
      .doc(groupId)
      .collection('loanRequests')
      .doc(loanId);
  
  final loansRef = FirebaseFirestore.instance
      .collection('groups')
      .doc(groupId)
      .collection('loans');

  final approvedData = {
    ...data,
    'status': 'approved',
    'approved': true,
    'approvedAt': DateTime.now(),
  };

  // Add to loans collection
  await loansRef.add(approvedData);
  
  // Update status instead of deleting ✅
  await requestRef.update({
    'status': 'approved',
    'approved': true,
    'approvedAt': DateTime.now(),
  });
  
}

  Future<void> _rejectLoan(String groupId, String loanId, String reason) async {
    final requestRef = FirebaseFirestore.instance.collection('groups').doc(groupId).collection('loanRequests').doc(loanId);
    await requestRef.update({
      'status': 'rejected',
      'approved': false,
      'rejectionReason': reason,
      'rejectedAt': DateTime.now(),
    });
  }

  Future<String?> _getRejectionReason(BuildContext context) async {
    String reason = '';

    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Rejection Reason"),
          content: TextField(
            autofocus: true,
            decoration: const InputDecoration(hintText: "Enter reason..."),
            onChanged: (val) => reason = val,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, reason),
              child: const Text("Submit"),
            ),
          ],
        );
      },
    );
  }
}
