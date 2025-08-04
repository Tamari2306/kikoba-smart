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
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("PDF uploaded")));
        }
      } catch (e) {
        debugPrint("Upload error: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Upload failed: $e")));
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
          SnackBar(content: Text(_editing ? 'Group updated' : 'Group created')),
        );
      }
    } catch (e) {
      debugPrint("Submit error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, _) => Scaffold(body: Center(child: Text("Error: $err"))),
      data: (user) {
        if (user == null || user.groupId == null) {
          return const Scaffold(body: Center(child: Text("No group context.")));
        }

        _groupId = user.groupId!;
        _isAdmin = user.role == 'admin';

        if (_loading) {
          _editing = true;
          _loadGroupData(_groupId!);
        }

        return Scaffold(
          appBar: AppBar(title: Text(_editing ? 'Edit Group' : 'Create Group')),
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _nameController,
                          enabled: _isAdmin,
                          decoration: const InputDecoration(labelText: "Group Name"),
                          validator: (val) => val == null || val.isEmpty ? "Enter group name" : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _interestRateController,
                          enabled: _isAdmin,
                          decoration: const InputDecoration(labelText: "Interest Rate (%)"),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _penaltyController,
                          enabled: _isAdmin,
                          decoration: const InputDecoration(labelText: "Penalty per day (TZS)"),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _rulesController,
                          enabled: _isAdmin,
                          decoration: InputDecoration(
                            labelText: "Group Rules / Constitution",
                            border: const OutlineInputBorder(),
                            helperText: _isAdmin ? "Editable by admins" : "Read-only for members",
                          ),
                          maxLines: null,
                        ),
                        const SizedBox(height: 16),
                        if (_pdfUrl != null)
                          TextButton.icon(
                            onPressed: () => launchUrl(Uri.parse(_pdfUrl!)),
                            icon: const Icon(Icons.picture_as_pdf),
                            label: const Text("View PDF"),
                          ),
                        const SizedBox(height: 8),
                        if (_isAdmin)
                          Column(
                            children: [
                              ElevatedButton.icon(
                                onPressed: _uploading ? null : () => _uploadPdf(_groupId!),
                                icon: const Icon(Icons.upload_file),
                                label: Text(_uploading ? "Uploading..." : "Upload PDF"),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _submit,
                                child: Text(_editing ? "Save Changes" : "Create Group"),
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
  }
}
