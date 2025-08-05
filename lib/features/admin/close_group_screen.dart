import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/auth_provider.dart'; // Change this import

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
  Map<String, String> userNames = {}; // userId => name
  double totalInterest = 0;
  double totalShares = 0;
  double totalAmount = 0;
  bool _isClosed = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    try {
      print("Starting to load data..."); // Debug print
      
      final user = ref.read(currentUserProvider).value;
      print("User: $user"); // Debug print
      print("User groupId: ${user?.groupId}"); // Debug print
      
      if (user == null) {
        setState(() {
          _error = "User not found";
          _loading = false;
        });
        return;
      }
      
      if (user.groupId == null) {
        setState(() {
          _error = "No group found for user";
          _loading = false;
        });
        return;
      }

      _groupId = user.groupId;
      print("Group ID: $_groupId"); // Debug print

      // Load user names first
      print("Loading user names..."); // Debug print
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('groupId', isEqualTo: _groupId)
          .get();
      
      for (final userDoc in usersSnapshot.docs) {
        final userData = userDoc.data();
        userNames[userDoc.id] = userData['name'] ?? userData['email'] ?? 'Unknown User';
      }
      print("User names loaded: $userNames"); // Debug print

      // Check if group is closed first
      final groupDoc = await FirebaseFirestore.instance
          .collection('groups')
          .doc(_groupId)
          .get();
      
      print("Group doc exists: ${groupDoc.exists}"); // Debug print
      
      if (!groupDoc.exists) {
        setState(() {
          _error = "Group not found in database";
          _loading = false;
        });
        return;
      }

      final groupData = groupDoc.data();
      print("Group data: $groupData"); // Debug print
      
      final closed = groupData?['closed'] ?? false;
      if (closed) {
        setState(() {
          _isClosed = true;
          _loading = false;
        });
        return;
      }

      // Load contributions
      print("Loading contributions..."); // Debug print
      final contributionsRef = FirebaseFirestore.instance
          .collection('groups')
          .doc(_groupId)
          .collection('contributions');

      final contribSnap = await contributionsRef.get();
      print("Contributions count: ${contribSnap.docs.length}"); // Debug print
      
      for (final doc in contribSnap.docs) {
        final data = doc.data();
        print("Contribution data: $data"); // Debug print
        
        final userId = data['userId'];
        final amount = (data['amount'] as num?)?.toDouble() ?? 0;
        final type = data['type'];

        totalAmount += amount;

        if (type == 'hisa') {
          userShares[userId] = (userShares[userId] ?? 0) + amount;
          totalShares += amount;
        }
      }

      // Load loans
      print("Loading loans..."); // Debug print
      final loansRef = FirebaseFirestore.instance
          .collection('groups')
          .doc(_groupId)
          .collection('loans');

      final loansSnap = await loansRef.get();
      print("Loans count: ${loansSnap.docs.length}"); // Debug print
      
      for (final doc in loansSnap.docs) {
        final data = doc.data();
        print("Loan data: $data"); // Debug print
        
        final interest = (data['interest'] as num?)?.toDouble() ?? 0;
        totalInterest += interest;
      }

      // Calculate payouts
      print("Calculating payouts..."); // Debug print
      print("Total shares: $totalShares"); // Debug print
      print("Total amount: $totalAmount"); // Debug print
      print("Total interest: $totalInterest"); // Debug print
      
      final distributable = totalAmount + totalInterest;
      for (final entry in userShares.entries) {
        if (totalShares > 0) {
          final percent = entry.value / totalShares;
          userPayouts[entry.key] = (percent * distributable);
        }
      }

      print("User payouts: $userPayouts"); // Debug print

      setState(() {
        _loading = false;
      });
      
    } catch (e, stackTrace) {
      print("Error loading data: $e"); // Debug print
      print("Stack trace: $stackTrace"); // Debug print
      
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _closeGroup() async {
    if (_groupId == null) return;

    try {
      final batch = FirebaseFirestore.instance.batch();

      // Save the final payouts under a 'finalPayouts' subcollection
      final groupRef = FirebaseFirestore.instance.collection('groups').doc(_groupId);
      final payoutRef = groupRef.collection('finalPayouts');

      for (final entry in userPayouts.entries) {
        batch.set(payoutRef.doc(entry.key), {
          'userId': entry.key,
          'userName': userNames[entry.key] ?? 'Unknown User',
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error closing group: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).value;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Close Group')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text("Loading group data..."),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Close Group')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text("Error: $_error"),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _loading = true;
                    _error = null;
                  });
                  _loadData();
                },
                child: const Text("Retry"),
              ),
            ],
          ),
        ),
      );
    }

    if (_isClosed) {
      return Scaffold(
        appBar: AppBar(title: const Text('Close Group')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text("Group is already closed."),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Close Group')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Total Contributions: TZS ${totalAmount.toStringAsFixed(0)}"),
                    Text("Total Interest Collected: TZS ${totalInterest.toStringAsFixed(0)}"),
                    Text("Total Shares: TZS ${totalShares.toStringAsFixed(0)}"),
                    Text("Total Distributable: TZS ${(totalAmount + totalInterest).toStringAsFixed(0)}"),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text("Final Payouts:", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: userPayouts.isEmpty 
                  ? const Center(child: Text("No payouts calculated"))
                  : ListView(
                      children: userPayouts.entries.map((entry) {
                        final userName = userNames[entry.key] ?? 'Unknown User';
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.blue[100],
                              child: Text(
                                userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                                style: TextStyle(color: Colors.blue[700]),
                              ),
                            ),
                            title: Text(userName),
                            subtitle: Text(
                              "User ID: ${entry.key}\n"
                              "Shares: TZS ${userShares[entry.key]?.toStringAsFixed(0) ?? '0'}\n"
                              "Final Amount: TZS ${entry.value.toStringAsFixed(0)}",
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: entry.value >= 0 ? Colors.green[100] : Colors.red[100],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                "TZS ${entry.value.toStringAsFixed(0)}",
                                style: TextStyle(
                                  color: entry.value >= 0 ? Colors.green[700] : Colors.red[700],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
            ),
            if (user?.role == 'admin')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: userPayouts.isNotEmpty ? _closeGroup : null,
                  icon: const Icon(Icons.lock),
                  label: const Text("Close Group & Distribute"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}