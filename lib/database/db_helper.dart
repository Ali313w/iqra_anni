import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('reader.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 3, // ترقية النسخة لإضافة جدول المفضلة
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE books (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT,
        path TEXT,
        content TEXT,
        lastSegmentIndex INTEGER
      )
    ''');
    
    await db.execute('''
      CREATE TABLE favorites (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        bookId INTEGER,
        segmentIndex INTEGER,
        text TEXT,
        title TEXT,
        timestamp TEXT
      )
    ''');
    
    await db.execute('CREATE INDEX idx_books_id ON books(id)');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS favorites (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          bookId INTEGER,
          segmentIndex INTEGER,
          text TEXT,
          title TEXT,
          timestamp TEXT
        )
      ''');
    }
  }

  // عمليات الكتب
  Future<int> insertBook(Map<String, dynamic> book) async {
    final db = await instance.database;
    return await db.transaction((txn) async {
      return await txn.insert('books', book);
    });
  }

  Future<List<Map<String, dynamic>>> queryAllBooks() async {
    final db = await instance.database;
    return await db.query('books', columns: ['id', 'title', 'lastSegmentIndex'], orderBy: 'id DESC');
  }

  Future<Map<String, dynamic>?> getBookContent(int id) async {
    final db = await instance.database;
    final results = await db.query('books', where: 'id = ?', whereArgs: [id], limit: 1);
    return results.isNotEmpty ? results.first : null;
  }

  Future<int> updatePosition(int id, int segmentIndex) async {
    final db = await instance.database;
    return await db.update('books', {'lastSegmentIndex': segmentIndex}, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteBook(int id) async {
    final db = await instance.database;
    return await db.delete('books', where: 'id = ?', whereArgs: [id]);
  }

  // عمليات المفضلة
  Future<int> insertFavorite(Map<String, dynamic> fav) async {
    final db = await instance.database;
    return await db.insert('favorites', fav);
  }

  Future<List<Map<String, dynamic>>> queryAllFavorites() async {
    final db = await instance.database;
    return await db.query('favorites', orderBy: 'id DESC');
  }

  Future<int> deleteFavorite(int id) async {
    final db = await instance.database;
    return await db.delete('favorites', where: 'id = ?', whereArgs: [id]);
  }
}
