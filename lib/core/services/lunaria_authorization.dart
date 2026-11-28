import 'package:supabase_flutter/supabase_flutter.dart';

class LunariaAuthorizationException implements Exception {
  const LunariaAuthorizationException(this.message);

  final String message;

  @override
  String toString() => message;
}

Future<bool> isCurrentLunariaUserAuthorized(SupabaseClient client) async {
  if (client.auth.currentUser == null) return false;

  final result = await client.rpc('is_lunaria_user_authorized');
  if (result is! bool) {
    throw const FormatException(
      'Supabase devolvió una respuesta de autorización inválida.',
    );
  }
  return result;
}
