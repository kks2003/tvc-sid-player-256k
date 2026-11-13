#!/usr/bin/env python3
"""A lejátszó magyar (ékezetes) szövegei TVC-kódolásban: strings.inc.

    python3 tools/gen_strings.py > strings.inc
    python3 tools/gen_strings.py --title "szöveg" build/title.bin   (a BASIC PRINT sora)

A TVC karakterkészletében az ékezetes nagybetűk $80-$88, a kisbetűk
$90-$98 (Á É Í Ó Ö Ő Ú Ü Ű sorrendben). A sorok legfeljebb 32 karakteresek.
"""
import sys

ACC = "ÁÉÍÓÖŐÚÜŰ"
TVC = {c: 0x80 + i for i, c in enumerate(ACC)}
TVC.update({c.lower(): 0x90 + i for i, c in enumerate(ACC)})

CR = "\r\n"
STRINGS = [   # (címke, szöveg); a "\r\n" sorvége 13, 10
    ("s_nocard", "Nincs TVC256k++ kártya!" + CR),
    ("s_badfile", "Nem PSID/RSID fájl!" + CR),
    ("s_nomem", "Nincs elég memória!" + CR),
    ("s_noplay", "Nincs lejátszócím!" + CR),
    ("s_author", "Szerző:"),
    ("s_rel", "Kiadva:"),
    ("s_info", "Betöltés: $"),
    ("s_song", "Dal: "),
    ("s_of", " / "),
    ("s_kind", "Típus:    "),
    ("s_clk0", "ismeretlen (PAL)"),
    ("s_title", "SID-lejátszó - TVC256k++  "),
    ("s_help", "Enter/tűz:indít D:megh. ESC:ki"),
    ("s_noread", "Nem olvasható a meghajtó!"),
    ("s_anykey", CR + "Nyomj meg egy gombot!"),
    ("s_notfound", "Nincs ilyen fájl!" + CR),
    ("s_toolarge", "Túl nagy fájl!" + CR),
    ("s_readerr", "Olvasási hiba!" + CR),
    ("s_rsid_no", "RSID-zene: teljes C64-et vár" + CR +
                  "(megszakítások, digi), ezt nem" + CR +
                  "tudom lejátszani." + CR),
    ("s_keys", "1-9,0: dal  <- ->: előző/köv." + CR +
               "ESC/SPACE: vissza a listához"),
]


def encode(text):
    out = []
    for ch in text:
        if ch in TVC:
            out.append(TVC[ch])
        elif ch == "\r":
            out.append(13)
        elif ch == "\n":
            out.append(10)
        elif 32 <= ord(ch) < 127:
            out.append(ord(ch))
        else:
            raise ValueError("nem TVC-karakter: %r" % ch)
    return out


def main():
    print("; strings.inc - GENERÁLT FÁJL (tools/gen_strings.py), kézzel ne módosítsd!")
    print("; a lejátszó szövegei TVC-kódolásban (ékezetes betűk: $80-$88, $90-$98)")
    for label, text in STRINGS:
        for line in text.split(CR):
            if len(line) > 32:
                sys.exit("túl hosszú sor (%d): %s" % (len(line), line))
        b = encode(text) + [0]
        print("%-11s db %s" % (label + ":", ", ".join("%d" % x for x in b)))


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--title":
        t = encode(sys.argv[2])
        open(sys.argv[3], "wb").write(bytes((t + [32] * 32)[:32]))
    else:
        main()
