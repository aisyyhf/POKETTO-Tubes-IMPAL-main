import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('poketto.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    print('================================');
    print('DATABASE LOCATION: $path');
    print('================================');

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE user (
        user_id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        password TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE category (
        category_id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL CHECK(type IN ('income', 'expense'))
      )
    ''');
    await db.execute('''
      CREATE TABLE budget (
        budget_id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER,
        category_id INTEGER,
        target_amount REAL,
        start_date TEXT,
        end_date TEXT,
        FOREIGN KEY (user_id) REFERENCES user (user_id) ON DELETE CASCADE,
        FOREIGN KEY (category_id) REFERENCES category (category_id)
      )
    ''');
    await db.execute('''
      CREATE TABLE transactions (
        transaction_id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER,
        category_id INTEGER,
        amount REAL NOT NULL,
        description TEXT,
        date TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES user (user_id) ON DELETE CASCADE,
        FOREIGN KEY (category_id) REFERENCES category (category_id)
      )
    ''');
    await db.execute('''
      CREATE TABLE reward_point (
        point_id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER,
        total_points INTEGER DEFAULT 0,
        FOREIGN KEY (user_id) REFERENCES user (user_id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE folder (
        folder_id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES user (user_id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE folder_transaction (
        folder_transaction_id INTEGER PRIMARY KEY AUTOINCREMENT,
        folder_id INTEGER NOT NULL,
        transaction_id INTEGER NOT NULL,
        FOREIGN KEY (folder_id) REFERENCES folder (folder_id) ON DELETE CASCADE,
        FOREIGN KEY (transaction_id) REFERENCES transactions (transaction_id) ON DELETE CASCADE
      )
    ''');

    await _insertDefaultCategories(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE folder (
          folder_id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id INTEGER NOT NULL,
          name TEXT NOT NULL,
          FOREIGN KEY (user_id) REFERENCES user (user_id) ON DELETE CASCADE
        )
      ''');
      await db.execute('''
        CREATE TABLE folder_transaction (
          folder_transaction_id INTEGER PRIMARY KEY AUTOINCREMENT,
          folder_id INTEGER NOT NULL,
          transaction_id INTEGER NOT NULL,
          FOREIGN KEY (folder_id) REFERENCES folder (folder_id) ON DELETE CASCADE,
          FOREIGN KEY (transaction_id) REFERENCES transactions (transaction_id) ON DELETE CASCADE
        )
      ''');
    }
  }

  Future<void> _insertDefaultCategories(Database db) async {
    final categories = [
      {'name': 'Gaji', 'type': 'income'},
      {'name': 'Bonus', 'type': 'income'},
      {'name': 'Investasi', 'type': 'income'},
      {'name': 'Makanan', 'type': 'expense'},
      {'name': 'Transport', 'type': 'expense'},
      {'name': 'Hiburan', 'type': 'expense'},
      {'name': 'Tagihan', 'type': 'expense'},
      {'name': 'Belanja', 'type': 'expense'},
    ];

    for (var category in categories) {
      await db.insert('category', category);
    }
  }

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // ===== USER OPERATIONS =====
  Future<int> getUserCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) FROM user');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> createUser(String name, String email, String password) async {
    final db = await database;
    final hashedPassword = _hashPassword(password);
    try {
      print('🔵 Creating user: $name, $email');
      final userId = await db.insert('user', {
        'name': name,
        'email': email,
        'password': hashedPassword,
      });
      print('✅ User created with ID: $userId');
      await db.insert('reward_point', {
        'user_id': userId,
        'total_points': 0,
      });
      print('✅ Reward points created for user $userId');
      return userId;
    } catch (e) {
      print('❌ Error creating user: $e');
      return -1;
    }
  }

  Future<Map<String, dynamic>?> loginUser(String email, String password) async {
    final db = await database;
    final hashedPassword = _hashPassword(password);
    final result = await db.query(
      'user',
      where: 'email = ? AND password = ?',
      whereArgs: [email, hashedPassword],
    );
    if (result.isNotEmpty) {
      return result.first;
    }
    return null;
  }

  Future<Map<String, dynamic>?> getUserById(int userId) async {
    final db = await database;
    final result = await db.query(
      'user',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    if (result.isNotEmpty) {
      return result.first;
    }
    return null;
  }

  Future<int> updateUser(int userId, String name, String email) async {
    final db = await database;
    return await db.update(
      'user',
      {'name': name, 'email': email},
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }

  // ===== CATEGORY OPERATIONS =====
  Future<List<Map<String, dynamic>>> getAllCategories() async {
    final db = await database;
    return await db.query('category');
  }

  Future<List<Map<String, dynamic>>> getCategoriesByType(String type) async {
    final db = await database;
    return await db.query(
      'category',
      where: 'type = ?',
      whereArgs: [type],
    );
  }

  // ===== TRANSACTION OPERATIONS =====
  Future<int> createTransaction({
    required int userId,
    required int categoryId,
    required double amount,
    required String description,
    required String date,
  }) async {
    final db = await database;
    try {
      final transactionId = await db.insert('transactions', {
        'user_id': userId,
        'category_id': categoryId,
        'amount': amount,
        'description': description,
        'date': date,
      });
      await _addRewardPoints(userId, 1);
      return transactionId;
    } catch (e) {
      print('Error creating transaction: $e');
      return -1;
    }
  }

  Future<List<Map<String, dynamic>>> getTransactionsByUser(int userId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT t.*, c.name as category_name, c.type as category_type
      FROM transactions t
      LEFT JOIN category c ON t.category_id = c.category_id
      WHERE t.user_id = ?
      ORDER BY t.date DESC
    ''', [userId]);
  }

  Future<List<Map<String, dynamic>>> getTransactionsByMonth(int userId, String month) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT DISTINCT t.*, c.name as category_name, c.type as category_type
      FROM transactions t
      LEFT JOIN category c ON t.category_id = c.category_id
      WHERE t.user_id = ? AND t.date LIKE ?
      ORDER BY t.date DESC
    ''', [userId, '$month%']);
  }

  Future<Map<String, dynamic>?> getTransactionById(int transactionId) async {
    final db = await database;
    try {
      final result = await db.rawQuery('''
        SELECT t.*, c.name as category_name, c.type as type
        FROM transactions t
        LEFT JOIN category c ON t.category_id = c.category_id
        WHERE t.transaction_id = ?
      ''', [transactionId]);
      
      if (result.isNotEmpty) {
        return result.first;
      }
      return null;
    } catch (e) {
      print('Error getting transaction: $e');
      return null;
    }
  }

  Future<int> updateTransaction({
    required int transactionId,
    required int categoryId,
    required double amount,
    required String description,
    required String date,
  }) async {
    final db = await database;
    try {
      final result = await db.update(
        'transactions',
        {
          'category_id': categoryId,
          'amount': amount,
          'description': description,
          'date': date,
        },
        where: 'transaction_id = ?',
        whereArgs: [transactionId],
      );
      print('✅ Transaction updated: $result row(s) affected');
      return result;
    } catch (e) {
      print('❌ Error updating transaction: $e');
      return 0;
    }
  }

  Future<int> deleteTransaction(int transactionId) async {
    final db = await database;
    try {
      final result = await db.delete(
        'transactions',
        where: 'transaction_id = ?',
        whereArgs: [transactionId],
      );
      print('✅ Transaction deleted: $result row(s) affected');
      return result;
    } catch (e) {
      print('❌ Error deleting transaction: $e');
      return 0;
    }
  }

  // ===== BUDGET OPERATIONS =====
  Future<int> createBudget({
    required int userId,
    required int categoryId,
    required double targetAmount,
    required String startDate,
    required String endDate,
  }) async {
    final db = await database;
    return await db.insert('budget', {
      'user_id': userId,
      'category_id': categoryId,
      'target_amount': targetAmount,
      'start_date': startDate,
      'end_date': endDate,
    });
  }

  Future<List<Map<String, dynamic>>> getBudgetsByUser(int userId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT b.*, c.name as category_name
      FROM budget b
      LEFT JOIN category c ON b.category_id = c.category_id
      WHERE b.user_id = ?
    ''', [userId]);
  }

  Future<int> updateBudget(int budgetId, double targetAmount) async {
    final db = await database;
    return await db.update(
      'budget',
      {'target_amount': targetAmount},
      where: 'budget_id = ?',
      whereArgs: [budgetId],
    );
  }

  Future<int> deleteBudget(int budgetId) async {
    final db = await database;
    return await db.delete(
      'budget',
      where: 'budget_id = ?',
      whereArgs: [budgetId],
    );
  }

  // ===== REWARD OPERATIONS =====
  Future<void> _addRewardPoints(int userId, int points) async {
    final db = await database;
    await db.rawUpdate('''
      UPDATE reward_point 
      SET total_points = total_points + ? 
      WHERE user_id = ?
    ''', [points, userId]);
  }

  Future<int?> getRewardPoints(int userId) async {
    final db = await database;
    final result = await db.query(
      'reward_point',
      where: 'user_id = ?',
      whereArgs: [userId],
    );

    if (result.isNotEmpty) {
      return result.first['total_points'] as int?;
    }
    return 0;
  }

  // ===== STATS OPERATIONS =====
  Future<Map<String, double>> getMonthlyStats(int userId, String month) async {
    final db = await database;

    final incomeResult = await db.rawQuery('''
      SELECT COALESCE(SUM(t.amount), 0) as total
      FROM transactions t
      LEFT JOIN category c ON t.category_id = c.category_id
      WHERE t.user_id = ? AND c.type = 'income' AND t.date LIKE ?
    ''', [userId, '$month%']);

    final expenseResult = await db.rawQuery('''
      SELECT COALESCE(SUM(t.amount), 0) as total
      FROM transactions t
      LEFT JOIN category c ON t.category_id = c.category_id
      WHERE t.user_id = ? AND c.type = 'expense' AND t.date LIKE ?
    ''', [userId, '$month%']);

    final income = (incomeResult.first['total'] as num).toDouble();
    final expense = (expenseResult.first['total'] as num).toDouble();

    return {
      'income': income,
      'expense': expense,
      'balance': income - expense,
    };
  }

  // ===== FOLDER OPERATIONS =====
  Future<int> createFolder(int userId, String folderName, List<int> transactionIds) async {
    final db = await database;
    return await db.transaction((txn) async {
      final folderId = await txn.insert('folder', {
        'user_id': userId,
        'name': folderName,
      });

      final batch = txn.batch();
      for (final transactionId in transactionIds) {
        batch.insert('folder_transaction', {
          'folder_id': folderId,
          'transaction_id': transactionId,
        });
      }
      await batch.commit(noResult: true);

      return folderId;
    });
  }

  Future<List<Map<String, dynamic>>> getFoldersByUser(int userId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT 
        f.folder_id, 
        f.name, 
        COUNT(ft.transaction_id) as transaction_count
      FROM folder f
      LEFT JOIN folder_transaction ft ON f.folder_id = ft.folder_id
      WHERE f.user_id = ?
      GROUP BY f.folder_id, f.name
      ORDER BY f.name ASC
    ''', [userId]);
  }

  Future<List<Map<String, dynamic>>> getTransactionsInFolder(int folderId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT t.*, c.name as category_name, c.type as category_type
      FROM transactions t
      JOIN folder_transaction ft ON t.transaction_id = ft.transaction_id
      LEFT JOIN category c ON t.category_id = c.category_id
      WHERE ft.folder_id = ?
      ORDER BY t.date DESC
    ''', [folderId]);
  }

  Future<void> addTransactionsToFolder(int folderId, List<int> transactionIds) async {
    final db = await database;

    await db.transaction((txn) async {
      final batch = txn.batch();

      for (final transactionId in transactionIds) {
        final existing = await txn.query(
          'folder_transaction',
          where: 'folder_id = ? AND transaction_id = ?',
          whereArgs: [folderId, transactionId],
          limit: 1,
        );

        if (existing.isEmpty) {
          batch.insert('folder_transaction', {
            'folder_id': folderId,
            'transaction_id': transactionId,
          });
        }
      }

      await batch.commit(noResult: true);
    });
    print('✅ Berhasil menambahkan transaksi ke folder ID: $folderId.');
  }

  Future<int> updateFolderName(int folderId, String newName) async {
    final db = await database;
    return await db.update(
      'folder',
      {'name': newName},
      where: 'folder_id = ?',
      whereArgs: [folderId],
    );
  }

  Future<void> removeTransactionsFromFolder(int folderId, List<int> transactionIds) async {
    final db = await database;
    await db.delete(
      'folder_transaction',
      where: 'folder_id = ? AND transaction_id IN (${transactionIds.map((_) => '?').join(',')})',
      whereArgs: [folderId, ...transactionIds],
    );
    print('✅ Berhasil mengeluarkan ${transactionIds.length} transaksi dari folder ID: $folderId.');
  }

  Future<void> deleteEmptyFolders() async {
    final db = await database;
    await db.rawDelete('''
      DELETE FROM folder
      WHERE folder_id NOT IN (
        SELECT DISTINCT folder_id FROM folder_transaction
      )
    ''');
    print('✅ Berhasil membersihkan folder yang kosong.');
  }

  // Close database
  Future<void> close() async {
    final db = await database;
    db.close();
  }
}