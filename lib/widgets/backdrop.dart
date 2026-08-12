import 'package:flutter/material.dart';

/// Full screen artwork that swaps between the portrait and landscape variants
/// shipped in the asset pack.
class OrientationBackdrop extends StatelessWidget {
  const OrientationBackdrop({
    super.key,
    required this.vertical,
    required this.horizontal,
    this.child,
  });

  final String vertical;
  final String horizontal;
  final Widget? child;

  static const verticalLoading =
      'assets/Tower_Surge_additional_assets/Vertical_Loading_Screen.webp';
  static const horizontalLoading =
      'assets/Tower_Surge_additional_assets/Horizontal_Loading_Screen.webp';

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final asset = size.width > size.height ? horizontal : vertical;
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          asset,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
          gaplessPlayback: true,
        ),
        ?child,
      ],
    );
  }
}
