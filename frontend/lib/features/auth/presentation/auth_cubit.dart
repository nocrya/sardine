import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sardine/features/auth/data/auth_remote_datasource.dart';
import 'package:sardine/features/auth/data/auth_session.dart';

sealed class AuthViewState extends Equatable {
  const AuthViewState();

  @override
  List<Object?> get props => [];
}

class AuthInitialView extends AuthViewState {
  const AuthInitialView();
}

class AuthLoadingView extends AuthViewState {
  const AuthLoadingView();
}

class AuthenticatedView extends AuthViewState {
  const AuthenticatedView(this.session);

  final AuthSession session;

  @override
  List<Object?> get props => [session];
}

class AuthErrorView extends AuthViewState {
  const AuthErrorView(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

class AuthCubit extends Cubit<AuthViewState> {
  AuthCubit(this._dataSource) : super(const AuthInitialView()) {
    restoreSession();
  }

  final AuthRemoteDataSource _dataSource;

  Future<void> restoreSession() async {
    final session = _dataSource.loadSession();
    if (session == null) {
      emit(const AuthInitialView());
      return;
    }

    emit(const AuthLoadingView());
    try {
      final user = await _dataSource.me(session.accessToken);
      emit(
        AuthenticatedView(
          AuthSession(
            accessToken: session.accessToken,
            tokenType: session.tokenType,
            expiresAt: session.expiresAt,
            user: user,
          ),
        ),
      );
    } on DioException catch (error) {
      await _dataSource.clearSession();
      emit(AuthErrorView(_messageFrom(error)));
    }
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    emit(const AuthLoadingView());
    try {
      final session = await _dataSource.login(email: email, password: password);
      emit(AuthenticatedView(session));
    } on DioException catch (error) {
      emit(AuthErrorView(_messageFrom(error)));
    }
  }

  Future<void> register({
    required String email,
    required String username,
    required String password,
    required String displayName,
  }) async {
    emit(const AuthLoadingView());
    try {
      final session = await _dataSource.register(
        email: email,
        username: username,
        password: password,
        displayName: displayName,
      );
      emit(AuthenticatedView(session));
    } on DioException catch (error) {
      emit(AuthErrorView(_messageFrom(error)));
    }
  }

  Future<void> logout() async {
    await _dataSource.clearSession();
    emit(const AuthInitialView());
  }

  String _messageFrom(DioException error) {
    final data = error.response?.data;
    if (data is Map<String, dynamic> && data['error'] is String) {
      return data['error'] as String;
    }
    return error.message ?? 'Authentication request failed';
  }
}
