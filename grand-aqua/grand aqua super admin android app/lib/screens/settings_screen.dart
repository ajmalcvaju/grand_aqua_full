import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/auth_provider.dart';
import '../widgets/admin_drawer.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  Map<String, dynamic> _settings = {};
  List<dynamic> _adminStaff = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchSettings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchSettings() async {
    setState(() => _isLoading = true);
    try {
      final api = ref.read(apiClientProvider);
      final sRes = await api.dio.get('/settings');
      final stRes = await api.dio.get('/settings/admin-staff');

      if (mounted) {
        setState(() {
          _settings = (sRes.data['data'] ?? sRes.data) as Map<String, dynamic>? ?? {};
          final stData = stRes.data['data'] ?? stRes.data;
          _adminStaff = stData is List ? stData : [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load settings: $e')),
        );
      }
    }
  }

  Widget _buildInfoField(String label, String value, {bool isMono = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
        const SizedBox(height: 5),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0F172A),
              fontFamily: isMono ? 'monospace' : null,
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('System Settings & Admin', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text('Enterprise Policies & Access Controls', style: TextStyle(fontSize: 10, color: Colors.white70)),
          ],
        ),
        backgroundColor: const Color(0xFF0284C7),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchSettings,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          tabs: const [
            Tab(icon: Icon(Icons.business, size: 18), text: 'Company Profile'),
            Tab(icon: Icon(Icons.security, size: 18), text: 'Admin Staff & Roles'),
          ],
        ),
      ),
      drawer: const AdminDrawer(currentRoute: '/settings'),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                // TAB 1: Company Profile
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 3)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.storefront, color: Color(0xFF0284C7)),
                              SizedBox(width: 8),
                              Text(
                                'Official Enterprise Identity',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                              ),
                            ],
                          ),
                          const Divider(height: 20),
                          _buildInfoField('Company Registered Name', _settings['COMPANY_NAME'] ?? 'Grand Aqua'),
                          _buildInfoField('Brand Tagline', _settings['COMPANY_TAGLINE'] ?? 'Pure | Safe | Healthy - Wholesale & Retail'),
                          _buildInfoField('GSTIN (18% Water Purifier Standard)', _settings['COMPANY_GSTIN'] ?? '07AAAAA0000A1Z5', isMono: true),
                          _buildInfoField('Operating Currency', 'INR (Indian Rupee - ₹)'),
                          _buildInfoField('Official Support Phone', _settings['COMPANY_PHONE'] ?? '+91 98765 43210'),
                          _buildInfoField('Official Support Email', _settings['COMPANY_EMAIL'] ?? 'support@grandaqua.com'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Server Info Card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 20),
                          SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Backend Engine Online', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF15803D))),
                                Text('NestJS Enterprise API connected via port 4000', style: TextStyle(fontSize: 10, color: Color(0xFF166534))),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // TAB 2: Administrative Staff & RBAC
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const Text(
                      'Authorized Administrative Staff Accounts',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Users with elevated administrative privileges across the Grand Aqua enterprise portal.',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    const SizedBox(height: 14),

                    if (_adminStaff.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(40),
                        alignment: Alignment.center,
                        child: const Text('No administrative staff records found.', style: TextStyle(color: Colors.grey)),
                      )
                    else
                      ..._adminStaff.map((staff) {
                        final fullName = staff['fullName'] ?? 'Admin';
                        final email = staff['email'] ?? 'admin@grandaqua.com';
                        final role = staff['role'] ?? 'SUPER_ADMIN';
                        final status = staff['status'] ?? 'ACTIVE';

                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(color: Colors.grey.shade200),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFF0284C7).withOpacity(0.12),
                              child: Text(
                                fullName.isNotEmpty ? fullName[0].toUpperCase() : 'A',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                              ),
                            ),
                            title: Text(fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(email, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0284C7).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        role,
                                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF0284C7), fontFamily: 'monospace'),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade50,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        status,
                                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.green.shade800),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ],
            ),
    );
  }
}
