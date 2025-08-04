import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
  final _groupCodeController = TextEditingController();

  String _selectedRole = 'member';
  bool _loading = false;

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final authService = ref.read(authServiceProvider);

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final groupCode = _groupCodeController.text.trim();

    try {
      await authService.signUp(
        name: name,
        email: email,
        password: password,
        role: _selectedRole,
        groupId: _selectedRole == 'admin' ? null : groupCode, // Admin will create group later
      );

      ref.invalidate(currentUserProvider);

      // Navigate based on role
      switch (_selectedRole) {
        case 'admin':
          if (mounted) context.go('/group-creation'); // Redirect to group creation
          break;
        case 'member':
          if (mounted) context.go('/dashboard/member');
          break;
        case 'diaspora':
          if (mounted) context.go('/dashboard/diaspora');
          break;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Signup failed: ${e.toString()}')));
      }
    }

    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _groupCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              
              // Header
              Text(
                'Join Our Community',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Create your account to get started',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Name Field
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: "Full Name",
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
                validator: (val) =>
                    val == null || val.trim().isEmpty ? "Please enter your full name" : null,
              ),
              const SizedBox(height: 16),

              // Email Field
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: "Email Address",
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return "Please enter your email";
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(val)) {
                    return "Please enter a valid email address";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Password Field
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: "Password",
                  prefixIcon: Icon(Icons.lock),
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                validator: (val) {
                  if (val == null || val.isEmpty) return "Please enter a password";
                  if (val.length < 6) return "Password must be at least 6 characters";
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Role Selection
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Your Role',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // Admin Option
                      RadioListTile<String>(
                        title: const Text('Admin'),
                        subtitle: const Text('Create and manage a new group'),
                        value: 'admin',
                        groupValue: _selectedRole,
                        onChanged: (val) => setState(() => _selectedRole = val!),
                      ),
                      
                      // Member Option
                      RadioListTile<String>(
                        title: const Text('Member'),
                        subtitle: const Text('Join an existing group'),
                        value: 'member',
                        groupValue: _selectedRole,
                        onChanged: (val) => setState(() => _selectedRole = val!),
                      ),
                      
                      // Diaspora Option
                      RadioListTile<String>(
                        title: const Text('Diaspora'),
                        subtitle: const Text('Invest in groups from abroad'),
                        value: 'diaspora',
                        groupValue: _selectedRole,
                        onChanged: (val) => setState(() => _selectedRole = val!),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Group Code Field (only for members and diaspora)
              if (_selectedRole != 'admin') ...[
                TextFormField(
                  controller: _groupCodeController,
                  decoration: InputDecoration(
                    labelText: "Group Code",
                    prefixIcon: const Icon(Icons.group),
                    border: const OutlineInputBorder(),
                    helperText: _selectedRole == 'member' 
                        ? "Enter the code provided by your group admin"
                        : "Enter the code of the group you want to invest in",
                  ),
                  validator: (val) =>
                      val == null || val.trim().isEmpty ? "Please enter the group code" : null,
                ),
                const SizedBox(height: 24),
              ] else
                const SizedBox(height: 24),

              // Signup Button
              ElevatedButton(
                onPressed: _loading ? null : _handleSignup,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        _selectedRole == 'admin' ? "Create Account & Setup Group" : "Create Account",
                        style: const TextStyle(fontSize: 16),
                      ),
              ),
              const SizedBox(height: 16),

              // Login Link
              TextButton(
                onPressed: () => context.go('/login'),
                child: const Text("Already have an account? Sign In"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}