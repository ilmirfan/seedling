from pathlib import Path
import hashlib
root=Path(__file__).resolve().parent.parent/'test-data'
web=root/'web';fixture=root/'fixtures';web.mkdir(parents=True,exist_ok=True);fixture.mkdir(parents=True,exist_ok=True)
def b(x):
 if isinstance(x,int):return b'i'+str(x).encode()+b'e'
 if isinstance(x,bytes):return str(len(x)).encode()+b':'+x
 if isinstance(x,str):return b(x.encode())
 if isinstance(x,list):return b'l'+b''.join(b(y) for y in x)+b'e'
 return b'd'+b''.join(b(k)+b(v) for k,v in sorted(x.items()))+b'e'
for name in ['Seedling-Test-Film.mp4','Seedling-Test-Document.txt']:
 data=(b'Seedling local integration fixture. No external peers.\n'*14000)[:512000]
 (web/name).write_bytes(data)
 pieces=b''.join(hashlib.sha1(data[i:i+16384]).digest() for i in range(0,len(data),16384))
 torrent={'info':{'length':len(data),'name':name,'piece length':16384,'pieces':pieces},'url-list':['http://127.0.0.1:8876/'+name]}
 (fixture/(name+'.torrent')).write_bytes(b(torrent))
print('Prepared local-only fixtures')
