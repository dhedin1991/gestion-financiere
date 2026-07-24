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
  static const int _dbVersion = 10;

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
      onUpgrade: _onUpgrade,
      onConfigure: (db) async {
        // Active les clés étrangères (désactivées par défaut dans SQLite).
        await db.execute('PRAGMA foreign_keys = ON');
      },
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

    // ==========================================================
    // TABLE : recurring_transactions (modèles de transactions à
    // régénérer automatiquement selon une fréquence)
    // ==========================================================
    await db.execute('''
      CREATE TABLE recurring_transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        account_id INTEGER NOT NULL,
        category_id INTEGER,
        type TEXT NOT NULL,          -- 'revenu' ou 'depense'
        amount REAL NOT NULL,
        currency TEXT NOT NULL DEFAULT 'XOF',
        description TEXT,
        frequency TEXT NOT NULL,     -- 'hebdomadaire' | 'mensuelle' | 'annuelle'
        next_due_date TEXT NOT NULL,
        active INTEGER NOT NULL DEFAULT 1,
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

    await db.execute('''
      CREATE TABLE debts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        person_name TEXT NOT NULL,
        description TEXT,
        total_amount REAL NOT NULL,
        currency TEXT NOT NULL DEFAULT 'XOF',
        account_id INTEGER,
        due_date TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE debt_payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        debt_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        payment_date TEXT NOT NULL,
        note TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (debt_id) REFERENCES debts (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('CREATE INDEX idx_debts_type ON debts (type)');
    await db.execute('CREATE INDEX idx_debt_payments_debt ON debt_payments (debt_id)');
    
    await db.execute('''
CREATE TABLE budgets (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT,
  category_id INTEGER,
  amount REAL NOT NULL,
  period TEXT NOT NULL,
  start_date TEXT NOT NULL,
  currency TEXT NOT NULL DEFAULT 'XOF',
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE CASCADE
)
''');

   await db.execute('CREATE INDEX idx_budgets_category ON budgets (category_id)');
    await db.execute('CREATE INDEX idx_budgets_period ON budgets (period)');

    await db.execute('''
      CREATE TABLE savings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        account_id INTEGER NOT NULL,
        target_amount REAL,
        target_date TEXT,
        current_balance REAL NOT NULL DEFAULT 0,
        currency TEXT NOT NULL DEFAULT 'XOF',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE savings_transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        savings_id INTEGER NOT NULL,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        date TEXT NOT NULL,
        note TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (savings_id) REFERENCES savings (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('CREATE INDEX idx_savings_account ON savings (account_id)');
    await db.execute('CREATE INDEX idx_savings_transactions_savings ON savings_transactions (savings_id)');

    await db.execute('''
      CREATE TABLE patrimoine_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        estimated_value REAL NOT NULL,
        currency TEXT NOT NULL DEFAULT 'XOF',
        acquisition_date TEXT,
        description TEXT,
        location TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('CREATE INDEX idx_patrimoine_category ON patrimoine_items (category)');

    // ==========================================================
    // TABLE : credits (Crédits professionnels)
    // ==========================================================
    await db.execute('''
      CREATE TABLE credits (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        contract_number TEXT,
        principal_amount REAL NOT NULL,
        interest_rate REAL NOT NULL DEFAULT 0,
        start_date TEXT NOT NULL,
        duration_months INTEGER NOT NULL,
        monthly_payment REAL NOT NULL,
        account_id INTEGER,
        currency TEXT NOT NULL DEFAULT 'XOF',
        status TEXT NOT NULL DEFAULT 'actif',
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE credit_installments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        credit_id INTEGER NOT NULL,
        due_date TEXT NOT NULL,
        amount REAL NOT NULL,
        status TEXT NOT NULL DEFAULT 'en_attente',
        payment_date TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (credit_id) REFERENCES credits (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('CREATE INDEX idx_credits_status ON credits (status)');
    await db.execute('CREATE INDEX idx_credit_installments_credit ON credit_installments (credit_id)');
    await db.execute('CREATE INDEX idx_credit_installments_status ON credit_installments (status)');

    // ==========================================================
    // TABLE : net_worth_snapshots (photos du patrimoine net dans le temps)
    // ==========================================================
    await db.execute('''
      CREATE TABLE net_worth_snapshots (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        snapshot_date TEXT NOT NULL,
        total_accounts REAL NOT NULL,
        total_savings REAL NOT NULL,
        total_patrimoine REAL NOT NULL,
        total_receivables REAL NOT NULL,
        total_debts REAL NOT NULL,
        total_credits_remaining REAL NOT NULL,
        net_worth REAL NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('CREATE UNIQUE INDEX idx_snapshot_date ON net_worth_snapshots (snapshot_date)');

    await _seedDefaultCategories(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE debts (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          type TEXT NOT NULL,
          person_name TEXT NOT NULL,
          description TEXT,
          total_amount REAL NOT NULL,
          currency TEXT NOT NULL DEFAULT 'XOF',
          account_id INTEGER,
          due_date TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE SET NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE debt_payments (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          debt_id INTEGER NOT NULL,
          amount REAL NOT NULL,
          payment_date TEXT NOT NULL,
          note TEXT,
          created_at TEXT NOT NULL,
          FOREIGN KEY (debt_id) REFERENCES debts (id) ON DELETE CASCADE
        )
      ''');
      await db.execute('CREATE INDEX idx_debts_type ON debts (type)');
      await db.execute('CREATE INDEX idx_debt_payments_debt ON debt_payments (debt_id)');
    }

    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE budgets (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT,
          category_id INTEGER,
          amount REAL NOT NULL,
          period TEXT NOT NULL,
          start_date TEXT NOT NULL,
          currency TEXT NOT NULL DEFAULT 'XOF',
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE CASCADE
        )
      ''');
      await db.execute('CREATE INDEX idx_budgets_category ON budgets (category_id)');
      await db.execute('CREATE INDEX idx_budgets_period ON budgets (period)');
    }

    if (oldVersion < 5) {
      await db.execute('''
        CREATE TABLE patrimoine_items (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          category TEXT NOT NULL,
          estimated_value REAL NOT NULL,
          currency TEXT NOT NULL DEFAULT 'XOF',
          acquisition_date TEXT,
          description TEXT,
          location TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');

      await db.execute('CREATE INDEX idx_patrimoine_category ON patrimoine_items (category)');
    }

    if (oldVersion < 6) {
      await db.execute('''
        CREATE TABLE credits (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          contract_number TEXT,
          principal_amount REAL NOT NULL,
          interest_rate REAL NOT NULL DEFAULT 0,
          start_date TEXT NOT NULL,
          duration_months INTEGER NOT NULL,
          monthly_payment REAL NOT NULL,
          account_id INTEGER,
          currency TEXT NOT NULL DEFAULT 'XOF',
          status TEXT NOT NULL DEFAULT 'actif',
          notes TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE SET NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE credit_installments (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          credit_id INTEGER NOT NULL,
          due_date TEXT NOT NULL,
          amount REAL NOT NULL,
          status TEXT NOT NULL DEFAULT 'en_attente',
          payment_date TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          FOREIGN KEY (credit_id) REFERENCES credits (id) ON DELETE CASCADE
        )
      ''');

      await db.execute('CREATE INDEX idx_credits_status ON credits (status)');
      await db.execute('CREATE INDEX idx_credit_installments_credit ON credit_installments (credit_id)');
      await db.execute('CREATE INDEX idx_credit_installments_status ON credit_installments (status)');
    }

    if (oldVersion < 7) {
      await db.execute('''
        CREATE TABLE net_worth_snapshots (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          snapshot_date TEXT NOT NULL,
          total_accounts REAL NOT NULL,
          total_savings REAL NOT NULL,
          total_patrimoine REAL NOT NULL,
          total_receivables REAL NOT NULL DEFAULT 0,
          total_debts REAL NOT NULL,
          total_credits_remaining REAL NOT NULL,
          net_worth REAL NOT NULL,
          created_at TEXT NOT NULL
        )
      ''');

      await db.execute('CREATE UNIQUE INDEX idx_snapshot_date ON net_worth_snapshots (snapshot_date)');
    }

    if (oldVersion < 8) {
      // Ajout de la colonne total_receivables si la table a déjà été créée
      // en version 7 sans cette colonne (mise à jour avant la correction).
      final columns = await db.rawQuery('PRAGMA table_info(net_worth_snapshots)');
      final hasReceivables = columns.any((col) => col['name'] == 'total_receivables');
      if (!hasReceivables) {
        await db.execute(
          'ALTER TABLE net_worth_snapshots ADD COLUMN total_receivables REAL NOT NULL DEFAULT 0',
        );
      }
    }

    if (oldVersion < 9) {
      // Migration non destructive : ne touche à aucune table existante,
      // se contente de créer la nouvelle table si elle n'existe pas déjà
      // (le IF NOT EXISTS protège un utilisateur qui aurait déjà cette
      // version par un autre chemin, sans jamais toucher ses données).
      await db.execute('''
        CREATE TABLE IF NOT EXISTS recurring_transactions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          account_id INTEGER NOT NULL,
          category_id INTEGER,
          type TEXT NOT NULL,
          amount REAL NOT NULL,
          currency TEXT NOT NULL DEFAULT 'XOF',
          description TEXT,
          frequency TEXT NOT NULL,
          next_due_date TEXT NOT NULL,
          active INTEGER NOT NULL DEFAULT 1,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE CASCADE,
          FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE SET NULL
        )
      ''');
    }
    if (oldVersion < 10) {
      // history_log existait déjà dans _onCreate mais avait été oubliée
      // ici : les installations mises à niveau depuis une version
      // antérieure ne l'avaient donc jamais reçue. IF NOT EXISTS protège
      // les quelques installations qui l'auraient déjà (fraîchement
      // créées) sans toucher à aucune donnée existante.
      await db.execute('''
        CREATE TABLE IF NOT EXISTS history_log (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          entity_type TEXT NOT NULL,
          entity_id INTEGER NOT NULL,
          action TEXT NOT NULL,
          old_value TEXT,
          new_value TEXT,
          date TEXT NOT NULL,
          time TEXT NOT NULL
        )
      ''');
    }
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
