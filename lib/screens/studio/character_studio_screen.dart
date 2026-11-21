import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme.dart';
import '../../data/models/app_user.dart';
import '../../data/models/fighter_config.dart';
import '../../data/models/fighter_stats.dart';
import '../../data/models/moveset.dart';
import '../../data/repositories/fighter_repository.dart';
import '../../game/preview/fighter_preview_game.dart';
import '../../services/app_services.dart';
import '../../services/face_cache.dart';

/// Character Studio: selfie/gallery -> circular face crop -> composited live
/// onto a customisable fighter inside a Flame preview, then saved to
/// Firestore (config) + Firebase Storage (face texture).
class CharacterStudioScreen extends StatefulWidget {
  const CharacterStudioScreen({super.key, required this.user, this.existing});

  final AppUser user;
  final FighterConfig? existing;

  @override
  State<CharacterStudioScreen> createState() => _CharacterStudioScreenState();
}

class _CharacterStudioScreenState extends State<CharacterStudioScreen> {
  static const _primaryOptions = [
    Color(0xFFD32F2F), Color(0xFF1E88E5), Color(0xFF43A047), Color(0xFF8E24AA),
    Color(0xFFFB8C00), Color(0xFF212121), Color(0xFFFAFAFA), Color(0xFF00897B),
    Color(0xFFD81B60), Color(0xFFFFC107),
  ];
  static const _skinOptions = [
    Color(0xFFFFDBAC), Color(0xFFF1C27D), Color(0xFFE0AC69),
    Color(0xFFC68642), Color(0xFF8D5524), Color(0xFF5C3A1E),
  ];
  static const _hairOptions = [
    Color(0xFF1B1B1B), Color(0xFF4E342E), Color(0xFFD7B56D),
    Color(0xFFB23A22), Color(0xFFECEFF1), Color(0xFF3949AB),
  ];

  late FighterConfig _draft;
  late final FighterPreviewGame _preview;
  final _name = TextEditingController();

  Uint8List? _newFaceBytes;
  ui.Image? _faceImage;
  bool _removeFace = false;
  bool _saving = false;

  bool get _isNew => widget.existing == null;

  @override
  void initState() {
    super.initState();
    _draft = widget.existing ?? FighterConfig.blank();
    _name.text = _draft.name;
    _preview = FighterPreviewGame(config: _draft);
    final existing = widget.existing;
    if (existing != null && existing.hasFace) {
      FaceCache.instance.load(existing).then((img) {
        if (!mounted || img == null || _newFaceBytes != null || _removeFace) return;
        setState(() => _faceImage = img);
        _syncPreview();
      });
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _update(FighterConfig Function(FighterConfig) change) {
    setState(() => _draft = change(_draft));
    _syncPreview();
  }

  void _syncPreview() => _preview.updateFighter(_draft, _faceImage);

  // ---------------------------------------------------------------------------
  // Face capture
  // ---------------------------------------------------------------------------

  Future<void> _pickFace(ImageSource source) async {
    try {
      final shot = await ImagePicker().pickImage(
        source: source,
        preferredCameraDevice: CameraDevice.front,
        maxWidth: 1200,
        maxHeight: 1200,
      );
      if (shot == null) return;

      Uint8List? bytes;
      if (kIsWeb) {
        bytes = await shot.readAsBytes(); // cropper needs extra web setup
      } else {
        final cropped = await ImageCropper().cropImage(
          sourcePath: shot.path,
          aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
          compressFormat: ImageCompressFormat.png,
          maxWidth: 512,
          maxHeight: 512,
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'Crop your face',
              toolbarColor: AppColors.background,
              toolbarWidgetColor: Colors.white,
              cropStyle: CropStyle.circle,
              lockAspectRatio: true,
              initAspectRatio: CropAspectRatioPreset.square,
            ),
            IOSUiSettings(
              title: 'Crop your face',
              cropStyle: CropStyle.circle,
              aspectRatioLockEnabled: true,
            ),
          ],
        );
        if (cropped == null) return;
        bytes = await cropped.readAsBytes();
      }

      final img = await FaceCache.decode(bytes);
      if (!mounted) return;
      setState(() {
        _newFaceBytes = bytes;
        _faceImage = img;
        _removeFace = false;
      });
      _syncPreview();
    } catch (e) {
      _toast('Could not get photo: $e');
    }
  }

  void _clearFace() {
    setState(() {
      _newFaceBytes = null;
      _faceImage = null;
      _removeFace = true;
    });
    _syncPreview();
  }

  // ---------------------------------------------------------------------------
  // Save / delete
  // ---------------------------------------------------------------------------

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      _toast('Give your fighter a name.');
      return;
    }
    if (!_draft.stats.isValid) {
      _toast('Stat points are over budget.');
      return;
    }
    setState(() => _saving = true);
    final uid = widget.user.uid;
    final now = DateTime.now();
    try {
      var cfg = _draft.copyWith(
        name: name,
        createdAt: widget.existing?.createdAt ?? now,
        updatedAt: now,
      );
      final bytes = _newFaceBytes;
      if (bytes != null) {
        final upload = await AppServices.faces.uploadFace(uid, cfg.id, bytes);
        cfg = cfg.copyWith(faceImagePath: upload.path, faceImageUrl: upload.url);
        await FaceCache.instance.put(cfg, bytes);
      } else if (_removeFace && widget.existing?.faceImagePath != null) {
        await AppServices.faces.deleteFace(widget.existing!.faceImagePath!);
        cfg = cfg.copyWith(clearFace: true);
      }
      await AppServices.fighters.saveFighter(uid, cfg, isNew: _isNew);
      if (mounted) Navigator.of(context).pop(cfg);
    } on SlotLimitReached catch (e) {
      _toast(e.toString());
    } catch (e) {
      _toast('Save failed: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final existing = widget.existing;
    if (existing == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${existing.name}?'),
        content: const Text('This removes the fighter and its face photo.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _saving = true);
    try {
      final path = existing.faceImagePath;
      if (path != null) await AppServices.faces.deleteFace(path);
      await AppServices.fighters.deleteFighter(widget.user.uid, existing.id);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      _toast('Delete failed: $e');
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'CHARACTER STUDIO — NEW FIGHTER' : 'CHARACTER STUDIO — EDIT'),
        actions: [
          if (!_isNew)
            IconButton(
              tooltip: 'Delete fighter',
              onPressed: _saving ? null : _delete,
              icon: const Icon(Icons.delete_outline),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save),
              label: const Text('SAVE'),
            ),
          ),
        ],
      ),
      body: Row(
        children: [
          Expanded(flex: 5, child: _previewPane()),
          Expanded(flex: 6, child: _controls()),
        ],
      ),
    );
  }

  Widget _previewPane() {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          children: [
            Positioned.fill(child: GameWidget(game: _preview)),
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 6,
                children: [
                  for (final slot in AttackSlot.values)
                    ActionChip(
                      label: Text(switch (slot) {
                        AttackSlot.light => 'LP',
                        AttackSlot.heavy => 'HK',
                        AttackSlot.special => 'SP',
                        AttackSlot.combo => 'COMBO',
                      }),
                      onPressed: () => _preview.demo(slot),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, Widget child) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 12)),
            const SizedBox(height: 6),
            child,
          ],
        ),
      );

  Widget _controls() {
    final s = _draft.stats;
    return ListView(
      padding: const EdgeInsets.fromLTRB(4, 10, 14, 20),
      children: [
        _section(
          'FACE',
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: _draft.skinColor,
                child: _faceImage == null
                    ? const Icon(Icons.face, size: 30, color: Colors.black54)
                    : ClipOval(
                        child: SizedBox(
                          width: 60,
                          height: 60,
                          child: RawImage(image: _faceImage, fit: BoxFit.cover),
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (!kIsWeb)
                      FilledButton.icon(
                        onPressed: () => _pickFace(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('SELFIE'),
                      ),
                    OutlinedButton.icon(
                      onPressed: () => _pickFace(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library),
                      label: const Text('GALLERY'),
                    ),
                    if (_faceImage != null)
                      TextButton(onPressed: _clearFace, child: const Text('Remove')),
                  ],
                ),
              ),
            ],
          ),
        ),
        _section(
          'NAME',
          TextField(
            controller: _name,
            maxLength: 16,
            decoration: const InputDecoration(hintText: 'e.g. Iron Comet', counterText: ''),
          ),
        ),
        _section(
          'COSTUME',
          Wrap(
            spacing: 6,
            children: [
              for (final c in Costume.values)
                ChoiceChip(
                  label: Text(c.label),
                  selected: _draft.costume == c,
                  onSelected: (_) => _update((d) => d.copyWith(costume: c)),
                ),
            ],
          ),
        ),
        _section(
          'BUILD',
          SegmentedButton<BodyType>(
            segments: [
              for (final b in BodyType.values) ButtonSegment(value: b, label: Text(b.label)),
            ],
            selected: {_draft.bodyType},
            onSelectionChanged: (v) => _update((d) => d.copyWith(bodyType: v.first)),
          ),
        ),
        _section(
          'COLORS',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _swatches('Main', _primaryOptions, _draft.primaryColor,
                  (c) => _update((d) => d.copyWith(primaryColor: c))),
              _swatches('Accent', _primaryOptions, _draft.secondaryColor,
                  (c) => _update((d) => d.copyWith(secondaryColor: c))),
              _swatches('Skin', _skinOptions, _draft.skinColor,
                  (c) => _update((d) => d.copyWith(skinColor: c))),
              _swatches('Hair', _hairOptions, _draft.hairColor,
                  (c) => _update((d) => d.copyWith(hairColor: c))),
            ],
          ),
        ),
        _section(
          'MOVESET',
          Column(
            children: [
              for (final m in Movesets.all) _movesetTile(m),
            ],
          ),
        ),
        _section(
          'STATS  (${s.remaining} points left)',
          Column(
            children: [
              _statStepper('Power', s.power, (v) => s.copyWith(power: v)),
              _statStepper('Speed', s.speed, (v) => s.copyWith(speed: v)),
              _statStepper('Defense', s.defense, (v) => s.copyWith(defense: v)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _swatches(String label, List<Color> options, Color selected, ValueChanged<Color> onPick) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(width: 56, child: Text(label, style: const TextStyle(fontSize: 12))),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final c in options)
                  GestureDetector(
                    onTap: () => onPick(c),
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: c.toARGB32() == selected.toARGB32() ? AppColors.gold : Colors.white24,
                          width: c.toARGB32() == selected.toARGB32() ? 3 : 1,
                        ),
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

  Widget _movesetTile(Moveset m) {
    final selected = _draft.movesetId == m.id;
    return Card(
      color: selected ? AppColors.accent.withValues(alpha: 0.25) : AppColors.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: selected ? AppColors.accent : Colors.white12),
      ),
      child: ListTile(
        dense: true,
        onTap: () => _update((d) => d.copyWith(movesetId: m.id)),
        title: Text(m.name.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text(
          '${m.description}\n'
          'LP ${m.light.name} • HK ${m.heavy.name} • SP ${m.special.name}\n'
          'COMBO ${m.combo.name}: ${m.sequenceLabel}',
          style: const TextStyle(fontSize: 11),
        ),
        isThreeLine: true,
        trailing: selected ? const Icon(Icons.check_circle, color: AppColors.gold) : null,
      ),
    );
  }

  Widget _statStepper(String label, int value, FighterStats Function(int) withValue) {
    final s = _draft.stats;
    final canInc = value < FighterStats.maxStat && s.remaining > 0;
    final canDec = value > FighterStats.minStat;
    return Row(
      children: [
        SizedBox(width: 70, child: Text(label)),
        IconButton(
          onPressed: canDec ? () => _update((d) => d.copyWith(stats: withValue(value - 1))) : null,
          icon: const Icon(Icons.remove_circle_outline),
        ),
        for (var i = 0; i < FighterStats.maxStat; i++)
          Container(
            width: 22,
            height: 10,
            margin: const EdgeInsets.only(right: 3),
            color: i < value ? AppColors.accent : Colors.white12,
          ),
        IconButton(
          onPressed: canInc ? () => _update((d) => d.copyWith(stats: withValue(value + 1))) : null,
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    );
  }
}
