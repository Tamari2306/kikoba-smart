// lib/features/member/repay_loan_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../providers/user_provider.dart';

class RepayLoanScreen extends ConsumerStatefulWidget {
  const RepayLoanScreen({super.key});

  @override
  ConsumerState<RepayLoanScreen> createState() => _RepayLoanScreenState();
}

class _RepayLoanScreenState extends ConsumerState<RepayLoanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text("Repay Loan")),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text("Error: $err")),
        data: (user) {
          if (user == null || user.groupId == null) {
            return const Center(child: Text("Group not found."));
          }

          final loanQuery = FirebaseFirestore.instance
              .collection('groups')
              .doc(user.groupId)
              .collection('loans')
              .where('userId', isEqualTo: user.uid)
              .where('status', isEqualTo: 'approved');

          return StreamBuilder<QuerySnapshot>(
            stream: loanQuery.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return const Center(child: Text("Error loading loan"));
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text("No active loan found"));
              }

              final loanDoc = snapshot.data!.docs.first;
              final loanData = loanDoc.data() as Map<String, dynamic>;
              final repaidAmount = (loanData['repayedAmount'] ?? 0) as int;
              final totalRepayable = (loanData['totalRepayable'] ?? 0) as int;
              final remaining = totalRepayable - repaidAmount;

              return Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Loan Summary", style: Theme.of(context).textTheme.titleLarge),
                              const SizedBox(height: 8),
                              Text("Total repayable: TZS ${totalRepayable.toString()}"),
                              Text("Already repaid: TZS ${repaidAmount.toString()}"),
                              Text(
                                "Remaining: TZS ${remaining.toString()}",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: remaining > 0 ? Colors.red : Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: "Repayment Amount (TZS)",
                          border: OutlineInputBorder(),
                        ),
                        validator: (val) {
                          if (val == null || val.isEmpty) return "Enter amount";
                          final amt = int.tryParse(val);
                          if (amt == null || amt <= 0) return "Enter a valid amount";
                          if (amt > remaining) return "Amount exceeds remaining balance";
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      _loading
                          ? const CircularProgressIndicator()
                          : ElevatedButton(
                              onPressed: () async => await _submitRepayment(
                                user.groupId!,
                                loanDoc.id,
                                loanData,
                                repaidAmount,
                                user.name,
                                user.uid,
                              ),
                              child: const Text("Submit Repayment"),
                            )
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _submitRepayment(
    String groupId, 
    String loanId, 
    Map<String, dynamic> loanData,
    int alreadyRepaid,
    String userName,
    String userId,
  ) async {
    if (!_formKey.currentState!.validate()) return;

    final repayAmount = int.parse(_amountController.text);
    setState(() => _loading = true);

    try {
      final batch = FirebaseFirestore.instance.batch();
      
      // Update the loan document
      final loanRef = FirebaseFirestore.instance
          .collection('groups')
          .doc(groupId)
          .collection('loans')
          .doc(loanId);

      final newRepaidAmount = alreadyRepaid + repayAmount;
      final totalRepayable = loanData['totalRepayable'] ?? 0;
      final isFullyPaid = newRepaidAmount >= totalRepayable;

      batch.update(loanRef, {
        'repayedAmount': newRepaidAmount,
        'status': isFullyPaid ? 'fully_paid' : 'approved',
        'lastRepaymentDate': FieldValue.serverTimestamp(),
      });

      // ✅ Save to group-level repayments collection (where ViewRepaymentsScreen looks)
      final groupRepaymentsRef = FirebaseFirestore.instance
          .collection('groups')
          .doc(groupId)
          .collection('repayments')
          .doc(); // Create new document

      batch.set(groupRepaymentsRef, {
        'amount': repayAmount,
        'createdAt': FieldValue.serverTimestamp(), // ✅ Using createdAt to match ViewRepaymentsScreen
        'userId': userId,
        'userName': userName,
        'loanId': loanId,
        'previousAmount': alreadyRepaid,
        'newTotal': newRepaidAmount,
        'isFullPayment': isFullyPaid,
        'originalLoanAmount': loanData['amount'],
        'totalRepayable': totalRepayable,
      });

      // Optional: Also save to loan-specific repayments for detailed tracking
      final loanRepaymentsRef = loanRef.collection('repayments').doc();
      batch.set(loanRepaymentsRef, {
        'amount': repayAmount,
        'createdAt': FieldValue.serverTimestamp(),
        'userId': userId,
        'userName': userName,
      });

      // Execute all writes
      await batch.commit();

      if (!mounted) return;
      Navigator.pop(context);
      
      final message = isFullyPaid 
          ? "Loan fully repaid! Congratulations!" 
          : "Repayment of TZS $repayAmount recorded successfully";
          
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isFullyPaid ? Colors.green : null,
        ),
      );
    } catch (e) {
      debugPrint("Repayment error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error processing repayment: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}