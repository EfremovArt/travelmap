# TravelMap

Приложение для путешествий на базе Flutter с использованием Mapbox карт.

## Mapbox Tokens

В приложении используются два типа токенов Mapbox:

1. **Публичный токен (Public Token)** - используется во время работы приложения для доступа к API Mapbox
   - Расположен в файле `lib/config/mapbox_config.dart` как `ACCESS_TOKEN`
   - Используется в коде для инициализации Mapbox через `MapboxOptions.setAccessToken()`

2. **Приватный токен (Secret Token)** - используется во время сборки Android приложения
   - Расположен в файле `android/gradle.properties` как `MAPBOX_DOWNLOADS_TOKEN`
   - Необходим для загрузки SDK Mapbox в процессе сборки

**Важно!** Оба токена должны принадлежать одному и тому же аккаунту Mapbox.

### Обновление токенов

Для обновления токенов:

1. Войдите в аккаунт Mapbox: [https://account.mapbox.com/](https://account.mapbox.com/)
2. Перейдите в раздел "Tokens"
3. Для обновления публичного токена создайте новый публичный токен и замените значение `ACCESS_TOKEN` в `lib/config/mapbox_config.dart`
4. Для обновления приватного токена создайте новый Secret token с правами "DOWNLOADS:READ" и замените значение `MAPBOX_DOWNLOADS_TOKEN` в `android/gradle.properties`

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
