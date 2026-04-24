import 'package:dio/dio.dart';
import 'package:sardine/core/di/dependency_injection.dart';

class ServerRemoteDataSource {
  ServerRemoteDataSource([Dio? client]) : _dio = client ?? getIt<Dio>();
  final Dio _dio;

  Dio get client => _dio;
}
