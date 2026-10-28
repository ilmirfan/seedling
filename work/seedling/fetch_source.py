import urllib.request,hashlib,pathlib,json
root=pathlib.Path(__file__).resolve().parent
info=json.load(urllib.request.urlopen('https://formulae.brew.sh/api/formula/transmission-cli.json'))
source=info['urls']['stable'];p=root/'engine'/('transmission-'+info['versions']['stable']+'.tar.xz')
if not p.exists():p.write_bytes(urllib.request.urlopen(source['url']).read())
assert hashlib.sha256(p.read_bytes()).hexdigest()==source['checksum']
(root/'engine/UPSTREAM.json').write_text(json.dumps({'transmission':info,'source_sha256':source['checksum']},indent=2))
print('Corresponding Transmission source archived and checksum verified')
