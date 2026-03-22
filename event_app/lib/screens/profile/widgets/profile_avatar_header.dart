// widgets/profile_avatar_header.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ProfileAvatarHeader extends StatelessWidget {
  const ProfileAvatarHeader({
    super.key,
    this.avatarUrl,
    this.avatarSize = 120.0,
    this.headerHeight = 110.0,
    this.headerRadius = 20.0,
    this.avatarOuterRadius = 28.0,
    this.avatarInnerRadius = 24.0,
    this.avatarTopOffset = 29.0,
    this.avatarBorderPadding = 4.0,
    this.headerGradientColors = const [
      Color(0xFFE64444),
      Color(0xFFFF6E82),
      Color(0xFFFEBC2F),
    ],
    this.sideSquareSize = 44.0,
    this.sideSquareGapFromAvatar = 0.0,
    this.sideSquareCornerRadius = 14.0,
    this.sideSquareColor = const Color(0xFF000000),
    this.sideSquareOpacity = 0.0,
    this.leftSideSvgAsset = 'assets/avatar/left_raounded.svg',
    this.rightSideSvgAsset = 'assets/avatar/right_rounded.svg',
    this.actionsBar,
    this.statusBarHeight = 25.0, // Добавляем параметр для высоты статус-бара
  });

  final String? avatarUrl;

  final double avatarSize;
  final double headerHeight;
  final double headerRadius;

  final double avatarOuterRadius;
  final double avatarInnerRadius;
  final double avatarTopOffset;
  final double avatarBorderPadding;

  final List<Color> headerGradientColors;

  final double sideSquareSize;
  final double sideSquareGapFromAvatar;
  final double sideSquareCornerRadius;
  final Color sideSquareColor;
  final double sideSquareOpacity;
  final String leftSideSvgAsset;
  final String rightSideSvgAsset;
  final Widget? actionsBar;
  final double statusBarHeight;

  @override
  Widget build(BuildContext context) {
    // Получаем высоту статус-бара если не передана
    final actualStatusBarHeight = statusBarHeight > 0
        ? statusBarHeight
        : MediaQuery.of(context).padding.top;

    // Смещаем всю шапку вниз на высоту статус-бара
    final topPadding = actualStatusBarHeight;
    final hasPhoto = avatarUrl != null && avatarUrl!.trim().isNotEmpty;

    return LayoutBuilder(
      builder: (context, constraints) {
        final sideInset =
            (((constraints.maxWidth - avatarSize) / 2) -
                    sideSquareGapFromAvatar -
                    sideSquareSize)
                .clamp(0.0, 10000.0);
        final sideTop = avatarTopOffset + (avatarSize - sideSquareSize) / 2;

        Widget sideSquareLeft = Container(
          width: sideSquareSize,
          height: sideSquareSize,
          decoration: BoxDecoration(
            color: sideSquareColor.withOpacity(sideSquareOpacity),
            borderRadius: BorderRadius.circular(sideSquareCornerRadius),
          ),
          child: Center(
            child: SvgPicture.asset(
              leftSideSvgAsset,
              width: sideSquareSize,
              height: sideSquareSize,
              fit: BoxFit.cover,
            ),
          ),
        );

        Widget sideSquareRight = Container(
          width: sideSquareSize,
          height: sideSquareSize,
          decoration: BoxDecoration(
            color: sideSquareColor.withOpacity(sideSquareOpacity),
            borderRadius: BorderRadius.circular(sideSquareCornerRadius),
          ),
          child: Center(
            child: SvgPicture.asset(
              rightSideSvgAsset,
              width: sideSquareSize,
              height: sideSquareSize,
              fit: BoxFit.cover,
            ),
          ),
        );

        return Padding(
          padding: EdgeInsets.only(top: topPadding),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(headerRadius),
                child: SizedBox(
                  width: double.infinity,
                  height: headerHeight,
                  child: Stack(
                    children: [
                      Container(
                        width: double.infinity,
                        height: headerHeight,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: headerGradientColors,
                            stops: const [0.0, 0.5, 1.0],
                          ),
                        ),
                      ),
                      Positioned(
                        left: sideInset,
                        top: sideTop,
                        child: sideSquareLeft,
                      ),
                      Positioned(
                        right: sideInset,
                        top: sideTop,
                        child: sideSquareRight,
                      ),
                      if (actionsBar != null)
                        Positioned(
                          top: 12,
                          left: 0,
                          right: 0,
                          child: actionsBar!,
                        ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: avatarTopOffset,
                child: Container(
                  width: avatarSize,
                  height: avatarSize,
                  decoration: BoxDecoration(
                    color: const Color(0xFF161616),
                    borderRadius: BorderRadius.circular(avatarOuterRadius),
                  ),
                  padding: EdgeInsets.all(avatarBorderPadding),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(avatarInnerRadius),
                    child: Container(
                      decoration: hasPhoto
                          ? BoxDecoration(
                              image: DecorationImage(
                                image: NetworkImage(avatarUrl!.trim()),
                                fit: BoxFit.cover,
                              ),
                            )
                          : const BoxDecoration(
                              color: Color(0xFF252525),
                            ),
                      child: hasPhoto
                          ? null
                          : const Center(
                              child: Icon(
                                Icons.person,
                                color: Colors.white70,
                                size: 34,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
