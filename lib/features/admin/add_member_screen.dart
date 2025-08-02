import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/auth_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';


class AddMemberScreen extends ConsumerStatefulWidget {
  const AddMemberScreen({super.key});

  @override
  ConsumerState<AddMemberScreen> createState() => _AddMemberScreenState();
}

class _AddMemberScreenState extends ConsumerState<AddMemberScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;

  Future<void> _handleAddMember() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();

    try {
      final currentUser = await ref.read(currentUserProvider.future);
      final groupId = currentUser?.groupId;
      final groupName = currentUser?.groupName;

      if (groupId == null) throw Exception("Missing group ID");

      // Create member account
      final auth = FirebaseAuth.instance;
      final cred = await auth.createUserWithEmailAndPassword(email: email, password: password);

      // Store member in Firestore
      final memberData = {
        'uid': cred.user!.uid,
        'name': name,
        'email': email,
        'phone': phone,
        'role': 'member',
        'groupId': groupId,
        'groupName': groupName,
      };

      await FirebaseFirestore.instance.collection('users').doc(cred.user!.uid).set(memberData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Member added successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }

    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add Member")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: "Name"),
                validator: (val) => val!.isEmpty ? "Enter name" : null,
              ),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: "Email"),
                validator: (val) => val!.contains('@') ? null : "Invalid email",
              ),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: "Phone Number"),
                validator: (val) => val!.length < 10 ? "Enter valid phone number" : null,
              ),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: "Temporary Password"),
                obscureText: true,
                validator: (val) => val!.length < 6 ? "Min 6 characters" : null,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loading ? null : _handleAddMember,
                child: _loading
                    ? const CircularProgressIndicator()
                    : const Text("Add Member"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
