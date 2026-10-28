# fix — VPN-клиент VictoryCloud

Брендированный клиент для подписок VictoryCloud (панель Remnawave).
Пользователь вставляет ключ или ссылку подписки, нажимает «Подключить» и выбирает сервер.
Чужие подписки и свои серверы в простом режиме не принимаются.

Сайт: <https://victorycloud.ru>, поддержка: <https://t.me/VictorySup_bot>.

Платформы: Android, macOS, Windows (один общий Flutter-код). Linux собирается, но не проверялся. iOS отложен.

## Происхождение и лицензия

Проект основан на [FlClash](https://github.com/chen08209/FlClash) (© chen08209, GPL-3.0)
с ядром [mihomo](https://github.com/MetaCubeX/mihomo) (Clash.Meta). Код распространяется
под той же лицензией [GPL-3.0](LICENSE): исходники этого репозитория публичны, изменения
относительно FlClash описаны в истории коммитов и ниже. Имя FlClash в приложении не используется,
кроме обязательной строки «Основано на FlClash» на экране «О программе».

## Что изменено относительно FlClash

- **Простой режим** (`lib/views/simple/simple_home.dart`): первый экран — поле «ключ или ссылка подписки»,
  кнопка «Подключить», статус, трафик, список серверов, меню «Сменить подписку» и «Расширенные настройки».
  Все остальные экраны FlClash живут в «Расширенных настройках» → раздел «Ещё».
- **Только наш домен**: принимаются подписки с хоста `subrw.victorycloud.ru`
  (константа `allowedSubscriptionHost` в `lib/common/brand.dart`). Голый ключ превращается в
  `https://subrw.victorycloud.ru/<ключ>`. Импорт файлов, QR и ручные серверы в простом режиме закрыты.
- **Заголовок `x-hwid`**: при скачивании подписки с нашего хоста отправляется стабильный идентификатор устройства
  (UUID, генерируется один раз), чтобы панель могла считать устройства.
- **Ребрендинг**: имя `fix`, вендор VictoryCloud, идентификатор `ru.victorycloud.fix` на Android и macOS,
  бинарник `fix.exe` на Windows, иконка-заглушка, ссылки на сайт и поддержку, проверка обновлений выключена.
- **CI**: `.github/workflows/build.yaml` собирает все платформы и выкладывает артефакты (см. ниже).

Полный интерфейс FlClash можно вернуть для отладки флагом сборки `--dart-define=SIMPLE_MODE=false`.

## Структура репозитория

| Путь | Что это |
| --- | --- |
| `lib/` | Flutter-приложение. `lib/common/brand.dart` — все константы бренда и домена. |
| `lib/views/simple/` | Простой экран. |
| `core/` | Go-обёртка ядра; `core/Clash.Meta` — подмодуль с ядром mihomo (форк chen08209, ветка `FlClash`). |
| `plugins/` | Локальные Flutter-плагины (сборка ядра, Rust-мост, трей, окно). |
| `services/helper` | Rust-служба для Windows и Linux (системный прокси, TUN). |
| `android/`, `macos/`, `windows/`, `linux/` | Платформенные проекты. |
| `arb/` | Переводы; русский полный. После правки: `dart run intl_utils:generate`. |
| `setup.dart` | Скрипт сборки пакетов (APK, dmg, exe/zip) в `dist/`. |
| `.github/workflows/build.yaml` | Сборка в GitHub Actions. |

## Сборка

Нужны: Flutter 3.47.x, Go 1.27.x, Rust через rustup, Git с подмодулями.

```bash
git clone --recursive https://github.com/UserDed694/fix.git
cd fix
flutter pub get
```

### Android (на Mac или Linux)

Дополнительно: Android SDK с NDK r28c и JDK 17. На этом Mac всё установлено без Homebrew в
`~/development` и `~/Library/Android/sdk`; переменные окружения задаёт `~/development/env.sh`.

```bash
source ~/development/env.sh
dart setup.dart android --arch arm64
```

Результат: `dist/fix-<версия>-android-arm64-v8a.apk`. Без `--arch` собираются все три ABI.
Без keystore APK подписывается отладочным ключом, а к идентификатору добавляется суффикс `.dev`
(так устроен `android/app/build.gradle.kts`). Для релиза создайте ключ:

```bash
keytool -genkey -v -keystore android/app/keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias fix
```

и запишите `storePassword`, `keyPassword`, `keyAlias`, `storeFile` в `android/local.properties`
(файл и keystore в git не попадают).

### macOS (только на Mac с полным Xcode)

Нужны Xcode из App Store и Node.js (скрипт сам ставит `appdmg` через npm).

```bash
sudo xcode-select -s /Applications/Xcode.app
dart setup.dart macos
```

Результат: `dist/fix-<версия>-macos-<arch>.dmg`. Сборка не подписана: при первом запуске macOS
покажет предупреждение, открыть можно через «Системные настройки → Конфиденциальность и безопасность».

### Windows

Собирается только на Windows (MinGW-w64 для ядра, Inno Setup 6 для установщика), поэтому здесь
используется GitHub Actions. Локально на Mac собрать нельзя.

### GitHub Actions

Workflow `build` запускается:

- при пуше в `main` — все пакеты попадают в артефакты запуска (Actions → запуск → Artifacts:
  `package-android`, `package-windows-amd64`, `package-macos-arm64`, `package-macos-amd64`);
- при пуше тега `v1.2.3` — то же плюс GitHub Release с файлами и `SHA256SUMS`;
- вручную: Actions → `build` → Run workflow, можно выбрать одну платформу.

Необязательные секреты для подписи Android: `KEYSTORE` (base64 от keystore.jks), `KEY_ALIAS`,
`STORE_PASSWORD`, `KEY_PASSWORD`. Без них собирается отладочная подпись.

## Как обновить ядро mihomo

Ядро лежит в подмодуле `core/Clash.Meta` и указывает на форк chen08209 (ветка `FlClash`),
в котором есть нужные FlClash правки. Обновление:

```bash
cd core/Clash.Meta
git fetch origin FlClash
git checkout origin/FlClash
cd ../..
git add core/Clash.Meta
git commit -m "chore(core): update mihomo"
```

Проще всего брать тот коммит подмодуля, на который указывает свежий релиз FlClash:
`git -C core/Clash.Meta checkout <хеш из FlClash>`. Версия Go для ядра задана в `core/go.mod`
и в `.github/workflows/build.yaml` (`GO_VERSION`); при смене ядра сверьте их.

## Как обновить базу FlClash

```bash
git remote add upstream https://github.com/chen08209/FlClash.git
git fetch upstream
git merge upstream/main
```

Конфликты ожидаемы в `lib/common/constant.dart`, `arb/*.arb`, `lib/views/navigation.dart`
и платформенных файлах с именами. После слияния: `dart run intl_utils:generate`,
`dart run build_runner build --delete-conflicting-outputs`, `flutter analyze`, `flutter test`.

## Как поменять бренд

- Имя, домен, ссылки: `lib/common/brand.dart` и `lib/common/constant.dart`.
- Иконка: положить PNG 1024×1024 в `assets/images/icon.png` и перегенерировать наборы
  для Android (`android/app/src/main/res/mipmap-*`), macOS (`macos/Runner/Assets.xcassets/AppIcon.appiconset`),
  Windows (`windows/runner/resources/app_icon.ico`, собирается `tool/src/icons/ico.dart`).
  Иконки трея в `assets/images/tray` и `assets_source/images/icon/*.svg` пока от FlClash:
  для них нужен SVG логотипа и `rsvg-convert` (`dart run tool/generate_status_icons.dart`).
- Идентификаторы: `android/app/build.gradle.kts` (`applicationId`), `macos/Runner/Configs/AppInfo.xcconfig`,
  `windows/CMakeLists.txt` и `windows/runner/Runner.rc`, `distribute_options.yaml` (имя файлов пакетов).

## Что ещё не сделано

- **iOS**: нужен Apple Developer (99 $/год) и Network Extension; в FlClash iOS нет, потребуется отдельная работа.
- **Магазины**: Google Play, App Store, Microsoft Store не настраивались.
- **Подпись**: macOS (notarization) и Windows (code signing) не подписываются; Android — только отладочный ключ.
- **Автообновление**: проверка обновлений выключена; включить можно после первых релизов в `UserDed694/fix`
  (`autoCheckUpdate` в `lib/models/config.dart`).
- **Иконки трея и уведомлений** остались от FlClash (см. выше).
- **Hysteria2**: в mihomo-подписке с панели сейчас только VLESS/REALITY и Trojan-WS; Hysteria2-ноды
  в шаблон не попадают, это настраивается на стороне Remnawave.
- **Linux** собирается, но не проверялся.
- Внутренние имена ядра и Kotlin-пакет `com.follow.clash` намеренно не переименованы:
  это не видно пользователю, а переименование затронуло бы десятки файлов и AAR ядра.
