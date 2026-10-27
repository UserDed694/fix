/// Настройки «простого режима» брендированного клиента.
///
/// Здесь собрано всё, что отличает наш клиент от исходного FlClash, но не
/// требует правок в платформенных папках: флаг простого режима, единственный
/// разрешённый хост подписок, превращение «ключа» в ссылку подписки и
/// заголовок устройства для панели. Файл экспортируется из `common.dart`,
/// поэтому доступен везде через `package:fl_clash/common/common.dart`.
library;

import 'package:fl_clash/common/string.dart';
import 'package:fl_clash/enum/enum.dart';

/// Полный интерфейс FlClash собирается с `--dart-define=SIMPLE_MODE=false`.
const simpleMode = bool.fromEnvironment('SIMPLE_MODE', defaultValue: true);

const allowedSubscriptionHost = 'subrw.victorycloud.ru';

/// Заголовок, по которому панель Remnawave считает устройства пользователя.
const hwidHeader = 'x-hwid';

const deviceIdKey = 'device_id';

const defaultPageLabel = simpleMode ? PageLabel.home : PageLabel.dashboard;

final _token = RegExp(r'^[A-Za-z0-9._~-]+$');

/// Готовую ссылку возвращает как есть; голый ключ из личного кабинета
/// превращает в ссылку подписки нашей панели.
String subscriptionUrlFor(String input) {
  final value = input.trim();
  if (!_token.hasMatch(value)) {
    return value;
  }
  return 'https://$allowedSubscriptionHost/$value';
}

bool isAllowedSubscriptionUrl(String url) =>
    url.webUri?.host.toLowerCase() == allowedSubscriptionHost;

/// Идентификатор устройства уходит только нашей панели, чужим серверам
/// (geo-данные, провайдеры правил) ничего лишнего не сообщаем.
Map<String, String> subscriptionHeaders(Uri uri, String deviceId) =>
    uri.host.toLowerCase() == allowedSubscriptionHost
    ? {hwidHeader: deviceId}
    : const {};
