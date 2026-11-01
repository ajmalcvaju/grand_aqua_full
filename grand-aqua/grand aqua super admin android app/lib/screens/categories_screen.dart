import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/auth_provider.dart';
import '../widgets/admin_drawer.dart';

class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  bool _isLoading = true;
  List<dynamic> _categories = [];
  String _searchQuery = '';
  String _statusFilter = 'ALL'; // ALL, ACTIVE, INACTIVE

  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }

  Future<void> _fetchCategories() async {
    setState(() => _isLoading = true);
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.dio.get('/products/categories');
      final data = res.data['data'] ?? res.data;
      if (mounted) {
        setState(() {
          _categories = data is List ? data : [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load categories: $e')),
        );
      }
    }
  }

  void _showAddEditCategoryDialog([Map<String, dynamic>? category]) {
    final isEditing = category != null;
    final nameCtrl = TextEditingController(text: category?['name'] ?? '');
    final slugCtrl = TextEditingController(text: category?['slug'] ?? '');
    final descCtrl = TextEditingController(text: category?['description'] ?? '');
    bool isActive = category?['isActive'] ?? true;
    bool autoSlug = !isEditing;
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.category, color: Color(0xFF0284C7), size: 20),
                ),
                const SizedBox(width: 10),
                Text(
                  isEditing ? 'Edit Category' : 'Add New Category',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Category Name *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameCtrl,
                    onChanged: (val) {
                      if (autoSlug) {
                        final generated = val
                            .toLowerCase()
                            .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
                            .replaceAll(RegExp(r'(^-|-$)+'), '');
                        slugCtrl.text = generated;
                      }
                      setDialogState(() {});
                    },
                    decoration: InputDecoration(
                      hintText: 'e.g. Domestic RO, Water Softeners',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('URL Slug *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      InkWell(
                        onTap: () => setDialogState(() => autoSlug = !autoSlug),
                        child: Row(
                          children: [
                            Checkbox(
                              value: autoSlug,
                              onChanged: (v) => setDialogState(() => autoSlug = v ?? false),
                              visualDensity: VisualDensity.compact,
                            ),
                            const Text('Auto', style: TextStyle(fontSize: 11, color: Colors.blueGrey)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  TextField(
                    controller: slugCtrl,
                    enabled: !autoSlug,
                    decoration: InputDecoration(
                      hintText: 'e.g. domestic-ro',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      isDense: true,
                      filled: autoSlug,
                      fillColor: autoSlug ? Colors.grey.shade100 : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Description (Optional)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: descCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Brief description of product classification...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Active Status', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      isActive ? 'Visible in catalog & product filters' : 'Hidden from store',
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                    value: isActive,
                    activeColor: const Color(0xFF0284C7),
                    onChanged: (val) => setDialogState(() => isActive = val),
                  ),
                ],
              ),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: isSaving
                    ? null
                    : () async {
                        final name = nameCtrl.text.trim();
                        final slug = slugCtrl.text.trim();
                        final desc = descCtrl.text.trim();

                        if (name.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter category name.')),
                          );
                          return;
                        }

                        setDialogState(() => isSaving = true);
                        try {
                          final api = ref.read(apiClientProvider);
                          if (isEditing) {
                            await api.dio.put('/products/categories/${category['id']}', data: {
                              'name': name,
                              'slug': slug.isNotEmpty ? slug : null,
                              'description': desc.isNotEmpty ? desc : null,
                              'isActive': isActive,
                            });
                          } else {
                            await api.dio.post('/products/categories', data: {
                              'name': name,
                              'slug': slug.isNotEmpty ? slug : null,
                              'description': desc.isNotEmpty ? desc : null,
                              'isActive': isActive,
                            });
                          }

                          if (context.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(isEditing ? 'Category updated' : 'Category created')),
                            );
                            _fetchCategories();
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
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(isEditing ? 'Save Changes' : 'Create Category'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showDeleteCategoryDialog(Map<String, dynamic> category) {
    final int productCount = category['_count']?['products'] ?? 0;
    final catName = category['name'] ?? 'Category';
    final catId = category['id'];
    bool isDeleting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.delete_outline, color: Colors.red.shade700, size: 22),
              ),
              const SizedBox(width: 10),
              const Text('Delete Category', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Are you sure you want to delete "$catName"?', style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 10),
              if (productCount > 0)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Cannot delete! $productCount products are currently assigned to this category. Please reassign or delete those products first.',
                          style: TextStyle(fontSize: 11, color: Colors.red.shade800, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                )
              else
                const Text(
                  'This category has 0 assigned products and can be safely deleted.',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            if (productCount == 0)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: isDeleting
                    ? null
                    : () async {
                        setDialogState(() => isDeleting = true);
                        try {
                          final api = ref.read(apiClientProvider);
                          await api.dio.delete('/products/categories/$catId');
                          if (context.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Category deleted successfully')),
                            );
                            _fetchCategories();
                          }
                        } catch (e) {
                          setDialogState(() => isDeleting = false);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Delete failed: $e')),
                            );
                          }
                        }
                      },
                child: isDeleting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Confirm Delete'),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int totalCount = _categories.length;
    final int activeCount = _categories.where((c) => c['isActive'] == true).length;
    int totalProducts = 0;
    for (final c in _categories) {
      totalProducts += ((c['_count']?['products'] ?? 0) as num).toInt();
    }

    final filtered = _categories.where((cat) {
      final name = (cat['name'] ?? '').toString().toLowerCase();
      final slug = (cat['slug'] ?? '').toString().toLowerCase();
      final q = _searchQuery.toLowerCase();
      final matchesSearch = name.contains(q) || slug.contains(q);

      final isActive = cat['isActive'] ?? true;
      final matchesStatus = _statusFilter == 'ALL' ||
          (_statusFilter == 'ACTIVE' && isActive) ||
          (_statusFilter == 'INACTIVE' && !isActive);

      return matchesSearch && matchesStatus;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Category Management', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text('Catalog Hierarchy & Classifications', style: TextStyle(fontSize: 10, color: Colors.white70)),
          ],
        ),
        backgroundColor: const Color(0xFF0284C7),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchCategories,
          ),
        ],
      ),
      drawer: const AdminDrawer(currentRoute: '/categories'),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0284C7),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Category', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () => _showAddEditCategoryDialog(),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchCategories,
              child: ListView(
                padding: const EdgeInsets.all(14),
                children: [
                  // Summary Banner
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0369A1), Color(0xFF0284C7)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0284C7).withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            const Text('TOTAL', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            Text('$totalCount', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                            const Text('Categories', style: TextStyle(color: Colors.white70, fontSize: 10)),
                          ],
                        ),
                        Container(width: 1, height: 35, color: Colors.white24),
                        Column(
                          children: [
                            const Text('ACTIVE', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            Text('$activeCount', style: const TextStyle(color: Color(0xFFBBF7D0), fontSize: 20, fontWeight: FontWeight.bold)),
                            const Text('Live in catalog', style: TextStyle(color: Colors.white70, fontSize: 10)),
                          ],
                        ),
                        Container(width: 1, height: 35, color: Colors.white24),
                        Column(
                          children: [
                            const Text('PRODUCTS', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            Text('$totalProducts', style: const TextStyle(color: Color(0xFFFDE68A), fontSize: 20, fontWeight: FontWeight.bold)),
                            const Text('Assigned items', style: TextStyle(color: Colors.white70, fontSize: 10)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Search
                  TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: 'Search category name or slug...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade300)),
                      filled: true,
                      fillColor: Colors.white,
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['ALL', 'ACTIVE', 'INACTIVE'].map((status) {
                        final isSel = _statusFilter == status;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: Text(
                              status == 'ALL' ? 'All Categories' : status == 'ACTIVE' ? 'Active' : 'Inactive',
                              style: TextStyle(fontSize: 11, fontWeight: isSel ? FontWeight.bold : FontWeight.normal),
                            ),
                            selected: isSel,
                            selectedColor: const Color(0xFF0284C7).withOpacity(0.15),
                            onSelected: (_) => setState(() => _statusFilter = status),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 14),

                  if (filtered.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(40),
                      alignment: Alignment.center,
                      child: const Column(
                        children: [
                          Icon(Icons.category_outlined, size: 48, color: Colors.grey),
                          SizedBox(height: 8),
                          Text('No categories found.', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                  else
                    ...filtered.map((cat) {
                      final name = cat['name'] ?? 'Unnamed Category';
                      final slug = cat['slug'] ?? 'no-slug';
                      final desc = cat['description'] ?? 'No description provided';
                      final isActive = cat['isActive'] ?? true;
                      final count = cat['_count']?['products'] ?? 0;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
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
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0284C7).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Center(
                                      child: Text(
                                        name.isNotEmpty ? name[0].toUpperCase() : 'C',
                                        style: const TextStyle(color: Color(0xFF0284C7), fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))),
                                        const SizedBox(height: 2),
                                        Text('/$slug', style: const TextStyle(fontSize: 11, color: Color(0xFF0284C7), fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, size: 20, color: Color(0xFF0284C7)),
                                        onPressed: () => _showAddEditCategoryDialog(cat),
                                        tooltip: 'Edit Category',
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                        onPressed: () => _showDeleteCategoryDialog(cat),
                                        tooltip: 'Delete Category',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              if (desc.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(desc, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                              ],
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.inventory_2_outlined, size: 13, color: Colors.blueGrey),
                                        const SizedBox(width: 4),
                                        Text(
                                          '$count Products',
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isActive ? Colors.green.shade50 : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      isActive ? 'ACTIVE' : 'INACTIVE',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: isActive ? Colors.green.shade800 : Colors.grey.shade600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  const SizedBox(height: 70), // Padding for FAB
                ],
              ),
            ),
    );
  }
}
