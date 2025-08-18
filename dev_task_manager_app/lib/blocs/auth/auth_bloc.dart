import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dio/dio.dart';
import '../../services/auth_service.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthService _authService = AuthService();

  AuthBloc() : super(AuthInitial()) {
    on<CheckAuthStatus>(_onCheckAuthStatus);
    on<LoginRequested>(_onLoginRequested);
    on<RegisterRequested>(_onRegisterRequested);
    on<LogoutRequested>(_onLogoutRequested);
  }

  Future<void> _onCheckAuthStatus(
      CheckAuthStatus event, Emitter<AuthState> emit) async {
    try {
      final user = await _authService.getCurrentUser();
      if (user != null) {
        emit(AuthSuccess(user: user));
      } else {
        emit(AuthUnauthenticated());
      }
    } catch (e) {
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onLoginRequested(
      LoginRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final user = await _authService.login(event.email, event.password);
      emit(AuthSuccess(user: user));
    } on DioException catch (e) {
      String errorMessage = 'Login failed';
      if (e.response?.data != null) {
        errorMessage = e.response!.data['message'] ?? errorMessage;
      }
      emit(AuthFailure(message: errorMessage));
    } catch (e) {
      emit(AuthFailure(message: 'An unexpected error occurred'));
    }
  }

  Future<void> _onRegisterRequested(
      RegisterRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final user =
          await _authService.register(event.name, event.email, event.password);
      emit(AuthSuccess(user: user));
    } on DioException catch (e) {
      String errorMessage = 'Registration failed';
      if (e.response?.data != null) {
        errorMessage = e.response!.data['message'] ?? errorMessage;
      }
      emit(AuthFailure(message: errorMessage));
    } catch (e) {
      emit(AuthFailure(message: 'An unexpected error occurred'));
    }
  }

  Future<void> _onLogoutRequested(
      LogoutRequested event, Emitter<AuthState> emit) async {
    try {
      await _authService.logout();
      emit(AuthUnauthenticated());
    } catch (e) {
      emit(AuthFailure(message: 'Logout failed'));
    }
  }
}
