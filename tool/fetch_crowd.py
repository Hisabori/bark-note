import urllib.request, urllib.parse, json
base='https://www.data.go.kr'
q={'publicDataPk':'15071311','publicDataDetailPk':'uddi:ec6e85c3-f01a-415d-8705-e20650f1be84','atchFileId':'','fileDetailSn':'1','publicDataTyCode':'PR0051'}
raw=urllib.request.urlopen(base+'/tcs/dss/selectFileDataDownload.do?'+urllib.parse.urlencode(q),timeout=25).read().decode()
print('METADATA',raw)
text=urllib.request.urlopen(base+'/js/biz/cmm/cmm/script_cmmFunction.js',timeout=25).read().decode('utf-8')
i=text.find('function fn_fileDataDownload')
print(text[i:i+6500])

