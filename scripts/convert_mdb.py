import sqlite3
import pyodbc
import os
import sys
import threading
import tkinter as tk
from tkinter import ttk, filedialog, messagebox
from decimal import Decimal

# ═══════════════════════════════════════════
# Global column mapping overrides
# ═══════════════════════════════════════════
COLUMN_MAPS = {
    'users': {'person_name': 'user_name'},
    'inter_icon': {'id': 'inter_id', 'state': 'check_1'},
    'osra': {'e_sid': 'e_s_id'},
    'hala_egtimaia': {'hala_egtimaia_name': 'hala_name', 'hala_egt_name': 'hala_name'},
    'hala_sehia': {'hala_sehia_name': 'hala_name'},
    'e_s': {'e_sid': 'e_s_id', 'e_sname': 'e_s_name'},
    'eatraf': {'id': 'eatraf_id'},
    'visits': {'id': 'visit_id'},
    'count_aid': {'count': 'count_value'},
    'count_2': {'count_2': 'count_2_id'},
    'masrofat': {'masrof_id': 'masrofat_id', 'count': 'count_value'}
}

TARGET_MAP = {
    'Pass': 'users', 'Icon': 'icon', 'Inter_Icon': 'inter_icon',
    'Osra': 'osra', 'Person': 'person', 'Areas': 'areas',
    'Streets': 'streets', 'Fathers': 'fathers', 'Stage': 'stage',
    'Karaba': 'karaba', 'Mostwa': 'mostwa', 'Hala_Egtimaia': 'hala_egtimaia',
    'Hala_Sehia': 'hala_sehia', 'E_S': 'e_s', 'KHdma': 'khdma',
    'Eatraf': 'eatraf', 'Visits': 'visits', 'Monasba': 'monasba',
    'Count': 'count_aid', 'Count_2': 'count_2', 'Masrofat': 'masrofat'
}

# ═══════════════════════════════════════════
# Table creation SQL (same schema as Flutter app)
# ═══════════════════════════════════════════
CREATE_TABLES_SQL = [
    '''CREATE TABLE IF NOT EXISTS areas (
        area_id INTEGER PRIMARY KEY AUTOINCREMENT,
        area_name TEXT NOT NULL UNIQUE
    )''',
    '''CREATE TABLE IF NOT EXISTS streets (
        street_id INTEGER PRIMARY KEY AUTOINCREMENT,
        street_name TEXT NOT NULL,
        area_id INTEGER NOT NULL,
        FOREIGN KEY (area_id) REFERENCES areas(area_id)
    )''',
    '''CREATE TABLE IF NOT EXISTS karaba (
        karaba_id INTEGER PRIMARY KEY AUTOINCREMENT,
        karaba_name TEXT NOT NULL UNIQUE
    )''',
    '''CREATE TABLE IF NOT EXISTS mostwa (
        mostwa_id INTEGER PRIMARY KEY AUTOINCREMENT,
        mostwa_name TEXT NOT NULL UNIQUE
    )''',
    '''CREATE TABLE IF NOT EXISTS hala_egtimaia (
        hala_egtimaia_id INTEGER PRIMARY KEY AUTOINCREMENT,
        hala_name TEXT NOT NULL UNIQUE
    )''',
    '''CREATE TABLE IF NOT EXISTS hala_sehia (
        hala_sehia_id INTEGER PRIMARY KEY AUTOINCREMENT,
        hala_name TEXT NOT NULL UNIQUE
    )''',
    '''CREATE TABLE IF NOT EXISTS e_s (
        e_s_id INTEGER PRIMARY KEY AUTOINCREMENT,
        e_s_name TEXT NOT NULL UNIQUE
    )''',
    '''CREATE TABLE IF NOT EXISTS stage (
        stage_id INTEGER PRIMARY KEY AUTOINCREMENT,
        stage_name TEXT NOT NULL UNIQUE
    )''',
    '''CREATE TABLE IF NOT EXISTS fathers (
        father_id INTEGER PRIMARY KEY AUTOINCREMENT,
        father_name TEXT NOT NULL,
        father_mobile TEXT,
        birth_date TEXT
    )''',
    '''CREATE TABLE IF NOT EXISTS khdma (
        khdma_id INTEGER PRIMARY KEY AUTOINCREMENT,
        khdma_name TEXT NOT NULL UNIQUE
    )''',
    '''CREATE TABLE IF NOT EXISTS osra (
        osra_id INTEGER PRIMARY KEY AUTOINCREMENT,
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
        FOREIGN KEY (karaba_id) REFERENCES karaba(karaba_id),
        FOREIGN KEY (e_s_id) REFERENCES e_s(e_s_id),
        FOREIGN KEY (area_id) REFERENCES areas(area_id),
        FOREIGN KEY (street_id) REFERENCES streets(street_id),
        FOREIGN KEY (hala_egtimaia_id) REFERENCES hala_egtimaia(hala_egtimaia_id)
    )''',
    '''CREATE TABLE IF NOT EXISTS person (
        person_id INTEGER PRIMARY KEY AUTOINCREMENT,
        person_name TEXT NOT NULL,
        osra_id INTEGER NOT NULL,
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
        FOREIGN KEY (osra_id) REFERENCES osra(osra_id),
        FOREIGN KEY (karaba_id) REFERENCES karaba(karaba_id),
        FOREIGN KEY (mostwa_id) REFERENCES mostwa(mostwa_id),
        FOREIGN KEY (hala_egtimaia_id) REFERENCES hala_egtimaia(hala_egtimaia_id),
        FOREIGN KEY (hala_sehia_id) REFERENCES hala_sehia(hala_sehia_id),
        FOREIGN KEY (stage_id) REFERENCES stage(stage_id),
        FOREIGN KEY (father_id) REFERENCES fathers(father_id)
    )''',
    '''CREATE TABLE IF NOT EXISTS eatraf (
        eatraf_id INTEGER PRIMARY KEY AUTOINCREMENT,
        person_id INTEGER NOT NULL,
        date TEXT NOT NULL,
        notes TEXT,
        FOREIGN KEY (person_id) REFERENCES person(person_id)
    )''',
    '''CREATE TABLE IF NOT EXISTS visits (
        visit_id INTEGER PRIMARY KEY AUTOINCREMENT,
        osra_id INTEGER NOT NULL,
        date TEXT NOT NULL,
        notes TEXT,
        FOREIGN KEY (osra_id) REFERENCES osra(osra_id)
    )''',
    '''CREATE TABLE IF NOT EXISTS monasba (
        monasba_id INTEGER PRIMARY KEY AUTOINCREMENT,
        osra_id INTEGER NOT NULL,
        monasba_name TEXT NOT NULL,
        monasba_date TEXT,
        month TEXT,
        FOREIGN KEY (osra_id) REFERENCES osra(osra_id)
    )''',
    '''CREATE TABLE IF NOT EXISTS count_aid (
        count_id INTEGER PRIMARY KEY AUTOINCREMENT,
        osra_id INTEGER NOT NULL,
        khdma_id INTEGER,
        count_value REAL DEFAULT 0,
        aynee TEXT,
        notes TEXT,
        FOREIGN KEY (osra_id) REFERENCES osra(osra_id),
        FOREIGN KEY (khdma_id) REFERENCES khdma(khdma_id)
    )''',
    '''CREATE TABLE IF NOT EXISTS count_2 (
        count_2_id INTEGER PRIMARY KEY AUTOINCREMENT,
        osra_id INTEGER NOT NULL,
        type TEXT,
        count_add REAL DEFAULT 0,
        notes TEXT,
        date_1 TEXT,
        FOREIGN KEY (osra_id) REFERENCES osra(osra_id)
    )''',
    '''CREATE TABLE IF NOT EXISTS masrofat (
        masrofat_id INTEGER PRIMARY KEY AUTOINCREMENT,
        osra_id INTEGER NOT NULL,
        masrof TEXT,
        count_value REAL DEFAULT 0,
        aynee TEXT,
        notes TEXT,
        FOREIGN KEY (osra_id) REFERENCES osra(osra_id)
    )''',
    '''CREATE TABLE IF NOT EXISTS users (
        pass_id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_name TEXT NOT NULL UNIQUE,
        pass_word TEXT NOT NULL
    )''',
    '''CREATE TABLE IF NOT EXISTS icon (
        icon_id INTEGER PRIMARY KEY AUTOINCREMENT,
        icon_name TEXT NOT NULL UNIQUE
    )''',
    '''CREATE TABLE IF NOT EXISTS inter_icon (
        inter_id INTEGER PRIMARY KEY AUTOINCREMENT,
        pass_id INTEGER NOT NULL,
        icon_id INTEGER,
        icon_name TEXT,
        check_1 INTEGER DEFAULT 1,
        FOREIGN KEY (pass_id) REFERENCES users(pass_id)
    )''',
]


class ConverterApp:
    def __init__(self, root):
        self.root = root
        self.root.title('تحويل قاعدة بيانات Access إلى SQLite — اخوة الرب')
        self.root.geometry('700x580')
        self.root.resizable(True, True)

        # Variables
        self.mdb_path = tk.StringVar()
        self.sqlite_path = tk.StringVar()
        self.password = tk.StringVar(value='2210')

        # Default SQLite path
        docs = os.path.join(os.path.expanduser('~'), 'Documents', 'AbonaFlemoon')
        self.sqlite_path.set(os.path.join(docs, 'eakhow_elrab.db'))

        self._build_ui()

    def _build_ui(self):
        main_frame = ttk.Frame(self.root, padding=20)
        main_frame.pack(fill=tk.BOTH, expand=True)

        # Title
        title = ttk.Label(main_frame, text='أداة تحويل قاعدة بيانات Access إلى SQLite',
                          font=('Segoe UI', 14, 'bold'))
        title.pack(pady=(0, 15))

        # --- Access file ---
        f1 = ttk.LabelFrame(main_frame, text='ملف Access (.mdb / .accdb)', padding=10)
        f1.pack(fill=tk.X, pady=5)
        ttk.Entry(f1, textvariable=self.mdb_path, width=60).pack(side=tk.LEFT, fill=tk.X, expand=True, padx=(0, 5))
        ttk.Button(f1, text='استعراض...', command=self._browse_mdb).pack(side=tk.LEFT)

        # --- SQLite output ---
        f2 = ttk.LabelFrame(main_frame, text='ملف SQLite الهدف (.db)', padding=10)
        f2.pack(fill=tk.X, pady=5)
        ttk.Entry(f2, textvariable=self.sqlite_path, width=60).pack(side=tk.LEFT, fill=tk.X, expand=True, padx=(0, 5))
        ttk.Button(f2, text='استعراض...', command=self._browse_sqlite).pack(side=tk.LEFT)

        # --- Password ---
        f3 = ttk.LabelFrame(main_frame, text='كلمة سر ملف Access', padding=10)
        f3.pack(fill=tk.X, pady=5)
        ttk.Entry(f3, textvariable=self.password, width=30).pack(side=tk.LEFT)

        # --- Convert button ---
        self.convert_btn = ttk.Button(main_frame, text='بدء التحويل ▶', command=self._start_conversion)
        self.convert_btn.pack(pady=15)

        # --- Progress ---
        self.progress = ttk.Progressbar(main_frame, mode='determinate', length=400)
        self.progress.pack(fill=tk.X, pady=5)

        self.status_label = ttk.Label(main_frame, text='جاهز للتحويل', font=('Segoe UI', 10))
        self.status_label.pack(pady=5)

        # --- Log ---
        log_frame = ttk.LabelFrame(main_frame, text='سجل التحويل', padding=5)
        log_frame.pack(fill=tk.BOTH, expand=True, pady=5)

        self.log_text = tk.Text(log_frame, height=10, wrap=tk.WORD, font=('Consolas', 9))
        scrollbar = ttk.Scrollbar(log_frame, orient=tk.VERTICAL, command=self.log_text.yview)
        self.log_text.configure(yscrollcommand=scrollbar.set)
        scrollbar.pack(side=tk.RIGHT, fill=tk.Y)
        self.log_text.pack(fill=tk.BOTH, expand=True)

    def _browse_mdb(self):
        path = filedialog.askopenfilename(
            title='اختر ملف Access',
            filetypes=[('Access Database', '*.mdb *.accdb'), ('All Files', '*.*')]
        )
        if path:
            self.mdb_path.set(path)

    def _browse_sqlite(self):
        path = filedialog.asksaveasfilename(
            title='اختر مكان حفظ ملف SQLite',
            defaultextension='.db',
            filetypes=[('SQLite Database', '*.db'), ('All Files', '*.*')]
        )
        if path:
            self.sqlite_path.set(path)

    def _log(self, msg):
        self.root.after(0, lambda: self._append_log(msg))

    def _append_log(self, msg):
        self.log_text.insert(tk.END, msg + '\n')
        self.log_text.see(tk.END)

    def _set_status(self, msg):
        self.root.after(0, lambda: self.status_label.configure(text=msg))

    def _set_progress(self, value):
        self.root.after(0, lambda: self.progress.configure(value=value))

    def _start_conversion(self):
        mdb = self.mdb_path.get().strip()
        sqlite = self.sqlite_path.get().strip()
        pwd = self.password.get().strip()

        if not mdb:
            messagebox.showerror('خطأ', 'يرجى اختيار ملف Access أولاً')
            return
        if not os.path.exists(mdb):
            messagebox.showerror('خطأ', f'ملف Access غير موجود:\n{mdb}')
            return
        if not sqlite:
            messagebox.showerror('خطأ', 'يرجى تحديد مكان حفظ ملف SQLite')
            return

        self.convert_btn.configure(state='disabled')
        self.log_text.delete('1.0', tk.END)
        self.progress.configure(value=0)

        thread = threading.Thread(target=self._run_migration, args=(mdb, sqlite, pwd), daemon=True)
        thread.start()

    def _run_migration(self, mdb_path, sqlite_path, password):
        try:
            self._log(f'ملف Access: {mdb_path}')
            self._log(f'ملف SQLite: {sqlite_path}')
            self._set_status('جاري الاتصال...')

            # Ensure directory exists
            sqlite_dir = os.path.dirname(sqlite_path)
            if sqlite_dir and not os.path.exists(sqlite_dir):
                os.makedirs(sqlite_dir)

            # Create/open SQLite and create tables
            sqlite_conn = sqlite3.connect(sqlite_path)
            sqlite_cursor = sqlite_conn.cursor()
            sqlite_cursor.execute('PRAGMA foreign_keys = OFF')

            self._log('إنشاء الجداول في SQLite...')
            for sql in CREATE_TABLES_SQL:
                sqlite_cursor.execute(sql)
            sqlite_conn.commit()

            sqlite_cursor.execute("SELECT name FROM sqlite_master WHERE type='table'")
            existing_tables = [r[0] for r in sqlite_cursor.fetchall()]
            self._log(f'عدد الجداول الموجودة: {len(existing_tables)}')

            # Connect to Access
            conn_str = f'DRIVER={{Microsoft Access Driver (*.mdb, *.accdb)}};DBQ={mdb_path};PWD={password};'
            self._set_status('جاري الاتصال بـ Access...')
            access_conn = pyodbc.connect(conn_str)
            access_cursor = access_conn.cursor()
            mdb_tables = [t.table_name for t in access_cursor.tables(tableType='TABLE')]
            self._log(f'جداول Access: {", ".join(mdb_tables)}')

            total_tables = len(TARGET_MAP)
            done_tables = 0

            for expected_mdb, target_sqlite in TARGET_MAP.items():
                done_tables += 1
                pct = int((done_tables / total_tables) * 100)
                self._set_progress(pct)

                actual_name = next((t for t in mdb_tables if t.lower() == expected_mdb.lower()), None)
                if not actual_name:
                    self._log(f'⏭ {expected_mdb} — غير موجود في Access')
                    continue
                if target_sqlite not in existing_tables:
                    self._log(f'⏭ {target_sqlite} — غير موجود في SQLite')
                    continue

                self._set_status(f'تحويل {actual_name} → {target_sqlite}...')
                try:
                    access_cursor.execute(f'SELECT * FROM [{actual_name}]')
                    rows = access_cursor.fetchall()
                    if not rows:
                        self._log(f'○ {actual_name} — لا توجد بيانات')
                        continue

                    columns = [col[0] for col in access_cursor.description]
                    sqlite_columns = []
                    overrides = COLUMN_MAPS.get(target_sqlite, {})
                    for col in columns:
                        sqlite_columns.append(overrides.get(col.lower(), col.lower()))

                    placeholders = ', '.join(['?'] * len(columns))
                    cols_str = ', '.join(sqlite_columns)
                    insert_sql = f'INSERT OR REPLACE INTO {target_sqlite} ({cols_str}) VALUES ({placeholders})'

                    success = 0
                    errors = 0
                    for row in rows:
                        try:
                            row_data = []
                            for val in row:
                                if isinstance(val, Decimal):
                                    row_data.append(float(val))
                                elif hasattr(val, 'isoformat'):
                                    row_data.append(val.isoformat())
                                else:
                                    row_data.append(val)
                            sqlite_cursor.execute(insert_sql, tuple(row_data))
                            success += 1
                        except Exception as e:
                            errors += 1
                            if errors <= 3:
                                self._log(f'  [خطأ إدخال]: {str(e)}')

                    sqlite_conn.commit()
                    msg = f'✓ {actual_name} → {target_sqlite}: {success}/{len(rows)} صف'
                    if errors:
                        msg += f' ({errors} أخطاء)'
                    self._log(msg)

                except Exception as e:
                    self._log(f'✗ {actual_name}: {str(e)[:80]}')

            access_conn.close()
            sqlite_conn.close()

            self._set_progress(100)
            self._set_status('✓ اكتمل التحويل بنجاح!')
            self._log('\n═══════════════════════════════════')
            self._log('تم التحويل بنجاح!')
            self._log(f'ملف SQLite: {sqlite_path}')
            self._log('═══════════════════════════════════')

            self.root.after(0, lambda: messagebox.showinfo('نجاح', 'تم تحويل البيانات بنجاح!'))

        except Exception as e:
            self._set_status(f'✗ خطأ: {str(e)[:60]}')
            self._log(f'\n✗ خطأ عام: {e}')
            self.root.after(0, lambda: messagebox.showerror('خطأ', f'حدث خطأ:\n{e}'))

        finally:
            self.root.after(0, lambda: self.convert_btn.configure(state='normal'))

def main():
    root = tk.Tk()
    app = ConverterApp(root)
    root.mainloop()

if __name__ == '__main__':
    main()
