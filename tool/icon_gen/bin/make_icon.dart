import 'dart:io';
import 'dart:math';

import 'package:image/image.dart' as img;

// Hatch icon: a 3x3 egg tray on warm cream — nine wells, the centre egg
// cracked open with a critter peeking out (dot eyes + antennae), a small x
// on the tray lip keeping the multiplication identity. All geometry is
// rounded rects, ellipses and polygons so the icon matches the in-app
// CustomPaint art direction.

// Palette (matches lib/shared/theme/app_colors.dart).
final cream = img.ColorRgb8(0xFF, 0xF6, 0xE9);
final ink = img.ColorRgb8(0x3A, 0x2B, 0x25);
final yolk = img.ColorRgb8(0xF2, 0xA9, 0x3B);
final yolkDark = img.ColorRgb8(0xC9, 0x86, 0x2A);
final shell = img.ColorRgb8(0xFD, 0xF1, 0xDC);
final speckle = img.ColorRgb8(0xD9, 0xC4, 0xA5);
final coral = img.ColorRgb8(0xFF, 0x6F, 0x61);

List<img.Point> eggOutline(double cx, double cy, double w, double h,
    {int steps = 64}) {
  // An egg: an ellipse pinched toward the top (image y grows downward).
  return [
    for (var i = 0; i < steps; i++)
      () {
        final t = 2 * pi * i / steps;
        final sy = sin(t);
        return img.Point(
          cx + (w / 2) * cos(t) * (1 - 0.14 * -sy),
          cy + (h / 2) * sy,
        );
      }(),
  ];
}

void thickLine(img.Image im, double x0, double y0, double x1, double y1,
    img.Color c, double thick) {
  // Squared-off stroke as a filled polygon (drawLine AA is too thin at size).
  final dx = x1 - x0, dy = y1 - y0;
  final len = sqrt(dx * dx + dy * dy);
  final nx = -dy / len * thick / 2, ny = dx / len * thick / 2;
  img.fillPolygon(im, vertices: [
    img.Point(x0 + nx, y0 + ny),
    img.Point(x1 + nx, y1 + ny),
    img.Point(x1 - nx, y1 - ny),
    img.Point(x0 - nx, y0 - ny),
  ], color: c);
}

void drawTray(img.Image im, double cx, double cy, double trayW) {
  final t = trayW;
  final x0 = cx - t / 2, y0 = cy - t / 2;

  // Tray body, rounded; a deeper lip strip at the bottom for the x mark.
  img.fillRect(im,
      x1: x0.round(),
      y1: y0.round(),
      x2: (x0 + t).round(),
      y2: (y0 + t).round(),
      color: yolk,
      radius: t * 0.10);

  // 3x3 wells + eggs. Grid area leaves the bottom lip clear.
  final gridX = x0 + t * 0.045;
  final gridY = y0 + t * 0.045;
  final gridW = t * 0.91;
  final gridH = t * 0.80;
  final cellW = gridW / 3;
  final cellH = gridH / 3;

  for (var r = 0; r < 3; r++) {
    for (var c = 0; c < 3; c++) {
      final ccx = gridX + (c + 0.5) * cellW;
      final ccy = gridY + (r + 0.5) * cellH;
      final isCenter = r == 1 && c == 1;

      // Well: a darkened dish behind every egg.
      img.fillCircle(im,
          x: ccx.round(),
          y: (ccy + cellH * 0.10).round(),
          radius: (cellW * 0.40).round(),
          color: yolkDark);

      if (isCenter) {
        _drawHatchling(im, ccx, ccy, cellW, cellH);
      } else {
        img.fillPolygon(im,
            vertices: eggOutline(ccx, ccy, cellW * 0.68, cellH * 0.86),
            color: shell);
        // Two speckles keep the shells from reading as blank dots.
        img.fillCircle(im,
            x: (ccx - cellW * 0.10).round(),
            y: (ccy + cellH * 0.05).round(),
            radius: (cellW * 0.045).round(),
            color: speckle);
        img.fillCircle(im,
            x: (ccx + cellW * 0.12).round(),
            y: (ccy + cellH * 0.18).round(),
            radius: (cellW * 0.035).round(),
            color: speckle);
      }
    }
  }

  // The x on the tray lip, centred under the grid.
  final mx = cx;
  final my = y0 + t * 0.925;
  final arm = t * 0.030;
  final thick = t * 0.016;
  thickLine(im, mx - arm, my - arm, mx + arm, my + arm, ink, thick);
  thickLine(im, mx - arm, my + arm, mx + arm, my - arm, ink, thick);
}

void _drawHatchling(img.Image im, double ccx, double ccy, double cellW,
    double cellH) {
  final domeR = cellW * 0.32;
  final domeCy = ccy - cellH * 0.06;

  // Antennae first so the dome overlaps their roots.
  for (final dir in [-1, 1]) {
    final rx = ccx + dir * domeR * 0.40;
    final ry = domeCy - domeR * 0.80;
    final tx = ccx + dir * domeR * 0.62;
    final ty = domeCy - domeR * 1.38;
    thickLine(im, rx, ry, tx, ty, ink, cellW * 0.035);
    img.fillCircle(im,
        x: tx.round(),
        y: ty.round(),
        radius: (cellW * 0.050).round(),
        color: ink);
  }

  // Body dome + big dot eyes (the eyes carry the charm — keep them large).
  img.fillCircle(im,
      x: ccx.round(), y: domeCy.round(), radius: domeR.round(), color: coral);
  for (final dir in [-1, 1]) {
    img.fillCircle(im,
        x: (ccx + dir * domeR * 0.48).round(),
        y: (domeCy - domeR * 0.12).round(),
        radius: (cellW * 0.070).round(),
        color: ink);
  }

  // Cracked lower shell in front: a solid bowl below the rim, then upward
  // teeth riding the rim line.
  final sw = cellW * 0.68, sh = cellH * 0.86;
  final rimY = ccy + cellH * 0.06;
  final left = ccx - sw / 2, right = ccx + sw / 2;
  // eggOutline walks t=0..2pi from the right edge through the bottom to the
  // left, so the below-rim points already arrive in fill order.
  final belly =
      eggOutline(ccx, ccy, sw, sh).where((p) => p.y > rimY).toList();
  img.fillPolygon(im,
      vertices: [img.Point(left, rimY), img.Point(right, rimY), ...belly],
      color: shell);
  final tooth = sw / 6;
  for (var i = 0; i < 6; i++) {
    final x = left + tooth * i;
    img.fillPolygon(im, vertices: [
      img.Point(x, rimY + 1),
      img.Point(x + tooth / 2, rimY - cellH * 0.06),
      img.Point(x + tooth, rimY + 1),
    ], color: shell);
  }
}

img.Image squareIcon(int size, {bool transparentBg = false, double blockScale = 0.86}) {
  // Render large, then resize: package:image has no anti-aliasing, so small
  // sizes are produced by cubic downscale of the 1024px master.
  const master = 1024;
  final im = img.Image(width: master, height: master, numChannels: 4);
  if (transparentBg) {
    img.fill(im, color: img.ColorRgba8(0, 0, 0, 0));
  } else {
    img.fill(im, color: cream);
  }
  drawTray(im, master / 2, master / 2, master * blockScale);
  if (size == master) return im;
  return img.copyResize(im,
      width: size, height: size, interpolation: img.Interpolation.cubic);
}

void save(img.Image im, String path) {
  File(path).writeAsBytesSync(img.encodePng(im));
  stdout.writeln('wrote $path (${im.width}x${im.height})');
}

void main() {
  final root = '${Directory.current.path}/../..';
  save(squareIcon(1024), '$root/assets/icon/app_icon.png');
  // Adaptive foreground: tray confined to the 66% safe zone, transparent ground.
  save(squareIcon(1024, transparentBg: true, blockScale: 0.56),
      '$root/assets/icon/app_icon_foreground.png');
  save(squareIcon(192), '$root/web/icons/Icon-192.png');
  save(squareIcon(512), '$root/web/icons/Icon-512.png');
  // Maskable: extra padding so any mask shape keeps the tray whole.
  save(squareIcon(192, blockScale: 0.64), '$root/web/icons/Icon-maskable-192.png');
  save(squareIcon(512, blockScale: 0.64), '$root/web/icons/Icon-maskable-512.png');
  save(squareIcon(48), '$root/web/favicon.png');
}
