import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../api/api_client.dart';
import '../../data/society_repository.dart';
import '../../models/user_role.dart';
import '../avatar_image.dart';
import '../picture_options_sheet.dart';

/// Edits the society's identity: name, address and logo.
///
/// Deliberately separate from [SocietySetupScreen], which rewrites towers and
/// flats and can destroy data. Renaming a society should never go near that.
/// Pops with `true` when anything was saved.
class SocietyDetailsScreen extends StatefulWidget {
  const SocietyDetailsScreen({super.key});

  @override
  State<SocietyDetailsScreen> createState() => _SocietyDetailsScreenState();
}

class _SocietyDetailsScreenState extends State<SocietyDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repo = SocietyRepository.instance;
  final _picker = ImagePicker();

  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final TextEditingController _cityController;
  late final TextEditingController _stateController;

  /// Set once a new logo has been uploaded, so the preview updates before save.
  String? _logoUrl;

  bool _saving = false;
  bool _uploadingLogo = false;

  Color get _accent => UserRole.societyAdmin.color;

  @override
  void initState() {
    super.initState();
    final s = _repo.society;
    _nameController = TextEditingController(text: s?.name ?? '');
    _addressController = TextEditingController(text: s?.address ?? '');
    _cityController = TextEditingController(text: s?.city ?? '');
    _stateController = TextEditingController(text: s?.state ?? '');
    _logoUrl = s?.logoUrl;
    // The preview initial follows what is typed.
    _nameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    super.dispose();
  }

  /// Camera badge → choose a source, or drop the picture.
  ///
  /// Everything here is held locally until Save, so picking a picture cannot
  /// commit a half-edited name alongside it.
  Future<void> _editPicture() async {
    final action = await showPictureOptions(
      context,
      accent: _accent,
      canRemove: _logoUrl != null,
    );
    if (action == null || !mounted) return;

    if (action == PictureAction.remove) {
      setState(() => _logoUrl = null);
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

    setState(() => _uploadingLogo = true);
    try {
      final url = await ApiClient.instance.uploadImage(File(picked.path));
      if (!mounted) return;
      setState(() {
        _logoUrl = url;
        _uploadingLogo = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploadingLogo = false);
      _snack(ApiClient.messageFor(e));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await _repo.updateProfile(
        name: _nameController.text.trim(),
        address: _addressController.text.trim(),
        city: _cityController.text.trim(),
        state: _stateController.text.trim(),
        logoUrl: _logoUrl,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack(ApiClient.messageFor(e));
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Society details'),
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
                          path: _logoUrl,
                          name: _nameController.text,
                          size: 96,
                          // Circular, matching the profile header's avatar.
                          background: _accent.withValues(alpha: 0.10),
                          foreground: _accent,
                          borderColor: _accent.withValues(alpha: 0.4),
                          borderWidth: 1,
                          fallbackIcon: Icons.apartment_rounded,
                        ),
                        if (_uploadingLogo)
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
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
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
                              onTap: _uploadingLogo ? null : _editPicture,
                              child: const Padding(
                                padding: EdgeInsets.all(7),
                                child: Icon(
                                  Icons.photo_camera_outlined,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Removing now lives in the camera badge's sheet, so the
                    // layout no longer jumps when a picture is added.
                    Text(
                      'Edit picture',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Society name',
                  prefixIcon: Icon(Icons.apartment_outlined),
                ),
                validator: (v) =>
                    (v?.trim().isEmpty ?? true) ? 'Enter society name' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _addressController,
                minLines: 2,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
                validator: (v) =>
                    (v?.trim().isEmpty ?? true) ? 'Enter address' : null,
              ),
              const SizedBox(height: 14),
              // Optional here, unlike society setup: societies created before
              // the app asked for these have neither, and their admin should
              // not be blocked from saving a name or logo over it.
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _cityController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'City',
                        prefixIcon: Icon(Icons.location_city_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _stateController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'State'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: (_saving || _uploadingLogo) ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: _accent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
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
