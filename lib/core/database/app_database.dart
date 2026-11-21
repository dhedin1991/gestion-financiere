import 'dart:io';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../utils/app_logger.dart';
import 'database_file_utils.dart';

/// Point d'accès unique à la base de données SQLite de l'application.
///
/// Toute l'application (tous les modules) passe par cette classe pour
/// obtenir la connexion à la base. Elle est fournie à l'app via un
/// Provider Riverpod (voir database_providers.dart) — c'est la base
/// du Repository Pattern : les couches supérieures ne connaissent que
/// cette classe, jamais les détails SQL bruts.
class AppDatabase {
  /// [directoryOverride] : dossier de la base, uniquement pour les tests
  /// (par défaut, le dossier de documents de l'application).
  AppDatabase({Directory? directoryOverride}) : _directoryOverride = directoryOverride;

  final Directory? _directoryOverride;

  static const String _dbName = 'gestion_financiere.db';
  static const int _dbVersion = 18;

  /// Version de schéma que cette version de l'app sait lire.
  static const int schemaVersion = _dbVersion;

  Database? _database;
  Future<Database>? _opening;

  /// Une seule ouverture à la fois : tous les appels simultanés au
  /// démarrage (comptes, tableau de bord, récurrences, rappels...) attendent
  /// la même ouverture au lieu d'en lancer chacun une.
  Future<Database> get database {
    final existing = _database;
    if (existing != null) return Future.value(existing);
    return _opening ??= _openOnce();
  }

  Future<Database> _openOnce() async {
    try {
      final db = await _initDatabase();
      _database = db;
      return db;
    } catch (_) {
      _opening = null; // permet de réessayer après un échec
      rethrow;
    }
  }

  /// Avant d'ouvrir la base pour de bon, vérifie si une migration vers le
  /// nouveau format de stockage des montants (centimes entiers, v13) va
  /// avoir lieu. Si oui, copie le fichier tel quel (avant toute
  /// modification) vers un fichier horodaté, pour permettre une
  /// restauration manuelle via la page Sauvegarde en cas de souci — même
  /// si la migration elle-même bénéficie déjà de la transaction implicite
  /// que sqflite ouvre automatiquement autour de tout `onUpgrade`, et ne
  /// devrait donc normalement jamais laisser la base dans un état
  /// intermédiaire incohérent.
  ///
  /// Ne bloque jamais le démarrage de l'app : un échec de sauvegarde est
  /// journalisé mais n'empêche pas la migration de continuer.
  Future<void> _backupBeforeCentsMigrationIfNeeded(String path) async {
    const centsMigrationVersion = 13;
    final file = File(path);
    if (!await file.exists()) return; // Première installation : rien à migrer.

    try {
      // Lecture directe de la version dans l'en-tête du fichier SQLite
      // (octets 60 à 63) : aucune seconde connexion n'est ouverte, donc
      // aucun risque de fermer la vraie base en cours d'utilisation.
      var currentVersion = 0;
      final raf = await file.open();
      try {
        await raf.setPosition(60);
        final bytes = await raf.read(4);
        if (bytes.length == 4) {
          currentVersion =
              (bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3];
        }
      } finally {
        await raf.close();
      }

      if (currentVersion > 0 && currentVersion < centsMigrationVersion) {
        final timestamp = DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
        final backupPath = join(dirname(path), 'avant_migration_centimes_$timestamp.db');
        await file.copy(backupPath);
        DatabaseFileUtils.pruneSafetyCopies(Directory(dirname(path)));
        AppLogger.info(
          'Sauvegarde de sécurité créée avant migration v$centsMigrationVersion : $backupPath',
          name: 'db_migration',
        );
      }
    } catch (e, stackTrace) {
      // On ne bloque jamais le lancement de l'app pour une sauvegarde de
      // confort : la vraie protection contre une migration partielle est
      // la transaction SQL atomique dans _onUpgrade.
      AppLogger.error(
        'Impossible de créer la sauvegarde de sécurité avant migration',
        name: 'db_migration',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<Database> _initDatabase() async {
    final directory = _directoryOverride ?? await getApplicationDocumentsDirectory();
    final path = join(directory.path, _dbName);

    await _backupBeforeCentsMigrationIfNeeded(path);

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
        entity_id INTEGER,
        role TEXT,
        alert_warning INTEGER,
        alert_critical INTEGER,
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
        transfer_group INTEGER,
        kind TEXT,
        ref_id INTEGER,
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
        anchor_day INTEGER,
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
  entity_id INTEGER,
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
        entity_id INTEGER,
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

    await _createInvoiceTables(db);

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
        entity_id INTEGER,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute(
        'CREATE UNIQUE INDEX idx_snapshot_date_entity ON net_worth_snapshots (snapshot_date, IFNULL(entity_id, 0))');

    // Taux de change saisis à la main (l'app reste 100% hors ligne, donc
    // aucun taux n'est récupéré automatiquement en ligne). `rate_to_xof`
    // exprime "1 unité de `currency` = combien de XOF" — sert uniquement à
    // calculer une estimation globale toutes devises confondues.
    await db.execute('''
      CREATE TABLE exchange_rates (
        currency TEXT PRIMARY KEY,
        rate_to_xof REAL NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE business_entities (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL DEFAULT 'personnel',
        created_at TEXT NOT NULL
      )
    ''');
    await db.insert('business_entities', {
      'name': 'Personnel',
      'type': 'personnel',
      'created_at': DateTime.now().toIso8601String(),
    });

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

    if (oldVersion < 4) {
      // Tables d'épargne : aucune migration ne les créait pour une base
      // antérieure à la v4 (ou une très ancienne sauvegarde restaurée).
      await db.execute('''
        CREATE TABLE IF NOT EXISTS savings (
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
        CREATE TABLE IF NOT EXISTS savings_transactions (
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
      await db.execute('CREATE INDEX IF NOT EXISTS idx_savings_account ON savings (account_id)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_savings_transactions_savings ON savings_transactions (savings_id)');
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
    if (oldVersion < 11) {
      // Base du multi-entités (Personnel / Société A / Société B...).
      // Migration non destructive : crée une entité "Personnel" par
      // défaut et y rattache tous les comptes déjà existants — rien
      // n'est perdu, rien ne devient orphelin.
      await db.execute('''
        CREATE TABLE IF NOT EXISTS business_entities (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          type TEXT NOT NULL DEFAULT 'personnel',
          created_at TEXT NOT NULL
        )
      ''');

      final existing = await db.query('business_entities', limit: 1);
      int defaultEntityId;
      if (existing.isEmpty) {
        defaultEntityId = await db.insert('business_entities', {
          'name': 'Personnel',
          'type': 'personnel',
          'created_at': DateTime.now().toIso8601String(),
        });
      } else {
        defaultEntityId = existing.first['id'] as int;
      }

      final columns = await db.rawQuery("PRAGMA table_info(accounts)");
      final hasEntityId = columns.any((c) => c['name'] == 'entity_id');
      if (!hasEntityId) {
        await db.execute('ALTER TABLE accounts ADD COLUMN entity_id INTEGER');
        await db.update(
          'accounts',
          {'entity_id': defaultEntityId},
          where: 'entity_id IS NULL',
        );
      }
    }
    if (oldVersion < 12) {
      // Étend le multi-entités à Budgets et Patrimoine (jusqu'ici
      // partagés entre toutes les entités faute de lien vers un compte).
      // Même logique non destructive que la migration précédente : une
      // entité par défaut existe forcément déjà (créée en v11), on s'y
      // rattache simplement.
      final entities = await db.query('business_entities', limit: 1);
      final defaultEntityId = entities.isNotEmpty
          ? entities.first['id'] as int
          : await db.insert('business_entities', {
              'name': 'Personnel',
              'type': 'personnel',
              'created_at': DateTime.now().toIso8601String(),
            });

      for (final table in ['budgets', 'patrimoine_items']) {
        final columns = await db.rawQuery("PRAGMA table_info($table)");
        final hasEntityId = columns.any((c) => c['name'] == 'entity_id');
        if (!hasEntityId) {
          await db.execute('ALTER TABLE $table ADD COLUMN entity_id INTEGER');
          await db.update(
            table,
            {'entity_id': defaultEntityId},
            where: 'entity_id IS NULL',
          );
        }
      }
    }
    if (oldVersion < 13) {
      // Migration vers le stockage des montants en centimes entiers
      // (au lieu de flottants), pour éliminer tout risque de dérive
      // d'arrondi sur des données financières (voir CHANGELOG). Toutes
      // les colonnes ci-dessous passent de "1500.5" (unités, flottant) à
      // "150050" (centimes, entier). CAST(...AS INTEGER) garantit un
      // stockage entier propre plutôt qu'un flottant à valeur entière.
      //
      // Toute la transformation bénéficie de la transaction implicite déjà
      // ouverte par sqflite pour onCreate/onUpgrade : soit toutes les
      // colonnes sont converties, soit aucune ne l'est en cas d'erreur —
      // jamais un état intermédiaire incohérent. Une sauvegarde de
      // sécurité du fichier a en plus été prise juste avant l'ouverture
      // de cette connexion (voir _backupBeforeCentsMigrationIfNeeded).
      const centsColumnsByTable = <String, List<String>>{
        'accounts': ['initial_balance', 'current_balance'],
        'transactions': ['amount'],
        'recurring_transactions': ['amount'],
        'debts': ['total_amount'],
        'debt_payments': ['amount'],
        'budgets': ['amount'],
        'savings': ['target_amount', 'current_balance'],
        'savings_transactions': ['amount'],
        'patrimoine_items': ['estimated_value'],
        'credits': ['principal_amount', 'monthly_payment'],
        'credit_installments': ['amount'],
        'net_worth_snapshots': [
          'total_accounts',
          'total_savings',
          'total_patrimoine',
          'total_receivables',
          'total_debts',
          'total_credits_remaining',
          'net_worth',
        ],
      };

      // NOTE : pas de db.transaction() explicite ici — sqflite exécute déjà
      // onCreate/onUpgrade dans une transaction implicite (comportement
      // documenté du plugin), comme le confirme le fait qu'aucun des blocs
      // de migration précédents dans ce fichier n'en utilise. Ajouter une
      // transaction imbriquée risquerait une erreur SQL "transaction within
      // a transaction" et casserait la migration pour tout le monde.
      for (final entry in centsColumnsByTable.entries) {
        final table = entry.key;
        // Vérifie l'existence de la table avant d'y toucher : selon la
        // version de départ de l'appareil, certaines tables plus
        // récentes (ex: savings, credits) ont déjà été créées par les
        // blocs de migration précédents exécutés juste au-dessus dans
        // ce même appel, donc elles existent forcément à ce stade —
        // cette vérification est une sécurité supplémentaire, pas une
        // hypothèse fragile.
        final tableExists = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name = ?",
          [table],
        );
        if (tableExists.isEmpty) continue;

        final existingColumns = await db.rawQuery('PRAGMA table_info($table)');
        final columnNames = existingColumns.map((c) => c['name'] as String).toSet();

        for (final column in entry.value) {
          if (!columnNames.contains(column)) continue;
          await db.execute(
            'UPDATE $table SET $column = CAST(ROUND($column * 100) AS INTEGER) '
            'WHERE $column IS NOT NULL',
          );
        }
      }
    }

    if (oldVersion < 14) {
      // Jour d'ancrage des récurrences (évite la dérive des échéances de fin
      // de mois : 31 janv. -> 28 févr. -> 31 mars). Migration non destructive.
      final cols = await db.rawQuery('PRAGMA table_info(recurring_transactions)');
      if (cols.isNotEmpty && !cols.any((c) => c['name'] == 'anchor_day')) {
        await db.execute('ALTER TABLE recurring_transactions ADD COLUMN anchor_day INTEGER');
      }
    }

    if (oldVersion < 17) {
      // Taux de change manuels (voir _onCreate pour le détail).
      await db.execute('''
        CREATE TABLE IF NOT EXISTS exchange_rates (
          currency TEXT PRIMARY KEY,
          rate_to_xof REAL NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
    }

    if (oldVersion < 18) {
      // Grand livre unifié + facturation + seuils d'alerte des comptes.
      // Migration non destructive : uniquement des colonnes/tables ajoutées.
      Future<void> addCol(String table, String col, String type) async {
        final cols = await db.rawQuery('PRAGMA table_info($table)');
        if (cols.isNotEmpty && !cols.any((c) => c['name'] == col)) {
          await db.execute('ALTER TABLE $table ADD COLUMN $col $type');
        }
      }

      await addCol('transactions', 'kind', 'TEXT');
      await addCol('transactions', 'ref_id', 'INTEGER');
      await addCol('accounts', 'role', 'TEXT');
      await addCol('accounts', 'alert_warning', 'INTEGER');
      await addCol('accounts', 'alert_critical', 'INTEGER');
      await _createInvoiceTables(db);
    }

    if (oldVersion < 16) {
      // Virements entre comptes : les deux écritures liées (dépense +
      // revenu) partagent ce même identifiant, pour être reconnues comme
      // un virement (exclu des totaux Revenus/Dépenses) et supprimées
      // ensemble. Migration non destructive.
      final cols = await db.rawQuery('PRAGMA table_info(transactions)');
      if (cols.isNotEmpty && !cols.any((c) => c['name'] == 'transfer_group')) {
        await db.execute('ALTER TABLE transactions ADD COLUMN transfer_group INTEGER');
      }
    }

    if (oldVersion < 15) {
      // Bilans par entité : une photo du patrimoine net par jour ET par
      // entité. Les photos existantes (d'avant) sont rattachées à la
      // première entité (Personnel), seule à exister quand elles ont été
      // prises. Migration non destructive : aucune donnée supprimée.
      final cols = await db.rawQuery('PRAGMA table_info(net_worth_snapshots)');
      if (cols.isNotEmpty) {
        if (!cols.any((c) => c['name'] == 'entity_id')) {
          await db.execute('ALTER TABLE net_worth_snapshots ADD COLUMN entity_id INTEGER');
          final entities = await db.query('business_entities',
              columns: ['id'], orderBy: 'id ASC', limit: 1);
          if (entities.isNotEmpty) {
            await db.update(
              'net_worth_snapshots',
              {'entity_id': entities.first['id']},
              where: 'entity_id IS NULL',
            );
          }
        }
        await db.execute('DROP INDEX IF EXISTS idx_snapshot_date');
        await db.execute(
            'CREATE UNIQUE INDEX IF NOT EXISTS idx_snapshot_date_entity ON net_worth_snapshots (snapshot_date, IFNULL(entity_id, 0))');
      }
    }
  }
  
  /// Facturation : factures et leurs lignes (montants en centimes).
  Future<void> _createInvoiceTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS invoices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        number TEXT NOT NULL,
        template TEXT NOT NULL DEFAULT 'classique',
        status TEXT NOT NULL DEFAULT 'brouillon',
        client_name TEXT NOT NULL,
        client_address TEXT,
        client_phone TEXT,
        client_email TEXT,
        issue_date TEXT NOT NULL,
        due_date TEXT,
        currency TEXT NOT NULL DEFAULT 'XOF',
        tax_rate REAL NOT NULL DEFAULT 0,
        discount INTEGER NOT NULL DEFAULT 0,
        paid_amount INTEGER NOT NULL DEFAULT 0,
        account_id INTEGER,
        notes TEXT,
        entity_id INTEGER,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS invoice_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_id INTEGER NOT NULL,
        description TEXT NOT NULL,
        quantity REAL NOT NULL DEFAULT 1,
        unit_price INTEGER NOT NULL DEFAULT 0,
        position INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (invoice_id) REFERENCES invoices (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_invoice_items_invoice ON invoice_items (invoice_id)');
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
    final pending = _opening;
    _opening = null;
    if (pending != null) {
      try {
        await pending;
      } catch (_) {}
    }
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
