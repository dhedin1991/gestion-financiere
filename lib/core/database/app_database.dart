import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// Point d'accès unique à la base de données SQLite de l'application.
///
/// Toute l'application (tous les modules) passe par cette classe pour
/// obtenir la connexion à la base. Elle est fournie à l'app via un
/// Provider Riverpod (voir database_providers.dart) — c'est la base
/// du Repository Pattern : les couches supérieures ne connaissent que
/// cette classe, jamais les détails SQL bruts.
class AppDatabase {
  static const String _dbName = 'gestion_financiere.db';
  static const int _dbVersion = 1;

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final directory = await getApplicationDocumentsDirectory();
    final path = join(directory.path, _dbName);

    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onConfigure: (db) async {
        // Active les clés étrangères (désactivées par défaut dans SQLite).
        await db.execute('PRAGMA foreign_keys = ON');
      },
      // onUpgrade sera complété au fil des versions futures (migrations),
      // conformément à l'exigence d'évolutivité sans réécriture majeure.
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // ==========================================================
    // TABLE : accounts (Comptes)
    // ==========================================================
    await db.execute('''
      CREATE TABLE accounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        bank_name TEXT,
        account_type TEXT NOT NULL DEFAULT 'courant',
        currency TEXT NOT NULL DEFAULT 'XOF',
        initial_balance REAL NOT NULL DEFAULT 0,
        current_balance REAL NOT NULL DEFAULT 0,
        color INTEGER,
        icon TEXT,
        is_archived INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // ==========================================================
    // TABLE : categories (personnalisables par l'utilisateur)
    // ==========================================================
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,          -- 'revenu' ou 'depense'
        parent_id INTEGER,           -- pour les sous-catégories
        color INTEGER,
        icon TEXT,
        is_default INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (parent_id) REFERENCES categories (id) ON DELETE SET NULL
      )
    ''');

    // ==========================================================
    // TABLE : transactions (Revenus + Dépenses)
    // ==========================================================
    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        account_id INTEGER NOT NULL,
        category_id INTEGER,
        type TEXT NOT NULL,          -- 'revenu' ou 'depense'
        amount REAL NOT NULL,
        currency TEXT NOT NULL DEFAULT 'XOF',
        description TEXT,
        payment_method TEXT,
        transaction_date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE CASCADE,
        FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE SET NULL
      )
    ''');

    // Index pour accélérer les requêtes fréquentes (tableau de bord,
    // filtrage par compte/période) — important vu le volume annoncé
    // (dizaines de milliers de transactions).
    await db.execute('CREATE INDEX idx_transactions_account ON transactions (account_id)');
    await db.execute('CREATE INDEX idx_transactions_date ON transactions (transaction_date)');
    await db.execute('CREATE INDEX idx_transactions_category ON transactions (category_id)');

    // ==========================================================
    // TABLE : history (journal des modifications, exigé au cahier des charges)
    // ==========================================================
    await db.execute('''
      CREATE TABLE history_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entity_type TEXT NOT NULL,
        entity_id INTEGER NOT NULL,
        action TEXT NOT NULL,        -- 'create', 'update', 'delete'
        old_value TEXT,
        new_value TEXT,
        date TEXT NOT NULL,
        time TEXT NOT NULL
      )
    ''');

    await _seedDefaultCategories(db);
  }

  /// Insère quelques catégories par défaut pour que l'app ne soit
  /// pas vide au premier lancement (l'utilisateur peut tout modifier ensuite).
  Future<void> _seedDefaultCategories(Database db) async {
    final now = DateTime.now().toIso8601String();
    final defaults = [
      {'name': 'Salaire', 'type': 'revenu'},
      {'name': 'Commerce', 'type': 'revenu'},
      {'name': 'Alimentation', 'type': 'depense'},
      {'name': 'Transport', 'type': 'depense'},
      {'name': 'Logement', 'type': 'depense'},
      {'name': 'Santé', 'type': 'depense'},
      {'name': 'Éducation', 'type': 'depense'},
      {'name': 'Loisirs', 'type': 'depense'},
    ];

    for (final cat in defaults) {
      await db.insert('categories', {
        'name': cat['name'],
        'type': cat['type'],
        'is_default': 1,
      });
    }
    // 'now' réservé pour un futur horodatage des seeds si besoin.
    assert(now.isNotEmpty);
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
