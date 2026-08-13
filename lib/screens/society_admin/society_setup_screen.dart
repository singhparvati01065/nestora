import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../api/api_client.dart';
import '../../data/society_repository.dart';
import '../../models/society.dart';
import '../../models/user_role.dart';
import '../avatar_image.dart';

/// Form to create or edit the society and its tower/flat structure.
///
/// Most societies have the same number of flats on every floor, so a tower only
/// asks for two numbers — floors, and flats per floor. Uneven towers opt in to a
/// per-floor breakdown, which stays hidden until then.
///
/// Pops with `true` when the society is saved.
class SocietySetupScreen extends StatefulWidget {
  const SocietySetupScreen({super.key, this.existing});

  /// When non-null, the form is pre-filled and edits the structure in place.
  final Society? existing;

  @override
  State<SocietySetupScreen> createState() => _SocietySetupScreenState();
}

/// Controllers + state for one tower's inputs.
///
/// A tower is "every floor has N flats, except these ones". Only the floors the
/// user singles out are held in [exceptions] — the rest are implied. That keeps
/// a 20-floor tower to two inputs instead of twenty boxes.
class _TowerFields {
  _TowerFields({int floors = 0, int flatsPerFloor = 0})
    : floorsController = TextEditingController(
        text: floors > 0 ? '$floors' : '',
      ),
      flatsController = TextEditingController(
        text: flatsPerFloor > 0 ? '$flatsPerFloor' : '',
      );

  final TextEditingController floorsController;

  /// Flats on every floor that has no entry in [exceptions].
  final TextEditingController flatsController;

  /// floor number → its own flat count. Empty for an even tower.
  final Map<int, int> exceptions = {};

  /// Open in the accordion. The first tower starts open so the form is not a
  /// wall of collapsed rows.
  bool expanded = false;

  int _read(TextEditingController c, {int max = 200}) {
    final n = int.tryParse(c.text.trim()) ?? 0;
    return n.clamp(0, max);
  }

  int get floorCount => _read(floorsController, max: 100);
  int get uniformFlats => _read(flatsController, max: 50);

  /// Floors with no exception yet — what "add an exception" can still offer.
  List<int> get availableFloors => [
    for (var f = 1; f <= floorCount; f++)
      if (!exceptions.containsKey(f)) f,
  ];

  /// Drops exceptions for floors that no longer exist after the count shrank.
  void pruneExceptions() {
    exceptions.removeWhere((floor, _) => floor > floorCount);
  }

  /// Pre-fills from an existing tower's per-floor counts. The most common count
  /// becomes the uniform value; whatever disagrees becomes an exception, so a
  /// tower that is even apart from its ground floor opens with exactly one row.
  void seedFromCounts(List<int> counts) {
    floorsController.text = counts.length.toString();
    if (counts.isEmpty) return;

    final tally = <int, int>{};
    for (final c in counts) {
      tally[c] = (tally[c] ?? 0) + 1;
    }
    final common = tally.entries
        .reduce((a, b) => b.value > a.value ? b : a)
        .key;
    flatsController.text = common.toString();

    for (var i = 0; i < counts.length; i++) {
      if (counts[i] != common) exceptions[i + 1] = counts[i];
    }
  }

  /// Final per-floor flat counts to build the tower from.
  List<int> resolveFlatsPerFloor() =>
      List.generate(floorCount, (i) => exceptions[i + 1] ?? uniformFlats);

  int get totalFlats => resolveFlatsPerFloor().fold(0, (a, b) => a + b);

  void dispose() {
    floorsController.dispose();
    flatsController.dispose();
  }
}

class _SocietySetupScreenState extends State<SocietySetupScreen> {
  static const int _maxTowers = 26;

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final TextEditingController _cityController;
  late final TextEditingController _stateController;
  late final TextEditingController _towersCountController;

  final List<_TowerFields> _towerFields = [];

  /// False when the society is one building with no towers. Chosen at creation
  /// only — the backend refuses to renumber an existing society's flats, so an
  /// edit inherits whatever the society already is.
  bool _hasTowers = true;

  /// Towers the user has scrolled past by lowering the count. Kept rather than
  /// disposed so putting the count back restores what they typed.
  final List<_TowerFields> _detachedTowers = [];

  Color get _accent => UserRole.societyAdmin.color;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final s = widget.existing;
    _nameController = TextEditingController(text: s?.name ?? '');
    _addressController = TextEditingController(text: s?.address ?? '');
    _cityController = TextEditingController(text: s?.city ?? '');
    _stateController = TextEditingController(text: s?.state ?? '');
    _nameController.addListener(() => setState(() {}));

    if (s != null) {
      _hasTowers = s.hasTowers;
      _towersCountController = TextEditingController(
        text: s.towers.length.toString(),
      );
      for (final tower in s.towers) {
        final fields = _TowerFields();
        fields.seedFromCounts(tower.flatsPerFloorCounts);
        _towerFields.add(fields);
      }
    } else {
      _towersCountController = TextEditingController(text: '1');
      _towerFields.add(_TowerFields());
    }
    if (_towerFields.isNotEmpty) _towerFields.first.expanded = true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _towersCountController.dispose();
    for (final f in [..._towerFields, ..._detachedTowers]) {
      f.dispose();
    }
    super.dispose();
  }

  /// Grows/shrinks the per-tower field list to match the typed tower count.
  void _syncTowerFields(String value) {
    final text = value.trim();
    // An empty box means the user is mid-edit — going 2 → 3 clears the field
    // first. Treating that blank as "zero towers" used to wipe every tower's
    // config, so the new count came back blank. Leave the list alone instead.
    if (text.isEmpty) {
      setState(() {});
      return;
    }

    var count = int.tryParse(text) ?? 0;
    if (count > _maxTowers) count = _maxTowers;
    if (count < 0) count = 0;

    setState(() {
      while (_towerFields.length < count) {
        // Bring back a tower the user shrank past, before making a blank one.
        _towerFields.add(
          _detachedTowers.isNotEmpty
              ? _detachedTowers.removeLast()
              : _TowerFields(),
        );
      }
      while (_towerFields.length > count) {
        _detachedTowers.add(_towerFields.removeLast());
      }
      if (_towerFields.isNotEmpty && !_towerFields.any((t) => t.expanded)) {
        _towerFields.first.expanded = true;
      }
    });
  }

  /// Switches between one building and several towers.
  ///
  /// One building is exactly one set of floors — the backend rejects anything
  /// else — so the extra towers are parked, not disposed, and come back if the
  /// user switches away again.
  void _setHasTowers(bool value) {
    setState(() {
      _hasTowers = value;
      if (value) {
        _towersCountController.text = '${_towerFields.length}';
        return;
      }
      while (_towerFields.length > 1) {
        _detachedTowers.add(_towerFields.removeLast());
      }
      if (_towerFields.isEmpty) _towerFields.add(_TowerFields());
      _towerFields.first.expanded = true;
      _towersCountController.text = '1';
    });
  }

  void _bumpTowers(int delta) {
    final next = (_towerFields.length + delta).clamp(1, _maxTowers);
    _towersCountController.text = '$next';
    _syncTowerFields('$next');
  }

  String? _validatePositiveInt(String? value, {int max = 200}) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Required';
    final n = int.tryParse(v);
    if (n == null) return 'Invalid';
    if (n < 1) return 'Min 1';
    if (n > max) return 'Too large';
    return null;
  }

  bool _saving = false;

  Future<void> _save({bool force = false}) async {
    if (!_formKey.currentState!.validate()) return;
    if (_towerFields.isEmpty) return;

    final specs = _towerFields
        .map((f) => TowerSpec(flatsPerFloor: f.resolveFlatsPerFloor()))
        .toList();

    setState(() => _saving = true);
    try {
      if (_isEditing) {
        await SocietyRepository.instance.update(
          towerSpecs: specs,
          hasTowers: _hasTowers,
          force: force,
        );
      } else {
        await SocietyRepository.instance.create(
          name: _nameController.text.trim(),
          address: _addressController.text.trim(),
          city: _cityController.text.trim(),
          state: _stateController.text.trim(),
          towerSpecs: specs,
          hasTowers: _hasTowers,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } on DestructiveChange catch (loss) {
      if (!mounted) return;
      setState(() => _saving = false);
      final confirmed = await _confirmDataLoss(loss);
      if (confirmed == true) await _save(force: true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(ApiClient.messageFor(e))));
    }
  }

  /// Spells out exactly what the edit destroys before letting it through.
  Future<bool?> _confirmDataLoss(DestructiveChange loss) {
    final flats = loss.flatNumbers;
    final shown = flats.take(12).join(', ');
    final rest = flats.length - 12;
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: Colors.red),
        title: const Text('This will delete data'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Removing ${flats.length} '
              '${flats.length == 1 ? 'flat' : 'flats'} also deletes:',
            ),
            const SizedBox(height: 8),
            for (final line in loss.losses)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  '•  $line',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            const SizedBox(height: 12),
            Text(
              'Flats: $shown${rest > 0 ? ' +$rest more' : ''}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            const Text('This cannot be undone.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete anyway'),
          ),
        ],
      ),
    );
  }

  int get _totalFlatsPreview =>
      _towerFields.fold(0, (sum, f) => sum + f.totalFlats);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = _nameController.text.trim();
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Structure' : 'Set Up Society'),
        backgroundColor: _accent,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              if (!_isEditing) ...[
                _LogoHeader(initial: initial, accent: _accent),
                const SizedBox(height: 24),
              ],
              // Editing is structure only — name and address live in Society
              // details, so they are not repeated here.
              if (!_isEditing) ...[
                const _SectionLabel('Details'),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Society name',
                    hintText: 'e.g. Green Valley Residency',
                    prefixIcon: Icon(Icons.apartment_outlined),
                  ),
                  validator: (v) =>
                      (v?.trim().isEmpty ?? true) ? 'Enter society name' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _addressController,
                  minLines: 2,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Address',
                    hintText: 'Full address with city & pincode',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                  validator: (v) =>
                      (v?.trim().isEmpty ?? true) ? 'Enter address' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _cityController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'City',
                          hintText: 'e.g. Pune',
                          prefixIcon: Icon(Icons.location_city_outlined),
                        ),
                        validator: (v) =>
                            (v?.trim().isEmpty ?? true) ? 'Enter city' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _stateController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'State',
                          hintText: 'e.g. Maharashtra',
                        ),
                        validator: (v) =>
                            (v?.trim().isEmpty ?? true) ? 'Enter state' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 26),
              ],
              _SectionLabel(_hasTowers ? 'Towers' : 'Building'),
              const SizedBox(height: 10),
              _LayoutChoice(
                hasTowers: _hasTowers,
                accent: _accent,
                onChanged: _setHasTowers,
              ),
              const SizedBox(height: 14),
              if (_hasTowers) ...[
                _CountRow(
                  label: 'Number of towers',
                  helper: _towerFields.isEmpty
                      ? 'Named A, B, C… automatically'
                      : 'Towers ${String.fromCharCode(65)}'
                            '–${String.fromCharCode(64 + _towerFields.length)}',
                  controller: _towersCountController,
                  accent: _accent,
                  icon: Icons.holiday_village_outlined,
                  onChanged: _syncTowerFields,
                  onStep: _bumpTowers,
                  validator: (v) => _validatePositiveInt(v, max: _maxTowers),
                ),
                const SizedBox(height: 14),
              ],
              for (var i = 0; i < _towerFields.length; i++)
                _TowerConfigCard(
                  // A tower-less society has one card and no letter to show.
                  letter: _hasTowers ? String.fromCharCode(65 + i) : null,
                  fields: _towerFields[i],
                  accent: _accent,
                  onChanged: () => setState(() {}),
                  validatePositiveInt: _validatePositiveInt,
                ),
              if (_totalFlatsPreview > 0) ...[
                const SizedBox(height: 6),
                _PreviewHint(
                  total: _totalFlatsPreview,
                  towers: _towerFields.length,
                  accent: _accent,
                  isEditing: _isEditing,
                  hasTowers: _hasTowers,
                ),
              ],
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
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
                label: Text(_isEditing ? 'Save Changes' : 'Create Society'),
              ),
              if (_isEditing) ...[
                const SizedBox(height: 10),
                Text(
                  'Existing flats keep their residents and bills. '
                  'Removing a flat that has any will ask first.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Small uppercase heading, matching the admin home's section labels.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text.toUpperCase(),
      style: theme.textTheme.labelMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    );
  }
}

/// One building, or several towers?
///
/// This decides how flats are numbered — 101 versus A101 — so changing it on a
/// society that already has flats renumbers all of them, which the backend
/// treats as deleting every flat and creating new ones.
class _LayoutChoice extends StatelessWidget {
  const _LayoutChoice({
    required this.hasTowers,
    required this.accent,
    required this.onChanged,
  });

  final bool hasTowers;
  final Color accent;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _LayoutOption(
                selected: !hasTowers,
                icon: Icons.apartment_rounded,
                title: 'One building',
                subtitle: 'Flats 101, 102…',
                accent: accent,
                onTap: () => onChanged(false),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _LayoutOption(
                selected: hasTowers,
                icon: Icons.holiday_village_outlined,
                title: 'Multiple towers',
                subtitle: 'Flats A101, B101…',
                accent: accent,
                onTap: () => onChanged(true),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _LayoutOption extends StatelessWidget {
  const _LayoutOption({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected
          ? accent.withValues(alpha: 0.10)
          : theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? accent : theme.colorScheme.outlineVariant,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: selected ? accent : theme.colorScheme.outline,
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: selected ? accent : null,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A number input with −/+ buttons. Typing still works for big jumps; the
/// buttons cover the common ±1 nudge without opening the keyboard.
class _CountRow extends StatelessWidget {
  const _CountRow({
    required this.label,
    required this.controller,
    required this.accent,
    required this.icon,
    required this.onChanged,
    required this.onStep,
    required this.validator,
    this.helper,
  });

  final String label;
  final String? helper;
  final TextEditingController controller;
  final Color accent;
  final IconData icon;
  final ValueChanged<String> onChanged;
  final void Function(int delta) onStep;
  final FormFieldValidator<String> validator;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: onChanged,
            decoration: InputDecoration(
              labelText: label,
              helperText: helper,
              prefixIcon: Icon(icon, size: 20),
              isDense: true,
            ),
            validator: validator,
          ),
        ),
        const SizedBox(width: 8),
        _StepButton(
          icon: Icons.remove,
          accent: accent,
          onTap: () => onStep(-1),
        ),
        const SizedBox(width: 6),
        _StepButton(icon: Icons.add, accent: accent, onTap: () => onStep(1)),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: accent.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, size: 20, color: accent),
        ),
      ),
    );
  }
}

class _LogoHeader extends StatelessWidget {
  const _LogoHeader({required this.initial, required this.accent});

  final String initial;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        children: [
          AvatarImage(
            path: null, // a society being created has no logo yet
            name: initial,
            size: 72,
            background: accent.withValues(alpha: 0.10),
            foreground: accent,
            borderColor: accent.withValues(alpha: 0.5),
            borderWidth: 1,
            fallbackIcon: Icons.apartment_rounded,
          ),
          const SizedBox(height: 8),
          // A picture can only be uploaded once the society exists, so the
          // create path points at where to add one.
          Text(
            'Add a picture later in Society details',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// One tower, collapsed to a summary until opened. Asks only for floors and
/// flats-per-floor; the per-floor grid is opt-in for uneven towers.
class _TowerConfigCard extends StatelessWidget {
  const _TowerConfigCard({
    required this.letter,
    required this.fields,
    required this.accent,
    required this.onChanged,
    required this.validatePositiveInt,
  });

  /// Null for a society with no towers — the card is then just "the building".
  final String? letter;

  final _TowerFields fields;
  final Color accent;
  final VoidCallback onChanged;
  final String? Function(String?, {int max}) validatePositiveInt;

  /// Adds or edits one floor's override. [floor] null means "add a new one".
  Future<void> _editException(BuildContext context, int? floor) async {
    final result = await showDialog<_FloorException>(
      context: context,
      builder: (_) => _FloorExceptionDialog(
        letter: letter ?? '',
        accent: accent,
        // Editing keeps its own floor selectable; adding cannot reuse a floor
        // that already has a row.
        selectableFloors:
            floor == null
                  ? fields.availableFloors
                  : [floor, ...fields.availableFloors]
              ..sort(),
        initialFloor: floor,
        initialFlats: floor == null
            ? fields.uniformFlats
            : fields.exceptions[floor]!,
      ),
    );
    if (result == null) return;
    // Re-picking a different floor while editing must not leave the old row.
    if (floor != null && floor != result.floor) fields.exceptions.remove(floor);
    fields.exceptions[result.floor] = result.flats;
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // A shrunken tower must not keep overrides for floors that are gone.
    fields.pruneExceptions();
    final floors = fields.floorCount;
    final total = fields.totalFlats;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              fields.expanded = !fields.expanded;
              onChanged();
            },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: letter == null
                        ? Icon(Icons.apartment_rounded, color: accent, size: 20)
                        : Text(
                            letter!,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: accent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          letter == null ? 'The building' : 'Tower $letter',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          floors == 0
                              ? 'Not configured yet'
                              : '$floors ${floors == 1 ? 'floor' : 'floors'} • '
                                    '$total ${total == 1 ? 'flat' : 'flats'}'
                                    '${fields.exceptions.isEmpty ? '' : ' • ${fields.exceptions.length} custom'}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: floors == 0
                                ? theme.colorScheme.error
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    fields.expanded ? Icons.expand_less : Icons.expand_more,
                    color: theme.colorScheme.outline,
                  ),
                ],
              ),
            ),
          ),
          if (fields.expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                children: [
                  Divider(color: theme.colorScheme.outlineVariant),
                  const SizedBox(height: 6),
                  _CountRow(
                    label: 'Floors',
                    controller: fields.floorsController,
                    accent: accent,
                    icon: Icons.stairs_outlined,
                    onChanged: (_) => onChanged(),
                    onStep: (d) {
                      final next = (fields.floorCount + d).clamp(1, 100);
                      fields.floorsController.text = '$next';
                      onChanged();
                    },
                    validator: (v) => validatePositiveInt(v, max: 100),
                  ),
                  const SizedBox(height: 12),
                  _CountRow(
                    label: 'Flats on each floor',
                    controller: fields.flatsController,
                    accent: accent,
                    icon: Icons.meeting_room_outlined,
                    onChanged: (_) => onChanged(),
                    onStep: (d) {
                      final next = (fields.uniformFlats + d).clamp(1, 50);
                      fields.flatsController.text = '$next';
                      onChanged();
                    },
                    validator: (v) => validatePositiveInt(v, max: 50),
                  ),
                  // Only the floors that break the pattern get a row. An even
                  // tower shows nothing here at all.
                  for (final floor in fields.exceptions.keys.toList()..sort())
                    _ExceptionRow(
                      floor: floor,
                      flats: fields.exceptions[floor]!,
                      accent: accent,
                      onEdit: () => _editException(context, floor),
                      onRemove: () {
                        fields.exceptions.remove(floor);
                        onChanged();
                      },
                    ),
                  if (floors > 0 && fields.availableFloors.isNotEmpty)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => _editException(context, null),
                        style: TextButton.styleFrom(
                          foregroundColor: accent,
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.add, size: 18),
                        label: Text(
                          fields.exceptions.isEmpty
                              ? 'A floor is different?'
                              : 'Add another floor',
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// One floor that breaks the tower's pattern.
class _FloorException {
  const _FloorException(this.floor, this.flats);

  final int floor;
  final int flats;
}

/// A single "Floor 1 — 2 flats" row, tappable to change, with a remove button.
class _ExceptionRow extends StatelessWidget {
  const _ExceptionRow({
    required this.floor,
    required this.flats,
    required this.accent,
    required this.onEdit,
    required this.onRemove,
  });

  final int floor;
  final int flats;
  final Color accent;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Material(
        color: accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onEdit,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
            child: Row(
              children: [
                Icon(Icons.tune, size: 16, color: accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Floor $floor',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '$flats ${flats == 1 ? 'flat' : 'flats'}',
                  style: theme.textTheme.bodyMedium?.copyWith(color: accent),
                ),
                IconButton(
                  tooltip: 'Remove',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    Icons.close,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  onPressed: onRemove,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Picks which floor differs and how many flats it has.
class _FloorExceptionDialog extends StatefulWidget {
  const _FloorExceptionDialog({
    required this.letter,
    required this.accent,
    required this.selectableFloors,
    required this.initialFloor,
    required this.initialFlats,
  });

  final String letter;
  final Color accent;
  final List<int> selectableFloors;
  final int? initialFloor;
  final int initialFlats;

  @override
  State<_FloorExceptionDialog> createState() => _FloorExceptionDialogState();
}

class _FloorExceptionDialogState extends State<_FloorExceptionDialog> {
  late int _floor = widget.initialFloor ?? widget.selectableFloors.first;
  late int _flats = widget.initialFlats > 0 ? widget.initialFlats : 1;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(
        widget.initialFloor == null
            ? 'Which floor is different?'
            : 'Floor $_floor',
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<int>(
            initialValue: _floor,
            decoration: const InputDecoration(
              labelText: 'Floor',
              prefixIcon: Icon(Icons.stairs_outlined, size: 20),
              isDense: true,
            ),
            items: [
              for (final f in widget.selectableFloors)
                DropdownMenuItem(value: f, child: Text('Floor $f')),
            ],
            onChanged: (v) => setState(() => _floor = v ?? _floor),
          ),
          const SizedBox(height: 18),
          Text('Flats on this floor', style: theme.textTheme.bodySmall),
          const SizedBox(height: 6),
          Row(
            children: [
              _StepButton(
                icon: Icons.remove,
                accent: widget.accent,
                onTap: () => setState(() => _flats = (_flats - 1).clamp(1, 50)),
              ),
              Expanded(
                child: Text(
                  '$_flats',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _StepButton(
                icon: Icons.add,
                accent: widget.accent,
                onTap: () => setState(() => _flats = (_flats + 1).clamp(1, 50)),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: widget.accent),
          onPressed: () =>
              Navigator.of(context).pop(_FloorException(_floor, _flats)),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

/// Live summary of what the entered numbers add up to.
class _PreviewHint extends StatelessWidget {
  const _PreviewHint({
    required this.total,
    required this.towers,
    required this.accent,
    required this.isEditing,
    required this.hasTowers,
  });

  final int total;
  final int towers;
  final Color accent;

  /// Editing states the resulting total; creating states what will be made.
  final bool isEditing;

  /// A single building has no towers to count, and its flats start at 101.
  final bool hasTowers;

  String _summary() {
    if (!hasTowers) {
      return isEditing
          ? 'Result: $total flats total.'
          : 'Creates $total flats (101, 102…).';
    }
    final label = towers == 1 ? 'tower' : 'towers';
    return isEditing
        ? 'Result: $towers $label, $total flats total.'
        : 'Creates $towers $label and $total flats (A101, A102…).';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: accent),
          const SizedBox(width: 10),
          Expanded(child: Text(_summary(), style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }
}
