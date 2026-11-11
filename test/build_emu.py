#!/usr/bin/env python3
"""Az Ep128web emulátormagjának (ep128emu) natív fordítása a teszthez.

    python3 test/build_emu.py ../Ep128web [objkönyvtár]   -> kiírja az emu_harness útvonalát

Kell: g++, gcc, és az Ep128web repó az ep128emu almodullal
(git -C ../Ep128web submodule update --init).
"""
import glob, os, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))


def build_emulator(root, objdir):
    """Az Ep128web build.sh-jában felsorolt forrásokat natívan lefordítja."""
    E = os.path.join(root, "ep128emu")
    if not os.path.exists(os.path.join(E, "src", "tvc64vm.cpp")):
        sys.exit("hiányzik az ep128emu almodul: git -C %s submodule update --init" % root)
    # az Ep128web javításai (ugyanúgy, mint a build.sh)
    for patch in sorted(glob.glob(os.path.join(root, "patches", "*.patch"))):
        if subprocess.call(["git", "-C", E, "apply", "--check", patch],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL) == 0:
            subprocess.check_call(["git", "-C", E, "apply", patch])
    txt = open(os.path.join(root, "build.sh")).read()
    block = txt.split('SOURCES="')[1].split('"')[0]
    srcs = []
    for l in block.split():
        if l.startswith("$(ls ") or l.endswith(")"):       # $(ls minta) a build.sh-ban
            l = l.replace("$(ls", "").rstrip(")")
            if l:
                srcs += sorted(glob.glob(os.path.join(root, l)))
        elif l.endswith((".cpp", ".c")):
            srcs.append(l.replace("$E", E))
    srcs = [s if os.path.isabs(s) else os.path.join(root, s) for s in srcs]
    srcs.append(os.path.join(HERE, "emu_harness.cpp"))
    inc = ["-I" + os.path.join(root, p) for p in
           ("test/native_shim", "web/stubs", "web/src", "web/src/twodfx/include", "web/src/lua")]
    inc += ["-I" + E + "/src", "-I" + E + "/z80", "-I" + E]
    cxx = ["g++", "-std=gnu++17", "-O2", "-w", "-fpermissive", "-DHAVE_STDINT_H", "-DZ80_ENABLE_CMOS",
           "-DCPC_LSB_FIRST=1", "-DENABLE_SDEXT", "-DHAVE_LUA_H"] + inc
    tdx = os.path.join(root, "web/src/twodfx")
    os.makedirs(objdir, exist_ok=True)
    objs = []
    for s in srcs:
        o = os.path.join(objdir, s.replace("/", "_") + ".o")
        if "/web/src/lua/" in s:
            cmd = ["gcc", "-O2", "-w", "-DLUA_COMPAT_5_2"]
        elif "/web/src/twodfx/" in s and s.endswith(".c"):
            cmd = ["gcc", "-O2", "-std=c99", "-w"] + ["-I" + os.path.join(tdx, d) for d in
                   ("include", "core", "assets", "firmware_eggs", "firmware_eggs/portable")]
        elif s.endswith(".c"):
            cmd = ["gcc", "-std=gnu11", "-O2", "-w", "-DHAVE_STDINT_H", "-DLFS_NO_ASSERT"] + inc
        else:
            cmd = cxx + (["-Dmain=ep_unused_emscripten_main"] if s.endswith("web/src/main.cpp") else [])
        if not os.path.exists(o) or os.path.getmtime(o) < os.path.getmtime(s):
            subprocess.check_call(cmd + ["-c", s, "-o", o])
        objs.append(o)
    # a TVC256k++ kártya mentendő változóinak listája (az Ep128web build.sh
    # generálja); a teszt nem használja a kártyát, elég egy üres lista
    stub = os.path.join(objdir, "cardstate_stub.c")
    with open(stub, "w") as f:
        f.write("struct card_state_region { void *p; unsigned n; };\n"
                "const struct card_state_region card_state_regions[1] = {{0, 0}};\n"
                "const unsigned card_state_region_count = 0;\n")
    subprocess.check_call(["gcc", "-c", stub, "-o", stub + ".o"])
    objs.append(stub + ".o")
    exe = os.path.join(objdir, "emu_harness")
    subprocess.check_call(["g++"] + objs + ["-o", exe])
    return exe


if __name__ == "__main__":
    root = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "..", "..", "Ep128web"))
    obj = sys.argv[2] if len(sys.argv) > 2 else os.path.join(tempfile.gettempdir(), "tvcsid_emu_obj")
    print(build_emulator(root, obj))
