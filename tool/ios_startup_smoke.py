"""Launch the real simulator app twice and require a Flutter first frame."""
import json
import base64
import os
from pathlib import Path
import re
import subprocess
import time


def run(*args, check=True):
    print('Running:', ' '.join(args[:4]), flush=True)
    result = subprocess.run(args, check=check, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=600).stdout.strip()
    return result


out = Path('build/startup-smoke')
out.mkdir(parents=True, exist_ok=True)
devices = json.loads(run('xcrun', 'simctl', 'list', 'devices', 'available', '--json'))['devices']
choices = [(runtime, d) for runtime, group in devices.items() for d in group if 'iOS' in runtime and d['name'].startswith('iPhone')]
assert choices, 'No available iPhone simulator'
runtime, device = sorted(choices, key=lambda item: tuple(map(int, re.findall(r'\d+', item[0]))), reverse=True)[0]
udid = device['udid']
print('Simulator:', runtime, device['name'], flush=True)
run('xcrun', 'simctl', 'boot', udid, check=False)
run('xcrun', 'simctl', 'bootstatus', udid, '-b')
bundle = 'com.barknote.barkNote'
run('xcrun', 'simctl', 'install', udid, 'build/ios/iphonesimulator/Runner.app')
container = Path(run('xcrun', 'simctl', 'get_app_container', udid, bundle, 'data'))
marker = container / 'Documents/startup-smoke-ready'
try:
    for attempt in (1, 2):
        run('xcrun', 'simctl', 'terminate', udid, bundle, check=False)
        marker.unlink(missing_ok=True)
        (container / 'Documents/glass-smoke-backend').unlink(missing_ok=True)
        launched = run('xcrun', 'simctl', 'launch', udid, bundle)
        print(launched, flush=True)
        pid = int(launched.rsplit(':', 1)[1].strip())
        for _ in range(45):
            os.kill(pid, 0)
            if marker.exists():
                break
            time.sleep(1)
        assert marker.exists(), 'Flutter did not render its first frame'
        assert marker.read_text() == 'first-frame-rendered'
        time.sleep(10)
        os.kill(pid, 0)
        material = (container / 'Documents/glass-smoke-backend').read_text()
        assert material in {'system-liquid-glass', 'blur-fallback', 'opaque-accessibility'}
        print('GLASS_BACKEND:' + material, flush=True)
        run('xcrun', 'simctl', 'io', udid, 'screenshot', str(out / f'launch-{attempt}.png'))
        print(f'Launch {attempt}: first frame rendered; process still alive after 10 seconds', flush=True)
    # Only the clean simulator home is transported here, without private keys.
    preview = out / 'home-preview.jpg'
    run('sips', '-s', 'format', 'jpeg', '-s', 'formatOptions', '70', '-Z', '960', str(out / 'launch-2.png'), '--out', str(preview))
    print('STARTUP_PREVIEW_BASE64:' + base64.b64encode(preview.read_bytes()).decode('ascii'), flush=True)
finally:
    run('xcrun', 'simctl', 'io', udid, 'screenshot', str(out / 'last-screen.png'), check=False)
    (out / 'device.log').write_text(run('xcrun', 'simctl', 'spawn', udid, 'log', 'show', '--last', '3m', '--style', 'compact', '--predicate', 'process == "Runner"', check=False))
