"""Bounded catalog reads and explicit eligibility for recorded validation."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
INPUTS = {}


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def read(relative, optional=False):
    path = ROOT / relative
    if optional and not path.exists():
        return None
    INPUTS[relative] = digest(path)
    with path.open(encoding='utf-8-sig') as stream:
        return json.load(stream)


def catalog_rows():
    """Yield one asset at a time instead of expanding 252 MB of JSON at once."""
    relative = 'assets/graphics/geology_v11/catalog.json'
    path = ROOT / relative
    INPUTS[relative] = digest(path)
    decoder = json.JSONDecoder()
    with path.open(encoding='utf-8') as stream:
        buffer = stream.read(4096)
        # This is the versioned offline writer's top-level assets array.
        key = buffer.index('"assets"')
        buffer = buffer[buffer.index('[', key) + 1:]
        while True:
            buffer = buffer.lstrip(' \r\n\t,')
            if buffer.startswith(']'):
                return
            try:
                row, end = decoder.raw_decode(buffer)
            except json.JSONDecodeError:
                chunk = stream.read(1024 * 1024)
                if not chunk:
                    raise ValueError('Truncated geology catalog') from None
                buffer += chunk
                continue
            yield row
            buffer = buffer[end:]


def identity_matches(result, default):
    return result and all(result.get(key) == default[key]
                          for key in ('height_sha256', 'obstacle_sha256'))


def render_sources_match(result):
    sources = (result or {}).get('render_source_sha256', {})
    if not sources:
        return False
    for relative, expected in sources.items():
        path = ROOT / relative
        if not path.is_file() or digest(path) != expected:
            return False
        INPUTS[relative] = expected
    return True


def guard_failure(label, report_path=None):
    guard = read(f'artifacts/guarded/{label}/guard.json', optional=True)
    if guard is None:
        return 'No guarded completion record'
    if guard['exit_code'] != 0 or guard.get('stop_reason'):
        return guard.get('stop_reason') or f"Exit {guard['exit_code']}"
    if report_path:
        from datetime import datetime
        path = ROOT / report_path
        if not path.exists() or path.stat().st_mtime < datetime.fromisoformat(guard['started']).timestamp():
            return 'Report predates its latest attempt'
    return ''
