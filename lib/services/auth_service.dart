import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthState {
  final Map<String, dynamic>? payload;
  final String? error;

  const AuthState({this.payload, this.error});
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState());

  void setPayload(Map<String, dynamic> payload) {
    state = AuthState(payload: payload);
  }

  void setError(String error) {
    state = AuthState(error: error);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});