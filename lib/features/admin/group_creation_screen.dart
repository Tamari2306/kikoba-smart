import 'dart:io' as io;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../providers/user_provider.dart';

class GroupCreationScreen extends ConsumerStatefulWidget {
  const GroupCreationScreen({super.key});

  @override
  ConsumerState<GroupCreationScreen> createState() => _GroupCreationScreenState();
}

class _GroupCreationScreenState extends ConsumerState<GroupCreationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _interestRateController = TextEditingController();
  final _penaltyController = TextEditingController();
  final _rulesController = TextEditingController();

  bool _isAdmin = false;
  bool _loading = true;
  bool _uploading = false;
  bool _editing = false;
  String? _pdfUrl;
  String? _groupId;

  @override
  void dispose() {
    _nameController.dispose();
    _interestRateController.dispose();
    _penaltyController.dispose();
    _rulesController.dispose();
    super.dispose();
  }

  Future<void> _loadGroupData(String groupId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('groups').doc(groupId).get();
      final configDoc = await FirebaseFirestore.instance
          .collection('groups')
          .doc(groupId)
          .collection('settings')
          .doc('config')
          .get();
      final constitutionDoc = await FirebaseFirestore.instance
          .collection('groups')
          .doc(groupId)
          .collection('settings')
          .doc('constitution')
          .get();

      if (doc.exists) {
        _nameController.text = doc.data()!['name'] ?? '';
      }
      if (configDoc.exists) {
        final config = configDoc.data()!;
        _interestRateController.text = config['interestRate']?.toString() ?? '';
        _penaltyController.text = config['penaltyPerDay']?.toString() ?? '';
      }
      if (constitutionDoc.exists) {
        final data = constitutionDoc.data()!;
        _rulesController.text = data['rules'] ?? '';
        _pdfUrl = data['pdfUrl'];
      }
    } catch (e) {
      debugPrint("Error loading group data: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _uploadPdf(String groupId) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: kIsWeb,
    );

    if (result != null) {
      setState(() => _uploading = true);

      try {
        final ref = FirebaseStorage.instance.ref().child('groups/$groupId/constitution.pdf');
        UploadTask uploadTask;
        if (kIsWeb) {
          final fileBytes = result.files.single.bytes!;
          uploadTask = ref.putData(fileBytes, SettableMetadata(contentType: 'application/pdf'));
        } else {
          final file = io.File(result.files.single.path!);
          uploadTask = ref.putFile(file, SettableMetadata(contentType: 'application/pdf'));
        }

        final snapshot = await uploadTask;
        final url = await snapshot.ref.getDownloadURL();
        setState(() => _pdfUrl = url);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Text("PDF uploaded successfully"),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      } catch (e) {
        debugPrint("Upload error: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(child: Text("Upload failed: $e")),
                ],
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      } finally {
        setState(() => _uploading = false);
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final groupName = _nameController.text.trim();
    final interest = double.tryParse(_interestRateController.text.trim()) ?? 0;
    final penalty = int.tryParse(_penaltyController.text.trim()) ?? 0;
    final rules = _rulesController.text.trim();

    try {
      final docRef = FirebaseFirestore.instance.collection('groups').doc(_groupId);

      // Save main group data
      await docRef.set({'name': groupName}, SetOptions(merge: true));

      // Save loan settings
      await docRef.collection('settings').doc('config').set({
        'interestRate': interest,
        'penaltyPerDay': penalty,
      }, SetOptions(merge: true));

      // Save constitution
      await docRef.collection('settings').doc('constitution').set({
        'rules': rules,
        'pdfUrl': _pdfUrl,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text(_editing ? 'Group updated successfully' : 'Group created successfully'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      debugPrint("Submit error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text("Error: $e")),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      loading: () => Scaffold(
        backgroundColor: Colors.grey.shade50,
        body: const Center(
          child: CircularProgressIndicator(color: Colors.green),
        ),
      ),
      error: (err, _) => Scaffold(
        backgroundColor: Colors.grey.shade50,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error, size: 64, color: Colors.red.shade300),
              const SizedBox(height: 16),
              Text(
                "Error: $err",
                style: TextStyle(color: Colors.red.shade700),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
      data: (user) {
        if (user == null || user.groupId == null) {
          return Scaffold(
            backgroundColor: Colors.grey.shade50,
            body: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.group_off, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    "No group context.",
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        }

        _groupId = user.groupId!;
        _isAdmin = user.role == 'admin';

        if (_loading) {
          _editing = true;
          _loadGroupData(_groupId!);
        }

        return Scaffold(
          backgroundColor: Colors.grey.shade50,
          appBar: AppBar(
            title: Text(
              _editing ? 'Edit Group Settings' : 'Create Group',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            backgroundColor: Colors.green,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: _loading
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Colors.green),
                      SizedBox(height: 16),
                      Text("Loading group data...", style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header Card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.1),
                                spreadRadius: 1,
                                blurRadius: 10,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _editing ? Icons.settings : Icons.group_add,
                                  size: 40,
                                  color: Colors.green.shade700,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _editing ? 'Group Settings' : 'Create New Group',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _editing 
                                    ? 'Configure your group settings and constitution'
                                    : 'Set up your new savings group',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              if (!_isAdmin) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade50,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.orange.shade200),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.visibility, size: 16, color: Colors.orange.shade700),
                                      const SizedBox(width: 4),
                                      Text(
                                        'View Only',
                                        style: TextStyle(
                                          color: Colors.orange.shade700,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Basic Information Card
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.1),
                                spreadRadius: 1,
                                blurRadius: 10,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Basic Information',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 20),
                              
                              _buildTextField(
                                controller: _nameController,
                                label: "Group Name",
                                icon: Icons.group,
                                enabled: _isAdmin,
                                validator: (val) => val == null || val.isEmpty ? "Enter group name" : null,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Loan Settings Card
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.1),
                                spreadRadius: 1,
                                blurRadius: 10,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Loan Settings',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 20),
                              
                              _buildTextField(
                                controller: _interestRateController,
                                label: "Interest Rate (%)",
                                icon: Icons.percent,
                                enabled: _isAdmin,
                                keyboardType: TextInputType.number,
                              ),
                              
                              const SizedBox(height: 20),
                              
                              _buildTextField(
                                controller: _penaltyController,
                                label: "Penalty per day (TZS)",
                                icon: Icons.money_off,
                                enabled: _isAdmin,
                                keyboardType: TextInputType.number,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Constitution Card
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.1),
                                spreadRadius: 1,
                                blurRadius: 10,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Group Constitution',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 20),
                              
                              TextFormField(
                                controller: _rulesController,
                                enabled: _isAdmin,
                                maxLines: 6,
                                decoration: InputDecoration(
                                  labelText: "Group Rules / Constitution",
                                  alignLabelWithHint: true,
                                  prefixIcon: const Padding(
                                    padding: EdgeInsets.only(bottom: 100),
                                    child: Icon(Icons.gavel, color: Colors.green),
                                  ),
                                  helperText: _isAdmin ? "Editable by admins" : "Read-only for members",
                                  helperStyle: TextStyle(color: Colors.grey.shade600),
                                  filled: true,
                                  fillColor: _isAdmin ? Colors.grey.shade50 : Colors.grey.shade100,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: Colors.green, width: 2),
                                  ),
                                  labelStyle: TextStyle(color: Colors.grey.shade600),
                                ),
                              ),
                              
                              const SizedBox(height: 20),
                              
                              // PDF Section
                              if (_pdfUrl != null) ...[
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.green.shade200),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.green.shade100,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          Icons.picture_as_pdf,
                                          color: Colors.green.shade700,
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Constitution PDF',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.green.shade700,
                                              ),
                                            ),
                                            Text(
                                              'Constitution document uploaded',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.green.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      ElevatedButton.icon(
                                        onPressed: () => launchUrl(Uri.parse(_pdfUrl!)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                        icon: const Icon(Icons.visibility, size: 16),
                                        label: const Text('View'),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],
                              
                              if (_isAdmin) ...[
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: _uploading ? null : () => _uploadPdf(_groupId!),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    icon: _uploading 
                                        ? const SizedBox(
                                            height: 16,
                                            width: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                            ),
                                          )
                                        : const Icon(Icons.upload_file),
                                    label: Text(_uploading ? "Uploading..." : "Upload Constitution PDF"),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Action Button
                        if (_isAdmin) ...[
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 2,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(_editing ? Icons.save : Icons.group_add),
                                  const SizedBox(width: 8),
                                  Text(
                                    _editing ? "Save Changes" : "Create Group",
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool enabled,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: enabled ? Colors.green : Colors.grey),
        filled: true,
        fillColor: enabled ? Colors.grey.shade50 : Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.green, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        labelStyle: TextStyle(color: Colors.grey.shade600),
      ),
    );
  }
}