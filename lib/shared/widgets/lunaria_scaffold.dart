import 'package:flutter/material.dart';

class LunariaScaffold extends StatelessWidget {
  const LunariaScaffold({
    super.key,
    required this.children,
    this.backgroundColor,
  });

  final List<Widget> children;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontal = constraints.maxWidth >= 700 ? 48.0 : 20.0;
            return ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(horizontal, 12, horizontal, 36),
              children: children,
            );
          },
        ),
      ),
    );
  }
}
