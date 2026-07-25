import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../api/api_client.dart';
import '../api/auth_api.dart';
import '../api/session.dart';
import '../models/complaint.dart';
import '../models/user_role.dart';
import 'avatar_image.dart';
import 'picture_options_sheet.dart';

/// Edits the signed-in person's photo and name, on one screen with a Save
/// button — the counterpart to the Society Admin's Society-details screen.
///
/// Everything is held locally until Save, so picking a photo cannot commit a
/// half-edited name alongside it. Pops with `true` when anything was saved.
class UserProfileEditScreen extends StatefulWidget {
  const UserProfileEditScreen({super.key});

  @override
  State<UserProfileEditScreen> createState() => _UserProfileEditScreenState();
}

class _UserProfileEditScreenState extends State<UserProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  late final TextEditingController _nameController;

  /// The photo chosen so far — a url to set, or null to fall back to the icon.
  String? _photoUrl;

  /// Trades chosen so far; only shown/saved for maintenance staff.
  final Set<String> _trades = {};

  bool _saving = false;
  bool _uploading = false;

  UserRole get _role => Session.instance.user?.role ?? UserRole.resident;
  Color get _accent => _role.color;
  bool get _isMaintenance => _role == UserRole.maintenanceStaff;

  @override
  void initState() {
    super.initState();
    final user = Session.instance.user;
    _nameController = TextEditingController(text: user?.name ?? '');
    _photoUrl = user?.photoUrl;
    _trades.addAll(user?.trades ?? const []);
    // The preview initial follows what is typed.
    _nameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// Camera badge → choose a source, or drop the photo. Held locally until Save.
  Future<void> _editPhoto() async {
    final action = await showPictureOptions(
      context,
      accent: _accent,
      canRemove: _photoUrl != null,
    );
    if (action == null || !mounted) return;

    if (action == PictureAction.remove) {
      setState(() => _photoUrl = null);
      return;
    }

    final picked = await _picker.pickImage(
      source: action == PictureAction.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() => _uploading = true);
    try {
      final url = await ApiClient.instance.uploadImage(File(picked.path));
      if (!mounted) return;
      setState(() {
        _photoUrl = url;
        _uploading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploading = false);
      _snack(ApiClient.messageFor(e));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isMaintenance && _trades.isEmpty) {
      _snack('Pick at least one type of work');
      return;
    }
    setState(() => _saving = true);
    try {
      await AuthApi.instance.updateMe(
        name: _nameController.text.trim(),
        photoUrl: _photoUrl, // explicit null clears the photo
        trades: _isMaintenance ? _trades.toList() : null,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack(ApiClient.messageFor(e));
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit profile'),
        backgroundColor: _accent,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
            children: [
              Center(
                child: Column(
                  children: [
                    Stack(
                      children: [
                        AvatarImage(
                          path: _photoUrl,
                          name: _nameController.text,
                          size: 96,
                          background: _accent.withValues(alpha: 0.10),
                          foreground: _accent,
                          borderColor: _accent.withValues(alpha: 0.4),
                          borderWidth: 1,
                          fallbackIcon: Icons.person,
                        ),
                        if (_uploading)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.3),
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                ),
                              ),
                            ),
                          ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Material(
                            color: _accent,
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: _uploading ? null : _editPhoto,
                              child: const Padding(
                                padding: EdgeInsets.all(7),
                                child: Icon(Icons.photo_camera_outlined,
                                    size: 16, color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text('Edit picture',
                        style: theme.textTheme.labelLarge
                            ?.copyWith(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Full name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) =>
                    (v?.trim().isEmpty ?? true) ? 'Enter your name' : null,
              ),
              if (_isMaintenance) ...[
                const SizedBox(height: 22),
                Text('Work you handle',
                    style: theme.textTheme.labelLarge
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('Complaints in these categories come to you.',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final c in kComplaintCategories)
                      FilterChip(
                        label: Text(c),
                        selected: _trades.contains(c),
                        selectedColor: _accent.withValues(alpha: 0.18),
                        checkmarkColor: _accent,
                        onSelected: (on) => setState(
                            () => on ? _trades.add(c) : _trades.remove(c)),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: (_saving || _uploading) ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: _accent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check),
                label: const Text('Save changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
