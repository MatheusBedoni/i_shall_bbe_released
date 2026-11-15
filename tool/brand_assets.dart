// Gera os assets de marca a partir de asset/logo.jpg:
//   - imprime a paleta dominante (k-means) para alimentar o tema
//   - asset/icon.png (1024x1024): recorte quadrado para o ícone do app
//   - asset/icon_foreground.png (1024x1024): versão com margem para o
//     adaptive icon do Android (safe zone de 66%)
//
// Uso: dart run tool/brand_assets.dart
import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

void main() {
  final source = img.decodeImage(File('asset/logo.jpg').readAsBytesSync())!;
  stdout.writeln('Fonte: ${source.width}x${source.height}');

  _printPalette(source);
  _writeIcons(source);
}

void _printPalette(img.Image source) {
  final small = img.copyResize(source, width: 120);
  final pixels = <List<double>>[];
  for (final p in small) {
    pixels.add([p.r.toDouble(), p.g.toDouble(), p.b.toDouble()]);
  }

  const k = 8;
  final rng = math.Random(42);
  var centers = List.generate(k, (_) => pixels[rng.nextInt(pixels.length)]);
  late List<int> assignment;
  for (var iter = 0; iter < 30; iter++) {
    assignment = pixels.map((p) {
      var best = 0;
      var bestD = double.infinity;
      for (var c = 0; c < k; c++) {
        final d = _dist(p, centers[c]);
        if (d < bestD) {
          bestD = d;
          best = c;
        }
      }
      return best;
    }).toList();
    final sums = List.generate(k, (_) => [0.0, 0.0, 0.0]);
    final counts = List.filled(k, 0);
    for (var i = 0; i < pixels.length; i++) {
      final c = assignment[i];
      for (var j = 0; j < 3; j++) {
        sums[c][j] += pixels[i][j];
      }
      counts[c]++;
    }
    centers = List.generate(
      k,
      (c) => counts[c] == 0
          ? centers[c]
          : [sums[c][0] / counts[c], sums[c][1] / counts[c], sums[c][2] / counts[c]],
    );
  }

  final counts = List.filled(k, 0);
  for (final a in assignment) {
    counts[a]++;
  }
  final order = List.generate(k, (i) => i)
    ..sort((a, b) => counts[b].compareTo(counts[a]));
  stdout.writeln('Paleta dominante:');
  for (final i in order) {
    final c = centers[i];
    final hex = c.map((v) => v.round().clamp(0, 255).toRadixString(16).padLeft(2, '0')).join();
    final pct = (counts[i] * 100 / pixels.length).toStringAsFixed(1);
    stdout.writeln('  #$hex  $pct%');
  }
}

double _dist(List<double> a, List<double> b) {
  var s = 0.0;
  for (var i = 0; i < 3; i++) {
    s += (a[i] - b[i]) * (a[i] - b[i]);
  }
  return s;
}

void _writeIcons(img.Image source) {
  // Recorte quadrado alinhado ao topo (rosto + fumaça).
  final side = math.min(source.width, source.height);
  final crop = img.copyCrop(source, x: 0, y: 0, width: side, height: side);
  final icon = img.copyResize(crop, width: 1024, height: 1024, interpolation: img.Interpolation.cubic);
  File('asset/icon.png').writeAsBytesSync(img.encodePng(icon));

  // Foreground do adaptive icon: conteúdo dentro de ~70% do canvas.
  final fg = img.Image(width: 1024, height: 1024, numChannels: 4);
  img.fill(fg, color: img.ColorRgba8(0, 0, 0, 0));
  final inner = img.copyResize(crop, width: 720, height: 720, interpolation: img.Interpolation.cubic);
  // Máscara circular para não sobrar canto quadrado nas formas arredondadas.
  final masked = img.Image(width: 720, height: 720, numChannels: 4);
  for (var y = 0; y < 720; y++) {
    for (var x = 0; x < 720; x++) {
      final dx = x - 360 + 0.5;
      final dy = y - 360 + 0.5;
      final p = inner.getPixel(x, y);
      final a = dx * dx + dy * dy <= 360 * 360 ? 255 : 0;
      masked.setPixelRgba(x, y, p.r, p.g, p.b, a);
    }
  }
  img.compositeImage(fg, masked, dstX: 152, dstY: 152);
  File('asset/icon_foreground.png').writeAsBytesSync(img.encodePng(fg));
  stdout.writeln('Gerados asset/icon.png e asset/icon_foreground.png');
}
