"""Exercise rebranding, migrations, backup and Dart repositories on isolated PostgreSQL."""
import json
import os
from pathlib import Path
import socket
import sqlite3
import subprocess
import tempfile
import time
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
PG = Path('E:/AbonaFlemoon/Server/postgresql/bin')
BACKEND = ROOT / 'build/membership_checks/backend/ChurchMembership.SyncServer.dll'
TEMP = Path(tempfile.mkdtemp(prefix='church-membership-regressions-'))
HIDDEN = subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0


def free_port():
    with socket.socket() as sock:
        sock.bind(('127.0.0.1', 0))
        return sock.getsockname()[1]


def main():
    pg_port, api_port = free_port(), free_port()
    base = f'http://127.0.0.1:{api_port}'
    backend = None
    started = False
    log = None

    def run(args):
        return subprocess.run([str(a) for a in args], check=True, creationflags=HIDDEN,
                              stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=90)

    def request(path, payload=None):
        req = urllib.request.Request(base + path,
            data=json.dumps(payload).encode() if payload is not None else None,
            headers={'Content-Type': 'application/json'})
        with urllib.request.urlopen(req, timeout=15) as response:
            return json.load(response)

    def execute(sql, values=(), endpoint='execute'):
        return request('/api/storage/' + endpoint, {'sql': sql, 'params': [
            {'type': 'int' if isinstance(v, int) else 'string', 'value': v} for v in values]})

    def start(database):
        nonlocal backend, log
        env = dict(os.environ, PORT=str(api_port), BindLocalOnly='true',
            ConnectionStrings__Postgres=f'Host=127.0.0.1;Port={pg_port};Database={database};Username=postgres',
            SqliteSeed__InitialDbPath=str(TEMP / 'absent.db'))
        log = open(TEMP / (database + '.log'), 'wb')
        backend = subprocess.Popen(['dotnet', str(BACKEND)], cwd=TEMP, env=env,
            stdout=log, stderr=log, creationflags=HIDDEN)
        for _ in range(120):
            if backend.poll() is not None:
                raise AssertionError(f'Backend exited; see {TEMP}')
            try:
                if request('/api/auth/ping')['status'] == 'ok':
                    return
            except OSError:
                time.sleep(.25)
        raise AssertionError('Backend did not become ready')

    def stop():
        nonlocal backend, log
        if backend:
            backend.terminate()
            backend.wait(timeout=20)
            backend = None
        if log:
            log.close()
            log = None

    try:
        run([PG / 'initdb.exe', '-D', TEMP / 'data', '-U', 'postgres', '-A', 'trust', '--no-locale', '-E', 'UTF8'])
        run([PG / 'pg_ctl.exe', '-D', TEMP / 'data', '-l', TEMP / 'postgres.log',
             '-o', f'-h 127.0.0.1 -p {pg_port}', '-w', 'start'])
        started = True
        start('abona_flemoon')
        family = execute('INSERT INTO osra (osra_name) VALUES (?)', ['أسرة اختبار'], 'insert')['lastInsertRowId']
        execute('INSERT INTO osra (osra_name) VALUES (?)', ['أسرة فارغة'], 'insert')
        execute('INSERT INTO person (person_name, osra_id, rakm_komy) VALUES (?, ?, ?)',
                ['مَارِيَا', family, '30405292601088'], 'insert')
        execute('INSERT INTO count_aid (osra_id, count_value, notes) VALUES (?, ?, ?)', [family, 80, 'ثابتة'], 'insert')
        execute('INSERT INTO count_2 (osra_id, count_add, notes) VALUES (?, ?, ?)', [family, 20, 'متغيرة'], 'insert')
        execute('INSERT INTO masrofat (osra_id, count_value, masrof) VALUES (?, ?, ?)', [family, 10, 'مصروف'], 'insert')
        execute('UPDATE icon SET icon_name = ? WHERE icon_name = ?', ['تقرير اخوة الرب', 'تقرير العضوية الكنسية'])
        execute('UPDATE inter_icon SET icon_name = ? WHERE icon_name = ?', ['تقرير اخوة الرب', 'تقرير العضوية الكنسية'])
        # Reproduce the old schema to exercise additive upgrades as well as renaming.
        for table, columns in {'osra': ['gender', 'governorate', 'age', 'birth_date'], 'person': ['gender', 'governorate']}.items():
            for column in columns:
                execute(f'ALTER TABLE {table} DROP COLUMN {column}')
        stop()
        start('church_membership')
        assert len(execute('SELECT * FROM osra', endpoint='query')['rows']) == 2
        assert len(execute('SELECT * FROM person', endpoint='query')['rows']) == 1
        assert len(execute('SELECT * FROM icon WHERE icon_name = ?', ['تقرير العضوية الكنسية'], 'query')['rows']) == 1
        assert not execute('SELECT * FROM icon WHERE icon_name = ?', ['تقرير اخوة الرب'], 'query')['rows']
        assert execute('SELECT * FROM inter_icon WHERE icon_name = ?', ['تقرير العضوية الكنسية'], 'query')['rows']
        print('PASS: database rename preserves families, members, aid, expenses and permissions', flush=True)

        flutter = Path('C:/Users/Graphic/flutter/bin/flutter.bat')
        subprocess.run([str(flutter), 'test', '--no-pub',
            f'--dart-define=MEMBERSHIP_TEST_URL={base}', 'test/membership_remote_test.dart'],
            cwd=ROOT, check=True, creationflags=HIDDEN, timeout=240)

        backup = TEMP / 'church_membership_backup.db'
        with urllib.request.urlopen(base + '/api/storage/sqlite/export', timeout=30) as response:
            backup.write_bytes(response.read())
        with sqlite3.connect(backup) as conn:
            assert conn.execute('PRAGMA user_version').fetchone()[0] == 11
            row = conn.execute('SELECT gender, governorate, birth_date FROM person WHERE person_name = ?', ('فرد يدوي',)).fetchone()
            assert row == ('ذكر', 'القاهرة', '1990-12-25')
            head = conn.execute('SELECT gender, governorate, birth_date FROM osra WHERE osra_name = ?', ('sdcsdcs',)).fetchone()
            assert head == ('ذكر', 'سوهاج', '2004-05-29')
            assert conn.execute('SELECT count(*) FROM count_aid').fetchone()[0] == 1
            assert conn.execute('SELECT count(*) FROM count_2').fetchone()[0] == 1
            assert conn.execute('SELECT count(*) FROM masrofat').fetchone()[0] == 1
        print(json.dumps({'passed': True, 'checks': ['legacy database migration', 'permissions', 'live Dart repositories', 'SQLite backup identity fields'], 'logs': str(TEMP)}), flush=True)
    finally:
        stop()
        if started:
            run([PG / 'pg_ctl.exe', '-D', TEMP / 'data', '-m', 'fast', '-w', 'stop'])


if __name__ == '__main__':
    main()
