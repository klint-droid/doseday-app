import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/medication.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/common.dart';

/// Opens the add/edit sheet styled after Figma screen_add.png
Future<Medication?> showMedicationForm(BuildContext context, {Medication? medication}) =>
    showModalBottomSheet<Medication>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => MedicationForm(medication: medication),
    );

class MedicationForm extends StatefulWidget {
  const MedicationForm({super.key, this.medication});

  final Medication? medication;

  @override
  State<MedicationForm> createState() => _MedicationFormState();
}

class _MedicationFormState extends State<MedicationForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _dosage;
  late final TextEditingController _instructions;
  late final TextEditingController _stock;
  late final TextEditingController _threshold;
  late String _unit;
  late DateTime _start;
  DateTime? _end;
  late List<String> _times;
  bool _saving = false;

  bool get _isEdit => widget.medication != null;

  @override
  void initState() {
    super.initState();
    final m = widget.medication;
    _name = TextEditingController(text: m?.name ?? '');
    _dosage = TextEditingController(text: m?.dosage ?? '1');
    _instructions = TextEditingController(text: m?.instructions ?? '');
    _stock = TextEditingController(text: '${m?.stockQuantity ?? 30}');
    _threshold = TextEditingController(text: '${m?.refillThreshold ?? 5}');
    _unit = m?.dosageUnit ?? Medication.units.first;
    _start = DateTime.tryParse(m?.startDate ?? '') ?? DateTime.now();
    _end = m?.endDate == null ? null : DateTime.tryParse(m!.endDate!);
    _times = [...(m?.times ?? ['08:00'])];
  }

  @override
  void dispose() {
    _name.dispose();
    _dosage.dispose();
    _instructions.dispose();
    _stock.dispose();
    _threshold.dispose();
    super.dispose();
  }

  Future<void> _addTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
    );
    if (picked == null) return;
    final t =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    if (_times.contains(t)) return;
    setState(() => _times = [..._times, t]..sort());
  }

  Future<void> _pickDate({required bool start}) async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: start ? _start : (_end ?? _start),
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 20),
    );
    if (selected == null) return;
    setState(() {
      if (start) {
        _start = selected;
      } else {
        _end = selected;
      }
    });
  }

  void _error(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_times.isEmpty) return _error('Add at least one reminder time.');
    if (_end != null && dateKey(_end!).compareTo(dateKey(_start)) < 0) {
      return _error('End date must be on or after the start date.');
    }

    setState(() => _saving = true);
    try {
      final old = widget.medication;
      final med = Medication(
        id: old?.id,
        name: _name.text.trim(),
        dosage: _dosage.text.trim(),
        dosageUnit: _unit,
        instructions: _instructions.text.trim(),
        startDate: dateKey(_start),
        endDate: _end == null ? null : dateKey(_end!),
        stockQuantity: int.parse(_stock.text),
        refillThreshold: int.parse(_threshold.text),
        times: [..._times],
        isActive: old?.isActive ?? true,
      );
      final saved = await DatabaseService.instance.saveMedication(med);
      await NotificationService.instance.scheduleMedication(saved);
      if (mounted) Navigator.pop(context, saved);
    } catch (e) {
      if (mounted) _error('Could not save medication: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _nonNegativeInt(String? v) {
    final n = int.tryParse(v ?? '');
    return n == null || n < 0 ? 'Use 0 or more' : null;
  }

  @override
  Widget build(BuildContext context) {
    const sectionStyle = TextStyle(
      fontWeight: FontWeight.w800,
      fontSize: 15,
      color: AppColors.text,
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isEdit ? 'Edit Medication' : 'Add Medication',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 18),

              // Medicine Name Field
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Medication Name',
                  hintText: 'e.g. Amoxicillin or Vitamin C',
                  prefixIcon: const Icon(Icons.medication_rounded, color: AppColors.primary),
                  fillColor: AppColors.surfaceSubtle,
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Enter medication name' : null,
              ),

              const SizedBox(height: 14),

              // Dose Amount & Unit Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _dosage,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                      decoration: InputDecoration(
                        labelText: 'Dose Amount',
                        hintText: 'e.g. 1 or 500',
                        fillColor: AppColors.surfaceSubtle,
                      ),
                      validator: (v) {
                        final n = double.tryParse(v ?? '');
                        return n == null || n <= 0 ? 'Enter valid dose' : null;
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _unit,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Unit',
                        fillColor: AppColors.surfaceSubtle,
                      ),
                      items: Medication.units
                          .map((u) => DropdownMenuItem(value: u, child: Text(u, overflow: TextOverflow.ellipsis)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _unit = v);
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Instructions field
              TextFormField(
                controller: _instructions,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Instructions (optional)',
                  hintText: 'e.g. Take with food or Before bed',
                  fillColor: AppColors.surfaceSubtle,
                ),
              ),

              const SizedBox(height: 20),

              // Reminder Times Section
              const Text('Reminder Times', style: sectionStyle),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  ..._times.map((t) => InputChip(
                        avatar: const Icon(Icons.alarm_rounded, size: 16, color: AppColors.primary),
                        label: Text(formatTime(t), style: const TextStyle(fontWeight: FontWeight.w700)),
                        backgroundColor: AppColors.primarySoft,
                        side: BorderSide.none,
                        onDeleted: _times.length == 1
                            ? null
                            : () => setState(() => _times = [..._times]..remove(t)),
                        deleteButtonTooltipMessage: 'Remove ${formatTime(t)}',
                      )),
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 16, color: AppColors.primary),
                    label: const Text('Add Time', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: AppColors.primary, width: 1.2),
                    onPressed: _addTime,
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Start & End Dates (Styled after Figma calendar cards)
              const Text('Schedule Duration', style: sectionStyle),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _pickDate(start: true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceSubtle,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            const PastelIconBadge(
                              icon: Icons.calendar_today_rounded,
                              bg: AppColors.primaryContainer,
                              color: AppColors.primary,
                              size: 34,
                              radius: 10,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Start Date', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                                  Text(
                                    shortDate(dateKey(_start)),
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.text),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _pickDate(start: false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceSubtle,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            const PastelIconBadge(
                              icon: Icons.event_rounded,
                              bg: AppColors.peachBg,
                              color: AppColors.peachColor,
                              size: 34,
                              radius: 10,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('End Date', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                                  Text(
                                    _end == null ? 'Ongoing' : shortDate(dateKey(_end!)),
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.text),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (_end != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => setState(() => _end = null),
                    child: const Text('Clear End Date', style: TextStyle(color: AppColors.primary, fontSize: 12)),
                  ),
                ),

              const SizedBox(height: 18),

              // Stock & Refill Alert
              const Text('Stock Management', style: sectionStyle),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _stock,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: 'Current Stock',
                        fillColor: AppColors.surfaceSubtle,
                      ),
                      validator: _nonNegativeInt,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _threshold,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: 'Refill Alert At',
                        fillColor: AppColors.surfaceSubtle,
                      ),
                      validator: _nonNegativeInt,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // Full-width Figma Royal Purple Button with Glow
              Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: .32),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4),
                        )
                      : Text(
                          _isEdit ? 'Save Changes' : 'Add Medication',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
