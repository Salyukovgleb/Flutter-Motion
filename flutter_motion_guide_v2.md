# Flutter Motion v2: сверхпростая библиотека анимаций. Спецификация и пошаговое руководство по разработке

> Название проекта: **Flutter Motion**. Имя Flutter-пакета: `kinetic_motion` (согласовано 2026-11-03; имена `motion` и `flutter_motion` уже заняты). Имя ядра: `motion_core`. Вход `.motion()` и имена типов сохраняются.
> Этот документ заменяет v1: API стал заметно проще, а разработка расписана по шагам с готовым кодом.
> Все числа про производительность и тайминги — стартовые ориентиры, их нужно подтвердить замерами на реальных устройствах.
> Код в документе — рабочие заготовки. Перед использованием сверяйте их с актуальными версиями Dart и Flutter (особенно API `vector_math`, `PaintingContext`, `melos`).

---

## Согласованные уточнения от 2026-11-03

Эти уточнения приняты владельцем после предварительной проверки документа.
Они имеют приоритет над заготовками кода ниже. Заготовки иллюстрируют архитектуру,
но не являются уже проверенной реализацией. Изменения в код вносятся только на
соответствующих шагах 1–20. Новые публичные возможности из этих уточнений не следуют.

1. **Имена и бюджет API.** Проект называется Flutter Motion, Flutter-пакет —
   `kinetic_motion`, точка входа — `package:kinetic_motion/kinetic_motion.dart`.
   Остальные пять пакетов сохраняют имена из раздела 3.4. Таблица 2.2 содержит
   12 групп методов, включая перечисленные направленные варианты. Не добавлять
   `slideStart`, `slideEnd`, `once` или `motion_shaders` без отдельного согласования.
   Отсутствие имени в реестре pub.dev не резервирует его; перед релизом проверить снова.
2. **Окружение и workspace.** Исходная проверяемая версия — Flutter 3.41.2,
   Dart 3.11.0; CI шага 1 закреплён на ней. Минимальная граница SDK — `^3.11.0`,
   Flutter-пакета — `>=3.41.2`. Melos закреплён на 7.8.2, конфигурация в корневом
   `pubspec.yaml`. В корне объявлен `lints`, во всех пакетах — `resolution: workspace`,
   общий lockfile коммитится. Оба CI job устанавливают Flutter: даже чистое ядро
   входит в общий resolver с Flutter-пакетом. Ядро тестируется обычным `dart test`.
   Матрицу двух актуальных стабильных Flutter добавить до релиза по разделам 8–9;
   совместимость вне проверенного SDK пока не заявлять.
3. **Границы шага 1.** Создать только два начальных пакета с пустыми библиотеками,
   удалить шаблонные публичные `Calculator`/`Awesome`. Допустимы тесты загрузки,
   границы Dart-ядра и Flutter test runner. При нуле исполняемых строк процент
   покрытия неприменим (0/0), не объявлять его равным 100%. При появлении реализации
   ввести контроль порогов ≥90% для ядра и ≥80% для Flutter-слоя. Расширения
   создаются на своих шагах, без опережения.
4. **Matrix4 и слои.** В проверенном vector_math 2.2.0 `setValues` принимает
   16 double в порядке хранения по столбцам и возвращает void; каскад в шаге 8
   корректен. `pushTransform` возвращает `TransformLayer?`, `pushOpacity` —
   `OpacityLayer`. Последний вызывает painter с Offset.zero: покрыть тестами
   вложенную трансформацию при ненулевом смещении родителя. `LayerHandle` хранить
   в полях и освобождать через `.layer = null`, как в заготовке.
5. **Compositing.** Изменение `usesOpacity` у того же экземпляра MotionSource
   должно обновлять compositing bits. Подписка рендер-объекта должна замечать это
   изменение, вызывать `markNeedsCompositingBitsUpdate` и `markNeedsPaint`.
   При opacity == 1 слой прозрачности не создаётся.
6. **Нажатия.** Кроме `hitTestChildren` и `applyPaintTransform`, переопределить
   `hitTest` по образцу RenderTransform: базовый RenderBox отсекает смещённые
   точки за своим исходным размером до вызова hitTestChildren. Ограничения предков
   сохраняются. Проверить смещение за исходные границы, поворот, масштаб и вырожденную
   матрицу, а также преобразования для overlay.
7. **Аллокации.** Гарантия отсутствия покадровых аллокаций относится к коду
   библиотеки, а не к внутренностям Flutter SDK: сам PaintingContext.pushTransform
   создаёт матрицу. Внутреннее время хранить числом, не создавать Duration на tick;
   списки, callbacks, буферы и матрицы готовить вне горячего пути. Для внутренних
   вычислений пружин избегать временного record; публичный Spring.solve сохраняет
   сигнатуру из спецификации. Профилировать AOT/profile, отдельно учитывать SDK.
8. **Композиция этапов.** Будущие этапы не должны менять предыдущие до своего
   старта. Правило применения каждого будущего клипа с t=0 из шага 4 недостаточно
   для повторных эффектов одной характеристики через then(). Реализация должна
   учитывать границы этапов, сохранять детерминированные seek/reverse и отсутствие
   вспышки до отложенного первого появления. Проверить повторные fade/scale через then.
9. **Дефолты и параметры.** Раздел 2 и таблица 2.13 имеют приоритет над кодом:
   appear — fade+slide за общие 350 мс; pop — сжатие от 1 до 0.75 и возврат за
   350 мс, а не старт с 0.75 за 450 мс. popIn — появление, включая fade. Всем
   эффектам из таблицы предоставить обещанные duration/delay/curve. Не добавлять
   исчезновение к pop без требования. Устранить неверные пояснения fadeOut в таблице.
10. **Reduced motion.** Цепочки мгновенно принимают конечное состояние, включая
    fadeIn, согласно критерию шага 10 и тесту шага 14. При `.to()` пространственные
    параметры принимают цель мгновенно, непространственное следование не колеблется.
    Частицы не создаются. Учитывать `.motion(respectReducedMotion: false)` при
    переходе к `.to()`, изменение системной настройки в работе и явную spring.
    Настройку spring при изменении параметра виджета вычислять заново.
11. **Плееры и lifecycle.** play(fromStart: true) сразу применяет начальное
    состояние и уведомляет рендер; большие dt корректно проходят несколько циклов.
    seek вне диапазона детерминирован. Dispose прекращает тики и уведомления,
    снимает связи контроллеров, сцен и скролла. При смене контроллера/сцены
    старые связи удаляются. Не перенацеливать неизменившиеся пружины при каждом
    rebuild. Проверить повторное подключение, pause/reverse и уход виджета.
12. **Порядок и демо.** Не использовать финальную рекомендацию перескочить
    с шага 2 к шагу 10. В шаге 10 поздние возможности шагов 12, 13, 17 могут
    временно иметь минимальные внутренние заглушки; реализация остаётся на своём
    шаге. Минимальные экраны gallery создавать к проверкам после шагов 5, 8,
    10, 12, 13. После каждого из них остановиться для проверки владельцем
    на устройстве. Шаг 18 расширяет уже существующую галерею.
13. **custom_lint.** Начальная проверенная сигнатура builder 0.8.1:
    run(CustomLintResolver, ErrorReporter, CustomLintContext). Согласовать версии
    builder/core/analyzer; не обновлять их независимо. Добавить createPlugin,
    разрешение типов и проверку продолжения цепочки вместо безусловной диагностики
    каждого motion(), quick fixes и запуск линтов в CI. Репозиторий custom_lint
    архивирован; менять технологию без отдельного согласования нельзя.
14. **Flame.** В опубликованном Flame 1.38.2 есть PositionComponent.position,
    scale и OpacityProvider. Хранить базовые position/scale/angle/opacity и применять
    эффекты относительно них; не захватывать повторно уже анимированную позицию.
    Переиспользовать Vector2 и не создавать Duration в update. Проверить фактические
    экспортируемые библиотеки и сигнатуры выбранной версии перед шагом 16.
15. **DevTools.** Расширение пакуется в extension/devtools/{config.yaml,build/}.
    Указать name, issueTracker, version, materialIconCodePoint, requiresConnection.
    Корень web-приложения — DevToolsExtension, обращения к VM через serviceManager.
    Сборка: dart run devtools_extensions build_and_copy --source=. --dest=<extension/devtools>;
    проверка: dart run devtools_extensions validate --package=<package-root>.
    Для scrub описать служебную команду управления, одного snapshot недостаточно.
    Служебные расширения и overlay регистрируются только в debug.
16. **Частицы.** Пул 256 — заготовка, не подтверждение сценария 5000.
    Использовать заранее выделенные буферы; простая отрисовка с новыми Offset/Color
    не удовлетворяет строгому запрету покадровых аллокаций кода библиотеки.
    Референсное устройство и частоту экрана зафиксировать до приёмки шага 15.
    FPS и отсутствие аллокаций не считать подтверждёнными unit-тестами.
17. **Пружины и тестовое время.** damping == 0 допускает незатухающую пружину:
    settleTime бесконечен, нельзя использовать его как конечную длительность
    easing. Проверять диапазоны и конечность входов в release, а не только assert.
    Тесты MotionHost учитывают clamp dt до 0.05: один pump(100.ms) не означает
    продвижения плеера на 100 мс. В unit-тестах допускается ручной Scheduler.
18. **Публикация.** Никакая приёмка шага сама по себе не разрешает pub.dev,
    GitHub Pages или автоматическую публикацию. Действия выполняются только после
    явного разрешения владельца. Push — в пределах отдельного разрешения владельца.

Источники проверки: локальный Flutter SDK 3.41.2 и исходники vector_math 2.2.0;
[workspace](https://dart.dev/tools/pub/workspaces),
[Melos](https://melos.invertase.dev/getting-started),
[custom_lint API](https://pub.dev/documentation/custom_lint_builder/latest/custom_lint_builder/DartLintRule-class.html),
[Flame](https://pub.dev/packages/flame),
[DevTools extensions](https://pub.dev/packages/devtools_extensions).

---

## Содержание

**Часть I. Что строим**
1. [Философия простоты](#1-философия-простоты)
2. [Спецификация API](#2-спецификация-api)
3. [Архитектура](#3-архитектура)

**Часть II. Как строим**
4. [Подготовка: навыки и окружение](#4-подготовка-навыки-и-окружение)
5. [Пошаговая разработка (шаги 1–20)](#5-пошаговая-разработка)

**Часть III. Как доводим до качества**
6. [Производительность](#6-производительность)
7. [Тестирование](#7-тестирование)
8. [CI/CD и релизы](#8-cicd-и-релизы)
9. [Дорожная карта по неделям](#9-дорожная-карта-по-неделям)
10. [Проверка простоты на людях](#10-проверка-простоты-на-людях)
11. [Риски](#11-риски)
12. [Чек-листы](#12-чек-листы)
13. [Глоссарий](#13-глоссарий)

---

# Часть I. Что строим

## 1. Философия простоты

### 1.1. Что изменилось по сравнению с v1

| Было (v1) | Стало (v2) |
|---|---|
| Нужен `MotionScope` в корне | Ноль настройки: работает сразу после `import` |
| `.motion(effects: [Fade(), SlideY(from: 18)])` | `.motion().fadeIn().slideUp()` |
| Нужно выбирать пружину, длительность, кривую | Один переключатель стиля на всё приложение (`calm`, `balanced`, `playful`, `snappy`) |
| Отдельные `SpringBuilder`, `SpringValue` для следования за значением | `.motion().to(offset: target)` — одна строка |
| Таймлайн собирается вручную из клипов | `MotionScene` + параметр `at:` у обычных цепочек |
| Каскад через `stagger:` и эффекты | `children.staggered()` |
| Ошибки — обычные исключения | Сообщения с причиной, решением и ссылкой, плюс линты |

### 1.2. Тест «пяти минут»

Новый разработчик, никогда не видевший библиотеку, должен за 5 минут по одному только README:

1. добавить пакет;
2. анимировать появление виджета;
3. анимировать список с каскадом;
4. сделать так, чтобы виджет плавно следовал за значением;
5. запустить анимацию по событию.

Если любой пункт требует чтения справочника API, API нужно упрощать. Тест проводится на живых людях (раздел 10), а не оценивается «на глаз».

### 1.3. Пять правил простоты

1. **Ноль настройки.** Никаких обязательных обёрток, контроллеров, `dispose`, `TickerProvider` и миксинов. Библиотека сама подключается к планировщику кадров Flutter и сама освобождает ресурсы вместе с виджетом.
2. **Умные дефолты.** Любой метод работает без параметров и даёт красивый результат. Длительности, кривые, пружины и расстояния берутся из выбранного стиля.
3. **Один вход.** Всё начинается с `.motion()` на любом виджете. Не нужно запоминать десяток разных виджетов-обёрток.
4. **Цепочка вместо конфигурации.** Эффекты добавляются вызовами методов, а не заполнением объектов настроек. Автодополнение в IDE показывает всё доступное.
5. **Ошибки учат.** Сообщение об ошибке говорит, что произошло, почему и как исправить. Типичные ошибки ловят линты ещё до запуска.

### 1.4. Лестница API (прогрессивное раскрытие)

| Уровень | Задача | Что нужно знать | Пример |
|---|---|---|---|
| 0 | «Просто сделай красиво» | один метод | `.motion().appear()` |
| 1 | Составить свою анимацию | цепочка и `then` | `.motion().fadeIn().slideUp().then().pulse()` |
| 2 | Следовать за состоянием | `to(...)` | `.motion().to(offset: pos, scale: 1.1)` |
| 3 | Сцена с таймлайном и scrub | `MotionScene`, `at:` | `.motion(at: 300.ms).fadeIn()` |
| 4 | Свои эффекты, игры, ядро | `Effect`, `motion_core` | `.motion().effect(MyEffect())` |

Правило: 90% приложений живёт на уровнях 0–2. Уровни 3–4 не должны усложнять первые три.

### 1.5. Бюджет API

Запомнить нужно не больше **12 методов** (раздел 2.2). Всё остальное — параметры с разумными умолчаниями. Любое предложение добавить метод в «основной набор» должно сопровождаться предложением убрать другой.

### 1.6. Чего не будет

- Нет обязательного `MotionScope`, `MotionApp`, `AnimationController`.
- Нет требования указывать длительность или кривую.
- Нет отдельных виджетов на каждый эффект (`FadeIn`, `SlideIn` и т.д.). Эффекты — это методы цепочки.
- Нет «магии» с глобальным изменяемым состоянием, кроме одного явного переключателя стиля (`Motion.style`).

---

## 2. Спецификация API

### 2.1. Установка и ноль настройки

```yaml
dependencies:
  kinetic_motion: ^0.1.0
```

```dart
import 'package:kinetic_motion/kinetic_motion.dart';

Text('Привет').motion().appear();
```

Больше ничего не требуется. Опционально, один раз в `main()`:

```dart
void main() {
  Motion.style = MotionStyle.playful;   // «характер» движения всего приложения
  runApp(const MyApp());
}
```

### 2.2. Основной набор: 12 методов

| № | Метод | Что делает | Типичный вызов |
|---|---|---|---|
| 1 | `appear()` | Готовое красивое появление (fade + slide up) | `.motion().appear()` |
| 2 | `fadeIn()` / `fadeOut()` | Прозрачность | `.motion().fadeIn()` |
| 3 | `slideUp()` / `slideDown()` / `slideLeft()` / `slideRight()` | Въезд с указанной стороны | `.motion().slideUp()` |
| 4 | `scaleIn()` / `scaleOut()` | Масштаб | `.motion().scaleIn()` |
| 5 | `popIn()` | Появление с пружинным отскоком | `.motion().popIn()` |
| 6 | `pop()` | Короткий «щелчок» (для лайков, кнопок) | `.motion(trigger: liked).pop()` |
| 7 | `shake()` | Тряска (ошибка в поле) | `.motion(trigger: err).shake()` |
| 8 | `pulse()` | Пульсация (привлечь внимание) | `.motion().pulse().loop()` |
| 9 | `spin()` | Поворот | `.motion().spin()` |
| 10 | `then()` | Следующий этап после предыдущих эффектов | `.fadeIn().then().pulse()` |
| 11 | `loop()` | Повторение | `.pulse().loop(times: 3)` |
| 12 | `to(...)` | Плавно следовать за значением (пружина) | `.motion().to(offset: pos)` |

Плюс расширение на списки: `children.staggered()`.

Общие необязательные параметры у каждого эффекта: `duration`, `delay`, `curve`. В 95% случаев их не указывают.

### 2.3. Правила композиции

- **Эффекты в цепочке идут одновременно.** `fadeIn().slideUp()` — это одно движение, а не два подряд.
- **`then()` начинает следующий этап** после завершения всех предыдущих эффектов.
- **`delay`** у эффекта сдвигает именно его старт.
- **Порядок вызовов в пределах одного этапа не важен** (эффекты складываются и умножаются, а не перезаписывают друг друга).

```dart
Text('Готово')
  .motion()
  .fadeIn()
  .slideUp()
  .then(delay: 200.ms)
  .pulse();
```

### 2.4. Каскад списка

```dart
Column(
  children: items.map((i) => MenuRow(i)).toList().staggered(),
);
```

- Интервал берётся из стиля (например, 60 мс), максимум общей задержки ограничен (по умолчанию 600 мс), чтобы длинные списки не «тянулись».
- Свой вариант:

```dart
cards.staggered(
  each: 50.ms,
  build: (child, i) => child.motion(index: i).popIn(),
);
```

### 2.5. Следование за значением (`to`)

Заменяет `AnimatedPositioned`, `AnimatedScale`, `AnimatedOpacity`, `AnimatedRotation` одним вызовом. Работает на пружинах: при смене цели в полёте нет рывка, скорость сохраняется.

```dart
Ball().motion().to(
  offset: target,        // Offset
  scale: pressed ? 0.9 : 1,
  opacity: enabled ? 1 : 0.4,
  rotation: angle,       // радианы
  stretch: true,         // растяжение вдоль скорости (для круглых и симметричных виджетов)
);
```

Все параметры необязательны. Что не указано, то не анимируется.

### 2.6. Триггеры и контроллер

**Триггер** — перезапуск эффекта при изменении значения:

```dart
Icon(Icons.favorite)
  .motion(trigger: liked)   // сработает, когда liked изменится
  .pop();
```

При первой сборке с `trigger` эффект **не проигрывается** (виджет сразу в конечном состоянии). Без `trigger` эффект проигрывается при появлении виджета.

**Контроллер** нужен редко (например, кнопка «Повторить»):

```dart
final ctrl = MotionController();

Column(children: rows).motion(controller: ctrl).appear();

TextButton(onPressed: ctrl.replay, child: const Text('Повторить'));
```

Методы: `play()`, `pause()`, `reverse()`, `replay()`, `seek(Duration)`, `stop()`. Контроллер не нужно уничтожать вручную.

### 2.7. Сцены: таймлайн и scrub

Если у цепочки указан `at:`, она подключается к ближайшей `MotionScene` и выполняется в её общей шкале времени. Без сцены `at:` работает как `delay`.

```dart
MotionScene(
  controller: scene,                 // необязательный
  child: Column(children: [
    Logo().motion(at: 0.ms).popIn(),
    Title().motion(at: 360.ms).fadeIn().slideUp(),
    Subtitle().motion(at: 720.ms).fadeIn().slideUp(),
    Bar().motion(at: 990.ms).scaleIn(),
  ]),
);

scene.play();
scene.seek(0.4);                       // доля 0..1
scene.bindTo(scrollController);        // прогресс привязан к скроллу
```

Готовый слайдер с дорожками для отладки: `MotionScrubber(scene)`.

### 2.8. Частицы

```dart
Stack(alignment: Alignment.center, children: [
  Burst(when: liked),                  // вспышка при переходе false → true
  Icon(Icons.favorite).motion(trigger: liked).pop(),
]);
```

Настройка при необходимости: `Burst(when: liked, count: 30, colors: Burst.warm, gravity: 520, ring: true)`.

### 2.9. Стиль приложения одной строкой

| Стиль | Характер | Множитель длительности | Отскок пружин | Интервал каскада | Расстояние слайда |
|---|---|---|---|---|---|
| `calm` | Спокойный, «премиальный» | 1,3× | 0 | 80 мс | 20 dp |
| `balanced` (по умолчанию) | Универсальный | 1,0× | 0,15 | 60 мс | 16 dp |
| `playful` | Живой, игривый | 1,0× | 0,35 | 50 мс | 20 dp |
| `snappy` | Быстрый, деловой | 0,7× | 0,05 | 35 мс | 12 dp |

Локальное переопределение для части дерева:

```dart
MotionTheme(
  style: MotionStyle.calm,
  child: SettingsScreen(),
);
```

### 2.10. Доступность

Режим «уменьшить анимацию» учитывается автоматически (`MediaQuery.disableAnimations`):

- пространственные эффекты (сдвиг, масштаб, поворот, тряска) выполняются мгновенно;
- цепочки мгновенно принимают конечное состояние; в `.to()` пространственные параметры сразу принимают цель, непространственные не колеблются;
- частицы отключаются.

Отключить для конкретного места можно, но не рекомендуется: `.motion(respectReducedMotion: false)`.

### 2.11. Свои эффекты

```dart
final class Wobble implements Effect {
  const Wobble();
  @override
  bool get affectsOpacity => false;
  @override
  void apply(EffectState s, double t) =>
      s.rotation += 0.1 * math.sin(t * math.pi * 6) * (1 - t);
}

Widget.motion().effect(const Wobble(), duration: 500.ms);
```

### 2.12. Четыре демо: код целиком

**1. Каскад**

```dart
Column(children: menu.map(MenuRow.new).toList().staggered());
```

**2. Пружина с прерыванием**

```dart
GestureDetector(
  onPanDown:   (d) => setState(() => target = d.localPosition),
  onPanUpdate: (d) => setState(() => target = d.localPosition),
  child: SizedBox(
    height: 130,
    child: Stack(children: [
      // offset — смещение от исходного места; вычитаем половину размера шара (36 / 2).
      const Ball().motion().to(offset: target - const Offset(18, 18), stretch: true),
    ]),
  ),
);
```

**3. Таймлайн со scrub**

```dart
MotionScene(
  controller: scene,
  child: Column(children: [
    Logo().motion(at: 0.ms).popIn(),
    Title().motion(at: 360.ms).fadeIn().slideUp(),
    Subtitle().motion(at: 720.ms).fadeIn().slideUp(),
    Bar().motion(at: 990.ms).scaleIn(),
    MotionScrubber(scene),
  ]),
);
```

**4. Лайк с частицами**

```dart
Stack(alignment: Alignment.center, children: [
  Burst(when: liked),
  GestureDetector(
    onTap: () => setState(() => liked = !liked),
    child: Icon(liked ? Icons.favorite : Icons.favorite_border)
        .motion(trigger: liked)
        .pop(),
  ),
]);
```

### 2.13. Таблица значений по умолчанию (стиль `balanced`)

| Эффект | Длительность | Параметры по умолчанию | Кривая |
|---|---|---|---|
| `fadeIn` / `fadeOut` | 300 мс | 0 → 1 / 1 → 0 | `outCubic` |
| `slide*` | 350 мс | 16 dp | `outCubic` |
| `scaleIn` / `scaleOut` | 300 мс | 0,9 ↔ 1 | `outCubic` |
| `popIn` | 450 мс | 0,6 → 1, отскок из стиля | пружинная кривая |
| `pop` | 350 мс | сжатие до 0,75 и возврат | пружинная кривая |
| `shake` | 400 мс | амплитуда 6 dp | затухающий синус |
| `pulse` | 600 мс | 1,0 → 1,08 → 1,0 | синус |
| `spin` | 500 мс | 1 оборот | `inOutCubic` |
| `appear` | 350 мс | fade + slide 16 dp | `outCubic` |

Длительности умножаются на множитель стиля. Значения подбираются и уточняются на этапе «полировки» (раздел 9).

---

## 3. Архитектура

### 3.1. Слои

```
┌──────────────────────────────────────────────────────┐
│ Расширения: motion_particles · motion_flame ·        │
│ motion_shaders · motion_lints · motion_devtools      │
├──────────────────────────────────────────────────────┤
│ kinetic_motion (Flutter): .motion(), MotionChain, MotionTo,  │
│ MotionScene, MotionLayer/RenderMotion, MotionHost    │
├──────────────────────────────────────────────────────┤
│ motion_core (чистый Dart): Spring, Ease, Effect,     │
│ EffectState, Timeline, Scheduler, SpringValue        │
└──────────────────────────────────────────────────────┘
```

### 3.2. Ключевые решения

| Решение | Зачем |
|---|---|
| Один `MotionHost` на приложение, лениво подключается к `SchedulerBinding` | Ноль настройки; нет десятков `Ticker` |
| Все виды анимации пишут в общий `EffectState` | Одна композиция трансформации за кадр, независимо от числа эффектов |
| `MotionSource` — общий интерфейс (`MotionPlayer` для цепочек, `SpringPlayer` для `.to()`) | Один `RenderObject` обслуживает оба режима |
| Перерисовка через `markNeedsPaint`, а не `setState` | Нет перестроения дерева на каждый кадр |
| Эффекты — чистые функции от прогресса `t` | Работают scrub, `seek`, реверс; детерминированные тесты |
| Цепочка — неизменяемое описание, превращается в `Timeline` внутри `State` | Простой API, устойчивость к hot reload |
| Стиль и режим reduced motion читаются в `didChangeDependencies` | Автоматическая реакция на тему и настройки системы |

### 3.3. Поток кадра

```
SchedulerBinding frame callback
        │ dt
        ▼
   MotionHost ──► Scheduler.update(dt) ──► Tickable.tick(dt)
                                              (MotionPlayer / SpringPlayer)
                                                    │ пишет в EffectState
                                                    ▼
                                           notifyListeners()
                                                    ▼
                                     RenderMotion.markNeedsPaint()
                                                    ▼
                         paint: opacity → transform → child (один проход)
```

Когда активных анимаций нет, `MotionHost` не запрашивает следующий кадр.

### 3.4. Структура репозитория

```
motion/
├─ packages/
│  ├─ motion_core/          # чистый Dart
│  ├─ kinetic_motion/               # Flutter-слой
│  ├─ motion_particles/     # Burst, пул частиц
│  ├─ motion_flame/         # адаптер Flame
│  ├─ motion_lints/         # правила custom_lint
│  └─ motion_devtools/      # расширение DevTools
├─ example/
│  ├─ gallery/              # галерея + playground (web)
│  └─ mini_game/            # игровой прототип
├─ benchmarks/
├─ docs/                    # сайт документации, ADR
├─ .github/workflows/
├─ pubspec.yaml             # корень workspace
└─ README.md
```

Зависимости: `motion_core` не зависит ни от чего; остальные зависят от него; расширения не зависят друг от друга.

---

# Часть II. Как строим

## 4. Подготовка: навыки и окружение

### 4.1. Что нужно уметь

| Область | Уровень | Где пригодится |
|---|---|---|
| Dart 3 (records, sealed/final классы, patterns) | уверенный | Весь код |
| Flutter: виджеты, `State`, жизненный цикл | уверенный | Слой `kinetic_motion` |
| Flutter: `RenderObject`, `PaintingContext`, слои | базовый, будете учить по ходу | Шаг 8 |
| Математика: линейная интерполяция, синус/косинус | школьный | Эффекты |
| Математика: дифференциальные уравнения | достаточно понимать результат; формулы даны в шаге 2 | Пружины |
| Git, GitHub Actions | базовый | CI |

Если не работали с `RenderObject`, перед шагом 8 прочитайте раздел документации Flutter про создание собственного render-объекта и изучите исходники `RenderOpacity` и `RenderTransform` в Flutter SDK. Это лучший справочник по тому, как правильно рисовать слои и обрабатывать нажатия.

### 4.2. Инструменты

- Flutter SDK (актуальная стабильная версия), Dart идёт в комплекте.
- Git и аккаунт GitHub.
- IDE: VS Code или Android Studio с плагинами Dart и Flutter.
- Реальные устройства для профилирования: слабый Android, iPhone, при возможности ещё один Android среднего уровня.
- Аккаунт на pub.dev (для публикации).

### 4.3. Рабочие соглашения на время разработки

- Каждый шаг ниже заканчивается пунктом **«Готово, когда»**. Не переходите дальше, пока он не выполнен.
- Каждый шаг — отдельный pull request (даже если вы работаете один). Это даёт историю и откат.
- Тест пишется вместе с кодом, а не после.
- После шагов 10, 12 и 13 делайте «демо-проверку»: соберите соответствующий экран в `example/gallery` и посмотрите на устройстве.

---

## 5. Пошаговая разработка

### Этап A. Фундамент (ядро на чистом Dart)

---

### Шаг 1. Репозиторий и инструменты

**Цель:** пустой, но полностью настроенный монорепозиторий с проходящим CI.

**Команды**

```bash
flutter --version && dart --version
dart pub global activate melos 7.8.2

mkdir motion && cd motion && git init
mkdir -p packages example docs benchmarks .github/workflows

cd packages
dart create -t package motion_core
flutter create --template=package kinetic_motion
cd ..
```

**Корневой `pubspec.yaml`** (workspace; для Melos 7 и новее)

```yaml
name: flutter_motion_workspace
publish_to: none

environment:
  sdk: ^3.11.0

workspace:
  - packages/motion_core
  - packages/kinetic_motion

dev_dependencies:
  lints: ^6.0.0
  melos: 7.8.2

melos:
  scripts:
    analyze:
      run: dart run melos run analyze:core --no-select && dart run melos run analyze:flutter --no-select
    analyze:core:
      run: dart run melos exec --no-flutter --concurrency=1 --fail-fast -- dart analyze --fatal-infos
    analyze:flutter:
      run: dart run melos exec --flutter --concurrency=1 --fail-fast -- flutter analyze --fatal-infos --fatal-warnings
    format:
      run: dart format --output=none --set-exit-if-changed .
    test:
      run: dart run melos run test:core --no-select && dart run melos run test:flutter --no-select
    test:core:
      run: dart run melos exec --no-flutter --dir-exists=test --concurrency=1 --fail-fast -- dart test --coverage=coverage
    test:flutter:
      run: dart run melos exec --flutter --dir-exists=test --concurrency=1 --fail-fast -- flutter test --coverage
```

В `pubspec.yaml` каждого пакета добавьте `resolution: workspace` и `environment.sdk: ^3.11.0`. Flutter-пакет зависит от Flutter SDK и `motion_core: ^0.1.0-dev.1`; ядро не имеет runtime-зависимостей. Общий `pubspec.lock` хранится в Git. Для этого проекта используется Melos 7.8.2; старую конфигурацию `melos.yaml` не добавлять. Команды доступны также через `dart run melos`.

**`analysis_options.yaml`** (в корне)

```yaml
include: package:lints/recommended.yaml
analyzer:
  language:
    strict-casts: true
    strict-inference: true
    strict-raw-types: true
linter:
  rules:
    - public_member_api_docs
    - prefer_final_fields
    - prefer_const_constructors
    - avoid_dynamic_calls
    - unawaited_futures
```

**CI-заготовка** `.github/workflows/ci.yml`

```yaml
name: ci

on:
  push:
  pull_request:
  workflow_dispatch:

permissions:
  contents: read

jobs:
  core:
    name: Core (Dart)
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@v7.0.1
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.41.2'
          channel: stable
          cache: true
      - name: Resolve shared workspace
        run: flutter pub get --enforce-lockfile
      - name: Bootstrap
        run: dart run melos bootstrap --enforce-lockfile
      - name: Check formatting
        run: dart run melos run format
      - name: Analyze workspace and core
        run: dart analyze --fatal-infos
      - name: Test core with coverage
        run: dart run melos run test:core --no-select
      - name: Upload core coverage
        uses: actions/upload-artifact@v7.0.2
        with:
          name: motion-core-coverage
          path: packages/motion_core/coverage/
          if-no-files-found: error
  flutter:
    name: Flutter
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@v7.0.1
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.41.2'
          channel: stable
          cache: true
      - name: Resolve shared workspace
        run: flutter pub get --enforce-lockfile
      - name: Analyze Flutter packages
        run: dart run melos run analyze:flutter --no-select
      - name: Test Flutter packages with coverage
        run: dart run melos run test:flutter --no-select
      - name: Upload Flutter coverage
        uses: actions/upload-artifact@v7.0.2
        with:
          name: kinetic-motion-coverage
          path: packages/kinetic_motion/coverage/
          if-no-files-found: error
```

**Дополнительно:** добавьте `LICENSE` (MIT или BSD-3), `README.md`, `CONTRIBUTING.md`, `CHANGELOG.md` в каждый пакет, первый ADR (`docs/adr/0001-monorepo.md`).

**Готово, когда:** `melos bootstrap`, `melos run analyze` и CI проходят на пустых пакетах.

---

### Шаг 2. Ядро: пружина

**Цель:** математически точная, устойчивая пружина с тестами.

**Файл `packages/motion_core/lib/src/spring.dart`**

```dart
import 'dart:math' as math;

/// An analytical damped harmonic oscillator, independent of the frame rate.
///
/// Parameters are validated by [solve] and [settleTime], including in release
/// mode. Deferring validation preserves constant construction. Stiffness and
/// mass must be positive; damping must be nonnegative. All must be finite.
///
/// ```dart
/// const spring = Spring(stiffness: 180, damping: 14, mass: 1);
/// final (position, velocity) = spring.solve(
///   from: 0, to: 1, velocity: 0, t: 0.2,
/// );
/// ```
final class Spring {
  /// Creates a spring whose physical parameters are validated on evaluation.
  ///
  /// ```dart
  /// const spring = Spring(stiffness: 100, damping: 20);
  /// ```
  const Spring({this.stiffness = 180, this.damping = 14, this.mass = 1});

  /// Creates a spring from an approximate duration in seconds and bounce.
  ///
  /// [duration] must be positive and finite. A finite [bounce] is clamped to
  /// 0..0.95. Zero bounce gives critical damping: a stationary spring does not
  /// overshoot its target. Duration is a tuning parameter, not a deadline.
  /// Throws [ArgumentError] for nonfinite inputs, a nonpositive duration, or
  /// generated parameters outside the representable floating-point range.
  ///
  /// ```dart
  /// final spring = Spring.bounce(duration: 0.5, bounce: 0.3);
  /// ```
  factory Spring.bounce({double duration = 0.5, double bounce = 0.15}) {
    _requireFinite(duration, 'duration');
    _requireFinite(bounce, 'bounce');
    if (duration <= 0) {
      throw ArgumentError.value(duration, 'duration', 'Must be positive.');
    }
    final w = 2 * math.pi / duration;
    final b = bounce.clamp(0.0, 0.95);
    final spring = Spring(stiffness: w * w, damping: 2 * w * (1 - b));
    spring._validateParameters();
    return spring;
  }

  /// A gently damped spring for smooth value following.
  ///
  /// ```dart
  /// const spring = Spring.smooth;
  /// ```
  static const smooth = Spring(stiffness: 170, damping: 26);

  /// A stiffer spring for quick responses.
  ///
  /// ```dart
  /// const spring = Spring.snappy;
  /// ```
  static const snappy = Spring(stiffness: 300, damping: 30);

  /// A lightly damped spring with a visible overshoot.
  ///
  /// ```dart
  /// const spring = Spring.bouncy;
  /// ```
  static const bouncy = Spring(stiffness: 220, damping: 12);

  /// The positive spring stiffness.
  ///
  /// ```dart
  /// final stiffness = Spring.bouncy.stiffness; // 220.0
  /// ```
  final double stiffness;

  /// The nonnegative damping coefficient; zero permits sustained oscillation.
  ///
  /// ```dart
  /// final damping = Spring.smooth.damping; // 26.0
  /// ```
  final double damping;

  /// The positive mass of the animated value.
  ///
  /// ```dart
  /// final mass = Spring.snappy.mass; // 1.0
  /// ```
  final double mass;

  double get _w0 => math.sqrt(stiffness) / math.sqrt(mass);
  double get _zeta => (damping / math.sqrt(stiffness)) / math.sqrt(mass) / 2;

  /// Estimates seconds until practical rest, about 0.1% of initial amplitude.
  ///
  /// This estimate is not a bound for arbitrary initial velocities. An
  /// undamped spring returns [double.infinity]. Invalid physical parameters
  /// throw [ArgumentError].
  ///
  /// ```dart
  /// final seconds = Spring.bouncy.settleTime;
  /// ```
  double get settleTime {
    _validateParameters();
    final z = _zeta, w0 = _w0;
    if (z == 0) return double.infinity;
    if ((z - 1).abs() < 1e-6) return 9.2 / w0;
    if (z < 1) return 6.9 / (z * w0);
    final root = math.sqrt(z - 1) * math.sqrt(z + 1);
    // Reciprocal form avoids cancellation in z - sqrt(z * z - 1).
    return (6.9 / w0) * (z + root);
  }

  /// Returns position and velocity at [t] seconds without integrating frames.
  ///
  /// [from], [to], [velocity] and [t] must be finite. Negative time evaluates
  /// the same analytical solution backwards. At zero time the inputs are
  /// returned exactly. Invalid inputs or physical parameters throw
  /// [ArgumentError]. Floating-point overflow is possible for extreme states
  /// or backwards times; use finite, representable physical scales.
  ///
  /// ```dart
  /// final (x, v) = Spring.bouncy.solve(
  ///   from: 0, to: 100, velocity: 0, t: 0.5,
  /// );
  /// ```
  (double x, double v) solve({
    required double from,
    required double to,
    required double velocity,
    required double t,
  }) {
    _validateParameters();
    _requireFinite(from, 'from');
    _requireFinite(to, 'to');
    _requireFinite(velocity, 'velocity');
    _requireFinite(t, 't');
    if (t == 0) return (from, velocity);

    final d0 = from - to;
    final w0 = _w0, z = _zeta;
    double x, v;
    if (z == 1) {
      final k = velocity + w0 * d0;
      final e = math.exp(-w0 * t);
      x = e * (d0 + k * t);
      v = e * (velocity - w0 * k * t);
    } else if (z < 1) {
      final wd = w0 * math.sqrt(1 - z * z);
      final a = z * w0;
      final b = (velocity + a * d0) / wd;
      final e = math.exp(-a * t);
      final c = math.cos(wd * t), s = math.sin(wd * t);
      x = e * (d0 * c + b * s);
      v = e * (velocity * c - (d0 * wd + a * b) * s);
    } else {
      final root = math.sqrt(z - 1) * math.sqrt(z + 1);
      final sum = z + root;
      final r1 = -w0 / sum, r2 = -w0 * sum;
      final e1 = math.exp(r1 * t), e2 = math.exp(r2 * t);
      final gap = r1 - r2;
      final u = gap * t;
      // Stable divided difference of exponentials near critical damping.
      final divided = u.abs() < 0.001
          ? e1 *
                t *
                (1 - u / 2 + u * u / 6 - u * u * u / 24 + u * u * u * u / 120)
          : (e1 - e2) / gap;
      final coefficient = velocity - r1 * d0;
      x = d0 * e1 + coefficient * divided;
      v = r1 * x + coefficient * e2;
    }
    return (to + x, v);
  }

  void _validateParameters() {
    _requireFinite(stiffness, 'stiffness');
    _requireFinite(damping, 'damping');
    _requireFinite(mass, 'mass');
    if (stiffness <= 0) {
      throw ArgumentError.value(stiffness, 'stiffness', 'Must be positive.');
    }
    if (damping < 0) {
      throw ArgumentError.value(damping, 'damping', 'Must be nonnegative.');
    }
    if (mass <= 0) {
      throw ArgumentError.value(mass, 'mass', 'Must be positive.');
    }
    if (!_w0.isFinite || _w0 == 0 || !_zeta.isFinite) {
      throw ArgumentError('Spring parameters exceed floating-point range.');
    }
  }

  static void _requireFinite(double value, String name) {
    if (!value.isFinite) {
      throw ArgumentError.value(value, name, 'Must be finite.');
    }
  }
}
```

**Почему аналитика, а не метод Эйлера:** численный шаг становится нестабильным при большом `dt` (например, после паузы приложения) и при жёстких пружинах. Аналитическое решение точно при любом `t`, а перенацеливание делается простой подменой `from`, `velocity` и сбросом `t`.

**Тесты `test/spring_test.dart`**

```dart
import 'package:motion_core/motion_core.dart';
import 'package:test/test.dart';

void main() {
  test('в момент t=0 возвращает старт и скорость', () {
    final (x, v) = Spring.smooth.solve(from: 3, to: 10, velocity: 5, t: 0);
    expect(x, closeTo(3, 1e-9));
    expect(v, closeTo(5, 1e-9));
  });

  test('сходится к цели', () {
    for (final s in [Spring.smooth, Spring.snappy, Spring.bouncy]) {
      final (x, v) = s.solve(from: 0, to: 100, velocity: 0, t: 10);
      expect(x, closeTo(100, 0.01));
      expect(v.abs(), lessThan(0.01));
    }
  });

  test('критическое затухание не даёт перелёта', () {
    const s = Spring(stiffness: 100, damping: 20); // ζ = 1
    for (var t = 0.0; t < 3; t += 0.01) {
      expect(s.solve(from: 0, to: 1, velocity: 0, t: t).$1, lessThan(1.0001));
    }
  });

  test('недодемпфированная пружина перелетает цель', () {
    var max = 0.0;
    for (var t = 0.0; t < 2; t += 0.005) {
      max = [max, Spring.bouncy.solve(from: 0, to: 1, velocity: 0, t: t).$1]
          .reduce((a, b) => a > b ? a : b);
    }
    expect(max, greaterThan(1.05));
  });

  test('аналитика совпадает с численным интегрированием', () {
    const s = Spring(stiffness: 200, damping: 15);
    double x = 0, v = 0;
    const h = 0.0001;
    for (var i = 0; i < 5000; i++) { // 0.5 сек
      v += (-s.stiffness * (x - 1) - s.damping * v) * h;
      x += v * h;
    }
    expect(s.solve(from: 0, to: 1, velocity: 0, t: 0.5).$1, closeTo(x, 0.01));
  });
}
```

**Уточнения реализации шага 2 (в рамках согласованной проверки входов).**
Const-конструктор сохраняется без assert: валидация физических параметров происходит
при solve/settleTime, включая release; фабрика проверяет свои входы сразу.
Неконечные значения и непредставимые производные параметры отклоняются с ArgumentError.
Нулевое damping даёт бесконечный settleTime. В solve критическое приближение из
старой заготовки заменено вычислением соответствующего аналитического режима;
алгебраически эквивалентные устойчивые формулы уменьшают потерю точности корней
и разности экспонент. Оценка settleTime остаётся приблизительной.
Обратное конечное время разрешено. Произвольные экстремальные сочетания double
могут переполняться; требование аналитики не отменяет границы представимости.
Подробности и границы публичного API — в docs/adr/0002-spring.md.

**Проверки шага 2:**

```sh
dart format .
dart analyze --fatal-infos
dart run melos run analyze --no-select
dart run melos run test --no-select
```

С шага 2 test:core собирает LCOV через `dart test --coverage-path=coverage/lcov.info`
и проверяет порог ядра ≥90% командой
`dart run tool/check_coverage.dart packages/motion_core/coverage/lcov.info 90`.
Пустой или отсутствующий отчёт не проходит проверку. Тесты включают независимую
численную интеграцию, seeded property-проверки и процесс без assertions.

**Готово, когда:** все тесты зелёные; в `Spring.bounce(bounce: 0)` отскока нет; публичные символы документированы. Покрытие ядра ≥90%.

---

### Шаг 3. Ядро: кривые и эффекты

**Цель:** набор кривых и чистые эффекты, записывающие результат в общую структуру.

**`ease.dart`**

```dart
import 'dart:math' as math;
import 'spring.dart';

typedef EaseFn = double Function(double t);

abstract final class Ease {
  static double linear(double t) => t;

  static double outCubic(double t) {
    final u = 1 - t;
    return 1 - u * u * u;
  }

  static double inOutCubic(double t) {
    if (t < 0.5) return 4 * t * t * t;
    final u = -2 * t + 2;
    return 1 - u * u * u / 2;
  }

  static double outBack(double t) {
    const c1 = 1.70158, c3 = c1 + 1;
    final u = t - 1;
    return 1 + c3 * u * u * u + c1 * u * u;
  }

  static final _springCache = <double, EaseFn>{};

  /// Пружинная кривая на отрезке [0, 1]: физическое движение, но с
  /// фиксированной длительностью, поэтому её можно листать (scrub) и реверсировать.
  static EaseFn spring({double bounce = 0.3}) =>
      _springCache.putIfAbsent(bounce, () {
        final s = Spring.bounce(duration: 1, bounce: bounce);
        final total = s.settleTime;
        return (double t) => t >= 1
            ? 1.0
            : t <= 0
                ? 0.0
                : s.solve(from: 0, to: 1, velocity: 0, t: t * total).$1;
      });

  /// Затухающий синус (для тряски): значение в [-1, 1].
  static double dampedSine(double t, {double cycles = 4}) =>
      math.sin(t * cycles * 2 * math.pi) * (1 - t);
}
```

**`effect.dart`**

```dart
import 'dart:math' as math;

/// Результат работы всех эффектов за кадр. Один экземпляр на цель, переиспользуется.
final class EffectState {
  double opacity = 1;
  double dx = 0, dy = 0;
  double scaleX = 1, scaleY = 1;
  double rotation = 0;
  double anchorX = 0.5, anchorY = 0.5;

  void reset() {
    opacity = 1; dx = 0; dy = 0; scaleX = 1; scaleY = 1;
    rotation = 0; anchorX = 0.5; anchorY = 0.5;
  }

  bool get hasTransform =>
      dx != 0 || dy != 0 || scaleX != 1 || scaleY != 1 || rotation != 0;
}

/// Чистая функция от прогресса [t] (0..1). Никаких аллокаций внутри [apply].
abstract interface class Effect {
  bool get affectsOpacity;
  void apply(EffectState state, double t);
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

final class Fade implements Effect {
  const Fade({this.from = 0, this.to = 1});
  final double from, to;
  @override bool get affectsOpacity => true;
  @override void apply(EffectState s, double t) => s.opacity *= _lerp(from, to, t);
}

/// Сдвиг: из (fromX, fromY) в (toX, toY).
final class Move implements Effect {
  const Move({this.fromX = 0, this.fromY = 0, this.toX = 0, this.toY = 0});
  final double fromX, fromY, toX, toY;
  @override bool get affectsOpacity => false;
  @override
  void apply(EffectState s, double t) {
    s.dx += _lerp(fromX, toX, t);
    s.dy += _lerp(fromY, toY, t);
  }
}

final class Scale implements Effect {
  const Scale({this.from = 0.9, this.to = 1});
  final double from, to;
  @override bool get affectsOpacity => false;
  @override
  void apply(EffectState s, double t) {
    final k = _lerp(from, to, t);
    s.scaleX *= k;
    s.scaleY *= k;
  }
}

final class Rotate implements Effect {
  const Rotate({this.from = 0, this.to = 2 * math.pi});
  final double from, to;
  @override bool get affectsOpacity => false;
  @override void apply(EffectState s, double t) => s.rotation += _lerp(from, to, t);
}

/// Горизонтальная тряска с затуханием. [t] — линейный прогресс.
final class Shake implements Effect {
  const Shake({this.amplitude = 6, this.cycles = 4});
  final double amplitude, cycles;
  @override bool get affectsOpacity => false;
  @override
  void apply(EffectState s, double t) =>
      s.dx += amplitude * math.sin(t * cycles * 2 * math.pi) * (1 - t);
}

/// Пульс: масштаб 1 → 1+amount → 1.
final class Pulse implements Effect {
  const Pulse({this.amount = 0.08});
  final double amount;
  @override bool get affectsOpacity => false;
  @override
  void apply(EffectState s, double t) {
    final k = 1 + amount * math.sin(t * math.pi);
    s.scaleX *= k;
    s.scaleY *= k;
  }
}
```

**Правила для автора эффекта**

1. Сложение (`+=`) для смещений и поворота, умножение (`*=`) для масштаба и прозрачности: так эффекты можно комбинировать в любом порядке.
2. Никаких `new`/литералов коллекций внутри `apply`.
3. При `t = 0` и `t = 1` эффект должен давать «начальное» и «конечное» состояния без скачков.

**Тесты:** для каждого эффекта проверьте `t = 0`, `0.5`, `1`; для `Shake` и `Pulse` — что при `t = 1` смещение равно нулю, масштаб равен 1.

**Готово, когда:** тесты зелёные, кривая `Ease.spring` в конце ровно `1.0`, в начале `0.0`.

---

### Шаг 4. Ядро: таймлайн

**Цель:** чистое вычисление состояния по времени.

**`timeline.dart`**

```dart
import 'effect.dart';
import 'ease.dart';

final class Clip {
  const Clip(this.effect, {required this.start, required this.length, this.ease = Ease.outCubic});
  final Effect effect;
  final Duration start, length;
  final EaseFn ease;
  Duration get end => start + length;
}

final class Timeline {
  Timeline(List<Clip> clips)
      : clips = List.unmodifiable(clips),
        duration = clips.fold(Duration.zero, (m, c) => c.end > m ? c.end : m),
        usesOpacity = clips.any((c) => c.effect.affectsOpacity);

  final List<Clip> clips;
  final Duration duration;
  final bool usesOpacity;

  /// Чистая функция времени: не зависит от предыстории вызовов.
  void evaluate(Duration time, EffectState state) {
    state.reset();
    for (final c in clips) {
      final double local;
      if (c.length == Duration.zero) {
        local = time >= c.start ? 1.0 : 0.0;
      } else {
        local = ((time - c.start).inMicroseconds / c.length.inMicroseconds)
            .clamp(0.0, 1.0)
            .toDouble();
      }
      c.effect.apply(state, c.ease(local));
    }
  }
}
```

Обратите внимание: до начала клипа он применяется с `t = 0`. Поэтому `fadeIn` с задержкой не «мигает»: виджет невидим всё время задержки.

**Тесты**

```dart
test('до старта клип в начальном состоянии, после конца в конечном', () {
  final tl = Timeline([
    Clip(const Fade(), start: 100.ms, length: 200.ms, ease: Ease.linear),
  ]);
  final s = EffectState();
  tl.evaluate(Duration.zero, s);              expect(s.opacity, 0);
  tl.evaluate(const Duration(milliseconds: 200), s); expect(s.opacity, closeTo(0.5, 1e-9));
  tl.evaluate(const Duration(seconds: 5), s); expect(s.opacity, 1);
});

test('evaluate чист: порядок вызовов не влияет на результат', () {
  // вычислить в порядке 0, 300, 100 и в порядке 100, 0, 300: значения для 100 равны
});
```

(Расширение `.ms` для `num` добавляется в `motion_core` в `duration_ext.dart`: `extension DurationNum on num { Duration get ms => Duration(microseconds: (this * 1000).round()); Duration get s => Duration(microseconds: (this * 1000000).round()); }`.)

**Готово, когда:** тесты зелёные, в `Timeline` нет изменяемого состояния кроме передаваемого `EffectState`.

---

### Шаг 5. Ядро: планировщик и `SpringValue`

**Цель:** общий цикл обновления без привязки ко Flutter.

**`scheduler.dart`**

```dart
abstract interface class Tickable {
  /// true — нужен следующий кадр; false — можно «уснуть».
  bool tick(double dt);
}

final class Scheduler {
  /// Вызывается, когда список активных анимаций стал непустым.
  void Function()? onWake;
  final _active = <Tickable>[];

  bool get isIdle => _active.isEmpty;

  void add(Tickable t) {
    if (_active.contains(t)) return;   // при >1000 анимаций замените на флаг внутри Tickable
    final wasIdle = _active.isEmpty;
    _active.add(t);
    if (wasIdle) onWake?.call();
  }

  /// Возвращает true, если остались активные анимации.
  bool update(double dt) {
    for (var i = _active.length - 1; i >= 0; i--) {
      if (!_active[i].tick(dt)) {
        _active[i] = _active.last;      // быстрое удаление без сдвига
        _active.removeLast();
      }
    }
    return _active.isNotEmpty;
  }
}
```

**`spring_value.dart`**

```dart
import 'scheduler.dart';
import 'spring.dart';

final class SpringValue implements Tickable {
  SpringValue(double initial, {this.spring = Spring.smooth, Scheduler? scheduler})
      : _scheduler = scheduler, _x = initial, _from = initial, _to = initial;

  final Scheduler? _scheduler;   // null: тики вызывает владелец (например, SpringPlayer)
  Spring spring;
  double _x, _v = 0, _from, _v0 = 0, _to, _t = 0;
  static const _restDelta = 0.001, _restSpeed = 0.01;

  double get value => _x;
  double get velocity => _v;
  double get target => _to;
  bool get isAtRest => _x == _to && _v == 0;

  /// Можно вызывать в любой момент: позиция и скорость сохраняются.
  void animateTo(double target) {
    _from = _x; _v0 = _v; _to = target; _t = 0;
    _scheduler?.add(this);
  }

  void snapTo(double value) {
    _x = _from = _to = value; _v = _v0 = 0;
  }

  @override
  bool tick(double dt) {
    if (isAtRest) return false;
    _t += dt;
    final r = spring.solve(from: _from, to: _to, velocity: _v0, t: _t);
    _x = r.$1; _v = r.$2;
    if ((_x - _to).abs() < _restDelta && _v.abs() < _restSpeed) {
      _x = _to; _v = 0;
      return false;
    }
    return true;
  }
}
```

**Тесты:** `animateTo` + `tick` по 1/60 с до покоя; перенацеливание в середине сохраняет скорость (`velocity` непосредственно после `animateTo` равна скорости до него); `Scheduler.update` возвращает `false`, когда все пружины остановились; `onWake` вызывается ровно один раз при добавлении в пустой планировщик.

**Готово, когда:** ядро собрано, покрытие тестами ≥ 90%, `dart pub publish --dry-run` в `motion_core` проходит.

---

### Этап B. Flutter-слой

---

### Шаг 6. `MotionHost`: автоматическое подключение к кадрам

**Цель:** ноль настройки. Планировщик сам просыпается и засыпает.

**`packages/kinetic_motion/lib/src/host.dart`**

```dart
import 'package:flutter/scheduler.dart';
import 'package:motion_core/motion_core.dart';

final class MotionHost {
  MotionHost._() { scheduler.onWake = _schedule; }
  static final instance = MotionHost._();

  final scheduler = Scheduler();
  Duration? _last;
  bool _scheduled = false;

  void _schedule() {
    if (_scheduled) return;
    _scheduled = true;
    SchedulerBinding.instance.scheduleFrameCallback(_onFrame);
  }

  void _onFrame(Duration timestamp) {
    _scheduled = false;
    final prev = _last;
    _last = timestamp;
    final dt = prev == null ? 0.0 : (timestamp - prev).inMicroseconds / 1e6;
    // Ограничиваем скачок после паузы (например, при сворачивании приложения).
    final more = scheduler.update(dt.clamp(0.0, 0.05).toDouble());
    if (more) {
      _schedule();
    } else {
      _last = null;
    }
  }
}
```

**Готово, когда:** юнит-тест: после `scheduler.add(fakeTickable)` и `tester.pump` вызывается `tick`; когда `tick` вернул `false`, новые кадры не запрашиваются (`tester.hasScheduledFrame == false`).

---

### Шаг 7. Источник движения и плеер цепочки

**Цель:** общий интерфейс для рендер-слоя и проигрыватель таймлайна.

**`source.dart`**

```dart
import 'package:flutter/foundation.dart';
import 'package:motion_core/motion_core.dart';

abstract interface class MotionSource implements Listenable {
  EffectState get state;
  /// Влияет ли источник на прозрачность (нужно для флага compositing).
  bool get usesOpacity;
}
```

**`player.dart`**

```dart
import 'package:flutter/foundation.dart';
import 'package:motion_core/motion_core.dart';
import 'host.dart';
import 'source.dart';

final class MotionPlayer extends ChangeNotifier implements MotionSource, Tickable {
  MotionPlayer({Scheduler? scheduler})
      : _scheduler = scheduler ?? MotionHost.instance.scheduler;

  final Scheduler _scheduler;
  @override
  final EffectState state = EffectState();

  Timeline _timeline = Timeline(const []);
  Duration _time = Duration.zero;
  bool _running = false;
  int _loopsDone = 0;

  /// null — бесконечно.
  int? loops = 1;
  double speed = 1;
  VoidCallback? onComplete;

  Duration get duration => _timeline.duration;
  Duration get time => _time;
  bool get isRunning => _running;
  @override
  bool get usesOpacity => _timeline.usesOpacity;

  /// Подмена таймлайна сохраняет текущее время (удобно при hot reload).
  set timeline(Timeline t) {
    _timeline = t;
    _apply();
  }

  void play({bool fromStart = false}) {
    if (fromStart) { _time = Duration.zero; _loopsDone = 0; }
    speed = speed.abs();
    _running = true;
    _scheduler.add(this);
  }

  void reverse() {
    speed = -speed.abs();
    _running = true;
    _scheduler.add(this);
  }

  void pause() => _running = false;

  void jumpToEnd() {
    _running = false;
    _time = duration;
    _apply();
  }

  void seek(Duration t) {
    _time = t;
    _apply();
  }

  @override
  bool tick(double dt) {
    if (!_running) return false;
    _time += Duration(microseconds: (dt * speed * 1e6).round());
    if (speed < 0 && _time <= Duration.zero) {
      _time = Duration.zero;
      _running = false;
    } else if (speed > 0 && _time >= duration) {
      final more = loops == null || _loopsDone + 1 < loops!;
      if (more && duration > Duration.zero) {
        _loopsDone++;
        _time -= duration;
      } else {
        _time = duration;
        _running = false;
      }
    }
    _apply();
    if (!_running) onComplete?.call();
    return _running;
  }

  void _apply() {
    _timeline.evaluate(_time, state);
    notifyListeners();
  }

  @override
  void dispose() {
    _running = false;   // планировщик сам выкинет плеер при следующем кадре
    super.dispose();
  }
}
```

**Готово, когда:** тесты с `Scheduler` и ручным `tick`: проигрывание до конца, повтор `loops: 3`, пауза, реверс, `seek` вне диапазона.

---

### Шаг 8. Рендер-объект: один проход вместо вложенных виджетов

**Цель:** применить `EffectState` к ребёнку без перестроения дерева, с правильной обработкой нажатий.

**`render_motion.dart`**

```dart
import 'dart:math' as math;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'source.dart';

final class MotionLayer extends SingleChildRenderObjectWidget {
  const MotionLayer({super.key, required this.source, super.child});
  final MotionSource source;

  @override
  RenderObject createRenderObject(BuildContext context) => RenderMotion(source);

  @override
  void updateRenderObject(BuildContext context, RenderMotion renderObject) =>
      renderObject.source = source;
}

final class RenderMotion extends RenderProxyBox {
  RenderMotion(this._source);

  MotionSource _source;
  final _matrix = Matrix4.identity();
  final _opacityLayer = LayerHandle<OpacityLayer>();
  final _transformLayer = LayerHandle<TransformLayer>();

  MotionSource get source => _source;
  set source(MotionSource v) {
    if (identical(v, _source)) return;
    if (attached) {
      _source.removeListener(markNeedsPaint);
      v.addListener(markNeedsPaint);
    }
    _source = v;
    markNeedsCompositingBitsUpdate();
    markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _source.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _source.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void dispose() {
    _opacityLayer.layer = null;
    _transformLayer.layer = null;
    super.dispose();
  }

  // Мы сами добавляем слой прозрачности, значит предки должны об этом знать.
  @override
  bool get alwaysNeedsCompositing => child != null && _source.usesOpacity;

  Matrix4 _currentMatrix() {
    final s = _source.state;
    final ax = size.width * s.anchorX, ay = size.height * s.anchorY;
    final c = math.cos(s.rotation), sn = math.sin(s.rotation);
    final a = c * s.scaleX, b = sn * s.scaleX;
    final cc = -sn * s.scaleY, d = c * s.scaleY;
    final e = s.dx + ax - (a * ax + cc * ay);
    final f = s.dy + ay - (b * ax + d * ay);
    // Матрица записывается напрямую: без аллокаций и устаревших методов vector_math.
    return _matrix..setValues(a, b, 0, 0, cc, d, 0, 0, 0, 0, 1, 0, e, f, 0, 1);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final c = child;
    if (c == null) return;
    final s = _source.state;
    if (s.opacity <= 0.001) {            // невидим: ничего не рисуем
      _opacityLayer.layer = null;
      _transformLayer.layer = null;
      return;
    }

    void paintTransformed(PaintingContext ctx, Offset off) {
      if (!s.hasTransform) {
        _transformLayer.layer = null;
        ctx.paintChild(c, off);
      } else {
        _transformLayer.layer = ctx.pushTransform(
          needsCompositing, off, _currentMatrix(),
          (inner, o) => inner.paintChild(c, o),
          oldLayer: _transformLayer.layer,
        );
      }
    }

    if (s.opacity >= 0.999) {
      _opacityLayer.layer = null;
      paintTransformed(context, offset);
    } else {
      _opacityLayer.layer = context.pushOpacity(
        offset, (s.opacity * 255).round().clamp(0, 255), paintTransformed,
        oldLayer: _opacityLayer.layer,
      );
    }
  }

  // Нажатия должны попадать туда, где виджет нарисован сейчас, а не в исходную позицию.
  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final c = child;
    if (c == null) return false;
    if (!_source.state.hasTransform) return c.hitTest(result, position: position);
    return result.addWithPaintTransform(
      transform: _currentMatrix(),
      position: position,
      hitTest: (r, p) => c.hitTest(r, position: p),
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    if (_source.state.hasTransform) transform.multiply(_currentMatrix());
  }
}
```

**На что обратить внимание**

- `hitTestChildren` и `applyPaintTransform` обязательны: без них кнопка внутри анимированного виджета нажимается «не там», а `showOverlay`/`Draggable` работают неверно.
- `LayerHandle` позволяет переиспользовать слои между кадрами.
- Метод `setValues` и порядок аргументов (по столбцам) стоит сверить с вашей версией `vector_math`.

**Тесты**

```dart
testWidgets('нажатие попадает в смещённый виджет', (tester) async {
  var taps = 0;
  final player = MotionPlayer()
    ..timeline = Timeline([Clip(const Move(toX: 100), start: Duration.zero, length: Duration.zero)])
    ..jumpToEnd();
  await tester.pumpWidget(Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: MotionLayer(
        source: player,
        child: GestureDetector(onTap: () => taps++, child: const SizedBox(width: 50, height: 50)),
      ),
    ),
  ));
  await tester.tapAt(const Offset(125, 25));   // 100 (смещение) + 25 (середина)
  expect(taps, 1);
  await tester.tapAt(const Offset(25, 25));    // исходное место теперь пустое
  expect(taps, 1);
});
```

**Готово, когда:** тест нажатий проходит, виджет рисуется без лишних слоёв при `opacity == 1`, в профайле (шаг «демо-проверка») перерисовка идёт только в `RenderMotion`.

---

### Шаг 9. Стиль и тема: «характер» движения одной строкой

**Цель:** все умолчания собраны в одном месте и меняются одним переключателем.

**`style.dart`**

```dart
import 'package:flutter/widgets.dart';
import 'package:motion_core/motion_core.dart';

@immutable
final class MotionStyle {
  const MotionStyle({
    this.durationScale = 1,
    this.bounce = 0.15,
    this.stagger = const Duration(milliseconds: 60),
    this.maxStagger = const Duration(milliseconds: 600),
    this.distance = 16,
  });

  static const calm = MotionStyle(
      durationScale: 1.3, bounce: 0, stagger: Duration(milliseconds: 80), distance: 20);
  static const balanced = MotionStyle();
  static const playful = MotionStyle(
      bounce: 0.35, stagger: Duration(milliseconds: 50), distance: 20);
  static const snappy = MotionStyle(
      durationScale: 0.7, bounce: 0.05, stagger: Duration(milliseconds: 35), distance: 12);

  final double durationScale, bounce, distance;
  final Duration stagger, maxStagger;

  Duration scaled(Duration base) => base * durationScale;
  EaseFn get springEase => Ease.spring(bounce: bounce);
}

abstract final class Motion {
  /// Менять до `runApp`. Для части дерева используйте [MotionTheme].
  static MotionStyle style = MotionStyle.balanced;
}

final class MotionTheme extends InheritedWidget {
  const MotionTheme({super.key, required this.style, required super.child});
  final MotionStyle style;

  static MotionStyle of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MotionTheme>()?.style ?? Motion.style;

  @override
  bool updateShouldNotify(MotionTheme old) => style != old.style;
}
```

**Правило ценности умолчаний:** значения из таблицы 2.13 подбираются не в кабинете, а «на глаз» в галерее на устройстве. Заведите в галерее экран «Лаборатория стиля» с ползунками и меняйте числа, пока выглядит хорошо во всех четырёх стилях.

**Готово, когда:** смена `Motion.style` до `runApp` меняет темп и отскок всех демо; `MotionTheme` переопределяет стиль для поддерева.

---

### Шаг 10. Цепочка `.motion()`: главный вход в библиотеку

**Цель:** весь «Уровень 0–1» API.

**`chain.dart`** (основа)

```dart
import 'package:flutter/widgets.dart';
import 'package:motion_core/motion_core.dart';
import 'player.dart';
import 'render_motion.dart';
import 'style.dart';

const _noTrigger = Object();
const _infinite = -1;

enum _Kind { fade, slide, scale, pop, shake, pulse, spin, custom }

const _baseMs = {
  _Kind.fade: 300, _Kind.slide: 350, _Kind.scale: 300, _Kind.pop: 450,
  _Kind.shake: 400, _Kind.pulse: 600, _Kind.spin: 500, _Kind.custom: 300,
};

@immutable
final class _Step {
  const _Step(this.kind, this.build, {this.duration, this.delay = Duration.zero, this.curve})
      : isThen = false;
  const _Step.then(this.delay)
      : kind = _Kind.custom, build = null, duration = null, curve = null, isThen = true;
  final _Kind kind;
  final Effect Function(MotionStyle)? build;
  final Duration? duration, delay;
  final EaseFn? curve;
  final bool isThen;
}

@immutable
final class _Opts {
  const _Opts({
    this.trigger = _noTrigger, this.delay = Duration.zero, this.at, this.index,
    this.stagger, this.controller, this.respectReducedMotion = true,
    this.loops = 1, this.onComplete,
  });
  final Object? trigger;
  final Duration delay;
  final Duration? at, stagger;
  final int? index;
  final MotionController? controller;
  final bool respectReducedMotion;
  final int loops;
  final VoidCallback? onComplete;

  _Opts copyWith({int? loops, VoidCallback? onComplete}) => _Opts(
      trigger: trigger, delay: delay, at: at, index: index, stagger: stagger,
      controller: controller, respectReducedMotion: respectReducedMotion,
      loops: loops ?? this.loops, onComplete: onComplete ?? this.onComplete);

  bool get hasTrigger => !identical(trigger, _noTrigger);
}

/// Точка входа: `anyWidget.motion().fadeIn().slideUp()`.
extension MotionX on Widget {
  MotionChain motion({
    Key? key,
    Object? trigger = _noTrigger,
    Duration delay = Duration.zero,
    Duration? at,
    int? index,
    Duration? stagger,
    MotionController? controller,
    bool respectReducedMotion = true,
  }) =>
      MotionChain._(this, const [],
          _Opts(trigger: trigger, delay: delay, at: at, index: index, stagger: stagger,
              controller: controller, respectReducedMotion: respectReducedMotion),
          key: key);
}

final class MotionChain extends StatefulWidget {
  const MotionChain._(this.child, this.steps, this.opts, {super.key});
  final Widget child;
  final List<_Step> steps;
  final _Opts opts;

  MotionChain _add(_Step s) => MotionChain._(child, [...steps, s], opts, key: key);

  // ----- эффекты -----
  MotionChain fadeIn({Duration? duration, Duration? delay, EaseFn? curve}) =>
      _add(_Step(_Kind.fade, (_) => const Fade(from: 0, to: 1),
          duration: duration, delay: delay ?? Duration.zero, curve: curve));

  MotionChain fadeOut({Duration? duration, Duration? delay, EaseFn? curve}) =>
      _add(_Step(_Kind.fade, (_) => const Fade(from: 1, to: 0),
          duration: duration, delay: delay ?? Duration.zero, curve: curve));

  MotionChain slideUp({double? distance, Duration? duration, Duration? delay, EaseFn? curve}) =>
      _add(_Step(_Kind.slide, (st) => Move(fromY: distance ?? st.distance),
          duration: duration, delay: delay ?? Duration.zero, curve: curve));
  // slideDown: Move(fromY: -d), slideLeft: Move(fromX: d), slideRight: Move(fromX: -d)

  MotionChain scaleIn({double from = 0.9, Duration? duration, Duration? delay, EaseFn? curve}) =>
      _add(_Step(_Kind.scale, (_) => Scale(from: from, to: 1),
          duration: duration, delay: delay ?? Duration.zero, curve: curve));
  // scaleOut: Scale(from: 1, to: 0.9) вместе с fadeOut при необходимости

  MotionChain popIn({Duration? duration, Duration? delay}) => _add(_Step(
      _Kind.pop, (_) => const Scale(from: 0.6, to: 1),
      duration: duration, delay: delay ?? Duration.zero));  // + Fade(0→1) отдельным шагом

  MotionChain pop({Duration? duration, Duration? delay}) => _add(_Step(
      _Kind.pop, (_) => const Scale(from: 0.75, to: 1),
      duration: duration, delay: delay ?? Duration.zero));

  MotionChain shake({double amplitude = 6, Duration? duration}) =>
      _add(_Step(_Kind.shake, (_) => Shake(amplitude: amplitude), duration: duration));

  MotionChain pulse({double amount = 0.08, Duration? duration}) =>
      _add(_Step(_Kind.pulse, (_) => Pulse(amount: amount), duration: duration));

  MotionChain spin({double turns = 1, Duration? duration}) => _add(_Step(
      _Kind.spin, (_) => Rotate(to: turns * 2 * 3.141592653589793), duration: duration));

  /// Пресет: fade + slide up, то, что нужно в 80% случаев.
  MotionChain appear({Duration? duration, Duration? delay}) =>
      fadeIn(duration: duration, delay: delay).slideUp(duration: duration, delay: delay);

  /// Свой эффект.
  MotionChain effect(Effect e, {Duration? duration, Duration? delay, EaseFn? curve}) =>
      _add(_Step(_Kind.custom, (_) => e,
          duration: duration, delay: delay ?? Duration.zero, curve: curve));

  // ----- структура -----
  MotionChain then({Duration delay = Duration.zero}) => _add(_Step.then(delay));
  MotionChain loop({int? times}) =>
      MotionChain._(child, steps, opts.copyWith(loops: times ?? _infinite), key: key);
  MotionChain onComplete(VoidCallback cb) =>
      MotionChain._(child, steps, opts.copyWith(onComplete: cb), key: key);

  /// Переход на пружинное следование за значением (не сочетается с эффектами цепочки).
  Widget to({Offset? offset, double? scale, double? opacity, double? rotation,
      bool stretch = false, Spring? spring}) {
    assert(steps.isEmpty, 'to() нельзя сочетать с эффектами цепочки. Используйте либо одно, либо другое.');
    return MotionTo(offset: offset, scale: scale, opacity: opacity, rotation: rotation,
        stretch: stretch, spring: spring, child: child);
  }

  @override
  State<MotionChain> createState() => _MotionChainState();
}

/// Простой контроллер для редких случаев («Повторить»).
final class MotionController {
  MotionPlayer? _p;
  void play() => _p?.play();
  void pause() => _p?.pause();
  void reverse() => _p?.reverse();
  void replay() => _p?.play(fromStart: true);
  void seek(Duration t) => _p?.seek(t);
  void stop() => _p?..pause()..seek(Duration.zero);
  bool get isRunning => _p?.isRunning ?? false;
}
```

**Состояние цепочки**

```dart
class _MotionChainState extends State<MotionChain> {
  final _player = MotionPlayer();
  MotionStyle _style = Motion.style;
  bool _reduce = false;
  bool _started = false;
  MotionSceneController? _scene;

  @override
  void initState() {
    super.initState();
    widget.opts.controller?._p = _player;
    // Подсказка вместо тихого «ничего не происходит».
    assert(widget.steps.isNotEmpty, motionEmptyChainMessage);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _style = MotionTheme.of(context);
    _reduce = widget.opts.respectReducedMotion &&
        (MediaQuery.maybeOf(context)?.disableAnimations ?? false);
    _scene = MotionSceneScope.maybeOf(context);
    _rebuildTimeline();
    if (!_started) {
      _started = true;
      _startInitial();
    }
  }

  @override
  void didUpdateWidget(MotionChain old) {
    super.didUpdateWidget(old);
    widget.opts.controller?._p = _player;
    _rebuildTimeline();                       // сохраняет текущее время (hot reload)
    final o = widget.opts;
    if (o.hasTrigger && o.trigger != old.opts.trigger) _fire();
  }

  void _rebuildTimeline() {
    final o = widget.opts;
    var extra = Duration.zero;
    if (o.index != null) {
      final each = o.stagger ?? _style.stagger;
      extra = each * o.index!;
      if (extra > _style.maxStagger) extra = _style.maxStagger;
    }
    _player
      ..loops = o.loops == _infinite ? null : o.loops
      ..onComplete = o.onComplete
      ..timeline = _resolve(extra);
    final scene = _scene;
    if (scene != null && o.at != null) scene.register(_player, o.at!);
  }

  Timeline _resolve(Duration extra) {
    var cursor = widget.opts.delay + extra + (_scene == null ? (widget.opts.at ?? Duration.zero) : Duration.zero);
    var end = Duration.zero;
    final clips = <Clip>[];
    for (final s in widget.steps) {
      if (s.isThen) { cursor = end + s.delay!; continue; }
      final start = cursor + s.delay!;
      final len = s.duration ?? _style.scaled(Duration(milliseconds: _baseMs[s.kind]!));
      clips.add(Clip(s.build!(_style), start: start, length: len,
          ease: s.curve ?? _defaultEase(s.kind)));
      if (start + len > end) end = start + len;
    }
    return Timeline(clips);
  }

  EaseFn _defaultEase(_Kind k) => switch (k) {
        _Kind.pop => _style.springEase,
        _Kind.spin => Ease.inOutCubic,
        _Kind.shake || _Kind.pulse => Ease.linear,
        _ => Ease.outCubic,
      };

  void _startInitial() {
    final inScene = _scene != null && widget.opts.at != null;
    if (inScene) { _player.seek(Duration.zero); return; }   // сцена сама управляет временем
    if (_reduce || widget.opts.hasTrigger) {
      _player.jumpToEnd();                                  // покой в конечном состоянии
    } else {
      _player.play(fromStart: true);
    }
  }

  void _fire() => _reduce ? _player.jumpToEnd() : _player.play(fromStart: true);

  @override
  void dispose() {
    _scene?.unregister(_player);
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MotionLayer(source: _player, child: widget.child);
}
```

**Заметки**

- Все остальные методы цепочки (`slideDown`, `slideLeft`, `slideRight`, `scaleOut`) пишутся по образцу `slideUp` и `scaleIn`.
- `popIn` и `pop` на практике добавляют ещё и прозрачность (`Fade`) отдельным шагом. Сделайте это внутри `popIn`, возвращая два шага.
- `slideStart` и `slideEnd` не входят в согласованный API; без отдельного согласования их не добавлять.
- Если пользователь изменил `trigger` на объект без корректного `==` (например, новый список каждый раз), эффект будет срабатывать на каждую пересборку. Это поведение надо поймать линтом (шаг 17) и описать в документации.

**Готово, когда:** вызов `Text('x').motion().appear()` работает без каких-либо обёрток; hot reload меняет параметры, не перезапуская анимацию; `trigger` не проигрывает эффект при первой сборке; режим reduced motion даёт мгновенное конечное состояние.

---

### Шаг 11. Каскад: `staggered()`

**Цель:** список с каскадом в одну строку.

```dart
extension MotionStaggerX on Iterable<Widget> {
  List<Widget> staggered({
    Duration? each,
    Widget Function(Widget child, int index)? build,
  }) {
    final list = toList();
    return [
      for (var i = 0; i < list.length; i++)
        build != null
            ? build(list[i], i)
            : list[i].motion(index: i, stagger: each).appear(),
    ];
  }
}
```

Общая задержка ограничивается `MotionStyle.maxStagger`, поэтому список из 200 элементов не «тянется» почти минуту.

**Подводный камень:** в `ListView.builder` элементы пересоздаются при прокрутке и анимируются заново. Решения: анимировать только первые N элементов (`index < 10 ? w.motion(index: index).appear() : w`). Дополнительный параметр `once` не входит в согласованный API и без отдельного согласования не добавляется.

**Готово, когда:** демо «Каскад» из галереи выглядит как в прототипе; в debug-режиме добавление 200 элементов не вызывает дропов кадров.

---

### Шаг 12. Следование за значением: `.to(...)`

**Цель:** замена семейства `Animated*` одним вызовом на пружинах.

**`spring_player.dart`**

```dart
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:motion_core/motion_core.dart';
import 'host.dart';
import 'source.dart';

final class SpringPlayer extends ChangeNotifier implements MotionSource, Tickable {
  SpringPlayer({Scheduler? scheduler})
      : _scheduler = scheduler ?? MotionHost.instance.scheduler;

  final Scheduler _scheduler;
  @override
  final EffectState state = EffectState();

  // Значения сами в планировщик не добавляются: тикает весь плеер целиком.
  final _x = SpringValue(0), _y = SpringValue(0), _scale = SpringValue(1),
      _rot = SpringValue(0), _alpha = SpringValue(1);
  bool _initialized = false, _usesOpacity = false, stretch = false;

  @override
  bool get usesOpacity => _usesOpacity;

  List<SpringValue> get _all => [_x, _y, _scale, _rot, _alpha];  // оптимизируйте: константный список полей

  void update({Offset? offset, double? scale, double? opacity, double? rotation,
      required Spring spring, bool stretch = false}) {
    this.stretch = stretch;
    for (final v in _all) { v.spring = spring; }
    void go(SpringValue v, double? target) {
      if (target == null) return;
      _initialized ? v.animateTo(target) : v.snapTo(target);
    }
    go(_x, offset?.dx); go(_y, offset?.dy); go(_scale, scale);
    go(_rot, rotation); go(_alpha, opacity);
    if (opacity != null) _usesOpacity = true;
    _initialized = true;
    _scheduler.add(this);
    _apply();
  }

  @override
  bool tick(double dt) {
    var active = false;
    for (final v in _all) {
      final r = v.tick(dt);
      active = active || r;
    }
    _apply();
    return active;
  }

  void _apply() {
    state.reset();
    state
      ..dx = _x.value
      ..dy = _y.value
      ..scaleX = _scale.value
      ..scaleY = _scale.value
      ..rotation = _rot.value
      ..opacity = _alpha.value.clamp(0.0, 1.0).toDouble();
    if (stretch) {
      final vx = _x.velocity, vy = _y.velocity;
      final speed = math.sqrt(vx * vx + vy * vy);
      final k = (speed / 1800).clamp(0.0, 0.35).toDouble();
      state
        ..rotation += math.atan2(vy, vx)
        ..scaleX *= 1 + k
        ..scaleY *= 1 - k * 0.8;
    }
    notifyListeners();
  }
}
```

> Растяжение через поворот и масштаб корректно выглядит на круглых и симметричных виджетах. Для произвольных виджетов позже добавьте в `EffectState` поля «растяжение вдоль направления» и применяйте матрицу `R·S·R⁻¹`.

**Виджет**

```dart
final class MotionTo extends StatefulWidget {
  const MotionTo({super.key, required this.child, this.offset, this.scale,
      this.opacity, this.rotation, this.stretch = false, this.spring});
  final Widget child;
  final Offset? offset;
  final double? scale, opacity, rotation;
  final bool stretch;
  final Spring? spring;
  @override
  State<MotionTo> createState() => _MotionToState();
}

class _MotionToState extends State<MotionTo> {
  final _player = SpringPlayer();
  Spring _spring = Spring.smooth;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final style = MotionTheme.of(context);
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    _spring = widget.spring ??
        Spring.bounce(duration: 0.5 * style.durationScale, bounce: reduce ? 0 : style.bounce);
    _push();
  }

  @override
  void didUpdateWidget(MotionTo old) {
    super.didUpdateWidget(old);
    _push();
  }

  void _push() => _player.update(
      offset: widget.offset, scale: widget.scale, opacity: widget.opacity,
      rotation: widget.rotation, spring: _spring, stretch: widget.stretch);

  @override
  void dispose() { _player.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => MotionLayer(source: _player, child: widget.child);
}
```

`SpringValue` из шага 5 работает и без планировщика (`scheduler` необязателен): в этом случае тики вызывает владелец, здесь это `SpringPlayer`.

**Готово, когда:** демо с шаром: повторные нажатия в полёте не дают рывков; `stretch` растягивает шар вдоль движения; при выключенной анимации в системе шар перемещается без колебаний.

---

### Шаг 13. Сцены: таймлайн, scrub и привязка к скроллу

**Цель:** общая шкала времени для нескольких цепочек.

**`scene.dart`**

```dart
import 'package:flutter/widgets.dart';
import 'package:motion_core/motion_core.dart';
import 'host.dart';
import 'player.dart';

final class MotionSceneController extends ChangeNotifier implements Tickable {
  MotionSceneController({Scheduler? scheduler})
      : _scheduler = scheduler ?? MotionHost.instance.scheduler;

  final Scheduler _scheduler;
  final _members = <MotionPlayer, Duration>{};
  Duration _time = Duration.zero;
  bool _running = false;
  ScrollController? _scroll;

  Duration get duration => _members.entries.fold(Duration.zero, (m, e) {
        final end = e.value + e.key.duration;
        return end > m ? end : m;
      });

  double get progress => duration == Duration.zero
      ? 1.0
      : (_time.inMicroseconds / duration.inMicroseconds).clamp(0.0, 1.0).toDouble();

  bool get isRunning => _running;

  void register(MotionPlayer p, Duration at) {
    _members[p] = at;
    _sync();
  }

  void unregister(MotionPlayer p) => _members.remove(p);

  void play({bool fromStart = true}) {
    if (fromStart || _time >= duration) _time = Duration.zero;
    _running = true;
    _scheduler.add(this);
  }

  void pause() => _running = false;

  /// [progress] от 0 до 1.
  void seek(double progress) {
    _running = false;
    _time = duration * progress.clamp(0.0, 1.0);
    _sync();
  }

  void bindTo(ScrollController c) {
    _scroll?.removeListener(_onScroll);
    _scroll = c..addListener(_onScroll);
  }

  void _onScroll() {
    final pos = _scroll!.position;
    if (pos.maxScrollExtent <= 0) return;
    seek(pos.pixels / pos.maxScrollExtent);
  }

  void _sync() {
    _members.forEach((p, at) => p.seek(_time - at));   // Timeline сам обрежет отрицательные значения
    notifyListeners();
  }

  @override
  bool tick(double dt) {
    if (!_running) return false;
    _time += Duration(microseconds: (dt * 1e6).round());
    if (_time >= duration) {
      _time = duration;
      _running = false;
    }
    _sync();
    return _running;
  }

  @override
  void dispose() {
    _scroll?.removeListener(_onScroll);
    _running = false;
    super.dispose();
  }
}

final class MotionSceneScope extends InheritedWidget {
  const MotionSceneScope({super.key, required this.controller, required super.child});
  final MotionSceneController controller;

  static MotionSceneController? maybeOf(BuildContext c) =>
      c.getInheritedWidgetOfExactType<MotionSceneScope>()?.controller;

  @override
  bool updateShouldNotify(MotionSceneScope old) => controller != old.controller;
}

final class MotionScene extends StatefulWidget {
  const MotionScene({super.key, this.controller, this.autoPlay = true, required this.child});
  final MotionSceneController? controller;
  final bool autoPlay;
  final Widget child;
  @override
  State<MotionScene> createState() => _MotionSceneState();
}

class _MotionSceneState extends State<MotionScene> {
  late final MotionSceneController? _own =
      widget.controller == null ? MotionSceneController() : null;
  MotionSceneController get _c => widget.controller ?? _own!;

  @override
  void initState() {
    super.initState();
    if (widget.autoPlay) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _c.play();
      });
    }
  }

  @override
  void dispose() { _own?.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) =>
      MotionSceneScope(controller: _c, child: widget.child);
}
```

**`MotionScrubber`** — готовый слайдер плюс дорожки: слушает `MotionSceneController`, рисует по строке на каждого участника (позиция `at` и длительность), красный «playhead» и `Slider`, вызывающий `seek`. Это отладочный виджет, в релиз приложения его включать не обязательно.

**Готово, когда:** демо «Интро» собрано на `MotionScene`; ползунок листает вперёд и назад без артефактов; `bindTo(scrollController)` связывает прогресс со скроллом.

---

### Шаг 14. Тесты виджетов и golden

**Цель:** зафиксировать поведение, чтобы смело менять внутренности.

**Вспомогательные функции**

```dart
Widget wrap(Widget w) => Directionality(textDirection: TextDirection.ltr, child: w);
RenderMotion renderOf(WidgetTester t) => t.renderObject<RenderMotion>(find.byType(MotionLayer));
```

**Набор обязательных тестов**

```dart
testWidgets('fadeIn: 0 → 1', (tester) async {
  await tester.pumpWidget(wrap(
      const SizedBox(width: 10, height: 10).motion().fadeIn(duration: 200.ms)));
  expect(renderOf(tester).source.state.opacity, 0);
  await tester.pump();                       // первый кадр задаёт точку отсчёта
  await tester.pump(100.ms);
  expect(renderOf(tester).source.state.opacity, inExclusiveRange(0.3, 1.0));
  await tester.pumpAndSettle();
  expect(renderOf(tester).source.state.opacity, 1);
});

testWidgets('trigger: при первой сборке покой, при смене проигрывается', (tester) async {
  Widget build(bool v) => wrap(const SizedBox(width: 10, height: 10)
      .motion(trigger: v).fadeIn(duration: 200.ms));
  await tester.pumpWidget(build(false));
  expect(renderOf(tester).source.state.opacity, 1);
  await tester.pumpWidget(build(true));
  expect(renderOf(tester).source.state.opacity, 0);
});

testWidgets('reduced motion: сразу конечное состояние', (tester) async {
  await tester.pumpWidget(MediaQuery(
    data: const MediaQueryData(disableAnimations: true),
    child: wrap(const SizedBox(width: 10, height: 10).motion().fadeIn()),
  ));
  expect(renderOf(tester).source.state.opacity, 1);
});

testWidgets('then: второй этап начинается после первого', (tester) async { /* ... */ });
testWidgets('staggered: задержка растёт с индексом и ограничена', (tester) async { /* ... */ });
testWidgets('to: перенацеливание в полёте сохраняет скорость', (tester) async { /* ... */ });
testWidgets('scene: seek(0.5) ставит участников в нужные состояния', (tester) async { /* ... */ });
testWidgets('dispose: нет утечек, планировщик засыпает', (tester) async { /* ... */ });
```

**Golden-кадры**

```dart
const _key = ValueKey('motion-golden');

extension MotionGolden on WidgetTester {
  Future<void> captureFrames(Widget w, {required List<Duration> at, required String name}) async {
    await pumpWidget(wrap(RepaintBoundary(key: _key, child: w)));
    await pump();
    var prev = Duration.zero;
    for (final t in at) {
      await pump(t - prev);
      prev = t;
      await expectLater(find.byKey(_key),
          matchesGoldenFile('goldens/${name}_${t.inMilliseconds}ms.png'));
    }
  }
}
```

Golden-файлы генерируйте и проверяйте только на одной платформе (Linux в CI), иначе шрифты и сглаживание будут давать расхождения. Обновление: `flutter test --update-goldens`.

**Готово, когда:** покрытие слоя `kinetic_motion` не ниже 80%, в CI есть golden-тесты для всех пресетов из таблицы 2.13.

---

### Этап C. Расширения и качество

---

### Шаг 15. Частицы: `Burst`

**Цель:** вспышка частиц одной строкой, без аллокаций в кадре.

**Пул частиц (`motion_particles/lib/src/pool.dart`)**

```dart
import 'dart:typed_data';

final class ParticlePool {
  ParticlePool(this.capacity)
      : x = Float32List(capacity), y = Float32List(capacity),
        vx = Float32List(capacity), vy = Float32List(capacity),
        life = Float32List(capacity), maxLife = Float32List(capacity),
        size = Float32List(capacity), color = Uint32List(capacity);

  final int capacity;
  int count = 0;
  final Float32List x, y, vx, vy, life, maxLife, size;
  final Uint32List color;

  void spawn(double px, double py, double pvx, double pvy,
      double lifetime, double sz, int argb) {
    if (count == capacity) return;          // пул полон: новые частицы пропускаются
    final i = count++;
    x[i] = px; y[i] = py; vx[i] = pvx; vy[i] = pvy;
    life[i] = 0; maxLife[i] = lifetime; size[i] = sz; color[i] = argb;
  }

  void update(double dt, {double gravity = 520, double drag = 1.5}) {
    final k = (1 - drag * dt).clamp(0.0, 1.0);
    for (var i = count - 1; i >= 0; i--) {
      life[i] += dt;
      if (life[i] >= maxLife[i]) { _remove(i); continue; }
      vy[i] += gravity * dt;
      vx[i] *= k; vy[i] *= k;
      x[i] += vx[i] * dt; y[i] += vy[i] * dt;
    }
  }

  void _remove(int i) {
    final last = --count;                    // удаление заменой на последнюю: O(1)
    if (i == last) return;
    x[i] = x[last]; y[i] = y[last]; vx[i] = vx[last]; vy[i] = vy[last];
    life[i] = life[last]; maxLife[i] = maxLife[last];
    size[i] = size[last]; color[i] = color[last];
  }
}
```

**Виджет (схема)**

```dart
final class Burst extends StatefulWidget {
  const Burst({super.key, required this.when, this.count = 30,
      this.colors = warm, this.minSpeed = 120, this.maxSpeed = 340,
      this.minLife = 0.6, this.maxLife = 1.1, this.gravity = 520,
      this.ring = true, this.seed});

  static const warm = [Color(0xFFD85A30), Color(0xFFD4537E), Color(0xFFEF9F27), Color(0xFF7F77DD)];

  final bool when;                // вспышка при переходе false → true
  final int count;
  final List<Color> colors;
  final double minSpeed, maxSpeed, minLife, maxLife, gravity;
  final bool ring;
  final int? seed;                // для воспроизводимых тестов
  @override
  State<Burst> createState() => _BurstState();
}

class _BurstState extends State<Burst> {
  late final _sim = _BurstSim(ParticlePool(256));
  late final _rnd = Random(widget.seed);

  @override
  void didUpdateWidget(Burst old) {
    super.didUpdateWidget(old);
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (!old.when && widget.when && !reduce) _sim.emit(widget, _rnd);
  }

  @override
  void dispose() { _sim.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: RepaintBoundary(
          // Нулевой размер: частицы рисуются от центра места, куда вы поместили Burst.
          child: CustomPaint(painter: _BurstPainter(_sim), size: Size.zero),
        ),
      );
}
```

`_BurstSim` — `ChangeNotifier` и `Tickable`: `emit` создаёт `count` частиц со случайным углом и скоростью, регистрируется в `MotionHost.instance.scheduler`; `tick` вызывает `pool.update` и `notifyListeners`; возвращает `true`, пока есть живые частицы или кольцо. `_BurstPainter` наследуется от `CustomPainter` с `super(repaint: sim)`, переносит начало координат в центр и рисует частицы одним переиспользуемым `Paint` (альфа считается как `((1 - life/maxLife) * 255).round()` и собирается в ARGB-цвет вручную, без устаревших методов `Color`). `shouldRepaint` возвращает `false`: перерисовку запускает `repaint`.

**Оптимизация позже:** группировать частицы по цвету и рисовать `drawRawPoints`, либо использовать `drawRawAtlas` для спрайтов.

**Готово, когда:** 5000 частиц одновременно держат частоту кадров на референсном устройстве; в профайле нет аллокаций в `tick` и `paint` (кроме `Offset` в простой версии); при `reduceMotion` частицы не создаются.

---

### Шаг 16. Игры: фиксированный шаг и адаптер Flame

**Цель:** то же ядро в игровом цикле.

**Фиксированный шаг в ядре (`stepper.dart`)**

```dart
final class FixedStepper {
  FixedStepper({this.step = 1 / 60, this.maxFrame = 0.25});
  final double step, maxFrame;
  double _acc = 0;

  /// Вызывает [update] фиксированными шагами. Возвращает число шагов.
  int advance(double dt, void Function(double step) update) {
    _acc += dt > maxFrame ? maxFrame : dt;   // защита от «спирали смерти»
    var n = 0;
    while (_acc >= step) { update(step); _acc -= step; n++; }
    return n;
  }

  /// Доля шага для интерполяции при отрисовке.
  double get alpha => _acc / step;
}
```

**Адаптер Flame (`motion_flame`)**, схема:

```dart
mixin MotionEffects on PositionComponent {
  final _scheduler = Scheduler();     // из motion_core: без Flutter-тикера
  final _state = EffectState();
  Timeline? _timeline;
  Duration _time = Duration.zero;
  late Vector2 _basePosition = position.clone();

  void runTimeline(Timeline t, {bool fromStart = true}) {
    _timeline = t;
    if (fromStart) _time = Duration.zero;
    _basePosition = position.clone();
  }

  @override
  void update(double dt) {
    super.update(dt);
    _scheduler.update(dt);
    final tl = _timeline;
    if (tl == null) return;
    _time += Duration(microseconds: (dt * 1e6).round());
    tl.evaluate(_time, _state);
    position.setValues(_basePosition.x + _state.dx, _basePosition.y + _state.dy);
    scale.setValues(_state.scaleX, _state.scaleY);
    angle = _state.rotation;
    if (this is OpacityProvider) (this as OpacityProvider).opacity = _state.opacity;
    if (_time >= tl.duration) _timeline = null;
  }
}
```

Сверьте названия API с вашей версией Flame (`OpacityProvider`, `Vector2.setValues`, `scale`).

**Особенности игр**

- Пулы объектов для частых анимаций (всплывающие цифры урона, вспышки).
- `timeScale` для замедления времени: умножайте `dt` перед передачей планировщику.
- Детерминированный запуск: `Random(seed)` для частиц, фиксированный шаг для физики.
- Никаких аллокаций в `update` и `render`.

**Готово, когда:** мини-игра в `example/mini_game` использует таймлайн, пружины и частицы из библиотеки и держит частоту кадров устройства.

---

### Шаг 17. Ошибки, линты и сниппеты

**Цель:** новичок не застревает, а ошибки находятся до запуска.

**Дружелюбные ошибки**

```dart
final class MotionError extends FlutterError {
  MotionError(String what, {required String why, required String fix, String? docs})
      : super.fromParts([
          ErrorSummary(what),
          ErrorDescription(why),
          ErrorHint(fix),
          if (docs != null) ErrorDescription('Подробнее: $docs'),
        ]);
}

const motionEmptyChainMessage =
    'Вызван .motion(), но не добавлено ни одного эффекта. '
    'Добавьте, например: .motion().appear() или .motion().fadeIn().';
```

Шаблон текста: **что случилось → почему → как исправить → ссылка**. Все сообщения проходят вычитку: никакого жаргона, одна конкретная правка.

**Линты (`motion_lints`, на базе `custom_lint`)**

| Правило | Что ловит | Исправление (quick fix) |
|---|---|---|
| `motion_empty_chain` | `.motion()` без эффектов | Добавить `.appear()` |
| `motion_unused_chain` | Результат `.motion()` нигде не используется как виджет | Подсказать использовать в дереве |
| `motion_constant_trigger` | `trigger:` — литерал или константа (никогда не сработает) | Передать изменяемое значение |
| `motion_unstable_trigger` | `trigger:` — новый список/мапа/объект на каждой сборке | Использовать значение с корректным `==` |
| `motion_to_with_effects` | `.to()` после эффектов | Убрать эффекты или разделить виджеты |
| `motion_in_builder_without_index` | `.appear()` в `ListView.builder` без `index` | Добавить `index: i` |

Схема правила (сверяйте API `custom_lint_builder` с актуальной документацией):

```dart
class EmptyChainRule extends DartLintRule {
  const EmptyChainRule() : super(code: _code);
  static const _code = LintCode(
    name: 'motion_empty_chain',
    problemMessage: '.motion() без эффектов ничего не делает.',
    correctionMessage: 'Добавьте эффект: .motion().appear()',
  );

  @override
  void run(CustomLintResolver resolver, ErrorReporter reporter, CustomLintContext context) {
    context.registry.addMethodInvocation((node) {
      if (node.methodName.name != 'motion') return;
      // Проверить, что получатель — Widget и результат не продолжен цепочкой.
      reporter.atNode(node, _code);
    });
  }
}
```

**Сниппеты для IDE** (VS Code, `dart.json`)

```json
{
  "motion appear":   { "prefix": "mappear",  "body": ["${1:child}.motion().appear()"] },
  "motion chain":    { "prefix": "mchain",   "body": ["${1:child}.motion().fadeIn().slideUp()"] },
  "motion staggered":{ "prefix": "mstagger", "body": ["${1:children}.staggered()"] },
  "motion to":       { "prefix": "mto",      "body": ["${1:child}.motion().to(offset: ${2:target})"] },
  "motion trigger":  { "prefix": "mtrigger", "body": ["${1:child}.motion(trigger: ${2:value}).pop()"] }
}
```

Аналогичные live templates опубликуйте для Android Studio.

**Готово, когда:** все шесть правил работают на тестовом проекте; любая ошибка из списка в документации воспроизводится и даёт понятное сообщение.

---

### Шаг 18. Галерея и playground

**Цель:** увидеть эффект и скопировать код за 10 секунд.

**Состав `example/gallery`**

1. **Лента эффектов:** карточка на каждый метод из таблицы 2.2: превью, кнопка «Повторить», код.
2. **Четыре главные демо** (раздел 2.12).
3. **Лаборатория стиля:** переключатель `calm / balanced / playful / snappy` и ползунки пружины.
4. **Рецепты (cookbook):** появление списка, лайк, переход, ввод с ошибкой (`shake`), карточка с переворотом, онбординг.
5. **Вкладка «Код»** с кнопкой копирования.

**Публикация в web**

```bash
cd example/gallery
flutter build web --release --wasm
```

Настройте GitHub Actions для публикации на GitHub Pages. Учтите `--base-href` для репозитория.

**Готово, когда:** любой эффект из таблицы 2.2 воспроизводится на сайте и в приложении; ссылка на playground есть в README.

---

### Шаг 19. DevTools и оверлей отладки

**Цель:** видеть, что анимируется прямо сейчас.

1. **Оверлей** `MotionDebug(child: ...)`: счётчик активных анимаций, время `Scheduler.update`, подсветка анимируемых областей рамкой.
2. **Служебные расширения VM:** в `MotionHost` в debug-режиме регистрируйте `developer.registerExtension('ext.motion.snapshot', ...)`, возвращающее список активных плееров (источник, прогресс, длительность).
3. **Расширение DevTools** (`motion_devtools`): в `extension/devtools/config.yaml` описание, внутри Flutter-web приложение. Оно опрашивает `ext.motion.snapshot`, показывает дорожки и прогресс, позволяет «листать» сцену. Сборка и копирование расширения выполняются командой из пакета `devtools_extensions`, детали сверяйте с его документацией.

**Готово, когда:** в работающем приложении видно список активных анимаций и их прогресс; оверлей не влияет на производительность в release (вырезается через `kDebugMode`).

---

### Шаг 20. Документация, релиз и сопровождение

**Цель:** выпустить пакеты и сделать их находимыми.

**1. README** (первый экран решает всё):

- Название, одна строка о ценности, GIF с тремя эффектами.
- Установка (2 строки).
- Пример «пяти минут»: появление, список, следование, триггер.
- Ссылки на playground, cookbook, API.

**2. Сайт документации.** Любой статический генератор (например, MkDocs или Docusaurus). Разделы: Быстрый старт, Основные методы (12), Стили, Сцены, Частицы, Игры, Cookbook, Миграция с `flutter_animate` и `AnimationController`, FAQ, Архитектура.

**3. API-справочник.** `dart doc` для каждого пакета; 100% публичных символов с примером в комментарии. Примеры в комментариях проверяются в CI.

**4. Подготовка к публикации**

```bash
dart pub publish --dry-run          # в каждом пакете
```

В `pubspec.yaml`: `description` (60–180 символов), `repository`, `issue_tracker`, `topics`, `screenshots`. В `example/` каждого пакета — запускаемый пример.

**5. Автоматическая публикация** (на pub.dev включите automated publishing для репозитория и укажите шаблон тега, например `motion_core-v{{version}}`)

```yaml
name: publish
on:
  push:
    tags:
      - 'motion_core-v[0-9]+.[0-9]+.[0-9]+*'
      - 'kinetic_motion-v[0-9]+.[0-9]+.[0-9]+*'
jobs:
  core:
    if: startsWith(github.ref_name, 'motion_core-v')
    permissions: { id-token: write }
    uses: dart-lang/setup-dart/.github/workflows/publish.yml@v1
    with: { working-directory: packages/motion_core }
```

Для Flutter-пакета следуйте официальной инструкции pub.dev по публикации Flutter-пакетов через OIDC (шаг публикации выполняется командой `flutter pub publish --force`). Порядок публикации всегда: `motion_core` → `kinetic_motion` → остальные.

**6. Версии и совместимость**

- SemVer для каждого пакета отдельно. До 1.0 ломающие изменения допустимы в минорной версии, но всегда описываются в CHANGELOG.
- Устаревание: `@Deprecated('Используйте X. Будет удалено в 0.5.0')`, удаление не раньше чем через один минорный релиз.
- Поддерживаются две последние стабильные версии Flutter.

**7. Сообщество:** `CONTRIBUTING.md`, шаблоны issue/PR, метки `good first issue`, кодекс поведения, `SECURITY.md`.

**Готово, когда:** пакеты опубликованы, `pana`/pub points на максимуме, у нового пользователя проходит «тест пяти минут» (раздел 10).

---

# Часть III. Как доводим до качества

## 6. Производительность

### 6.1. Бюджет кадра

| Частота | Бюджет |
|---|---|
| 60 Гц | 16,6 мс |
| 90 Гц | 11,1 мс |
| 120 Гц | 8,3 мс |

Ориентир: библиотека занимает не больше 10% бюджета на типовой сцене. Цель уточняется после первых замеров.

### 6.2. Золотые правила

1. Один планировщик, один запрос кадра. Планировщик спит без работы.
2. Никакого `setState` на каждый кадр: перерисовка через `markNeedsPaint`.
3. Никаких аллокаций в `tick`, `apply`, `paint`, `update`.
4. Опасные слои (`saveLayer`) только там, где без них нельзя; `Opacity=1` слоя не создаёт.
5. `RepaintBoundary` вокруг независимо анимируемых областей.
6. Не анимируйте то, что не видно (`opacity ≤ 0.001` — не рисуем).

### 6.3. Как измерять

1. Только `flutter run --profile` на **реальном** устройстве.
2. DevTools → Performance: ищите кадры дольше бюджета, смотрите разбивку UI/Raster.
3. Повторяйте на слабом Android, iPhone и десктопе.
4. Для автоматических замеров используйте `flutter drive --profile` с `traceAction` и сохраняйте `timeline_summary`.
5. Результаты каждого релиза сравнивайте с предыдущим.

### 6.4. Бенчмарки (`benchmarks/`)

| Сценарий | Параметры |
|---|---|
| Пружины | 1, 10, 100, 1000 одновременных |
| Цепочки | 100 виджетов с `fadeIn().slideUp()` |
| Каскад | список из 200 элементов |
| Таймлайн | сцена из 50 участников |
| Частицы | 1000, 5000, 10 000 |

Регрессия больше 10% блокирует слияние до объяснения.

### 6.5. Типичные ловушки

| Ловушка | Эффект | Решение |
|---|---|---|
| Прозрачность большого поддерева | `saveLayer`, просадка | Анимировать у листьев, использовать цвет вместо `Opacity` |
| Размытие (`ImageFilter`) | Дорого на слабых GPU | Предрасчитанные картинки, шейдер |
| Тени, меняющиеся каждый кадр | Перерасчёт | Фиксированные тени |
| `ClipPath` с анимацией | Антиалиасинг | Упрощённые формы |
| Много `Ticker`-ов | Лишние пробуждения | Один `MotionHost` |
| Списки с анимацией при прокрутке | Повторы эффекта | Анимировать только первые элементы |

---

## 7. Тестирование

### 7.1. Пирамида

| Уровень | Что | Инструменты |
|---|---|---|
| Юнит (ядро) | Пружины, кривые, эффекты, таймлайн | `package:test` |
| Property-тесты | Инварианты на случайных параметрах | цикл со случайными значениями и `Random(seed)` |
| Виджеты | Цепочки, триггеры, сцены, нажатия | `flutter_test` |
| Golden | Ключевые кадры пресетов | `matchesGoldenFile`, CI на Linux |
| Интеграционные | Сцены на устройстве | `integration_test` |
| Бенчмарки | Время кадра, аллокации | DevTools, `flutter drive` |

### 7.2. Property-тесты (идеи)

- Для любых `stiffness, damping, mass > 0` решение конечно и сходится к цели.
- `solve(t = 0)` возвращает `(from, velocity)`.
- Аналитика и мелкошаговое численное интегрирование совпадают в пределах допуска.
- `Timeline.evaluate(t)` не зависит от порядка вызовов.
- При `t = 0` и `t = 1` эффекты дают ожидаемые крайние состояния.

### 7.3. Детерминизм

- Никаких реальных таймеров: время только из `tester.pump(duration)` или ручного `tick`.
- Случайность частиц только из `Random(seed)`.
- Golden-файлы генерируются на одной платформе.

### 7.4. Пороги качества

| Метрика | Порог |
|---|---|
| Покрытие `motion_core` | ≥ 90% |
| Покрытие `kinetic_motion` | ≥ 80% |
| Предупреждения анализатора | 0 |
| Документированные публичные символы | 100% |

---

## 8. CI/CD и релизы

### 8.1. Конвейер для pull request

1. Форматирование и анализ (`--fatal-infos`).
2. Тесты ядра с покрытием.
3. Тесты Flutter-пакетов, golden-тесты.
4. Сборка примеров (Android debug, web).
5. `dart pub publish --dry-run` для каждого пакета.
6. Проверка CHANGELOG (есть запись для изменений API).

По расписанию (ночью) и на релизных ветках: бенчмарки и сравнение с предыдущим релизом. Матрица Flutter: стабильная и предыдущая стабильная версии.

### 8.2. Релизная процедура

1. Обновить версии и CHANGELOG (`melos version` или вручную).
2. Прогнать полный CI и бенчмарки.
3. Создать тег `motion_core-vX.Y.Z`, затем `kinetic_motion-vX.Y.Z`.
4. CI публикует пакеты на pub.dev.
5. Опубликовать заметки о релизе, обновить сайт и playground.

### 8.3. Ветки и коммиты

- `main` всегда зелёная; работа в короткоживущих ветках.
- Conventional Commits (`feat:`, `fix:`, `perf:`, `docs:`, `refactor:`).
- Каждое изменение публичного API сопровождается ADR в `docs/adr/`.

---

## 9. Дорожная карта по неделям

Ориентиры для одного разработчика на полной занятости. При частичной занятости умножайте сроки.

| Недели | Шаги | Результат | Релиз |
|---|---|---|---|
| 1 | 1 | Репозиторий, CI, правила | — |
| 2 | 2–3 | Пружины, кривые, эффекты с тестами | — |
| 3 | 4–5 | Таймлайн, планировщик, `SpringValue` | — |
| 4 | 6–8 | `MotionHost`, плеер, `RenderMotion` | — |
| 5 | 9–10 | Стиль, цепочка `.motion()` | — |
| 6 | 11–12 | Каскад, `.to()` | — |
| 7 | 13–14 | Сцены, тесты виджетов, golden | — |
| 8 | полировка | Подбор значений по умолчанию, галерея v0, README | **0.1.0** |
| 9–10 | 15 | Частицы `Burst` | 0.2.0 |
| 11 | 16 | Flame и мини-игра | 0.3.0 |
| 12 | 17 | Линты, ошибки, сниппеты | 0.4.0 |
| 13 | 18 | Playground, cookbook | 0.5.0 |
| 14 | 19 | DevTools, оверлей | 0.6.0 |
| 15 | 10 (раздел) | Проверка на людях, правки API | 0.9.0 (бета) |
| 16–19 | стабилизация | Баги, документация, миграции | **1.0.0** |

### Критерии приёмки релизов

**0.1.0**

- [ ] Все 12 методов основного набора работают и покрыты тестами.
- [ ] Тест «пяти минут» проходит у 3 из 5 новых разработчиков.
- [ ] Нет обязательной настройки.
- [ ] Reduced motion работает.
- [ ] Нажатия по анимированным виджетам корректны.
- [ ] Один тикер на приложение подтверждён профилированием.

**0.9.0 (бета)**

- [ ] API заморожен, аудит имён пройден.
- [ ] Бенчмарки без регрессий за 3 релиза.
- [ ] Документация и cookbook полные.
- [ ] Тест «пяти минут» проходит у 4 из 5.

**1.0.0**

- [ ] Все критерии из разделов 6–7 выполнены.
- [ ] 160/160 pub points.
- [ ] Политика версий и поддержки опубликована.

---

## 10. Проверка простоты на людях

Простота не измеряется «на глаз». Проводите короткие тесты.

**Участники:** 5 разработчиков Flutter, не видевших библиотеку (разный опыт).

**Сценарий (по 30 минут на человека)**

1. Дать только README. Не подсказывать.
2. Задачи по порядку: (а) анимировать появление текста; (б) каскад в списке; (в) шар, следующий за нажатием; (г) эффект на лайк; (д) исправить намеренно допущенную ошибку (пустая цепочка).
3. Наблюдать молча, фиксировать: время на каждую задачу, куда смотрел, где ошибся, что сказал вслух.

**Метрики**

| Метрика | Цель |
|---|---|
| Время на задачу (а) | до 2 минут |
| Время на задачи (а–г) суммарно | до 5–10 минут |
| Обращения к справочнику API | 0–1 |
| Задача (д) решена по тексту ошибки | у всех |

**После теста:** каждая проблема превращается в изменение API, названия, умолчания или сообщения об ошибке. Повторите с новой пятёркой после правок.

---

## 11. Риски

| Риск | Вероятность | Влияние | Снижение |
|---|---|---|---|
| Конкуренция с `flutter_animate` | Высокая | Среднее | Фокус на пружинах, сценах, играх, нулевой настройке |
| Простое API «разрастается» | Средняя | Высокое | Бюджет API (12 методов), ADR на каждое расширение |
| Просадки на слабых устройствах | Средняя | Высокое | Бенчмарки в CI, профилирование на железе с первого дня |
| Ошибки в `RenderObject` (слои, нажатия) | Средняя | Высокое | Тесты нажатий, изучение `RenderOpacity`/`RenderTransform`, ревью |
| Изменения во Flutter и Impeller | Средняя | Среднее | Тонкий render-слой, матрица версий в CI |
| Неудобное API обнаружится поздно | Средняя | Высокое | Тесты на людях с версии 0.1 |
| Выгорание и нехватка времени | Высокая | Среднее | Малый объём 1.0, автоматизация, документация для контрибьюторов |
| Занятое имя пакета | Низкая | Низкое | Проверка до начала публичной работы |

---

## 12. Чек-листы

### 12.1. Новый эффект

- [ ] `Effect.apply` без аллокаций, `affectsOpacity` задан верно.
- [ ] Юнит-тест на `t = 0 / 0.5 / 1`.
- [ ] Метод в цепочке с `duration`, `delay`, `curve` и умолчаниями из стиля.
- [ ] Строка в таблице 2.13.
- [ ] Golden-тест (если визуальный).
- [ ] Пример в галерее и cookbook.
- [ ] Поведение при reduced motion.
- [ ] Запись в CHANGELOG.

### 12.2. Pull request

- [ ] Тесты зелёные, покрытие не упало.
- [ ] `analyze` без замечаний, публичное API документировано.
- [ ] Бенчмарки без регрессии для горячих путей.
- [ ] Для изменений API — ADR и запись в CHANGELOG.
- [ ] Новый метод в основном наборе: что убрано взамен (бюджет API).

### 12.3. Перед релизом

- [ ] Критерии этапа из раздела 9 выполнены.
- [ ] `dart pub publish --dry-run` в каждом пакете.
- [ ] Примеры собираются на всех платформах.
- [ ] Сайт и playground обновлены.
- [ ] Заметки о релизе готовы.

### 12.4. Перед первым публичным коммитом

- [ ] Имя пакета проверено.
- [ ] Лицензия, README, CONTRIBUTING, CODE_OF_CONDUCT, SECURITY.
- [ ] CI зелёный.
- [ ] Первые ADR записаны.

---

## 13. Глоссарий

| Термин | Значение |
|---|---|
| Цепочка (chain) | Последовательность вызовов `.motion().fadeIn().slideUp()` |
| Эффект (effect) | Элементарное преобразование: прозрачность, сдвиг, масштаб, поворот |
| `EffectState` | Общая изменяемая структура, в которую эффекты записывают результат кадра |
| Пружина (spring) | Физическая модель движения к цели (жёсткость, затухание, масса) |
| Перенацеливание | Смена цели в полёте с сохранением позиции и скорости |
| Каскад (stagger) | Запуск анимаций элементов со сдвигом по времени |
| Сцена (scene) | Общая шкала времени для нескольких цепочек |
| Scrub | Ручная прокрутка анимации вперёд и назад |
| Триггер | Значение, смена которого перезапускает эффект |
| Стиль (style) | Набор умолчаний, задающий «характер» движения всего приложения |
| Reduced motion | Системная настройка сокращения анимаций |
| Горячий путь | Код, выполняемый каждый кадр |
| Fixed timestep | Обновление мира фиксированными шагами |
| ADR | Запись об архитектурном решении |

---

*Согласованный порядок: шаги 1–20 строго последовательно. Переход к шагу 10 до завершения шагов 3–9 не допускается.*
