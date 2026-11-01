import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import '../core/auth_provider.dart';
import '../widgets/admin_drawer.dart';

class SalesmenScreen extends ConsumerStatefulWidget {
  const SalesmenScreen({super.key});

  @override
  ConsumerState<SalesmenScreen> createState() => _SalesmenScreenState();
}

class _SalesmenScreenState extends ConsumerState<SalesmenScreen> {
  List<dynamic> _salesmen = [];
  List<dynamic> _allBuyers = [];
  bool _isLoading = true;
  String _selectedStatus = 'ALL';
  String _searchQuery = '';

  final _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
  final _dateFormat = DateFormat('dd MMM yyyy');

  String _resolveImageUrl(dynamic url) {
    if (url == null) return '';
    final clean = url.toString().trim();
    if (clean.isEmpty) return '';
    if (clean.startsWith('http://') || clean.startsWith('https://')) return clean;
    final api = ref.read(apiClientProvider);
    final base = api.dio.options.baseUrl.replaceAll('/api/v1', '');
    return clean.startsWith('/') ? '$base$clean' : '$base/$clean';
  }

  @override
  void initState() {
    super.initState();
    _fetchSalesmen();
    _fetchBuyers();
  }

  Future<void> _fetchBuyers() async {
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.dio.get('/buyers?limit=200');
      final data = res.data['data'] ?? res.data;
      if (mounted) {
        setState(() {
          _allBuyers = (data is Map && data['buyers'] != null)
              ? data['buyers']
              : (data is List ? data : []);
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchSalesmen() async {
    setState(() => _isLoading = true);
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.dio.get('/salesmen');
      final data = res.data['data'] ?? res.data;
      if (mounted) {
        setState(() {
          _salesmen = (data is List) ? data : (data['salesmen'] ?? []);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load salesmen: $e')),
        );
      }
    }
  }

  // Toggle Block / Unblock Salesman
  Future<void> _toggleBlockSalesman(Map<String, dynamic> salesman) async {
    final sId = salesman['id']?.toString() ?? '';
    final isBlocked = (salesman['employmentStatus'] == 'BLOCKED') ||
        (salesman['user']?['accountStatus'] == 'BLOCKED');
    final actionName = isBlocked ? 'Unblock' : 'Block';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('$actionName Salesman'),
        content: Text(
          isBlocked
              ? 'Are you sure you want to unblock ${salesman['user']?['fullName'] ?? 'this salesman'}? They will regain access to their mobile sales app.'
              : 'Are you sure you want to block ${salesman['user']?['fullName'] ?? 'this salesman'}? Their account and access will be temporarily frozen.',
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
      await api.dio.put('/salesmen/$sId/toggle-block');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isBlocked ? 'Salesman unblocked successfully' : 'Salesman blocked successfully'),
            backgroundColor: isBlocked ? const Color(0xFF10B981) : const Color(0xFFEF4444),
          ),
        );
        _fetchSalesmen();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Action failed: $e')),
        );
      }
    }
  }

  // Delete Salesman
  Future<void> _deleteSalesman(Map<String, dynamic> salesman) async {
    final sId = salesman['id']?.toString() ?? '';
    final name = salesman['user']?['fullName'] ?? 'Salesman';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Salesman Account'),
        content: Text(
          'Are you sure you want to permanently delete $name ($sId)? All assigned buyers will be safely unassigned.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final api = ref.read(apiClientProvider);
      await api.dio.delete('/salesmen/$sId');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$name removed successfully')),
        );
        _fetchSalesmen();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e')),
        );
      }
    }
  }

  // Create Salesman Dialog
  void _showAddSalesmanDialog() {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final usernameCtrl = TextEditingController();
    final mobileCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final designationCtrl = TextEditingController(text: 'Area Sales Manager');
    final territoryCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final passwordCtrl = TextEditingController(text: 'Sales@123');
    String? pickedPhotoUrl;
    bool isUploadingPhoto = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final previewUrl = _resolveImageUrl(pickedPhotoUrl);

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Add New Salesman',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: 10),

                    // Salesman Photo Picker
                    Center(
                      child: Column(
                        children: [
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              CircleAvatar(
                                radius: 36,
                                backgroundColor: const Color(0xFF0284C7).withValues(alpha: 0.1),
                                backgroundImage: previewUrl.isNotEmpty ? NetworkImage(previewUrl) : null,
                                child: previewUrl.isEmpty
                                    ? const Icon(Icons.person, size: 40, color: Color(0xFF0284C7))
                                    : null,
                              ),
                              if (isUploadingPhoto)
                                const Positioned.fill(
                                  child: CircularProgressIndicator(),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            alignment: WrapAlignment.center,
                            children: [
                              OutlinedButton.icon(
                                onPressed: isUploadingPhoto
                                    ? null
                                    : () async {
                                        try {
                                          final result = await FilePicker.pickFiles(type: FileType.image);
                                          if (result.isEmpty) return;
                                          final picked = result.first;

                                          setDialogState(() => isUploadingPhoto = true);

                                          MultipartFile multipartFile;
                                          if (picked.path != null) {
                                            multipartFile = await MultipartFile.fromFile(picked.path!, filename: picked.name);
                                          } else {
                                            final fileBytes = await picked.readAsBytes();
                                            multipartFile = MultipartFile.fromBytes(fileBytes, filename: picked.name);
                                          }

                                          final api = ref.read(apiClientProvider);
                                          final res = await api.dio.post('/upload', data: FormData.fromMap({'file': multipartFile}));
                                          final data = res.data['data'] ?? res.data;
                                          final uploadedUrl = (data['url'] ?? data['relativePath'] ?? '').toString();

                                          setDialogState(() {
                                            isUploadingPhoto = false;
                                            if (uploadedUrl.isNotEmpty) {
                                              pickedPhotoUrl = uploadedUrl;
                                            }
                                          });
                                        } catch (err) {
                                          setDialogState(() => isUploadingPhoto = false);
                                          if (ctx.mounted) {
                                            ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Upload failed: $err'), backgroundColor: Colors.red));
                                          }
                                        }
                                      },
                                icon: const Icon(Icons.camera_alt_outlined, size: 16),
                                label: Text(pickedPhotoUrl != null ? 'Change Photo' : 'Upload Photo', style: const TextStyle(fontSize: 12)),
                              ),
                              if (pickedPhotoUrl != null && pickedPhotoUrl!.isNotEmpty)
                                TextButton(
                                  onPressed: () => setDialogState(() => pickedPhotoUrl = null),
                                  child: const Text('Remove', style: TextStyle(color: Colors.red, fontSize: 12)),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: nameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Full Name *',
                              prefixIcon: Icon(Icons.person_outline),
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter full name' : null,
                          ),
                        ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: usernameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Username (Optional)',
                          prefixIcon: Icon(Icons.alternate_email, size: 18),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: mobileCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Mobile Number *',
                          prefixIcon: Icon(Icons.phone_outlined),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (v == null || v.trim().length < 10) ? 'Enter 10-digit mobile' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email Address *',
                          prefixIcon: Icon(Icons.email_outlined),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (v == null || !v.contains('@')) ? 'Enter valid email' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: designationCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Designation *',
                          prefixIcon: Icon(Icons.badge_outlined),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter designation' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: territoryCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Territory / Region',
                          prefixIcon: Icon(Icons.location_on_outlined),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: addressCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Operational Headquarters / Address',
                    prefixIcon: Icon(Icons.home_work_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: passwordCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Initial Password *',
                    prefixIcon: Icon(Icons.lock_outline),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.length < 6) ? 'Min 6 characters' : null,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.check),
                    label: const Text('Create Salesman Account', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      try {
                        final api = ref.read(apiClientProvider);
                        await api.dio.post('/salesmen', data: {
                          'fullName': nameCtrl.text.trim(),
                          'username': usernameCtrl.text.trim().toLowerCase().isNotEmpty ? usernameCtrl.text.trim().toLowerCase() : null,
                          'phone': mobileCtrl.text.trim(),
                          'mobileNumber': mobileCtrl.text.trim(),
                          'email': emailCtrl.text.trim(),
                          'designation': designationCtrl.text.trim(),
                          'territory': territoryCtrl.text.trim(),
                          'address': addressCtrl.text.trim(),
                          'password': passwordCtrl.text,
                          'profilePhoto': pickedPhotoUrl,
                        });
                        if (mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Salesman created successfully!'),
                              backgroundColor: Color(0xFF10B981),
                            ),
                          );
                          _fetchSalesmen();
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to create: $e')),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  ),
);
}

  // Edit Salesman Dialog
  void _showEditSalesmanDialog(Map<String, dynamic> salesman) {
    final formKey = GlobalKey<FormState>();
    final sId = salesman['id']?.toString() ?? '';
    final nameCtrl = TextEditingController(text: salesman['user']?['fullName'] ?? '');
    final usernameCtrl = TextEditingController(text: salesman['user']?['username'] ?? '');
    final designationCtrl = TextEditingController(text: salesman['designation'] ?? '');
    final territoryCtrl = TextEditingController(text: salesman['territory'] ?? '');
    String status = salesman['employmentStatus'] ?? 'ACTIVE';
    String? pickedPhotoUrl = salesman['user']?['profilePhoto'];
    bool isUploadingPhoto = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final previewUrl = _resolveImageUrl(pickedPhotoUrl);

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Edit ${salesman['user']?['fullName'] ?? 'Salesman'}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: 10),

                    // Salesman Photo Picker
                    Center(
                      child: Column(
                        children: [
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              CircleAvatar(
                                radius: 36,
                                backgroundColor: const Color(0xFF0284C7).withValues(alpha: 0.1),
                                backgroundImage: previewUrl.isNotEmpty ? NetworkImage(previewUrl) : null,
                                child: previewUrl.isEmpty
                                    ? const Icon(Icons.person, size: 40, color: Color(0xFF0284C7))
                                    : null,
                              ),
                              if (isUploadingPhoto)
                                const Positioned.fill(
                                  child: CircularProgressIndicator(),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            alignment: WrapAlignment.center,
                            children: [
                              OutlinedButton.icon(
                                onPressed: isUploadingPhoto
                                    ? null
                                    : () async {
                                        try {
                                          final result = await FilePicker.pickFiles(type: FileType.image);
                                          if (result.isEmpty) return;
                                          final picked = result.first;

                                          setDialogState(() => isUploadingPhoto = true);

                                          MultipartFile multipartFile;
                                          if (picked.path != null) {
                                            multipartFile = await MultipartFile.fromFile(picked.path!, filename: picked.name);
                                          } else {
                                            final fileBytes = await picked.readAsBytes();
                                            multipartFile = MultipartFile.fromBytes(fileBytes, filename: picked.name);
                                          }

                                          final api = ref.read(apiClientProvider);
                                          final res = await api.dio.post('/upload', data: FormData.fromMap({'file': multipartFile}));
                                          final data = res.data['data'] ?? res.data;
                                          final uploadedUrl = (data['url'] ?? data['relativePath'] ?? '').toString();

                                          setDialogState(() {
                                            isUploadingPhoto = false;
                                            if (uploadedUrl.isNotEmpty) {
                                              pickedPhotoUrl = uploadedUrl;
                                            }
                                          });
                                        } catch (err) {
                                          setDialogState(() => isUploadingPhoto = false);
                                          if (ctx.mounted) {
                                            ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Upload failed: $err'), backgroundColor: Colors.red));
                                          }
                                        }
                                      },
                                icon: const Icon(Icons.camera_alt_outlined, size: 16),
                                label: Text(pickedPhotoUrl != null ? 'Change Photo' : 'Upload Photo', style: const TextStyle(fontSize: 12)),
                              ),
                              if (pickedPhotoUrl != null && pickedPhotoUrl!.isNotEmpty)
                                TextButton(
                                  onPressed: () => setDialogState(() => pickedPhotoUrl = null),
                                  child: const Text('Remove', style: TextStyle(color: Colors.red, fontSize: 12)),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller: nameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Full Name *',
                            prefixIcon: Icon(Icons.person_outline),
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter full name' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: usernameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Username (Optional)',
                            prefixIcon: Icon(Icons.alternate_email, size: 18),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: designationCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Designation *',
                            prefixIcon: Icon(Icons.badge_outlined),
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter designation' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: territoryCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Territory / Region',
                            prefixIcon: Icon(Icons.location_on_outlined),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: status,
                    decoration: const InputDecoration(
                      labelText: 'Employment Status',
                      prefixIcon: Icon(Icons.verified_user_outlined),
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'ACTIVE', child: Text('Active (Authorized)')),
                      DropdownMenuItem(value: 'BLOCKED', child: Text('Blocked (Access Restricted)')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => status = val);
                    },
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.save),
                      label: const Text('Update Profile', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;
                        try {
                          final api = ref.read(apiClientProvider);
                          await api.dio.put('/salesmen/$sId', data: {
                            'fullName': nameCtrl.text.trim(),
                            'username': usernameCtrl.text.trim().toLowerCase().isNotEmpty ? usernameCtrl.text.trim().toLowerCase() : null,
                            'designation': designationCtrl.text.trim(),
                            'territory': territoryCtrl.text.trim(),
                            'employmentStatus': status,
                            'profilePhoto': pickedPhotoUrl,
                          });
                          if (mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Salesman profile updated!'),
                                backgroundColor: Color(0xFF10B981),
                              ),
                            );
                            _fetchSalesmen();
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to update: $e')),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

  // Assigned Buyers Modal
  void _showAssignedBuyersModal(Map<String, dynamic> salesman) {
    final sId = salesman['id']?.toString() ?? '';
    final name = salesman['user']?['fullName'] ?? 'Salesman';
    String? selectedBuyerToAssign;
    List<dynamic> currentBuyers = List.from(salesman['assignedBuyers'] ?? []);
    bool isAssigning = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final assignedIds = currentBuyers.map((b) => b['id']?.toString()).toSet();
          final availableBuyers = _allBuyers.where((b) => !assignedIds.contains(b['id']?.toString())).toList();

          return Container(
            height: MediaQuery.of(ctx).size.height * 0.85,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Assigned Buyers ($name)',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        Text(
                          '${currentBuyers.length} accounts currently assigned',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 10),

                // Assign New Buyer Bar
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Assign New Buyer to this Salesman:',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedBuyerToAssign,
                              isExpanded: true,
                              hint: const Text('Select buyer account', style: TextStyle(fontSize: 13)),
                              items: availableBuyers.map<DropdownMenuItem<String>>((b) {
                                final bName = b['businessName'] ?? b['user']?['fullName'] ?? 'Buyer';
                                final bType = b['buyerType'] ?? 'CUSTOMER';
                                return DropdownMenuItem<String>(
                                  value: b['id']?.toString(),
                                  child: Text(
                                    '$bName ($bType)',
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                setModalState(() => selectedBuyerToAssign = val);
                              },
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF0284C7),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: (selectedBuyerToAssign == null || isAssigning)
                                ? null
                                : () async {
                                    setModalState(() => isAssigning = true);
                                    try {
                                      final api = ref.read(apiClientProvider);
                                      await api.dio.post('/salesmen/$sId/assign-buyer', data: {
                                        'buyerProfileId': selectedBuyerToAssign,
                                      });

                                      // Re-fetch assigned buyers
                                      final bRes = await api.dio.get('/salesmen/$sId/buyers');
                                      final bData = bRes.data['data'] ?? bRes.data;
                                      setModalState(() {
                                        currentBuyers = List.from(bData);
                                        selectedBuyerToAssign = null;
                                        isAssigning = false;
                                      });
                                      _fetchSalesmen();
                                    } catch (e) {
                                      setModalState(() => isAssigning = false);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Failed to assign buyer: $e')),
                                      );
                                    }
                                  },
                            child: isAssigning
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('Assign'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                const Text(
                  'Assigned Accounts',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 8),

                // List of Assigned Buyers
                Expanded(
                  child: currentBuyers.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.person_off_outlined, size: 48, color: Colors.grey),
                              SizedBox(height: 8),
                              Text('No buyers currently assigned to this salesman.', style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: currentBuyers.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (ctx, index) {
                            final buyer = currentBuyers[index];
                            final bId = buyer['id']?.toString() ?? '';
                            final bName = buyer['businessName'] ?? buyer['user']?['fullName'] ?? 'Buyer';
                            final bPhone = buyer['user']?['mobileNumber'] ?? 'No phone';
                            final bType = buyer['buyerType'] ?? 'CUSTOMER';
                            final ordersCount = buyer['orders'] != null ? (buyer['orders'] as List).length : 0;

                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: const Color(0xFF0284C7).withOpacity(0.1),
                                    child: const Icon(Icons.storefront, color: Color(0xFF0284C7)),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(bName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF0284C7).withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                bType,
                                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(bPhone, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text('$ordersCount Total Orders', style: const TextStyle(fontSize: 10, color: Colors.teal)),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Unassign Buyer',
                                    icon: const Icon(Icons.link_off, color: Colors.red),
                                    onPressed: () async {
                                      final unassignConfirm = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx2) => AlertDialog(
                                          title: const Text('Unassign Buyer'),
                                          content: Text('Unassign $bName from $name?'),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(ctx2, false),
                                              child: const Text('Cancel'),
                                            ),
                                            FilledButton(
                                              style: FilledButton.styleFrom(backgroundColor: Colors.red),
                                              onPressed: () => Navigator.pop(ctx2, true),
                                              child: const Text('Unassign'),
                                            ),
                                          ],
                                        ),
                                      );

                                      if (unassignConfirm == true) {
                                        try {
                                          final api = ref.read(apiClientProvider);
                                          await api.dio.delete('/salesmen/$sId/unassign-buyer/$bId');
                                          final bRes = await api.dio.get('/salesmen/$sId/buyers');
                                          final bData = bRes.data['data'] ?? bRes.data;
                                          setModalState(() {
                                            currentBuyers = List.from(bData);
                                          });
                                          _fetchSalesmen();
                                        } catch (e) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Failed to unassign: $e')),
                                          );
                                        }
                                      }
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Sales History Modal with Date Range & Buyer Filters
  void _showSalesHistoryModal(Map<String, dynamic> salesman) {
    final sId = salesman['id']?.toString() ?? '';
    final name = salesman['user']?['fullName'] ?? 'Salesman';
    final assignedBuyers = List<dynamic>.from(salesman['assignedBuyers'] ?? []);

    DateTime? startDate;
    DateTime? endDate;
    String? filterBuyerId;
    bool isLoadingHistory = true;
    Map<String, dynamic>? historyData;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          Future<void> loadHistory() async {
            setModalState(() => isLoadingHistory = true);
            try {
              final api = ref.read(apiClientProvider);
              String url = '/salesmen/$sId/sales-history?';
              if (startDate != null) {
                url += 'startDate=${startDate!.toIso8601String().split('T')[0]}&';
              }
              if (endDate != null) {
                url += 'endDate=${endDate!.toIso8601String().split('T')[0]}&';
              }
              if (filterBuyerId != null && filterBuyerId!.isNotEmpty) {
                url += 'buyerProfileId=$filterBuyerId&';
              }

              final res = await api.dio.get(url);
              final data = res.data['data'] ?? res.data;
              setModalState(() {
                historyData = data;
                isLoadingHistory = false;
              });
            } catch (e) {
              setModalState(() => isLoadingHistory = false);
            }
          }

          if (historyData == null && isLoadingHistory) {
            loadHistory();
          }

          final summary = historyData?['summary'] ?? {};
          final orders = (historyData?['orders'] as List<dynamic>?) ?? [];

          return Container(
            height: MediaQuery.of(ctx).size.height * 0.90,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sales Performance & History',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        Text(
                          'Performance record for $name',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Divider(),

                // Filters Container (Dates + Buyer)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              ),
                              icon: const Icon(Icons.date_range, size: 16),
                              label: Text(
                                startDate == null ? 'From Date' : _dateFormat.format(startDate!),
                                style: const TextStyle(fontSize: 11),
                              ),
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: startDate ?? DateTime.now().subtract(const Duration(days: 30)),
                                  firstDate: DateTime(2023),
                                  lastDate: DateTime.now().add(const Duration(days: 365)),
                                );
                                if (picked != null) {
                                  startDate = picked;
                                  loadHistory();
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              ),
                              icon: const Icon(Icons.event_available, size: 16),
                              label: Text(
                                endDate == null ? 'To Date' : _dateFormat.format(endDate!),
                                style: const TextStyle(fontSize: 11),
                              ),
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: endDate ?? DateTime.now(),
                                  firstDate: DateTime(2023),
                                  lastDate: DateTime.now().add(const Duration(days: 365)),
                                );
                                if (picked != null) {
                                  endDate = picked;
                                  loadHistory();
                                }
                              },
                            ),
                          ),
                          if (startDate != null || endDate != null || filterBuyerId != null) ...[
                            const SizedBox(width: 6),
                            IconButton(
                              tooltip: 'Reset Filters',
                              icon: const Icon(Icons.clear, size: 20, color: Colors.red),
                              onPressed: () {
                                startDate = null;
                                endDate = null;
                                filterBuyerId = null;
                                loadHistory();
                              },
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: filterBuyerId,
                        isExpanded: true,
                        hint: const Text('Filter by specific buyer (All)', style: TextStyle(fontSize: 12)),
                        items: [
                          const DropdownMenuItem<String>(
                            value: '',
                            child: Text('All Buyers', style: TextStyle(fontSize: 12)),
                          ),
                          ...assignedBuyers.map<DropdownMenuItem<String>>((b) {
                            final bName = b['businessName'] ?? b['user']?['fullName'] ?? 'Buyer';
                            final bType = b['buyerType'] ?? 'CUSTOMER';
                            return DropdownMenuItem<String>(
                              value: b['id']?.toString() ?? '',
                              child: Text('$bName ($bType)', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                            );
                          }),
                        ],
                        onChanged: (val) {
                          filterBuyerId = (val != null && val.isNotEmpty) ? val : null;
                          loadHistory();
                        },
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // KPI Strip
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricTile(
                        'Total Sales',
                        _currencyFormat.format(summary['totalSales'] ?? 0),
                        const Color(0xFF0284C7),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildMetricTile(
                        'Collected',
                        _currencyFormat.format(summary['totalPaid'] ?? 0),
                        const Color(0xFF10B981),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildMetricTile(
                        '3% Commission',
                        _currencyFormat.format(summary['provisionalCommission'] ?? 0),
                        const Color(0xFF8B5CF6),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Orders Found: ${orders.length}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    Text(
                      'Outstanding: ${_currencyFormat.format(summary['totalOutstanding'] ?? 0)}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFE11D48)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Orders List
                Expanded(
                  child: isLoadingHistory
                      ? const Center(child: CircularProgressIndicator())
                      : orders.isEmpty
                          ? const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey),
                                  SizedBox(height: 8),
                                  Text(
                                    'No sales orders recorded for the selected criteria.',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              itemCount: orders.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 8),
                              itemBuilder: (ctx, index) {
                                final order = orders[index];
                                final orderNo = order['orderNumber'] ?? 'ORD-####';
                                final bName = order['buyer']?['businessName'] ?? 'Customer';
                                final bTier = order['buyer']?['buyerType'] ?? 'CUSTOMER';
                                final total = order['finalTotal'] ?? 0;
                                final status = order['status'] ?? 'PENDING';
                                final pStatus = order['paymentStatus'] ?? 'PENDING';
                                final dateStr = order['createdAt'] != null
                                    ? _dateFormat.format(DateTime.parse(order['createdAt']))
                                    : '';

                                return Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.grey.shade200),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      CircleAvatar(
                                        radius: 18,
                                        backgroundColor: status == 'DELIVERED'
                                            ? Colors.green.shade50
                                            : Colors.blue.shade50,
                                        child: Icon(
                                          status == 'DELIVERED' ? Icons.check_circle : Icons.inventory_2,
                                          size: 18,
                                          color: status == 'DELIVERED' ? Colors.green : Colors.blue,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(orderNo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                                Text(_currencyFormat.format(total), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF0F172A))),
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Text('$bName ($bTier)', style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
                                            const SizedBox(height: 4),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(dateStr, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                                Row(
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: Colors.blue.shade50,
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: Text(status, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blue)),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: pStatus == 'PAID' ? Colors.green.shade50 : Colors.amber.shade50,
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: Text(pStatus, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: pStatus == 'PAID' ? Colors.green : Colors.orange)),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMetricTile(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Filter salesmen by search and status
    final filteredSalesmen = _salesmen.where((s) {
      final name = s['user']?['fullName']?.toString().toLowerCase() ?? '';
      final username = s['user']?['username']?.toString().toLowerCase() ?? '';
      final mobile = s['user']?['mobileNumber']?.toString().toLowerCase() ?? '';
      final empCode = s['employeeCode']?.toString().toLowerCase() ?? '';
      final territory = s['territory']?.toString().toLowerCase() ?? '';
      final designation = s['designation']?.toString().toLowerCase() ?? '';
      final q = _searchQuery.toLowerCase();

      final matchesSearch = q.isEmpty ||
          name.contains(q) ||
          username.contains(q) ||
          mobile.contains(q) ||
          empCode.contains(q) ||
          territory.contains(q) ||
          designation.contains(q);

      final isBlocked = (s['employmentStatus'] == 'BLOCKED') ||
          (s['user']?['accountStatus'] == 'BLOCKED');

      final matchesStatus = _selectedStatus == 'ALL' ||
          (_selectedStatus == 'ACTIVE' && !isBlocked) ||
          (_selectedStatus == 'BLOCKED' && isBlocked);

      return matchesSearch && matchesStatus;
    }).toList();

    final totalCount = _salesmen.length;
    final activeCount = _salesmen.where((s) => (s['employmentStatus'] != 'BLOCKED') && (s['user']?['accountStatus'] != 'BLOCKED')).length;
    final blockedCount = totalCount - activeCount;

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sales Team Management', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            Text('Salesmen, Assigned Buyers & History', style: TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
        backgroundColor: const Color(0xFF0284C7),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh list',
            onPressed: _fetchSalesmen,
          ),
        ],
      ),
      drawer: const AdminDrawer(currentRoute: '/salesmen'),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0284C7),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add),
        label: const Text('Add Salesman', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: _showAddSalesmanDialog,
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
                    hintText: 'Search by name, mobile, code, territory...',
                    hintStyle: const TextStyle(fontSize: 13),
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _buildFilterChip('ALL', 'All ($totalCount)'),
                    const SizedBox(width: 8),
                    _buildFilterChip('ACTIVE', 'Active ($activeCount)'),
                    const SizedBox(width: 8),
                    _buildFilterChip('BLOCKED', 'Blocked ($blockedCount)'),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Salesman Cards List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _fetchSalesmen,
                    child: filteredSalesmen.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.people_outline, size: 64, color: Colors.grey),
                                SizedBox(height: 12),
                                Text('No salesmen found matching criteria.', style: TextStyle(color: Colors.grey)),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(12),
                            itemCount: filteredSalesmen.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 12),
                            itemBuilder: (ctx, index) {
                              final salesman = filteredSalesmen[index];
                              return _buildSalesmanCard(salesman);
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _selectedStatus == key;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : Colors.black87, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      selected: isSelected,
      selectedColor: const Color(0xFF0284C7),
      backgroundColor: const Color(0xFFF1F5F9),
      showCheckmark: false,
      onSelected: (_) => setState(() => _selectedStatus = key),
    );
  }

  Widget _buildSalesmanCard(Map<String, dynamic> salesman) {
    final name = salesman['user']?['fullName'] ?? 'Salesman';
    final mobile = salesman['user']?['phone'] ?? salesman['user']?['mobileNumber'] ?? 'No mobile';
    final email = salesman['user']?['email'] ?? 'No email';
    final designation = salesman['designation'] ?? salesman['assignedTerritory'] ?? 'Sales Executive';
    final territory = salesman['assignedTerritory'] ?? salesman['territory'] ?? 'Unassigned';
    final empCode = salesman['employeeCode'] ?? 'GA-SLS';
    final photoUrl = _resolveImageUrl(salesman['user']?['profilePhoto']);
    final isBlocked = (salesman['employmentStatus'] == 'BLOCKED') ||
        (salesman['user']?['accountStatus'] == 'BLOCKED');
    final assignedBuyers = (salesman['assignedBuyers'] as List<dynamic>?) ?? [];

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
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Top Header
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: isBlocked ? Colors.red.shade100 : const Color(0xFF0284C7).withValues(alpha: 0.12),
                      backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                      child: photoUrl.isEmpty
                          ? Text(
                              name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'S',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isBlocked ? Colors.red.shade800 : const Color(0xFF0284C7),
                              ),
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: isBlocked ? Colors.red : const Color(0xFF10B981),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isBlocked ? Colors.red.shade50 : Colors.green.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isBlocked ? Colors.red.shade200 : Colors.green.shade200,
                              ),
                            ),
                            child: Text(
                              isBlocked ? 'BLOCKED' : 'ACTIVE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isBlocked ? Colors.red.shade700 : Colors.green.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              empCode,
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                            ),
                          ),
                          if (salesman['user']?['username'] != null && (salesman['user']['username'] as String).isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Text(
                              '@${salesman['user']['username']}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
                            ),
                          ],
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              designation,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              territory,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.phone_outlined, size: 14, color: Color(0xFF0284C7)),
                          const SizedBox(width: 4),
                          Text(mobile, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0284C7))),
                          const SizedBox(width: 12),
                          const Icon(Icons.email_outlined, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(email, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Metrics Band
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            color: const Color(0xFFF8FAFC),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.people_alt_outlined, size: 15, color: Color(0xFF0284C7)),
                    const SizedBox(width: 4),
                    Text(
                      '${assignedBuyers.length} Assigned Buyers',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                    ),
                  ],
                ),
                Text(
                  'Territory: $territory',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                ),
              ],
            ),
          ),

          // Actions Footer
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                // Assigned Buyers Button
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      side: const BorderSide(color: Color(0xFF0284C7)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.groups, size: 16, color: Color(0xFF0284C7)),
                    label: const Text('Buyers', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0284C7))),
                    onPressed: () => _showAssignedBuyersModal(salesman),
                  ),
                ),
                const SizedBox(width: 6),
                // Sales History Button
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      side: const BorderSide(color: Colors.teal),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.history, size: 16, color: Colors.teal),
                    label: const Text('History', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.teal)),
                    onPressed: () => _showSalesHistoryModal(salesman),
                  ),
                ),
                const SizedBox(width: 6),
                // Block / Unblock Button
                IconButton(
                  tooltip: isBlocked ? 'Unblock Salesman' : 'Block Salesman',
                  icon: Icon(
                    isBlocked ? Icons.lock_open : Icons.block,
                    color: isBlocked ? const Color(0xFF10B981) : Colors.amber.shade800,
                    size: 20,
                  ),
                  onPressed: () => _toggleBlockSalesman(salesman),
                ),
                // Edit Button
                IconButton(
                  tooltip: 'Edit Profile',
                  icon: const Icon(Icons.edit_outlined, color: Color(0xFF475569), size: 20),
                  onPressed: () => _showEditSalesmanDialog(salesman),
                ),
                // Delete Button
                IconButton(
                  tooltip: 'Delete Salesman',
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                  onPressed: () => _deleteSalesman(salesman),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
