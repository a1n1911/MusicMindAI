# MusicMind

## RU

MusicMind — это pet-проект iOS-приложения на SwiftUI для работы с музыкой из разных сервисов в одном месте.

Что уже реализовано:
- подключение Яндекс.Музыки, SoundCloud и VK;
- AI-анализ музыкального вкуса и треков;
- создание плейлистов по текстовому запросу;
- миграция треков в Яндекс.Музыку;
- экспорт треков в CSV.

Проект сделан как портфолио-практика по SwiftUI, работе с API и AI-интеграциям.

## EN

MusicMind is a SwiftUI iOS pet project for managing music from multiple services in one app.

Implemented features:
- Yandex Music, SoundCloud, and VK integrations;
- AI-based music taste and track analysis;
- playlist generation from a text prompt;
- track migration to Yandex Music;
- CSV export for tracks.

This project is built as a portfolio app to practice SwiftUI, external API integrations, and AI features.

## Setup

### RU
1. Открой проект в Xcode.
2. Добавь переменную окружения `GEMINI_API_KEY` в Scheme:
   - Product -> Scheme -> Edit Scheme... -> Run -> Arguments -> Environment Variables.
3. Вставь свой ключ Gemini в значение `GEMINI_API_KEY`.
4. Запусти приложение на симуляторе или устройстве.

### EN
1. Open the project in Xcode.
2. Add `GEMINI_API_KEY` as an environment variable in your Scheme:
   - Product -> Scheme -> Edit Scheme... -> Run -> Arguments -> Environment Variables.
3. Paste your Gemini API key as the value for `GEMINI_API_KEY`.
4. Run the app on a simulator or device.
