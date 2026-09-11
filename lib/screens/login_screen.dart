import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// Sign-in: split-screen hero on wide viewports, frosted card on phone.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final auth = context.read<AuthProvider>();
    final ok = await auth.login(
      email: _email.text.trim(),
      password: _password.text,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pushReplacementNamed(AppConstants.routeHome);
      return;
    }
    _notify(auth.errorMessage ?? 'Those credentials did not match.');
  }

  void _continueAsGuest() {
    HapticFeedback.selectionClick();
    Navigator.of(context).pushReplacementNamed(AppConstants.routeHome);
  }

  void _notify(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
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
      eyebrow: 'Welcome back',
      title: 'Sign in to continue',
      subtitle:
          'Your upcoming journeys, saved seats and wallet — all in one place.',
      imageUrl: Imagery.luxuryInterior,
      quote: 'Arrive the way you meant to — rested, unhurried, and on time.',
      footer: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            'New to Swift Fleet?',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: isDark
                  ? Lux.textOnDarkMuted
                  : Lux.ink.withValues(alpha: 0.6),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context)
                .pushReplacementNamed(AppConstants.routeRegister),
            child: const Text('Create an account'),
          ),
        ],
      ),
      form: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
              controller: _password,
              label: 'Password',
              hint: '••••••••',
              prefixIcon: Icons.lock_outline_rounded,
              obscure: _obscure,
              textInputAction: TextInputAction.done,
              validator: Validators.password,
              onSubmitted: (_) => _submit(),
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
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _notify('Password reset is coming soon'),
                child: const Text('Forgot password?'),
              ),
            ),
            const SizedBox(height: 4),
            PremiumButton(
              label: 'Sign in',
              icon: Icons.arrow_forward_rounded,
              loading: auth.isLoading,
              onPressed: auth.isLoading ? null : _submit,
            ),
            const SizedBox(height: 24),
            const OrDivider(),
            const SizedBox(height: 18),
            const SocialAuthButtons(),
            const SizedBox(height: 14),
            GhostButton(
              label: 'Continue as guest',
              icon: Icons.person_outline_rounded,
              foreground: isDark ? Lux.textOnDark : Lux.ink,
              onPressed: _continueAsGuest,
            ),
          ],
        ),
      ),
    );
  }
}
