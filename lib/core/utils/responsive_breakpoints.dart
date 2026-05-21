import 'package:flutter/material.dart';

enum OnboardingLayoutVariant {
  defaultCentered,
  compactHeight,
  smallPhone,
  largePhoneCentered,
  tabletPhoneFrame,
}

enum OnboardingHeroVariant {
  full,
  compact,
  minimal,
  assetImage,
  flutterVectorPlaceholder,
}

enum AuthLayoutVariant {
  defaultCentered,
  compactHeight,
  smallPhone,
  largePhoneCentered,
  tabletPhoneFrame,
}

enum AuthBottomIllustrationVariant { full, compact, hidden }

class OnboardingResponsiveProfile {
  const OnboardingResponsiveProfile({
    required this.layoutVariant,
    required this.heroVariant,
    required this.horizontalPadding,
    required this.logoFontSize,
    required this.taglineFontSize,
    required this.heroWidth,
    required this.heroHeight,
    required this.headlineFontSize,
    required this.headlineLineHeight,
    required this.descriptionFontSize,
    required this.buttonHeight,
    required this.buttonRadius,
    required this.footerFontSize,
    required this.logoTopPadding,
    required this.gapScale,
    required this.isWideLayout,
    required this.isShortHeight,
  });

  final OnboardingLayoutVariant layoutVariant;
  final OnboardingHeroVariant heroVariant;
  final double horizontalPadding;
  final double logoFontSize;
  final double taglineFontSize;
  final double heroWidth;
  final double heroHeight;
  final double headlineFontSize;
  final double headlineLineHeight;
  final double descriptionFontSize;
  final double buttonHeight;
  final double buttonRadius;
  final double footerFontSize;
  final double logoTopPadding;
  final double gapScale;
  final bool isWideLayout;
  final bool isShortHeight;

  double scaleGap(double value) => value * gapScale;
}

class SignInResponsiveProfile {
  const SignInResponsiveProfile({
    required this.layoutVariant,
    required this.bottomIllustrationVariant,
    required this.horizontalPadding,
    required this.topActionButtonSize,
    required this.appIconCardSize,
    required this.appIconInnerSize,
    required this.headlineFontSize,
    required this.headlineLineHeight,
    required this.subtitleFontSize,
    required this.formCardMinHeight,
    required this.inputRowHeight,
    required this.primaryButtonHeight,
    required this.socialButtonHeight,
    required this.socialButtonGap,
    required this.socialLabelFontSize,
    required this.createAccountPanelHeight,
    required this.topActionsToAppIconGap,
    required this.appIconToHeadlineGap,
    required this.subtitleToFormCardGap,
    required this.primaryButtonToDividerGap,
    required this.gapScale,
    required this.showDecorativeBackground,
    required this.isWideLayout,
  });

  final AuthLayoutVariant layoutVariant;
  final AuthBottomIllustrationVariant bottomIllustrationVariant;
  final double horizontalPadding;
  final double topActionButtonSize;
  final double appIconCardSize;
  final double appIconInnerSize;
  final double headlineFontSize;
  final double headlineLineHeight;
  final double subtitleFontSize;
  final double formCardMinHeight;
  final double inputRowHeight;
  final double primaryButtonHeight;
  final double socialButtonHeight;
  final double socialButtonGap;
  final double socialLabelFontSize;
  final double createAccountPanelHeight;
  final double topActionsToAppIconGap;
  final double appIconToHeadlineGap;
  final double subtitleToFormCardGap;
  final double primaryButtonToDividerGap;
  final double gapScale;
  final bool showDecorativeBackground;
  final bool isWideLayout;

  double scaleGap(double value) => value * gapScale;
}

class ResponsiveBreakpoints {
  static const double smallPhone = 360;
  static const double normalPhone = 430;
  static const double largePhone = 600;
  static const double shortHeight = 700;
  
  static bool isSmallPhone(BuildContext context) => MediaQuery.of(context).size.width < smallPhone;
  static bool isNormalPhone(BuildContext context) => MediaQuery.of(context).size.width >= smallPhone && MediaQuery.of(context).size.width <= normalPhone;
  static bool isLargePhone(BuildContext context) => MediaQuery.of(context).size.width > normalPhone && MediaQuery.of(context).size.width <= largePhone;
  static bool isTabletOrWeb(BuildContext context) => MediaQuery.of(context).size.width > largePhone;
  static bool isShortScreen(BuildContext context) => MediaQuery.of(context).size.height < shortHeight;

  static OnboardingResponsiveProfile onboardingProfileFor(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final width = size.width;
    final height = size.height;
    final isShort = height < shortHeight;

    if (width < smallPhone) {
      return OnboardingResponsiveProfile(
        layoutVariant: isShort
            ? OnboardingLayoutVariant.compactHeight
            : OnboardingLayoutVariant.smallPhone,
        heroVariant: isShort ? OnboardingHeroVariant.compact : OnboardingHeroVariant.compact,
        horizontalPadding: 18,
        logoFontSize: 38,
        taglineFontSize: 14,
        heroWidth: 280,
        heroHeight: 204,
        headlineFontSize: 26,
        headlineLineHeight: 32,
        descriptionFontSize: 14,
        buttonHeight: 50,
        buttonRadius: 14,
        footerFontSize: 10,
        logoTopPadding: isShort ? 36 : 52.7,
        gapScale: isShort ? 0.85 : 0.85,
        isWideLayout: false,
        isShortHeight: isShort,
      );
    }

    if (width <= normalPhone) {
      return OnboardingResponsiveProfile(
        layoutVariant: isShort
            ? OnboardingLayoutVariant.compactHeight
            : OnboardingLayoutVariant.defaultCentered,
        heroVariant: isShort ? OnboardingHeroVariant.compact : OnboardingHeroVariant.full,
        horizontalPadding: 24,
        logoFontSize: 46,
        taglineFontSize: 15,
        heroWidth: 326,
        heroHeight: 238,
        headlineFontSize: 30,
        headlineLineHeight: 36,
        descriptionFontSize: 16,
        buttonHeight: 54,
        buttonRadius: 16,
        footerFontSize: 11,
        logoTopPadding: isShort ? 36 : 62,
        gapScale: isShort ? 0.85 : 1,
        isWideLayout: false,
        isShortHeight: isShort,
      );
    }

    if (width <= largePhone) {
      return OnboardingResponsiveProfile(
        layoutVariant: OnboardingLayoutVariant.largePhoneCentered,
        heroVariant: isShort ? OnboardingHeroVariant.compact : OnboardingHeroVariant.full,
        horizontalPadding: 24,
        logoFontSize: 46,
        taglineFontSize: 15,
        heroWidth: 326,
        heroHeight: 238,
        headlineFontSize: 30,
        headlineLineHeight: 36,
        descriptionFontSize: 16,
        buttonHeight: 54,
        buttonRadius: 16,
        footerFontSize: 11,
        logoTopPadding: isShort ? 36 : 62,
        gapScale: isShort ? 0.9 : 1,
        isWideLayout: true,
        isShortHeight: isShort,
      );
    }

    return OnboardingResponsiveProfile(
      layoutVariant: OnboardingLayoutVariant.tabletPhoneFrame,
      heroVariant: isShort ? OnboardingHeroVariant.compact : OnboardingHeroVariant.full,
      horizontalPadding: 24,
      logoFontSize: 46,
      taglineFontSize: 15,
      heroWidth: 326,
      heroHeight: 238,
      headlineFontSize: 30,
      headlineLineHeight: 36,
      descriptionFontSize: 16,
      buttonHeight: 54,
      buttonRadius: 16,
      footerFontSize: 11,
      logoTopPadding: isShort ? 36 : 62,
      gapScale: isShort ? 0.9 : 1,
      isWideLayout: true,
      isShortHeight: isShort,
    );
  }

  static SignInResponsiveProfile signInProfileFor(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final width = size.width;
    final height = size.height;
    final isVeryShort = height < 680;
    final isShort = height < 760;

    final double horizontalPadding = width < smallPhone ? 18 : 24;
    final bool smallPhoneLayout = width < smallPhone;
    final bool wideLayout = width > normalPhone;

    final double topActionButtonSize = smallPhoneLayout ? 44 : 48;
    double appIconCardSize = smallPhoneLayout ? 76 : 92;
    if (isVeryShort) {
      appIconCardSize = 70;
    }

    final double appIconInnerSize = isVeryShort
        ? 40
        : smallPhoneLayout
            ? 44
            : 54;
    final double headlineFontSize = smallPhoneLayout ? 24 : 28;
    final double headlineLineHeight = smallPhoneLayout ? 30 : 34;
    final double subtitleFontSize = smallPhoneLayout ? 14 : 16;
    final double formCardMinHeight = smallPhoneLayout ? 150 : 158;
    final double inputRowHeight = smallPhoneLayout ? 50 : 54;
    final double primaryButtonHeight = smallPhoneLayout ? 50 : 54;
    final double socialButtonHeight = smallPhoneLayout ? 58 : 66;
    final double socialButtonGap = smallPhoneLayout ? 8 : 10;
    final double socialLabelFontSize = smallPhoneLayout ? 12 : 14;
    final double createAccountPanelHeight = smallPhoneLayout ? 60 : 68;
    final double gapScale = isVeryShort
        ? 0.76
        : smallPhoneLayout
            ? 0.84
            : 1;

    return SignInResponsiveProfile(
      layoutVariant: isVeryShort
          ? AuthLayoutVariant.compactHeight
          : smallPhoneLayout
              ? AuthLayoutVariant.smallPhone
              : wideLayout
                  ? width > largePhone
                      ? AuthLayoutVariant.tabletPhoneFrame
                      : AuthLayoutVariant.largePhoneCentered
                  : AuthLayoutVariant.defaultCentered,
      bottomIllustrationVariant: isVeryShort
          ? AuthBottomIllustrationVariant.hidden
          : isShort
              ? AuthBottomIllustrationVariant.compact
              : AuthBottomIllustrationVariant.full,
      horizontalPadding: horizontalPadding,
      topActionButtonSize: topActionButtonSize,
      appIconCardSize: appIconCardSize,
      appIconInnerSize: appIconInnerSize,
      headlineFontSize: headlineFontSize,
      headlineLineHeight: headlineLineHeight,
      subtitleFontSize: subtitleFontSize,
      formCardMinHeight: formCardMinHeight,
      inputRowHeight: inputRowHeight,
      primaryButtonHeight: primaryButtonHeight,
      socialButtonHeight: socialButtonHeight,
      socialButtonGap: socialButtonGap,
      socialLabelFontSize: socialLabelFontSize,
      createAccountPanelHeight: createAccountPanelHeight,
      topActionsToAppIconGap: isShort ? 24 : 42,
      appIconToHeadlineGap: isShort ? 20 : 28,
      subtitleToFormCardGap: isShort ? 24 : 36,
      primaryButtonToDividerGap: isShort ? 18 : 26,
      gapScale: gapScale,
      showDecorativeBackground: !isVeryShort,
      isWideLayout: wideLayout,
    );
  }
}
