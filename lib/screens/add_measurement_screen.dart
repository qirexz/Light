import 'dart:io';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../data/measurement_repository.dart';
import '../data/photo_storage.dart';
import '../models/measurement.dart';
import '../utils/enum_labels.dart';

class AddMeasurementScreen extends StatefulWidget {
  /// If provided, the type is fixed (e.g. opened from that type's
  /// detail screen). If null, the user picks a type from a dropdown.
  final MeasurementType? fixedType;

  /// If editing an existing entry, pass it here to prefill the form.
  final Measurement? existing;

  const AddMeasurementScreen({super.key, this.fixedType, this.existing});

  @override
  State<AddMeasurementScreen> createState() => _AddMeasurementScreenState();
}

class _AddMeasurementScreenState extends State<AddMeasurementScreen> {
  final _repo = MeasurementRepository();
  final _uuid = const Uuid();
  late final TextEditingController _valueController;
  late final TextEditingController _unitController;
  late MeasurementType _type;
  late DateTime _date;
  String? _photoPath;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _type = existing?.type ?? widget.fixedType ?? MeasurementType.bodyWeight;
    _unitController = TextEditingController(text: existing?.unit ?? _type.defaultUnit);
    _date = existing?.date ?? DateTime.now();
    _photoPath = existing?.photoPath;
    _valueController = TextEditingController(
      text: existing == null
          ? ''
          : (existing.value == existing.value.roundToDouble()
              ? existing.value.toStringAsFixed(0)
              : existing.value.toString()),
    );
  }

  @override
  void dispose() {
    _valueController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _attachPhoto() async {
    final source = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Take photo'),
              onTap: () => Navigator.pop(context, true),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, false),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final path = await PhotoStorage.pickAndStore(fromCamera: source);
    if (path != null) setState(() => _photoPath = path);
  }

  void _removePhoto() => setState(() => _photoPath = null);

  Future<void> _save() async {
    final value = double.tryParse(_valueController.text);
    if (value == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Enter a valid number.')));
      return;
    }
    setState(() => _saving = true);
    final measurement = Measurement(
      id: widget.existing?.id ?? _uuid.v4(),
      type: _type,
      value: value,
      unit: _unitController.text.trim().isEmpty ? _type.defaultUnit : _unitController.text.trim(),
      date: _date,
      photoPath: _photoPath,
    );
    if (_isEditing) {
      await _repo.updateMeasurement(measurement);
    } else {
      await _repo.insertMeasurement(measurement);
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Entry' : 'Add Measurement'),
        actions: [
          TextButton(onPressed: _saving ? null : _save, child: const Text('Save')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.fixedType == null)
            DropdownButtonFormField<MeasurementType>(
              value: _type,
              decoration: const InputDecoration(labelText: 'Measurement type'),
              items: [
                for (final t in MeasurementType.values)
                  DropdownMenuItem(value: t, child: Text(t.label)),
              ],
              onChanged: (t) {
                if (t == null) return;
                setState(() {
                  _type = t;
                  _unitController.text = t.defaultUnit;
                });
              },
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _valueController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  autofocus: !_isEditing,
                  decoration: const InputDecoration(
                    labelText: 'Value',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _unitController,
                  decoration: const InputDecoration(
                    labelText: 'Unit',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_today),
            title: Text('${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}'),
            trailing: const Icon(Icons.edit),
            onTap: _pickDate,
          ),
          const SizedBox(height: 16),
          const Text('Progress Photo (optional)', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (_photoPath != null)
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(File(_photoPath!), height: 220, width: double.infinity, fit: BoxFit.cover),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: IconButton(
                    icon: const CircleAvatar(child: Icon(Icons.close, size: 18)),
                    onPressed: _removePhoto,
                  ),
                ),
              ],
            )
          else
            OutlinedButton.icon(
              icon: const Icon(Icons.add_a_photo_outlined),
              label: const Text('Attach photo'),
              onPressed: _attachPhoto,
            ),
        ],
      ),
    );
  }
}
