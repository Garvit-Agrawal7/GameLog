import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../database/dao/games_dao.dart';
import '../game_library_provider.dart';
import '../services/auth_service.dart';
import '../main_shell.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../database/app_database.dart';
import 'forgot_password_screen.dart';
import 'verification_screen.dart';

enum _AuthMode { login, signUp }

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({
    super.key,
    this.startInSignUp = false,
  });

  final bool startInSignUp;

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userIdController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  late _AuthMode _mode;
  bool _isLoading = false;
  String? _authErrorMessage;

  @override
  void initState() {
    super.initState();
    _mode = widget.startInSignUp ? _AuthMode.signUp : _AuthMode.login;
  }

  @override
  void dispose() {
    _userIdController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _authenticate({
    required AuthService auth,
    required String userId,
    required String email,
    required String password,
  }) async {
    if (_mode == _AuthMode.signUp) {
      await auth.signUp(email: email, userId: userId, password: password);
      if (mounted) {
        ref.read(authProvider.notifier).setPendingVerification();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => VerificationScreen(
              initialEmail: email,
            ),
          ),
        );
      }
      return;
    }

    final result = await auth.login(userId: userId, password: password);
    await ref.read(authProvider.notifier).persistVerifiedSession(
          accessToken: result.accessToken,
          user: result.user,
        );
    ref.invalidate(gameLibraryProvider);
    await _syncLibraryFromBackend(
      userId: result.user.id,
      accessToken: result.accessToken,
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _authErrorMessage = null;
    });
    final auth = ref.read(authServiceProvider);
    final userId = _userIdController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    try {
      await _authenticate(auth: auth, userId: userId, email: email, password: password);

      if (!mounted || _mode == _AuthMode.signUp) {
        return;
      }

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainShell()),
        );
      }
    } on DioException catch (e) {
      if (mounted) {
        final detail = e.response?.data is Map<String, dynamic>
            ? e.response?.data['detail']
            : null;

        if (e.response?.statusCode == 401 && _mode == _AuthMode.login && detail == 'Invalid credentials') {
          setState(() {
            _authErrorMessage = 'Invalid username or password';
          });
          return;
        }

        if (e.response?.statusCode == 403 && _mode == _AuthMode.login && detail == 'Account is disabled') {
          setState(() {
            _authErrorMessage = 'You have been temporarily restricted from using GameLog';
          });
          return;
        }

        if (e.response?.statusCode == 403 &&
            _mode == _AuthMode.login &&
            detail == 'Email is not verified') {
          setState(() {
            _authErrorMessage = 'Please verify your email before logging in';
          });
          return;
        }

        if (e.response?.statusCode == 400 &&
            _mode == _AuthMode.signUp &&
            detail == 'Email or userid already pending verification') {
          setState(() {
            _authErrorMessage = 'This account is already pending verification';
          });
          return;
        }

        if (e.response?.statusCode == 400 &&
            _mode == _AuthMode.signUp &&
            detail == 'Email or userid already exists') {
          setState(() {
            _authErrorMessage = 'Email or user ID already exists';
          });
          return;
        }

        setState(() {
          _authErrorMessage = 'An unexpected error occurred';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _authErrorMessage = 'An unexpected error occurred';
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }


  Future<void> _syncLibraryFromBackend({
    required String userId,
    required String accessToken,
  }) async {
    final auth = ref.read(authServiceProvider);
    final database = AppDatabase();
    final remoteGames = await auth.fetchLibrary(
      userId: userId,
      accessToken: accessToken,
    );

    if (remoteGames.isEmpty) {
      return;
    }

    await database.gamesDao.clearAllGames();

    for (final remoteGame in remoteGames) {
      await database.gamesDao.insertGame(
        GameModel(
          id: remoteGame.id,
          title: remoteGame.title,
          coverUrl: remoteGame.coverUrl,
          genres: remoteGame.genres,
          summary: remoteGame.summary,
          rating: remoteGame.rating,
          hoursPlayed: remoteGame.hoursPlayed,
          timeToBeatHours: remoteGame.timeToBeatHours,
          status: remoteGame.status,
          userRating: remoteGame.userRating,
          year: remoteGame.year,
          inLibrary: remoteGame.inLibrary,
          lastUpdated: remoteGame.lastUpdated,
        ),
      );
    }

    ref.invalidate(gameLibraryProvider);
  }

  Future<void> _forgotPassword() async {
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ForgotPasswordScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLogin = _mode == _AuthMode.login;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.accentPurple.withValues(alpha: 0.3),
              AppColors.bg0,
            ],
            stops: const [0.1, 0.8],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.bg0.withValues(alpha: 0.42),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                  ),
                  padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Column(
                            children: [
                              Image.asset(
                                'assets/images/logo.png',
                                width: 96,
                                height: 96,
                                fit: BoxFit.contain,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'GameLog',
                                style: AppTextStyles.title.copyWith(fontSize: 28),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          isLogin ? 'Login' : 'Sign up',
                          style: AppTextStyles.display.copyWith(fontSize: 24),
                        ),
                        const SizedBox(height: 22),
                        if (!isLogin) ...[
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
                            decoration: _inputDecoration('Email'),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Enter your email';
                              }
                              if (!value.contains('@')) {
                                return 'Enter a valid email';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                        ],
                        TextFormField(
                          controller: _userIdController,
                          style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
                          decoration: _inputDecoration(isLogin ? 'User ID or Email' : 'User ID'),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Enter your User ID';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
                          decoration: _inputDecoration('Password'),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Enter your password';
                            }
                            if (value.length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                        ),
                        if (!isLogin) ...[
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: true,
                            style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
                            decoration: _inputDecoration('Confirm password'),
                            validator: (value) {
                              if (_passwordController.text.isEmpty) {
                                return null;
                              }
                              if (value == null || value.isEmpty) {
                                return 'Confirm your password';
                              }
                              if (value != _passwordController.text) {
                                return 'Passwords do not match';
                              }
                              return null;
                            },
                          ),
                        ],
                        const SizedBox(height: 20),
                        if (_authErrorMessage != null) ...[
                          Text(
                            _authErrorMessage!,
                            style: AppTextStyles.body.copyWith(
                              color: AppColors.error,
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accentPurple,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : Text(isLogin ? 'Login' : 'Sign up'),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _forgotPassword,
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              foregroundColor: AppColors.textSecondary,
                            ),
                            child: const Text(
                              'Forgot password',
                              style: TextStyle(decoration: TextDecoration.underline),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Center(
                          child: TextButton(
                            onPressed: () {
                              setState(() {
                                _mode = isLogin ? _AuthMode.signUp : _AuthMode.login;
                                _authErrorMessage = null;
                              });
                            },
                            child: Text(
                              isLogin ? 'Need an account? Sign up' : 'Have an account? Login',
                              style: const TextStyle(decoration: TextDecoration.underline),
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
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: AppTextStyles.body.copyWith(color: AppColors.textMuted),
      filled: true,
      fillColor: AppColors.bg1.withValues(alpha: 0.9),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.accentPurple, width: 1.4),
      ),
    );
  }
}
