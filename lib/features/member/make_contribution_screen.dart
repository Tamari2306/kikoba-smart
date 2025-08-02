import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/user_provider.dart';

class MakeContributionScreen extends ConsumerStatefulWidget {
  const MakeContributionScreen({super.key});

  @override
  ConsumerState<MakeContributionScreen> createState() => _MakeContributionScreenState();
}

class _MakeContributionScreenState extends ConsumerState<MakeContributionScreen> {
  final _amountController = TextEditingController();
  String _type = 'hisa'; // Default
  bool _isSubmitting = false;

  Future<void> _submitContribution() async {
    final user = ref.read(currentUserProvider).value;
    if (user == null || user.groupId == null) return;

    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) return;

    setState(() => _isSubmitting = true);

    try {
      await FirebaseFirestore.instance
          .collection('groups')
          .doc(user.groupId)
          .collection('contributions')
          .add({
        'userId': user.uid,
        'userName': user.name,
        'amount': amount,
        'type': _type, // 'hisa' or 'jamii'
        'timestamp': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Contribution submitted.")),
      );
      _amountController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Make Contribution')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: _type,
              decoration: const InputDecoration(labelText: 'Contribution Type'),
              items: const [
                DropdownMenuItem(value: 'hisa', child: Text('Hisa (Share Capital)')),
                DropdownMenuItem(value: 'jamii', child: Text('Jamii (Monthly Contribution)')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _type = value);
                }
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Amount (TZS)'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submitContribution,
              child: _isSubmitting
                  ? const CircularProgressIndicator()
                  : const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }
}
