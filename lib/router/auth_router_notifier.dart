import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRouterNotifier extends ChangeNotifier {
  AuthRouterNotifier() {
    _subscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (_) {
        notifyListeners();
      },
    );
  }

  late final StreamSubscription<AuthState> _subscription;

  bool get isLoggedIn {
    return Supabase.instance.client.auth.currentSession != null;
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
