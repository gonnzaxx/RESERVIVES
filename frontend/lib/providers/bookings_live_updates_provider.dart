import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

final reservasPollTickProvider = StreamProvider.autoDispose<int>((ref) async* {
  var tick = 0;
  yield tick;
  while (true) {
    await Future<void>.delayed(const Duration(seconds: 30));
    tick++;
    yield tick;
  }
});
