import 'dart:async';
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  setUp(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.localesTestValue = [const Locale('zh')];
    addTearDown(binding.platformDispatcher.clearLocalesTestValue);
  });
  await testMain();
}
