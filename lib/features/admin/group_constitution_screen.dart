import 'dart:io' as io;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../providers/user_provider.dart';

class GroupConstitutionScreen extends ConsumerStatefulWidget {
  const GroupConstitutionScreen({super.key});

  @override
  ConsumerState<GroupConstitutionScreen> createState() => _GroupConstitutionScreenState();
}

class _GroupConstitutionScreenState extends ConsumerState<GroupConstitutionScreen> {
  final _rulesController = TextEditingController();
  bool _isAdmin = false;
  bool _loading = true;
  bool _uploading = false;
  String? _pdfUrl;
  String? _currentGroupId;

  @override
  void initState() {
    super.initState();
    // Data loading will be triggered after the first build when we have the user data
  }

  @override
  void dispose() {
    _rulesController.dispose();
    super.dispose();
  }

  Future<void> _loadData(String groupId) async {
    try {
      final docRef = FirebaseFirestore.instance
          .collection('groups')
          .doc(groupId)
          .collection('settings')
          .doc('constitution');

      final docSnap = await docRef.get();
      if (docSnap.exists) {
        final data = docSnap.data()!;
        if (mounted) {
          setState(() {
            _rulesController.text = data['rules'] ?? '';
            _pdfUrl = data['pdfUrl'];
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading constitution data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _saveChanges(String groupId) async {
    try {
      final rulesText = _rulesController.text.trim();
      await FirebaseFirestore.instance
          .collection('groups')
          .doc(groupId)
          .collection('settings')
          .doc('constitution')
          .set({
        'rules': rulesText,
        'pdfUrl': _pdfUrl,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Changes saved")),
        );
      }
    } catch (e) {
      debugPrint('Error saving changes: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving changes: $e')),
        );
      }
    }
  }

  Future<void> _uploadPdf(String groupId) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: kIsWeb, // For web compatibility
    );

    if (result != null) {
      final ref = FirebaseStorage.instance.ref().child('groups/$groupId/constitution.pdf');

      try {
        setState(() => _uploading = true);

        UploadTask uploadTask;
        if (kIsWeb) {
          final fileBytes = result.files.single.bytes;
          uploadTask = ref.putData(fileBytes!, SettableMetadata(contentType: 'application/pdf'));
        } else {
          final file = io.File(result.files.single.path!);
          uploadTask = ref.putFile(file, SettableMetadata(contentType: 'application/pdf'));
        }

        final snapshot = await uploadTask;
        final url = await snapshot.ref.getDownloadURL();

        if (mounted) {
          setState(() {
            _pdfUrl = url;
            _uploading = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('PDF uploaded successfully')),
          );
        }
      } catch (e) {
        debugPrint('Upload error: $e');
        if (mounted) {
          setState(() => _uploading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Upload failed: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      data: (user) {
        if (user?.groupId == null) {
          return const Scaffold(
            body: Center(child: Text("No group context.")),
          );
        }

        final groupId = user!.groupId!;
        _isAdmin = user.role == 'admin';

        // Load data only once when groupId changes or on first load
        if (_loading && _currentGroupId != groupId) {
          _currentGroupId = groupId;
          // Use addPostFrameCallback to avoid calling setState during build
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _loadData(groupId);
          });
        }

        if (_loading) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        return Scaffold(
          appBar: AppBar(title: const Text("Group Constitution")),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _rulesController,
                    enabled: _isAdmin, // ✅ This should work consistently now
                    maxLines: null,
                    decoration: InputDecoration(
                      labelText: "Group Rules / Constitution",
                      border: const OutlineInputBorder(),
                      helperText: _isAdmin ? "You can edit as admin" : "Read-only for members",
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_pdfUrl != null)
                  Row(
                    children: [
                      const Icon(Icons.picture_as_pdf),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextButton(
                          onPressed: () => launchUrl(Uri.parse(_pdfUrl!)),
                          child: const Text("View Uploaded PDF"),
                        ),
                      ),
                    ],
                  ),
                if (_isAdmin)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _uploading ? null : () => _uploadPdf(groupId),
                        icon: const Icon(Icons.upload_file),
                        label: Text(_uploading ? "Uploading..." : "Upload PDF"),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () => _saveChanges(groupId),
                        child: const Text("Save Changes"),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, _) => Scaffold(body: Center(child: Text("Error: $err"))),
    );
  }
}