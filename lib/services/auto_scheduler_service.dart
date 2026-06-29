import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hesen/models/match_model.dart';
import 'package:hesen/services/notification_service.dart';
import 'package:hesen/services/favorite_teams_service.dart';

class AutoSchedulerService {
  static Future<void> autoScheduleFavoriteMatches(List<Match> matches) async {
    // الإشعارات المحلية غير مدعومة على الويب حالياً
    if (kIsWeb) return;

    try {
      final favoriteTeams = await FavoriteTeamsService.getFavoriteTeams();
      if (favoriteTeams.isEmpty) {
        debugPrint('[AUTO SCHEDULER] No favorite teams set yet.');
        return;
      }

      debugPrint('[AUTO SCHEDULER] Checking matches for favorite teams: $favoriteTeams');
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();

      for (var match in matches) {
        final teamA = match.teamA.trim();
        final teamB = match.teamB.trim();

        // التحقق مما إذا كان أي من الفريقين في قائمة المفضلات
        final isTeamAFavorite = favoriteTeams.contains(teamA);
        final isTeamBFavorite = favoriteTeams.contains(teamB);

        if (isTeamAFavorite || isTeamBFavorite) {
          // التحقق مما إذا كان هناك تنبيه مجدول بالفعل لهذه المباراة
          final isAlreadyScheduled = prefs.getBool('reminder_${match.id}') ?? false;
          if (isAlreadyScheduled) {
            continue;
          }

          // حساب توقيت المباراة
          final matchDateTime = DateFormat('HH:mm').parse(match.matchTime);
          var matchDateTimeWithToday = DateTime(
            now.year, now.month, now.day,
            matchDateTime.hour, matchDateTime.minute,
          );

          // معالجة المباريات التي تتخطى منتصف الليل
          if (matchDateTimeWithToday.isBefore(now) &&
              now.difference(matchDateTimeWithToday) >
                  const Duration(minutes: 180)) {
            matchDateTimeWithToday = matchDateTimeWithToday
                .add(const Duration(days: 1));
          }

          // التنبيه قبل المباراة بدقيقة واحدة
          DateTime reminderTime = matchDateTimeWithToday.subtract(const Duration(minutes: 1));
          bool isImmediate = false;
          
          if (reminderTime.isBefore(now)) {
            // إذا كان وقت التنبيه قد مر ولكن المباراة لم تبدأ بعد، نجدول التنبيه ليبدأ بعد 5 ثوانٍ
            if (matchDateTimeWithToday.isAfter(now)) {
              reminderTime = now.add(const Duration(seconds: 5));
              isImmediate = true;
            } else {
              // المباراة بدأت بالفعل
              continue;
            }
          }

          // جدولة الإشعار
          final success = await NotificationService.scheduleMatchReminder(
            id: match.id,
            title: 'مباراة على وشك البدء ⚽',
            body: isImmediate
                ? 'مباراة $teamA ضد $teamB تبدأ الآن، استعد للمشاهدة!'
                : 'مباراة $teamA ضد $teamB ستبدأ بعد دقيقة واحدة، استعد للمشاهدة!',
            scheduledTime: reminderTime,
          );

          if (success) {
            await prefs.setBool('reminder_${match.id}', true);
            debugPrint('[AUTO SCHEDULER] Automatically scheduled reminder for: $teamA vs $teamB at $reminderTime');
          }
        }
      }
    } catch (e) {
      debugPrint('[AUTO SCHEDULER] Error during auto scheduling: $e');
    }
  }
}
