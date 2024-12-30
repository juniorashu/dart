import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google/services/crud_exception.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' show join;

class NotesService {
  Database? _db;
  List<DatabaseNote> _notes = [];
  static final NotesService _shared = NotesService._sharedInstance();
  NotesService._sharedInstance();
  factory NotesService() => _shared;

  final _notesStreamController =
      StreamController<List<DatabaseNote>>.broadcast();
  Stream<List<DatabaseNote>> get allNotes => _notesStreamController.stream;
  Future<DatabaseUser> getOrcreateUser({required String email}) async {
    try {
      final user = await getUser(email: email);
      return user;
    } on CouldNotFindUser {
      final createdUser = await createUser(email: email);
      return createdUser;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _cacheNotes() async {
    final allNotes = await getAllNotes();
    _notes = allNotes.toList();
    _notesStreamController.add(_notes);
  }

  Future<DatabaseNote> updateNote(
      {required DatabaseNote note, required String text}) async {
    await _ensureDbisOpen();
    final db = _getDatabaseOrthrow();
    await getNote(id: note.id);
    final updateCount =
        await db.update(noteTable, {textColumn: text, issyncColumn: 0});
    if (updateCount == 0) {
      throw CouldNotUpdateNote();
    } else {
      final updatedNote = await getNote(id: note.id);
      _notes.removeWhere((note) => note.id == updatedNote.id);
      _notes.add(updatedNote);
      _notesStreamController.add(_notes);
      return updatedNote;
    }
  }

  Future<Iterable<DatabaseNote>> getAllNotes() async {
    await _ensureDbisOpen();
    final db = _getDatabaseOrthrow();
    final notes = await db.query(
      noteTable,
    );
    return notes.map((noteRow) => DatabaseNote.fromRow(noteRow));
  }

  Future<DatabaseNote> getNote({required int id}) async {
    await _ensureDbisOpen();
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
      final note = DatabaseNote.fromRow(notes.first);
      _notes.removeWhere((note) => note.id == id);
      _notes.add(note);
      _notesStreamController.add(_notes);
      return note;
    }
  }

  Future<int> deleteAllNotes() async {
    await _ensureDbisOpen();
    final db = _getDatabaseOrthrow();

    final numberOfDeletion = await db.delete(noteTable);
    _notes = [];
    _notesStreamController.add(_notes);
    return numberOfDeletion;
  }

  Future<void> deleteNote({required int id}) async {
    await _ensureDbisOpen();
    final db = _getDatabaseOrthrow();
    final deletedCount = await db.delete(
      noteTable,
      where: 'id=?',
      whereArgs: [id],
    );
    if (deletedCount == 0) {
      throw CouldNoteDeleteUser();
    } else {
      // final countBefore = _notes.length;
      _notes.removeWhere((note) => note.id == id);
      _notesStreamController.add(_notes);
    }
  }

  Future<DatabaseNote> createNote({required DatabaseUser owner}) async {
    await _ensureDbisOpen();
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

    _notes.add(note);
    _notesStreamController.add(_notes);
    return note;
  }

  Future<DatabaseUser> getUser({required String email}) async {
    await _ensureDbisOpen();
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
    await _ensureDbisOpen();
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
    await _ensureDbisOpen();
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

  Future<void> _ensureDbisOpen() async {
    try {
      await open();
    } on DatabaseAlreadyOpenException {}
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

      await db.execute(createUserTable);
      await db.execute(createNoteTable);
      await _cacheNotes();
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
