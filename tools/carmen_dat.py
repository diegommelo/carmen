#!/usr/bin/env python3
"""Read the resource archives of Carmen Sandiego (DOS, 1990): CARMEN.DAT and CITIES.DAT.

Archive layout (little endian):
  u32  offset of the directory
  ...  resources
  directory: u16 count, then count x {u16 id, u32 offset, u16 size}
Each resource at `offset` is 1 + size bytes: a check byte (bitwise NOT of the
8-bit sum of the payload) followed by the payload.

Compressed text payload: u16 decoded length, then a bit stream (MSB first).
The top two bits of the first stream byte give the escape width w = 5..8,
and the stream itself starts at bit 2. Read 4 bits: a nonzero code is an index
into the 16-entry frequency table; zero means "read w more bits", which is an
index into the full table (or, when w == 8, a literal byte). The table lives
in the executable's data segment (see TABLE_OFFSET).

usage:
  carmen_dat.py list FILE.DAT
  carmen_dat.py text FILE.DAT CARMEN_unpacked.EXE      # decode all text resources
  carmen_dat.py cities CITIES.DAT CARMEN_unpacked.EXE  # cities as JSON
"""
import json
import struct
import sys

TABLE_OFFSET = 0x2df4  # DGROUP offset of the character table in CARMEN.EXE 1991

LOCATIONS = ['Bank', 'Hotel', 'Museum', 'Sport Club', 'Library', 'Airport', 'Harbor', 'Riverfront',
             'Palace', 'Stock Exchange', 'Marketplace', 'Foreign Ministry']


def directory(path):
    d = open(path, 'rb').read()
    diroff = struct.unpack('<I', d[:4])[0]
    n = struct.unpack('<H', d[diroff:diroff + 2])[0]
    res = {}
    for i in range(n):
        rid, off, size = struct.unpack('<HIH', d[diroff + 2 + 8 * i:diroff + 10 + 8 * i])
        check, payload = d[off], d[off + 1:off + 1 + size]
        if (~sum(payload)) & 0xff != check:
            raise ValueError(f'bad check byte in resource {rid}')
        res[rid] = payload
    return res


def char_table(exe_path):
    exe = open(exe_path, 'rb').read()
    hdr = struct.unpack('<H', exe[8:10])[0] * 16
    dgroup = struct.unpack('<H', exe[14:16])[0]  # initial SS == DGROUP for MSC programs
    base = hdr + dgroup * 16 + TABLE_OFFSET
    return exe[base:base + 256]


def decode_text(payload, table):
    n = struct.unpack('<H', payload[:2])[0]
    data = payload[2:]
    width = (data[0] >> 6) + 5
    bit = 2
    out = bytearray()

    def get(k):
        nonlocal bit
        v = 0
        for _ in range(k):
            v = (v << 1) | ((data[bit >> 3] >> (7 - (bit & 7))) & 1)
            bit += 1
        return v

    while len(out) < n:
        c, k = get(4), 4
        if c == 0:
            c, k = get(width), width
        out.append(c if k == 8 else table[c])
    return bytes(out)


def string_list(raw):
    """Decoded text resources are a count byte followed by NUL-terminated strings.
    0x81 stands for he/she and 0x82 for his/her (filled in from the suspect's sex)."""
    count, parts = raw[0], raw[1:].split(b'\0')
    s = [p.decode('latin-1').replace('\x81', ' {he} ').replace('\x82', ' {his} ') for p in parts[:count]]
    return [' '.join(x.split()) for x in s]


def cities(res, table):
    base, stride = struct.unpack('<HH', res[1][2:6])
    out = []
    rid = base
    while rid in res:
        p = res[rid]
        row, col = struct.unpack('<HH', p[:4])  # map position: row (north->south), column (west->east)
        name = p[4:p.index(b'\0', 4)].decode('latin-1')
        nloc = struct.unpack('<H', res[rid + 10][:2])[0]
        locs = list(struct.unpack(f'<{nloc}H', res[rid + 10][2:2 + 2 * nloc]))
        clues = {}
        for t in range(1, 13):
            if rid + 10 + t in res:
                clues[LOCATIONS[t - 1]] = string_list(decode_text(res[rid + 10 + t], table))
        out.append({
            'id': rid, 'name': name, 'map': {'row': row, 'col': col},
            'description': string_list(decode_text(res[rid + 3], table)),
            'treasures': string_list(decode_text(res[rid + 4], table)),
            'locations': [LOCATIONS[t - 1] for t in locs],
            'clues_pointing_here': clues,
        })
        rid += stride
    return out


def main(argv):
    cmd, path = argv[1], argv[2]
    res = directory(path)
    if cmd == 'list':
        for rid, p in sorted(res.items()):
            print(f'{rid:6d} {len(p):6d}  {p[:16].hex(" ")}')
    elif cmd == 'text':
        table = char_table(argv[3])
        for rid, p in sorted(res.items()):
            try:
                t = decode_text(p, table)
            except (IndexError, ValueError):
                continue
            if len(t) > 4 and t[0] < 40 and t.count(0) >= t[0] and sum(32 <= b < 127 or b in (0, 0x81, 0x82) for b in t) == len(t) - 1:
                print(rid, json.dumps(string_list(t), ensure_ascii=False))
    elif cmd == 'cities':
        print(json.dumps(cities(res, char_table(argv[3])), indent=1, ensure_ascii=False))


if __name__ == '__main__':
    main(sys.argv)
