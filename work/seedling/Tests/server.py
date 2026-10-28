from http.server import ThreadingHTTPServer,BaseHTTPRequestHandler
from pathlib import Path
import re
root=Path(__file__).resolve().parent.parent/'test-data/web'
class Handler(BaseHTTPRequestHandler):
 def do_GET(self):
  path=root/Path(self.path).name
  if not path.is_file():self.send_error(404);return
  data=path.read_bytes();start=0;end=len(data)-1
  match=re.match(r'bytes=(\d+)-(\d*)',self.headers.get('Range',''))
  if match:
   start=int(match[1]);end=min(int(match[2]) if match[2] else end,end)
   self.send_response(206);self.send_header('Content-Range',f'bytes {start}-{end}/{len(data)}')
  else:self.send_response(200)
  self.send_header('Accept-Ranges','bytes');self.send_header('Content-Length',str(end-start+1));self.end_headers()
  try:self.wfile.write(data[start:end+1])
  except BrokenPipeError:pass
 def log_message(self,*args):pass
ThreadingHTTPServer(('127.0.0.1',8876),Handler).serve_forever()
