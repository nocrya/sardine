import 'package:dio/dio.dart';
import 'package:sardine/core/utils/logger.dart';

/// 简单请求/响应日志拦截器，占位，后续可接鉴权、刷新 token 等。
class AppLoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    appLog('${options.method} ${options.uri}');
    return super.onRequest(options, handler);
  }
}
