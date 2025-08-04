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

          return FutureBuilder<Map<String, dynamic>>(
            future: _loadGroupAndLoanData(user.groupId!, user.uid),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              
              if (snapshot.hasError || !snapshot.hasData) {
                return const Center(child: Text("Error loading loan data"));
              }

              final data = snapshot.data!;
              final groupSettings = data['groupSettings'] as Map<String, dynamic>?;
              final loanData = data['loanData'] as Map<String, dynamic>?;
              final loanId = data['loanId'] as String?;

              if (loanData == null) {
                return const Center(child: Text("No active loan found"));
              }

              // Calculate penalty details
              final penaltyData = _calculatePenalties(loanData, groupSettings);
              
              final repaidAmount = (loanData['repayedAmount'] ?? 0) as int;
              final totalRepayable = (loanData['totalRepayable'] ?? 0) as int;
              final totalPenalties = penaltyData['totalPenalties'] as int;
              final remaining = totalRepayable - repaidAmount + totalPenalties;

              return Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        // Loan Summary Card
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Loan Summary", style: Theme.of(context).textTheme.titleLarge),
                                const Divider(),
                                _buildSummaryRow("Original Amount:", "TZS ${loanData['amount']}"),
                                _buildSummaryRow("Total Repayable:", "TZS $totalRepayable"),
                                _buildSummaryRow("Already Repaid:", "TZS $repaidAmount"),
                                if (totalPenalties > 0) ...[
                                  _buildSummaryRow("Penalties:", "TZS $totalPenalties", valueColor: Colors.red),
                                  const Divider(),
                                ],
                                _buildSummaryRow(
                                  "Total Remaining:", 
                                  "TZS $remaining", 
                                  valueColor: remaining > 0 ? Colors.red : Colors.green,
                                  bold: true,
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Penalty Details Card (if applicable)
                        if (totalPenalties > 0) ...[
                          const SizedBox(height: 16),
                          Card(
                            color: Colors.red.shade50,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.warning, color: Colors.red),
                                      const SizedBox(width: 8),
                                      Text(
                                        "Penalty Information", 
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          color: Colors.red,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(),
                                  Text("Due Date: ${_formatDate(penaltyData['dueDate'])}"),
                                  Text("Total Days Since Due: ${penaltyData['daysOverdue']}"),
                                  Text("Grace Period: ${penaltyData['gracePeriodDays']} days"),
                                  Text("Penalty Days: ${penaltyData['effectivePenaltyDays']}"), // Fixed variable name
                                  Text("Daily Penalty: TZS ${penaltyData['dailyPenalty']}"),
                                  Text(
                                    "Total Penalties: TZS $totalPenalties",
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 20),
                        
                        // Payment Input
                        TextFormField(
                          controller: _amountController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: "Repayment Amount (TZS)",
                            border: const OutlineInputBorder(),
                            helperText: totalPenalties > 0 
                                ? "Amount includes penalties" 
                                : "Enter amount to pay",
                          ),
                          validator: (val) {
                            if (val == null || val.isEmpty) return "Enter amount";
                            final amt = int.tryParse(val);
                            if (amt == null || amt <= 0) return "Enter a valid amount";
                            if (amt > remaining) return "Amount exceeds total remaining balance";
                            return null;
                          },
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Payment Buttons
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  _amountController.text = remaining.toString();
                                },
                                child: const Text("Pay Full Amount"),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _loading
                                  ? const Center(child: CircularProgressIndicator())
                                  : ElevatedButton(
                                      onPressed: () async => await _submitRepayment(
                                        user.groupId!,
                                        loanId!,
                                        loanData,
                                        repaidAmount,
                                        user.name,
                                        user.uid,
                                        totalPenalties,
                                        penaltyData,
                                      ),
                                      child: const Text("Submit Payment"),
                                    ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {Color? valueColor, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return "${date.day}/${date.month}/${date.year}";
  }

  Future<Map<String, dynamic>> _loadGroupAndLoanData(String groupId, String userId) async {
    // Load group settings
    final groupDoc = await FirebaseFirestore.instance
        .collection('groups')
        .doc(groupId)
        .get();
    
    final groupSettings = groupDoc.data();

    // Load user's active loan
    final loanQuery = await FirebaseFirestore.instance
        .collection('groups')
        .doc(groupId)
        .collection('loans')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'approved')
        .get();

    Map<String, dynamic>? loanData;
    String? loanId;
    
    if (loanQuery.docs.isNotEmpty) {
      final loanDoc = loanQuery.docs.first;
      loanData = loanDoc.data();
      loanId = loanDoc.id;
    }

    return {
      'groupSettings': groupSettings,
      'loanData': loanData,
      'loanId': loanId,
    };
  }

  Map<String, dynamic> _calculatePenalties(Map<String, dynamic> loanData, Map<String, dynamic>? groupSettings) {
    final dueDate = (loanData['dueDate'] as Timestamp).toDate();
    final now = DateTime.now();
    final daysOverdue = now.difference(dueDate).inDays;
    
    // Get penalty settings from group - cast to int properly
    final dailyPenalty = (groupSettings?['dailyPenalty'] ?? 1000) as int;
    final gracePeriodDays = (groupSettings?['gracePeriodDays'] ?? 7) as int;
    final penaltyEnabled = groupSettings?['penaltyEnabled'] ?? true;
    
    int totalPenalties = 0;
    int effectivePenaltyDays = 0;
    
    if (penaltyEnabled && daysOverdue > gracePeriodDays) {
      effectivePenaltyDays = daysOverdue - gracePeriodDays;
      totalPenalties = effectivePenaltyDays * dailyPenalty;
    }

    return {
      'dueDate': dueDate,
      'daysOverdue': daysOverdue > 0 ? daysOverdue : 0,
      'effectivePenaltyDays': effectivePenaltyDays,
      'gracePeriodDays': gracePeriodDays,
      'dailyPenalty': dailyPenalty,
      'totalPenalties': totalPenalties,
      'penaltyEnabled': penaltyEnabled,
    };
  }

  Future<void> _submitRepayment(
    String groupId,
    String loanId,
    Map<String, dynamic> loanData,
    int alreadyRepaid,
    String userName,
    String userId,
    int totalPenalties,
    Map<String, dynamic> penaltyData,
  ) async {
    if (!_formKey.currentState!.validate()) return;

    final repayAmount = int.parse(_amountController.text);
    setState(() => _loading = true);

    try {
      final batch = FirebaseFirestore.instance.batch();
      
      // Calculate payment allocation
      int penaltyPayment = 0;
      int principalPayment = repayAmount;
      
      if (totalPenalties > 0) {
        if (repayAmount >= totalPenalties) {
          penaltyPayment = totalPenalties;
          principalPayment = repayAmount - totalPenalties;
        } else {
          penaltyPayment = repayAmount;
          principalPayment = 0;
        }
      }

      // Update the loan document
      final loanRef = FirebaseFirestore.instance
          .collection('groups')
          .doc(groupId)
          .collection('loans')
          .doc(loanId);

      final newRepaidAmount = alreadyRepaid + principalPayment;
      final totalRepayable = loanData['totalRepayable'] ?? 0;
      final isFullyPaid = newRepaidAmount >= totalRepayable && penaltyPayment >= totalPenalties;

      batch.update(loanRef, {
        'repayedAmount': newRepaidAmount,
        'penaltiesPaid': (loanData['penaltiesPaid'] ?? 0) + penaltyPayment,
        'status': isFullyPaid ? 'fully_paid' : 'approved',
        'lastRepaymentDate': FieldValue.serverTimestamp(),
      });

      // Save to group-level repayments collection
      final groupRepaymentsRef = FirebaseFirestore.instance
          .collection('groups')
          .doc(groupId)
          .collection('repayments')
          .doc();

      batch.set(groupRepaymentsRef, {
        'amount': repayAmount,
        'principalAmount': principalPayment,
        'penaltyAmount': penaltyPayment,
        'createdAt': FieldValue.serverTimestamp(),
        'userId': userId,
        'userName': userName,
        'loanId': loanId,
        'previousAmount': alreadyRepaid,
        'newTotal': newRepaidAmount,
        'isFullPayment': isFullyPaid,
        'originalLoanAmount': loanData['amount'],
        'totalRepayable': totalRepayable,
        'daysOverdue': penaltyData['daysOverdue'],
        'dailyPenaltyRate': penaltyData['dailyPenalty'],
      });

      // Save to loan-specific repayments
      final loanRepaymentsRef = loanRef.collection('repayments').doc();
      batch.set(loanRepaymentsRef, {
        'amount': repayAmount,
        'principalAmount': principalPayment,
        'penaltyAmount': penaltyPayment,
        'createdAt': FieldValue.serverTimestamp(),
        'userId': userId,
        'userName': userName,
        'daysOverdue': penaltyData['daysOverdue'],
      });

      // Execute all writes
      await batch.commit();

      if (!mounted) return;
      Navigator.pop(context);
      
      String message;
      if (isFullyPaid) {
        message = "Loan fully repaid! Congratulations!";
      } else if (penaltyPayment > 0) {
        message = "Payment recorded: TZS $principalPayment (principal) + TZS $penaltyPayment (penalty)";
      } else {
        message = "Repayment of TZS $repayAmount recorded successfully";
      }
          
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isFullyPaid ? Colors.green : null,
          duration: const Duration(seconds: 4),
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