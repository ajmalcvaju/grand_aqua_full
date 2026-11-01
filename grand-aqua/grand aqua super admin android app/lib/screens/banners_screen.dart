import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import '../core/auth_provider.dart';
import '../widgets/admin_drawer.dart';

const List<Map<String, String>> audienceOptions = [
  {'value': 'ALL_BUYERS', 'label': '1. All Buyers', 'desc': 'Visible to every buyer'},
  {'value': 'ALL_WHOLESALERS', 'label': '2. All Wholesalers', 'desc': 'Wholesalers only'},
  {'value': 'ALL_DISTRIBUTORS', 'label': '3. All Distributors', 'desc': 'Distributors only'},
  {'value': 'ALL_DEALERS', 'label': '4. All Dealers', 'desc': 'Dealers only'},
  {'value': 'ALL_CUSTOMERS', 'label': '5. All Customers', 'desc': 'Retail customers only'},
  {'value': 'SPECIFIC_BUYERS', 'label': '6. Select Buyers', 'desc': 'Targeted to chosen buyers'},
  {'value': 'EXCLUDE_BUYERS', 'label': '7. Except Selected Buyers', 'desc': 'All except chosen buyers'},
];

class BannersScreen extends ConsumerStatefulWidget {
  const BannersScreen({super.key});

  @override
  ConsumerState<BannersScreen> createState() => _BannersScreenState();
}

class _BannersScreenState extends ConsumerState<BannersScreen> {
  List<dynamic> _banners = [];
  List<dynamic> _buyers = [];
  bool _isLoading = true;
  String _selectedAudienceFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.dio.get('/banners');
      final data = res.data['data'] ?? res.data;

      List<dynamic> buyersList = [];
      try {
        final bRes = await api.dio.get('/buyers?limit=200');
        final bData = bRes.data['data'] ?? bRes.data;
        buyersList = (bData['buyers'] ?? bData) as List<dynamic>? ?? [];
      } catch (_) {}

      setState(() {
        _banners = (data as List<dynamic>?) ?? [];
        _buyers = buyersList;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleActive(String id, bool current) async {
    try {
      final api = ref.read(apiClientProvider);
      await api.dio.put('/banners/$id', data: {'isActive': !current});
      _fetchData();
    } catch (_) {}
  }

  Future<void> _deleteBanner(String id, String title) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Banner?'),
        content: Text('Are you sure you want to delete "$title"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final api = ref.read(apiClientProvider);
        await api.dio.delete('/banners/$id');
        _fetchData();
      } catch (_) {}
    }
  }

  void _openBannerForm({Map<String, dynamic>? banner}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _BannerFormModal(
        banner: banner,
        allBuyers: _buyers,
        onSaved: () {
          Navigator.pop(ctx);
          _fetchData();
        },
      ),
    );
  }

  List<dynamic> get _filteredBanners {
    if (_selectedAudienceFilter == 'ALL') return _banners;
    return _banners.where((b) => b['audienceType'] == _selectedAudienceFilter).toList();
  }

  Widget _buildAudienceBadge(String audienceType, int buyerCount) {
    Color bg = const Color(0xFFE0F2FE);
    Color text = const Color(0xFF0284C7);
    String label = audienceType;

    switch (audienceType) {
      case 'ALL_BUYERS':
        label = '1. All Buyers';
        bg = const Color(0xFFEFF6FF);
        text = const Color(0xFF2563EB);
        break;
      case 'ALL_WHOLESALERS':
        label = '2. Wholesalers';
        bg = const Color(0xFFECFDF5);
        text = const Color(0xFF059669);
        break;
      case 'ALL_DISTRIBUTORS':
        label = '3. Distributors';
        bg = const Color(0xFFF5F3FF);
        text = const Color(0xFF7C3AED);
        break;
      case 'ALL_DEALERS':
        label = '4. Dealers';
        bg = const Color(0xFFFFFBEB);
        text = const Color(0xFFD97706);
        break;
      case 'ALL_CUSTOMERS':
        label = '5. Customers';
        bg = const Color(0xFFECFEFF);
        text = const Color(0xFF0891B2);
        break;
      case 'SPECIFIC_BUYERS':
        label = '6. Select Buyers ($buyerCount)';
        bg = const Color(0xFFEEF2FF);
        text = const Color(0xFF4F46E5);
        break;
      case 'EXCLUDE_BUYERS':
        label = '7. Except Selected ($buyerCount)';
        bg = const Color(0xFFFFF1F2);
        text = const Color(0xFFE11D48);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(color: text, fontWeight: FontWeight.bold, fontSize: 10),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredBanners;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Banner Management', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Banner',
            onPressed: () => _openBannerForm(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchData,
          ),
        ],
      ),
      drawer: const AdminDrawer(currentRoute: '/banners'),
      body: RefreshIndicator(
        onRefresh: _fetchData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Audience Filter Carousel
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text('All (${_banners.length})'),
                      selected: _selectedAudienceFilter == 'ALL',
                      onSelected: (_) => setState(() => _selectedAudienceFilter = 'ALL'),
                      selectedColor: const Color(0xFF0284C7),
                      backgroundColor: Colors.white,
                      labelStyle: TextStyle(
                        fontSize: 11,
                        fontWeight: _selectedAudienceFilter == 'ALL' ? FontWeight.bold : FontWeight.w500,
                        color: _selectedAudienceFilter == 'ALL' ? Colors.white : const Color(0xFF475569),
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  ...audienceOptions.map((opt) {
                    final isSel = _selectedAudienceFilter == opt['value'];
                    final count = _banners.where((b) => b['audienceType'] == opt['value']).length;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text('${opt['label']} ($count)'),
                        selected: isSel,
                        onSelected: (_) => setState(() => _selectedAudienceFilter = opt['value']!),
                        selectedColor: const Color(0xFF0284C7),
                        backgroundColor: Colors.white,
                        labelStyle: TextStyle(
                          fontSize: 11,
                          fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                          color: isSel ? Colors.white : const Color(0xFF475569),
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    );
                  }),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Banners List
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.image_not_supported_outlined, size: 48, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      const Text(
                        'No banners found for this audience',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B), fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () => _openBannerForm(),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Create Banner'),
                        style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0284C7)),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filtered.length,
                itemBuilder: (ctx, i) {
                  final b = filtered[i];
                  final bool active = b['isActive'] ?? true;
                  String img = (b['imageUrl'] ?? '').toString();
                  if (img.startsWith('/')) {
                    final api = ref.read(apiClientProvider);
                    var base = api.dio.options.baseUrl;
                    if (base.endsWith('/api/v1')) base = base.substring(0, base.length - 7);
                    img = '$base$img';
                  }
                  final buyerCount = (b['selectedBuyerIds'] as List<dynamic>?)?.length ?? 0;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 14),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Banner Image Preview
                        Stack(
                          children: [
                            AspectRatio(
                              aspectRatio: 16 / 9,
                              child: img.isNotEmpty
                                  ? Image.network(
                                      img,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => Container(
                                        color: Colors.grey.shade100,
                                        child: const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                                      ),
                                    )
                                  : Container(color: Colors.grey.shade100),
                            ),
                            // Order Badge
                            Positioned(
                              top: 8,
                              left: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Order #${b['displayOrder'] ?? 0}',
                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            // Active Switch
                            Positioned(
                              top: 8,
                              right: 8,
                              child: InkWell(
                                onTap: () => _toggleActive(b['id'], active),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: active ? Colors.green.shade700 : Colors.grey.shade700,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    active ? 'Active' : 'Hidden',
                                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Content
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  _buildAudienceBadge(b['audienceType'] ?? 'ALL_BUYERS', buyerCount),
                                  const Spacer(),
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF0284C7)),
                                    onPressed: () => _openBannerForm(banner: b),
                                    constraints: const BoxConstraints(),
                                    padding: const EdgeInsets.all(4),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                    onPressed: () => _deleteBanner(b['id'], b['title'] ?? ''),
                                    constraints: const BoxConstraints(),
                                    padding: const EdgeInsets.all(4),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                b['title'] ?? '',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              if ((b['subtitle'] ?? '').toString().isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  b['subtitle'],
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                ),
                              ],
                              if ((b['actionUrl'] ?? '').toString().isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  'Link: ${b['actionUrl']}',
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF0284C7), fontFamily: 'monospace'),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _BannerFormModal extends ConsumerStatefulWidget {
  final Map<String, dynamic>? banner;
  final List<dynamic> allBuyers;
  final VoidCallback onSaved;

  const _BannerFormModal({this.banner, required this.allBuyers, required this.onSaved});

  @override
  ConsumerState<_BannerFormModal> createState() => _BannerFormModalState();
}

class _BannerFormModalState extends ConsumerState<_BannerFormModal> {
  final _titleController = TextEditingController();
  final _subtitleController = TextEditingController();
  final _imgController = TextEditingController();
  final _actionController = TextEditingController();
  final _orderController = TextEditingController(text: '1');
  String _audienceType = 'ALL_BUYERS';
  List<String> _selectedBuyerIds = [];
  bool _isActive = true;
  bool _isSaving = false;
  String _buyerSearch = '';
  bool _isUploadingImage = false;
  bool _showManualUrl = false;

  @override
  void initState() {
    super.initState();
    if (widget.banner != null) {
      _titleController.text = widget.banner!['title'] ?? '';
      _subtitleController.text = widget.banner!['subtitle'] ?? '';
      _imgController.text = widget.banner!['imageUrl'] ?? '';
      _actionController.text = widget.banner!['actionUrl'] ?? '';
      _orderController.text = '${widget.banner!['displayOrder'] ?? 1}';
      _audienceType = widget.banner!['audienceType'] ?? 'ALL_BUYERS';
      _selectedBuyerIds = List<String>.from(widget.banner!['selectedBuyerIds'] ?? []);
      _isActive = widget.banner!['isActive'] ?? true;
    }
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
      );

      if (result.isEmpty) return;

      final picked = result.first;
      setState(() => _isUploadingImage = true);

      final api = ref.read(apiClientProvider);
      MultipartFile multipartFile;
      if (picked.path != null) {
        multipartFile = await MultipartFile.fromFile(picked.path!, filename: picked.name);
      } else {
        final fileBytes = await picked.readAsBytes();
        multipartFile = MultipartFile.fromBytes(fileBytes, filename: picked.name);
      }

      final formData = FormData.fromMap({
        'file': multipartFile,
      });

      final res = await api.dio.post('/upload', data: formData);
      final data = res.data['data'] ?? res.data;
      final uploadedUrl = (data['url'] ?? data['relativePath'] ?? '').toString();

      if (uploadedUrl.isNotEmpty) {
        setState(() {
          _imgController.text = uploadedUrl;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Banner image uploaded successfully!'),
              backgroundColor: Color(0xFF0284C7),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingImage = false);
      }
    }
  }

  String _resolveImageUrl(String rawUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.startsWith('/')) {
      final api = ref.read(apiClientProvider);
      var base = api.dio.options.baseUrl;
      if (base.endsWith('/api/v1')) base = base.substring(0, base.length - 7);
      return '$base$trimmed';
    }
    return trimmed;
  }

  Future<void> _submit() async {
    if (_titleController.text.trim().isEmpty || _imgController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter Title and upload Banner Image')),
      );
      return;
    }

    if ((_audienceType == 'SPECIFIC_BUYERS' || _audienceType == 'EXCLUDE_BUYERS') && _selectedBuyerIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one buyer for this audience')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final api = ref.read(apiClientProvider);
      final payload = {
        'title': _titleController.text.trim(),
        'subtitle': _subtitleController.text.trim(),
        'imageUrl': _imgController.text.trim(),
        'actionUrl': _actionController.text.trim(),
        'audienceType': _audienceType,
        'selectedBuyerIds': _selectedBuyerIds,
        'displayOrder': int.tryParse(_orderController.text) ?? 1,
        'isActive': _isActive,
      };

      if (widget.banner != null) {
        await api.dio.put('/banners/${widget.banner!['id']}', data: payload);
      } else {
        await api.dio.post('/banners', data: payload);
      }

      widget.onSaved();
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save banner: $e')),
        );
      }
    }
  }

  void _openBuyerPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final filtered = widget.allBuyers.where((b) {
            final q = _buyerSearch.toLowerCase().trim();
            final name = (b['user']?['fullName'] ?? b['fullName'] ?? '').toString().toLowerCase();
            final bName = (b['businessName'] ?? '').toString().toLowerCase();
            final phone = (b['user']?['phone'] ?? b['phone'] ?? '').toString().toLowerCase();
            return q.isEmpty || name.contains(q) || bName.contains(q) || phone.contains(q);
          }).toList();

          return Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _audienceType == 'SPECIFIC_BUYERS' ? 'Select Targeted Buyers' : 'Select Excluded Buyers',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                TextField(
                  onChanged: (val) {
                    setSheetState(() => _buyerSearch = val);
                  },
                  decoration: InputDecoration(
                    hintText: 'Search buyer name, phone, business...',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (ctx, idx) {
                      final b = filtered[idx];
                      final bId = b['id'] ?? '';
                      final isChecked = _selectedBuyerIds.contains(bId);
                      final name = b['user']?['fullName'] ?? b['fullName'] ?? 'Buyer';
                      final bName = b['businessName'] ?? name;
                      final phone = b['user']?['phone'] ?? b['phone'] ?? '';
                      final type = b['buyerType'] ?? 'CUSTOMER';

                      return CheckboxListTile(
                        value: isChecked,
                        activeColor: const Color(0xFF0284C7),
                        title: Text(bName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: Text('$name • $phone • $type', style: const TextStyle(fontSize: 11)),
                        onChanged: (val) {
                          setSheetState(() {
                            if (val == true) {
                              _selectedBuyerIds.add(bId);
                            } else {
                              _selectedBuyerIds.remove(bId);
                            }
                          });
                          setState(() {});
                        },
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

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.banner != null ? 'Edit Banner' : 'Create New Banner',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const Divider(),
          Expanded(
            child: ListView(
              children: [
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Banner Title *', hintText: 'e.g. Festival Special Offer'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _subtitleController,
                  decoration: const InputDecoration(labelText: 'Subtitle / Description', hintText: 'e.g. 20% off on all RO spares'),
                ),
                const SizedBox(height: 14),

                // Upload Image Section
                _buildImageSection(),
                const SizedBox(height: 14),

                TextField(
                  controller: _actionController,
                  decoration: const InputDecoration(labelText: 'Action / Deep Link', hintText: 'e.g. /cart, /category'),
                ),
                const SizedBox(height: 16),

                // Audience Selector
                const Text('Choose Audience *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: _audienceType,
                  isExpanded: true,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: audienceOptions.map((opt) {
                    return DropdownMenuItem(
                      value: opt['value'],
                      child: Text(opt['label']!, style: const TextStyle(fontSize: 13)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _audienceType = val);
                  },
                ),

                // If Option 6 or 7 chosen
                if (_audienceType == 'SPECIFIC_BUYERS' || _audienceType == 'EXCLUDE_BUYERS') ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _openBuyerPicker,
                    icon: const Icon(Icons.people_outline, size: 18),
                    label: Text(
                      _selectedBuyerIds.isEmpty
                          ? 'Select Buyers (${widget.allBuyers.length} available)'
                          : '${_selectedBuyerIds.length} buyers selected',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],

                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _orderController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Display Order', hintText: '1'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Active', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        value: _isActive,
                        activeTrackColor: const Color(0xFF0284C7),
                        onChanged: (val) => setState(() => _isActive = val),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: FilledButton(
              onPressed: _isSaving ? null : _submit,
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0284C7)),
              child: Text(
                _isSaving ? 'Saving...' : (widget.banner != null ? 'Update Banner' : 'Create Banner'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageSection() {
    final hasImage = _imgController.text.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Banner Creative Image *',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            TextButton(
              onPressed: () => setState(() => _showManualUrl = !_showManualUrl),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                _showManualUrl ? 'Hide URL' : 'Or paste URL',
                style: const TextStyle(fontSize: 11, color: Color(0xFF0284C7)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (_isUploadingImage)
          Container(
            height: 140,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFF0F9FF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFBAE6FD)),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Color(0xFF0284C7)),
                SizedBox(height: 12),
                Text(
                  'Uploading banner image to server...',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0369A1)),
                ),
                SizedBox(height: 4),
                Text(
                  'Please wait a moment',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          )
        else if (hasImage)
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade300),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                Stack(
                  children: [
                    Image.network(
                      _resolveImageUrl(_imgController.text),
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        height: 150,
                        width: double.infinity,
                        color: Colors.grey.shade100,
                        child: const Center(
                          child: Icon(Icons.broken_image_outlined, size: 40, color: Colors.grey),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF059669),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle, size: 12, color: Colors.white),
                            SizedBox(width: 4),
                            Text(
                              'Image Ready',
                              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickAndUploadImage,
                          icon: const Icon(Icons.photo_library_outlined, size: 16),
                          label: const Text('Change Image', style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0284C7),
                            side: const BorderSide(color: Color(0xFF0284C7)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                        tooltip: 'Remove Image',
                        onPressed: () => setState(() => _imgController.clear()),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else
          InkWell(
            onTap: _pickAndUploadImage,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFCBD5E1), style: BorderStyle.solid),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.cloud_upload_outlined, size: 32, color: Color(0xFF0284C7)),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Upload Banner Image',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap to choose JPG, PNG, WEBP from device',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Recommended: 16:9 or 2:1 widescreen ratio',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF1D4ED8)),
                    ),
                  ),
                ],
              ),
            ),
          ),

        if (_showManualUrl) ...[
          const SizedBox(height: 10),
          TextField(
            controller: _imgController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Direct Image URL (Manual)',
              hintText: 'https://... or /uploads/...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              prefixIcon: const Icon(Icons.link, size: 18),
            ),
          ),
        ],
      ],
    );
  }
}
