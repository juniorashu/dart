import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' show join;
import 'package:sqflite/sqlite_api.dart';

class DatabaseAlreadyOpenException implements Exception {}

class UnableToGetDocumentException implements Exception {}

class DatabaseIsNoteOpen implements Exception {}

class CouldNoteDeleteUser implements Exception {}

class UserAlreadyExists implements Exception {}

class CouldNoteFindNote implements Exception {}

class CouldNotUpdateNote implements Exception {}

class NotesService {
  Database? _db;

  
  Future<DatabaseNote> updateNote(
      {required DatabaseNote note, required String text}) async {
    final db = _getDatabaseOrthrow();
    await getNote(id: note.id);
    final updateCount =
        await db.update(noteTable, {textColumn: text, issyncColumn: 0});
    if (updateCount == 0) {
      throw CouldNotUpdateNote();
    } else {
      return await getNote(id: note.id);
    }
  }

  Future<Iterable<DatabaseNote>> getAllNotes() async {
    final db = _getDatabaseOrthrow();
    final notes = await db.query(
      noteTable,
    );
    return notes.map((noteRow) => DatabaseNote.fromRow(noteRow));
  }

  Future<DatabaseNote> getNote({required int id}) async {
    final db = _getDatabaseOrthrow();
    final notes = await db.query(
      noteTable,
      limit: 1,
      where: 'id=?',
      whereArgs: [id],
    );
    if (notes.isEmpty) {
      throw CouldNoteFindNote();
    } else {
      return DatabaseNote.fromRow(notes.first);
    }
  }

  Future<int> deleteAllNotes() async {
    final db = _getDatabaseOrthrow();
    return await db.delete(noteTable);
  }

  Future<void> deleteNote({required int id}) async {
    final db = _getDatabaseOrthrow();
    final deletedCount = await db.delete(
      noteTable,
      where: 'id=?',
      whereArgs: [id],
    );
    if (deletedCount == 0) {
      throw CouldNoteDeleteUser();
    }
  }

  Future<DatabaseNote> createNote({required DatabaseUser owner}) async {
    final db = _getDatabaseOrthrow();

    final dbUser = await getUser(email: owner.email);
    if (dbUser != owner) {
      throw CouldNoteDeleteUser();
    }
    const text = '';
    // create the note
    final noteId = await db.insert(noteTable, {
      useridColumn: owner.id,
      textColumn: text,
      issyncColumn: 1,
    });
    final note = DatabaseNote(
        id: noteId, userid: owner.id, text: text, issyncserver: true);
    return note;
  }

  Future<DatabaseUser> getUser({required String email}) async {
    final db = _getDatabaseOrthrow();
    final results = await db.query(
      userTable,
      limit: 1,
      where: 'email = ?',
      whereArgs: [email.toLowerCase()],
    );
    if (results.isEmpty) {
      throw CouldNoteDeleteUser();
    } else {
      return DatabaseUser.from(results.first);
    }
  }

  Future<DatabaseUser> createUser({required String email}) async {
    final db = _getDatabaseOrthrow();
    final result = await db.query(userTable,
        limit: 1, where: 'email = ?', whereArgs: [email.toLowerCase()]);
    if (result.isNotEmpty) {
      throw UserAlreadyExists();
    }
    final userid = await db.insert(userTable, {
      emailColumn: email.toLowerCase(),
    });
    return DatabaseUser(id: userid, email: email);
  }

  Future<void> deleteUser({required String email}) async {
    final db = _getDatabaseOrthrow();
    final deleteCount = await db.delete(userTable,
        where: 'Email = ?', whereArgs: [email.toLowerCase()]);
    if (deleteCount != 1) {
      throw CouldNoteDeleteUser();
    }
  }

  Database _getDatabaseOrthrow() {
    final db = _db;
    if (db == null) {
      throw DatabaseIsNoteOpen();
    } else {
      return db;
    }
  }

  Future<void> close() async {
    final db = _db;
    if (db == null) {
      throw DatabaseIsNoteOpen();
    } else {
      await db.close();
      _db = null;
    }
  }

  Future<void> open() async {
    if (_db != null) {
      throw DatabaseAlreadyOpenException();
    }
    try {
      final docspath = await getApplicationDocumentsDirectory();
      final dbpath = join(docspath.path, dbName);
      final db = await openDatabase(dbpath);
      _db = db;
      const createUserTable = '''CREATE TABLE IF NOT EXISTS "user" (
	"ID"	INTEGER NOT NULL,
	"email"	INTEGER NOT NULL UNIQUE,
	PRIMARY KEY("ID" AUTOINCREMENT)
);
''';
      await db.execute(createUserTable);
      const createNoteTable = '''CREATE TABLE IF NOT EXISTS "note" (
	"ID"	INTEGER NOT NULL,
	"USER_ID"	INTEGER NOT NULL,
	"TEXT"	TEXT,
	"IS_SYNC_SERVER"	INTEGER DEFAULT 0,
	PRIMARY KEY("ID" AUTOINCREMENT)
);
''';
      await db.execute(createNoteTable);
    } on MissingPlatformDirectoryException {
      throw UnableToGetDocumentException();
    }
  }
}

@immutable
class DatabaseUser {
  final int id;
  final String email;
  const DatabaseUser({
    required this.id,
    required this.email,
  });
  DatabaseUser.from(Map<String, Object?> map)
      : id = map[idColumn] as int,
        email = map[emailColumn] as String;

  @override
  // TODO: implement hashCode
  String toString() => 'person, ID = $id, email = $email ';
  @override
  bool operator ==(covariant DatabaseUser other) => id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class DatabaseNote {
  final int id;
  final int userid;
  final String text;
  final bool issyncserver;

  DatabaseNote({
    required this.id,
    required this.userid,
    required this.text,
    required this.issyncserver,
  });
  DatabaseNote.fromRow(Map<String, Object?> map)
      : id = map[idColumn] as int,
        userid = map[useridColumn] as int,
        text = map[textColumn] as String,
        issyncserver = (map[issyncColumn] as int) == 1 ? true : false;
  @override
  String toString() =>
      ' Note, ID =$id, userid=$userid, issyncserver = $issyncserver ';
  @override
  bool operator ==(covariant DatabaseNote other) => id == other.id;
  @override
  int get hashCode => id.hashCode;
}

const dbName = 'database-flutter.db';
const noteTable = 'note';
const userTable = 'user';
const idColumn = 'id';
const emailColumn = 'email';
const useridColumn = 'USER_ID';
const textColumn = 'TEXT';
const issyncColumn = 'IS_SYNC_SERVER';
const createNoteTable = '''CREATE TABLE IF NOT EXISTS "note" (
	"ID"	INTEGER NOT NULL,
	"USER_ID"	INTEGER NOT NULL,
	"TEXT"	TEXT,
	"IS_SYNC_SERVER"	INTEGER DEFAULT 0,
	PRIMARY KEY("ID" AUTOINCREMENT)
);
''';
const createUserTable = '''CREATE TABLE IF NOT EXISTS "user" (
	"ID"	INTEGER NOT NULL,
	"email"	INTEGER NOT NULL UNIQUE,
	PRIMARY KEY("ID" AUTOINCREMENT)
);
''';
