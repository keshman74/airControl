#import "ACHome.h"
#import <LPMusicKit/LPDeviceManager.h>
#import <LPMusicKit/LPDeviceInfo.h>
#import <LPMusicKit/LPDevicePlayer.h>
#import <LPMusicKit/LPDeviceSettings.h>
#import <LPMusicKit/LPDeviceTimer.h>
#import <LPMDPKit/LPMDPKitManager.h>
#import <LPMDPKit/LPPlayItem.h>
#import <LPMDPKit/LPPlayHeader.h>
#import <LPMDPKit/LPPlayMusicList.h>
#import <LPMDPKit/LPAccount.h>
#import "DDXMLDocument.h"
#import "UIImageView+WebCache.h"
#import "UIView+WebCache.h"
#import "NSObject+FBKVOController.h"
#import <arpa/inet.h>
#import <ifaddrs.h>
#import <Network/Network.h>
#import <Security/Security.h>
#import <CommonCrypto/CommonCryptor.h>
#import <WebKit/WebKit.h>
#import <AVFoundation/AVFoundation.h>
#import <CommonCrypto/CommonDigest.h>
#import "LPNASViewController.h"
#import "LPLocalMusicViewController.h"
#import "LPMultiroomViewController.h"
#import "PresetViewController.h"
#import "AlarmClockMainViewController.h"

static NSString * const ACChanged = @"airControlDeviceChanged";
static NSString * const ACOffice = @"FF31F09E48AFA4782E6479EC";
// Desktop airControl uses orange as the primary interaction accent. Keep green
// reserved for device connectivity/status indicators.
static UIColor *ACAccent(void) { return [UIColor colorWithRed:1.0 green:.624 blue:.039 alpha:1]; }
static UIColor *ACStatusAccent(void) { return [UIColor colorWithRed:.224 green:.851 blue:.541 alpha:1]; }
static UIColor *ACBackground(void) { return UIColor.blackColor; }
static UIColor *ACCard(void) { return [UIColor colorWithRed:.067 green:.067 blue:.067 alpha:1]; }
static UIColor *ACPrimaryText(void) { return UIColor.whiteColor; }
static UIColor *ACSecondaryText(void) { return [UIColor colorWithWhite:.72 alpha:1]; }
static UIColor *ACSeparator(void) { return [UIColor colorWithWhite:.34 alpha:1]; }
static NSString * const ACLanguagePreferenceKey = @"airControl.interfaceLanguage";
static NSString *ACLanguageCode(void) {
    NSString *preference = [[NSUserDefaults standardUserDefaults] stringForKey:ACLanguagePreferenceKey];
    if (preference.length && ![preference isEqualToString:@"auto"]) return preference;
    NSString *system = NSLocale.preferredLanguages.firstObject ?: @"uk";
    NSString *code = [[NSLocale localeWithLocaleIdentifier:system] objectForKey:NSLocaleLanguageCode] ?: @"uk";
    return [@[@"uk", @"en", @"he", @"ru"] containsObject:code] ? code : @"uk";
}
static NSString *ACT(NSString *uk, NSString *en, NSString *he, NSString *ru) {
    NSString *code = ACLanguageCode();
    if ([code isEqualToString:@"en"]) return en;
    if ([code isEqualToString:@"he"]) return he;
    if ([code isEqualToString:@"ru"]) return ru;
    return uk;
}
NSString *ACMenuText(NSString *value) {
    if (!value.length) return value;
    NSDictionary<NSString *, NSArray<NSString *> *> *translations = @{
        @"Обзор": @[@"Огляд", @"Browse", @"עיון", @"Обзор"],
        @"Устройства": @[@"Пристрої", @"Devices", @"התקנים", @"Устройства"],
        @"Настройки": @[@"Налаштування", @"Settings", @"הגדרות", @"Настройки"],
        @"Выбранная зона": @[@"Вибрана зона", @"Selected zone", @"אזור נבחר", @"Выбранная зона"],
        @"Коснитесь, чтобы выбрать устройство": @[@"Торкніться, щоб вибрати пристрій", @"Tap to select a device", @"הקש לבחירת התקן", @"Коснитесь, чтобы выбрать устройство"],
        @"Входы и источники": @[@"Входи та джерела", @"Inputs and sources", @"כניסות ומקורות", @"Входы и источники"],
        @"Выбрать вход на текущей зоне": @[@"Вибрати вхід поточної зони", @"Select input for this zone", @"בחר כניסה לאזור זה", @"Выбрать вход на текущей зоне"],
        @"БИБЛИОТЕКА": @[@"БІБЛІОТЕКА", @"LIBRARY", @"ספרייה", @"БИБЛИОТЕКА"],
        @"Фавориты": @[@"Улюблене", @"Favourites", @"מועדפים", @"Избранное"],
        @"Избранное содержимое устройства": @[@"Вибране на пристрої", @"Device favourites", @"מועדפים במכשיר", @"Избранное на устройстве"],
        @"USB": @[@"USB", @"USB", @"USB", @"USB"],
        @"AirPlay": @[@"AirPlay", @"AirPlay", @"AirPlay", @"AirPlay"],
        @"Deezer": @[@"Deezer", @"Deezer", @"Deezer", @"Deezer"],
        @"Qobuz": @[@"Qobuz", @"Qobuz", @"Qobuz", @"Qobuz"],
        @"TIDAL": @[@"TIDAL", @"TIDAL", @"TIDAL", @"TIDAL"],
        @"YouTube Music": @[@"YouTube Music", @"YouTube Music", @"YouTube Music", @"YouTube Music"],
        @"SoundCloud": @[@"SoundCloud", @"SoundCloud", @"SoundCloud", @"SoundCloud"],
        @"Радио": @[@"Радіо", @"Radio", @"רדיו", @"Радио"],
        @"Bluetooth": @[@"Bluetooth", @"Bluetooth", @"Bluetooth", @"Bluetooth"],
        @"Линейный вход": @[@"Лінійний вхід", @"Line In", @"כניסת Line", @"Линейный вход"],
        @"Оптический вход": @[@"Оптичний вхід", @"Optical In", @"כניסה אופטית", @"Оптический вход"],
        @"Медиатека накопителя на устройстве": @[@"Медіатека накопичувача пристрою", @"Device USB library", @"ספריית USB במכשיר", @"Медиатека накопителя на устройстве"],
        @"Папка": @[@"Папка", @"Folder", @"תיקייה", @"Папка"],
        @"Назад в папку USB": @[@"Назад до папки USB", @"Back to USB folder", @"חזרה לתיקיית USB", @"Назад в папку USB"],
        @"В этой папке нет файлов": @[@"У цій папці немає файлів", @"No files in this folder", @"אין קבצים בתיקייה זו", @"В этой папке нет файлов"],
        @"Пресеты": @[@"Пресети", @"Presets", @"תחנות קבועות", @"Пресеты"],
        @"Слоты быстрого доступа": @[@"Швидкий доступ до слотів", @"Quick access slots", @"קיצורי גישה", @"Слоты быстрого доступа"],
        @"Медиасерверы": @[@"Медіасервери", @"Media servers", @"שרתי מדיה", @"Медиасерверы"],
        @"Поиск NAS через SDK": @[@"Пошук NAS через SDK", @"Find NAS servers", @"חיפוש שרתי NAS", @"Поиск NAS через SDK"],
        @"Медиатека iPhone": @[@"Медіатека iPhone", @"iPhone library", @"ספריית iPhone", @"Медиатека iPhone"],
        @"Музыка на этом телефоне": @[@"Музика на цьому телефоні", @"Music on this phone", @"מוזיקה בטלפון זה", @"Музыка на этом телефоне"],
        @"РАДИО": @[@"РАДІО", @"RADIO", @"רדיו", @"РАДИО"],
        @"TuneIn": @[@"TuneIn", @"TuneIn", @"TuneIn", @"TuneIn"],
        @"Radio Browser": @[@"Radio Browser", @"Radio Browser", @"Radio Browser", @"Radio Browser"],
        @"Поиск радиостанций": @[@"Пошук радіостанцій", @"Find radio stations", @"חיפוש תחנות רדיו", @"Поиск радиостанций"],
        @"Каталог интернет-радио": @[@"Каталог інтернет-радіо", @"Internet radio directory", @"מדריך רדיו אינטרנטי", @"Каталог интернет-радио"],
        @"ОНЛАЙН-СЕРВИСЫ": @[@"ОНЛАЙН-СЕРВІСИ", @"MUSIC SERVICES", @"שירותי מוזיקה", @"ОНЛАЙН-СЕРВИСЫ"],
        @"Библиотека и воспроизведение": @[@"Медіатека та відтворення", @"Library and playback", @"ספרייה והשמעה", @"Библиотека и воспроизведение"],
        @"Вход и каталог сервиса": @[@"Вхід і каталог сервісу", @"Sign in and browse", @"התחברות וקטלוג השירות", @"Вход и каталог сервиса"],
        @"Жанры": @[@"Жанри", @"Genres", @"ז'אנרים", @"Жанры"],
        @"Страны": @[@"Країни", @"Countries", @"מדינות", @"Страны"],
        @"Местное радио": @[@"Місцеве радіо", @"Local radio", @"רדיו מקומי", @"Местное радио"],
        @"Назад в библиотеку": @[@"Назад до медіатеки", @"Back to library", @"חזרה לספרייה", @"Назад в библиотеку"],
        @"Назад к альбомам": @[@"Назад до альбомів", @"Back to albums", @"חזרה לאלבומים", @"Назад к альбомам"],
        @"Текущая очередь": @[@"Поточна черга", @"Current queue", @"תור נוכחי", @"Текущая очередь"],
        @"Каталог очередей": @[@"Каталог черг", @"Queue catalog", @"קטלוג תורים", @"Каталог очередей"],
        @"Сейчас играет": @[@"Зараз грає", @"Now playing", @"מושמע כעת", @"Сейчас играет"],
        @"Музыкальные сервисы": @[@"Музичні сервіси", @"Music services", @"שירותי מוזיקה", @"Музыкальные сервисы"],
        @"Плейлисты": @[@"Списки відтворення", @"Playlists", @"רשימות השמעה", @"Плейлисты"],
        @"Альбомы": @[@"Альбоми", @"Albums", @"אלבומים", @"Альбомы"],
        @"Вход в Qobuz": @[@"Вхід у Qobuz", @"Sign in to Qobuz", @"התחברות ל‑Qobuz", @"Вход в Qobuz"],
        @"Выберите зону": @[@"Виберіть зону", @"Select a zone", @"בחר אזור", @"Выберите зону"],
        @"Выберите устройство": @[@"Виберіть пристрій", @"Select a device", @"בחר התקן", @"Выберите устройство"],
        @"Discover": @[@"Огляд", @"Discover", @"גילוי", @"Обзор"],
        @"Library": @[@"Медіатека", @"Library", @"ספרייה", @"Библиотека"],
        @"My Library": @[@"Моя медіатека", @"My Library", @"הספרייה שלי", @"Моя библиотека"],
        @"My library": @[@"Моя медіатека", @"My library", @"הספרייה שלי", @"Моя библиотека"],
        @"My Playlists": @[@"Мої списки відтворення", @"My Playlists", @"רשימות ההשמעה שלי", @"Мои плейлисты"],
        @"Favourite Artists": @[@"Улюблені виконавці", @"Favourite Artists", @"אמנים מועדפים", @"Любимые исполнители"],
        @"Favourite Albums": @[@"Улюблені альбоми", @"Favourite Albums", @"אלבומים מועדפים", @"Любимые альбомы"],
        @"Favourite Tracks": @[@"Улюблені композиції", @"Favourite Tracks", @"רצועות מועדפות", @"Любимые треки"],
        @"Favourite Playlists": @[@"Улюблені списки", @"Favourite Playlists", @"רשימות מועדפות", @"Любимые плейлисты"],
        @"Purchased Albums": @[@"Придбані альбоми", @"Purchased Albums", @"אלבומים שנרכשו", @"Купленные альбомы"],
        @"Purchased Tracks": @[@"Придбані композиції", @"Purchased Tracks", @"רצועות שנרכשו", @"Купленные треки"],
        @"Playlists": @[@"Списки відтворення", @"Playlists", @"רשימות השמעה", @"Плейлисты"],
        @"Albums": @[@"Альбоми", @"Albums", @"אלבומים", @"Альбомы"],
        @"Tracks": @[@"Композиції", @"Tracks", @"רצועות", @"Треки"],
        @"Artists": @[@"Виконавці", @"Artists", @"אמנים", @"Исполнители"],
        @"Genres": @[@"Жанри", @"Genres", @"ז'אנרים", @"Жанры"],
        @"Charts": @[@"Чарти", @"Charts", @"מצעדים", @"Чарты"],
        @"Recommendations": @[@"Рекомендації", @"Recommendations", @"המלצות", @"Рекомендации"],
        @"Mixes": @[@"Мікси", @"Mixes", @"מיקסים", @"Миксы"],
        @"Search": @[@"Пошук", @"Search", @"חיפוש", @"Поиск"],
        @"History": @[@"Історія", @"History", @"היסטוריה", @"История"],
        @"Following": @[@"Підписки", @"Following", @"במעקב", @"Подписки"],
        @"Logout": @[@"Вийти", @"Log out", @"התנתקות", @"Выйти"],
        @"No music selected": @[@"Музику не вибрано", @"No music selected", @"לא נבחרה מוזיקה", @"Музыка не выбрана"],
        @"No Music Selected": @[@"Музику не вибрано", @"No Music Selected", @"לא נבחרה מוזיקה", @"Музыка не выбрана"],
        @"A mix based on your favourites": @[@"Мікс на основі ваших уподобань", @"A mix based on your favourites", @"מיקס המבוסס על המועדפים שלך", @"Микс на основе ваших предпочтений"],
        @"Selected device": @[@"Вибраний пристрій", @"Selected device", @"התקן נבחר", @"Выбранное устройство"],
        @"Current queue": @[@"Поточна черга", @"Current queue", @"תור נוכחי", @"Текущая очередь"],
        @"Queue is empty": @[@"Черга порожня", @"Queue is empty", @"התור ריק", @"Очередь пуста"],
        @"No items": @[@"Немає елементів", @"No items", @"אין פריטים", @"Нет записей"],
        @"New Releases": @[@"Нові релізи", @"New Releases", @"מהדורות חדשות", @"Новые релизы"],
        @"Recommended for You": @[@"Рекомендовано для вас", @"Recommended for You", @"מומלץ עבורך", @"Рекомендации для вас"],
        @"Top Albums": @[@"Найкращі альбоми", @"Top Albums", @"האלבומים המובילים", @"Популярные альбомы"],
        @"Press Acclaim": @[@"Вибір критиків", @"Press Acclaim", @"בחירת המבקרים", @"Выбор критиков"],
        @"Qobuz Playlists": @[@"Списки відтворення Qobuz", @"Qobuz Playlists", @"רשימות השמעה של Qobuz", @"Плейлисты Qobuz"],
        @"Playlists by Category": @[@"Списки за категоріями", @"Playlists by Category", @"רשימות לפי קטגוריה", @"Плейлисты по категориям"],
        @"Qobuz Essential Discography": @[@"Основна дискографія Qobuz", @"Qobuz Essential Discography", @"דיסקוגרפיה נבחרת של Qobuz", @"Главное в дискографии Qobuz"],
        @"See All  ›": @[@"Усі  ›", @"See All  ›", @"הכול  ›", @"Все  ›"],
        @"Account": @[@"Обліковий запис", @"Account", @"חשבון", @"Аккаунт"],
        @"Back": @[@"Назад", @"Back", @"חזרה", @"Назад"],
        @"Cancel": @[@"Скасувати", @"Cancel", @"ביטול", @"Отмена"],
        @"Done": @[@"Готово", @"Done", @"סיום", @"Готово"],
        @"Play": @[@"Відтворити", @"Play", @"הפעל", @"Воспроизвести"],
        @"Pause": @[@"Пауза", @"Pause", @"השהה", @"Пауза"],
        @"Device": @[@"Пристрій", @"Device", @"התקן", @"Устройство"],
        @"devices": @[@"пристрої", @"devices", @"התקנים", @"устройства"],
        @"device": @[@"пристрій", @"device", @"התקן", @"устройство"],
        @"Pause All": @[@"Вимкнути все", @"Turn All Off", @"כיבוי הכול", @"Выключить всё"],
        @"Add Device": @[@"Додати пристрій", @"Add Device", @"הוסף התקן", @"Добавить устройство"],
        @"Group volume": @[@"Гучність групи", @"Group volume", @"עוצמת הקבוצה", @"Громкость группы"],
        @"Нет выбранной музыки": @[@"Музику не вибрано", @"No music selected", @"לא נבחרה מוזיקה", @"Нет выбранной музыки"],
        @"Выбрать музыку": @[@"Вибрати музику", @"Select music", @"בחר מוזיקה", @"Выбрать музыку"],
        @"ВОСПРОИЗВЕДЕНИЕ": @[@"ВІДТВОРЕННЯ", @"PLAYBACK", @"השמעה", @"ВОСПРОИЗВЕДЕНИЕ"],
        @"ЛИНЕЙНЫЙ ВХОД": @[@"ЛІНІЙНИЙ ВХІД", @"LINE IN", @"כניסת קו", @"ЛИНЕЙНЫЙ ВХОД"],
        @"СЕТЬ": @[@"МЕРЕЖА", @"NETWORK", @"רשת", @"СЕТЬ"],
        @"Громкость": @[@"Гучність", @"Volume", @"עוצמת קול", @"Громкость"],
        @"Проверяю устройство…": @[@"Перевіряю пристрій…", @"Checking device…", @"בודק התקן…", @"Проверяю устройство…"]
        ,@"Вход устройства": @[@"Вхід пристрою", @"Device input", @"כניסת התקן", @"Вход устройства"]
        ,@"Bluetooth": @[@"Bluetooth", @"Bluetooth", @"Bluetooth", @"Bluetooth"]
        ,@"RCA": @[@"RCA", @"RCA", @"RCA", @"RCA"]
        ,@"HDMI": @[@"HDMI", @"HDMI", @"HDMI", @"HDMI"]
        ,@"XLR": @[@"XLR", @"XLR", @"XLR", @"XLR"]
        ,@"Входы недоступны": @[@"Входи недоступні", @"Inputs unavailable", @"הכניסות אינן זמינות", @"Входы недоступны"]
        ,@"Устройство не сообщило список поддерживаемых входов.": @[@"Пристрій не повідомив список підтримуваних входів.", @"Device did not report its supported inputs.", @"ההתקן לא דיווח על הכניסות הנתמכות.", @"Устройство не сообщило список поддерживаемых входов."]
        ,@"Не удалось сменить вход": @[@"Не вдалося змінити вхід", @"Could not change input", @"לא ניתן לשנות כניסה", @"Не удалось сменить вход"]
        ,@"Включён": @[@"Увімкнено", @"Enabled", @"מופעל", @"Включён"]
        ,@"Выключен": @[@"Вимкнено", @"Disabled", @"כבוי", @"Выключен"]
        ,@"Низкие": @[@"Низькі", @"Bass", @"נמוכים", @"Низкие"]
        ,@"Высокие": @[@"Високі", @"Treble", @"גבוהים", @"Высокие"]
        ,@"Эквалайзер": @[@"Еквалайзер", @"Equalizer", @"אקולייזר", @"Эквалайзер"]
        ,@"Будильник": @[@"Будильник", @"Alarm", @"שעון מעורר", @"Будильник"]
        ,@"Таймер сна · 30 минут": @[@"Таймер сну · 30 хвилин", @"Sleep timer · 30 minutes", @"טיימר שינה · 30 דקות", @"Таймер сна · 30 минут"]
        ,@"Сеть": @[@"Мережа", @"Network", @"רשת", @"Сеть"]
        ,@"Линейный вход": @[@"Лінійний вхід", @"Line In", @"כניסת קו", @"Линейный вход"]
        ,@"Оптический": @[@"Оптичний", @"Optical", @"אופטי", @"Оптический"]
        ,@"Радио": @[@"Радіо", @"Radio", @"רדיו", @"Радио"]
        ,@"TF-карта": @[@"TF-картка", @"TF card", @"כרטיס TF", @"TF-карта"]
        ,@"Введите название станции.": @[@"Введіть назву станції.", @"Enter a station name.", @"הזן שם תחנה.", @"Введите название станции."]
        ,@"Название станции": @[@"Назва станції", @"Station name", @"שם התחנה", @"Название станции"]
        ,@"Устройство не вернуло читаемую очередь": @[@"Пристрій не повернув чергу для читання", @"Device returned an unreadable queue", @"ההתקן לא החזיר תור קריא", @"Устройство не вернуло читаемую очередь"]
        ,@"Очередь пуста": @[@"Черга порожня", @"Queue is empty", @"התור ריק", @"Очередь пуста"]
        ,@"Таймер не установлен": @[@"Таймер не встановлено", @"Timer not set", @"הטיימר לא הוגדר", @"Таймер не установлен"]
        ,@"Таймер сна": @[@"Таймер сну", @"Sleep timer", @"טיימר שינה", @"Таймер сна"]
        ,@"Выключить через 30 минут": @[@"Вимкнути через 30 хвилин", @"Turn off in 30 minutes", @"כיבוי בעוד 30 דקות", @"Выключить через 30 минут"]
        ,@"Эквалайзер недоступен": @[@"Еквалайзер недоступний", @"Equalizer unavailable", @"האקולייזר אינו זמין", @"Эквалайзер недоступен"]
        ,@"Устройство не вернуло настройки эквалайзера.": @[@"Пристрій не повернув налаштування еквалайзера.", @"Device did not return equalizer settings.", @"ההתקן לא החזיר הגדרות אקולייזר.", @"Устройство не вернуло настройки эквалайзера."]
        ,@"Обновить": @[@"Оновити", @"Refresh", @"רענון", @"Обновить"]
        ,@"Загрузка настроек эквалайзера…": @[@"Завантаження налаштувань еквалайзера…", @"Loading equalizer settings…", @"טוען הגדרות אקולייזר…", @"Загрузка настроек эквалайзера…"]
        ,@"Устройство не предоставило поддерживаемые полосы эквалайзера.": @[@"Пристрій не надав підтримувані смуги еквалайзера.", @"The device did not provide supported equalizer bands.", @"המכשיר לא סיפק תחומי אקולייזר נתמכים.", @"Устройство не предоставило поддерживаемые полосы эквалайзера."]
        ,@"Устройство не объявило регулируемые полосы эквалайзера.": @[@"Пристрій не оголосив регульовані смуги еквалайзера.", @"The device did not advertise adjustable equalizer bands.", @"המכשיר לא הכריז על תחומי אקולייזר הניתנים לכוונון.", @"Устройство не объявило регулируемые полосы эквалайзера."]
        ,@"Полосы и диапазон загружены из профиля устройства.": @[@"Смуги та діапазон завантажено з профілю пристрою.", @"Bands and range loaded from the device profile.", @"התחומים והטווח נטענו מפרופיל המכשיר.", @"Полосы и диапазон загружены из профиля устройства."]
        ,@"Режим эквалайзера": @[@"Режим еквалайзера", @"Equalizer mode", @"מצב אקולייזר", @"Режим эквалайзера"]
        ,@"Пользовательский режим": @[@"Користувацький режим", @"Custom mode", @"מצב מותאם אישית", @"Пользовательский режим"]
        ,@"Пользовательский": @[@"Користувацький", @"Custom", @"מותאם אישית", @"Пользовательский"]
        ,@"полос поддерживается устройством": @[@"смуг підтримує пристрій", @"bands supported by device", @"תחומים נתמכים במכשיר", @"полос поддерживается устройством"]
        ,@"Изменения отправляются на выбранную колонку.": @[@"Зміни надсилаються на вибрану колонку.", @"Changes are sent to the selected speaker.", @"השינויים נשלחים לרמקול שנבחר.", @"Изменения отправляются на выбранную колонку."]
        ,@"Не удалось применить эквалайзер": @[@"Не вдалося застосувати еквалайзер", @"Could not apply equalizer", @"לא ניתן להחיל את האקולייזר", @"Не удалось применить эквалайзер"]
        ,@"Эквалайзер применён к выбранному устройству.": @[@"Еквалайзер застосовано до вибраного пристрою.", @"Equalizer applied to the selected device.", @"האקולייזר הוחל על המכשיר שנבחר.", @"Эквалайзер применён к выбранному устройству."]
        ,@"Средние": @[@"Середні", @"Mid", @"אמצע", @"Средние"]
        ,@"Устройство не вернуло числовые значения полос.": @[@"Пристрій не повернув числові значення смуг.", @"Device did not return numeric band values.", @"ההתקן לא החזיר ערכים מספריים לרצועות.", @"Устройство не вернуло числовые значения полос."]
        ,@"Нативная сборка с Linkplay Music Kit 1.0.14.": @[@"Нативна збірка з Linkplay Music Kit 1.0.14.", @"Native build with Linkplay Music Kit 1.0.14.", @"גרסה מקורית עם Linkplay Music Kit 1.0.14.", @"Нативная сборка с Linkplay Music Kit 1.0.14."]
        ,@"Add Alarm": @[@"Додати будильник", @"Add Alarm", @"הוספת שעון מעורר", @"Добавить будильник"]
        ,@"Edit Alarm": @[@"Редагувати будильник", @"Edit Alarm", @"עריכת שעון מעורר", @"Изменить будильник"]
        ,@"Repeat": @[@"Повтор", @"Repeat", @"חזרה", @"Повтор"]
        ,@"Music": @[@"Музика", @"Music", @"מוזיקה", @"Музыка"]
        ,@"Duration": @[@"Тривалість", @"Duration", @"משך", @"Длительность"]
        ,@"Device default": @[@"За налаштуванням пристрою", @"Device default", @"ברירת מחדל של ההתקן", @"По умолчанию устройства"]
        ,@"alarm_Once": @[@"Один раз", @"Once", @"פעם אחת", @"Один раз"]
        ,@"alarm_Everyday": @[@"Щодня", @"Every day", @"כל יום", @"Каждый день"]
        ,@"alarm_CustomDays": @[@"Вибрані дні", @"Selected days", @"ימים נבחרים", @"Выбранные дни"]
        ,@"alarm_Please_select_the_alarm_clock_song": @[@"Виберіть музику або пресет для будильника", @"Choose music or a preset for the alarm", @"בחר מוזיקה או תחנה קבועה לשעון המעורר", @"Выберите музыку или пресет для будильника"]
        ,@"Выбрать пресет": @[@"Вибрати пресет", @"Choose a preset", @"בחר תחנה קבועה", @"Выбрать пресет"]
        ,@"Музыка из пресетов": @[@"Музика з пресетів", @"Preset music", @"מוזיקה מתחנות קבועות", @"Музыка из пресетов"]
        ,@"Monday": @[@"Понеділок", @"Monday", @"יום שני", @"Понедельник"]
        ,@"Tuesday": @[@"Вівторок", @"Tuesday", @"יום שלישי", @"Вторник"]
        ,@"Wednesday": @[@"Середа", @"Wednesday", @"יום רביעי", @"Среда"]
        ,@"Thursday": @[@"Четвер", @"Thursday", @"יום חמישי", @"Четверг"]
        ,@"Friday": @[@"П’ятниця", @"Friday", @"יום שישי", @"Пятница"]
        ,@"Saturday": @[@"Субота", @"Saturday", @"יום שבת", @"Суббота"]
        ,@"Sunday": @[@"Неділя", @"Sunday", @"יום ראשון", @"Воскресенье"]
        ,@"Song": @[@"Пісня", @"Song", @"שיר", @"Песня"]
        ,@"Artist": @[@"Виконавець", @"Artist", @"אמן", @"Исполнитель"]
        ,@"Playlist": @[@"Список відтворення", @"Playlist", @"רשימת השמעה", @"Плейлист"]
        ,@"Search station": @[@"Пошук станції", @"Search station", @"חיפוש תחנה", @"Поиск станции"]
        ,@"alarm_You_haven_t_set_up_any_alarms_yet": @[@"Будильників ще немає", @"You haven't set up any alarms yet", @"עדיין לא הוגדרו שעונים מעוררים", @"Будильники ещё не настроены"]
        ,@"Only supports 4 alarm clocks": @[@"Підтримується не більше 4 будильників", @"Supports up to 4 alarms", @"ניתן להגדיר עד 4 שעונים מעוררים", @"Поддерживается не более 4 будильников"]
        ,@"alarm_Content_is_empty": @[@"Музику не вибрано", @"No music selected", @"לא נבחרה מוזיקה", @"Музыка не выбрана"]
        ,@"alarm_Recently_Played": @[@"Нещодавно відтворене", @"Recently played", @"הושמעו לאחרונה", @"Недавно воспроизводилось"]
        ,@"alarm_Favorites": @[@"Улюблене", @"Favourites", @"מועדפים", @"Избранное"]
        ,@"Трек, исполнитель или альбом": @[@"Пісня, виконавець або альбом", @"Track, artist or album", @"שיר, אמן או אלבום", @"Трек, исполнитель или альбом"]
        ,@"Трек или исполнитель": @[@"Пісня або виконавець", @"Track or artist", @"שיר או אמן", @"Трек или исполнитель"]
        ,@"Введите название трека или исполнителя.": @[@"Введіть назву пісні або виконавця.", @"Enter a track or artist name.", @"הזן שם שיר או אמן.", @"Введите название трека или исполнителя."]
        ,@"Станция не запущена": @[@"Не вдалося запустити станцію", @"Station did not start", @"התחנה לא הופעלה", @"Станция не запущена"]
        ,@"Deezer на колонке": @[@"Deezer на пристрої", @"Deezer on speaker", @"Deezer ברמקול", @"Deezer на колонке"]
        ,@"Вход Deezer на колонке": @[@"Вхід Deezer на пристрої", @"Sign in to Deezer on speaker", @"התחברות ל‑Deezer ברמקול", @"Вход Deezer на колонке"]
        ,@"Вход выполняется на выбранной колонке. Для A98 используется сервис Deezer2; для A31 — совместимый старый сервис. Deezer App ID не требуется.": @[@"Вхід виконується на вибраному пристрої. Для A98 використовується Deezer2, для A31 — сумісний старий сервіс. App ID Deezer не потрібен.", @"Sign-in runs on the selected speaker. A98 uses Deezer2; A31 uses the compatible legacy service. No Deezer App ID is required.", @"ההתחברות מתבצעת ברמקול שנבחר. A98 משתמש ב‑Deezer2; ‏A31 בשירות הישן התואם. אין צורך ב‑Deezer App ID.", @"Вход выполняется на выбранной колонке. Для A98 используется Deezer2; для A31 — совместимый старый сервис. Deezer App ID не требуется."]
        ,@"Логин или почта": @[@"Логін або електронна пошта", @"Username or email", @"שם משתמש או דוא״ל", @"Логин или почта"]
        ,@"Пароль": @[@"Пароль", @"Password", @"סיסמה", @"Пароль"]
        ,@"Войти": @[@"Увійти", @"Sign in", @"התחברות", @"Войти"]
        ,@"Обновить библиотеку": @[@"Оновити медіатеку", @"Refresh library", @"רענון הספרייה", @"Обновить библиотеку"]
        ,@"Сменить аккаунт": @[@"Змінити обліковий запис", @"Change account", @"החלפת חשבון", @"Сменить аккаунт"]
        ,@"Введите логин и пароль Deezer.": @[@"Введіть логін і пароль Deezer.", @"Enter your Deezer username and password.", @"הזן שם משתמש וסיסמה של Deezer.", @"Введите логин и пароль Deezer."]
        ,@"Каталог радиостанций": @[@"Каталог радіостанцій", @"Radio station catalog", @"מדריך תחנות רדיו", @"Каталог радиостанций"]
        ,@"Доступно на колонке": @[@"Доступно на пристрої", @"Available on speaker", @"זמין ברמקול", @"Доступно на колонке"]
        ,@"Колонка не объявляет этот сервис": @[@"Пристрій не оголошує цей сервіс", @"Device does not advertise this service", @"ההתקן אינו מצהיר על השירות הזה", @"Колонка не объявляет этот сервис"]
        ,@"Встроенный вход и каталог запускаются отдельно от входа на сайте сервиса.": @[@"Вбудований вхід і каталог працюють окремо від входу на сайті сервісу.", @"Built-in sign-in and catalog are separate from the service website login.", @"התחברות וקטלוג מובנים נפרדים מהתחברות באתר השירות.", @"Встроенный вход и каталог запускаются отдельно от входа на сайте сервиса."]
        ,@"Проверяю встроенные сервисы выбранной колонки…": @[@"Перевіряю вбудовані сервіси вибраного пристрою…", @"Checking the selected speaker's built-in services…", @"בודק את השירותים המובנים ברמקול שנבחר…", @"Проверяю встроенные сервисы выбранной колонки…"]
        ,@"Не удалось прочитать StreamServicesCapability. Обновите выбор устройства и попробуйте снова.": @[@"Не вдалося прочитати StreamServicesCapability. Оновіть вибір пристрою та спробуйте ще раз.", @"Could not read StreamServicesCapability. Refresh the selected device and try again.", @"לא ניתן לקרוא את StreamServicesCapability. רענן את ההתקן שנבחר ונסה שוב.", @"Не удалось прочитать StreamServicesCapability. Обновите выбор устройства и попробуйте снова."]
        ,@"Доступность зависит от ответа StreamServicesCapability самой колонки. Встроенный вход и каталог запускаются отдельно от входа на сайте сервиса.": @[@"Доступність залежить від відповіді StreamServicesCapability пристрою. Вбудований вхід і каталог працюють окремо від входу на сайті сервісу.", @"Availability depends on the speaker's StreamServicesCapability response. Built-in sign-in and browsing are separate from the service website login.", @"הזמינות תלויה בתשובת StreamServicesCapability של הרמקול. התחברות וקטלוג מובנים נפרדים מהתחברות באתר השירות.", @"Доступность зависит от ответа StreamServicesCapability самой колонки. Встроенный вход и каталог запускаются отдельно от входа на сайте сервиса."]
        ,@"Доступно на колонке · %@": @[@"Доступно на пристрої · %@", @"Available on speaker · %@", @"זמין ברמקול · %@", @"Доступно на колонке · %@"]
        ,@"Album": @[@"Альбом", @"Album", @"אלבום", @"Альбом"]
        ,@"Будильники": @[@"Будильники", @"Alarms", @"שעונים מעוררים", @"Будильники"]
        ,@"Войдите в другой аккаунт Qobuz.": @[@"Увійдіть в інший обліковий запис Qobuz.", @"Sign in to a different Qobuz account.", @"התחבר לחשבון Qobuz אחר.", @"Войдите в другой аккаунт Qobuz."]
        ,@"Загрузка…": @[@"Завантаження…", @"Loading…", @"טוען…", @"Загрузка…"]
        ,@"Сначала выберите устройство во вкладке «Устройства».": @[@"Спочатку виберіть пристрій на вкладці «Пристрої».", @"Select a device on the Devices tab first.", @"תחילה בחר התקן בכרטיסיית ההתקנים.", @"Сначала выберите устройство во вкладке «Устройства»."]
        ,@"Откройте вкладку «Устройства» и выберите активную зону.": @[@"Відкрийте вкладку «Пристрої» та виберіть активну зону.", @"Open Devices and select an active zone.", @"פתח את הכרטיסייה התקנים ובחר אזור פעיל.", @"Откройте вкладку «Устройства» и выберите активную зону."]
        ,@"Станции не найдены.": @[@"Станцій не знайдено.", @"No stations found.", @"לא נמצאו תחנות.", @"Станции не найдены."]
        ,@"Каталог недоступен. Повторите поиск.": @[@"Каталог недоступний. Повторіть пошук.", @"Catalog unavailable. Try again.", @"הקטלוג אינו זמין. נסה שוב.", @"Каталог недоступен. Повторите поиск."]
        ,@"Треки не найдены.": @[@"Композицій не знайдено.", @"No tracks found.", @"לא נמצאו רצועות.", @"Треки не найдены."]
        ,@"Каталог Deezer недоступен.": @[@"Каталог Deezer недоступний.", @"Deezer catalog is unavailable.", @"הקטלוג של Deezer אינו זמין.", @"Каталог Deezer недоступен."]
        ,@"Открыть Deezer": @[@"Відкрити Deezer", @"Open Deezer", @"פתיחת Deezer", @"Открыть Deezer"]
        ,@"Нажмите на трек, чтобы прослушать доступное превью на iPhone. Для полного трека откройте Deezer.": @[@"Торкніться композиції, щоб прослухати доступний фрагмент на iPhone. Для повної версії відкрийте Deezer.", @"Tap a track to play its available preview on iPhone. Open Deezer for the full track.", @"הקש על רצועה להשמעת קטע התצוגה המקדימה הזמין ב‑iPhone. להשמעה מלאה, פתח את Deezer.", @"Нажмите на трек, чтобы прослушать доступное превью на iPhone. Для полного трека откройте Deezer."]
        ,@"Поиск…": @[@"Пошук…", @"Searching…", @"מחפש…", @"Поиск…"]
        ,@"Проверьте доступность потока или выберите другую станцию.": @[@"Перевірте доступність потоку або виберіть іншу станцію.", @"Check the stream or choose another station.", @"בדוק את זמינות הזרם או בחר תחנה אחרת.", @"Проверьте доступность потока или выберите другую станцию."]
        ,@"Mode": @[@"Режим", @"Mode", @"מצב", @"Режим"]
        ,@"EQEnable": @[@"Еквалайзер", @"Equalizer", @"אקולייזר", @"Эквалайзер"]
        ,@"По умолчанию устройства": @[@"За замовчуванням пристрою", @"Device default", @"ברירת מחדל של ההתקן", @"По умолчанию устройства"]
    };
    NSArray<NSString *> *values = translations[value];
    if (values.count == 4) return ACT(values[0], values[1], values[2], values[3]);
    if ([value hasPrefix:@"Зона · "]) return [NSString stringWithFormat:@"%@ · %@", ACT(@"Зона", @"Zone", @"אזור", @"Зона"), ACMenuText([value substringFromIndex:7])];
    return value;
}
static NSString *ACLanguageName(NSString *code) {
    if ([code isEqualToString:@"auto"]) return ACT(@"Автоматично", @"Automatic", @"אוטומטי", @"Автоматически");
    if ([code isEqualToString:@"uk"]) return @"Українська";
    if ([code isEqualToString:@"en"]) return @"English";
    if ([code isEqualToString:@"he"]) return @"עברית";
    return @"Русский";
}
static NSString *ACName(LPDevice *d) { return d.deviceStatus.friendlyName.length ? d.deviceStatus.friendlyName : @"Linkplay"; }
static NSString *ACText(NSString *s) { return s.length && [s caseInsensitiveCompare:@"unknown"] != NSOrderedSame ? s : nil; }
@interface ACLocalHTTPDelegate : NSObject <NSURLSessionTaskDelegate>
@end
@implementation ACLocalHTTPDelegate
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
    willPerformHTTPRedirection:(NSHTTPURLResponse *)response newRequest:(NSURLRequest *)request
    completionHandler:(void (^)(NSURLRequest *))completionHandler {
    completionHandler(nil);
}
@end

static void ACRequestWithTimeout(NSString *host, NSInteger port, NSString *path, NSString *queryName, NSString *command,
                                 NSString *soap, NSString *action, NSTimeInterval timeout, void (^done)(NSData *)) {
    struct in_addr address;
    if (!host.length || inet_pton(AF_INET, host.UTF8String, &address) != 1) { done(nil); return; }
    uint32_t ip = ntohl(address.s_addr);
    if ((ip >> 24) != 10 && (ip >> 20) != 0xAC1 && (ip >> 16) != 0xC0A8) { done(nil); return; }
    NSURLComponents *url = [NSURLComponents new];
    url.scheme = @"http"; url.host = host; url.port = @(port); url.path = path;
    if (command) url.queryItems = @[[NSURLQueryItem queryItemWithName:queryName value:command]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url.URL cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:timeout];
    if (soap) {
        request.HTTPMethod = @"POST";
        request.HTTPBody = [soap dataUsingEncoding:NSUTF8StringEncoding];
        [request setValue:@"text/xml; charset=utf-8" forHTTPHeaderField:@"Content-Type"];
        [request setValue:action forHTTPHeaderField:@"SOAPAction"];
    }
    static NSURLSession *session;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        session = [NSURLSession sessionWithConfiguration:NSURLSessionConfiguration.ephemeralSessionConfiguration
                                               delegate:[ACLocalHTTPDelegate new] delegateQueue:nil];
    });
    [[session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
        // UPnP SOAP faults are commonly returned with HTTP 500 and include an
        // actionable fault code in the response body. Keep that body so callers
        // can distinguish a rejected action from a network timeout.
        BOOL success = !error && statusCode >= 200 && statusCode <= 599 && data.length <= 4000000 && (soap || statusCode == 200);
        dispatch_async(dispatch_get_main_queue(), ^{ done(success ? data : nil); });
    }] resume];
}

static void ACRequest(NSString *host, NSInteger port, NSString *path, NSString *queryName, NSString *command,
                      NSString *soap, NSString *action, void (^done)(NSData *)) {
    ACRequestWithTimeout(host, port, path, queryName, command, soap, action, 4, done);
}

static void ACLocalHTTP(LPDevice *device, NSInteger port, NSString *path, NSString *command,
                        NSString *soap, NSString *action, void (^done)(NSData *)) {
    ACRequest(device.deviceStatus.IP, port, path, @"command", command, soap, action, done);
}

static void ACReadJSON(LPDevice *device, NSString *command, void (^done)(NSDictionary *)) {
    ACLocalHTTP(device, 80, @"/httpapi.asp", command, nil, nil, ^(NSData *data) {
        id json = data.length ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
        done([json isKindOfClass:NSDictionary.class] ? json : nil);
    });
}

static NSString *ACDeviceID(LPDevice *device) {
    return device.deviceStatus.UUID;
}

static NSArray<DDXMLNode *> *ACNodes(DDXMLNode *node, NSString *path);
static NSString *ACDIDL(DDXMLNode *node, NSString *name);
static DDXMLNode *ACXMLData(NSData *data);

// A98 units in this inventory identify their project as AmlogicA113, not
// necessarily as "A98". Select the same modern source WiiM Home uses for that
// platform. Legacy A31 projects continue to use the original Deezer source.
static NSString *ACDeezerSourceForDevice(LPDevice *device) {
    if (!device) return @"Deezer";
    NSMutableArray<NSString *> *hints = [NSMutableArray array];
    if (device.deviceStatus.productName.length) [hints addObject:device.deviceStatus.productName];
    NSDictionary *metadata = device.deviceStatus.deviceInfoDictionary;
    if ([metadata isKindOfClass:NSDictionary.class]) {
        for (NSString *key in @[@"ProjectName", @"project", @"modelName", @"ModelName", @"chip", @"Chip", @"productName"]) {
            id value = metadata[key];
            if ([value isKindOfClass:NSString.class]) [hints addObject:value];
        }
    }
    for (NSString *hint in hints) {
        if ([hint rangeOfString:@"A98" options:NSCaseInsensitiveSearch].location != NSNotFound ||
            [hint rangeOfString:@"AmlogicA113" options:NSCaseInsensitiveSearch].location != NSNotFound) return @"Deezer2";
    }
    return @"Deezer";
}

// WiiM Home decides which Deezer implementation to use from the device's
// StreamServicesCapability, not from its marketing name. Query that action
// directly so A98 variants that identify as AmlogicA113 still select Deezer2.
static void ACResolveDeezerSource(LPDevice *device, void (^completion)(NSString *, NSDictionary *)) {
    NSString *host = device.deviceStatus.IP;
    NSMutableOrderedSet<NSNumber *> *ports = [NSMutableOrderedSet orderedSetWithArray:@[@49152, @59152]];
    NSInteger reportedPort = device.deviceStatus.port;
    if (reportedPort > 0 && reportedPort <= 65535) [ports addObject:@(reportedPort)];
    [ports addObjectsFromArray:@[@49494, @80]];
    NSArray<NSString *> *paths = @[@"/description.xml", @"/device.xml"];
    __block NSUInteger portIndex = 0, pathIndex = 0;
    __block void (^tryNext)(void);
    tryNext = ^{
        if (portIndex >= ports.count) { completion(ACDeezerSourceForDevice(device), nil); tryNext = nil; return; }
        NSInteger port = ports[portIndex].integerValue;
        NSString *descriptionPath = paths[pathIndex++];
        if (pathIndex >= paths.count) { pathIndex = 0; portIndex++; }
        ACRequestWithTimeout(host, port, descriptionPath, nil, nil, nil, nil, 2.5, ^(NSData *data) {
            DDXMLNode *root = ACXMLData(data);
            for (DDXMLNode *service in ACNodes(root, @".//*[local-name()='service']")) {
                NSString *type = ACDIDL(service, @"serviceType");
                NSString *serviceID = ACDIDL(service, @"serviceId");
                if (![type containsString:@":service:RenderingControl:"] &&
                    ![serviceID.lowercaseString containsString:@"renderingcontrol"]) continue;
                NSString *control = ACDIDL(service, @"controlURL");
                if (!control.length) continue;
                NSURLComponents *base = [NSURLComponents new]; base.scheme = @"http"; base.host = host; base.port = @(port);
                NSURL *controlURL = [[NSURL URLWithString:control relativeToURL:base.URL] absoluteURL];
                NSURLComponents *endpoint = [NSURLComponents componentsWithURL:controlURL resolvingAgainstBaseURL:YES];
                if (![endpoint.host isEqualToString:host] || !endpoint.path.length || [endpoint.scheme.lowercaseString isEqualToString:@"https"]) continue;
                NSString *capabilityBody = @"<s:Envelope xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\"><s:Body><u:StreamServicesCapability xmlns:u=\"urn:schemas-upnp-org:service:RenderingControl:1\"><InstanceID>0</InstanceID><AppVersion>1.0</AppVersion></u:StreamServicesCapability></s:Body></s:Envelope>";
                NSString *soapAction = @"\"urn:schemas-upnp-org:service:RenderingControl:1#StreamServicesCapability\"";
                ACRequestWithTimeout(host, endpoint.port.integerValue ?: 80, endpoint.path, nil, nil, capabilityBody, soapAction, 4.0, ^(NSData *capabilityData) {
                    DDXMLNode *response = ACXMLData(capabilityData);
                    NSString *json = ACDIDL(response, @"StreamCapability");
                    NSData *jsonData = [json dataUsingEncoding:NSUTF8StringEncoding];
                    id decoded = jsonData.length ? [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil] : nil;
                    NSArray *services = [decoded isKindOfClass:NSDictionary.class] && [decoded[@"streamServices"] isKindOfClass:NSArray.class] ? decoded[@"streamServices"] : nil;
                    if (services) {
                        BOOL supportsDeezer2 = NO;
                        BOOL hasDeezer = NO;
                        NSDictionary *deezer2Info = nil;
                        for (NSDictionary *item in services) {
                            if (![item isKindOfClass:NSDictionary.class]) continue;
                            NSString *identifier = [item[@"id"] isKindOfClass:NSString.class] ? item[@"id"] : @"";
                            if ([identifier caseInsensitiveCompare:@"Deezer2"] == NSOrderedSame) { supportsDeezer2 = YES; deezer2Info = item; }
                            if ([identifier caseInsensitiveCompare:@"Deezer"] == NSOrderedSame || [identifier caseInsensitiveCompare:@"deezer"] == NSOrderedSame) hasDeezer = YES;
                        }
                        completion(supportsDeezer2 ? @"Deezer2" : (hasDeezer ? @"Deezer" : ACDeezerSourceForDevice(device)), deezer2Info);
                    } else {
                        completion(ACDeezerSourceForDevice(device), nil);
                    }
                    tryNext = nil;
                });
                return;
            }
            tryNext();
        });
    };
    tryNext();
}

// Read the selected device's advertised streaming services. Keep this based on
// live StreamServicesCapability rather than assuming every Linkplay platform
// exposes the same providers.
static void ACDiscoverStreamServices(LPDevice *device, void (^completion)(NSArray<NSDictionary *> *)) {
    NSString *host = device.deviceStatus.IP;
    if (!host.length) { completion(@[]); return; }
    NSMutableOrderedSet<NSNumber *> *ports = [NSMutableOrderedSet orderedSetWithArray:@[@49152, @59152]];
    NSInteger reportedPort = device.deviceStatus.port;
    if (reportedPort > 0 && reportedPort <= 65535) [ports addObject:@(reportedPort)];
    [ports addObjectsFromArray:@[@49494, @80]];
    NSArray<NSString *> *paths = @[@"/description.xml", @"/device.xml"];
    __block NSUInteger portIndex = 0, pathIndex = 0;
    __block void (^tryNext)(void);
    tryNext = ^{
        if (portIndex >= ports.count) { completion(@[]); tryNext = nil; return; }
        NSInteger port = ports[portIndex].integerValue;
        NSString *descriptionPath = paths[pathIndex++];
        if (pathIndex >= paths.count) { pathIndex = 0; portIndex++; }
        ACRequestWithTimeout(host, port, descriptionPath, nil, nil, nil, nil, 2.5, ^(NSData *data) {
            DDXMLNode *root = ACXMLData(data);
            for (DDXMLNode *service in ACNodes(root, @".//*[local-name()='service']")) {
                NSString *type = ACDIDL(service, @"serviceType");
                NSString *serviceID = ACDIDL(service, @"serviceId");
                if (![type containsString:@":service:RenderingControl:"] &&
                    ![serviceID.lowercaseString containsString:@"renderingcontrol"]) continue;
                NSString *control = ACDIDL(service, @"controlURL");
                if (!control.length) continue;
                NSURLComponents *base = [NSURLComponents new]; base.scheme = @"http"; base.host = host; base.port = @(port);
                NSURL *controlURL = [[NSURL URLWithString:control relativeToURL:base.URL] absoluteURL];
                NSURLComponents *endpoint = [NSURLComponents componentsWithURL:controlURL resolvingAgainstBaseURL:YES];
                if (![endpoint.host isEqualToString:host] || !endpoint.path.length || [endpoint.scheme.lowercaseString isEqualToString:@"https"]) continue;
                NSString *body = @"<s:Envelope xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\"><s:Body><u:StreamServicesCapability xmlns:u=\"urn:schemas-upnp-org:service:RenderingControl:1\"><InstanceID>0</InstanceID><AppVersion>1.0</AppVersion></u:StreamServicesCapability></s:Body></s:Envelope>";
                NSString *action = @"\"urn:schemas-upnp-org:service:RenderingControl:1#StreamServicesCapability\"";
                ACRequestWithTimeout(host, endpoint.port.integerValue ?: 80, endpoint.path, nil, nil, body, action, 4.0, ^(NSData *capabilityData) {
                    DDXMLNode *response = ACXMLData(capabilityData);
                    NSData *jsonData = [ACDIDL(response, @"StreamCapability") dataUsingEncoding:NSUTF8StringEncoding];
                    id decoded = jsonData.length ? [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil] : nil;
                    NSArray *services = [decoded isKindOfClass:NSDictionary.class] && [decoded[@"streamServices"] isKindOfClass:NSArray.class] ? decoded[@"streamServices"] : @[];
                    NSMutableArray *valid = [NSMutableArray array];
                    for (id item in services) if ([item isKindOfClass:NSDictionary.class] && [item[@"id"] isKindOfClass:NSString.class]) [valid addObject:item];
                    completion(valid);
                    tryNext = nil;
                });
                return;
            }
            tryNext();
        });
    };
    tryNext();
}

static void ACReadQueue(LPDevice *device, NSString *queue, void (^done)(NSString *)) {
    NSString *service = @"urn:schemas-wiimu-com:service:PlayQueue:1";
    NSString *body = [NSString stringWithFormat:@"<s:Envelope xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\"><s:Body><u:BrowseQueue xmlns:u=\"%@\"><QueueName>%@</QueueName></u:BrowseQueue></s:Body></s:Envelope>", service, queue];
    NSString *action = [NSString stringWithFormat:@"\"%@#BrowseQueue\"", service];
    ACLocalHTTP(device, 59152, @"/upnp/control/PlayQueue1", nil, body, action, ^(NSData *data) {
        done(data.length ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : nil);
    });
}

static NSString *ACTime(NSTimeInterval t) {
    NSInteger sec = (NSInteger)MAX(0, isfinite(t) ? t : 0);
    return [NSString stringWithFormat:@"%ld:%02ld", (long)(sec / 60), (long)(sec % 60)];
}

@class ACLANPlayer;

@interface ACStore : NSObject <LPDeviceManagerObserver>
@property(nonatomic, readonly) NSArray<LPDevice *> *devices;
@property(nonatomic, copy) NSString *selectedID;
@property(nonatomic, readonly) NSString *targetID;
@property(nonatomic, readonly) ACLANPlayer *selectedLANPlayer;
- (void)selectLANPlayer:(ACLANPlayer *)player identity:(NSString *)identity;
@property(nonatomic, readonly) LPDevice *selected;
- (void)setActive:(BOOL)active;
- (void)refresh;
- (void)select:(LPDevice *)device;
- (BOOL)isOnline:(LPDevice *)device;
@end

@implementation ACStore {
    NSMutableDictionary<NSString *, LPDevice *> *_online;
    NSMutableDictionary<NSString *, LPDevice *> *_known;
    NSMutableDictionary<NSString *, NSNumber *> *_lastSeen;
    NSUInteger _emptyRetries;
    NSString *_lanIdentity;
    ACLANPlayer *_selectedLANPlayer;
    BOOL _active;
    NSTimer *_discoveryRetry;
    nw_path_monitor_t _wifiMonitor;
    BOOL _wifiPathKnown, _wifiAvailable, _rescanScheduled;
}
- (instancetype)init {
    if ((self = [super init])) {
        _online = [NSMutableDictionary dictionary];
        _known = [NSMutableDictionary dictionary];
        _lastSeen = [NSMutableDictionary dictionary];
    }
    return self;
}
- (NSArray<LPDevice *> *)devices {
    return [_known.allValues sortedArrayUsingComparator:^NSComparisonResult(LPDevice *a, LPDevice *b) {
        return [ACName(a) localizedCaseInsensitiveCompare:ACName(b)];
    }];
}
- (LPDevice *)selected { return self.selectedID ? _online[self.selectedID] : nil; }
- (NSString *)targetID { return _lanIdentity ?: self.selectedID; }
- (ACLANPlayer *)selectedLANPlayer { return _selectedLANPlayer; }
- (void)selectLANPlayer:(ACLANPlayer *)player identity:(NSString *)identity {
    _selectedLANPlayer = player;
    _lanIdentity = [identity copy];
    self.selectedID = nil;
    [self notify];
}
- (BOOL)isOnline:(LPDevice *)device { return _online[device.deviceStatus.UUID ?: @""] != nil; }
- (void)notify { [NSNotificationCenter.defaultCenter postNotificationName:ACChanged object:self]; }
- (void)setActive:(BOOL)active {
    if (_active == active) return;
    _active = active;
    LPDeviceManager *manager = [LPDeviceManager sharedInstance];
    if (active) {
        [manager addObserver:self];
        [manager start:@""];
        __weak typeof(self) weakSelf = self;
        _wifiMonitor = nw_path_monitor_create_with_type(nw_interface_type_wifi);
        nw_path_monitor_t monitor = _wifiMonitor;
        nw_path_monitor_set_queue(monitor, dispatch_get_main_queue());
        nw_path_monitor_set_update_handler(monitor, ^(nw_path_t path) {
            typeof(self) self = weakSelf;
            if (!self || !self->_active) return;
            BOOL available = nw_path_get_status(path) == nw_path_status_satisfied;
            BOOL reconnected = self->_wifiPathKnown && available && !self->_wifiAvailable;
            self->_wifiPathKnown = YES;
            self->_wifiAvailable = available;
            if (reconnected) [self refresh];
        });
        nw_path_monitor_start(monitor);
        _discoveryRetry = [NSTimer scheduledTimerWithTimeInterval:15 repeats:YES block:^(NSTimer *timer) {
            typeof(self) self = weakSelf;
            if (!self || !self->_active || self->_online.count) return;
            if (++self->_emptyRetries % 2) [self refresh];
            else {
                LPDeviceManager *manager = [LPDeviceManager sharedInstance];
                [manager stop];
                [manager start:@""];
            }
        }];
    } else {
        if (_wifiMonitor) nw_path_monitor_cancel(_wifiMonitor);
        _wifiMonitor = nil;
        _wifiPathKnown = NO;
        [_discoveryRetry invalidate];
        _discoveryRetry = nil;
        [manager removeObserver:self];
        [manager stop];
        // Keep the last device snapshot while iOS suspends the app. The SDK
        // will refresh it after foregrounding; clearing it here made every
        // zone disappear and show offline until discovery completed again.
    }
}
- (void)refresh {
    if (!_active) { [self setActive:YES]; return; }
    LPDeviceManager *manager = [LPDeviceManager sharedInstance];
    [manager upnpDeviceStop];
    [manager upnpDeviceStart];
}
- (void)select:(LPDevice *)device {
    if (!_online[device.deviceStatus.UUID ?: @""]) return;
    _selectedLANPlayer = nil;
    _lanIdentity = nil;
    self.selectedID = device.deviceStatus.UUID;
    [device.deviceInfo updateCurrentPlayInfo];
    [self notify];
}
- (void)onLPDeviceOnline:(LPDevice *)device {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self->_active || !device.deviceStatus.UUID.length || device.deviceStatus.maybeIllegal) return;
        self->_emptyRetries = 0;
        self->_known[device.deviceStatus.UUID] = device;
        self->_online[device.deviceStatus.UUID] = device;
        self->_lastSeen[device.deviceStatus.UUID] = @(CACurrentMediaTime());
        [self notify];
    });
}
- (void)onLPDeviceOffline:(LPDevice *)device {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *identity = device.deviceStatus.UUID;
        if (!self->_active || !identity.length || self->_online[identity] != device) return;
        NSTimeInterval offlineAt = CACurrentMediaTime();
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            if (!self->_active || self->_online[identity] != device) return;
            if (self->_lastSeen[identity].doubleValue > offlineAt) return;
            [self->_online removeObjectForKey:identity];
            [self notify];
            if (!self->_rescanScheduled) {
                self->_rescanScheduled = YES;
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 4 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                    self->_rescanScheduled = NO;
                    if (self->_active && !self->_online[identity]) [self refresh];
                });
            }
        });
    });
}
- (void)onLPDeviceUpdate:(LPDevice *)device {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *identity = device.deviceStatus.UUID ?: @"";
        if (self->_active && identity.length && !device.deviceStatus.maybeIllegal) {
            self->_known[identity] = device;
            self->_online[identity] = device;
            self->_lastSeen[identity] = @(CACurrentMediaTime());
            [self notify];
        }
    });
}
@end

static NSArray<DDXMLNode *> *ACNodes(DDXMLNode *node, NSString *path) {
    return [node nodesForXPath:path error:nil] ?: @[];
}
static NSString *ACValue(DDXMLNode *node, NSString *name) {
    return ACNodes(node, [NSString stringWithFormat:@"./*[local-name()='%@']", name]).firstObject.stringValue ?: @"";
}
static NSString *ACDIDL(DDXMLNode *node, NSString *name) {
    return ACNodes(node, [NSString stringWithFormat:@".//*[local-name()='%@']", name]).firstObject.stringValue ?: @"";
}

static DDXMLNode *ACXMLData(NSData *data) {
    NSString *text = data.length ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : nil;
    if (!text.length || [text rangeOfString:@"<!DOCTYPE" options:NSCaseInsensitiveSearch].location != NSNotFound) return nil;
    return [[[DDXMLDocument alloc] initWithXMLString:text options:0 error:nil] rootElement];
}

static void ACDiscoverPlayQueueEndpoint(LPDevice *device, NSString *action,
                                        void (^completion)(NSInteger, NSString *, NSString *, NSString *)) {
    NSString *host = device.deviceStatus.IP;
    NSMutableOrderedSet<NSNumber *> *ports = [NSMutableOrderedSet orderedSet];
    [ports addObject:@49152];
    [ports addObject:@59152];
    NSInteger reportedPort = device.deviceStatus.port;
    if (reportedPort > 0 && reportedPort <= 65535) [ports addObject:@(reportedPort)];
    for (NSNumber *port in @[@49494, @80]) [ports addObject:port];
    NSArray<NSString *> *paths = @[@"/description.xml", @"/device.xml"];
    __block NSUInteger portIndex = 0;
    __block NSUInteger pathIndex = 0;
    __block BOOL playQueueFound = NO;
    __block void (^tryNext)(void);
    tryNext = ^{
        if (portIndex >= ports.count) {
            NSString *message = playQueueFound ? [NSString stringWithFormat:@"Описание PlayQueue найдено, но оно не объявляет действие %@.", action]
                                                 : [NSString stringWithFormat:@"Не удалось найти описание PlayQueue на %@.", ACName(device)];
            completion(0, nil, nil, message);
            tryNext = nil;
            return;
        }
        NSInteger port = ports[portIndex].integerValue;
        NSString *path = paths[pathIndex];
        pathIndex++;
        if (pathIndex >= paths.count) { pathIndex = 0; portIndex++; }
        ACRequestWithTimeout(host, port, path, nil, nil, nil, nil, 2.5, ^(NSData *data) {
            DDXMLNode *root = ACXMLData(data);
            NSString *serviceType = nil;
            for (DDXMLNode *service in ACNodes(root, @".//*[local-name()='service']")) {
                NSString *serviceID = ACDIDL(service, @"serviceId");
                NSString *candidateType = ACDIDL(service, @"serviceType");
                BOOL isPlayQueue = [serviceID isEqualToString:@"urn:wiimu-com:serviceId:PlayQueue"] ||
                    [candidateType containsString:@":service:PlayQueue:"];
                if (!isPlayQueue || !candidateType.length) continue;
                serviceType = candidateType;
                playQueueFound = YES;
                NSString *control = ACDIDL(service, @"controlURL");
                NSString *scpd = ACDIDL(service, @"SCPDURL");
                if (!control.length) continue;
                NSURLComponents *base = [NSURLComponents new];
                base.scheme = @"http"; base.host = host; base.port = @(port);
                NSURL *controlURL = [[NSURL URLWithString:control relativeToURL:base.URL] absoluteURL];
                NSURLComponents *controlComponents = [NSURLComponents componentsWithURL:controlURL resolvingAgainstBaseURL:YES];
                if (![controlComponents.host isEqualToString:host] || !controlComponents.path.length ||
                    ([controlComponents.scheme.lowercaseString isEqualToString:@"https"])) continue;
                NSInteger controlPort = controlComponents.port.integerValue ?: 80;
                if (!scpd.length) { completion(controlPort, controlComponents.path, serviceType, nil); tryNext = nil; return; }
                NSURL *scpdURL = [[NSURL URLWithString:scpd relativeToURL:base.URL] absoluteURL];
                NSURLComponents *scpdComponents = [NSURLComponents componentsWithURL:scpdURL resolvingAgainstBaseURL:YES];
                if (![scpdComponents.host isEqualToString:host] || !scpdComponents.path.length ||
                    [scpdComponents.scheme.lowercaseString isEqualToString:@"https"]) continue;
                ACRequestWithTimeout(host, scpdComponents.port.integerValue ?: 80, scpdComponents.path,
                                      nil, nil, nil, nil, 2.5, ^(NSData *scpdData) {
                    DDXMLNode *description = ACXMLData(scpdData);
                    BOOL supportsAction = NO;
                    for (DDXMLNode *node in ACNodes(description, @".//*[local-name()='action']/*[local-name()='name']")) {
                        if ([node.stringValue isEqualToString:action]) { supportsAction = YES; break; }
                    }
                    if (supportsAction) {
                        completion(controlPort, controlComponents.path, serviceType, nil);
                        tryNext = nil;
                    } else {
                        tryNext();
                    }
                });
                return;
            }
            tryNext();
        });
    };
    tryNext();
}

static NSDictionary *ACACSStatus(NSData *data) {
    id value = data.length ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
    NSDictionary *status = [value isKindOfClass:NSDictionary.class] ? value : nil;
    return status[@"ProjectName"] && (status[@"UUID"] || status[@"uuid"]) ? status : nil;
}

static NSArray<NSString *> *ACWiFiPeers(void) {
    struct ifaddrs *interfaces;
    if (getifaddrs(&interfaces) != 0) return @[];
    NSMutableArray *peers = [NSMutableArray array];
    for (struct ifaddrs *it = interfaces; it; it = it->ifa_next) {
        if (!it->ifa_addr || !it->ifa_netmask || it->ifa_addr->sa_family != AF_INET || strcmp(it->ifa_name, "en0")) continue;
        uint32_t address = ntohl(((struct sockaddr_in *)it->ifa_addr)->sin_addr.s_addr);
        uint32_t mask = ntohl(((struct sockaddr_in *)it->ifa_netmask)->sin_addr.s_addr);
        if (!mask || mask >= 0xfffffffe) continue;
        mask = MAX(mask, 0xffffff00U);
        if ((address >> 24) != 10 && (address >> 20) != 0xAC1 && (address >> 16) != 0xC0A8) continue;
        uint32_t network = address & mask;
        uint32_t broadcast = network | ~mask;
        for (uint32_t ip = network + 1; ip < broadcast; ip++) {
            if (ip == address) continue;
            struct in_addr peer = { .s_addr = htonl(ip) };
            char text[INET_ADDRSTRLEN];
            if (inet_ntop(AF_INET, &peer, text, sizeof(text))) [peers addObject:@(text)];
        }
        break;
    }
    freeifaddrs(interfaces);
    return peers;
}

static UITableViewCell *ACCell(NSString *title, NSString *detail, NSString *icon);

static NSURL *ACStreamURL(id value) {
    if (![value isKindOfClass:NSString.class] || [value length] > 4096) return nil;
    NSURLComponents *url = [NSURLComponents componentsWithString:value];
    if (!url.host.length || url.user || url.password || ![@[@"http", @"https"] containsObject:url.scheme.lowercaseString]) return nil;
    return url.URL;
}

@interface ACRadioStationCell : UITableViewCell
- (void)configureWithStation:(NSDictionary *)station;
- (void)configureWithStation:(NSDictionary *)station highlighted:(BOOL)highlighted;
@end

@implementation ACRadioStationCell {
    UIImageView *_thumbnail;
    UILabel *_stationName, *_stationDetail;
}
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)identifier {
    if ((self = [super initWithStyle:style reuseIdentifier:identifier])) {
        _thumbnail = [UIImageView new];
        _thumbnail.contentMode = UIViewContentModeScaleAspectFit;
        _thumbnail.clipsToBounds = YES;
        _thumbnail.layer.cornerRadius = 6;
        _thumbnail.backgroundColor = [UIColor colorWithWhite:.16 alpha:1];
        _thumbnail.tintColor = ACAccent();
        _thumbnail.translatesAutoresizingMaskIntoConstraints = NO;

        _stationName = [UILabel new];
        _stationName.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
        _stationName.adjustsFontForContentSizeCategory = YES;
        _stationName.numberOfLines = 2;
        _stationDetail = [UILabel new];
        _stationDetail.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
        _stationDetail.adjustsFontForContentSizeCategory = YES;
        _stationDetail.textColor = ACSecondaryText();

        UIStackView *text = [[UIStackView alloc] initWithArrangedSubviews:@[_stationName, _stationDetail]];
        text.axis = UILayoutConstraintAxisVertical;
        text.spacing = 2;
        text.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:_thumbnail];
        [self.contentView addSubview:text];
        UILayoutGuide *margins = self.contentView.layoutMarginsGuide;
        // A station always reserves 44 × 44 pt, including while its artwork loads.
        [NSLayoutConstraint activateConstraints:@[
            [_thumbnail.leadingAnchor constraintEqualToAnchor:margins.leadingAnchor],
            [_thumbnail.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_thumbnail.topAnchor constraintGreaterThanOrEqualToAnchor:self.contentView.topAnchor constant:8],
            [_thumbnail.bottomAnchor constraintLessThanOrEqualToAnchor:self.contentView.bottomAnchor constant:-8],
            [_thumbnail.widthAnchor constraintEqualToConstant:44],
            [_thumbnail.heightAnchor constraintEqualToConstant:44],
            [text.leadingAnchor constraintEqualToAnchor:_thumbnail.trailingAnchor constant:12],
            [text.trailingAnchor constraintEqualToAnchor:margins.trailingAnchor],
            [text.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [text.topAnchor constraintGreaterThanOrEqualToAnchor:self.contentView.topAnchor constant:8],
            [text.bottomAnchor constraintLessThanOrEqualToAnchor:self.contentView.bottomAnchor constant:-8],
        ]];
        self.isAccessibilityElement = YES;
    }
    return self;
}
- (void)prepareForReuse {
    [super prepareForReuse];
    [_thumbnail sd_cancelCurrentImageLoad];
    _thumbnail.image = nil;
}
- (void)configureWithStation:(NSDictionary *)station {
    [self configureWithStation:station highlighted:NO];
}
- (void)configureWithStation:(NSDictionary *)station highlighted:(BOOL)highlighted {
    _stationName.text = station[@"name"];
    _stationName.textColor = highlighted ? ACAccent() : UIColor.labelColor;
    _stationDetail.text = station[@"detail"];
    _stationDetail.hidden = !_stationDetail.text.length;
    self.accessibilityLabel = _stationName.text;
    self.accessibilityValue = _stationDetail.text;
    UIImage *placeholder = [UIImage systemImageNamed:station[@"placeholder"] ?: @"radio"];
    [_thumbnail sd_setImageWithURL:ACStreamURL(station[@"art"]) placeholderImage:placeholder options:SDWebImageRetryFailed];
}
@end

@interface ACDeezerFlowCell : UITableViewCell
- (void)configure;
@end

@implementation ACDeezerFlowCell {
    UIView *_hero;
}
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)identifier {
    if ((self = [super initWithStyle:style reuseIdentifier:identifier])) {
        self.backgroundColor = UIColor.clearColor;
        self.contentView.backgroundColor = ACCard();
        self.contentView.clipsToBounds = YES;
        self.contentView.layer.cornerRadius = 18;
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        _hero = [UIView new];
        _hero.translatesAutoresizingMaskIntoConstraints = NO;
        _hero.backgroundColor = ACCard();
        [self.contentView addSubview:_hero];

        UILabel *watermark = [UILabel new];
        watermark.text = @"DEEZER";
        watermark.font = [UIFont systemFontOfSize:50 weight:UIFontWeightBlack];
        watermark.textColor = [ACPrimaryText() colorWithAlphaComponent:0.10];
        watermark.textAlignment = NSTextAlignmentCenter;
        watermark.translatesAutoresizingMaskIntoConstraints = NO;

        UIButton *play = [UIButton buttonWithType:UIButtonTypeSystem];
        [play setImage:[UIImage systemImageNamed:@"play"] forState:UIControlStateNormal];
        play.tintColor = ACPrimaryText();
        play.contentEdgeInsets = UIEdgeInsetsMake(20, 22, 20, 18);
        play.layer.borderColor = ACPrimaryText().CGColor;
        play.layer.borderWidth = 1.5;
        play.layer.cornerRadius = 41;
        play.translatesAutoresizingMaskIntoConstraints = NO;
        play.userInteractionEnabled = NO;

        UILabel *title = [UILabel new];
        title.text = @"FLOW";
        title.font = [UIFont systemFontOfSize:22 weight:UIFontWeightBold];
        title.textAlignment = NSTextAlignmentCenter;
        title.textColor = ACPrimaryText();
        title.translatesAutoresizingMaskIntoConstraints = NO;

        UILabel *subtitle = [UILabel new];
        subtitle.text = @"A mix based on your favourites";
        subtitle.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
        subtitle.textAlignment = NSTextAlignmentCenter;
        subtitle.textColor = ACSecondaryText();
        subtitle.translatesAutoresizingMaskIntoConstraints = NO;

        [_hero addSubview:watermark];
        [_hero addSubview:play];
        [_hero addSubview:title];
        [_hero addSubview:subtitle];
        [NSLayoutConstraint activateConstraints:@[
            [_hero.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
            [_hero.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
            [_hero.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
            [_hero.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],
            [watermark.centerXAnchor constraintEqualToAnchor:_hero.centerXAnchor],
            [watermark.centerYAnchor constraintEqualToAnchor:_hero.centerYAnchor],
            [play.centerXAnchor constraintEqualToAnchor:_hero.centerXAnchor],
            [play.topAnchor constraintEqualToAnchor:_hero.topAnchor constant:54],
            [play.widthAnchor constraintEqualToConstant:82],
            [play.heightAnchor constraintEqualToConstant:82],
            [title.topAnchor constraintEqualToAnchor:play.bottomAnchor constant:22],
            [title.centerXAnchor constraintEqualToAnchor:_hero.centerXAnchor],
            [subtitle.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:8],
            [subtitle.centerXAnchor constraintEqualToAnchor:_hero.centerXAnchor],
        ]];
        self.accessibilityLabel = @"Flow. A mix based on your favourites";
    }
    return self;
}
- (void)configure {}
@end

typedef void (^ACRadioPlay)(NSDictionary *station, NSURL *url, void (^done)(BOOL));

@interface ACRadioCatalog : UITableViewController <UISearchBarDelegate>
- (instancetype)initWithTuneIn:(BOOL)tuneIn play:(ACRadioPlay)play;
@end

@implementation ACRadioCatalog {
    BOOL _tuneIn, _playing;
    NSUInteger _searchGeneration, _playGeneration;
    ACRadioPlay _play;
    NSArray<NSDictionary *> *_stations;
    NSString *_message, *_directory, *_filterKey, *_filterValue, *_browseID, *_browseParam;
    NSArray<NSDictionary *> *_browseQuery;
    BOOL _filterExact;
}
- (instancetype)initWithTuneIn:(BOOL)tuneIn play:(ACRadioPlay)play {
    if ((self = [super initWithStyle:UITableViewStyleInsetGrouped])) {
        _tuneIn = tuneIn;
        _play = [play copy];
        self.title = tuneIn ? @"TuneIn" : @"Radio Browser";
    }
    return self;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    [self.tableView registerClass:ACRadioStationCell.class forCellReuseIdentifier:@"RadioStation"];
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 60;
    UISearchBar *bar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, 320, 52)];
    bar.delegate = self;
    bar.placeholder = ACMenuText(@"Название станции");
    if (!_directory && !_browseID) self.tableView.tableHeaderView = bar;
    if (_directory) [self loadDirectory];
    else if (_browseID) [self search:@""];
    else if (_tuneIn) _message = ACMenuText(@"Введите название станции.");
    else [self search:@""];
}
- (void)fetch:(NSString *)path host:(NSString *)host query:(NSArray<NSURLQueryItem *> *)query
         done:(void (^)(id))done {
    NSURLComponents *url = [NSURLComponents new];
    url.scheme = @"https"; url.host = host; url.path = path; url.queryItems = query;
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url.URL cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:8];
    [request setValue:@"airControlMobile/1.0" forHTTPHeaderField:@"User-Agent"];
    [[NSURLSession.sharedSession dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        id value = !error && [(NSHTTPURLResponse *)response statusCode] == 200 && data.length && data.length < 3000000 ?
            [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
        dispatch_async(dispatch_get_main_queue(), ^{ done(value); });
    }] resume];
}
- (void)collectTuneIn:(NSArray *)list into:(NSMutableArray *)entries depth:(NSUInteger)depth {
    if (depth > 5 || ![list isKindOfClass:NSArray.class]) return;
    for (id item in list) {
        if (![item isKindOfClass:NSDictionary.class]) continue;
        NSString *guide = [item[@"guide_id"] isKindOfClass:NSString.class] ? item[@"guide_id"] : @"";
        BOOL station = [guide rangeOfString:@"^s[0-9]+$" options:NSRegularExpressionSearch].location != NSNotFound;
        BOOL category = [guide rangeOfString:@"^[a-z][a-z0-9_-]{0,63}$" options:NSRegularExpressionSearch].location != NSNotFound && !station;
        NSURL *link = ACStreamURL(item[@"URL"]);
        if (link && [link.host.lowercaseString isEqualToString:@"opml.radiotime.com"] &&
            [link.path caseInsensitiveCompare:@"/Browse.ashx"] == NSOrderedSame) category = YES;
        NSArray *children = [item[@"children"] isKindOfClass:NSArray.class] ? item[@"children"] : nil;
        // TuneIn wraps some categories in structural outlines such as “FM”.
        // Expand only those wrappers; preserve actual browse nodes so the user
        // can navigate category-by-category instead of skipping levels.
        if (children.count && !station && !category)
            [self collectTuneIn:item[@"children"] into:entries depth:depth + 1];
        else [entries addObject:item];
        if (entries.count >= 250) break;
    }
}
- (void)loadDirectory {
    _message = @"Загрузка…";
    NSString *path = [_directory isEqualToString:@"countries"] ? @"/json/countrycodes" : @"/json/tags";
    NSArray *query = @[[NSURLQueryItem queryItemWithName:@"hidebroken" value:@"true"],
        [NSURLQueryItem queryItemWithName:@"order" value:[_directory isEqualToString:@"countries"] ? @"name" : @"stationcount"],
        [NSURLQueryItem queryItemWithName:@"reverse" value:[_directory isEqualToString:@"countries"] ? @"false" : @"true"],
        [NSURLQueryItem queryItemWithName:@"limit" value:@"250"]];
    void (^consume)(id) = ^(id value) {
        NSMutableArray *rows = [NSMutableArray array];
        BOOL countries = [self->_directory isEqualToString:@"countries"];
        if ([value isKindOfClass:NSArray.class]) for (id entry in value) {
            if (![entry isKindOfClass:NSDictionary.class]) continue;
            // Radio Browser's /json/countrycodes response uses `name` for
            // the ISO-3166 alpha-2 code (for example {name:"BE", ...}).
            NSString *key = entry[@"name"];
            if (![key isKindOfClass:NSString.class] || !key.length) continue;
            NSString *name = countries ? ([NSLocale.currentLocale localizedStringForCountryCode:key] ?: key) : key;
            [rows addObject:@{@"name":name, @"filter":key}];
        }
        if (countries) [rows sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
            return [a[@"name"] localizedCaseInsensitiveCompare:b[@"name"]];
        }];
        self->_stations = rows;
        self->_message = rows.count ? nil : @"Каталог категорий недоступен.";
        [self.tableView reloadData];
    };
    [self fetch:path host:@"de1.api.radio-browser.info" query:query done:^(id result) {
        if ([result isKindOfClass:NSArray.class] && [result count]) consume(result);
        else [self fetch:path host:@"nl1.api.radio-browser.info" query:query done:consume];
    }];
}
- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
    if (_directory) return;
    [self search:[searchBar.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] ?: @""];
}
- (void)search:(NSString *)text {
    NSUInteger request = ++_searchGeneration;
    _stations = @[];
    _message = @"Загрузка…";
    [self.tableView reloadData];
    void (^consume)(id) = ^(id value) {
        if (request != self->_searchGeneration) return;
        // Keep TuneIn's direct children intact: flattening `children` here
        // discarded category nodes and made browsing jump to the wrong level.
        id list = self->_tuneIn && [value isKindOfClass:NSDictionary.class] ? value[@"body"] : value;
        if ([list isKindOfClass:NSDictionary.class]) list = @[list];
        if (self->_tuneIn) {
            NSMutableArray *expanded = [NSMutableArray array];
            [self collectTuneIn:[list isKindOfClass:NSArray.class] ? list : @[] into:expanded depth:0];
            list = expanded;
        }
        NSMutableArray *stations = [NSMutableArray array];
        NSMutableSet *seen = [NSMutableSet set];
        if ([list isKindOfClass:NSArray.class]) for (id item in list) {
            if (![item isKindOfClass:NSDictionary.class]) continue;
            NSString *name = item[self->_tuneIn ? @"text" : @"name"];
            if (![name isKindOfClass:NSString.class] || !name.length) continue;
            NSString *guide = self->_tuneIn ? item[@"guide_id"] : nil;
            if (self->_tuneIn && (![guide isKindOfClass:NSString.class] ||
                [guide rangeOfString:@"^s[0-9]+$" options:NSRegularExpressionSearch].location == NSNotFound)) {
                NSURL *link = ACStreamURL(item[@"URL"]);
                NSString *browseParam = @"id";
                NSString *browse = ([guide isKindOfClass:NSString.class] &&
                    [guide rangeOfString:@"^[a-z][a-z0-9_-]{0,63}$" options:NSRegularExpressionSearch].location != NSNotFound) ? guide : nil;
                NSMutableArray<NSDictionary *> *browseQuery = [NSMutableArray array];
                if (browse.length) [browseQuery addObject:@{@"name":@"id", @"value":browse}];
                if ([link.host.lowercaseString isEqualToString:@"opml.radiotime.com"] &&
                    [link.path caseInsensitiveCompare:@"/Browse.ashx"] == NSOrderedSame) {
                    NSMutableArray *routeItems = [NSMutableArray array];
                    for (NSURLQueryItem *param in [NSURLComponents componentsWithURL:link resolvingAgainstBaseURL:NO].queryItems) {
                        if (([@[@"id", @"c", @"filter", @"formats", @"partnerId"] containsObject:param.name]) && param.value.length) {
                            [routeItems addObject:@{@"name":param.name, @"value":param.value}];
                            if ([param.name isEqualToString:@"c"]) { browse = param.value; browseParam = @"c"; }
                            else if ([param.name isEqualToString:@"id"] && ![browseParam isEqualToString:@"c"]) { browse = param.value; browseParam = @"id"; }
                        }
                    }
                    if (routeItems.count) browseQuery = routeItems;
                }
                if (browse.length) [stations addObject:@{@"name":name, @"browse":browse,
                    @"browseParam":browseParam, @"browseQuery":browseQuery}];
                continue;
            }
            NSURL *stream = self->_tuneIn ? nil : (ACStreamURL(item[@"url_resolved"]) ?: ACStreamURL(item[@"url"]));
            NSString *key = guide ?: stream.absoluteString;
            if (!key || [seen containsObject:key]) continue;
            [seen addObject:key];
            NSString *art = [item[self->_tuneIn ? @"image" : @"favicon"] isKindOfClass:NSString.class] ?
                item[self->_tuneIn ? @"image" : @"favicon"] : @"";
            NSMutableArray *details = [NSMutableArray array];
            if (!self->_tuneIn) for (NSString *key in @[@"country", @"tags"]) {
                id detail = item[key];
                if ([detail isKindOfClass:NSString.class] && [detail length]) [details addObject:detail];
            }
            [stations addObject:@{@"name":name, @"id":guide ?: @"", @"stream":stream.absoluteString ?: @"",
                @"art":art, @"detail":[details componentsJoinedByString:@" · "]}];
            if (stations.count >= 50) break;
        }
        self->_stations = stations;
        self->_message = ACMenuText(value ? @"Станции не найдены." : @"Каталог недоступен. Повторите поиск.");
        [self.tableView reloadData];
    };
    if (_tuneIn) {
        if (!text.length && _browseID) {
            BOOL category = [_browseParam isEqualToString:@"c"] || (!_browseParam && [@[@"music", @"local"] containsObject:_browseID]);
            NSMutableArray<NSURLQueryItem *> *route = [NSMutableArray array];
            for (NSDictionary *item in _browseQuery) {
                NSString *name = item[@"name"], *value = item[@"value"];
                if (name.length && value.length) [route addObject:[NSURLQueryItem queryItemWithName:name value:value]];
            }
            if (!route.count) [route addObject:[NSURLQueryItem queryItemWithName:category ? @"c" : @"id" value:_browseID]];
            [route addObject:[NSURLQueryItem queryItemWithName:@"render" value:@"json"]];
            [self fetch:@"/Browse.ashx" host:@"opml.radiotime.com" query:route done:consume];
            return;
        }
        if (!text.length) { _message = ACMenuText(@"Введите название станции."); [self.tableView reloadData]; return; }
        [self fetch:@"/Search.ashx" host:@"opml.radiotime.com" query:@[
            [NSURLQueryItem queryItemWithName:@"query" value:text], [NSURLQueryItem queryItemWithName:@"render" value:@"json"]
        ] done:consume];
    } else {
        NSMutableArray *query = [@[[NSURLQueryItem queryItemWithName:@"name" value:text], [NSURLQueryItem queryItemWithName:@"limit" value:@"50"],
            [NSURLQueryItem queryItemWithName:@"hidebroken" value:@"true"], [NSURLQueryItem queryItemWithName:@"order" value:@"clickcount"],
            [NSURLQueryItem queryItemWithName:@"reverse" value:@"true"]] mutableCopy];
            if (_filterKey) [query addObject:[NSURLQueryItem queryItemWithName:_filterKey value:_filterValue]];
        if (_filterExact) [query addObject:[NSURLQueryItem queryItemWithName:@"tagExact" value:@"true"]];
        [self fetch:@"/json/stations/search" host:@"de1.api.radio-browser.info" query:query done:^(id value) {
            if ([value isKindOfClass:NSArray.class]) consume(value);
            else if (request == self->_searchGeneration)
                [self fetch:@"/json/stations/search" host:@"nl1.api.radio-browser.info" query:query done:consume];
        }];
    }
}
- (BOOL)showsCategories { return !_directory && !_filterKey && !_browseID; }
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return [self showsCategories] ? 2 : 1; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self showsCategories] && section == 0 ? 3 : MAX(1, _stations.count);
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([self showsCategories] && indexPath.section == 0) {
        UITableViewCell *cell = ACCell(@[@"Жанры", @"Страны", @"Местное радио"][indexPath.row], nil,
            @[@"music.note.list", @"globe", @"location"][indexPath.row]);
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        return cell;
    }
    if (!_stations.count) return ACCell(_message, nil, @"info.circle");
    NSDictionary *station = _stations[indexPath.row];
    if (station[@"browse"] || station[@"filter"]) {
        UITableViewCell *cell = ACCell(station[@"name"], nil, @"folder");
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        return cell;
    }
    ACRadioStationCell *cell = [tableView dequeueReusableCellWithIdentifier:@"RadioStation" forIndexPath:indexPath];
    [cell configureWithStation:station];
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if ([self showsCategories] && indexPath.section == 0) {
        ACRadioCatalog *page = [[ACRadioCatalog alloc] initWithTuneIn:_tuneIn play:_play];
        NSInteger category = indexPath.row;
        page.title = ACMenuText(@[@"Жанры", @"Страны", @"Местное радио"][category]);
        if (_tuneIn) page->_browseID = @[@"music", @"r0", @"local"][category];
        else if (category < 2) page->_directory = category == 0 ? @"genres" : @"countries";
        else {
            NSString *region = NSLocale.currentLocale.countryCode;
            if (!region.length) {
                page->_directory = @"countries";
            } else {
                page->_filterKey = @"countrycode";
                page->_filterValue = region;
                NSString *country = [NSLocale.currentLocale localizedStringForCountryCode:region] ?: region;
                page.title = [@"Местное радио · " stringByAppendingString:country];
            }
        }
        [self.navigationController pushViewController:page animated:YES];
        return;
    }
    if (indexPath.row < _stations.count && (_stations[indexPath.row][@"browse"] || _stations[indexPath.row][@"filter"])) {
        NSDictionary *row = _stations[indexPath.row];
        ACRadioCatalog *page = [[ACRadioCatalog alloc] initWithTuneIn:_tuneIn play:_play];
        page.title = row[@"name"];
        page->_browseID = row[@"browse"];
        page->_browseParam = row[@"browseParam"];
        page->_browseQuery = row[@"browseQuery"];
        if (row[@"filter"]) {
            page->_filterKey = [_directory isEqualToString:@"countries"] ? @"countrycode" : @"tag";
            page->_filterExact = [_directory isEqualToString:@"genres"];
            page->_filterValue = row[@"filter"];
        }
        [self.navigationController pushViewController:page animated:YES];
        return;
    }
    if (_playing || indexPath.row >= _stations.count) return;
    _playing = YES;
    NSUInteger playRequest = ++_playGeneration;
    NSDictionary *station = _stations[indexPath.row];
    void (^finish)(BOOL) = ^(BOOL success) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!self->_playing || self->_playGeneration != playRequest) return;
            self->_playing = NO;
            if (success || !self.view.window || self.presentedViewController) return;
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:ACMenuText(@"Станция не запущена")
                message:ACMenuText(@"Проверьте доступность потока или выберите другую станцию.") preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
        });
    };
    if (!_tuneIn) { _play(station, ACStreamURL(station[@"stream"]), finish); return; }
    [self fetch:@"/Tune.ashx" host:@"opml.radiotime.com" query:@[
        [NSURLQueryItem queryItemWithName:@"id" value:station[@"id"]], [NSURLQueryItem queryItemWithName:@"render" value:@"json"]
    ] done:^(id value) {
        if (!self.view.window) { finish(NO); return; }
        id body = [value isKindOfClass:NSDictionary.class] ? value[@"body"] : nil;
        if ([body isKindOfClass:NSArray.class]) for (id entry in body) {
            if (![entry isKindOfClass:NSDictionary.class]) continue;
            NSURL *url = ACStreamURL(entry[@"url"] ?: entry[@"URL"]);
            if (url) { self->_play(station, url, finish); return; }
        }
        finish(NO);
    }];
}
@end

@interface ACDeezerCatalog : UITableViewController <UISearchBarDelegate>
@end

@implementation ACDeezerCatalog {
    NSArray<NSDictionary *> *_tracks;
    NSURLSessionDataTask *_search;
    AVPlayer *_preview;
    NSString *_message;
    NSUInteger _generation;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Deezer";
    _message = ACMenuText(@"Введите название трека или исполнителя.");
    UISearchBar *search = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, 320, 52)];
    search.placeholder = ACMenuText(@"Трек или исполнитель");
    search.delegate = self;
    self.tableView.tableHeaderView = search;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:ACMenuText(@"Открыть Deezer")
        style:UIBarButtonItemStylePlain target:self action:@selector(openDeezer)];
}
- (void)openDeezer {
    [UIApplication.sharedApplication openURL:[NSURL URLWithString:@"https://www.deezer.com/"] options:@{} completionHandler:nil];
}
- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [_preview pause];
    _preview = nil;
}
- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
    NSString *text = [searchBar.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (!text.length) return;
    [_search cancel];
    [_preview pause];
    _preview = nil;
    NSUInteger generation = ++_generation;
    _tracks = @[];
    _message = ACMenuText(@"Поиск…");
    [self.tableView reloadData];
    NSURLComponents *url = [NSURLComponents componentsWithString:@"https://api.deezer.com/search"];
    url.queryItems = @[[NSURLQueryItem queryItemWithName:@"q" value:text], [NSURLQueryItem queryItemWithName:@"limit" value:@"30"]];
    NSURLRequest *request = [NSURLRequest requestWithURL:url.URL cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:8];
    __weak typeof(self) weakSelf = self;
    _search = [NSURLSession.sharedSession dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        id json = !error && [(NSHTTPURLResponse *)response statusCode] == 200 && data.length && data.length < 1000000 ?
            [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
        id results = [json isKindOfClass:NSDictionary.class] ? json[@"data"] : nil;
        NSMutableArray *tracks = [NSMutableArray array];
        if ([results isKindOfClass:NSArray.class]) for (id item in results) {
            if (![item isKindOfClass:NSDictionary.class] || ![item[@"title"] isKindOfClass:NSString.class]) continue;
            id artist = [item[@"artist"] isKindOfClass:NSDictionary.class] ? item[@"artist"][@"name"] : nil;
            id art = [item[@"album"] isKindOfClass:NSDictionary.class] ? item[@"album"][@"cover_medium"] : nil;
            [tracks addObject:@{@"name":item[@"title"], @"detail":[artist isKindOfClass:NSString.class] ? artist : @"",
                @"art":ACStreamURL(art).absoluteString ?: @"", @"preview":ACStreamURL(item[@"preview"]).absoluteString ?: @""}];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            typeof(self) self = weakSelf;
            if (!self || self->_generation != generation) return;
            self->_tracks = tracks;
            self->_message = ACMenuText([results isKindOfClass:NSArray.class] ? @"Треки не найдены." : @"Каталог Deezer недоступен.");
            [self.tableView reloadData];
        });
    }];
    [_search resume];
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return MAX(1, _tracks.count); }
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return ACMenuText(@"Нажмите на трек, чтобы прослушать доступное превью на iPhone. Для полного трека откройте Deezer.");
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (!_tracks.count) return ACCell(_message, nil, @"info.circle");
    ACRadioStationCell *cell = [tableView dequeueReusableCellWithIdentifier:@"DeezerTrack"];
    if (!cell) cell = [[ACRadioStationCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"DeezerTrack"];
    NSDictionary *track = _tracks[indexPath.row];
    [cell configureWithStation:track];
    cell.accessoryType = [track[@"preview"] length] ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.row >= _tracks.count) return;
    NSURL *url = ACStreamURL(_tracks[indexPath.row][@"preview"]);
    if (!url) return;
    [_preview pause];
    _preview = [AVPlayer playerWithURL:url];
    [_preview play];
}
@end

static NSString *ACDeezerXMLEscape(NSString *value) {
    NSString *text = value ?: @"";
    return [[[[[text stringByReplacingOccurrencesOfString:@"&" withString:@"&amp;"]
        stringByReplacingOccurrencesOfString:@"<" withString:@"&lt;"]
        stringByReplacingOccurrencesOfString:@">" withString:@"&gt;"]
        stringByReplacingOccurrencesOfString:@"'" withString:@"&apos;"]
        stringByReplacingOccurrencesOfString:@"\"" withString:@"&quot;"];
}

// The 4STREAM WiimuNDK.encryptPwd native routine uses the Linkplay rolling
// XOR/letter encoding for credentials sent in PlayQueue UserLogin. Keep the
// implementation shared by Deezer and Qobuz instead of sending clear text.
static NSString *ACLinkplayEncryptPassword(NSString *password) {
    NSMutableData *modifiedUTF8 = [NSMutableData data];
    for (NSUInteger i = 0; i < password.length; i++) {
        uint16_t unit = [password characterAtIndex:i];
        uint8_t bytes[3];
        NSUInteger count;
        if (unit == 0) { bytes[0] = 0xc0; bytes[1] = 0x80; count = 2; }
        else if (unit < 0x80) { bytes[0] = (uint8_t)unit; count = 1; }
        else if (unit < 0x800) { bytes[0] = (uint8_t)(0xc0 | (unit >> 6)); bytes[1] = (uint8_t)(0x80 | (unit & 0x3f)); count = 2; }
        else { bytes[0] = (uint8_t)(0xe0 | (unit >> 12)); bytes[1] = (uint8_t)(0x80 | ((unit >> 6) & 0x3f)); bytes[2] = (uint8_t)(0x80 | (unit & 0x3f)); count = 3; }
        [modifiedUTF8 appendBytes:bytes length:count];
    }
    NSData *data = modifiedUTF8;
    const uint8_t *bytes = data.bytes;
    NSUInteger count = MIN(data.length, 255);
    uint32_t state = 0x1e00;
    NSMutableString *encoded = [NSMutableString stringWithCapacity:count * 2];
    for (NSUInteger i = 0; i < count; i++) {
        uint8_t value = (uint8_t)(bytes[i] ^ (state >> 8));
        state = (uint32_t)((((state & 0xffff) + value) * 0xce6d + 0x58bf) & 0xffffffff);
        [encoded appendFormat:@"%C%C", (unichar)('A' + value / 26), (unichar)('A' + value % 26)];
    }
    return encoded;
}

// WiiM Home's shortUuid() normalization is shared by login and by its signed
// Deezer2 catalog authorization.
static NSString *ACDeezer2ShortUUID(NSString *deviceID) {
    if (!deviceID.length) return nil;
    NSString *shortUUID = deviceID;
    if (deviceID.length > 24) {
        if ([deviceID.uppercaseString hasPrefix:@"UUID:"]) {
            NSString *compact = [[deviceID substringFromIndex:5] stringByReplacingOccurrencesOfString:@"-" withString:@""];
            if (compact.length < 24) return nil;
            shortUUID = [compact substringToIndex:24];
        } else {
            shortUUID = [deviceID substringToIndex:24];
        }
    }
    return shortUUID.length >= 16 ? shortUUID : nil;
}

// WiiM Home uses AES/CBC/NoPadding with a zero IV and zero padding.
static NSString *ACDeezer2Password(NSString *password, NSString *deviceID) {
    NSString *shortUUID = ACDeezer2ShortUUID(deviceID);
    if (!password.length || !shortUUID.length) return nil;
    NSData *key = [[shortUUID substringToIndex:16] dataUsingEncoding:NSUTF8StringEncoding];
    NSData *plain = [password dataUsingEncoding:NSUTF8StringEncoding];
    if (key.length != kCCKeySizeAES128 || !plain.length) return nil;
    size_t paddedLength = ((plain.length + kCCBlockSizeAES128 - 1) / kCCBlockSizeAES128) * kCCBlockSizeAES128;
    NSMutableData *padded = [NSMutableData dataWithLength:paddedLength];
    memcpy(padded.mutableBytes, plain.bytes, plain.length);
    NSMutableData *encrypted = [NSMutableData dataWithLength:paddedLength];
    uint8_t iv[kCCBlockSizeAES128] = {0};
    size_t encryptedLength = 0;
    CCCryptorStatus status = CCCrypt(kCCEncrypt, kCCAlgorithmAES, 0, key.bytes, key.length, iv,
                                     padded.bytes, padded.length, encrypted.mutableBytes, encrypted.length, &encryptedLength);
    if (status != kCCSuccess || encryptedLength != paddedLength) return nil;
    encrypted.length = encryptedLength;
    return [encrypted base64EncodedStringWithOptions:0];
}

static NSString *ACMD5Hex(NSString *value) {
    NSData *bytes = [value dataUsingEncoding:NSUTF8StringEncoding];
    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    CC_MD5(bytes.bytes, (CC_LONG)bytes.length, digest);
    NSMutableString *hex = [NSMutableString stringWithCapacity:32];
    for (NSUInteger i = 0; i < sizeof(digest); i++) [hex appendFormat:@"%02x", digest[i]];
    return hex;
}

// Deezer2's device response AES-encrypts its client secret for the controller.
static NSString *ACDeezer2DecryptSecret(NSString *encodedSecret, NSString *deviceID) {
    NSString *shortUUID = ACDeezer2ShortUUID(deviceID);
    if (!encodedSecret.length || !shortUUID.length) return nil;
    NSData *encrypted = [[NSData alloc] initWithBase64EncodedString:encodedSecret options:0];
    NSData *key = [[shortUUID substringToIndex:16] dataUsingEncoding:NSUTF8StringEncoding];
    if (!encrypted.length || encrypted.length % kCCBlockSizeAES128 || key.length != kCCKeySizeAES128) return nil;
    NSMutableData *plain = [NSMutableData dataWithLength:encrypted.length];
    uint8_t iv[kCCBlockSizeAES128] = {0};
    size_t plainLength = 0;
    CCCryptorStatus status = CCCrypt(kCCDecrypt, kCCAlgorithmAES, 0, key.bytes, key.length, iv,
                                     encrypted.bytes, encrypted.length, plain.mutableBytes, plain.length, &plainLength);
    if (status != kCCSuccess || plainLength > plain.length) return nil;
    plain.length = plainLength;
    NSMutableData *clean = [NSMutableData dataWithCapacity:plain.length];
    const uint8_t *plainBytes = plain.bytes;
    for (NSUInteger index = 0; index < plain.length; index++) if (plainBytes[index] != 0) [clean appendBytes:&plainBytes[index] length:1];
    return [[NSString alloc] initWithData:clean encoding:NSUTF8StringEncoding];
}

static NSString *ACDeezerTrackID(NSDictionary *entry) {
    for (id candidate in @[entry[@"track_id"] ?: @"", entry[@"id"] ?: @"", entry[@"url"] ?: @"", entry[@"uri"] ?: @""]) {
        NSString *text = [candidate isKindOfClass:NSString.class] ? candidate : [candidate description];
        NSString *last = [[text componentsSeparatedByString:@","] lastObject];
        last = [[last stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]
            stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"[]"]];
        if ([last rangeOfString:@"^[0-9]{2,}$" options:NSRegularExpressionSearch].location != NSNotFound) return last;
        NSURLComponents *components = [NSURLComponents componentsWithString:text];
        NSString *pathID = components.path.lastPathComponent;
        if ([pathID rangeOfString:@"^[0-9]{2,}$" options:NSRegularExpressionSearch].location != NSNotFound) return pathID;
    }
    return nil;
}

static NSString *ACDeezerArt(NSDictionary *entry);

static BOOL ACDeezerIsPlayableTrack(NSDictionary *entry) {
    NSString *trackID = [entry[@"track_id"] isKindOfClass:NSString.class] ? entry[@"track_id"] : nil;
    NSString *type = [entry[@"type"] isKindOfClass:NSString.class] ? [entry[@"type"] lowercaseString] : @"";
    if (trackID.length) return ACDeezerTrackID(entry) != nil;
    if ([type containsString:@"album"] || [type containsString:@"playlist"] ||
        [type containsString:@"folder"] || [type containsString:@"artist"] ||
        [type containsString:@"category"] || [type containsString:@"directory"] ||
        [type containsString:@"container"]) return NO;
    BOOL explicitTrack = [@[@"track", @"audio", @"audiotrack", @"musictrack", @"song", @"object.item.audioitem.musictrack"] containsObject:type];
    id streams = entry[@"streams"];
    BOOL hasStreams = ([streams isKindOfClass:NSArray.class] && [streams count] > 0) ||
        ([streams isKindOfClass:NSDictionary.class] && [streams count] > 0);
    NSString *url = [entry[@"url"] isKindOfClass:NSString.class] ? [entry[@"url"] lowercaseString] : @"";
    BOOL trackURL = [url containsString:@"/track/"] || [url containsString:@"/song/"];
    NSString *identifier = [entry[@"id"] isKindOfClass:NSString.class] ? entry[@"id"] : @"";
    BOOL trackIdentifier = [identifier.lowercaseString containsString:@"track"] || [identifier.lowercaseString containsString:@"song"];
    return ACDeezerTrackID(entry) && (explicitTrack || hasStreams || trackURL || trackIdentifier);
}

static NSMutableDictionary<NSString *, NSDictionary<NSString *, NSString *> *> *ACDeezerArtworkCache(void) {
    static NSMutableDictionary *cache;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ cache = [NSMutableDictionary dictionary]; });
    return cache;
}

static NSString *ACDeezerArtworkKey(NSString *title, NSString *artist) {
    return [NSString stringWithFormat:@"%@|%@", [(title ?: @"") lowercaseString], [(artist ?: @"") lowercaseString]];
}

static void ACDeezerRememberArtwork(NSString *deviceID, NSArray<NSDictionary *> *tracks) {
    if (!deviceID.length) return;
    NSMutableDictionary *artwork = [NSMutableDictionary dictionary];
    for (NSDictionary *track in tracks) {
        NSString *url = ACDeezerArt(track);
        NSString *title = [track[@"title"] isKindOfClass:NSString.class] ? track[@"title"] : @"";
        id value = track[@"artist"];
        NSString *artist = [value isKindOfClass:NSDictionary.class] ? (value[@"title"] ?: value[@"name"] ?: @"") : ([value isKindOfClass:NSString.class] ? value : @"");
        NSString *trackID = ACDeezerTrackID(track);
        if (url.length && title.length) {
            artwork[ACDeezerArtworkKey(title, artist)] = url;
            artwork[ACDeezerArtworkKey(title, @"")] = url;
            if (trackID.length) artwork[[ @"id:" stringByAppendingString:trackID ]] = url;
        }
    }
    @synchronized (ACDeezerArtworkCache()) { ACDeezerArtworkCache()[deviceID] = artwork; }
}

static NSString *ACDeezerRememberedArtwork(NSString *deviceID, NSString *title, NSString *artist, NSString *trackID) {
    if (!deviceID.length || (!title.length && !trackID.length)) return nil;
    @synchronized (ACDeezerArtworkCache()) {
        NSDictionary *artwork = ACDeezerArtworkCache()[deviceID];
        return (trackID.length ? artwork[[ @"id:" stringByAppendingString:trackID ]] : nil) ?: artwork[ACDeezerArtworkKey(title, artist)] ?: artwork[ACDeezerArtworkKey(title, @"")];
    }
}

static NSString *ACDeezerImageURL(id value, NSUInteger depth) {
    if (!value || depth > 6) return nil;
    if ([value isKindOfClass:NSString.class]) {
        NSString *text = [value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if ([text hasPrefix:@"//"]) text = [@"https:" stringByAppendingString:text];
        NSURLComponents *parts = [NSURLComponents componentsWithString:text];
        if (![@[@"https", @"http"] containsObject:parts.scheme.lowercaseString] || !parts.host.length || parts.user.length || parts.password.length) return nil;
        NSString *address = parts.URL.absoluteString;
        // Deezer's CDN uses the size prefix in the path (for example
        // 56x56-000000-80-0-0.jpg). Ask for its XL rendition instead.
        if ([parts.host.lowercaseString containsString:@"dzcdn"] || [parts.host.lowercaseString containsString:@"deezer"]) {
            NSString *path = parts.percentEncodedPath ?: parts.path;
            NSRegularExpression *size = [NSRegularExpression regularExpressionWithPattern:@"/(?:[0-9]{2,4}x[0-9]{2,4})-" options:0 error:nil];
            NSTextCheckingResult *match = [size firstMatchInString:path options:0 range:NSMakeRange(0, path.length)];
            if (match) {
                NSString *updated = [path stringByReplacingCharactersInRange:match.range withString:@"/1000x1000-"];
                parts.percentEncodedPath = updated;
                address = parts.URL.absoluteString ?: address;
            }
        }
        return address;
    }
    NSArray *preferred = @[@"cover_xl", @"picture_xl", @"image_xl", @"cover_big", @"picture_big", @"image_big", @"original", @"large", @"url", @"src", @"href", @"uri", @"default", @"imageurl", @"coverurl", @"artworkurl", @"medium", @"cover_medium", @"small", @"cover_small", @"thumbnail"];
    if ([value isKindOfClass:NSDictionary.class]) {
        NSDictionary *dictionary = value;
        for (NSString *key in preferred) {
            NSString *found = ACDeezerImageURL(dictionary[key], depth + 1);
            if (found.length) return found;
        }
        for (id nested in dictionary.allValues) {
            NSString *found = ACDeezerImageURL(nested, depth + 1);
            if (found.length) return found;
        }
    } else if ([value isKindOfClass:NSArray.class]) {
        for (id nested in (NSArray *)value) {
            NSString *found = ACDeezerImageURL(nested, depth + 1);
            if (found.length) return found;
        }
    }
    return nil;
}

static NSString *ACDeezerArt(NSDictionary *entry) {
    id album = [entry[@"album"] isKindOfClass:NSDictionary.class] ? entry[@"album"] : nil;
    for (NSString *key in @[@"cover_xl", @"picture_xl", @"image_xl", @"cover_big", @"picture_big", @"image_big", @"images", @"image", @"cover", @"cover_url", @"coverUrl", @"artwork", @"artworkUrl", @"albumArtURI", @"imageUrl", @"image_url", @"thumbnail", @"thumbnail_url", @"icon", @"icon_url"]) {
        NSString *address = ACDeezerImageURL(entry[key], 0);
        if (address.length) return address;
    }
    for (id rawKey in entry) {
        if (![rawKey isKindOfClass:NSString.class]) continue;
        NSString *key = [rawKey lowercaseString];
        if (![key containsString:@"image"] && ![key containsString:@"cover"] && ![key containsString:@"artwork"] && ![key containsString:@"thumbnail"]) continue;
        NSString *address = ACDeezerImageURL(entry[rawKey], 0);
        if (address.length) return address;
    }
    if (album) {
        for (NSString *key in @[@"cover_xl", @"picture_xl", @"image_xl", @"cover_big", @"picture_big", @"image_big", @"images", @"image", @"cover", @"cover_url", @"coverUrl", @"artwork", @"thumbnail", @"cover_medium", @"cover_small"]) {
            NSString *address = ACDeezerImageURL(album[key], 0);
            if (address.length) return address;
        }
        for (id rawKey in album) {
            if (![rawKey isKindOfClass:NSString.class]) continue;
            NSString *key = [rawKey lowercaseString];
            if (![key containsString:@"image"] && ![key containsString:@"cover"] && ![key containsString:@"artwork"]) continue;
            NSString *address = ACDeezerImageURL(album[rawKey], 0);
            if (address.length) return address;
        }
    }
    return nil;
}

@interface ACDeezerRedirectGuard : NSObject <NSURLSessionTaskDelegate>
@end
@implementation ACDeezerRedirectGuard
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
    willPerformHTTPRedirection:(NSHTTPURLResponse *)response newRequest:(NSURLRequest *)request
    completionHandler:(void (^)(NSURLRequest *))completionHandler {
    NSString *oldHost = task.currentRequest.URL.host.lowercaseString;
    NSURL *newURL = request.URL;
    BOOL allowed = [newURL.scheme.lowercaseString isEqualToString:@"https"] &&
        [newURL.host.lowercaseString isEqualToString:oldHost] && [oldHost hasSuffix:@".airable.io"];
    completionHandler(allowed ? request : nil);
}
@end

@interface ACLegacyDeezerCatalog : UITableViewController <UISearchBarDelegate, NSURLSessionTaskDelegate>
@property(nonatomic, weak) ACStore *store;
- (void)loadURL:(NSString *)address query:(NSString *)query push:(BOOL)push retryCount:(NSUInteger)retryCount;
- (void)playEntry:(NSDictionary *)entry;
@end

@implementation ACLegacyDeezerCatalog {
    NSDictionary *_userInfo;
    NSDictionary *_page;
    NSArray<NSDictionary *> *_entries;
    NSString *_pageURL;
    NSString *_searchURL;
    NSString *_password;
    NSString *_message;
    NSURLSession *_catalogSession;
    ACDeezerRedirectGuard *_redirectGuard;
    NSMutableArray<NSDictionary *> *_history;
    BOOL _busy;
    BOOL _resolvingSource;
    NSString *_source;
    NSDictionary *_streamServiceInfo;
    NSString *_catalogAuthorizationSummary;
    NSDictionary *_albumDetail;
    NSTimeInterval _getInfoStartedAt;
    BOOL _playFlowOnLoad;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Deezer";
    _message = @"Подключаюсь к аккаунту Deezer на колонке…";
    UISearchBar *search = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, 320, 52)];
    search.placeholder = @"Трек, исполнитель или альбом";
    search.delegate = self;
    self.tableView.tableHeaderView = search;
    _redirectGuard = [ACDeezerRedirectGuard new];
    _history = [NSMutableArray array];
    NSURLSessionConfiguration *configuration = NSURLSessionConfiguration.ephemeralSessionConfiguration;
    configuration.URLCache = nil;
    _catalogSession = [NSURLSession sessionWithConfiguration:configuration delegate:_redirectGuard delegateQueue:nil];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Аккаунт"
        style:UIBarButtonItemStylePlain target:self action:@selector(accountAction)];
    [self getUserInfo];
}
- (LPDevice *)selectedDevice {
    LPDevice *device = self.store.selected;
    return device && [ACDeviceID(device) isEqualToString:self.store.targetID] ? device : nil;
}
- (void)setBusy:(BOOL)busy message:(NSString *)message {
    _busy = busy;
    if (message) _message = message;
    self.navigationItem.rightBarButtonItem.enabled = !busy;
    [self.tableView reloadData];
}
- (void)soapAction:(NSString *)action arguments:(NSDictionary<NSString *, NSString *> *)arguments
          completion:(void (^)(NSDictionary *, NSString *))completion {
    LPDevice *device = [self selectedDevice];
    if (!device) { completion(nil, @"Сначала выберите Linkplay-устройство."); return; }
    NSMutableString *children = [NSMutableString string];
    for (NSString *name in arguments) [children appendFormat:@"<%@>%@</%@>", name, ACDeezerXMLEscape(arguments[name]), name];
    ACDiscoverPlayQueueEndpoint(device, action, ^(NSInteger port, NSString *path, NSString *service, NSString *discoveryError) {
        if (!path.length) { completion(nil, discoveryError ?: @"Служба PlayQueue не найдена."); return; }
        NSString *body = [NSString stringWithFormat:@"<s:Envelope xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\"><s:Body><u:%@ xmlns:u=\"%@\">%@</u:%@></s:Body></s:Envelope>", action, service, children, action];
        NSString *soapAction = [NSString stringWithFormat:@"\"%@#%@\"", service, action];
        ACRequestWithTimeout(device.deviceStatus.IP, port, path, nil, nil, body, soapAction,
                             [action isEqualToString:@"UserLogin"] ? 35.0 : 10.0, ^(NSData *data) {
        DDXMLNode *root = ACXMLData(data);
        if (!root) { completion(nil, [NSString stringWithFormat:@"Устройство не ответило на %@.", action]); return; }
        DDXMLNode *fault = ACNodes(root, @".//*[local-name()='Fault']").firstObject;
        if (fault) {
            NSString *code = ACDIDL(fault, @"errorCode");
            NSString *description = ACDIDL(fault, @"errorDescription");
            NSArray<NSString *> *faultParts = @[code ?: @"", description ?: @""];
            NSPredicate *nonempty = [NSPredicate predicateWithBlock:^BOOL(NSString *value, NSDictionary *bindings) { return value.length > 0; }];
            NSString *faultText = [[faultParts filteredArrayUsingPredicate:nonempty] componentsJoinedByString:@" — "];
            completion(nil, faultText.length ? [NSString stringWithFormat:@"Deezer: UPnP %@", faultText] : @"Устройство отклонило команду Deezer.");
            return;
        }
        DDXMLNode *response = ACNodes(root, [NSString stringWithFormat:@"./*[local-name()='Body']/*[local-name()='%@Response']", action]).firstObject;
        if (!response) { completion(nil, [NSString stringWithFormat:@"Неожиданный ответ %@.", action]); return; }
        NSMutableDictionary *values = [NSMutableDictionary dictionary];
        for (DDXMLNode *node in response.children) if (node.name.length) values[node.name] = node.stringValue ?: @"";
        completion(values, nil);
        });
    });
}
- (void)getUserInfo {
    LPDevice *device = [self selectedDevice];
    if (!device) { [self setBusy:NO message:@"Выберите Linkplay-устройство на вкладке «Устройства». "]; return; }
    if (!_source.length) {
        if (_resolvingSource) return;
        _resolvingSource = YES;
        [self setBusy:YES message:@"Определяю поддерживаемый сервис Deezer на колонке…"];
        NSString *identity = [ACDeviceID(device) copy];
        ACResolveDeezerSource(device, ^(NSString *source, NSDictionary *serviceInfo) {
            self->_resolvingSource = NO;
            LPDevice *current = [self selectedDevice];
            if (![ACDeviceID(current) isEqualToString:identity]) { [self setBusy:NO message:@"Выбранная зона изменилась. Повторите запрос."]; return; }
            self->_source = source;
            self->_streamServiceInfo = serviceInfo;
            [self getUserInfo];
        });
        return;
    }
    _getInfoStartedAt = floor(NSDate.date.timeIntervalSince1970);
    [self setBusy:YES message:@"Проверяю вход Deezer на колонке…"];
    NSString *source = _source;
    [self soapAction:@"GetUserInfo" arguments:@{@"AccountSource": source} completion:^(NSDictionary *result, NSString *error) {
        NSDictionary *info = nil;
        NSString *json = result[@"Result"];
        NSData *data = [json dataUsingEncoding:NSUTF8StringEncoding];
        id value = data.length ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
        if ([value isKindOfClass:NSDictionary.class]) info = value;
        self->_userInfo = info;
        BOOL loggedIn = [self isReady:info];
        [self setBusy:NO message:loggedIn ? @"Загружаю библиотеку Deezer…" : (error ?: @"Войдите в Deezer для выбранной колонки.")];
        if (loggedIn) [self loadURL:[self initialCatalogURLForInfo:info] query:nil push:NO];
        else [self presentLogin];
    }];
}
- (BOOL)isReady:(NSDictionary *)info {
    NSString *message = [info[@"msg"] isKindOfClass:NSString.class] ? info[@"msg"] : @"";
    if ([@[@"not login", @"action timeout"] containsObject:message.lowercaseString]) return NO;
    if ([_source isEqualToString:@"Deezer2"]) {
        NSString *userID = [info[@"userId"] isKindOfClass:NSString.class] ? info[@"userId"] : info[@"user_id"];
        NSString *secret = [info[@"secret"] isKindOfClass:NSString.class] ? info[@"secret"] : info[@"clientSecret"];
        NSString *baseURL = [info[@"baseUrl"] isKindOfClass:NSString.class] ? info[@"baseUrl"] : @"";
        return userID.length > 0 && secret.length > 0 && baseURL.length > 0;
    }
    return [info[@"access_token"] length] && [info[@"deezer_secret"] length] && [info[@"list_url"] length];
}
- (void)accountAction {
    if ([self isReady:_userInfo]) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:ACMenuText(@"Deezer на колонке")
            message:[NSString stringWithFormat:@"%@\n\nПароль не сохраняется в airControl.", _userInfo[@"user_name"] ?: @"Подключено"]
            preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:ACMenuText(@"Обновить библиотеку") style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
            [self loadURL:[self initialCatalogURLForInfo:self->_userInfo] query:nil push:NO];
        }]];
        [alert addAction:[UIAlertAction actionWithTitle:ACMenuText(@"Сменить аккаунт") style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) { [self presentLogin]; }]];
        [alert addAction:[UIAlertAction actionWithTitle:ACMenuText(@"Cancel") style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    } else [self presentLogin];
}
- (void)presentLogin {
    if (!self.view.window || self.presentedViewController || _busy) return;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:ACMenuText(@"Вход Deezer на колонке")
        message:ACMenuText(@"Вход выполняется на выбранной колонке. Для A98 используется сервис Deezer2; для A31 — совместимый старый сервис. Deezer App ID не требуется.")
        preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) { field.placeholder = ACMenuText(@"Логин или почта"); field.autocapitalizationType = UITextAutocapitalizationTypeNone; field.keyboardType = UIKeyboardTypeEmailAddress; field.text = self->_userInfo[@"user_name"]; }];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) { field.placeholder = ACMenuText(@"Пароль"); field.secureTextEntry = YES; }];
    [alert addAction:[UIAlertAction actionWithTitle:ACMenuText(@"Войти") style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        NSString *username = [alert.textFields[0].text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        NSString *password = alert.textFields[1].text ?: @"";
        if (!username.length || !password.length) { [self noticeDeezer:ACMenuText(@"Введите логин и пароль Deezer.")]; return; }
        self->_password = password;
        NSString *source = self->_source ?: ACDeezerSourceForDevice([self selectedDevice]);
        NSString *encodedPassword = [source isEqualToString:@"Deezer2"]
            ? ACDeezer2Password(password, ACDeviceID([self selectedDevice]))
            : ACLinkplayEncryptPassword(password);
        if (!encodedPassword.length) {
            [self noticeDeezer:[source isEqualToString:@"Deezer2"]
                ? @"Не удалось подготовить Deezer2-вход: отсутствует UUID устройства."
                : @"Не удалось подготовить пароль Deezer."];
            return;
        }
        NSDictionary *args = [source isEqualToString:@"Deezer2"]
            ? @{@"AccountSource": source, @"UserName": username, @"PassWord": encodedPassword,
                @"Code": @"", @"Proxy": @"", @"SavePass": @"0"}
            : @{@"AccountSource": source, @"UserName": username, @"PassWord": encodedPassword,
                @"Code": @"", @"Proxy": @"", @"SavePass": @"0", @"Token": @""};
        [self setBusy:YES message:@"Выполняю вход на колонке…"];
        [self soapAction:@"UserLogin" arguments:args completion:^(NSDictionary *result, NSString *error) {
            if (error) {
                NSString *sourceError = [NSString stringWithFormat:@"%@ — %@", source, error];
                [self setBusy:NO message:sourceError];
                [self noticeDeezer:sourceError];
                return;
            }
            [self getUserInfo];
        }];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:ACMenuText(@"Cancel") style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}
- (void)noticeDeezer:(NSString *)message {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Deezer" message:ACMenuText(message) preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
        if (self.view.window && !self.presentedViewController) [self presentViewController:alert animated:YES completion:nil];
    });
}
- (NSURL *)validatedCatalogURL:(NSString *)address base:(NSString *)base {
    NSURL *url = [NSURL URLWithString:address relativeToURL:[NSURL URLWithString:base]].absoluteURL;
    NSString *host = url.host.lowercaseString;
    NSURL *root = [NSURL URLWithString:base];
    if (![url.scheme.lowercaseString isEqualToString:@"https"] || ![host hasSuffix:@".airable.io"] ||
        ![host isEqualToString:root.host.lowercaseString] || url.user.length || url.password.length || url.port) return nil;
    return url;
}
- (NSString *)initialCatalogURLForInfo:(NSDictionary *)info {
    if ([_source isEqualToString:@"Deezer2"]) {
        NSString *base = [info[@"baseUrl"] isKindOfClass:NSString.class] ? info[@"baseUrl"] : @"";
        if (![base hasSuffix:@"/"]) base = [base stringByAppendingString:@"/"];
        // WiiM Home's Deezer2 landing page is baseUrl + "deezer".
        // "deezer/collection" is the separate My Library page.
        return [base stringByAppendingString:@"deezer"];
    }
    return [info[@"list_url"] isKindOfClass:NSString.class] ? info[@"list_url"] : @"";
}
- (BOOL)isDeezer2HomePage {
    if (![_source isEqualToString:@"Deezer2"]) return NO;
    NSURLComponents *components = [NSURLComponents componentsWithString:_pageURL ?: @""];
    return [components.path.lastPathComponent.lowercaseString isEqualToString:@"deezer"];
}
- (NSArray<NSDictionary *> *)homeEntriesFromEntries:(NSArray<NSDictionary *> *)entries {
    NSArray<NSArray<NSString *> *> *groups = @[
        @[@"flow"], @[@"charts"], @[@"mixes"], @[@"genres"], @[@"my library", @"collection"]
    ];
    NSMutableArray<NSDictionary *> *ordered = [NSMutableArray array];
    NSMutableSet<NSString *> *used = [NSMutableSet set];
    for (NSArray<NSString *> *tokens in groups) {
        for (NSUInteger index = 0; index < entries.count; index++) {
            NSDictionary *entry = entries[index];
            NSString *identity = [[NSString stringWithFormat:@"%@ %@ %@", entry[@"title"] ?: @"", entry[@"id"] ?: @"", entry[@"url"] ?: @""] lowercaseString];
            BOOL matches = NO;
            for (NSString *token in tokens) if ([identity containsString:token]) { matches = YES; break; }
            if (matches && ![used containsObject:@(index).stringValue]) {
                [ordered addObject:entry];
                [used addObject:@(index).stringValue];
                break;
            }
        }
    }
    if (!ordered.count) return entries;
    for (NSUInteger index = 0; index < entries.count; index++) {
        if (![used containsObject:@(index).stringValue]) [ordered addObject:entries[index]];
    }
    return ordered;
}
- (BOOL)isFlowEntry:(NSDictionary *)entry {
    NSString *identity = [[NSString stringWithFormat:@"%@ %@ %@", entry[@"title"] ?: @"", entry[@"id"] ?: @"", entry[@"url"] ?: @""] lowercaseString];
    return [identity containsString:@"flow"];
}
- (NSString *)deezer2UserAgent:(NSDictionary *)info {
    LPDevice *device = [self selectedDevice];
    NSString *project = [_streamServiceInfo[@"brand"] isKindOfClass:NSString.class] ? _streamServiceInfo[@"brand"] : (device.deviceStatus.productName ?: @"Linkplay");
    NSString *hardware = [_streamServiceInfo[@"hw"] isKindOfClass:NSString.class] ? _streamServiceInfo[@"hw"] : @"";
    NSString *firmware = device.deviceStatus.firmware ?: @"";
    NSString *deviceName = device.deviceStatus.friendlyName ?: @"";
    NSString *appVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"] ?: @"1";
    NSString *os = [NSString stringWithFormat:@"iOS/%@", UIDevice.currentDevice.systemVersion ?: @""];
    return [NSString stringWithFormat:@"%@ (hw=\"%@\"; fw=\"%@\"; fn=\"%@\") +Companion(app=\"%@\"; os=\"%@\"; hw=\"%@\")",
            project, hardware, firmware, deviceName, appVersion, os, UIDevice.currentDevice.model ?: @"iPhone"];
}
- (NSString *)authorizationForInfo:(NSDictionary *)info URL:(NSURL *)url {
    if ([_source isEqualToString:@"Deezer2"]) {
        LPDevice *device = [self selectedDevice];
        NSString *uuid = ACDeezer2ShortUUID(ACDeviceID(device));
        NSString *secret = [info[@"secret"] isKindOfClass:NSString.class] ? info[@"secret"] : info[@"clientSecret"];
        NSString *decryptedSecret = ACDeezer2DecryptSecret(secret, uuid);
        BOOL usedDecryptedSecret = decryptedSecret.length > 0;
        decryptedSecret = decryptedSecret ?: secret;
        if (!uuid.length || !decryptedSecret.length || !url.absoluteString.length) return @"";
        NSString *agent = [self deezer2UserAgent:info];
        NSString *publicIP = [info[@"publicIP"] isKindOfClass:NSString.class] ? info[@"publicIP"] : @"null";
        NSTimeInterval offset = [info[@"offset"] doubleValue];
        NSDate *date = [NSDate dateWithTimeIntervalSinceNow:offset];
        NSDateFormatter *formatter = [NSDateFormatter new];
        formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
        formatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
        formatter.dateFormat = @"EEE, dd MMM yyyy HH:mm:ss 'GMT'";
        NSString *dateHeader = [formatter stringFromDate:date];
        NSString *inner = ACMD5Hex([NSString stringWithFormat:@"%@;%@", decryptedSecret, uuid]);
        NSString *signedText = [NSString stringWithFormat:@"%@;%@;%@;%@;%@;GET %@", inner, uuid, agent, publicIP, dateHeader, url.absoluteString];
        NSString *signature = ACMD5Hex(signedText);
        _catalogAuthorizationSummary = [NSString stringWithFormat:@"Deezer2; UUID %lu chars; secret %@; brand %@; hw %@; firmware %@; device name %@; public IP %@; offset %@; URL host %@",
            (unsigned long)uuid.length, usedDecryptedSecret ? @"decrypted" : @"raw/unknown",
            [_streamServiceInfo[@"brand"] length] ? @"yes" : @"no",
            [_streamServiceInfo[@"hw"] length] ? @"yes" : @"no",
            device.deviceStatus.firmware.length ? @"yes" : @"no",
            device.deviceStatus.friendlyName.length ? @"yes" : @"no",
            [info[@"publicIP"] length] ? @"present" : @"missing",
            info[@"offset"] ? @"present" : @"missing", url.host ?: @"missing"];
        NSData *authData = [[NSString stringWithFormat:@"%@:%@", uuid, signature] dataUsingEncoding:NSUTF8StringEncoding];
        // WiiM Home's Deezer2 API expects the raw Base64 signature here;
        // unlike the legacy Deezer endpoint, it does not use the "Basic " scheme prefix.
        return [authData base64EncodedStringWithOptions:0];
    }
    NSURL *catalogURL = url;
    _catalogAuthorizationSummary = [NSString stringWithFormat:@"%@ authorization; token %@; device secret %@; URL host %@",
        _source.length ? _source : @"Unknown source",
        [info[@"access_token"] length] ? @"present" : @"missing",
        [info[@"deezer_secret"] length] ? @"present" : @"missing",
        catalogURL.host ?: @"missing"];
    NSTimeInterval now = floor(NSDate.date.timeIntervalSince1970);
    NSTimeInterval deviceNow = now + [info[@"fw_cur_time"] doubleValue] + [info[@"offset_time"] doubleValue] - _getInfoStartedAt;
    NSString *value = [NSString stringWithFormat:@"%@%@%.0f", info[@"access_token"], info[@"deezer_secret"], deviceNow];
    NSData *bytes = [value dataUsingEncoding:NSUTF8StringEncoding];
    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    CC_MD5(bytes.bytes, (CC_LONG)bytes.length, digest);
    NSMutableString *hex = [NSMutableString stringWithCapacity:32];
    for (NSUInteger i = 0; i < sizeof(digest); i++) [hex appendFormat:@"%02x", digest[i]];
    while (hex.length > 1 && [hex characterAtIndex:0] == '0') [hex deleteCharactersInRange:NSMakeRange(0, 1)];
    NSData *basicData = [[NSString stringWithFormat:@"%@:%@", info[@"access_token"], hex] dataUsingEncoding:NSUTF8StringEncoding];
    NSString *basic = [basicData base64EncodedStringWithOptions:0];
    return [@"Basic " stringByAppendingString:basic];
}
- (void)updateDeezer2InfoFromResponse:(NSHTTPURLResponse *)response {
    if (![_source isEqualToString:@"Deezer2"] || ![response isKindOfClass:NSHTTPURLResponse.class]) return;
    NSMutableDictionary *updated = [_userInfo mutableCopy];
    if (!updated) return;
    NSString *publicIP = [response valueForHTTPHeaderField:@"X-Client-Ip"];
    if (publicIP.length) updated[@"publicIP"] = publicIP;
    NSString *dateHeader = [response valueForHTTPHeaderField:@"Date"];
    if (dateHeader.length) {
        NSDateFormatter *formatter = [NSDateFormatter new];
        formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
        formatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
        formatter.dateFormat = @"EEE, dd MMM yyyy HH:mm:ss 'GMT'";
        NSDate *serverDate = [formatter dateFromString:dateHeader];
        if (serverDate) {
            NSInteger offset = (NSInteger)(floor(serverDate.timeIntervalSince1970) - floor(NSDate.date.timeIntervalSince1970));
            updated[@"offset"] = @(offset);
        }
    }
    _userInfo = updated;
}
- (void)loadURL:(NSString *)address query:(NSString *)query push:(BOOL)push {
    [self loadURL:address query:query push:push retryCount:0];
}
- (void)loadURL:(NSString *)address query:(NSString *)query push:(BOOL)push retryCount:(NSUInteger)retryCount {
    NSDictionary *info = _userInfo;
    if (![self isReady:info]) { [self presentLogin]; return; }
    NSString *base = [_source isEqualToString:@"Deezer2"] ? info[@"baseUrl"] : info[@"list_url"];
    NSURL *url = [self validatedCatalogURL:address base:base];
    if (!url) { [self setBusy:NO message:@"Ссылка каталога Deezer не относится к серверу airable."]; return; }
    if (query.length) {
        NSURLComponents *components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
        NSMutableArray *items = [components.queryItems mutableCopy] ?: [NSMutableArray array];
        [items removeObjectsAtIndexes:[items indexesOfObjectsPassingTest:^BOOL(NSURLQueryItem *item, NSUInteger index, BOOL *stop) { return [@[@"t", @"q"] containsObject:item.name]; }]];
        [items addObjectsFromArray:@[[NSURLQueryItem queryItemWithName:@"t" value:@"all"], [NSURLQueryItem queryItemWithName:@"q" value:query]]];
        components.queryItems = items;
        url = components.URL;
    }
    if (retryCount == 0 && push && _page) [_history addObject:@{ @"page":_page, @"entries":_entries ?: @[], @"pageURL":_pageURL ?: @"",
        @"searchURL":_searchURL ?: @"", @"title":self.title ?: @"Deezer", @"albumDetail":_albumDetail ?: NSNull.null }];
    if (retryCount == 0 && !push) [_history removeAllObjects];
    [self setBusy:YES message:@"Загружаю каталог…"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:15];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request setValue:[self authorizationForInfo:info URL:url] forHTTPHeaderField:@"Authorization"];
    if ([_source isEqualToString:@"Deezer2"]) {
        [request setValue:[self deezer2UserAgent:info] forHTTPHeaderField:@"User-Agent"];
        [request setValue:@"en-US" forHTTPHeaderField:@"Accept-Language"];
    }
    __weak typeof(self) weakSelf = self;
    [[_catalogSession dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSHTTPURLResponse *http = (NSHTTPURLResponse *)response;
        id json = !error && http.statusCode >= 200 && http.statusCode < 300 && data.length < 4000000 ?
            [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            typeof(self) self = weakSelf;
            if (!self) return;
            if (![self.store.targetID isEqualToString:ACDeviceID([self selectedDevice])]) { [self setBusy:NO message:@"Выбранная зона изменилась. Повторите запрос."]; return; }
            [self updateDeezer2InfoFromResponse:http];
            // WiiM Home learns the public IP and server clock from response headers,
            // even on HTTP 403, then retries the same catalogue request with the
            // updated signature. Allow at most three total attempts here.
            if (http.statusCode == 403 && retryCount < 2) {
                [self loadURL:url.absoluteString query:nil push:NO retryCount:retryCount + 1];
                return;
            }
            if (![json isKindOfClass:NSDictionary.class]) {
                self->_playFlowOnLoad = NO;
                NSString *message = nil;
                if (http.statusCode == 401 || http.statusCode == 403) {
                    NSString *serverMessage = @"";
                    id errorBody = data.length ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
                    if ([errorBody isKindOfClass:NSDictionary.class]) {
                        id candidate = errorBody[@"message"] ?: errorBody[@"error_description"] ?: errorBody[@"error"] ?: errorBody[@"msg"];
                        if ([candidate isKindOfClass:NSString.class]) {
                            NSString *text = (NSString *)candidate;
                            serverMessage = [text substringToIndex:MIN(text.length, 100)];
                        }
                    }
                    NSString *sourceSummary = [NSString stringWithFormat:@"Источник %@. %@",
                        self->_source.length ? self->_source : @"не определён",
                        self->_catalogAuthorizationSummary ?: @"Сводка параметров авторизации отсутствует."];
                    message = [NSString stringWithFormat:@"Каталог Deezer отклонил запрос (HTTP %ld). %@%@",
                        (long)http.statusCode, sourceSummary,
                        serverMessage.length ? [NSString stringWithFormat:@"; ответ: %@", serverMessage] : @""];
                } else {
                    message = http.statusCode == 401 || http.statusCode == 403 ? @"Сессия Deezer отклонена. Войдите снова." : @"Каталог Deezer не ответил. Проверьте связь с колонкой и Интернетом.";
                }
                [self setBusy:NO message:message];
                if (http.statusCode == 401 || http.statusCode == 403) {
                    NSLog(@"[airControl Deezer catalog diagnostic] %@", message);
                    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Диагностика Deezer"
                        message:message preferredStyle:UIAlertControllerStyleAlert];
                    [alert addAction:[UIAlertAction actionWithTitle:@"Скопировать отчёт" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
                        UIPasteboard.generalPasteboard.string = message;
                    }]];
                    [alert addAction:[UIAlertAction actionWithTitle:@"Закрыть" style:UIAlertActionStyleCancel handler:nil]];
                    [self presentViewController:alert animated:YES completion:nil];
                }
                return;
            }
            self->_page = json;
            self->_pageURL = url.absoluteString;
            NSDictionary *content = [json[@"content"] isKindOfClass:NSDictionary.class] ? json[@"content"] : json;
            NSArray *entries = [content[@"entries"] isKindOfClass:NSArray.class] ? content[@"entries"] : ([json[@"entries"] isKindOfClass:NSArray.class] ? json[@"entries"] : @[]);
            self->_entries = [entries filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id value, NSDictionary *bindings) { return [value isKindOfClass:NSDictionary.class]; }]];
            if ([self isDeezer2HomePage]) self->_entries = [self homeEntriesFromEntries:self->_entries];
            NSDictionary *search = nil;
            for (NSDictionary *entry in self->_entries) if ([[entry[@"id"] description].lowercaseString containsString:@"search"]) { search = entry; break; }
            self->_searchURL = [search[@"url"] isKindOfClass:NSString.class] ? search[@"url"] : [self initialCatalogURLForInfo:self->_userInfo];
            NSString *title = [json[@"title"] isKindOfClass:NSString.class] ? json[@"title"] : nil;
            self.title = title.length ? title : @"Deezer";
            BOOL shouldStartFlow = self->_playFlowOnLoad;
            self->_playFlowOnLoad = NO;
            [self setBusy:NO message:self->_entries.count ? @"" : @"В этом разделе пока нет записей."];
            [self updatePagination:content[@"pagination"]];
            if (shouldStartFlow) {
                NSDictionary *firstTrack = nil;
                for (NSDictionary *candidate in self->_entries) if (ACDeezerIsPlayableTrack(candidate)) { firstTrack = candidate; break; }
                if (firstTrack) [self playEntry:firstTrack];
                else [self noticeDeezer:@"Flow загрузился, но не вернул доступных треков."];
            }
        });
    }] resume];
}
- (void)updatePagination:(NSDictionary *)pagination {
    NSString *next = [pagination[@"next"] isKindOfClass:NSString.class] ? pagination[@"next"] : nil;
    if (!next.length) { self.tableView.tableFooterView = nil; return; }
    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[]];
    stack.axis = UILayoutConstraintAxisHorizontal;
    stack.distribution = UIStackViewDistributionFillEqually;
    stack.frame = CGRectMake(0, 0, self.view.bounds.size.width, 54);
    if (next.length) [stack addArrangedSubview:[self pagingButton:@"Следующая страница" action:@selector(nextPage:)]];
    self.tableView.tableFooterView = stack;
}
- (UIView *)pagingButton:(NSString *)title action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.frame = CGRectMake(0, 0, self.view.bounds.size.width, 54);
    [button setTitle:title forState:UIControlStateNormal];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}
- (void)nextPage:(id)sender {
    NSDictionary *content = [_page[@"content"] isKindOfClass:NSDictionary.class] ? _page[@"content"] : _page;
    NSString *next = [content[@"pagination"] isKindOfClass:NSDictionary.class] ? content[@"pagination"][@"next"] : nil;
    if (next.length) [self loadURL:next query:nil push:YES];
}
- (void)backPage:(id)sender {
    NSDictionary *previous = _history.lastObject;
    if (!previous) return;
    [_history removeLastObject];
    _page = previous[@"page"];
    _entries = previous[@"entries"];
    _pageURL = previous[@"pageURL"];
    _searchURL = previous[@"searchURL"];
    _albumDetail = previous[@"albumDetail"] == NSNull.null ? nil : previous[@"albumDetail"];
    self.title = previous[@"title"];
    NSDictionary *content = [_page[@"content"] isKindOfClass:NSDictionary.class] ? _page[@"content"] : _page;
    [self setBusy:NO message:_entries.count ? @"" : @"В этом разделе пока нет записей."];
    [self updatePagination:content[@"pagination"]];
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    LPDevice *device = self.store.selected;
    __weak typeof(self) weakSelf = self;
    void (^refresh)(id, id, NSDictionary *) = ^(id observer, id object, NSDictionary *change) {
        dispatch_async(dispatch_get_main_queue(), ^{ [weakSelf.tableView reloadData]; });
    };
    [self.KVOController observe:device.mediaInfo keyPaths:@[@"title", @"artist"] options:NSKeyValueObservingOptionNew block:refresh];
    [self.KVOController observe:device.deviceInfo keyPath:@"playStatus" options:NSKeyValueObservingOptionNew block:refresh];
}
- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [self.KVOController unobserveAll];
}
- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
    NSString *query = [searchBar.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (query.length) [self loadURL:_searchURL ?: [self initialCatalogURLForInfo:_userInfo] query:query push:YES];
}
- (NSString *)queueForEntry:(NSDictionary *)entry tracks:(NSArray<NSDictionary *> *)tracks selected:(NSInteger)selected {
    NSString *title = [entry[@"title"] isKindOfClass:NSString.class] ? entry[@"title"] : @"Deezer";
    NSMutableString *xml = [NSMutableString stringWithFormat:@"<?xml version=\"1.0\" ?><PlayList><ListName>%@</ListName><ListInfo><Radio>0</Radio><SourceName>Deezer</SourceName><SearchUrl>%@</SearchUrl><TrackNumber>%lu</TrackNumber><Quality>0</Quality><Login_username>%@</Login_username><Login_password>%@</Login_password><UpdateTime>0</UpdateTime><LastPlayIndex>1</LastPlayIndex><SwitchPageMode>0</SwitchPageMode><CurrentPage>0</CurrentPage><TotalPages>0</TotalPages></ListInfo><Tracks>",
        ACDeezerXMLEscape(title), ACDeezerXMLEscape(_pageURL ?: _userInfo[@"list_url"]), (unsigned long)tracks.count,
        ACDeezerXMLEscape(_userInfo[@"user_name"] ?: @""), ACDeezerXMLEscape(_password ?: _userInfo[@"user_password"] ?: @"")];
    NSInteger index = 0;
    for (NSDictionary *track in tracks) {
        NSString *trackID = ACDeezerTrackID(track);
        if (!trackID.length) continue;
        index++;
        NSString *trackTitle = [track[@"title"] isKindOfClass:NSString.class] ? track[@"title"] : @"Deezer";
        id artistValue = track[@"artist"];
        NSString *artist = [artistValue isKindOfClass:NSDictionary.class] ? (artistValue[@"title"] ?: artistValue[@"name"] ?: @"") : ([artistValue isKindOfClass:NSString.class] ? artistValue : @"");
        id albumValue = track[@"album"];
        NSString *album = [albumValue isKindOfClass:NSDictionary.class] ? (albumValue[@"title"] ?: albumValue[@"name"] ?: @"") : ([albumValue isKindOfClass:NSString.class] ? albumValue : @"");
        NSString *art = ACDeezerArt(track) ?: @"";
        NSString *metadata = [NSString stringWithFormat:@"<DIDL-Lite xmlns:dc=\"http://purl.org/dc/elements/1.1/\" xmlns:upnp=\"urn:schemas-upnp-org:metadata-1-0/upnp/\" xmlns:song=\"www.linkplay.com/song/\" xmlns=\"urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/\"><upnp:class>object.item.audioItem.musicTrack</upnp:class><item><song:id>%@</song:id><dc:title>%@</dc:title><upnp:artist>%@</upnp:artist><upnp:album>%@</upnp:album><res protocolInfo=\"http-get:*:audio/mpeg:*\">wiimu_search://%@</res>%@</item></DIDL-Lite>",
            ACDeezerXMLEscape(trackID), ACDeezerXMLEscape(trackTitle), ACDeezerXMLEscape(artist), ACDeezerXMLEscape(album), ACDeezerXMLEscape(trackID), art.length ? [NSString stringWithFormat:@"<upnp:albumArtURI>%@</upnp:albumArtURI>", ACDeezerXMLEscape(art)] : @""];
        [xml appendFormat:@"<Track%ld><URL>wiimu_search://%@</URL><Source>Deezer</Source><Key></Key><Id>%@</Id><Metadata>%@</Metadata></Track%ld>", (long)index, ACDeezerXMLEscape(trackID), ACDeezerXMLEscape(trackID), ACDeezerXMLEscape(metadata), (long)index];
    }
    [xml appendString:@"</Tracks></PlayList>"];
    return xml;
}
- (LPPlayMusicList *)sdkQueueForEntry:(NSDictionary *)entry tracks:(NSArray<NSDictionary *> *)tracks selected:(NSInteger)selected {
    id rawAccountID = _userInfo[@"user_id"] ?: _userInfo[@"userId"];
    NSString *accountID = [rawAccountID isKindOfClass:NSString.class] ? rawAccountID : ([rawAccountID respondsToSelector:@selector(stringValue)] ? [rawAccountID stringValue] : nil);
    if (!accountID.length || !tracks.count) return nil;
    LPAccount *account = [LPAccount new];
    account.source = @"Deezer2";
    account.userId = accountID;
    account.token = accountID;
    account.userName = [NSString stringWithFormat:@"%@", _userInfo[@"user_name"] ?: @""];

    NSString *title = [NSString stringWithFormat:@"%@", _page[@"title"] ?: entry[@"title"] ?: @"Deezer"];
    NSString *pageID = [_page[@"id"] isKindOfClass:NSString.class] ? _page[@"id"] : _pageURL;
    NSString *pageURL = _pageURL;
    NSString *lowerURL = pageURL.lowercaseString;
    LPPlayHeader *header = [LPPlayHeader new];
    header.headTitle = title;
    header.headId = pageID ?: @"Deezer";
    header.mediaSource = @"Deezer2";
    header.mediaType = MEDIATYPE_NETLIST;
    header.searchUrl = pageURL;
    header.loopMode = LP_LOOPMODE_NOBACK;
    header.headType = [lowerURL containsString:@"playlist"] ? LP_HEADER_TYPE_PLAYLIST :
        ([lowerURL containsString:@"album"] ? LP_HEADER_TYPE_ALBUM : LP_HEADER_TYPE_COLLECTION);
    header.imageUrl = ACDeezerArt(entry);
    header.totalTracks = (int)tracks.count;

    NSMutableArray<LPPlayItem *> *items = [NSMutableArray arrayWithCapacity:tracks.count];
    for (NSDictionary *track in tracks) {
        NSString *rawURL = [track[@"url"] isKindOfClass:NSString.class] ? track[@"url"] : nil;
        NSString *baseURL = [self->_source isEqualToString:@"Deezer2"] ? _userInfo[@"baseUrl"] : _userInfo[@"list_url"];
        NSURL *url = [self validatedCatalogURL:rawURL base:baseURL];
        NSString *trackID = ACDeezerTrackID(track);
        if (!url || !trackID.length) continue;
        LPPlayItem *item = [LPPlayItem new];
        item.trackId = trackID;
        item.trackName = [track[@"title"] isKindOfClass:NSString.class] ? track[@"title"] : @"Deezer";
        item.trackUrl = url.absoluteString;
        item.trackImage = ACDeezerArt(track);
        id artistValue = track[@"artist"];
        item.trackArtist = [artistValue isKindOfClass:NSDictionary.class] ? (artistValue[@"title"] ?: artistValue[@"name"] ?: @"") : ([artistValue isKindOfClass:NSString.class] ? artistValue : @"");
        id albumValue = track[@"album"];
        item.albumName = [albumValue isKindOfClass:NSDictionary.class] ? (albumValue[@"title"] ?: albumValue[@"name"] ?: @"") : ([albumValue isKindOfClass:NSString.class] ? albumValue : @"");
        item.trackDuration = [track[@"duration"] respondsToSelector:@selector(intValue)] ? [track[@"duration"] intValue] : 0;
        [items addObject:item];
    }
    if (!items.count) return nil;
    LPPlayMusicList *list = [LPPlayMusicList new];
    list.account = account;
    list.header = header;
    list.list = items;
    list.index = (int)MIN(MAX(0, selected), (NSInteger)items.count - 1);
    return list;
}
- (void)playLegacyEntry:(NSDictionary *)entry tracks:(NSArray<NSDictionary *> *)tracks selected:(NSInteger)selected {
    NSString *title = [NSString stringWithFormat:@"%@", _page[@"title"] ?: entry[@"title"] ?: @"Deezer"];
    NSString *context = [self queueForEntry:@{@"title":title} tracks:tracks selected:selected];
    [self soapAction:@"CreateQueue" arguments:@{@"QueueContext":context} completion:^(NSDictionary *result, NSString *error) {
        if (error) { [self setBusy:NO message:error]; [self noticeDeezer:error]; return; }
        [self soapAction:@"PlayQueueWithIndex" arguments:@{@"QueueName":title, @"Index":[NSString stringWithFormat:@"%ld", (long)selected + 1]} completion:^(NSDictionary *playResult, NSString *playError) {
            [self setBusy:NO message:playError ?: @"Трек запущен через совместимый режим Deezer."];
            if (playError) [self noticeDeezer:playError];
        }];
    }];
}
- (void)playEntry:(NSDictionary *)entry {
    NSMutableArray *tracks = [NSMutableArray array];
    NSInteger selected = 0;
    NSString *selectedID = ACDeezerTrackID(entry);
    for (NSDictionary *item in _entries) {
        if (!ACDeezerIsPlayableTrack(item)) continue;
        if ([ACDeezerTrackID(item) isEqualToString:selectedID]) selected = tracks.count;
        [tracks addObject:item];
    }
    if (!tracks.count || !selectedID.length) { [self noticeDeezer:@"В записи каталога не найден ID трека."]; return; }
    ACDeezerRememberArtwork(ACDeviceID([self selectedDevice]), tracks);
    LPDevice *device = [self selectedDevice];
    LPPlayMusicList *list = [self sdkQueueForEntry:entry tracks:tracks selected:selected];
    NSDictionary *payload = list ? [[LPMDPKitManager shared] playMusicSingleSource:list] : nil;
    LPDevicePlayer *player = device ? [device getPlayer] : nil;
    if (!payload.count || !player) {
        [self setBusy:YES message:@"Запускаю Deezer совместимым режимом…"];
        [self playLegacyEntry:entry tracks:tracks selected:selected];
        return;
    }
    [self setBusy:YES message:@"Передаю очередь Deezer2 через Linkplay SDK…"];
    __block BOOL finished = NO;
    void (^fallback)(NSString *) = ^(NSString *reason) {
        if (finished) return;
        finished = YES;
        [self setBusy:YES message:@"Этот чип не принял Deezer2. Переключаюсь на совместимый режим…"];
        [self playLegacyEntry:entry tracks:tracks selected:selected];
    };
    [player playAudioWithMusicDictionary:payload completionHandler:^(BOOL success, NSString *response) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (finished) return;
            if (success) {
                finished = YES;
                [self setBusy:NO message:@"Очередь Deezer запущена через Deezer2."];
            } else fallback(response);
        });
    }];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 15 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        if (!finished) fallback(@"SDK не ответил вовремя");
    });
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return MAX(1, _entries.count + (_history.count ? 1 : 0));
}
- (BOOL)isAlbumDetailPage {
    if (!_albumDetail) return NO;
    NSString *type = [_page[@"type"] isKindOfClass:NSString.class] ? [_page[@"type"] lowercaseString] : @"";
    NSString *url = (_pageURL ?: @"").lowercaseString;
    return [type containsString:@"album"] || [url containsString:@"/album"] || [url containsString:@"/albums"];
}
- (UIView *)albumHeaderView {
    CGFloat width = self.tableView.bounds.size.width;
    CGFloat height = MIN(500, MAX(440, width + 150));
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, height)];
    header.backgroundColor = UIColor.blackColor;
    NSString *art = ACDeezerArt(_page) ?: ACDeezerArt(_albumDetail);
    UIImageView *backdrop = [[UIImageView alloc] initWithFrame:header.bounds];
    backdrop.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    backdrop.contentMode = UIViewContentModeScaleAspectFill; backdrop.clipsToBounds = YES; backdrop.alpha = .32;
    [backdrop sd_setImageWithURL:ACStreamURL(art) placeholderImage:nil options:SDWebImageRetryFailed];
    [header addSubview:backdrop];
    UIVisualEffectView *blur = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]];
    blur.frame = header.bounds; blur.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight; [header addSubview:blur];
    CGFloat coverSize = MIN(276, width - 48);
    UIImageView *cover = [[UIImageView alloc] initWithFrame:CGRectMake((width-coverSize)/2, 16, coverSize, coverSize)];
    cover.contentMode = UIViewContentModeScaleAspectFill; cover.clipsToBounds = YES; cover.layer.cornerRadius = 12;
    [cover sd_setImageWithURL:ACStreamURL(art) placeholderImage:[UIImage systemImageNamed:@"music.note"] options:SDWebImageRetryFailed | SDWebImageHighPriority];
    [header addSubview:cover];
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(20, coverSize + 24, width - 40, 38)];
    title.font = [UIFont boldSystemFontOfSize:28]; title.textColor = UIColor.whiteColor; title.numberOfLines = 1;
    title.text = [self.title isEqualToString:@"Deezer"] ? (_page[@"title"] ?: _albumDetail[@"title"] ?: @"Альбом") : self.title;
    [header addSubview:title];
    id artistValue = _page[@"artist"] ?: _albumDetail[@"artist"];
    NSString *artist = [artistValue isKindOfClass:NSDictionary.class] ? (artistValue[@"title"] ?: artistValue[@"name"]) : ([artistValue isKindOfClass:NSString.class] ? artistValue : nil);
    UILabel *subtitle = [[UILabel alloc] initWithFrame:CGRectMake(20, coverSize + 62, width - 110, 28)];
    subtitle.font = [UIFont systemFontOfSize:16]; subtitle.textColor = UIColor.lightGrayColor; subtitle.text = artist ?: @"Deezer"; [header addSubview:subtitle];
    UILabel *count = [[UILabel alloc] initWithFrame:CGRectMake(20, height - 46, width - 100, 24)];
    count.font = [UIFont systemFontOfSize:15]; count.textColor = UIColor.lightGrayColor;
    count.text = [NSString stringWithFormat:@"%lu треков", (unsigned long)_entries.count]; [header addSubview:count];
    UIButton *play = [UIButton buttonWithType:UIButtonTypeSystem];
    play.frame = CGRectMake(width - 76, height - 62, 54, 54); play.layer.cornerRadius = 27;
    play.backgroundColor = ACAccent(); play.tintColor = UIColor.blackColor;
    [play setImage:[UIImage systemImageNamed:@"play.fill"] forState:UIControlStateNormal];
    [play addAction:[UIAction actionWithHandler:^(__unused UIAction *action) {
        for (NSDictionary *track in self->_entries) if (ACDeezerIsPlayableTrack(track)) { [self playEntry:track]; return; }
        [self noticeDeezer:@"В альбоме пока нет доступных композиций."];
    }] forControlEvents:UIControlEventTouchUpInside]; [header addSubview:play];
    return header;
}
- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    return [self isAlbumDetailPage] ? [self albumHeaderView] : nil;
}
- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if (![self isAlbumDetailPage]) return 0.01;
    CGFloat width = tableView.bounds.size.width;
    return MIN(500, MAX(440, width + 150));
}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (_history.count && indexPath.row == 0) return 58;
    NSInteger entryIndex = indexPath.row - (_history.count ? 1 : 0);
    if (self.isDeezer2HomePage && entryIndex >= 0 && entryIndex < _entries.count && [self isFlowEntry:_entries[entryIndex]]) return 410;
    return self.isDeezer2HomePage ? 64 : 68;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (_history.count && indexPath.row == 0) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"LegacyDeezerBack"];
        if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"LegacyDeezerBack"];
        cell.textLabel.text = ACMenuText(@"Назад в библиотеку");
        cell.imageView.image = [UIImage systemImageNamed:@"arrow.uturn.backward"];
        [cell.imageView sd_cancelCurrentImageLoad];
        cell.accessoryType = UITableViewCellAccessoryNone;
        return cell;
    }
    NSInteger entryIndex = indexPath.row - (_history.count ? 1 : 0);
    if (entryIndex < 0 || entryIndex >= _entries.count) return ACCell(_message ?: @"Нет записей.", nil, @"music.note");
    NSDictionary *entry = _entries[entryIndex];
    if (self.isDeezer2HomePage && [self isFlowEntry:entry]) {
        ACDeezerFlowCell *cell = [tableView dequeueReusableCellWithIdentifier:@"DeezerFlowHero"];
        if (!cell) cell = [[ACDeezerFlowCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"DeezerFlowHero"];
        [cell configure];
        return cell;
    }
    if (self.isDeezer2HomePage) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"DeezerHomeCategory"];
        if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"DeezerHomeCategory"];
        cell.textLabel.text = ACMenuText([entry[@"title"] isKindOfClass:NSString.class] ? entry[@"title"] : @"Deezer");
        cell.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
        cell.textLabel.textColor = UIColor.labelColor;
        cell.imageView.image = nil;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        return cell;
    }
    ACRadioStationCell *cell = [tableView dequeueReusableCellWithIdentifier:@"LegacyDeezerEntry"];
    if (!cell) cell = [[ACRadioStationCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"LegacyDeezerEntry"];
    NSString *title = [entry[@"title"] isKindOfClass:NSString.class] ? entry[@"title"] : @"Без названия";
    id artistValue = entry[@"artist"], albumValue = entry[@"album"];
    NSString *artist = [artistValue isKindOfClass:NSDictionary.class] ? (artistValue[@"title"] ?: artistValue[@"name"]) : ([artistValue isKindOfClass:NSString.class] ? artistValue : nil);
    NSString *album = [albumValue isKindOfClass:NSDictionary.class] ? (albumValue[@"title"] ?: albumValue[@"name"]) : ([albumValue isKindOfClass:NSString.class] ? albumValue : nil);
    NSArray *details = [@[artist ?: @"", album ?: @""] filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSString *value, NSDictionary *bindings) { return value.length > 0; }]];
    LPDevice *device = self.store.selected;
    NSString *playingTitle = device.mediaInfo.title ?: @"";
    id artistValueNow = entry[@"artist"];
    NSString *entryArtist = [artistValueNow isKindOfClass:NSDictionary.class] ? (artistValueNow[@"title"] ?: artistValueNow[@"name"] ?: @"") : ([artistValueNow isKindOfClass:NSString.class] ? artistValueNow : @"");
    NSString *playingArtist = device.mediaInfo.artist ?: @"";
    BOOL playing = ACDeezerIsPlayableTrack(entry) && device.deviceInfo.playStatus == LP_PLAYER_STATE_PLAYING &&
        playingTitle.length && [playingTitle localizedCaseInsensitiveCompare:title] == NSOrderedSame &&
        (!playingArtist.length || !entryArtist.length || [playingArtist localizedCaseInsensitiveCompare:entryArtist] == NSOrderedSame);
    [cell configureWithStation:@{@"name":title, @"detail":[details componentsJoinedByString:@" · "], @"art":ACDeezerArt(entry) ?: @"", @"placeholder":@"music.note"} highlighted:playing];
    if (playing) cell.accessoryView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"waveform"]];
    cell.accessoryType = (ACDeezerIsPlayableTrack(entry) || entry[@"url"]) ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (_busy) return;
    if (_history.count && indexPath.row == 0) { [self backPage:nil]; return; }
    NSInteger entryIndex = indexPath.row - (_history.count ? 1 : 0);
    if (entryIndex < 0 || entryIndex >= _entries.count) return;
    NSDictionary *entry = _entries[entryIndex];
    if (self.isDeezer2HomePage && [self isFlowEntry:entry]) {
        NSString *flowURL = [entry[@"url"] isKindOfClass:NSString.class] ? entry[@"url"] : nil;
        if (flowURL.length) {
            _playFlowOnLoad = YES;
            [self loadURL:flowURL query:nil push:YES];
        }
        return;
    }
    if (ACDeezerIsPlayableTrack(entry)) { [self playEntry:entry]; return; }
    NSString *url = [entry[@"url"] isKindOfClass:NSString.class] ? entry[@"url"] : nil;
    if (url.length) {
        NSString *type = [entry[@"type"] isKindOfClass:NSString.class] ? [entry[@"type"] lowercaseString] : @"";
        NSDictionary *album = ([type containsString:@"album"] || [url.lowercaseString containsString:@"/album"]) ? entry : nil;
        [self loadURL:url query:nil push:YES];
        _albumDetail = album;
    }
}
- (void)dealloc { [_catalogSession invalidateAndCancel]; }
@end

static NSString *ACQobuzLocalIP(NSString *host) {
    struct in_addr remote;
    if (!host.length || inet_pton(AF_INET, host.UTF8String, &remote) != 1) return nil;
    uint32_t ip = ntohl(remote.s_addr);
    if ((ip >> 24) != 10 && (ip >> 20) != 0xAC1 && (ip >> 16) != 0xC0A8) return nil;
    struct ifaddrs *interfaces;
    if (getifaddrs(&interfaces) != 0) return nil;
    NSString *result = nil;
    for (struct ifaddrs *it = interfaces; it; it = it->ifa_next) {
        if (!it->ifa_addr || !it->ifa_netmask || it->ifa_addr->sa_family != AF_INET || strcmp(it->ifa_name, "en0")) continue;
        struct in_addr local = ((struct sockaddr_in *)it->ifa_addr)->sin_addr;
        uint32_t mask = ((struct sockaddr_in *)it->ifa_netmask)->sin_addr.s_addr;
        if (!mask || (local.s_addr & mask) != (remote.s_addr & mask) || local.s_addr == remote.s_addr) continue;
        char buffer[INET_ADDRSTRLEN];
        if (inet_ntop(AF_INET, &local, buffer, sizeof(buffer))) result = @(buffer);
        break;
    }
    freeifaddrs(interfaces);
    return result;
}

static NSString *ACQobuzText(id value) {
    return [value isKindOfClass:NSString.class] || [value isKindOfClass:NSNumber.class] ? [value description] : @"";
}

static NSDictionary *ACQobuzObject(id value) {
    return [value isKindOfClass:NSDictionary.class] ? value : nil;
}

static NSArray *ACQobuzItems(id value) {
    id items = ACQobuzObject(value)[@"items"];
    return [items isKindOfClass:NSArray.class] ? items : @[];
}

static NSDictionary *ACQobuzLegacyKey(void) {
    return @{(__bridge id)kSecClass:(__bridge id)kSecClassGenericPassword,
             (__bridge id)kSecAttrService:@"com.filmoscopelab.aircontrol.qobuz",
             (__bridge id)kSecAttrAccount:@"api-session"};
}

static NSDictionary *ACQobuzKeyForDevice(NSString *deviceID) {
    if (!deviceID.length) return nil;
    return @{(__bridge id)kSecClass:(__bridge id)kSecClassGenericPassword,
             (__bridge id)kSecAttrService:@"com.filmoscopelab.aircontrol.qobuz",
             (__bridge id)kSecAttrAccount:[@"device-session:" stringByAppendingString:deviceID]};
}

static NSDictionary *ACQobuzReadKey(NSDictionary *key) {
    if (!key) return nil;
    NSMutableDictionary *query = [key mutableCopy];
    query[(__bridge id)kSecReturnData] = @YES;
    CFTypeRef result = NULL;
    if (SecItemCopyMatching((__bridge CFDictionaryRef)query, &result) != errSecSuccess) return nil;
    NSData *data = CFBridgingRelease(result);
    return ACQobuzObject([NSJSONSerialization JSONObjectWithData:data options:0 error:nil]);
}

static NSDictionary *ACQobuzSession(NSString *deviceID) {
    NSDictionary *session = ACQobuzReadKey(ACQobuzKeyForDevice(deviceID));
    return session ?: ACQobuzReadKey(ACQobuzLegacyKey());
}

static BOOL ACQobuzStoreSession(NSDictionary *session, NSString *deviceID) {
    NSDictionary *key = ACQobuzKeyForDevice(deviceID);
    if (!key || !session) return NO;
    NSData *value = [NSJSONSerialization dataWithJSONObject:session options:0 error:nil];
    if (!value.length) return NO;
    NSDictionary *update = @{(__bridge id)kSecValueData:value};
    OSStatus status = SecItemUpdate((__bridge CFDictionaryRef)key, (__bridge CFDictionaryRef)update);
    if (status == errSecItemNotFound) {
        NSMutableDictionary *item = [key mutableCopy];
        [item addEntriesFromDictionary:update];
        item[(__bridge id)kSecAttrAccessible] = (__bridge id)kSecAttrAccessibleWhenUnlockedThisDeviceOnly;
        status = SecItemAdd((__bridge CFDictionaryRef)item, NULL);
    }
    return status == errSecSuccess;
}

static void ACQobuzDeviceAction(LPDevice *device, NSString *action, NSDictionary<NSString *, NSString *> *arguments,
                               void (^completion)(NSDictionary *, NSString *)) {
    if (!device || !action.length) { completion(nil, @"Сначала выберите Linkplay-устройство."); return; }
    NSMutableString *children = [NSMutableString string];
    NSArray<NSString *> *wireOrder = [action isEqualToString:@"UserLogin"]
        ? @[@"AccountSource", @"UserName", @"PassWord", @"Proxy", @"Version", @"CodeVerifier", @"SavePass", @"Code"]
        : ([action isEqualToString:@"GetUserInfo"] ? @[@"AccountSource", @"RefreshToken", @"Version"] : @[]);
    NSMutableOrderedSet<NSString *> *orderedNames = [NSMutableOrderedSet orderedSet];
    for (NSString *name in wireOrder) if (arguments[name] != nil) [orderedNames addObject:name];
    NSArray<NSString *> *remaining = [[arguments.allKeys filteredArrayUsingPredicate:
        [NSPredicate predicateWithBlock:^BOOL(NSString *name, NSDictionary *bindings) { return ![orderedNames containsObject:name]; }]] sortedArrayUsingSelector:@selector(compare:)];
    [orderedNames addObjectsFromArray:remaining];
    for (NSString *name in orderedNames) [children appendFormat:@"<%@>%@</%@>", name, ACDeezerXMLEscape(arguments[name]), name];
    ACDiscoverPlayQueueEndpoint(device, action, ^(NSInteger port, NSString *path, NSString *service, NSString *discoveryError) {
        if (!path.length) { completion(nil, discoveryError ?: @"Служба PlayQueue не найдена."); return; }
        NSString *body = [NSString stringWithFormat:@"<s:Envelope xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\"><s:Body><u:%@ xmlns:u=\"%@\">%@</u:%@></s:Body></s:Envelope>", action, service, children, action];
        NSString *soapAction = [NSString stringWithFormat:@"\"%@#%@\"", service, action];
        ACRequestWithTimeout(device.deviceStatus.IP, port, path, nil, nil, body, soapAction,
                             [action isEqualToString:@"UserLogin"] ? 35.0 : 10.0, ^(NSData *data) {
            DDXMLNode *root = ACXMLData(data);
            if (!root) { completion(nil, [NSString stringWithFormat:@"Устройство не ответило на %@.", action]); return; }
            DDXMLNode *fault = ACNodes(root, @".//*[local-name()='Fault']").firstObject;
            if (fault) {
                NSString *code = ACDIDL(fault, @"errorCode");
                NSString *description = ACDIDL(fault, @"errorDescription");
                NSArray<NSString *> *faultParts = [@[code ?: @"", description ?: @""] filteredArrayUsingPredicate:
                    [NSPredicate predicateWithBlock:^BOOL(NSString *value, NSDictionary *bindings) { return value.length > 0; }]];
                NSString *faultText = [faultParts componentsJoinedByString:@" — "];
                completion(nil, faultText.length ? [NSString stringWithFormat:@"UPnP %@", faultText] : @"Устройство отклонило команду Qobuz.");
                return;
            }
            DDXMLNode *response = ACNodes(root, [NSString stringWithFormat:@"./*[local-name()='Body']/*[local-name()='%@Response']", action]).firstObject;
            if (!response) { completion(nil, [NSString stringWithFormat:@"Неожиданный ответ %@.", action]); return; }
            NSMutableDictionary *values = [NSMutableDictionary dictionary];
            for (DDXMLNode *node in response.children) if (node.name.length) values[node.name] = node.stringValue ?: @"";
            completion(values, nil);
        });
    });
}

static NSURL *ACQobuzURL(NSString *path, NSDictionary *session, NSArray *parameters) {
    NSURLComponents *url = [NSURLComponents componentsWithString:@"https://www.qobuz.com"];
    url.path = [@"/api.json/0.2/" stringByAppendingString:path];
    url.queryItems = [parameters copy];
    if (![session[@"auth2"] boolValue]) {
        NSMutableArray *items = [url.queryItems mutableCopy] ?: [NSMutableArray array];
        [items addObject:[NSURLQueryItem queryItemWithName:@"app_id" value:session[@"apiAppId"] ?: @"713396910"]];
        [items addObject:[NSURLQueryItem queryItemWithName:@"user_auth_token" value:session[@"token"] ?: @""]];
        url.queryItems = items;
    }
    return url.URL;
}

static NSString *ACQobuzAPIError(NSData *data, NSInteger status, NSError *error) {
    if (error) return [NSString stringWithFormat:@"Сеть: %@", error.localizedDescription ?: @"ошибка соединения"];
    id parsed = data.length && data.length < 4000000 ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
    NSDictionary *root = ACQobuzObject(parsed);
    NSDictionary *apiError = ACQobuzObject(root[@"error"]);
    NSString *detail = ACQobuzText(apiError[@"description"] ?: apiError[@"message"] ?: root[@"message"]);
    if (detail.length > 180) detail = [[detail substringToIndex:180] stringByAppendingString:@"…"];
    return detail.length ? [NSString stringWithFormat:@"HTTP %ld — %@", (long)status, detail] : [NSString stringWithFormat:@"HTTP %ld", (long)status];
}

static NSString *ACQobuzDecryptDeviceToken(NSString *encoded, NSString *deviceID) {
    NSString *uuid = ACDeezer2ShortUUID(deviceID);
    NSData *cipher = [[NSData alloc] initWithBase64EncodedString:encoded ?: @"" options:0];
    NSData *key = uuid.length >= 16 ? [[uuid substringToIndex:16] dataUsingEncoding:NSUTF8StringEncoding] : nil;
    if (!cipher.length || cipher.length % kCCBlockSizeAES128 || key.length != kCCKeySizeAES128) return encoded;
    NSMutableData *plain = [NSMutableData dataWithLength:cipher.length];
    uint8_t iv[kCCBlockSizeAES128] = {0}; size_t length = 0;
    CCCryptorStatus status = CCCrypt(kCCDecrypt, kCCAlgorithmAES, 0, key.bytes, key.length, iv,
                                     cipher.bytes, cipher.length, plain.mutableBytes, plain.length, &length);
    if (status != kCCSuccess || length > plain.length) return encoded;
    plain.length = length;
    const uint8_t *bytes = plain.bytes; while (plain.length && bytes[plain.length - 1] == 0) plain.length--;
    return [[NSString alloc] initWithData:plain encoding:NSUTF8StringEncoding] ?: encoded;
}

// WiiM Home completes Qobuz OAuth on the selected speaker via its UPnP
// UserLogin action. Do not exchange the code with an unrelated app ID/private key.
static void ACQobuzCompleteDeviceLogin(LPDevice *device, NSString *code, BOOL oauth2, BOOL apiAuth2, NSString *appId,
                                       void (^completion)(NSDictionary *session, NSString *error)) {
    if (!code.length) { completion(nil, @"Qobuz не вернул код авторизации."); return; }
    NSString *wireCode = ACDeezer2Password(code, ACDeviceID(device));
    if (!wireCode.length) { completion(nil, @"Не удалось подготовить код Qobuz для выбранной колонки."); return; }
    NSMutableDictionary *arguments = [@{
        @"AccountSource":@"Qobuz", @"UserName":@"", @"PassWord":@"", @"Proxy":@"",
        @"SavePass":@"0", @"Code":wireCode
    } mutableCopy];
    // The OAuth web flow and the speaker's UserLogin payload version are
    // independent. A31 advertises Qobuz 1.2 (legacy ext_app_id/redirect_url)
    // while GetUserInfo reports API version 2.0; WiiM still sends Version=2.0
    // to UserLogin for that combination. Gate this field on the API version,
    // not on the Qobuz catalog/source version.
    if (apiAuth2) arguments[@"Version"] = @"2.0";
    ACQobuzDeviceAction(device, @"UserLogin", arguments, ^(NSDictionary *response, NSString *actionError) {
        if (!response) {
            // WiiM re-reads GetUserInfo after login and uses that response as
            // the authoritative account state. Include only non-secret status
            // fields in the UI so a 501 can be diagnosed without exposing tokens.
            ACQobuzDeviceAction(device, @"GetUserInfo", @{@"AccountSource":@"Qobuz"}, ^(NSDictionary *infoResponse, NSString *infoError) {
                id infoRaw = infoResponse[@"Result"];
                NSDictionary *info = [infoRaw isKindOfClass:NSString.class]
                    ? ACQobuzObject([NSJSONSerialization JSONObjectWithData:[infoRaw dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil])
                    : ACQobuzObject(infoRaw);
                NSMutableArray *details = [NSMutableArray array];
                for (NSString *key in @[@"msg", @"errorType", @"sourceVersion", @"version", @"tokenState"]) {
                    NSString *value = ACQobuzText(info[key]);
                    if (value.length) [details addObject:[NSString stringWithFormat:@"%@=%@", key, value]];
                }
                NSString *diagnostic = actionError ?: @"Колонка не завершила вход Qobuz.";
                if (details.count) diagnostic = [diagnostic stringByAppendingFormat:@"\nПосле отказа GetUserInfo: %@", [details componentsJoinedByString:@", "]];
                else if (infoError.length) diagnostic = [diagnostic stringByAppendingFormat:@"\nПовторный GetUserInfo: %@", infoError];
                completion(nil, diagnostic);
            });
            return;
        }
        id raw = response[@"Result"];
        NSDictionary *result = [raw isKindOfClass:NSString.class] ? ACQobuzObject([NSJSONSerialization JSONObjectWithData:[raw dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil]) : ACQobuzObject(raw);
        if (!result.count) result = response;
        NSDictionary *user = ACQobuzObject(result[@"user"] ?: result[@"userInfo"] ?: result[@"user_info"]);
        NSString *userToken = ACQobuzText(result[@"user_auth_token"] ?: result[@"userAuthToken"]);
        NSString *accessToken = ACQobuzText(result[@"accessToken"] ?: result[@"access_token"] ?: result[@"token"]);
        NSString *token = userToken.length ? userToken : ACQobuzDecryptDeviceToken(accessToken, ACDeviceID(device));
        if (!token.length) { completion(nil, ACQobuzText(result[@"message"] ?: result[@"error"]) ?: @"Колонка ответила, но не вернула токен Qobuz."); return; }
        NSMutableDictionary *session = [@{
            @"clientId":appId.length ? appId : @"155398957",
            @"apiAppId":@"713396910",
            @"token":token,
            @"auth2":result[@"version"] ? @(ACQobuzText(result[@"version"]).doubleValue >= 2.0) : @(apiAuth2),
            @"displayName":ACQobuzText(user[@"username"] ?: user[@"email"] ?: result[@"username"]),
            @"userID":ACQobuzText(user[@"id"] ?: result[@"userId"] ?: result[@"user_id"] ?: result[@"id"]),
            @"deviceID":ACDeviceID(device) ?: @""
        } mutableCopy];
        completion(session, nil);
    });
}

@interface ACQobuzSocket : NSObject
- (void)send:(NSData *)json to:(NSString *)host selected:(BOOL (^)(void))selected done:(void (^)(BOOL))done;
@end

@implementation ACQobuzSocket {
    nw_connection_t _connection;
    dispatch_source_t _heartbeat;
    NSString *_host;
    uint8_t _sequence;
}
- (void)stop {
    if (_heartbeat) { dispatch_source_cancel(_heartbeat); _heartbeat = nil; }
    if (_connection) {
        nw_connection_set_state_changed_handler(_connection, nil);
        nw_connection_cancel(_connection);
        _connection = nil;
    }
}
- (void)dealloc { [self stop]; }
- (void)read:(nw_connection_t)connection {
    __weak typeof(self) weakSelf = self;
    nw_connection_receive(connection, 1, 16384, ^(dispatch_data_t data, nw_content_context_t context, bool complete, nw_error_t error) {
        typeof(self) self = weakSelf;
        if (!self || self->_connection != connection) return;
        if (complete || error) [self stop];
        else [self read:connection];
    });
}
- (void)write:(NSData *)data high:(uint8_t)high low:(uint8_t)low done:(void (^)(BOOL))done {
    NSUInteger length = data.length - (high == 1 && data.length ? 1 : 0);
    const uint8_t header[] = {0xa3, 0xbf, ++_sequence, length & 255, (length >> 8) & 255, high, low};
    const uint8_t end = 0xfb;
    NSMutableData *packet = [NSMutableData dataWithBytes:header length:sizeof(header)];
    if (data) [packet appendData:data];
    [packet appendBytes:&end length:1];
    dispatch_data_t bytes = dispatch_data_create(packet.bytes, packet.length, dispatch_get_main_queue(), DISPATCH_DATA_DESTRUCTOR_DEFAULT);
    nw_connection_send(_connection, bytes, NW_CONNECTION_DEFAULT_MESSAGE_CONTEXT, true, ^(nw_error_t error) {
        if (done) done(!error);
    });
}
- (void)send:(NSData *)json to:(NSString *)host selected:(BOOL (^)(void))selected done:(void (^)(BOOL))done {
    if (!json.length || json.length > 65536 || !selected()) { done(NO); return; }
    if (_connection && [_host isEqualToString:host] && _heartbeat) {
        [self write:json high:1 low:0x40 done:done];
        return;
    }
    [self stop];
    _host = [host copy];
    nw_parameters_t parameters = nw_parameters_create_secure_tcp(NW_PARAMETERS_DISABLE_PROTOCOL, NW_PARAMETERS_DEFAULT_CONFIGURATION);
    nw_connection_t connection = nw_connection_create(nw_endpoint_create_host(host.UTF8String, "23040"), parameters);
    _connection = connection;
    __weak typeof(self) weakSelf = self;
    __block BOOL pending = YES;
    __block NSData *pendingJSON = json;
    __block void (^callback)(BOOL) = [done copy];
    void (^finish)(BOOL) = ^(BOOL sent) {
        if (!pending) return;
        pending = NO;
        pendingJSON = nil;
        void (^completion)(BOOL) = callback;
        callback = nil;
        completion(sent);
    };
    nw_connection_set_queue(connection, dispatch_get_main_queue());
    nw_connection_set_state_changed_handler(connection, ^(nw_connection_state_t state, nw_error_t error) {
        typeof(self) self = weakSelf;
        if (!self || self->_connection != connection) { finish(NO); return; }
        if (state == nw_connection_state_failed || state == nw_connection_state_cancelled) {
            [self stop]; finish(NO);
        } else if (state == nw_connection_state_ready && !self->_heartbeat) {
            if (!pending || !selected()) { [self stop]; finish(NO); return; }
            [self read:connection];
            [self write:nil high:0 low:0 done:nil];
            [self write:pendingJSON high:1 low:0x40 done:finish];
            self->_heartbeat = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
            dispatch_source_set_timer(self->_heartbeat, dispatch_time(DISPATCH_TIME_NOW, 3*NSEC_PER_SEC), 3*NSEC_PER_SEC, NSEC_PER_MSEC*100);
            dispatch_source_set_event_handler(self->_heartbeat, ^{
                typeof(self) self = weakSelf;
                if (!selected()) { [self stop]; return; }
                [self write:nil high:0 low:5 done:nil];
            });
            dispatch_resume(self->_heartbeat);
        }
    });
    nw_connection_start(connection);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 6*NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        typeof(self) self = weakSelf;
        if (pending && self && self->_connection == connection) [self stop];
        finish(NO);
    });
}
@end

@interface ACQobuzWebLogin : UIViewController <WKNavigationDelegate>
@property(nonatomic, copy) void (^onSession)(NSDictionary *session, BOOL (^active)(void), void (^done)(BOOL));
@property(nonatomic, strong) LPDevice *device;
@property(nonatomic) BOOL oauth2;
@property(nonatomic) BOOL apiAuth2;
@property(nonatomic, copy) NSString *appId;
@property(nonatomic, copy) NSString *redirectURL;
@end

@implementation ACQobuzWebLogin {
    WKWebView *_web;
    BOOL _checking, _finished;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = ACMenuText(@"Вход в Qobuz");
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
        target:self action:@selector(closeLogin)];
    WKWebViewConfiguration *config = [WKWebViewConfiguration new];
    // Match WiiM Home's embedded Qobuz sign-in: keep WebKit's first-party
    // consent/login cookies across the account form and the authorization page.
    config.websiteDataStore = WKWebsiteDataStore.defaultDataStore;
    config.defaultWebpagePreferences.allowsContentJavaScript = YES;
    _web = [[WKWebView alloc] initWithFrame:CGRectZero configuration:config];
    _web.navigationDelegate = self;
    self.view = _web;
    NSURLComponents *login = [NSURLComponents componentsWithString:self.oauth2 ? @"https://www.qobuz.com/signin/oauth2" : @"https://www.qobuz.com/signin/oauth"];
    NSString *redirect = self.redirectURL.length ? self.redirectURL : @"https://a000.linkplay.com/alexa.php";
    // WiiM decodes the URL advertised by GetUserInfo before placing it in the
    // Qobuz authorization request. URLComponents then safely encodes it once.
    redirect = redirect.stringByRemovingPercentEncoding ?: redirect;
    login.queryItems = self.oauth2 ? @[
        [NSURLQueryItem queryItemWithName:@"client_id" value:self.appId ?: @""],
        [NSURLQueryItem queryItemWithName:@"redirect_uri" value:redirect],
        [NSURLQueryItem queryItemWithName:@"response_type" value:@"code"]
    ] : @[
        [NSURLQueryItem queryItemWithName:@"ext_app_id" value:self.appId ?: @""],
        [NSURLQueryItem queryItemWithName:@"redirect_url" value:redirect]
    ];
    [_web loadRequest:[NSURLRequest requestWithURL:login.URL]];
}
- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    _finished = YES;
}
- (void)closeLogin {
    _finished = YES;
    [_web stopLoading];
    [self dismissViewControllerAnimated:YES completion:nil];
}
- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction
 decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    NSURL *url = navigationAction.request.URL;
    NSString *host = url.host.lowercaseString ?: @"";
    NSURL *callbackURL = [NSURL URLWithString:self.redirectURL.stringByRemovingPercentEncoding ?: self.redirectURL];
    BOOL isWebCallback = callbackURL.host.length && [host isEqualToString:callbackURL.host.lowercaseString] &&
        [url.scheme.lowercaseString isEqualToString:callbackURL.scheme.lowercaseString] &&
        ((!url.port && !callbackURL.port) || [url.port isEqual:callbackURL.port]) &&
        [url.path isEqualToString:callbackURL.path];
    BOOL isAppCallback = self.oauth2 && [url.scheme isEqualToString:@"com.linkplay.wiimhome"] &&
        [host isEqualToString:@"callback"];
    BOOL isCallback = isWebCallback || isAppCallback;
    if (isCallback) {
        NSURLComponents *components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
        NSString *code = nil, *fallbackCode = nil;
        NSString *oauthError = nil, *callbackService = nil;
        for (NSURLQueryItem *item in components.queryItems) {
            if ([item.name.lowercaseString isEqualToString:@"code_autorisation"]) code = item.value;
            else if ([item.name.lowercaseString isEqualToString:@"authorization_code"] ||
                     [item.name.lowercaseString isEqualToString:@"code"]) fallbackCode = item.value;
            if ([item.name.lowercaseString isEqualToString:@"error"] || [item.name.lowercaseString isEqualToString:@"error_description"]) oauthError = item.value;
            if ([item.name isEqualToString:@"service"]) callbackService = item.value;
        }
        if (isAppCallback) code = [callbackService isEqualToString:@"qobuz"] ? fallbackCode : nil;
        if (isWebCallback && self.oauth2 && !oauthError.length) {
            decisionHandler(WKNavigationActionPolicyAllow);
            return;
        }
        decisionHandler(WKNavigationActionPolicyCancel);
        if (_checking || _finished || !self.onSession) return;
        if (!code.length) {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Вход Qobuz не завершён"
                message:oauthError.length ? oauthError : @"Страница разрешения не вернула код авторизации. Войдите ещё раз и подтвердите доступ приложению." preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"Закрыть" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) { [self closeLogin]; }]];
            [self presentViewController:alert animated:YES completion:nil];
            return;
        }
        _checking = YES;
        __weak typeof(self) weakSelf = self;
        ACQobuzCompleteDeviceLogin(self.device, code, self.oauth2, self.apiAuth2, self.appId, ^(NSDictionary *session, NSString *error) {
            typeof(self) self = weakSelf;
            if (!self || self->_finished) return;
            if (!session) {
                self->_checking = NO;
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Вход Qobuz не завершён"
                    message:error ?: @"Колонка не вернула сессию Qobuz." preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:@"Продолжить вход" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) { [self->_web reload]; }]];
                [alert addAction:[UIAlertAction actionWithTitle:@"Закрыть" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) { [self closeLogin]; }]];
                [self presentViewController:alert animated:YES completion:nil];
                return;
            }
            self.onSession(session, ^BOOL { return !self->_finished; }, ^(BOOL success) {
                if (self->_finished) return;
                self->_checking = NO;
                if (success) [self closeLogin];
                else {
                    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Qobuz не подтвердил сессию"
                        message:@"Код входа получен, но API не принял токен. Повторите вход." preferredStyle:UIAlertControllerStyleAlert];
                    [alert addAction:[UIAlertAction actionWithTitle:@"Повторить" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) { [self->_web reload]; }]];
                    [alert addAction:[UIAlertAction actionWithTitle:@"Закрыть" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) { [self closeLogin]; }]];
                    [self presentViewController:alert animated:YES completion:nil];
                }
            });
        });
        return;
    }
    // Qobuz may hand off the sign-in form to its identity provider before
    // returning to the Linkplay callback. Keep all HTTPS steps inside WKWebView.
    BOOL allowed = [url.scheme.lowercaseString isEqualToString:@"https"];
    decisionHandler(allowed ? WKNavigationActionPolicyAllow : WKNavigationActionPolicyCancel);
}
@end

@interface ACQobuzCatalog : UITableViewController <UISearchBarDelegate>
@property(nonatomic, weak) ACStore *store;
- (void)setBusy:(BOOL)busy message:(NSString *)message;
@end

@implementation ACQobuzCatalog {
    NSArray<NSDictionary *> *_rows;
    NSString *_message, *_collectionID, *_rowKind, *_tracksURL;
    NSDictionary *_currentAlbum;
    NSArray<NSDictionary *> *_parentRows;
    NSString *_parentTitle, *_parentRowKind;
    BOOL _parentPlaylist;
    BOOL _playlist, _sending, _busy;
    BOOL _loginPrompted, _initialCatalogLoaded;
    NSUInteger _generation;
    ACQobuzSocket *_socket;
    UISearchBar *_searchBar;
    UISegmentedControl *_tabs;
    UIView *_catalogHeader;
    NSArray<NSMutableDictionary *> *_sections;
    BOOL _dashboard;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Qobuz";
    _socket = [ACQobuzSocket new];
    _searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, 320, 52)];
    _searchBar.placeholder = @"Альбом или исполнитель"; _searchBar.delegate = self;
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, MAX(320, self.tableView.bounds.size.width), 112)];
    header.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _tabs = [[UISegmentedControl alloc] initWithItems:@[@"Discover", @"Library"]];
    _tabs.selectedSegmentIndex = 1;
    _tabs.frame = CGRectMake(20, 4, header.bounds.size.width - 40, 44);
    _tabs.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [_tabs addTarget:self action:@selector(library) forControlEvents:UIControlEventValueChanged];
    [header addSubview:_tabs];
    _searchBar.frame = CGRectMake(0, 54, header.bounds.size.width, 52);
    _searchBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [header addSubview:_searchBar];
    _catalogHeader = header;
    self.tableView.tableHeaderView = _catalogHeader;
    self.tableView.backgroundColor = UIColor.blackColor;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:ACQobuzSession(ACDeviceID(self.store.selected)) ? @"Аккаунт" : @"Войти"
        style:UIBarButtonItemStylePlain target:self action:@selector(sessionMenu)];
    _message = ACQobuzSession(ACDeviceID(self.store.selected)) ? @"Загружаю библиотеку Qobuz…" : @"Войдите в Qobuz на выбранной колонке, чтобы открыть каталог и библиотеку.";
}
- (void)setBusy:(BOOL)busy message:(NSString *)message {
    _busy = busy;
    if (message) _message = message;
    self.navigationItem.rightBarButtonItem.enabled = !busy;
    [self.tableView reloadData];
}
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (_initialCatalogLoaded) return;
    if (ACQobuzSession(ACDeviceID(self.store.selected))) {
        _initialCatalogLoaded = YES;
        [self library];
    } else if (!_loginPrompted) {
        _loginPrompted = YES;
        dispatch_async(dispatch_get_main_queue(), ^{ if (self.view.window && !self.presentedViewController) [self beginLogin]; });
    }
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    LPDevice *device = self.store.selected;
    __weak typeof(self) weakSelf = self;
    void (^refreshPlayingTrack)(id, id, NSDictionary *) = ^(id observer, id object, NSDictionary *change) {
        dispatch_async(dispatch_get_main_queue(), ^{ [weakSelf.tableView reloadData]; });
    };
    [self.KVOController observe:device.mediaInfo keyPaths:@[@"title", @"artist"] options:NSKeyValueObservingOptionNew block:refreshPlayingTrack];
    [self.KVOController observe:device.deviceInfo keyPath:@"playStatus" options:NSKeyValueObservingOptionNew block:refreshPlayingTrack];
}
- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [self.KVOController unobserveAll];
}
- (void)notice:(NSString *)message {
    if (!self.view.window || self.presentedViewController) return;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Qobuz" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}
- (void)sessionMenu {
    if (!ACQobuzSession(ACDeviceID(self.store.selected))) { [self beginLogin]; return; }
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Аккаунт Qobuz"
        message:@"Сессия хранится в защищённом хранилище этого iPhone." preferredStyle:UIAlertControllerStyleActionSheet];
    [alert addAction:[UIAlertAction actionWithTitle:@"Обновить библиотеку" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) { [self library]; }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Войти в другой аккаунт" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        SecItemDelete((__bridge CFDictionaryRef)ACQobuzKeyForDevice(ACDeviceID(self.store.selected)));
        SecItemDelete((__bridge CFDictionaryRef)ACQobuzLegacyKey());
        self.navigationItem.rightBarButtonItem.title = @"Войти";
        self->_rows = @[]; self->_message = @"Войдите в другой аккаунт Qobuz."; [self.tableView reloadData];
        [self beginLogin];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Выйти из аккаунта" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        SecItemDelete((__bridge CFDictionaryRef)ACQobuzKeyForDevice(ACDeviceID(self.store.selected)));
        SecItemDelete((__bridge CFDictionaryRef)ACQobuzLegacyKey());
        self->_generation++; self->_rows = @[]; self->_collectionID = nil; self->_message = @"Вы вышли из Qobuz.";
        self.navigationItem.rightBarButtonItem.title = @"Войти";
        [self.tableView reloadData];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Отмена" style:UIAlertActionStyleCancel handler:nil]];
    alert.popoverPresentationController.barButtonItem = self.navigationItem.rightBarButtonItem;
    [self presentViewController:alert animated:YES completion:nil];
}
- (void)beginLogin {
    LPDevice *device = self.store.selected;
    if (!device || !ACDeviceID(device).length) {
        [self notice:@"Сначала выберите Linkplay-устройство на вкладке «Устройства»."];
        return;
    }
    NSString *deviceID = [ACDeviceID(device) copy];
    [self setBusy:YES message:@"Читаю параметры Qobuz с выбранной колонки…"];
    ACDiscoverStreamServices(device, ^(NSArray<NSDictionary *> *services) {
        if (![ACDeviceID(self.store.selected) isEqualToString:deviceID]) { [self setBusy:NO message:@"Выбор устройства изменился. Повторите вход для нужной колонки."]; return; }
        NSDictionary *qobuz = nil;
        for (NSDictionary *item in services) {
            NSString *identifier = [item[@"id"] isKindOfClass:NSString.class] ? item[@"id"] : @"";
            if ([identifier caseInsensitiveCompare:@"Qobuz"] == NSOrderedSame) { qobuz = item; break; }
        }
        [self setBusy:YES message:@"Получаю OAuth-профиль Qobuz с колонки…"];
        ACQobuzDeviceAction(device, @"GetUserInfo", @{@"AccountSource":@"Qobuz"}, ^(NSDictionary *response, NSString *actionError) {
            if (![ACDeviceID(self.store.selected) isEqualToString:deviceID]) { [self setBusy:NO message:@"Выбор устройства изменился. Повторите вход для нужной колонки."]; return; }
            id raw = response[@"Result"];
            NSDictionary *profile = [raw isKindOfClass:NSString.class]
                ? ACQobuzObject([NSJSONSerialization JSONObjectWithData:[raw dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil])
                : ACQobuzObject(raw);
            if (!profile.count) {
                [self setBusy:NO message:actionError ?: @"Колонка не вернула профиль Qobuz."];
                [self notice:actionError ?: @"GetUserInfo Qobuz не вернул параметры авторизации. Проверьте, что выбранная колонка онлайн."];
                return;
            }
            NSString *(^stringField)(NSDictionary *, NSArray<NSString *> *) = ^NSString *(NSDictionary *object, NSArray<NSString *> *names) {
                for (NSString *name in names) {
                    id value = object[name];
                    if ([value isKindOfClass:NSString.class] && [value length]) return value;
                    if ([value respondsToSelector:@selector(stringValue)] && [value stringValue].length) return [value stringValue];
                }
                return @"";
            };
            NSString *appId = stringField(profile, @[@"clientId", @"client_id"]);
            NSString *redirect = stringField(profile, @[@"redirectUrl", @"redirect_url"]);
            NSString *sourceVersion = stringField(profile, @[@"sourceVersion", @"source_version"]);
            NSString *apiVersion = stringField(profile, @[@"version"]);
            if (!sourceVersion.length) sourceVersion = stringField(qobuz, @[@"sourceVersion", @"source_version", @"version"]);
            if (!sourceVersion.length) {
                NSString *diagnostic = [NSString stringWithFormat:@"Колонка %@ не сообщила версию источника Qobuz. Не выбираю OAuth-страницу наугад.", ACName(device)];
                [self setBusy:NO message:diagnostic]; [self notice:diagnostic]; return;
            }
            // Match WiiM Home's QobuzUserInfo fallbacks for legacy devices
            // whose GetUserInfo response omits the OAuth identifiers.
            if (!appId.length) appId = @"155398957";
            if (!redirect.length) redirect = @"https://a000.linkplay.com/alexa.php";
            BOOL oauth2 = sourceVersion.doubleValue >= 1.8;
            BOOL apiAuth2 = apiVersion.doubleValue >= 2.0;
            [self setBusy:NO message:[NSString stringWithFormat:@"Профиль %@ получен. Продолжите вход в Qobuz.", ACName(device)]];
            ACQobuzWebLogin *login = [ACQobuzWebLogin new];
            login.device = device;
            login.oauth2 = oauth2;
            login.apiAuth2 = apiAuth2;
            login.appId = appId;
            login.redirectURL = redirect;
            __weak typeof(self) weakSelf = self;
            login.onSession = ^(NSDictionary *session, BOOL (^active)(void), void (^done)(BOOL)) {
                typeof(self) self = weakSelf;
                if (!self || !active() || ![ACDeviceID(self.store.selected) isEqualToString:deviceID]) { done(NO); return; }
                NSMutableDictionary *profiledSession = [session mutableCopy];
                [self validateWebSession:profiledSession active:^BOOL {
                    typeof(self) self = weakSelf;
                    return self && active() && [ACDeviceID(self.store.selected) isEqualToString:deviceID];
                } done:done];
            };
            UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:login];
            navigation.modalPresentationStyle = UIModalPresentationFullScreen;
            [self presentViewController:navigation animated:YES completion:nil];
        });
    });
}
- (void)validateWebSession:(NSDictionary *)session active:(BOOL (^)(void))active done:(void (^)(BOOL))done {
    [self request:@"user/lastUpdate" session:session query:@[] done:^(NSDictionary *data, NSString *error) {
        if (!active()) return;
        if (!ACQobuzObject(data[@"last_update"])) { done(NO); return; }
        NSString *deviceID = ACDeviceID(self.store.selected);
        NSMutableDictionary *deviceSession = [session mutableCopy];
        deviceSession[@"deviceID"] = deviceID ?: @"";
        if (ACQobuzStoreSession(deviceSession, deviceID)) {
            self->_initialCatalogLoaded = YES;
            self->_message = @"Qobuz подключён. Загружаю ваши плейлисты…";
            self.navigationItem.rightBarButtonItem.title = @"Аккаунт";
            [self.tableView reloadData];
        }
        BOOL saved = ACQobuzSession(deviceID) != nil;
        done(saved);
        if (saved) dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 350 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
            self->_initialCatalogLoaded = YES;
            [self library];
        });
    }];
}
- (void)request:(NSString *)path session:(NSDictionary *)session query:(NSArray *)query done:(void (^)(NSDictionary *, NSString *))done {
    NSURL *url = ACQobuzURL(path, session, query);
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:15];
    if ([session[@"auth2"] boolValue]) {
        [request setValue:[@"Bearer " stringByAppendingString:ACQobuzText(session[@"token"]) ?: @""] forHTTPHeaderField:@"Authorization"];
    } else {
        [request setValue:ACQobuzText(session[@"clientId"]) ?: @"155398957" forHTTPHeaderField:@"X-App-Id"];
        [request setValue:ACQobuzText(session[@"token"]) forHTTPHeaderField:@"X-User-Auth-Token"];
    }
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    static NSURLSession *client;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        client = [NSURLSession sessionWithConfiguration:NSURLSessionConfiguration.ephemeralSessionConfiguration
            delegate:[ACLocalHTTPDelegate new] delegateQueue:nil];
    });
    [[client dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSInteger status = [(NSHTTPURLResponse *)response statusCode];
        id parsed = !error && status >= 200 && status < 300 && data.length && data.length < 4000000 ?
            [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
        NSDictionary *object = ACQobuzObject(parsed);
        NSString *failure = (!object || object[@"error"]) ? ACQobuzAPIError(data, status, error) : nil;
        dispatch_async(dispatch_get_main_queue(), ^{ done(object, failure); });
    }] resume];
}
- (void)load:(NSString *)path query:(NSArray *)query key:(NSString *)key {
    _dashboard = NO;
    NSDictionary *session = ACQobuzSession(ACDeviceID(self.store.selected));
    if (!session) { [self notice:@"Подключите API-сессию Qobuz."]; return; }
    _tracksURL = ACQobuzURL(path, session, query).absoluteString;
    NSUInteger request = ++_generation;
    _rows = @[]; _message = @"Загрузка…"; [self.tableView reloadData];
    [self request:path session:session query:query done:^(NSDictionary *data, NSString *error) {
        if (request != self->_generation) return;
        NSMutableArray *rows = [NSMutableArray array];
        for (id item in [self itemsInResponse:data kind:key]) {
            NSDictionary *row = ACQobuzObject(item);
            if (row && (ACQobuzText(row[@"id"]).length || ACQobuzText(row[@"slug"]).length)) [rows addObject:row];
        }
        self->_rows = rows;
        self->_message = data ? @"Нет результатов." : [NSString stringWithFormat:@"Каталог Qobuz: %@", error ?: @"пустой ответ"];
        [self.tableView reloadData];
    }];
}
- (void)searchBarSearchButtonClicked:(UISearchBar *)bar {
    [bar resignFirstResponder];
    if (!bar.text.length) return;
    _currentAlbum = nil; _collectionID = nil; _playlist = NO; _rowKind = @"albums";
    self.tableView.tableHeaderView = _catalogHeader;
    [self load:@"catalog/search" query:@[[NSURLQueryItem queryItemWithName:@"query" value:bar.text],
        [NSURLQueryItem queryItemWithName:@"limit" value:@"30"]] key:@"albums"];
}
- (NSDictionary *)section:(NSString *)title path:(NSString *)path kind:(NSString *)kind type:(NSString *)type {
    return @{@"title":title, @"path":path, @"kind":kind, @"type":type};
}
- (NSArray *)queryForSection:(NSDictionary *)section limit:(NSString *)limit {
    NSMutableArray *query = [NSMutableArray arrayWithObjects:
        [NSURLQueryItem queryItemWithName:@"offset" value:@"0"],
        [NSURLQueryItem queryItemWithName:@"limit" value:limit], nil];
    if ([section[@"type"] length]) [query addObject:[NSURLQueryItem queryItemWithName:@"type" value:section[@"type"]]];
    return query;
}
- (NSArray *)itemsInResponse:(NSDictionary *)data kind:(NSString *)kind {
    id container = data[kind];
    NSArray *items = [container isKindOfClass:NSArray.class] ? container : ACQobuzItems(container);
    if (!items.count) items = ACQobuzItems(data);
    return items ?: @[];
}
- (void)library {
    if (!ACQobuzSession(ACDeviceID(self.store.selected))) { [self beginLogin]; return; }
    NSUInteger generation = ++_generation;
    _dashboard = YES; _collectionID = nil; _currentAlbum = nil; self.tableView.tableHeaderView = _catalogHeader; self.title = @"Qobuz";
    NSArray *specs = _tabs.selectedSegmentIndex == 0 ? @[
        [self section:@"New Releases" path:@"album/getFeatured" kind:@"albums" type:@"new-releases"],
        [self section:@"Recommended for You · My Weekly Q" path:@"dynamic-tracks/get" kind:@"tracks" type:@"weekly"],
        [self section:@"Qobuz Playlists" path:@"playlist/getFeatured" kind:@"playlists" type:@"editor-picks"],
        [self section:@"Playlists by Category" path:@"playlist/getTags" kind:@"tags" type:@""],
        [self section:@"Qobuz Essential Discography" path:@"album/getFeatured" kind:@"albums" type:@"ideal-discography"],
        [self section:@"Top Albums" path:@"album/getFeatured" kind:@"albums" type:@"most-streamed"],
        [self section:@"Press Accolades" path:@"album/getFeatured" kind:@"albums" type:@"press-awards"]
    ] : @[
        [self section:@"My Playlists" path:@"playlist/getUserPlaylists" kind:@"playlists" type:@""],
        [self section:@"Favourite Artists" path:@"favorite/getUserFavorites" kind:@"artists" type:@"artists"],
        [self section:@"Favourite Albums" path:@"favorite/getUserFavorites" kind:@"albums" type:@"albums"],
        [self section:@"Favourite Tracks" path:@"favorite/getUserFavorites" kind:@"tracks" type:@"tracks"],
        [self section:@"Purchased Albums" path:@"purchase/getUserPurchases" kind:@"albums" type:@"albums"],
        [self section:@"Purchased Tracks" path:@"purchase/getUserPurchases" kind:@"tracks" type:@"tracks"]
    ];
    NSMutableArray *sections = [NSMutableArray array];
    for (NSDictionary *spec in specs) {
        NSMutableDictionary *section = [spec mutableCopy];
        section[@"items"] = @[]; section[@"message"] = @"Загрузка…";
        [sections addObject:section];
    }
    _sections = sections;
    [self.tableView reloadData];
    for (NSMutableDictionary *section in _sections) {
        [self request:section[@"path"] session:ACQobuzSession(ACDeviceID(self.store.selected))
            query:[self queryForSection:section limit:@"12"] done:^(NSDictionary *data, NSString *error) {
            if (generation != self->_generation) return;
            section[@"items"] = [self itemsInResponse:data kind:section[@"kind"]];
            section[@"message"] = error ?: @"В этом разделе пока ничего нет.";
            [self.tableView reloadData];
        }];
    }
}
- (void)openSection:(NSDictionary *)section {
    _dashboard = NO; _collectionID = nil; _currentAlbum = nil; self.tableView.tableHeaderView = _catalogHeader;
    _rowKind = section[@"kind"]; _playlist = [_rowKind isEqualToString:@"playlists"];
    self.title = section[@"title"];
    [self load:section[@"path"] query:[self queryForSection:section limit:@"100"] key:section[@"kind"]];
}
- (void)openDashboardItem:(NSDictionary *)item section:(NSDictionary *)section {
    if ([section[@"kind"] isEqualToString:@"tags"]) {
        _dashboard = NO; _rowKind = @"playlists"; _playlist = YES; _collectionID = nil;
        [self load:@"playlist/getFeatured" query:@[
            [NSURLQueryItem queryItemWithName:@"type" value:@"last-created"],
            [NSURLQueryItem queryItemWithName:@"tags" value:ACQobuzText(item[@"slug"])],
            [NSURLQueryItem queryItemWithName:@"limit" value:@"100"]] key:@"playlists"];
        return;
    }
    _dashboard = NO; ++_generation; _collectionID = nil;
    _rowKind = section[@"kind"]; _playlist = [_rowKind isEqualToString:@"playlists"];
    _rows = section[@"items"];
    _tracksURL = ACQobuzURL(section[@"path"], ACQobuzSession(ACDeviceID(self.store.selected)), [self queryForSection:section limit:@"100"]).absoluteString;
    NSUInteger index = [_rows indexOfObject:item];
    if (index != NSNotFound) [self tableView:self.tableView didSelectRowAtIndexPath:[NSIndexPath indexPathForRow:index inSection:0]];
}
- (NSString *)artwork:(NSDictionary *)item {
    NSDictionary *image = ACQobuzObject(item[@"image"]) ?: ACQobuzObject(ACQobuzObject(item[@"album"])[@"image"]);
    NSString *url = ACQobuzText(image[@"large"] ?: image[@"medium"] ?: image[@"small"]);
    id images = item[@"images300"] ?: item[@"images150"];
    if (!url.length && [images isKindOfClass:NSArray.class]) url = ACQobuzText([images firstObject]);
    return url;
}
- (NSString *)subtitle:(NSDictionary *)item {
    return ACQobuzText(ACQobuzObject(item[@"artist"])[@"name"] ?: ACQobuzObject(item[@"performer"])[@"name"] ?: ACQobuzObject(item[@"owner"])[@"name"]);
}
- (UITableViewCell *)mediaCell:(NSDictionary *)item {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    cell.backgroundColor = UIColor.blackColor;
    UIImageView *image = [[UIImageView alloc] initWithFrame:CGRectMake(18, 9, 64, 64)];
    image.contentMode = UIViewContentModeScaleAspectFill; image.clipsToBounds = YES; image.layer.cornerRadius = 7;
    [image sd_setImageWithURL:[NSURL URLWithString:[self artwork:item]] placeholderImage:[UIImage systemImageNamed:@"music.note"]];
    [cell.contentView addSubview:image];
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(96, 12, MAX(100, self.tableView.bounds.size.width - 120), 34)];
    title.autoresizingMask = UIViewAutoresizingFlexibleWidth; title.numberOfLines = 2;
    title.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium]; title.textColor = UIColor.whiteColor;
    title.text = ACQobuzText(item[@"title"] ?: item[@"name"]); [cell.contentView addSubview:title];
    UILabel *artist = [[UILabel alloc] initWithFrame:CGRectMake(96, 49, title.bounds.size.width, 22)];
    artist.autoresizingMask = UIViewAutoresizingFlexibleWidth; artist.font = [UIFont systemFontOfSize:14];
    artist.textColor = UIColor.lightGrayColor; artist.text = [self subtitle:item];
    [cell.contentView addSubview:artist];
    LPDevice *device = self.store.selected;
    BOOL isPlaying = device.deviceInfo.playStatus == LP_PLAYER_STATE_PLAYING &&
        [ACQobuzText(device.mediaInfo.title) localizedCaseInsensitiveCompare:title.text ?: @""] == NSOrderedSame &&
        (!artist.text.length || !ACQobuzText(device.mediaInfo.artist).length ||
         [ACQobuzText(device.mediaInfo.artist) localizedCaseInsensitiveCompare:artist.text] == NSOrderedSame);
    if (isPlaying) {
        title.textColor = ACAccent();
        UIImageView *playing = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"waveform"]];
        playing.tintColor = ACAccent();
        cell.accessoryView = playing;
    }
    return cell;
}
- (UIView *)albumDetailHeader:(UITableView *)tableView {
    CGFloat width = tableView.bounds.size.width;
    CGFloat height = 470;
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, height)];
    header.backgroundColor = UIColor.blackColor;
    UIImageView *backdrop = [[UIImageView alloc] initWithFrame:header.bounds];
    backdrop.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    backdrop.contentMode = UIViewContentModeScaleAspectFill; backdrop.clipsToBounds = YES; backdrop.alpha = .35;
    [backdrop sd_setImageWithURL:[NSURL URLWithString:[self artwork:_currentAlbum]] placeholderImage:nil options:SDWebImageRetryFailed];
    [header addSubview:backdrop];
    UIVisualEffectView *blur = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]];
    blur.frame = header.bounds; blur.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight; [header addSubview:blur];
    UIImageView *cover = [[UIImageView alloc] initWithFrame:CGRectMake((width - 276) / 2, 18, 276, 276)];
    cover.contentMode = UIViewContentModeScaleAspectFill; cover.clipsToBounds = YES; cover.layer.cornerRadius = 12;
    [cover sd_setImageWithURL:[NSURL URLWithString:[self artwork:_currentAlbum]] placeholderImage:[UIImage systemImageNamed:@"music.note"] options:SDWebImageRetryFailed | SDWebImageHighPriority];
    [header addSubview:cover];
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(20, 306, width - 40, 38)];
    title.font = [UIFont boldSystemFontOfSize:28]; title.textColor = UIColor.whiteColor;
    title.text = ACQobuzText(_currentAlbum[@"title"] ?: _currentAlbum[@"name"]); [header addSubview:title];
    UILabel *artist = [[UILabel alloc] initWithFrame:CGRectMake(20, 344, width - 40, 26)];
    artist.font = [UIFont systemFontOfSize:17]; artist.textColor = UIColor.whiteColor; artist.text = [self subtitle:_currentAlbum]; [header addSubview:artist];
    UIButton *play = [UIButton buttonWithType:UIButtonTypeSystem];
    play.frame = CGRectMake(width - 76, 386, 54, 54); play.layer.cornerRadius = 27;
    play.backgroundColor = ACAccent(); play.tintColor = UIColor.blackColor;
    [play setImage:[UIImage systemImageNamed:@"play.fill"] forState:UIControlStateNormal];
    [play addTarget:self action:@selector(playAlbum) forControlEvents:UIControlEventTouchUpInside]; [header addSubview:play];
    UILabel *count = [[UILabel alloc] initWithFrame:CGRectMake(20, 400, width - 112, 24)];
    count.font = [UIFont systemFontOfSize:15]; count.textColor = ACSecondaryText();
    count.text = [NSString stringWithFormat:@"%lu песен", (unsigned long)_rows.count]; [header addSubview:count];
    return header;
}
- (void)playAlbum {
    if (_rows.count) [self playTrack:_rows.firstObject];
    else [self notice:@"Список песен альбома ещё загружается."];
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return _dashboard ? _sections.count : 1; }
- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)index {
    if (!_dashboard) return _currentAlbum && _collectionID ? [self albumDetailHeader:tableView] : nil;
    NSDictionary *section = _sections[index];
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tableView.bounds.size.width, 64)];
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(20, 12, header.bounds.size.width - 125, 44)];
    title.font = [UIFont boldSystemFontOfSize:23]; title.textColor = UIColor.whiteColor;
    title.text = ACMenuText(section[@"title"]); title.adjustsFontSizeToFitWidth = YES;
    title.autoresizingMask = UIViewAutoresizingFlexibleWidth; [header addSubview:title];
    UIButton *all = [UIButton buttonWithType:UIButtonTypeSystem];
    all.frame = CGRectMake(header.bounds.size.width - 100, 18, 88, 32);
    all.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [all setTitle:ACMenuText(@"See All  ›") forState:UIControlStateNormal];
    [all addAction:[UIAction actionWithHandler:^(UIAction *action) { [self openSection:section]; }] forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:all]; return header;
}
- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section { return _dashboard ? 64 : (_currentAlbum && _collectionID ? 470 : 0.01); }
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)index {
    if (!_dashboard) return 82;
    NSDictionary *section = _sections[index.section];
    if (![section[@"items"] count]) return 80;
    if ([section[@"kind"] isEqualToString:@"tracks"]) return 82;
    return [section[@"type"] isEqualToString:@"new-releases"] ? 516 : 258;
}
- (void)favoriteSection:(NSString *)kind title:(NSString *)title {
    self.title = title;
    _currentAlbum = nil; _collectionID = nil; _playlist = NO; _rowKind = kind; self.tableView.tableHeaderView = _catalogHeader;
    [self load:@"favorite/getUserFavorites" query:@[
        [NSURLQueryItem queryItemWithName:@"type" value:kind],
        [NSURLQueryItem queryItemWithName:@"limit" value:@"100"]] key:kind];
}
- (void)playlists {
    self.title = ACMenuText(@"Плейлисты");
    _currentAlbum = nil; _collectionID = nil; _playlist = YES; _rowKind = @"playlists"; self.tableView.tableHeaderView = _catalogHeader;
    [self load:@"playlist/getUserPlaylists" query:@[[NSURLQueryItem queryItemWithName:@"offset" value:@"0"],
        [NSURLQueryItem queryItemWithName:@"limit" value:@"50"]] key:@"playlists"];
}
- (void)favorites {
    self.title = ACMenuText(@"Альбомы");
    _currentAlbum = nil; _collectionID = nil; _playlist = NO; _rowKind = @"albums"; self.tableView.tableHeaderView = _catalogHeader;
    [self load:@"favorite/getUserFavorites" query:@[[NSURLQueryItem queryItemWithName:@"type" value:@"albums"],
        [NSURLQueryItem queryItemWithName:@"limit" value:@"50"]] key:@"albums"];
}
- (NSArray *)collectionQuery:(NSString *)limit {
    NSMutableArray *query = [@[[NSURLQueryItem queryItemWithName:_playlist ? @"playlist_id" : @"album_id" value:_collectionID],
        [NSURLQueryItem queryItemWithName:@"limit" value:limit], [NSURLQueryItem queryItemWithName:@"offset" value:@"0"]] mutableCopy];
    if (_playlist) [query addObject:[NSURLQueryItem queryItemWithName:@"extra" value:@"tracks"]];
    return query;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { if (!_dashboard) return MAX(1, _rows.count + ((_currentAlbum && _collectionID) ? 1 : 0));
    NSDictionary *spec = _sections[section];
    return [spec[@"kind"] isEqualToString:@"tracks"] ? MAX(1, [spec[@"items"] count]) : 1; }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)index {
    if (_dashboard) {
        NSDictionary *section = _sections[index.section];
        NSArray *items = section[@"items"];
        if (!items.count) return ACCell(section[@"message"], nil, @"music.note");
        if ([section[@"kind"] isEqualToString:@"tracks"]) {
            NSDictionary *item = items[index.row];
            return [self mediaCell:item];
        }
        UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
        cell.backgroundColor = UIColor.blackColor; cell.selectionStyle = UITableViewCellSelectionStyleNone;
        BOOL twoRows = [section[@"type"] isEqualToString:@"new-releases"];
        CGFloat galleryHeight = twoRows ? 516 : 258;
        UIScrollView *scroll = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, tableView.bounds.size.width, galleryHeight)];
        scroll.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        CGFloat x = 20;
        NSUInteger cardIndex = 0;
        for (NSDictionary *item in items) {
            UIButton *card = [UIButton buttonWithType:UIButtonTypeCustom];
            CGFloat y = twoRows ? (cardIndex % 2) * 258 : 0;
            x = 20 + (twoRows ? cardIndex / 2 : cardIndex) * 172;
            card.frame = CGRectMake(x, y, 158, 250);
            UIImageView *cover = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 158, 158)];
            cover.contentMode = UIViewContentModeScaleAspectFill; cover.clipsToBounds = YES;
            cover.layer.cornerRadius = [section[@"kind"] isEqualToString:@"artists"] ? 79 : 12;
            cover.backgroundColor = UIColor.darkGrayColor;
            [cover sd_setImageWithURL:[NSURL URLWithString:[self artwork:item]] placeholderImage:[UIImage systemImageNamed:@"music.note"]];
            [card addSubview:cover];
            NSArray *images = [item[@"images300"] isKindOfClass:NSArray.class] ? item[@"images300"] : nil;
            if (images.count >= 4) {
                cover.image = nil;
                for (NSUInteger tile = 0; tile < 4; tile++) {
                    UIImageView *image = [[UIImageView alloc] initWithFrame:CGRectMake((tile % 2) * 79, (tile / 2) * 79, 79, 79)];
                    image.contentMode = UIViewContentModeScaleAspectFill; image.clipsToBounds = YES;
                    [image sd_setImageWithURL:[NSURL URLWithString:ACQobuzText(images[tile])]];
                    [cover addSubview:image];
                }
            }
            if ([item[@"hires"] boolValue] || [ACQobuzObject(item[@"album"])[@"hires"] boolValue]) {
                UILabel *badge = [[UILabel alloc] initWithFrame:CGRectMake(105, 130, 50, 24)];
                badge.text = @"Hi-Res"; badge.textAlignment = NSTextAlignmentCenter;
                badge.font = [UIFont boldSystemFontOfSize:11]; badge.textColor = UIColor.blackColor;
                badge.backgroundColor = [UIColor colorWithRed:1 green:.83 blue:.25 alpha:1];
                [card addSubview:badge];
            }
            UILabel *name = [[UILabel alloc] initWithFrame:CGRectMake(0, 166, 158, 48)];
            name.numberOfLines = 2; name.font = [UIFont systemFontOfSize:17 weight:UIFontWeightMedium]; name.textColor = UIColor.whiteColor;
            name.text = ACQobuzText(item[@"title"] ?: item[@"name"]); [card addSubview:name];
            UILabel *artist = [[UILabel alloc] initWithFrame:CGRectMake(0, 216, 158, 22)];
            artist.font = [UIFont systemFontOfSize:14]; artist.textColor = UIColor.lightGrayColor;
            artist.text = [self subtitle:item]; [card addSubview:artist];
            [card addAction:[UIAction actionWithHandler:^(UIAction *action) { [self openDashboardItem:item section:section]; }] forControlEvents:UIControlEventTouchUpInside];
            [scroll addSubview:card]; cardIndex++;
        }
        scroll.contentSize = CGSizeMake(x + 178, galleryHeight); [cell.contentView addSubview:scroll]; return cell;
    }
    if (_currentAlbum && _collectionID) {
        if (index.row == 0) return ACCell(@"Назад к альбомам", nil, @"arrow.uturn.backward");
        NSUInteger trackIndex = index.row - 1;
        if (trackIndex >= _rows.count) return ACCell(_message, nil, @"info.circle");
        return [self mediaCell:_rows[trackIndex]];
    }
    if (!_rows.count) return ACCell(_message, nil, @"info.circle");
    NSDictionary *row = _rows[index.row];
    NSString *name = ACQobuzText(row[@"title"]);
    if (!name.length) name = ACQobuzText(row[@"name"]);
    return [self mediaCell:row];
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)index {
    [tableView deselectRowAtIndexPath:index animated:YES];
    if (_dashboard) {
        NSDictionary *section = _sections[index.section];
        NSArray *items = section[@"items"];
        if (index.row < items.count && [section[@"kind"] isEqualToString:@"tracks"]) [self openDashboardItem:items[index.row] section:section];
        return;
    }
    if (_currentAlbum && _collectionID) {
        if (index.row == 0) {
            _rows = _parentRows ?: @[]; _currentAlbum = nil; _collectionID = nil;
            _rowKind = _parentRowKind ?: @"albums"; _playlist = _parentPlaylist;
            self.title = _parentTitle ?: @"Qobuz"; self.tableView.tableHeaderView = _catalogHeader;
            [self.tableView reloadData];
            return;
        }
        NSUInteger trackIndex = index.row - 1;
        if (trackIndex < _rows.count && !_sending) [self playTrack:_rows[trackIndex]];
        return;
    }
    if (index.row >= _rows.count || _sending) return;
    NSDictionary *row = _rows[index.row];
    NSString *section = ACQobuzText(row[@"section"]);
    if (section.length) {
        if ([section isEqualToString:@"playlists"]) [self playlists];
        else [self favoriteSection:section title:row[@"title"]];
        return;
    }
    if ([_rowKind isEqualToString:@"tags"]) {
        [self openDashboardItem:row section:@{@"kind":@"tags"}];
        return;
    }
    if ([_rowKind isEqualToString:@"artists"]) {
        _rowKind = @"albums";
        self.title = ACQobuzText(row[@"name"]);
        [self load:@"artist/get" query:@[
            [NSURLQueryItem queryItemWithName:@"artist_id" value:ACQobuzText(row[@"id"])],
            [NSURLQueryItem queryItemWithName:@"extra" value:@"albums"],
            [NSURLQueryItem queryItemWithName:@"limit" value:@"100"]] key:@"albums"];
        return;
    }
    if ([_rowKind isEqualToString:@"tracks"]) { [self playTrack:row]; return; }
    if (!_collectionID) {
        _parentRows = [_rows copy]; _parentTitle = [self.title copy]; _parentRowKind = [_rowKind copy]; _parentPlaylist = _playlist;
        _rowKind = @"tracks";
        self.title = ACQobuzText(row[@"title"] ?: row[@"name"]);
        _collectionID = ACQobuzText(row[@"id"]);
        _currentAlbum = row;
        self.tableView.tableHeaderView = nil;
        [self load:_playlist ? @"playlist/get" : @"album/get" query:[self collectionQuery:@"100"] key:@"tracks"];
        return;
    }
    [self playTrack:row];
}
- (void)playLinkplayTrack:(NSDictionary *)row {
    LPDevice *device = self.store.selected;
    NSString *deviceID = ACDeviceID(device);
    NSDictionary *session = ACQobuzSession(deviceID);
    if (!device || !session) { [self notice:@"Выберите колонку и войдите в Qobuz."]; return; }
    LPAccount *account = [LPAccount new];
    account.source = @"Qobuz";
    account.token = session[@"token"];
    account.userId = session[@"userID"] ?: @"";
    account.userName = session[@"displayName"] ?: @"";
    LPPlayHeader *header = [LPPlayHeader new];
    header.mediaSource = @"Qobuz"; header.mediaType = MEDIATYPE_NETLIST;
    header.headTitle = self.title ?: @"Qobuz";
    header.headId = _collectionID ?: @"Qobuz";
    header.searchUrl = _tracksURL ?: @"";
    header.quality = @"7";
    header.loopMode = LP_LOOPMODE_NOBACK;
    header.headType = _collectionID ? (_playlist ? LP_HEADER_TYPE_PLAYLIST : LP_HEADER_TYPE_ALBUM) : LP_HEADER_TYPE_COLLECTION;
    NSMutableArray *items = [NSMutableArray array];
    NSInteger selected = NSNotFound;
    for (NSDictionary *track in _rows) {
        NSString *trackID = ACQobuzText(track[@"id"]);
        if (!trackID.length) continue;
        if ([trackID isEqualToString:ACQobuzText(row[@"id"])]) selected = items.count;
        LPPlayItem *item = [LPPlayItem new];
        item.trackId = trackID; item.trackName = ACQobuzText(track[@"title"] ?: track[@"name"]);
        item.trackUrl = _tracksURL ?: @"";
        item.trackImage = [self artwork:track]; item.trackArtist = [self subtitle:track];
        NSDictionary *album = ACQobuzObject(track[@"album"]);
        item.albumName = ACQobuzText(album[@"title"]); item.albumId = ACQobuzText(album[@"id"]);
        item.trackDuration = [track[@"duration"] intValue];
        [items addObject:item];
    }
    if (selected == NSNotFound || !items.count) { [self notice:@"Трек отсутствует в текущей очереди."]; return; }
    header.totalTracks = (int)items.count;
    LPPlayMusicList *list = [LPPlayMusicList new];
    list.account = account; list.header = header; list.list = items; list.index = (int)selected;
    NSDictionary *payload = [[LPMDPKitManager shared] playMusicSingleSource:list];
    LPDevicePlayer *player = [device getPlayer];
    if (!payload.count || !player) { [self notice:@"SDK не подготовил очередь Qobuz для выбранной колонки."]; return; }
    _sending = YES;
    [player playAudioWithMusicDictionary:payload completionHandler:^(BOOL success, NSString *response) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self->_sending = NO;
            if (![ACDeviceID(self.store.selected) isEqualToString:deviceID]) return;
            if (!success) [self notice:response.length ? response : @"Колонка отклонила очередь Qobuz."];
        });
    }];
}
- (void)playTrack:(NSDictionary *)row {
    NSString *target = self.store.targetID;
    if (![target hasPrefix:@"acs2:"]) { [self playLinkplayTrack:row]; return; }
    NSString *host = [NSURL URLWithString:[target substringFromIndex:5]].host;
    NSDictionary *session = ACQobuzSession(ACDeviceID(self.store.selected));
    NSString *localIP = ACQobuzLocalIP(host);
    if (!session || !localIP) { [self notice:@"Нужна активная сессия и подключение A33 в локальной Wi‑Fi сети."]; return; }
    NSString *trackID = ACQobuzText(row[@"id"]);
    NSMutableArray *ids = [NSMutableArray array];
    for (NSDictionary *item in _rows) [ids addObject:ACQobuzText(item[@"id"])];
    NSURL *context = ACQobuzURL(_playlist ? @"playlist/get" : @"album/get", session,
        [self collectionQuery:[NSString stringWithFormat:@"%lu", (unsigned long)ids.count]]);
    NSString *title = ACQobuzText(row[@"title"]);
    id image = row[@"image"] ?: ACQobuzObject(row[@"album"])[@"image"];
    NSString *art = [image isKindOfClass:NSString.class] ? image : ACQobuzText(ACQobuzObject(image)[@"large"]);
    NSDictionary *payload = @{@"TrackImage":art, @"TrackTitle":title, @"TrackId":trackID,
        @"StreamMediaName":@"qobuz", @"SongList":[ids componentsJoinedByString:@"-"], @"TrackContext":context.absoluteString,
        @"Path":context.absoluteString, @"SongPlay":trackID, @"Ip":localIP, @"Token":session[@"token"],
        @"duration":ACQobuzText(row[@"duration"]), @"FormatId":@"7"};
    NSData *json = [NSJSONSerialization dataWithJSONObject:payload options:0 error:nil];
    __weak ACStore *store = self.store;
    BOOL (^selected)(void) = ^BOOL { return [store.targetID isEqualToString:target]; };
    _sending = YES;
    [_socket send:json to:host selected:selected done:^(BOOL sent) {
        if (!sent) { self->_sending = NO; [self notice:@"Не удалось отправить команду A33."]; return; }
        [self verifyTrack:trackID host:host selected:selected remaining:4];
    }];
}
- (void)verifyTrack:(NSString *)trackID host:(NSString *)host selected:(BOOL (^)(void))selected remaining:(NSUInteger)remaining {
    if (!selected()) { _sending = NO; return; }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        ACRequest(host, 8000, @"/", @"Instruct", @"getPlayerStatus", nil, nil, ^(NSData *data) {
            if (!selected()) { self->_sending = NO; return; }
            NSDictionary *status = data.length ? ACQobuzObject([NSJSONSerialization JSONObjectWithData:data options:0 error:nil]) : nil;
            NSString *current = ACQobuzText(status[@"TrackId"] ?: status[@"trackId"]);
            NSString *play = ACQobuzText(status[@"status"] ?: status[@"PlayState"]).lowercaseString;
            if ([current isEqualToString:trackID] && [@[@"play", @"playing"] containsObject:play]) {
                self->_sending = NO; [self notice:@"A33 подтвердил воспроизведение трека."];
            } else if (remaining > 1) {
                [self verifyTrack:trackID host:host selected:selected remaining:remaining - 1];
            } else {
                self->_sending = NO; [self notice:@"Команда отправлена. A33 не подтвердил ID играющего трека."];
            }
        });
    });
}
@end

@interface ACMusicServices : UITableViewController
@property(nonatomic, weak) ACStore *store;
@property(nonatomic, copy) NSString *initialServiceID;
@end

@implementation ACMusicServices {
    NSArray<NSArray<NSString *> *> *_services;
    NSDictionary<NSString *, NSDictionary *> *_deviceServices;
    NSString *_capabilityDeviceID;
    BOOL _capabilityLoading;
    BOOL _didOpenInitialService;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = ACMenuText(@"Музыкальные сервисы");
    _services = @[
        @[@"Deezer", @"https://www.deezer.com/", @"https://account.deezer.com/en-us/login/", @"Deezer"],
        @[@"Qobuz", @"https://play.qobuz.com/", @"https://www.qobuz.com/signin", @"Qobuz"],
        @[@"TIDAL", @"https://listen.tidal.com/", @"https://account.tidal.com/", @"Tidal"],
        @[@"YouTube Music", @"https://music.youtube.com/", @"https://music.youtube.com/", @"YouTubeMusic"],
        @[@"SoundCloud", @"https://soundcloud.com/", @"https://soundcloud.com/signin", @"SoundCloud"],
    ];
    [self refreshDeviceServices];
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self refreshDeviceServices];
}
- (void)refreshDeviceServices {
    LPDevice *device = self.store.selected;
    NSString *deviceID = ACDeviceID(device);
    if (!deviceID.length || _capabilityLoading || [_capabilityDeviceID isEqualToString:deviceID]) return;
    _capabilityLoading = YES;
    _capabilityDeviceID = [deviceID copy];
    _deviceServices = nil;
    [self.tableView reloadData];
    ACDiscoverStreamServices(device, ^(NSArray<NSDictionary *> *services) {
        if (![ACDeviceID(self.store.selected) isEqualToString:deviceID]) { self->_capabilityLoading = NO; return; }
        NSMutableDictionary *index = [NSMutableDictionary dictionary];
        for (NSDictionary *service in services) {
            NSString *identifier = [service[@"id"] isKindOfClass:NSString.class] ? service[@"id"] : @"";
            if (identifier.length) index[identifier.lowercaseString] = service;
        }
        self->_deviceServices = index;
        self->_capabilityLoading = NO;
        [self.tableView reloadData];
        [self openInitialServiceWhenReady];
    });
}
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self openInitialServiceWhenReady];
}
- (void)openInitialServiceWhenReady {
    if (_didOpenInitialService || !self.initialServiceID.length || !self.view.window) return;
    BOOL builtInFlow = [self.initialServiceID isEqualToString:@"Qobuz"] || [self.initialServiceID isEqualToString:@"Deezer"];
    if (_capabilityLoading && !builtInFlow) return;
    NSInteger index = [_services indexOfObjectPassingTest:^BOOL(NSArray<NSString *> *row, NSUInteger idx, BOOL *stop) {
        return [row[3] isEqualToString:self.initialServiceID];
    }];
    if (index == NSNotFound) return;
    if (!builtInFlow &&
        ![self capabilityForService:self.initialServiceID]) return;
    _didOpenInitialService = YES;
    [self tableView:self.tableView didSelectRowAtIndexPath:[NSIndexPath indexPathForRow:index inSection:0]];
}
- (NSDictionary *)capabilityForService:(NSString *)serviceID {
    NSArray<NSString *> *aliases = [serviceID isEqualToString:@"Tidal"] ? @[@"tidal"] :
        ([serviceID isEqualToString:@"YouTubeMusic"] ? @[@"youtubemusic", @"youtube music"] :
        ([serviceID isEqualToString:@"SoundCloud"] ? @[@"soundcloud"] :
        ([serviceID isEqualToString:@"Qobuz"] ? @[@"qobuz"] : @[@"deezer", @"deezer2"])));
    for (NSString *key in aliases) if (_deviceServices[key]) return _deviceServices[key];
    return nil;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return _services.count; }
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (_capabilityLoading) return ACMenuText(@"Проверяю встроенные сервисы выбранной колонки…");
    if (!_deviceServices) return ACMenuText(@"Не удалось прочитать StreamServicesCapability. Обновите выбор устройства и попробуйте снова.");
    return ACMenuText(@"Доступность зависит от ответа StreamServicesCapability самой колонки. Встроенный вход и каталог запускаются отдельно от входа на сайте сервиса.");
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSArray *service = _services[indexPath.row];
    NSDictionary *capability = [self capabilityForService:service[3]];
    NSString *version = [capability[@"version"] isKindOfClass:NSString.class] ? capability[@"version"] : @"";
    NSString *detail = _capabilityLoading ? ACMenuText(@"Проверка устройства…") :
        (capability ? (version.length ? [NSString stringWithFormat:ACMenuText(@"Доступно на колонке · %@"), version] : ACMenuText(@"Доступно на колонке")) : ACMenuText(@"Колонка не объявляет этот сервис"));
    UITableViewCell *cell = ACCell(ACMenuText(service[0]), detail, capability ? @"person.crop.circle" : @"nosign");
    cell.accessoryType = capability ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;
    cell.textLabel.textColor = capability ? UIColor.labelColor : UIColor.secondaryLabelColor;
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSArray<NSString *> *service = _services[indexPath.row];
    if (_capabilityLoading) return;
    // Qobuz is confirmed on both A31 and A98. Keep its account/catalog flow
    // reachable even if this particular firmware fails capability discovery.
    if ([service[3] isEqualToString:@"Qobuz"]) {
        ACQobuzCatalog *catalog = [[ACQobuzCatalog alloc] initWithStyle:UITableViewStyleInsetGrouped];
        catalog.store = self.store;
        [self.navigationController pushViewController:catalog animated:YES];
        return;
    }
    // Deezer's native screen probes the account on the selected speaker and
    // loads the library when already signed in; otherwise it presents the
    // in-app device login form. Avoid an intermediate menu with dead actions.
    if ([service[3] isEqualToString:@"Deezer"] && self.store.selected) {
        ACLegacyDeezerCatalog *catalog = [[ACLegacyDeezerCatalog alloc] initWithStyle:UITableViewStyleInsetGrouped];
        catalog.store = self.store;
        [self.navigationController pushViewController:catalog animated:YES];
        return;
    }
    if (![self capabilityForService:service[3]]) {
        UIAlertController *unsupported = [UIAlertController alertControllerWithTitle:service[0]
            message:@"Выбранная колонка не объявляет этот музыкальный сервис. airControl не будет запускать для него неработающий вход." preferredStyle:UIAlertControllerStyleAlert];
        [unsupported addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:unsupported animated:YES completion:nil];
        return;
    }
    UIAlertController *actions = [UIAlertController alertControllerWithTitle:service[0]
        message:@"Войдите в аккаунт сервиса." preferredStyle:UIAlertControllerStyleAlert];
    [actions addAction:[UIAlertAction actionWithTitle:@"Войти" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [self openServiceURL:service[2]];
    }]];
    [actions addAction:[UIAlertAction actionWithTitle:@"Отмена" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:actions animated:YES completion:nil];
}
- (void)openServiceURL:(NSString *)address {
    NSURL *url = [NSURL URLWithString:address];
    [UIApplication.sharedApplication openURL:url options:@{} completionHandler:^(BOOL success) {
        if (success || !self.view.window || self.presentedViewController) return;
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Не удалось открыть сервис"
            message:nil preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    }];
}
@end

@interface ACThinSlider : UISlider
@end
@implementation ACThinSlider
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) self.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;
    return self;
}
- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) self.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;
    return self;
}
- (CGRect)trackRectForBounds:(CGRect)bounds {
    CGRect track = [super trackRectForBounds:bounds];
    track.size.height = 2.0;
    track.origin.y = CGRectGetMidY(bounds) - 1.0;
    return track;
}
@end

@interface ACTransportScreen : UIViewController {
@protected
    UILabel *_track, *_artist, *_clock, *_volumeText, *_sourceLabel, *_quality;
    UIImageView *_cover;
    UISlider *_seek, *_volume;
    UIButton *_toggle, *_previous, *_next, *_repeatButton, *_moreButton, *_queueButton;
}
- (void)toggle;
- (void)previous;
- (void)next;
- (void)seek:(UISlider *)sender;
- (void)volume:(UISlider *)sender;
- (void)showQueue;
- (void)repeatTrack;
- (void)showMore;
@end

@implementation ACTransportScreen
- (UILabel *)label:(UIFont *)font color:(UIColor *)color {
    UILabel *label = [UILabel new]; label.font = font; label.textColor = color;
    label.textAlignment = NSTextAlignmentCenter; label.numberOfLines = 2;
    return label;
}
- (UIButton *)button:(NSString *)title symbol:(NSString *)icon action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    UIButtonConfiguration *config = [UIButtonConfiguration tintedButtonConfiguration];
    config.image = [UIImage systemImageNamed:icon]; config.title = title;
    config.imagePadding = 6; config.baseForegroundColor = ACAccent();
    button.configuration = config;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = ACBackground();
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
    self.navigationItem.hidesBackButton = YES;
    UIButton *back = [UIButton buttonWithType:UIButtonTypeSystem];
    [back setImage:[UIImage systemImageNamed:@"chevron.left"] forState:UIControlStateNormal];
    back.tintColor = ACPrimaryText();
    back.frame = CGRectMake(0, 0, 34, 34);
    back.layer.cornerRadius = 17;
    back.layer.borderWidth = 1;
    back.layer.borderColor = [ACPrimaryText() colorWithAlphaComponent:.65].CGColor;
    [back addTarget:self action:@selector(closeTransport) forControlEvents:UIControlEventTouchUpInside];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:back];
    _sourceLabel = [UILabel new];
    _sourceLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    _sourceLabel.textColor = ACPrimaryText();
    _sourceLabel.textAlignment = NSTextAlignmentCenter;
    _sourceLabel.text = ACMenuText(@"ВОСПРОИЗВЕДЕНИЕ");
    self.navigationItem.titleView = _sourceLabel;
    UIScrollView *scroll = [UIScrollView new];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:scroll];
    UIStackView *stack = [UIStackView new]; stack.axis = UILayoutConstraintAxisVertical; stack.spacing = 7;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [scroll addSubview:stack];
    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [scroll.topAnchor constraintEqualToAnchor:safe.topAnchor], [scroll.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor],
        [scroll.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor], [scroll.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor],
        [stack.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor constant:5],
        [stack.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor constant:-8],
        [stack.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor constant:24],
        [stack.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor constant:-24],
        [stack.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor constant:-48]
    ]];
    UIView *coverFrame = [UIView new];
    [stack addArrangedSubview:coverFrame];
    [coverFrame.heightAnchor constraintEqualToAnchor:stack.widthAnchor multiplier:1.0].active = YES;
    _cover = [UIImageView new]; _cover.contentMode = UIViewContentModeScaleAspectFill;
    _cover.backgroundColor = ACCard(); _cover.tintColor = ACSecondaryText();
    _cover.layer.cornerRadius = 18; _cover.clipsToBounds = YES;
    [coverFrame addSubview:_cover];
    [_cover.widthAnchor constraintEqualToAnchor:stack.widthAnchor].active = YES;
    [_cover.heightAnchor constraintEqualToAnchor:_cover.widthAnchor multiplier:1.0].active = YES;
    _cover.translatesAutoresizingMaskIntoConstraints = NO;
    [_cover.centerXAnchor constraintEqualToAnchor:coverFrame.centerXAnchor].active = YES;
    [_cover.centerYAnchor constraintEqualToAnchor:coverFrame.centerYAnchor].active = YES;
    _track = [self label:[UIFont systemFontOfSize:21 weight:UIFontWeightSemibold] color:ACPrimaryText()];
    _track.textAlignment = NSTextAlignmentLeft;
    _artist = [self label:[UIFont systemFontOfSize:14 weight:UIFontWeightRegular] color:ACSecondaryText()];
    _clock = [self label:[UIFont monospacedDigitSystemFontOfSize:13 weight:UIFontWeightRegular] color:ACSecondaryText()];
    _volumeText = [self label:[UIFont preferredFontForTextStyle:UIFontTextStyleFootnote] color:ACSecondaryText()];
    _quality = [self label:[UIFont systemFontOfSize:12 weight:UIFontWeightSemibold] color:ACSecondaryText()];
    _quality.numberOfLines = 1;
    _quality.hidden = YES;
    UIStackView *titleRow = [[UIStackView alloc] initWithArrangedSubviews:@[_track]];
    titleRow.axis = UILayoutConstraintAxisHorizontal;
    titleRow.alignment = UIStackViewAlignmentCenter;
    _moreButton = [self button:nil symbol:@"ellipsis" action:@selector(showMore)];
    _moreButton.accessibilityLabel = @"Дополнительные действия";
    [_moreButton.widthAnchor constraintEqualToConstant:42].active = YES;
    [titleRow addArrangedSubview:_moreButton];
    _seek = [ACThinSlider new]; _volume = [ACThinSlider new]; _seek.continuous = NO; _volume.continuous = NO;
    _volume.maximumValue = 100;
    _seek.minimumTrackTintColor = ACAccent(); _volume.minimumTrackTintColor = ACAccent();
    _seek.maximumTrackTintColor = [UIColor colorWithWhite:.88 alpha:1];
    _volume.maximumTrackTintColor = [UIColor colorWithWhite:.27 alpha:1];
    _seek.thumbTintColor = UIColor.clearColor; _volume.thumbTintColor = ACPrimaryText();
    [_seek addTarget:self action:@selector(seek:) forControlEvents:UIControlEventValueChanged];
    [_volume addTarget:self action:@selector(volume:) forControlEvents:UIControlEventValueChanged];
    _previous = [self button:nil symbol:@"backward.fill" action:@selector(previous)]; _previous.accessibilityLabel = @"Предыдущий трек";
    _repeatButton = [self button:nil symbol:@"repeat.1" action:@selector(repeatTrack)];
    _repeatButton.accessibilityLabel = @"Повтор трека";
    _toggle = [self button:nil symbol:@"play.fill" action:@selector(toggle)];
    _next = [self button:nil symbol:@"forward.fill" action:@selector(next)]; _next.accessibilityLabel = @"Следующий трек";
    UIStackView *controls = [[UIStackView alloc] initWithArrangedSubviews:@[_repeatButton, _previous, _toggle, _next]];
    controls.distribution = UIStackViewDistributionFillEqually; controls.spacing = 12;
    [controls.heightAnchor constraintEqualToConstant:46].active = YES;
    _queueButton = [self button:ACMenuText(@"Текущая очередь") symbol:@"list.bullet" action:@selector(showQueue)];
    for (UIView *view in @[titleRow, _artist, _quality, _seek, _clock, controls, _volumeText, _volume, _queueButton]) [stack addArrangedSubview:view];
}
- (void)closeTransport { [self.navigationController popViewControllerAnimated:YES]; }
- (void)toggle {}
- (void)previous {}
- (void)next {}
- (void)seek:(UISlider *)sender {}
- (void)volume:(UISlider *)sender {}
- (void)showQueue {}
- (void)repeatTrack {}
- (void)showMore {}
@end

// A33 and Libre have separate wire contracts from the Linkplay Music Kit.
@interface ACLANPlayer : ACTransportScreen
@property(nonatomic, copy) void (^onVerified)(NSString *name);
@property(nonatomic, copy) BOOL (^isSelected)(void);
- (ACRadioCatalog *)catalogWithTuneIn:(BOOL)tuneIn;
- (instancetype)initWithEndpoint:(NSURLComponents *)endpoint libre:(BOOL)libre;
@end

@implementation ACLANPlayer {
    NSURLComponents *_endpoint;
    BOOL _libre, _ready;
    NSString *_transport, *_rendering;
    BOOL _playing, _reading, _sending;
    NSTimeInterval _duration;
    NSString *_deviceName, *_coverAddress;
    NSSet<NSString *> *_actions;
    NSTimer *_poll;
}
- (instancetype)initWithEndpoint:(NSURLComponents *)endpoint libre:(BOOL)libre {
    if ((self = [super init])) { _endpoint = endpoint; _libre = libre; }
    return self;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = ACMenuText(@"Сейчас играет");
    _track.text = @"Проверяю устройство…";
    _artist.text = _libre ? @"Libre · UPnP" : @"A33 · ACS2";
    _cover.image = [UIImage systemImageNamed:@"music.note"];
    _seek.enabled = _volume.enabled = _toggle.enabled = _previous.enabled = _next.enabled = _queueButton.enabled = NO;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"radio"]
        style:UIBarButtonItemStylePlain target:self action:@selector(openRadio)];
    self.navigationItem.rightBarButtonItem.accessibilityLabel = @"Интернет-радио";
    self.navigationItem.rightBarButtonItem.enabled = NO;
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self refresh];
    __weak typeof(self) weakSelf = self;
    _poll = [NSTimer scheduledTimerWithTimeInterval:2 repeats:YES block:^(NSTimer *timer) { [weakSelf refresh]; }];
}
- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [_poll invalidate];
    _poll = nil;
}
- (void)acs:(NSString *)command done:(void (^)(NSData *))done {
    ACRequest(_endpoint.host, 8000, @"/", @"Instruct", command, nil, nil, done);
}
- (void)soap:(NSString *)action rendering:(BOOL)rendering args:(NSString *)args done:(void (^)(DDXMLNode *))done {
    NSString *service = rendering ? @"urn:schemas-upnp-org:service:RenderingControl:1" : @"urn:schemas-upnp-org:service:AVTransport:1";
    NSURLComponents *url = [NSURLComponents componentsWithString:rendering ? _rendering : _transport];
    NSString *body = [NSString stringWithFormat:@"<s:Envelope xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\"><s:Body><u:%@ xmlns:u=\"%@\"><InstanceID>0</InstanceID>%@</u:%@></s:Body></s:Envelope>", action, service, args ?: @"", action];
    ACRequest(url.host, url.port.integerValue ?: 80, url.path, nil, nil, body,
              [NSString stringWithFormat:@"\"%@#%@\"", service, action], ^(NSData *data) {
        DDXMLNode *root = ACXMLData(data);
        NSString *path = [NSString stringWithFormat:@"./*[local-name()='Body']/*[local-name()='%@Response' and namespace-uri()='%@']", action, service];
        done(ACNodes(root, path).firstObject);
    });
}
- (void)refresh {
    if (_reading || _sending) return;
    if (_ready) { [self readState]; return; }
    if (!_libre) {
        [self readState];
        return;
    }
    _reading = YES;
    ACRequest(_endpoint.host, _endpoint.port.integerValue ?: 80, _endpoint.path, nil, nil, nil, nil, ^(NSData *data) {
        self->_reading = NO;
        DDXMLNode *root = ACXMLData(data);
        if (![ACDIDL(root, @"deviceType") isEqualToString:@"urn:schemas-upnp-org:device:MediaRenderer:1"]) {
            self->_track.text = @"По адресу нет описания MediaRenderer."; return;
        }
        for (DDXMLNode *service in ACNodes(root, @".//*[local-name()='service']")) {
            NSString *type = ACValue(service, @"serviceType"), *control = ACValue(service, @"controlURL");
            if (!control.length) continue;
            NSURL *url = [NSURL URLWithString:control relativeToURL:self->_endpoint.URL].absoluteURL;
            if (![url.host isEqualToString:self->_endpoint.host] || ![url.scheme isEqualToString:@"http"] ||
                url.user || url.password || url.query || url.fragment) continue;
            if ([type isEqualToString:@"urn:schemas-upnp-org:service:AVTransport:1"]) self->_transport = url.absoluteString;
            if ([type isEqualToString:@"urn:schemas-upnp-org:service:RenderingControl:1"]) self->_rendering = url.absoluteString;
        }
        self->_ready = self->_transport.length && self->_rendering.length;
        if (self->_ready) {
            self->_deviceName = ACText(ACDIDL(root, @"friendlyName")) ?: @"Libre";
            if (self.onVerified) self.onVerified(self->_deviceName);
            [self readState];
        }
        else self->_track.text = @"Устройство не объявило AVTransport и RenderingControl.";
    });
}
- (void)readState {
    if (_reading) return;
    _reading = YES;
    if (!_libre) {
        [self acs:@"getStatusEx" done:^(NSData *data) {
            NSDictionary *status = ACACSStatus(data);
            self->_ready = status != nil;
            if (status) self->_deviceName = [status[@"DevName"] description] ?: [status[@"ProjectName"] description];
            if (status && self.onVerified) self.onVerified(self->_deviceName);
            id left = status[@"DevVolumeL"], right = status[@"DevVolumeR"];
            NSString *transport = [status[@"PlayState"] description];
            [self acs:@"getPlayerStatus" done:^(NSData *playerData) {
                id parsed = playerData.length ? [NSJSONSerialization JSONObjectWithData:playerData options:0 error:nil] : nil;
                NSDictionary *player = [parsed isKindOfClass:NSDictionary.class] ? parsed : nil;
                self->_reading = NO;
                [self showTransport:transport volume:left];
                self->_previous.enabled = self->_next.enabled = transport.length && !self->_sending;
                [self showTrack:ACText([player[@"Title"] description]) artist:[player[@"Artist"] description]
                    artwork:nil elapsed:[[player[@"curpos"] description] doubleValue] / 1000
                    duration:[[player[@"totlen"] description] doubleValue] / 1000];
                if (right && left && ![[right description] isEqualToString:[left description]]) {
                    self->_volume.enabled = NO;
                    self->_volumeText.text = [NSString stringWithFormat:@"%@ L/R: %@ / %@", ACMenuText(@"Громкость"), left, right];
                }
            }];
        }];
        return;
    }
    [self soap:@"GetTransportInfo" rendering:NO args:nil done:^(DDXMLNode *transport) {
        [self soap:@"GetVolume" rendering:YES args:@"<Channel>Master</Channel>" done:^(DDXMLNode *volume) {
            [self showTransport:ACValue(transport, @"CurrentTransportState") volume:ACValue(volume, @"CurrentVolume")];
            [self soap:@"GetPositionInfo" rendering:NO args:nil done:^(DDXMLNode *position) {
                NSString *metadata = ACValue(position, @"TrackMetaData");
                DDXMLNode *didl = ACXMLData([metadata dataUsingEncoding:NSUTF8StringEncoding]);
                [self showTrack:ACText(ACDIDL(didl, @"title")) artist:ACDIDL(didl, @"artist")
                    artwork:ACDIDL(didl, @"albumArtURI") elapsed:[self seconds:ACValue(position, @"RelTime")]
                    duration:[self seconds:ACValue(position, @"TrackDuration")]];
                [self soap:@"GetCurrentTransportActions" rendering:NO args:nil done:^(DDXMLNode *actions) {
                    NSString *raw = ACValue(actions, @"Actions");
                    NSMutableSet *available = [NSMutableSet set];
                    for (NSString *action in [raw componentsSeparatedByString:@","])
                        [available addObject:[action stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]];
                    self->_actions = available;
                    self->_previous.enabled = [available containsObject:@"Previous"] && !self->_sending;
                    self->_next.enabled = [available containsObject:@"Next"] && !self->_sending;
                    self->_seek.enabled = self->_duration > 0 && [available containsObject:@"Seek"] && !self->_sending;
                    self->_reading = NO;
                }];
            }];
        }];
    }];
}
- (NSTimeInterval)seconds:(NSString *)value {
    NSArray *parts = [value componentsSeparatedByString:@":"];
    if (parts.count != 3) return 0;
    return [parts[0] doubleValue] * 3600 + [parts[1] doubleValue] * 60 + [parts[2] doubleValue];
}
- (void)showTrack:(NSString *)title artist:(NSString *)artist artwork:(NSString *)artwork
          elapsed:(NSTimeInterval)elapsed duration:(NSTimeInterval)duration {
    _track.text = title.length ? title : (_deviceName ?: @"Нет данных о треке");
    _artist.text = artist.length ? artist : (_libre ? @"Libre" : @"A33");
    _duration = isfinite(duration) ? MAX(0, duration) : 0;
    if (!_seek.tracking) _seek.value = _duration > 0 ? MIN(1, MAX(0, elapsed / _duration)) : 0;
    _clock.text = [NSString stringWithFormat:@"%@ / %@", ACTime(elapsed), ACTime(_duration)];
    _seek.enabled = _duration > 0 && (!_libre || [_actions containsObject:@"Seek"]) && !_sending;
    NSString *cover = ACStreamURL(artwork).absoluteString ?: @"";
    if (![_coverAddress isEqualToString:cover]) {
        _coverAddress = cover;
        [_cover sd_setImageWithURL:ACStreamURL(cover) placeholderImage:[UIImage systemImageNamed:@"music.note"]];
    }
}
- (void)showTransport:(NSString *)transport volume:(id)volume {
    NSScanner *scanner = [NSScanner scannerWithString:[volume description] ?: @""];
    NSInteger value;
    BOOL hasVolume = [scanner scanInteger:&value] && scanner.isAtEnd && value >= 0 && value <= 100;
    if (hasVolume && !_volume.tracking) _volume.value = value;
    _volume.enabled = hasVolume && !_sending;
    _volumeText.text = hasVolume ? [NSString stringWithFormat:@"%@ · %ld%%", ACMenuText(@"Громкость"), (long)value] : ACMenuText(@"Громкость");
    _playing = [@[@"play", @"playing"] containsObject:transport.lowercaseString ?: @""];
    UIButtonConfiguration *config = _toggle.configuration;
    config.image = [UIImage systemImageNamed:_playing ? @"pause.fill" : @"play.fill"];
    _toggle.configuration = config;
    _toggle.accessibilityLabel = _playing ? @"Пауза" : @"Воспроизвести";
    _toggle.enabled = transport.length && !_sending;
    self.navigationItem.rightBarButtonItem.enabled = _ready;
}
- (ACRadioCatalog *)catalogWithTuneIn:(BOOL)tuneIn {
    __weak typeof(self) weakSelf = self;
    return [[ACRadioCatalog alloc] initWithTuneIn:tuneIn play:^(NSDictionary *station, NSURL *url, void (^done)(BOOL)) {
        typeof(self) self = weakSelf;
        if (!self || !url || !self->_ready || !self.isSelected || !self.isSelected()) { done(NO); return; }
        if (!self->_libre) {
            [self acs:[@"setPlayerCmd:play:" stringByAppendingString:url.absoluteString] done:^(NSData *data) {
                NSString *response = data.length ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : nil;
                NSString *result = [response stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
                done(result.length && [result caseInsensitiveCompare:@"OK"] == NSOrderedSame);
            }];
            return;
        }
        NSString *escaped = [url.absoluteString stringByReplacingOccurrencesOfString:@"&" withString:@"&amp;"];
        escaped = [escaped stringByReplacingOccurrencesOfString:@"<" withString:@"&lt;"];
        NSString *args = [NSString stringWithFormat:@"<CurrentURI>%@</CurrentURI><CurrentURIMetaData></CurrentURIMetaData>", escaped];
        [self soap:@"SetAVTransportURI" rendering:NO args:args done:^(DDXMLNode *result) {
            if (!result || !self.isSelected()) { done(NO); return; }
            [self soap:@"Play" rendering:NO args:@"<Speed>1</Speed>" done:^(DDXMLNode *played) { done(played != nil); }];
        }];
    }];
}
- (void)openRadio {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Интернет-радио" message:nil preferredStyle:UIAlertControllerStyleAlert];
    for (NSString *name in @[@"TuneIn", @"Radio Browser"]) {
        [alert addAction:[UIAlertAction actionWithTitle:name style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [self.navigationController pushViewController:[self catalogWithTuneIn:[name isEqualToString:@"TuneIn"]] animated:YES];
        }]];
    }
    [alert addAction:[UIAlertAction actionWithTitle:@"Отмена" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}
- (void)toggle {
    if (_playing) [self send:@"Pause" command:@"pause" rendering:NO args:nil];
    else [self send:@"Play" command:@"resume" rendering:NO args:@"<Speed>1</Speed>"];
}
- (void)previous { [self send:@"Previous" command:@"prev" rendering:NO args:nil]; }
- (void)next { [self send:@"Next" command:@"next" rendering:NO args:nil]; }
- (void)seek:(UISlider *)sender {
    if (_duration <= 0) return;
    NSInteger seconds = lround(sender.value * _duration);
    NSString *target = [NSString stringWithFormat:@"%02ld:%02ld:%02ld", (long)(seconds / 3600), (long)(seconds / 60 % 60), (long)(seconds % 60)];
    [self send:@"Seek" command:[NSString stringWithFormat:@"setplay:%ld", (long)seconds] rendering:NO
           args:[NSString stringWithFormat:@"<Unit>REL_TIME</Unit><Target>%@</Target>", target]];
}
- (void)volume:(UISlider *)sender {
    NSInteger value = lroundf(sender.value);
    [self send:@"SetVolume" command:[NSString stringWithFormat:@"vol:%ld", (long)value] rendering:YES
           args:[NSString stringWithFormat:@"<Channel>Master</Channel><DesiredVolume>%ld</DesiredVolume>", (long)value]];
}
- (void)send:(NSString *)action command:(NSString *)command rendering:(BOOL)rendering args:(NSString *)args {
    if (!_ready || _sending) return;
    _sending = YES;
    _toggle.enabled = _previous.enabled = _next.enabled = _seek.enabled = _volume.enabled = NO;
    void (^finish)(void) = ^{
        self->_sending = NO;
        [self refresh];
    };
    if (_libre) [self soap:action rendering:rendering args:args done:^(DDXMLNode *result) { finish(); }];
    else [self acs:[@"setPlayerCmd:" stringByAppendingString:command] done:^(NSData *data) { finish(); }];
}
@end

@interface ACQueueSnapshot : NSObject
@property(nonatomic) NSArray<NSArray<NSString *> *> *rows;
@property(nonatomic) NSInteger active;
@property(nonatomic) NSInteger reportedIndex;
@property(nonatomic, copy) NSString *source;
@property(nonatomic) NSString *heading;
+ (instancetype)read:(NSString *)string device:(LPDevice *)device queue:(NSString *)queue;
@end

@implementation ACQueueSnapshot
+ (instancetype)read:(NSString *)string device:(LPDevice *)device queue:(NSString *)queue {
    if (!string.length || string.length > 4000000 ||
        [string rangeOfString:@"<!DOCTYPE" options:NSCaseInsensitiveSearch].location != NSNotFound) return nil;
    DDXMLDocument *doc = [[DDXMLDocument alloc] initWithXMLString:string options:0 error:nil];
    DDXMLNode *root = doc.rootElement;
    if ([root.localName isEqualToString:@"Envelope"]) {
        DDXMLNode *context = ACNodes(root, @"./*[local-name()='Body']/*[local-name()='BrowseQueueResponse']/*[local-name()='QueueContext']").firstObject;
        root = ACNodes(context, @"./*").firstObject;
        if (!root) {
            NSString *body = [context.stringValue stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
            if (!body.length || [body rangeOfString:@"<!DOCTYPE" options:NSCaseInsensitiveSearch].location != NSNotFound) return nil;
            doc = [[DDXMLDocument alloc] initWithXMLString:body options:0 error:nil];
            root = doc.rootElement;
        }
    }
    ACQueueSnapshot *snapshot = [ACQueueSnapshot new];
    snapshot.active = NSNotFound;
    NSMutableArray *rows = [NSMutableArray array];
    if ([root.localName isEqualToString:@"PlayQueue"]) {
        NSString *active = ACValue(ACNodes(root, @"./*[local-name()='CurrentPlayList']").firstObject, @"Name");
        snapshot.heading = active.length ? [@"Активная очередь: " stringByAppendingString:active] : @"Каталог очередей";
        for (DDXMLNode *item in ACNodes(root, @"./*[local-name()='PlayListInfo']/*")) {
            NSString *name = ACValue(item, @"Name");
            if (name.length) [rows addObject:@[name, [name isEqualToString:active] ? @"Активная очередь" : @""]];
        }
    } else if ([root.localName isEqualToString:@"PlayList"]) {
        DDXMLNode *info = ACNodes(root, @"./*[local-name()='ListInfo']").firstObject;
        NSString *source = ACValue(info, @"SourceName");
        snapshot.source = source;
        snapshot.heading = ACValue(root, @"ListName");
        if (!snapshot.heading.length) snapshot.heading = source;
        for (DDXMLNode *track in ACNodes(root, @"./*[local-name()='Tracks']/*")) {
            NSString *metadata = ACValue(track, @"Metadata");
            DDXMLDocument *didl = nil;
            if (metadata.length && [metadata rangeOfString:@"<!DOCTYPE" options:NSCaseInsensitiveSearch].location == NSNotFound)
                didl = [[DDXMLDocument alloc] initWithXMLString:metadata options:0 error:nil];
            NSString *url = ACValue(track, @"URL");
            NSString *fallback = [url hasPrefix:@"/media/"] ? url.lastPathComponent : nil;
            fallback = fallback.stringByRemovingPercentEncoding ?: fallback;
            NSString *title = ACText(ACDIDL(didl, @"title")) ?: fallback ?: @"Без названия";
            NSString *artist = ACText(ACDIDL(didl, @"artist"));
            NSString *album = ACText(ACDIDL(didl, @"album"));
            NSString *detail = artist && album ? [NSString stringWithFormat:@"%@ · %@", artist, album] : artist ?: album ?: @"";
            [rows addObject:@[title, detail, url ?: @""]];
        }
        NSString *indexText = [ACValue(info, @"LastPlayIndex") stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        BOOL isOneBasedIndex = [indexText rangeOfString:@"^[1-9][0-9]*$" options:NSRegularExpressionSearch].location != NSNotFound;
        NSInteger index = isOneBasedIndex ? indexText.integerValue : 0;
        snapshot.reportedIndex = index;
        LPDeviceStatus *status = device.deviceStatus;
        if ([queue isEqualToString:@"CurrentQueue"] && status.UUID.length && [status.UUID caseInsensitiveCompare:ACOffice] == NSOrderedSame &&
            [status.firmware isEqualToString:@"4.6.415156"] && device.deviceInfo && device.deviceInfo.playStatus == LP_PLAYER_STATE_PLAYING &&
            ([@[@"Qobuz", @"USBDiskQueue"] containsObject:source]) && index > 0 && index <= rows.count) {
            snapshot.active = index - 1;
        }
    } else return nil;
    snapshot.rows = rows;
    return snapshot;
}
@end

static void ACApplyUSBHighlight(ACQueueSnapshot *snapshot, NSDictionary *status) {
    if (![snapshot.source isEqualToString:@"USBDiskQueue"] ||
        ![[status[@"mode"] description] isEqualToString:@"11"]) return;
    snapshot.active = NSNotFound;
    NSInteger index = [[status[@"plicurr"] description] integerValue];
    NSInteger count = [[status[@"plicount"] description] integerValue];
    if (index > 0 && index == snapshot.reportedIndex && count == snapshot.rows.count && index <= count)
        snapshot.active = index - 1;
}

static UITableViewCell *ACCell(NSString *title, NSString *detail, NSString *icon) {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    cell.textLabel.text = ACMenuText(title);
    cell.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    cell.detailTextLabel.text = ACMenuText(detail);
    cell.textLabel.textColor = ACPrimaryText();
    cell.detailTextLabel.textColor = ACSecondaryText();
    cell.detailTextLabel.numberOfLines = 2;
    cell.imageView.image = [UIImage systemImageNamed:icon];
    cell.tintColor = ACAccent();
    cell.backgroundColor = ACCard();
    return cell;
}

@interface ACQueueController : UITableViewController
- (instancetype)initWithDevice:(LPDevice *)device queue:(NSString *)queue title:(NSString *)title;
@end
@implementation ACQueueController {
    LPDevice *_device;
    NSString *_queue, *_state;
    NSString *_usbFolderPath;
    ACQueueSnapshot *_snapshot;
    NSUInteger _generation;
    NSUInteger _usbRequest;
    BOOL _startingUSB;
}
- (instancetype)initWithDevice:(LPDevice *)device queue:(NSString *)queue title:(NSString *)title {
    if ((self = [super initWithStyle:UITableViewStyleInsetGrouped])) {
        _device = device; _queue = queue; self.title = ACMenuText(title);
    }
    return self;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.refreshControl = [UIRefreshControl new];
    [self.refreshControl addTarget:self action:@selector(loadQueue) forControlEvents:UIControlEventValueChanged];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(queueBecameActive:)
        name:UIApplicationDidBecomeActiveNotification object:nil];
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self loadQueue];
}
- (void)queueBecameActive:(NSNotification *)notification {
    if (self.view.window && self.navigationController.topViewController == self) [self loadQueue];
}
- (NSArray<NSDictionary *> *)visibleUSBEntries {
    if (!_snapshot.rows.count) return @[];
    NSString *folder = _usbFolderPath ?: @"";
    NSString *prefix = folder.length ? [folder stringByAppendingString:@"/"] : @"";
    NSMutableSet<NSString *> *folders = [NSMutableSet set];
    NSMutableArray<NSDictionary *> *files = [NSMutableArray array];
    [_snapshot.rows enumerateObjectsUsingBlock:^(NSArray<NSString *> *row, NSUInteger index, BOOL *stop) {
        NSString *path = row.count > 2 ? row[2] : @"";
        NSURL *url = [NSURL URLWithString:path];
        if (url.scheme.length) path = url.path ?: path;
        path = path.stringByRemovingPercentEncoding ?: path;
        path = [path stringByReplacingOccurrencesOfString:@"\\" withString:@"/"];
        while ([path hasPrefix:@"/"]) path = [path substringFromIndex:1];
        if ([path hasPrefix:@"media/"]) {
            path = [path substringFromIndex:6];
            // USB resources commonly arrive as /media/sda1/Folder/track.flac.
            // The mount name is transport metadata, not a browsable folder.
            if ([path hasPrefix:@"sda"]) {
                NSRange slash = [path rangeOfString:@"/"];
                if (slash.location != NSNotFound && slash.location <= 8) path = [path substringFromIndex:slash.location + 1];
            }
        }
        if ([path hasPrefix:@"udisk/"]) path = [path substringFromIndex:6];
        if (folder.length && ![path hasPrefix:prefix]) return;
        NSString *relative = folder.length ? [path substringFromIndex:prefix.length] : path;
        if (!relative.length) return;
        NSRange slash = [relative rangeOfString:@"/"];
        if (slash.location != NSNotFound) {
            NSString *name = [relative substringToIndex:slash.location];
            if (name.length) [folders addObject:name];
        } else {
            [files addObject:@{@"title":row[0], @"detail":row.count > 1 ? row[1] : @"", @"index":@(index)}];
        }
    }];
    NSMutableArray<NSDictionary *> *entries = [NSMutableArray array];
    for (NSString *name in [folders.allObjects sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)])
        [entries addObject:@{@"folder":name}];
    [entries addObjectsFromArray:files];
    return entries;
}
- (void)loadQueue {
    NSUInteger generation = ++_generation;
    _state = @"Читаю очередь…";
    if (_snapshot) _snapshot.active = NSNotFound;
    [self.tableView reloadData];
    [self.refreshControl beginRefreshing];
    __weak typeof(self) weakSelf = self;
    BOOL isUSBList = [_queue isEqualToString:@"USBDiskQueue"];
    void (^finish)(ACQueueSnapshot *, NSString *) = ^(ACQueueSnapshot *snapshot, NSString *message) {
        typeof(self) self = weakSelf;
        if (!self || self->_generation != generation) return;
        self->_generation++;
        self->_snapshot = snapshot;
        self->_state = message;
        [self.refreshControl endRefreshing];
        [self.tableView reloadData];
    };
    __block BOOL fallbackStarted = NO;
    void (^fallback)(ACQueueSnapshot *) = ^(ACQueueSnapshot *original) {
        typeof(self) self = weakSelf;
        if (!self || self->_generation != generation || fallbackStarted) return;
        fallbackStarted = YES;
        if (!isUSBList) {
            finish(original, ACMenuText(original ? @"Очередь пуста" : @"Устройство не вернуло читаемую очередь"));
            return;
        }
        ACReadQueue(self->_device, @"USBDiskQueue", ^(NSString *raw) {
            typeof(self) self = weakSelf;
            if (!self || self->_generation != generation) return;
            ACQueueSnapshot *snapshot = [ACQueueSnapshot read:raw device:self->_device queue:self->_queue] ?: original;
            finish(snapshot, snapshot ? @"Очередь пуста" : @"USB-очередь недоступна");
        });
    };
    LPDevice *device = _device;
    NSString *queue = _queue;
    void (^readSDK)(void) = ^{
        [device.deviceInfo browseQueue:queue skipContent:NO completionHandler:^(id object, NSString *raw) {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSString *payload = raw.length ? raw : ([object isKindOfClass:NSString.class] ? object : nil);
                ACQueueSnapshot *snapshot = [ACQueueSnapshot read:payload device:device queue:queue];
                if (snapshot.rows.count) finish(snapshot, nil);
                else fallback(snapshot);
            });
        }];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{ fallback(nil); });
    };
    if (![queue isEqualToString:@"CurrentQueue"] && !isUSBList) {
        readSDK();
    } else {
        // The SDK input and media fields can lag the player's live USB mode.
        ACReadJSON(device, @"getPlayerStatus", ^(NSDictionary *status) {
            typeof(self) self = weakSelf;
            if (!self || self->_generation != generation) return;
            id mode = status[@"mode"];
            if (![[mode description] isEqualToString:@"11"]) {
                readSDK();
                return;
            }
            ACReadQueue(device, queue, ^(NSString *raw) {
                typeof(self) self = weakSelf;
                if (!self || self->_generation != generation) return;
                ACQueueSnapshot *snapshot = [ACQueueSnapshot read:raw device:device queue:queue];
                if (snapshot.rows.count) {
                    ACApplyUSBHighlight(snapshot, status);
                    finish(snapshot, nil);
                    return;
                }
                if (isUSBList) { readSDK(); return; }
                ACReadQueue(device, @"USBDiskQueue", ^(NSString *usbRaw) {
                    typeof(self) self = weakSelf;
                    if (!self || self->_generation != generation) return;
                    ACQueueSnapshot *usb = [ACQueueSnapshot read:usbRaw device:device queue:@"USBDiskQueue"];
                    ACApplyUSBHighlight(usb, status);
                    if (usb.rows.count) finish(usb, nil);
                    else readSDK();
                });
            });
        });
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 20 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        finish(nil, @"Очередь не ответила");
    });
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if ([_queue isEqualToString:@"USBDiskQueue"] && _snapshot.rows.count)
        return MAX([self visibleUSBEntries].count + (_usbFolderPath.length ? 1 : 0), 1);
    return MAX(_snapshot.rows.count, 1);
}
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (!_snapshot.rows.count) return nil;
    NSString *title = _snapshot.heading ?: @"";
    if ([_queue isEqualToString:@"USBDiskQueue"] && _usbFolderPath.length) title = [NSString stringWithFormat:@"%@ / %@", title, _usbFolderPath];
    return [NSString stringWithFormat:@"%@  ·  %lu", title, (unsigned long)_snapshot.rows.count];
}
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)p {
    if (!_snapshot.rows.count) return ACCell(_state, nil, @"info.circle");
    if ([_queue isEqualToString:@"USBDiskQueue"]) {
        BOOL hasBack = _usbFolderPath.length > 0;
        if (hasBack && p.row == 0) return ACCell(@"Назад в папку USB", _usbFolderPath, @"arrow.uturn.backward");
        NSArray<NSDictionary *> *entries = [self visibleUSBEntries];
        NSUInteger rowIndex = p.row - (hasBack ? 1 : 0);
        if (rowIndex >= entries.count) return ACCell(@"В этой папке нет файлов", nil, @"info.circle");
        NSDictionary *entry = entries[rowIndex];
        if (entry[@"folder"]) return ACCell(entry[@"folder"], @"Папка", @"folder");
        NSUInteger originalIndex = [entry[@"index"] unsignedIntegerValue];
        BOOL active = _snapshot.active == originalIndex;
        UITableViewCell *cell = ACCell(entry[@"title"], entry[@"detail"], active ? @"waveform" : @"music.note");
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        if (active) cell.textLabel.textColor = ACAccent();
        return cell;
    }
    NSArray *item = _snapshot.rows[p.row];
    BOOL active = _snapshot.active == p.row;
    UITableViewCell *cell = ACCell(item[0], item[1], active ? @"waveform" : @"music.note");
    if (active) {
        cell.textLabel.textColor = ACAccent();
        cell.backgroundColor = [ACAccent() colorWithAlphaComponent:.14];
        cell.accessibilityTraits |= UIAccessibilityTraitSelected;
    }
    BOOL isUSB = [_queue isEqualToString:@"USBDiskQueue"];
    cell.selectionStyle = isUSB ? UITableViewCellSelectionStyleDefault : UITableViewCellSelectionStyleNone;
    if (isUSB) cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (![_queue isEqualToString:@"USBDiskQueue"] || _startingUSB || !_snapshot.rows.count) return;
    BOOL hasBack = _usbFolderPath.length > 0;
    if (hasBack && indexPath.row == 0) {
        NSArray<NSString *> *parts = [_usbFolderPath componentsSeparatedByString:@"/"];
        _usbFolderPath = parts.count > 1 ? [[parts subarrayWithRange:NSMakeRange(0, parts.count - 1)] componentsJoinedByString:@"/"] : @"";
        [self.tableView reloadData]; return;
    }
    NSArray<NSDictionary *> *entries = [self visibleUSBEntries];
    NSUInteger visibleIndex = indexPath.row - (hasBack ? 1 : 0);
    if (visibleIndex >= entries.count) return;
    NSDictionary *entry = entries[visibleIndex];
    NSString *folderName = entry[@"folder"];
    if (folderName.length) {
        _usbFolderPath = _usbFolderPath.length ? [_usbFolderPath stringByAppendingFormat:@"/%@", folderName] : folderName;
        [self.tableView reloadData]; return;
    }
    NSUInteger trackIndex = [entry[@"index"] unsignedIntegerValue];
    LPDevice *online = [[LPDeviceManager sharedInstance] deviceForID:_device.deviceStatus.UUID];
    LPDevicePlayer *player = [online getPlayer];
    if (!player) return;
    _startingUSB = YES;
    NSUInteger request = ++_usbRequest;
    __weak typeof(self) weakSelf = self;
    LPPlayerBlock finish = ^(BOOL success, NSString *result) {
        dispatch_async(dispatch_get_main_queue(), ^{
            typeof(self) self = weakSelf;
            if (!self || !self->_startingUSB || self->_usbRequest != request) return;
            self->_startingUSB = NO;
            if (success && self.navigationController.topViewController == self) {
                if (trackIndex < self->_snapshot.rows.count) {
                    self->_snapshot.active = trackIndex;
                    [self.tableView reloadData];
                }
                [online.deviceInfo updateCurrentPlayInfo];
                return;
            }
            if (!success && self.navigationController.topViewController == self && !self.presentedViewController) {
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"USB-трек не запущен" message:nil preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
                [self presentViewController:alert animated:YES completion:nil];
            }
        });
    };
    [player playUSBSongsWithIndex:(int)trackIndex completionHandler:finish];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{ finish(NO, nil); });
}
@end

@interface ACNowPlaying : ACTransportScreen
- (instancetype)initWithStore:(ACStore *)store;
@end

static NSString *ACNowPlayingSourceName(LPDevice *device) {
    if (!device) return ACMenuText(@"Сейчас играет");
    LPMediaInfo *media = device.mediaInfo;
    NSString *source = ACText(media.trackSource) ?: @"";
    NSString *type = ACText(media.mediaType) ?: @"";
    NSString *description = ACText(media.typeDescription) ?: @"";
    NSString *url = ACText(media.url) ?: @"";
    NSString *facts = [[NSString stringWithFormat:@"%@ %@ %@ %@", source, type, description, url] lowercaseString];
    NSArray<NSArray<NSString *> *> *services = @[
        @[@"radio browser", @"radiobrowser", @"Radio Browser"],
        @[@"tunein", @"newtunein", @"TuneIn"],
        @[@"qobuz", @"Qobuz"],
        @[@"deezer", @"Deezer"],
        @[@"tidal", @"TIDAL"],
        @[@"youtube music", @"youtubemusic", @"YouTube Music"],
        @[@"soundcloud", @"SoundCloud"]
    ];
    for (NSArray<NSString *> *service in services) {
        for (NSUInteger i = 0; i + 1 < service.count; i++)
            if ([facts containsString:service[i]]) return ACMenuText(service.lastObject);
    }
    if ([facts containsString:@"airplay"] || [type caseInsensitiveCompare:MEDIATYPE_AIRPLAY] == NSOrderedSame)
        return ACMenuText(@"AirPlay");
    if ([facts containsString:@"usb"] || [facts containsString:@"usbdisk"] || [facts containsString:@"usbdiskqueue"])
        return ACMenuText(@"USB");
    if (media.isLive || [facts containsString:@"radio"] || [facts containsString:@"vtuner"])
        return ACMenuText(@"Радио");
    switch (device.deviceStatus.currentInputMode) {
        case LPLineIn: return ACMenuText(@"Линейный вход");
        case LPBluetooth: return ACMenuText(@"Bluetooth");
        case LPUSB: return ACMenuText(@"USB");
        case LPRadio: return ACMenuText(@"Радио");
        case LPOptical: return ACMenuText(@"Оптический вход");
        default: break;
    }
    if (source.length && ![@[@"wifi", @"unknown"] containsObject:source.lowercaseString]) return source;
    return ACMenuText(@"Сейчас играет");
}

@implementation ACNowPlaying {
    ACStore *_store;
    NSString *_identity, *_coverURL;
    NSTimer *_timer;
    BOOL _transportPending;
    BOOL _positionInitialized, _positionWasPlaying;
    NSTimeInterval _positionAnchor, _positionAnchorUptime, _lastReportedPosition;
    NSString *_positionTrackKey;
    float _pendingVolume;
    NSTimeInterval _volumeDeadline;
    NSUInteger _command;
}
- (instancetype)initWithStore:(ACStore *)store {
    if ((self = [super init])) { _store = store; _identity = store.selectedID; self.title = ACMenuText(@"Сейчас играет"); }
    return self;
}
- (LPDevice *)device { return [_store.selectedID isEqualToString:_identity] ? _store.selected : nil; }
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self render];
    __weak typeof(self) weakSelf = self;
    LPDevice *device = self.device;
    void (^refresh)(id, id, NSDictionary *) = ^(id observer, id object, NSDictionary *change) {
        dispatch_async(dispatch_get_main_queue(), ^{
            typeof(self) self = weakSelf;
            if (self && self->_timer) [self render];
        });
    };
    [self.KVOController observe:device.deviceStatus keyPath:@"volume" options:NSKeyValueObservingOptionNew block:refresh];
    [self.KVOController observe:device.deviceInfo keyPath:@"playStatus" options:NSKeyValueObservingOptionNew block:refresh];
    [self.KVOController observe:device.mediaInfo keyPaths:@[@"title", @"artist", @"artworkUri", @"artwork", @"trackSource", @"mediaType", @"metaDataString"]
                         options:NSKeyValueObservingOptionNew block:refresh];
    // Poll SDK state once per second, but render the progress between device
    // reports using the local monotonic clock so coarse 5 s updates look smooth.
    _timer = [NSTimer scheduledTimerWithTimeInterval:.25 repeats:YES block:^(NSTimer *timer) { [weakSelf render]; }];
}
- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated]; [_timer invalidate]; _timer = nil;
    [self.KVOController unobserveAll];
}
- (void)render {
    LPDevice *d = self.device;
    LPDeviceStatus *status = d.deviceStatus;
    NSString *trackTitle = ACText(d.mediaInfo.title);
    NSString *trackArtist = ACText(d.mediaInfo.artist);
    _track.text = trackTitle ?: (d ? @"Нет данных о треке" : @"Устройство недоступно");
    _artist.text = trackArtist ?: (d ? ACName(d) : @"");
    // Keep the playback origin visible above the artwork, including AirPlay
    // and streaming services whose device input mode is reported as Wi-Fi.
    _sourceLabel.text = ACNowPlayingSourceName(d);
    NSTimeInterval duration = status.trackDuration;
    BOOL playing = d.deviceInfo && d.deviceInfo.playStatus == LP_PLAYER_STATE_PLAYING;
    NSTimeInterval now = NSProcessInfo.processInfo.systemUptime;
    NSTimeInterval reportedPosition = MAX(0, status.relativeTime);
    NSString *trackKey = [NSString stringWithFormat:@"%@|%@|%@|%@", trackTitle ?: @"", trackArtist ?: @"",
        d.mediaInfo.album ?: @"", d.mediaInfo.trackSource ?: @""];
    BOOL trackChanged = !_positionTrackKey || ![_positionTrackKey isEqualToString:trackKey];
    NSTimeInterval predictedPosition = _positionAnchor + (_positionWasPlaying ? MAX(0, now - _positionAnchorUptime) : 0);
    BOOL serverPositionChanged = !_positionInitialized || fabs(reportedPosition - _lastReportedPosition) > .4;
    if (!_positionInitialized || trackChanged || playing != _positionWasPlaying ||
        (!playing && serverPositionChanged) ||
        (serverPositionChanged && fabs(reportedPosition - predictedPosition) > 1.75)) {
        _positionAnchor = reportedPosition;
        _positionAnchorUptime = now;
        _positionInitialized = YES;
    }
    _lastReportedPosition = reportedPosition;
    _positionTrackKey = trackKey;
    _positionWasPlaying = playing;
    NSTimeInterval displayedPosition = _positionAnchor + (playing ? MAX(0, now - _positionAnchorUptime) : 0);
    if (duration > 0) displayedPosition = MIN(duration, displayedPosition);
    if (!_seek.tracking) _seek.value = duration > 0 ? MIN(1, MAX(0, displayedPosition / duration)) : 0;
    float reportedVolume = MIN(100, MAX(0, status.volume));
    if (!d || reportedVolume == _pendingVolume) _volumeDeadline = 0;
    if (!_volume.tracking)
        _volume.value = now < _volumeDeadline ? _pendingVolume : reportedVolume;
    _clock.text = [NSString stringWithFormat:@"%@ / %@", ACTime(displayedPosition), ACTime(duration)];
    _volumeText.text = d ? [NSString stringWithFormat:@"%@ · %.0f%%", ACMenuText(@"Громкость"), _volume.value] : ACMenuText(@"Громкость");
    _seek.enabled = d && duration > 0 && !d.mediaInfo.isLive && !_transportPending;
    _volume.enabled = d != nil;
    UIButtonConfiguration *config = _toggle.configuration;
    config.image = [UIImage systemImageNamed:playing ? @"pause.fill" : @"play.fill"];
    _toggle.configuration = config; _toggle.accessibilityLabel = playing ? @"Пауза" : @"Воспроизвести";
    _toggle.enabled = _previous.enabled = _next.enabled = d != nil && !_transportPending;
    _repeatButton.enabled = d != nil && !_transportPending;
    BOOL repeatingTrack = d.deviceInfo.playMode == LP_SINGLEREPEAT;
    UIButtonConfiguration *repeatConfig = _repeatButton.configuration;
    repeatConfig.image = [UIImage systemImageNamed:repeatingTrack ? @"repeat.1" : @"repeat"];
    repeatConfig.baseForegroundColor = repeatingTrack ? ACAccent() : ACSecondaryText();
    _repeatButton.configuration = repeatConfig;
    _queueButton.enabled = d.deviceInfo != nil;
    NSString *artwork = ACText(d.mediaInfo.artworkUri);
    if ([artwork caseInsensitiveCompare:@"un_known"] == NSOrderedSame ||
        [artwork caseInsensitiveCompare:@"null"] == NSOrderedSame) artwork = nil;
    NSString *metadata = d.mediaInfo.metaDataString;
    DDXMLDocument *didl = nil;
    if (!artwork && metadata.length && metadata.length < 256000 &&
        [metadata rangeOfString:@"<!DOCTYPE" options:NSCaseInsensitiveSearch].location == NSNotFound) {
        didl = [[DDXMLDocument alloc] initWithXMLString:metadata options:0 error:nil];
        artwork = ACDIDL(didl, @"albumArtURI");
    }
    if (!didl && metadata.length && metadata.length < 256000 && [metadata rangeOfString:@"<!DOCTYPE" options:NSCaseInsensitiveSearch].location == NSNotFound)
        didl = [[DDXMLDocument alloc] initWithXMLString:metadata options:0 error:nil];
    _quality.text = [self audioQualityFromDIDL:didl];
    _quality.hidden = _quality.text.length == 0;
    if ([artwork hasPrefix:@"/"] && ![artwork hasPrefix:@"//"] && d.deviceStatus.IP.length) {
        NSURLComponents *origin = [NSURLComponents new];
        origin.scheme = @"http";
        origin.host = d.deviceStatus.IP;
        artwork = [NSURL URLWithString:artwork relativeToURL:origin.URL].absoluteString;
    }
    artwork = ACDeezerImageURL(artwork, 0) ?: artwork;
    NSURL *artURL = ACStreamURL(artwork);
    NSString *rememberedArtwork = ACDeezerRememberedArtwork(ACDeviceID(d), trackTitle, trackArtist, ACDIDL(didl, @"id"));
    // Catalog responses contain the larger Deezer artwork variants. Prefer
    // that cached high-resolution URL over the low-resolution renderer URI.
    if (ACStreamURL(rememberedArtwork)) artwork = rememberedArtwork;
    else if (!artURL) artwork = nil;
    UIImage *sdkArtwork = d.mediaInfo.artwork;
    NSString *sourceFacts = [[NSString stringWithFormat:@"%@ %@ %@", d.mediaInfo.trackSource ?: @"", d.mediaInfo.mediaType ?: @"", d.mediaInfo.typeDescription ?: @""] lowercaseString];
    BOOL airPlaySource = [sourceFacts containsString:@"airplay"] || [d.mediaInfo.mediaType caseInsensitiveCompare:MEDIATYPE_AIRPLAY] == NSOrderedSame;
    if (airPlaySource && sdkArtwork) {
        if (![_coverURL isEqualToString:@"__sdk_artwork__"]) {
            _coverURL = @"__sdk_artwork__";
            [_cover sd_cancelCurrentImageLoad];
            _cover.image = sdkArtwork;
        } else if (_cover.image != sdkArtwork) {
            _cover.image = sdkArtwork;
        }
    } else if (artwork.length) [self showCover:artwork];
    else if (sdkArtwork) {
        if (![_coverURL isEqualToString:@"__sdk_artwork__"]) {
            _coverURL = @"__sdk_artwork__";
            [_cover sd_cancelCurrentImageLoad];
            _cover.image = sdkArtwork;
        } else if (_cover.image != sdkArtwork) _cover.image = sdkArtwork;
    } else {
        [self showCover:@""];
    }
}
- (NSString *)audioQualityFromDIDL:(DDXMLDocument *)didl {
    DDXMLNode *resource = ACNodes(didl, @".//*[local-name()='res']").firstObject;
    if (!resource) return nil;
    DDXMLElement *element = (DDXMLElement *)resource;
    NSString *bitrateText = [element attributeForName:@"bitrate"].stringValue;
    NSString *sampleText = [element attributeForName:@"sampleFrequency"].stringValue;
    NSString *bitsText = [element attributeForName:@"bitsPerSample"].stringValue;
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    double bitrate = bitrateText.doubleValue;
    if (bitrate > 0 && isfinite(bitrate)) {
        double kbps = bitrate > 10000 ? bitrate / 1000.0 : bitrate;
        [parts addObject:[NSString stringWithFormat:@"%.0f kbps", kbps]];
    }
    double sampleRate = sampleText.doubleValue;
    if (sampleRate > 0 && isfinite(sampleRate))
        [parts addObject:[NSString stringWithFormat:@"%.1f kHz", sampleRate > 1000 ? sampleRate / 1000.0 : sampleRate]];
    NSInteger bits = bitsText.integerValue;
    if (bits > 0 && bits <= 64) [parts addObject:[NSString stringWithFormat:@"%ld-bit", (long)bits]];
    return parts.count ? [parts componentsJoinedByString:@" · "] : nil;
}
- (void)showCover:(NSString *)value {
    value = value ?: @"";
    if ([_coverURL isEqualToString:value]) return;
    _coverURL = [value copy];
    NSURLComponents *parts = [NSURLComponents componentsWithString:value];
    NSString *scheme = parts.scheme.lowercaseString;
    BOOL valid = ([@[@"https", @"http"] containsObject:scheme] && parts.host.length && !parts.user && !parts.password);
    [_cover sd_setImageWithURL:valid ? parts.URL : nil placeholderImage:[UIImage systemImageNamed:@"music.note"]
                       options:SDWebImageRetryFailed | SDWebImageHighPriority];
}
- (void)issue:(void (^)(LPDevicePlayer *, LPPlayerBlock))command {
    LPDevicePlayer *player = [self.device getPlayer];
    if (!player || _transportPending) return;
    _transportPending = YES; NSUInteger serial = ++_command; [self render];
    __weak typeof(self) weakSelf = self;
    LPPlayerBlock finish = ^(BOOL success, NSString *result) {
        dispatch_async(dispatch_get_main_queue(), ^{
            typeof(self) self = weakSelf;
            if (!self || self->_command != serial) return;
            self->_command++;
            self->_transportPending = NO;
            if (success) [self.device.deviceInfo updateCurrentPlayInfo];
            [self render];
            if (!success && self.view.window) {
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Команда не подтверждена" message:nil preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
                [self presentViewController:alert animated:YES completion:nil];
            }
        });
    };
    command(player, finish);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{ finish(NO, nil); });
}
- (void)toggle {
    BOOL playing = self.device.deviceInfo && self.device.deviceInfo.playStatus == LP_PLAYER_STATE_PLAYING;
    [self issue:^(LPDevicePlayer *p, LPPlayerBlock done) { if (playing) [p pause:done]; else [p play:done]; }];
}
- (void)previous { [self issue:^(LPDevicePlayer *p, LPPlayerBlock done) { [p previous:done]; }]; }
- (void)next { [self issue:^(LPDevicePlayer *p, LPPlayerBlock done) { [p next:done]; }]; }
- (void)volume:(UISlider *)sender {
    LPDevicePlayer *player = [self.device getPlayer];
    if (!player) return;
    _pendingVolume = roundf(sender.value);
    _volumeDeadline = NSProcessInfo.processInfo.systemUptime + 4;
    [player setVolume:_pendingVolume];
}
- (void)seek:(UISlider *)sender {
    LPDevice *d = self.device;
    if (!d || d.deviceStatus.trackDuration <= 0 || d.mediaInfo.isLive) return;
    NSTimeInterval time = sender.value * d.deviceStatus.trackDuration;
    _positionAnchor = time;
    _positionAnchorUptime = NSProcessInfo.processInfo.systemUptime;
    _positionWasPlaying = d.deviceInfo && d.deviceInfo.playStatus == LP_PLAYER_STATE_PLAYING;
    _positionInitialized = YES;
    [self issue:^(LPDevicePlayer *p, LPPlayerBlock done) { [p setProgress:time completionHandler:done]; }];
}
- (void)showQueue {
    LPDevice *device = self.device;
    if (!device) return;
    [self.navigationController pushViewController:[[ACQueueController alloc] initWithDevice:device
        queue:@"CurrentQueue" title:@"Текущая очередь"] animated:YES];
}
- (void)repeatTrack {
    LPDevice *device = self.device;
    LPDevicePlayer *player = [device getPlayer];
    if (!player) return;
    BOOL repeatEnabled = device.deviceInfo.playMode == LP_SINGLEREPEAT;
    LPPlayMode mode = repeatEnabled ? LP_DEFAULT : LP_SINGLEREPEAT;
    [player setPlayMode:mode completionHandler:^(BOOL success, NSString *result) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (success) {
                device.deviceInfo.playMode = mode;
                [self render];
            } else if (self.view.window && !self.presentedViewController) {
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Не удалось изменить повтор"
                    message:result.length ? result : nil preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
                [self presentViewController:alert animated:YES completion:nil];
            }
        });
    }];
}
- (void)showMore {
    LPDevice *device = self.device;
    if (!device) return;
    UIAlertController *menu = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    [menu addAction:[UIAlertAction actionWithTitle:ACMenuText(@"Пресеты") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        PresetViewController *presets = [PresetViewController new];
        presets.deviceId = device.deviceStatus.UUID;
        [self.navigationController pushViewController:presets animated:YES];
    }]];
    [menu addAction:[UIAlertAction actionWithTitle:ACMenuText(@"Будильник") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        AlarmClockMainViewController *alarms = [AlarmClockMainViewController new];
        alarms.deviceId = device.deviceStatus.UUID;
        [self.navigationController pushViewController:alarms animated:YES];
    }]];
    [menu addAction:[UIAlertAction actionWithTitle:ACMenuText(@"Таймер сна · 30 минут") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [[device getTimer] setTimerWithTime:1800 completionHandler:^(NSURLResponse *response, id result, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                UIAlertController *notice = [UIAlertController alertControllerWithTitle:ACMenuText(error ? @"Таймер не установлен" : @"Таймер сна")
                    message:error.localizedDescription preferredStyle:UIAlertControllerStyleAlert];
                [notice addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
                if (self.view.window && !self.presentedViewController) [self presentViewController:notice animated:YES completion:nil];
            });
        }];
    }]];
    [menu addAction:[UIAlertAction actionWithTitle:ACMenuText(@"Эквалайзер") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [device.deviceSettings getSupportEQAndValues:^(NSURLResponse *response, id result, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSMutableArray<NSString *> *lines = [NSMutableArray array];
                if ([result isKindOfClass:NSDictionary.class]) {
                    NSDictionary *eq = result;
                    for (NSString *key in @[@"Mode", @"Bass", @"Treble", @"EQEnable"]) {
                        id value = eq[key];
                        if ([value isKindOfClass:NSString.class] || [value isKindOfClass:NSNumber.class])
                            [lines addObject:[NSString stringWithFormat:@"%@ · %@", key, value]];
                    }
                    id bands = eq[@"EQValue"];
                    if ([bands isKindOfClass:NSArray.class]) for (id band in bands) {
                        if (![band isKindOfClass:NSDictionary.class]) continue;
                        id name = band[@"Name"], value = band[@"Value"];
                        if (name && value) [lines addObject:[NSString stringWithFormat:@"%@ · %@", name, value]];
                    }
                }
                UIAlertController *notice = [UIAlertController alertControllerWithTitle:@"Эквалайзер"
                    message:lines.count ? [lines componentsJoinedByString:@"\n"] : (error.localizedDescription ?: @"Эквалайзер не вернул настройки.")
                    preferredStyle:UIAlertControllerStyleAlert];
                [notice addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
                if (self.view.window && !self.presentedViewController) [self presentViewController:notice animated:YES completion:nil];
            });
        }];
    }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"Отмена" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:menu animated:YES completion:nil];
}
@end

typedef NS_ENUM(NSUInteger, ACSection) { ACBrowse, ACDevices, ACSettings };

@interface ACPage : UITableViewController
- (instancetype)initWithStore:(ACStore *)store section:(ACSection)section;
- (void)setVolume:(float)value forDeviceID:(NSString *)deviceID;
- (void)togglePlaybackForDeviceID:(NSString *)deviceID;
- (void)openMultiroomForDeviceID:(NSString *)deviceID;
- (void)openSettingsForDeviceID:(NSString *)deviceID;
- (void)chooseMusicForDeviceID:(NSString *)deviceID;
@end

@interface ACDeviceCardCell : UITableViewCell
@property(nonatomic, copy) void (^onSelect)(void);
@property(nonatomic, copy) void (^onLink)(void);
@property(nonatomic, copy) void (^onTogglePlayback)(void);
@property(nonatomic, copy) void (^onChooseMusic)(void);
@property(nonatomic, copy) void (^onSettings)(void);
@property(nonatomic, copy) void (^onVolume)(float volume);
- (void)configureDevice:(LPDevice *)device online:(BOOL)online selected:(BOOL)selected multiroomMember:(BOOL)member master:(BOOL)master;
- (void)configureLAN:(NSString *)name subtitle:(NSString *)subtitle selected:(BOOL)selected;
@end

@implementation ACDeviceCardCell {
    UILabel *_name, *_track, *_subtitle, *_volumeValue;
    UIImageView *_artwork;
    UIView *_statusDot;
    UIButton *_link, *_musicButton, *_playPause, *_settingsButton;
    ACThinSlider *_volumeSlider;
    LPDevice *_device;
    BOOL _selected, _online, _lan;
    NSString *_coverURL;
}
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.backgroundColor = UIColor.clearColor;
        self.contentView.backgroundColor = ACCard();
        self.contentView.layer.cornerRadius = 22;
        self.contentView.layer.masksToBounds = YES;
        _name = [UILabel new]; _name.font = [UIFont systemFontOfSize:18 weight:UIFontWeightSemibold]; _name.textColor = ACPrimaryText();
        _track = [UILabel new]; _track.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium]; _track.textColor = ACPrimaryText(); _track.numberOfLines = 1;
        _subtitle = [UILabel new]; _subtitle.font = [UIFont systemFontOfSize:13]; _subtitle.textColor = ACSecondaryText(); _subtitle.numberOfLines = 1;
        _artwork = [UIImageView new]; _artwork.backgroundColor = [UIColor colorWithWhite:.16 alpha:1]; _artwork.tintColor = ACSecondaryText();
        _artwork.contentMode = UIViewContentModeScaleAspectFill; _artwork.clipsToBounds = YES; _artwork.layer.cornerRadius = 9;
        _link = [UIButton buttonWithType:UIButtonTypeSystem]; [_link setImage:[UIImage systemImageNamed:@"link"] forState:UIControlStateNormal]; _link.tintColor = ACPrimaryText();
        _link.accessibilityLabel = @"Настроить Multiroom для этой зоны";
        [_link addTarget:self action:@selector(linkDevice) forControlEvents:UIControlEventTouchUpInside];
        _statusDot = [UIView new]; _statusDot.backgroundColor = ACStatusAccent(); _statusDot.layer.cornerRadius = 4;
        _musicButton = [UIButton buttonWithType:UIButtonTypeSystem];
        UIButtonConfiguration *musicConfig = [UIButtonConfiguration filledButtonConfiguration];
        musicConfig.title = ACMenuText(@"Выбрать музыку"); musicConfig.image = [UIImage systemImageNamed:@"chevron.right"];
        musicConfig.imagePlacement = NSDirectionalRectEdgeTrailing; musicConfig.imagePadding = 8;
        musicConfig.baseBackgroundColor = ACAccent();
        musicConfig.baseForegroundColor = UIColor.blackColor; musicConfig.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        musicConfig.contentInsets = NSDirectionalEdgeInsetsMake(5, 12, 5, 12); _musicButton.configuration = musicConfig;
        [_musicButton addTarget:self action:@selector(chooseMusic) forControlEvents:UIControlEventTouchUpInside];
        _playPause = [UIButton buttonWithType:UIButtonTypeSystem]; [_playPause setImage:[UIImage systemImageNamed:@"pause.fill"] forState:UIControlStateNormal];
        _playPause.tintColor = UIColor.whiteColor; _playPause.backgroundColor = [ACAccent() colorWithAlphaComponent:.25];
        _playPause.accessibilityLabel = @"Пауза или воспроизведение";
        _playPause.layer.cornerRadius = 17; [_playPause addTarget:self action:@selector(togglePlayback) forControlEvents:UIControlEventTouchUpInside];
        _settingsButton = [UIButton buttonWithType:UIButtonTypeSystem]; [_settingsButton setImage:[UIImage systemImageNamed:@"gearshape"] forState:UIControlStateNormal];
        _settingsButton.accessibilityLabel = @"Настройки устройства";
        _settingsButton.tintColor = ACPrimaryText(); [_settingsButton addTarget:self action:@selector(openSettings) forControlEvents:UIControlEventTouchUpInside];
        _volumeSlider = [ACThinSlider new]; _volumeSlider.minimumValue = 0; _volumeSlider.maximumValue = 100;
        _volumeSlider.minimumTrackTintColor = ACAccent(); _volumeSlider.maximumTrackTintColor = [UIColor colorWithWhite:.3 alpha:1]; _volumeSlider.thumbTintColor = UIColor.whiteColor;
        [_volumeSlider addTarget:self action:@selector(volumePreview:) forControlEvents:UIControlEventValueChanged];
        [_volumeSlider addTarget:self action:@selector(volumeChanged:) forControlEvents:UIControlEventTouchUpInside];
        [_volumeSlider addTarget:self action:@selector(volumeChanged:) forControlEvents:UIControlEventTouchUpOutside];
        _volumeValue = [UILabel new]; _volumeValue.font = [UIFont monospacedDigitSystemFontOfSize:13 weight:UIFontWeightMedium]; _volumeValue.textColor = ACSecondaryText(); _volumeValue.textAlignment = NSTextAlignmentRight;

        for (UIView *view in @[_name, _link, _statusDot, _artwork, _track, _subtitle, _musicButton, _playPause, _volumeSlider, _volumeValue, _settingsButton]) {
            view.translatesAutoresizingMaskIntoConstraints = NO; [self.contentView addSubview:view];
        }
        UILayoutGuide *g = self.contentView.layoutMarginsGuide;
        [NSLayoutConstraint activateConstraints:@[
            [_name.topAnchor constraintEqualToAnchor:g.topAnchor constant:3], [_name.leadingAnchor constraintEqualToAnchor:_statusDot.trailingAnchor constant:8], [_name.trailingAnchor constraintLessThanOrEqualToAnchor:_playPause.leadingAnchor constant:-8],
            [_statusDot.leadingAnchor constraintEqualToAnchor:g.leadingAnchor], [_statusDot.centerYAnchor constraintEqualToAnchor:_name.centerYAnchor], [_statusDot.widthAnchor constraintEqualToConstant:8], [_statusDot.heightAnchor constraintEqualToConstant:8],
            [_link.centerYAnchor constraintEqualToAnchor:_name.centerYAnchor], [_link.trailingAnchor constraintEqualToAnchor:g.trailingAnchor], [_link.widthAnchor constraintEqualToConstant:38], [_link.heightAnchor constraintEqualToConstant:38],
            [_artwork.topAnchor constraintEqualToAnchor:_name.bottomAnchor constant:9], [_artwork.leadingAnchor constraintEqualToAnchor:g.leadingAnchor], [_artwork.widthAnchor constraintEqualToConstant:76], [_artwork.heightAnchor constraintEqualToConstant:76],
            [_track.topAnchor constraintEqualToAnchor:_artwork.topAnchor constant:8], [_track.leadingAnchor constraintEqualToAnchor:_artwork.trailingAnchor constant:14], [_track.trailingAnchor constraintLessThanOrEqualToAnchor:g.trailingAnchor],
            [_subtitle.topAnchor constraintEqualToAnchor:_track.bottomAnchor constant:5], [_subtitle.leadingAnchor constraintEqualToAnchor:_track.leadingAnchor], [_subtitle.trailingAnchor constraintLessThanOrEqualToAnchor:g.trailingAnchor],
        [_musicButton.topAnchor constraintEqualToAnchor:_subtitle.bottomAnchor constant:2], [_musicButton.leadingAnchor constraintEqualToAnchor:_track.leadingAnchor], [_musicButton.heightAnchor constraintGreaterThanOrEqualToConstant:30],
            [_playPause.centerYAnchor constraintEqualToAnchor:_name.centerYAnchor], [_playPause.trailingAnchor constraintEqualToAnchor:_link.leadingAnchor constant:-4], [_playPause.widthAnchor constraintEqualToConstant:34], [_playPause.heightAnchor constraintEqualToConstant:34],
            [_volumeSlider.topAnchor constraintEqualToAnchor:_artwork.bottomAnchor constant:13], [_volumeSlider.leadingAnchor constraintEqualToAnchor:g.leadingAnchor],
            [_volumeSlider.centerYAnchor constraintEqualToAnchor:_settingsButton.centerYAnchor], [_volumeValue.centerYAnchor constraintEqualToAnchor:_volumeSlider.centerYAnchor],
            [_volumeValue.leadingAnchor constraintEqualToAnchor:_volumeSlider.trailingAnchor constant:8], [_volumeValue.widthAnchor constraintEqualToConstant:32],
            [_settingsButton.leadingAnchor constraintEqualToAnchor:_volumeValue.trailingAnchor constant:10], [_settingsButton.trailingAnchor constraintEqualToAnchor:g.trailingAnchor], [_settingsButton.widthAnchor constraintEqualToConstant:36], [_settingsButton.heightAnchor constraintEqualToConstant:36],
            [_volumeSlider.bottomAnchor constraintEqualToAnchor:g.bottomAnchor constant:-3]
        ]];
    }
    return self;
}
- (void)prepareForReuse {
    [super prepareForReuse]; _device = nil; _selected = NO; _lan = NO; _coverURL = nil;
    self.onSelect = self.onLink = self.onTogglePlayback = self.onChooseMusic = self.onSettings = nil; self.onVolume = nil;
}
- (void)configureDevice:(LPDevice *)device online:(BOOL)online selected:(BOOL)selected multiroomMember:(BOOL)member master:(BOOL)master {
    _device = device; _online = online; _selected = selected; _lan = NO;
    self.contentView.layer.borderWidth = 0.75;
    self.contentView.layer.borderColor = [UIColor colorWithWhite:.25 alpha:1].CGColor;
    _volumeSlider.hidden = _volumeValue.hidden = _settingsButton.hidden = NO;
    _artwork.hidden = _track.hidden = _subtitle.hidden = _link.hidden = NO;
    _name.text = master ? [ACName(device) stringByAppendingString:@" · Мастер"] : ACName(device);
    NSString *currentTitle = ACText(device.mediaInfo.title);
    _track.text = currentTitle ?: ACMenuText(@"Нет выбранной музыки");
    _subtitle.text = ACText(device.mediaInfo.artist) ?: @"";
    _volumeSlider.value = MIN(100, MAX(0, device.deviceStatus.volume)); _volumeValue.text = [NSString stringWithFormat:@"%.0f", _volumeSlider.value];
    _volumeSlider.enabled = online; _settingsButton.enabled = online; _link.alpha = online ? 1 : .45;
    _statusDot.backgroundColor = online ? ACStatusAccent() : [UIColor colorWithRed:1 green:.29 blue:.35 alpha:1];
    BOOL playing = selected && device.deviceInfo && device.deviceInfo.playStatus == LP_PLAYER_STATE_PLAYING;
    // Keep green for connectivity only; the selected zone gets a subtle charcoal lift.
    self.contentView.backgroundColor = selected ? [UIColor colorWithWhite:(playing ? .15 : .12) alpha:1] : ACCard();
    [_playPause setImage:[UIImage systemImageNamed:playing ? @"pause.fill" : @"play.fill"] forState:UIControlStateNormal];
    _playPause.hidden = !selected || !online || !currentTitle.length;
    _musicButton.hidden = currentTitle.length > 0;
    _artwork.image = [UIImage systemImageNamed:@"music.note"];
    NSString *art = ACText(device.mediaInfo.artworkUri);
    NSURL *url = ACStreamURL(art);
    if (url) {
        _coverURL = url.absoluteString;
        [_artwork sd_setImageWithURL:url placeholderImage:[UIImage systemImageNamed:@"music.note"]
                             options:SDWebImageRetryFailed | SDWebImageHighPriority];
    } else { [_artwork sd_cancelCurrentImageLoad]; _coverURL = nil; }
}
- (void)configureLAN:(NSString *)name subtitle:(NSString *)subtitle selected:(BOOL)selected {
    _device = nil; _online = YES; _selected = selected; _lan = YES;
    self.contentView.layer.borderWidth = 0;
    self.contentView.layer.borderColor = UIColor.clearColor.CGColor;
    _volumeSlider.hidden = _volumeValue.hidden = _settingsButton.hidden = YES;
    _artwork.hidden = _track.hidden = _subtitle.hidden = _link.hidden = NO;
    _name.text = name; _track.text = selected ? @"Открыть управление" : @"Устройство в локальной сети";
    _statusDot.backgroundColor = ACStatusAccent();
    _subtitle.text = subtitle; _volumeSlider.hidden = _volumeValue.hidden = _settingsButton.hidden = YES;
    _artwork.image = [UIImage systemImageNamed:@"hifispeaker.fill"]; _playPause.hidden = YES; _musicButton.hidden = YES;
}
- (void)selectDevice { if (self.onSelect) self.onSelect(); }
- (void)linkDevice { if (self.onLink) self.onLink(); }
- (void)chooseMusic { if (self.onChooseMusic) self.onChooseMusic(); }
- (void)togglePlayback { if (self.onTogglePlayback) self.onTogglePlayback(); }
- (void)openSettings { if (self.onSettings) self.onSettings(); }
- (void)volumePreview:(UISlider *)sender { _volumeValue.text = [NSString stringWithFormat:@"%.0f", sender.value]; }
- (void)volumeChanged:(UISlider *)sender { [self volumePreview:sender]; if (self.onVolume) self.onVolume(sender.value); }
@end

@interface ACMultiroomGroupCell : UITableViewCell
@property(nonatomic, copy) void (^onLink)(void);
@property(nonatomic, copy) void (^onVolume)(LPDevice *device, float value);
@property(nonatomic, copy) void (^onSettings)(LPDevice *device);
- (void)configureMaster:(LPDevice *)master members:(NSArray<LPDevice *> *)members selected:(BOOL)selected online:(BOOL)online;
@end

@implementation ACMultiroomGroupCell {
    UILabel *_title, *_track, *_artist, *_groupVolumeLabel, *_groupVolumeValue;
    UIImageView *_art;
    UIStackView *_membersStack;
    UISlider *_groupSlider;
    UIButton *_link;
    CAShapeLayer *_cardBorderLayer;
    LPDevice *_master;
    NSArray<LPDevice *> *_members, *_zoneDevices;
}
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) {
        self.selectionStyle = UITableViewCellSelectionStyleDefault;
        self.backgroundColor = UIColor.clearColor;
        self.contentView.backgroundColor = ACCard();
        self.contentView.layer.cornerRadius = 20;
        self.contentView.layer.cornerCurve = kCACornerCurveContinuous;
        self.contentView.layer.borderWidth = 0;
        self.contentView.clipsToBounds = NO;
        _cardBorderLayer = [CAShapeLayer layer];
        _cardBorderLayer.fillColor = UIColor.clearColor.CGColor;
        _cardBorderLayer.strokeColor = ACAccent().CGColor;
        _cardBorderLayer.lineWidth = 1.5;
        _cardBorderLayer.contentsScale = UIScreen.mainScreen.scale;
        [self.contentView.layer addSublayer:_cardBorderLayer];
        UIStackView *stack = [UIStackView new]; stack.axis = UILayoutConstraintAxisVertical; stack.spacing = 9;
        stack.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:stack];
        _title = [UILabel new]; _title.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold]; _title.textColor = ACPrimaryText();
        _link = [UIButton buttonWithType:UIButtonTypeSystem]; [_link setImage:[UIImage systemImageNamed:@"link"] forState:UIControlStateNormal];
        _link.tintColor = ACPrimaryText(); _link.accessibilityLabel = @"Настроить группу Multiroom";
        [_link addTarget:self action:@selector(linkTapped) forControlEvents:UIControlEventTouchUpInside];
        UIStackView *header = [[UIStackView alloc] initWithArrangedSubviews:@[_title, [UIView new], _link]];
        header.axis = UILayoutConstraintAxisHorizontal; header.alignment = UIStackViewAlignmentCenter;
        [_link.widthAnchor constraintEqualToConstant:34].active = YES; [_link.heightAnchor constraintEqualToConstant:34].active = YES;

        _art = [UIImageView new]; _art.translatesAutoresizingMaskIntoConstraints = NO;
        _art.backgroundColor = [UIColor colorWithWhite:.16 alpha:1]; _art.tintColor = ACSecondaryText();
        _art.contentMode = UIViewContentModeScaleAspectFill; _art.clipsToBounds = YES; _art.layer.cornerRadius = 10;
        [_art.widthAnchor constraintEqualToConstant:64].active = YES; [_art.heightAnchor constraintEqualToConstant:64].active = YES;
        _track = [UILabel new]; _track.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium]; _track.textColor = ACPrimaryText(); _track.numberOfLines = 1;
        _artist = [UILabel new]; _artist.font = [UIFont systemFontOfSize:13]; _artist.textColor = ACSecondaryText(); _artist.numberOfLines = 1;
        UIStackView *metadata = [[UIStackView alloc] initWithArrangedSubviews:@[_track, _artist]];
        metadata.axis = UILayoutConstraintAxisVertical; metadata.spacing = 4;
        UIStackView *playing = [[UIStackView alloc] initWithArrangedSubviews:@[_art, metadata]];
        playing.axis = UILayoutConstraintAxisHorizontal; playing.alignment = UIStackViewAlignmentCenter; playing.spacing = 12;
        _groupVolumeLabel = [UILabel new]; _groupVolumeLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium]; _groupVolumeLabel.textColor = ACSecondaryText();
        _groupVolumeLabel.text = ACMenuText(@"Group volume");
        _groupSlider = [ACThinSlider new]; _groupSlider.minimumValue = 0; _groupSlider.maximumValue = 100;
        _groupSlider.minimumTrackTintColor = ACAccent(); _groupSlider.maximumTrackTintColor = [UIColor colorWithWhite:.3 alpha:1]; _groupSlider.thumbTintColor = ACPrimaryText();
        [_groupSlider addTarget:self action:@selector(groupVolumeChanged:) forControlEvents:UIControlEventTouchUpInside];
        [_groupSlider addTarget:self action:@selector(groupVolumeChanged:) forControlEvents:UIControlEventTouchUpOutside];
        _groupVolumeValue = [UILabel new]; _groupVolumeValue.font = [UIFont monospacedDigitSystemFontOfSize:12 weight:UIFontWeightMedium]; _groupVolumeValue.textColor = ACSecondaryText();
        UIStackView *groupVolume = [[UIStackView alloc] initWithArrangedSubviews:@[_groupSlider, _groupVolumeValue]];
        groupVolume.axis = UILayoutConstraintAxisHorizontal; groupVolume.alignment = UIStackViewAlignmentCenter; groupVolume.spacing = 10;
        [_groupVolumeValue.widthAnchor constraintEqualToConstant:28].active = YES;
        _membersStack = [UIStackView new]; _membersStack.axis = UILayoutConstraintAxisVertical; _membersStack.spacing = 3;
        for (UIView *view in @[header, playing, _groupVolumeLabel, groupVolume, _membersStack]) [stack addArrangedSubview:view];
        [NSLayoutConstraint activateConstraints:@[
            [stack.leadingAnchor constraintEqualToAnchor:self.contentView.layoutMarginsGuide.leadingAnchor],
            [stack.trailingAnchor constraintEqualToAnchor:self.contentView.layoutMarginsGuide.trailingAnchor],
            [stack.topAnchor constraintEqualToAnchor:self.contentView.layoutMarginsGuide.topAnchor constant:5],
            [stack.bottomAnchor constraintEqualToAnchor:self.contentView.layoutMarginsGuide.bottomAnchor constant:-5]
        ]];
    }
    return self;
}
- (void)prepareForReuse { [super prepareForReuse]; self.onLink = nil; self.onVolume = nil; self.onSettings = nil; }
- (void)layoutSubviews {
    [super layoutSubviews];
    // Keep the complete stroke inside the row's clipping bounds. Drawing the
    // path on the very edge (even inset by half a line width) clips the top
    // corners when UITableView rounds/clips the selected grouped row.
    // Leave a little more room than half the stroke so Core Animation's
    // antialiasing does not shave the upper corner pixels at the table edge.
    CGFloat inset = 3.5;
    CGRect borderRect = CGRectInset(self.contentView.bounds, inset, inset);
    _cardBorderLayer.frame = self.contentView.bounds;
    _cardBorderLayer.path = [UIBezierPath bezierPathWithRoundedRect:borderRect cornerRadius:16.5].CGPath;
}
- (void)configureMaster:(LPDevice *)master members:(NSArray<LPDevice *> *)members selected:(BOOL)selected online:(BOOL)online {
    _master = master; _members = members ?: @[];
    _zoneDevices = [@[master] arrayByAddingObjectsFromArray:_members];
    BOOL playing = master.deviceInfo.playStatus == LP_PLAYER_STATE_PLAYING;
    self.contentView.backgroundColor = selected ? [UIColor colorWithWhite:(playing ? .15 : .12) alpha:1] : ACCard();
    _title.text = ACName(master);
    NSString *title = ACText(master.mediaInfo.title);
    _track.text = title ?: ACMenuText(@"No Music Selected");
    _artist.text = ACText(master.mediaInfo.artist) ?: @"";
    NSString *artwork = ACText(master.mediaInfo.artworkUri);
    NSURL *url = ACStreamURL(artwork);
    _art.image = [UIImage systemImageNamed:@"music.note"];
    if (url) [_art sd_setImageWithURL:url placeholderImage:[UIImage systemImageNamed:@"music.note"] options:SDWebImageRetryFailed | SDWebImageHighPriority];
    else [_art sd_cancelCurrentImageLoad];
    _link.enabled = online;
    float total = master.deviceStatus.volume; NSUInteger count = 1;
    for (LPDevice *device in _members) { total += device.deviceStatus.volume; count++; }
    _groupSlider.value = MIN(100, MAX(0, total / count));
    _groupVolumeValue.text = [NSString stringWithFormat:@"%.0f", _groupSlider.value];
    for (UIView *oldRow in [_membersStack.arrangedSubviews copy]) { [_membersStack removeArrangedSubview:oldRow]; [oldRow removeFromSuperview]; }
    for (LPDevice *device in _zoneDevices) {
        UIStackView *row = [UIStackView new]; row.axis = UILayoutConstraintAxisHorizontal; row.alignment = UIStackViewAlignmentCenter; row.spacing = 8;
        UILabel *name = [UILabel new]; name.text = ACName(device); name.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium]; name.textColor = ACPrimaryText();
        name.numberOfLines = 1; name.lineBreakMode = NSLineBreakByTruncatingTail;
        UIImageView *speaker = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"speaker.wave.2.fill"]]; speaker.tintColor = ACSecondaryText();
        [speaker.widthAnchor constraintEqualToConstant:17].active = YES;
        UISlider *slider = [ACThinSlider new]; slider.minimumValue = 0; slider.maximumValue = 100; slider.value = device.deviceStatus.volume;
        slider.minimumTrackTintColor = ACAccent(); slider.maximumTrackTintColor = [UIColor colorWithWhite:.3 alpha:1]; slider.thumbTintColor = ACPrimaryText();
        slider.enabled = online; slider.tag = [_zoneDevices indexOfObject:device];
        [slider addTarget:self action:@selector(memberVolumeChanged:) forControlEvents:UIControlEventTouchUpInside];
        [slider addTarget:self action:@selector(memberVolumeChanged:) forControlEvents:UIControlEventTouchUpOutside];
        UIButton *settings = [UIButton buttonWithType:UIButtonTypeSystem]; [settings setImage:[UIImage systemImageNamed:@"gearshape"] forState:UIControlStateNormal];
        settings.tintColor = ACPrimaryText(); settings.tag = slider.tag; settings.accessibilityLabel = [NSString stringWithFormat:@"Настройки %@", ACName(device)];
        [settings addTarget:self action:@selector(memberSettingsTapped:) forControlEvents:UIControlEventTouchUpInside];
        [settings.widthAnchor constraintEqualToConstant:30].active = YES;
        [row addArrangedSubview:speaker]; [row addArrangedSubview:name]; [row addArrangedSubview:slider]; [row addArrangedSubview:settings];
        [name.widthAnchor constraintGreaterThanOrEqualToConstant:60].active = YES;
        [_membersStack addArrangedSubview:row];
    }
}
- (void)linkTapped { if (self.onLink) self.onLink(); }
- (void)groupVolumeChanged:(UISlider *)sender {
    _groupVolumeValue.text = [NSString stringWithFormat:@"%.0f", sender.value];
    if (self.onVolume) { self.onVolume(_master, sender.value); for (LPDevice *device in _members) self.onVolume(device, sender.value); }
}
- (void)memberVolumeChanged:(UISlider *)sender {
    if (sender.tag < _zoneDevices.count && self.onVolume) self.onVolume(_zoneDevices[sender.tag], sender.value);
}
- (void)memberSettingsTapped:(UIButton *)sender {
    if (sender.tag < _zoneDevices.count && self.onSettings) self.onSettings(_zoneDevices[sender.tag]);
}
@end

@interface ACEqualizerController : UITableViewController
- (instancetype)initWithDevice:(LPDevice *)device;
@end

@implementation ACEqualizerController {
    LPDevice *_device;
    NSMutableDictionary *_eq;
    NSMutableArray<NSMutableDictionary *> *_bands;
    UILabel *_messageLabel;
    BOOL _loading;
    BOOL _saving;
}
- (instancetype)initWithDevice:(LPDevice *)device {
    self = [super initWithStyle:UITableViewStyleInsetGrouped];
    if (self) _device = device;
    return self;
}
- (NSString *)chipFamily {
    NSMutableArray<NSString *> *hints = [NSMutableArray array];
    if (_device.deviceStatus.productName.length) [hints addObject:_device.deviceStatus.productName];
    NSDictionary *info = _device.deviceStatus.deviceInfoDictionary;
    for (NSString *key in @[@"ProjectName", @"project", @"modelName", @"ModelName", @"hardware", @"chip"]) {
        id value = info[key]; if ([value isKindOfClass:NSString.class]) [hints addObject:value];
    }
    NSString *all = [[hints componentsJoinedByString:@" "] uppercaseString];
    if ([all containsString:@"A31"] || [all containsString:@"UP2STREAM_PRO_V4"]) return @"A31";
    if ([all containsString:@"A98"] || [all containsString:@"AMLOGICA113"]) return @"A98 / Amlogic A113";
    if ([all containsString:@"A33"]) return @"A33";
    if ([all containsString:@"LIBRE"]) return @"Libre";
    return _device.deviceStatus.productName.length ? _device.deviceStatus.productName : @"Linkplay";
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = ACMenuText(@"Эквалайзер");
    self.view.backgroundColor = ACBackground(); self.tableView.backgroundColor = ACBackground();
    self.tableView.separatorColor = ACSeparator(); self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 76;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:ACMenuText(@"Обновить") style:UIBarButtonItemStylePlain target:self action:@selector(readEQ)];
    _messageLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 68)];
    _messageLabel.textColor = ACSecondaryText(); _messageLabel.font = [UIFont systemFontOfSize:14];
    _messageLabel.numberOfLines = 0; _messageLabel.textAlignment = NSTextAlignmentCenter;
    self.tableView.tableFooterView = _messageLabel;
    [self readEQ];
}
- (void)setMessage:(NSString *)text {
    _messageLabel.text = text;
    [_messageLabel sizeToFit];
    self.tableView.tableFooterView = _messageLabel;
}
- (void)readEQ {
    if (_loading || !_device) return;
    _loading = YES; [self setMessage:ACMenuText(@"Загрузка настроек эквалайзера…")];
    [_device.deviceSettings getSupportEQAndValues:^(NSURLResponse *response, id result, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self->_loading = NO;
            if (error || ![result isKindOfClass:NSDictionary.class]) {
                [self setMessage:error.localizedDescription ?: ACMenuText(@"Устройство не предоставило поддерживаемые полосы эквалайзера.")];
                [self.tableView reloadData]; return;
            }
            self->_eq = [result mutableCopy];
            NSArray *reported = [result[@"EQValue"] isKindOfClass:NSArray.class] ? result[@"EQValue"] : @[];
            self->_bands = [NSMutableArray array];
            for (id value in reported) if ([value isKindOfClass:NSDictionary.class] && [value[@"Name"] isKindOfClass:NSString.class]) {
                NSMutableDictionary *band = [value mutableCopy];
                double number = [band[@"Value"] respondsToSelector:@selector(doubleValue)] ? [band[@"Value"] doubleValue] : 0;
                band[@"Value"] = @((NSInteger)lrint(number)); [self->_bands addObject:band];
            }
            NSString *chip = [self chipFamily];
            [self setMessage:self->_bands.count ? [NSString stringWithFormat:@"%@ · %@ · %lu %@. %@",
                chip, self->_eq[@"Mode"] ?: ACMenuText(@"Пользовательский"), (unsigned long)self->_bands.count,
                ACMenuText(@"полос поддерживается устройством"), ACMenuText(@"Изменения отправляются на выбранную колонку.")]
                : ACMenuText(@"Устройство не объявило регулируемые полосы эквалайзера.")];
            [self.tableView reloadData];
        });
    }];
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 2; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return 2;
    return _bands.count;
}
- (NSString *)localizedBandName:(NSString *)name {
    NSString *key = name.uppercaseString;
    if ([key containsString:@"BASS"] || [key containsString:@"LOW"]) return ACMenuText(@"Низкие");
    if ([key containsString:@"TREBLE"] || [key containsString:@"HIGH"]) return ACMenuText(@"Высокие");
    if ([key containsString:@"MID"]) return ACMenuText(@"Средние");
    return name;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
        cell.backgroundColor = ACCard(); cell.contentView.backgroundColor = ACCard();
        cell.textLabel.textColor = ACPrimaryText(); cell.detailTextLabel.textColor = ACSecondaryText();
        cell.textLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
        cell.detailTextLabel.font = [UIFont systemFontOfSize:14]; cell.detailTextLabel.numberOfLines = 0;
        if (indexPath.row == 0) {
            cell.textLabel.text = [NSString stringWithFormat:@"%@ · %@", ACName(_device), [self chipFamily]];
            cell.detailTextLabel.text = ACMenuText(@"Полосы и диапазон загружены из профиля устройства.");
        } else {
            cell.textLabel.text = ACMenuText(@"Режим эквалайзера");
            cell.detailTextLabel.text = [_eq[@"Mode"] description] ?: ACMenuText(@"Пользовательский режим");
        }
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        return cell;
    }
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    cell.backgroundColor = ACCard(); cell.contentView.backgroundColor = ACCard();
    cell.textLabel.textColor = ACPrimaryText(); cell.detailTextLabel.textColor = ACSecondaryText();
    cell.textLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    NSMutableDictionary *band = _bands[indexPath.row];
    NSInteger value = [band[@"Value"] integerValue];
    cell.textLabel.text = [NSString stringWithFormat:@"%@   %ld", [self localizedBandName:band[@"Name"]], (long)value];
    UISlider *slider = [[UISlider alloc] initWithFrame:CGRectZero];
    slider.minimumValue = -5; slider.maximumValue = 5; slider.value = value;
    slider.minimumTrackTintColor = ACAccent(); slider.maximumTrackTintColor = ACSeparator(); slider.thumbTintColor = ACPrimaryText();
    slider.tag = indexPath.row; [slider addTarget:self action:@selector(sliderChanged:) forControlEvents:UIControlEventValueChanged];
    [slider addTarget:self action:@selector(sliderCommitted:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
    cell.detailTextLabel.text = nil;
    slider.translatesAutoresizingMaskIntoConstraints = NO; [cell.contentView addSubview:slider];
    [NSLayoutConstraint activateConstraints:@[
        [slider.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:16],
        [slider.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-16],
        [slider.topAnchor constraintEqualToAnchor:cell.textLabel.bottomAnchor constant:8],
        [slider.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor constant:-12],
        [slider.heightAnchor constraintEqualToConstant:28]
    ]];
    return cell;
}
- (void)sliderChanged:(UISlider *)slider {
    NSInteger index = slider.tag; if (index >= _bands.count) return;
    NSInteger value = (NSInteger)lrintf(slider.value);
    NSMutableDictionary *band = _bands[index]; band[@"Value"] = @(value);
    UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:index inSection:1]];
    cell.textLabel.text = [NSString stringWithFormat:@"%@   %ld", [self localizedBandName:band[@"Name"]], (long)value];
}
- (void)sliderCommitted:(UISlider *)slider {
    [self sliderChanged:slider]; if (_saving || !_eq) return;
    _saving = YES; _eq[@"EQValue"] = [_bands copy];
    NSDictionary *payload = [_eq copy];
    [_device.deviceSettings setEQValues:payload completionHandler:^(NSURLResponse *response, id result, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self->_saving = NO;
            if (error) { [self setMessage:[NSString stringWithFormat:@"%@ · %@", ACMenuText(@"Не удалось применить эквалайзер"), error.localizedDescription]]; return; }
            [self setMessage:ACMenuText(@"Эквалайзер применён к выбранному устройству.")];
            [self readEQ];
        });
    }];
}
@end

@interface ACDeviceSettingsDetail : UITableViewController
@property(nonatomic, strong) LPDevice *device;
@property(nonatomic) BOOL networkPage;
@end

@implementation ACDeviceSettingsDetail {
    NSArray<NSArray<NSString *> *> *_rows;
    BOOL _a31NetworkModeKnown;
    BOOL _a31UsesDHCP;
}
- (NSString *)localized:(NSString *)uk en:(NSString *)en he:(NSString *)he ru:(NSString *)ru {
    return ACT(uk, en, he, ru);
}
- (NSString *)deviceBuildDate {
    NSDictionary *info = self.device.deviceStatus.deviceInfoDictionary;
    if (![info isKindOfClass:NSDictionary.class]) return @"—";
    NSSet *keys = [NSSet setWithArray:@[@"builddate", @"build_date", @"buildtime", @"build_time", @"firmwaredate", @"firmware_date"]];
    for (id key in info) {
        if ([keys containsObject:[[key description] lowercaseString]]) {
            NSString *value = [info[key] description];
            if (value.length && ![value isEqualToString:@"(null)"]) return value;
        }
    }
    return @"—";
}
- (BOOL)isVerifiedA31 {
    NSMutableArray<NSString *> *hints = [NSMutableArray array];
    if (self.device.deviceStatus.productName.length) [hints addObject:self.device.deviceStatus.productName];
    NSDictionary *metadata = self.device.deviceStatus.deviceInfoDictionary;
    if ([metadata isKindOfClass:NSDictionary.class]) {
        for (NSString *key in @[@"ProjectName", @"project", @"modelName", @"ModelName", @"hardware", @"chip"]) {
            id value = metadata[key];
            if (value) [hints addObject:[value description]];
        }
    }
    for (NSString *hint in hints) if ([hint rangeOfString:@"A31" options:NSCaseInsensitiveSearch].location != NSNotFound ||
        [hint rangeOfString:@"UP2STREAM_PRO_V4" options:NSCaseInsensitiveSearch].location != NSNotFound) return YES;
    return NO;
}
- (void)reloadNetworkRowsWithStaticInfo:(NSDictionary *)info {
    LPDeviceStatus *status = self.device.deviceStatus;
    NSString *signal = status.RSSI.length ? [NSString stringWithFormat:@"%@ dBm", status.RSSI] : @"—";
    NSString *wifi = status.SSID.length ? status.SSID : (status.netstat.length ? status.netstat : @"—");
    NSString *mode = _a31NetworkModeKnown ? (_a31UsesDHCP ? @"DHCP" : @"Static") : @"—";
    NSString *ip = [info[@"wifi_static_ip"] description] ?: status.IP ?: @"—";
    NSString *mask = [info[@"wifi_static_mask"] description] ?: @"—";
    NSString *gateway = [info[@"wifi_static_gateway"] description] ?: @"—";
    NSString *dns = [info[@"wifi_static_dns1"] description] ?: @"—";
    NSString *config = [self isVerifiedA31]
        ? [NSString stringWithFormat:@"%@ · %@\n%@ / %@ / DNS %@", mode, ip, mask, gateway, dns]
        : [self localized:@"Статический IP не поддерживается для этой модели в текущей сборке" en:@"Static IP setup is not enabled for this model in this build" he:@"הגדרת IP קבוע אינה זמינה לדגם זה בגרסה זו" ru:@"Настройка статического IP для этой модели пока недоступна"];
    _rows = @[
        @[[self localized:@"Подключение" en:@"Connection" he:@"חיבור" ru:@"Подключение"], wifi],
        @[[self localized:@"IP-адрес" en:@"IP address" he:@"כתובת IP" ru:@"IP-адрес"], status.IP ?: @"—"],
        @[[self localized:@"MAC Wi-Fi" en:@"Wi-Fi MAC" he:@"כתובת MAC של Wi-Fi" ru:@"MAC Wi-Fi"], status.MAC ?: @"—"],
        @[[self localized:@"Канал" en:@"Channel" he:@"ערוץ" ru:@"Канал"], status.WifiChannel.length ? status.WifiChannel : @"—"],
        @[[self localized:@"Уровень сигнала" en:@"Signal strength" he:@"עוצמת אות" ru:@"Уровень сигнала"], signal],
        @[[self localized:@"Режим и параметры IP" en:@"IP mode and settings" he:@"מצב והגדרות IP" ru:@"Режим и параметры IP"], config]
    ];
    [self.tableView reloadData];
}
- (void)loadA31NetworkInfo {
    if (![self isVerifiedA31]) { [self reloadNetworkRowsWithStaticInfo:nil]; return; }
    ACReadJSON(self.device, @"getStaticIP", ^(NSDictionary *info) {
        if (!info) { [self reloadNetworkRowsWithStaticInfo:nil]; return; }
        _a31NetworkModeKnown = YES;
        // Device contract observed in airControl: wifi=1 means DHCP, wifi=0 static.
        _a31UsesDHCP = [[info[@"wifi"] description] isEqualToString:@"1"];
        [self reloadNetworkRowsWithStaticInfo:info];
    });
}
- (BOOL)isValidIPv4:(NSString *)value {
    NSArray<NSString *> *parts = [value componentsSeparatedByString:@"."];
    if (parts.count != 4) return NO;
    for (NSString *part in parts) {
        NSScanner *scanner = [NSScanner scannerWithString:part];
        int octet = -1;
        if (![scanner scanInt:&octet] || !scanner.isAtEnd || octet < 0 || octet > 255 || part.length == 0) return NO;
    }
    return YES;
}
- (void)showNetworkActions {
    if (![self isVerifiedA31]) {
        [self showMessage:[self localized:@"Настройка статического IP не доступна этой модели через проверенный интерфейс." en:@"Static IP setup is not available for this model through a verified interface." he:@"הגדרת IP קבוע אינה זמינה לדגם זה דרך ממשק מאומת." ru:@"Настройка статического IP для этой модели не доступна через проверенный интерфейс."]];
        return;
    }
    UIAlertController *actions = [UIAlertController alertControllerWithTitle:[self localized:@"Настройка сети" en:@"Network settings" he:@"הגדרות רשת" ru:@"Настройка сети"] message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    [actions addAction:[UIAlertAction actionWithTitle:[self localized:@"Получать IP автоматически (DHCP)" en:@"Obtain IP automatically (DHCP)" he:@"קבלת IP אוטומטית (DHCP)" ru:@"Получать IP автоматически (DHCP)"] style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        UIAlertController *confirm = [UIAlertController alertControllerWithTitle:[self localized:@"Включить DHCP?" en:@"Enable DHCP?" he:@"להפעיל DHCP?" ru:@"Включить DHCP?"] message:[self localized:@"IP-адрес устройства может измениться. После переключения найдите устройство заново." en:@"The device IP may change. Rediscover the device after switching." he:@"כתובת ה-IP עשויה להשתנות. יש לאתר את המכשיר מחדש לאחר המעבר." ru:@"IP-адрес устройства может измениться. После переключения найдите устройство заново."] preferredStyle:UIAlertControllerStyleAlert];
        [confirm addAction:[UIAlertAction actionWithTitle:[self localized:@"Отмена" en:@"Cancel" he:@"ביטול" ru:@"Отмена"] style:UIAlertActionStyleCancel handler:nil]];
        [confirm addAction:[UIAlertAction actionWithTitle:@"DHCP" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *confirmAction) {
            ACRequest(self.device.deviceStatus.IP, 80, @"/httpapi.asp", @"command", @"setDhcp:wifi", nil, nil, ^(NSData *data) {
                NSString *reply = data.length ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : nil;
                [self showMessage:reply.length ? [NSString stringWithFormat:@"%@: %@", [self localized:@"Ответ устройства" en:@"Device response" he:@"תגובת המכשיר" ru:@"Ответ устройства"], reply] : [self localized:@"Нет ответа. Устройство могло сменить IP-адрес." en:@"No response. The device may have changed IP address." he:@"אין תגובה. ייתכן שכתובת המכשיר השתנתה." ru:@"Нет ответа. Устройство могло сменить IP-адрес."]];
            });
        }]];
        [self presentViewController:confirm animated:YES completion:nil];
    }]];
    [actions addAction:[UIAlertAction actionWithTitle:[self localized:@"Задать статический IP" en:@"Set static IP" he:@"הגדרת IP קבוע" ru:@"Задать статический IP"] style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        UIAlertController *form = [UIAlertController alertControllerWithTitle:[self localized:@"Статический IP Wi-Fi" en:@"Static Wi-Fi IP" he:@"כתובת Wi-Fi קבועה" ru:@"Статический IP Wi-Fi"] message:nil preferredStyle:UIAlertControllerStyleAlert];
        NSArray<NSString *> *labels = @[
            [self localized:@"IP-адрес" en:@"IP address" he:@"כתובת IP" ru:@"IP-адрес"],
            [self localized:@"Маска подсети" en:@"Subnet mask" he:@"מסכת רשת" ru:@"Маска подсети"],
            [self localized:@"Шлюз" en:@"Gateway" he:@"שער" ru:@"Шлюз"],
            @"DNS"
        ];
        NSArray<NSString *> *defaults = @[self.device.deviceStatus.IP ?: @"192.168.0.100", @"255.255.255.0", @"192.168.0.1", @"192.168.0.1"];
        for (NSUInteger index = 0; index < labels.count; index++) {
            [form addTextFieldWithConfigurationHandler:^(UITextField *field) {
                field.placeholder = labels[index]; field.text = defaults[index]; field.keyboardType = UIKeyboardTypeDecimalPad;
            }];
        }
        [form addAction:[UIAlertAction actionWithTitle:[self localized:@"Отмена" en:@"Cancel" he:@"ביטול" ru:@"Отмена"] style:UIAlertActionStyleCancel handler:nil]];
        [form addAction:[UIAlertAction actionWithTitle:[self localized:@"Применить" en:@"Apply" he:@"החל" ru:@"Применить"] style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
            NSArray<NSString *> *values = [form.textFields valueForKey:@"text"];
            for (NSString *value in values) if (![self isValidIPv4:value]) { [self showMessage:[self localized:@"Проверьте IP-адрес, маску, шлюз и DNS." en:@"Check the IP address, subnet mask, gateway and DNS." he:@"יש לבדוק את כתובת ה-IP, המסכה, השער וה-DNS." ru:@"Проверьте IP-адрес, маску, шлюз и DNS."]]; return; }
            NSDictionary *payload = @{@"type":@"wifi", @"ip":values[0], @"mask":values[1], @"gateway":values[2], @"dns":@[@{@"service":values[3]}]};
            NSString *command = [@"setStaticIP:" stringByAppendingString:[[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:payload options:NSJSONWritingFragmentsAllowed error:nil] encoding:NSUTF8StringEncoding] ?: @""];
            ACRequest(self.device.deviceStatus.IP, 80, @"/httpapi.asp", @"command", command, nil, nil, ^(NSData *data) {
                NSString *reply = data.length ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : nil;
                [self showMessage:reply.length ? [NSString stringWithFormat:@"%@. %@: %@", [self localized:@"IP-адрес применён; устройство может отключиться от текущего адреса" en:@"IP settings sent; the device may disconnect from its current address" he:@"הגדרות ה-IP נשלחו; המכשיר עשוי להתנתק מהכתובת הנוכחית" ru:@"Настройки IP отправлены; устройство может отключиться от текущего адреса"], [self localized:@"Ответ" en:@"Response" he:@"תגובה" ru:@"Ответ"], reply] : [self localized:@"Ответ не получен. Проверьте устройство по новому IP-адресу." en:@"No response. Check the device at the new IP address." he:@"לא התקבלה תגובה. יש לבדוק את המכשיר בכתובת החדשה." ru:@"Ответ не получен. Проверьте устройство по новому IP-адресу."]];
            });
        }]];
        [self presentViewController:form animated:YES completion:nil];
    }]];
    [actions addAction:[UIAlertAction actionWithTitle:[self localized:@"Отмена" en:@"Cancel" he:@"ביטול" ru:@"Отмена"] style:UIAlertActionStyleCancel handler:nil]];
    actions.popoverPresentationController.sourceView = self.view;
    actions.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 1, 1);
    [self presentViewController:actions animated:YES completion:nil];
}
- (void)showMessage:(NSString *)message {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:self.title message:message preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    });
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = ACBackground();
    self.tableView.backgroundColor = ACBackground();
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 58;
    self.title = self.networkPage ? [self localized:@"Сеть" en:@"Network" he:@"רשת" ru:@"Сеть"] :
        [self localized:@"Информация об устройстве" en:@"Device information" he:@"מידע על המכשיר" ru:@"Информация об устройстве"];
    LPDeviceStatus *status = self.device.deviceStatus;
    if (self.networkPage) {
        [self reloadNetworkRowsWithStaticInfo:nil];
        [self loadA31NetworkInfo];
    } else {
        _rows = @[
            @[[self localized:@"Название зоны" en:@"Zone name" he:@"שם אזור" ru:@"Название зоны"], status.friendlyName ?: @"—"],
            @[[self localized:@"Уровень сигнала" en:@"Signal strength" he:@"עוצמת אות" ru:@"Уровень сигнала"], status.RSSI.length ? [NSString stringWithFormat:@"%@ dBm", status.RSSI] : @"—"],
            @[[self localized:@"IP-адрес" en:@"IP address" he:@"כתובת IP" ru:@"IP-адрес"], status.IP ?: @"—"],
            @[[self localized:@"MAC-адрес" en:@"MAC address" he:@"כתובת MAC" ru:@"MAC-адрес"], status.MAC ?: @"—"],
            @[[self localized:@"ID устройства" en:@"Device ID" he:@"מזהה מכשיר" ru:@"ID устройства"], status.UUID ?: status.nativeUUID ?: @"—"],
            @[[self localized:@"Версия прошивки" en:@"Firmware version" he:@"גרסת קושחה" ru:@"Версия прошивки"], status.firmware ?: @"—"],
            @[[self localized:@"Дата прошивки" en:@"Firmware date" he:@"תאריך קושחה" ru:@"Дата прошивки"], [self deviceBuildDate]],
            @[[self localized:@"Перезагрузить" en:@"Reboot" he:@"הפעלה מחדש" ru:@"Перезагрузить"],
              [self localized:@"Перезапустить устройство" en:@"Restart this device" he:@"הפעלה מחדש של המכשיר" ru:@"Перезапустить устройство"]],
            @[[self localized:@"Заводские установки" en:@"Factory reset" he:@"איפוס להגדרות יצרן" ru:@"Заводские установки"],
              [self localized:@"Удалит настройки устройства" en:@"Erases device settings" he:@"ימחק את הגדרות המכשיר" ru:@"Удалит настройки устройства"]]
        ];
    }
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return _rows.count; }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"DeviceSettingRow"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"DeviceSettingRow"];
    cell.backgroundColor = ACCard(); cell.contentView.backgroundColor = ACCard();
    cell.textLabel.textColor = ACPrimaryText(); cell.textLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    cell.detailTextLabel.textColor = ACSecondaryText(); cell.detailTextLabel.font = [UIFont systemFontOfSize:14];
    cell.textLabel.text = _rows[indexPath.row][0]; cell.detailTextLabel.text = _rows[indexPath.row][1];
    cell.detailTextLabel.numberOfLines = 0;
    cell.accessoryType = (!self.networkPage && indexPath.row == 8) || (self.networkPage && indexPath.row == 5) ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;
    cell.selectionStyle = (!self.networkPage && indexPath.row == 8) || (self.networkPage && indexPath.row == 5) ? UITableViewCellSelectionStyleDefault : UITableViewCellSelectionStyleNone;
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (self.networkPage) {
        if (indexPath.row == 5) [self showNetworkActions];
        return;
    }
    if (indexPath.row == 7) {
        UIAlertController *confirm = [UIAlertController alertControllerWithTitle:[self localized:@"Перезагрузить устройство?" en:@"Reboot device?" he:@"להפעיל מחדש את המכשיר?" ru:@"Перезагрузить устройство?"] message:[self localized:@"Колонка временно исчезнет из сети." en:@"The speaker will temporarily disappear from the network." he:@"הרמקול ייעלם זמנית מהרשת." ru:@"Колонка временно исчезнет из сети."] preferredStyle:UIAlertControllerStyleAlert];
        [confirm addAction:[UIAlertAction actionWithTitle:[self localized:@"Отмена" en:@"Cancel" he:@"ביטול" ru:@"Отмена"] style:UIAlertActionStyleCancel handler:nil]];
        [confirm addAction:[UIAlertAction actionWithTitle:[self localized:@"Перезагрузить" en:@"Reboot" he:@"הפעלה מחדש" ru:@"Перезагрузить"] style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) {
            ACRequest(self.device.deviceStatus.IP, 80, @"/httpapi.asp", @"command", @"reboot", nil, nil, ^(NSData *data) {
                NSString *reply = data.length ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : nil;
                [self showMessage:reply.length ? reply : [self localized:@"Ответ не получен; устройство могло начать перезагрузку." en:@"No response; the device may be rebooting." he:@"לא התקבלה תגובה; ייתכן שהמכשיר מופעל מחדש." ru:@"Ответ не получен; устройство могло начать перезагрузку."]];
            });
        }]];
        [self presentViewController:confirm animated:YES completion:nil];
        return;
    }
    if (indexPath.row != 8) return;
    UIAlertController *confirm = [UIAlertController alertControllerWithTitle:[self localized:@"Сбросить устройство?" en:@"Reset device?" he:@"לאפס את המכשיר?" ru:@"Сбросить устройство?"]
        message:[self localized:@"Устройство вернётся к заводским настройкам и может отключиться от сети." en:@"The device will return to factory settings and may disconnect from the network." he:@"המכשיר יחזור להגדרות היצרן ועלול להתנתק מהרשת." ru:@"Устройство вернётся к заводским настройкам и может отключиться от сети."] preferredStyle:UIAlertControllerStyleAlert];
    [confirm addAction:[UIAlertAction actionWithTitle:[self localized:@"Отмена" en:@"Cancel" he:@"ביטול" ru:@"Отмена"] style:UIAlertActionStyleCancel handler:nil]];
    [confirm addAction:[UIAlertAction actionWithTitle:[self localized:@"Сбросить" en:@"Reset" he:@"איפוס" ru:@"Сбросить"] style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) {
        [self.device.deviceSettings resetDeviceWithHandler:^(NSURLResponse *response, id responseObject, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSString *message = error.localizedDescription ?: [self localized:@"Команда сброса отправлена." en:@"Reset command sent." he:@"פקודת האיפוס נשלחה." ru:@"Команда сброса отправлена."];
                UIAlertController *result = [UIAlertController alertControllerWithTitle:self.title message:message preferredStyle:UIAlertControllerStyleAlert];
                [result addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
                [self presentViewController:result animated:YES completion:nil];
            });
        }];
    }]];
    [self presentViewController:confirm animated:YES completion:nil];
}
@end

@implementation ACPage {
    ACStore *_store;
    ACSection _section;
    NSArray<LPDevice *> *_devices;
    NSArray<NSDictionary *> *_deviceRows;
    NSSet<NSString *> *_multiroomIDs, *_multiroomMasterIDs;
    NSMutableArray<NSDictionary *> *_lanDevices;
    NSUInteger _lanRemaining;
    BOOL _lanScanning, _lanScanFinished;
    NSString *_shownID;
    NSString *_miniCoverURL;
    UIView *_mini;
    UIImageView *_miniArt;
    UILabel *_miniTitle, *_miniSubtitle;
    UILabel *_devicesCountLabel;
    UIButton *_miniToggle, *_miniNext;
    NSArray<NSArray<NSString *> *> *_items;
    NSArray<NSNumber *> *_browseActions;
}
- (instancetype)initWithStore:(ACStore *)store section:(ACSection)section {
    if ((self = [super initWithStyle:UITableViewStyleInsetGrouped])) {
        _store = store; _section = section;
        self.title = @[ACT(@"Огляд", @"Browse", @"עיון", @"Обзор"), ACT(@"Кімнати", @"Rooms", @"חדרים", @"Комнаты"), ACT(@"Налаштування", @"Settings", @"הגדרות", @"Настройки")][section];
        self.tabBarItem = [[UITabBarItem alloc] initWithTitle:self.title
          image:[UIImage systemImageNamed:@[@"square.grid.2x2", @"hifispeaker", @"gearshape"][section]] tag:section];
    }
    return self;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.backgroundColor = ACBackground();
    self.tableView.separatorColor = ACSeparator();
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.sectionHeaderTopPadding = 10;
    self.tableView.rowHeight = 62;
    // Keep the root tabs on a compact navigation bar. Large-title mode leaves
    // a tall empty region above the first row, especially in the RTL browse tab.
    self.navigationController.navigationBar.prefersLargeTitles = NO;
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
    [self buildMiniPlayer];
    if (_section == ACDevices) {
        _lanDevices = [NSMutableArray array];
        [self buildDevicesHeader];
        self.refreshControl = [UIRefreshControl new];
        [self.refreshControl addTarget:self action:@selector(rescan) forControlEvents:UIControlEventValueChanged];
    }
    if (_section == ACBrowse) {
        _items = @[
            @[@"Выбранная зона", @"Коснитесь, чтобы выбрать устройство", @"hifispeaker.fill"],
            @[@"Входы и источники", @"Выбрать вход на текущей зоне", @"slider.horizontal.3"],
            @[@"БИБЛИОТЕКА", @"", @"section"],
            @[@"Фавориты", @"Избранное содержимое устройства", @"heart"],
            @[@"Пресеты", @"Слоты быстрого доступа", @"star"],
            @[@"USB", @"Медиатека накопителя на устройстве", @"externaldrive"],
            @[@"Медиатека iPhone", @"Музыка на этом телефоне", @"music.note.house"],
            @[@"Медиасерверы", @"Поиск NAS через SDK", @"server.rack"],
            @[@"РАДИО", @"", @"section"],
            @[@"TuneIn", @"Поиск радиостанций", @"radio"],
            @[@"Radio Browser", @"Каталог интернет-радио", @"radio"],
            @[@"ОНЛАЙН-СЕРВИСЫ", @"", @"section"],
            @[@"Deezer", @"Библиотека и воспроизведение", @"music.note"],
            @[@"Qobuz", @"Библиотека и воспроизведение", @"music.note"],
            @[@"TIDAL", @"Вход и каталог сервиса", @"music.note"],
            @[@"YouTube Music", @"Вход и каталог сервиса", @"music.note"],
            @[@"SoundCloud", @"Вход и каталог сервиса", @"music.note"]
        ];
        _browseActions = @[@(-2), @(-3), @(-1), @0, @3, @1, @5, @4, @(-1), @6, @7, @(-1), @100, @101, @102, @103, @104];
    }
    if (_section == ACSettings) _items = @[
        @[ACT(@"Информация об устройстве", @"Device information", @"מידע על המכשיר", @"Информация об устройстве"), ACName(_store.selected) ?: @"—", @"info.circle"],
        @[ACT(@"Сеть", @"Network", @"רשת", @"Сеть"), ACT(@"IP, Wi-Fi и уровень сигнала", @"IP, Wi-Fi and signal strength", @"IP, Wi-Fi ועוצמת אות", @"IP, Wi-Fi и уровень сигнала"), @"wifi"],
        @[ACT(@"Мова", @"Language", @"שפה", @"Язык"), ACLanguageName([[NSUserDefaults standardUserDefaults] stringForKey:ACLanguagePreferenceKey] ?: @"auto"), @"character.bubble"],
        @[ACT(@"Джерело", @"Source", @"מקור", @"Источник"), ACT(@"Доступні входи пристрою", @"Available device inputs", @"כניסות התקן זמינות", @"Доступные входы устройства"), @"arrow.down.to.line"],
        @[ACT(@"Еквалайзер", @"Equalizer", @"אקולייזר", @"Эквалайзер"), ACT(@"Налаштування звуку", @"Read audio configuration", @"הגדרות שמע", @"Прочитать конфигурацию звука"), @"slider.horizontal.3"],
        @[@"Multiroom", ACT(@"Пристрої та групи", @"Devices and groups", @"התקנים וקבוצות", @"Устройства и группы"), @"hifispeaker.2"],
        @[ACT(@"Будильники", @"Alarms", @"שעונים מעוררים", @"Будильники"), ACT(@"Розклад на пристрої", @"Device schedule", @"לוח זמנים במכשיר", @"Расписание на устройстве"), @"alarm"],
        @[ACT(@"Таймер сну", @"Sleep timer", @"טיימר שינה", @"Таймер сна"), ACT(@"Вимкнення через 30 хвилин", @"Power off after 30 minutes", @"כיבוי בעוד 30 דקות", @"Выключение через 30 минут"), @"moon"],
        @[ACT(@"Про програму", @"About", @"אודות", @"О приложении"), @"airControl · Linkplay iOS", @"info.circle"],
        @[ACT(@"Облікові записи сервісів", @"Music service accounts", @"חשבונות שירותי מוזיקה", @"Аккаунты сервисов"), ACT(@"Вхід у музичні сервіси", @"Sign in to music services", @"התחברות לשירותי מוזיקה", @"Вход в музыкальные сервисы"), @"person.crop.circle"]
    ];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(updatePage) name:ACChanged object:_store];
    [self updatePage];
}
- (void)rebuildLocalizedInterface {
    UIView.appearance.semanticContentAttribute = [ACLanguageCode() isEqualToString:@"he"] ? UISemanticContentAttributeForceRightToLeft : UISemanticContentAttributeForceLeftToRight;
    if (_section == ACSettings) {
        self.title = ACT(@"Налаштування", @"Settings", @"הגדרות", @"Настройки");
        self.tabBarItem.title = self.title;
        _items = @[
            @[ACT(@"Информация об устройстве", @"Device information", @"מידע על המכשיר", @"Информация об устройстве"), ACName(_store.selected) ?: @"—", @"info.circle"],
            @[ACT(@"Сеть", @"Network", @"רשת", @"Сеть"), ACT(@"IP, Wi-Fi и уровень сигнала", @"IP, Wi-Fi and signal strength", @"IP, Wi-Fi ועוצמת אות", @"IP, Wi-Fi и уровень сигнала"), @"wifi"],
            @[ACT(@"Мова", @"Language", @"שפה", @"Язык"), ACLanguageName([[NSUserDefaults standardUserDefaults] stringForKey:ACLanguagePreferenceKey] ?: @"auto"), @"character.bubble"],
            @[ACT(@"Джерело", @"Source", @"מקור", @"Источник"), ACT(@"Доступні входи пристрою", @"Available device inputs", @"כניסות התקן זמינות", @"Доступные входы устройства"), @"arrow.down.to.line"],
            @[ACT(@"Еквалайзер", @"Equalizer", @"אקולייזер", @"Эквалайзер"), ACT(@"Налаштування звуку", @"Read audio configuration", @"הגדרות שמע", @"Прочитать конфигурацию звука"), @"slider.horizontal.3"],
            @[@"Multiroom", ACT(@"Пристрої та групи", @"Devices and groups", @"התקנים וקבוצות", @"Устройства и группы"), @"hifispeaker.2"],
            @[ACT(@"Будильники", @"Alarms", @"שעונים מעוררים", @"Будильники"), ACT(@"Розклад на пристрої", @"Device schedule", @"לוח זמנים במכשיר", @"Расписание на устройстве"), @"alarm"],
            @[ACT(@"Таймер сну", @"Sleep timer", @"טיימר שינה", @"Таймер сна"), ACT(@"Вимкнення через 30 хвилин", @"Power off after 30 minutes", @"כיבוי בעוד 30 דקות", @"Выключение через 30 минут"), @"moon"],
            @[ACT(@"Про програму", @"About", @"אודות", @"О приложении"), @"airControl · Linkplay iOS", @"info.circle"],
            @[ACT(@"Облікові записи сервісів", @"Music service accounts", @"חשבונות שירותי מוזיקה", @"Аккаунты сервисов"), ACT(@"Вхід у музичні сервіси", @"Sign in to music services", @"התחברות לשירותי מוזיקה", @"Вход в музыкальные сервисы"), @"person.crop.circle"]
        ];
    }
    NSArray<NSString *> *tabTitles = @[ACT(@"Огляд", @"Browse", @"עיון", @"Обзор"), ACT(@"Кімнати", @"Rooms", @"חדרים", @"Комнаты"), ACT(@"Налаштування", @"Settings", @"הגדרות", @"Настройки")];
    for (NSUInteger index = 0; index < self.tabBarController.viewControllers.count && index < tabTitles.count; index++) {
        UIViewController *controller = self.tabBarController.viewControllers[index];
        controller.tabBarItem.title = tabTitles[index];
        if ([controller isKindOfClass:UINavigationController.class]) {
            ACPage *page = (ACPage *)((UINavigationController *)controller).viewControllers.firstObject;
            page.title = tabTitles[index];
            if (index == ACDevices && page.isViewLoaded) { [page buildDevicesHeader]; [page updatePage]; }
        }
    }
    [self.tableView reloadData];
}
- (void)buildDevicesHeader {
    UIButton *pause = [UIButton buttonWithType:UIButtonTypeSystem];
    [pause setTitle:ACMenuText(@"Pause All") forState:UIControlStateNormal];
    [pause setTitleColor:ACPrimaryText() forState:UIControlStateNormal];
    [pause setTitleColor:ACAccent() forState:UIControlStateHighlighted];
    [pause.titleLabel setFont:[UIFont systemFontOfSize:14 weight:UIFontWeightMedium]];
    [pause addTarget:self action:@selector(pauseAllDevices) forControlEvents:UIControlEventTouchUpInside];
    [pause sizeToFit];
    pause.frame = CGRectMake(0, 0, MAX(92, pause.bounds.size.width), 38);
    UIButton *add = [UIButton buttonWithType:UIButtonTypeSystem];
    [add setImage:[[UIImage systemImageNamed:@"plus"] imageWithTintColor:ACPrimaryText()] forState:UIControlStateNormal];
    [add setImage:[[UIImage systemImageNamed:@"plus"] imageWithTintColor:ACAccent()] forState:UIControlStateHighlighted];
    add.adjustsImageWhenHighlighted = NO;
    add.tintColor = ACPrimaryText();
    add.accessibilityLabel = ACMenuText(@"Add Device");
    add.frame = CGRectMake(0, 0, 38, 38);
    [add addTarget:self action:@selector(addDeviceAction) forControlEvents:UIControlEventTouchUpInside];
    UIStackView *centerTitle = [UIStackView new]; centerTitle.axis = UILayoutConstraintAxisVertical;
    centerTitle.alignment = UIStackViewAlignmentCenter; centerTitle.spacing = 1;
    centerTitle.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;
    UILabel *title = [UILabel new]; title.text = ACT(@"Кімнати", @"Rooms", @"חדרים", @"Комнаты"); title.textColor = ACPrimaryText();
    title.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    _devicesCountLabel = [UILabel new]; _devicesCountLabel.textColor = ACSecondaryText();
    _devicesCountLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightRegular];
    _devicesCountLabel.textAlignment = NSTextAlignmentCenter;
    [centerTitle addArrangedSubview:title]; [centerTitle addArrangedSubview:_devicesCountLabel];
    [centerTitle sizeToFit];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:pause];
    self.navigationItem.titleView = centerTitle;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:add];
    self.tableView.tableHeaderView = nil;
}
- (void)buildMiniPlayer {
    _mini = [UIView new];
    _mini.translatesAutoresizingMaskIntoConstraints = NO;
    _mini.backgroundColor = [UIColor colorWithWhite:.14 alpha:.98];
    _mini.layer.cornerRadius = 26;
    _mini.layer.borderWidth = .75;
    _mini.layer.borderColor = [UIColor colorWithWhite:.38 alpha:1].CGColor;
    _mini.hidden = YES;
    [self.tableView addSubview:_mini];
    UITapGestureRecognizer *open = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(miniOpen:)];
    open.cancelsTouchesInView = NO;
    [_mini addGestureRecognizer:open];

    _miniArt = [UIImageView new];
    _miniArt.translatesAutoresizingMaskIntoConstraints = NO;
    _miniArt.backgroundColor = [UIColor colorWithWhite:.2 alpha:1];
    _miniArt.contentMode = UIViewContentModeScaleAspectFill;
    _miniArt.clipsToBounds = YES;
    _miniArt.layer.cornerRadius = 20;
    _miniArt.image = [UIImage systemImageNamed:@"music.note"];
    _miniArt.tintColor = ACSecondaryText();
    _miniTitle = [UILabel new];
    _miniTitle.translatesAutoresizingMaskIntoConstraints = NO;
    _miniTitle.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    _miniTitle.textColor = ACPrimaryText(); _miniTitle.numberOfLines = 1;
    _miniSubtitle = [UILabel new];
    _miniSubtitle.translatesAutoresizingMaskIntoConstraints = NO;
    _miniSubtitle.font = [UIFont systemFontOfSize:12];
    _miniSubtitle.textColor = ACSecondaryText(); _miniSubtitle.numberOfLines = 1;
    UIStackView *metadata = [[UIStackView alloc] initWithArrangedSubviews:@[_miniTitle, _miniSubtitle]];
    metadata.translatesAutoresizingMaskIntoConstraints = NO;
    metadata.axis = UILayoutConstraintAxisVertical; metadata.spacing = 2;

    _miniToggle = [UIButton buttonWithType:UIButtonTypeSystem];
    _miniToggle.translatesAutoresizingMaskIntoConstraints = NO;
    [_miniToggle setImage:[UIImage systemImageNamed:@"pause.fill"] forState:UIControlStateNormal];
    _miniToggle.tintColor = ACPrimaryText();
    [_miniToggle addTarget:self action:@selector(miniTogglePlayback) forControlEvents:UIControlEventTouchUpInside];
    _miniNext = [UIButton buttonWithType:UIButtonTypeSystem];
    _miniNext.translatesAutoresizingMaskIntoConstraints = NO;
    [_miniNext setImage:[UIImage systemImageNamed:@"forward.end.fill"] forState:UIControlStateNormal];
    _miniNext.tintColor = ACSecondaryText();
    [_miniNext addTarget:self action:@selector(miniNextTrack) forControlEvents:UIControlEventTouchUpInside];
    for (UIView *v in @[_miniArt, metadata, _miniToggle, _miniNext]) [_mini addSubview:v];
    [NSLayoutConstraint activateConstraints:@[
        [_mini.leadingAnchor constraintEqualToAnchor:self.tableView.safeAreaLayoutGuide.leadingAnchor constant:14],
        [_mini.trailingAnchor constraintEqualToAnchor:self.tableView.safeAreaLayoutGuide.trailingAnchor constant:-14],
        [_mini.bottomAnchor constraintEqualToAnchor:self.tableView.safeAreaLayoutGuide.bottomAnchor constant:-6],
        [_mini.heightAnchor constraintEqualToConstant:54],
        [_miniArt.leadingAnchor constraintEqualToAnchor:_mini.leadingAnchor constant:5],
        [_miniArt.centerYAnchor constraintEqualToAnchor:_mini.centerYAnchor],
        [_miniArt.widthAnchor constraintEqualToConstant:42], [_miniArt.heightAnchor constraintEqualToConstant:42],
        [metadata.leadingAnchor constraintEqualToAnchor:_miniArt.trailingAnchor constant:9],
        [metadata.centerYAnchor constraintEqualToAnchor:_mini.centerYAnchor],
        [_miniToggle.leadingAnchor constraintEqualToAnchor:metadata.trailingAnchor constant:4],
        [_miniToggle.centerYAnchor constraintEqualToAnchor:_mini.centerYAnchor],
        [_miniToggle.widthAnchor constraintEqualToConstant:38], [_miniToggle.heightAnchor constraintEqualToConstant:42],
        [_miniNext.leadingAnchor constraintEqualToAnchor:_miniToggle.trailingAnchor constant:1],
        [_miniNext.trailingAnchor constraintEqualToAnchor:_mini.trailingAnchor constant:-7],
        [_miniNext.centerYAnchor constraintEqualToAnchor:_mini.centerYAnchor],
        [_miniNext.widthAnchor constraintEqualToConstant:38], [_miniNext.heightAnchor constraintEqualToConstant:42],
        [metadata.trailingAnchor constraintLessThanOrEqualToAnchor:_miniToggle.leadingAnchor constant:-4]
    ]];
    self.tableView.contentInset = UIEdgeInsetsMake(0, 0, 68, 0);
    self.tableView.scrollIndicatorInsets = UIEdgeInsetsMake(0, 0, 68, 0);
}
- (void)miniOpen:(UITapGestureRecognizer *)gesture { [self nowPlaying]; }
- (void)miniTogglePlayback {
    NSString *identity = ACDeviceID(_store.selected);
    if (!identity.length) return;
    [self togglePlaybackForDeviceID:identity];
}
- (void)miniNextTrack {
    LPDevice *device = _store.selected;
    LPDevicePlayer *player = [device getPlayer];
    if (!device || !player || ![_store isOnline:device]) return;
    NSString *identity = ACDeviceID(device);
    [player next:^(BOOL success, NSString *result) {
        if (success && [ACDeviceID(self->_store.selected) isEqualToString:identity])
            [device.deviceInfo updateCurrentPlayInfo];
    }];
}
- (void)pauseAllDevices {
    for (LPDevice *device in _devices) {
        if (![_store isOnline:device] || !device.deviceInfo || device.deviceInfo.playStatus != LP_PLAYER_STATE_PLAYING) continue;
        [[device getPlayer] pause:^(BOOL success, NSString *result) { if (success) [device.deviceInfo updateCurrentPlayInfo]; }];
    }
}
- (void)addDeviceAction {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Add Device" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    [alert addAction:[UIAlertAction actionWithTitle:@"Объединить зоны" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        LPDevice *device = self->_store.selected;
        if (!device) for (LPDevice *candidate in self->_devices) if ([self->_store isOnline:candidate]) { device = candidate; break; }
        if (device) [self openMultiroomForDeviceID:ACDeviceID(device)];
        else [self alert:@"Нет доступных зон" body:@"Сначала выберите устройство Linkplay."];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Подключить A33 / Libre" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) { [self connectLAN]; }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Отмена" style:UIAlertActionStyleCancel handler:nil]];
    if (alert.popoverPresentationController) {
        alert.popoverPresentationController.sourceView = self.view;
        alert.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 1, 1);
        alert.popoverPresentationController.permittedArrowDirections = 0;
    }
    [self presentViewController:alert animated:YES completion:nil];
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    if (_mini) [self.tableView bringSubviewToFront:_mini];
    if (_section == ACDevices && self.tableView.tableHeaderView) {
        CGRect frame = self.tableView.tableHeaderView.frame;
        CGFloat width = self.tableView.bounds.size.width;
        if (fabs(frame.size.width - width) > 0.5) { frame.size.width = width; self.tableView.tableHeaderView.frame = frame; }
    }
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self updatePage];
    if (_section == ACDevices && !_lanScanning && !_lanScanFinished && ACWiFiPeers().count) [self findLAN];
}
- (void)dealloc { [NSNotificationCenter.defaultCenter removeObserver:self]; }
- (void)registerLAN:(NSDictionary *)match {
    NSURLComponents *url = match[@"url"];
    for (NSUInteger i = 0; i < _lanDevices.count; i++) {
        NSURLComponents *known = _lanDevices[i][@"url"];
        if (![known.host isEqualToString:url.host] || ![_lanDevices[i][@"libre"] isEqual:match[@"libre"]]) continue;
        _lanDevices[i] = match;
        return;
    }
    [_lanDevices addObject:match];
}
- (void)findLAN {
    if (_lanScanning) return;
    NSMutableArray<NSString *> *peers = [ACWiFiPeers() mutableCopy];
    for (NSString *host in @[@"192.168.0.31", @"192.168.0.15"]) {
        if (![peers containsObject:host]) continue;
        [peers removeObject:host];
        [peers insertObject:host atIndex:0];
    }
    if (!peers.count) { [self alert:@"Поиск недоступен" body:@"Подключитесь к частной Wi‑Fi сети."]; return; }
    _lanScanning = YES;
    _lanScanFinished = NO;
    _lanRemaining = peers.count;
    [self.tableView reloadData];

    __block NSUInteger next = 0;
    __weak typeof(self) weakSelf = self;
    __block void (^scan)(void);
    scan = ^{
        typeof(self) self = weakSelf;
        if (!self) { scan = nil; return; }
        if (next == peers.count) return;
        NSString *host = peers[next++];
        dispatch_group_t requests = dispatch_group_create();
        dispatch_group_enter(requests);
        ACRequestWithTimeout(host, 8000, @"/", @"Instruct", @"getStatusEx", nil, nil, 2.5, ^(NSData *acs) {
            NSDictionary *status = ACACSStatus(acs);
            if (status) {
                NSString *label = [NSString stringWithFormat:@"%@ · A33", status[@"DevName"] ?: status[@"ProjectName"]];
                [self registerLAN:@{@"label":label, @"url":[NSURLComponents componentsWithString:[@"http://" stringByAppendingString:host]], @"libre":@NO}];
                [self.tableView reloadData];
            }
            dispatch_group_leave(requests);
        });
        dispatch_group_enter(requests);
        ACRequestWithTimeout(host, 49494, @"/description.xml", nil, nil, nil, nil, 2.5, ^(NSData *data) {
            DDXMLNode *root = ACXMLData(data);
            NSString *model = ACDIDL(root, @"modelName");
            if (model.length && [model caseInsensitiveCompare:@"LP10"] == NSOrderedSame &&
                [ACDIDL(root, @"deviceType") isEqualToString:@"urn:schemas-upnp-org:device:MediaRenderer:1"]) {
                NSString *label = [NSString stringWithFormat:@"%@ · Libre", ACText(ACDIDL(root, @"friendlyName")) ?: model];
                NSString *url = [NSString stringWithFormat:@"http://%@:49494/description.xml", host];
                [self registerLAN:@{@"label":label, @"url":[NSURLComponents componentsWithString:url], @"libre":@YES}];
                [self.tableView reloadData];
            }
            dispatch_group_leave(requests);
        });
        dispatch_group_notify(requests, dispatch_get_main_queue(), ^{
            self->_lanRemaining--;
            if (!self->_lanRemaining) {
                scan = nil;
                self->_lanScanning = NO;
                self->_lanScanFinished = YES;
                [self.tableView reloadData];
            } else {
                scan();
            }
        });
    };
    for (NSUInteger worker = 0; worker < MIN(24, peers.count); worker++) scan();
}
- (NSString *)lanIdentityForURL:(NSURLComponents *)url libre:(BOOL)libre {
    return [NSString stringWithFormat:@"%@:%@", libre ? @"libre" : @"acs2", url.URL.absoluteString];
}
- (void)openLAN:(NSURLComponents *)url libre:(BOOL)libre {
    NSString *identity = [self lanIdentityForURL:url libre:libre];
    if ([_store.targetID isEqualToString:identity] && _store.selectedLANPlayer) {
        [self nowPlaying];
        return;
    }
    ACLANPlayer *page = [[ACLANPlayer alloc] initWithEndpoint:url libre:libre];
    __weak ACStore *store = _store;
    __weak ACLANPlayer *selectedPage = page;
    page.isSelected = ^BOOL { return selectedPage && store.selectedLANPlayer == selectedPage; };
    __weak typeof(self) weakSelf = self;
    page.onVerified = ^(NSString *name) {
        typeof(self) self = weakSelf;
        if (!self) return;
        NSString *label = [NSString stringWithFormat:@"%@ · %@", name, libre ? @"Libre" : @"A33"];
        [self registerLAN:@{@"label":label, @"url":url, @"libre":@(libre)}];
        [self.tableView reloadData];
    };
    [_store selectLANPlayer:page identity:identity];
    [self nowPlaying];
}
- (void)connectLAN {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Подключить устройство"
        message:@"Введите IP устройства. Для Libre с другим портом введите полный адрес UPnP-описания." preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.placeholder = @"192.168.0.10 или http://…/description.xml";
        field.autocorrectionType = UITextAutocorrectionTypeNo;
        field.autocapitalizationType = UITextAutocapitalizationTypeNone;
    }];
    for (NSString *family in @[@"A33", @"Libre"]) {
        [alert addAction:[UIAlertAction actionWithTitle:family style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            BOOL libre = [family isEqualToString:@"Libre"];
            NSString *input = [alert.textFields.firstObject.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
            if (libre && ![input containsString:@"://"])
                input = [NSString stringWithFormat:@"http://%@:49494/description.xml", input];
            NSURLComponents *url = [NSURLComponents componentsWithString:libre ? input : [@"http://" stringByAppendingString:input]];
            if (!url.host.length || ![url.scheme isEqualToString:@"http"] || url.user || url.password || url.query || url.fragment ||
                (libre && !url.path.length) || (!libre && (url.path.length || url.port))) {
                dispatch_async(dispatch_get_main_queue(), ^{ [self alert:@"Проверьте адрес" body:nil]; });
                return;
            }
            [self openLAN:url libre:libre];
        }]];
    }
    [alert addAction:[UIAlertAction actionWithTitle:@"Найти в Wi‑Fi" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [self findLAN];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Отмена" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}
- (void)rescan { [_store refresh]; [self findLAN]; [self.refreshControl endRefreshing]; }
- (void)updatePage {
    if (_section == ACSettings) {
        self.title = ACT(@"Налаштування", @"Settings", @"הגדרות", @"Настройки");
        self.tabBarItem.title = self.title;
        if (_items.count > 0) {
            NSMutableArray *rows = [_items mutableCopy];
            NSArray *infoRow = rows[0];
            rows[0] = @[infoRow[0], _store.selected ? ACName(_store.selected) : @"—", infoRow[2]];
            _items = rows;
            if (self.isViewLoaded) [self.tableView reloadData];
        }
    }
    LPDevice *device = _store.selected;
    NSString *target = _store.targetID;
    NSString *family = [target hasPrefix:@"libre:"] ? @"Libre" : @"A33";
    _mini.hidden = !device && !_store.selectedLANPlayer;
    _miniTitle.text = device ? ACName(device) : family;
    _miniSubtitle.text = device ? (ACText(device.mediaInfo.title) ?: ACText(device.mediaInfo.trackSource) ?: @"Нет выбранной музыки") : @"Подключённое устройство";
    BOOL miniPlaying = device.deviceInfo && device.deviceInfo.playStatus == LP_PLAYER_STATE_PLAYING;
    [_miniToggle setImage:[UIImage systemImageNamed:miniPlaying ? @"pause.fill" : @"play.fill"] forState:UIControlStateNormal];
    _miniToggle.enabled = device && [_store isOnline:device];
    _miniNext.enabled = device && [_store isOnline:device];
    _miniNext.alpha = _miniNext.enabled ? 1 : .45;
    NSString *artwork = ACText(device.mediaInfo.artworkUri);
    NSURL *artURL = ACStreamURL(artwork);
    NSString *urlString = artURL.absoluteString ?: @"";
    if (![_miniCoverURL isEqualToString:urlString]) {
        _miniCoverURL = urlString;
        [_miniArt sd_setImageWithURL:artURL placeholderImage:[UIImage systemImageNamed:@"music.note"]
                             options:SDWebImageRetryFailed | SDWebImageLowPriority];
    }
    if (_section == ACBrowse) {
        NSMutableArray *rows = [_items mutableCopy];
        NSString *zone = device ? ACName(device) : (_store.selectedLANPlayer ? family : @"Выберите зону");
        rows[0] = @[[NSString stringWithFormat:@"Зона · %@", zone], @"Коснитесь, чтобы выбрать устройство", @"hifispeaker.fill"];
        NSString *source = ACText(device.mediaInfo.trackSource) ?: @"Выбрать вход на текущей зоне";
        rows[1] = @[@"Входы и источники", source, @"slider.horizontal.3"];
        _items = rows;
    }
    if (_section == ACDevices) {
        LPDeviceManager *manager = [LPDeviceManager sharedInstance];
        NSMutableArray<LPDevice *> *ordered = [NSMutableArray array];
        NSMutableArray<NSDictionary *> *rows = [NSMutableArray array];
        NSMutableSet<NSString *> *used = [NSMutableSet set], *members = [NSMutableSet set], *masters = [NSMutableSet set];
        for (LPDevice *master in manager.getMasterDevices) {
            NSString *masterID = ACDeviceID(master);
            NSArray<LPDevice *> *slaves = masterID.length ? [manager slaveDeviceArray:masterID] : @[];
            if (!slaves.count) continue;
            if (masterID.length) { [members addObject:masterID]; [masters addObject:masterID]; }
            [rows addObject:@{@"master":master, @"members":[slaves copy]}];
            [ordered addObject:master]; if (masterID.length) [used addObject:masterID];
            for (LPDevice *slave in slaves) {
                NSString *slaveID = ACDeviceID(slave);
                if (slaveID.length) { [members addObject:slaveID]; [used addObject:slaveID]; }
                if (slave) [ordered addObject:slave];
            }
        }
        for (LPDevice *device in _store.devices) {
            NSString *identity = ACDeviceID(device);
            if (identity.length && ![used containsObject:identity]) {
                [ordered addObject:device];
                [rows addObject:@{@"device":device}];
            }
            NSString *masterID = device.deviceStatus.masterID;
            if (identity.length && device.deviceStatus.roomState == LP_ROOM_SLAVE && masterID.length) [members addObject:identity];
        }
        _devices = ordered;
        _deviceRows = rows;
        _multiroomIDs = members; _multiroomMasterIDs = masters;
        NSUInteger connectedCount = 0;
        for (LPDevice *connected in ordered) if ([_store isOnline:connected]) connectedCount++;
        connectedCount += _lanDevices.count;
        NSString *unit = ACT(connectedCount == 1 ? @"пристрій" : @"пристрої",
                             connectedCount == 1 ? @"device" : @"devices",
                             connectedCount == 1 ? @"מכשיר" : @"התקנים",
                             connectedCount == 1 ? @"устройство" : @"устройства");
        _devicesCountLabel.text = [NSString stringWithFormat:@"(%lu %@)", (unsigned long)connectedCount, unit];
    } else _devices = _store.devices;
    if (_section == ACDevices || ![_shownID isEqualToString:_store.targetID]) {
        _shownID = [_store.targetID copy];
        [self.tableView reloadData];
    }
}
- (void)nowPlaying {
    ACLANPlayer *lan = _store.selectedLANPlayer;
    if (lan) {
        UINavigationController *nav = (UINavigationController *)self.tabBarController.viewControllers[ACDevices];
        self.tabBarController.selectedIndex = ACDevices;
        if ([nav.viewControllers containsObject:lan]) [nav popToViewController:lan animated:YES];
        else [nav pushViewController:lan animated:YES];
        return;
    }
    if (_store.selected) [self.navigationController pushViewController:[[ACNowPlaying alloc] initWithStore:_store] animated:YES];
}
- (void)alert:(NSString *)title body:(NSString *)body {
    if (self.navigationController.topViewController != self || self.presentedViewController) return;
    UIAlertController *a = [UIAlertController alertControllerWithTitle:title message:body preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}
- (LPDevice *)deviceForID:(NSString *)deviceID {
    for (LPDevice *device in _store.devices) if ([ACDeviceID(device) isEqualToString:deviceID]) return device;
    return nil;
}
- (void)setVolume:(float)value forDeviceID:(NSString *)deviceID {
    LPDevice *device = [self deviceForID:deviceID];
    if (!device || ![_store isOnline:device]) return;
    // The compact card sends a single command after touch-up, avoiding a burst
    // of volume requests while the user is dragging.
    [[device getPlayer] setVolume:(NSInteger)lrintf(MIN(100, MAX(0, value)))];
}
- (void)togglePlaybackForDeviceID:(NSString *)deviceID {
    LPDevice *device = [self deviceForID:deviceID];
    if (!device || ![_store isOnline:device]) return;
    LPDevicePlayer *player = [device getPlayer];
    if (!player) return;
    BOOL playing = device.deviceInfo && device.deviceInfo.playStatus == LP_PLAYER_STATE_PLAYING;
    __weak typeof(self) weakSelf = self;
    LPPlayerBlock completion = ^(BOOL success, NSString *result) {
        dispatch_async(dispatch_get_main_queue(), ^{
            typeof(self) self = weakSelf;
            if (!self || !success) return;
            if ([ACDeviceID(self->_store.selected) isEqualToString:deviceID]) [device.deviceInfo updateCurrentPlayInfo];
            [self.tableView reloadData];
        });
    };
    if (playing) [player pause:completion]; else [player play:completion];
}
- (void)openSettingsForDeviceID:(NSString *)deviceID {
    LPDevice *device = [self deviceForID:deviceID];
    if (!device || ![_store isOnline:device]) return;
    [_store select:device];
    self.tabBarController.selectedIndex = ACSettings;
}
- (void)openMultiroomForDeviceID:(NSString *)deviceID {
    LPDevice *device = [self deviceForID:deviceID];
    if (!device || ![_store isOnline:device]) return;
    [_store select:device];
    LPMultiroomViewController *multiroom = [LPMultiroomViewController new];
    multiroom.uuid = deviceID;
    [self.navigationController pushViewController:multiroom animated:YES];
}
- (void)chooseMusicForDeviceID:(NSString *)deviceID {
    LPDevice *device = [self deviceForID:deviceID];
    if (!device || ![_store isOnline:device]) return;
    [_store select:device];
    self.tabBarController.selectedIndex = ACBrowse;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _section == ACDevices ? MAX(_deviceRows.count + _lanDevices.count + ((_lanScanning || (_lanScanFinished && !_lanDevices.count)) ? 1 : 0), 1) : _items.count;
}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (_section == ACDevices) {
        if (indexPath.row < _deviceRows.count) {
            NSDictionary *row = _deviceRows[indexPath.row];
            NSArray *members = row[@"members"];
            return members.count ? 254 + MIN(members.count + 1, 5) * 38 : 220;
        }
        if (indexPath.row - _deviceRows.count < _lanDevices.count) return 130;
        return 62;
    }
    if (_section == ACBrowse && indexPath.row < _browseActions.count && _browseActions[indexPath.row].integerValue == -1) return 38;
    return 62;
}
- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return (_section == ACDevices || _section == ACBrowse) ? 0.01 : 34;
}
- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    if (_section == ACBrowse) return [UIView new];
    UILabel *label = [UILabel new];
    label.text = [self tableView:tableView titleForHeaderInSection:section];
    label.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    label.textColor = ACSecondaryText();
    label.backgroundColor = ACBackground();
    label.text = [NSString stringWithFormat:@"  %@", label.text ?: @""];
    return label;
}
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (_section == ACDevices || _section == ACBrowse) return @"";
    LPDevice *selectedZone = _store.selected;
    return selectedZone ? ACName(selectedZone) : ACMenuText(@"Выбранное устройство");
}
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)p {
    if (_section == ACDevices) {
        if (p.row >= _deviceRows.count) {
            NSUInteger index = p.row - _deviceRows.count;
            if (index < _lanDevices.count) {
                NSDictionary *match = _lanDevices[index];
                NSURLComponents *url = match[@"url"];
                NSString *identity = [self lanIdentityForURL:url libre:[match[@"libre"] boolValue]];
                ACDeviceCardCell *cell = [t dequeueReusableCellWithIdentifier:@"ACDeviceCard"];
                if (!cell) cell = [[ACDeviceCardCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"ACDeviceCard"];
                cell.contentView.backgroundColor = [_store.targetID isEqualToString:identity] ? [UIColor colorWithWhite:.106 alpha:1] : ACCard();
                [cell configureLAN:match[@"label"] subtitle:url.host selected:[_store.targetID isEqualToString:identity]];
                __weak typeof(self) weakSelf = self;
                cell.onSelect = ^{ [weakSelf openLAN:url libre:[match[@"libre"] boolValue]]; };
                return cell;
            }
            if (_lanScanning) return ACCell(@"Ищу A33 и Libre", nil, @"wifi");
            if (_lanScanFinished) return ACCell(@"A33 и Libre не найдены", @"Можно подключиться по адресу через A33 / Libre.", @"info.circle");
            return ACCell(@"Ищу устройства Linkplay", @"Разрешите локальную сеть. Потяните вниз для повторного поиска.", @"wifi");
        }
        NSDictionary *row = _deviceRows[p.row];
        LPDevice *groupMaster = row[@"master"];
        if (groupMaster) {
            NSArray<LPDevice *> *groupMembers = row[@"members"] ?: @[];
            ACMultiroomGroupCell *cell = [t dequeueReusableCellWithIdentifier:@"ACMultiroomGroup"];
            if (!cell) cell = [[ACMultiroomGroupCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"ACMultiroomGroup"];
            NSString *masterID = ACDeviceID(groupMaster);
            [cell configureMaster:groupMaster members:groupMembers
                selected:[masterID isEqualToString:_store.selectedID] online:[_store isOnline:groupMaster]];
            __weak typeof(self) weakSelf = self;
            cell.onLink = ^{ [weakSelf openMultiroomForDeviceID:masterID]; };
            cell.onVolume = ^(LPDevice *device, float value) { [weakSelf setVolume:value forDeviceID:ACDeviceID(device)]; };
            cell.onSettings = ^(LPDevice *device) { [weakSelf openSettingsForDeviceID:ACDeviceID(device)]; };
            return cell;
        }
        LPDevice *d = row[@"device"];
        if (!d) return ACCell(@"Устройство недоступно", nil, @"info.circle");
        BOOL online = [_store isOnline:d];
        BOOL selected = online && [d.deviceStatus.UUID isEqualToString:_store.selectedID];
        ACDeviceCardCell *cell = [t dequeueReusableCellWithIdentifier:@"ACDeviceCard"];
        if (!cell) cell = [[ACDeviceCardCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"ACDeviceCard"];
        cell.contentView.backgroundColor = selected ? [UIColor colorWithWhite:.106 alpha:1] : ACCard();
        NSString *deviceIDForGroup = ACDeviceID(d);
        [cell configureDevice:d online:online selected:selected
            multiroomMember:[_multiroomIDs containsObject:deviceIDForGroup]
            master:[_multiroomMasterIDs containsObject:deviceIDForGroup]];
        NSString *identity = [ACDeviceID(d) copy];
        __weak typeof(self) weakSelf = self;
        cell.onSelect = ^{
            typeof(self) self = weakSelf; if (!self) return;
            LPDevice *current = nil;
            for (LPDevice *candidate in self->_store.devices) if ([ACDeviceID(candidate) isEqualToString:identity]) { current = candidate; break; }
            if (!current) { [self->_store refresh]; return; }
            if (![self->_store isOnline:current]) { [self->_store refresh]; return; }
            [self->_store select:current];
        };
        cell.onLink = ^{ [weakSelf openMultiroomForDeviceID:identity]; };
        cell.onTogglePlayback = ^{ [weakSelf togglePlaybackForDeviceID:identity]; };
        cell.onChooseMusic = ^{ [weakSelf chooseMusicForDeviceID:identity]; };
        cell.onSettings = ^{ [weakSelf openSettingsForDeviceID:identity]; };
        cell.onVolume = ^(float value) { [weakSelf setVolume:value forDeviceID:identity]; };
        return cell;
    }
    if (_section == ACBrowse && p.row < _browseActions.count && _browseActions[p.row].integerValue == -1) {
        UITableViewCell *heading = [UITableViewCell new];
        heading.backgroundColor = ACBackground(); heading.contentView.backgroundColor = ACBackground();
        heading.selectionStyle = UITableViewCellSelectionStyleNone;
        heading.textLabel.text = ACMenuText(_items[p.row][0]);
        heading.textLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
        heading.textLabel.textColor = ACSecondaryText();
        return heading;
    }
    NSArray *item = _items[p.row];
    UITableViewCell *cell = ACCell(item[0], item[1], item[2]);
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}
- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)p {
    [t deselectRowAtIndexPath:p animated:YES];
    if (_section == ACDevices) {
        if (p.row >= _deviceRows.count) {
            NSUInteger index = p.row - _deviceRows.count;
            if (index < _lanDevices.count) {
                NSDictionary *match = _lanDevices[index];
                [self openLAN:match[@"url"] libre:[match[@"libre"] boolValue]];
            }
            return;
        }
        NSDictionary *row = _deviceRows[p.row];
        LPDevice *device = row[@"master"] ?: row[@"device"];
        if (!device || ![_store isOnline:device]) { [_store refresh]; return; }
        [_store select:device];
        [self nowPlaying];
        return;
    }
    NSInteger browseAction = (_section == ACBrowse && p.row < _browseActions.count) ? _browseActions[p.row].integerValue : NSIntegerMax;
    if (_section == ACBrowse && browseAction == -1) return;
    if (_section == ACBrowse && browseAction == -2) {
        self.tabBarController.selectedIndex = ACDevices;
        return;
    }
    if (_section == ACBrowse && browseAction == -3) {
        if (_store.selected) [self showInputs:_store.selected];
        else if (_store.selectedLANPlayer) [self alert:@"Источники A33 / Libre" body:@"Переключение входов этой зоны доступно на странице устройства."];
        else [self alert:@"Выберите зону" body:@"Сначала выберите устройство во вкладке «Устройства»."];
        return;
    }
    if (_section == ACSettings && p.row == 0) {
        if (!_store.selected) { [self alert:ACT(@"Выберите зону", @"Select a zone", @"בחר אזור", @"Выберите зону") body:nil]; return; }
        ACDeviceSettingsDetail *detail = [ACDeviceSettingsDetail new]; detail.device = _store.selected;
        [self.navigationController pushViewController:detail animated:YES]; return;
    }
    if (_section == ACSettings && p.row == 1) {
        if (!_store.selected) { [self alert:ACT(@"Выберите зону", @"Select a zone", @"בחר אזור", @"Выберите зону") body:nil]; return; }
        ACDeviceSettingsDetail *detail = [ACDeviceSettingsDetail new]; detail.device = _store.selected; detail.networkPage = YES;
        [self.navigationController pushViewController:detail animated:YES]; return;
    }
    if (_section == ACSettings && p.row == 2) {
        NSArray<NSString *> *codes = @[@"auto", @"uk", @"en", @"he", @"ru"];
        UIAlertController *picker = [UIAlertController alertControllerWithTitle:ACT(@"Мова інтерфейсу", @"Interface language", @"שפת הממשק", @"Язык интерфейса") message:ACT(@"Автоматично використовує мову iPhone, якщо вона підтримується.", @"Automatically follows iPhone language when supported.", @"בחירה אוטומטית של שפת iPhone אם היא נתמכת.", @"Автоматически использует язык iPhone, если он поддерживается.") preferredStyle:UIAlertControllerStyleActionSheet];
        NSString *current = [[NSUserDefaults standardUserDefaults] stringForKey:ACLanguagePreferenceKey] ?: @"auto";
        for (NSString *code in codes) {
            NSString *title = [ACLanguageName(code) stringByAppendingString:[code isEqualToString:current] ? @" ✓" : @""];
            [picker addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
                [[NSUserDefaults standardUserDefaults] setObject:code forKey:ACLanguagePreferenceKey];
                [self rebuildLocalizedInterface];
            }]];
        }
        [picker addAction:[UIAlertAction actionWithTitle:ACT(@"Скасувати", @"Cancel", @"ביטול", @"Отмена") style:UIAlertActionStyleCancel handler:nil]];
        picker.popoverPresentationController.sourceView = self.view;
        picker.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 1, 1);
        [self presentViewController:picker animated:YES completion:nil];
        return;
    }
    if (_section == ACSettings && p.row > 2) p = [NSIndexPath indexPathForRow:p.row - 3 inSection:p.section];
    if (_section == ACBrowse && browseAction >= 100) {
        NSArray *serviceIDs = @[@"Deezer", @"Qobuz", @"Tidal", @"YouTubeMusic", @"SoundCloud"];
        ACMusicServices *services = [[ACMusicServices alloc] initWithStyle:UITableViewStyleInsetGrouped];
        services.store = _store; services.initialServiceID = serviceIDs[browseAction - 100];
        [self.navigationController pushViewController:services animated:YES];
        return;
    }
    if (_section == ACSettings && p.row == 5) {
    [self alert:@"airControl iOS" body:ACMenuText(@"Нативная сборка с Linkplay Music Kit 1.0.14.")];
        return;
    }
    if (_section == ACSettings && p.row == 6) {
        ACMusicServices *services = [[ACMusicServices alloc] initWithStyle:UITableViewStyleInsetGrouped];
        services.store = _store;
        [self.navigationController pushViewController:services animated:YES];
        return;
    }
    ACLANPlayer *lan = _store.selectedLANPlayer;
    if (lan) {
        if (_section == ACBrowse && (browseAction == 6 || browseAction == 7)) {
            [self.navigationController pushViewController:[lan catalogWithTuneIn:browseAction == 6] animated:YES];
        } else {
            [self alert:@"Функция недоступна для этой зоны" body:@"Откройте плеер выбранного A33 или Libre в разделе «Устройства»."];
        }
        return;
    }
    LPDevice *d = _store.selected;
    if (!d) { [self alert:@"Выберите устройство" body:@"Откройте вкладку «Устройства» и выберите активную зону."]; return; }
    UIViewController *page;
    if (_section == ACBrowse) {
        switch (browseAction) {
            case 0: case 1: {
                if (!d.deviceInfo) { [self alert:@"Очередь недоступна" body:nil]; return; }
                NSArray *names = @[@"MyFavouriteQueue", @"USBDiskQueue"];
                page = [[ACQueueController alloc] initWithDevice:d queue:names[browseAction] title:_items[p.row][0]];
                break;
            }
            case 3: { PresetViewController *v = [PresetViewController new]; v.deviceId = d.deviceStatus.UUID; page = v; break; }
            case 4: { LPNASViewController *v = [LPNASViewController new]; v.uuid = d.deviceStatus.UUID; page = v; break; }
            case 5: { LPLocalMusicViewController *v = [LPLocalMusicViewController new]; v.uuid = d.deviceStatus.UUID; page = v; break; }
            case 6: case 7: {
                NSString *identity = [ACDeviceID(d) copy];
                __weak typeof(self) weakSelf = self;
                page = [[ACRadioCatalog alloc] initWithTuneIn:browseAction == 6 play:^(NSDictionary *station, NSURL *url, void (^done)(BOOL)) {
                    typeof(self) self = weakSelf;
                    LPDevice *selected = self ? self->_store.selected : nil;
                    if (!url || ![ACDeviceID(selected) isEqualToString:identity]) { done(NO); return; }
                    LPPlayHeader *header = [LPPlayHeader new];
                    header.headTitle = station[@"name"]; header.headId = url.absoluteString;
                    header.headType = LP_HEADER_TYPE_STATION; header.mediaType = MEDIATYPE_RADIO;
                    header.mediaSource = UPNPSERVER_SOURCE; header.imageUrl = station[@"art"];
                    LPPlayItem *item = [LPPlayItem new];
                    item.trackName = header.headTitle; item.trackId = header.headId;
                    item.trackUrl = url.absoluteString; item.trackImage = header.imageUrl;
                    LPPlayMusicList *list = [LPPlayMusicList new];
                    list.header = header; list.list = @[item]; list.index = 0;
                    NSDictionary *payload = [[LPMDPKitManager shared] playMusicSingleSource:list];
                    LPDevicePlayer *player = [selected getPlayer];
                    if (!payload.count || !player) { done(NO); return; }
                    [player playAudioWithMusicDictionary:payload completionHandler:^(BOOL success, NSString *response) { done(success); }];
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{ done(NO); });
                }];
                break;
            }
        }
    } else {
        switch (p.row) {
            case 0: [self showInputs:d]; break;
            case 1: page = [[ACEqualizerController alloc] initWithDevice:d]; break;
            case 2: { LPMultiroomViewController *v = [LPMultiroomViewController new]; v.uuid = d.deviceStatus.UUID; page = v; break; }
            case 3: { AlarmClockMainViewController *v = [AlarmClockMainViewController new]; v.deviceId = d.deviceStatus.UUID; page = v; break; }
            case 4: [self showSleep:d]; break;
        }
    }
    if (page) [self.navigationController pushViewController:page animated:YES];
}
- (void)showInputs:(LPDevice *)device {
    ACReadJSON(device, @"getStatusEx", ^(NSDictionary *status) {
        if (![ACDeviceID(self->_store.selected) isEqualToString:ACDeviceID(device)]) return;
        NSMutableOrderedSet<NSNumber *> *supported = [NSMutableOrderedSet orderedSet];
        id field = status[@"plm_support"] ?: status[@"plms"];
        NSString *maskText = [field isKindOfClass:NSString.class] || [field isKindOfClass:NSNumber.class] ? [field description] : @"";
        NSScanner *scanner = [NSScanner scannerWithString:maskText];
        unsigned long long mask = 0;
        BOOL hasMask = [maskText.lowercaseString hasPrefix:@"0x"] ?
            [scanner scanHexLongLong:&mask] && scanner.isAtEnd : [scanner scanUnsignedLongLong:&mask] && scanner.isAtEnd;
#ifndef LINKPLAY_PUBLIC_HEADER
        mask |= device.deviceStatus.plms;
#endif
        if (hasMask || mask) {
            // Linkplay SDK 1.0.14 maps these status bits to LPInputSource.
            NSDictionary *bits = @{@1:@(LPLineIn), @2:@(LPBluetooth), @3:@(LPUSB), @4:@(LPOptical),
                @5:@(LPRCA), @7:@(LPRadio), @10:@(LPHDMI), @13:@(LPTFCard)};
            [supported addObject:@(LPWiFi)];
            for (NSNumber *bit in [[bits allKeys] sortedArrayUsingSelector:@selector(compare:)]) {
                if (mask & (1ULL << bit.unsignedIntValue)) [supported addObject:bits[bit]];
            }
        }
        for (id value in [device.deviceSettings getSupportInputSource]) {
                if (![value isKindOfClass:NSNumber.class] && ![value isKindOfClass:NSString.class]) continue;
                NSScanner *entry = [NSScanner scannerWithString:[value description]];
                NSInteger source;
                if ([entry scanInteger:&source] && entry.isAtEnd && source >= LPLineIn && source <= LPXLR)
                    [supported addObject:@(source)];
        }
        BOOL checkUSB = [status[@"project"] isEqual:@"UP2STREAM_PRO_V4"] && ![supported containsObject:@(LPUSB)];
        if (!checkUSB) {
            [self presentInputs:supported device:device];
            return;
        }
        // The tested A31 can publish a populated USB queue without advertising the legacy USB bit.
        ACReadQueue(device, @"USBDiskQueue", ^(NSString *raw) {
            if ([ACQueueSnapshot read:raw device:device queue:@"USBDiskQueue"].rows.count)
                [supported addObject:@(LPUSB)];
            [self presentInputs:supported device:device];
        });
    });
}
- (void)presentInputs:(NSOrderedSet<NSNumber *> *)supported device:(LPDevice *)device {
    if (![ACDeviceID(_store.selected) isEqualToString:ACDeviceID(device)] ||
        self.navigationController.topViewController != self || self.presentedViewController) return;
    NSArray *names = @[@"Линейный вход", @"Bluetooth", @"USB", @"Радио", @"RCA", @"HDMI", @"Оптический", @"Сеть", @"TF-карта", @"XLR"];
    if (!supported.count) { [self alert:ACMenuText(@"Входы недоступны") body:ACMenuText(@"Устройство не сообщило список поддерживаемых входов.")]; return; }
    UIAlertController *a = [UIAlertController alertControllerWithTitle:ACMenuText(@"Вход устройства") message:nil preferredStyle:UIAlertControllerStyleAlert];
    for (NSNumber *value in supported) {
        NSInteger source = value.integerValue;
        [a addAction:[UIAlertAction actionWithTitle:ACMenuText(names[source]) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            LPDevice *selected = self->_store.selected;
            if (![ACDeviceID(selected) isEqualToString:ACDeviceID(device)]) return;
            [selected.deviceSettings switchInputSource:(LPInputSource)source completionHandler:^(NSURLResponse *response, id result, NSError *error) {
                if (error) dispatch_async(dispatch_get_main_queue(), ^{ [self alert:ACMenuText(@"Не удалось сменить вход") body:nil]; });
            }];
        }]];
    }
    [a addAction:[UIAlertAction actionWithTitle:ACMenuText(@"Cancel") style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}
- (void)showEQ:(LPDevice *)device {
    ACReadJSON(device, @"EQGet", ^(NSDictionary *tone) {
        if (![ACDeviceID(self->_store.selected) isEqualToString:ACDeviceID(device)]) return;
        NSNumber *bass = tone[@"Bass"], *treble = tone[@"Treble"], *enabled = tone[@"EQEnable"];
        if ([bass isKindOfClass:NSNumber.class] && [treble isKindOfClass:NSNumber.class] && [enabled isKindOfClass:NSNumber.class]) {
            NSString *body = [NSString stringWithFormat:@"%@\n%@: %@\n%@: %@", ACMenuText(enabled.boolValue ? @"Включён" : @"Выключен"), ACMenuText(@"Низкие"), bass, ACMenuText(@"Высокие"), treble];
            [self alert:ACMenuText(@"Эквалайзер") body:body];
            return;
        }
        [device.deviceSettings getSupportEQAndValues:^(NSURLResponse *response, id result, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (![ACDeviceID(self->_store.selected) isEqualToString:ACDeviceID(device)]) return;
                if (error || ![result isKindOfClass:NSDictionary.class] || ![result count]) {
                    [self alert:ACMenuText(@"Эквалайзер недоступен") body:ACMenuText(@"Устройство не вернуло настройки эквалайзера.")];
                    return;
                }
                NSDictionary *eq = result;
                NSMutableArray<NSString *> *lines = [NSMutableArray array];
                id bands = eq[@"EQValue"];
                if ([bands isKindOfClass:NSArray.class]) {
                    for (id band in bands) {
                        if (![band isKindOfClass:NSDictionary.class]) continue;
                        id name = band[@"Name"], value = band[@"Value"];
                        if ([name isKindOfClass:NSString.class] &&
                            ([value isKindOfClass:NSNumber.class] || [value isKindOfClass:NSString.class]))
                            [lines addObject:[NSString stringWithFormat:@"%@: %@", name, value]];
                    }
                }
                for (NSString *key in @[@"Mode", @"Bass", @"Treble", @"EQEnable"]) {
                    id value = eq[key];
                    if ([value isKindOfClass:NSString.class] || [value isKindOfClass:NSNumber.class])
                        [lines addObject:[NSString stringWithFormat:@"%@: %@", ACMenuText(key), value]];
                }
                [self alert:ACMenuText(@"Эквалайзер") body:lines.count ? [lines componentsJoinedByString:@"\n"] :
                    ACMenuText(@"Устройство не вернуло числовые значения полос.")];
            });
        }];
    });
}
- (void)showSleep:(LPDevice *)device {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:ACMenuText(@"Таймер сна") message:ACName(device) preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:ACMenuText(@"Выключить через 30 минут") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        if (self->_store.selected != device) return;
        [[device getTimer] setTimerWithTime:1800 completionHandler:^(NSURLResponse *response, id result, NSError *error) {
            if (error) dispatch_async(dispatch_get_main_queue(), ^{ [self alert:ACMenuText(@"Таймер не установлен") body:nil]; });
        }];
    }]];
    [a addAction:[UIAlertAction actionWithTitle:ACMenuText(@"Cancel") style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}
@end

@implementation ACHome {
    ACStore *_store;
    NSString *_screenDeviceID;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    UIView.appearance.semanticContentAttribute = [ACLanguageCode() isEqualToString:@"he"] ? UISemanticContentAttributeForceRightToLeft : UISemanticContentAttributeForceLeftToRight;
    self.view.backgroundColor = ACBackground();
    self.view.tintColor = ACAccent();
    self.tabBar.tintColor = ACAccent();
    UITableView.appearance.backgroundColor = ACBackground();
    UITableView.appearance.separatorColor = ACSeparator();
    UITableViewCell.appearance.backgroundColor = ACCard();
    UISearchBar.appearance.barTintColor = ACCard();
    UISearchTextField.appearance.textColor = ACPrimaryText();
    UISearchTextField.appearance.backgroundColor = ACCard();
    UIBarButtonItem.appearance.tintColor = ACPrimaryText();
    UINavigationBar.appearance.tintColor = ACPrimaryText();
    UINavigationBarAppearance *navigationAppearance = [UINavigationBarAppearance new];
    [navigationAppearance configureWithOpaqueBackground];
    navigationAppearance.backgroundColor = ACBackground();
    navigationAppearance.titleTextAttributes = @{NSForegroundColorAttributeName:ACPrimaryText()};
    navigationAppearance.largeTitleTextAttributes = @{NSForegroundColorAttributeName:ACPrimaryText()};
    UINavigationBar.appearance.standardAppearance = navigationAppearance;
    UINavigationBar.appearance.scrollEdgeAppearance = navigationAppearance;
    UITabBarAppearance *tabAppearance = [UITabBarAppearance new];
    [tabAppearance configureWithOpaqueBackground];
    tabAppearance.backgroundColor = ACCard();
    UITabBar.appearance.standardAppearance = tabAppearance;
    UITabBar.appearance.scrollEdgeAppearance = tabAppearance;
    self.tabBar.barTintColor = ACCard();
    self.tabBar.backgroundColor = ACCard();
    _store = [ACStore new];
    NSMutableArray *tabs = [NSMutableArray array];
    for (ACSection index = ACBrowse; index <= ACSettings; index++) {
        ACPage *page = [[ACPage alloc] initWithStore:_store section:index];
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:page];
        nav.tabBarItem = page.tabBarItem;
        [tabs addObject:nav];
    }
    self.viewControllers = tabs;
    self.selectedIndex = ACDevices;
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(selectionChanged:)
                                              name:ACChanged object:_store];
}
- (void)selectionChanged:(NSNotification *)notification {
    NSString *identity = _store.targetID;
    if (!identity.length || [_screenDeviceID isEqualToString:identity]) return;
    _screenDeviceID = [identity copy];
    for (UINavigationController *nav in self.viewControllers) {
        [nav.topViewController dismissViewControllerAnimated:NO completion:nil];
        [nav popToRootViewControllerAnimated:NO];
    }
}
- (void)setDiscoveryActive:(BOOL)active {
    [self loadViewIfNeeded];
    [_store setActive:active];
}
@end
