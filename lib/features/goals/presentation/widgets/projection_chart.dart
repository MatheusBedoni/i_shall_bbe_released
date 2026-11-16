import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/utils/money.dart';
import 'goal_texts.dart';

/// Linha do saldo projetado mês a mês contra a linha da meta.
///
/// Uma única série (não precisa de legenda); a meta é uma referência
/// tracejada e o prazo, quando existe, um marcador vertical. Tocar ou
/// arrastar sobre o gráfico mostra o valor do mês.
class ProjectionChart extends StatefulWidget {
  const ProjectionChart({
    super.key,
    required this.timeline,
    required this.target,
    this.deadlineMonth,
    this.height = 200,
  });

  /// Saldo por mês; índice 0 = hoje.
  final List<double> timeline;
  final double target;

  /// Índice do mês do prazo na [timeline], se houver.
  final int? deadlineMonth;
  final double height;

  @override
  State<ProjectionChart> createState() => _ProjectionChartState();
}

class _ProjectionChartState extends State<ProjectionChart> {
  int? _hover;

  void _update(double dx, double width) {
    final n = widget.timeline.length;
    if (n < 2) return;
    final plotLeft = _ProjectionPainter.left;
    final plotWidth = width - plotLeft - _ProjectionPainter.right;
    final t = ((dx - plotLeft) / plotWidth).clamp(0.0, 1.0);
    final i = (t * (n - 1)).round();
    if (i != _hover) setState(() => _hover = i);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    if (widget.timeline.length < 2) {
      return SizedBox(
        height: widget.height,
        child: Center(
          child: Text('Sem projeção para exibir.', style: textTheme.bodySmall),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => _update(d.localPosition.dx, width),
          onPanStart: (d) => _update(d.localPosition.dx, width),
          onPanUpdate: (d) => _update(d.localPosition.dx, width),
          onPanEnd: (_) => setState(() => _hover = null),
          child: CustomPaint(
            size: Size(width, widget.height),
            painter: _ProjectionPainter(
              timeline: widget.timeline,
              target: widget.target,
              deadlineMonth: widget.deadlineMonth,
              hover: _hover,
              line: scheme.primary,
              targetLine: scheme.secondary,
              grid: scheme.outlineVariant.withValues(alpha: 0.5),
              marker: scheme.outline,
              surface: scheme.surfaceContainerLow,
              tooltipSurface: scheme.inverseSurface,
              tooltipText: scheme.onInverseSurface,
              label: scheme.onSurfaceVariant,
              labelStyle: textTheme.labelSmall ?? const TextStyle(fontSize: 10),
            ),
          ),
        );
      },
    );
  }
}

class _ProjectionPainter extends CustomPainter {
  _ProjectionPainter({
    required this.timeline,
    required this.target,
    required this.deadlineMonth,
    required this.hover,
    required this.line,
    required this.targetLine,
    required this.grid,
    required this.marker,
    required this.surface,
    required this.tooltipSurface,
    required this.tooltipText,
    required this.label,
    required this.labelStyle,
  });

  static const left = 60.0;
  static const right = 12.0;
  static const top = 16.0;
  static const bottom = 22.0;

  final List<double> timeline;
  final double target;
  final int? deadlineMonth;
  final int? hover;
  final Color line;
  final Color targetLine;
  final Color grid;
  final Color marker;
  final Color surface;
  final Color tooltipSurface;
  final Color tooltipText;
  final Color label;
  final TextStyle labelStyle;

  @override
  void paint(Canvas canvas, Size size) {
    final n = timeline.length;
    final plotW = size.width - left - right;
    final plotH = size.height - top - bottom;
    final maxValue = timeline.fold(0.0, math.max);
    final yMax = math.max(math.max(maxValue, target), 1) * 1.08;

    double x(int i) => left + plotW * i / (n - 1);
    double y(double v) => top + plotH - plotH * (v / yMax);

    // Grade e eixo Y (recessivos).
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var k = 0; k <= 3; k++) {
      final v = yMax * k / 3;
      final yy = y(v);
      canvas.drawLine(Offset(left, yy), Offset(left + plotW, yy), gridPaint);
      _text(canvas, Money.compact(v), Offset(left - 6, yy), align: _Align.right);
    }

    // Eixo X: hoje, meio (se longo) e fim.
    final baseline = top + plotH;
    _text(canvas, 'hoje', Offset(left, baseline + 4), align: _Align.leftTop);
    if (n > 24) {
      final mid = (n - 1) ~/ 2;
      _text(canvas, GoalTexts.months(mid), Offset(x(mid), baseline + 4),
          align: _Align.centerTop);
    }
    _text(canvas, GoalTexts.months(n - 1), Offset(left + plotW, baseline + 4),
        align: _Align.rightTop);

    // Linha da meta.
    final ty = y(target);
    _dashed(canvas, Offset(left, ty), Offset(left + plotW, ty),
        Paint()..color = targetLine..strokeWidth = 1.5);
    _text(canvas, 'Meta', Offset(left + plotW, ty - 3), align: _Align.rightBottom);

    // Prazo.
    final d = deadlineMonth;
    if (d != null && d > 0 && d < n) {
      final dx = x(d);
      _dashed(canvas, Offset(dx, top), Offset(dx, baseline),
          Paint()..color = marker..strokeWidth = 1);
      _text(canvas, 'Prazo', Offset(dx, top), align: _Align.centerBottom);
    }

    // Área + linha da série.
    final path = Path()..moveTo(x(0), y(timeline[0]));
    for (var i = 1; i < n; i++) {
      path.lineTo(x(i), y(timeline[i]));
    }
    final area = Path.from(path)
      ..lineTo(x(n - 1), baseline)
      ..lineTo(x(0), baseline)
      ..close();
    canvas.drawPath(area, Paint()..color = line.withValues(alpha: 0.10));
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );

    // Hover: cruz, marcador com anel de superfície e tooltip.
    final h = hover;
    if (h != null && h >= 0 && h < n) {
      final hx = x(h);
      final hy = y(timeline[h]);
      canvas.drawLine(Offset(hx, top), Offset(hx, baseline),
          Paint()..color = marker..strokeWidth = 1);
      canvas.drawCircle(Offset(hx, hy), 6, Paint()..color = surface);
      canvas.drawCircle(Offset(hx, hy), 4, Paint()..color = line);

      final text = '${h == 0 ? 'Hoje' : GoalTexts.months(h)} · ${Money.format(timeline[h])}';
      final tp = TextPainter(
        text: TextSpan(text: text, style: labelStyle.copyWith(color: tooltipText)),
        textDirection: TextDirection.ltr,
      )..layout();
      const pad = 6.0;
      final boxW = tp.width + pad * 2;
      final boxH = tp.height + pad * 2;
      var bx = hx - boxW / 2;
      bx = bx.clamp(left, math.max(left, size.width - right - boxW));
      final by = math.max(0.0, hy - boxH - 10);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(bx, by, boxW, boxH),
        const Radius.circular(6),
      );
      canvas.drawRRect(rect, Paint()..color = tooltipSurface);
      tp.paint(canvas, Offset(bx + pad, by + pad));
    }
  }

  void _dashed(Canvas canvas, Offset a, Offset b, Paint paint) {
    const dash = 5.0;
    const gap = 4.0;
    final total = (b - a).distance;
    final dir = (b - a) / total;
    var covered = 0.0;
    while (covered < total) {
      final end = math.min(covered + dash, total);
      canvas.drawLine(a + dir * covered, a + dir * end, paint);
      covered = end + gap;
    }
  }

  void _text(Canvas canvas, String text, Offset anchor, {required _Align align}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: labelStyle.copyWith(color: label)),
      textDirection: TextDirection.ltr,
    )..layout();
    final offset = switch (align) {
      _Align.right => Offset(anchor.dx - tp.width, anchor.dy - tp.height / 2),
      _Align.leftTop => anchor,
      _Align.centerTop => Offset(anchor.dx - tp.width / 2, anchor.dy),
      _Align.rightTop => Offset(anchor.dx - tp.width, anchor.dy),
      _Align.rightBottom => Offset(anchor.dx - tp.width, anchor.dy - tp.height),
      _Align.centerBottom => Offset(anchor.dx - tp.width / 2, anchor.dy - tp.height),
    };
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(_ProjectionPainter old) =>
      old.timeline != timeline ||
      old.target != target ||
      old.deadlineMonth != deadlineMonth ||
      old.hover != hover ||
      old.line != line ||
      old.surface != surface;
}

enum _Align { right, leftTop, centerTop, rightTop, rightBottom, centerBottom }
