import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../controllers/auth_controller.dart';
import 'access_screen.dart';
import 'login_screen.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _phone = TextEditingController();
  final _birthYear = TextEditingController();
  final _pin = TextEditingController();
  final _confirmPin = TextEditingController();
  final _secretWord = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    _birthYear.dispose();
    _pin.dispose();
    _confirmPin.dispose();
    _secretWord.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);

    if (_phone.text.trim().length < 8) {
      setState(() => _error = 'Enter a valid phone number');
      return;
    }
    final year = int.tryParse(_birthYear.text.trim());
    if (year == null || year < 1940 || year > DateTime.now().year) {
      setState(() => _error = 'Enter a valid birth year');
      return;
    }
    if (!RegExp(r'^\d{4}$').hasMatch(_pin.text)) {
      setState(() => _error = 'PIN must be exactly 4 digits');
      return;
    }
    if (_pin.text != _confirmPin.text) {
      setState(() => _error = 'PINs do not match');
      return;
    }
    if (_secretWord.text.trim().length < 3) {
      setState(() => _error = 'Secret word must be at least 3 characters');
      return;
    }

    final success = await ref.read(authProvider.notifier).register(
          _phone.text.trim(),
          _birthYear.text.trim(),
          _pin.text,
          secretWord: _secretWord.text.trim(),
        );

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
          title: const Text('Create Account'),
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
              Text(
                'Register with your phone number. No email needed.',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  color: AppTheme.textMuted,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  hintText: '6XXXXXXXX',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _birthYear,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Year of Birth',
                  hintText: '1990',
                ),
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
                decoration: const InputDecoration(
                  labelText: 'Create PIN',
                  hintText: '4-digit PIN',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _confirmPin,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 4,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
                decoration: const InputDecoration(labelText: 'Confirm PIN'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _secretWord,
                decoration: const InputDecoration(
                  labelText: 'Secret Word',
                  hintText: 'For PIN reset (e.g. mother\'s maiden name)',
                  helperText:
                      'Remember this — you\'ll need it to reset your PIN',
                ),
              ),
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
                onPressed: auth.isLoading ? null : _submit,
                child: auth.isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Create Account'),
              ),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                ),
                child: const Text('Already have an account? Sign In'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
