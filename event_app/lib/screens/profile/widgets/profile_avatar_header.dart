import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ProfileAvatarHeader extends StatelessWidget {
  const ProfileAvatarHeader({
    super.key,
    required this.avatarColor,
    required this.avatarIconCodePoint,
    this.avatarUrl,
    this.avatarSize = 120.0,
    this.headerHeight = 108.0,
    this.headerRadius = 20.0,
    this.avatarOuterRadius = 28.0,
    this.avatarInnerRadius = 24.0,
    this.avatarTopOffset = 50.0,
    this.avatarBorderPadding = 4.0,
    this.headerColor = const Color(0xFFFF5F57),
    this.sideSquareSize = 44.0,
    this.sideSquareGapFromAvatar = 0.0,
    this.sideSquareCornerRadius = 14.0,
    this.sideSquareColor = const Color(0xFF000000),
    this.sideSquareOpacity = 0.0,
    this.leftSideSvgAsset = 'assets/avatar/left_raounded.svg',
    this.rightSideSvgAsset = 'assets/avatar/right_rounded.svg',
  });

  final Color avatarColor;
  final String? avatarUrl;
  final int avatarIconCodePoint;

  final double avatarSize;
  final double headerHeight;
  final double headerRadius;

  final double avatarOuterRadius;
  final double avatarInnerRadius;
  final double avatarTopOffset;
  final double avatarBorderPadding;

  final Color headerColor;

  final double sideSquareSize;
  final double sideSquareGapFromAvatar;
  final double sideSquareCornerRadius;
  final Color sideSquareColor;
  final double sideSquareOpacity;
  final String leftSideSvgAsset;
  final String rightSideSvgAsset;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final sideInset = (((constraints.maxWidth - avatarSize) / 2) - sideSquareGapFromAvatar - sideSquareSize)
            .clamp(0.0, 10000.0);
        // Вертикально выравниваем боковые квадраты по центру аватарки.
        // Тогда они всегда будут "на уровне" аватара при любых headerHeight.
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

        return Stack(
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
                        color: headerColor,
                      ),
                    ),
                    Positioned(left: sideInset, top: sideTop, child: sideSquareLeft),
                    Positioned(right: sideInset, top: sideTop, child: sideSquareRight),
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
                  color: const Color(0xFF161616),  // обычный цвет вместо градиента
                  borderRadius: BorderRadius.circular(avatarOuterRadius),
                ),
                padding: EdgeInsets.all(avatarBorderPadding),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(avatarInnerRadius),
                  child: Container(
                    decoration: BoxDecoration(
                      color: avatarColor,
                      image: avatarUrl == null
                          ? null
                          : DecorationImage(
                              image: NetworkImage(avatarUrl!),
                              fit: BoxFit.cover,
                            ),
                    ),
                    child: avatarUrl == null
                        ? Center(
                            child: Icon(
                              IconData(
                                avatarIconCodePoint,
                                fontFamily: 'MaterialIcons',
                              ),
                              color: Colors.white,
                              size: 34,
                            ),
                          )
                        : null,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

