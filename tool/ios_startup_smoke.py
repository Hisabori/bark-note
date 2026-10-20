"""Launch the real simulator app twice and require a Flutter first frame."""
import json
import os
from pathlib import Path
import re
import subprocess
import time


def run(*args, check=True):
    return subprocess.run(args, check=check, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT).stdout.strip()


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
        run('xcrun', 'simctl', 'io', udid, 'screenshot', str(out / f'launch-{attempt}.png'))
        print(f'Launch {attempt}: first frame rendered; process still alive after 10 seconds', flush=True)
finally:
    (out / 'device.log').write_text(run('xcrun', 'simctl', 'spawn', udid, 'log', 'show', '--last', '3m', '--style', 'compact', '--predicate', 'process == "Runner"', check=False))
