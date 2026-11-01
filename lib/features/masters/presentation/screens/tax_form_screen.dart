import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/polish_widgets.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../core/widgets/responsive_widgets.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/tax_model.dart';
import '../providers/tax_provider.dart';

class TaxFormScreen extends ConsumerStatefulWidget {
  final String? taxId;
  const TaxFormScreen({super.key, this.taxId});

  @override
  ConsumerState<TaxFormScreen> createState() => _TaxFormScreenState();
}

class _TaxFormScreenState extends ConsumerState<TaxFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _taxCategoryController = TextEditingController();
  final _shortNameController = TextEditingController();
  final _cgstRateController = TextEditingController(text: '0.0');
  final _sgstRateController = TextEditingController(text: '0.0');
  final _igstRateController = TextEditingController(text: '0.0');
  final _cessRateController = TextEditingController(text: '0.0');
  final _remarkOnInvoiceController = TextEditingController();
  final _salesAccountController = TextEditingController();
  final _salesAccountOmsController = TextEditingController();
  final _mouldAmortController = TextEditingController();
  final _cgstAccountController = TextEditingController();
  final _sgstAccountController = TextEditingController();
  final _igstAccountController = TextEditingController();

  bool _saving = false;
  bool _initialized = false;
  TaxModel? _existingTax;
  String? _errorMessage;

  @override
  void dispose() {
    _taxCategoryController.dispose();
    _shortNameController.dispose();
    _cgstRateController.dispose();
    _sgstRateController.dispose();
    _igstRateController.dispose();
    _cessRateController.dispose();
    _remarkOnInvoiceController.dispose();
    _salesAccountController.dispose();
    _salesAccountOmsController.dispose();
    _mouldAmortController.dispose();
    _cgstAccountController.dispose();
    _sgstAccountController.dispose();
    _igstAccountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isEdit = widget.taxId != null;
    final isMobile = ResponsiveLayout.isMobile(context);

    final authState = ref.watch(authProvider);
    final companyId = authState.user?.companyId ?? '';
    final role = authState.selectedRole ?? 'Employee';
    final canManage = role == 'Owner' || role == 'Accountant';

    if (!canManage) {
      return ResponsiveScaffold(
        appBar: AppBar(title: const Text('Access Denied')),
        body: const Center(
          child: Text('Access Denied. Only Owner or Accountant can manage Tax Master.'),
        ),
      );
    }

    if (isEdit && !_initialized) {
      final taxDetailsAsync = ref.watch(taxDetailsStreamProvider(widget.taxId!));
      return taxDetailsAsync.when(
        data: (tax) {
          if (tax == null) {
            return ResponsiveScaffold(
              appBar: AppBar(title: const Text('Tax Record Not Found')),
              body: const Center(child: Text('The requested Tax record could not be found.')),
            );
          }
          _existingTax = tax;
          _taxCategoryController.text = tax.taxCategory;
          _shortNameController.text = tax.shortName;
          _cgstRateController.text = tax.cgstRate.toString();
          _sgstRateController.text = tax.sgstRate.toString();
          _igstRateController.text = tax.igstRate.toString();
          _cessRateController.text = tax.cessRate.toString();
          _remarkOnInvoiceController.text = tax.remarkOnInvoice;
          _salesAccountController.text = tax.salesAccount ?? '';
          _salesAccountOmsController.text = tax.salesAccountOms ?? '';
          _mouldAmortController.text = tax.mouldAmortization ?? '';
          _cgstAccountController.text = tax.cgstAccount ?? '';
          _sgstAccountController.text = tax.sgstAccount ?? '';
          _igstAccountController.text = tax.igstAccount ?? '';
          _initialized = true;

          return _buildFormScaffold(context, theme, isDark, isEdit, isMobile, companyId);
        },
        loading: () => ResponsiveScaffold(
          appBar: AppBar(title: const Text('Loading Tax...')),
          body: const Center(child: CardListSkeleton()),
        ),
        error: (err, _) => ResponsiveScaffold(
          appBar: AppBar(title: const Text('Error')),
          body: Center(child: Text('Error loading tax: $err')),
        ),
      );
    }

    return _buildFormScaffold(context, theme, isDark, isEdit, isMobile, companyId);
  }

  Widget _buildFormScaffold(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    bool isEdit,
    bool isMobile,
    String companyId,
  ) {
    return ResponsiveScaffold(
      appBar: AppBar(
        title: Text(
          isEdit ? 'Edit Tax Master' : 'New Tax Master',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? AppSizes.p16 : AppSizes.p24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(AppSizes.p12),
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
                        border: Border.all(color: AppColors.error.withOpacity(0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSizes.p16),
                  ],

                  // Card 1: Tax Identity & Rates
                  ResponsiveCard(
                    padding: const EdgeInsets.all(AppSizes.p20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader(theme, 'Tax Category & Percentage Slabs', Icons.percent_rounded),
                        const SizedBox(height: AppSizes.p16),
                        ResponsiveFormRow(
                          children: [
                            TextFormField(
                              controller: _taxCategoryController,
                              decoration: InputDecoration(
                                labelText: 'Tax Category *',
                                hintText: 'e.g. GST 18%, GST 12%, Exempted',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSizes.inputRadius)),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Tax Category is required';
                                }
                                return null;
                              },
                            ),
                            TextFormField(
                              controller: _shortNameController,
                              textCapitalization: TextCapitalization.characters,
                              decoration: InputDecoration(
                                labelText: 'Short Name *',
                                hintText: 'e.g. GST18, GST12, EXMPT',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSizes.inputRadius)),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Short Name is required';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSizes.p16),
                        ResponsiveFormRow(
                          children: [
                            TextFormField(
                              controller: _cgstRateController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: 'C-GST % *',
                                suffixText: '%',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSizes.inputRadius)),
                              ),
                              validator: _validateTaxRate,
                              onChanged: (val) {
                                // Auto-fill IGST = CGST + SGST if desired
                                final cgst = double.tryParse(val.trim()) ?? 0.0;
                                final sgst = double.tryParse(_sgstRateController.text.trim()) ?? 0.0;
                                if (_igstRateController.text.isEmpty || _igstRateController.text == '0.0') {
                                  _igstRateController.text = (cgst + sgst).toString();
                                }
                              },
                            ),
                            TextFormField(
                              controller: _sgstRateController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: 'S-GST % *',
                                suffixText: '%',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSizes.inputRadius)),
                              ),
                              validator: _validateTaxRate,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSizes.p16),
                        ResponsiveFormRow(
                          children: [
                            TextFormField(
                              controller: _igstRateController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: 'I-GST % *',
                                suffixText: '%',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSizes.inputRadius)),
                              ),
                              validator: _validateTaxRate,
                            ),
                            TextFormField(
                              controller: _cessRateController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: 'Cess %',
                                suffixText: '%',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSizes.inputRadius)),
                              ),
                              validator: _validateTaxRate,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSizes.p16),
                        TextFormField(
                          controller: _remarkOnInvoiceController,
                          decoration: InputDecoration(
                            labelText: 'Remark on Invoice',
                            hintText: 'e.g. Tax payable under reverse charge, ITC eligible',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSizes.inputRadius)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSizes.p16),

                  // Card 2: Accounting & Ledger Mapping
                  ResponsiveCard(
                    padding: const EdgeInsets.all(AppSizes.p20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader(theme, 'Ledger & Accounting Maps', Icons.account_balance_wallet_outlined),
                        const SizedBox(height: AppSizes.p8),
                        Text(
                          'Configure accounting ledger codes for automated journal entries and invoicing.',
                          style: theme.textTheme.bodySmall?.copyWith(color: isDark ? Colors.white60 : Colors.grey.shade600),
                        ),
                        const SizedBox(height: AppSizes.p16),
                        ResponsiveFormRow(
                          children: [
                            TextFormField(
                              controller: _salesAccountController,
                              decoration: InputDecoration(
                                labelText: 'Sales A/C',
                                hintText: 'e.g. Local Sales 18%',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSizes.inputRadius)),
                              ),
                            ),
                            TextFormField(
                              controller: _salesAccountOmsController,
                              decoration: InputDecoration(
                                labelText: 'Sales A/C OMS',
                                hintText: 'e.g. Inter-State Sales 18%',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSizes.inputRadius)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSizes.p16),
                        TextFormField(
                          controller: _mouldAmortController,
                          decoration: InputDecoration(
                            labelText: 'Mould Amort.',
                            hintText: 'e.g. Mould Amortization A/C',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSizes.inputRadius)),
                          ),
                        ),
                        const SizedBox(height: AppSizes.p16),
                        ResponsiveFormRow(
                          children: [
                            TextFormField(
                              controller: _cgstAccountController,
                              decoration: InputDecoration(
                                labelText: 'C-GST A/C',
                                hintText: 'e.g. Output CGST 9%',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSizes.inputRadius)),
                              ),
                            ),
                            TextFormField(
                              controller: _sgstAccountController,
                              decoration: InputDecoration(
                                labelText: 'S-GST A/C',
                                hintText: 'e.g. Output SGST 9%',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSizes.inputRadius)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSizes.p16),
                        TextFormField(
                          controller: _igstAccountController,
                          decoration: InputDecoration(
                            labelText: 'I-GST A/C',
                            hintText: 'e.g. Output IGST 18%',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSizes.inputRadius)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSizes.p24),

                  // Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: _saving ? null : () => context.pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.buttonRadius)),
                        ),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: AppSizes.p16),
                      ElevatedButton.icon(
                        onPressed: _saving ? null : () => _submitForm(companyId, isEdit),
                        icon: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.check_rounded),
                        label: Text(isEdit ? 'Update Tax' : 'Save Tax'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.buttonRadius)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  String? _validateTaxRate(String? val) {
    if (val == null || val.trim().isEmpty) {
      return 'Percentage is required';
    }
    final num = double.tryParse(val.trim());
    if (num == null) {
      return 'Must be a valid decimal number';
    }
    if (num < 0) {
      return 'Cannot be negative';
    }
    if (num > 100) {
      return 'Percentage cannot exceed 100%';
    }
    return null;
  }

  Future<void> _submitForm(String companyId, bool isEdit) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    final repo = ref.read(taxRepositoryProvider);
    final category = _taxCategoryController.text.trim();
    final shortName = _shortNameController.text.trim();

    try {
      // Duplicate category check
      final isTaken = await repo.isTaxCategoryTaken(
        companyId,
        category,
        excludeTaxId: isEdit ? widget.taxId : null,
      );

      if (isTaken) {
        setState(() {
          _saving = false;
          _errorMessage = 'A tax category named "$category" already exists in this company.';
        });
        return;
      }

      final cgst = double.tryParse(_cgstRateController.text.trim()) ?? 0.0;
      final sgst = double.tryParse(_sgstRateController.text.trim()) ?? 0.0;
      final igst = double.tryParse(_igstRateController.text.trim()) ?? 0.0;
      final cess = double.tryParse(_cessRateController.text.trim()) ?? 0.0;

      if (isEdit && _existingTax != null) {
        final updated = _existingTax!.copyWith(
          taxCategory: category,
          shortName: shortName,
          cgstRate: cgst,
          sgstRate: sgst,
          igstRate: igst,
          cessRate: cess,
          remarkOnInvoice: _remarkOnInvoiceController.text.trim(),
          salesAccount: _salesAccountController.text.trim(),
          salesAccountOms: _salesAccountOmsController.text.trim(),
          mouldAmortization: _mouldAmortController.text.trim(),
          cgstAccount: _cgstAccountController.text.trim(),
          sgstAccount: _sgstAccountController.text.trim(),
          igstAccount: _igstAccountController.text.trim(),
        );
        await repo.updateTax(companyId, updated);
      } else {
        final newTax = TaxModel(
          taxId: '',
          companyId: companyId,
          taxCategory: category,
          shortName: shortName,
          cgstRate: cgst,
          sgstRate: sgst,
          igstRate: igst,
          cessRate: cess,
          remarkOnInvoice: _remarkOnInvoiceController.text.trim(),
          salesAccount: _salesAccountController.text.trim(),
          salesAccountOms: _salesAccountOmsController.text.trim(),
          mouldAmortization: _mouldAmortController.text.trim(),
          cgstAccount: _cgstAccountController.text.trim(),
          sgstAccount: _sgstAccountController.text.trim(),
          igstAccount: _igstAccountController.text.trim(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await repo.createTax(companyId, newTax);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEdit ? 'Tax record updated successfully' : 'Tax record created successfully'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      setState(() {
        _saving = false;
        _errorMessage = 'Error saving tax: $e';
      });
    }
  }
}
