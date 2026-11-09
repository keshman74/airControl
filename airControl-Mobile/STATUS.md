# airControl Mobile · статус на 9 ноября 2026

Единая ветка iOS и Android в [keshman74/airControl](https://github.com/keshman74/airControl/tree/airControl-Mobile), созданная от `origin/main` (`16f8436`). Версия приложения `0.1.0`. Код React, HTTPAPI и UPnP PlayQueue находится в `airControl-Mobile/src/`; платформенные проекты находятся в `ios/` и `android/`. В Git входят lockfile, SwiftPM pin, Gradle Wrapper и исходные файлы обеих платформ. Capacitor восстанавливает веб-ресурсы и сгенерированные файлы из общих исходников. Подпись настраивается локально.

| Назначение | Локальный путь на Mac |
|---|---|
| Рабочая копия для Codex Local | `/Users/lab/AI/airControl/airControl-mobile-work` |
| Исходный React + Capacitor прототип | `/Users/lab/AI/airControl/airControl-Mobile` |
| Xcode общего приложения | `/Users/lab/AI/airControl/airControl-mobile-work/airControl-Mobile/ios/App/App.xcodeproj` |
| Android Studio | `/Users/lab/AI/airControl/airControl-mobile-work/airControl-Mobile/android` |
| Нативный iOS-проект | `/Users/lab/AI/airControl/airControl-iOS-SDK/LPMusicKitDemo.xcodeproj` |
| Инструкция и контроллер нативного проекта | `/Users/lab/AI/airControl/airControl-iOS-SDK/README.md`, `/Users/lab/AI/airControl/airControl-iOS-SDK/LPMusicKitDemo/ACHome.m` |
| Локальный снимок нативного проекта с контрольной суммой и журналом сборки | `/Users/lab/AI/airControl/Linkplay-SDK-Archive/airControl-iOS-SDK-baseline-20261109/` |

## Источники и испытания протокола

- [Документация Linkplay Mobile SDK](https://linkplayapp.github.io/linkplay_sdk_doc/en/) и [исходники документации](https://github.com/linkplayapp/linkplay_sdk_doc).
- [airControl Protocol KB и материалы аудита, PR №8](https://github.com/keshman74/airControl-Protocol-KB/pull/8). [Аудит Android и iOS](https://github.com/keshman74/airControl-Protocol-KB/tree/90e04ea/evidence/official-docs/LINKPLAY-MOBILE-SDK-FULL-AUDIT-2026-11-09). Локально аудит находится в `/Users/lab/AI/airControl/Linkplay-Mobile-SDK-KB/evidence/official-docs/LINKPLAY-MOBILE-SDK-FULL-AUDIT-2026-11-09/`, снимок исходников в `/Users/lab/AI/airControl/Linkplay-Mobile-SDK-source-snapshot/`.
- Office 29, A31, `192.168.0.29`, прошивка `4.6.415156`. Устройство объявило BrowseQueue в собственном SCPD. Чтение `CurrentQueue`, `USBDiskQueue` и `TotalQueue` подтверждено прямым UPnP. [Операции и описание](https://github.com/keshman74/airControl-Protocol-KB/blob/90e04ea/evidence/hardware-tests/OFFICE29-A31-PLAYQUEUE-2026-11-09.md) · [Пакетный прогон](https://github.com/keshman74/airControl-Protocol-KB/tree/90e04ea/evidence/hardware-tests/OFFICE29-A31-BATCH-2026-11-09).
- `LastPlayIndex` отсчитывается от 1 при стабильной текущей очереди на проверенных источниках Office 29. Есть 23 валидных измерения USB и 11 Qobuz. [Индекс USB](https://github.com/keshman74/airControl-Protocol-KB/blob/90e04ea/evidence/hardware-tests/OFFICE29-A31-PLAYQUEUE-INDEX-2026-11-09.md) · [Индекс Qobuz](https://github.com/keshman74/airControl-Protocol-KB/blob/90e04ea/evidence/hardware-tests/OFFICE29-A31-QOBUZ-QUEUE-2026-11-09.md).
- В аппаратном снимке проверены 63 HTTPS-обложки Qobuz и 58 записей USB, включая 10 записей с повреждённым вложенным DIDL. Общий клиент читает внешний ответ и использует имя файла, когда оно доступно. [Метаданные и повреждённый DIDL](https://github.com/keshman74/airControl-Protocol-KB/blob/90e04ea/evidence/hardware-tests/OFFICE29-A31-QOBUZ-QUEUE-METADATA-2026-11-09.md).

Локальные сырые материалы в `/Users/lab/AI/airControl/`:

| Файл | Назначение |
|---|---|
| `office29-audit-20261109-012722/report.json` | Начальная инвентаризация, 5122 строки аудита |
| `office29-batch-20261109-020707/report.json` | Массовый аппаратный прогон |
| `office29-playqueue-20261109-040621/report.json` | Описание устройства, SCPD и ответы очередей |
| `office29-queue-index-20261109-041101/samples.jsonl` | Переключения USB |
| `office29-qobuz-index-20261109-041402/samples.jsonl` | Переключения Qobuz |
| `office29-qobuz-browse-20261109-051524/report.json` и XML в той же папке | Снимки очередей и метаданных для повторной проверки парсера |
| `/tmp/aircontrol-mobile-xcode.log` | Предыдущая сборка исходного общего прототипа |
| `/tmp/aircontrol-mobile-work-build.log` | Подписанная сборка из новой рабочей копии |

## Возможности и перенос

| Функция | Общий прототип | Нативный iOS, Music Kit 1.0.14 | Следующий шаг |
|---|---|---|---|
| Устройства | Ручной IPv4, проверка UUID и прошивки, поиск описания по портам | SDK discovery, online/offline и выбор по UUID, IP и прошивка | Проверить discovery на iPhone, затем добавить общий список и платформенные адаптеры поиска |
| Сейчас играет | Чтение статуса, HTTPS-обложка, подсветка трека при стабильной очереди и индексе в диапазоне | Метаданные, обложка, play/pause, назад/вперёд, позиция и громкость | Проверить команды и отклик на Office 29, затем добавить управление в общий плеер |
| Обзор | CurrentQueue, USBDiskQueue, TotalQueue, обновление и обработка повреждённого DIDL | Те же три очереди через SDK, резервное имя файла, правило индекса для Office 29 | Сверить результаты двух реализаций на USB и Qobuz |
| Настройки | Ожидает переноса | Выбор объявленного входа, просмотр EQ, таймер сна | Сверить чтение и изменение каждого параметра на устройстве |
| Дополнительные экраны | Ожидают переноса | Переиспользованы экраны демо для пресетов, NAS, медиатеки iPhone, Multiroom и будильников | Проверить доступность на каждом устройстве и переносить по одному сценарию |
| Аккаунты и каталоги сервисов, RoomFit, первоначальная настройка устройства, редактирование очереди | Ожидают реализации | Ожидают реализации; чтение текущей очереди Qobuz подтверждает только протокол чтения очереди | Определить доступные API, разрешения и сценарии испытаний |

## Сборка и ручной прогон

```bash
cd /Users/lab/AI/airControl/airControl-mobile-work/airControl-Mobile
npm ci
npm run sync
```

Нужен Node.js 22 или новее для Capacitor 8. В новой копии использован Node.js 26.0.0. После изменения `src/` повторить `npm run sync`.

1. **iOS.** Выполнить `npm run ios`. В Xcode выбрать target **App**, включить **Automatically manage signing**, выбрать свою **Team** и физический iPhone. При необходимости включить Developer Mode. Нажать Run и разрешить доступ к локальной сети. Для сборки на физическое устройство из терминала передать свой `DEVELOPMENT_TEAM` и использовать `-allowProvisioningUpdates`.
2. **Android.** Установить Android Studio, JDK 21 (подойдёт встроенный JBR 21) и Android SDK Platform 36. В SDK Manager установить Platform Tools, включить отладку по USB на телефоне и принять запрос авторизации. Открыть проект командой `npm run android`, дождаться Gradle Sync, выбрать телефон и нажать Run. CLI для сборки после настройки SDK и Java — `cd android && ./gradlew assembleDebug`.
3. **Сценарий на обоих телефонах.** Подключить телефон к той же Wi‑Fi сети, открыть приложение и нажать **Подключить** для `192.168.0.29`. Сверить устройство и прошивку. Открыть **Сейчас играет**, **USB**, **Очереди** и нажать **Обновить** на каждой вкладке. При подключённом USB запустить трек и переключить его, сверив название и подсветку. Повторить для Qobuz на самом Office 29. Если очередь пуста, зафиксировать это отдельно от сетевой ошибки. В общем прототипе адрес вводится вручную.
4. **Нативный контроль.** Проверить SHA-256 локального архива командой `shasum -a 256 -c SHA256SUMS` из его папки. Распаковать архив в отдельный каталог, открыть `LPMusicKitDemo.xcodeproj` и выбрать схему `LPMusicKitDemo`, свою Team и iPhone. SDK 1.0.14 входит в локальный снимок, исходный дистрибутив и checksum находятся в `/Users/lab/AI/airControl/Linkplay-SDK-Archive/iOS/1.0.14/`, демо в `iOS/1.0.14-demo/` под тем же корнем. Android-демо `Android/1.1.5-demo/` содержит исходники и Maven-координаты, поставка AAR ожидает отдельного доступа. Закрытые SDK, локальные журналы и пользовательские ответы устройства хранятся отдельно от ветки.

## Результаты контрольного прогона

| Приложение и версия | Платформа и устройство | Сценарий | Результат и подтверждение |
|---|---|---|---|
| Общее, 0.1.0 из этой ветки | macOS, Node 26 | Чистая установка зависимостей, Vite и синхронизация Capacitor | `npm ci` и `npm run sync` успешны для обоих проектов |
| Общее, 0.1.0 из этой ветки | iOS, iPhone 13 | Подписанная сборка в Xcode 26.6, установка, запуск | `BUILD SUCCEEDED`; `devicectl` подтвердил установку и запуск `com.filmoscopelab.aircontrol.mobile`. Копия журнала `/Users/lab/AI/airControl/Linkplay-SDK-Archive/airControl-iOS-SDK-baseline-20261109/common-mobile-build.log` |
| Общее, 0.1.0 из этой ветки | iOS, iPhone 13 → Office 29 | Ручное подключение, «Сейчас играет», USB и «Очереди» | Владелец подтвердил работу подключения и всех трёх вкладок в чате. Отдельная сверка подсветки при переключении трека, повреждённых USB-строк и обложек в интерфейсе ожидает проверки. Автоматического обнаружения устройств в этой версии нет |
| Общий клиент из этой ветки | Node на Mac → Office 29, A31 4.6.415156 | HTTPAPI, обнаружение PlayQueue через SCPD, три операции BrowseQueue | `getStatusEx` вернул Office 29, `getPlayerStatus` вернул `play`, TotalQueue — 5 записей, CurrentQueue — 1 трек, USBDiskQueue — 58 треков. Запросы выполнил `src/linkplay.js` с подставленным транспортом Node и XML-парсером |
| Общее, 0.1.0 из этой ветки | Android, Mac без JDK и SDK | Debug APK и повтор сценария | `./gradlew assembleDebug` остановился на поиске Java. Сборка, установка и аппаратная проверка ожидают Android Studio, SDK и устройства |
| Нативное, Music Kit 1.0.14 | iOS, iPhone 13 | Подписанная сборка, установка и запуск | `BUILD SUCCEEDED` в `native-build.log` локального снимка. Установка и запуск `com.filmoscopelab.aircontrol.native` подтверждены `devicectl` в предыдущем прогоне |
| Нативное, Music Kit 1.0.14 | iOS, iPhone 13 → Office 29 | SDK discovery и аппаратные сценарии отдельных экранов | Ожидают проверки. Прямые UPnP-результаты выше относятся к другому пути выполнения |

Для работы в Codex откройте корень `/Users/lab/AI/airControl/airControl-mobile-work` как локальный проект и выберите **Local** и ветку `airControl-Mobile`. Для независимых задач создавайте **Worktree** от той же ветки.
