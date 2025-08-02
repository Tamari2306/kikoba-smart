// lib/features/member/request_loan_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../providers/user_provider.dart';

class RequestLoanScreen extends ConsumerStatefulWidget {
  const RequestLoanScreen({super.key});

  @override
  ConsumerState<RequestLoanScreen> createState() => _RequestLoanScreenState();
}

class _RequestLoanScreenState extends ConsumerState<RequestLoanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text("Request Loan")),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text("Error: $err")),
        data: (user) {
          if (user == null || user.groupId == null) {
            return const Center(child: Text("Group not found."));
          }

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "Loan Amount (TZS)"),
                    validator: (val) {
                      if (val == null || val.isEmpty) return "Enter amount";
                      if (int.tryParse(val) == null) return "Enter a valid number";
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  _loading
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                          onPressed: () => _submitLoanRequest(user.groupId!, user.uid, user.name),
                          child: const Text("Submit Request"),
                        )
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _submitLoanRequest(String groupId, String userId, String userName) async {
    if (!_formKey.currentState!.validate()) return;
    final amount = int.parse(_amountController.text);

    setState(() => _loading = true);

    try {
      final groupDoc = await FirebaseFirestore.instance.collection('groups').doc(groupId).get();
      final interestRate = groupDoc.data()?['interestRate'] ?? 10; // default 10%

      // Determine loan duration
      int durationDays;
      if (amount <= 1000000) {
        durationDays = 90;
      } else if (amount <= 3000000) {
        durationDays = 180;
      } else {
        durationDays = 270;
      }

      // Calculate interest and total repayable
      final interest = (amount * (interestRate / 100)).round();
      final totalRepayable = amount + interest;

      final createdAt = DateTime.now();
      final dueDate = createdAt.add(Duration(days: durationDays));

      await FirebaseFirestore.instance
          .collection('groups')
          .doc(groupId)
          .collection('loanRequests')
          .add({
        'userId': userId,
        'userName': userName,
        'amount': amount,
        'interest': interest,
        'totalRepayable': totalRepayable,
        'durationDays': durationDays,
        'dueDate': dueDate,
        'createdAt': createdAt,
        'approved': false,
        'status': 'pending',
        'repayedAmount': 0,
      });

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Loan request submitted")));
    } catch (e) {
      debugPrint("Loan request error: $e");
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Something went wrong.")));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
