import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SystemLogService extends ChangeNotifier {
  static final List<String> _logs = [];
  static const int _maxLogs = 500;

  static void log(String message) {
    final timestamp = DateTime.now().toString().split('.').first;
    final logEntry = '[$timestamp] $message';
    
    // In-memory logs for UI
    _logs.insert(0, logEntry);
    if (_logs.length > _maxLogs) {
      _logs.removeLast();
    }

    // Always print to console for dev
    debugPrint(logEntry);

    // Persist to file on Desktop
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      _writeToLogFile(logEntry);
    }
  }

  static List<String> get logs => List.unmodifiable(_logs);

  static Future<void> _writeToLogFile(String entry) async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final logFile = File('${docDir.path}/lda_pos_system_logs.txt');
      await logFile.writeAsString('$entry\n', mode: FileMode.append);
    } catch (e) {
      debugPrint('Failed to write to log file: $e');
    }
  }

  static Future<String> getLogFilePath() async {
    if (kIsWeb) return 'Not available on Web';
    final docDir = await getApplicationDocumentsDirectory();
    return '${docDir.path}/lda_pos_system_logs.txt';
  }

  static void clear() {
    _logs.clear();
  }
}

final systemLogsProvider = Provider((ref) => SystemLogService.logs);
final systemLogsRefreshProvider = StateProvider((ref) => 0);
