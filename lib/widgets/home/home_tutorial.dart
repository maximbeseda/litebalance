import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

import '../../theme/app_colors_extension.dart';

/// Покрокова підказка-«coach marks» поверх реального головного екрана. Показуємо
/// один раз — при першому вході на головний екран після онбордингу. Підсвічує
/// шапку з підсумками, монетки доходів/рахунків і кнопку меню, паралельно
/// пояснюючи головний жест — перетягування монетки на іншу категорію.
class HomeTutorial {
  HomeTutorial._();

  /// Глибокий фірмовий фон LiteBalance — під ним підсвічена ділянка «світиться».
  static const Color _shadow = Color(0xFF0A1026);

  static TutorialCoachMark build({
    required BuildContext context,
    required GlobalKey headerKey,
    required GlobalKey incomeKey,
    required GlobalKey accountKey,
    required GlobalKey menuKey,
    VoidCallback? onDone,
  }) {
    final colors = Theme.of(context).extension<AppColorsExtension>()!;

    final targets = <TargetFocus>[
      _target(
        id: 'tut_header',
        key: headerKey,
        title: 'tutorial_overview_title'.tr(),
        desc: 'tutorial_overview_desc'.tr(),
        colors: colors,
        shape: ShapeLightFocus.RRect,
      ),
      _target(
        id: 'tut_income',
        key: incomeKey,
        title: 'tutorial_income_title'.tr(),
        desc: 'tutorial_income_desc'.tr(),
        colors: colors,
        shape: ShapeLightFocus.RRect,
      ),
      _target(
        id: 'tut_account',
        key: accountKey,
        title: 'tutorial_accounts_title'.tr(),
        desc: 'tutorial_accounts_desc'.tr(),
        colors: colors,
        shape: ShapeLightFocus.RRect,
      ),
      _target(
        id: 'tut_menu',
        key: menuKey,
        title: 'tutorial_menu_title'.tr(),
        desc: 'tutorial_menu_desc'.tr(),
        colors: colors,
        shape: ShapeLightFocus.Circle,
        isLast: true,
      ),
    ];

    return TutorialCoachMark(
      targets: targets,
      colorShadow: _shadow,
      opacityShadow: 0.92,
      textSkip: 'skip'.tr().toUpperCase(),
      textStyleSkip: const TextStyle(
        color: Colors.white70,
        fontWeight: FontWeight.w600,
      ),
      paddingFocus: 8,
      onFinish: () => onDone?.call(),
      onSkip: () {
        onDone?.call();
        return true;
      },
    );
  }

  static TargetFocus _target({
    required String id,
    required GlobalKey key,
    required String title,
    required String desc,
    required AppColorsExtension colors,
    required ShapeLightFocus shape,
    bool isLast = false,
  }) {
    return TargetFocus(
      identify: id,
      keyTarget: key,
      shape: shape,
      radius: 16,
      enableOverlayTab: true,
      contents: [
        TargetContent(
          align: ContentAlign.bottom,
          builder: (context, controller) => _card(
            title: title,
            desc: desc,
            colors: colors,
            isLast: isLast,
            onNext: controller.next,
          ),
        ),
      ],
    );
  }

  static Widget _card({
    required String title,
    required String desc,
    required AppColorsExtension colors,
    required bool isLast,
    required VoidCallback onNext,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      constraints: const BoxConstraints(maxWidth: 320),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            desc,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 15,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: onNext,
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.accent,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: Text(
                (isLast ? 'done' : 'tutorial_next').tr(),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
