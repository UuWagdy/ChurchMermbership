import sqlite3
import os
import sys

# Ensure UTF-8 output
try:
    sys.stdout.reconfigure(encoding='utf-8')
except AttributeError:
    pass

db_salamona = r"E:\el odwia\El_Salamona.db"
db_kawsar = r"E:\el odwia\ElKawsar.db"
out_dir = r"E:\el odwia\project\assets\database"
db_out = os.path.join(out_dir, "eakhow_elrab.db")

# Ensure output directory exists
os.makedirs(out_dir, exist_ok=True)

if os.path.exists(db_out):
    os.remove(db_out)

conn_out = sqlite3.connect(db_out)
cur_out = conn_out.cursor()

# Create same schema
SCHEMA_SQL = [
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
        hala_sehia_id INTEGER,
        mostwa_id INTEGER,
        FOREIGN KEY (karaba_id) REFERENCES karaba(karaba_id),
        FOREIGN KEY (e_s_id) REFERENCES e_s(e_s_id),
        FOREIGN KEY (area_id) REFERENCES areas(area_id),
        FOREIGN KEY (street_id) REFERENCES streets(street_id),
        FOREIGN KEY (hala_egtimaia_id) REFERENCES hala_egtimaia(hala_egtimaia_id),
        FOREIGN KEY (hala_sehia_id) REFERENCES hala_sehia(hala_sehia_id),
        FOREIGN KEY (mostwa_id) REFERENCES mostwa(mostwa_id)
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
        rakm_komy TEXT,
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
    '''CREATE TABLE IF NOT EXISTS settings (
        setting_key TEXT PRIMARY KEY,
        setting_value TEXT
    )'''
]

for sql in SCHEMA_SQL:
    cur_out.execute(sql)
conn_out.commit()

# Helper to insert and get id for unique text lookup tables
def get_or_create_lookup(table, id_col, name_col, name_val):
    if not name_val:
        return None
    name_val = name_val.strip()
    cur_out.execute(f"SELECT {id_col} FROM {table} WHERE {name_col} = ?", (name_val,))
    row = cur_out.fetchone()
    if row:
        return row[0]
    cur_out.execute(f"INSERT INTO {table} ({name_col}) VALUES (?)", (name_val,))
    conn_out.commit()
    return cur_out.lastrowid

# Helper to get lookup name by ID from source database
def get_source_lookup_name(conn_src, table, id_col, name_col, src_id):
    if src_id is None:
        return None
    c = conn_src.cursor()
    c.execute(f"SELECT {name_col} FROM {table} WHERE {id_col} = ?", (src_id,))
    row = c.fetchone()
    return row[0] if row else None

# Seed initial lookups in output database (same as flutter _seedData)
def seed_lookups():
    # Admin User
    cur_out.execute("INSERT OR IGNORE INTO users (pass_id, user_name, pass_word) VALUES (1, 'admin', '1234')")
    
    icon_list = [
      'إدراج أسر', 'مناطق وشوارع', 'آباء كهنة', 'مناسبات',
      'بحث', 'أعياد ميلاد', 'صلاحيات', 'حساب مساعدات',
      'تقرير اخوة الرب', 'خدمات', 'مصروفات', 'بحث مصروفات',
      'إدارة القوائم', 'طباعة كارنيه', 'صيانة النظام', 'الافتقاد', 'ترحيل المراحل'
    ]
    for ic in icon_list:
        cur_out.execute("INSERT OR IGNORE INTO icon (icon_name) VALUES (?)", (ic,))
    
    cur_out.execute("SELECT icon_id, icon_name FROM icon")
    icons = cur_out.fetchall()
    for icon_id, icon_name in icons:
        cur_out.execute("INSERT OR IGNORE INTO inter_icon (pass_id, icon_id, icon_name, check_1) VALUES (1, ?, ?, 1)", (icon_id, icon_name))
        
    conn_out.commit()

seed_lookups()

# We will merge data from both databases
sources = [
    {"name": "Salamona", "path": db_salamona},
    {"name": "Kawsar", "path": db_kawsar}
]

# Unify area names:
# Area 10 -> "السلاموني"
# Area 11 -> "الكوثر"
# We insert them manually to ensure they are clean
cur_out.execute("INSERT OR IGNORE INTO areas (area_id, area_name) VALUES (1, 'السلاموني')")
cur_out.execute("INSERT OR IGNORE INTO areas (area_id, area_name) VALUES (2, 'الكوثر')")
conn_out.commit()

# ID mappings: (source_name, old_id) -> new_id
area_map = {
    ("Salamona", 10): 1, # السلامونى -> السلاموني
    ("Salamona", 11): 2, # الكوثر -> الكوثر
    ("Kawsar", 10): 1,   # س -> السلاموني
    ("Kawsar", 11): 2    # الكوثر -> الكوثر
}

street_map = {}
father_map = {}
osra_map = {}
person_map = {}

# Keep track of duplicate streets
# (new_area_id, street_name) -> new_street_id
street_cache = {}

for src in sources:
    print(f"\nProcessing database: {src['name']}")
    if not os.path.exists(src['path']):
        print(f"Skipping {src['name']} - file not found")
        continue
        
    conn_src = sqlite3.connect(src['path'])
    cur_src = conn_src.cursor()
    
    # 1. Map Streets
    cur_src.execute("SELECT street_id, street_name, area_id FROM streets")
    for old_sid, sname, old_aid in cur_src.fetchall():
        sname = sname.strip()
        # Get unified area ID
        new_aid = area_map.get((src['name'], old_aid))
        if not new_aid:
            # Fallback if there is an unexpected area
            area_name = get_source_lookup_name(conn_src, "areas", "area_id", "area_name", old_aid)
            new_aid = get_or_create_lookup("areas", "area_id", "area_name", area_name)
            
        cache_key = (new_aid, sname)
        if cache_key in street_cache:
            street_map[(src['name'], old_sid)] = street_cache[cache_key]
        else:
            cur_out.execute("INSERT INTO streets (street_name, area_id) VALUES (?, ?)", (sname, new_aid))
            new_sid = cur_out.lastrowid
            street_cache[cache_key] = new_sid
            street_map[(src['name'], old_sid)] = new_sid
            
    # 2. Map Fathers
    cur_src.execute("SELECT father_id, father_name, father_mobile, birth_date FROM fathers")
    for old_fid, fname, fmobile, fbirth in cur_src.fetchall():
        fname = fname.strip()
        cur_out.execute("SELECT father_id FROM fathers WHERE father_name = ?", (fname,))
        row = cur_out.fetchone()
        if row:
            father_map[(src['name'], old_fid)] = row[0]
        else:
            cur_out.execute("INSERT INTO fathers (father_name, father_mobile, birth_date) VALUES (?, ?, ?)", 
                            (fname, fmobile, fbirth))
            new_fid = cur_out.lastrowid
            father_map[(src['name'], old_fid)] = new_fid
            
    # 3. Map Osra (Families)
    # Get all columns of osra table in source database
    cur_src.execute("PRAGMA table_info(osra)")
    cols = [col[1] for col in cur_src.fetchall()]
    
    cur_src.execute("SELECT * FROM osra")
    for row in cur_src.fetchall():
        osra_row = dict(zip(cols, row))
        old_oid = osra_row['osra_id']
        
        # Get lookup names from source and translate to new IDs
        # Karaba
        k_name = get_source_lookup_name(conn_src, "karaba", "karaba_id", "karaba_name", osra_row.get('karaba_id'))
        new_kid = get_or_create_lookup("karaba", "karaba_id", "karaba_name", k_name)
        
        # E_S (economic status)
        es_name = get_source_lookup_name(conn_src, "e_s", "e_s_id", "e_s_name", osra_row.get('e_s_id'))
        new_esid = get_or_create_lookup("e_s", "e_s_id", "e_s_name", es_name)
        
        # Area & Street
        new_aid = area_map.get((src['name'], osra_row.get('area_id')))
        new_sid = street_map.get((src['name'], osra_row.get('street_id')))
        
        # Social Status
        hala_name = get_source_lookup_name(conn_src, "hala_egtimaia", "hala_egtimaia_id", "hala_name", osra_row.get('hala_egtimaia_id'))
        new_halaid = get_or_create_lookup("hala_egtimaia", "hala_egtimaia_id", "hala_name", hala_name)
        
        # Health Status (if exists)
        health_name = get_source_lookup_name(conn_src, "hala_sehia", "hala_sehia_id", "hala_name", osra_row.get('hala_sehia_id'))
        new_healthid = get_or_create_lookup("hala_sehia", "hala_sehia_id", "hala_name", health_name)
        
        # Education Level (if exists)
        mostwa_name = get_source_lookup_name(conn_src, "mostwa", "mostwa_id", "mostwa_name", osra_row.get('mostwa_id'))
        new_mostwaid = get_or_create_lookup("mostwa", "mostwa_id", "mostwa_name", mostwa_name)
        
        # Insert unified osra
        cur_out.execute('''
            INSERT INTO osra (
                osra_name, karaba_id, e_s_id, area_id, street_id, dalil_name, 
                emara, door, shaka, r_o, phone, number, hala_egtimaia_id, 
                rakm_komy, code, hala_sehia_id, mostwa_id
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', (
            osra_row['osra_name'], new_kid, new_esid, new_aid, new_sid, osra_row.get('dalil_name'),
            osra_row.get('emara'), osra_row.get('door'), osra_row.get('shaka'), osra_row.get('r_o'),
            osra_row.get('phone'), osra_row.get('number', 0), new_halaid, 
            osra_row.get('rakm_komy'), osra_row.get('code'), new_healthid, new_mostwaid
        ))
        new_oid = cur_out.lastrowid
        osra_map[(src['name'], old_oid)] = new_oid

    # 4. Map Person (Individuals)
    cur_src.execute("PRAGMA table_info(person)")
    p_cols = [col[1] for col in cur_src.fetchall()]
    
    cur_src.execute("SELECT * FROM person")
    for row in cur_src.fetchall():
        p_row = dict(zip(p_cols, row))
        old_pid = p_row['person_id']
        
        # Translate lookups
        k_name = get_source_lookup_name(conn_src, "karaba", "karaba_id", "karaba_name", p_row.get('karaba_id'))
        new_kid = get_or_create_lookup("karaba", "karaba_id", "karaba_name", k_name)
        
        mostwa_name = get_source_lookup_name(conn_src, "mostwa", "mostwa_id", "mostwa_name", p_row.get('mostwa_id'))
        new_mostwaid = get_or_create_lookup("mostwa", "mostwa_id", "mostwa_name", mostwa_name)
        
        hala_name = get_source_lookup_name(conn_src, "hala_egtimaia", "hala_egtimaia_id", "hala_name", p_row.get('hala_egtimaia_id'))
        new_halaid = get_or_create_lookup("hala_egtimaia", "hala_egtimaia_id", "hala_name", hala_name)
        
        health_name = get_source_lookup_name(conn_src, "hala_sehia", "hala_sehia_id", "hala_name", p_row.get('hala_sehia_id'))
        new_healthid = get_or_create_lookup("hala_sehia", "hala_sehia_id", "hala_name", health_name)
        
        stage_name = get_source_lookup_name(conn_src, "stage", "stage_id", "stage_name", p_row.get('stage_id'))
        new_stageid = get_or_create_lookup("stage", "stage_id", "stage_name", stage_name)
        
        new_fid = father_map.get((src['name'], p_row.get('father_id')))
        new_oid = osra_map.get((src['name'], p_row['osra_id']))
        
        if not new_oid:
            print(f"Warning: Person {p_row['person_name']} has missing osra_id {p_row['osra_id']}")
            continue
            
        cur_out.execute('''
            INSERT INTO person (
                person_name, osra_id, karaba_id, birth_date, mostwa_id, moahil, 
                date_moiahil, hala_egtimaia_id, hala_sehia_id, wazefa, place_work, 
                mobile, facebook, father, stage_id, father_id, month, age, rakm_komy
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', (
            p_row['person_name'], new_oid, new_kid, p_row.get('birth_date'), new_mostwaid, p_row.get('moahil'),
            p_row.get('date_moiahil'), new_halaid, new_healthid, p_row.get('wazefa'), p_row.get('place_work'),
            p_row.get('mobile'), p_row.get('facebook'), p_row.get('father'), new_stageid, new_fid,
            p_row.get('month'), p_row.get('age'), p_row.get('rakm_komy')
        ))
        new_pid = cur_out.lastrowid
        person_map[(src['name'], old_pid)] = new_pid

    # 5. Map eatraf
    cur_src.execute("SELECT person_id, date, notes FROM eatraf")
    for old_pid, date, notes in cur_src.fetchall():
        new_pid = person_map.get((src['name'], old_pid))
        if new_pid:
            cur_out.execute("INSERT INTO eatraf (person_id, date, notes) VALUES (?, ?, ?)", (new_pid, date, notes))

    # 6. Map visits (الافتقاد)
    cur_src.execute("SELECT osra_id, date, notes FROM visits")
    for old_oid, date, notes in cur_src.fetchall():
        new_oid = osra_map.get((src['name'], old_oid))
        if new_oid:
            cur_out.execute("INSERT INTO visits (osra_id, date, notes) VALUES (?, ?, ?)", (new_oid, date, notes))

    # 7. Map monasba
    cur_src.execute("SELECT osra_id, monasba_name, monasba_date, month FROM monasba")
    for old_oid, name, date, month in cur_src.fetchall():
        new_oid = osra_map.get((src['name'], old_oid))
        if new_oid:
            cur_out.execute("INSERT INTO monasba (osra_id, monasba_name, monasba_date, month) VALUES (?, ?, ?, ?)", 
                            (new_oid, name, date, month))

    # 8. Map count_aid (fixed aid)
    cur_src.execute("SELECT osra_id, khdma_id, count_value, aynee, notes FROM count_aid")
    for old_oid, old_khdmaid, val, aynee, notes in cur_src.fetchall():
        new_oid = osra_map.get((src['name'], old_oid))
        khdma_name = get_source_lookup_name(conn_src, "khdma", "khdma_id", "khdma_name", old_khdmaid)
        new_khdmaid = get_or_create_lookup("khdma", "khdma_id", "khdma_name", khdma_name)
        if new_oid:
            cur_out.execute("INSERT INTO count_aid (osra_id, khdma_id, count_value, aynee, notes) VALUES (?, ?, ?, ?, ?)", 
                            (new_oid, new_khdmaid, val, aynee, notes))

    # 9. Map count_2 (variable aid)
    cur_src.execute("SELECT osra_id, type, count_add, notes, date_1 FROM count_2")
    for old_oid, type_val, add_val, notes, date1 in cur_src.fetchall():
        new_oid = osra_map.get((src['name'], old_oid))
        if new_oid:
            cur_out.execute("INSERT INTO count_2 (osra_id, type, count_add, notes, date_1) VALUES (?, ?, ?, ?, ?)", 
                            (new_oid, type_val, add_val, notes, date1))

    # 10. Map masrofat
    cur_src.execute("SELECT osra_id, masrof, count_value, aynee, notes FROM masrofat")
    for old_oid, masrof, val, aynee, notes in cur_src.fetchall():
        new_oid = osra_map.get((src['name'], old_oid))
        if new_oid:
            cur_out.execute("INSERT INTO masrofat (osra_id, masrof, count_value, aynee, notes) VALUES (?, ?, ?, ?, ?)", 
                            (new_oid, masrof, val, aynee, notes))
                            
    conn_src.close()
    print(f"Finished database: {src['name']}")

conn_out.commit()

# Print statistics of unified database
print("\n=== Statistics of Merged Database ===")
for table in ['areas', 'streets', 'karaba', 'mostwa', 'hala_egtimaia', 'hala_sehia', 'e_s', 'stage', 'fathers', 'khdma', 'osra', 'person', 'eatraf', 'visits', 'monasba', 'count_aid', 'count_2', 'masrofat']:
    cur_out.execute(f"SELECT COUNT(*) FROM [{table}]")
    print(f"Table: {table}, rows: {cur_out.fetchone()[0]}")
    
conn_out.close()
print("\nDatabase merge complete! Output saved to:", db_out)
