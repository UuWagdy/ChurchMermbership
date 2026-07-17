import sqlite3
import sys

# Ensure UTF-8 printing
try:
    sys.stdout.reconfigure(encoding='utf-8')
except AttributeError:
    pass

db1 = r"E:\el odwia\El_Salamona.db"
db2 = r"E:\el odwia\ElKawsar.db"

def show_areas(path):
    print(f"=== Areas in {path} ===")
    conn = sqlite3.connect(path)
    c = conn.cursor()
    c.execute("SELECT * FROM areas")
    print("Areas:", c.fetchall())
    c.execute("SELECT * FROM streets")
    print("Streets:", c.fetchall())
    conn.close()

show_areas(db1)
show_areas(db2)
