import 'package:flutter_test/flutter_test.dart';
import 'package:lunaria_flutter/features/authentication/presentation/auth_error_messages.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('explains that unconfirmed users can request another email', () {
    final message = authErrorMessage(
      const AuthApiException(
        'Email not confirmed',
        code: 'email_not_confirmed',
      ),
      request: AuthRequest.signIn,
    );

    expect(message, contains('no está verificada'));
    expect(message, contains('nuevo correo'));
  });

  test('explains the default SMTP recipient restriction', () {
    final message = authErrorMessage(
      const AuthApiException(
        'Email address not authorized',
        code: 'email_address_not_authorized',
      ),
      request: AuthRequest.signUp,
    );

    expect(message, contains('SMTP personalizado'));
  });

  test('explains Supabase email rate limits', () {
    final message = authErrorMessage(
      const AuthApiException(
        'Email rate limit exceeded',
        code: 'over_email_send_rate_limit',
      ),
      request: AuthRequest.resendVerification,
    );

    expect(message, contains('limitó temporalmente'));
  });

  test('does not expose raw auth server messages in fallback errors', () {
    final message = authErrorMessage(
      const AuthApiException('Sensitive server detail'),
      request: AuthRequest.signUp,
    );

    expect(message, isNot(contains('Sensitive server detail')));
    expect(message, contains('configuración de correo'));
  });
}
