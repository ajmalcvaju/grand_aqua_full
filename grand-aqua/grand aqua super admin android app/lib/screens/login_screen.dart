import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../core/auth_provider.dart';

class AdminLoginScreen extends ConsumerStatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  ConsumerState<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends ConsumerState<AdminLoginScreen> {
  final _emailCtrl = TextEditingController(text: 'admin@grandaqua.com');
  final _passCtrl = TextEditingController(text: 'GrandAqua@Admin2026');

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F172A), Color(0xFF0284C7), Color(0xFF0F172A)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Card(
                elevation: 12,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Official Grand Aqua Logo
                      Image.asset(
                        'assets/images/grand_aqua_logo.png',
                        width: 220,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Super Admin Portal',
                        style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 24),

                      if (authState.errorMessage != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Text(
                            authState.errorMessage!,
                            style: TextStyle(color: Colors.red.shade800, fontSize: 12),
                          ),
                        ),

                      TextField(
                        controller: _emailCtrl,
                        decoration: InputDecoration(
                          labelText: 'Admin Email or Username',
                          prefixIcon: const Icon(Icons.email_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _passCtrl,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                      ),
                      const SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: FilledButton(
                          onPressed: authState.isLoading
                              ? null
                              : () async {
                                  final success = await ref
                                      .read(authProvider.notifier)
                                      .login(_emailCtrl.text.trim(), _passCtrl.text.trim());
                                  if (success && mounted) {
                                    context.go('/dashboard');
                                  }
                                },
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF0284C7),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: authState.isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Text('Sign In to Admin Portal', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton.icon(
                        onPressed: () => _showServerSettingsDialog(context),
                        icon: const Icon(Icons.settings_ethernet, size: 16, color: Colors.grey),
                        label: const Text(
                          'Configure Server IP / URL',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
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

  void _showServerSettingsDialog(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final currentUrl = prefs.getString('custom_backend_url') ?? ApiClient.defaultUrl;
    final ctrl = TextEditingController(text: currentUrl);
    String? testStatus;
    bool isTesting = false;

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.settings_ethernet, color: Color(0xFF0284C7)),
              SizedBox(width: 8),
              Text('Backend Server URL', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter the backend API base URL:',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: ctrl,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  labelText: 'API Base URL',
                  hintText: 'http://192.168.29.44:4000/api/v1',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              const Text('Quick Presets:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  ActionChip(
                    label: const Text('Wi-Fi (192.168.29.44)', style: TextStyle(fontSize: 10)),
                    onPressed: () {
                      setDialogState(() {
                        ctrl.text = 'http://192.168.29.44:4000/api/v1';
                        testStatus = null;
                      });
                    },
                  ),
                  ActionChip(
                    label: const Text('Emulator (10.0.2.2)', style: TextStyle(fontSize: 10)),
                    onPressed: () {
                      setDialogState(() {
                        ctrl.text = 'http://10.0.2.2:4000/api/v1';
                        testStatus = null;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (testStatus != null)
                Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: testStatus!.startsWith('SUCCESS') ? Colors.green.shade50 : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: testStatus!.startsWith('SUCCESS') ? Colors.green.shade200 : Colors.red.shade200,
                    ),
                  ),
                  child: Text(
                    testStatus!,
                    style: TextStyle(
                      fontSize: 11,
                      color: testStatus!.startsWith('SUCCESS') ? Colors.green.shade800 : Colors.red.shade800,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: isTesting
                      ? null
                      : () async {
                          setDialogState(() {
                            isTesting = true;
                            testStatus = null;
                          });
                          try {
                            final testDio = Dio(BaseOptions(
                              baseUrl: ctrl.text.trim(),
                              connectTimeout: const Duration(seconds: 4),
                              receiveTimeout: const Duration(seconds: 4),
                            ));
                            final res = await testDio.get('/products/categories');
                            if (res.statusCode == 200) {
                              setDialogState(() {
                                testStatus = 'SUCCESS: Connected to Grand Aqua Backend!';
                              });
                            } else {
                              setDialogState(() {
                                testStatus = 'Server responded with code ${res.statusCode}';
                              });
                            }
                          } catch (e) {
                            setDialogState(() {
                              testStatus = 'FAILED: Cannot connect. Check Wi-Fi & IP.';
                            });
                          } finally {
                            setDialogState(() => isTesting = false);
                          }
                        },
                  icon: isTesting
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.wifi_tethering, size: 16),
                  label: Text(isTesting ? 'Testing Connection...' : 'Test Connection'),
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
              onPressed: () async {
                final newUrl = ctrl.text.trim();
                if (newUrl.isNotEmpty) {
                  final api = ref.read(apiClientProvider);
                  await api.updateBaseUrl(newUrl);
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Server URL set to $newUrl')),
                    );
                  }
                }
              },
              child: const Text('Save URL'),
            ),
          ],
        ),
      ),
    );
  }
}
