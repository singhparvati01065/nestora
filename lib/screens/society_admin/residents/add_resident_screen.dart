import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../api/api_client.dart';
import '../../../data/residents_repository.dart';
import '../../../data/society_repository.dart';
import '../../../models/resident.dart';
import '../../../models/user_role.dart';
import '../../picture_options_sheet.dart';

/// Full screen to add (or edit) a resident of a flat. Pops `true` on success so
/// the list can refresh. Pass [existing] to edit that resident instead.
class AddResidentScreen extends StatefulWidget {
  const AddResidentScreen({super.key, this.existing});

  /// When set, the screen edits this resident rather than creating a new one.
  final Resident? existing;

  @override
  State<AddResidentScreen> createState() => _AddResidentScreenState();
}

class _AddResidentScreenState extends State<AddResidentScreen> {
  final _repo = ResidentsRepository.instance;
  Color get _accent => UserRole.societyAdmin.color;

  final _formKey = GlobalKey<FormState>();

  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _rent = TextEditingController();
  final _advance = TextEditingController();
  final _maintenance = TextEditingController();
  final _occupation = TextEditingController();
  final _family = TextEditingController();

  String? _flatId;
  var _type = ResidentType.owner;
  DateTime _moveIn = DateTime.now();
  final _docPaths = <String>[];
  var _uploadingDoc = false;
  var _submitting = false;

  bool get _isEdit => widget.existing != null;

  /// Owners pay maintenance only — rent and advance belong to a tenancy.
  bool get _isOwner => _type == ResidentType.owner;

  /// Every field is mandatory except the advance, which not every tenancy has.
  String? _required(String? v) =>
      (v?.trim().isEmpty ?? true) ? 'Required' : null;

  /// Rent and advance are an owner's to skip, so their text is dropped rather
  /// than kept hidden — otherwise a tenant's amounts would be saved anyway.
  void _setType(ResidentType type) {
    setState(() {
      _type = type;
      if (type == ResidentType.owner) {
        _rent.clear();
        _advance.clear();
      }
    });
  }

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e == null) return;
    _flatId = e.flatId;
    _type = e.type;
    _moveIn = e.moveInDate ?? DateTime.now();
    _name.text = e.name;
    _phone.text = e.phone;
    if (e.monthlyRent != null) _rent.text = e.monthlyRent!.toStringAsFixed(0);
    if (e.advanceAmount != null) {
      _advance.text = e.advanceAmount!.toStringAsFixed(0);
    }
    if (e.maintenanceAmount != null) {
      _maintenance.text = e.maintenanceAmount!.toStringAsFixed(0);
    }
    _occupation.text = e.occupation ?? '';
    if (e.familyMembers != null) _family.text = '${e.familyMembers}';
    _docPaths.addAll(e.documentUrls);
  }

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  String _fmtDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _rent.dispose();
    _advance.dispose();
    _maintenance.dispose();
    _occupation.dispose();
    _family.dispose();
    super.dispose();
  }

  Future<void> _pickDocument() async {
    final choice = await showPictureOptions(
      context,
      accent: _accent,
      canRemove: false,
      title: 'Add document',
    );
    if (choice == null) return;
    final picked = await ImagePicker().pickImage(
      source: choice == PictureAction.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      maxWidth: 1600,
    );
    if (picked == null) return;
    setState(() => _uploadingDoc = true);
    try {
      final path = await ApiClient.instance.uploadImage(File(picked.path));
      setState(() {
        _docPaths.add(path);
        _uploadingDoc = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _uploadingDoc = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Upload failed')));
    }
  }

  /// Opens the tapped document full screen, so an uploaded ID proof can be read
  /// without leaving the form.
  void _openDocument(int index) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _DocumentViewer(
          paths: List.of(_docPaths),
          initialIndex: index,
          accent: _accent,
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final occupation = _occupation.text.trim().isEmpty
          ? null
          : _occupation.text.trim();
      // An owner has neither, whatever a previous tenancy left in the fields.
      final rent = _isOwner ? null : double.tryParse(_rent.text.trim());
      final advance = _isOwner ? null : double.tryParse(_advance.text.trim());
      if (_isEdit) {
        await _repo.update(
          widget.existing!,
          name: _name.text.trim(),
          phone: _phone.text.trim(),
          type: _type,
          moveInDate: _moveIn,
          monthlyRent: rent,
          advance: advance,
          maintenance: double.tryParse(_maintenance.text.trim()),
          occupation: occupation,
          familyMembers: int.tryParse(_family.text.trim()),
          documentUrls: _docPaths,
        );
      } else {
        await _repo.add(
          name: _name.text.trim(),
          phone: _phone.text.trim(),
          flatId: _flatId!,
          type: _type,
          moveInDate: _moveIn,
          rent: rent,
          advance: advance,
          maintenance: double.tryParse(_maintenance.text.trim()),
          occupation: occupation,
          familyMembers: int.tryParse(_family.text.trim()),
          documentUrls: _docPaths,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(ApiClient.messageFor(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final allFlats = SocietyRepository.instance.society?.allFlats ?? const [];
    // Add mode: only flats with no active resident. Edit mode: flat is fixed.
    final vacantFlats = allFlats
        .where((f) => _repo.byFlatId(f.id) == null)
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Resident' : 'Add Resident'),
        backgroundColor: _accent,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          children: [
            if (_isEdit)
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Flat',
                  prefixIcon: Icon(Icons.home_outlined),
                ),
                child: Text(widget.existing!.flatNumber),
              )
            else
              DropdownButtonFormField<String>(
                initialValue: _flatId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Flat',
                  hintText: vacantFlats.isEmpty
                      ? 'All flats are occupied'
                      : 'Choose a vacant flat',
                  prefixIcon: const Icon(Icons.home_outlined),
                ),
                items: [
                  for (final f in vacantFlats)
                    DropdownMenuItem(value: f.id, child: Text(f.number)),
                ],
                onChanged: (v) => setState(() => _flatId = v),
                validator: (v) => v == null ? 'Choose a flat' : null,
              ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Full name',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: _required,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              validator: _required,
            ),
            const SizedBox(height: 12),
            SegmentedButton<ResidentType>(
              segments: const [
                ButtonSegment(value: ResidentType.owner, label: Text('Owner')),
                ButtonSegment(
                  value: ResidentType.tenant,
                  label: Text('Tenant'),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (s) => _setType(s.first),
            ),
            const SizedBox(height: 12),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _moveIn,
                  firstDate: DateTime(2015),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _moveIn = picked);
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Move-in date',
                  prefixIcon: Icon(Icons.event_outlined),
                ),
                child: Text(_fmtDate(_moveIn)),
              ),
            ),
            // Only a tenancy has rent and an advance; an owner just pays
            // maintenance, so both fields are out of the way entirely.
            if (!_isOwner) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _rent,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Rent',
                  hintText: 'Monthly rent',
                  prefixIcon: Icon(Icons.home_outlined),
                ),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _advance,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Advance',
                  hintText: 'Security deposit (optional)',
                  prefixIcon: Icon(Icons.savings_outlined),
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _maintenance,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Maintenance',
                hintText: 'Monthly maintenance',
                prefixIcon: Icon(Icons.handyman_outlined),
              ),
              validator: _required,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _occupation,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Occupation',
                hintText: 'e.g. Software Engineer',
                prefixIcon: Icon(Icons.work_outline),
              ),
              validator: _required,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _family,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Family members',
                hintText: 'People living in the flat',
                prefixIcon: Icon(Icons.groups_outlined),
              ),
              validator: _required,
            ),
            const SizedBox(height: 16),
            _DocumentsField(
              paths: _docPaths,
              uploading: _uploadingDoc,
              accent: _accent,
              onAdd: _pickDocument,
              onOpen: _openDocument,
              onRemove: (p) => setState(() => _docPaths.remove(p)),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _accent,
              minimumSize: const Size.fromHeight(52),
            ),
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    _isEdit ? 'Save' : 'Add Resident',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// The "Documents" section: an upload button plus a chip per uploaded document.
/// Tapping a chip opens that document; the × removes it.
class _DocumentsField extends StatelessWidget {
  const _DocumentsField({
    required this.paths,
    required this.uploading,
    required this.accent,
    required this.onAdd,
    required this.onOpen,
    required this.onRemove,
  });

  final List<String> paths;
  final bool uploading;
  final Color accent;
  final Future<void> Function() onAdd;
  final void Function(int index) onOpen;
  final void Function(String path) onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DOCUMENTS',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: uploading ? null : onAdd,
          style: OutlinedButton.styleFrom(
            foregroundColor: accent,
            side: BorderSide(color: accent.withValues(alpha: 0.5)),
            minimumSize: const Size.fromHeight(46),
          ),
          icon: uploading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.upload_file_outlined),
          label: Text(uploading ? 'Uploading…' : 'Upload document'),
        ),
        if (paths.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < paths.length; i++)
                InputChip(
                  avatar: Icon(
                    Icons.description_outlined,
                    size: 18,
                    color: accent,
                  ),
                  label: Text('Document ${i + 1}'),
                  onPressed: () => onOpen(i),
                  onDeleted: () => onRemove(paths[i]),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Tap a document to open it',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

/// Full-screen look at the uploaded documents, swipeable when there is more
/// than one and pinch-zoomable so small print on an ID proof stays readable.
class _DocumentViewer extends StatefulWidget {
  const _DocumentViewer({
    required this.paths,
    required this.initialIndex,
    required this.accent,
  });

  final List<String> paths;
  final int initialIndex;
  final Color accent;

  @override
  State<_DocumentViewer> createState() => _DocumentViewerState();
}

class _DocumentViewerState extends State<_DocumentViewer> {
  late final PageController _controller = PageController(
    initialPage: widget.initialIndex,
  );
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final paths = widget.paths;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          paths.length == 1
              ? 'Document'
              : 'Document ${_index + 1} of ${paths.length}',
        ),
        backgroundColor: widget.accent,
        foregroundColor: Colors.white,
      ),
      body: PageView.builder(
        controller: _controller,
        onPageChanged: (i) => setState(() => _index = i),
        itemCount: paths.length,
        itemBuilder: (context, i) {
          final url = ApiClient.imageUrl(paths[i]);
          if (url == null) return const SizedBox.shrink();
          return InteractiveViewer(
            minScale: 1,
            maxScale: 4,
            child: Center(
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Text(
                  "Couldn't load this document",
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
