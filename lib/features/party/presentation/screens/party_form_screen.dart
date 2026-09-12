import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/responsive_widgets.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/constants/state_codes.dart';
import '../../domain/models/party_model.dart';
import '../providers/party_provider.dart';

class PartyFormScreen extends ConsumerStatefulWidget {
  final String? partyId;
  const PartyFormScreen({super.key, this.partyId});

  @override
  ConsumerState<PartyFormScreen> createState() => _PartyFormScreenState();
}

class _PartyFormScreenState extends ConsumerState<PartyFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _partyNameController = TextEditingController();
  final _vendorCodeController = TextEditingController();
  final _addressController = TextEditingController();
  final _contactNumberController = TextEditingController();
  final _contactPersonNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _gstinController = TextEditingController();
  final _stateCodeController = TextEditingController();

  String _partyType = 'Customer';
  String? _selectedState;
  bool _saving = false;
  bool _initialized = false;

  @override
  void dispose() {
    _partyNameController.dispose();
    _vendorCodeController.dispose();
    _addressController.dispose();
    _contactNumberController.dispose();
    _contactPersonNameController.dispose();
    _emailController.dispose();
    _gstinController.dispose();
    _stateCodeController.dispose();
    super.dispose();
  }

  void _onStateSelected(String? stateName) {
    if (stateName != null) {
      setState(() {
        _selectedState = stateName;
        _stateCodeController.text = getStateCode(stateName);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEdit = widget.partyId != null;
    final authState = ref.watch(authProvider);
    final role = authState.selectedRole ?? 'Employee';
    final isOwner = role == 'Owner';

    // Safety check: Only Owner can access Party Master Management Form
    if (!isOwner) {
      return ResponsiveScaffold(
        appBar: AppBar(title: const Text('Access Denied')),
        body: const Center(
          child: Text('Access Denied. Only Owner can add or edit Party Master records.'),
        ),
      );
    }

    if (isEdit && !_initialized) {
      final partyDetailsAsync = ref.watch(partyDetailsStreamProvider(widget.partyId!));
      return partyDetailsAsync.when(
        data: (party) {
          if (party == null) {
            return ResponsiveScaffold(
              appBar: AppBar(title: const Text('Party Not Found')),
              body: const Center(child: Text('The requested Party record could not be found.')),
            );
          }
          _partyNameController.text = party.partyName;
          _partyType = party.partyType;
          _vendorCodeController.text = party.vendorCode;
          _addressController.text = party.address;
          _contactNumberController.text = party.contactNumber;
          _contactPersonNameController.text = party.contactPersonName;
          _emailController.text = party.email;
          _gstinController.text = party.gstin;
          _selectedState = party.state.isNotEmpty ? party.state : null;
          _stateCodeController.text = party.stateCode.isNotEmpty ? party.stateCode : (party.state.isNotEmpty ? getStateCode(party.state) : '');
          _initialized = true;

          return _buildFormScaffold(theme, isEdit);
        },
        loading: () => const ResponsiveScaffold(body: Center(child: CircularProgressIndicator())),
        error: (err, stack) => ResponsiveScaffold(
          body: Center(child: Text('Error loading Party record: $err', style: TextStyle(color: theme.colorScheme.error))),
        ),
      );
    }

    return _buildFormScaffold(theme, isEdit);
  }

  Widget _buildFormScaffold(ThemeData theme, bool isEdit) {
    final titlePrefix = isEdit ? 'Edit' : 'Add';
    final stateList = kIndianStateCodes.keys.toList()..sort();

    return ResponsiveScaffold(
      appBar: AppBar(
        title: Text('$titlePrefix Party Master Record'),
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
      ),
      body: _saving
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.p24),
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 750),
                    child: SingleChildScrollView(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Party Name & Party Type
                            ResponsiveFormRow(
                              children: [
                                TextFormField(
                                  controller: _partyNameController,
                                  decoration: InputDecoration(
                                    labelText: 'Party Name *',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                                    ),
                                  ),
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) {
                                      return 'Party Name is required';
                                    }
                                    return null;
                                  },
                                ),
                                DropdownButtonFormField<String>(
                                  value: _partyType,
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    labelText: 'Party Type *',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                                    ),
                                  ),
                                  items: const [
                                    DropdownMenuItem(value: 'Customer', child: Text('Customer', overflow: TextOverflow.ellipsis)),
                                    DropdownMenuItem(value: 'Supplier', child: Text('Supplier', overflow: TextOverflow.ellipsis)),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() => _partyType = val);
                                    }
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSizes.p16),

                            // Vendor Code & Contact Person Name
                            ResponsiveFormRow(
                              children: [
                                TextFormField(
                                  controller: _vendorCodeController,
                                  decoration: InputDecoration(
                                    labelText: 'Vendor Code (Optional)',
                                    hintText: 'e.g. VEN-001',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                                    ),
                                  ),
                                ),
                                TextFormField(
                                  controller: _contactPersonNameController,
                                  decoration: InputDecoration(
                                    labelText: 'Contact Person Name (Optional)',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSizes.p16),

                            // Contact Number & Email
                            ResponsiveFormRow(
                              children: [
                                TextFormField(
                                  controller: _contactNumberController,
                                  keyboardType: TextInputType.phone,
                                  decoration: InputDecoration(
                                    labelText: 'Contact Number *',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                                    ),
                                  ),
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) {
                                      return 'Contact Number is required';
                                    }
                                    return null;
                                  },
                                ),
                                TextFormField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: InputDecoration(
                                    labelText: 'Email (Optional)',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSizes.p16),

                            // GSTIN & State
                            ResponsiveFormRow(
                              children: [
                                TextFormField(
                                  controller: _gstinController,
                                  textCapitalization: TextCapitalization.characters,
                                  decoration: InputDecoration(
                                    labelText: 'GSTIN (Optional)',
                                    hintText: 'e.g. 27AAAAA0000A1Z5',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                                    ),
                                  ),
                                ),
                                DropdownButtonFormField<String>(
                                  value: _selectedState,
                                  isExpanded: true,
                                  hint: const Text('Select State', overflow: TextOverflow.ellipsis),
                                  decoration: InputDecoration(
                                    labelText: 'State *',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                                    ),
                                  ),
                                  items: stateList.map((state) {
                                    return DropdownMenuItem(
                                      value: state,
                                      child: Text(state, overflow: TextOverflow.ellipsis),
                                    );
                                  }).toList(),
                                  onChanged: _onStateSelected,
                                  validator: (val) {
                                    if (val == null || val.isEmpty) {
                                      return 'State selection is required';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSizes.p16),

                            // State Code (Auto-filled) & Address
                            ResponsiveFormRow(
                              children: [
                                TextFormField(
                                  controller: _stateCodeController,
                                  enabled: false,
                                  decoration: InputDecoration(
                                    labelText: 'State Code (Auto-mapped)',
                                    hintText: 'Auto-filled',
                                    filled: true,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                                    ),
                                  ),
                                ),
                                TextFormField(
                                  controller: _addressController,
                                  decoration: InputDecoration(
                                    labelText: 'Address (Optional)',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSizes.p32),

                            // Save Button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _submitForm,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.colorScheme.primary,
                                  padding: const EdgeInsets.symmetric(vertical: AppSizes.p16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
                                  ),
                                ),
                                child: Text(
                                  isEdit ? 'Update Party Master' : 'Save Party Master',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    final authState = ref.read(authProvider);
    final companyId = authState.user?.companyId;
    if (companyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: No company workspace detected.')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final partyRepo = ref.read(partyRepositoryProvider);
      final stateName = _selectedState ?? '';
      final stateCode = getStateCode(stateName);

      if (widget.partyId != null) {
        // Edit Mode
        final existingPartyAsync = ref.read(partyDetailsStreamProvider(widget.partyId!));
        final existingParty = existingPartyAsync.value;
        if (existingParty != null) {
          final updatedParty = existingParty.copyWith(
            partyName: _partyNameController.text.trim(),
            partyType: _partyType,
            vendorCode: _vendorCodeController.text.trim(),
            address: _addressController.text.trim(),
            contactNumber: _contactNumberController.text.trim(),
            contactPersonName: _contactPersonNameController.text.trim(),
            email: _emailController.text.trim(),
            gstin: _gstinController.text.trim(),
            state: stateName,
            stateCode: stateCode,
            updatedAt: DateTime.now(),
          );
          await partyRepo.updateParty(companyId, updatedParty);
        }
      } else {
        // Create Mode
        final newPartyId = FirebaseFirestore.instance.collection('companies').doc(companyId).collection('parties').doc().id;
        final newParty = PartyModel(
          partyId: newPartyId,
          companyId: companyId,
          partyName: _partyNameController.text.trim(),
          partyType: _partyType,
          vendorCode: _vendorCodeController.text.trim(),
          address: _addressController.text.trim(),
          contactNumber: _contactNumberController.text.trim(),
          contactPersonName: _contactPersonNameController.text.trim(),
          email: _emailController.text.trim(),
          gstin: _gstinController.text.trim(),
          state: stateName,
          stateCode: stateCode,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await partyRepo.createParty(companyId, newParty);
      }

      if (mounted) {
        final message = widget.partyId != null ? 'Party updated successfully.' : 'Party created successfully.';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving Party: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
