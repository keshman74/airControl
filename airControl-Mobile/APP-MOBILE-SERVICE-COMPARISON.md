# App Mobile · Deezer, Qobuz и TIDAL · 10 ноября 2026

Материалы: `/Users/lab/AI/App Mobile/`. APK исследованы статически. Наблюдения в PCAP отделены от статических выводов; полнота, авторизация и слышимый звук не следуют из существования метода. Значения паролей, токенов, идентификаторов приложений и пользовательских полей из APK и PCAP не включены.

## Матрица

| Клиент | Найденный путь | Уровень подтверждения |
|---|---|---|
| 4STREAM | В старом `FragDeezerLogin.W2()` пользователь вводит данные, клиент преобразует пароль через `WiimuNDK.encryptPwd`, а `action.r.d.f` передаёт `AccountSource=Deezer` в SOAP `UserLogin`. Конструктор `org.teleal.cling.c.a.a.k` добавляет `UserName`, `PassWord`, `SavePass=0`, `Code`, `Proxy`, `Token`. Набор полей запроса определяет описание сервиса прошивки. `DeviceStreamServices.isSupportDeezer2()` отдельно проверяет наличие версии `Deezer2`. Старый экран превращает результат Deezer в `AlbumInfo`/музыкальный список, в APK есть генератор XML очереди и действия `CreateQueue` и `PlayQueueWithIndex`. | Путь входа и общие билдеры подтверждены по APK. Точный исходящий XML успешного старта старого Deezer ещё не снят. |
| WiiM Home | Каталоги Qobuz/Tidal/Deezer отделены от управления очередью. Текущая ветка Deezer использует `Deezer2`. `CreateQueue` несёт контекст каталога и ID трека; отдельный `PlayQueueWithIndex` зависит от версии PlayQueue. | Статический разбор и снимок Qobuz на Office 29. Подтверждение пользователя о старом A31 ожидает повторного захвата. См. `WIIM-SERVICE-PLAYBACK.md`. |
| Muzo Home 3.5.11 | В APK есть собственные пакеты Qobuz/TIDAL. `lpmdpkit/utils/n.java` формирует `SourceName`, `SearchUrl`, `Id`, `URL`, `StartPlayIndex`. `as.d` и `as.l` создают `CreateQueue` и `PlayQueueWithIndex`; `ph.b` проверяет порог 1.2 после создания. | Статически подтверждена та же схема Linkplay PlayQueue. Сетевой запуск Muzo здесь не проверялся. |
| iAudioCloud | A33 TCP/23040. Qobuz `01 40`; TIDAL `00 20`, с `SongList`, `SongPlay`, `StreamMediaName`, `Path`, `Token`. `DeviceModel.setTIDALToken` использует `00 21`. | В `a33-qobuz-test.pcap` найден один целый кадр Qobuz, в `a33.pcap` три. Выделение сигнатур в отдельных пакетах без полной TCP-сборки, поэтому это нижняя оценка. Для TIDAL команды подтверждены по коду, воспроизведение из захвата не подтверждено. |

REA evidence: 4STREAM `ev_06f3ed187f73c7d5e14284f4bc3f8fbd22e58228e00874ed224679895b5ed986`; Muzo `ev_13a6ce515ed85898ac1df6cd74ddb03248d0ad06e547c7f66dd6b49e7efc0ad6`; iAudioCloud `ev_9096de12d6870919fe7e04005cf19a5ecec9afc47d81dcb6e06f2126339d2`. Для WiiM см. предыдущий отчёт.

## Что проверять на запасном A31

1. Снять исходное состояние по IP устройства. Затем запустить один полный трек Deezer в 4STREAM и сразу снять второй снимок. Повторить в WiiM Home. Записывать название клиента и слышимый результат отдельно от сетевого ответа.
2. Сравнить `SourceName` (прежде всего `Deezer` или `Deezer2`), наличие ID, форму `SearchUrl` и `URL`, индекс и состояние плеера. Для исходящей команды нужен отдельный узкий захват телефона ↔ A31 на фактическом порту PlayQueue, по возможности уже после входа, когда пользователь нажимает Play.
3. После сопоставления проверить запуск на airControl. Если старый клиент передаёт контекст через `CreateQueue`, передавать тот же формат в разрешённой сессии на колонке. 4STREAM использует защищённое преобразование пароля, не стоит заменять его открытым паролем или переносить чужую клиентскую сессию. Путь A33 для TIDAL проверять отдельно от A31.
4. Скрипт `/Users/lab/AI/airControl/scripts/linkplay-office29/snapshot_service.py` пишет только сокращённый JSON, без сырого SOAP и значений URL. На Office 29 проверены `getStatusEx`, `getPlayerStatus` и `BrowseQueue` по порту 59152.
