import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../providers/auth_provider.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _groupInputController = TextEditingController();

  final _interestRateController = TextEditingController();
  final _penaltyPerDayController = TextEditingController();
  final _constitutionController = TextEditingController();

  String _selectedRole = 'admin';
  bool _loading = false;

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final authService = ref.read(authServiceProvider);
    final firestore = FirebaseFirestore.instance;

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final groupInput = _groupInputController.text.trim();

    String? groupId;

    try {
      if (_selectedRole == 'admin') {
        final newGroup = await firestore.collection('groups').add({
          'name': groupInput,
          'createdAt': DateTime.now(),
        });
        groupId = newGroup.id;

        final interestRate = double.tryParse(_interestRateController.text.trim()) ?? 0.1;
        final penaltyPerDay = int.tryParse(_penaltyPerDayController.text.trim()) ?? 5000;
        final rules = _constitutionController.text.trim();

        await firestore.collection('groups').doc(groupId).collection('settings').doc('config').set({
  'interestRate': 0.1,
  'penaltyPerDay': 100,
  'smallLoanLimit': 50000,
  'smallLoanDurationDays': 30,
  'largeLoanDurationDays': 60,
});

// Save group constitution/rules
await firestore.collection('groups').doc(groupId).collection('settings').doc('constitution').set({
  'rules': '''
1. Members must contribute monthly.
2. Loans above TZS 1M must be approved by majority.
3. Interest rate: 10% per loan duration.
4. Penalty: TZS 5,000/day for overdue loans.
5. Diaspora can only invest, not borrow.

These rules are governed by the group's agreement.
''',
});


      } else {
        final groupDoc = await firestore.collection('groups').doc(groupInput).get();
        if (!groupDoc.exists) throw Exception("Group code not found");
        groupId = groupInput;
      }

      await authService.signUp(
        name: name,
        email: email,
        password: password,
        role: _selectedRole,
        groupId: groupId,
      );

      ref.invalidate(currentUserProvider);

      switch (_selectedRole) {
        case 'admin':
          if (mounted) context.go('/dashboard/admin');
          break;
        case 'member':
          if (mounted) context.go('/dashboard/member');
          break;
        case 'diaspora':
          if (mounted) context.go('/dashboard/diaspora');
          break;
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }

    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign Up')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: "Name"),
                validator: (val) =>
                    val == null || val.isEmpty ? "Enter your name" : null,
              ),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: "Email"),
                validator: (val) =>
                    val != null && val.contains('@') ? null : "Invalid email",
              ),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: "Password"),
                obscureText: true,
                validator: (val) =>
                    val != null && val.length >= 6 ? null : "Min 6 chars",
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedRole,
                decoration: const InputDecoration(labelText: "Role"),
                items: const [
                  DropdownMenuItem(value: 'admin', child: Text('Admin (Create group)')),
                  DropdownMenuItem(value: 'member', child: Text('Member (Join group)')),
                  DropdownMenuItem(value: 'diaspora', child: Text('Diaspora')),
                ],
                onChanged: (val) => setState(() => _selectedRole = val!),
              ),
              const SizedBox(height: 12),
              if (_selectedRole == 'admin') ...[
                TextFormField(
                  controller: _groupInputController,
                  decoration: const InputDecoration(labelText: "Group name"),
                  validator: (val) =>
                      val == null || val.isEmpty ? "Enter group name" : null,
                ),
                TextFormField(
                  controller: _interestRateController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: "Interest rate (e.g. 0.1 for 10%)"),
                  validator: (val) =>
                      val == null || double.tryParse(val) == null ? "Enter valid interest rate" : null,
                ),
                TextFormField(
                  controller: _penaltyPerDayController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: "Penalty per overdue day (TZS)"),
                  validator: (val) =>
                      val == null || int.tryParse(val) == null ? "Enter penalty per day" : null,
                ),
                TextFormField(
                  controller: _constitutionController,
                  decoration: const InputDecoration(labelText: "Group rules / constitution"),
                  maxLines: 5,
                  validator: (val) =>
                      val == null || val.isEmpty ? "Enter group rules" : null,
                ),
              ],
              if (_selectedRole == 'member')
                TextFormField(
                  controller: _groupInputController,
                  decoration: const InputDecoration(labelText: "Group code"),
                  validator: (val) =>
                      val == null || val.isEmpty ? "Enter group code" : null,
                ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loading ? null : _handleSignup,
                child: _loading
                    ? const CircularProgressIndicator()
                    : const Text("Sign Up"),
              ),
              TextButton(
                onPressed: () => context.go('/login'),
                child: const Text("Already have an account? Log in"),
              )
            ],
          ),
        ),
      ),
    );
  }
}
