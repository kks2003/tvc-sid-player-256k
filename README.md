# SID-lejátszó TVC-re (TVC256k++ kártyával)

Eredeti C64 `.sid` (PSID) zenéket játszik le **átalakítás nélkül** a
Videoton TV-Computeren, a [TVC256k++](https://github.com/dikdom/tvc256kplusplus)
kártya vSID-jével. A lejátszót (`sidplay.cas`) egyszer kell betölteni, utána
a kártya aktuális meghajtójáról (pendrive, PSRAM, flash) közvetlenül a `.sid`
fájlokat olvassa. A fejlécet a TVC dolgozza fel, a zene 6502-es
lejátszórutinját pedig egy Z80-as 6502-emulátor futtatja. A SID-regiszterek
írása a kártya `$E0..$F8` regisztereibe megy, a hangot a kártya állítja elő.

A kész, lefordított lejátszó: **[`sidplay.cas`](sidplay.cas)** (ebben a
könyvtárban). Saját fordítás:

```sh
./build.sh                   # -> build/sidplay.cas
```

A gépen: a `sidplay.cas` a kártya valamelyik meghajtójára, `LOAD "sidplay"`.
Egy egyszerű fájlválasztó indul, amely az aktuális könyvtár alkönyvtárait
és `.sid` fájljait mutatja:

- **fel / le**: léptetés, **balra / jobbra**: lapozás,
- **Enter**: a fájl lejátszása, illetve belépés a `[könyvtárba]` (`[..]`: vissza),
- **D**: a következő meghajtó (USB pendrive, PSRAM, flash),
- **ESC**: vissza a BASIC-be.

Lejátszás közben:

- **1-9**, **0**: az 1-9., illetve a 10. dal,
- **jobbra / balra nyíl**: a következő / előző dal,
- **ESC** vagy **SPACE**: vissza a fájlválasztóhoz.

Kell: Python 3, [sjasmplus](https://github.com/z00m128/sjasmplus). A gépen:
TVC 64k és TVC256k++ kártya (az 1., 2., 3. vagy 0. slotban, a lejátszó
megkeresi). A zene indulásakor kiírja a nevét, a szerzőt, a kiadást, a
betöltési címet és a dal számát. A `.sid` fájl legfeljebb kb. 44 KB lehet;
ami a zene után marad a 64 KB-ból, az a 6502 munkaterülete.

## Hogyan működik

- `sidplay.asm`: a kártya keresése, a könyvtár listázása és a fájl
  beolvasása a kártya fájlparancsaival (`REG_USB_MSC_CMD`: OPENDIR, READDIR,
  FOPEN, FREAD, FCLOSE, a paraméterek a kártya IO RAM-jában, `$D900`/`$DA00`),
  a PSID fejléc, a 6502 memóriája, az időzítő-IT-nkénti hívás.
- `cpu6502.asm`: a 6502-emulátor, a `tools/gen6502.py` generálja (minden
  dokumentált utasítás, decimális mód, és a lejátszókban előforduló nem
  dokumentáltak: LAX, SAX, DCP, ISC, SLO, RLA, SRE, RRA, ANC, ALR, SBX, NOP-ok).
- A 6502 64 KB-os címtere 256 bájtos lapokban. A zene a beolvasási
  pufferben marad (`$5100`-tól, lapra igazítva), a többi lap igény szerint
  foglalódik a zene fölött. A `$D400-$D7FF` írása a SID-be megy, az OSC3
  hívásonként visszaolvasva.
- A `$8000-$FFFF` tartományba a betöltés és a lejátszás idejére a kártya
  két gyors RAM-lapja (14., 15.) lapozódik be (`$B0`/`$B1` regiszter), így
  a TVC saját U2/U3 RAM-ja (a BASIC területe) érintetlen marad. A fájl
  `$C000` alatti része az IO RAM-on át jön (FREAD), a többi egyben,
  közvetlenül a kártya RAM-jába (FREAD_DEST).
- A lejátszócím a fejlécből, vagy ha 0, az init által beállított
  IT-vektorból (`$0314` vagy `$FFFE`); a kernal IT-kilépési pontjai
  (`$EA31`, `$EA81`, `$FEBC`) kis csonkok.

## Sebesség

Egy 6502-es utasítás átlagosan kb. 95 Z80-ciklus (az emulátor szerint, a
TVC memória-várakozásaival), így egy időzítő-IT alatt kb. 640 utasítás fér
el. Ami ezt adja:

- A kezelők címének alsó bájtja maga az opkód, a felső egy 256 bájtos
  táblából jön (`LD A,(DE)` / `INC DE` / `LD L,A` / `LD H,OPHI` /
  `LD H,(HL)` / `JP (HL)`). Ehhez a `build.sh` két menetben fordít: az első
  megméri a kezelőket, a második elpakolja őket.
- Az elágazás táblájának lapja állandóan a C regiszterben van (`LD H,C`).
- A 6502 N és Z jelzője a Z80 jelzőiben él (ahol a címszámítás elrontaná,
  ott `EX AF,AF'` védi), A a B-ben, X az IXl-ben, Y az IXh-ban, az átvitel
  a memóriában.
- Az indexelt címzés ritka lapátlépésének javítása a kezelő végén van, a
  fő úton csak egy nem teljesülő `JR C`.
- A zene lapjai a Z80 memóriájában is folytonosak, ezért a PC sima `INC DE`.
- Lejátszás alatt saját, rövid IT-kezelő fut a ROM-é helyett (az hívásonként
  kb. 5000 ciklus), ez figyeli az időkorlátot is (végtelen ciklus ellen).
- Ha egy hívás kicsúszik az időből, a következő rövidebbek behozzák.

- A `STA $D4xx` (abszolút és indexelt) a lassú út helyett közvetlenül a
  kártyára ír: a lejátszók hívásonként 20-30-szor írnak a SID-be.

Emulátorban mérve (a SID-regiszterírások sorozata bájtra egyezik egy PC-s
6502-emulátoréval): Commando (250-340 utasítás/hívás) és Golden Axe 1. dal
(átlag 583, legfeljebb 668 utasítás/hívás) teljes tempóban megy. A Cybernoid
II (Jeroen Tel) 1. dala 2 percig mérve: az első percben teljes tempó, utána,
ahol hívásonként átlag 633-644 utasítás fut, 10 mp-es szakaszonként legfeljebb
1,3%-kal lassabb. Ennél nehezebb lejátszórutinnál a zene jobban lelassul.

## Tempó

A lejátszót a TVC hanggenerátorának IT-je hívja (195312,5 / (4096 - n) Hz),
nem a képkocka-IT. A kettő közös állapotbitet használ, ezért lejátszás
közben a kurzor-IT tiltva van (CRTC R10 = 23h, ahogy a ROM magnórutinja is
csinálja), kilépéskor visszaáll.

- A fejléc `speed` bitje 0 (VBI): 50,12 Hz, a PAL C64 képkockája.
- A `speed` bit 1 (CIA): a CIA1 A időzítője szerint, 985248 / (T + 1) Hz
  (ha az init nem írta, a kernal 60 Hz-e). Ha a zene futás közben átírja az
  időzítőt, a tempó követi. 47,7 Hz alatt az IT kétszer (háromszor...)
  gyorsabb, és minden 2. (3. ...) hív.

Emulátorban mérve: VBI 50,12 Hz, CIA T = 8192 mellett 120 Hz (elvárt 120,3).

## NTSC zenék

Ha a PSID fejléc (v2+, `$76-$77` jelzők) NTSC órajelet ír:

- VBI-zenénél 59,83 Hz a hívás (az NTSC C64 képkockája),
- CIA-zenénél 1022727 / (T + 1) Hz (alapértéke a kernal NTSC 60 Hz-e),
- a hangmagasság-regiszterek (`$D400/01`, `$D407/08`, `$D40E/0F`) a PAL
  órajelű vSID-hez átszámolva: f × 1,038 (f + f/32 + f/128 − f/1024), így a
  hangok nem szólnak 3,8%-kal mélyebben.

A burkológörbék (ADSR) és a szűrő az NTSC és a PAL órajel közti 3,8%-os
különbséget nem követik, ez hallhatóan nem számít.

## Korlátok

- Csak PSID-szerű zenék; az RSID-k (CIA/VIC IT, kernal hívások) általában nem.
- A digis (mintás, `$D418`-as) zenék és a 2SID/3SID nem.
- Ha a lejátszórutin tartósan tovább fut egy időzítő-IT-nél (kb. 640
  utasítás fölött), a zene lassul.

## Teszt

```sh
python3 test/make_test_sid.py teszt.sid && ./build.sh
```

Az emulátoros teszt a `test/emu_harness.cpp`-vel megy (az Ep128web emulátormagjával, natívan fordítva: `python3 test/build_emu.py ../Ep128web`):
`CARD=2` (a kártya a 2. slotban), `CARD_FILE="sidplay.cas,build/sidplay.cas;teszt.sid,teszt.sid"`
(a fájlok a kártya PSRAM-meghajtóján), `TYPE_AT="4:teszt\n"` (a fájlnév
begépelése), a betöltendő program neve `sidplay`.

A helyesség és a tempó ellenőrzése (py65 kell hozzá): a harness
`ALLPORTS=1` portnaplóját a `test/sid_ref.py zene.sid portnaplo.txt` veti
össze egy PC-s 6502-emulátor SID-regiszterírásaival, és kiírja a
hívás/képkocka arányt.
