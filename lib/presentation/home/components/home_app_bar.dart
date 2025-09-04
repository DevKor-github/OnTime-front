import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:on_time_front/presentation/app/bloc/auth/app_bloc.dart';
import 'package:on_time_front/presentation/shared/constants/constants.dart';

class HomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  HomeAppBar({super.key, this.title, this.actions});

  final Widget? title;
  final List<Widget>? actions;

  final bellSvg = SvgPicture.asset(
    'bell.svg',
    package: 'assets',
    semanticsLabel: 'bell',
    height: 21,
    fit: BoxFit.contain,
  );

  final friendsSvg = SvgPicture.asset(
    'friends.svg',
    package: 'assets',
    semanticsLabel: 'friends',
    height: 21,
    fit: BoxFit.contain,
  );

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: title,
      actions: actions ??
          [
            IconButton(
              icon: friendsSvg,
              onPressed: () {
                context.read<AppBloc>().add(AppSignOutPressed());
              },
            ),
            IconButton(
              icon: bellSvg,
              onPressed: () {},
            )
          ],
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(appBarHeight);
}
