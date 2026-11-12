#!/usr/bin/env python3
"""Ellenőrzés: a TVC-s lejátszó SID-regiszterírásai egyeznek-e egy PC-s
6502-emulátoréval (py65), és tartja-e a tempót.

    python3 test/sid_ref.py zene.sid portnaplo.txt [hívások száma]

A portnapló az emu_harness kimenete ALLPORTS=1 mellett (képkocka, PC, port,
érték); a kártya a 2. slotban (30h/31h port). Kell: pip install py65.
"""
import collections, struct, sys
from py65.devices.mpu6502 import MPU
from py65.memory import ObservableMemory


def reference(path, calls, song=None):
    d = open(path, "rb").read()
    v, off, load, init, play, songs, start, speed = struct.unpack(">HHHHHHHI", d[4:22])
    data = d[off:]
    if load == 0:
        load = data[0] | data[1] << 8
        data = data[2:]
    if init == 0:
        init = load
    w = []
    ntsc = v >= 2 and off >= 0x7C and (d[0x77] & 0x0C) == 0x08
    shadow = [0] * 32
    FREQ = {0: 0, 1: 0, 7: 7, 8: 7, 14: 14, 15: 14}

    def sid_write(a, val):
        r = a & 0x1F
        if r >= 25:
            return
        if ntsc and r in FREQ:          # a lejátszó átszámolása (sid_out)
            shadow[r] = val
            lo = FREQ[r]
            f = shadow[lo] | shadow[lo + 1] << 8
            q = f >> 5
            g = f + q
            if g <= 0xFFFF:
                q >>= 2
                g += q
                if g <= 0xFFFF:
                    g -= q >> 3
            if g > 0xFFFF:
                g = 0xFFFF
            w.append((lo, g & 255))
            w.append((lo + 1, g >> 8))
        else:
            w.append((r, val))
    mem = ObservableMemory()
    mem.subscribe_to_write(range(0xD400, 0xD800), sid_write)
    mem.subscribe_to_read(range(0xD000, 0xE000), lambda a: 0)
    m = MPU(memory=mem)
    for i, b in enumerate(data):
        mem[load + i] = b
    mem[0], mem[1] = 0x2F, 0x37
    n_instr = []

    def call(addr, a=0):
        mem[0xFFF0], mem[0xFFF1], mem[0xFFF2] = 0x20, addr & 255, addr >> 8
        m.pc, m.a, n = 0xFFF0, a, 0
        while m.pc != 0xFFF3 and n < 300000:
            m.step()
            n += 1
        return n
    m.sp, m.p = 0xFF, 0x24
    call(init, (song or start) - 1)
    for _ in range(calls):
        n_instr.append(call(play))
    return w, n_instr


def main():
    sid, log = sys.argv[1], sys.argv[2]
    calls = int(sys.argv[3]) if len(sys.argv) > 3 else 500
    lines = [l.split() for l in open(log)]
    frames = [int(l[0]) for l in lines if l[2] == "30" and l[3] == "FB"]     # OSC3 olvasás: hívásonként egy
    sel, got = None, []
    for fr, pc, port, val in lines:
        if port == "30":
            sel = val
        elif port == "31" and sel and "E0" <= sel <= "F8" and int(pc, 16) < 0x8000:
            got.append((int(sel, 16) - 0xE0, int(val, 16)))
    got = got[25:]                                  # az indulás előtti SID-nullázás
    ref, n_instr = reference(sid, calls)
    n = 0
    while n < min(len(ref), len(got)) and ref[n] == got[n]:
        n += 1
    ok = n == min(len(ref), len(got)) and n > 0
    print("utasítás/hívás: átlag %.0f, legfeljebb %d" % (sum(n_instr) / len(n_instr), max(n_instr)))
    print("SID-írások: referencia %d, TVC %d, egyezik: %d%s" % (len(ref), len(got), n, "" if ok else "  ELTÉR!"))
    if len(frames) > 201:
        d = collections.Counter(b - a for a, b in zip(frames, frames[1:]))
        print("hívás/képkocka: %.4f (az utolsó 200: %.4f), közök: %s"
              % ((len(frames) - 1) / (frames[-1] - frames[0]), 199 / (frames[-1] - frames[-200]), sorted(d.items())))
    sys.exit(0 if ok else 1)


main()
