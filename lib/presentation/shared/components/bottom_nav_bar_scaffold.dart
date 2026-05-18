import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:on_time_front/presentation/schedule_create/screens/schedule_create_screen.dart';
import 'package:on_time_front/presentation/shared/constants/app_colors.dart';
import 'package:on_time_front/l10n/app_localizations.dart';

class BottomNavBarScaffold extends StatefulWidget {
  const BottomNavBarScaffold({
    super.key,
    required this.child,
    this.backgroundColor,
  });
  final Widget child;
  final Color? backgroundColor;

  @override
  State<BottomNavBarScaffold> createState() =>
      _BottomNavigationBarScaffoldState();
}

class _BottomNavigationBarScaffoldState extends State<BottomNavBarScaffold> {
  void onDestinationSelected(int index) {
    switch (index) {
      case 0:
        context.go('/home');
        break;
      case 1:
        context.go('/myPage');
        break;
    }
  }

  Color _getBackgroundColor(BuildContext context) {
    // If backgroundColor is explicitly provided, use it
    if (widget.backgroundColor != null) {
      return widget.backgroundColor!;
    }
    final colorScheme = Theme.of(context).colorScheme;

    // Otherwise, determine background color based on current route
    final currentLocation = GoRouterState.of(context).uri.path;
    switch (currentLocation) {
      case '/home':
        return colorScheme.surfaceContainerLowest;
      case '/myPage':
        return Colors.grey[50]!; // Example: different color for myPage
      default:
        return AppColors.blue[100]!; // Default fallback
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentLocation = GoRouterState.of(context).uri.path;
    return Scaffold(
      body: widget.child,
      backgroundColor: _getBackgroundColor(context),
      bottomNavigationBar: ClipRRect(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16.0),
          topRight: Radius.circular(16.0),
        ),
        child: Container(
          color: AppColors.white,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 32.0),
            child: SizedBox(
              height: 56,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _BottomNavDestination(
                    selected: currentLocation == '/home',
                    color: colorScheme.primary,
                    unselectedColor: colorScheme.onPrimaryContainer,
                    label: AppLocalizations.of(context)!.home,
                    onTap: () => onDestinationSelected(0),
                    child: const _HomeIcon(),
                  ),
                  _BottomNavDestination(
                    selected: currentLocation == '/myPage',
                    color: colorScheme.primary,
                    unselectedColor: colorScheme.onPrimaryContainer,
                    label: AppLocalizations.of(context)!.myPage,
                    onTap: () => onDestinationSelected(1),
                    child: const _MyIcon(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: SizedBox(
        height: 76,
        width: 76,
        child: FilledButton(
          onPressed: () {
            showModalBottomSheet(
              context: context,
              isDismissible: false,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => const ScheduleCreateScreen(),
            );
          },
          // onPressed: () {
          //   context.go('/scheduleCreate');
          // },
          style: FilledButton.styleFrom(
            shape: CircleBorder(),
            padding: EdgeInsets.all(13),
          ),
          child: _PlusIcon(),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}

class _BottomNavDestination extends StatelessWidget {
  const _BottomNavDestination({
    required this.selected,
    required this.color,
    required this.unselectedColor,
    required this.label,
    required this.onTap,
    required this.child,
  });

  final bool selected;
  final Color color;
  final Color unselectedColor;
  final String label;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: InkWell(
          onTap: onTap,
          child: Center(
            child: IconTheme(
              data: IconThemeData(
                size: 24,
                color: selected ? color : unselectedColor,
              ),
              child: child,
            ),
          ),
        ),
      ),
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
      semanticsLabel: AppLocalizations.of(context)!.home,
      height: iconTheme.size,
      fit: BoxFit.contain,
      colorFilter: ColorFilter.mode(iconTheme.color!, BlendMode.srcIn),
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
      semanticsLabel: AppLocalizations.of(context)!.myPage,
      height: iconTheme.size,
      fit: BoxFit.contain,
      colorFilter: ColorFilter.mode(iconTheme.color!, BlendMode.srcIn),
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
      semanticsLabel: AppLocalizations.of(context)!.plus,
      height: 50,
      fit: BoxFit.contain,
    );
  }
}
