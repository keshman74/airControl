# airControl Mobile

## Архитектура

Текущая основная версия для iPhone — восстановленное нативное приложение `ios-native/LPMusicKitDemo.xcodeproj` на Linkplay Music Kit. Оно сохраняет уже реализованный интерфейс и поведение. `npm run ios` открывает именно этот проект.

`src/`, `ios/` и `android/` — отдельный React/Capacitor прототип и общие сетевые наработки. Они сохранены для переноса и будущей Android-версии; это не текущая iPhone-сборка. План переноса и карта экранов находятся в `android-port/`.

## Запуск и синхронизация

Открыть и собрать текущую нативную iOS-версию:

```bash
npm run ios
```

Открыть общий React/Capacitor прототип:

```bash
npm ci
npm run sync
npm run ios:capacitor
npm run android
```

В Xcode выберите схему `LPMusicKitDemo`, устройство и Team в **Signing & Capabilities**. Для React/Capacitor приложения выберите схему `App`; для Android выберите телефон или эмулятор в Android Studio.

Перед подключением к Linkplay разрешите локальную сеть на iOS. Текущий общий HTTP-клиент работает с локальными IPv4-адресами и проверенными HTTPAPI/UPnP маршрутами.

## Текущее состояние

Нативный клиент — основной продуктовый вариант для iPhone. React/Capacitor клиент содержит подключение к устройству, чтение очередей PlayQueue и сценарий Deezer для подтверждённых устройств/прошивок. Android-проект пока является оболочкой прототипа; функциональный паритет с нативной версией ещё предстоит реализовать.

Перед добавлением платформенной функции проверяйте, можно ли реализовать её общим HTTP/UPnP протоколом. Если нужен Capacitor-плагин, его контракт должен иметь реализацию и для iOS, и для Android до подключения к UI.

## Источники

- React-клиент: `src/`
- iOS Capacitor-оболочка: `ios/`
- Android Capacitor-оболочка: `android/`
- Основной нативный iOS-проект: `ios-native/`
- Android-перенос: `android-port/`
- Общий React/Capacitor прототип: `src/`, `ios/`, `android/`
- [Linkplay Protocol KB](https://github.com/keshman74/airControl-Protocol-KB/pull/8)
