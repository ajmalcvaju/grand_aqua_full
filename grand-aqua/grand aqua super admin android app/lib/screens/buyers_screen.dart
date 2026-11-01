import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import '../core/auth_provider.dart';
import '../widgets/admin_drawer.dart';

class BuyersScreen extends ConsumerStatefulWidget {
  const BuyersScreen({super.key});

  @override
  ConsumerState<BuyersScreen> createState() => _BuyersScreenState();
}

class _BuyersScreenState extends ConsumerState<BuyersScreen> {
  List<dynamic> _buyers = [];
  List<dynamic> _salesmen = [];
  bool _isLoading = true;
  String _selectedCategory = 'ALL';
  String _searchQuery = '';

  final _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _fetchBuyers();
    _fetchSalesmen();
  }

  Future<void> _fetchSalesmen() async {
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.dio.get('/salesmen');
      final data = res.data['data'] ?? res.data;
      if (mounted) {
        setState(() {
          _salesmen = (data is List) ? data : (data['salesmen'] ?? []);
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchBuyers() async {
    setState(() => _isLoading = true);
    try {
      final api = ref.read(apiClientProvider);
      String url = '/buyers?limit=200';
      if (_selectedCategory != 'ALL') {
        url += '&buyerType=$_selectedCategory';
      }
      final res = await api.dio.get(url);
      final data = res.data['data'] ?? res.data;
      if (mounted) {
        setState(() {
          _buyers = data['buyers'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load buyers: $e')),
        );
      }
    }
  }

  // 1. Create or Edit Buyer Dialog (CRUD with Owner & Shop Image Upload)
  void _showBuyerFormDialog({Map<String, dynamic>? buyer}) {
    final isEditing = buyer != null;
    final fullNameCtrl = TextEditingController(text: buyer?['user']?['fullName'] ?? '');
    final usernameCtrl = TextEditingController(text: buyer?['user']?['username'] ?? '');
    final phoneCtrl = TextEditingController(text: buyer?['user']?['phone'] ?? buyer?['user']?['mobileNumber'] ?? '');
    final emailCtrl = TextEditingController(text: buyer?['user']?['email'] ?? '');
    final passwordCtrl = TextEditingController();
    final businessNameCtrl = TextEditingController(text: buyer?['businessName'] ?? '');
    final businessTypeCtrl = TextEditingController(text: buyer?['businessType'] ?? 'Retail Shop / Hardware');
    final gstinCtrl = TextEditingController(text: buyer?['gstin'] ?? '');
    final billingAddressCtrl = TextEditingController(text: buyer?['billingAddress'] ?? '');
    final districtCtrl = TextEditingController(text: buyer?['district'] ?? '');
    final stateCtrl = TextEditingController(text: buyer?['state'] ?? 'Kerala');
    final pinCodeCtrl = TextEditingController(text: buyer?['pinCode'] ?? '');
    final creditLimitCtrl = TextEditingController(text: (buyer?['creditLimit'] ?? 0).toString());
    final creditDaysCtrl = TextEditingController(text: (buyer?['creditDays'] ?? buyer?['paymentTermsDays'] ?? 30).toString());

    final ownerPhotoCtrl = TextEditingController(text: buyer?['ownerPhoto'] ?? buyer?['user']?['profilePhoto'] ?? '');
    final shopPhotoCtrl = TextEditingController(text: buyer?['shopPhoto'] ?? '');

    String selectedBuyerType = buyer?['buyerType'] ?? 'DEALER';
    String selectedLoyaltyTier = buyer?['loyaltyTier'] ?? 'NONE';
    String? selectedSalesmanId = buyer?['assignedSalesmanId'] ?? buyer?['assignedSalesman']?['id'];

    bool isUploadingOwner = false;
    bool isUploadingShop = false;

    Future<void> pickAndUploadImage(String field, StateSetter setDialogState) async {
      final result = await FilePicker.pickFiles(type: FileType.image);
      if (result.isNotEmpty) {
        final picked = result.first;
        setDialogState(() {
          if (field == 'owner') isUploadingOwner = true;
          if (field == 'shop') isUploadingShop = true;
        });

        try {
          final api = ref.read(apiClientProvider);
          MultipartFile multipartFile;
          if (picked.path != null) {
            multipartFile = await MultipartFile.fromFile(picked.path!, filename: picked.name);
          } else {
            final bytes = await picked.readAsBytes();
            multipartFile = MultipartFile.fromBytes(bytes, filename: picked.name);
          }

          final formData = FormData.fromMap({'file': multipartFile});
          final res = await api.dio.post('/upload', data: formData);
          final data = res.data['data'] ?? res.data;
          final uploadedUrl = (data['url'] ?? data['relativePath'] ?? '').toString();

          setDialogState(() {
            if (field == 'owner') ownerPhotoCtrl.text = uploadedUrl;
            if (field == 'shop') shopPhotoCtrl.text = uploadedUrl;
          });
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Upload failed: $e')),
            );
          }
        } finally {
          setDialogState(() {
            if (field == 'owner') isUploadingOwner = false;
            if (field == 'shop') isUploadingShop = false;
          });
        }
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(
                isEditing ? Icons.edit_note : Icons.person_add_alt_1,
                color: const Color(0xFF0284C7),
              ),
              const SizedBox(width: 8),
              Text(
                isEditing ? 'Edit Buyer Profile' : 'Add New Trade Buyer',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // DUAL IMAGE UPLOAD (OWNER & SHOP)
                  const Text(
                    'SHOP & OWNER PHOTOGRAPHS',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                  ),
                  const SizedBox(height: 8),

                  // Owner Image Upload Tile
                  _buildImageUploadCard(
                    title: 'Owner Photograph',
                    icon: Icons.camera_alt_outlined,
                    url: ownerPhotoCtrl.text,
                    isUploading: isUploadingOwner,
                    onPick: () => pickAndUploadImage('owner', setDialogState),
                    onClear: () => setDialogState(() => ownerPhotoCtrl.clear()),
                  ),
                  const SizedBox(height: 10),

                  // Shop Image Upload Tile
                  _buildImageUploadCard(
                    title: 'Shop / Storefront Photograph',
                    icon: Icons.storefront_outlined,
                    url: shopPhotoCtrl.text,
                    isUploading: isUploadingShop,
                    onPick: () => pickAndUploadImage('shop', setDialogState),
                    onClear: () => setDialogState(() => shopPhotoCtrl.clear()),
                  ),

                  const SizedBox(height: 16),
                  const Text(
                    'CONTACT & LOGIN CREDENTIALS',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),

                  TextField(
                    controller: fullNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Contact Person / Owner Name *',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),

                  TextField(
                    controller: usernameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Username (Admin Managed)',
                      helperText: 'Only Super Admin can set or edit',
                      prefixIcon: Icon(Icons.alternate_email, size: 16),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),

                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Mobile (Login & OTP) *',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),

                  TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email Address',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),

                  const SizedBox(height: 10),
                  TextField(
                    controller: passwordCtrl,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: isEditing
                          ? 'Set / Reset Password (leave blank to keep current)'
                          : 'Initial Password (default: GrandAqua@Buyer2026)',
                      helperText: isEditing
                          ? 'Enter new password to reset, or leave empty'
                          : 'Super Admin decides initial password',
                      prefixIcon: const Icon(Icons.lock_outline, size: 18),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),

                  const SizedBox(height: 16),
                  const Text(
                    'BUSINESS & TRADE DETAILS',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),

                  TextField(
                    controller: businessNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Business / Shop Name *',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),

                  TextField(
                    controller: businessTypeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Business Type',
                      hintText: 'e.g. Retailer, Hardware, Plumber',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),

                  TextField(
                    controller: gstinCtrl,
                    decoration: const InputDecoration(
                      labelText: 'GSTIN',
                      hintText: 'e.g. 32AAAAA0000A1Z5',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),

                  const SizedBox(height: 16),
                  const Text(
                    'CATEGORY & LOYALTY TIER',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                  ),
                  const SizedBox(height: 8),

                  DropdownButtonFormField<String>(
                    value: selectedBuyerType,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Buyer Category (Pricing Tier) *',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'CUSTOMER', child: Text('CUSTOMER (Retail Price)', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 'DEALER', child: Text('DEALER (Shop / Retailer Discount)', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 'WHOLESALER', child: Text('WHOLESALER (Bulk Rate)', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 'DISTRIBUTOR', child: Text('DISTRIBUTOR (Stockist Rate)', overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedBuyerType = val);
                    },
                  ),
                  const SizedBox(height: 10),

                  DropdownButtonFormField<String>(
                    value: selectedLoyaltyTier,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Loyalty Tier *',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'NONE', child: Text('Standard Tier (None)', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 'GOLD', child: Text('🥇 GOLD TIER', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 'DIAMOND', child: Text('💎 DIAMOND TIER', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 'PLATINUM', child: Text('🏆 PLATINUM TIER', overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedLoyaltyTier = val);
                    },
                  ),

                  const SizedBox(height: 16),
                  const Text(
                    'CREDIT FACILITY & DUE TERMS',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.teal),
                  ),
                  const SizedBox(height: 8),

                  TextField(
                    controller: creditLimitCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Credit Limit (₹)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),

                  TextField(
                    controller: creditDaysCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Credit Due Terms (Days)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),

                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: selectedSalesmanId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Assigned Salesman',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    hint: const Text('Select Salesman (Optional)', overflow: TextOverflow.ellipsis),
                    items: [
                      const DropdownMenuItem<String>(
                        value: '',
                        child: Text('Unassigned (None)', overflow: TextOverflow.ellipsis),
                      ),
                      ..._salesmen.map<DropdownMenuItem<String>>((s) {
                        final sName = s['user']?['fullName'] ?? 'Salesman';
                        final sCode = s['employeeCode'] ?? '';
                        return DropdownMenuItem<String>(
                          value: s['id']?.toString() ?? '',
                          child: Text('$sName ($sCode)', overflow: TextOverflow.ellipsis),
                        );
                      }),
                    ],
                    onChanged: (val) {
                      setDialogState(() => selectedSalesmanId = val);
                    },
                  ),

                  const SizedBox(height: 16),
                  const Text(
                    'ADDRESS & LOCATION',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),

                  TextField(
                    controller: billingAddressCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Shop / Billing Address',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),

                  TextField(
                    controller: districtCtrl,
                    decoration: const InputDecoration(
                      labelText: 'District / City',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),

                  TextField(
                    controller: stateCtrl,
                    decoration: const InputDecoration(
                      labelText: 'State',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),

                  TextField(
                    controller: pinCodeCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'PIN Code',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0284C7)),
              onPressed: () async {
                if (fullNameCtrl.text.trim().isEmpty || phoneCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Contact name and mobile number are required')),
                  );
                  return;
                }

                try {
                  final api = ref.read(apiClientProvider);
                  final payload = {
                    'fullName': fullNameCtrl.text.trim(),
                    'username': usernameCtrl.text.trim().toLowerCase().isNotEmpty ? usernameCtrl.text.trim().toLowerCase() : null,
                    'phone': phoneCtrl.text.trim(),
                    'email': emailCtrl.text.trim().isNotEmpty ? emailCtrl.text.trim() : null,
                    'password': passwordCtrl.text.trim().isNotEmpty ? passwordCtrl.text.trim() : null,
                    'businessName': businessNameCtrl.text.trim().isNotEmpty ? businessNameCtrl.text.trim() : fullNameCtrl.text.trim(),
                    'businessType': businessTypeCtrl.text.trim(),
                    'gstin': gstinCtrl.text.trim().isNotEmpty ? gstinCtrl.text.trim() : null,
                    'billingAddress': billingAddressCtrl.text.trim(),
                    'district': districtCtrl.text.trim(),
                    'state': stateCtrl.text.trim(),
                    'pinCode': pinCodeCtrl.text.trim(),
                    'buyerType': selectedBuyerType,
                    'loyaltyTier': selectedLoyaltyTier,
                    'creditLimit': double.tryParse(creditLimitCtrl.text) ?? 0,
                    'creditDays': int.tryParse(creditDaysCtrl.text) ?? 30,
                    'ownerPhoto': ownerPhotoCtrl.text.isNotEmpty ? ownerPhotoCtrl.text : null,
                    'shopPhoto': shopPhotoCtrl.text.isNotEmpty ? shopPhotoCtrl.text : null,
                    'assignedSalesmanId': (selectedSalesmanId != null && selectedSalesmanId!.isNotEmpty) ? selectedSalesmanId : null,
                  };

                  if (isEditing) {
                    await api.dio.put('/buyers/${buyer['id']}', data: payload);
                  } else {
                    await api.dio.post('/buyers', data: payload);
                  }

                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isEditing ? 'Buyer updated successfully!' : 'Buyer registered successfully!'),
                        backgroundColor: const Color(0xFF10B981),
                      ),
                    );
                    _fetchBuyers();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error saving buyer: $e')),
                    );
                  }
                }
              },
              child: Text(isEditing ? 'Update Buyer' : 'Create Buyer'),
            ),
          ],
        ),
      ),
    );
  }

  // Helper widget for media upload card with live preview
  Widget _buildImageUploadCard({
    required String title,
    required IconData icon,
    required String url,
    required bool isUploading,
    required VoidCallback onPick,
    required VoidCallback onClear,
  }) {
    final hasFile = url.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: hasFile ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasFile ? const Color(0xFF86EFAC) : Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: hasFile ? const Color(0xFF16A34A) : const Color(0xFF0284C7)),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (hasFile)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, size: 12, color: Colors.green),
                      SizedBox(width: 3),
                      Text('Uploaded', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          if (isUploading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 10),
                  Text('Uploading picture...', style: TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            )
          else if (hasFile)
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    url,
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 30, color: Colors.grey),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    url.split('/').last,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF334155)),
                  ),
                ),
                TextButton(
                  onPressed: onPick,
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                  child: const Text('Change', style: TextStyle(fontSize: 11)),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 16, color: Colors.red),
                  visualDensity: VisualDensity.compact,
                  onPressed: onClear,
                  tooltip: 'Remove',
                ),
              ],
            )
          else
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onPick,
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                icon: const Icon(Icons.cloud_upload_outlined, size: 16),
                label: Text('Choose / Take $title', style: const TextStyle(fontSize: 11)),
              ),
            ),
        ],
      ),
    );
  }

  // 2. Loyalty Tier Changer Dialog (Make Gold, Diamond, Platinum)
  void _showLoyaltyTierDialog(Map<String, dynamic> buyer) {
    String currentTier = buyer['loyaltyTier'] ?? 'NONE';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Assign Loyalty Tier', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(
              buyer['businessName'] ?? buyer['user']?['fullName'] ?? 'Buyer',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTierOptionTile(
              title: '🥇 GOLD TIER',
              description: 'Gold level benefits, priority dispatch & trade rebates.',
              color: const Color(0xFFD97706),
              bgColor: const Color(0xFFFEF3C7),
              isSelected: currentTier == 'GOLD',
              onTap: () => _updateBuyerTier(buyer['id'], 'GOLD', ctx),
            ),
            const SizedBox(height: 8),
            _buildTierOptionTile(
              title: '💎 DIAMOND TIER',
              description: 'Maximum credit eligibility & exclusive volume discounts.',
              color: const Color(0xFF0284C7),
              bgColor: const Color(0xFFE0F2FE),
              isSelected: currentTier == 'DIAMOND',
              onTap: () => _updateBuyerTier(buyer['id'], 'DIAMOND', ctx),
            ),
            const SizedBox(height: 8),
            _buildTierOptionTile(
              title: '🏆 PLATINUM TIER',
              description: 'Executive VIP partner with custom pricing & support.',
              color: const Color(0xFF7C3AED),
              bgColor: const Color(0xFFF3E8FF),
              isSelected: currentTier == 'PLATINUM',
              onTap: () => _updateBuyerTier(buyer['id'], 'PLATINUM', ctx),
            ),
            const SizedBox(height: 8),
            _buildTierOptionTile(
              title: '⚪ STANDARD TIER',
              description: 'Default membership with standard catalogue access.',
              color: const Color(0xFF475569),
              bgColor: const Color(0xFFF1F5F9),
              isSelected: currentTier == 'NONE',
              onTap: () => _updateBuyerTier(buyer['id'], 'NONE', ctx),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildTierOptionTile({
    required String title,
    required String description,
    required Color color,
    required Color bgColor,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
            if (isSelected) Icon(Icons.check_circle, color: color, size: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _updateBuyerTier(String buyerId, String newTier, BuildContext dialogCtx) async {
    Navigator.pop(dialogCtx);
    try {
      final api = ref.read(apiClientProvider);
      await api.dio.put('/buyers/$buyerId/loyalty-tier', data: {
        'newTier': newTier,
        'reason': 'Loyalty tier updated via Super Admin Mobile App',
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Buyer loyalty tier set to $newTier!'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
        _fetchBuyers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update loyalty tier: $e')),
        );
      }
    }
  }

  // 3. Delete Buyer Confirmation Dialog
  void _showDeleteConfirmDialog(String id, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Buyer Profile?'),
        content: Text(
          'Are you sure you want to permanently delete "$name"? All trade profile, credit, and linked addresses will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              try {
                final api = ref.read(apiClientProvider);
                await api.dio.delete('/buyers/$id');
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Buyer deleted successfully!'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  _fetchBuyers();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete buyer: $e')),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // 4. Complete Buyer History & Profile Bottom Sheet (Purchases, Products, Payments & Dues)
  void _showBuyerDetailSheet(Map<String, dynamic> buyer) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _BuyerDetailSheet(
        buyerId: buyer['id'],
        initialBuyer: buyer,
        onTierChanged: _fetchBuyers,
      ),
    );
  }

  // 5. Promote / Change Category Dialog
  void _showPromoteDialog(Map<String, dynamic> buyer) {
    String newType = buyer['buyerType'] ?? 'DEALER';
    final reasonCtrl = TextEditingController(text: 'Tier upgraded by Super Admin');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Change Category\n${buyer['businessName'] ?? buyer['user']?['fullName']}',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Target Category & Pricing Tier:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: newType,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 'CUSTOMER', child: Text('Customer (Retail)')),
                  DropdownMenuItem(value: 'DEALER', child: Text('Dealer (Shop / Retailer)')),
                  DropdownMenuItem(value: 'WHOLESALER', child: Text('Wholesaler (Bulk Buyer)')),
                  DropdownMenuItem(value: 'DISTRIBUTOR', child: Text('Distributor (Regional Stockist)')),
                ],
                onChanged: (val) {
                  if (val != null) setDialogState(() => newType = val);
                },
                decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                decoration: const InputDecoration(
                  labelText: 'Authorization Reason *',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0284C7)),
              onPressed: () async {
                try {
                  final api = ref.read(apiClientProvider);
                  await api.dio.put('/buyers/${buyer['id']}/promote-type', data: {
                    'newType': newType,
                    'reason': reasonCtrl.text.trim().isNotEmpty ? reasonCtrl.text.trim() : 'Mobile promotion',
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Buyer category updated successfully!'),
                        backgroundColor: Color(0xFF10B981),
                      ),
                    );
                    _fetchBuyers();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error updating category: $e')),
                    );
                  }
                }
              },
              child: const Text('Confirm'),
            ),
          ],
        ),
      ),
    );
  }

  // 6. Assign / Reassign Salesman Dialog
  void _showAssignSalesmanDialog(Map<String, dynamic> buyer) {
    String? currentSalesmanId = buyer['assignedSalesmanId'] ?? buyer['assignedSalesman']?['id'];
    String? selectedSalesmanId = currentSalesmanId;
    final reasonCtrl = TextEditingController(text: 'Territory assignment');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Assign Salesman\n${buyer['businessName'] ?? buyer['user']?['fullName']}',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Assigned Sales Representative:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: selectedSalesmanId,
                isExpanded: true,
                hint: const Text('Select Salesman'),
                items: [
                  const DropdownMenuItem<String>(
                    value: '',
                    child: Text('Unassigned (None)'),
                  ),
                  ..._salesmen.map<DropdownMenuItem<String>>((s) {
                    final sName = s['user']?['fullName'] ?? 'Salesman';
                    final sCode = s['employeeCode'] ?? '';
                    final sTerritory = s['territory'] ?? '';
                    return DropdownMenuItem<String>(
                      value: s['id']?.toString() ?? '',
                      child: Text(
                        '$sName ($sCode) - $sTerritory',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13),
                      ),
                    );
                  }),
                ],
                onChanged: (val) {
                  setDialogState(() => selectedSalesmanId = val);
                },
                decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                decoration: const InputDecoration(
                  labelText: 'Assignment Reason / Territory Note',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0284C7)),
              onPressed: () async {
                try {
                  final api = ref.read(apiClientProvider);
                  final bId = buyer['id'];
                  if (selectedSalesmanId == null || selectedSalesmanId!.isEmpty) {
                    if (currentSalesmanId != null && currentSalesmanId.isNotEmpty) {
                      await api.dio.delete('/salesmen/$currentSalesmanId/unassign-buyer/$bId');
                    }
                  } else {
                    await api.dio.put('/buyers/$bId/assign-salesman', data: {
                      'salesmanProfileId': selectedSalesmanId,
                      'reason': reasonCtrl.text.trim(),
                    });
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Salesman assigned successfully!'),
                        backgroundColor: Color(0xFF10B981),
                      ),
                    );
                    _fetchBuyers();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error assigning salesman: $e')),
                    );
                  }
                }
              },
              child: const Text('Assign'),
            ),
          ],
        ),
      ),
    );
  }

  // 7. Toggle Block / Unblock Buyer Account
  Future<void> _toggleBlockBuyer(Map<String, dynamic> buyer) async {
    final bId = buyer['id'];
    final user = buyer['user'];
    final isBlocked = (user?['accountStatus'] == 'BLOCKED') || (buyer['accountStatus'] == 'BLOCKED');
    final actionName = isBlocked ? 'Unblock' : 'Block';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$actionName Buyer Account'),
        content: Text(
          isBlocked
              ? 'Unblock ${buyer['businessName'] ?? user?['fullName']}? They will be able to log in, browse prices, and place orders.'
              : 'Block ${buyer['businessName'] ?? user?['fullName']}? Their login and ordering access will be frozen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: isBlocked ? const Color(0xFF10B981) : const Color(0xFFEF4444),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(actionName),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final api = ref.read(apiClientProvider);
      await api.dio.put('/buyers/$bId/status', data: {
        'status': isBlocked ? 'ACTIVE' : 'BLOCKED',
        'reason': 'Status toggled via Super Admin Mobile App',
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isBlocked ? 'Buyer unblocked successfully' : 'Buyer blocked successfully'),
            backgroundColor: isBlocked ? const Color(0xFF10B981) : const Color(0xFFEF4444),
          ),
        );
        _fetchBuyers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredBuyers = _buyers.where((b) {
      final bName = (b['businessName'] ?? '').toString().toLowerCase();
      final uName = (b['user']?['fullName'] ?? '').toString().toLowerCase();
      final username = (b['user']?['username'] ?? '').toString().toLowerCase();
      final phone = (b['user']?['mobileNumber'] ?? b['user']?['phone'] ?? '').toString().toLowerCase();
      final bId = (b['buyerId'] ?? '').toString().toLowerCase();
      final sName = (b['assignedSalesman']?['user']?['fullName'] ?? '').toString().toLowerCase();
      final q = _searchQuery.toLowerCase();

      final matchesSearch = q.isEmpty ||
          bName.contains(q) ||
          uName.contains(q) ||
          username.contains(q) ||
          phone.contains(q) ||
          bId.contains(q) ||
          sName.contains(q);

      final matchesCategory = _selectedCategory == 'ALL' || b['buyerType'] == _selectedCategory;

      return matchesSearch && matchesCategory;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Buyer Management', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            Text('Accounts, Media, Dues & Tiers', style: TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
        backgroundColor: const Color(0xFF0284C7),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () {
              _fetchBuyers();
              _fetchSalesmen();
            },
          ),
        ],
      ),
      drawer: const AdminDrawer(currentRoute: '/buyers'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showBuyerFormDialog(),
        backgroundColor: const Color(0xFF0284C7),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add Buyer', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // Search & Filter Box
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: Column(
              children: [
                TextField(
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Search by business, phone, owner, ID...',
                    hintStyle: const TextStyle(fontSize: 13),
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['ALL', 'CUSTOMER', 'DEALER', 'WHOLESALER', 'DISTRIBUTOR'].map((cat) {
                      final isSelected = _selectedCategory == cat;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6.0),
                        child: ChoiceChip(
                          label: Text(
                            cat == 'ALL' ? 'All Buyers' : cat,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? Colors.white : Colors.black87,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: const Color(0xFF0284C7),
                          backgroundColor: const Color(0xFFF1F5F9),
                          showCheckmark: false,
                          onSelected: (_) {
                            setState(() => _selectedCategory = cat);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Buyers List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: () async {
                      await _fetchBuyers();
                      await _fetchSalesmen();
                    },
                    child: filteredBuyers.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.people_outline, size: 64, color: Colors.grey),
                                SizedBox(height: 12),
                                Text('No buyers found matching criteria.', style: TextStyle(color: Colors.grey)),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
                            itemCount: filteredBuyers.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 12),
                            itemBuilder: (ctx, i) {
                              final b = filteredBuyers[i];
                              return _buildBuyerCard(b);
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBuyerCard(Map<String, dynamic> buyer) {
    final businessName = buyer['businessName'] ?? buyer['user']?['fullName'] ?? 'Trade Buyer';
    final buyerId = buyer['buyerId'] ?? 'ID-####';
    final buyerType = buyer['buyerType'] ?? 'CUSTOMER';
    final loyaltyTier = buyer['loyaltyTier'] ?? 'NONE';
    final phone = buyer['user']?['mobileNumber'] ?? buyer['user']?['phone'] ?? 'No phone';
    final salesman = buyer['assignedSalesman'];
    final salesmanName = salesman?['user']?['fullName'];

    final due = buyer['dueSummary'] ?? {};
    final outstanding = (due['outstandingAmount'] ?? buyer['outstandingBalance'] ?? 0).toDouble();
    final creditLimit = (buyer['creditLimit'] ?? 0).toDouble();
    final daysLeft = due['daysLeft'];
    final isOverdue = due['isOverdue'] == true;
    final statusText = due['statusText'] ?? '';

    final ownerPhoto = buyer['ownerPhoto'] ?? buyer['user']?['profilePhoto'];
    final shopPhoto = buyer['shopPhoto'];
    final isBlocked = (buyer['accountStatus'] == 'BLOCKED') || (buyer['user']?['accountStatus'] == 'BLOCKED');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isBlocked ? Colors.red.shade200 : Colors.grey.shade200,
          width: isBlocked ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Owner Photo + Business Info + Category
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Owner avatar or letter badge
                if (ownerPhoto != null && ownerPhoto.toString().isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Image.network(
                      ownerPhoto.toString(),
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => _buildLetterAvatar(businessName),
                    ),
                  )
                else
                  _buildLetterAvatar(businessName),

                const SizedBox(width: 10),

                // Name & Code
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              businessName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0284C7).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              buyerType,
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Text(buyerId, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0284C7))),
                          if (buyer['user']?['username'] != null && (buyer['user']['username'] as String).isNotEmpty) ...[
                            const SizedBox(width: 5),
                            Text(
                              '@${buyer['user']['username']}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
                            ),
                          ],
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: () => _showLoyaltyTierDialog(buyer),
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: loyaltyTier == 'GOLD'
                                    ? Colors.amber.shade100
                                    : loyaltyTier == 'DIAMOND'
                                    ? Colors.lightBlue.shade100
                                    : loyaltyTier == 'PLATINUM'
                                    ? Colors.purple.shade100
                                    : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                loyaltyTier == 'NONE' ? 'Standard' : '★ $loyaltyTier',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: loyaltyTier == 'GOLD'
                                      ? Colors.amber.shade900
                                      : loyaltyTier == 'DIAMOND'
                                      ? Colors.lightBlue.shade900
                                      : loyaltyTier == 'PLATINUM'
                                      ? Colors.purple.shade900
                                      : Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(phone, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                      if (shopPhoto != null && shopPhoto.toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Row(
                            children: const [
                              Icon(Icons.storefront, size: 12, color: Color(0xFF10B981)),
                              SizedBox(width: 3),
                              Text('Shop photo attached', style: TextStyle(fontSize: 10, color: Color(0xFF10B981), fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Middle Bar: Financials & Days Left for Payment
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: const Color(0xFFF8FAFC),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Credit Limit: ${_currencyFormat.format(creditLimit)}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.teal),
                    ),
                    Text(
                      'Outstanding: ${_currencyFormat.format(outstanding)}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: outstanding > 0 ? const Color(0xFFE11D48) : Colors.grey,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      salesmanName != null ? 'Rep: $salesmanName' : 'Rep: Unassigned',
                      style: TextStyle(
                        fontSize: 10,
                        color: salesmanName != null ? const Color(0xFF0F172A) : Colors.grey,
                      ),
                    ),
                    // Days left indicator
                    if (outstanding > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: isOverdue ? Colors.red.shade100 : Colors.teal.shade50,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: isOverdue ? Colors.red.shade300 : Colors.teal.shade200),
                        ),
                        child: Text(
                          statusText.isNotEmpty ? statusText : (daysLeft != null ? '$daysLeft days left' : 'Within Terms'),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isOverdue ? Colors.red.shade900 : Colors.teal.shade900,
                          ),
                        ),
                      )
                    else
                      const Text('✓ All Dues Cleared', style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),

          // Action Buttons Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                // History & Products Button
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _showBuyerDetailSheet(buyer),
                    icon: const Icon(Icons.receipt_long, size: 14),
                    label: const Text('History', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 4),

                // Make Gold/Diamond/Platinum Button
                IconButton(
                  tooltip: 'Make Gold / Diamond / Platinum',
                  icon: const Icon(Icons.military_tech_outlined, color: Colors.amber, size: 20),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _showLoyaltyTierDialog(buyer),
                ),

                // Edit Buyer
                IconButton(
                  tooltip: 'Edit Buyer Details',
                  icon: const Icon(Icons.edit_outlined, color: Color(0xFF0284C7), size: 18),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _showBuyerFormDialog(buyer: buyer),
                ),

                // Category Promote
                IconButton(
                  tooltip: 'Change Category',
                  icon: const Icon(Icons.swap_horiz, color: Colors.teal, size: 20),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _showPromoteDialog(buyer),
                ),

                // Salesman Assignment
                IconButton(
                  tooltip: 'Assign Salesman',
                  icon: const Icon(Icons.person_pin_outlined, color: Colors.indigo, size: 18),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _showAssignSalesmanDialog(buyer),
                ),

                // Block / Unblock
                IconButton(
                  tooltip: isBlocked ? 'Unblock Buyer' : 'Block Buyer',
                  icon: Icon(
                    isBlocked ? Icons.lock_open : Icons.block,
                    color: isBlocked ? const Color(0xFF10B981) : Colors.amber.shade800,
                    size: 18,
                  ),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _toggleBlockBuyer(buyer),
                ),

                // Delete Buyer
                IconButton(
                  tooltip: 'Delete Buyer',
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _showDeleteConfirmDialog(buyer['id'], businessName),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLetterAvatar(String name) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFF0284C7).withOpacity(0.12),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF0284C7).withOpacity(0.25)),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : 'B',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0284C7)),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// COMPLETE BUYER DETAIL BOTTOM SHEET (Purchases with Products, Payments & Dues)
// -----------------------------------------------------------------------------
class _BuyerDetailSheet extends ConsumerStatefulWidget {
  final String buyerId;
  final Map<String, dynamic> initialBuyer;
  final VoidCallback onTierChanged;

  const _BuyerDetailSheet({
    required this.buyerId,
    required this.initialBuyer,
    required this.onTierChanged,
  });

  @override
  ConsumerState<_BuyerDetailSheet> createState() => _BuyerDetailSheetState();
}

class _BuyerDetailSheetState extends ConsumerState<_BuyerDetailSheet> {
  Map<String, dynamic>? _buyerDetail;
  bool _isLoading = true;
  int _activeTabIndex = 0; // 0: Purchases, 1: Payments, 2: Info

  final _currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.dio.get('/buyers/${widget.buyerId}');
      if (mounted) {
        setState(() {
          _buyerDetail = res.data['data'] ?? res.data;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _buyerDetail = widget.initialBuyer;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final buyer = _buyerDetail ?? widget.initialBuyer;
    final businessName = buyer['businessName'] ?? buyer['user']?['fullName'] ?? 'Buyer Profile';
    final buyerId = buyer['buyerId'] ?? 'ID-####';
    final buyerType = buyer['buyerType'] ?? 'CUSTOMER';
    final loyaltyTier = buyer['loyaltyTier'] ?? 'NONE';

    final due = buyer['dueSummary'] ?? {};
    final outstanding = (due['outstandingAmount'] ?? buyer['outstandingBalance'] ?? 0).toDouble();
    final creditLimit = (buyer['creditLimit'] ?? 0).toDouble();
    final availableCredit = (due['availableCredit'] ?? 0).toDouble();
    final termsDays = due['paymentTermsDays'] ?? buyer['creditDays'] ?? 30;
    final daysLeft = due['daysLeft'];
    final isOverdue = due['isOverdue'] == true;
    final statusText = due['statusText'] ?? '';

    final ownerPhoto = buyer['ownerPhoto'] ?? buyer['user']?['profilePhoto'];
    final shopPhoto = buyer['shopPhoto'];

    final orders = (buyer['orders'] as List<dynamic>?) ?? [];
    final payments = (buyer['payments'] as List<dynamic>?) ?? [];

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
          ),

          // Header: Owner Photo + Business Info + Close
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 12, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (ownerPhoto != null && ownerPhoto.toString().isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(25),
                    child: Image.network(
                      ownerPhoto.toString(),
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.person, size: 50, color: Colors.grey),
                    ),
                  )
                else
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        businessName.isNotEmpty ? businessName[0].toUpperCase() : 'B',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                      ),
                    ),
                  ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        businessName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(buyerId, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0284C7))),
                          if (buyer['user']?['username'] != null && (buyer['user']['username'] as String).isNotEmpty) ...[
                            const SizedBox(width: 5),
                            Text(
                              '@${buyer['user']['username']}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
                            ),
                          ],
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0284C7).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(buyerType, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0284C7))),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.amber.shade200),
                            ),
                            child: Text('★ $loyaltyTier', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber.shade900)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),

          // Financial Dues Summary Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('OUTSTANDING BALANCE', style: TextStyle(fontSize: 9, color: Colors.white60, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text(
                            _currency.format(outstanding),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: outstanding > 0 ? const Color(0xFFFB7185) : Colors.white,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isOverdue
                              ? Colors.red.withOpacity(0.25)
                              : outstanding > 0
                              ? Colors.teal.withOpacity(0.25)
                              : Colors.green.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isOverdue
                                ? Colors.red.shade400
                                : outstanding > 0
                                ? Colors.teal.shade300
                                : Colors.green.shade400,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isOverdue ? Icons.warning_amber_rounded : Icons.timer_outlined,
                              size: 14,
                              color: isOverdue ? Colors.red.shade300 : Colors.teal.shade200,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              statusText.isNotEmpty ? statusText : (daysLeft != null ? '$daysLeft Days Left' : 'All Clear'),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isOverdue ? Colors.red.shade200 : Colors.teal.shade100,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white24, height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Credit Limit: ${_currency.format(creditLimit)}', style: const TextStyle(fontSize: 10, color: Colors.white70)),
                      Text('Available: ${_currency.format(availableCredit)}', style: const TextStyle(fontSize: 10, color: Color(0xFF86EFAC), fontWeight: FontWeight.bold)),
                      Text('Terms: $termsDays Days', style: const TextStyle(fontSize: 10, color: Colors.white70)),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Tabs: Purchases (with Products), Payments, Shop Profile
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: _buildSheetTabButton('🛍️ Purchases (${orders.length})', 0),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildSheetTabButton('💳 Payments (${payments.length})', 1),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildSheetTabButton('🏪 Shop Info', 2),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),
          const Divider(height: 1),

          // Tab Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _activeTabIndex == 0
                ? _buildPurchasesTab(orders)
                : _activeTabIndex == 1
                ? _buildPaymentsTab(payments)
                : _buildShopInfoTab(buyer, shopPhoto),
          ),
        ],
      ),
    );
  }

  Widget _buildSheetTabButton(String label, int index) {
    final isSelected = _activeTabIndex == index;
    return InkWell(
      onTap: () => setState(() => _activeTabIndex = index),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0284C7) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  // TAB 1: PURCHASES (INCLUDING PRODUCTS)
  Widget _buildPurchasesTab(List<dynamic> orders) {
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.shopping_bag_outlined, size: 48, color: Colors.grey),
            SizedBox(height: 8),
            Text('No purchase orders recorded yet', style: TextStyle(color: Colors.grey, fontSize: 13)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(14),
      itemCount: orders.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) {
        final ord = orders[i];
        final items = (ord['items'] as List<dynamic>?) ?? [];
        final totalAmount = (ord['finalAmount'] ?? 0).toDouble();

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Order Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    ord['orderNumber'] ?? ord['id'] ?? 'ORD-####',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0284C7)),
                  ),
                  Text(
                    _currency.format(totalAmount),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    ord['createdAt'] != null
                        ? DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(ord['createdAt']))
                        : 'Date N/A',
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(ord['status'] ?? 'PENDING', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: ord['paymentStatus'] == 'PAID' ? Colors.green.shade100 : Colors.red.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          ord['paymentStatus'] ?? 'PENDING',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: ord['paymentStatus'] == 'PAID' ? Colors.green.shade800 : Colors.red.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const Divider(height: 14),

              // Products Breakdown in Order
              const Text('Purchased Products:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 4),
              if (items.isNotEmpty)
                ...items.map<Widget>((item) {
                  final pName = item['product']?['name'] ?? item['productName'] ?? 'Grand Aqua Product';
                  final qty = item['quantity'] ?? 1;
                  final unitPrice = (item['unitPrice'] ?? 0).toDouble();
                  final lineTotal = (item['totalPrice'] ?? (qty * unitPrice)).toDouble();

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '$pName (x$qty)',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF334155)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          _currency.format(lineTotal),
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                  );
                })
              else
                const Text('Standard packaged order items', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey)),
            ],
          ),
        );
      },
    );
  }

  // TAB 2: PAYMENTS
  Widget _buildPaymentsTab(List<dynamic> payments) {
    if (payments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.payment_outlined, size: 48, color: Colors.grey),
            SizedBox(height: 8),
            Text('No payment transactions recorded yet', style: TextStyle(color: Colors.grey, fontSize: 13)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(14),
      itemCount: payments.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) {
        final pay = payments[i];
        final amount = (pay['amount'] ?? 0).toDouble();

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pay['paymentNumber'] ?? 'REC-####',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0284C7)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    pay['paymentDate'] != null
                        ? DateFormat('dd MMM yyyy').format(DateTime.parse(pay['paymentDate']))
                        : 'Date N/A',
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                  if (pay['transactionReference'] != null)
                    Text('Ref: ${pay['transactionReference']}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _currency.format(amount),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF16A34A)),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Text(
                      pay['paymentMethod'] ?? 'BANK',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.green.shade800),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // TAB 3: SHOP & PROFILE INFO
  Widget _buildShopInfoTab(Map<String, dynamic> buyer, dynamic shopPhoto) {
    final salesman = buyer['assignedSalesman'];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Shop Storefront Image
          if (shopPhoto != null && shopPhoto.toString().isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(
                shopPhoto.toString(),
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.store, size: 60, color: Colors.grey)),
              ),
            ),
            const SizedBox(height: 12),
          ],

          _buildInfoRow('Business Name', buyer['businessName'] ?? 'N/A'),
          _buildInfoRow('Business Type', buyer['businessType'] ?? 'Retailer'),
          _buildInfoRow('GSTIN', buyer['gstin'] ?? 'Unregistered'),
          _buildInfoRow('Owner / Contact', buyer['user']?['fullName'] ?? 'N/A'),
          _buildInfoRow('Mobile Number', buyer['user']?['phone'] ?? buyer['user']?['mobileNumber'] ?? 'N/A'),
          _buildInfoRow('Email Address', buyer['user']?['email'] ?? 'Not provided'),
          _buildInfoRow('Billing Address', buyer['billingAddress'] ?? 'Not provided'),
          _buildInfoRow('Location', '${buyer['district'] ?? ''}, ${buyer['state'] ?? ''} - ${buyer['pinCode'] ?? ''}'),
          _buildInfoRow('Assigned Sales Rep', salesman?['user']?['fullName'] ?? 'Unassigned'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 11, color: Color(0xFF0F172A), fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
