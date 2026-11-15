#!/usr/bin/env python3
"""Stand-in for llama.cpp's llama-server, for tests: same command line, same
endpoints (/health, /props, /v1/models, /v1/chat/completions with streaming,
reasoning and tool calls), same log lines the app reads.

FAKE_LLAMA_FAIL=1 makes it stop while loading, like a model that can't load.
"""
import json
import os
import sys
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

args = sys.argv[1:]


def opt(*names, default=None):
    for i, a in enumerate(args):
        if a in names and i + 1 < len(args):
            return args[i + 1]
    return default


if '--list-devices' in args:
    print('Available devices:')
    print('  Vulkan0: Fake GPU 9000 (12288 MiB, 11000 MiB free)')
    sys.exit(0)

model = opt('-m', '--model', default='')
host = opt('--host', default='127.0.0.1')
port = int(opt('--port', default='8080'))
key = opt('--api-key', default='')
alias = opt('--alias', '-a', default=os.path.basename(model))
ctx = int(opt('-c', '--ctx-size', default='4096'))
ngl = opt('-ngl', '--n-gpu-layers', default='auto')
log = sys.stderr

print(f'build: 11157 (fake) args: {" ".join(a for a in args if a != key)}', file=log, flush=True)
print(f'llama_model_load: loading model from {model}', file=log, flush=True)
if os.environ.get('FAKE_LLAMA_FAIL'):
    print('llama_model_load: error loading model: failed to load model', file=log, flush=True)
    sys.exit(1)
if not os.path.exists(model):
    print(f'gguf_init_from_file: failed to open GGUF file {model}', file=log, flush=True)
    print('llama_model_load: error loading model: failed to load model', file=log, flush=True)
    sys.exit(1)
time.sleep(0.3)
layers = 0 if ngl == '0' else 29
print(f'load_tensors: offloaded {layers}/29 layers to GPU', file=log, flush=True)
print(f'llama_context: n_ctx = {ctx}', file=log, flush=True)

started = time.time()


def tool_result_in(messages):
    return any(m.get('role') == 'tool' for m in messages)


class Handler(BaseHTTPRequestHandler):
    protocol_version = 'HTTP/1.1'

    def log_message(self, *a):
        pass

    def _json(self, code, body):
        data = json.dumps(body).encode()
        self.send_response(code)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def _authorized(self):
        return not key or self.headers.get('Authorization') == f'Bearer {key}'

    def do_GET(self):
        if self.path == '/health':
            if time.time() - started < 0.5:
                return self._json(503, {'error': {'message': 'Loading model'}})
            return self._json(200, {'status': 'ok'})
        if not self._authorized():
            return self._json(401, {'error': {'message': 'Invalid API Key', 'type': 'authentication_error'}})
        if self.path == '/props':
            return self._json(200, {'default_generation_settings': {'n_ctx': ctx}})
        if self.path == '/v1/models':
            return self._json(200, {'object': 'list', 'data': [{'id': alias, 'object': 'model'}]})
        self._json(404, {'error': {'message': 'not found'}})

    def _chunk(self, delta=None, finish=None, usage=None):
        body = {'choices': [{'index': 0, 'delta': delta or {}, 'finish_reason': finish}]}
        if usage:
            body = {'choices': [], 'usage': usage}
        line = f'data: {json.dumps(body)}\n\n'.encode()
        self.wfile.write(f'{len(line):x}\r\n'.encode() + line + b'\r\n')
        self.wfile.flush()

    def _say(self, answer):
        self.send_response(200)
        self.send_header('Content-Type', 'text/event-stream')
        self.send_header('Transfer-Encoding', 'chunked')
        self.end_headers()
        self._chunk({'content': answer})
        self._chunk(finish='stop')
        line = b'data: [DONE]\n\n'
        self.wfile.write(f'{len(line):x}\r\n'.encode() + line + b'\r\n0\r\n\r\n')
        self.wfile.flush()

    def do_POST(self):
        length = int(self.headers.get('Content-Length', '0'))
        req = json.loads(self.rfile.read(length) or b'{}')
        if not self._authorized():
            return self._json(401, {'error': {'message': 'Invalid API Key', 'type': 'authentication_error'}})
        if self.path != '/v1/chat/completions':
            return self._json(404, {'error': {'message': 'not found'}})
        messages = req.get('messages', [])
        last = messages[-1] if messages else {}
        text = last.get('content') if isinstance(last.get('content'), str) else json.dumps(last.get('content'))
        tools = [t['function']['name'] for t in req.get('tools', [])]
        system = messages[0].get('content', '') if messages else ''
        # "[ctx:N]" in the system prompt: a context of N characters, refused
        # beyond it as llama-server does.
        import re
        limit = re.search(r'\[ctx:(\d+)\]', system) if isinstance(system, str) else None
        if limit and sum(len(json.dumps(m)) for m in messages) > int(limit.group(1)):
            return self._json(400, {'error': {
                'code': 400,
                'message': 'request (9000 tokens) exceeds the available context size (4096 tokens), try increasing it',
                'type': 'exceed_context_size_error'}})
        if isinstance(system, str) and system.startswith('You check answers'):
            return self._say('APPROVED')
        if isinstance(text, str) and 'write a short plan' in text:
            return self._say('1. Hand the calculation to the Analyst.\n2. Write the answer.')
        self.send_response(200)
        self.send_header('Content-Type', 'text/event-stream')
        self.send_header('Transfer-Encoding', 'chunked')
        self.end_headers()
        if tools and not tool_result_in(messages):
            # Asks for a tool (handing work over first, when it can),
            # arguments split over two chunks.
            name = next((t for t in ('ask_assistant', 'run_python') if t in tools), tools[0])
            args = json.dumps(
                {'query': 'fake search'} if 'search' in name
                else {'assistant': 'Analyst', 'task': 'Compute 6*7'} if name == 'ask_assistant'
                else {'code': 'print(6*7)'} if name == 'run_python'
                else {'expression': '6*7'})
            self._chunk({'reasoning_content': f'I should use {name}.'})
            self._chunk({'tool_calls': [{'index': 0, 'id': 'call_1', 'type': 'function',
                                          'function': {'name': name, 'arguments': args[:5]}}]})
            self._chunk({'tool_calls': [{'index': 0, 'function': {'arguments': args[5:]}}]})
            self._chunk(finish='tool_calls')
        else:
            if tool_result_in(messages):
                tool_text = [m['content'] for m in messages if m.get('role') == 'tool'][-1]
                answer = f'Using the tool result ({tool_text[:40]}), the answer is ready.'
            else:
                answer = f'Echo from {alias}: {text}'
            self._chunk({'reasoning_content': 'Thinking briefly.'})
            for word in answer.split(' '):
                self._chunk({'content': word + ' '})
                time.sleep(0.01)
            self._chunk(finish='stop')
        self._chunk(usage={'prompt_tokens': 42, 'completion_tokens': 10})
        line = b'data: [DONE]\n\n'
        self.wfile.write(f'{len(line):x}\r\n'.encode() + line + b'\r\n0\r\n\r\n')
        self.wfile.flush()


server = ThreadingHTTPServer((host, port), Handler)
print(f'main: server is listening on http://{host}:{port} - starting the main loop', file=log, flush=True)
print('srv  update_slots: all slots are idle', file=log, flush=True)
try:
    server.serve_forever()
except KeyboardInterrupt:
    pass
