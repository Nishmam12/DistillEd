// Isar database singleton — opens and provides a shared Isar instance.

import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';

class IsarService {
  static Isar? _isar;

  /// Returns the shared Isar instance, opening the database on first call.
  /// [schemas] must contain all Isar collection schemas for the app.
  static Future<Isar> openDatabase(List<CollectionSchema<dynamic>> schemas) async {
    if (_isar != null && _isar!.isOpen) {
      return _isar!;
    }

    final dir = await getApplicationDocumentsDirectory();

    _isar = await Isar.open(
      schemas,
      directory: dir.path,
      name: 'inkflow',
    );

    return _isar!;
  }

  /// Returns the existing Isar instance. Throws if database has not been opened.
  static Isar get instance {
    if (_isar == null || !_isar!.isOpen) {
      throw StateError('Isar database has not been opened. Call openDatabase() first.');
    }
    return _isar!;
  }
}
