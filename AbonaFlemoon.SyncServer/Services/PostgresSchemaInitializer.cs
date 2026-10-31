using Microsoft.Data.Sqlite;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace AbonaFlemoon.SyncServer.Services;

public static class PostgresSchemaInitializer
{
    // الترتيب الإلزامي للجداول الـ 22 حسب اعتمادية المفاتيح الأجنبية (من الأب إلى الابن)
    public static readonly string[] OrderedTables = new[]
    {
        "areas",
        "streets",
        "karaba",
        "mostwa",
        "hala_egtimaia",
        "hala_sehia",
        "e_s",
        "stage",
        "fathers",
        "khdma",
        "users",
        "icon",
        "inter_icon",
        "settings",
        "osra",
        "person",
        "eatraf",
        "visits",
        "monasba",
        "count_aid",
        "count_2",
        "masrofat"
    };

    // الجداول ذات المفتاح الأساسي الرقمي التسلسلي (SERIAL PRIMARY KEY)
    public static readonly Dictionary<string, string> SingleIdPrimaryKeys = new(StringComparer.OrdinalIgnoreCase)
    {
        ["areas"] = "area_id",
        ["streets"] = "street_id",
        ["karaba"] = "karaba_id",
        ["mostwa"] = "mostwa_id",
        ["hala_egtimaia"] = "hala_egtimaia_id",
        ["hala_sehia"] = "hala_sehia_id",
        ["e_s"] = "e_s_id",
        ["stage"] = "stage_id",
        ["fathers"] = "father_id",
        ["khdma"] = "khdma_id",
        ["users"] = "pass_id",
        ["icon"] = "icon_id",
        ["inter_icon"] = "inter_id",
        ["osra"] = "osra_id",
        ["person"] = "person_id",
        ["eatraf"] = "eatraf_id",
        ["visits"] = "visit_id",
        ["monasba"] = "monasba_id",
        ["count_aid"] = "count_id",
        ["count_2"] = "count_2_id",
        ["masrofat"] = "masrofat_id"
    };

    // أعمدة التعارض عند تنفيذ INSERT OR REPLACE -> ON CONFLICT (...) DO UPDATE
    public static readonly Dictionary<string, string[]> ConflictTargetColumns = new(StringComparer.OrdinalIgnoreCase)
    {
        ["areas"] = new[] { "area_id" },
        ["streets"] = new[] { "street_id" },
        ["karaba"] = new[] { "karaba_id" },
        ["mostwa"] = new[] { "mostwa_id" },
        ["hala_egtimaia"] = new[] { "hala_egtimaia_id" },
        ["hala_sehia"] = new[] { "hala_sehia_id" },
        ["e_s"] = new[] { "e_s_id" },
        ["stage"] = new[] { "stage_id" },
        ["fathers"] = new[] { "father_id" },
        ["khdma"] = new[] { "khdma_id" },
        ["users"] = new[] { "pass_id" },
        ["icon"] = new[] { "icon_id" },
        ["inter_icon"] = new[] { "inter_id" },
        ["settings"] = new[] { "setting_key" },
        ["osra"] = new[] { "osra_id" },
        ["person"] = new[] { "person_id" },
        ["eatraf"] = new[] { "eatraf_id" },
        ["visits"] = new[] { "visit_id" },
        ["monasba"] = new[] { "monasba_id" },
        ["count_aid"] = new[] { "count_id" },
        ["count_2"] = new[] { "count_2_id" },
        ["masrofat"] = new[] { "masrofat_id" }
    };

    // الأعمدة الفريدة الإضافية (UNIQUE) في جداول الثوابت لمعالجة INSERT OR REPLACE بدون مفتاح أساسي
    public static readonly Dictionary<string, string> UniqueNameColumns = new(StringComparer.OrdinalIgnoreCase)
    {
        ["areas"] = "area_name",
        ["karaba"] = "karaba_name",
        ["mostwa"] = "mostwa_name",
        ["hala_egtimaia"] = "hala_name",
        ["hala_sehia"] = "hala_name",
        ["e_s"] = "e_s_name",
        ["stage"] = "stage_name",
        ["khdma"] = "khdma_name",
        ["users"] = "user_name",
        ["icon"] = "icon_name",
        ["settings"] = "setting_key"
    };

    // تطبيع أسماء الأعمدة في نتائج الاستعلامات
    public static readonly Dictionary<string, string> CanonicalColumnNames = new(StringComparer.OrdinalIgnoreCase)
    {
        ["area_id"] = "area_id",
        ["area_name"] = "area_name",
        ["street_id"] = "street_id",
        ["street_name"] = "street_name",
        ["karaba_id"] = "karaba_id",
        ["karaba_name"] = "karaba_name",
        ["mostwa_id"] = "mostwa_id",
        ["mostwa_name"] = "mostwa_name",
        ["hala_egtimaia_id"] = "hala_egtimaia_id",
        ["hala_sehia_id"] = "hala_sehia_id",
        ["hala_name"] = "hala_name",
        ["e_s_id"] = "e_s_id",
        ["e_s_name"] = "e_s_name",
        ["stage_id"] = "stage_id",
        ["stage_name"] = "stage_name",
        ["father_id"] = "father_id",
        ["father_name"] = "father_name",
        ["father_mobile"] = "father_mobile",
        ["birth_date"] = "birth_date",
        ["khdma_id"] = "khdma_id",
        ["khdma_name"] = "khdma_name",
        ["pass_id"] = "pass_id",
        ["user_name"] = "user_name",
        ["pass_word"] = "pass_word",
        ["icon_id"] = "icon_id",
        ["icon_name"] = "icon_name",
        ["inter_id"] = "inter_id",
        ["check_1"] = "check_1",
        ["setting_key"] = "setting_key",
        ["setting_value"] = "setting_value",
        ["osra_id"] = "osra_id",
        ["osra_name"] = "osra_name",
        ["dalil_name"] = "dalil_name",
        ["emara"] = "emara",
        ["door"] = "door",
        ["shaka"] = "shaka",
        ["r_o"] = "r_o",
        ["phone"] = "phone",
        ["number"] = "number",
        ["rakm_komy"] = "rakm_komy",
        ["code"] = "code",
        ["member_count"] = "member_count",
        ["person_id"] = "person_id",
        ["person_name"] = "person_name",
        ["moahil"] = "moahil",
        ["date_moiahil"] = "date_moiahil",
        ["wazefa"] = "wazefa",
        ["place_work"] = "place_work",
        ["mobile"] = "mobile",
        ["facebook"] = "facebook",
        ["father"] = "father",
        ["month"] = "month",
        ["age"] = "age",
        ["eatraf_id"] = "eatraf_id",
        ["date"] = "date",
        ["notes"] = "notes",
        ["visit_id"] = "visit_id",
        ["monasba_id"] = "monasba_id",
        ["monasba_name"] = "monasba_name",
        ["monasba_date"] = "monasba_date",
        ["count_id"] = "count_id",
        ["count_value"] = "count_value",
        ["aynee"] = "aynee",
        ["count_2_id"] = "count_2_id",
        ["type"] = "type",
        ["count_add"] = "count_add",
        ["date_1"] = "date_1",
        ["masrofat_id"] = "masrofat_id",
        ["masrof"] = "masrof",
        ["family_count"] = "family_count",
        ["person_count"] = "person_count",
        ["total"] = "total"
    };

    public static readonly string[] AllRequiredPermissions = new[]
    {
        "إدراج أسر",
        "مناطق وشوارع",
        "آباء كهنة",
        "مناسبات",
        "بحث",
        "أعياد ميلاد",
        "صلاحيات",
        "حساب مساعدات",
        "تقرير العضوية الكنسية",
        "خدمات",
        "مصروفات",
        "بحث مصروفات",
        "إدارة القوائم",
        "طباعة كارنيه",
        "صيانة النظام",
        "الافتقاد",
        "ترحيل المراحل",
        "الاعتراف"
    };

    public static async Task EnsureDatabaseAndSchemaAsync(
        string connectionString,
        string? initialSqlitePath,
        ILogger logger)
    {
        var builder = new NpgsqlConnectionStringBuilder(connectionString);
        var targetDatabase = builder.Database;
        if (string.IsNullOrWhiteSpace(targetDatabase))
        {
            throw new InvalidOperationException("Database name must be specified in Postgres connection string.");
        }

        // 1. التأكد من وجود قاعدة البيانات نفسها في PostgreSQL وإنشاؤها إن لم تكن موجودة
        var adminBuilder = new NpgsqlConnectionStringBuilder(connectionString)
        {
            Database = "postgres"
        };

        await using (var adminConn = new NpgsqlConnection(adminBuilder.ConnectionString))
        {
            await adminConn.OpenAsync();
            await using var checkCmd = new NpgsqlCommand(
                "SELECT 1 FROM pg_database WHERE datname = @dbName;", adminConn);
            checkCmd.Parameters.AddWithValue("@dbName", targetDatabase);
            var exists = await checkCmd.ExecuteScalarAsync() != null;

            if (!exists)
            {
                if (targetDatabase == "church_membership")
                {
                    await using var legacyCheck = new NpgsqlCommand("SELECT 1 FROM pg_database WHERE datname = 'abona_flemoon'", adminConn);
                    if (await legacyCheck.ExecuteScalarAsync() != null)
                    {
                        // Rename only when the new database is absent. Never replace data.
                        await using var rename = new NpgsqlCommand("ALTER DATABASE abona_flemoon RENAME TO church_membership", adminConn);
                        await rename.ExecuteNonQueryAsync();
                        exists = true;
                    }
                }
                if (!exists) {
                logger.LogInformation("Creating PostgreSQL database '{Database}'...", targetDatabase);
                await using var createDbCmd = new NpgsqlCommand($"CREATE DATABASE \"{targetDatabase}\";", adminConn);
                await createDbCmd.ExecuteNonQueryAsync();
                }
            }
        }

        // 2. إنشاء الجداول والفهارس في قاعدة البيانات المستهدفة
        await using var conn = new NpgsqlConnection(connectionString);
        await conn.OpenAsync();

        var ddl = GetCreateTablesSql();
        await using (var cmd = new NpgsqlCommand(ddl, conn))
        {
            await cmd.ExecuteNonQueryAsync();
        }

        // 3. التأكد من البيانات الافتراضية أو الاستيراد من ملف SQLite الأولي إذا كانت القاعدة فارغة
        await SeedDefaultDataOrImportInitialSqliteAsync(conn, initialSqlitePath, logger);

        // 4. مزامنة جميع المتسلسلات (Sequences)
        await SyncAllSequencesAsync(conn);
    }

    public static string GetCreateTablesSql()
    {
        return @"
CREATE TABLE IF NOT EXISTS areas (
    area_id SERIAL PRIMARY KEY,
    area_name TEXT NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS streets (
    street_id SERIAL PRIMARY KEY,
    street_name TEXT NOT NULL,
    area_id INTEGER NOT NULL REFERENCES areas(area_id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS karaba (
    karaba_id SERIAL PRIMARY KEY,
    karaba_name TEXT NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS mostwa (
    mostwa_id SERIAL PRIMARY KEY,
    mostwa_name TEXT NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS hala_egtimaia (
    hala_egtimaia_id SERIAL PRIMARY KEY,
    hala_name TEXT NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS hala_sehia (
    hala_sehia_id SERIAL PRIMARY KEY,
    hala_name TEXT NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS e_s (
    e_s_id SERIAL PRIMARY KEY,
    e_s_name TEXT NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS stage (
    stage_id SERIAL PRIMARY KEY,
    stage_name TEXT NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS fathers (
    father_id SERIAL PRIMARY KEY,
    father_name TEXT NOT NULL,
    father_mobile TEXT,
    birth_date TEXT
);

CREATE TABLE IF NOT EXISTS khdma (
    khdma_id SERIAL PRIMARY KEY,
    khdma_name TEXT NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS users (
    pass_id SERIAL PRIMARY KEY,
    user_name TEXT NOT NULL UNIQUE,
    pass_word TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS icon (
    icon_id SERIAL PRIMARY KEY,
    icon_name TEXT NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS inter_icon (
    inter_id SERIAL PRIMARY KEY,
    pass_id INTEGER NOT NULL REFERENCES users(pass_id) ON DELETE CASCADE,
    icon_id INTEGER,
    icon_name TEXT,
    check_1 INTEGER DEFAULT 1
);

CREATE TABLE IF NOT EXISTS settings (
    setting_key TEXT PRIMARY KEY,
    setting_value TEXT
);

CREATE TABLE IF NOT EXISTS osra (
    osra_id SERIAL PRIMARY KEY,
    osra_name TEXT NOT NULL,
    karaba_id INTEGER,
    e_s_id INTEGER,
    area_id INTEGER,
    street_id INTEGER,
    dalil_name TEXT,
    emara TEXT,
    door TEXT,
    shaka TEXT,
    r_o TEXT,
    phone TEXT,
    number INTEGER DEFAULT 0,
    hala_egtimaia_id INTEGER,
    rakm_komy TEXT,
    code INTEGER,
    hala_sehia_id INTEGER,
    mostwa_id INTEGER
);

CREATE TABLE IF NOT EXISTS person (
    person_id SERIAL PRIMARY KEY,
    person_name TEXT NOT NULL,
    osra_id INTEGER NOT NULL REFERENCES osra(osra_id) ON DELETE CASCADE,
    karaba_id INTEGER,
    birth_date TEXT,
    mostwa_id INTEGER,
    moahil TEXT,
    date_moiahil TEXT,
    hala_egtimaia_id INTEGER,
    hala_sehia_id INTEGER,
    wazefa TEXT,
    place_work TEXT,
    mobile TEXT,
    facebook TEXT,
    father TEXT,
    stage_id INTEGER,
    father_id INTEGER,
    month TEXT,
    age TEXT,
    rakm_komy TEXT
);

CREATE TABLE IF NOT EXISTS eatraf (
    eatraf_id SERIAL PRIMARY KEY,
    person_id INTEGER NOT NULL REFERENCES person(person_id) ON DELETE CASCADE,
    date TEXT NOT NULL,
    notes TEXT
);

CREATE TABLE IF NOT EXISTS visits (
    visit_id SERIAL PRIMARY KEY,
    osra_id INTEGER NOT NULL REFERENCES osra(osra_id) ON DELETE CASCADE,
    date TEXT NOT NULL,
    notes TEXT
);

CREATE TABLE IF NOT EXISTS monasba (
    monasba_id SERIAL PRIMARY KEY,
    osra_id INTEGER NOT NULL REFERENCES osra(osra_id) ON DELETE CASCADE,
    monasba_name TEXT NOT NULL,
    monasba_date TEXT,
    month TEXT
);

CREATE TABLE IF NOT EXISTS count_aid (
    count_id SERIAL PRIMARY KEY,
    osra_id INTEGER NOT NULL REFERENCES osra(osra_id) ON DELETE CASCADE,
    khdma_id INTEGER,
    count_value DOUBLE PRECISION DEFAULT 0,
    aynee TEXT,
    notes TEXT
);

CREATE TABLE IF NOT EXISTS count_2 (
    count_2_id SERIAL PRIMARY KEY,
    osra_id INTEGER NOT NULL REFERENCES osra(osra_id) ON DELETE CASCADE,
    type TEXT,
    count_add DOUBLE PRECISION DEFAULT 0,
    notes TEXT,
    date_1 TEXT
);

CREATE TABLE IF NOT EXISTS masrofat (
    masrofat_id SERIAL PRIMARY KEY,
    osra_id INTEGER NOT NULL REFERENCES osra(osra_id) ON DELETE CASCADE,
    masrof TEXT,
    count_value DOUBLE PRECISION DEFAULT 0,
    aynee TEXT,
    notes TEXT
);

ALTER TABLE osra ADD COLUMN IF NOT EXISTS birth_date TEXT;
ALTER TABLE osra ADD COLUMN IF NOT EXISTS age TEXT;
ALTER TABLE osra ADD COLUMN IF NOT EXISTS gender TEXT;
ALTER TABLE osra ADD COLUMN IF NOT EXISTS governorate TEXT;
ALTER TABLE person ADD COLUMN IF NOT EXISTS gender TEXT;
ALTER TABLE person ADD COLUMN IF NOT EXISTS governorate TEXT;

ALTER TABLE osra DROP CONSTRAINT IF EXISTS osra_karaba_id_fkey;
ALTER TABLE osra DROP CONSTRAINT IF EXISTS osra_e_s_id_fkey;
ALTER TABLE osra DROP CONSTRAINT IF EXISTS osra_area_id_fkey;
ALTER TABLE osra DROP CONSTRAINT IF EXISTS osra_street_id_fkey;
ALTER TABLE osra DROP CONSTRAINT IF EXISTS osra_hala_egtimaia_id_fkey;
ALTER TABLE osra DROP CONSTRAINT IF EXISTS osra_hala_sehia_id_fkey;
ALTER TABLE osra DROP CONSTRAINT IF EXISTS osra_mostwa_id_fkey;
ALTER TABLE person DROP CONSTRAINT IF EXISTS person_karaba_id_fkey;
ALTER TABLE person DROP CONSTRAINT IF EXISTS person_mostwa_id_fkey;
ALTER TABLE person DROP CONSTRAINT IF EXISTS person_hala_egtimaia_id_fkey;
ALTER TABLE person DROP CONSTRAINT IF EXISTS person_hala_sehia_id_fkey;
ALTER TABLE person DROP CONSTRAINT IF EXISTS person_stage_id_fkey;
ALTER TABLE person DROP CONSTRAINT IF EXISTS person_father_id_fkey;
ALTER TABLE count_aid DROP CONSTRAINT IF EXISTS count_aid_khdma_id_fkey;
ALTER TABLE inter_icon DROP CONSTRAINT IF EXISTS inter_icon_icon_id_fkey;

CREATE INDEX IF NOT EXISTS idx_streets_area_id ON streets(area_id);
CREATE INDEX IF NOT EXISTS idx_osra_area_id ON osra(area_id);
CREATE INDEX IF NOT EXISTS idx_osra_street_id ON osra(street_id);
CREATE INDEX IF NOT EXISTS idx_osra_name ON osra(osra_name);
CREATE INDEX IF NOT EXISTS idx_person_osra_id ON person(osra_id);
CREATE INDEX IF NOT EXISTS idx_person_father_id ON person(father_id);
CREATE INDEX IF NOT EXISTS idx_eatraf_person_id ON eatraf(person_id);
CREATE INDEX IF NOT EXISTS idx_visits_osra_id ON visits(osra_id);
CREATE INDEX IF NOT EXISTS idx_monasba_osra_id ON monasba(osra_id);
CREATE INDEX IF NOT EXISTS idx_count_aid_osra_id ON count_aid(osra_id);
CREATE INDEX IF NOT EXISTS idx_count_2_osra_id ON count_2(osra_id);
CREATE INDEX IF NOT EXISTS idx_masrofat_osra_id ON masrofat(osra_id);
";
    }

    private static async Task SeedDefaultDataOrImportInitialSqliteAsync(
        NpgsqlConnection conn,
        string? configuredSqlitePath,
        ILogger logger)
    {
        await using var checkCmd = new NpgsqlCommand("SELECT COUNT(*) FROM users;", conn);
        var userCount = Convert.ToInt64(await checkCmd.ExecuteScalarAsync() ?? 0L);

        await using var checkOsraCmd = new NpgsqlCommand("SELECT COUNT(*) FROM osra;", conn);
        var osraCount = Convert.ToInt64(await checkOsraCmd.ExecuteScalarAsync() ?? 0L);

        if (userCount == 0 && osraCount == 0)
        {
            var resolvedPath = ResolveInitialSqliteFile(configuredSqlitePath);
            if (resolvedPath != null && File.Exists(resolvedPath))
            {
                logger.LogInformation("PostgreSQL database is empty. Importing initial data from '{SqlitePath}'...", resolvedPath);
                try { await ImportFromSqliteFileInternalAsync(conn, resolvedPath, logger); }
                catch (Exception ex) when (ex is SqliteException or PostgresException)
                {
                    logger.LogWarning(ex, "Initial SQLite import failed; starting the empty server with defaults. Source file preserved.");
                }
            }
        }

        await EnsureAllPermissionsAndDefaultsAsync(conn);
    }

    public static async Task EnsureAllPermissionsAndDefaultsAsync(NpgsqlConnection conn, NpgsqlTransaction? tx = null)
    {
        // Rename the permission before seeding, preserving existing grants.
        await using (var branding = new NpgsqlCommand(@"
UPDATE icon SET icon_name = 'تقرير العضوية الكنسية'
 WHERE icon_name = 'تقرير اخوة الرب' AND NOT EXISTS (SELECT 1 FROM icon WHERE icon_name = 'تقرير العضوية الكنسية');
UPDATE inter_icon SET icon_id = (SELECT icon_id FROM icon WHERE icon_name = 'تقرير العضوية الكنسية'), icon_name = 'تقرير العضوية الكنسية' WHERE icon_name = 'تقرير اخوة الرب';
DELETE FROM icon WHERE icon_name = 'تقرير اخوة الرب';
UPDATE settings SET setting_value = 'Church Membership - العضوية الكنسية' WHERE setting_key IN ('service_name', 'serviceName');", conn, tx))
        { await branding.ExecuteNonQueryAsync(); }

        await using (var userCountCmd = new NpgsqlCommand("SELECT COUNT(*) FROM users;", conn, tx))
        {
            var count = Convert.ToInt64(await userCountCmd.ExecuteScalarAsync() ?? 0L);
            if (count == 0)
            {
                await using var insertAdmin = new NpgsqlCommand(
                    "INSERT INTO users (user_name, pass_word) VALUES ('admin', '1234') ON CONFLICT (user_name) DO NOTHING;",
                    conn, tx);
                await insertAdmin.ExecuteNonQueryAsync();
            }
        }

        // ضمان وجود جميع الأيقونات الـ 18 المطلوبة في التطبيق (مطابق لـ database_helper.dart v10)
        foreach (var permName in AllRequiredPermissions)
        {
            await using var iconCmd = new NpgsqlCommand(
                "INSERT INTO icon (icon_name) VALUES (@name) ON CONFLICT (icon_name) DO NOTHING;",
                conn, tx);
            iconCmd.Parameters.AddWithValue("@name", permName);
            await iconCmd.ExecuteNonQueryAsync();
        }

        // الحصول على pass_id للمدير الرئيسي (pass_id = 1 أو أول مستخدم في الجدول)
        int? adminPassId = null;
        await using (var adminCmd = new NpgsqlCommand("SELECT pass_id FROM users ORDER BY pass_id ASC LIMIT 1;", conn, tx))
        {
            var scalar = await adminCmd.ExecuteScalarAsync();
            if (scalar != null && scalar != DBNull.Value)
            {
                adminPassId = Convert.ToInt32(scalar);
            }
        }

        if (adminPassId.HasValue)
        {
            foreach (var permName in AllRequiredPermissions)
            {
                await using var checkPerm = new NpgsqlCommand(
                    "SELECT COUNT(*) FROM inter_icon WHERE pass_id = @passId AND icon_name = @name;",
                    conn, tx);
                checkPerm.Parameters.AddWithValue("@passId", adminPassId.Value);
                checkPerm.Parameters.AddWithValue("@name", permName);
                var exists = Convert.ToInt64(await checkPerm.ExecuteScalarAsync() ?? 0L) > 0;
                if (!exists)
                {
                    await using var insertPerm = new NpgsqlCommand(@"
                        INSERT INTO inter_icon (pass_id, icon_id, icon_name, check_1)
                        SELECT @passId, icon_id, @name, 1 FROM icon WHERE icon_name = @name LIMIT 1;",
                        conn, tx);
                    insertPerm.Parameters.AddWithValue("@passId", adminPassId.Value);
                    insertPerm.Parameters.AddWithValue("@name", permName);
                    await insertPerm.ExecuteNonQueryAsync();
                }
            }
        }

        // ضمان صلاحية 'الاعتراف' لجميع المستخدمين إذا لم تكن مضافة لهم (مطابق لترقية v10 في database_helper.dart)
        await using (var eatrafCmd = new NpgsqlCommand(@"
            INSERT INTO inter_icon (pass_id, icon_id, icon_name, check_1)
            SELECT u.pass_id, i.icon_id, 'الاعتراف', 1
            FROM users u
            CROSS JOIN icon i
            WHERE i.icon_name = 'الاعتراف'
              AND NOT EXISTS (
                  SELECT 1 FROM inter_icon ii
                  WHERE ii.pass_id = u.pass_id AND ii.icon_name = 'الاعتراف'
              );", conn, tx))
        {
            await eatrafCmd.ExecuteNonQueryAsync();
        }

        const string defaultSettingsSql = @"
INSERT INTO settings (setting_key, setting_value) VALUES
    ('church_name', 'كنيسة القديسين بطرس وبولس'),
    ('bishop_name', '')
ON CONFLICT (setting_key) DO NOTHING;
";
        await using (var settingsCmd = new NpgsqlCommand(defaultSettingsSql, conn, tx))
        {
            await settingsCmd.ExecuteNonQueryAsync();
        }
    }

    private static string? ResolveInitialSqliteFile(string? configuredPath)
    {
        var candidates = new List<string>();
        if (!string.IsNullOrWhiteSpace(configuredPath))
        {
            candidates.Add(Path.GetFullPath(Path.Combine(AppContext.BaseDirectory, configuredPath)));
            candidates.Add(Path.GetFullPath(configuredPath));
        }

        var baseDir = AppContext.BaseDirectory;
        candidates.Add(Path.Combine(baseDir, "church_membership.db"));
        candidates.Add(Path.Combine(baseDir, "assets", "database", "church_membership.db"));
        for (var depth = 0; depth <= 3; depth++)
        {
            var root = baseDir;
            for (var i = 0; i < depth; i++) root = Path.Combine(root, "..");
            candidates.Add(Path.GetFullPath(Path.Combine(root, "data", "flutter_assets", "assets", "database", "church_membership.db")));
        }
        candidates.Add(Path.Combine(baseDir, "eakhow_elrab.db"));
        candidates.Add(Path.Combine(baseDir, "data", "flutter_assets", "assets", "database", "eakhow_elrab.db"));
        candidates.Add(Path.GetFullPath(Path.Combine(baseDir, "..", "eakhow_elrab.db")));
        candidates.Add(Path.GetFullPath(Path.Combine(baseDir, "..", "data", "flutter_assets", "assets", "database", "eakhow_elrab.db")));
        candidates.Add(Path.GetFullPath(Path.Combine(baseDir, "..", "..", "eakhow_elrab.db")));
        candidates.Add(Path.GetFullPath(Path.Combine(baseDir, "..", "..", "data", "flutter_assets", "assets", "database", "eakhow_elrab.db")));
        candidates.Add(Path.GetFullPath(Path.Combine(baseDir, "..", "assets", "database", "eakhow_elrab.db")));
        candidates.Add(Path.GetFullPath(Path.Combine(baseDir, "..", "..", "..", "..", "assets", "database", "eakhow_elrab.db")));

        return candidates.FirstOrDefault(File.Exists);
    }

    public static async Task ImportFromSqliteFileInternalAsync(
        NpgsqlConnection pgConn,
        string sqliteFilePath,
        ILogger? logger = null)
    {
        await using var sqliteConn = new SqliteConnection($"Data Source={sqliteFilePath};Mode=ReadOnly");
        await sqliteConn.OpenAsync();

        await using var tx = await pgConn.BeginTransactionAsync();
        try
        {
            // تعطيل قيود المفاتيح الأجنبية مؤقتاً أثناء الاستيراد الشامل لتفادي مشاكل البيانات التاريخية غير المتطابقة
            await using (var replicaCmd = new NpgsqlCommand("SET LOCAL session_replication_role = 'replica';", pgConn, tx))
            {
                await replicaCmd.ExecuteNonQueryAsync();
            }

            // تفريغ الجداول بترتيب عكسي
            for (int i = OrderedTables.Length - 1; i >= 0; i--)
            {
                var table = OrderedTables[i];
                await using var delCmd = new NpgsqlCommand($"DELETE FROM \"{table}\";", pgConn, tx);
                await delCmd.ExecuteNonQueryAsync();
            }

            // نسخ كل جدول بالترتيب
            foreach (var table in OrderedTables)
            {
                await CopySqliteTableToPostgresAsync(sqliteConn, pgConn, tx, table, logger);
            }

            // ترقية الصلاحيات والأيقونات إلى النسخة 10 ومزامنة جميع المتسلسلات
            await EnsureAllPermissionsAndDefaultsAsync(pgConn, tx);
            await SyncAllSequencesAsync(pgConn, tx);
            await tx.CommitAsync();
        }
        catch
        {
            await tx.RollbackAsync();
            throw;
        }
    }

    private static async Task CopySqliteTableToPostgresAsync(
        SqliteConnection sqliteConn,
        NpgsqlConnection pgConn,
        NpgsqlTransaction tx,
        string table,
        ILogger? logger)
    {
        // التحقق من وجود الجدول في ملف SQLite
        await using (var existsCmd = sqliteConn.CreateCommand())
        {
            existsCmd.CommandText = "SELECT 1 FROM sqlite_master WHERE type='table' AND lower(name)=lower(@t);";
            existsCmd.Parameters.AddWithValue("@t", table);
            if (await existsCmd.ExecuteScalarAsync() == null)
            {
                return;
            }
        }

        // جلب أعمدة الجدول في PostgreSQL
        var pgColumns = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        await using (var colCmd = new NpgsqlCommand(
            "SELECT column_name FROM information_schema.columns WHERE table_schema = 'public' AND table_name = @t;",
            pgConn, tx))
        {
            colCmd.Parameters.AddWithValue("@t", table.ToLowerInvariant());
            await using var colReader = await colCmd.ExecuteReaderAsync();
            while (await colReader.ReadAsync())
            {
                pgColumns.Add(colReader.GetString(0));
            }
        }

        await using var selectCmd = sqliteConn.CreateCommand();
        selectCmd.CommandText = $"SELECT * FROM \"{table}\";";
        await using var reader = await selectCmd.ExecuteReaderAsync();

        var matchedColumns = new List<(int Ordinal, string Name)>();
        for (int i = 0; i < reader.FieldCount; i++)
        {
            var colName = reader.GetName(i).ToLowerInvariant();
            if (pgColumns.Contains(colName))
            {
                matchedColumns.Add((i, colName));
            }
        }

        if (matchedColumns.Count == 0) return;

        var colListSql = string.Join(", ", matchedColumns.Select(c => $"\"{c.Name}\""));
        var paramListSql = string.Join(", ", matchedColumns.Select((_, idx) => $"@p{idx}"));
        var insertSql = $"INSERT INTO \"{table}\" ({colListSql}) VALUES ({paramListSql}) ON CONFLICT DO NOTHING;";

        int count = 0;
        while (await reader.ReadAsync())
        {
            await using var insertCmd = new NpgsqlCommand(insertSql, pgConn, tx);
            for (int idx = 0; idx < matchedColumns.Count; idx++)
            {
                var ordinal = matchedColumns[idx].Ordinal;
                object val = reader.IsDBNull(ordinal) ? DBNull.Value : reader.GetValue(ordinal);
                insertCmd.Parameters.AddWithValue($"@p{idx}", val);
            }
            await insertCmd.ExecuteNonQueryAsync();
            count++;
        }

        logger?.LogInformation("Imported {Count} rows into '{Table}'.", count, table);
    }

    public static async Task SyncAllSequencesAsync(NpgsqlConnection conn, NpgsqlTransaction? tx = null)
    {
        foreach (var (table, pk) in SingleIdPrimaryKeys)
        {
            var sql = $@"
SELECT setval(
    pg_get_serial_sequence('{table}', '{pk}'),
    COALESCE((SELECT MAX(""{pk}"") FROM ""{table}""), 0) + 1,
    false
);";
            await using var cmd = new NpgsqlCommand(sql, conn, tx);
            await cmd.ExecuteNonQueryAsync();
        }
    }
}
