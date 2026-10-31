# خطة التحويل التفصيلية الشاملة (من SQLite محلي إلى معمارية متزامنة لحظياً متعددة الأجهزة + مدير السيرفر + المثبت)
**المشروع المستهدف:** `e:\el odwia\project` (`abona_flemoon` — برنامج العضوية الكنسية / إخوة الرب)  
**المهارة المرجعية المعتمدة:** `E:\Prog Progs\skills\flutter-sqlite-dotnet-postgres` (مع المراجع الثلاثة `01-contracts-data-and-delivery.md`، `02-realtime-ui.md`، `03-performance.md`)  
**المشاريع المرجعية لمدير السيرفر والمثبت:**
- `E:\POWER\Offline_First_Sync\sales_flutter_app\DrSalesServerManager`
- `E:\Final\petros_pols_flutter\SundaySchoolServerManager` & `SundaySchool.SyncServer` & `installer`

---

## ⚠️ تعليمات صارمة للموديل المنفذ (`gemini3.8flash`) — اقرأها قبل كتابة أي سطر كود!

1. **الالتزام الحرفي بالمعمارية والعقود (Contracts):**
   - لا تغير أسماء الحقول في JSON أو مسارات الـ Endpoints أو أسماء الأحداث في SignalR نهائياً.
   - هذا المشروع يستخدم **`sqflite` / `sqflite_common_ffi`** (عبر `DatabaseHelper().database`) مع **`provider` (`ChangeNotifier`)**، ولا يستخدم Drift أو Riverpod. لذلك طبقة الجسر في Flutter (`lib/sync/dotnet_postgres_database.dart`) يجب أن تُنفذ واجهات `Database` و`Transaction` و`Batch` الخاصة بـ `sqflite_common_ffi` لكي تعمل جميع الـ Repositories السبعة (`AuthRepository`, `FamilyRepository`, `PersonRepository`, `FinancialRepository`, `LookupRepository`, `SearchRepository`, `SettingsRepository`, `TrackingRepository`) **بدون تغيير منطق الأعمال أو الاستعلامات فيها**.
2. **ممنوعات قاطعة أثناء التنفيذ:**
   - ❌ **ممنوع** تشغيل `flutter analyze` على كامل المشروع (لأنه يستهلك الذاكرة والوقت). استخدم دائماً `dart analyze <ملف_محدد>` على الملفات التي أنشأتها أو عدلتها فقط.
   - ❌ **ممنوع** استخدام الترقيم الموضعي `$1, $2` في `SqlDialectTranslator`، بل استخدم دائماً `@p0, @p1, ...` مع استبدال `?` خارج النصوص فقط (`OutsideSingleQuotes`).
   - ❌ **ممنوع** ترك أعمدة الهوية التسلسلية (`osra_id`, `person_id`, إلخ) بقيمة `null` عند تنفيذ `INSERT` في PostgreSQL؛ يجب حذف المفتاح الأساسي إذا كانت قيمته `null` في `DotNetPostgresDatabase.insert()` وفي السيرفر قبل إرسال `INSERT` إلى PostgreSQL لكي يولّد `SERIAL` الرقم تلقائياً.
   - ❌ **ممنوع** إرسال إشعارات SignalR أثناء فتح Transaction قبل تنفيذ `COMMIT`؛ يجب تجميع الجداول المتأثرة وإرسال حدث واحد `DatabaseChanged` بعد نجاح `Commit` فقط.
   - ❌ **ممنوع** استخدام نفس منافذ (Ports) البرامج الأخرى على جهاز المستخدم (`DrSales` يستخدم `3000/5433`، و`SundaySchool` يستخدم `5050/5434`). استخدم المنافذ المخصصة لهذا المشروع حصراً:
     - **منفذ API السيرفر (`.NET 8`):** `5060`
     - **منفذ PostgreSQL المحمول:** `5435`
     - **اسم قاعدة بيانات PostgreSQL:** `abona_flemoon`
     - **مجلد بيانات PostgreSQL المحمول:** `AbonaFlemoon_ServerData`
     - **اسم Mutex مدير السيرفر:** `AbonaFlemoon_ServerManager_5060_v1`
3. **أمر المراجعة الإلزامي في نهاية التنفيذ:**
   - بعد الانتهاء من تنفيذ جميع المراحل والتحقق منها، **يجب عليك** طباعة "أمر المراجعة النهائي" الموجود في **القسم التاسع (Section 9)** في نهاية هذا الملف نصياً كما هو للمستخدم لكي ينسخه ويلصقه في محادثة جديدة مع الموديل المراجع.

---

## 1. نظرة عامة على هيكل الملفات المطلوب إنشاؤها وتعديلها

### أ) الملفات الجديدة التي سيتم إنشاؤها:
```text
e:\el odwia\project\
├── AbonaFlemoon.SyncServer\                      # مشروع الـ Backend (.NET 8 Web API + SignalR + Npgsql)
│   ├── AbonaFlemoon.SyncServer.csproj
│   ├── Program.cs
│   ├── appsettings.json
│   ├── Controllers\
│   │   ├── AuthController.cs
│   │   └── StorageController.cs
│   ├── Hubs\
│   │   └── SyncHub.cs
│   ├── Models\
│   │   └── ApiModels.cs
│   └── Services\
│       ├── PostgresSchemaInitializer.cs
│       ├── SqlDialectTranslator.cs
│       └── StorageService.cs
│
├── AbonaFlemoonServerManager\                    # تطبيق مدير السيرفر والأنفاق (WinForms .NET 8)
│   ├── AbonaFlemoonServerManager.csproj
│   ├── Program.cs
│   ├── ServerSupervisor.cs
│   ├── TunnelSupervisor.cs
│   ├── MainForm.cs
│   └── TunnelManagerForm.cs
│
├── lib\sync\                                     # طبقة التزامن والاتصال اللحظي في Flutter
│   ├── server_config.dart
│   ├── server_connection_service.dart
│   ├── dotnet_postgres_database.dart
│   ├── signalr_sync_service.dart
│   ├── data_sync_coordinator.dart
│   └── server_connection_dialog.dart
│
├── installer\                                    # ملفات المثبت وسكربتات إدارة السيرفر
│   ├── AbonaFlemoonSetup.iss
│   ├── install-server.ps1
│   ├── repair-server.ps1
│   └── uninstall-server.ps1
│
├── build_and_make_installer.bat                  # سكربت البناء الشامل وتوليد المثبت النهائي
└── test\
    └── remote_database_contract_test.dart        # اختبارات العقد والترجمة ودمج المعاملات
```

### ب) الملفات الحالية التي سيتم تعديلها:
1. `pubspec.yaml` — إضافة الحزم: `http: ^1.2.2`، `shared_preferences: ^2.3.2`، `web_socket_channel: ^3.0.1`.
2. `lib/data/database/database_helper.dart` — دعم التبديل الفوري بين `DotNetPostgresDatabase` (في وضع السيرفر) و`sqflite` المحلي (في الوضع المحلي) + توحيد مسار قاعدة البيانات المحلية `getLocalDatabasePath()` + دوال `reopenDatabase()` و`replaceDatabaseFile()`.
3. `lib/data/services/backup_service.dart` — توحيد مسار قاعدة البيانات المحلية مع `DatabaseHelper` + دعم التصدير والاستيراد المباشر عبر السيرفر (`/api/storage/sqlite/export` و`/api/storage/sqlite/import`) عندما يكون `ServerConfig.isServerMode == true`.
4. `lib/providers/family_provider.dart` — حفظ آخر فلتر بحث وإضافة `refreshSilently()` بدون وميض (`_isLoading`) لتحديث الأسر وأفراد الأسرة المحددة لحظياً عند وصول إشعار SignalR + تحويل `member_count` بأمان إلى `int`.
5. `lib/providers/lookup_provider.dart` — إضافة `refreshSilently()` لتحديث جميع جداول الثوابت والآباء والخدام بدون وميض.
6. `lib/providers/tracking_provider.dart` — حفظ آخر `personId` و`familyId` وإضافة `refreshSilently()` + تحويل `addBatchVisits` لاستخدام `db.batch()` لرفع الأداء عبر الشبكة.
7. `lib/providers/financial_provider.dart` — حفظ آخر `familyId` وإضافة `refreshSilently()`.
8. `lib/providers/auth_provider.dart` — إضافة `refreshSilently()` لتحديث صلاحيات المستخدم الحالي وقائمة المستخدمين لحظياً.
9. `lib/providers/settings_provider.dart` — إضافة `refreshSilently()` لتحديث الإعدادات لحظياً.
10. `lib/main.dart` و`lib/app.dart` — تهيئة `ServerBootstrap.initialize()` وتسجيل `ServerConfigProvider` و`SignalRSyncProvider` ولف التطبيق بـ `DataSyncCoordinator`.
11. `lib/ui/screens/auth/login_screen.dart` — إضافة زر حالة وإعدادات الاتصال بالسيرفر (`ServerConnectionStatusButton`) أعلى شاشة تسجيل الدخول.
12. `lib/ui/screens/home/home_screen.dart` — إضافة زر ومؤشر الاتصال اللحظي بالسيرفر (`ServerConnectionStatusButton`) في شريط الأدوات العلوي (`AppBar.actions`).
13. `lib/ui/screens/admin/users_screen.dart` و`lib/ui/screens/reports/birthdays_screen.dart` — الاستماع للتحديثات الصامتة من `AuthProvider` و`FamilyProvider` لتحديث القوائم المحلية تلقائياً.
14. `android/app/src/main/AndroidManifest.xml` — إضافة صلاحية `INTERNET` وتفعيل `android:usesCleartextTraffic="true"` لدعم الاتصال بالسيرفر عبر HTTP على الشبكة المحلية (LAN).

---

## المرحلة الأولى (Phase 1): بناء سيرفر التزامن الخلفي `AbonaFlemoon.SyncServer` (.NET 8 + PostgreSQL + SignalR)

### 1.1 ملف المشروع `AbonaFlemoon.SyncServer/AbonaFlemoon.SyncServer.csproj`
أنشئ ملف المشروع بالإعدادات والحزم التالية بالضبط:
```xml
<Project Sdk="Microsoft.NET.Sdk.Web">

  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="Microsoft.AspNetCore.OpenApi" Version="8.0.25" />
    <PackageReference Include="Microsoft.Data.Sqlite" Version="8.0.14" />
    <PackageReference Include="Npgsql" Version="8.0.6" />
    <PackageReference Include="Swashbuckle.AspNetCore" Version="6.6.2" />
  </ItemGroup>

</Project>
```

### 1.2 ملف الإعدادات `AbonaFlemoon.SyncServer/appsettings.json`
```json
{
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning"
    }
  },
  "AllowedHosts": "*",
  "ConnectionStrings": {
    "Postgres": "Host=127.0.0.1;Port=5435;Database=abona_flemoon;Username=postgres;Password=postgres;Pooling=true;MinPoolSize=2;MaxPoolSize=100;ConnectionIdleLifetime=300;Timeout=15;CommandTimeout=60;KeepAlive=30"
  },
  "SqliteSeed": {
    "InitialDbPath": "../assets/database/eakhow_elrab.db"
  }
}
```

### 1.3 نماذج البيانات والعقود `AbonaFlemoon.SyncServer/Models/ApiModels.cs`
يجب الالتزام الحرفي بهذه النماذج (DTOs):
```csharp
using System.Text.Json;
using System.Text.Json.Serialization;

namespace AbonaFlemoon.SyncServer.Models;

public class SqlParamDto
{
    [JsonPropertyName("type")]
    public string Type { get; set; } = "null";

    [JsonPropertyName("value")]
    public JsonElement? Value { get; set; }
}

public class SqlStatementRequest
{
    [JsonPropertyName("sql")]
    public string Sql { get; set; } = string.Empty;

    [JsonPropertyName("params")]
    public List<SqlParamDto> Params { get; set; } = new();

    [JsonPropertyName("txId")]
    public string? TxId { get; set; }
}

public class SqlBatchStatementDto
{
    [JsonPropertyName("sql")]
    public string Sql { get; set; } = string.Empty;

    [JsonPropertyName("params")]
    public List<SqlParamDto> Params { get; set; } = new();
}

public class SqlBatchRequest
{
    [JsonPropertyName("statements")]
    public List<SqlBatchStatementDto> Statements { get; set; } = new();

    [JsonPropertyName("txId")]
    public string? TxId { get; set; }
}

public class TxActionRequest
{
    [JsonPropertyName("txId")]
    public string TxId { get; set; } = string.Empty;
}

public class QueryResultResponse
{
    [JsonPropertyName("rows")]
    public List<Dictionary<string, object?>> Rows { get; set; } = new();
}

public class ExecuteResultResponse
{
    [JsonPropertyName("affectedRows")]
    public int AffectedRows { get; set; }
}

public class InsertResultResponse
{
    [JsonPropertyName("lastInsertRowId")]
    public long LastInsertRowId { get; set; }
}

public class TxBeginResponse
{
    [JsonPropertyName("txId")]
    public string TxId { get; set; } = string.Empty;
}

public class DatabaseChangeNotification
{
    [JsonPropertyName("tables")]
    public List<string> Tables { get; set; } = new();

    [JsonPropertyName("operation")]
    public string Operation { get; set; } = "write";

    [JsonPropertyName("timestampUtc")]
    public DateTime TimestampUtc { get; set; } = DateTime.UtcNow;
}
```

### 1.4 تهيئة مخطط PostgreSQL لجميع الـ 22 جدولاً والاستيراد التلقائي من SQLite (`AbonaFlemoon.SyncServer/Services/PostgresSchemaInitializer.cs`)
**مهم جداً:** قاعدة بيانات `eakhow_elrab.db` تحتوي على **22 جدولاً بالضبط**. يجب تعريفها بترتيب الاعتمادية (Foreign Keys)، مع تعريف:
- `SingleIdPrimaryKeys` (المفتاح الأساسي التسلسلي لكل جدول له عمود `SERIAL PRIMARY KEY` ليتم إرجاعه في `RETURNING` ومزامنة الـ `SEQUENCE` الخاصة به، وحذفه عند الـ `INSERT` إذا أُرسل بـ `null`).
- `ConflictTargetColumns` (الأعمدة المستهدفة عند تحويل `INSERT OR REPLACE`، وتشمل المفاتيح الأساسية).
- `CanonicalColumnNames` (تطبيع أسماء الأعمدة عند القراءة لكي تطابق ما تتوقعه نماذج Flutter بنسبة 100%).
- الاستيراد الأولي التلقائي من ملف `eakhow_elrab.db` إذا كانت قاعدة PostgreSQL فارغة عند أول تشغيل، متبوعاً باستدعاء `SyncAllSequencesAsync`.

اكتب الكود الكامل التالي في `AbonaFlemoon.SyncServer/Services/PostgresSchemaInitializer.cs`:
```csharp
using Microsoft.Data.Sqlite;
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
                logger.LogInformation("Creating PostgreSQL database '{Database}'...", targetDatabase);
                await using var createDbCmd = new NpgsqlCommand($"CREATE DATABASE \"{targetDatabase}\";", adminConn);
                await createDbCmd.ExecuteNonQueryAsync();
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
    icon_id INTEGER REFERENCES icon(icon_id) ON DELETE SET NULL,
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
    karaba_id INTEGER REFERENCES karaba(karaba_id) ON DELETE SET NULL,
    e_s_id INTEGER REFERENCES e_s(e_s_id) ON DELETE SET NULL,
    area_id INTEGER REFERENCES areas(area_id) ON DELETE SET NULL,
    street_id INTEGER REFERENCES streets(street_id) ON DELETE SET NULL,
    dalil_name TEXT,
    emara TEXT,
    door TEXT,
    shaka TEXT,
    r_o TEXT,
    phone TEXT,
    number INTEGER DEFAULT 0,
    hala_egtimaia_id INTEGER REFERENCES hala_egtimaia(hala_egtimaia_id) ON DELETE SET NULL,
    rakm_komy TEXT,
    code INTEGER,
    hala_sehia_id INTEGER REFERENCES hala_sehia(hala_sehia_id) ON DELETE SET NULL,
    mostwa_id INTEGER REFERENCES mostwa(mostwa_id) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS person (
    person_id SERIAL PRIMARY KEY,
    person_name TEXT NOT NULL,
    osra_id INTEGER NOT NULL REFERENCES osra(osra_id) ON DELETE CASCADE,
    karaba_id INTEGER REFERENCES karaba(karaba_id) ON DELETE SET NULL,
    birth_date TEXT,
    mostwa_id INTEGER REFERENCES mostwa(mostwa_id) ON DELETE SET NULL,
    moahil TEXT,
    date_moiahil TEXT,
    hala_egtimaia_id INTEGER REFERENCES hala_egtimaia(hala_egtimaia_id) ON DELETE SET NULL,
    hala_sehia_id INTEGER REFERENCES hala_sehia(hala_sehia_id) ON DELETE SET NULL,
    wazefa TEXT,
    place_work TEXT,
    mobile TEXT,
    facebook TEXT,
    father TEXT,
    stage_id INTEGER REFERENCES stage(stage_id) ON DELETE SET NULL,
    father_id INTEGER REFERENCES fathers(father_id) ON DELETE SET NULL,
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
    khdma_id INTEGER REFERENCES khdma(khdma_id) ON DELETE SET NULL,
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
                await ImportFromSqliteFileInternalAsync(conn, resolvedPath, logger);
                return;
            }
        }

        // ضمان وجود حساب admin والصلاحيات والإعدادات الافتراضية على الأقل
        const string defaultSeedSql = @"
INSERT INTO users (user_name, pass_word) VALUES ('admin', 'admin') ON CONFLICT (user_name) DO NOTHING;

INSERT INTO icon (icon_name) VALUES
    ('الأسر'),
    ('التقارير'),
    ('الافتقاد'),
    ('المساعدات'),
    ('الثوابت'),
    ('المستخدمين'),
    ('الإعدادات'),
    ('الصيانة')
ON CONFLICT (icon_name) DO NOTHING;

INSERT INTO settings (setting_key, setting_value) VALUES
    ('church_name', 'كنيسة السيدة العذراء مريم'),
    ('service_name', 'خدمة إخوة الرب'),
    ('theme_mode', 'light')
ON CONFLICT (setting_key) DO NOTHING;
";
        await using var seedCmd = new NpgsqlCommand(defaultSeedSql, conn);
        await seedCmd.ExecuteNonQueryAsync();
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
        candidates.Add(Path.Combine(baseDir, "eakhow_elrab.db"));
        candidates.Add(Path.Combine(baseDir, "data", "flutter_assets", "assets", "database", "eakhow_elrab.db"));
        candidates.Add(Path.GetFullPath(Path.Combine(baseDir, "..", "eakhow_elrab.db")));
        candidates.Add(Path.GetFullPath(Path.Combine(baseDir, "..", "data", "flutter_assets", "assets", "database", "eakhow_elrab.db")));
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
```

### 1.5 مترجم لهجات SQL من SQLite إلى PostgreSQL (`AbonaFlemoon.SyncServer/Services/SqlDialectTranslator.cs`)
**انتبه جيداً:** بالإضافة للقواعد العشر القياسية في المهارة، هذا المشروع يحتوي على استعلامات خاصة في `PersonRepository` و`SearchRepository` و`LookupRepository`:
1. `strftime('%m', birth_date)` -> يجب ترجمته إلى `SUBSTRING((birth_date)::text FROM 6 FOR 2)`.
2. `strftime('%Y', 'now')` -> `TO_CHAR(NOW(), 'YYYY')` و`strftime('%Y', expr)` -> `SUBSTRING((expr)::text FROM 1 FOR 4)`.
3. `strftime('%Y%m%d', 'now')` -> `CAST(TO_CHAR(NOW(), 'YYYYMMDD') AS INTEGER)`.
4. `date(expr)` في `SearchRepository.complexSearch` -> `(expr)::text`.
5. `INSERT OR REPLACE INTO <table_name>`: إذا كانت الأعمدة المدرجة لا تحتوي على المفتاح الأساسي وكان للجدول عمود فريد في `UniqueNameColumns` (مثل `INSERT OR REPLACE INTO areas (area_name) VALUES (?)`)، يتم وضع هدف التعارض على العمود الفريد (`ON CONFLICT ("area_name") DO UPDATE SET ...`)، وإلا على `ConflictTargetColumns`.

اكتب الكود الكامل التالي في `AbonaFlemoon.SyncServer/Services/SqlDialectTranslator.cs`:
```csharp
using System.Text;
using System.Text.RegularExpressions;

namespace AbonaFlemoon.SyncServer.Services;

public sealed class TranslatedSqlCommand
{
    public string Sql { get; init; } = string.Empty;
    public bool IsNoOpPragma { get; init; }
    public string? TargetTable { get; init; }
    public string? ReturningPrimaryKeyColumn { get; init; }
    public HashSet<string> AffectedTables { get; init; } = new(StringComparer.OrdinalIgnoreCase);
}

public static class SqlDialectTranslator
{
    public static TranslatedSqlCommand Translate(string rawSql, bool appendReturningForInsert = false)
    {
        if (string.IsNullOrWhiteSpace(rawSql))
        {
            return new TranslatedSqlCommand { Sql = string.Empty, IsNoOpPragma = true };
        }

        var sql = rawSql.Trim();

        // Rule 1: PRAGMA interception
        if (sql.StartsWith("PRAGMA", StringComparison.OrdinalIgnoreCase))
        {
            return new TranslatedSqlCommand
            {
                Sql = string.Empty,
                IsNoOpPragma = true
            };
        }

        var affectedTables = ExtractAffectedTables(sql);
        string? targetTable = affectedTables.FirstOrDefault();

        // Rule 6: datetime('now', '-N days/months/hours') & datetime('now')
        sql = Regex.Replace(
            sql,
            @"datetime\s*\(\s*'now'\s*,\s*'([+-]?\d+)\s+(day|days|month|months|year|years|hour|hours|minute|minutes)'\s*\)",
            m =>
            {
                var amount = m.Groups[1].Value;
                var unit = m.Groups[2].Value;
                var op = amount.StartsWith('-') ? "-" : "+";
                var absVal = amount.TrimStart('+', '-');
                return $"(NOW() {op} INTERVAL '{absVal} {unit}')";
            },
            RegexOptions.IgnoreCase);

        sql = Regex.Replace(
            sql,
            @"datetime\s*\(\s*'now'(?:\s*,\s*'localtime')?\s*\)",
            "NOW()",
            RegexOptions.IgnoreCase);

        // ترجمة دوال التواريخ الخاصة بمشروع العضوية الكنسية (strftime & date)
        // 1) CAST(strftime('%Y%m%d', 'now') AS INTEGER) أو strftime('%Y%m%d', 'now')
        sql = Regex.Replace(
            sql,
            @"strftime\s*\(\s*'%Y%m%d'\s*,\s*'now'\s*\)",
            "TO_CHAR(NOW(), 'YYYYMMDD')",
            RegexOptions.IgnoreCase);

        // 2) strftime('%Y', 'now')
        sql = Regex.Replace(
            sql,
            @"strftime\s*\(\s*'%Y'\s*,\s*'now'\s*\)",
            "TO_CHAR(NOW(), 'YYYY')",
            RegexOptions.IgnoreCase);

        // 3) strftime('%m', expr) -> SUBSTRING((expr)::text FROM 6 FOR 2)
        sql = Regex.Replace(
            sql,
            @"strftime\s*\(\s*'%m'\s*,\s*([^)]+)\)",
            "SUBSTRING(($1)::text FROM 6 FOR 2)",
            RegexOptions.IgnoreCase);

        // 4) strftime('%Y', expr) -> SUBSTRING((expr)::text FROM 1 FOR 4)
        sql = Regex.Replace(
            sql,
            @"strftime\s*\(\s*'%Y'\s*,\s*([^)]+)\)",
            "SUBSTRING(($1)::text FROM 1 FOR 4)",
            RegexOptions.IgnoreCase);

        // 5) date(expr) -> (expr)::text (في مقارنة النصوص YYYY-MM-DD)
        sql = Regex.Replace(
            sql,
            @"\bdate\s*\(\s*([^)]+)\)",
            "($1)::text",
            RegexOptions.IgnoreCase);

        // Rule 7: IFNULL(a, b) -> COALESCE(a, b)
        sql = Regex.Replace(sql, @"\bIFNULL\s*\(", "COALESCE(", RegexOptions.IgnoreCase);

        // Rule 8: json_extract(col, '$.field') -> (col::jsonb ->> 'field')
        sql = Regex.Replace(
            sql,
            @"json_extract\s*\(\s*([^,]+?)\s*,\s*'\$\.([a-zA-Z0-9_]+)'\s*\)",
            "($1::jsonb ->> '$2')",
            RegexOptions.IgnoreCase);

        // Rule 9: LIKE -> ILIKE
        sql = ReplaceKeywordOutsideQuotes(sql, "LIKE", "ILIKE");

        // Rule 2 & 3: INSERT OR IGNORE / INSERT OR REPLACE
        sql = TranslateInsertConflict(sql, out var insertTable);
        if (!string.IsNullOrEmpty(insertTable))
        {
            targetTable = insertTable;
            affectedTables.Add(insertTable);
        }

        // Rule 4: RETURNING "<pk>" for single-ID tables on INSERT
        string? returningPk = null;
        if (appendReturningForInsert &&
            !string.IsNullOrEmpty(targetTable) &&
            Regex.IsMatch(sql, @"^\s*INSERT\b", RegexOptions.IgnoreCase) &&
            !Regex.IsMatch(sql, @"\bRETURNING\b", RegexOptions.IgnoreCase) &&
            PostgresSchemaInitializer.SingleIdPrimaryKeys.TryGetValue(targetTable, out var pkCol))
        {
            sql = sql.TrimEnd().TrimEnd(';');
            sql = $"{sql} RETURNING \"{pkCol}\"";
            returningPk = pkCol;
        }

        // Rule 5: Replace '?' outside single quotes with @p0, @p1, ...
        sql = ReplaceQuestionMarksOutsideQuotes(sql);

        return new TranslatedSqlCommand
        {
            Sql = sql,
            IsNoOpPragma = false,
            TargetTable = targetTable,
            ReturningPrimaryKeyColumn = returningPk,
            AffectedTables = affectedTables
        };
    }

    private static string TranslateInsertConflict(string sql, out string? tableName)
    {
        tableName = null;

        // الفحص الأول: INSERT OR IGNORE INTO <table> ...
        var ignoreMatch = Regex.Match(
            sql,
            @"^\s*INSERT\s+OR\s+IGNORE\s+INTO\s+[""`]?([a-zA-Z0-9_]+)[""`]?\s*(.*)$",
            RegexOptions.IgnoreCase | RegexOptions.Singleline);

        if (ignoreMatch.Success)
        {
            tableName = ignoreMatch.Groups[1].Value.ToLowerInvariant();
            var rest = ignoreMatch.Groups[2].Value.TrimEnd().TrimEnd(';');
            return $"INSERT INTO \"{tableName}\" {rest} ON CONFLICT DO NOTHING";
        }

        // الفحص الثاني: INSERT OR REPLACE INTO <table> (<cols>) VALUES (...)
        var replaceMatch = Regex.Match(
            sql,
            @"^\s*INSERT\s+OR\s+REPLACE\s+INTO\s+[""`]?([a-zA-Z0-9_]+)[""`]?\s*\(([^)]+)\)\s*VALUES\s*(.+)$",
            RegexOptions.IgnoreCase | RegexOptions.Singleline);

        if (replaceMatch.Success)
        {
            tableName = replaceMatch.Groups[1].Value.ToLowerInvariant();
            var rawCols = replaceMatch.Groups[2].Value;
            var valuesClause = replaceMatch.Groups[3].Value.TrimEnd().TrimEnd(';');

            var columns = rawCols
                .Split(',')
                .Select(c => c.Trim().Trim('"', '`', '[', ']').ToLowerInvariant())
                .Where(c => !string.IsNullOrEmpty(c))
                .ToList();

            var quotedCols = string.Join(", ", columns.Select(c => $"\"{c}\""));

            string[] conflictCols;
            if (PostgresSchemaInitializer.ConflictTargetColumns.TryGetValue(tableName, out var configuredTargets))
            {
                // إذا كان المفتاح الأساسي غير موجود ضمن الأعمدة المرسلة وكان للجدول عمود فريد (مثل area_name أو setting_key)
                if (!configuredTargets.All(t => columns.Contains(t, StringComparer.OrdinalIgnoreCase)) &&
                    PostgresSchemaInitializer.UniqueNameColumns.TryGetValue(tableName, out var uniqueCol) &&
                    columns.Contains(uniqueCol, StringComparer.OrdinalIgnoreCase))
                {
                    conflictCols = new[] { uniqueCol };
                }
                else
                {
                    conflictCols = configuredTargets;
                }
            }
            else
            {
                conflictCols = new[] { columns[0] };
            }

            var conflictTargetSql = string.Join(", ", conflictCols.Select(c => $"\"{c}\""));
            var updateCols = columns
                .Where(c => !conflictCols.Contains(c, StringComparer.OrdinalIgnoreCase))
                .ToList();

            if (updateCols.Count == 0)
            {
                return $"INSERT INTO \"{tableName}\" ({quotedCols}) VALUES {valuesClause} ON CONFLICT ({conflictTargetSql}) DO NOTHING";
            }

            var updateSetSql = string.Join(", ", updateCols.Select(c => $"\"{c}\" = EXCLUDED.\"{c}\""));
            return $"INSERT INTO \"{tableName}\" ({quotedCols}) VALUES {valuesClause} ON CONFLICT ({conflictTargetSql}) DO UPDATE SET {updateSetSql}";
        }

        // الفحص الثالث: INSERT INTO العادي لاستخراج اسم الجدول
        var normalInsert = Regex.Match(
            sql,
            @"^\s*INSERT\s+INTO\s+[""`]?([a-zA-Z0-9_]+)[""`]?",
            RegexOptions.IgnoreCase);
        if (normalInsert.Success)
        {
            tableName = normalInsert.Groups[1].Value.ToLowerInvariant();
        }

        return sql;
    }

    public static string ReplaceQuestionMarksOutsideQuotes(string sql)
    {
        var sb = new StringBuilder(sql.Length + 32);
        bool inSingleQuote = false;
        bool inDoubleQuote = false;
        int paramIndex = 0;

        for (int i = 0; i < sql.Length; i++)
        {
            char c = sql[i];
            if (c == '\'' && !inDoubleQuote)
            {
                sb.Append(c);
                if (inSingleQuote && i + 1 < sql.Length && sql[i + 1] == '\'')
                {
                    sb.Append(sql[++i]);
                    continue;
                }
                inSingleQuote = !inSingleQuote;
            }
            else if (c == '"' && !inSingleQuote)
            {
                inDoubleQuote = !inDoubleQuote;
                sb.Append(c);
            }
            else if (c == '?' && !inSingleQuote && !inDoubleQuote)
            {
                sb.Append("@p").Append(paramIndex++);
            }
            else
            {
                sb.Append(c);
            }
        }

        return sb.ToString();
    }

    private static string ReplaceKeywordOutsideQuotes(string sql, string keyword, string replacement)
    {
        var sb = new StringBuilder(sql.Length + 16);
        int i = 0;
        bool inSingleQuote = false;

        while (i < sql.Length)
        {
            char c = sql[i];
            if (c == '\'')
            {
                sb.Append(c);
                if (inSingleQuote && i + 1 < sql.Length && sql[i + 1] == '\'')
                {
                    sb.Append(sql[++i]);
                    i++;
                    continue;
                }
                inSingleQuote = !inSingleQuote;
                i++;
                continue;
            }

            if (!inSingleQuote &&
                i + keyword.Length <= sql.Length &&
                string.Compare(sql, i, keyword, 0, keyword.Length, StringComparison.OrdinalIgnoreCase) == 0)
            {
                bool leftBoundary = i == 0 || !char.IsLetterOrDigit(sql[i - 1]) && sql[i - 1] != '_';
                bool rightBoundary = (i + keyword.Length == sql.Length) ||
                                     (!char.IsLetterOrDigit(sql[i + keyword.Length]) && sql[i + keyword.Length] != '_');
                if (leftBoundary && rightBoundary)
                {
                    sb.Append(replacement);
                    i += keyword.Length;
                    continue;
                }
            }

            sb.Append(c);
            i++;
        }

        return sb.ToString();
    }

    public static HashSet<string> ExtractAffectedTables(string sql)
    {
        var result = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        var patterns = new[]
        {
            @"\bINSERT\s+(?:OR\s+\w+\s+)?INTO\s+[""`]?([a-zA-Z0-9_]+)[""`]?",
            @"\bUPDATE\s+[""`]?([a-zA-Z0-9_]+)[""`]?",
            @"\bDELETE\s+FROM\s+[""`]?([a-zA-Z0-9_]+)[""`]?",
            @"\bTRUNCATE\s+(?:TABLE\s+)?[""`]?([a-zA-Z0-9_]+)[""`]?"
        };

        foreach (var pattern in patterns)
        {
            foreach (Match m in Regex.Matches(sql, pattern, RegexOptions.IgnoreCase))
            {
                var table = m.Groups[1].Value.ToLowerInvariant();
                result.Add(table);
            }
        }

        return result;
    }
}
```

### 1.6 مركز التزامن اللحظي `AbonaFlemoon.SyncServer/Hubs/SyncHub.cs`
```csharp
using Microsoft.AspNetCore.SignalR;

namespace AbonaFlemoon.SyncServer.Hubs;

public class SyncHub : Hub
{
    private readonly ILogger<SyncHub> _logger;

    public SyncHub(ILogger<SyncHub> logger)
    {
        _logger = logger;
    }

    public override Task OnConnectedAsync()
    {
        _logger.LogInformation("Client connected to SyncHub: {ConnectionId}", Context.ConnectionId);
        return base.OnConnectedAsync();
    }

    public override Task OnDisconnectedAsync(Exception? exception)
    {
        _logger.LogInformation("Client disconnected from SyncHub: {ConnectionId}", Context.ConnectionId);
        return base.OnDisconnectedAsync(exception);
    }

    public Task Ping() => Clients.Caller.SendAsync("Pong", DateTime.UtcNow);
}
```

### 1.7 خدمة التخزين والمعاملات والتصدير/الاستيراد (`AbonaFlemoon.SyncServer/Services/StorageService.cs`)
هذه الخدمة تتولى:
- إدارة المعاملات النشطة (`ActiveTransactionContext`) في `ConcurrentDictionary<string, ActiveTransactionContext>` مع `SemaphoreSlim(1, 1)` لكل معاملة ومؤقت تنظيف تلقائي للمعاملات الخاملة بعد 90 ثانية.
- ربط المعاملات (`BindParameters`) بدقة حسب `SqlParamDto.Type`.
- قراءة الصفوف وتطبيع أسماء الأعمدة عبر `CanonicalColumnNames` وتحويل القيم (`DateTime` -> ISO-8601، `decimal` -> `double`).
- بث إشعار `DatabaseChanged` عبر `IHubContext<SyncHub>` **فقط بعد نجاح الكتابة أو بعد `CommitTransactionAsync`**.
- تصدير كامل بيانات PostgreSQL إلى ملف SQLite صالح 100% (`ExportToSqliteBytesAsync`) واستيراد ملف SQLite إلى PostgreSQL (`ImportFromSqliteBytesAsync`) مع مزامنة جميع المتسلسلات (`SyncAllSequencesAsync`).

اكتب الكود الكامل التالي في `AbonaFlemoon.SyncServer/Services/StorageService.cs`:
```csharp
using System.Collections.Concurrent;
using System.Data;
using System.Text.Json;
using AbonaFlemoon.SyncServer.Hubs;
using AbonaFlemoon.SyncServer.Models;
using Microsoft.AspNetCore.SignalR;
using Microsoft.Data.Sqlite;
using Npgsql;

namespace AbonaFlemoon.SyncServer.Services;

public sealed class ActiveTransactionContext : IAsyncDisposable
{
    public string TxId { get; init; } = string.Empty;
    public NpgsqlConnection Connection { get; init; } = default!;
    public NpgsqlTransaction Transaction { get; init; } = default!;
    public SemaphoreSlim Gate { get; } = new(1, 1);
    public HashSet<string> TouchedTables { get; } = new(StringComparer.OrdinalIgnoreCase);
    public DateTime LastActivityUtc { get; set; } = DateTime.UtcNow;

    public async ValueTask DisposeAsync()
    {
        Gate.Dispose();
        await Transaction.DisposeAsync();
        await Connection.DisposeAsync();
    }
}

public class StorageService : IDisposable
{
    private readonly string _connectionString;
    private readonly IHubContext<SyncHub> _hubContext;
    private readonly ILogger<StorageService> _logger;
    private readonly ConcurrentDictionary<string, ActiveTransactionContext> _transactions = new();
    private readonly Timer _cleanupTimer;

    public StorageService(
        IConfiguration configuration,
        IHubContext<SyncHub> hubContext,
        ILogger<StorageService> logger)
    {
        _connectionString = configuration.GetConnectionString("Postgres")
            ?? throw new InvalidOperationException("Missing ConnectionStrings:Postgres");
        _hubContext = hubContext;
        _logger = logger;
        _cleanupTimer = new Timer(CleanupStaleTransactions, null, TimeSpan.FromSeconds(30), TimeSpan.FromSeconds(30));
    }

    public async Task<bool> CheckDatabaseHealthAsync()
    {
        try
        {
            await using var conn = new NpgsqlConnection(_connectionString);
            await conn.OpenAsync();
            await using var cmd = new NpgsqlCommand("SELECT 1;", conn);
            await cmd.ExecuteScalarAsync();
            return true;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "PostgreSQL health check failed.");
            return false;
        }
    }

    public async Task<TxBeginResponse> BeginTransactionAsync()
    {
        var conn = new NpgsqlConnection(_connectionString);
        await conn.OpenAsync();
        var tx = await conn.BeginTransactionAsync(IsolationLevel.ReadCommitted);
        var txId = Guid.NewGuid().ToString("N");

        var ctx = new ActiveTransactionContext
        {
            TxId = txId,
            Connection = conn,
            Transaction = tx,
            LastActivityUtc = DateTime.UtcNow
        };

        _transactions[txId] = ctx;
        return new TxBeginResponse { TxId = txId };
    }

    public async Task CommitTransactionAsync(string txId)
    {
        if (!_transactions.TryRemove(txId, out var ctx))
        {
            throw new KeyNotFoundException($"Transaction '{txId}' not found or already closed.");
        }

        await ctx.Gate.WaitAsync();
        try
        {
            await ctx.Transaction.CommitAsync();
        }
        finally
        {
            ctx.Gate.Release();
            await ctx.DisposeAsync();
        }

        if (ctx.TouchedTables.Count > 0)
        {
            await BroadcastChangesAsync(ctx.TouchedTables, "tx_commit");
        }
    }

    public async Task RollbackTransactionAsync(string txId)
    {
        if (!_transactions.TryRemove(txId, out var ctx))
        {
            return;
        }

        await ctx.Gate.WaitAsync();
        try
        {
            await ctx.Transaction.RollbackAsync();
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Rollback error for transaction {TxId}", txId);
        }
        finally
        {
            ctx.Gate.Release();
            await ctx.DisposeAsync();
        }
    }

    public async Task<QueryResultResponse> QueryAsync(SqlStatementRequest request)
    {
        var translated = SqlDialectTranslator.Translate(request.Sql, appendReturningForInsert: false);
        if (translated.IsNoOpPragma || string.IsNullOrWhiteSpace(translated.Sql))
        {
            return new QueryResultResponse();
        }

        if (!string.IsNullOrWhiteSpace(request.TxId) && _transactions.TryGetValue(request.TxId, out var txCtx))
        {
            await txCtx.Gate.WaitAsync();
            try
            {
                txCtx.LastActivityUtc = DateTime.UtcNow;
                foreach (var t in translated.AffectedTables) txCtx.TouchedTables.Add(t);
                var rows = await ExecuteReaderInternalAsync(txCtx.Connection, txCtx.Transaction, translated.Sql, request.Params);
                return new QueryResultResponse { Rows = rows };
            }
            finally
            {
                txCtx.Gate.Release();
            }
        }
        else
        {
            await using var conn = new NpgsqlConnection(_connectionString);
            await conn.OpenAsync();
            var rows = await ExecuteReaderInternalAsync(conn, null, translated.Sql, request.Params);
            if (translated.AffectedTables.Count > 0)
            {
                await BroadcastChangesAsync(translated.AffectedTables, "query_write");
            }
            return new QueryResultResponse { Rows = rows };
        }
    }

    public async Task<InsertResultResponse> InsertAsync(SqlStatementRequest request)
    {
        var translated = SqlDialectTranslator.Translate(request.Sql, appendReturningForInsert: true);
        if (translated.IsNoOpPragma || string.IsNullOrWhiteSpace(translated.Sql))
        {
            return new InsertResultResponse { LastInsertRowId = 0 };
        }

        if (!string.IsNullOrWhiteSpace(request.TxId) && _transactions.TryGetValue(request.TxId, out var txCtx))
        {
            await txCtx.Gate.WaitAsync();
            try
            {
                txCtx.LastActivityUtc = DateTime.UtcNow;
                foreach (var t in translated.AffectedTables) txCtx.TouchedTables.Add(t);
                var id = await ExecuteInsertInternalAsync(txCtx.Connection, txCtx.Transaction, translated, request.Params);
                return new InsertResultResponse { LastInsertRowId = id };
            }
            finally
            {
                txCtx.Gate.Release();
            }
        }
        else
        {
            await using var conn = new NpgsqlConnection(_connectionString);
            await conn.OpenAsync();
            var id = await ExecuteInsertInternalAsync(conn, null, translated, request.Params);
            if (translated.AffectedTables.Count > 0)
            {
                await BroadcastChangesAsync(translated.AffectedTables, "insert");
            }
            return new InsertResultResponse { LastInsertRowId = id };
        }
    }

    public async Task<ExecuteResultResponse> ExecuteAsync(SqlStatementRequest request)
    {
        var translated = SqlDialectTranslator.Translate(request.Sql, appendReturningForInsert: false);
        if (translated.IsNoOpPragma || string.IsNullOrWhiteSpace(translated.Sql))
        {
            return new ExecuteResultResponse { AffectedRows = 0 };
        }

        if (!string.IsNullOrWhiteSpace(request.TxId) && _transactions.TryGetValue(request.TxId, out var txCtx))
        {
            await txCtx.Gate.WaitAsync();
            try
            {
                txCtx.LastActivityUtc = DateTime.UtcNow;
                foreach (var t in translated.AffectedTables) txCtx.TouchedTables.Add(t);
                var affected = await ExecuteNonQueryInternalAsync(txCtx.Connection, txCtx.Transaction, translated.Sql, request.Params);
                return new ExecuteResultResponse { AffectedRows = affected };
            }
            finally
            {
                txCtx.Gate.Release();
            }
        }
        else
        {
            await using var conn = new NpgsqlConnection(_connectionString);
            await conn.OpenAsync();
            var affected = await ExecuteNonQueryInternalAsync(conn, null, translated.Sql, request.Params);
            if (translated.AffectedTables.Count > 0)
            {
                await BroadcastChangesAsync(translated.AffectedTables, "execute");
            }
            return new ExecuteResultResponse { AffectedRows = affected };
        }
    }

    public async Task<ExecuteResultResponse> ExecuteBatchAsync(SqlBatchRequest request)
    {
        if (request.Statements.Count == 0)
        {
            return new ExecuteResultResponse { AffectedRows = 0 };
        }

        int totalAffected = 0;

        if (!string.IsNullOrWhiteSpace(request.TxId) && _transactions.TryGetValue(request.TxId, out var txCtx))
        {
            await txCtx.Gate.WaitAsync();
            try
            {
                txCtx.LastActivityUtc = DateTime.UtcNow;
                foreach (var stmt in request.Statements)
                {
                    var translated = SqlDialectTranslator.Translate(stmt.Sql, appendReturningForInsert: false);
                    if (translated.IsNoOpPragma || string.IsNullOrWhiteSpace(translated.Sql)) continue;
                    foreach (var t in translated.AffectedTables) txCtx.TouchedTables.Add(t);
                    totalAffected += await ExecuteNonQueryInternalAsync(txCtx.Connection, txCtx.Transaction, translated.Sql, stmt.Params);
                }
                return new ExecuteResultResponse { AffectedRows = totalAffected };
            }
            finally
            {
                txCtx.Gate.Release();
            }
        }
        else
        {
            var touchedTables = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            await using var conn = new NpgsqlConnection(_connectionString);
            await conn.OpenAsync();
            await using var tx = await conn.BeginTransactionAsync();
            try
            {
                foreach (var stmt in request.Statements)
                {
                    var translated = SqlDialectTranslator.Translate(stmt.Sql, appendReturningForInsert: false);
                    if (translated.IsNoOpPragma || string.IsNullOrWhiteSpace(translated.Sql)) continue;
                    foreach (var t in translated.AffectedTables) touchedTables.Add(t);
                    totalAffected += await ExecuteNonQueryInternalAsync(conn, tx, translated.Sql, stmt.Params);
                }
                await tx.CommitAsync();
            }
            catch
            {
                await tx.RollbackAsync();
                throw;
            }

            if (touchedTables.Count > 0)
            {
                await BroadcastChangesAsync(touchedTables, "batch");
            }

            return new ExecuteResultResponse { AffectedRows = totalAffected };
        }
    }

    private static async Task<List<Dictionary<string, object?>>> ExecuteReaderInternalAsync(
        NpgsqlConnection conn,
        NpgsqlTransaction? tx,
        string sql,
        List<SqlParamDto> parameters)
    {
        await using var cmd = new NpgsqlCommand(sql, conn, tx);
        BindParameters(cmd, parameters);

        var rows = new List<Dictionary<string, object?>>();
        await using var reader = await cmd.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            var row = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);
            for (int i = 0; i < reader.FieldCount; i++)
            {
                var rawName = reader.GetName(i);
                var colName = PostgresSchemaInitializer.CanonicalColumnNames.TryGetValue(rawName, out var canonical)
                    ? canonical
                    : rawName.ToLowerInvariant();

                if (reader.IsDBNull(i))
                {
                    row[colName] = null;
                    continue;
                }

                var val = reader.GetValue(i);
                row[colName] = val switch
                {
                    DateTime dt => dt.ToString("O"),
                    DateTimeOffset dto => dto.ToString("O"),
                    decimal dec => (double)dec,
                    _ => val
                };
            }
            rows.Add(row);
        }

        return rows;
    }

    private static async Task<long> ExecuteInsertInternalAsync(
        NpgsqlConnection conn,
        NpgsqlTransaction? tx,
        TranslatedSqlCommand translated,
        List<SqlParamDto> parameters)
    {
        await using var cmd = new NpgsqlCommand(translated.Sql, conn, tx);
        BindParameters(cmd, parameters);

        if (translated.ReturningPrimaryKeyColumn != null)
        {
            var scalar = await cmd.ExecuteScalarAsync();
            if (scalar != null && scalar != DBNull.Value)
            {
                return Convert.ToInt64(scalar);
            }
            return 0L;
        }

        return await cmd.ExecuteNonQueryAsync();
    }

    private static async Task<int> ExecuteNonQueryInternalAsync(
        NpgsqlConnection conn,
        NpgsqlTransaction? tx,
        string sql,
        List<SqlParamDto> parameters)
    {
        await using var cmd = new NpgsqlCommand(sql, conn, tx);
        BindParameters(cmd, parameters);
        return await cmd.ExecuteNonQueryAsync();
    }

    private static void BindParameters(NpgsqlCommand cmd, List<SqlParamDto>? parameters)
    {
        if (parameters == null || parameters.Count == 0) return;

        for (int i = 0; i < parameters.Count; i++)
        {
            var p = parameters[i];
            var paramName = $"@p{i}";
            var type = (p.Type ?? "null").ToLowerInvariant();

            if (type == "null" || p.Value == null || p.Value.Value.ValueKind == JsonValueKind.Null)
            {
                cmd.Parameters.AddWithValue(paramName, DBNull.Value);
                continue;
            }

            var elem = p.Value.Value;
            switch (type)
            {
                case "int":
                case "integer":
                    cmd.Parameters.AddWithValue(paramName, elem.GetInt64());
                    break;
                case "double":
                case "float":
                case "real":
                case "num":
                    cmd.Parameters.AddWithValue(paramName, elem.GetDouble());
                    break;
                case "bool":
                case "boolean":
                    cmd.Parameters.AddWithValue(paramName, elem.GetBoolean());
                    break;
                case "bytes":
                case "blob":
                    var base64 = elem.GetString() ?? string.Empty;
                    cmd.Parameters.AddWithValue(paramName, Convert.FromBase64String(base64));
                    break;
                default:
                    cmd.Parameters.AddWithValue(paramName, elem.ToString());
                    break;
            }
        }
    }

    public async Task<byte[]> ExportToSqliteBytesAsync()
    {
        var tempSqlitePath = Path.Combine(Path.GetTempPath(), $"abona_flemoon_export_{Guid.NewGuid():N}.db");
        try
        {
            await using (var sqliteConn = new SqliteConnection($"Data Source={tempSqlitePath};Mode=ReadWriteCreate"))
            {
                await sqliteConn.OpenAsync();
                await CreateSqliteSchemaForExportAsync(sqliteConn);

                await using var pgConn = new NpgsqlConnection(_connectionString);
                await pgConn.OpenAsync();

                await using var sqliteTx = await sqliteConn.BeginTransactionAsync();
                foreach (var table in PostgresSchemaInitializer.OrderedTables)
                {
                    await using var pgCmd = new NpgsqlCommand($"SELECT * FROM \"{table}\";", pgConn);
                    await using var reader = await pgCmd.ExecuteReaderAsync();

                    if (!reader.HasRows) continue;

                    var cols = new List<string>();
                    for (int i = 0; i < reader.FieldCount; i++)
                    {
                        cols.Add(reader.GetName(i));
                    }

                    var colNamesSql = string.Join(", ", cols.Select(c => $"\"{c}\""));
                    var paramNamesSql = string.Join(", ", cols.Select((_, i) => $"@p{i}"));
                    var insertSql = $"INSERT INTO \"{table}\" ({colNamesSql}) VALUES ({paramNamesSql});";

                    while (await reader.ReadAsync())
                    {
                        await using var insertCmd = sqliteConn.CreateCommand();
                        insertCmd.Transaction = (SqliteTransaction)sqliteTx;
                        insertCmd.CommandText = insertSql;

                        for (int i = 0; i < cols.Count; i++)
                        {
                            var val = reader.IsDBNull(i) ? DBNull.Value : reader.GetValue(i);
                            insertCmd.Parameters.AddWithValue($"@p{i}", val);
                        }
                        await insertCmd.ExecuteNonQueryAsync();
                    }
                }
                await sqliteTx.CommitAsync();
            }

            SqliteConnection.ClearAllPools();
            return await File.ReadAllBytesAsync(tempSqlitePath);
        }
        finally
        {
            SqliteConnection.ClearAllPools();
            if (File.Exists(tempSqlitePath))
            {
                try { File.Delete(tempSqlitePath); } catch { }
            }
        }
    }

    public async Task ImportFromSqliteBytesAsync(byte[] sqliteBytes)
    {
        var tempSqlitePath = Path.Combine(Path.GetTempPath(), $"abona_flemoon_import_{Guid.NewGuid():N}.db");
        try
        {
            await File.WriteAllBytesAsync(tempSqlitePath, sqliteBytes);
            await using var pgConn = new NpgsqlConnection(_connectionString);
            await pgConn.OpenAsync();
            await PostgresSchemaInitializer.ImportFromSqliteFileInternalAsync(pgConn, tempSqlitePath, _logger);
            await BroadcastChangesAsync(PostgresSchemaInitializer.OrderedTables, "sqlite_import");
        }
        finally
        {
            SqliteConnection.ClearAllPools();
            if (File.Exists(tempSqlitePath))
            {
                try { File.Delete(tempSqlitePath); } catch { }
            }
        }
    }

    private static async Task CreateSqliteSchemaForExportAsync(SqliteConnection sqliteConn)
    {
        const string sqliteDdl = @"
CREATE TABLE IF NOT EXISTS areas (area_id INTEGER PRIMARY KEY AUTOINCREMENT, area_name TEXT NOT NULL UNIQUE);
CREATE TABLE IF NOT EXISTS streets (street_id INTEGER PRIMARY KEY AUTOINCREMENT, street_name TEXT NOT NULL, area_id INTEGER NOT NULL);
CREATE TABLE IF NOT EXISTS karaba (karaba_id INTEGER PRIMARY KEY AUTOINCREMENT, karaba_name TEXT NOT NULL UNIQUE);
CREATE TABLE IF NOT EXISTS mostwa (mostwa_id INTEGER PRIMARY KEY AUTOINCREMENT, mostwa_name TEXT NOT NULL UNIQUE);
CREATE TABLE IF NOT EXISTS hala_egtimaia (hala_egtimaia_id INTEGER PRIMARY KEY AUTOINCREMENT, hala_name TEXT NOT NULL UNIQUE);
CREATE TABLE IF NOT EXISTS hala_sehia (hala_sehia_id INTEGER PRIMARY KEY AUTOINCREMENT, hala_name TEXT NOT NULL UNIQUE);
CREATE TABLE IF NOT EXISTS e_s (e_s_id INTEGER PRIMARY KEY AUTOINCREMENT, e_s_name TEXT NOT NULL UNIQUE);
CREATE TABLE IF NOT EXISTS stage (stage_id INTEGER PRIMARY KEY AUTOINCREMENT, stage_name TEXT NOT NULL UNIQUE);
CREATE TABLE IF NOT EXISTS fathers (father_id INTEGER PRIMARY KEY AUTOINCREMENT, father_name TEXT NOT NULL, father_mobile TEXT, birth_date TEXT);
CREATE TABLE IF NOT EXISTS khdma (khdma_id INTEGER PRIMARY KEY AUTOINCREMENT, khdma_name TEXT NOT NULL UNIQUE);
CREATE TABLE IF NOT EXISTS users (pass_id INTEGER PRIMARY KEY AUTOINCREMENT, user_name TEXT NOT NULL UNIQUE, pass_word TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS icon (icon_id INTEGER PRIMARY KEY AUTOINCREMENT, icon_name TEXT NOT NULL UNIQUE);
CREATE TABLE IF NOT EXISTS inter_icon (inter_id INTEGER PRIMARY KEY AUTOINCREMENT, pass_id INTEGER NOT NULL, icon_id INTEGER, icon_name TEXT, check_1 INTEGER DEFAULT 1);
CREATE TABLE IF NOT EXISTS settings (setting_key TEXT PRIMARY KEY, setting_value TEXT);
CREATE TABLE IF NOT EXISTS osra (osra_id INTEGER PRIMARY KEY AUTOINCREMENT, osra_name TEXT NOT NULL, karaba_id INTEGER, e_s_id INTEGER, area_id INTEGER, street_id INTEGER, dalil_name TEXT, emara TEXT, door TEXT, shaka TEXT, r_o TEXT, phone TEXT, number INTEGER DEFAULT 0, hala_egtimaia_id INTEGER, rakm_komy TEXT, code INTEGER, hala_sehia_id INTEGER, mostwa_id INTEGER);
CREATE TABLE IF NOT EXISTS person (person_id INTEGER PRIMARY KEY AUTOINCREMENT, person_name TEXT NOT NULL, osra_id INTEGER NOT NULL, karaba_id INTEGER, birth_date TEXT, mostwa_id INTEGER, moahil TEXT, date_moiahil TEXT, hala_egtimaia_id INTEGER, hala_sehia_id INTEGER, wazefa TEXT, place_work TEXT, mobile TEXT, facebook TEXT, father TEXT, stage_id INTEGER, father_id INTEGER, month TEXT, age TEXT, rakm_komy TEXT);
CREATE TABLE IF NOT EXISTS eatraf (eatraf_id INTEGER PRIMARY KEY AUTOINCREMENT, person_id INTEGER NOT NULL, date TEXT NOT NULL, notes TEXT);
CREATE TABLE IF NOT EXISTS visits (visit_id INTEGER PRIMARY KEY AUTOINCREMENT, osra_id INTEGER NOT NULL, date TEXT NOT NULL, notes TEXT);
CREATE TABLE IF NOT EXISTS monasba (monasba_id INTEGER PRIMARY KEY AUTOINCREMENT, osra_id INTEGER NOT NULL, monasba_name TEXT NOT NULL, monasba_date TEXT, month TEXT);
CREATE TABLE IF NOT EXISTS count_aid (count_id INTEGER PRIMARY KEY AUTOINCREMENT, osra_id INTEGER NOT NULL, khdma_id INTEGER, count_value REAL DEFAULT 0, aynee TEXT, notes TEXT);
CREATE TABLE IF NOT EXISTS count_2 (count_2_id INTEGER PRIMARY KEY AUTOINCREMENT, osra_id INTEGER NOT NULL, type TEXT, count_add REAL DEFAULT 0, notes TEXT, date_1 TEXT);
CREATE TABLE IF NOT EXISTS masrofat (masrofat_id INTEGER PRIMARY KEY AUTOINCREMENT, osra_id INTEGER NOT NULL, masrof TEXT, count_value REAL DEFAULT 0, aynee TEXT, notes TEXT);
";
        await using var cmd = sqliteConn.CreateCommand();
        cmd.CommandText = sqliteDdl;
        await cmd.ExecuteNonQueryAsync();
    }

    public async Task BroadcastChangesAsync(IEnumerable<string> tables, string operation)
    {
        var list = tables
            .Where(t => !string.IsNullOrWhiteSpace(t))
            .Select(t => t.ToLowerInvariant())
            .Distinct()
            .ToList();

        if (list.Count == 0) return;

        var payload = new DatabaseChangeNotification
        {
            Tables = list,
            Operation = operation,
            TimestampUtc = DateTime.UtcNow
        };

        await _hubContext.Clients.All.SendAsync("DatabaseChanged", payload);
    }

    private void CleanupStaleTransactions(object? state)
    {
        var cutoff = DateTime.UtcNow.AddSeconds(-90);
        foreach (var kvp in _transactions)
        {
            if (kvp.Value.LastActivityUtc < cutoff)
            {
                if (_transactions.TryRemove(kvp.Key, out var stale))
                {
                    _logger.LogWarning("Rolling back stale transaction {TxId}", kvp.Key);
                    _ = Task.Run(async () =>
                    {
                        try { await stale.Transaction.RollbackAsync(); } catch { }
                        try { await stale.DisposeAsync(); } catch { }
                    });
                }
            }
        }
    }

    public void Dispose()
    {
        _cleanupTimer.Dispose();
    }
}
```

### 1.8 الـ Controllers (`AuthController.cs` و`StorageController.cs`) و`Program.cs`

#### أ) `AbonaFlemoon.SyncServer/Controllers/AuthController.cs`
```csharp
using AbonaFlemoon.SyncServer.Services;
using Microsoft.AspNetCore.Mvc;

namespace AbonaFlemoon.SyncServer.Controllers;

[ApiController]
[Route("api/auth")]
public class AuthController : ControllerBase
{
    private readonly StorageService _storageService;

    public AuthController(StorageService storageService)
    {
        _storageService = storageService;
    }

    [HttpGet("ping")]
    public async Task<IActionResult> Ping()
    {
        var dbHealthy = await _storageService.CheckDatabaseHealthAsync();
        if (!dbHealthy)
        {
            return StatusCode(503, new
            {
                status = "unhealthy",
                engine = "PostgreSQL",
                serverTime = DateTime.UtcNow
            });
        }

        return Ok(new
        {
            status = "ok",
            engine = "PostgreSQL",
            app = "AbonaFlemoon.SyncServer",
            serverTime = DateTime.UtcNow
        });
    }
}
```

#### ب) `AbonaFlemoon.SyncServer/Controllers/StorageController.cs`
```csharp
using AbonaFlemoon.SyncServer.Models;
using AbonaFlemoon.SyncServer.Services;
using Microsoft.AspNetCore.Mvc;

namespace AbonaFlemoon.SyncServer.Controllers;

[ApiController]
[Route("api/storage")]
public class StorageController : ControllerBase
{
    private readonly StorageService _storageService;
    private readonly ILogger<StorageController> _logger;

    public StorageController(StorageService storageService, ILogger<StorageController> logger)
    {
        _storageService = storageService;
        _logger = logger;
    }

    [HttpPost("query")]
    public async Task<IActionResult> Query([FromBody] SqlStatementRequest request)
    {
        try
        {
            var result = await _storageService.QueryAsync(request);
            return Ok(result);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Query failed for SQL: {Sql}", request.Sql);
            return BadRequest(new { error = ex.Message });
        }
    }

    [HttpPost("insert")]
    public async Task<IActionResult> Insert([FromBody] SqlStatementRequest request)
    {
        try
        {
            var result = await _storageService.InsertAsync(request);
            return Ok(result);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Insert failed for SQL: {Sql}", request.Sql);
            return BadRequest(new { error = ex.Message });
        }
    }

    [HttpPost("execute")]
    public async Task<IActionResult> Execute([FromBody] SqlStatementRequest request)
    {
        try
        {
            var result = await _storageService.ExecuteAsync(request);
            return Ok(result);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Execute failed for SQL: {Sql}", request.Sql);
            return BadRequest(new { error = ex.Message });
        }
    }

    [HttpPost("batch")]
    public async Task<IActionResult> Batch([FromBody] SqlBatchRequest request)
    {
        try
        {
            var result = await _storageService.ExecuteBatchAsync(request);
            return Ok(result);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Batch execution failed.");
            return BadRequest(new { error = ex.Message });
        }
    }

    [HttpPost("tx/begin")]
    public async Task<IActionResult> BeginTransaction()
    {
        try
        {
            var result = await _storageService.BeginTransactionAsync();
            return Ok(result);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "BeginTransaction failed.");
            return BadRequest(new { error = ex.Message });
        }
    }

    [HttpPost("tx/commit")]
    public async Task<IActionResult> CommitTransaction([FromBody] TxActionRequest request)
    {
        try
        {
            await _storageService.CommitTransactionAsync(request.TxId);
            return Ok(new { status = "committed" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "CommitTransaction failed for {TxId}", request.TxId);
            return BadRequest(new { error = ex.Message });
        }
    }

    [HttpPost("tx/rollback")]
    public async Task<IActionResult> RollbackTransaction([FromBody] TxActionRequest request)
    {
        try
        {
            await _storageService.RollbackTransactionAsync(request.TxId);
            return Ok(new { status = "rolled_back" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "RollbackTransaction failed for {TxId}", request.TxId);
            return BadRequest(new { error = ex.Message });
        }
    }

    [HttpGet("sqlite/export")]
    public async Task<IActionResult> ExportSqlite()
    {
        try
        {
            var bytes = await _storageService.ExportToSqliteBytesAsync();
            return File(bytes, "application/octet-stream", $"eakhow_elrab_backup_{DateTime.Now:yyyyMMdd_HHmm}.db");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "SQLite export failed.");
            return BadRequest(new { error = ex.Message });
        }
    }

    [HttpPost("sqlite/import")]
    [RequestSizeLimit(200_000_000)]
    public async Task<IActionResult> ImportSqlite(IFormFile? file)
    {
        try
        {
            byte[] sqliteBytes;
            if (file != null && file.Length > 0)
            {
                using var ms = new MemoryStream();
                await file.CopyToAsync(ms);
                sqliteBytes = ms.ToArray();
            }
            else
            {
                using var ms = new MemoryStream();
                await Request.Body.CopyToAsync(ms);
                sqliteBytes = ms.ToArray();
            }

            if (sqliteBytes.Length < 100)
            {
                return BadRequest(new { error = "ملف قاعدة البيانات المرسل فارغ أو غير صالح." });
            }

            await _storageService.ImportFromSqliteBytesAsync(sqliteBytes);
            return Ok(new { status = "imported" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "SQLite import failed.");
            return BadRequest(new { error = ex.Message });
        }
    }
}
```

#### ج) `AbonaFlemoon.SyncServer/Program.cs`
```csharp
using System.IO.Compression;
using AbonaFlemoon.SyncServer.Hubs;
using AbonaFlemoon.SyncServer.Services;
using Microsoft.AspNetCore.ResponseCompression;

var builder = WebApplication.CreateBuilder(args);

builder.WebHost.UseUrls("http://0.0.0.0:5060");

builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

builder.Services.AddSignalR(options =>
{
    options.EnableDetailedErrors = true;
    options.KeepAliveInterval = TimeSpan.FromSeconds(15);
    options.ClientTimeoutInterval = TimeSpan.FromSeconds(45);
});

builder.Services.AddResponseCompression(options =>
{
    options.EnableForHttps = true;
    options.Providers.Add<BrotliCompressionProvider>();
    options.Providers.Add<GzipCompressionProvider>();
    options.MimeTypes = ResponseCompressionDefaults.MimeTypes.Concat(new[] { "application/json" });
});
builder.Services.Configure<BrotliCompressionProviderOptions>(opts => opts.Level = CompressionLevel.Fastest);
builder.Services.Configure<GzipCompressionProviderOptions>(opts => opts.Level = CompressionLevel.Fastest);

builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowAll", policy =>
    {
        policy.SetIsOriginAllowed(_ => true)
              .AllowAnyHeader()
              .AllowAnyMethod()
              .AllowCredentials();
    });
});

builder.Services.AddSingleton<StorageService>();

var app = builder.Build();

using (var scope = app.Services.CreateScope())
{
    var logger = scope.ServiceProvider.GetRequiredService<ILoggerFactory>().CreateLogger("Startup");
    var connStr = builder.Configuration.GetConnectionString("Postgres")!;
    var initialSqlitePath = builder.Configuration["SqliteSeed:InitialDbPath"];
    await PostgresSchemaInitializer.EnsureDatabaseAndSchemaAsync(connStr, initialSqlitePath, logger);
}

app.UseResponseCompression();
app.UseCors("AllowAll");
app.UseSwagger();
app.UseSwaggerUI();

app.MapControllers();
app.MapHub<SyncHub>("/hubs/sync");

app.Run();
```

---

## المرحلة الثانية (Phase 2): بناء مدير السيرفر والأنفاق `AbonaFlemoonServerManager` (WinForms .NET 8)

هذا المشروع يطابق تماماً `E:\POWER\Offline_First_Sync\sales_flutter_app\DrSalesServerManager` مع دعم تشغيل وإدارة PostgreSQL المحمول (منفذ `5435`) وسيرفر `.NET 8` (`AbonaFlemoon.SyncServer` على منفذ `5060`) مثل `SundaySchoolServerManager`، بالإضافة إلى `TunnelSupervisor` و`TunnelManagerForm` (Cloudflare Quick / Cloudflare Stable / Ngrok / LAN) وكتابة ملف `SERVER_INFO.txt`.

### 2.1 ملف المشروع `AbonaFlemoonServerManager/AbonaFlemoonServerManager.csproj`
```xml
<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <OutputType>WinExe</OutputType>
    <TargetFramework>net8.0-windows</TargetFramework>
    <Nullable>enable</Nullable>
    <UseWindowsForms>true</UseWindowsForms>
    <ImplicitUsings>enable</ImplicitUsings>
    <AssemblyName>AbonaFlemoonServerManager</AssemblyName>
    <RootNamespace>AbonaFlemoonServerManager</RootNamespace>
  </PropertyGroup>

</Project>
```

### 2.2 ملف نقطة الدخول `AbonaFlemoonServerManager/Program.cs`
انسخ منطق `Program.cs` من `DrSalesServerManager` مع استخدام اسم Mutex خاص بالمشروع:
- اسم الـ Mutex: `"AbonaFlemoon_ServerManager_5060_v1"`
- دعم معامل سطر الأوامر `--background` لبدء التشغيل المخفي في شريط المهام (System Tray).

### 2.3 ملف إدارة السيرفر وPostgreSQL المحمول `AbonaFlemoonServerManager/ServerSupervisor.cs`
يجب أن يدمج `ServerSupervisor.cs` بين تصميم `DrSalesServerManager/ServerSupervisor.cs` وتشغيل PostgreSQL المحمول من `SundaySchoolServerManager/ServerSupervisor.cs`:
- الثوابت:
  - `public int Port => 5060;`
  - `public int PostgresPort => 5435;`
  - `public string DatabaseName => "abona_flemoon";`
- تحديد المسارات (`ResolvePaths()`):
  - يبحث عن مجلد `pgsql\bin\postgres.exe` و`initdb.exe` بجانب المدير أو في المجلد الأب (`..`).
  - ينشئ مجلد البيانات الدائم `C:\Users\<User>\AppData\Local\AbonaFlemoon_ServerData\pgdata` (لتفادي مشاكل صلاحيات الكتابة داخل `Program Files`).
  - يبحث عن `AbonaFlemoon.SyncServer.exe` أو `AbonaFlemoon.SyncServer.dll` في `server\` أو `..\server\`.
- دورة حياة التشغيل (`StartAsync()`):
  1. التأكد من تهيئة عنقود PostgreSQL (`initdb.exe -D <pgdata> -U postgres -E UTF8 --locale=C --auth=trust`) إذا لم يكن ملف `PG_VERSION` موجوداً.
  2. فحص المنفذ `5435`؛ إذا لم يكن يعمل، شغّل `postgres.exe -D <pgdata> -p 5435 -h 127.0.0.1` وانتظر حتى يستجيب المنفذ `5435`.
  3. فحص المنفذ `5060` عبر `http://127.0.0.1:5060/api/auth/ping`؛ إذا لم يكن يعمل، شغّل `AbonaFlemoon.SyncServer` مع تمرير متغير البيئة:
     `ConnectionStrings__Postgres = "Host=127.0.0.1;Port=5435;Database=abona_flemoon;Username=postgres;Password=postgres;Pooling=true;MaxPoolSize=100"`
  4. انتظر حتى يرجع `http://127.0.0.1:5060/api/auth/ping` كود `200 OK`.
  5. اكتب ملف `SERVER_INFO.txt` (أرقام المنافذ وعناوين IP للشبكة المحلية LAN).
- المراقب التلقائي (`WatchdogLoopAsync`): يفحص كل 8 ثوانٍ صحة السيرفر ويعيد تشغيله تلقائياً إذا توقف بدون طلب إيقاف يدوي.
- دالة التثبيت في بدء تشغيل الويندوز (`SetAutoStartWithWindows(bool enable)`): تسجل `"AbonaFlemoonServerManager"` في `HKCU\Software\Microsoft\Windows\CurrentVersion\Run` مع `--background`.

### 2.4 ملف إدارة الأنفاق السحابية `AbonaFlemoonServerManager/TunnelSupervisor.cs` و`TunnelManagerForm.cs`
- انسخ `TunnelSupervisor.cs` و`TunnelManagerForm.cs` من `E:\POWER\Offline_First_Sync\sales_flutter_app\DrSalesServerManager` مع تعديل:
  - `namespace AbonaFlemoonServerManager`
  - مسار حفظ إعدادات النفق في `LocalApplicationData\AbonaFlemoon_ServerData\tunnel_config.json`
  - المنفذ الافتراضي للنفق هو `5060` (بدلاً من `3000`).
  - عنوان النافذة: `"إعدادات الربط السحابي والشبكة — برنامج العضوية الكنسية (إخوة الرب)"`.

### 2.5 الواجهة الرئيسية لمدير السيرفر `AbonaFlemoonServerManager/MainForm.cs`
- انسخ تصميم `MainForm.cs` من `DrSalesServerManager/MainForm.cs` مع تخصيص العناوين:
  - عنوان النافذة: `"مدير سيرفر العضوية الكنسية (إخوة الرب) - Abona Flemoon Server Manager"`
  - عرض حالة كل من PostgreSQL (`5435`) وسيرفر التزامن (`5060`) وعناوين الشبكة المحلية (`http://192.168.x.x:5060`) والرابط السحابي النشط (إن وُجد) مع أزرار:
    - تشغيل السيرفر / إيقاف السيرفر / إعادة التشغيل
    - نسخ رابط السيرفر للموبايل والأجهزة الفرعية
    - فتح إعدادات الربط السحابي (Cloudflare / Ngrok) (`TunnelManagerForm`)
    - فتح مجلد البيانات والنسخ الاحتياطية
    - التصغير إلى شريط المهام (System Tray) مع أيقونة وقائمة سياقية (`فتح لوحة التحكم`، `إعادة تشغيل السيرفر`، `إغلاق كامل`).

---

## المرحلة الثالثة (Phase 3): طبقة التزامن والجسر في Flutter (`lib/sync/*`)

### 3.1 تحديث `pubspec.yaml`
أضف الحزم الثلاث التالية تحت `dependencies:` في `e:\el odwia\project\pubspec.yaml`:
```yaml
  http: ^1.2.2
  shared_preferences: ^2.3.2
  web_socket_channel: ^3.0.1
```
ثم نفّذ `flutter pub get`.

### 3.2 إعدادات السيرفر `lib/sync/server_config.dart`
أنشئ الملف `lib/sync/server_config.dart` ليحفظ إعدادات الاتصال في الذاكرة وفي `SharedPreferences`:
```dart
import 'package:shared_preferences/shared_preferences.dart';

class ServerConfig {
  static const String _keyEnabled = 'sync_server_enabled';
  static const String _keyBaseUrl = 'sync_server_base_url';

  static bool isServerMode = false;
  static String baseUrl = 'http://127.0.0.1:5060';

  static String normalizeUrl(String raw) {
    var trimmed = raw.trim();
    if (trimmed.isEmpty) return 'http://127.0.0.1:5060';
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      trimmed = 'http://$trimmed';
    }
    while (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    isServerMode = prefs.getBool(_keyEnabled) ?? false;
    baseUrl = normalizeUrl(prefs.getString(_keyBaseUrl) ?? 'http://127.0.0.1:5060');
  }

  static Future<void> save({required bool enabled, required String url}) async {
    final normalized = normalizeUrl(url);
    isServerMode = enabled;
    baseUrl = normalized;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnabled, enabled);
    await prefs.setString(_keyBaseUrl, normalized);
  }
}
```

### 3.3 خدمة الاتصال والاكتشاف التلقائي `lib/sync/server_connection_service.dart`
أنشئ الملف `lib/sync/server_connection_service.dart` ويحتوي على:
1. `ServerConnectionCheckResult` (`isReachable`, `statusCode`, `engine`, `message`).
2. `ServerConnectionService`:
   - تفحص `${ServerConfig.normalizeUrl(url)}/api/auth/ping` بمهلة 4 ثوانٍ.
3. `ServerBootstrap.initialize()`:
   - يستدعي `await ServerConfig.load()`.
   - على نظام Windows فقط: إذا لم يكن المستخدم قد حفظ إعداداً مسبقاً، يفحص تلقائياً `http://127.0.0.1:5060/api/auth/ping`؛ وإذا استجاب السيرفر المحلي على نفس الجهاز يفعل `ServerConfig.save(enabled: true, url: 'http://127.0.0.1:5060')` تلقائياً (حتى يعمل وضع التثبيت الكامل Full Mode فور التثبيت بدون تدخل يدوي!).
4. `ServerConfigProvider extends ChangeNotifier`:
   - يوفر `isServerMode`، `baseUrl`، `isConnected`، `lastError`، ودالة `Future<bool> applySettings({required bool enabled, required String url})` التي تختبر الاتصال، تحفظ الإعدادات، وتستدعي `await DatabaseHelper().reopenDatabase()` لتبديل قاعدة البيانات فوراً بدون الحاجة لإعادة تشغيل البرنامج!

### 3.4 جسر قاعدة البيانات البعيدة لـ `sqflite` (`lib/sync/dotnet_postgres_database.dart`)
**هذا الملف هو قلب التحويل في Flutter!**  
بما أن جميع الـ Repositories في المشروع تستدعي `final db = await _dbHelper.database;` وتستخدم دوال `Database` الخاصة بـ `sqflite`:
- `query(table, {distinct, columns, where, whereArgs, groupBy, having, orderBy, limit, offset})`
- `rawQuery(sql, [arguments])`
- `insert(table, values, {nullColumnHack, conflictAlgorithm})`
- `rawInsert(sql, [arguments])`
- `update(table, values, {where, whereArgs, conflictAlgorithm})`
- `rawUpdate(sql, [arguments])`
- `delete(table, {where, whereArgs})`
- `rawDelete(sql, [arguments])`
- `execute(sql, [arguments])`
- `transaction<T>((txn) async => ...)`
- `batch()` -> `Batch` (`insert`, `update`, `delete`, `execute`, `rawInsert`, `rawUpdate`, `rawDelete`, `commit`)

يجب أن ينفذ `DotNetPostgresDatabase` الواجهة `Database` من `package:sqflite_common_ffi/sqflite_ffi.dart` بالكامل!

#### أهم القواعد الحاسمة داخل `DotNetPostgresDatabase`:
1. **`CaseInsensitiveRowMap` (`MapBase<String, dynamic>`):**
   - جميع الصفوف المرجعة من `query` و`rawQuery` يجب تغليفها بـ `CaseInsensitiveRowMap` حتى ينجح `row['osra_id']` أو `row['OSRA_ID']` أو `row['member_count']` دائماً.
   - إذا كانت القيمة رقماً صحيحاً لمفتاح مثل `member_count` أو `family_count` أو `person_count`، تأكد من إرجاعه كـ `int` عند قراءته في Dart.
2. **معالجة المفاتيح الأساسية الفارغة (`null` Primary Key) عند `insert(table, values, ...)`:**
   - في هذا المشروع، دوال `toMap()` في جميع الموديلات (`Family.toMap()`, `Person.toMap()`, `Area.toMap()`, `Street.toMap()`, `Father.toMap()`, `User.toMap()`, `Permission.toMap()`, `Confession.toMap()`, `Visit.toMap()`, `Occasion.toMap()`, `FixedAid.toMap()`, `VariableAid.toMap()`, `Expense.toMap()`) تُرجع المفتاح الأساسي بقيمة `null` عند الإضافة الجديدة (مثال: `'osra_id': null`).
   - في `DotNetPostgresDatabase.insert`: احذف أي عمود من `values` إذا كان هو المفتاح الأساسي للجدول (`_singleIdPrimaryKeys[table]`) وكانت قيمته `null`!
   - مثال: `final cleanedValues = Map<String, Object?>.from(values); final pk = _singleIdPrimaryKeys[table.toLowerCase()]; if (pk != null && cleanedValues[pk] == null) { cleanedValues.remove(pk); }`
3. **تحويل `ConflictAlgorithm` في `insert`:**
   - إذا كان `conflictAlgorithm == ConflictAlgorithm.ignore` -> يبني الجملة `INSERT OR IGNORE INTO "$table" (...) VALUES (...)`.
   - إذا كان `conflictAlgorithm == ConflictAlgorithm.replace` -> يبني الجملة `INSERT OR REPLACE INTO "$table" (...) VALUES (...)`.
   - غير ذلك -> يبني الجملة `INSERT INTO "$table" (...) VALUES (...)`.
4. **بناء جملة `SELECT` في `query(...)`:**
   - يبني `SELECT ${distinct == true ? 'DISTINCT ' : ''}${columns != null && columns.isNotEmpty ? columns.join(', ') : '*'} FROM "$table"`
   - يضيف `WHERE $where`، `GROUP BY $groupBy`، `HAVING $having`، `ORDER BY $orderBy`، `LIMIT $limit`، `OFFSET $offset`.
   - يمرر `whereArgs` إلى `/api/storage/query`.
5. **بناء جملة `UPDATE` في `update(...)`:**
   - يفصل أعمدة `values` إلى `"$col" = ?`، ويجمع قيم `values.values` مع `whereArgs` بالترتيب الصحيح، ويرسلها إلى `/api/storage/execute`.
6. **بناء جملة `DELETE` في `delete(...)`:**
   - يبني `DELETE FROM "$table"${where != null ? ' WHERE $where' : ''}` مع `whereArgs` ويرسلها إلى `/api/storage/execute`.
7. **دعم `transaction<T>((txn) async { ... })`:**
   - يستدعي `/api/storage/tx/begin` للحصول على `txId`.
   - ينشئ كائن `_DotNetPostgresTransaction(this, txId)` الذي ينفذ `Transaction` ويمرر `txId` في كل طلب (`query`, `insert`, `update`, `delete`, `rawDelete`, `execute`, `batch`).
   - عند النجاح يستدعي `/api/storage/tx/commit`، وعند حدوث أي استثناء يستدعي `/api/storage/tx/rollback` ثم يعيد رمي الاستثناء (`rethrow`).
8. **دعم `batch()`:**
   - يجمع العمليات في قائمة من `{ "sql": ..., "params": ... }` وعند استدعاء `commit()` يرسلها دفعة واحدة إلى `/api/storage/batch`!

اكتب الكود الكامل لـ `lib/sync/dotnet_postgres_database.dart`:
```dart
import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'server_config.dart';

class CaseInsensitiveRowMap extends MapBase<String, dynamic> {
  final Map<String, dynamic> _inner = {};
  final Map<String, String> _lowercaseKeyMap = {};

  CaseInsensitiveRowMap(Map<String, dynamic> source) {
    source.forEach((k, v) {
      _inner[k] = v;
      _lowercaseKeyMap[k.toLowerCase()] = k;
    });
  }

  @override
  dynamic operator [](Object? key) {
    if (key is! String) return null;
    if (_inner.containsKey(key)) return _inner[key];
    final actualKey = _lowercaseKeyMap[key.toLowerCase()];
    return actualKey != null ? _inner[actualKey] : null;
  }

  @override
  void operator []=(String key, dynamic value) {
    final existingKey = _lowercaseKeyMap[key.toLowerCase()];
    if (existingKey != null && existingKey != key) {
      _inner.remove(existingKey);
    }
    _inner[key] = value;
    _lowercaseKeyMap[key.toLowerCase()] = key;
  }

  @override
  void clear() {
    _inner.clear();
    _lowercaseKeyMap.clear();
  }

  @override
  Iterable<String> get keys => _inner.keys;

  @override
  dynamic remove(Object? key) {
    if (key is! String) return null;
    final actualKey = _lowercaseKeyMap.remove(key.toLowerCase());
    if (actualKey != null) {
      return _inner.remove(actualKey);
    }
    return null;
  }
}

abstract class _BasePostgresExecutor implements DatabaseExecutor {
  final http.Client _client;
  final String Function() _baseUrlProvider;
  final String? _txId;

  static const Map<String, String> _singleIdPrimaryKeys = {
    'areas': 'area_id',
    'streets': 'street_id',
    'karaba': 'karaba_id',
    'mostwa': 'mostwa_id',
    'hala_egtimaia': 'hala_egtimaia_id',
    'hala_sehia': 'hala_sehia_id',
    'e_s': 'e_s_id',
    'stage': 'stage_id',
    'fathers': 'father_id',
    'khdma': 'khdma_id',
    'users': 'pass_id',
    'icon': 'icon_id',
    'inter_icon': 'inter_id',
    'osra': 'osra_id',
    'person': 'person_id',
    'eatraf': 'eatraf_id',
    'visits': 'visit_id',
    'monasba': 'monasba_id',
    'count_aid': 'count_id',
    'count_2': 'count_2_id',
    'masrofat': 'masrofat_id',
  };

  _BasePostgresExecutor(this._client, this._baseUrlProvider, this._txId);

  Uri _endpoint(String path) => Uri.parse('${_baseUrlProvider()}$path');

  static List<Map<String, dynamic>> encodeParams(List<Object?>? args) {
    if (args == null || args.isEmpty) return const [];
    return args.map((arg) {
      if (arg == null) {
        return {'type': 'null', 'value': null};
      } else if (arg is int) {
        return {'type': 'int', 'value': arg};
      } else if (arg is double) {
        return {'type': 'double', 'value': arg};
      } else if (arg is num) {
        return {'type': 'double', 'value': arg.toDouble()};
      } else if (arg is bool) {
        return {'type': 'bool', 'value': arg};
      } else if (arg is Uint8List) {
        return {'type': 'bytes', 'value': base64Encode(arg)};
      } else if (arg is List<int>) {
        return {'type': 'bytes', 'value': base64Encode(Uint8List.fromList(arg))};
      } else if (arg is DateTime) {
        return {'type': 'string', 'value': arg.toIso8601String()};
      } else {
        return {'type': 'string', 'value': arg.toString()};
      }
    }).toList();
  }

  Future<Map<String, dynamic>> _postJson(String path, Map<String, dynamic> body) async {
    final response = await _client
        .post(
          _endpoint(path),
          headers: const {'Content-Type': 'application/json; charset=utf-8'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      String errMsg = 'HTTP ${response.statusCode}';
      try {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map && decoded['error'] != null) {
          errMsg = decoded['error'].toString();
        }
      } catch (_) {
        errMsg = utf8.decode(response.bodyBytes);
      }
      throw Exception('خطأ في اتصال السيرفر ($path): $errMsg');
    }

    if (response.bodyBytes.isEmpty) return <String, dynamic>{};
    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }

  @override
  Future<void> execute(String sql, [List<Object?>? arguments]) async {
    if (sql.trim().toUpperCase().startsWith('PRAGMA')) return;
    await _postJson('/api/storage/execute', {
      'sql': sql,
      'params': encodeParams(arguments),
      if (_txId != null) 'txId': _txId,
    });
  }

  @override
  Future<int> rawInsert(String sql, [List<Object?>? arguments]) async {
    final res = await _postJson('/api/storage/insert', {
      'sql': sql,
      'params': encodeParams(arguments),
      if (_txId != null) 'txId': _txId,
    });
    return (res['lastInsertRowId'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    final cleaned = Map<String, Object?>.from(values);
    final pk = _singleIdPrimaryKeys[table.toLowerCase()];
    if (pk != null) {
      cleaned.removeWhere((k, v) => k.toLowerCase() == pk && v == null);
    }

    String prefix = 'INSERT INTO';
    if (conflictAlgorithm == ConflictAlgorithm.ignore) {
      prefix = 'INSERT OR IGNORE INTO';
    } else if (conflictAlgorithm == ConflictAlgorithm.replace) {
      prefix = 'INSERT OR REPLACE INTO';
    }

    final cols = cleaned.keys.toList();
    final args = cols.map((k) => cleaned[k]).toList();
    final colsSql = cols.map((c) => '"$c"').join(', ');
    final placeholders = List.filled(cols.length, '?').join(', ');
    final sql = '$prefix "$table" ($colsSql) VALUES ($placeholders)';

    return rawInsert(sql, args);
  }

  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    final sb = StringBuffer('SELECT ');
    if (distinct == true) sb.write('DISTINCT ');
    if (columns != null && columns.isNotEmpty) {
      sb.write(columns.join(', '));
    } else {
      sb.write('*');
    }
    sb.write(' FROM "$table"');
    if (where != null && where.trim().isNotEmpty) {
      sb.write(' WHERE $where');
    }
    if (groupBy != null && groupBy.trim().isNotEmpty) {
      sb.write(' GROUP BY $groupBy');
    }
    if (having != null && having.trim().isNotEmpty) {
      sb.write(' HAVING $having');
    }
    if (orderBy != null && orderBy.trim().isNotEmpty) {
      sb.write(' ORDER BY $orderBy');
    }
    if (limit != null) {
      sb.write(' LIMIT $limit');
    }
    if (offset != null) {
      sb.write(' OFFSET $offset');
    }

    return rawQuery(sb.toString(), whereArgs);
  }

  @override
  Future<List<Map<String, Object?>>> rawQuery(String sql, [List<Object?>? arguments]) async {
    if (sql.trim().toUpperCase().startsWith('PRAGMA')) return <Map<String, Object?>>[];
    final res = await _postJson('/api/storage/query', {
      'sql': sql,
      'params': encodeParams(arguments),
      if (_txId != null) 'txId': _txId,
    });
    final rawRows = (res['rows'] as List<dynamic>? ?? const []);
    return rawRows
        .map((r) => CaseInsensitiveRowMap(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  @override
  Future<QueryCursor> rawQueryCursor(
    String sql,
    List<Object?>? arguments, {
    int? bufferSize,
  }) {
    throw UnimplementedError('rawQueryCursor is not used in this project.');
  }

  @override
  Future<QueryCursor> queryCursor(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
    int? bufferSize,
  }) {
    throw UnimplementedError('queryCursor is not used in this project.');
  }

  @override
  Future<int> rawUpdate(String sql, [List<Object?>? arguments]) async {
    final res = await _postJson('/api/storage/execute', {
      'sql': sql,
      'params': encodeParams(arguments),
      if (_txId != null) 'txId': _txId,
    });
    return (res['affectedRows'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    final cols = values.keys.toList();
    final setClause = cols.map((c) => '"$c" = ?').join(', ');
    final args = <Object?>[
      ...cols.map((c) => values[c]),
      if (whereArgs != null) ...whereArgs,
    ];
    final sql = 'UPDATE "$table" SET $setClause${where != null && where.trim().isNotEmpty ? ' WHERE $where' : ''}';
    return rawUpdate(sql, args);
  }

  @override
  Future<int> rawDelete(String sql, [List<Object?>? arguments]) async {
    return rawUpdate(sql, arguments);
  }

  @override
  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    final sql = 'DELETE FROM "$table"${where != null && where.trim().isNotEmpty ? ' WHERE $where' : ''}';
    return rawDelete(sql, whereArgs);
  }

  @override
  Batch batch() => _DotNetPostgresBatch(this);
}

class _DotNetPostgresTransaction extends _BasePostgresExecutor implements Transaction {
  final DotNetPostgresDatabase _parentDb;

  _DotNetPostgresTransaction(this._parentDb, String txId)
      : super(_parentDb._client, _parentDb._baseUrlProvider, txId);

  @override
  Database get database => _parentDb;
}

class _DotNetPostgresBatch implements Batch {
  final _BasePostgresExecutor _executor;
  final List<Map<String, dynamic>> _statements = [];

  _DotNetPostgresBatch(this._executor);

  @override
  int get length => _statements.length;

  @override
  Future<List<Object?>> commit({bool? exclusive, bool? noResult, bool? continueOnError}) async {
    if (_statements.isEmpty) return const [];
    final res = await _executor._postJson('/api/storage/batch', {
      'statements': _statements,
      if (_executor._txId != null) 'txId': _executor._txId,
    });
    _statements.clear();
    if (noResult == true) return const [];
    return [(res['affectedRows'] as num?)?.toInt() ?? 0];
  }

  @override
  Future<List<Object?>> apply({bool? noResult, bool? continueOnError}) =>
      commit(noResult: noResult, continueOnError: continueOnError);

  @override
  void rawInsert(String sql, [List<Object?>? arguments]) {
    _statements.add({
      'sql': sql,
      'params': _BasePostgresExecutor.encodeParams(arguments),
    });
  }

  @override
  void insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) {
    final cleaned = Map<String, Object?>.from(values);
    final pk = _BasePostgresExecutor._singleIdPrimaryKeys[table.toLowerCase()];
    if (pk != null) {
      cleaned.removeWhere((k, v) => k.toLowerCase() == pk && v == null);
    }
    String prefix = 'INSERT INTO';
    if (conflictAlgorithm == ConflictAlgorithm.ignore) {
      prefix = 'INSERT OR IGNORE INTO';
    } else if (conflictAlgorithm == ConflictAlgorithm.replace) {
      prefix = 'INSERT OR REPLACE INTO';
    }
    final cols = cleaned.keys.toList();
    final args = cols.map((k) => cleaned[k]).toList();
    final colsSql = cols.map((c) => '"$c"').join(', ');
    final placeholders = List.filled(cols.length, '?').join(', ');
    rawInsert('$prefix "$table" ($colsSql) VALUES ($placeholders)', args);
  }

  @override
  void rawUpdate(String sql, [List<Object?>? arguments]) {
    _statements.add({
      'sql': sql,
      'params': _BasePostgresExecutor.encodeParams(arguments),
    });
  }

  @override
  void update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) {
    final cols = values.keys.toList();
    final setClause = cols.map((c) => '"$c" = ?').join(', ');
    final args = <Object?>[
      ...cols.map((c) => values[c]),
      if (whereArgs != null) ...whereArgs,
    ];
    final sql = 'UPDATE "$table" SET $setClause${where != null && where.trim().isNotEmpty ? ' WHERE $where' : ''}';
    rawUpdate(sql, args);
  }

  @override
  void rawDelete(String sql, [List<Object?>? arguments]) => rawUpdate(sql, arguments);

  @override
  void delete(String table, {String? where, List<Object?>? whereArgs}) {
    final sql = 'DELETE FROM "$table"${where != null && where.trim().isNotEmpty ? ' WHERE $where' : ''}';
    rawDelete(sql, whereArgs);
  }

  @override
  void execute(String sql, [List<Object?>? arguments]) => rawUpdate(sql, arguments);

  @override
  void query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) {}

  @override
  void rawQuery(String sql, [List<Object?>? arguments]) {}
}

class DotNetPostgresDatabase extends _BasePostgresExecutor implements Database {
  bool _isOpen = true;

  DotNetPostgresDatabase({
    http.Client? client,
    String Function()? baseUrlProvider,
  }) : super(
          client ?? http.Client(),
          baseUrlProvider ?? (() => ServerConfig.baseUrl),
          null,
        );

  @override
  Database get database => this;

  @override
  String get path => _baseUrlProvider();

  @override
  bool get isOpen => _isOpen;

  @override
  Future<void> close() async {
    _isOpen = false;
  }

  @override
  Future<T> transaction<T>(
    Future<T> Function(Transaction txn) action, {
    bool? exclusive,
  }) async {
    final beginRes = await _postJson('/api/storage/tx/begin', const {});
    final txId = beginRes['txId'] as String;
    final txn = _DotNetPostgresTransaction(this, txId);
    try {
      final result = await action(txn);
      await _postJson('/api/storage/tx/commit', {'txId': txId});
      return result;
    } catch (e) {
      try {
        await _postJson('/api/storage/tx/rollback', {'txId': txId});
      } catch (_) {}
      rethrow;
    }
  }

  @override
  Future<T> readTransaction<T>(Future<T> Function(Transaction txn) action) =>
      transaction(action);

  @override
  Future<T> devInvokeMethod<T>(String method, [Object? arguments]) =>
      throw UnimplementedError();

  @override
  Future<T> devInvokeSqlMethod<T>(String method, String sql, [List<Object?>? arguments]) =>
      throw UnimplementedError();
}
```

### 3.5 عميل SignalR اللحظي عبر WebSocket (`lib/sync/signalr_sync_service.dart`)
أنشئ الملف `lib/sync/signalr_sync_service.dart` (مطابقاً لمواصفات المرجع الثاني `02-realtime-ui.md`):
- يستخدم `web_socket_channel` للاتصال بـ `${wsBaseUrl}/hubs/sync` (حيث `http://` يتحول إلى `ws://` و`https://` يتحول إلى `wss://`).
- يرسل إطار المصافحة فور الاتصال: `'{"protocol":"json","version":1}\x1e'`.
- يفصل الرسائل الواردة بفاصل `\x1e`.
- عندما يستقبل رسالة `type == 1` و`target == 'DatabaseChanged'`، يستخرج قائمة الجداول `tables` ويطلقها عبر `Stream<Set<String>> onTablesChanged`.
- يرد على `type == 6` (Ping) بإرسال `'{"type":6}\x1e'`.
- يدعم إعادة الاتصال التلقائي المتدرج (Exponential Backoff: 2s -> 4s -> 8s -> 15s) عند انقطاع الشبكة، وعند استعادة الاتصال يبث حدث `{'*'} ` لتحديث جميع الشاشات المفتوحة فوراً!
- يوفر `SignalRSyncProvider extends ChangeNotifier` لعرض حالة الاتصال اللحظي (`isConnected`) في الشريط العلوي.

### 3.6 منسق التحديثات اللحظية للواجهة بدون وميض (`lib/sync/data_sync_coordinator.dart`)
أنشئ الملف `lib/sync/data_sync_coordinator.dart`:
- عبارة عن `StatefulWidget` يلتف حول شجرة التطبيق داخل `MultiProvider` في `lib/app.dart`.
- يستمع لـ `SignalRSyncService.instance.onTablesChanged` مع **Debounce لمدة 120ms** لدمج الإشعارات المتلاحقة.
- يوجه التحديثات الصامتة (`refreshSilently()`) إلى الـ Providers حسب الجداول المتأثرة:
  1. إذا تغير أي من `{'*', 'osra', 'person', 'areas', 'streets'}` -> يستدعي `context.read<FamilyProvider>().refreshSilently()`.
  2. إذا تغير أي من `{'*', 'areas', 'streets', 'fathers', 'karaba', 'mostwa', 'hala_egtimaia', 'hala_sehia', 'e_s', 'stage', 'khdma'}` -> يستدعي `context.read<LookupProvider>().refreshSilently()`.
  3. إذا تغير أي من `{'*', 'eatraf', 'visits', 'monasba', 'osra', 'person'}` -> يستدعي `context.read<TrackingProvider>().refreshSilently()`.
  4. إذا تغير أي من `{'*', 'count_aid', 'count_2', 'masrofat'}` -> يستدعي `context.read<FinancialProvider>().refreshSilently()`.
  5. إذا تغير أي من `{'*', 'users', 'inter_icon', 'icon'}` -> يستدعي `context.read<AuthProvider>().refreshSilently()`.
  6. إذا تغير أي من `{'*', 'settings'}` -> يستدعي `context.read<SettingsProvider>().loadSettings()`.

### 3.7 نافذة وزر إعدادات الاتصال بالسيرفر والمزامنة (`lib/sync/server_connection_dialog.dart`) — إلزامي بنفس التصميم القياسي حرفياً!
أنشئ الملف `lib/sync/server_connection_dialog.dart` بالكود الكامل التالي (يطابق التصميم القياسي حرفياً ويدعم `Provider` / `ChangeNotifier` والمنفذ `5060` واكتشاف عنوان الشبكة المحلية `LAN_URL` من `SERVER_INFO.txt` أو كروت الشبكة ورفع ملف SQLite المحلي مباشرة إلى PostgreSQL):

```dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../data/database/database_helper.dart';
import '../providers/auth_provider.dart';
import '../providers/family_provider.dart';
import '../providers/financial_provider.dart';
import '../providers/lookup_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/tracking_provider.dart';
import 'server_config.dart';
import 'server_connection_service.dart';
import 'signalr_sync_service.dart';

/// زر/شارة حالة الاتصال المباشر (يوضع في شاشة تسجيل الدخول وفي الشريط العلوي للشاشة الرئيسية)
class ServerConnectionStatusButton extends StatelessWidget {
  final bool compact;
  final bool darkBackground;

  const ServerConnectionStatusButton({
    super.key,
    this.compact = false,
    this.darkBackground = true,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer2<ServerConfigProvider, SignalRSyncProvider>(
      builder: (context, cfg, signalR, _) {
        final Color dotColor;
        final String statusLabel;
        final String tooltipText;

        if (!cfg.isServerMode) {
          dotColor = const Color(0xFF60A5FA); // Blue for Local SQLite
          statusLabel = 'محلي (SQLite)';
          tooltipText =
              'وضع التشغيل: قاعدة بيانات محلية (SQLite) — اضغط لإعدادات الاتصال بالسيرفر';
        } else if (signalR.isConnected) {
          dotColor = const Color(0xFF10B981); // Emerald Green
          statusLabel = 'متصل بالسيرفر (SignalR)';
          tooltipText =
              'متصل بسيرفر .NET + PostgreSQL والمزامنة الفورية نشطة (${cfg.baseUrl})';
        } else if (signalR.isConnecting) {
          dotColor = const Color(0xFFF59E0B); // Amber
          statusLabel = 'جارٍ الاتصال بالسيرفر...';
          tooltipText = 'جارٍ الاتصال بسيرفر المزامنة (${cfg.baseUrl})';
        } else {
          dotColor = const Color(0xFFEF4444); // Red
          statusLabel = 'السيرفر غير متصل';
          tooltipText =
              'تعذر الاتصال بسيرفر المزامنة (${cfg.baseUrl}) — اضغط للتحقق من الإعدادات';
        }

        final fgColor = darkBackground ? Colors.white : const Color(0xFF1A237E);

        if (compact) {
          return Tooltip(
            message: tooltipText,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => ServerConnectionDialog.show(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: darkBackground
                      ? Colors.white.withValues(alpha: 0.12)
                      : const Color(0xFF1A237E).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: dotColor.withValues(alpha: 0.55),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: dotColor,
                        boxShadow: [
                          BoxShadow(
                            color: dotColor.withValues(alpha: 0.5),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      cfg.isServerMode
                          ? Icons.dns_rounded
                          : Icons.storage_rounded,
                      size: 14,
                      color: fgColor.withValues(alpha: 0.9),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: fgColor.withValues(alpha: 0.95),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.settings_ethernet_rounded,
                      size: 14,
                      color: fgColor.withValues(alpha: 0.8),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Tooltip(
          message: tooltipText,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => ServerConnectionDialog.show(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: darkBackground
                      ? Colors.white.withValues(alpha: 0.14)
                      : const Color(0xFF1A237E).withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: darkBackground
                        ? Colors.white.withValues(alpha: 0.28)
                        : const Color(0xFF1A237E).withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: dotColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.settings_ethernet_rounded,
                      size: 18,
                      color: fgColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'إعدادات الاتصال والسيرفر ($statusLabel)',
                      style: TextStyle(
                        color: fgColor,
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class ServerConnectionDialog extends StatefulWidget {
  const ServerConnectionDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const ServerConnectionDialog(),
    );
  }

  @override
  State<ServerConnectionDialog> createState() => _ServerConnectionDialogState();
}

class _ServerConnectionDialogState extends State<ServerConnectionDialog> {
  late bool _isServerMode;
  late TextEditingController _urlController;
  bool _isTesting = false;
  bool _isSaving = false;
  bool _isUploadingDb = false;
  ServerConnectionCheckResult? _healthResult;
  String? _lanUrl;

  @override
  void initState() {
    super.initState();
    _isServerMode = ServerConfig.isServerMode;
    _urlController = TextEditingController(text: ServerConfig.baseUrl);
    _discoverLanUrl();
  }

  Future<void> _discoverLanUrl() async {
    if (kIsWeb) return;
    try {
      // 1) البحث في SERVER_INFO.txt إن وُجد
      if (Platform.isWindows) {
        final exeDir = File(Platform.resolvedExecutable).parent.path;
        final candidates = [
          '$exeDir\\SERVER_INFO.txt',
          '${Directory.current.path}\\SERVER_INFO.txt',
        ];
        for (final path in candidates) {
          final f = File(path);
          if (await f.exists()) {
            final lines = await f.readAsLines();
            for (final line in lines) {
              if (line.startsWith('LAN_URL=')) {
                final val = line.substring('LAN_URL='.length).trim();
                if (val.isNotEmpty && mounted) {
                  setState(() => _lanUrl = val);
                  return;
                }
              }
            }
          }
        }
      }

      // 2) اكتشاف IP الشبكة المحلية تلقائياً من كروت الشبكة
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback && !addr.address.startsWith('169.254.')) {
            if (mounted) {
              setState(() => _lanUrl = 'http://${addr.address}:5060');
            }
            return;
          }
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTesting = true;
      _healthResult = null;
    });
    final res = await ServerConnectionService.checkConnection(_urlController.text);
    if (mounted) {
      setState(() {
        _isTesting = false;
        _healthResult = res;
      });
    }
  }

  Future<void> _refreshAllProviders() async {
    if (!mounted) return;
    final familyProv = context.read<FamilyProvider>();
    final lookupProv = context.read<LookupProvider>();
    final trackingProv = context.read<TrackingProvider>();
    final financialProv = context.read<FinancialProvider>();
    final authProv = context.read<AuthProvider>();
    final settingsProv = context.read<SettingsProvider>();

    await Future.wait([
      familyProv.refreshSilently(),
      lookupProv.refreshSilently(),
      trackingProv.refreshSilently(),
      financialProv.refreshSilently(),
      authProv.refreshSilently(),
      settingsProv.loadSettings(),
    ]);
  }

  Future<void> _saveAndConnect() async {
    setState(() => _isSaving = true);
    try {
      final url = ServerConfig.normalizeUrl(_urlController.text);
      if (_isServerMode) {
        final check = await ServerConnectionService.checkConnection(url);
        if (!check.isReachable) {
          if (mounted) {
            setState(() {
              _healthResult = check;
              _isSaving = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(check.message),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      }

      if (!mounted) return;
      await context.read<ServerConfigProvider>().applySettings(
            enabled: _isServerMode,
            url: url,
          );

      await _refreshAllProviders();

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isServerMode
                  ? 'تم الاتصال بسيرفر .NET + PostgreSQL وتفعيل المزامنة الفورية (SignalR) بنجاح!'
                  : 'تم التبديل إلى قاعدة البيانات المحلية (SQLite) بنجاح.',
            ),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _uploadLocalDbToPostgres() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('رفع قاعدة البيانات المحلية إلى PostgreSQL'),
          content: const Text(
            'سيتم رفع جميع البيانات الموجودة في ملف SQLite المحلي على هذا الجهاز إلى قاعدة بيانات PostgreSQL على السيرفر ومزامنتها فوراً مع جميع الأجهزة المتصلة.\n\nهل تريد المتابعة؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('نعم، ارفع البيانات الآن'),
            ),
          ],
        ),
      ),
    );

    if (confirm != true) return;

    setState(() => _isUploadingDb = true);
    try {
      final url = ServerConfig.normalizeUrl(_urlController.text);
      final localPath = await DatabaseHelper().getLocalDatabasePath();
      final localFile = File(localPath);
      if (!await localFile.exists()) {
        throw Exception('ملف قاعدة البيانات المحلية غير موجود في: $localPath');
      }

      final bytes = await localFile.readAsBytes();
      final uri = Uri.parse('$url/api/storage/sqlite/import');
      final response = await http
          .post(
            uri,
            headers: const {'Content-Type': 'application/octet-stream'},
            body: bytes,
          )
          .timeout(const Duration(minutes: 2));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('فشل رفع البيانات (HTTP ${response.statusCode}): ${response.body}');
      }

      if (!mounted) return;
      await context.read<ServerConfigProvider>().applySettings(
            enabled: true,
            url: url,
          );
      await _refreshAllProviders();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تم رفع البيانات المحلية إلى PostgreSQL بنجاح وإشعار جميع الأجهزة عبر SignalR!',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل رفع البيانات: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingDb = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final signalR = context.watch<SignalRSyncProvider>();
    final primaryColor = Theme.of(context).primaryColor;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.settings_ethernet_rounded,
                        color: primaryColor,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'إعدادات الاتصال والسيرفر والمزامنة',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: primaryColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Flutter > Dart Logic > .NET 8 > PostgreSQL > SignalR',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w600,
                            ),
                            textDirection: TextDirection.ltr,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const Divider(height: 26),

                // 2. Mode Selection Cards
                const Text(
                  'وضع تشغيل قاعدة البيانات:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildModeOption(
                        selected: _isServerMode,
                        icon: Icons.dns_rounded,
                        title: 'سيرفر مركزي (.NET + PostgreSQL)',
                        subtitle: 'مزامنة فورية لحظية بين جميع الأجهزة عبر SignalR',
                        onTap: () => setState(() => _isServerMode = true),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildModeOption(
                        selected: !_isServerMode,
                        icon: Icons.storage_rounded,
                        title: 'قاعدة بيانات محلية (SQLite)',
                        subtitle: 'تشغيل منفرد على هذا الجهاز فقط بدون سيرفر',
                        onTap: () => setState(() => _isServerMode = false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // 3. Server URL Input
                Text(
                  'عنوان السيرفر (Server URL):',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                    color: _isServerMode ? Colors.black87 : Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: TextField(
                    controller: _urlController,
                    enabled: _isServerMode,
                    decoration: InputDecoration(
                      hintText: 'http://192.168.1.100:5060',
                      prefixIcon: const Icon(Icons.link_rounded),
                      suffixIcon: IconButton(
                        tooltip: 'استعادة العنوان الافتراضي',
                        icon: const Icon(Icons.restore_rounded, size: 18),
                        onPressed: _isServerMode
                            ? () => setState(
                                  () => _urlController.text =
                                      'http://127.0.0.1:5060',
                                )
                            : null,
                      ),
                    ),
                  ),
                ),

                // Quick Fill Discovered URLs
                if (_isServerMode) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.computer, size: 15),
                        label: const Text(
                          'نفس الجهاز (127.0.0.1:5060)',
                          style: TextStyle(fontSize: 11.5),
                        ),
                        onPressed: () {
                          setState(
                            () => _urlController.text = 'http://127.0.0.1:5060',
                          );
                        },
                      ),
                      if (_lanUrl != null)
                        ActionChip(
                          avatar: const Icon(Icons.lan_outlined, size: 15),
                          label: Text(
                            'الشبكة المحلية ($_lanUrl)',
                            style: const TextStyle(fontSize: 11.5),
                          ),
                          onPressed: () {
                            setState(() => _urlController.text = _lanUrl!);
                          },
                        ),
                    ],
                  ),
                ],

                const SizedBox(height: 16),

                // 4. Test Connection & Live SignalR Status Row
                if (_isServerMode) ...[
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _isTesting ? null : _testConnection,
                        icon: _isTesting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.network_check_rounded, size: 18),
                        label: const Text('اختبار الاتصال بالسيرفر'),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildSignalRStatusBadge(signalR),
                      ),
                    ],
                  ),
                ],

                // Health Test Result Banner
                if (_healthResult != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _healthResult!.isReachable
                          ? const Color(0xFFECFDF5)
                          : const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _healthResult!.isReachable
                            ? const Color(0xFF10B981)
                            : const Color(0xFFEF4444),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _healthResult!.isReachable
                              ? Icons.check_circle_rounded
                              : Icons.error_outline_rounded,
                          color: _healthResult!.isReachable
                              ? const Color(0xFF059669)
                              : const Color(0xFFDC2626),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _healthResult!.message,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _healthResult!.isReachable
                                  ? const Color(0xFF065F46)
                                  : const Color(0xFF991B1B),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // 5. Upload Local SQLite to PostgreSQL Card
                if (_isServerMode) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blueGrey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blueGrey.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.cloud_upload_outlined,
                          color: Color(0xFF1A237E),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'نقل البيانات المحلية إلى السيرفر (PostgreSQL)',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12.5,
                                ),
                              ),
                              Text(
                                'رفع بيانات SQLite الحالية على هذا الجهاز إلى قاعدة بيانات PostgreSQL',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed:
                              _isUploadingDb ? null : _uploadLocalDbToPostgres,
                          icon: _isUploadingDb
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.upload_file_rounded, size: 17),
                          label: const Text('رفع الآن'),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 22),

                // 6. Footer Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('إلغاء'),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: _isSaving ? null : _saveAndConnect,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save_rounded, size: 18),
                      label: Text(
                        _isServerMode
                            ? 'حفظ واتصال بالسيرفر الآن'
                            : 'حفظ والتشغيل محلياً',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeOption({
    required bool selected,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final primaryColor = Theme.of(context).primaryColor;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? primaryColor.withValues(alpha: 0.08)
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? primaryColor : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: selected ? primaryColor : Colors.grey.shade600,
                ),
                const Spacer(),
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  size: 18,
                  color: selected ? primaryColor : Colors.grey.shade400,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12.5,
                color: selected ? primaryColor : Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignalRStatusBadge(SignalRSyncProvider signalR) {
    final Color color;
    final String text;
    if (signalR.isConnected) {
      color = const Color(0xFF10B981);
      text = 'SignalR: متصل (مزامنة فورية)';
    } else if (signalR.isConnecting) {
      color = const Color(0xFFF59E0B);
      text = 'SignalR: جارٍ الاتصال...';
    } else {
      color = Colors.grey.shade600;
      text = 'SignalR: غير متصل حالياً';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
```

---

## المرحلة الرابعة (Phase 4): تحديث ملفات Flutter الحالية للتكامل السلس

### 4.1 تعديل `lib/data/database/database_helper.dart`
عدّل `DatabaseHelper` بحيث:
1. يحتوي على دالة عامة ثابتة `Future<String> getLocalDatabasePath()` تعيد مسار `eakhow_elrab.db` الموحد:
   - على Windows / Linux: `join(File(Platform.resolvedExecutable).parent.path, 'eakhow_elrab.db')`
   - على Android / iOS / macOS: `join((await getApplicationDocumentsDirectory()).path, 'AbonaFlemoon', 'eakhow_elrab.db')`
2. في `Future<Database> get database async`:
   - إذا كان `ServerConfig.isServerMode == true`، يعيد نسخة `DotNetPostgresDatabase()`!
   - إذا كان `ServerConfig.isServerMode == false`، يعيد قاعدة البيانات المحلية `_localDatabase ??= await _initLocalDatabase()`.
3. أضف دالة `Future<void> reopenDatabase() async` التي تغلق `_localDatabase` وتعيد تهيئة الاتصال، ودالة `Future<void> closeDatabase() async`.

### 4.2 تعديل `lib/data/services/backup_service.dart`
1. استبدل حساب المسار القديم باستدعاء `await DatabaseHelper().getLocalDatabasePath()` (لإصلاح اختلاف المسار على الويندوز!).
2. في `exportDatabase()`:
   - إذا كان `ServerConfig.isServerMode == true`: يقوم بتحميل ملف SQLite الكامل من السيرفر عبر `GET ${ServerConfig.baseUrl}/api/storage/sqlite/export` وحفظه في المسار الذي يختاره المستخدم عبر `FilePicker.platform.saveFile(...)`!
   - إذا كان `ServerConfig.isServerMode == false`: ينسخ الملف المحلي كما هو.
3. في `importDatabase()`:
   - يختار المستخدم ملف `.db` عبر `FilePicker.platform.pickFiles(...)`.
   - إذا كان `ServerConfig.isServerMode == true`: يرفع بايتات الملف إلى السيرفر عبر `POST ${ServerConfig.baseUrl}/api/storage/sqlite/import`، وبمجرد نجاح الطلب سيرسل السيرفر إشعار `DatabaseChanged` فتتحدث جميع الأجهزة فوراً!
   - إذا كان `ServerConfig.isServerMode == false`: يغلق قاعدة البيانات المحلية (`await DatabaseHelper().closeDatabase()`)، ينسخ الملف الجديد مكانها، ثم يستدعي `await DatabaseHelper().reopenDatabase()`.

### 4.3 تعديل الـ Providers السبعة لدعم التحديث الصامت بدون وميض (`refreshSilently`) والأداء العالي
1. **`lib/providers/family_provider.dart`:**
   - أضف متغيراً خاصاً `Future<List<Family>> Function()? _lastFetchAction;` يحفظ آخر عملية جلب (سواء كانت `loadFamilies(query: ...)` أو `loadFamiliesWithComplexFilters(...)`).
   - أضف دالة `Future<void> refreshSilently() async` تعيد تنفيذ `_lastFetchAction` (أو `_familyRepo.getFamilies()`) وتحدث `_families`، وإذا كان `_selectedFamily?.osraId != null` تحدث `_selectedFamily` و`_selectedFamilyMembers`، ثم تستدعي `notifyListeners()` **بدون تغيير `_isLoading`** (حتى لا تظهر دائرة التحميل ولا تضيع مدخلات المستخدم!).
   - في `Family.fromMap` داخل `lib/data/models/family_models.dart`: تأكد أن `memberCount` يُقرأ كـ `(map['member_count'] as num?)?.toInt() ?? 0` و`number` كـ `(map['number'] as num?)?.toInt() ?? 0` و`code` كـ `(map['code'] as num?)?.toInt()` لتفادي أي تعارض بين `int` و`int64` القادم من PostgreSQL `COUNT()`.
2. **`lib/providers/lookup_provider.dart`:**
   - أضف دالة `Future<void> refreshSilently() async` تجلب جميع الجداول الـ 10 بالتوازي (`Future.wait([...])`) وتحدث القوائم وتستدعي `notifyListeners()` بدون تفعيل `_isLoading = true`.
3. **`lib/providers/tracking_provider.dart`:**
   - احفظ `_lastPersonId` عند استدعاء `loadConfessions(int personId)` و`_lastFamilyId` عند استدعاء `loadVisits(int familyId)` أو `loadOccasions(int familyId)`.
   - أضف `Future<void> refreshSilently() async` يعيد جلب البيانات المفتوحة حالياً بدون تفعيل `_isLoading = true`.
   - في `TrackingRepository.addBatchVisits(List<int> familyIds, String date, String notes)` داخل `lib/data/repositories/tracking_repository.dart`: استخدم `final batch = db.batch();` ثم `batch.insert('visits', ...)` ثم `await batch.commit(noResult: true);` بدلاً من حلقة `for` فردية لكي تُرسل في طلب `/api/storage/batch` واحد فقط!
4. **`lib/providers/financial_provider.dart`:**
   - احفظ `int? _lastFamilyId;` عند استدعاء `loadAllFinancials(int familyId)` وأضف `Future<void> refreshSilently() async` يعيد تحميل المساعدات والمصروفات للأسرة الحالية بدون تفعيل `_isLoading = true`.
5. **`lib/providers/auth_provider.dart`:**
   - أضف `Future<void> refreshSilently() async` يعيد جلب صلاحيات `_currentUser` (إذا كان مسجلاً للدخول) ويستدعي `notifyListeners()`.
6. **`lib/providers/settings_provider.dart`:**
   - تأكد أن `loadSettings()` تحدث `_churchName` و`_serviceName` و`_themeMode` وتستدعي `notifyListeners()`.

### 4.4 تعديل `lib/main.dart` و`lib/app.dart` وإضافة زر الاتصال بالسيرفر في `login_screen.dart` و`home_screen.dart`
1. في `lib/main.dart`:
   - بعد `WidgetsFlutterBinding.ensureInitialized();` وقبل `await DatabaseHelper().database;`، استدعِ:
     ```dart
     await ServerBootstrap.initialize();
     if (ServerConfig.isServerMode) {
       SignalRSyncService.instance.start();
     }
     ```
2. في `lib/app.dart`:
   - سجل `ChangeNotifierProvider(create: (_) => ServerConfigProvider())` و`ChangeNotifierProvider(create: (_) => SignalRSyncProvider())` ضمن `MultiProvider`.
   - لف `MaterialApp` بـ `DataSyncCoordinator(child: MaterialApp(...))`.
3. **إلزامي في `lib/ui/screens/auth/login_screen.dart`:**
   - استورد `../../../sync/server_connection_dialog.dart`.
   - لف محتوى `Scaffold.body` بـ `Stack` وضع `ServerConnectionStatusButton` في أعلى اليسار (كما في الصورة القياسية تماماً):
     ```dart
     body: Stack(
       children: [
         Container(
           // الخلفية المتدرجة وبطاقة تسجيل الدخول الحالية كما هي
           ...
         ),
         const Positioned(
           top: 16,
           left: 16,
           child: SafeArea(
             child: ServerConnectionStatusButton(
               darkBackground: true,
             ),
           ),
         ),
       ],
     ),
     ```
4. **إلزامي في `lib/ui/screens/home/home_screen.dart`:**
   - استورد `../../../sync/server_connection_dialog.dart`.
   - في `AppBar.actions` (قبل زر تبديل الثيم وزر تسجيل الخروج) أضف الزر المدمج:
     ```dart
     actions: [
       const Padding(
         padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
         child: ServerConnectionStatusButton(
           compact: true,
           darkBackground: true,
         ),
       ),
       // باقي الأزرار الحالية في AppBar
       ...
     ],
     ```
5. في `lib/ui/screens/admin/users_screen.dart` و`lib/ui/screens/reports/birthdays_screen.dart`:
   - اربط الشاشتين بـ `AuthProvider` و`FamilyProvider` بحيث عند تغير بيانات الـ Provider يتم تحديث القائمة المحلية تلقائياً.

---

## المرحلة الخامسة (Phase 5): إعدادات الشبكة للموبايل (`AndroidManifest.xml`)

في الملف `android/app/src/main/AndroidManifest.xml`:
1. أضف قبل `<application`:
   ```xml
   <uses-permission android:name="android.permission.INTERNET"/>
   <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
   ```
2. أضف داخل وسم `<application`:
   ```xml
   android:usesCleartextTraffic="true"
   ```
   (ضروري جداً لكي يتمكن تطبيق الأندرويد من الاتصال بالسيرفر المحلي عبر `http://192.168.x.x:5060` بدون رفض نظام أندرويد لاتصالات HTTP غير المشفرة).

---

## المرحلة السادسة (Phase 6): بناء المثبت الشامل وسكربتات السيرفر (`installer/*` و`build_and_make_installer.bat`)

انسخ هيكل المثبت من `E:\Final\petros_pols_flutter\installer` وخصصه بالكامل لبرنامج العضوية الكنسية (`AbonaFlemoon`):

### 6.1 سكربت التثبيت `installer/install-server.ps1`
- يستقبل `-InstallDir` و`-ServerPort 5060` و`-PostgresPort 5435` و`-StartNow $true` و`-Silent $true`.
- يضيف قواعد جدار الحماية (Windows Firewall) للمنفذين `5060` (TCP) و`5435` (TCP) باسم `"AbonaFlemoon Sync Server (5060)"` و`"AbonaFlemoon PostgreSQL (5435)"`.
- يسجل `AbonaFlemoonServerManager.exe --background` في `HKCU\Software\Microsoft\Windows\CurrentVersion\Run`.
- يشغل `AbonaFlemoonServerManager.exe --background` وينتظر حتى يستجيب `http://127.0.0.1:5060/api/auth/ping`.

### 6.2 سكربت الإصلاح `installer/repair-server.ps1` وسكربت الحذف `installer/uninstall-server.ps1`
- `repair-server.ps1`: يوقف أي عمليات معلقة لـ `AbonaFlemoon.SyncServer` أو `AbonaFlemoonServerManager`، يعيد ضبط قواعد Firewall، ويعيد تشغيل المدير.
- `uninstall-server.ps1`: يوقف `AbonaFlemoonServerManager` و`AbonaFlemoon.SyncServer` وعمليات `postgres.exe` التابعة لمجلد التطبيق، ويحذف مفتاح بدء التشغيل التلقائي وقواعد جدار الحماية.

### 6.3 ملف Inno Setup `installer/AbonaFlemoonSetup.iss`
- معرف التطبيق الفريد: `AppId={{D84A91F2-6C3E-49B1-A5E8-7F2B39C14560}}`
- اسم البرنامج: `برنامج العضوية الكنسية - إخوة الرب`
- ملف الإخراج: `installer\Output\AbonaFlemoon_Setup_v1.0.0.exe`
- يدعم وضعي تثبيت (`WizardForm` Radio Buttons كما في `SundaySchoolSetup.iss`):
  1. **الوضع الأول (`ClientOnly` - افتراضي للأجهزة الفرعية):** يثبت واجهة البرنامج `abona_flemoon.exe` فقط بدون السيرفر وبدون PostgreSQL.
  2. **الوضع الثاني (`FullServer` - للجهاز الرئيسي/السيرفر):** يثبت واجهة البرنامج + `AbonaFlemoonServerManager.exe` + `server\AbonaFlemoon.SyncServer.exe` + محرك `pgsql\` المحمول + `tools\` (`cloudflared.exe` / `ngrok.exe`) ويشغل `install-server.ps1` تلقائياً في نهاية التثبيت!

### 6.4 سكربت البناء الشامل `build_and_make_installer.bat`
يقوم بالخطوات التالية بالترتيب:
1. بناء تطبيق Flutter للويندوز: `flutter build windows --release`
2. نشر سيرفر التزامن `.NET 8`:
   `dotnet publish AbonaFlemoon.SyncServer\AbonaFlemoon.SyncServer.csproj -c Release -r win-x64 --self-contained true -o build\installer_staging\server`
3. نشر مدير السيرفر `AbonaFlemoonServerManager`:
   `dotnet publish AbonaFlemoonServerManager\AbonaFlemoonServerManager.csproj -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true -o build\installer_staging\manager`
4. نسخ محرك PostgreSQL المحمول (`pgsql`) وأدوات الأنفاق (`tools`) من المسارات المرجعية المتاحة على الجهاز (`E:\Final\petros_pols_flutter\build\installer_staging\pgsql` أو `E:\POWER\Offline_First_Sync\...`) إذا كانت متوفرة، أو تجهيز مجلداتها في `build\installer_staging`.
5. تشغيل `ISCC.exe installer\AbonaFlemoonSetup.iss` لتوليد ملف التنصيب النهائي `installer\Output\AbonaFlemoon_Setup_v1.0.0.exe`.

---

## المرحلة السابعة (Phase 7): اختبارات العقد والتحقق الآلي (`test/remote_database_contract_test.dart`)

أنشئ ملف الاختبار `test/remote_database_contract_test.dart` للتحقق من:
1. **`CaseInsensitiveRowMap`:** القراءة والكتابة والحذف بأحرف كبيرة وصغيرة (`osra_id`, `OSRA_ID`, `member_count`).
2. **`encodeParams`:** تحويل الأنواع (`int`, `double`, `bool`, `String`, `Uint8List`, `null`) إلى صيغة `SqlParamDto` المطابقة للسيرفر.
3. **حذف المفتاح الأساسي الفارغ (`null` PK) عند `insert`:** التأكد من أن `insert('osra', {'osra_id': null, 'osra_name': 'أسرة تجريبية'})` يرسل جملة `INSERT INTO "osra" ("osra_name") VALUES (?)` بدون العمود `osra_id`!
4. **تحويل `ConflictAlgorithm.ignore` و`ConflictAlgorithm.replace`:** التأكد من توليد `INSERT OR IGNORE INTO` و`INSERT OR REPLACE INTO`.
5. **عزل الـ Transaction (`txId`):** التأكد من أن جميع الأوامر داخل `db.transaction((txn) async { ... })` تحمل نفس `txId` وتستدعي `/api/storage/tx/begin` ثم `/api/storage/tx/commit` (أو `/api/storage/tx/rollback` عند الخطأ).

---

## المرحلة الثامنة (Phase 8): خطوات التحقق الإلزامية قبل التسليم

على الموديل المنفذ (`gemini3.8flash`) تنفيذ الأوامر التالية والتأكد من نجاحها بنسبة 100% بدون أي خطأ:

1. **بناء السيرفر الخلفي:**
   ```powershell
   dotnet build "e:\el odwia\project\AbonaFlemoon.SyncServer\AbonaFlemoon.SyncServer.csproj" -c Release
   ```
2. **بناء مدير السيرفر:**
   ```powershell
   dotnet build "e:\el odwia\project\AbonaFlemoonServerManager\AbonaFlemoonServerManager.csproj" -c Release
   ```
3. **فحص ملفات Dart المعدلة والجديدة (بدون تشغيل `flutter analyze` العام):**
   ```powershell
   dart analyze lib/sync/server_config.dart lib/sync/server_connection_service.dart lib/sync/dotnet_postgres_database.dart lib/sync/signalr_sync_service.dart lib/sync/data_sync_coordinator.dart lib/sync/server_connection_dialog.dart lib/data/database/database_helper.dart lib/data/services/backup_service.dart lib/providers/family_provider.dart lib/providers/lookup_provider.dart lib/providers/tracking_provider.dart lib/providers/financial_provider.dart lib/providers/auth_provider.dart lib/providers/settings_provider.dart lib/main.dart lib/app.dart lib/ui/screens/auth/login_screen.dart lib/ui/screens/home/home_screen.dart
   ```
4. **تشغيل اختبارات العقد في Flutter:**
   ```powershell
   flutter test test/remote_database_contract_test.dart
   ```
5. **بناء نسخة الويندوز والتأكد من عدم وجود أي أخطاء ترجمة:**
   ```powershell
   flutter build windows --release
   ```

---

## القسم التاسع (Section 9): أمر المراجعة النهائي (إلزامي على `gemini3.8flash` طباعته للمستخدم في نهاية التنفيذ)

بعد أن تنتهي يا `gemini3.8flash` من تنفيذ جميع المراحل أعلاه والتحقق من نجاح جميع أوامر المرحلة الثامنة، **اطبع للمستخدم النص التالي داخل مربع كود (`markdown`) لكي ينسخه ويرسله في محادثة جديدة للموديل المراجع:**

```text
لقد قام موديل التنفيذ بتطبيق خطة التحويل في الملف `e:\el odwia\project\MIGRATION_PLAN_DETAILED.md` بناءً على المهارة `E:\Prog Progs\skills\flutter-sqlite-dotnet-postgres`.
أرجو منك الآن القيام بمراجعة شاملة ودقيقة (Full Code & Architecture Audit) وراء الموديل المنفذ والتأكد من النقاط التالية:

1. مراجعة مشروع الـ Backend (`AbonaFlemoon.SyncServer`):
   - مطابقة الـ 22 جدولاً في `PostgresSchemaInitializer.cs` مع `database_helper.dart` ومزامنة الـ Sequences (`SyncAllSequencesAsync`) والاستيراد التلقائي من `eakhow_elrab.db`.
   - دقة `SqlDialectTranslator.cs` في ترجمة القواعد الـ 10 + دوال `strftime('%m', ...)` و`strftime('%Y', ...)` و`strftime('%Y%m%d', ...)` و`date(...)` الخاصة بتقارير الميلاد والبحث المتقدم.
   - سلامة `StorageService.cs` في إدارة الـ Transactions (`txId` + `SemaphoreSlim`) وبث `DatabaseChanged` عبر SignalR بعد الـ Commit فقط، وتصدير/استيراد SQLite.

2. مراجعة مشروع مدير السيرفر (`AbonaFlemoonServerManager`):
   - فحص `ServerSupervisor.cs` و`TunnelSupervisor.cs` و`MainForm.cs` و`TunnelManagerForm.cs` والتأكد من إدارة PostgreSQL المحمول (منفذ 5435) وسيرفر .NET 8 (منفذ 5060) والـ Watchdog والـ System Tray والأنفاق السحابية.

3. مراجعة طبقة التزامن في Flutter (`lib/sync/*` والـ Providers والـ Screens):
   - فحص `dotnet_postgres_database.dart` والتأكد من حذف المفتاح الأساسي عندما يكون `null` عند الـ `insert`، ودعم `CaseInsensitiveRowMap` و`transaction` و`batch`.
   - فحص `signalr_sync_service.dart` و`data_sync_coordinator.dart` ودوال `refreshSilently()` في جميع الـ Providers للتأكد من التحديث اللحظي بدون وميض (Flicker-free).
   - فحص `server_connection_dialog.dart` والتأكد من وجود `ServerConnectionStatusButton` و`ServerConnectionDialog` بنفس التصميم القياسي في `login_screen.dart` و`home_screen.dart` (مع بطاقتي اختيار الوضع، وأزرار `نفس الجهاز` و`الشبكة المحلية`، وفحص الاتصال وشارة SignalR، وزر `رفع الآن` لنقل بيانات SQLite المحلية إلى PostgreSQL).

4. مراجعة ملفات المثبت (`installer/AbonaFlemoonSetup.iss` وسكربتات PowerShell و`build_and_make_installer.bat`).

5. تشغيل الاختبارات والفحص الفعلي (`dotnet build`, `dart analyze`, `flutter test`) وإصلاح أي نقص أو خطأ تجده بنفسك فوراً حتى يصبح المشروع جاهزاً للإنتاج بنسبة 100%.
```

