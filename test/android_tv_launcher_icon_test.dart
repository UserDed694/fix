import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

String _androidAttribute(String source, String element, String attribute) {
  final elementTag = RegExp('<$element\\b[^>]*>').firstMatch(source)!.group(0)!;
  return RegExp(
    'android:$attribute="([^"]+)"',
  ).firstMatch(elementTag)!.group(1)!;
}

Future<ui.Image> _decode(File file) async {
  final codec = await ui.instantiateImageCodec(await file.readAsBytes());
  final frame = await codec.getNextFrame();
  codec.dispose();
  return frame.image;
}

/// Прямоугольник непрозрачных пикселей — то, что реально видно на иконке.
Future<ui.Rect> _opaqueBounds(ui.Image image) async {
  final bytes = (await image.toByteData(
    format: ui.ImageByteFormat.rawStraightRgba,
  ))!;
  var left = image.width;
  var top = image.height;
  var right = -1;
  var bottom = -1;
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      final alpha = bytes.getUint8((y * image.width + x) * 4 + 3);
      if (alpha < 128) {
        continue;
      }
      if (x < left) left = x;
      if (x > right) right = x;
      if (y < top) top = y;
      if (y > bottom) bottom = y;
    }
  }
  return ui.Rect.fromLTRB(
    left.toDouble(),
    top.toDouble(),
    right + 1.0,
    bottom + 1.0,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Иконки fix — растровые PNG (у FlClash были WebP и векторный логотип).
  test('TV launcher icons meet density-specific minimum sizes', () async {
    const expectedSizes = {
      'mdpi': 80,
      'hdpi': 120,
      'xhdpi': 160,
      'xxhdpi': 240,
      'xxxhdpi': 320,
    };

    for (final MapEntry(key: density, value: size) in expectedSizes.entries) {
      final file = File(
        'android/app/src/main/res/'
        'mipmap-television-$density/ic_launcher.png',
      );
      expect(file.existsSync(), isTrue, reason: 'missing ${file.path}');

      final image = await _decode(file);
      expect((image.width, image.height), (size, size), reason: file.path);
      image.dispose();
    }
  });

  test('TV adaptive launcher icon stays centered in the safe zone', () async {
    final adaptiveIcon = File(
      'android/app/src/main/res/'
      'mipmap-television-anydpi-v26/ic_launcher.xml',
    ).readAsStringSync();
    expect(
      _androidAttribute(adaptiveIcon, 'foreground', 'drawable'),
      '@drawable/ic_launcher_foreground',
    );
    expect(
      _androidAttribute(adaptiveIcon, 'background', 'drawable'),
      '@color/ic_launcher_background',
    );

    // mdpi: 1 px = 1 dp, поэтому границы сравниваются прямо с зоной 72 dp
    // внутри холста адаптивной иконки 108 dp.
    final foreground = await _decode(
      File('android/app/src/main/res/drawable-mdpi/ic_launcher_foreground.png'),
    );
    expect((foreground.width, foreground.height), (108, 108));
    final glyphBounds = await _opaqueBounds(foreground);
    foreground.dispose();
    const safeZone = ui.Rect.fromLTWH(18, 18, 72, 72);

    expect(glyphBounds.left, greaterThanOrEqualTo(safeZone.left));
    expect(glyphBounds.top, greaterThanOrEqualTo(safeZone.top));
    expect(glyphBounds.right, lessThanOrEqualTo(safeZone.right));
    expect(glyphBounds.bottom, lessThanOrEqualTo(safeZone.bottom));
    expect(glyphBounds.center.dx, closeTo(safeZone.center.dx, 1.5));
    expect(glyphBounds.center.dy, closeTo(safeZone.center.dy, 1.5));
  });
}
