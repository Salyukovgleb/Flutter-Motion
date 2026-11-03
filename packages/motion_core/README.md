# motion_core

Чистое Dart-ядро Flutter Motion без Flutter, `dart:ui` и сторонних runtime-зависимостей.

## Пружина

Доступны `Spring`, фабрика `Spring.bounce`, пресеты `smooth`, `snappy`, `bouncy`,
аналитическое решение `solve` и оценка `settleTime`. Кривые и эффекты описаны ниже; таймлайн и планировщик
появятся на своих шагах. Пакет пока не опубликован.

```dart
import 'package:motion_core/motion_core.dart';

void main() {
  final spring = Spring.bounce(duration: 0.5, bounce: 0.15);
  final (x, v) = spring.solve(from: 0, to: 100, velocity: 0, t: 0.25);
  print('Position: $x; velocity: $v');
}
```

`solve` не зависит от частоты кадров. Для продолжения движения передайте
текущие положение и скорость как `from` и `velocity`. При `bounce: 0` движение
из покоя не перелетает цель. Длительность в `Spring.bounce` приблизительная.
При нулевом damping колебания не затухают и `settleTime` бесконечен.

`const Spring(...)` сохраняет параметры; `solve` и `settleTime` проверяют их
при использовании, включая release. Положительными и конечными должны быть
stiffness и mass, damping — конечным и неотрицательным. Фабрика проверяет duration
и bounce сразу; конечный bounce ограничивается диапазоном 0..0.95.
Все входы `solve` должны быть конечными. Экстремальные состояния и обратное
время могут вызвать переполнение double; используйте представимые физические масштабы.

## Шаг 3: кривые и эффекты

Кривые `Ease.linear`, `outCubic`, `inOutCubic`, `outBack`, `spring` и
`dampedSine` работают без Flutter. Пружинную функцию следует получить при
подготовке анимации и переиспользовать при вычислении кадров:

```dart
final EaseFn curve = Ease.spring(bounce: 0.3);
final state = EffectState();
const fade = Fade();
const move = Move(fromY: 16);

void evaluate(double progress) {
  state.reset();
  final t = curve(progress);
  fade.apply(state, t);
  move.apply(state, t);
}
```

`Ease.spring` возвращает точно 0.0 в начале и 1.0 в конце; промежуточный
прогресс вычисляется по аналитической пружине без временного record.

Шесть эффектов: Fade меняет прозрачность, Move — смещение, Scale — масштаб,
Rotate — поворот в радианах, Shake — горизонтальную тряску, Pulse — пульсацию.
Они реализуют `Effect`: `affectsOpacity` сообщает о прозрачности, `apply`
накапливает результат в существующий `EffectState`. Смещения и повороты
складываются, масштаб и прозрачность умножаются. Перед новым кадром вызывается
reset. Эффекты не ограничивают overshoot кривой и не хранят историю вычислений.

Из корня монорепозитория:

```sh
dart run melos run test:core --no-select
```

Команда запускает все тесты ядра, формирует LCOV и отклоняет покрытие ниже 90%.
Проверка аргументов отдельно запускается с выключенными assertions.

Настройка — в [README монорепозитория](../../README.md),
правила — в [CONTRIBUTING.md](CONTRIBUTING.md),
требования — в [спецификации](../../flutter_motion_guide_v2.md).
Dartdoc — английский, документация проекта — русская. Лицензия — MIT.
