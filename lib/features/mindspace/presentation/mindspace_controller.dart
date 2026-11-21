import 'package:flutter/foundation.dart';

import '../../../shared/models/lunaria_models.dart';
import '../data/mindspace_repository.dart';

class MindSpaceController extends ChangeNotifier {
  MindSpaceController(this._repository);

  final MindSpaceRepository _repository;

  List<MoodEntry> moods = const [];
  List<DiaryEntry> diaries = const [];
  Object? loadError;
  bool isLoading = true;
  bool isSavingMood = false;
  bool isSavingDiary = false;
  bool isDeletingDiary = false;
  bool _disposed = false;

  Future<void> load() async {
    isLoading = true;
    loadError = null;
    _notify();
    try {
      moods = await _repository.fetchMoods();
      _notify();
      final loadedDiaries = await _repository.fetchDiaryEntries();
      diaries = loadedDiaries;
    } catch (error) {
      loadError = error;
    } finally {
      isLoading = false;
      _notify();
    }
  }

  Future<void> addMood({required String mood, required String note}) async {
    if (isSavingMood) return;
    isSavingMood = true;
    _notify();
    try {
      final entry = await _repository.createMood(mood: mood, note: note);
      moods = [entry, ...moods];
    } finally {
      isSavingMood = false;
      _notify();
    }
  }

  Future<void> addDiary({required String title, required String body}) async {
    if (isSavingDiary) return;
    isSavingDiary = true;
    _notify();
    try {
      final entry = await _repository.createDiary(title: title, body: body);
      diaries = [entry, ...diaries];
    } finally {
      isSavingDiary = false;
      _notify();
    }
  }

  Future<void> updateDiary({
    required String id,
    required String title,
    required String body,
  }) async {
    if (isSavingDiary) return;
    isSavingDiary = true;
    _notify();
    try {
      final updated = await _repository.updateDiary(
        id: id,
        title: title,
        body: body,
      );
      diaries = [
        for (final entry in diaries)
          if (entry.id == id) updated else entry,
      ];
    } finally {
      isSavingDiary = false;
      _notify();
    }
  }

  Future<void> deleteDiary(String id) async {
    if (isDeletingDiary) return;
    isDeletingDiary = true;
    _notify();
    try {
      await _repository.deleteDiary(id);
      diaries = diaries.where((entry) => entry.id != id).toList();
    } finally {
      isDeletingDiary = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
