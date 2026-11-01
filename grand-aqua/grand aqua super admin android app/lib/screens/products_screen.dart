import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/auth_provider.dart';
import '../widgets/admin_drawer.dart';

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  List<dynamic> _products = [];
  List<dynamic> _categories = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedCategoryId = '';

  @override
  void initState() {
    super.initState();
    _fetchCategories();
    _fetchProducts();
  }

  Future<void> _fetchCategories() async {
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.dio.get('/products/categories');
      if (mounted) {
        setState(() {
          _categories = (res.data is List) ? res.data : (res.data['data'] ?? []);
        });
      }
    } catch (_) {}
  }

  Future<void> _showQuickCategoryDialog(
    BuildContext parentCtx, {
    Map<String, dynamic>? category,
    required Function(String newId) onSaved,
  }) async {
    final isEditing = category != null;
    final nameCtrl = TextEditingController(text: category?['name'] ?? '');
    final descCtrl = TextEditingController(text: category?['description'] ?? '');
    bool isSaving = false;

    await showDialog(
      context: parentCtx,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(isEditing ? 'Edit Category' : 'Add New Category', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Category Name *', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  hintText: 'e.g. Industrial Softeners',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              const Text('Description (Optional)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              TextField(
                controller: descCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Category details...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: isSaving
                  ? null
                  : () async {
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty) return;

                      setDialogState(() => isSaving = true);
                      try {
                        final api = ref.read(apiClientProvider);
                        dynamic savedId = category?['id'];
                        if (isEditing) {
                          await api.dio.put('/products/categories/$savedId', data: {
                            'name': name,
                            'description': descCtrl.text.trim().isNotEmpty ? descCtrl.text.trim() : null,
                          });
                        } else {
                          final res = await api.dio.post('/products/categories', data: {
                            'name': name,
                            'description': descCtrl.text.trim().isNotEmpty ? descCtrl.text.trim() : null,
                          });
                          final data = res.data['data'] ?? res.data;
                          savedId = data['id'];
                        }
                        await _fetchCategories();
                        if (savedId != null) {
                          onSaved(savedId.toString());
                        }
                        if (context.mounted) {
                          Navigator.pop(ctx);
                        }
                      } catch (e) {
                        setDialogState(() => isSaving = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      }
                    },
              child: isSaving
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(isEditing ? 'Save' : 'Add Category'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _fetchProducts() async {
    setState(() => _isLoading = true);
    try {
      final api = ref.read(apiClientProvider);
      String url = '/products?limit=50';
      if (_searchQuery.isNotEmpty) {
        url += '&search=${Uri.encodeComponent(_searchQuery)}';
      }
      if (_selectedCategoryId.isNotEmpty) {
        url += '&categoryId=${Uri.encodeComponent(_selectedCategoryId)}';
      }
      final res = await api.dio.get(url);
      final data = res.data['data'] ?? res.data;
      if (mounted) {
        setState(() {
          _products = data['products'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showProductFormDialog({Map<String, dynamic>? product}) {
    final isEditing = product != null;
    final nameCtrl = TextEditingController(text: product?['name'] ?? '');
    final skuCtrl = TextEditingController(text: product?['sku'] ?? '');
    final brandCtrl = TextEditingController(text: product?['brand'] ?? 'Grand Aqua');
    final shortDescCtrl = TextEditingController(text: product?['shortDescription'] ?? '');
    final fullDescCtrl = TextEditingController(text: product?['fullDescription'] ?? '');
    final stockCtrl = TextEditingController(
      text: (product?['stockQuantity'] ?? product?['inventory']?['currentStock'] ?? 50).toString(),
    );
    bool isQtyPricingEnabled = product?['isQuantityPricingEnabled'] == true;
    List<Map<String, dynamic>> qtySlabs = [];
    if (product?['quantityPricingSlabs'] is List) {
      for (var s in (product!['quantityPricingSlabs'] as List)) {
        qtySlabs.add({
          'minQuantity': TextEditingController(text: (s['minQuantity'] ?? s['minQty'] ?? 1).toString()),
          'maxQuantity': TextEditingController(text: s['maxQuantity'] != null ? s['maxQuantity'].toString() : ''),
          'price': TextEditingController(text: (s['price'] ?? s['unitPrice'] ?? 0).toString()),
        });
      }
    }

    // Extract media
    final mediaList = (product?['media'] as List<dynamic>?) ?? [];
    String initialImage = '';
    String initialVideo = '';
    String initial3d = '';
    for (var m in mediaList) {
      if (m['mediaType'] == 'IMAGE' && initialImage.isEmpty) {
        initialImage = m['url'] ?? '';
      } else if (m['mediaType'] == 'VIDEO' && initialVideo.isEmpty) {
        initialVideo = m['url'] ?? '';
      } else if (m['mediaType'] == '3D_MODEL' && initial3d.isEmpty) {
        initial3d = m['url'] ?? '';
      }
    }

    final imageCtrl = TextEditingController(text: initialImage);
    final videoCtrl = TextEditingController(text: initialVideo);
    final model3dCtrl = TextEditingController(text: initial3d);

    bool isUploadingImage = false;
    bool isUploadingVideo = false;
    bool isUploading3d = false;

    // Helper for uploading image, video, or 3D files to /upload endpoint
    Future<void> pickAndUploadMedia(String type, StateSetter setDialogState) async {
      FileType fileType = FileType.image;
      List<String>? allowedExts;
      if (type == 'video') {
        fileType = FileType.video;
      } else if (type == '3d') {
        fileType = FileType.custom;
        allowedExts = ['glb', 'gltf', 'obj', 'stl'];
      }

      final result = await FilePicker.pickFiles(
        type: fileType,
        allowedExtensions: allowedExts,
      );

      if (result.isNotEmpty) {
        final picked = result.first;
        setDialogState(() {
          if (type == 'image') isUploadingImage = true;
          if (type == 'video') isUploadingVideo = true;
          if (type == '3d') isUploading3d = true;
        });

        try {
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

          setDialogState(() {
            if (type == 'image') imageCtrl.text = uploadedUrl;
            if (type == 'video') videoCtrl.text = uploadedUrl;
            if (type == '3d') model3dCtrl.text = uploadedUrl;
          });
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Upload failed: $e')),
            );
          }
        } finally {
          setDialogState(() {
            if (type == 'image') isUploadingImage = false;
            if (type == 'video') isUploadingVideo = false;
            if (type == '3d') isUploading3d = false;
          });
        }
      }
    }

    // 4-Tier prices
    final pricing = product?['pricing'] ?? {};
    final custPriceCtrl = TextEditingController(text: (pricing['customerPrice'] ?? 0).toString());
    final dealerPriceCtrl = TextEditingController(text: (pricing['dealerPrice'] ?? 0).toString());
    final wholePriceCtrl = TextEditingController(text: (pricing['wholesalerPrice'] ?? 0).toString());
    final distPriceCtrl = TextEditingController(text: (pricing['distributorPrice'] ?? 0).toString());
    final purchasePriceCtrl = TextEditingController(text: (product?['purchasePrice'] ?? pricing['purchasePrice'] ?? 0).toString());

    String selectedCatId = product?['categoryId'] ??
        (_categories.isNotEmpty ? _categories.first['id'] : '');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(
                isEditing ? Icons.edit_note : Icons.add_box_outlined,
                color: const Color(0xFF0284C7),
              ),
              const SizedBox(width: 8),
              Text(
                isEditing ? 'Edit Product' : 'Add New Product',
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
                  const Text(
                    'BASIC INFORMATION',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Product Name *',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Category *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          InkWell(
                            onTap: () async {
                              await _showQuickCategoryDialog(
                                context,
                                onSaved: (newCatId) {
                                  setDialogState(() {
                                    selectedCatId = newCatId;
                                  });
                                },
                              );
                              setDialogState(() {});
                            },
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              child: Row(
                                children: [
                                  Icon(Icons.add_circle_outline, size: 14, color: Color(0xFF0284C7)),
                                  SizedBox(width: 3),
                                  Text('New Category', style: TextStyle(fontSize: 11, color: Color(0xFF0284C7), fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                          if (selectedCatId.isNotEmpty) ...[
                            const Text(' | ', style: TextStyle(color: Colors.grey)),
                            InkWell(
                              onTap: () async {
                                final currentCat = _categories.firstWhere(
                                  (c) => c['id'] == selectedCatId,
                                  orElse: () => null,
                                );
                                if (currentCat != null) {
                                  await _showQuickCategoryDialog(
                                    context,
                                    category: currentCat,
                                    onSaved: (catId) {
                                      setDialogState(() {});
                                    },
                                  );
                                  setDialogState(() {});
                                }
                              },
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                child: Row(
                                  children: [
                                    Icon(Icons.edit_outlined, size: 13, color: Colors.blueGrey),
                                    SizedBox(width: 2),
                                    Text('Edit', style: TextStyle(fontSize: 11, color: Colors.blueGrey, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    value: selectedCatId.isNotEmpty ? selectedCatId : null,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                      hintText: 'Select Category',
                    ),
                    items: _categories.map<DropdownMenuItem<String>>((c) {
                      return DropdownMenuItem<String>(
                        value: c['id'],
                        child: Text(c['name'] ?? 'Category'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedCatId = val);
                    },
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: skuCtrl,
                          decoration: const InputDecoration(
                            labelText: 'SKU (Optional)',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: stockCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Number of Stocks *',
                            hintText: 'e.g. 50',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: shortDescCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Short Description',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: fullDescCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Full Description / Specs',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),

                  const SizedBox(height: 16),
                  const Text(
                    'PRODUCT MEDIA UPLOAD (IMAGE, VIDEO, 3D)',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                  ),
                  const SizedBox(height: 8),

                  // 1. PRODUCT IMAGE UPLOAD
                  _buildMediaUploadTile(
                    label: 'Product Image',
                    hintText: 'Upload image (PNG, JPG, WebP)',
                    icon: Icons.image_outlined,
                    url: imageCtrl.text,
                    isUploading: isUploadingImage,
                    onPick: () => pickAndUploadMedia('image', setDialogState),
                    onClear: () => setDialogState(() => imageCtrl.clear()),
                    onPreview: imageCtrl.text.isNotEmpty
                        ? () => _showSingleMediaPreview('Product Image Preview', 'image', imageCtrl.text)
                        : null,
                  ),

                  const SizedBox(height: 10),

                  // 2. PRODUCT VIDEO UPLOAD
                  _buildMediaUploadTile(
                    label: 'Product Video',
                    hintText: 'Upload video (MP4, WebM)',
                    icon: Icons.videocam_outlined,
                    url: videoCtrl.text,
                    isUploading: isUploadingVideo,
                    onPick: () => pickAndUploadMedia('video', setDialogState),
                    onClear: () => setDialogState(() => videoCtrl.clear()),
                    onPreview: videoCtrl.text.isNotEmpty
                        ? () => _showSingleMediaPreview('Product Video Preview', 'video', videoCtrl.text)
                        : null,
                  ),

                  const SizedBox(height: 10),

                  // 3. PRODUCT 3D VIEW UPLOAD
                  _buildMediaUploadTile(
                    label: 'Product 3D Model',
                    hintText: 'Upload 3D model (.GLB, .GLTF, .OBJ)',
                    icon: Icons.view_in_ar_outlined,
                    url: model3dCtrl.text,
                    isUploading: isUploading3d,
                    onPick: () => pickAndUploadMedia('3d', setDialogState),
                    onClear: () => setDialogState(() => model3dCtrl.clear()),
                    onPreview: model3dCtrl.text.isNotEmpty
                        ? () => _showSingleMediaPreview('Product 3D Model Preview', '3d', model3dCtrl.text)
                        : null,
                  ),

                  const SizedBox(height: 16),
                  const Text(
                    'INDEPENDENT 4-TIER PRICING (₹)',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: custPriceCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: '1. Customer Price',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: dealerPriceCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: '2. Dealer Price',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: wholePriceCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: '3. Wholesaler Price',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: distPriceCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: '4. Distributor Price',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Purchase / Cost Price (₹)',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('Super Admin Confidential', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFFB45309))),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: purchasePriceCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            hintText: 'Enter purchase cost price',
                            border: OutlineInputBorder(),
                            isDense: true,
                            fillColor: Colors.white,
                            filled: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // QUANTITY-BASED DYNAMIC PRICING SECTION
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.layers_outlined, size: 18, color: Color(0xFF15803D)),
                                const SizedBox(width: 6),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Price Based on Quantity',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                                    ),
                                    Text(
                                      isQtyPricingEnabled ? 'Turned ON (Active)' : 'Turned OFF (Disabled)',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: isQtyPricingEnabled ? const Color(0xFF16A34A) : Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Switch(
                              value: isQtyPricingEnabled,
                              activeColor: const Color(0xFF16A34A),
                              onChanged: (val) {
                                setDialogState(() {
                                  isQtyPricingEnabled = val;
                                  if (val && qtySlabs.isEmpty) {
                                    qtySlabs.add({
                                      'minQuantity': TextEditingController(text: '10'),
                                      'maxQuantity': TextEditingController(text: ''),
                                      'price': TextEditingController(text: custPriceCtrl.text),
                                    });
                                  }
                                });
                              },
                            ),
                          ],
                        ),
                        if (isQtyPricingEnabled) ...[
                          const SizedBox(height: 10),
                          const Text(
                            'Customized Volume Tiers & Prices:',
                            style: TextStyle(fontSize: 10, color: Color(0xFF166534), fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          if (qtySlabs.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.0),
                              child: Text('No slabs added yet. Tap "+ Add Quantity Tier" below.', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            )
                          else
                            ...qtySlabs.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final slab = entry.value;
                              final minCtrl = slab['minQuantity'] as TextEditingController;
                              final maxCtrl = slab['maxQuantity'] as TextEditingController;
                              final priceCtrl = slab['price'] as TextEditingController;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.green.shade200),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: TextField(
                                        controller: minCtrl,
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                          labelText: 'Min Qty',
                                          isDense: true,
                                          border: OutlineInputBorder(),
                                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                        ),
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      flex: 3,
                                      child: TextField(
                                        controller: maxCtrl,
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                          labelText: 'Max Qty',
                                          hintText: 'and above',
                                          isDense: true,
                                          border: OutlineInputBorder(),
                                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                        ),
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      flex: 4,
                                      child: TextField(
                                        controller: priceCtrl,
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                          labelText: 'Price (₹)',
                                          isDense: true,
                                          border: OutlineInputBorder(),
                                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                        ),
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () {
                                        setDialogState(() {
                                          qtySlabs.removeAt(idx);
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              );
                            }),
                          const SizedBox(height: 4),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () {
                                setDialogState(() {
                                  int nextMin = 10;
                                  if (qtySlabs.isNotEmpty) {
                                    final last = qtySlabs.last;
                                    final lastMax = int.tryParse((last['maxQuantity'] as TextEditingController).text);
                                    final lastMin = int.tryParse((last['minQuantity'] as TextEditingController).text) ?? 10;
                                    nextMin = (lastMax != null && lastMax >= lastMin) ? lastMax + 1 : lastMin + 20;
                                  }
                                  qtySlabs.add({
                                    'minQuantity': TextEditingController(text: nextMin.toString()),
                                    'maxQuantity': TextEditingController(text: ''),
                                    'price': TextEditingController(text: '0'),
                                  });
                                });
                              },
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Add Quantity Tier', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF15803D),
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                          ),
                        ] else ...[
                          const SizedBox(height: 6),
                          const Text(
                            'Volume-based pricing is turned OFF. Standard 4-tier pricing applies to all orders.',
                            style: TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                        ],
                      ],
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
                if (nameCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Product name is required!')),
                  );
                  return;
                }
                if (selectedCatId.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please select a category!')),
                  );
                  return;
                }

                final slabsPayload = isQtyPricingEnabled
                    ? qtySlabs.map((s) {
                        final minQ = int.tryParse((s['minQuantity'] as TextEditingController).text.trim()) ?? 1;
                        final maxText = (s['maxQuantity'] as TextEditingController).text.trim();
                        final maxQ = maxText.isNotEmpty ? int.tryParse(maxText) : null;
                        final p = double.tryParse((s['price'] as TextEditingController).text.trim()) ?? 0.0;
                        return {
                          'minQuantity': minQ,
                          'maxQuantity': maxQ,
                          'price': p,
                        };
                      }).where((s) => (s['price'] as double) > 0).toList()
                    : [];

                final payload = {
                  'name': nameCtrl.text.trim(),
                  'sku': skuCtrl.text.trim().isNotEmpty ? skuCtrl.text.trim() : null,
                  'categoryId': selectedCatId,
                  'brand': brandCtrl.text.trim(),
                  'shortDescription': shortDescCtrl.text.trim(),
                  'fullDescription': fullDescCtrl.text.trim(),
                  'stock': int.tryParse(stockCtrl.text.trim()) ?? 50,
                  'stockQuantity': int.tryParse(stockCtrl.text.trim()) ?? 50,
                  'isQuantityPricingEnabled': isQtyPricingEnabled,
                  'quantityPricingSlabs': slabsPayload,
                  'imageUrl': imageCtrl.text.trim().isNotEmpty ? imageCtrl.text.trim() : null,
                  'videoUrl': videoCtrl.text.trim().isNotEmpty ? videoCtrl.text.trim() : null,
                  'model3dUrl': model3dCtrl.text.trim().isNotEmpty ? model3dCtrl.text.trim() : null,
                  'customerPrice': double.tryParse(custPriceCtrl.text.trim()) ?? 0.0,
                  'dealerPrice': double.tryParse(dealerPriceCtrl.text.trim()) ?? 0.0,
                  'wholesalerPrice': double.tryParse(wholePriceCtrl.text.trim()) ?? 0.0,
                  'distributorPrice': double.tryParse(distPriceCtrl.text.trim()) ?? 0.0,
                  'purchasePrice': double.tryParse(purchasePriceCtrl.text.trim()) ?? 0.0,
                };

                try {
                  final api = ref.read(apiClientProvider);
                  if (isEditing) {
                    await api.dio.put('/products/${product['id']}', data: payload);
                  } else {
                    await api.dio.post('/products', data: payload);
                  }

                  if (mounted && ctx.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isEditing ? 'Product updated successfully!' : 'Product created successfully!',
                        ),
                      ),
                    );
                    _fetchProducts();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error saving product: $e')),
                    );
                  }
                }
              },
              child: Text(isEditing ? 'Update' : 'Create'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchExternalUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open: $url')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open link: $e')),
        );
      }
    }
  }

  Widget _buildMediaTabButton({
    required IconData icon,
    required String label,
    required bool isSelected,
    required bool hasBadge,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? const Color(0xFF0284C7) : Colors.grey.shade600,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? const Color(0xFF0284C7) : Colors.grey.shade700,
              ),
            ),
            if (hasBadge) ...[
              const SizedBox(width: 4),
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Color(0xFF10B981),
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreviewContent(String? url) {
    if (url == null || url.isEmpty) {
      return Container(
        height: 240,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_not_supported_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text(
              'No product image uploaded yet',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 250,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 4.0,
              child: Image.network(
                url,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                },
                errorBuilder: (context, error, stackTrace) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.broken_image, size: 40, color: Colors.grey),
                      const SizedBox(height: 6),
                      Text('Failed to load image', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.pinch, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  'Pinch / drag to zoom & pan',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
            OutlinedButton.icon(
              onPressed: () => _launchExternalUrl(url),
              icon: const Icon(Icons.open_in_browser, size: 14),
              label: const Text('Open in Browser', style: TextStyle(fontSize: 11)),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildVideoPreviewContent(String? url) {
    if (url == null || url.isEmpty) {
      return Container(
        height: 240,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.videocam_off_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text(
              'No product video uploaded yet',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    final filename = url.split('/').last;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Cinematic video card
        Container(
          height: 190,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 8,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _launchExternalUrl(url),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: Colors.red.shade600,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.shade900.withOpacity(0.4),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: const Icon(Icons.play_arrow_rounded, size: 38, color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      filename,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'MP4 / WebM • Tap to Stream',
                        style: TextStyle(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _launchExternalUrl(url),
                icon: const Icon(Icons.play_circle_fill, size: 18),
                label: const Text('Play Video'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () => _launchExternalUrl(url),
              icon: const Icon(Icons.open_in_browser, size: 16),
              label: const Text('Open URL'),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Video will launch directly in your device media player or browser.',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _build3dPreviewContent(String? url) {
    if (url == null || url.isEmpty) {
      return Container(
        height: 240,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.view_in_ar_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text(
              'No 3D model (.glb/.gltf) uploaded yet',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    final filename = url.split('/').last;
    final interactiveViewerUrl = 'https://modelviewer.dev/editor/?url=${Uri.encodeComponent(url)}';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 3D holographic card
        Container(
          height: 190,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1E1B4B), Color(0xFF312E81)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.purple.shade900.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _launchExternalUrl(interactiveViewerUrl),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: const Color(0xFF9333EA),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.purple.shade900.withOpacity(0.5),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: const Icon(Icons.threed_rotation, size: 34, color: Colors.white),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      filename,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        '.GLB / .GLTF • 360° & AR Ready',
                        style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _launchExternalUrl(interactiveViewerUrl),
                icon: const Icon(Icons.view_in_ar, size: 18),
                label: const Text('Interactive 3D / AR View'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () => _launchExternalUrl(url),
              icon: const Icon(Icons.download_outlined, size: 16),
              label: const Text('Direct File'),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Interactive 3D Viewer features 360° orbital rotation, zoom, lighting adjustment, and AR camera view.',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  void _showSingleMediaPreview(String title, String type, String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480),
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (type == 'image')
                _buildImagePreviewContent(url)
              else if (type == 'video')
                _buildVideoPreviewContent(url)
              else
                _build3dPreviewContent(url),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMediaViewer(Map<String, dynamic> product) {
    final mediaList = (product['media'] as List<dynamic>?) ?? [];
    String? imgUrl;
    String? videoUrl;
    String? model3dUrl;

    for (var m in mediaList) {
      if (m['mediaType'] == 'IMAGE' && imgUrl == null) imgUrl = m['url'];
      if (m['mediaType'] == 'VIDEO' && videoUrl == null) videoUrl = m['url'];
      if (m['mediaType'] == '3D_MODEL' && model3dUrl == null) model3dUrl = m['url'];
    }

    int activeIndex = 0;
    if (imgUrl != null && imgUrl.isNotEmpty) {
      activeIndex = 0;
    } else if (videoUrl != null && videoUrl.isNotEmpty) {
      activeIndex = 1;
    } else if (model3dUrl != null && model3dUrl.isNotEmpty) {
      activeIndex = 2;
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 480, maxHeight: 620),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 16, 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  product['name'] ?? 'Product Media & 3D Preview',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'SKU: ${product['sku'] ?? 'N/A'} • ${product['brand'] ?? 'Grand Aqua'}',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(ctx),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                    ),

                    // Segmented Tabs
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.all(4),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildMediaTabButton(
                                icon: Icons.image_outlined,
                                label: 'Image',
                                isSelected: activeIndex == 0,
                                hasBadge: imgUrl != null && imgUrl.isNotEmpty,
                                onTap: () => setModalState(() => activeIndex = 0),
                              ),
                            ),
                            Expanded(
                              child: _buildMediaTabButton(
                                icon: Icons.videocam_outlined,
                                label: 'Video',
                                isSelected: activeIndex == 1,
                                hasBadge: videoUrl != null && videoUrl.isNotEmpty,
                                onTap: () => setModalState(() => activeIndex = 1),
                              ),
                            ),
                            Expanded(
                              child: _buildMediaTabButton(
                                icon: Icons.view_in_ar_outlined,
                                label: '3D View',
                                isSelected: activeIndex == 2,
                                hasBadge: model3dUrl != null && model3dUrl.isNotEmpty,
                                onTap: () => setModalState(() => activeIndex = 2),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Content Area
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: activeIndex == 0
                            ? _buildImagePreviewContent(imgUrl)
                            : activeIndex == 1
                                ? _buildVideoPreviewContent(videoUrl)
                                : _build3dPreviewContent(model3dUrl),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Bottom Action Bar
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF0284C7),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showDeleteConfirmDialog(String productId, String productName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Product?'),
        content: Text(
          'Are you sure you want to permanently delete "$productName"? All pricing, media, and inventory records will be removed.',
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
                await api.dio.delete('/products/$productId');
                if (mounted && ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Product deleted successfully!')),
                  );
                  _fetchProducts();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete product: $e')),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Product Management', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            Text('Catalog, Media & 4-Tier Pricing', style: TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
        backgroundColor: const Color(0xFF0284C7),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _fetchCategories();
              _fetchProducts();
            },
          ),
        ],
      ),
      drawer: const AdminDrawer(currentRoute: '/products'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showProductFormDialog(),
        backgroundColor: const Color(0xFF0284C7),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Product', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // Search & Filter Box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: Column(
              children: [
                TextField(
                  onChanged: (val) {
                    _searchQuery = val.trim();
                    _fetchProducts();
                  },
                  decoration: InputDecoration(
                    hintText: 'Search SKU, name...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                if (_categories.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 6.0),
                          child: ChoiceChip(
                            label: const Text('All Categories'),
                            selected: _selectedCategoryId.isEmpty,
                            onSelected: (_) {
                              setState(() => _selectedCategoryId = '');
                              _fetchProducts();
                            },
                          ),
                        ),
                        ..._categories.map((c) {
                          final isSelected = _selectedCategoryId == c['id'];
                          return Padding(
                            padding: const EdgeInsets.only(right: 6.0),
                            child: ChoiceChip(
                              label: Text(c['name'] ?? ''),
                              selected: isSelected,
                              onSelected: (_) {
                                setState(() => _selectedCategoryId = isSelected ? '' : c['id']);
                                _fetchProducts();
                              },
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Product List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _products.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            const Text(
                              'No products found',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Tap "+ Add Product" to register purifiers or spare parts.',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _fetchProducts,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                          itemCount: _products.length,
                          itemBuilder: (context, index) {
                            final prod = _products[index];
                            final pricing = prod['pricing'] ?? {};
                            final mediaList = (prod['media'] as List<dynamic>?) ?? [];
                            final has3d = mediaList.any((m) => m['mediaType'] == '3D_MODEL');
                            final hasVideo = mediaList.any((m) => m['mediaType'] == 'VIDEO');
                            final imgObj = mediaList.firstWhere(
                              (m) => m['mediaType'] == 'IMAGE',
                              orElse: () => null,
                            );
                            final imgUrl = imgObj?['url'];

                            return Card(
                              margin: const EdgeInsets.only(bottom: 14),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(color: Colors.grey.shade200),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Header: Thumbnail, SKU & Name
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Product Image Thumbnail
                                        Container(
                                          width: 60,
                                          height: 60,
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade100,
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: Colors.grey.shade300),
                                          ),
                                          child: imgUrl != null && imgUrl.isNotEmpty
                                              ? ClipRRect(
                                                  borderRadius: BorderRadius.circular(10),
                                                  child: Image.network(
                                                    imgUrl,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (context, error, stackTrace) => const Icon(
                                                      Icons.water_drop,
                                                      color: Color(0xFF0284C7),
                                                    ),
                                                  ),
                                                )
                                              : const Icon(Icons.water_drop, color: Color(0xFF0284C7)),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: Colors.grey.shade900,
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(
                                                      prod['sku'] ?? 'NO-SKU',
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 9,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  if (has3d)
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                      decoration: BoxDecoration(
                                                        color: Colors.purple.shade100,
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: Text(
                                                        '3D',
                                                        style: TextStyle(
                                                          color: Colors.purple.shade900,
                                                          fontSize: 9,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                  if (hasVideo) ...[
                                                    const SizedBox(width: 4),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                      decoration: BoxDecoration(
                                                        color: Colors.red.shade100,
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: Text(
                                                        'VIDEO',
                                                        style: TextStyle(
                                                          color: Colors.red.shade900,
                                                          fontSize: 9,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                prod['name'] ?? '',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              Text(
                                                prod['category']?['name'] ?? 'General Purifier',
                                                style: const TextStyle(fontSize: 11, color: Color(0xFF0284C7)),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 10),
                                    if (prod['shortDescription'] != null &&
                                        (prod['shortDescription'] as String).isNotEmpty)
                                      Text(
                                        prod['shortDescription'],
                                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),

                                    const SizedBox(height: 10),
                                    // 4-Tier Pricing Grid
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.grey.shade200),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            '4-TIER SELLING PRICES (EXCL. 18% GST)',
                                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey),
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              _buildPriceItem(
                                                'Customer',
                                                '₹${pricing['customerPrice'] ?? 0}',
                                                Colors.black87,
                                              ),
                                              _buildPriceItem(
                                                'Dealer',
                                                '₹${pricing['dealerPrice'] ?? 0}',
                                                Colors.teal.shade800,
                                              ),
                                              _buildPriceItem(
                                                'Wholesaler',
                                                '₹${pricing['wholesalerPrice'] ?? 0}',
                                                Colors.cyan.shade800,
                                              ),
                                              _buildPriceItem(
                                                'Distributor',
                                                '₹${pricing['distributorPrice'] ?? 0}',
                                                const Color(0xFF0284C7),
                                              ),
                                              _buildPriceItem(
                                                'Purchase Cost',
                                                '₹${prod['purchasePrice'] ?? pricing['purchasePrice'] ?? 0}',
                                                Colors.amber.shade900,
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),

                                    const SizedBox(height: 8),

                                    // Volume / Quantity Pricing Container on Card
                                    Builder(
                                      builder: (ctx) {
                                        final isQtyOn = prod['isQuantityPricingEnabled'] == true;
                                        final slabs = (prod['quantityPricingSlabs'] as List<dynamic>?) ?? [];

                                        if (isQtyOn && slabs.isNotEmpty) {
                                          return Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF0FDF4),
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(color: const Color(0xFFBBF7D0)),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Row(
                                                      children: const [
                                                        Icon(Icons.auto_awesome, size: 12, color: Color(0xFF16A34A)),
                                                        SizedBox(width: 4),
                                                        Text(
                                                          'QTY-BASED PRICING (ON)',
                                                          style: TextStyle(
                                                            fontSize: 9,
                                                            fontWeight: FontWeight.bold,
                                                            color: Color(0xFF15803D),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFFDCFCE7),
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: Text(
                                                        '${slabs.length} Tier${slabs.length > 1 ? 's' : ''}',
                                                        style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Color(0xFF166534)),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Wrap(
                                                  spacing: 6,
                                                  runSpacing: 4,
                                                  children: slabs.take(3).map((s) {
                                                    final minQ = s['minQuantity'] ?? s['minQty'] ?? 1;
                                                    final maxQ = s['maxQuantity'];
                                                    final p = s['price'] ?? s['unitPrice'] ?? 0;
                                                    final qRange = maxQ != null ? '$minQ-$maxQ' : '$minQ+';
                                                    return Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: Colors.white,
                                                        borderRadius: BorderRadius.circular(4),
                                                        border: Border.all(color: Colors.green.shade200),
                                                      ),
                                                      child: Text(
                                                        '$qRange pcs: ₹$p',
                                                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF166534)),
                                                      ),
                                                    );
                                                  }).toList(),
                                                ),
                                              ],
                                            ),
                                          );
                                        } else {
                                          return Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade50,
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: Colors.grey.shade200),
                                            ),
                                            child: Row(
                                              children: const [
                                                Icon(Icons.circle, size: 6, color: Colors.grey),
                                                SizedBox(width: 4),
                                                Text(
                                                  'Qty-Based Pricing: Disabled (Base tiers apply)',
                                                  style: TextStyle(fontSize: 9, color: Colors.grey),
                                                ),
                                              ],
                                            ),
                                          );
                                        }
                                      },
                                    ),

                                    const SizedBox(height: 8),

                                    // Stock Quantity & Warranty Row
                                    Builder(
                                      builder: (ctx) {
                                        final stock = (prod['stockQuantity'] ?? prod['inventory']?['currentStock'] ?? 0);
                                        final intStock = stock is int ? stock : int.tryParse(stock.toString()) ?? 0;
                                        final isOutOfStock = intStock <= 0;
                                        final isLowStock = intStock > 0 && intStock <= 10;

                                        return Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                const Icon(Icons.inventory_2_outlined, size: 14, color: Colors.grey),
                                                const SizedBox(width: 4),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: isOutOfStock
                                                        ? Colors.red.shade50
                                                        : isLowStock
                                                        ? Colors.amber.shade50
                                                        : Colors.green.shade50,
                                                    borderRadius: BorderRadius.circular(6),
                                                    border: Border.all(
                                                      color: isOutOfStock
                                                          ? Colors.red.shade200
                                                          : isLowStock
                                                          ? Colors.amber.shade200
                                                          : Colors.green.shade200,
                                                    ),
                                                  ),
                                                  child: Text(
                                                    isOutOfStock
                                                        ? 'Out of Stock (0 Units)'
                                                        : isLowStock
                                                        ? 'Low Stock: $intStock Units'
                                                        : 'In Stock: $intStock Units',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                      color: isOutOfStock
                                                          ? Colors.red.shade900
                                                          : isLowStock
                                                          ? Colors.amber.shade900
                                                          : Colors.green.shade900,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Text(
                                              prod['warrantyDetails'] != null ? '1 Yr Warranty' : 'Manufacturer Warranty',
                                              style: const TextStyle(fontSize: 10, color: Colors.grey),
                                            ),
                                          ],
                                        );
                                      },
                                    ),

                                    const SizedBox(height: 8),
                                    // Action Buttons
                                    Row(
                                      children: [
                                        OutlinedButton.icon(
                                          onPressed: () => _showMediaViewer(prod),
                                          icon: const Icon(Icons.remove_red_eye, size: 14),
                                          label: const Text('Media & 3D', style: TextStyle(fontSize: 11)),
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                            visualDensity: VisualDensity.compact,
                                          ),
                                        ),
                                        const Spacer(),
                                        IconButton(
                                          icon: const Icon(Icons.edit, size: 18, color: Color(0xFF0284C7)),
                                          onPressed: () => _showProductFormDialog(product: prod),
                                          visualDensity: VisualDensity.compact,
                                          tooltip: 'Edit Product',
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                          onPressed: () => _showDeleteConfirmDialog(prod['id'], prod['name'] ?? 'Product'),
                                          visualDensity: VisualDensity.compact,
                                          tooltip: 'Delete Product',
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceItem(String label, String price, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey)),
        Text(
          price,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  Widget _buildMediaUploadTile({
    required String label,
    required String hintText,
    required IconData icon,
    required String url,
    required bool isUploading,
    required VoidCallback onPick,
    required VoidCallback onClear,
    VoidCallback? onPreview,
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
                label,
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
          const SizedBox(height: 6),
          if (isUploading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 10),
                  Text('Uploading file to server...', style: TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            )
          else if (hasFile)
            Row(
              children: [
                Expanded(
                  child: Text(
                    url.split('/').last,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF334155)),
                  ),
                ),
                if (onPreview != null)
                  IconButton(
                    icon: const Icon(Icons.remove_red_eye_outlined, size: 18, color: Color(0xFF0284C7)),
                    visualDensity: VisualDensity.compact,
                    onPressed: onPreview,
                    tooltip: 'Preview Media',
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
                label: Text(hintText, style: const TextStyle(fontSize: 11)),
              ),
            ),
        ],
      ),
    );
  }
}
