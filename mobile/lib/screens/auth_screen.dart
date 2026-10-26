import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api/trago_api_client.dart';
import '../state/app_state.dart';
import '../theme/trago_theme.dart';
import '../widgets/trago_logo.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _registering = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _switchMode() {
    setState(() {
      _registering = !_registering;
      _error = null;
      _passwordController.clear();
    });
    _formKey.currentState?.reset();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _error = null);
    final state = context.read<AppState>();
    try {
      if (_registering) {
        await state.register(
          email: _emailController.text,
          password: _passwordController.text,
          displayName: _nameController.text,
        );
      } else {
        await state.login(
          email: _emailController.text,
          password: _passwordController.text,
        );
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Não foi possível concluir a autenticação.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final notice = _error ?? state.authNotice;
    return Scaffold(
      backgroundColor: TragoColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: AutofillGroup(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Center(
                            child: TragoLogo(showTagline: true, fontSize: 34),
                          ),
                          const SizedBox(height: 28),
                          Text(
                            _registering ? 'Criar conta' : 'Entrar',
                            style: const TextStyle(
                              color: TragoColors.navy,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _registering
                                ? 'Cadastre sua identidade para iniciar uma sessão segura.'
                                : 'Use sua conta para acessar os recursos protegidos.',
                            style: const TextStyle(color: TragoColors.muted),
                          ),
                          const SizedBox(height: 22),
                          if (_registering) ...[
                            TextFormField(
                              controller: _nameController,
                              autofillHints: const [AutofillHints.name],
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Nome',
                                prefixIcon: Icon(Icons.person_outline_rounded),
                              ),
                              validator: (value) {
                                final name = value?.trim() ?? '';
                                if (name.isEmpty) {
                                  return 'Informe seu nome.';
                                }
                                if (name.length > 100) {
                                  return 'Use no máximo 100 caracteres.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                          ],
                          TextFormField(
                            controller: _emailController,
                            autofillHints: const [
                              AutofillHints.username,
                              AutofillHints.email,
                            ],
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autocorrect: false,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                            validator: (value) {
                              final email = value?.trim() ?? '';
                              if (email.isEmpty ||
                                  !RegExp(
                                    r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                                  ).hasMatch(email)) {
                                return 'Informe um email válido.';
                              }
                              if (email.length > 254) {
                                return 'Email muito longo.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _passwordController,
                            autofillHints: [
                              _registering
                                  ? AutofillHints.newPassword
                                  : AutofillHints.password,
                            ],
                            obscureText: _obscurePassword,
                            enableSuggestions: false,
                            autocorrect: false,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) =>
                                state.authBusy ? null : _submit(),
                            decoration: InputDecoration(
                              labelText: 'Senha',
                              prefixIcon: const Icon(
                                Icons.lock_outline_rounded,
                              ),
                              suffixIcon: IconButton(
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                            validator: (value) {
                              final password = value ?? '';
                              if (password.isEmpty) {
                                return 'Informe sua senha.';
                              }
                              if (_registering && password.length < 12) {
                                return 'Use pelo menos 12 caracteres.';
                              }
                              if (password.length > 128) {
                                return 'Use no máximo 128 caracteres.';
                              }
                              return null;
                            },
                          ),
                          if (notice != null) ...[
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: TragoColors.coralSoft,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                notice,
                                style: const TextStyle(
                                  color: TragoColors.coralDark,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: state.authBusy ? null : _submit,
                            child: state.authBusy
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.4,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(_registering ? 'Cadastrar' : 'Entrar'),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: state.authBusy ? null : _switchMode,
                            child: Text(
                              _registering
                                  ? 'Já tenho conta'
                                  : 'Criar uma conta',
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
      ),
    );
  }
}
