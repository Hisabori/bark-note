import urllib.request, re
url = 'https://www.data.go.kr/js/biz/datset/script_fileDetail.js'
text = urllib.request.urlopen(url, timeout=25).read().decode('utf-8')
start = text.find('fn_fileDataDown :')
if start < 0: start = text.find('fn_fileDataDown:')
if start < 0: start = text.find('fn_fileDataDown')
print(text[start:start+13000])
