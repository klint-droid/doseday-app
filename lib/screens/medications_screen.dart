import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/medication.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/common.dart';
import 'medication_form.dart';

class MedicationsScreen extends StatefulWidget {
  const MedicationsScreen({super.key});

  @override
  State<MedicationsScreen> createState() => _MedicationsScreenState();
}

class _MedicationsScreenState extends State<MedicationsScreen> {
  final _db = DatabaseService.instance;
  List<Medication>? _meds;

  @override
  void initState() {
    super.initState();
    _db.changes.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    _db.changes.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final meds = await _db.getMedications();
    if (mounted) setState(() => _meds = meds);
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _edit(Medication med) async {
    final updated = await showMedicationForm(context, medication: med);
    if (updated != null && mounted) _toast('${updated.name} updated');
  }

  Future<void> _toggleActive(Medication med) async {
    if (med.id == null) return;
    final active = !med.isActive;
    await _db.setActive(med.id!, active);
    await NotificationService.instance.scheduleMedication(med.copyWith(isActive: active));
    if (mounted) _toast(active ? 'Reminders resumed for ${med.name}' : 'Reminders paused for ${med.name}');
  }

  Future<void> _delete(Medication med) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        icon: const Icon(Icons.delete_outline_rounded),
        title: const Text('Delete medication?'),
        content: Text('This removes ${med.name}, its reminders, and its dose history.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.missed),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (yes == true && med.id != null) {
      await NotificationService.instance.cancelMedication(med.id!);
      await _db.deleteMedication(med.id!);
      if (mounted) _toast('${med.name} deleted');
    }
  }

  Future<void> _refill(Medication med) async {
    final controller = TextEditingController(text: '30');
    final amount = await showDialog<int>(
      context: context,
      builder: (c) => AlertDialog(
        icon: const Icon(Icons.inventory_2_outlined),
        title: Text('Restock ${med.name}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: 'Units added',
            hintText: 'e.g. 30',
            helperText: 'Current stock: ${med.stockQuantity}',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, int.tryParse(controller.text)), child: const Text('Add stock')),
        ],
      ),
    );
    controller.dispose();
    if (amount != null && amount > 0 && med.id != null) {
      await _db.addRefill(med.id!, amount);
      if (mounted) _toast('Added $amount units to ${med.name}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final meds = _meds;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
          children: [
            const PageHeader(title: 'Your medicines', subtitle: 'Manage your medication details and reminders.'),
            const SizedBox(height: 22),
            if (meds == null)
              const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator()))
            else if (meds.isEmpty)
              const EmptyCard(
                title: 'Your medicine list is empty',
                subtitle: 'Tap “+” below to create your first reminder.',
                icon: Icons.medication_outlined,
              )
            else
              ...meds.map(_medCard),
          ],
        ),
      ),
    );
  }

  Widget _medCard(Medication m) {
    final stockColor = m.needsRefill ? AppColors.warning : AppColors.textMuted;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: m.isActive ? 1 : .6,
      child: AppCard(
        margin: const EdgeInsets.only(bottom: 12),
        onTap: () => _edit(m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconBadge(
                  icon: m.isActive ? Icons.medication_rounded : Icons.pause_circle_outline_rounded,
                  color: m.isActive ? AppColors.primary : AppColors.pending,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                      Text(m.doseLabel, style: const TextStyle(color: AppColors.textMuted)),
                    ],
                  ),
                ),
                if (!m.isActive) const StatusPill(label: 'Paused', color: AppColors.pending),
                PopupMenuButton<String>(
                  tooltip: 'Options for ${m.name}',
                  onSelected: (v) {
                    switch (v) {
                      case 'edit':
                        _edit(m);
                      case 'refill':
                        _refill(m);
                      case 'toggle':
                        _toggleActive(m);
                      case 'delete':
                        _delete(m);
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Edit'))),
                    const PopupMenuItem(
                        value: 'refill', child: ListTile(leading: Icon(Icons.add_box_outlined), title: Text('Add refill stock'))),
                    PopupMenuItem(
                      value: 'toggle',
                      child: ListTile(
                        leading: Icon(m.isActive ? Icons.pause_outlined : Icons.play_arrow_outlined),
                        title: Text(m.isActive ? 'Pause reminders' : 'Resume reminders'),
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(Icons.delete_outline, color: AppColors.missed),
                        title: Text('Delete', style: TextStyle(color: AppColors.missed)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: m.times
                  .map((t) => Chip(
                        avatar: const Icon(Icons.alarm_rounded, size: 16),
                        label: Text(formatTime(t)),
                        visualDensity: VisualDensity.compact,
                        side: BorderSide.none,
                        backgroundColor: AppColors.chip,
                      ))
                  .toList(),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.inventory_2_outlined, size: 16, color: stockColor),
                const SizedBox(width: 5),
                Text(
                  '${m.stockQuantity} units left',
                  style: TextStyle(
                    fontSize: 13,
                    color: stockColor,
                    fontWeight: m.needsRefill ? FontWeight.w700 : FontWeight.normal,
                  ),
                ),
                const Spacer(),
                if (m.needsRefill) const StatusPill(label: 'Refill soon', color: AppColors.warning),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.event_outlined, size: 16, color: AppColors.textMuted),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    m.endDate == null
                        ? 'From ${shortDate(m.startDate)} • ongoing'
                        : '${shortDate(m.startDate)} – ${shortDate(m.endDate!)}',
                    style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                  ),
                ),
              ],
            ),
            if (m.instructions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.textMuted),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(m.instructions, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
