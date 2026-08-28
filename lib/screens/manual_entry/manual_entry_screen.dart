import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/navigation/app_navigation.dart';
import '../../services/analysis_service.dart';
import '../../widgets/app_chip.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/buttons/app_buttons.dart';

class ManualEntryScreen extends StatefulWidget {
  const ManualEntryScreen({super.key});

  @override
  State<ManualEntryScreen> createState() => _ManualEntryScreenState();
}

class _ManualEntryScreenState extends State<ManualEntryScreen> {
  final _productNameCtrl = TextEditingController();
  final _plasticCodeCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  final _categories = ['Bottle', 'Container', 'Bag', 'Wrap', 'Tube', 'Other'];
  String? _selectedCategory;
  bool _isLoading = false;

  bool get _isValid =>
      _productNameCtrl.text.trim().isNotEmpty &&
      _plasticCodeCtrl.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _productNameCtrl.addListener(() => setState(() {}));
    _plasticCodeCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _productNameCtrl.dispose();
    _plasticCodeCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_isValid) return;
    setState(() => _isLoading = true);
    // TODO(engineer): connect to real AnalysisService when backend is ready
    final service = AnalysisService();
    final result = await service.analyzeManualEntry(
      productName: _productNameCtrl.text.trim(),
      plasticCode: _plasticCodeCtrl.text.trim().toUpperCase(),
      additionalNotes:
          _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    );
    if (mounted) {
      setState(() => _isLoading = false);
      context.push('/ai-analysis', extra: result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manual Entry'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => goBackOrHome(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Enter product details',
                    style: textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Provide as much information as possible for\na more accurate analysis.',
                    style: textTheme.bodyMedium
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 24),

                  // Product name
                  AppTextField(
                    label: 'Product Name *',
                    hint: 'e.g. Water Bottle, Food Container',
                    controller: _productNameCtrl,
                    textInputAction: TextInputAction.next,
                    prefixIcon: Icons.inventory_2_outlined,
                  ),
                  const SizedBox(height: 16),

                  // Plastic code
                  AppTextField(
                    label: 'Plastic Code / Type *',
                    hint: 'e.g. PET, HDPE, PVC, PP',
                    controller: _plasticCodeCtrl,
                    textInputAction: TextInputAction.next,
                    prefixIcon: Icons.science_outlined,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Found inside the recycling symbol on the product.',
                    style: textTheme.bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 24),

                  // Category chips
                  Text('Category', style: textTheme.titleSmall),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _categories.map((cat) {
                      return CategoryChip(
                        label: cat,
                        selected: _selectedCategory == cat,
                        onTap: () => setState(() => _selectedCategory =
                            _selectedCategory == cat ? null : cat),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // Notes
                  AppTextArea(
                    label: 'Additional Notes (optional)',
                    hint: 'Describe any markings, smells, or concerns…',
                    controller: _notesCtrl,
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),

          // ── Sticky bottom CTA ─────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            decoration: BoxDecoration(
              color: cs.surface,
              border: Border(
                top: BorderSide(color: cs.outlineVariant, width: 1),
              ),
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                child: PrimaryButton(
                  label: 'Analyse Product',
                  onPressed: _isValid ? _submit : null,
                  isLoading: _isLoading,
                  leadingIcon: Icons.biotech_rounded,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
