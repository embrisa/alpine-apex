"""Local-only static review server; no uploads or gameplay endpoints."""
import argparse,json
from functools import partial
from http.server import SimpleHTTPRequestHandler,ThreadingHTTPServer
from pathlib import Path

class Handler(SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path=='/__pose_review_health':
            payload=json.dumps({'service':'alpine-pose-review','version':1,'directory':str(Path(self.directory).resolve())}).encode()
            self.send_response(200);self.send_header('Content-Type','application/json');self.send_header('Content-Length',str(len(payload)));self.end_headers();self.wfile.write(payload)
        else:super().do_GET()
    def end_headers(self):
        self.send_header('X-Content-Type-Options','nosniff')
        self.send_header('Cache-Control','no-cache')
        super().end_headers()

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--root',required=True);p.add_argument('--port',type=int,default=8769);args=p.parse_args()
    folder=Path(args.root).resolve();assert folder.is_dir()
    server=ThreadingHTTPServer(('127.0.0.1',args.port),partial(Handler,directory=str(folder)))
    print(f'Pose review: http://127.0.0.1:{args.port}',flush=True)
    server.serve_forever()
