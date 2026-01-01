import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:crypto/crypto.dart';
import 'package:intl/intl.dart';
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
      version: 6, // UPDATED: Version 6 untuk force hapus reward_point
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // User table
    await db.execute('''
      CREATE TABLE user (
        user_id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        password TEXT NOT NULL
      )
    ''');
    
    // Category table
    await db.execute('''
      CREATE TABLE category (
        category_id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL CHECK(type IN ('income', 'expense'))
      )
    ''');
    
    // Budget/Target table
    await db.execute('''
      CREATE TABLE budget (
        budget_id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER,
        name TEXT NOT NULL,
        category_id INTEGER,
        target_amount REAL,
        start_date TEXT,
        end_date TEXT,
        is_active INTEGER DEFAULT 0,
        created_at TEXT,
        FOREIGN KEY (user_id) REFERENCES user (user_id) ON DELETE CASCADE,
        FOREIGN KEY (category_id) REFERENCES category (category_id)
      )
    ''');
    
    // Transactions table
    await db.execute('''
      CREATE TABLE transactions (
        transaction_id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER,
        category_id INTEGER,
        budget_id INTEGER,
        amount REAL NOT NULL,
        description TEXT,
        date TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES user (user_id) ON DELETE CASCADE,
        FOREIGN KEY (category_id) REFERENCES category (category_id),
        FOREIGN KEY (budget_id) REFERENCES budget (budget_id) ON DELETE SET NULL
      )
    ''');

    // Folder table (untuk "Kategori Saya")
    await db.execute('''
      CREATE TABLE folder (
        folder_id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES user (user_id) ON DELETE CASCADE
      )
    ''');
    
    // Folder-Transaction junction table
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
    // Version 2: Add folder tables
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
    
    // Version 3: Add name to budget and budget_id to transactions
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE budget ADD COLUMN name TEXT DEFAULT ""');
      await db.execute('ALTER TABLE transactions ADD COLUMN budget_id INTEGER REFERENCES budget(budget_id) ON DELETE SET NULL');
    }

    // Version 4: Add is_active and created_at to budget
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE budget ADD COLUMN is_active INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE budget ADD COLUMN created_at TEXT');
      await db.execute("UPDATE budget SET created_at = datetime('now')");
      print('✅ Added is_active and created_at columns to budget table');
    }

    // Version 5: Drop reward_point table
    if (oldVersion < 5) {
      try {
        await db.execute('DROP TABLE IF EXISTS reward_point');
        print('✅ Removed reward_point table (unused feature)');
      } catch (e) {
        print('⚠️  Error dropping reward_point: $e');
      }
    }

    // Version 6: Force drop reward_point if still exists
    if (oldVersion < 6) {
      try {
        await db.execute('DROP TABLE IF EXISTS reward_point');
        print('✅ [V6] Force removed reward_point table');
      } catch (e) {
        print('⚠️  [V6] reward_point already removed or error: $e');
      }
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

  Future<int> createCategory(String name, String type) async {
    final db = await database;
    try {
      return await db.insert('category', {
        'name': name,
        'type': type,
      });
    } catch (e) {
      print('Error creating category: $e');
      return -1;
    }
  }

  Future<int> updateCategory(int categoryId, String name) async {
    final db = await database;
    try {
      return await db.update(
        'category',
        {'name': name},
        where: 'category_id = ?',
        whereArgs: [categoryId],
      );
    } catch (e) {
      print('Error updating category: $e');
      return -1;
    }
  }

  Future<int> deleteCategory(int categoryId) async {
    final db = await database;
    try {
      final result = await db.query(
        'transactions',
        where: 'category_id = ?',
        whereArgs: [categoryId],
        limit: 1,
      );
      
      if (result.isNotEmpty) {
        print('Cannot delete category: still in use');
        return -1;
      }
      
      return await db.delete(
        'category',
        where: 'category_id = ?',
        whereArgs: [categoryId],
      );
    } catch (e) {
      print('Error deleting category: $e');
      return -1;
    }
  }

  // ===== TRANSACTION OPERATIONS =====
  Future<int> createTransaction({
    required int userId,
    required int categoryId,
    required double amount,
    required String description,
    required String date,
    int? budgetId,
  }) async {
    final db = await database;
    try {
      final transactionId = await db.insert('transactions', {
        'user_id': userId,
        'category_id': categoryId,
        'budget_id': budgetId,
        'amount': amount,
        'description': description,
        'date': date,
      });
      return transactionId;
    } catch (e) {
      print('Error creating transaction: $e');
      return -1;
    }
  }

  Future<int> updateTransaction({
    required int transactionId,
    required int categoryId,
    required double amount,
    required String description,
    required String date,
    int? budgetId,
  }) async {
    final db = await database;
    try {
      return await db.update(
        'transactions',
        {
          'category_id': categoryId,
          'budget_id': budgetId,
          'amount': amount,
          'description': description,
          'date': date,
        },
        where: 'transaction_id = ?',
        whereArgs: [transactionId],
      );
    } catch (e) {
      print('Error updating transaction: $e');
      return -1;
    }
  }

  Future<List<Map<String, dynamic>>> getTransactionsByUser(int userId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT t.*, c.name as category_name, c.type as category_type, b.name as budget_name
      FROM transactions t
      LEFT JOIN category c ON t.category_id = c.category_id
      LEFT JOIN budget b ON t.budget_id = b.budget_id
      WHERE t.user_id = ?
      ORDER BY t.date DESC
    ''', [userId]);
  }

  Future<List<Map<String, dynamic>>> getTransactionsByMonth(int userId, String month) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT DISTINCT t.*, c.name as category_name, c.type as category_type, b.name as budget_name
      FROM transactions t
      LEFT JOIN category c ON t.category_id = c.category_id
      LEFT JOIN budget b ON t.budget_id = b.budget_id
      WHERE t.user_id = ? AND t.date LIKE ?
      ORDER BY t.date DESC
    ''', [userId, '$month%']);
  }

  Future<int> deleteTransaction(int transactionId) async {
    final db = await database;
    return await db.delete(
      'transactions',
      where: 'transaction_id = ?',
      whereArgs: [transactionId],
    );
  }

  // ===== BUDGET/TARGET OPERATIONS =====
  Future<int> createBudget({
    required int userId,
    required String name,
    required int categoryId,
    required double targetAmount,
    required String startDate,
    required String endDate,
  }) async {
    final db = await database;

    return await db.insert('budget', {
      'user_id': userId,
      'name': name,
      'category_id': categoryId,
      'target_amount': targetAmount,
      'start_date': startDate,
      'end_date': endDate,
      'is_active': 0,
      'created_at': DateTime.now().toIso8601String(),
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

  Future<List<Map<String, dynamic>>> getAllTargets(int userId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT b.*, c.name as category_name
      FROM budget b
      LEFT JOIN category c ON b.category_id = c.category_id
      WHERE b.user_id = ?
      ORDER BY b.is_active DESC, b.end_date DESC
    ''', [userId]);
  }

  Future<List<Map<String, dynamic>>> getActiveTargets(int userId) async {
    final db = await database;
    final now = DateTime.now();
    final today = DateFormat('yyyy-MM-dd').format(now);
    
    return await db.rawQuery('''
      SELECT b.*, c.name as category_name
      FROM budget b
      LEFT JOIN category c ON b.category_id = c.category_id
      WHERE b.user_id = ? AND b.end_date >= ?
      ORDER BY b.end_date ASC
    ''', [userId, today]);
  }

  Future<Map<String, dynamic>?> getActiveTarget(int userId) async {
    final db = await database;
    
    final result = await db.rawQuery('''
      SELECT b.*, c.name as category_name
      FROM budget b
      LEFT JOIN category c ON b.category_id = c.category_id
      WHERE b.user_id = ? AND b.is_active = 1
      ORDER BY b.created_at DESC
      LIMIT 1
    ''', [userId]);
    
    if (result.isNotEmpty) {
      return result.first;
    }
    return null;
  }

  Future<int> setActiveTarget(int userId, int budgetId) async {
    final db = await database;
    
    return await db.transaction((txn) async {
      // Non-aktifkan semua target user
      await txn.update(
        'budget',
        {'is_active': 0},
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      
      // Aktifkan target yang dipilih
      final result = await txn.update(
        'budget',
        {'is_active': 1},
        where: 'budget_id = ? AND user_id = ?',
        whereArgs: [budgetId, userId],
      );
      
      print('✅ Target $budgetId set as active for user $userId');
      return result;
    });
  }

  Future<Map<String, dynamic>> getTargetProgress(int userId, int budgetId) async {
    final db = await database;
    
    final budgetResult = await db.query(
      'budget',
      where: 'budget_id = ?',
      whereArgs: [budgetId],
    );
    
    if (budgetResult.isEmpty) {
      return {
        'spent': 0.0,
        'target': 0.0,
        'remaining': 0.0,
        'percentage': 0.0,
      };
    }
    
    final budget = budgetResult.first;
    final targetAmount = (budget['target_amount'] as num).toDouble();
    final startDate = budget['start_date'] as String;
    final endDate = budget['end_date'] as String;
    
    final spentResult = await db.rawQuery('''
      SELECT COALESCE(SUM(t.amount), 0) as total
      FROM transactions t
      WHERE t.user_id = ? 
        AND t.budget_id = ?
        AND t.date BETWEEN ? AND ?
    ''', [userId, budgetId, startDate, endDate]);
    
    final spent = (spentResult.first['total'] as num).toDouble();
    final remaining = targetAmount - spent;
    final percentage = targetAmount > 0 ? (spent / targetAmount * 100) : 0.0;
    
    return {
      'spent': spent,
      'target': targetAmount,
      'remaining': remaining > 0 ? remaining : 0.0,
      'percentage': percentage > 100 ? 100.0 : percentage,
    };
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

  Future<int> deleteTarget(int budgetId) async {
    final db = await database;
    return await db.delete(
      'budget',
      where: 'budget_id = ?',
      whereArgs: [budgetId],
    );
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

  // ===== FOLDER OPERATIONS (Kategori Saya) =====
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
    try {
      final db = await database;
      await db.rawDelete('''
        DELETE FROM folder
        WHERE folder_id NOT IN (
          SELECT DISTINCT folder_id FROM folder_transaction
        )
      ''');
      print('✅ Berhasil membersihkan folder yang kosong.');
    } catch (e) {
      print('⚠️  Error cleaning empty folders: $e');
    }
  }

  Future<void> close() async {
    final db = await database;
    db.close();
  }
}