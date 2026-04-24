import 'dart:developer' as dev;

/// 轻量日志封装，后续可替换为 log 包等。
void appLog(String message, {String name = 'Sardine'}) {
  dev.log(message, name: name);
}
