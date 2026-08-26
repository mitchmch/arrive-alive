import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../controllers/auth_controller.dart';
import 'access_screen.dart';
import 'register_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phone = TextEditingController();
  final _pin = TextEditingController();
  final _secretWord = TextEditingController();
  final _newPin = TextEditingController();
  final _confirmNewPin = TextEditingController();
  bool _isResetMode = false;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    _pin.dispose();
    _secretWord.dispose();
    _newPin.dispose();
    _confirmNewPin.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() => _error = null);
    if (_phone.text.trim().isEmpty || !RegExp(r'^\d{4}$').hasMatch(_pin.text)) {
      setState(() => _error = 'Enter a phone number and exactly 4 PIN digits');
      return;
    }
    final success = await ref
        .read(authProvider.notifier)
        .login(_phone.text.trim(), _pin.text);
    if (success && mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  Future<void> _goBack() async {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AccessScreen()),
      (_) => false,
    );
  }

  Future<void> _resetPin() async {
    setState(() => _error = null);
    if (_phone.text.trim().isEmpty ||
        _secretWord.text.trim().length < 3 ||
        !RegExp(r'^\d{4}$').hasMatch(_newPin.text)) {
      setState(() => _error = 'Fill all fields');
      return;
    }
    if (_newPin.text != _confirmNewPin.text) {
      setState(() => _error = 'PINs do not match');
      return;
    }
    final success = await ref
        .read(authProvider.notifier)
        .resetPin(_phone.text.trim(), _secretWord.text.trim(), _newPin.text);
    if (success) {
      setState(() => _isResetMode = false);
      _pin.clear();
      _secretWord.clear();
      _newPin.clear();
      _confirmNewPin.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PIN reset successful. Sign in with new PIN.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goBack();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isResetMode ? 'Reset PIN' : 'Sign In'),
          leading: IconButton(
            onPressed: _goBack,
            tooltip: 'Go Back',
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!_isResetMode) ...[
                TextField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone Number'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _pin,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 4,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  decoration: const InputDecoration(labelText: 'PIN'),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => setState(() => _isResetMode = true),
                    child: Text(
                      'Forgot PIN?',
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                ),
              ] else ...[
                Text(
                  'Reset your PIN by confirming your secret word.',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    color: AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone Number'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _secretWord,
                  decoration: const InputDecoration(
                    labelText: 'Secret Word',
                    hintText: 'Enter your secret word',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _newPin,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 4,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  decoration: const InputDecoration(labelText: 'New PIN'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _confirmNewPin,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 4,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Confirm New PIN',
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    color: AppTheme.destructive,
                  ),
                ),
              ],
              if (auth.error != null) ...[
                const SizedBox(height: 12),
                Text(
                  auth.error!,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    color: AppTheme.destructive,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed:
                    auth.isLoading ? null : (_isResetMode ? _resetPin : _login),
                child: auth.isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(_isResetMode ? 'Reset PIN' : 'Sign In'),
              ),
              if (_isResetMode)
                TextButton(
                  onPressed: () => setState(() => _isResetMode = false),
                  child: const Text('Back to Sign In'),
                ),
              if (!_isResetMode)
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RegisterScreen()),
                  ),
                  child: const Text("Don't have an account? Register"),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
