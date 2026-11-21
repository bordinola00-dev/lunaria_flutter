import 'package:supabase_flutter/supabase_flutter.dart';

enum AuthRequest { signUp, signIn, resendVerification }

String authErrorMessage(AuthException error, {required AuthRequest request}) {
  final code = error.code?.toLowerCase();
  final serverMessage = error.message.toLowerCase();

  if (error is AuthRetryableFetchException) {
    return 'No se pudo conectar con Supabase. Revisa tu conexión e inténtalo de nuevo.';
  }
  if (code == 'email_address_not_authorized' ||
      serverMessage.contains('email address not authorized')) {
    return 'Supabase no autorizó el envío a ese correo. El remitente predeterminado '
        'solo entrega a direcciones autorizadas; configura SMTP personalizado '
        'en el proyecto.';
  }
  if (code == 'over_email_send_rate_limit' ||
      code == 'over_request_rate_limit' ||
      serverMessage.contains('email rate limit')) {
    return 'Supabase limitó temporalmente los correos. Espera antes de volver '
        'a intentarlo; para envíos habituales, configura SMTP personalizado.';
  }
  if (code == 'email_not_confirmed' ||
      serverMessage.contains('email not confirmed')) {
    return 'Tu cuenta aún no está verificada. Revisa Recibidos y Spam o '
        'solicita un nuevo correo de verificación.';
  }
  if (code == 'email_exists' || code == 'user_already_exists') {
    return 'Ya existe una cuenta con ese correo. Inicia sesión o reenvía la '
        'verificación si aún no la confirmaste.';
  }
  if (code == 'weak_password') {
    return 'La contraseña no cumple los requisitos definidos para este proyecto.';
  }
  if (code == 'signup_disabled' || code == 'email_provider_disabled') {
    return 'El registro por correo está deshabilitado en el proyecto Supabase.';
  }
  if (code == 'invalid_credentials') {
    return 'El correo o la contraseña no coinciden. Si aún no verificaste la '
        'cuenta, solicita otro correo de verificación.';
  }
  if (code == 'email_address_invalid' ||
      serverMessage.contains('invalid email')) {
    return 'El correo electrónico no tiene un formato válido.';
  }

  return switch (request) {
    AuthRequest.signUp => 'No se pudo crear la cuenta. Revisa los datos y la configuración de correo del proyecto.',
    AuthRequest.signIn => 'No se pudo iniciar sesión. Revisa el correo, la contraseña y tu conexión.',
    AuthRequest.resendVerification =>
      'No se pudo reenviar el correo. Espera un momento y vuelve a intentarlo.',
  };
}

bool shouldOfferVerificationResend(AuthException error) {
  final code = error.code?.toLowerCase();
  final message = error.message.toLowerCase();
  return code == 'email_exists' ||
      code == 'user_already_exists' ||
      code == 'email_not_confirmed' ||
      code == 'over_email_send_rate_limit' ||
      code == 'email_address_not_authorized' ||
      message.contains('email address not authorized');
}
