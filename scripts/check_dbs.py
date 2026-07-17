import sqlite3
import os

db1 = r"E:\el odwia\El_Salamona.db"
db2 = r"E:\el odwia\ElKawsar.db"

def inspect_db(path):
    print(f"=== Inspecting {os.path.basename(path)} ===")
    if not os.path.exists(path):
        print("File does not exist")
        return
    conn = sqlite3.connect(path)
    c = conn.cursor()
    c.execute("SELECT name FROM sqlite_master WHERE type='table'")
    tables = [r[0] for r in c.fetchall()]
    print("Tables:", tables)
    for table in tables:
        c.execute(f"SELECT COUNT(*) FROM [{table}]")
        count = c.fetchone()[0]
        print(f"  Table: {table}, rows: {count}")
    conn.close()

inspect_db(db1)
inspect_db(db2)
