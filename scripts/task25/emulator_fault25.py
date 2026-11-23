#!/usr/bin/env python3
"""Extract bounded crash metadata only. Never decode memory/stack streams or copy dumps."""
import json
from pathlib import Path
import re
import struct


class InvalidMetadata(ValueError): pass


class MetadataReader:
    def __init__(self, stream, size): self.stream, self.size = stream, size
    def at(self, offset, count):
        if offset < 0 or count < 0 or count > 4096 or offset + count > self.size:
            raise InvalidMetadata('METADATA_RANGE_OR_SIZE')
        self.stream.seek(offset)
        data = self.stream.read(count)
        if len(data) != count: raise InvalidMetadata('SHORT_METADATA')
        return data
    def unpack(self, fmt, offset): return struct.unpack(fmt, self.at(offset, struct.calcsize(fmt)))


def safe_module_name(value):
    name = value.replace('\\', '/').rsplit('/', 1)[-1]
    if re.fullmatch(r'(?:lib[A-Za-z0-9_.+-]+\.so(?:\.[0-9]+)*|qemu-system-[A-Za-z0-9_-]+|emulator(?:\.task17-real)?|linux-vdso\.so\.[0-9]+)', name):
        return name
    return '<unrecognized-code-module>'


def parse_stream(stream, size):
    r = MetadataReader(stream, size)
    signature, version, count, directory, _, _, _ = r.unpack('<IIIIIIQ', 0)
    if signature != 0x504d444d or count > 128: raise InvalidMetadata('NOT_BOUNDED_MINIDUMP')
    entries = {}
    for i in range(count):
        kind, length, offset = r.unpack('<III', directory + i * 12)
        if kind in (4, 6, 7):
            if kind in entries: raise InvalidMetadata('DUPLICATE_METADATA_STREAM')
            if offset + length > size: raise InvalidMetadata('STREAM_RANGE')
            entries[kind] = (offset, length)
    if not all(k in entries for k in (4, 6, 7)): raise InvalidMetadata('REQUIRED_METADATA_MISSING')
    sys_rva, sys_len = entries[7]
    if sys_len < 2: raise InvalidMetadata('SYSTEM_METADATA_SHORT')
    arch, = r.unpack('<H', sys_rva)
    exc_rva, exc_len = entries[6]
    if exc_len < 168: raise InvalidMetadata('EXCEPTION_METADATA_SHORT')
    thread, = r.unpack('<I', exc_rva)
    code, = r.unpack('<I', exc_rva + 8)
    exception_address, = r.unpack('<Q', exc_rva + 24)
    context_size, context_rva = r.unpack('<II', exc_rva + 160)
    instruction = None
    # Only host instruction pointer, no general registers/stack/guest memory.
    if arch == 9 and context_size >= 256:
        instruction, = r.unpack('<Q', context_rva + 248)
    modules_rva, modules_len = entries[4]
    module_count, = r.unpack('<I', modules_rva)
    if module_count > 4096 or modules_len < 4 + 108 * module_count:
        raise InvalidMetadata('MODULE_LIST_BOUNDS')
    modules = []
    for i in range(module_count):
        base, length, _, _, name_rva = r.unpack('<QIIII', modules_rva + 4 + i * 108)
        name_size, = r.unpack('<I', name_rva)
        if name_size > 1024 or name_size % 2: raise InvalidMetadata('MODULE_NAME_BOUNDS')
        name = safe_module_name(r.at(name_rva + 4, name_size).decode('utf-16le'))
        modules.append((base, length, name))
    def location(address):
        if address is None: return {'status':'UNSUPPORTED_CONTEXT_ARCHITECTURE'}
        for base, length, name in modules:
            if base <= address < base + length:
                return {'status':'MAPPED_CODE_METADATA', 'module':name, 'moduleOffset':hex(address - base)}
        return {'status':'OUTSIDE_REPORTED_CODE_MODULES'}
    return {'status':'SAFE_EXCEPTION_MODULE_METADATA_ONLY', 'schema':1,
            'processorArchitecture':arch, 'exceptionCode':hex(code), 'exceptionThread':thread,
            'instruction':location(instruction), 'exceptionLocation':location(exception_address),
            'moduleCount':module_count, 'memoryOrStackStreamsDecoded':False,
            'rawDumpOrGuestMemoryPublished':False, 'registerRead':'AMD64_INSTRUCTION_POINTER_ONLY' if instruction is not None else 'NONE'}


def collect(roots, output):
    results = []
    seen = set()
    for root in roots:
        if not root.is_dir(): continue
        for path in root.rglob('*.dmp'):
            if len(seen) >= 50: break
            if path.is_symlink() or not path.is_file(): continue
            canonical = str(path.resolve())
            if canonical in seen: continue
            seen.add(canonical)
            try:
                with path.open('rb') as f: value = parse_stream(f, path.stat().st_size)
                value.update(index=len(results), dumpSize=path.stat().st_size, modifiedAtUnix=path.stat().st_mtime)
            except (OSError, InvalidMetadata, UnicodeError, struct.error) as error:
                value = {'status':'METADATA_NOT_AVAILABLE', 'index':len(results), 'errorType':type(error).__name__}
            results.append(value)
    result = {'status':'METADATA_EXTRACTED' if results else 'NO_MINIDUMP_FOUND', 'records':results,
              'noDumpCopied':True, 'noMemoryOrStackStreamsDecoded':True,
              'diagnosis':'Instruction module metadata is evidence, not proof of an application migration defect.'}
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({'status':result['status'], 'records':len(results), 'noRawDumpPublished':True}))


def main():
    import os
    from candidate25 import guard
    root = guard()
    if os.environ.get('CANDIDATE25_WORKFLOW') != '.github/workflows/sulfi-candidates25-verify.yml':
        raise InvalidMetadata('VERIFY_WORKFLOW_ONLY')
    collect([Path('/tmp/android-runner'), root], root/'task25-native-evidence/forensics/FAULT_MODULE_METADATA_25.json')


if __name__ == '__main__': main()
