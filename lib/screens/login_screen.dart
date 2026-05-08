import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:st_george_pos/providers/pos_providers.dart';
import 'package:st_george_pos/locales/app_localizations.dart';
import 'package:st_george_pos/widgets/language_switcher.dart';

// Debug only — maps seeded usernames to their passwords
const _kDebugPasswords = {'Director': 'director123', 'Cashier 1': 'cashier123'};

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  String? _selectedUsername;
  final _passwordController = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  // Usernames are loaded from DB; we show them in the dropdown
  // but password is always entered manually
  final _passwordFocus = FocusNode();

  @override
  void dispose() {
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_selectedUsername == null || _passwordController.text.isEmpty) {
      setState(() => _error = ref.t('auth.selectUser'));
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final success = await ref
        .read(authProvider.notifier)
        .login(_selectedUsername!, _passwordController.text);
    if (!mounted) return;
    setState(() => _loading = false);
    if (!success) {
      setState(() => _error = ref.t('auth.incorrectPassword'));
      _passwordController.clear();
    }
    // On success, main.dart watches authProvider and navigates automatically
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(languageProvider);
    final usersAsync = ref.watch(usersProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF121212), Color(0xFF003D22), Color(0xFF121212)],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: Center(
          child: SizedBox(
            width: 420,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  padding: const EdgeInsets.all(48),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.12)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo / Title
                      const Icon(
                        Icons.restaurant,
                        size: 56,
                        color: Color(0xFFD4AF37),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        ref.t('app.title'),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 4,
                          color: Color(0xFFD4AF37),
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Language switcher
                      const CompactLanguageSwitcher(),
                      Text(
                        ref.t('app.pos'),
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 13,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 40),

                      // Username dropdown
                      usersAsync.when(
                        data: (users) {
                          final activeUsers = users
                              .where((u) => u.isActive)
                              .toList();
                          return DropdownButtonFormField<String>(
                            value: _selectedUsername,
                            dropdownColor: const Color(0xFF1A1A1A),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                            ),
                            decoration: InputDecoration(
                              labelText: ref.t('auth.username'),
                              labelStyle: const TextStyle(
                                color: Colors.white38,
                              ),
                              border: InputBorder.none,
                            ),
                            items: activeUsers
                                .map(
                                  (u) => DropdownMenuItem(
                                    value: u.username,
                                    child: Row(
                                      children: [
                                        Icon(
                                          u.role.toString().contains('director')
                                              ? Icons
                                                    .admin_panel_settings_outlined
                                              : Icons.point_of_sale,
                                          size: 18,
                                          color:
                                              u.role.toString().contains(
                                                'director',
                                              )
                                              ? const Color(0xFFD4AF37)
                                              : Colors.white54,
                                        ),
                                        const SizedBox(width: 10),
                                        Text(u.username),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) {
                              setState(() {
                                _selectedUsername = val;
                                _error = null;
                                // DEBUG: autofill password
                                if (kDebugMode)
                                  _passwordController.text =
                                      _kDebugPasswords[val] ?? '';
                              });
                              _passwordFocus.requestFocus();
                            },
                          );
                        },
                        loading: () => const LinearProgressIndicator(),
                        error: (e, _) => Text(
                          '${ref.t('common.error')}: $e',
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Password field
                      TextFormField(
                        controller: _passwordController,
                        focusNode: _passwordFocus,
                        obscureText: _obscure,
                        style: const TextStyle(color: Colors.white),
                        decoration:
                            _inputDecoration(
                              ref.t('auth.password'),
                              Icons.lock_outline,
                            ).copyWith(
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscure
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: Colors.white38,
                                  size: 20,
                                ),
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                              ),
                            ),
                        onFieldSubmitted: (_) => _login(),
                      ),

                      // Error message
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.redAccent.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: Colors.redAccent,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: const TextStyle(
                                    color: Colors.redAccent,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 32),

                      // Login button
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD4AF37),
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          onPressed: _loading ? null : _login,
                          child: _loading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.black,
                                  ),
                                )
                              : Text(
                                  ref.t('auth.login').toUpperCase(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 2,
                                    fontSize: 15,
                                  ),
                                ),
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

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white38),
      prefixIcon: Icon(icon, color: Colors.white38, size: 20),
      filled: true,
      fillColor: Colors.white.withOpacity(0.06),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD4AF37), width: 1.5),
      ),
    );
  }
}
