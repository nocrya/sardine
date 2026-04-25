import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sardine/core/network/dio_client.dart';
import 'package:sardine/features/auth/data/auth_remote_datasource.dart';
import 'package:sardine/features/direct_message/data/direct_message_remote_datasource.dart';
import 'package:sardine/features/server/data/server_remote_datasource.dart';
import 'package:sardine/features/server/data/workspace_realtime_service.dart';
import 'package:sardine/features/voice/data/voice_remote_datasource.dart';

/// 全局 GetIt 定位器
final getIt = GetIt.instance;

/// 注册可替换的单例；在 [main] 中调用一次。
Future<void> configureDependencies() async {
  if (!getIt.isRegistered<Dio>()) {
    getIt.registerSingleton<Dio>(buildDioClient());
  }

  if (!getIt.isRegistered<SharedPreferences>()) {
    final preferences = await SharedPreferences.getInstance();
    getIt.registerSingleton<SharedPreferences>(preferences);
  }

  if (!getIt.isRegistered<AuthRemoteDataSource>()) {
    getIt.registerLazySingleton<AuthRemoteDataSource>(AuthRemoteDataSource.new);
  }

  if (!getIt.isRegistered<ServerRemoteDataSource>()) {
    getIt.registerLazySingleton<ServerRemoteDataSource>(
        ServerRemoteDataSource.new);
  }

  if (!getIt.isRegistered<DirectMessageRemoteDataSource>()) {
    getIt.registerLazySingleton<DirectMessageRemoteDataSource>(
      DirectMessageRemoteDataSource.new,
    );
  }

  if (!getIt.isRegistered<VoiceRemoteDataSource>()) {
    getIt.registerLazySingleton<VoiceRemoteDataSource>(
      VoiceRemoteDataSource.new,
    );
  }

  if (!getIt.isRegistered<WorkspaceRealtimeService>()) {
    getIt.registerLazySingleton<WorkspaceRealtimeService>(
      () => WorkspaceRealtimeService(getIt<AuthRemoteDataSource>()),
    );
  }
}
