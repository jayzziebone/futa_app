import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/theme.dart';

class CreditScoreGauge extends StatelessWidget {
  final int score;
  final int? previousScore;
  final int minScore;
  final int maxScore;

  const CreditScoreGauge({
    super.key,
    required this.score,
    this.previousScore,
    this.minScore = 300,
    this.maxScore = 900,
  });

  String get _ratingLabel {
    if (score >= 800) return 'Excellent';
    if (score >= 700) return 'Très Bon';
    if (score >= 600) return 'Bon';
    return 'Moyen';
  }

  Color get _ratingColor {
    if (score >= 800) return const Color(0xFF16A34A);
    if (score >= 700) return const Color(0xFF22C55E);
    if (score >= 600)
      return const Color(0xFFFD992A); // Gold/Orange matching logo accent
    return const Color(0xFFF65C50); // Coral/Red matching logo accent
  }

  String get _ratingDescription {
    if (score >= 800) {
      return 'Votre santé financière est robuste. Vous bénéficiez d\'un accès prioritaire aux nouveaux plans de financement.';
    }
    if (score >= 700) {
      return 'Votre dossier est solide. Vos demandes de paiement fractionné sont acceptées automatiquement.';
    }
    if (score >= 600) {
      return 'Bon score général. Continuez à payer vos tranches à temps pour atteindre le niveau Excellent.';
    }
    return 'Score intermédiaire. Réglez vos retards éventuels pour améliorer votre capacité d\'emprunt.';
  }

  @override
  Widget build(BuildContext context) {
    final double ratio = (score - minScore) / (maxScore - minScore);
    final Color activeColor = _ratingColor;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'SCORE FUTA',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            IconButton(
              tooltip: 'Comprendre le score FUTA',
              onPressed: () => _showScoreInfo(context, score),
              icon: Icon(
                Icons.help_outline,
                color: Colors.grey.shade400,
                size: 24,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Center(
          child: SizedBox(
            width: 240,
            height: 140,
            child: CustomPaint(
              painter: _GaugePainter(
                ratio: ratio.clamp(0.0, 1.0),
                activeColor: activeColor,
              ),
              child: Container(
                padding: const EdgeInsets.only(top: 40),
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (previousScore != null && score != previousScore) ...[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            score > previousScore! ? Icons.arrow_upward : Icons.arrow_downward,
                            color: score > previousScore! ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${(score - previousScore!).abs()}',
                            style: TextStyle(
                              color: score > previousScore! ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                    Text(
                      '$score',
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                        color: FutaTheme.blueDark,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text(
                              'Description du Score',
                              style: TextStyle(
                                color: FutaTheme.blueDark,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            content: Text(
                              _ratingDescription,
                              style: const TextStyle(
                                fontSize: 14,
                                height: 1.4,
                                color: FutaTheme.textDark,
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text(
                                  'Fermer',
                                  style: TextStyle(color: FutaTheme.emeraldGreen),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _ratingLabel,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: activeColor,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.info_outline,
                            size: 12,
                            color: Colors.grey.shade400,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Padding(
        //   padding: const EdgeInsets.symmetric(horizontal: 24.0),
        //   child: Text(
        //     _ratingDescription,
        //     textAlign: TextAlign.center,
        //     style: const TextStyle(
        //       fontSize: 13,
        //       color: FutaTheme.textLight,
        //       height: 1.4,
        //     ),
        //   ),
        // ),
      ],
    );
  }

  void _showScoreInfo(BuildContext context, int score) {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Fermer',
      barrierColor: Colors.black.withValues(alpha: 0.28),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) {
        return const SizedBox.shrink();
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );

        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
            child: Center(
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: MediaQuery.of(context).size.width.clamp(0, 420) - 32,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.14),
                        blurRadius: 28,
                        offset: const Offset(0, 16),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Score FUTA',
                              style: TextStyle(
                                color: Color(0xFF1E293B),
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Votre score actuel est $score. Il évolue selon votre historique de paiements, vos contrats actifs et les retards.',
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const _ScoreLevelRow(
                        label: 'Moyen',
                        range: '300 - 599',
                        color: Colors.orange,
                      ),
                      const _ScoreLevelRow(
                        label: 'Bon',
                        range: '600 - 699',
                        color: Color(0xFF84CC16),
                      ),
                      const _ScoreLevelRow(
                        label: 'Très bon',
                        range: '700 - 799',
                        color: Color(0xFF22C55E),
                      ),
                      const _ScoreLevelRow(
                        label: 'Excellent',
                        range: '800 - 900',
                        color: Color(0xFF16A34A),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Text(
                          'Les paiements à temps augmentent le score. Les retards, les montants impayés et les contrats en défaut le diminuent.',
                          style: TextStyle(
                            color: Color(0xFF475569),
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ScoreLevelRow extends StatelessWidget {
  const _ScoreLevelRow({
    required this.label,
    required this.range,
    required this.color,
  });

  final String label;
  final String range;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF1E293B),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            range,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double ratio;
  final Color activeColor;

  _GaugePainter({required this.ratio, required this.activeColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = size.width / 2;

    final basePaint = Paint()
      ..color = Colors.grey.shade100
      ..strokeWidth = 20
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Background arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      pi,
      pi,
      false,
      basePaint,
    );

    // Active arc (multi-color gradient matching logo theme)
    final activePaint = Paint()
      ..shader = SweepGradient(
        colors: const [
          Color(0xFFF65C50), // Coral/Red
          Color(0xFFFD992A), // Gold/Orange
          Color(0xFF22C55E), // Light Green
          Color(0xFF16A34A), // Rich Green
        ],
        stops: const [0.0, 0.3, 0.6, 1.0],
        startAngle: pi,
        endAngle: 2 * pi,
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..strokeWidth = 20
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      pi,
      pi * ratio,
      false,
      activePaint,
    );

    // Needle indicator
    final needleAngle = pi + (pi * ratio);

    final needleLength = radius - 10;
    final needleX = center.dx + cos(needleAngle) * needleLength;
    final needleY = center.dy + sin(needleAngle) * needleLength;

    // Small circle indicator on the arc
    canvas.drawCircle(
      Offset(needleX, needleY),
      12,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      Offset(needleX, needleY),
      12,
      Paint()
        ..color = activeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    canvas.drawCircle(
      Offset(needleX, needleY),
      6,
      Paint()
        ..color = activeColor
        ..style = PaintingStyle.fill,
    );

    // Small dark brand triangle pointing to the arc
    final trianglePaint = Paint()
      ..color = FutaTheme.blueDark
      ..style = PaintingStyle.fill;
    final trianglePath = Path();
    final triangleAngle = pi + (pi * ratio);

    // Position the triangle slightly inside the arc
    final double innerRadius = radius - 15;
    final double tx = center.dx + cos(triangleAngle) * innerRadius;
    final double ty = center.dy + sin(triangleAngle) * innerRadius;

    // Create a small triangle shape
    final double triangleSize = 8.0;
    trianglePath.moveTo(tx, ty);
    trianglePath.lineTo(
      center.dx + cos(triangleAngle - 0.1) * (innerRadius - triangleSize),
      center.dy + sin(triangleAngle - 0.1) * (innerRadius - triangleSize),
    );
    trianglePath.lineTo(
      center.dx + cos(triangleAngle + 0.1) * (innerRadius - triangleSize),
      center.dy + sin(triangleAngle + 0.1) * (innerRadius - triangleSize),
    );
    trianglePath.close();
    canvas.drawPath(trianglePath, trianglePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
