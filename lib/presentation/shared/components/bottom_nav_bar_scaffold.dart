import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:on_time_front/presentation/schedule_create/screens/schedule_create_screen.dart';
import 'package:on_time_front/presentation/shared/constants/app_colors.dart';

class BottomNavBarScaffold extends StatefulWidget {
  const BottomNavBarScaffold({super.key, required this.child});
  final Widget child;

  @override
  State<BottomNavBarScaffold> createState() =>
      _BottomNavigationBarScaffoldState();
}

class _BottomNavigationBarScaffoldState extends State<BottomNavBarScaffold> {
  int selectedIndex = 0;

  void onDestinationSelected(int index) {
    setState(() {
      selectedIndex = index;
    });
    switch (index) {
      case 0:
        context.go('/home');
        break;
      case 1:
        context.go('/myPage');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: AppColors.blue[100],
      body: widget.child,
      bottomNavigationBar: ClipRRect(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16.0),
          topRight: Radius.circular(16.0),
        ),
        child: Container(
          color: AppColors.white,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: BottomNavigationBar(
              items: [
                BottomNavigationBarItem(
                  icon: _HomeIcon(),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: _MyIcon(),
                  label: 'My',
                ),
              ],
              currentIndex: selectedIndex,
              onTap: onDestinationSelected,
              iconSize: 24.0,
              unselectedItemColor: colorScheme.onPrimaryContainer,
              elevation: 0,
              showSelectedLabels: false,
              showUnselectedLabels: false,
            ),
          ),
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(top: 24.0),
        child: SizedBox(
          height: 76,
          width: 76,
          child: FilledButton(
            // onPressed: () {
            //   context.go('/scheduleCreate');
            // },
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => ScheduleCreateScreen(),
              );
            },
            style: FilledButton.styleFrom(
              shape: CircleBorder(),
              padding: EdgeInsets.all(13),
            ),
            child: _PlusIcon(),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}

class _HomeIcon extends StatelessWidget {
  const _HomeIcon();

  @override
  Widget build(BuildContext context) {
    final iconTheme = IconTheme.of(context);
    return SvgPicture.asset(
      'Home.svg',
      package: 'assets',
      semanticsLabel: 'home',
      height: iconTheme.size,
      fit: BoxFit.contain,
      colorFilter: ColorFilter.mode(
        iconTheme.color!,
        BlendMode.srcIn,
      ),
    );
  }
}

class _MyIcon extends StatelessWidget {
  const _MyIcon();

  @override
  Widget build(BuildContext context) {
    final iconTheme = IconTheme.of(context);
    return SvgPicture.asset(
      'My.svg',
      package: 'assets',
      semanticsLabel: 'myPage',
      height: iconTheme.size,
      fit: BoxFit.contain,
      colorFilter: ColorFilter.mode(
        iconTheme.color!,
        BlendMode.srcIn,
      ),
    );
  }
}

class _PlusIcon extends StatelessWidget {
  const _PlusIcon();

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'Plus.svg',
      package: 'assets',
      semanticsLabel: 'plus',
      height: 50,
      fit: BoxFit.contain,
    );
  }
}
