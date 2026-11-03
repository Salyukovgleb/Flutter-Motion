# Flutter Motion

Библиотека анимаций Flutter с нулевой настройкой, цепочками эффектов и пружинами.
Имя основного Dart-пакета — `kinetic_motion`, имя ядра — `motion_core`.

## Состояние разработки

Шаг 3: в `motion_core` реализованы пружины, кривые и шесть эффектов с тестами.
Flutter API ещё не реализован, пакеты не опубликованы. Требования и порядок шагов находятся в
[спецификации](flutter_motion_guide_v2.md).

## Структура

- `packages/motion_core` — чистый Dart, без runtime-зависимостей и `dart:ui`.
- `packages/kinetic_motion` — Flutter-слой, зависит от `motion_core`.
- `example/` — место для галереи и мини-игры в соответствующих шагах.
- `benchmarks/` — место для бенчмарков.
- `docs/adr/` — архитектурные решения.

Расширения `motion_particles`, `motion_flame`, `motion_lints`, `motion_devtools`
будут добавлены на своих шагах. Основной набор API ограничен 12 группами из
раздела 2.2 спецификации; вход `.motion()` сохраняется при новом имени пакета.

## Окружение

Проверяемая исходная версия: Flutter **3.41.2**, Dart **3.11.0**.
CI использует ту же версию Flutter. Общий `pubspec.lock` хранится в Git.
Пакеты workspace перечислены явно, у каждого задано `resolution: workspace`.

```sh
flutter pub get --enforce-lockfile
dart run melos bootstrap --enforce-lockfile
dart run melos run format
dart run melos run analyze --no-select
dart run melos run test --no-select
```

Глобальный Melos необязателен. Для команд `melos bootstrap` и `melos run analyze`:

```sh
dart pub global activate melos 7.8.2
```

Каталог `$HOME/.pub-cache/bin` должен находиться в `PATH`.

## Проверки и покрытие

Ядро тестируется отдельной Dart VM, Flutter-пакет — через `flutter test`.
Артефакты покрытия собираются в `coverage/` каждого пакета и сохраняются CI.
С шага 2 `melos run test:core` проверяет покрытие ядра ≥90% по LCOV. Отсутствующий
или пустой отчёт считается ошибкой. Flutter-библиотека пока пуста: процент
покрытия неприменим. Порог ≥80% для `kinetic_motion` будет включён при появлении
её исполняемого кода.

README и `docs/` ведутся на русском, dartdoc и идентификаторы — на английском.
Правила работы — в [CONTRIBUTING.md](CONTRIBUTING.md). Лицензия — MIT.
