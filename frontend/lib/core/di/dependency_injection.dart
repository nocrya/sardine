import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sardine/core/network/dio_client.dart';
import 'package:sardine/features/auth/data/auth_remote_datasource.dart';

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
}
