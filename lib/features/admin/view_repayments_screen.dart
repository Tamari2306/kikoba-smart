import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/user_provider.dart';

class ViewRepaymentsScreen extends ConsumerWidget {
  const ViewRepaymentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      data: (user) {
        if (user == null || user.groupId == null) {
          return const Scaffold(body: Center(child: Text("No group found.")));
        }

        final stream = FirebaseFirestore.instance
            .collection('groups')
            .doc(user.groupId)
            .collection('repayments')
            .orderBy('createdAt', descending: true) // ✅ Fixed field name
            .snapshots();

        return Scaffold(
          appBar: AppBar(title: const Text('Loan Repayments')),
          body: StreamBuilder<QuerySnapshot>(
            stream: stream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Error loading repayments: ${snapshot.error}'),
                    ],
                  ),
                );
              }
              
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.payment, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No repayments yet', style: TextStyle(fontSize: 18)),
                      SizedBox(height: 8),
                      Text('Repayments will appear here once members start paying back loans'),
                    ],
                  ),
                );
              }

              final docs = snapshot.data!.docs;

              return ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final amount = data['amount'] ?? 0;
                  final userName = data['userName'] ?? 'Unknown';
                  final loanId = data['loanId'] ?? 'N/A';
                  
                  // Handle different possible timestamp field names
                  DateTime? repaymentDate;
                  if (data['createdAt'] != null) {
                    repaymentDate = (data['createdAt'] as Timestamp).toDate();
                  } else if (data['timestamp'] != null) {
                    repaymentDate = (data['timestamp'] as Timestamp).toDate();
                  } else if (data['paidAt'] != null) {
                    repaymentDate = (data['paidAt'] as Timestamp).toDate();
                  }

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.green.shade100,
                        child: const Icon(Icons.payment, color: Colors.green),
                      ),
                      title: Text(
                        "TZS ${amount.toString()}",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("By: $userName"),
                          if (loanId != 'N/A') Text("Loan ID: $loanId", style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                      trailing: repaymentDate != null
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  "${repaymentDate.day}/${repaymentDate.month}/${repaymentDate.year}",
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                ),
                                Text(
                                  "${repaymentDate.hour.toString().padLeft(2, '0')}:${repaymentDate.minute.toString().padLeft(2, '0')}",
                                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                                ),
                              ],
                            )
                          : const Text("No date", style: TextStyle(fontSize: 12)),
                      isThreeLine: loanId != 'N/A',
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