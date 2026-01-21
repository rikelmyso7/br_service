import 'package:flutter/material.dart';

/// Utilitário para criar layouts responsivos e evitar crashes de dimensionamento
class ResponsiveUtils {
  // Breakpoints padrão
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 800;
  static const double desktopBreakpoint = 1200;

  // Dimensões mínimas de segurança
  static const double minWidth = 250;
  static const double minHeight = 300;
  static const double defaultWidth = 320;
  static const double defaultHeight = 480;

  /// Retorna o tipo de dispositivo baseado na largura da tela
  static DeviceType getDeviceType(double screenWidth) {
    if (screenWidth >= desktopBreakpoint) return DeviceType.desktop;
    if (screenWidth >= tabletBreakpoint) return DeviceType.tablet;
    if (screenWidth >= mobileBreakpoint) return DeviceType.mobile;
    return DeviceType.small;
  }

  /// Calcula largura responsiva com validações de segurança
  static double getResponsiveWidth(BuildContext context, {
    double? fixedDesktop,
    double? percentageTablet,
    double? percentageMobile,
    double? maxWidth,
    double? minWidth,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final safeScreenWidth = screenWidth > 0 ? screenWidth : defaultWidth;
    final deviceType = getDeviceType(safeScreenWidth);

    double width;

    switch (deviceType) {
      case DeviceType.desktop:
        width = fixedDesktop ?? 500;
        break;
      case DeviceType.tablet:
        width = safeScreenWidth * (percentageTablet ?? 0.7);
        break;
      case DeviceType.mobile:
        width = safeScreenWidth * (percentageMobile ?? 0.9);
        break;
      case DeviceType.small:
        width = safeScreenWidth * 0.95;
        break;
    }

    // Aplica constraints de segurança
    if (maxWidth != null) width = width.clamp(0, maxWidth);
    if (minWidth != null) width = width.clamp(minWidth, double.infinity);
    
    return width.clamp(ResponsiveUtils.minWidth, double.infinity);
  }

  /// Calcula altura responsiva com validações de segurança
  static double getResponsiveHeight(BuildContext context, {
    double? fixedHeight,
    double? percentage,
    double? maxHeight,
    double? minHeight,
  }) {
    final screenHeight = MediaQuery.of(context).size.height;
    final safeScreenHeight = screenHeight > 0 ? screenHeight : defaultHeight;

    double height;

    if (fixedHeight != null && safeScreenHeight > 600) {
      height = fixedHeight;
    } else {
      height = safeScreenHeight * (percentage ?? 0.8);
    }

    // Aplica constraints de segurança
    if (maxHeight != null) height = height.clamp(0, maxHeight);
    if (minHeight != null) height = height.clamp(minHeight, double.infinity);

    return height.clamp(ResponsiveUtils.minHeight, double.infinity);
  }

  /// Retorna padding responsivo baseado no tamanho da tela
  static EdgeInsets getResponsivePadding(BuildContext context, {
    double? mobile,
    double? tablet, 
    double? desktop,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final deviceType = getDeviceType(screenWidth);

    double padding;
    switch (deviceType) {
      case DeviceType.desktop:
        padding = desktop ?? 32;
        break;
      case DeviceType.tablet:
        padding = tablet ?? 24;
        break;
      case DeviceType.mobile:
        padding = mobile ?? 16;
        break;
      case DeviceType.small:
        padding = mobile ?? 12;
        break;
    }

    return EdgeInsets.all(padding);
  }

  /// Retorna font size responsivo
  static double getResponsiveFontSize(BuildContext context, {
    double? small,
    double? medium,
    double? large,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final deviceType = getDeviceType(screenWidth);

    switch (deviceType) {
      case DeviceType.desktop:
        return large ?? 18;
      case DeviceType.tablet:
        return medium ?? 16;
      case DeviceType.mobile:
        return medium ?? 14;
      case DeviceType.small:
        return small ?? 12;
    }
  }
}

enum DeviceType {
  small,    // < 600px
  mobile,   // 600-800px
  tablet,   // 800-1200px
  desktop,  // >= 1200px
}

/// Widget Container responsivo reutilizável
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final double? fixedDesktopWidth;
  final double? tabletWidthPercentage;
  final double? mobileWidthPercentage;
  final double? fixedHeight;
  final double? heightPercentage;
  final double? maxWidth;
  final double? maxHeight;
  final EdgeInsets? padding;
  final BoxDecoration? decoration;
  final bool enableScrolling;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.fixedDesktopWidth,
    this.tabletWidthPercentage,
    this.mobileWidthPercentage,
    this.fixedHeight,
    this.heightPercentage,
    this.maxWidth,
    this.maxHeight,
    this.padding,
    this.decoration,
    this.enableScrolling = false,
  });

  @override
  Widget build(BuildContext context) {
    final width = ResponsiveUtils.getResponsiveWidth(
      context,
      fixedDesktop: fixedDesktopWidth,
      percentageTablet: tabletWidthPercentage,
      percentageMobile: mobileWidthPercentage,
      maxWidth: maxWidth,
    );

    final height = ResponsiveUtils.getResponsiveHeight(
      context,
      fixedHeight: fixedHeight,
      percentage: heightPercentage,
      maxHeight: maxHeight,
    );

    final container = Container(
      width: double.infinity,
      constraints: BoxConstraints(
        maxWidth: width,
        maxHeight: height,
        minWidth: ResponsiveUtils.minWidth,
        minHeight: ResponsiveUtils.minHeight,
      ),
      padding: padding,
      decoration: decoration,
      child: child,
    );

    return enableScrolling 
        ? SingleChildScrollView(child: container)
        : container;
  }
}