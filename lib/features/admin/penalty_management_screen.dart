// lib/features/admin/penalty_management_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../providers/user_provider.dart';

class PenaltyManagementScreen extends ConsumerWidget {
  const PenaltyManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      data: (user) {
        if (user == null || user.groupId == null) {
          return const Scaffold(body: Center(child: Text("No group found.")));
        }

        return FutureBuilder<Map<String, dynamic>>(
          future: _loadPenaltyData(user.groupId!),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            if (snapshot.hasError) {
              return Scaffold(body: Center(child: Text("Error: ${snapshot.error}")));
            }

            if (!snapshot.hasData) {
              return const Scaffold(body: Center(child: Text("No data found.")));
            }

            final data = snapshot.data!;
            final groupSettings = data['groupSettings'] as Map<String, dynamic>;
            final overdueLoans = data['overdueLoans'] as List<Map<String, dynamic>>;
            final penaltyStats = data['penaltyStats'] as Map<String, dynamic>;

            return Scaffold(
              appBar: AppBar(
                title: const Text('Penalty Management'),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.settings),
                    onPressed: () => _showPenaltySettings(context, user.groupId!, groupSettings),
                  ),
                ],
              ),
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Penalty Settings Summary
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Current Penalty Settings", style: Theme.of(context).textTheme.titleLarge),
                            const Divider(),
                            _buildSettingRow("Daily Penalty:", "TZS ${groupSettings['dailyPenalty'] ?? 1000}"),
                            _buildSettingRow("Grace Period:", "${groupSettings['gracePeriodDays'] ?? 7} days"),
                            _buildSettingRow("Status:", groupSettings['penaltyEnabled'] == true ? "Enabled" : "Disabled"),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Penalty Statistics
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Penalty Statistics", style: Theme.of(context).textTheme.titleLarge),
                            const Divider(),
                            Row(
                              children: [
                                Expanded(child: _buildStatCard("Total Penalties", "TZS ${penaltyStats['totalPenalties']}", Icons.money_off, Colors.red)),
                                const SizedBox(width: 8),
                                Expanded(child: _buildStatCard("Overdue Loans", "${penaltyStats['overdueCount']}", Icons.warning, Colors.orange)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(child: _buildStatCard("Penalties Collected", "TZS ${penaltyStats['collectedPenalties']}", Icons.check_circle, Colors.green)),
                                const SizedBox(width: 8),
                                Expanded(child: _buildStatCard("Outstanding", "TZS ${penaltyStats['outstandingPenalties']}", Icons.pending, Colors.blue)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Overdue Loans List
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Overdue Loans (${overdueLoans.length})", style: Theme.of(context).textTheme.titleLarge),
                            const Divider(),
                            if (overdueLoans.isEmpty)
                              const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("No overdue loans! 🎉")))
                            else
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: overdueLoans.length,
                                itemBuilder: (context, index) {
                                  final loan = overdueLoans[index];
                                  final penalties = _calculateLoanPenalties(loan, groupSettings);

                                  return Card(
                                    margin: const EdgeInsets.symmetric(vertical: 4),
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: Colors.red.shade100,
                                        child: Text("${penalties['daysOverdue']}", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                                      ),
                                      title: Text(loan['userName'] ?? 'Unknown'),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text("Loan: TZS ${loan['amount']}"),
                                          Text("Due: ${penalties['dueDateString']}"),
                                        ],
                                      ),
                                      trailing: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text("TZS ${penalties['totalPenalties']}", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                                          Text("${penalties['effectiveDays']} penalty days", style: const TextStyle(fontSize: 12)),
                                        ],
                                      ),
                                      isThreeLine: true,
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, _) => Scaffold(body: Center(child: Text("Error: $err"))),
    );
  }

  Widget _buildSettingRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label), Text(value, style: const TextStyle(fontWeight: FontWeight.bold))],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16)),
          Text(title, style: TextStyle(fontSize: 12, color: color), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return "${date.day}/${date.month}/${date.year}";
  }

  Map<String, dynamic> _calculateLoanPenalties(Map<String, dynamic> loan, Map<String, dynamic> groupSettings) {
    final dueTimestamp = loan['dueDate'];
    if (dueTimestamp == null || dueTimestamp is! Timestamp) {
      return {
        'daysOverdue': 0,
        'effectiveDays': 0,
        'totalPenalties': 0,
        'dueDateString': 'Unknown',
      };
    }

    final dueDate = dueTimestamp.toDate();
    final now = DateTime.now();
    final daysOverdue = now.difference(dueDate).inDays;
    final gracePeriod = (groupSettings['gracePeriodDays'] ?? 7) as int;
    final dailyPenalty = (groupSettings['dailyPenalty'] ?? 1000) as int;

    final effectiveDays = daysOverdue > gracePeriod ? daysOverdue - gracePeriod : 0;
    final totalPenalties = effectiveDays * dailyPenalty;

    return {
      'daysOverdue': daysOverdue,
      'effectiveDays': effectiveDays,
      'totalPenalties': totalPenalties,
      'dueDateString': _formatDate(dueDate),
    };
  }

  Future<Map<String, dynamic>> _loadPenaltyData(String groupId) async {
    final groupDoc = await FirebaseFirestore.instance.collection('groups').doc(groupId).get();
    final groupSettings = groupDoc.data() ?? {};

    final loansQuery = await FirebaseFirestore.instance
        .collection('groups')
        .doc(groupId)
        .collection('loans')
        .where('status', isEqualTo: 'approved')
        .get();

    final repaymentsQuery = await FirebaseFirestore.instance
        .collection('groups')
        .doc(groupId)
        .collection('repayments')
        .get();

    final now = DateTime.now();
    final gracePeriod = (groupSettings['gracePeriodDays'] ?? 7) as int;
    final dailyPenalty = (groupSettings['dailyPenalty'] ?? 1000) as int;

    List<Map<String, dynamic>> overdueLoans = [];
    int totalPenalties = 0;
    int overdueCount = 0;

    for (final loanDoc in loansQuery.docs) {
      final loanData = loanDoc.data();
      final dueDateRaw = loanData['dueDate'];

      if (dueDateRaw is! Timestamp) {
        continue; // Skip invalid or missing dueDate
      }

      final dueDate = dueDateRaw.toDate();
      final daysOverdue = now.difference(dueDate).inDays;

      if (daysOverdue > gracePeriod) {
        overdueCount++;
        final effectiveDays = daysOverdue - gracePeriod;
        final loanPenalty = effectiveDays * dailyPenalty;
        totalPenalties += loanPenalty;

        overdueLoans.add({
          ...loanData,
          'loanId': loanDoc.id,
          'daysOverdue': daysOverdue,
          'effectiveDays': effectiveDays,
          'penalties': loanPenalty,
        });
      }
    }

    int collectedPenalties = 0;
    for (final repaymentDoc in repaymentsQuery.docs) {
      final repaymentData = repaymentDoc.data();
      collectedPenalties += (repaymentData['penaltyAmount'] as int? ?? 0);
    }

    final outstandingPenalties = totalPenalties - collectedPenalties;

    return {
      'groupSettings': groupSettings,
      'overdueLoans': overdueLoans,
      'penaltyStats': {
        'totalPenalties': totalPenalties,
        'overdueCount': overdueCount,
        'collectedPenalties': collectedPenalties,
        'outstandingPenalties': outstandingPenalties,
      },
    };
  }

  void _showPenaltySettings(BuildContext context, String groupId, Map<String, dynamic> currentSettings) {
    final dailyPenaltyController = TextEditingController(text: (currentSettings['dailyPenalty'] ?? 1000).toString());
    final gracePeriodController = TextEditingController(text: (currentSettings['gracePeriodDays'] ?? 7).toString());
    bool penaltyEnabled = currentSettings['penaltyEnabled'] ?? true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text("Update Penalty Settings"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: dailyPenaltyController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Daily Penalty (TZS)", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: gracePeriodController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Grace Period (Days)", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text("Enable Penalties"),
                value: penaltyEnabled,
                onChanged: (value) => setState(() => penaltyEnabled = value),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () async {
                await FirebaseFirestore.instance.collection('groups').doc(groupId).update({
                  'dailyPenalty': int.parse(dailyPenaltyController.text),
                  'gracePeriodDays': int.parse(gracePeriodController.text),
                  'penaltyEnabled': penaltyEnabled,
                  'updatedAt': FieldValue.serverTimestamp(),
                });

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Penalty settings updated")));
              },
              child: const Text("Update"),
            ),
          ],
        ),
      ),
    );
  }
}
