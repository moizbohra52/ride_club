import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../routes/app_routes.dart';
import '../../services/auth_service.dart';
import '../../services/theme_service.dart';
import 'create_ride_tab.dart';
import 'join_ride_tab.dart';
import 'my_rides_tab.dart';
import 'rides_shell_controller.dart';

class RidesShellView extends GetView<RidesShellController> {
  const RidesShellView({super.key});

  @override
  Widget build(BuildContext context) {
    const List<String> titles = <String>[
      'My Rides',
      'Create a ride',
      'Join a ride',
    ];
    final ThemeService theme = Get.find<ThemeService>();
    return Obx(
      () => Scaffold(
        appBar: AppBar(
          title: Text(titles[controller.tabIndex.value]),
          actions: <Widget>[
            IconButton(
              tooltip: 'Profile',
              onPressed: () => Get.toNamed(Routes.profile),
              icon: Builder(
                builder: (BuildContext context) {
                  final String? photo =
                      Get.find<AuthService>().currentUser?.photoURL;
                  if (photo == null) {
                    return const Icon(Icons.account_circle_outlined);
                  }
                  return CircleAvatar(
                    radius: 14,
                    backgroundImage: NetworkImage(photo),
                  );
                },
              ),
            ),
            Obx(
              () => IconButton(
                onPressed: theme.toggle,
                icon: Icon(theme.icon),
                tooltip: 'Switch theme',
              ),
            ),
          ],
        ),
        body: SafeArea(
          top: false, // AppBar already handles top safe area
          child: IndexedStack(
            index: controller.tabIndex.value,
            children: const <Widget>[
              MyRidesTab(),
              CreateRideTab(),
              JoinRideTab(),
            ],
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: controller.tabIndex.value,
          onDestinationSelected: (int i) => controller.tabIndex.value = i,
          destinations: const <NavigationDestination>[
            NavigationDestination(
              icon: Icon(Icons.route_outlined),
              selectedIcon: Icon(Icons.route_rounded),
              label: 'My Rides',
            ),
            NavigationDestination(
              icon: Icon(Icons.add_road_outlined),
              selectedIcon: Icon(Icons.add_road_rounded),
              label: 'Create',
            ),
            NavigationDestination(
              icon: Icon(Icons.group_add_outlined),
              selectedIcon: Icon(Icons.group_add_rounded),
              label: 'Join',
            ),
          ],
        ),
      ),
    );
  }
}
