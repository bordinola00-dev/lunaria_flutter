import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/models/lunaria_models.dart';
import 'supabase_config.dart';

class LunariaSupabaseRepository {
  LunariaSupabaseRepository();

  SupabaseClient get _client {
    final client = supabase;
    if (client == null) {
      throw StateError('Supabase no está configurado.');
    }
    return client;
  }

  String get userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw StateError('No hay una sesión activa.');
    return id;
  }

  Future<void> upsertProfile({
    required String name,
    required List<String> interests,
  }) async {
    await _client.from('profiles').upsert({
      'id': userId,
      'name': name,
      'interests': interests,
    });
  }

  Future<void> insertMood({required String mood, required String note}) async {
    await _client.from('mood_entries').insert({
      'user_id': userId,
      'mood': mood,
      'note': note,
    });
  }

  Future<void> insertDiary({
    required String title,
    required String body,
  }) async {
    await _client.from('diary_entries').insert({
      'user_id': userId,
      'title': title,
      'body': body,
    });
  }

  Future<void> deleteDiary(String id) async {
    await _client
        .from('diary_entries')
        .delete()
        .eq('id', id)
        .eq('user_id', userId);
  }

  Future<String?> fetchDailyMood(String date) async {
    final row = await _client
        .from('mood_entries')
        .select('mood')
        .eq('user_id', userId)
        .eq('entry_date', date)
        .maybeSingle();
    return row?['mood'] as String?;
  }

  Future<void> upsertDailyMood({
    required String date,
    required String mood,
    required String note,
  }) async {
    await _client.rpc(
      'set_daily_mood',
      params: {'p_mood': mood, 'p_note': note, 'p_entry_date': date},
    );
  }

  Future<List<DailyRoutine>> fetchRoutines() async {
    final rows = await _client
        .from('daily_routines')
        .select()
        .eq('user_id', userId)
        .order('routine_date', ascending: false)
        .order('created_at', ascending: false)
        .limit(200);
    return rows
        .map((row) => DailyRoutine.fromJson(_routineFromRow(row)))
        .toList();
  }

  Future<DailyRoutine> insertRoutine({
    required String title,
    required String description,
    required String date,
  }) async {
    final row = await _client
        .from('daily_routines')
        .insert({
          'user_id': userId,
          'title': title,
          'description': description,
          'routine_date': date,
        })
        .select()
        .single();
    return DailyRoutine.fromJson(_routineFromRow(row));
  }

  Future<DailyRoutine> completeRoutine(String id) async {
    final row = await _client
        .from('daily_routines')
        .update({'completed_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id)
        .eq('user_id', userId)
        .select()
        .single();
    return DailyRoutine.fromJson(_routineFromRow(row));
  }

  Map<String, dynamic> _routineFromRow(Map<String, dynamic> row) => {
    'id': row['id'],
    'title': row['title'],
    'description': row['description'],
    'routineDate': row['routine_date'],
    'createdAt': row['created_at'],
    'completedAt': row['completed_at'],
  };

  Future<void> insertProduct({
    required String name,
    required String brand,
    required String category,
    required String shade,
  }) async {
    await _client.from('beauty_products').insert({
      'user_id': userId,
      'name': name,
      'brand': brand,
      'category': category,
      'shade': shade,
    });
  }

  Future<void> insertLook({
    required String name,
    required String description,
  }) async {
    await _client.from('beauty_looks').insert({
      'user_id': userId,
      'name': name,
      'description': description,
    });
  }

  Future<void> insertSong({
    required String title,
    required String artist,
    required String url,
  }) async {
    await _client.from('songs').insert({
      'user_id': userId,
      'title': title,
      'artist': artist,
      'url': url,
    });
  }

  Future<void> insertPlaylist({
    required String name,
    required String url,
  }) async {
    await _client.from('playlists').insert({
      'user_id': userId,
      'name': name,
      'url': url,
    });
  }
}
