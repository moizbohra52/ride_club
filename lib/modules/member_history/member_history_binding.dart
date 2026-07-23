import 'package:get/get.dart';

import 'member_history_controller.dart';

/// Injects [MemberHistoryController] from the [MemberHistoryArgs] passed to the
/// route.
class MemberHistoryBinding extends Bindings {
  @override
  void dependencies() {
    final MemberHistoryArgs args = Get.arguments as MemberHistoryArgs;
    Get.lazyPut<MemberHistoryController>(
      () => MemberHistoryController(uid: args.uid, name: args.name),
    );
  }
}
