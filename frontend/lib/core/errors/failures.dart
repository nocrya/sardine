import 'package:equatable/equatable.dart';

/// 领域/应用层可展示的错误基类，与具体 UI/Bloc 解耦。
abstract class Failure extends Equatable {
  const Failure([this.message = '']);
  final String message;

  @override
  List<Object?> get props => [message];
}

/// 占位：网络/未知错误。
class UnknownFailure extends Failure {
  const UnknownFailure([super.message = 'Unknown error']);
}
