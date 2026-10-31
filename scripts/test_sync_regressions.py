"""Temporary PostgreSQL regressions; never connects to the installed app data."""
import json
import os
from pathlib import Path
import socket
import subprocess
import tempfile
import time
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
PG = Path('E:/AbonaFlemoon/Server/postgresql/bin')
TEMP = Path(tempfile.mkdtemp(prefix='membership-sync-test-'))
HIDDEN = subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0


def run(args):
    return subprocess.run([str(a) for a in args], check=True,
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        creationflags=HIDDEN, timeout=90)


def free_port():
    with socket.socket() as sock:
        sock.bind(('127.0.0.1', 0))
        return sock.getsockname()[1]


def main():
    pg_port, api_port = free_port(), free_port()
    base = f'http://127.0.0.1:{api_port}'
    backend = None
    started = False
    seed = TEMP / 'old-client.db'
    seed.write_bytes(b'incompatible old client database')

    def request(path, payload=None):
        req = urllib.request.Request(base + path,
            data=json.dumps(payload).encode() if payload is not None else None,
            headers={'Content-Type': 'application/json'})
        with urllib.request.urlopen(req, timeout=10) as response:
            return json.load(response)

    def execute(sql, values=(), endpoint='execute'):
        return request('/api/storage/' + endpoint, {'sql': sql, 'params': [
            {'type': 'int' if isinstance(v, int) else 'string', 'value': v} for v in values]})

    try:
        run([PG/'initdb.exe', '-D', TEMP/'data', '-U', 'postgres', '-A', 'trust', '--no-locale', '-E', 'UTF8'])
        run([PG/'pg_ctl.exe', '-D', TEMP/'data', '-l', TEMP/'postgres.log',
             '-o', f'-h 127.0.0.1 -p {pg_port}', '-w', 'start'])
        started = True
        env = dict(os.environ, PORT=str(api_port), BindLocalOnly='true',
            ConnectionStrings__Postgres=f'Host=127.0.0.1;Port={pg_port};Database=membership_sync_test;Username=postgres',
            SqliteSeed__InitialDbPath=str(seed))
        with open(TEMP/'backend.log', 'wb') as log:
            backend = subprocess.Popen(['dotnet', str(ROOT/'AbonaFlemoon.SyncServer/bin/Release/net8.0/ChurchMembership.SyncServer.dll')],
                cwd=TEMP, env=env, stdout=log, stderr=log, creationflags=HIDDEN)
        for _ in range(100):
            try:
                if request('/api/auth/ping')['status'] == 'ok':
                    break
            except OSError:
                time.sleep(.25)
        else:
            raise AssertionError('isolated membership backend did not start')

        assert seed.read_bytes() == b'incompatible old client database'
        assert execute('SELECT COUNT(*) AS n FROM users', endpoint='query')['rows'][0]['n'] == 1
        assert execute('SELECT COUNT(*) AS n FROM osra', endpoint='query')['rows'][0]['n'] == 0
        family = execute('INSERT INTO osra (osra_name) VALUES (?)', ["Fixture O'Family"], 'insert')['lastInsertRowId']
        execute('INSERT INTO person (person_name, osra_id) VALUES (?, ?)', ['Fixture member', family], 'insert')
        members = execute('SELECT * FROM person WHERE osra_id = ?', [family], 'query')['rows']
        assert len(members) == 1 and members[0]['osra_id'] == family
        changed = execute('UPDATE person SET person_name = ? WHERE osra_id = ?', ['Updated member', family])
        assert changed['rowsAffected'] == 1 if 'rowsAffected' in changed else changed['affectedRows'] == 1
        rows = execute('SELECT o.*, COUNT(p.person_id) AS member_count FROM osra o LEFT JOIN person p ON o.osra_id = p.osra_id GROUP BY o.osra_id', endpoint='query')['rows']
        assert rows[0]['member_count'] == 1
        print(json.dumps({'passed': True, 'checks': ['empty host defaults', 'old client file preserved', 'custom port', 'families', 'members', 'update'], 'logs': str(TEMP)}))
    finally:
        if backend:
            backend.terminate()
            backend.wait(timeout=20)
        if started:
            run([PG/'pg_ctl.exe', '-D', TEMP/'data', '-m', 'fast', '-w', 'stop'])


if __name__ == '__main__':
    main()
