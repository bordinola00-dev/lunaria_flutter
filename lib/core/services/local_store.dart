import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/models/lunaria_models.dart';
import 'supabase_config.dart';
import 'supabase_repository.dart';

class LunariaStore extends ChangeNotifier {
  LunariaStore();

  static const _key = 'lunaria_store_v1';
  final _supabase = LunariaSupabaseRepository();

  String name = 'Luna';
  List<String> interests = const [];
  bool onboardingComplete = false;
  bool authenticated = false;
  List<MoodEntry> moods = [];
  List<DiaryEntry> diaries = [];
  List<BeautyProduct> products = [];
  List<BeautyLook> looks = [];
  List<Song> songs = [];
  List<Playlist> playlists = [];
  List<DailyRoutine> routines = [];
  String? dailyMood;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      name = json['name'] as String? ?? 'Luna';
      interests = (json['interests'] as List<dynamic>? ?? const [])
          .map((value) => value as String)
          .toList();
      onboardingComplete = json['onboardingComplete'] as bool? ?? false;
      authenticated = json['authenticated'] as bool? ?? false;
      moods = (json['moods'] as List<dynamic>? ?? const [])
          .map(
            (value) =>
                MoodEntry.fromJson(Map<String, dynamic>.from(value as Map)),
          )
          .toList();
      diaries = (json['diaries'] as List<dynamic>? ?? const [])
          .map(
            (value) =>
                DiaryEntry.fromJson(Map<String, dynamic>.from(value as Map)),
          )
          .toList();
      products = (json['products'] as List<dynamic>? ?? const [])
          .map(
            (value) =>
                BeautyProduct.fromJson(Map<String, dynamic>.from(value as Map)),
          )
          .toList();
      looks = (json['looks'] as List<dynamic>? ?? const [])
          .map(
            (value) =>
                BeautyLook.fromJson(Map<String, dynamic>.from(value as Map)),
          )
          .toList();
      songs = (json['songs'] as List<dynamic>? ?? const [])
          .map(
            (value) => Song.fromJson(Map<String, dynamic>.from(value as Map)),
          )
          .toList();
      playlists = (json['playlists'] as List<dynamic>? ?? const [])
          .map(
            (value) =>
                Playlist.fromJson(Map<String, dynamic>.from(value as Map)),
          )
          .toList();
      routines = (json['routines'] as List<dynamic>? ?? const [])
          .map(
            (value) =>
                DailyRoutine.fromJson(Map<String, dynamic>.from(value as Map)),
          )
          .toList();
    }

    final client = supabase;
    if (client != null) {
      authenticated = client.auth.currentSession != null;
    }
    dailyMood = _todaysMood()?.mood;
    notifyListeners();
  }

  Future<void> loadHomeData() async {
    if (supabase?.auth.currentSession == null) return;
    final date = _todayDate();
    final results = await Future.wait([
      _supabase.fetchDailyMood(date),
      _supabase.fetchRoutines(),
    ]);
    dailyMood = results[0] as String?;
    routines = results[1] as List<DailyRoutine>;
    await _save();
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode({
        'name': name,
        'interests': interests,
        'onboardingComplete': onboardingComplete,
        'authenticated': authenticated,
        'moods': moods.map((value) => value.toJson()).toList(),
        'diaries': diaries.map((value) => value.toJson()).toList(),
        'products': products.map((value) => value.toJson()).toList(),
        'looks': looks.map((value) => value.toJson()).toList(),
        'songs': songs.map((value) => value.toJson()).toList(),
        'playlists': playlists.map((value) => value.toJson()).toList(),
        'routines': routines.map((value) => value.toJson()).toList(),
      }),
    );
  }

  Future<void> setDailyMood(String mood, {String note = ''}) async {
    final date = _todayDate();
    final current = _todaysMood();
    final savedNote = note.isEmpty ? current?.note ?? '' : note;
    if (supabase?.auth.currentSession != null) {
      await _supabase.upsertDailyMood(date: date, mood: mood, note: savedNote);
    }

    if (current == null) {
      moods.insert(
        0,
        MoodEntry(
          id: '${DateTime.now().microsecondsSinceEpoch}',
          mood: mood,
          note: savedNote,
          createdAt: DateTime.now(),
          entryDate: date,
        ),
      );
    } else {
      final index = moods.indexOf(current);
      moods[index] = MoodEntry(
        id: current.id,
        mood: mood,
        note: savedNote,
        createdAt: current.createdAt,
        entryDate: date,
      );
    }
    dailyMood = mood;
    await _save();
    notifyListeners();
  }

  Future<void> createRoutine({
    required String title,
    required String description,
  }) async {
    final date = _todayDate();
    final remoteSession = supabase?.auth.currentSession != null;
    final routine = remoteSession
        ? await _supabase.insertRoutine(
            title: title,
            description: description,
            date: date,
          )
        : DailyRoutine(
            id: '${DateTime.now().microsecondsSinceEpoch}',
            title: title,
            description: description,
            routineDate: date,
            createdAt: DateTime.now(),
          );
    routines.insert(0, routine);
    await _save();
    notifyListeners();
  }

  Future<void> completeRoutine(String id) async {
    final index = routines.indexWhere((routine) => routine.id == id);
    if (index < 0 || routines[index].isCompleted) return;

    final old = routines[index];
    final updated = supabase?.auth.currentSession != null
        ? await _supabase.completeRoutine(id)
        : DailyRoutine(
            id: old.id,
            title: old.title,
            description: old.description,
            routineDate: old.routineDate,
            createdAt: old.createdAt,
            completedAt: DateTime.now(),
          );
    routines[index] = updated;
    await _save();
    notifyListeners();
  }

  MoodEntry? _todaysMood() {
    final today = _todayDate();
    for (final entry in moods) {
      if (entry.entryDate == today) return entry;
    }
    return null;
  }

  String _todayDate() {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '${now.year}-$month-$day';
  }

  Future<void> completeOnboarding(List<String> selected) async {
    interests = selected;
    onboardingComplete = true;
    await _save();
    notifyListeners();
  }

  Future<void> authenticate(String displayName) async {
    name = displayName.trim().isEmpty ? name : displayName.trim();
    authenticated = true;
    await _save();
    if (isSupabaseConfigured && supabase?.auth.currentSession != null) {
      await _supabase.upsertProfile(name: name, interests: interests);
    }
    notifyListeners();
  }

  Future<void> logout() async {
    authenticated = false;
    await _save();
    notifyListeners();
  }

  Future<void> setName(String value) async {
    name = value.trim();
    await _save();
    if (isSupabaseConfigured && supabase?.auth.currentSession != null) {
      await _supabase.upsertProfile(name: name, interests: interests);
    }
    notifyListeners();
  }

  Future<void> addMood(String mood, {String note = ''}) async {
    moods.insert(
      0,
      MoodEntry(
        id: '${DateTime.now().microsecondsSinceEpoch}',
        mood: mood,
        note: note,
        createdAt: DateTime.now(),
      ),
    );
    await _save();
    if (isSupabaseConfigured && supabase?.auth.currentSession != null) {
      await _supabase.insertMood(mood: mood, note: note);
    }
    notifyListeners();
  }

  Future<void> addDiary(String title, String body) async {
    diaries.insert(
      0,
      DiaryEntry(
        id: '${DateTime.now().microsecondsSinceEpoch}',
        title: title,
        body: body,
        createdAt: DateTime.now(),
      ),
    );
    await _save();
    if (isSupabaseConfigured && supabase?.auth.currentSession != null) {
      await _supabase.insertDiary(title: title, body: body);
    }
    notifyListeners();
  }

  Future<void> deleteDiary(String id) async {
    diaries.removeWhere((entry) => entry.id == id);
    await _save();
    if (isSupabaseConfigured && supabase?.auth.currentSession != null) {
      await _supabase.deleteDiary(id);
    }
    notifyListeners();
  }

  Future<void> addProduct({
    required String name,
    required String brand,
    required String category,
    required String shade,
  }) async {
    products.insert(
      0,
      BeautyProduct(
        id: '${DateTime.now().microsecondsSinceEpoch}',
        name: name,
        brand: brand,
        category: category,
        shade: shade,
        createdAt: DateTime.now(),
      ),
    );
    await _save();
    if (isSupabaseConfigured && supabase?.auth.currentSession != null) {
      await _supabase.insertProduct(
        name: name,
        brand: brand,
        category: category,
        shade: shade,
      );
    }
    notifyListeners();
  }

  Future<void> addLook(String name, String description) async {
    looks.insert(
      0,
      BeautyLook(
        id: '${DateTime.now().microsecondsSinceEpoch}',
        name: name,
        description: description,
        createdAt: DateTime.now(),
      ),
    );
    await _save();
    if (isSupabaseConfigured && supabase?.auth.currentSession != null) {
      await _supabase.insertLook(name: name, description: description);
    }
    notifyListeners();
  }

  Future<void> addSong(String title, String artist, String url) async {
    songs.insert(
      0,
      Song(
        id: '${DateTime.now().microsecondsSinceEpoch}',
        title: title,
        artist: artist,
        url: url,
        createdAt: DateTime.now(),
      ),
    );
    await _save();
    if (isSupabaseConfigured && supabase?.auth.currentSession != null) {
      await _supabase.insertSong(title: title, artist: artist, url: url);
    }
    notifyListeners();
  }

  Future<void> addPlaylist(String name, String url) async {
    playlists.insert(
      0,
      Playlist(
        id: '${DateTime.now().microsecondsSinceEpoch}',
        name: name,
        url: url,
        createdAt: DateTime.now(),
      ),
    );
    await _save();
    if (isSupabaseConfigured && supabase?.auth.currentSession != null) {
      await _supabase.insertPlaylist(name: name, url: url);
    }
    notifyListeners();
  }
}
