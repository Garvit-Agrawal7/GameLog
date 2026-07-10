import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'auth_screen.dart';

class VerificationScreen extends ConsumerStatefulWidget {
  const VerificationScreen({
    super.key,
    required this.initialEmail,
  });

  final String initialEmail;

  @override
  ConsumerState<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends ConsumerState<VerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeControllers = List.generate(6, (_) => TextEditingController());
  final _codeFocusNodes = List.generate(6, (_) => FocusNode());
  bool _isLoading = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _codeFocusNodes.first.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    for (final controller in _codeControllers) {
      controller.dispose();
    }
    for (final focusNode in _codeFocusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _message = null;
    });

    final auth = ref.read(authServiceProvider);
    final email = widget.initialEmail.trim();
    final code = _codeControllers.map((controller) => controller.text).join().trim();

    try {
      await auth.verifyEmail(email: email, code: code);
      if (mounted) {
        ref.read(authProvider.notifier).setAnonymous();
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => AuthScreen()),
          (route) => false,
        );
      }
    } on DioException catch (e) {
      final detail = e.response?.data is Map<String, dynamic>
          ? e.response?.data['detail']
          : null;

      if (mounted) {
        setState(() {
          _message = _verificationErrorMessage(
            statusCode: e.response?.statusCode,
            detail: detail?.toString(),
          );
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _message = 'An unexpected error occurred';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _verificationErrorMessage({
    required int? statusCode,
    required String? detail,
  }) {
    if (statusCode == 400 && detail == 'Invalid verification code') return 'Invalid verification code';
    if (statusCode == 400 && detail == 'Verification code has expired') return 'Verification code has expired';
    if (statusCode == 409 && detail == 'Verification code has already been used') return 'This code has already been used';
    return detail ?? 'An unexpected error occurred';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => AuthScreen(startInSignUp: true)),
          (route) => false,
        );
      },
      child: Scaffold(
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
                        Text(
                          'Verify email',
                          style: AppTextStyles.display.copyWith(fontSize: 24),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Check your email for a 6-digit verification code.',
                          style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          widget.initialEmail,
                          style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(6, (index) {
                            return SizedBox(
                              width: 46,
                              child: KeyboardListener(
                                focusNode: FocusNode(),
                                autofocus: false,
                                onKeyEvent: (event) {
                                  if (event is KeyDownEvent &&
                                      event.logicalKey == LogicalKeyboardKey.backspace &&
                                      _codeControllers[index].text.isEmpty &&
                                      index > 0) {
                                    _codeFocusNodes[index - 1].requestFocus();
                                    _codeControllers[index - 1].clear();
                                  }
                                },
                                child: TextFormField(
                                  controller: _codeControllers[index],
                                  focusNode: _codeFocusNodes[index],
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  maxLength: 1,
                                  textInputAction: index == 5 ? TextInputAction.done : TextInputAction.next,
                                  style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
                                  decoration: _otpDecoration(),
                                  onChanged: (value) {
                                    if (value.length > 1) {
                                      _handlePaste(value);
                                      return;
                                    }
                                    if (value.isNotEmpty && index < 5) {
                                      _codeFocusNodes[index + 1].requestFocus();
                                    }
                                  },
                                  onTap: () {
                                    if (_codeControllers[index].text.isNotEmpty) {
                                      _codeControllers[index].selection = TextSelection.collapsed(
                                        offset: _codeControllers[index].text.length,
                                      );
                                    }
                                  },
                                  onEditingComplete: () {
                                    if (index < 5) {
                                      _codeFocusNodes[index + 1].requestFocus();
                                    } else {
                                      FocusScope.of(context).unfocus();
                                    }
                                  },
                                  validator: (value) {
                                    final code = _codeControllers.map((controller) => controller.text).join();
                                    if (code.length != 6) return 'Enter the 6-digit code';
                                    return null;
                                  },
                                ),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 8),
                        if (_message != null) ...[
                          Text(
                            _message!,
                            style: AppTextStyles.body.copyWith(color: AppColors.error),
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
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Verify'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: TextButton(
                            onPressed: () {
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(builder: (_) => AuthScreen(startInSignUp: true)),
                                (route) => false,
                              );
                            },
                            child: const Text(
                              'Back to sign up',
                              style: TextStyle(decoration: TextDecoration.underline),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ));
  }

  void _handlePaste(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    for (var i = 0; i < _codeControllers.length; i++) {
      _codeControllers[i].text = i < digits.length ? digits[i] : '';
    }
    final nextIndex = digits.length.clamp(0, 5);
    _codeFocusNodes[nextIndex].requestFocus();
  }

  InputDecoration _otpDecoration() {
    return InputDecoration(
      counterText: '',
      filled: true,
      fillColor: AppColors.bg1.withValues(alpha: 0.9),
      contentPadding: const EdgeInsets.symmetric(vertical: 14),
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
