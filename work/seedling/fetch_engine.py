import urllib.request,json,hashlib,tarfile,pathlib
root=pathlib.Path(__file__).resolve().parent/'engine'
for name in ['transmission-cli','libpsl','miniupnpc']:
 data=json.load(urllib.request.urlopen('https://formulae.brew.sh/api/formula/'+name+'.json'))
 bottles=data['bottle']['stable']['files']
 key=next(x for x in ['arm64_sequoia','arm64_tahoe','arm64_golden_gate'] if x in bottles)
 b=bottles[key]
 token=json.load(urllib.request.urlopen('https://ghcr.io/token?service=ghcr.io&scope=repository:homebrew/core/'+name+':pull'))['token']
 req=urllib.request.Request(b['url'],headers={'Authorization':'Bearer '+token})
 raw=urllib.request.urlopen(req).read()
 assert hashlib.sha256(raw).hexdigest()==b['sha256']
 archive=root/(name+'.tar.gz'); archive.write_bytes(raw)
 with tarfile.open(archive) as t:t.extractall(root/name,filter='data')
 print(name,data['versions']['stable'],'checksum verified')
