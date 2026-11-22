import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/medication.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/common.dart';
import '../widgets/notifications_sheet.dart';
import 'medication_form.dart';

class MedicationsScreen extends StatefulWidget {
  const MedicationsScreen({super.key});

  @override
  State<MedicationsScreen> createState() => _MedicationsScreenState();
}

class _MedicationsScreenState extends State<MedicationsScreen> {
  final _db = DatabaseService.instance;
  List<Medication>? _meds;
  String _selectedFilter = 'All'; // All, Active, Low Stock, Paused

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
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.primary,
        ),
      );
  }

  Future<void> _edit(Medication med) async {
    final updated = await showMedicationForm(context, medication: med);
    if (updated != null && mounted) _toast('${updated.name} updated');
  }

  Future<void> _addNew() async {
    final saved = await showMedicationForm(context);
    if (saved != null && mounted) _toast('${saved.name} added to cabinet');
  }

  Future<void> _seedSampleMedications() async {
    final today = dateKey(DateTime.now());
    final samples = [
      Medication(
        name: 'Amoxicillin 500mg',
        dosage: '1',
        dosageUnit: 'capsule(s)',
        instructions: 'Take after breakfast & dinner',
        startDate: today,
        stockQuantity: 14,
        refillThreshold: 5,
        times: ['08:00', '20:00'],
      ),
      Medication(
        name: 'Vitamin D3 + K2',
        dosage: '1',
        dosageUnit: 'tablet(s)',
        instructions: 'Take with morning meal',
        startDate: today,
        stockQuantity: 45,
        refillThreshold: 10,
        times: ['09:00'],
      ),
      Medication(
        name: 'Losartan Potassium 50mg',
        dosage: '1',
        dosageUnit: 'tablet(s)',
        instructions: 'Evening blood pressure maintenance',
        startDate: today,
        stockQuantity: 4,
        refillThreshold: 5,
        times: ['19:00'],
      ),
    ];
    for (final m in samples) {
      final saved = await _db.saveMedication(m);
      await NotificationService.instance.scheduleMedication(saved);
    }
    if (mounted) _toast('Loaded 3 sample medications with active alarms');
  }

  Future<void> _toggleActive(Medication med) async {
    if (med.id == null) return;
    final active = !med.isActive;
    await _db.setActive(med.id!, active);
    await NotificationService.instance.scheduleMedication(med.copyWith(isActive: active));
    if (mounted) {
      _toast(active
          ? 'Reminders resumed for ${med.name}'
          : 'Reminders paused for ${med.name}');
    }
  }

  Future<void> _delete(Medication med) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        icon: const Icon(Icons.delete_outline_rounded, color: AppColors.missed),
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
        icon: const Icon(Icons.inventory_2_outlined, color: AppColors.primary),
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
          FilledButton(
            onPressed: () => Navigator.pop(c, int.tryParse(controller.text)),
            child: const Text('Add stock'),
          ),
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
    final allMeds = meds ?? [];
    final activeCount = allMeds.where((m) => m.isActive).length;
    final totalStock = allMeds.fold<int>(0, (sum, m) => sum + m.stockQuantity);
    final lowStockCount = allMeds.where((m) => m.isActive && m.needsRefill).length;

    final filtered = allMeds.where((m) {
      if (_selectedFilter == 'Active') return m.isActive;
      if (_selectedFilter == 'Low Stock') return m.needsRefill;
      if (_selectedFilter == 'Paused') return !m.isActive;
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 115),
          children: [
            // Top Bar matching Tarsi Wallet / Cabinet tab
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MEDICINE CABINET',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Your Prescriptions',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: AppColors.text,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => NotificationsSheet.show(context),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: AppColors.borderLight),
                  ),
                  icon: const Icon(Icons.notifications_none_rounded, color: AppColors.primary),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _addNew,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Scenic 3D Bird Cabinet Overview Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFE5F3EA),
                    Color(0xFFCBE6D4),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFB8DEC5)),
              ),
              child: Row(
                children: [
                  // 3D Bird Mascot Avatar
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.asset(
                        'assets/images/mascot_3d_bird.png',
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Image.asset(
                          'assets/images/app_logo.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$totalStock Units in Stock',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                            color: AppColors.text,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '$activeCount active medicines • ${lowStockCount == 0 ? 'All well stocked' : '$lowStockCount need refill'}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF2D533E),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Filter Pills
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: ['All', 'Active', 'Low Stock', 'Paused'].map((f) {
                  final active = _selectedFilter == f;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedFilter = f),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                        decoration: BoxDecoration(
                          color: active ? AppColors.primary : Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: active ? AppColors.primary : AppColors.borderLight,
                          ),
                        ),
                        child: Text(
                          f,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: active ? Colors.white : AppColors.textMuted,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 16),

            if (meds == null)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(30),
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              )
            else if (meds.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Column(
                  children: [
                    SizedBox(
                      width: 96,
                      height: 96,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Image.asset(
                          'assets/images/mascot_3d_bird.png',
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Image.asset('assets/images/app_logo.png'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Your medicine cabinet is empty',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Add your first daily prescription or load a sample routine to explore stock tracking & exact alarms.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _addNew,
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('Add Medicine'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _seedSampleMedications,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(color: AppColors.primary),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            icon: const Icon(Icons.auto_awesome_rounded, size: 17),
                            label: const Text(
                              'Load Samples',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )
            else if (filtered.isEmpty)
              EmptyCard(
                title: 'No medicines in "$_selectedFilter"',
                subtitle: 'Switch filters above to see your other prescriptions.',
                icon: Icons.filter_alt_off_rounded,
              )
            else
              ...filtered.map(_medCard),
          ],
        ),
      ),
    );
  }

  Widget _medCard(Medication m) {
    final isLow = m.needsRefill;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: m.isActive ? 1 : .65,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isLow
                ? AppColors.overdueText.withValues(alpha: 0.35)
                : AppColors.borderLight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.025),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: InkWell(
          onTap: () => _edit(m),
          borderRadius: BorderRadius.circular(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Tarsi-style left date/icon squircle
                  Container(
                    width: 48,
                    height: 50,
                    decoration: BoxDecoration(
                      color: isLow ? AppColors.overdueBg : AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      m.isActive ? Icons.medication_rounded : Icons.pause_circle_outline_rounded,
                      color: isLow ? AppColors.overdueText : AppColors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: !m.isActive
                                    ? const Color(0xFFF1F4F2)
                                    : (isLow ? AppColors.overdueBg : AppColors.mintBg),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                !m.isActive
                                    ? 'Paused'
                                    : (isLow ? 'Refill soon' : 'Active'),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: !m.isActive
                                      ? AppColors.textMuted
                                      : (isLow ? AppColors.overdueText : AppColors.mintColor),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              m.doseLabel,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          m.name,
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: AppColors.text,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Right Column: Stock Quantity + LEFT
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${m.stockQuantity} left',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w900,
                          color: isLow ? AppColors.overdueText : AppColors.text,
                        ),
                      ),
                      Text(
                        'STOCK',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
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
                      const PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          leading: Icon(Icons.edit_outlined),
                          title: Text('Edit'),
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'refill',
                        child: ListTile(
                          leading: Icon(Icons.add_box_outlined, color: AppColors.primary),
                          title: Text('Add refill stock'),
                        ),
                      ),
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
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: m.times
                          .map(
                            (t) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceSubtle,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.alarm_rounded, size: 13, color: AppColors.primary),
                                  const SizedBox(width: 4),
                                  Text(
                                    formatTime(t),
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.text,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _refill(m),
                    style: TextButton.styleFrom(
                      backgroundColor: AppColors.primaryContainer,
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 15),
                    label: const Text(
                      'Restock',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
