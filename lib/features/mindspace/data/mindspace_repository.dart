import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_config.dart';
import '../../../shared/models/lunaria_models.dart';

abstract interface class MindSpaceRepository {
  Future<List<MoodEntry>> fetchMoods();

  Future<List<DiaryEntry>> fetchDiaryEntries();

  Future<MoodEntry> createMood({required String mood, required String note});

  Future<DiaryEntry> createDiary({required String title, required String body});

  Future<DiaryEntry> updateDiary({
    required String id,
    required String title,
    required String body,
  });

  Future<void> deleteDiary(String id);
}

class SupabaseMindSpaceRepository implements MindSpaceRepository {
  SupabaseMindSpaceRepository({SupabaseClient? client})
    : _injectedClient = client;

  static const _pageSize = 200;
  static const _requestTimeout = Duration(seconds: 20);
  final SupabaseClient? _injectedClient;

  SupabaseClient get _client {
    final client = _injectedClient ?? supabase;
    if (client == null) {
      if (isSupabaseConfigured) {
        throw const MindSpaceAccessException(
          'Supabase está configurado, pero su cliente no está activo. '
          'Pulsa «Volver a intentar» para reactivar la conexión.',
        );
      }
      throw const MindSpaceAccessException(
        'No se recibieron SUPABASE_URL y SUPABASE_ANON_KEY al compilar. '
        'Un archivo .env no se carga automáticamente; inicia Flutter con '
        '--dart-define para ambos valores.',
      );
    }
    return client;
  }

  String get _userId {
    final userId = _client.auth.currentSession?.user.id;
    if (userId == null) {
      throw const MindSpaceAccessException(
        'Inicia sesión con Supabase para acceder a tu espacio privado.',
      );
    }
    return userId;
  }

  @override
  Future<List<MoodEntry>> fetchMoods() async {
    final client = _client;
    final userId = _userId;
    final entries = <MoodEntry>[];
    var offset = 0;

    while (true) {
      final rows = await client
          .from('mood_entries')
          .select('id, mood, note, created_at')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .order('id', ascending: false)
          .range(offset, offset + _pageSize - 1)
          .timeout(_requestTimeout);
      entries.addAll(rows.map(_moodFromRow));
      if (rows.length < _pageSize) return entries;
      offset += _pageSize;
    }
  }

  @override
  Future<List<DiaryEntry>> fetchDiaryEntries() async {
    final client = _client;
    final userId = _userId;
    final entries = <DiaryEntry>[];
    var offset = 0;

    while (true) {
      final rows = await client
          .from('diary_entries')
          .select('id, title, body, created_at')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .order('id', ascending: false)
          .range(offset, offset + _pageSize - 1)
          .timeout(_requestTimeout);
      entries.addAll(rows.map(_diaryFromRow));
      if (rows.length < _pageSize) return entries;
      offset += _pageSize;
    }
  }

  @override
  Future<MoodEntry> createMood({
    required String mood,
    required String note,
  }) async {
    final row = await _client
        .from('mood_entries')
        .insert({'user_id': _userId, 'mood': mood, 'note': note})
        .select('id, mood, note, created_at')
        .single()
        .timeout(_requestTimeout);
    return _moodFromRow(row);
  }

  @override
  Future<DiaryEntry> createDiary({
    required String title,
    required String body,
  }) async {
    final row = await _client
        .from('diary_entries')
        .insert({'user_id': _userId, 'title': title, 'body': body})
        .select('id, title, body, created_at')
        .single()
        .timeout(_requestTimeout);
    return _diaryFromRow(row);
  }

  @override
  Future<DiaryEntry> updateDiary({
    required String id,
    required String title,
    required String body,
  }) async {
    final row = await _client
        .from('diary_entries')
        .update({'title': title, 'body': body})
        .eq('id', id)
        .eq('user_id', _userId)
        .select('id, title, body, created_at')
        .maybeSingle()
        .timeout(_requestTimeout);
    if (row == null) {
      throw const MindSpaceAccessException(
        'No se encontró esa entrada o no tienes permiso para editarla.',
      );
    }
    return _diaryFromRow(row);
  }

  @override
  Future<void> deleteDiary(String id) async {
    final row = await _client
        .from('diary_entries')
        .delete()
        .eq('id', id)
        .eq('user_id', _userId)
        .select('id')
        .maybeSingle()
        .timeout(_requestTimeout);
    if (row == null) {
      throw const MindSpaceAccessException(
        'No se encontró esa entrada o no tienes permiso para eliminarla.',
      );
    }
  }

  MoodEntry _moodFromRow(Map<String, dynamic> row) => MoodEntry(
    id: row['id'] as String,
    mood: row['mood'] as String,
    note: row['note'] as String? ?? '',
    createdAt: DateTime.parse(row['created_at'] as String),
  );

  DiaryEntry _diaryFromRow(Map<String, dynamic> row) => DiaryEntry(
    id: row['id'] as String,
    title: row['title'] as String,
    body: row['body'] as String,
    createdAt: DateTime.parse(row['created_at'] as String),
  );
}

class MindSpaceAccessException implements Exception {
  const MindSpaceAccessException(this.message);

  final String message;

  @override
  String toString() => message;
}

String describeMindSpaceError(Object error) {
  if (error is MindSpaceAccessException) return error.message;
  if (error is AuthException) {
    return 'La sesión de Supabase no es válida. Inicia sesión de nuevo.';
  }
  if (error is PostgrestException) {
    final code = error.code;
    final message = error.message.toLowerCase();
    if (code == 'PGRST205') {
      return 'Supabase no encuentra la tabla de MindSpace ($code). '
          'Aplica la migración 004 y recarga el esquema de la API.';
    }
    if (code == '42501' || message.contains('row-level security')) {
      return 'Supabase rechazó la operación por permisos o RLS ($code). '
          'Confirma que hay una sesión activa y que las políticas permiten '
          'solo filas cuyo user_id coincide con auth.uid().';
    }
    return 'Falló una consulta de Supabase${code == null ? '' : ' ($code)'}: '
        '${error.message}';
  }
  if (error is TimeoutException) {
    return 'Supabase tardó demasiado en responder. Revisa la conexión e inténtalo de nuevo.';
  }
  return 'No se pudo completar la operación de MindSpace: $error';
}
