import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../core/theme.dart';

// ==================== REUSABLE WIDGET CHIPS ====================

Widget buildTypeChip(String type) {
  Color bg = FutaTheme.blueDark.withOpacity(0.08);
  Color text = FutaTheme.blueDark;

  if (type.contains('Maternelle')) {
    bg = const Color(0xFFFFFBEB);
    text = const Color(0xFFD97706);
  } else if (type.contains('Primaire')) {
    bg = const Color(0xFFEEF2FF);
    text = FutaTheme.blueIndigo;
  } else if (type.contains('Secondaire')) {
    bg = const Color(0xFFF0FDF4);
    text = const Color(0xFF0F766E);
  }

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      type,
      style: TextStyle(
        color: text,
        fontWeight: FontWeight.bold,
        fontSize: 10,
      ),
    ),
  );
}

Widget buildInstallmentChip(String title) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: const Color(0xFFF1F5F9),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      title,
      style: const TextStyle(
        color: Color(0xFF475569),
        fontWeight: FontWeight.w600,
        fontSize: 10,
      ),
    ),
  );
}

// ==================== CUSTOM CHART WIDGETS & PAINTERS ====================

class TotalEarningsBarChart extends StatelessWidget {
  const TotalEarningsBarChart({super.key});

  @override
  Widget build(BuildContext context) {
    final List<String> months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul'];
    final List<double> earnings = [26, 22, 19, 28, 12, 30, 26];
    final List<double> expenses = [18, 14, 12, 22, 15, 21, 29];
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(months.length, (index) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Earnings Bar
                Container(
                  width: 12,
                  height: earnings[index] * 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 6),
                // Expense Bar
                Container(
                  width: 12,
                  height: expenses[index] * 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D9488),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              months[index],
              style: const TextStyle(fontSize: 11, color: FutaTheme.textLight, fontWeight: FontWeight.bold),
            ),
          ],
        );
      }),
    );
  }
}

class RevenusTotauxBarChart extends StatefulWidget {
  final List<String> months;
  final List<double> revenues;
  const RevenusTotauxBarChart({super.key, required this.months, required this.revenues});

  @override
  State<RevenusTotauxBarChart> createState() => _RevenusTotauxBarChartState();
}

class _RevenusTotauxBarChartState extends State<RevenusTotauxBarChart> {
  int? _hoveredIndex;

  @override
  Widget build(BuildContext context) {
    final double maxVal = widget.revenues.isNotEmpty 
        ? widget.revenues.reduce((a, b) => a > b ? a : b) 
        : 0.0;
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(widget.months.length, (index) {
        final rev = widget.revenues[index];
        final bool isHovered = _hoveredIndex == index;
        // Proportional height up to 90px
        final double barHeight = maxVal > 0 ? (rev / maxVal) * 90 : 0.0;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            setState(() {
              if (_hoveredIndex == index) {
                _hoveredIndex = null;
              } else {
                _hoveredIndex = index;
              }
            });
          },
          child: MouseRegion(
            onEnter: (_) => setState(() => _hoveredIndex = index),
            onExit: (_) => setState(() => _hoveredIndex = null),
            cursor: SystemMouseCursors.click,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Hover label showing amount
                SizedBox(
                  height: 22,
                  child: AnimatedOpacity(
                    opacity: isHovered ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 150),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: FutaTheme.blueDark,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${NumberFormat.compact(locale: 'fr').format(rev)} FC',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Tooltip(
                  message: '${NumberFormat.decimalPattern('fr').format(rev)} FC',
                  preferBelow: false,
                  child: Container(
                    width: 18,
                    height: barHeight > 5 ? barHeight : 5,
                    decoration: BoxDecoration(
                      color: isHovered ? FutaTheme.emeraldGreen : FutaTheme.blueDark,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.months[index],
                  style: const TextStyle(fontSize: 10, color: FutaTheme.textLight, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

class AttendanceRingChart extends StatelessWidget {
  final double attendanceRate;
  const AttendanceRingChart({super.key, required this.attendanceRate});

  @override
  Widget build(BuildContext context) {
    final int displayRate = attendanceRate.round();
    return Column(
      children: [
        SizedBox(
          width: 130,
          height: 130,
          child: CustomPaint(
            painter: RingChartPainter(
              percentage: displayRate.toDouble(),
              color: const Color(0xFF0D9488),
              backgroundColor: const Color(0xFFE2E8F0),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$displayRate%',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const Text(
                    'Présence',
                    style: TextStyle(fontSize: 10, color: FutaTheme.textLight, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Column(
              children: [
                Text('$displayRate%', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                const Text('Élèves', style: TextStyle(fontSize: 11, color: FutaTheme.textLight)),
              ],
            ),
            Container(width: 1.5, height: 24, color: Colors.grey.shade200),
            Column(
              children: const [
                Text('95%', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                Text('Profs', style: TextStyle(fontSize: 11, color: FutaTheme.textLight)),
              ],
            ),
          ],
        )
      ],
    );
  }
}

class RingChartPainter extends CustomPainter {
  final double percentage;
  final Color color;
  final Color backgroundColor;

  RingChartPainter({
    required this.percentage,
    required this.color,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 10.0;

    final paintBg = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius - strokeWidth / 2, paintBg);

    final paintFill = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
      -3.14159 / 2,
      2 * 3.14159 * (percentage / 100),
      false,
      paintFill,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class StudentProgressLineChart extends StatelessWidget {
  const StudentProgressLineChart({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 160,
      width: double.infinity,
      child: CustomPaint(
        painter: LineChartPainter(
          values: [45, 79, 65, 85, 50, 80],
        ),
      ),
    );
  }
}

class LineChartPainter extends CustomPainter {
  final List<double> values;

  LineChartPainter({required this.values});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final width = size.width;
    final height = size.height;
    final stepX = width / (values.length - 1);
    final points = <Offset>[];

    for (int i = 0; i < values.length; i++) {
      final x = i * stepX;
      final y = height - (values[i] / 100.0 * height);
      points.add(Offset(x, y));
    }

    // Draw shaded area
    final fillPath = Path();
    fillPath.moveTo(0, height);
    fillPath.lineTo(points.first.dx, points.first.dy);
    for (int i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];
      final controlX = p1.dx + (p2.dx - p1.dx) / 2;
      fillPath.cubicTo(controlX, p1.dy, controlX, p2.dy, p2.dx, p2.dy);
    }
    fillPath.lineTo(width, height);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFFF65C50).withOpacity(0.18),
          const Color(0xFFF65C50).withOpacity(0.00),
        ],
      ).createShader(Rect.fromLTWH(0, 0, width, height));
    canvas.drawPath(fillPath, fillPaint);

    // Draw grid background line
    final gridPaint = Paint()
      ..color = Colors.grey.shade100
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    for (int i = 1; i <= 3; i++) {
      final y = height * (i / 4.0);
      canvas.drawLine(Offset(0, y), Offset(width, y), gridPaint);
    }

    // Draw smooth curved line
    final linePath = Path();
    linePath.moveTo(points.first.dx, points.first.dy);
    for (int i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];
      final controlX = p1.dx + (p2.dx - p1.dx) / 2;
      linePath.cubicTo(controlX, p1.dy, controlX, p2.dy, p2.dx, p2.dy);
    }

    final linePaint = Paint()
      ..color = const Color(0xFFF65C50) // matching brand coral/red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(linePath, linePaint);

    // Draw connection points and tooltips
    final pointPaint = Paint()
      ..color = const Color(0xFFF65C50)
      ..style = PaintingStyle.fill;
    final whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    
    for (int i = 0; i < points.length; i++) {
      canvas.drawCircle(points[i], 5, pointPaint);
      canvas.drawCircle(points[i], 3, whitePaint);
    }

    // Highlight Test 2 (Index 1: 79%) tooltip bubble
    if (points.length > 1) {
      final target = points[1];
      
      // Draw tooltip background
      final bubbleRect = Rect.fromCenter(center: Offset(target.dx, target.dy - 26), width: 38, height: 20);
      final rrect = RRect.fromRectAndRadius(bubbleRect, const Radius.circular(5));
      final bubblePaint = Paint()
        ..color = const Color(0xFFF65C50)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(rrect, bubblePaint);

      // Label Text
      const textStyle = TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold);
      final textSpan = TextSpan(text: '79%', style: textStyle);
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(target.dx - textPainter.width / 2, target.dy - 26 - textPainter.height / 2));

      // Pointer down line
      final pointerPaint = Paint()
        ..color = const Color(0xFFF65C50)
        ..strokeWidth = 1.5;
      canvas.drawLine(Offset(target.dx, target.dy - 16), Offset(target.dx, target.dy - 5), pointerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ==================== CLASSROOM PARSING UTILITIES ====================

class ParsedClassroom {
  final String level;      // 'Maternelle', 'Primaire', 'Secondaire', or 'Autres'
  final String grade;      // e.g. '1ere Maternelle', '6eme Primaire'
  final String section;    // e.g. 'A', 'B', 'C'
  
  ParsedClassroom({required this.level, required this.grade, required this.section});
}

ParsedClassroom parseClassroom(String classroomStr) {
  final cleanStr = classroomStr.trim();
  if (cleanStr.isEmpty) {
    return ParsedClassroom(level: 'Autres', grade: 'Non spécifié', section: 'A');
  }

  final parts = cleanStr.split(RegExp(r'\s+'));
  if (parts.isEmpty) {
    return ParsedClassroom(level: 'Autres', grade: 'Non spécifié', section: 'A');
  }
  
  if (parts.length == 1) {
    return ParsedClassroom(level: 'Autres', grade: cleanStr, section: 'A');
  }

  String section = 'A';
  String gradeAndLevelPart = cleanStr;
  final lastPart = parts.last;
  
  if (RegExp(r'^[A-Za-z]$').hasMatch(lastPart)) {
    section = lastPart.toUpperCase();
    gradeAndLevelPart = parts.sublist(0, parts.length - 1).join(' ').trim();
  }

  String level = 'Autres';
  final lowerPart = gradeAndLevelPart.toLowerCase();

  if (lowerPart.contains('maternelle') || lowerPart.contains('mat')) {
    level = 'Maternelle';
  } else if (lowerPart.contains('primaire') || lowerPart.contains('prim')) {
    level = 'Primaire';
  } else if (lowerPart.contains('secondaire') || lowerPart.contains('sec') || lowerPart.contains('human') || lowerPart.contains('hum')) {
    level = 'Secondaire';
  } else {
    // Guess based on number
    if (RegExp(r'\b(7|8)\b').hasMatch(lowerPart) || lowerPart.contains('7ème') || lowerPart.contains('8ème') || lowerPart.contains('7eme') || lowerPart.contains('8eme')) {
      level = 'Secondaire';
    } else if (RegExp(r'\b(1|2|3|4|5|6)\b').hasMatch(lowerPart) || lowerPart.contains('1ere') || lowerPart.contains('2eme') || lowerPart.contains('3eme') || lowerPart.contains('4eme') || lowerPart.contains('5eme') || lowerPart.contains('6eme') || lowerPart.contains('1ère') || lowerPart.contains('2ème') || lowerPart.contains('3ème') || lowerPart.contains('4ème') || lowerPart.contains('5ème') || lowerPart.contains('6ème')) {
      level = 'Primaire';
    } else {
      level = 'Autres';
    }
  }

  return ParsedClassroom(
    level: level,
    grade: gradeAndLevelPart,
    section: section,
  );
}
