import 'package:flutter_riverpod/legacy.dart';

import 'services/local_store.dart';

final lunariaStoreProvider = ChangeNotifierProvider<LunariaStore>(
  (ref) => LunariaStore(),
);
