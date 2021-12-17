import 'package:logger/logger.dart' as logger;
import 'package:logging/logging.dart' show Logger, Level;

void setupLogging() {
  Logger.root.level = Level.ALL; // defaults to Level.INFO
  var pretty = logger.Logger(
      filter: logger.ProductionFilter(), level: logger.Level.verbose);
  Logger.root.onRecord.listen((record) {
    logger.Level level;
    if (record.level == Level.INFO) {
      level = logger.Level.info;
    } else if (record.level == Level.FINE) {
      level = logger.Level.debug;
    } else {
      level = logger.Level.wtf;
    }
    pretty.log(level, record.message, record.error, record.stackTrace);
  });
}
