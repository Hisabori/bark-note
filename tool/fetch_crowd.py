import urllib.request, csv, io, json, pathlib, hashlib
url='https://www.data.go.kr/cmm/cmm/fileDownload.do?atchFileId=FILE_000000003682445&fileDetailSn=1'
data=urllib.request.urlopen(url,timeout=30).read()
text=None
for encoding in ['utf-8-sig','cp949']:
    try: text=data.decode(encoding); break
    except UnicodeDecodeError: pass
assert text and '<html' not in text[:200].lower(), 'Dataset download did not return CSV'
rows=list(csv.reader(io.StringIO(text)))
assert len(rows)>1000, len(rows)
print('CSV rows:',len(rows),'columns:',rows[0]); print('FIRST',rows[1][:8])
out=pathlib.Path('crowd-artifact');out.mkdir(exist_ok=True)
(out/'crowd-original.csv').write_bytes(data)
(out/'crowd.json').write_text(json.dumps({'source':'https://www.data.go.kr/data/15071311/fileData.do','asOf':'2026-06-30','sha256':hashlib.sha256(data).hexdigest(),'headers':rows[0],'rows':rows[1:]},ensure_ascii=False,separators=(',',':')),encoding='utf-8')
