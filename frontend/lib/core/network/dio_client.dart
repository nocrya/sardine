import 'package:dio/dio.dart';
import 'package:sardine/core/constants/app_constants.dart';
import 'package:sardine/core/network/dio_interceptors.dart';

/// 构造默认 [Dio]，可在此统一起 baseUrl、超时、拦截器。
Dio buildDioClient() {
  final options = BaseOptions(
    baseUrl: AppConstants.defaultApiBaseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 20),
  );
  final dio = Dio(options)..interceptors.add(AppLoggingInterceptor());
  return dio;
}
