#!/usr/bin/env python3
"""Unpack the PKLITE-compressed CARMEN.EXE into a plain MZ executable.

The PKLITE stub is run in a 16-bit emulator (unicorn) until the Microsoft C
runtime starts (first INT 21h/AH=30h). The image is dumped twice, loaded at
two different segments; words that differ by the segment delta are the
relocation entries, which lets us rebuild a valid MZ header for Ghidra/IDA.

usage: unpack_exe.py CARMEN.EXE CARMEN_unpacked.EXE
requires: pip install unicorn
"""
import struct
import sys

from unicorn import Uc, UC_ARCH_X86, UC_MODE_16, UC_HOOK_INTR, UC_HOOK_CODE
from unicorn.x86_const import (UC_X86_REG_AH, UC_X86_REG_AX, UC_X86_REG_CS, UC_X86_REG_DS,
                               UC_X86_REG_ES, UC_X86_REG_IP, UC_X86_REG_SP, UC_X86_REG_SS)

MEM = 0x40000


def run_stub(data, load):
    """Run the stub with the image loaded at segment `load`; return memory and OEP state."""
    (_, cblp, cp, nrel, hdr, _, _, ss, sp, _, ip, cs, lfarlc) = struct.unpack('<2sHHHHHHHHHHHH', data[:26])
    size = (cp - 1) * 512 + (cblp or 512)
    psp = load - 0x10
    mu = Uc(UC_ARCH_X86, UC_MODE_16)
    mu.mem_map(0, 0x100000)
    mu.mem_write(load * 16, data[hdr * 16:size])
    mu.mem_write(psp * 16, b'\xcd\x20' + struct.pack('<H', 0x9fff))
    for i in range(nrel):
        o, s = struct.unpack('<HH', data[lfarlc + 4 * i:lfarlc + 4 * i + 4])
        a = (load + s) * 16 + o
        v = struct.unpack('<H', mu.mem_read(a, 2))[0]
        mu.mem_write(a, struct.pack('<H', (v + load) & 0xffff))
    regs = {UC_X86_REG_CS: (load + cs) & 0xffff, UC_X86_REG_IP: ip, UC_X86_REG_SS: (load + ss) & 0xffff,
            UC_X86_REG_SP: sp, UC_X86_REG_DS: psp, UC_X86_REG_ES: psp}
    for r, v in regs.items():
        mu.reg_write(r, v)
    state = {'segs': []}

    def on_code(mu, addr, sz, ud):
        c = mu.reg_read(UC_X86_REG_CS)
        if not state['segs'] or state['segs'][-1][0] != c:
            state['segs'].append((c, mu.reg_read(UC_X86_REG_IP)))

    def on_int(mu, no, ud):
        if no == 0x21 and mu.reg_read(UC_X86_REG_AH) == 0x30:
            mu.reg_write(UC_X86_REG_AX, 0x0005)
            if len(state['segs']) > 2:  # we are past the stub: this is the C runtime
                state['oep'] = state['segs'][-1]
                mu.emu_stop()

    mu.hook_add(UC_HOOK_CODE, on_code)
    mu.hook_add(UC_HOOK_INTR, on_int)
    mu.emu_start(((load + cs) & 0xffff) * 16 + ip, 0, count=200_000_000)
    return bytes(mu.mem_read(load * 16, MEM)), state['oep']


def find_dgroup(mem, oep, load):
    """MSC startup: 'mov di, DGROUP' after the DOS version check, then 'add sp, STACK'."""
    off = (oep[0] - load) * 16 + oep[1]
    code = mem[off:off + 0x40]
    i = code.index(b'\xbf')  # mov di, imm16
    dgroup = struct.unpack('<H', code[i + 1:i + 3])[0]
    j = code.index(b'\x81\xc4')  # add sp, imm16
    stack = struct.unpack('<H', code[j + 2:j + 4])[0]
    return dgroup - load, stack


def main(src, dst):
    data = open(src, 'rb').read()
    a, oep = run_stub(data, 0x1000)
    b, _ = run_stub(data, 0x2000)
    dgroup, stack = find_dgroup(a, oep, 0x1000)
    end = dgroup * 16 + stack
    img = bytearray(a[:end])
    rel = []
    i = 0
    while i < end - 1:
        if a[i] != b[i]:
            p = i - 1  # the high byte of a segment word changed
            va = struct.unpack('<H', a[p:p + 2])[0]
            img[p:p + 2] = struct.pack('<H', (va - 0x1000) & 0xffff)
            rel.append(p)
            i += 1
        i += 1
    while len(img) % 16:
        img.append(0)
    hdrsz = (28 + 4 * len(rel) + 15) // 16 * 16
    total = hdrsz + len(img)
    h = struct.pack('<2sHHHHHHHHHHHHH', b'MZ', total % 512, (total + 511) // 512, len(rel), hdrsz // 16,
                    0x100, 0xffff, dgroup, stack, 0, oep[1], oep[0] - 0x1000, 28, 0)[:28]
    h += b''.join(struct.pack('<HH', p & 0xf, p >> 4) for p in rel)
    h += b'\0' * (hdrsz - len(h))
    open(dst, 'wb').write(h + img)
    print(f'OEP {oep[0] - 0x1000:04x}:{oep[1]:04x}  DGROUP {dgroup:04x}  {len(rel)} relocations')


if __name__ == '__main__':
    main(*sys.argv[1:3])
