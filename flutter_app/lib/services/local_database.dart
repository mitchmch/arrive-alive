import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

/// Local SQLite database for offline-first caching.
/// Tables: journeys, speed_samples, violations, incidents, agencies,
/// cached_routes, sync_queue
class LocalDatabase {
  static final LocalDatabase _instance = LocalDatabase._();
  factory LocalDatabase() => _instance;
  LocalDatabase._();

  Database? _db;

  /// Get the database instance, initializing if needed
  Future<Database> get database async {
    _db ??= await _init();
    return _db!;
  }

  Future<Database> _init() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'arrive_alive.db');

    return openDatabase(
      path,
      version: 5,
      onCreate: (db, version) async {
        // Journeys table — localId is primary, remoteId is the server-assigned ID
        await db.execute('''
          CREATE TABLE journeys (
            localId TEXT PRIMARY KEY,
            remoteId INTEGER,
            userId INTEGER,
            mode TEXT NOT NULL,
            vehicleDetails TEXT NOT NULL,
            assets TEXT,
            defects TEXT,
            driverName TEXT,
            passengerCount INTEGER DEFAULT 1,
            agencyId INTEGER,
            frozenSpeedLimit REAL NOT NULL,
            speedLimitMode TEXT NOT NULL,
            speedLimitSelectedAt TEXT NOT NULL,
            startTime TEXT NOT NULL,
            endTime TEXT,
            status TEXT DEFAULT 'active',
            maxSpeed REAL DEFAULT 0,
            distance REAL DEFAULT 0,
            violationCount INTEGER DEFAULT 0,
            score INTEGER DEFAULT 100,
            path TEXT,
            violations TEXT,
            synced INTEGER DEFAULT 0,
            updatedAt TEXT,
            version INTEGER DEFAULT 1
          )
        ''');

        // Violations table
        await db.execute('''
          CREATE TABLE violations (
            localId TEXT PRIMARY KEY,
            remoteId INTEGER,
            journeyLocalId TEXT,
            journeyRemoteId INTEGER,
            vehicleReg TEXT NOT NULL,
            mode TEXT NOT NULL,
            agencyId INTEGER,
            speed REAL NOT NULL,
            speedLimit REAL NOT NULL,
            lat REAL NOT NULL,
            lng REAL NOT NULL,
            reportCount INTEGER DEFAULT 1,
            episodeStartedAt TEXT,
            episodeEndedAt TEXT,
            sampleCount INTEGER DEFAULT 1,
            timestamp TEXT NOT NULL,
            synced INTEGER DEFAULT 0,
            updatedAt TEXT,
            version INTEGER DEFAULT 1
          )
        ''');

        await _createSpeedSamplesTable(db);

        // Incidents table — cached from server for offline viewing
        await db.execute('''
          CREATE TABLE incidents (
            id INTEGER PRIMARY KEY,
            type TEXT NOT NULL,
            description TEXT,
            lat REAL,
            lng REAL,
            vehicleReg TEXT,
            driverName TEXT,
            timestamp TEXT NOT NULL,
            status TEXT DEFAULT 'active',
            confirmationCount INTEGER DEFAULT 0,
            notThereCount INTEGER DEFAULT 0,
            lastConfirmedAt TEXT,
            resolvedAt TEXT,
            userConfirmedStillThere INTEGER,
            isLocal INTEGER DEFAULT 0,
            cachedAt TEXT NOT NULL
          )
        ''');

        // Agencies table — cached from server
        await db.execute('''
          CREATE TABLE agencies (
            id INTEGER PRIMARY KEY,
            name TEXT NOT NULL,
            region TEXT,
            phone TEXT,
            safetyScore REAL DEFAULT 100,
            violationCount INTEGER DEFAULT 0,
            totalJourneys INTEGER DEFAULT 0,
            cachedAt TEXT NOT NULL
          )
        ''');

        // Cached routes — store recent route lookups for offline reuse
        await db.execute('''
          CREATE TABLE cached_routes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            originLat REAL NOT NULL,
            originLng REAL NOT NULL,
            destLat REAL NOT NULL,
            destLng REAL NOT NULL,
            destinationName TEXT,
            polylineText TEXT NOT NULL,
            distanceMeters INTEGER,
            durationSeconds INTEGER,
            instructions TEXT,
            cachedAt TEXT NOT NULL
          )
        ''');

        // Sync queue — operations to retry when back online
        await db.execute('''
          CREATE TABLE sync_queue (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            operation TEXT NOT NULL,
            endpoint TEXT NOT NULL,
            method TEXT NOT NULL,
            body TEXT NOT NULL,
            dependsOn TEXT,
            createdAt TEXT NOT NULL,
            attempts INTEGER DEFAULT 0,
            operationId TEXT,
            state TEXT DEFAULT 'pending',
            lastError TEXT,
            nextAttemptAt TEXT
          )
        ''');

        // Indexes for faster queries
        await db.execute(
          'CREATE INDEX idx_journeys_remote ON journeys(remoteId)',
        );
        await db.execute(
          'CREATE INDEX idx_violations_journey ON violations(journeyLocalId)',
        );
        await db.execute(
          'CREATE INDEX idx_speed_samples_journey '
          'ON speed_samples(journeyLocalId, recordedAt)',
        );
        await db.execute(
          'CREATE INDEX idx_incidents_cached ON incidents(cachedAt)',
        );
        await db.execute(
          'CREATE INDEX idx_sync_queue_depends ON sync_queue(dependsOn)',
        );
        await db.execute(
          'CREATE UNIQUE INDEX idx_sync_queue_operation_id '
          'ON sync_queue(operationId)',
        );
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE incidents ADD COLUMN confirmationCount INTEGER DEFAULT 0',
          );
          await db.execute(
            'ALTER TABLE incidents ADD COLUMN notThereCount INTEGER DEFAULT 0',
          );
          await db.execute(
            'ALTER TABLE incidents ADD COLUMN lastConfirmedAt TEXT',
          );
          await db.execute('ALTER TABLE incidents ADD COLUMN resolvedAt TEXT');
          await db.execute(
            'ALTER TABLE incidents ADD COLUMN userConfirmedStillThere INTEGER',
          );
          await db.execute(
            'ALTER TABLE incidents ADD COLUMN isLocal INTEGER DEFAULT 0',
          );
        }
        if (oldVersion < 3) {
          await db.execute('ALTER TABLE journeys ADD COLUMN updatedAt TEXT');
          await db.execute(
            'ALTER TABLE journeys ADD COLUMN version INTEGER DEFAULT 1',
          );
          await db.execute('ALTER TABLE violations ADD COLUMN updatedAt TEXT');
          await db.execute(
            'ALTER TABLE violations ADD COLUMN version INTEGER DEFAULT 1',
          );
          await db
              .execute('ALTER TABLE sync_queue ADD COLUMN operationId TEXT');
          await db.execute(
            "ALTER TABLE sync_queue ADD COLUMN state TEXT DEFAULT 'pending'",
          );
          await db.execute('ALTER TABLE sync_queue ADD COLUMN lastError TEXT');
          await db.execute(
            'ALTER TABLE sync_queue ADD COLUMN nextAttemptAt TEXT',
          );
          await db.execute(
            'CREATE UNIQUE INDEX idx_sync_queue_operation_id '
            'ON sync_queue(operationId)',
          );
        }
        if (oldVersion < 4) {
          await db.execute(
            'ALTER TABLE violations ADD COLUMN episodeStartedAt TEXT',
          );
          await db.execute(
            'ALTER TABLE violations ADD COLUMN episodeEndedAt TEXT',
          );
          await db.execute(
            'ALTER TABLE violations ADD COLUMN sampleCount INTEGER DEFAULT 1',
          );
          await _createSpeedSamplesTable(db);
          await db.execute(
            'CREATE INDEX idx_speed_samples_journey '
            'ON speed_samples(journeyLocalId, recordedAt)',
          );
        }
        if (oldVersion < 5) {
          await db.execute(
            'ALTER TABLE journeys ADD COLUMN frozenSpeedLimit REAL',
          );
          await db.execute(
            'ALTER TABLE journeys ADD COLUMN speedLimitMode TEXT',
          );
          await db.execute(
            'ALTER TABLE journeys ADD COLUMN speedLimitSelectedAt TEXT',
          );
          await db.execute(
            'UPDATE journeys SET frozenSpeedLimit = 70 '
            'WHERE frozenSpeedLimit IS NULL',
          );
          await db.execute(
            'UPDATE journeys SET speedLimitMode = mode '
            'WHERE speedLimitMode IS NULL',
          );
          await db.execute(
            'UPDATE journeys SET speedLimitSelectedAt = startTime '
            'WHERE speedLimitSelectedAt IS NULL',
          );
        }
      },
    );
  }

  static Future<void> _createSpeedSamplesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS speed_samples (
        localId TEXT PRIMARY KEY,
        remoteId INTEGER,
        journeyLocalId TEXT NOT NULL,
        journeyRemoteId INTEGER,
        recordedAt TEXT NOT NULL,
        speed REAL NOT NULL,
        speedLimit REAL NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        accuracy REAL NOT NULL,
        isMoving INTEGER NOT NULL,
        synced INTEGER DEFAULT 0
      )
    ''');
  }

  // === Journeys ===

  Future<String> insertJourney(Map<String, dynamic> journey) async {
    final db = await database;
    final localId = journey['localId'] as String;
    await db.insert(
      'journeys',
      journey,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return localId;
  }

  Future<void> updateJourney(
    String localId,
    Map<String, dynamic> updates,
  ) async {
    final db = await database;
    await db.update(
      'journeys',
      updates,
      where: 'localId = ?',
      whereArgs: [localId],
    );
  }

  Future<List<Map<String, dynamic>>> getLocalJourneys(int? userId) async {
    final db = await database;
    if (userId != null) {
      return db.query(
        'journeys',
        where: 'userId = ?',
        whereArgs: [userId],
        orderBy: 'startTime DESC',
      );
    }
    return db.query('journeys', orderBy: 'startTime DESC');
  }

  Future<Map<String, dynamic>?> getJourneyByLocalId(String localId) async {
    final db = await database;
    final results = await db.query(
      'journeys',
      where: 'localId = ?',
      whereArgs: [localId],
    );
    return results.isEmpty ? null : results.first;
  }

  // === Violations ===

  Future<String> insertSpeedSample(Map<String, dynamic> sample) async {
    final db = await database;
    final localId = sample['localId'] as String;
    await db.insert(
      'speed_samples',
      sample,
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    return localId;
  }

  Future<void> updateSpeedSample(
    String localId,
    Map<String, dynamic> updates,
  ) async {
    final db = await database;
    await db.update(
      'speed_samples',
      updates,
      where: 'localId = ?',
      whereArgs: [localId],
    );
  }

  Future<List<Map<String, dynamic>>> getJourneySpeedSamples(
    String journeyLocalId,
  ) async {
    final db = await database;
    return db.query(
      'speed_samples',
      where: 'journeyLocalId = ?',
      whereArgs: [journeyLocalId],
      orderBy: 'recordedAt ASC',
    );
  }

  Future<void> markJourneyEvidenceSynced(String journeyLocalId) async {
    final db = await database;
    final batch = db.batch();
    batch.update(
      'speed_samples',
      {'synced': 1},
      where: 'journeyLocalId = ?',
      whereArgs: [journeyLocalId],
    );
    batch.update(
      'violations',
      {'synced': 1},
      where: 'journeyLocalId = ?',
      whereArgs: [journeyLocalId],
    );
    await batch.commit(noResult: true);
  }

  Future<String> insertViolation(Map<String, dynamic> violation) async {
    final db = await database;
    final localId = violation['localId'] as String;
    await db.insert(
      'violations',
      violation,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return localId;
  }

  Future<List<Map<String, dynamic>>> getLocalViolations(
    String? journeyLocalId,
  ) async {
    final db = await database;
    if (journeyLocalId != null) {
      return db.query(
        'violations',
        where: 'journeyLocalId = ?',
        whereArgs: [journeyLocalId],
      );
    }
    return db.query('violations', orderBy: 'timestamp DESC');
  }

  Future<void> updateViolation(
    String localId,
    Map<String, dynamic> updates,
  ) async {
    final db = await database;
    await db.update(
      'violations',
      updates,
      where: 'localId = ?',
      whereArgs: [localId],
    );
  }

  // === Incidents (cached from server) ===

  Future<void> cacheIncidents(List<Map<String, dynamic>> incidents) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final batch = db.batch();
    // The incidents endpoint represents the current live set. Replacing the
    // cache prevents hazards resolved on the server from reappearing offline.
    batch.delete('incidents');
    for (final inc in incidents) {
      batch.insert(
          'incidents',
          {
            ...inc,
            'cachedAt': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> updateCachedIncident(
    int id,
    Map<String, dynamic> updates,
  ) async {
    final db = await database;
    await db.update('incidents', updates, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> removeCachedIncident(int id) async {
    final db = await database;
    await db.delete('incidents', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getCachedIncidents({
    int limit = 200,
  }) async {
    final db = await database;
    return db.query('incidents', orderBy: 'timestamp DESC', limit: limit);
  }

  Future<void> clearOldIncidents({int keepDays = 7}) async {
    final db = await database;
    final cutoff =
        DateTime.now().subtract(Duration(days: keepDays)).toIso8601String();
    await db.delete('incidents', where: 'cachedAt < ?', whereArgs: [cutoff]);
  }

  // === Agencies (cached from server) ===

  Future<void> cacheAgencies(List<Map<String, dynamic>> agencies) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final batch = db.batch();
    for (final a in agencies) {
      batch.insert(
          'agencies',
          {
            ...a,
            'cachedAt': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getCachedAgencies() async {
    final db = await database;
    return db.query('agencies', orderBy: 'safetyScore ASC');
  }

  // === Cached Routes ===

  Future<void> cacheRoute(Map<String, dynamic> route) async {
    final db = await database;
    await db.insert('cached_routes', {
      ...route,
      'cachedAt': DateTime.now().toIso8601String(),
    });
  }

  Future<Map<String, dynamic>?> getCachedRoute(
    double originLat,
    double originLng,
    double destLat,
    double destLng,
  ) async {
    final db = await database;
    final results = await db.query(
      'cached_routes',
      where: 'originLat = ? AND originLng = ? AND destLat = ? AND destLng = ?',
      whereArgs: [originLat, originLng, destLat, destLng],
      orderBy: 'cachedAt DESC',
      limit: 1,
    );
    return results.isEmpty ? null : results.first;
  }

  // === Sync Queue ===

  Future<int> enqueueSync(Map<String, dynamic> operation) async {
    final db = await database;
    return db.insert(
        'sync_queue',
        {
          ...operation,
          'createdAt': DateTime.now().toIso8601String(),
          'attempts': 0,
          'state': 'pending',
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<List<Map<String, dynamic>>> getSyncQueue() async {
    final db = await database;
    return db.query(
      'sync_queue',
      where: "state IN ('pending', 'retrying')",
      orderBy: 'createdAt ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getAllSyncQueue() async {
    final db = await database;
    return db.query('sync_queue', orderBy: 'createdAt ASC');
  }

  Future<void> updateSyncQueueItem(int id, Map<String, dynamic> updates) async {
    final db = await database;
    await db.update('sync_queue', updates, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> removeSyncQueueItem(int id) async {
    final db = await database;
    await db.delete('sync_queue', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> incrementSyncAttempts(int id) async {
    final db = await database;
    await db.rawUpdate(
      'UPDATE sync_queue SET attempts = attempts + 1 WHERE id = ?',
      [id],
    );
  }

  Future<void> markSyncRetry(
    int id, {
    required String error,
    required DateTime nextAttemptAt,
  }) async {
    final db = await database;
    await db.rawUpdate(
      "UPDATE sync_queue SET attempts = attempts + 1, state = 'retrying', "
      'lastError = ?, nextAttemptAt = ? WHERE id = ?',
      [error, nextAttemptAt.toIso8601String(), id],
    );
  }

  Future<void> markSyncFailed(int id, String error) async {
    await updateSyncQueueItem(id, {
      'state': 'failed',
      'lastError': error,
      'nextAttemptAt': null,
    });
  }

  Future<void> retryFailedSync() async {
    final db = await database;
    await db.update(
      'sync_queue',
      {'state': 'pending', 'attempts': 0, 'lastError': null},
      where: "state = 'failed'",
    );
  }

  /// Close the database connection
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
