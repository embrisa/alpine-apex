"""Local Cascadeur installed MCP client; preserve requests even after timeouts."""
import argparse, json, pathlib, sys, time, urllib.request
p = argparse.ArgumentParser()
p.add_argument('label'); p.add_argument('script', nargs='?'); p.add_argument('--code')
a = p.parse_args()
root = pathlib.Path(__file__).resolve().parent
code = a.code if a.code is not None else pathlib.Path(a.script).read_text(encoding='utf-8-sig')
body = {'jsonrpc':'2.0','id':1,'method':'tools/call','params':{'name':'run_script','arguments':{'code':code}}}
started=time.time(); result=None; failure=None
try:
    req=urllib.request.Request('http://127.0.0.1:8765/mcp',data=json.dumps(body).encode(),headers={'Content-Type':'application/json'})
    with urllib.request.urlopen(req,timeout=45) as response: result=json.load(response)
except Exception as exc: failure=repr(exc)
receipt={'label':a.label,'started_unix':started,'seconds':time.time()-started,'request':body,'response':result,'transport_error':failure}
(root/'receipts').mkdir(exist_ok=True)
out=root/'receipts'/(time.strftime('%H%M%S')+'_'+a.label+'.json')
assert not out.exists()
out.write_text(json.dumps(receipt,indent=2),encoding='utf-8')
print(json.dumps(result,indent=2) if result else failure); print('RECEIPT',out)
sys.exit(1 if failure or result.get('error') or result.get('result',{}).get('isError') else 0)
