import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../config/imagery.dart';
import '../config/premium_theme.dart';
import '../providers/auth_provider.dart';
import '../utils/constants.dart';
import '../utils/validators.dart';
import '../widgets/auth_shell.dart';
import '../widgets/premium_button.dart';
import '../widgets/premium_input.dart';

/// Account creation, sharing the auth shell with the sign-in screen.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final auth = context.read<AuthProvider>();
    final ok = await auth.register(
      name: _name.text.trim(),
      email: _email.text.trim(),
      phone: _phone.text.trim(),
      password: _password.text,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pushReplacementNamed(AppConstants.routeHome);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(auth.errorMessage ?? 'We could not create that account.'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Lux.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AuthShell(
      eyebrow: 'Join the club',
      title: 'Create your account',
      subtitle:
          'Members save their details once and book in a few taps thereafter.',
      imageUrl: Imagery.roadTrip,
      quote: 'Every seat is a first-class seat. Every journey, unhurried.',
      footer: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            'Already a member?',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: isDark
                  ? Lux.textOnDarkMuted
                  : Lux.ink.withValues(alpha: 0.6),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context)
                .pushReplacementNamed(AppConstants.routeLogin),
            child: const Text('Sign in'),
          ),
        ],
      ),
      form: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PremiumTextField(
              controller: _name,
              label: 'Full name',
              hint: 'As it should appear on your ticket',
              prefixIcon: Icons.person_outline_rounded,
              textInputAction: TextInputAction.next,
              validator: (v) => Validators.required(v, 'Name'),
            ),
            const SizedBox(height: 16),
            PremiumTextField(
              controller: _email,
              label: 'Email address',
              hint: 'you@example.com',
              prefixIcon: Icons.alternate_email_rounded,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: Validators.email,
            ),
            const SizedBox(height: 16),
            PremiumTextField(
              controller: _phone,
              label: 'Phone number',
              hint: '0803 000 0000',
              prefixIcon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              validator: Validators.phone,
            ),
            const SizedBox(height: 16),
            PremiumTextField(
              controller: _password,
              label: 'Password',
              hint: 'At least 6 characters',
              prefixIcon: Icons.lock_outline_rounded,
              obscure: _obscure,
              textInputAction: TextInputAction.next,
              validator: Validators.password,
              suffix: IconButton(
                tooltip: _obscure ? 'Show password' : 'Hide password',
                icon: Icon(
                  _obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 20,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            const SizedBox(height: 16),
            PremiumTextField(
              controller: _confirm,
              label: 'Confirm password',
              hint: 'Repeat your password',
              prefixIcon: Icons.lock_reset_rounded,
              obscure: _obscure,
              textInputAction: TextInputAction.done,
              validator: (v) =>
                  Validators.confirmPassword(v, _password.text),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 24),
            PremiumButton(
              label: 'Create account',
              icon: Icons.arrow_forward_rounded,
              loading: auth.isLoading,
              onPressed: auth.isLoading ? null : _submit,
            ),
            const SizedBox(height: 24),
            const OrDivider(label: 'or sign up with'),
            const SizedBox(height: 18),
            const SocialAuthButtons(),
          ],
        ),
      ),
    );
  }
}
