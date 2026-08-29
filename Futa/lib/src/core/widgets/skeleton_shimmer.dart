import 'package:flutter/material.dart';
import '../theme.dart';

/// High-performance, 60fps shimmer effect for modern loading states
class FutaShimmer extends StatefulWidget {
  final Widget child;
  final Color baseColor;
  final Color highlightColor;

  const FutaShimmer({
    super.key,
    required this.child,
    this.baseColor = const Color(0xFFE2E8F0), // Slate 200
    this.highlightColor = const Color(0xFFF8FAFC), // Slate 50
  });

  @override
  State<FutaShimmer> createState() => _FutaShimmerState();
}

class _FutaShimmerState extends State<FutaShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                widget.baseColor,
                widget.highlightColor,
                widget.baseColor,
              ],
              stops: [
                _controller.value - 0.3,
                _controller.value,
                _controller.value + 0.3,
              ],
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// A versatile skeleton placeholder box with rounded corners
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double? height;
  final double borderRadius;
  final Color color;

  const SkeletonBox({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = 8,
    this.color = const Color(0xFFE2E8F0),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// Dashboard Stats Grid Skeleton
class SkeletonDashboardMetrics extends StatelessWidget {
  final int count;
  final bool isWeb;

  const SkeletonDashboardMetrics({
    super.key,
    this.count = 4,
    this.isWeb = false,
  });

  @override
  Widget build(BuildContext context) {
    return FutaShimmer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (isWeb || constraints.maxWidth > 700) {
            return Row(
              children: List.generate(
                count,
                (index) => Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: index < count - 1 ? 16.0 : 0,
                    ),
                    child: _buildCard(),
                  ),
                ),
              ),
            );
          } else {
            return Column(
              children: List.generate(
                count,
                (index) => Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: _buildCard(),
                ),
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SkeletonBox(width: 80, height: 14),
              SkeletonBox(width: 32, height: 32, borderRadius: 16),
            ],
          ),
          const SizedBox(height: 12),
          const SkeletonBox(width: 120, height: 24),
          const SizedBox(height: 8),
          const SkeletonBox(width: 60, height: 12),
        ],
      ),
    );
  }
}

/// Table Rows Skeleton for School Roster
class SkeletonTableRows extends StatelessWidget {
  final int rowCount;

  const SkeletonTableRows({
    super.key,
    this.rowCount = 5,
  });

  @override
  Widget build(BuildContext context) {
    return FutaShimmer(
      child: Column(
        children: List.generate(
          rowCount,
          (index) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFF1F5F9)),
            ),
            child: Row(
              children: [
                const SkeletonBox(width: 36, height: 36, borderRadius: 18),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      SkeletonBox(width: 140, height: 14),
                      SizedBox(height: 6),
                      SkeletonBox(width: 80, height: 10),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  flex: 2,
                  child: SkeletonBox(width: 100, height: 14),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  flex: 1,
                  child: SkeletonBox(width: 60, height: 24, borderRadius: 12),
                ),
                const SizedBox(width: 16),
                const SkeletonBox(width: 70, height: 14),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Installment List Skeleton for Parent Dashboard
class SkeletonInstallmentList extends StatelessWidget {
  final int count;

  const SkeletonInstallmentList({
    super.key,
    this.count = 3,
  });

  @override
  Widget build(BuildContext context) {
    return FutaShimmer(
      child: Column(
        children: List.generate(
          count,
          (index) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF1F5F9)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    SkeletonBox(width: 100, height: 16),
                    SkeletonBox(width: 70, height: 22, borderRadius: 11),
                  ],
                ),
                const SizedBox(height: 12),
                const SkeletonBox(width: double.infinity, height: 8, borderRadius: 4),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    SkeletonBox(width: 90, height: 14),
                    SkeletonBox(width: 80, height: 32, borderRadius: 8),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Student Detail Screen Skeleton
class SkeletonStudentDetail extends StatelessWidget {
  const SkeletonStudentDetail({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FutaTheme.backgroundLight,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 600),
              child: FutaShimmer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. HERO HEADER CARD SKELETON
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: const [
                              SkeletonBox(width: 40, height: 40, borderRadius: 12),
                              SkeletonBox(width: 90, height: 26, borderRadius: 13),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const SkeletonBox(width: 76, height: 76, borderRadius: 38),
                          const SizedBox(height: 14),
                          const SkeletonBox(width: 180, height: 22),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              SkeletonBox(width: 70, height: 20, borderRadius: 6),
                              SizedBox(width: 8),
                              SkeletonBox(width: 90, height: 20, borderRadius: 6),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const SkeletonBox(width: double.infinity, height: 48, borderRadius: 14),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 2. FINANCIAL STATS CARD SKELETON
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: const [
                              SkeletonBox(width: 120, height: 16),
                              SkeletonBox(width: 80, height: 24, borderRadius: 8),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: const [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SkeletonBox(width: 60, height: 12),
                                    SizedBox(height: 6),
                                    SkeletonBox(width: 100, height: 20),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SkeletonBox(width: 60, height: 12),
                                    SizedBox(height: 6),
                                    SkeletonBox(width: 100, height: 20),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const SkeletonBox(width: double.infinity, height: 10, borderRadius: 5),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 3. ECHEANCIER / INSTALLMENTS SKELETON
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SkeletonBox(width: 140, height: 18),
                          const SizedBox(height: 16),
                          ...List.generate(
                            3,
                            (index) => Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFF1F5F9)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: const [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      SkeletonBox(width: 100, height: 14),
                                      SizedBox(height: 6),
                                      SkeletonBox(width: 70, height: 11),
                                    ],
                                  ),
                                  SkeletonBox(width: 80, height: 28, borderRadius: 8),
                                ],
                              ),
                            ),
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
      ),
    );
  }
}

