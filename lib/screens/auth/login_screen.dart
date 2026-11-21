import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/models/stage_data.dart';
import '../../data/repositories/auth_repository.dart';
import '../../services/app_services.dart';
import '../../widgets/stage_backdrop.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _register = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on AuthFailure catch (e) {
      _error = e.message;
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _busy = false);
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    _run(() => _register
        ? AppServices.auth.register(
            displayName: _name.text.trim(),
            email: _email.text.trim(),
            password: _password.text,
          )
        : AppServices.auth.signIn(email: _email.text.trim(), password: _password.text));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const StageBackdrop(stage: Stages.neonRooftop, dim: 0.45),
          SafeArea(
            child: Row(
              children: [
                const Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ARENA', style: AppTheme.titleStyle),
                        Text('FURY', style: AppTheme.titleStyle),
                        SizedBox(height: 8),
                        Text(
                          'Build your fighter. Put your face on it. Win.',
                          style: TextStyle(color: Colors.white70, fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: 400,
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: _buildCard(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard() {
    return Card(
      color: AppColors.panel.withValues(alpha: 0.92),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(_register ? 'CREATE ACCOUNT' : 'SIGN IN', style: AppTheme.headingStyle),
              if (!AppServices.firebaseReady) ...[
                const SizedBox(height: 8),
                const Text(
                  'Offline demo mode — Firebase is not configured. Any email works.',
                  style: TextStyle(color: AppColors.gold, fontSize: 12),
                ),
              ],
              const SizedBox(height: 14),
              if (_register) ...[
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Fighter tag'),
                  maxLength: 16,
                  validator: (v) =>
                      (v == null || v.trim().length < 2) ? 'At least 2 characters' : null,
                ),
                const SizedBox(height: 6),
              ],
              TextFormField(
                controller: _email,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _password,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
                validator: (v) => (v == null || v.length < 6) ? 'At least 6 characters' : null,
                onFieldSubmitted: (_) => _submit(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: Color(0xFFFF8A80))),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(_register ? 'REGISTER' : 'LOGIN'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _busy ? null : () => _run(AppServices.auth.signInAsGuest),
                child: const Text('PLAY AS GUEST'),
              ),
              TextButton(
                onPressed: _busy ? null : () => setState(() => _register = !_register),
                child: Text(_register ? 'Have an account? Sign in' : 'New here? Create an account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
