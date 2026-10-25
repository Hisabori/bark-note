"""Validate UIKit scene schema, not just XML/plist syntax."""
import plistlib
import sys
from pathlib import Path


def validate(data):
    scene = data['UIApplicationSceneManifest']
    configs = scene['UISceneConfigurations']
    assert set(configs) == {'UIWindowSceneSessionRoleApplication'}, 'Non-scene keys inside UISceneConfigurations'
    assert isinstance(configs['UIWindowSceneSessionRoleApplication'], list)
    entries = configs['UIWindowSceneSessionRoleApplication']
    assert len(entries) == 1
    assert entries[0]['UISceneDelegateClassName'].endswith('.SceneDelegate')
    assert entries[0]['UISceneStoryboardFile'] == 'Main'
    for node in (scene, configs, *entries):
        assert not {'NSAppTransportSecurity', 'NSMicrophoneUsageDescription', 'NSLocationWhenInUseUsageDescription', 'NSSupportsLiveActivities'} & node.keys(), 'App-only keys nested in scene metadata'
    assert data['NSLocationWhenInUseUsageDescription']
    assert 'location' not in data.get('UIBackgroundModes', [])
    assert 'NSLocationAlwaysAndWhenInUseUsageDescription' not in data
    assert data['NSMicrophoneUsageDescription']
    assert data['NSSupportsLiveActivities'] is True


if __name__ == '__main__':
    path = Path(sys.argv[1] if len(sys.argv) > 1 else 'ios/Runner/Info.plist')
    validate(plistlib.loads(path.read_bytes()))
    print('UIKit scene metadata schema verified')
