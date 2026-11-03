# motion_core

Чистое Dart-ядро Flutter Motion без Flutter, `dart:ui` и сторонних runtime-зависимостей.

## Шаг 2: пружина

Доступны `Spring`, фабрика `Spring.bounce`, пресеты `smooth`, `snappy`, `bouncy`,
аналитическое решение `solve` и оценка `settleTime`. Остальные возможности ядра
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
