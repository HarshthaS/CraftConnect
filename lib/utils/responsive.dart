import 'package:flutter/material.dart';

class Responsive {
  final BuildContext context;
  Responsive(this.context);

  double get width => MediaQuery.of(context).size.width;
  double get height => MediaQuery.of(context).size.height;

  bool get isSmallPhone => width < 360;
  bool get isPhone => width >= 360 && width < 450;
  bool get isMediumPhone => width >= 450 && width < 600;
  bool get isFoldable => width >= 600 && width < 900;
  bool get isTablet => width >= 900 && width < 1200;
  bool get isDesktop => width >= 1200;

  double ts(double size) {
    if (isSmallPhone) return size * 0.85;
    if (isPhone) return size * 0.95;
    if (isMediumPhone) return size * 1.05;
    if (isFoldable) return size * 1.15;
    if (isTablet) return size * 1.33;
    if (isDesktop) return size * 1.45;
    return size;
  }

  double sp(double size) {
    if (isSmallPhone) return size * 0.80;
    if (isPhone) return size * 0.90;
    if (isMediumPhone) return size * 1.00;
    if (isFoldable) return size * 1.15;
    if (isTablet) return size * 1.30;
    return size;
  }

  double icon(double size) {
    if (isSmallPhone) return size * 0.85;
    if (isPhone) return size * 0.95;
    if (isMediumPhone) return size * 1.05;
    if (isFoldable) return size * 1.15;
    if (isTablet) return size * 1.30;
    if (isDesktop) return size * 1.40;
    return size;
  }

  double w(double value) {
    return width * (value / 400);
  }

  double h(double value) {
    return height * (value / 800);
  }

  int gridCount() {
    if (isSmallPhone) return 2;
    if (isPhone) return 2;
    if (isMediumPhone) return 3;
    if (isFoldable) return 3;
    if (isTablet) return 4;
    if (isDesktop) return 6;
    return 2;
  }

  double gridAspect() {
    if (isSmallPhone) return 0.72;
    if (isPhone) return 0.75;
    if (isMediumPhone) return 0.82;
    if (isFoldable) return 0.90;
    if (isTablet) return 1.0;
    return 1.2;
  }
}
