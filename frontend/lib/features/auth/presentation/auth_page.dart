import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sardine/core/config/app_config.dart';
import 'package:sardine/core/di/dependency_injection.dart';
import 'package:sardine/features/auth/presentation/auth_cubit.dart';
import 'package:sardine/shared/widgets/app_gap.dart';

class AuthPage extends StatelessWidget {
  const AuthPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AuthCubit(getIt()),
      child: const _AuthView(),
    );
  }
}

class _AuthView extends StatefulWidget {
  const _AuthView();

  @override
  State<_AuthView> createState() => _AuthViewState();
}

class _AuthViewState extends State<_AuthView> {
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _registerMode = false;

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _displayNameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Authentication')),
      body: BlocBuilder<AuthCubit, AuthViewState>(
        builder: (context, state) {
          final loading = state is AuthLoadingView;

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const _InfoTile(label: 'Backend', value: AppConfig.apiBaseUrl),
              const AppGap.v(height: 16),
              if (state is AuthenticatedView) ...[
                Text(
                  'Logged in as ${state.session.user.displayName}',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const AppGap.v(height: 12),
                _InfoTile(label: 'Email', value: state.session.user.email),
                const AppGap.v(height: 12),
                _InfoTile(
                    label: 'Username', value: state.session.user.username),
                const AppGap.v(height: 12),
                FilledButton(
                  onPressed: () => context.read<AuthCubit>().logout(),
                  child: const Text('Logout'),
                ),
              ] else ...[
                Text(
                  _registerMode ? 'Create account' : 'Sign in',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const AppGap.v(height: 16),
                TextField(
                  controller: _emailController,
                  enabled: !loading,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const AppGap.v(height: 12),
                if (_registerMode) ...[
                  TextField(
                    controller: _usernameController,
                    enabled: !loading,
                    decoration: const InputDecoration(labelText: 'Username'),
                  ),
                  const AppGap.v(height: 12),
                  TextField(
                    controller: _displayNameController,
                    enabled: !loading,
                    decoration:
                        const InputDecoration(labelText: 'Display name'),
                  ),
                  const AppGap.v(height: 12),
                ],
                TextField(
                  controller: _passwordController,
                  enabled: !loading,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password'),
                ),
                const AppGap.v(height: 16),
                if (state is AuthErrorView) ...[
                  Text(
                    state.message,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  const AppGap.v(height: 12),
                ],
                FilledButton(
                  onPressed: loading ? null : () => _submit(context),
                  child: Text(_registerMode ? 'Register' : 'Login'),
                ),
                const AppGap.v(height: 12),
                TextButton(
                  onPressed: loading
                      ? null
                      : () => setState(() => _registerMode = !_registerMode),
                  child: Text(
                    _registerMode
                        ? 'Already have an account? Sign in'
                        : 'Need an account? Register',
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  void _submit(BuildContext context) {
    final cubit = context.read<AuthCubit>();
    if (_registerMode) {
      cubit.register(
        email: _emailController.text.trim(),
        username: _usernameController.text.trim(),
        displayName: _displayNameController.text.trim(),
        password: _passwordController.text,
      );
      return;
    }
    cubit.login(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(
              width: 92,
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            Expanded(child: Text(value)),
          ],
        ),
      ),
    );
  }
}
