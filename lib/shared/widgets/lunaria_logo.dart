import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class LunariaLogo extends StatelessWidget {
  const LunariaLogo({super.key, this.size = 64});

  final double size;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/branding/lunaria_logo.svg',
    width: size,
    height: size,
    semanticsLabel: 'Lunaria',
  );
}
