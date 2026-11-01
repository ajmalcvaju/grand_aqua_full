import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../core/auth_provider.dart';

class BuyerLoginScreen extends ConsumerStatefulWidget {
  const BuyerLoginScreen({super.key});

  @override
  ConsumerState<BuyerLoginScreen> createState() => _BuyerLoginScreenState();
}

class _BuyerLoginScreenState extends ConsumerState<BuyerLoginScreen> {
  int _activeTabIndex = 0; // 0: Password Login, 1: OTP Login

  // Password Login Tab controllers
  final _identifierCtrl = TextEditingController(text: '+919811122233');
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;

  // OTP Login Tab controllers
  final _otpPhoneCtrl = TextEditingController(text: '+919811122233');
  final _otpCodeCtrl = TextEditingController();
  bool _otpSent = false;
  int _otpCooldown = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(authProvider).isAuthenticated && mounted) {
        context.go('/home');
      }
    });
  }

  @override
  void dispose() {
    _identifierCtrl.dispose();
    _passwordCtrl.dispose();
    _otpPhoneCtrl.dispose();
    _otpCodeCtrl.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    setState(() {
      _otpCooldown = 60;
      _otpSent = true;
    });
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_otpCooldown > 1) {
        setState(() => _otpCooldown--);
      } else {
        timer.cancel();
        setState(() => _otpCooldown = 0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F172A), Color(0xFF0369A1), Color(0xFF0F172A)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Card(
                  elevation: 16,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  child: Padding(
                    padding: const EdgeInsets.all(22.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // App Brand Header (Official Logo)
                        Image.asset(
                          'assets/images/grand_aqua_logo.png',
                          width: 220,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Buyer Portal — Pure | Safe | Healthy',
                          style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 20),

                        // Error Banner
                        if (authState.errorMessage != null)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, color: Colors.red, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    authState.errorMessage!,
                                    style: TextStyle(color: Colors.red.shade800, fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Login Mode Selector (Password Login vs OTP Login)
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () => setState(() => _activeTabIndex = 0),
                                  borderRadius: BorderRadius.circular(10),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    decoration: BoxDecoration(
                                      color: _activeTabIndex == 0 ? const Color(0xFF0284C7) : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: _activeTabIndex == 0
                                          ? [
                                              BoxShadow(
                                                color: const Color(0xFF0284C7).withValues(alpha: 0.25),
                                                blurRadius: 4,
                                                offset: const Offset(0, 2),
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.lock_outline,
                                          size: 16,
                                          color: _activeTabIndex == 0 ? Colors.white : const Color(0xFF64748B),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Password Login',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: _activeTabIndex == 0 ? Colors.white : const Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: InkWell(
                                  onTap: () => setState(() => _activeTabIndex = 1),
                                  borderRadius: BorderRadius.circular(10),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    decoration: BoxDecoration(
                                      color: _activeTabIndex == 1 ? const Color(0xFF0284C7) : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: _activeTabIndex == 1
                                          ? [
                                              BoxShadow(
                                                color: const Color(0xFF0284C7).withValues(alpha: 0.25),
                                                blurRadius: 4,
                                                offset: const Offset(0, 2),
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.sms_outlined,
                                          size: 16,
                                          color: _activeTabIndex == 1 ? Colors.white : const Color(0xFF64748B),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'OTP Login',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: _activeTabIndex == 1 ? Colors.white : const Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Active Tab Content (No clipping, full clearance for floating labels)
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: _activeTabIndex == 0
                              ? _buildPasswordTab(authState)
                              : _buildOtpTab(authState),
                        ),

                        const Divider(height: 24),

                        // Registration Button (New Customer)
                        InkWell(
                          onTap: () => _showRegistrationDialog(context),
                          borderRadius: BorderRadius.circular(10),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  "Don't have an account? ",
                                  style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
                                ),
                                const Text(
                                  'Register / Create Account',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0284C7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 8),

                        // Server Settings Option
                        TextButton.icon(
                          onPressed: () => _showServerSettingsDialog(context),
                          icon: const Icon(Icons.settings_ethernet, size: 14, color: Colors.grey),
                          label: const Text(
                            'Configure Server IP / URL',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
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
      ),
    );
  }

  // 1. Password Login View
  Widget _buildPasswordTab(AuthState authState) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _identifierCtrl,
            decoration: InputDecoration(
              labelText: 'Mobile Number or Username',
              hintText: 'e.g. +919811122233 or username',
              prefixIcon: const Icon(Icons.person_outline),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey.shade50,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _passwordCtrl,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, size: 20),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey.shade50,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => _showForgotPasswordDialog(context),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Forgot Password?',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 50,
            child: FilledButton(
              onPressed: authState.isLoading ? null : _handlePasswordLogin,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: authState.isLoading
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : const Text('Log In with Password', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }

  // 2. OTP Login View
  Widget _buildOtpTab(AuthState authState) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _otpPhoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'Registered Mobile Number',
              hintText: '+919811122233',
              prefixIcon: const Icon(Icons.phone_android),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey.shade50,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _otpCodeCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: InputDecoration(
                    counterText: '',
                    labelText: 'Enter 6-Digit OTP',
                    hintText: '123456',
                    prefixIcon: const Icon(Icons.pin),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 52,
                child: OutlinedButton(
                  onPressed: (_otpCooldown > 0 || authState.isLoading) ? null : _handleRequestOtp,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF0284C7)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    _otpCooldown > 0 ? '${_otpCooldown}s' : (_otpSent ? 'Resend' : 'Get OTP'),
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 50,
            child: FilledButton(
              onPressed: authState.isLoading ? null : _handleOtpLogin,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: authState.isLoading
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : const Text('Verify OTP & Log In', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handlePasswordLogin() async {
    final identifier = _identifierCtrl.text.trim();
    final password = _passwordCtrl.text.trim();

    if (identifier.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your mobile number or username')),
      );
      return;
    }
    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your password')),
      );
      return;
    }

    final success = await ref.read(authProvider.notifier).loginWithPassword(identifier, password);
    if (success && mounted) {
      context.go('/home');
    } else if (mounted) {
      final err = ref.read(authProvider).errorMessage ?? 'Login failed. Please check credentials.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _handleRequestOtp() async {
    final phone = _otpPhoneCtrl.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your mobile number')),
      );
      return;
    }

    final ok = await ref.read(authProvider.notifier).requestOtp(phone);
    if (ok && mounted) {
      _startCooldown();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('OTP sent successfully (Demo OTP: 123456)'),
          backgroundColor: Color(0xFF0284C7),
        ),
      );
    }
  }

  Future<void> _handleOtpLogin() async {
    final phone = _otpPhoneCtrl.text.trim();
    final otp = _otpCodeCtrl.text.trim();

    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your mobile number')),
      );
      return;
    }
    if (otp.isEmpty || otp.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the OTP received')),
      );
      return;
    }

    final success = await ref.read(authProvider.notifier).loginWithOtp(phone, otp);
    if (success && mounted) {
      context.go('/home');
    } else if (mounted) {
      final err = ref.read(authProvider).errorMessage ?? 'OTP verification failed';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  // 3. New Customer Registration Dialog (ONLY Company Name and Mobile Number required)
  void _showRegistrationDialog(BuildContext context) {
    final businessNameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController(text: '+91');
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.app_registration, color: Color(0xFF0284C7)),
              SizedBox(width: 8),
              Text('Create Buyer Account', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Register your business to access wholesale catalog, pricing and direct quotations.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 14),

                TextField(
                  controller: businessNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Company / Business Name *',
                    hintText: 'e.g. Apex Aqua Traders',
                    prefixIcon: Icon(Icons.business_outlined),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Mobile Number *',
                    hintText: '+919876543210',
                    prefixIcon: Icon(Icons.phone_android),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 14),

                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF86EFAC)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.shield_outlined, size: 18, color: Color(0xFF16A34A)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Only your Company Name and Mobile Number are required. Your official username and initial password are set exclusively by Super Admin.',
                          style: TextStyle(fontSize: 11, color: Color(0xFF166534), height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0284C7)),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final bName = businessNameCtrl.text.trim();
                      final phone = phoneCtrl.text.trim();

                      if (bName.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter your company / business name')),
                        );
                        return;
                      }
                      if (phone.isEmpty || phone == '+91') {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter your mobile number')),
                        );
                        return;
                      }

                      setDialogState(() => isSubmitting = true);
                      final result = await ref.read(authProvider.notifier).registerBuyer(
                            businessName: bName,
                            phone: phone,
                          );
                      setDialogState(() => isSubmitting = false);

                      if (result != null && ctx.mounted) {
                        Navigator.pop(ctx);
                        _showRegistrationSuccessDialog(context, result);
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Register Account'),
            ),
          ],
        ),
      ),
    );
  }

  void _showRegistrationSuccessDialog(BuildContext context, Map<String, dynamic> result) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Color(0xFF10B981)),
            SizedBox(width: 8),
            Text('Registration Submitted!', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome, ${result['businessName']}!',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 6),
            Text(
              'Your Buyer ID: ${result['buyerId'] ?? 'Assigned'}',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0284C7), fontSize: 13),
            ),
            const SizedBox(height: 10),
            const Text(
              'Your registration has been submitted to Grand Aqua Super Admin. The Super Admin will assign your official username and initial password.',
              style: TextStyle(fontSize: 12, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 8),
            const Text(
              'Once activated, you can log in with either Password or Mobile OTP.',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
            ),
          ],
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0284C7)),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got It'),
          ),
        ],
      ),
    );
  }

  // 4. Forgot Password Dialog
  void _showForgotPasswordDialog(BuildContext context) {
    final phoneCtrl = TextEditingController(text: _identifierCtrl.text.startsWith('+') ? _identifierCtrl.text : '');
    final otpCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();

    bool otpSent = false;
    bool isRequestingOtp = false;
    bool isResetting = false;
    bool obscureNew = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.lock_reset, color: Color(0xFF0284C7)),
              SizedBox(width: 8),
              Text('Reset Password', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Enter your registered mobile number to receive an OTP and set a new password.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 14),

                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  enabled: !otpSent,
                  decoration: InputDecoration(
                    labelText: 'Registered Mobile Number',
                    hintText: '+919811122233',
                    prefixIcon: const Icon(Icons.phone_android),
                    border: const OutlineInputBorder(),
                    isDense: true,
                    suffixIcon: otpSent
                        ? const Icon(Icons.check_circle, color: Color(0xFF10B981))
                        : TextButton(
                            onPressed: isRequestingOtp
                                ? null
                                : () async {
                                    final p = phoneCtrl.text.trim();
                                    if (p.isEmpty) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Please enter your mobile number')),
                                      );
                                      return;
                                    }
                                    setDialogState(() => isRequestingOtp = true);
                                    final ok = await ref.read(authProvider.notifier).requestForgotPasswordOtp(p);
                                    setDialogState(() {
                                      isRequestingOtp = false;
                                      if (ok) otpSent = true;
                                    });
                                  },
                            child: isRequestingOtp
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Text('Send OTP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                  ),
                ),

                if (otpSent) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: otpCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: const InputDecoration(
                      counterText: '',
                      labelText: 'Enter 6-Digit OTP (Demo: 123456)',
                      prefixIcon: Icon(Icons.pin),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: newPassCtrl,
                    obscureText: obscureNew,
                    decoration: InputDecoration(
                      labelText: 'New Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility, size: 18),
                        onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                      ),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmPassCtrl,
                    obscureText: obscureNew,
                    decoration: const InputDecoration(
                      labelText: 'Confirm New Password',
                      prefixIcon: Icon(Icons.lock_outline),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            if (otpSent)
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0284C7)),
                onPressed: isResetting
                    ? null
                    : () async {
                        final phone = phoneCtrl.text.trim();
                        final otp = otpCtrl.text.trim();
                        final newPass = newPassCtrl.text.trim();
                        final confPass = confirmPassCtrl.text.trim();

                        if (otp.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter the OTP')));
                          return;
                        }
                        if (newPass.length < 6) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password must be at least 6 characters')));
                          return;
                        }
                        if (newPass != confPass) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Passwords do not match')));
                          return;
                        }

                        setDialogState(() => isResetting = true);
                        final ok = await ref.read(authProvider.notifier).resetPassword(
                              phone: phone,
                              otp: otp,
                              newPassword: newPass,
                            );
                        setDialogState(() => isResetting = false);

                        if (ok && ctx.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Password reset successfully! You can now log in with your new password.'),
                              backgroundColor: Color(0xFF10B981),
                            ),
                          );
                        }
                      },
                child: isResetting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Reset Password'),
              ),
          ],
        ),
      ),
    );
  }

  // 5. Server URL Configuration
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
                'Enter backend API base URL:',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: ctrl,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  labelText: 'API Base URL',
                  hintText: ApiClient.defaultUrl,
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
                    label: const Text('Cloudflare Tunnel', style: TextStyle(fontSize: 10)),
                    onPressed: () {
                      setDialogState(() {
                        ctrl.text = 'https://table-screensaver-interior-reflections.trycloudflare.com/api/v1';
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
                              connectTimeout: const Duration(seconds: 5),
                              receiveTimeout: const Duration(seconds: 5),
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
                              testStatus = 'FAILED: Cannot connect: $e';
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
                      SnackBar(content: Text('Server URL set to: $newUrl')),
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
