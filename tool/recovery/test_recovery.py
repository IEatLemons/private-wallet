#!/usr/bin/env python3
"""CLI integration checks using only public BIP39 fixtures."""
import json
import os
from pathlib import Path
import resource
import signal
import stat
import subprocess
import sys
import tempfile
import time

BINARY = str(Path(sys.argv[1]).resolve())
PHRASE = 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about'
OTHER = 'test test test test test test test test test test test junk'
STANDARD = '0x9858effd232b4033e47d90003d41ec34ecaeda94'
LEGACY = 'TNNrLX8qUY6pYY29Wyh7bWCLZnuic39qjr'
UNMATCHED = '0xe4079dbbc13d661736562ad156c90dce0fa4f705'

with tempfile.TemporaryDirectory(prefix='asterkeel-recovery-tests-') as name:
    root = Path(name)
    config = root / 'input.env'
    config.write_text(f'COLLECT_MNEMONIC="{PHRASE}"\nIGNORED="must-not-appear"\n')
    config.chmod(0o600)

    def command(state, *args):
        return [BINARY, '--config', str(config), '--state-dir', str(root / state),
                '--target', UNMATCHED, '--index', '0', '--cpu-percent', '25', *args]

    def run(state, *args, expected=0):
        p = subprocess.run(command(state, *args), capture_output=True, text=True, timeout=30)
        assert p.returncode == expected, (p.returncode, p.stdout, p.stderr)
        assert PHRASE not in p.stdout + p.stderr
        assert 'must-not-appear' not in p.stdout + p.stderr
        return p

    def checkpoint(state):
        return json.loads((root / state / 'checkpoint.json').read_text())

    run('standard', '--target', STANDARD, '--account-max', '0')
    state = checkpoint('standard')
    assert state['status'] == 'standard_address_match'
    match = state['last_match']
    secret = Path(match['private_result_file'])
    value = json.loads(secret.read_text())
    assert len(value['derived_private_key']) == 64
    assert value['standard_address_matches_target'] is True
    assert stat.S_IMODE(secret.stat().st_mode) == 0o600
    assert stat.S_IMODE(secret.parent.stat().st_mode) == 0o700
    assert value['derived_private_key'] not in (root / 'standard' / 'checkpoint.json').read_text()
    run('standard', '--target', STANDARD, '--account-max', '0')
    original_secret = secret.read_text()
    damaged = json.loads(original_secret)
    damaged['derived_private_key'] = '00' * 32
    secret.write_text(json.dumps(damaged))
    run('standard', '--target', STANDARD, '--account-max', '0', expected=2)
    assert json.loads(secret.read_text())['derived_private_key'] == '00' * 32
    secret.write_text(original_secret)
    print('PASS standard match stops, re-verifies cached keys and saves private result without secret logs')

    run('legacy', '--target', LEGACY, '--account-max', '0', expected=3)
    state = checkpoint('legacy')
    assert state['status'] == 'legacy_hash_match_only'
    assert state['last_match']['standard_address_matches_target'] is False
    assert state['last_match']['standard_evm'] == STANDARD
    print('PASS legacy match is never labelled as a controlling key')

    run('legacy-continue', '--target', LEGACY, '--account-max', '0', '--stop-on', 'standard', expected=4)
    state = checkpoint('legacy-continue')
    assert state['status'] == 'range_exhausted'
    assert state['legacy_matches'] == 1
    print('PASS standard-only mode continues after a legacy match')

    run('resume', '--limit', '5')
    assert checkpoint('resume')['next_cursor'] == 5
    run('resume', '--limit', '7', '--cpu-percent', '10')
    assert checkpoint('resume')['next_cursor'] == 12
    assert checkpoint('resume')['candidates_checked'] == 12
    before = (root / 'resume' / 'checkpoint.json').read_bytes()
    config.write_text(f'COLLECT_MNEMONIC="{OTHER}"\n')
    run('resume', '--limit', '1', expected=2)
    assert (root / 'resume' / 'checkpoint.json').read_bytes() == before
    config.write_text(f'COLLECT_MNEMONIC="{PHRASE}"\n')
    print('PASS resume keeps exact cursor and rejects a different seed')

    (root / 'corrupt').mkdir()
    (root / 'corrupt' / 'checkpoint.json').write_text('broken')
    run('corrupt', '--limit', '1', expected=2)
    assert (root / 'corrupt' / 'checkpoint.json').read_text() == 'broken'
    print('PASS corrupt checkpoints are not silently overwritten')

    run('memory', '--max-rss-mb', '1', expected=5)
    assert not (root / 'memory' / 'checkpoint.json').exists()
    print('PASS memory ceiling stops before loading the seed')

    p = subprocess.Popen(command('signals', '--cpu-percent', '10'), stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    try:
        deadline = time.monotonic() + 15
        while not (root / 'signals' / 'checkpoint.json').exists():
            assert p.poll() is None
            assert time.monotonic() < deadline
            time.sleep(0.05)
        run('signals', '--limit', '1', expected=2)
        time.sleep(0.4)
        p.send_signal(signal.SIGINT)
        out, err = p.communicate(timeout=5)
        assert p.returncode == 0 and PHRASE not in out + err
        state = checkpoint('signals')
        assert state['status'] == 'paused' and state['reason'] == 'interrupted'
        cursor = state['next_cursor']
        assert cursor > 0
        run('signals', '--limit', '3')
        assert checkpoint('signals')['next_cursor'] == cursor + 3
    finally:
        if p.poll() is None:
            p.kill()
            p.wait()
    print('PASS single-instance locking, Ctrl+C save and restart')

    before = resource.getrusage(resource.RUSAGE_CHILDREN)
    started = time.monotonic()
    run('load', '--limit', '200')
    elapsed = time.monotonic() - started
    after = resource.getrusage(resource.RUSAGE_CHILDREN)
    cpu = after.ru_utime + after.ru_stime - before.ru_utime - before.ru_stime
    state = checkpoint('load')
    duty = state['session_active_microseconds'] / max(1, state['session_active_microseconds'] + state['session_sleep_microseconds'])
    assert duty <= 0.251
    assert cpu / elapsed < 0.60, (cpu, elapsed)
    assert state['rss_bytes'] < 256 * 1024 * 1024
    print(f'PASS measured load: CPU/wall={cpu/elapsed:.2f} of one core; RSS={state["rss_bytes"]/1048576:.1f} MiB')
print('All offline recovery integration checks passed.')
