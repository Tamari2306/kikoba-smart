import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/user_provider.dart';

class CloseGroupScreen extends ConsumerStatefulWidget {
  const CloseGroupScreen({super.key});

  @override
  ConsumerState<CloseGroupScreen> createState() => _CloseGroupScreenState();
}

class _CloseGroupScreenState extends ConsumerState<CloseGroupScreen> {
  bool _loading = true;
  String? _groupId;
  Map<String, double> userShares = {}; // userId => hisa
  Map<String, double> userPayouts = {};
  double totalInterest = 0;
  double totalShares = 0;
  double totalAmount = 0;
  bool _isClosed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final user = ref.read(currentUserProvider).value;
    if (user == null || user.groupId == null) return;

    _groupId = user.groupId;
    final contributionsRef = FirebaseFirestore.instance
        .collection('groups')
        .doc(_groupId)
        .collection('contributions');

    final loansRef = FirebaseFirestore.instance
        .collection('groups')
        .doc(_groupId)
        .collection('loans');

    final groupDoc = await FirebaseFirestore.instance.collection('groups').doc(_groupId).get();
    final closed = groupDoc.data()?['closed'] ?? false;
    if (closed) {
      setState(() {
        _isClosed = true;
        _loading = false;
      });
      return;
    }

    final contribSnap = await contributionsRef.get();
    for (final doc in contribSnap.docs) {
      final data = doc.data();
      final userId = data['userId'];
      final amount = (data['amount'] as num).toDouble();
      final type = data['type'];

      totalAmount += amount;

      if (type == 'hisa') {
        userShares[userId] = (userShares[userId] ?? 0) + amount;
        totalShares += amount;
      }
    }

    final loansSnap = await loansRef.get();
    for (final doc in loansSnap.docs) {
      final interest = (doc.data()['interest'] ?? 0);
      totalInterest += (interest as num).toDouble();
    }

    // Distribute total (shares + interest) by shares
    final distributable = totalAmount + totalInterest;
    for (final entry in userShares.entries) {
      final percent = entry.value / totalShares;
      userPayouts[entry.key] = (percent * distributable);
    }

    setState(() {
      _loading = false;
    });
  }

  Future<void> _closeGroup() async {
    if (_groupId == null) return;

    final batch = FirebaseFirestore.instance.batch();

    // Save the final payouts under a 'finalPayouts' subcollection
    final groupRef = FirebaseFirestore.instance.collection('groups').doc(_groupId);
    final payoutRef = groupRef.collection('finalPayouts');

    for (final entry in userPayouts.entries) {
      batch.set(payoutRef.doc(entry.key), {
        'userId': entry.key,
        'finalAmount': entry.value,
        'shares': userShares[entry.key],
        'timestamp': FieldValue.serverTimestamp(),
      });
    }

    // Mark group as closed
    batch.update(groupRef, {'closed': true});

    await batch.commit();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Group closed and payouts recorded.")),
      );
      setState(() {
        _isClosed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).value;

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_isClosed) {
      return Scaffold(
        appBar: AppBar(title: const Text('Close Group')),
        body: const Center(child: Text("Group is already closed.")),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Close Group')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Total Contributions: TZS ${totalAmount.toStringAsFixed(0)}"),
            Text("Total Interest Collected: TZS ${totalInterest.toStringAsFixed(0)}"),
            Text("Total Shares: TZS ${totalShares.toStringAsFixed(0)}"),
            const SizedBox(height: 16),
            const Text("Final Payouts:", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: userPayouts.entries.map((entry) {
                  return Card(
                    child: ListTile(
                      title: Text("User ID: ${entry.key}"),
                      subtitle: Text(
                        "Shares: ${userShares[entry.key]?.toStringAsFixed(0) ?? '0'}\n"
                        "Final Amount: TZS ${entry.value.toStringAsFixed(0)}",
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            if (user?.role == 'admin')
              ElevatedButton.icon(
                onPressed: _closeGroup,
                icon: const Icon(Icons.lock),
                label: const Text("Close Group & Distribute"),
              ),
          ],
        ),
      ),
    );
  }
}
