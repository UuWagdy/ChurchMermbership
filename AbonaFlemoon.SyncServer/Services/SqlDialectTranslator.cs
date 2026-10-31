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
