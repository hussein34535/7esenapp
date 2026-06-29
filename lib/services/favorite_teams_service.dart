import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class FavoriteTeamsService {
  static const String _favoritesKey = 'smart_favorite_teams';
  static const String _scorePrefix = 'team_score_';
  static const int favoriteThreshold = 3; // عدد مرات التفعيل لتصنيف الفريق كمفضل

  /// زيادة نقاط الفريق عند جدولة مباراة له
  static Future<void> incrementTeamScore(String teamName) async {
    if (teamName.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final cleanName = teamName.trim();
    final key = '$_scorePrefix$cleanName';
    
    int currentScore = prefs.getInt(key) ?? 0;
    currentScore++;
    await prefs.setInt(key, currentScore);
    debugPrint('[FAVORITE TEAMS] Incremented score for $cleanName to $currentScore');

    if (currentScore >= favoriteThreshold) {
      await addToFavorites(cleanName);
    }
  }

  /// تقليل نقاط الفريق عند إلغاء تفعيل تنبيه مباراة
  static Future<void> decrementTeamScore(String teamName) async {
    if (teamName.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final cleanName = teamName.trim();
    final key = '$_scorePrefix$cleanName';
    
    int currentScore = prefs.getInt(key) ?? 0;
    if (currentScore > 0) {
      currentScore--;
      await prefs.setInt(key, currentScore);
      debugPrint('[FAVORITE TEAMS] Decremented score for $cleanName to $currentScore');
    }

    if (currentScore < favoriteThreshold) {
      await removeFromFavorites(cleanName);
    }
  }

  /// إضافة فريق إلى قائمة المفضلات
  static Future<void> addToFavorites(String teamName) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> favorites = prefs.getStringList(_favoritesKey) ?? [];
    if (!favorites.contains(teamName)) {
      favorites.add(teamName);
      await prefs.setStringList(_favoritesKey, favorites);
      debugPrint('[FAVORITE TEAMS] Added $teamName to favorites list');
    }
  }

  /// إزالة فريق من قائمة المفضلات
  static Future<void> removeFromFavorites(String teamName) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> favorites = prefs.getStringList(_favoritesKey) ?? [];
    if (favorites.contains(teamName)) {
      favorites.remove(teamName);
      await prefs.setStringList(_favoritesKey, favorites);
      debugPrint('[FAVORITE TEAMS] Removed $teamName from favorites list');
    }
  }

  /// التحقق مما إذا كان الفريق مفضلاً للمستخدم
  static Future<bool> isFavoriteTeam(String teamName) async {
    if (teamName.isEmpty) return false;
    final prefs = await SharedPreferences.getInstance();
    List<String> favorites = prefs.getStringList(_favoritesKey) ?? [];
    return favorites.contains(teamName.trim());
  }

  /// الحصول على قائمة الفرق المفضلة بالكامل
  static Future<List<String>> getFavoriteTeams() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_favoritesKey) ?? [];
  }
}
