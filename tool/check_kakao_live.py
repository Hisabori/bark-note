import json, os, urllib.request, urllib.parse, urllib.error

def get(path, query):
    url = 'https://dapi.kakao.com' + path + '?' + urllib.parse.urlencode(query)
    req = urllib.request.Request(url, headers={'Authorization': 'KakaoAK ' + os.environ['KAKAO_KEY']})
    with urllib.request.urlopen(req, timeout=15) as response:
        return json.load(response)

try:
    places = get('/v2/local/search/keyword.json', {'query': '서울역', 'size': '1'})
    assert places.get('documents'), 'No place results'
    print('Kakao place API: authenticated, results present')
    routes = get('/v2/routing/publictraffic', {'start_x': '126.972', 'start_y': '37.555', 'end_x': '127.027', 'end_y': '37.498'})
    print('Kakao route API status:', routes.get('status'), 'routes:', len(routes.get('routes', [])))
    assert routes.get('status') == 'OK'
except urllib.error.HTTPError as error:
    print('Kakao live verification: HTTP', error.code)
    raise SystemExit(1)
except Exception as error:
    print('Kakao live verification failed:', type(error).__name__)
    raise SystemExit(1)
