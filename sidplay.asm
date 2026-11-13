; ============================================================================
; sidplay.asm - C64 SID-zene lejátszó Videoton TVC 64k + TVC256k++ kártyára
; (sjasmplus). A lejátszó egyszer töltődik be (sidplay.cas), utána a kártya
; aktuális meghajtójáról (pendrive, PSRAM, flash) közvetlenül az eredeti .sid
; fájlt olvassa be, átalakítás nélkül. A fejlécet a TVC dolgozza fel, a zene
; 6502-es lejátszórutinját egy Z80-as 6502-emulátor (cpu6502.asm) futtatja.
; A SID-regiszterek írása a kártya vSID-jére megy ($E0..$F8 regiszterek).
;
; Kell: TVC 64k (a U3 RAM is), TVC256k++ kártya az 1..3. vagy 0. slotban.
;
; Memória: a 6502 64 KB-os címtere 256 bájtos lapokban, igény szerint
; foglalva: a U3 ($C000-$FFFF), a beolvasott fájl fölötti szabad RAM a HIMEM
; alá, végül a .sid fájl helye (a lapokba másolás után).
; A $D000-$DFFF tartomány I/O: a $D400-$D7FF írása a SID-be megy, az olvasás
; egy árnyéklapról jön (OSC3/ENV3 képkockánként frissítve a kártyáról).
;
; Fájlválasztó: fel/le (balra/jobbra: lapozás), Enter vagy joystick tűz:
; lejátszás vagy belépés a könyvtárba, D: másik meghajtó, ESC: vissza a BASIC-be.
; A joystickok (1., 2.) iránya is léptet.
; ============================================================================

P_PAGING    equ 02h
P_KBDROW    equ 03h
P_KBDIN     equ 58h
V_PAGING    equ 0003h
V_PORT03    equ 0B11h
IRQVEC      equ 0038h
IO_PARAM    equ 0D900h          ; a kártya IO RAM-ja a slot IOMEM-jében
IO_RESULT   equ 0DA00h
IO_ATTR     equ 0DB00h
REG_MSC     equ 0D6h            ; REG_USB_MSC_CMD
REG_DRIVE   equ 0C5h
CHUNK       equ 1530            ; legfeljebb 6*256-2 bájt olvasásonként
PAGE_RUN    equ 0B0h            ; U0 U1 U2 U3 (a ROM IT-je SYS-re vált és visszaállítja)
KEYMASK     equ 28h             ; 7. sor: b3 = ESC, b5 = SPACE

V_PORT05    equ 0B12h           ; a 05h port tükre (b5: hang-IT, b4: hangjel)
P_PITCHLO   equ 04h
P_PITCHHI   equ 05h
P_ITCLR     equ 07h
P_TGRESET   equ 5Bh             ; olvasás: a hanggenerátor alaphelyzetbe
P_CRTCSEL   equ 70h
P_CRTCDAT   equ 71h
VBI_X       equ 3897            ; 195312,5 / 50,1245 Hz (PAL C64 képkocka)
VBI_X_NTSC  equ 3265            ; 195312,5 / 59,826 Hz (NTSC C64 képkocka)
CIA_DEFAULT equ 4025h           ; a kernal CIA1 időzítője (~60 Hz, PAL)
CIA_DEF_NTSC equ 4295h          ; ugyanez NTSC gépen
CIA_MUL     equ 12992           ; 65536 * 195312,5 / 985248 (PAL órajel)
CIA_MUL_NTSC equ 12515          ; 65536 * 195312,5 / 1022727 (NTSC órajel)
REG_MEM_P2  equ 0B0h            ; a kártya gyors RAM-lapja a U2-be / U3-ba
REG_MEM_P3  equ 0B1h
CARD_PG2    equ 14              ; lejátszás alatt: a zene $8000-$FFFF része
CARD_PG3    equ 15
BUF_END     equ 0FF00h          ; a fájl vége legfeljebb (a lapra igazítás miatt)

REG_VSID    equ 0E0h
SID_REGS    equ 25

            include "cas.inc"

start:
            assert start < 10000
            ld (saved_sp), sp
            ld sp, stack_top
            push ix
            push iy
            call main
            pop iy
            pop ix
            ld sp, (saved_sp)
            ret

; ---- szöveg kiírása (ROM: RST 30h / 21h = EDITOR karakterkiírás, C) -----------------
prstr:      ld a, (hl)
            or a
            ret z
            push hl
            ld c, a
            rst 30h
            db 21h
            pop hl
            inc hl
            jr prstr

; 32 bájtos PSID szövegmező kiírása (0 vagy a mező vége zárja), majd sorvége
prfield:    ld b, 32
.l:         ld a, (hl)
            or a
            jr z, .e
            cp 20h
            jr c, .n
            cp 7Fh
            jr c, .ok
.n:         ld a, '?'
.ok:        push hl
            push bc
            ld c, a
            rst 30h
            db 21h
            pop bc
            pop hl
            inc hl
            djnz .l
.e:         ld hl, s_crlf
            jr prstr

; HL = szám (0..65535) kiírása tízes számrendszerben
prnum:      ld de, numbuf + 5
            xor a
            ld (de), a
.l:         dec de
            push de
            ld c, 10
            call div16
            pop de
            add a, '0'
            ld (de), a
            ld a, h
            or l
            jr nz, .l
            ex de, hl
            jr prstr
; HL = HL / C, A = maradék
div16:      xor a
            ld b, 16
.l:         add hl, hl
            rla
            cp c
            jr c, .n
            sub c
            inc l
.n:         djnz .l
            ret

; ---- főprogram -------------------------------------------------------------
main:
            ; kártya keresése: a regiszterválasztó port visszaolvasható
            ld hl, slot_order
.slot:      ld a, (hl)
            cp 0FFh
            jr z, .nocard
            inc hl
            ld c, a
            ld a, 55h
            out (c), a
            in a, (c)
            cp 55h
            jr nz, .slot
            ld a, 0AAh
            out (c), a
            in a, (c)
            cp 0AAh
            jr z, .found
            jr .slot
.nocard:    ld hl, s_nocard
            call prstr
            ld hl, 1
            ret
.found:     ld a, c
            ld (sid_reset.psel1 + 1), a       ; a portcímek a kódba
            ld (sid_out.psel + 1), a
            ld (wslow_A.psel4 + 1), a
            ld (sid_fast.psel + 1), a
            ld (sid_out.psel2 + 1), a
            ld (sid_out.psel3 + 1), a
            ld (play_file.psel3 + 1), a
            inc a
            ld (sid_reset.pdat1 + 1), a
            ld (sid_out.pdat + 1), a
            ld (wslow_A.pdat4 + 1), a
            ld (sid_fast.pdat + 1), a
            ld (sid_out.pdat2 + 1), a
            ld (sid_out.pdat3 + 1), a
            ld (play_file.pdat3 + 1), a
            inc a
            ld c, a
            xor a
            out (c), a              ; nincs automatikus léptetés
            ld a, c
            sub 2
            ld (card_base), a
            sub 10h                 ; slot * 10h -> slot * 40h (a 03h port 6-7. bitje)
            add a, a
            add a, a
            ld (card_slot6), a
            ld a, (V_PAGING)        ; az eredeti lapozás (a lejátszás után vissza)
            ld (saved_paging), a
            call screen_on
            jp browser

; ---- egy beolvasott .sid lejátszása (sidbuf .. sidend) ----------------------
play_file:
            ; PSID fejléc (nagy-endián mezők)
            ld a, (sidbuf + 1)
            cp 'S'
            jr nz, .badfile
            ld a, (sidbuf + 2)
            cp 'I'
            jr nz, .badfile
            ld a, (sidbuf + 3)
            cp 'D'
            jr z, .okfile
.badfile:   ld hl, s_badfile
            call prstr
            ld hl, 2
            ret
.okfile:
            ld ix, sidbuf
            ld h, (ix + 6)
            ld l, (ix + 7)
            ld de, sidbuf
            add hl, de              ; HL = az adatok eleje
            ld d, (ix + 8)
            ld e, (ix + 9)          ; DE = betöltési cím
            ld a, d
            or e
            jr nz, .hasload
            ld e, (hl)
            inc hl
            ld d, (hl)
            inc hl
.hasload:   ld (data_ptr), hl
            ld (load_addr), de
            ex de, hl
            ld hl, (sidend)
            or a
            sbc hl, de
            ld (data_len), hl
            ld h, (ix + 0Ah)
            ld l, (ix + 0Bh)
            ld a, h
            or l
            jr nz, .hasinit
            ld hl, (load_addr)
.hasinit:   ld (init_addr), hl
            ld h, (ix + 0Ch)
            ld l, (ix + 0Dh)
            ld (play_addr), hl
            ld a, (ix + 0Fh)        ; dalok száma
            ld (songs), a
            ld a, (ix + 11h)        ; kezdő dal
            or a
            jr nz, .hassong
            inc a
.hassong:   ld (song), a
            ld a, (song_req)        ; a fájlnév után megadott dal
            or a
            jr z, .nosongreq
            ld hl, songs
            cp (hl)
            jr z, .songok
            jr nc, .nosongreq
.songok:    ld (song), a
.nosongreq:

            call draw_info          ; az adatlap (név, szerző, dal...)
            ld a, (sidbuf)          ; RSID: teljes C64-et vár, nem játsszuk le
            cp 'R'
            jr nz, .psid
            ld bc, 0100h + SONG_ROW
            call gotoxy
            ld hl, C_BLACK * 256 + C_YELLOW
            call colors
            ld hl, s_rsid_no
            call prstr
            ld hl, C_BLACK * 256 + C_GREEN
            call colors
            ld hl, 6
            ret
.psid:

            ld a, (V_PORT05)
            ld (saved_p05), a
            call calc_speed         ; a fejlécből, mielőtt a helyére csúszik a zene
            ld hl, wslow_A.inl      ; a SID-írás gyors útjai: PAL közvetlen, NTSC
            ld de, sid_fast.inl     ; átszámolással
            ld a, (ntsc)
            or a
            jr z, .sw
            ld hl, wslow_A.conv
            ld de, sid_fast.conv
.sw:        ld (wslow_A.sw + 1), hl
            ld (sid_fast.sw + 1), de
            di
            ld a, PAGE_RUN
            ld (V_PAGING), a
            out (P_PAGING), a
            ld hl, IRQVEC           ; saját IT-kezelő (a ROM-é ~5000 ciklus)
            ld de, irq_save
            ld bc, 3
            ldir
            ld a, 0C3h
            ld (IRQVEC), a
            ld hl, irq_handler
            ld (IRQVEC + 1), hl
            ld a, 1
            ld (irq_on), a
            ei
            call load_image
            jr nc, .loaded
            call stop_all
            ld hl, s_nomem
            call prstr
            ld hl, 3
            ret
.loaded:
            call install_stubs
            call sid_reset

            ; init: A = dal - 1
            ld a, (song)
            dec a
            ld (rA), a
            xor a
            ld (rX), a
            ld (rY), a
            ld (fC), a
            ld (fV), a
            ld (fD), a
            ld (rF), a              ; N = 0, Z = 0
            ld a, 04h
            ld (fI), a
            ld a, 0FFh
            ld (rS), a
            ld a, 2Fh
            ld (ZPG + 0), a
            ld a, 37h
            ld (ZPG + 1), a
            ld hl, (init_addr)
            xor a                   ; a CIA1 A időzítőjét az init írhatja
            ld (cia_lo), a
            ld (cia_hi), a
            ld a, 150               ; legfeljebb 3 másodperc
            call call_jsr

            ; lejátszócím: a fejlécből, vagy az IT-vektor ($0314, $FFFE)
            ld hl, (play_addr)
            ld a, h
            or l
            jr nz, .jsrmode
            ld hl, 0314h
            call rd16
            ld a, h
            or l
            jr z, .hwvec
            ld de, 0EA31h
            or a
            sbc hl, de
            add hl, de
            jr z, .hwvec
            ld (play_addr), hl
            ld a, 2                 ; kernal-féle IT: P, A, X, Y a veremben
            jr .mode
.hwvec:     ld hl, 0FFFEh
            call rd16
            ld a, h
            or l
            jr nz, .hw
            call stop_all
            ld hl, s_noplay
            call prstr
            ld hl, 4
            ret
.hw:        ld (play_addr), hl
            ld a, 1                 ; hardveres IT: P a veremben, RTI
            jr .mode
.jsrmode:   xor a
.mode:      ld (play_mode), a
            call timer_start
            xor a
            ld (cia_dirty), a

; ---- időzítő-IT-nként a lejátszó (VBI: 50,12 Hz, CIA: a zene tempója) ------
.frame:     ld a, (pending)         ; van kiszolgálatlan időzítő-IT?
            or a
            jr nz, .go
            halt
            jr .frame
.go:        di                      ; ha egy hívás kicsúszott, a következők behozzák
            ld a, (pending)
            dec a
            cp 3
            jr c, .pc
            ld a, 2
.pc:        ld (pending), a
            ei
            ld hl, it_cnt           ; minden it_div. IT-re
            dec (hl)
            jr nz, .frame
            ld a, (it_div)
            ld (hl), a
            ld a, REG_VSID + 1Bh    ; OSC3, ENV3 az árnyéklapra
.psel3:      out (0), a
.pdat3:      in a, (0)
            ld (IOSH + 1Bh), a
            ld (IOSH + 3Bh), a
            ld a, (play_mode)
            ld hl, (play_addr)
            or a
            jr nz, .irq
            ld a, 8
            call call_jsr
            jr .keys
.irq:       call call_irq
.keys:      ld hl, (cps_cnt)        ; eltelt egy másodperc?
            dec hl
            ld (cps_cnt), hl
            ld a, h
            or l
            jr nz, .nt
            ld hl, (cps)
            ld (cps_cnt), hl
            ld hl, secs
            inc (hl)
            ld a, (hl)
            cp 60
            jr c, .sec
            ld (hl), 0
            ld hl, mins
            ld a, (hl)
            cp 99
            jr nc, .sec
            inc (hl)
.sec:       call show_time          ; (a ROM-mal; a lejátszó kicsit később jön)
.nt:        ld a, (cia_dirty)       ; a zene átírta a CIA időzítőt
            or a
            call nz, timer_update
            ld hl, key_cnt          ; ESC/SPACE minden 4., a dalválasztók minden
            dec (hl)                ; 8. hívásnál (a billentyűolvasás is idő)
            ld a, (hl)
            and 3
            jp nz, .frame
            call read_keys
            cp KEYMASK
            jr nz, .esc
            ld hl, key_cnt
            ld a, (hl)
            or a
            jp nz, .frame
            ld (hl), 8
            call read_song_key      ; számbillentyű / nyilak: másik dal
            or a
            jp z, .frame
            ld hl, songs
            cp (hl)
            jr z, .sok
            jp nc, .frame
.sok:       ld hl, song
            cp (hl)
            jp z, .frame
            ld (song_req), a
            call stop_all
.krel:      halt                    ; megvárjuk, hogy elengedjék
            call read_song_key
            or a
            jr nz, .krel
            ld hl, 5
            ret
.esc:       call stop_all
.rel:       halt                    ; megvárjuk, hogy elengedjék
            call read_keys
            cp KEYMASK
            jr nz, .rel
            ld hl, 0
            ret

stop_all:   call sid_reset
            di
            ld a, (saved_paging)
            ld (V_PAGING), a
            out (P_PAGING), a
            ld a, (irq_on)          ; a ROM IT-kezelője vissza
            or a
            jr z, .i
            xor a
            ld (irq_on), a
            ld hl, irq_save
            ld de, IRQVEC
            ld bc, 3
            ldir
.i:         ld a, (timer_on)        ; a hang-IT ki, a kurzor-IT vissza
            or a
            jr z, .t
            xor a
            ld (timer_on), a
            ld a, (saved_p05)
            ld (V_PORT05), a
            out (P_PITCHHI), a
            ld a, 0Ah
            out (P_CRTCSEL), a
            ld a, 03h
            out (P_CRTCDAT), a
.t:         ei
            ret

; saját IT-kezelő a lejátszás alatt: nyugtáz, számol
irq_handler:
            push af
            out (P_ITCLR), a
            ld a, (ticks)
            inc a
            ld (ticks), a
            ld a, (pending)
            inc a
            ld (pending), a
            ld a, (emu_on)          ; őrkutya: a 6502-es kód túl sokáig fut?
            or a
            jr z, .r
            push hl
            ld a, (ticks)
            ld hl, wd_start
            sub (hl)
            pop hl
.wd_lim:    cp 0
            jr nc, .to
.r:         pop af
            ei
            ret
.to:        xor a
            ld (emu_on), a
            ld sp, (emu_sp)         ; az emu_run hívójához térünk vissza
            ei
            jp emu_timeout

; ---- időzítő: a hanggenerátor IT-je (195312,5 / (4096 - n) Hz) ---------------
; A képkocka-IT (a CRTC kurzor-IT-je) közös állapotbitet használ a hang-IT-vel,
; ezért közben tiltva van (CRTC R10 = 23h, mint a ROM magnórutinjában).
; A PSID fejléc speed mezőjének a dalhoz tartozó bitje: 0 = VBI (PAL 50,12 Hz),
; 1 = a CIA1 A időzítője (985248 / (T + 1) Hz; ha az init nem írta: 60 Hz).
calc_speed:
            ld a, (song)            ; bit = dal - 1 (32 fölött a 31.)
            dec a
            cp 32
            jr c, .b
            ld a, 31
.b:         ld c, a
            srl a
            srl a
            srl a
            ld e, a
            ld a, 15h
            sub e
            ld e, a
            ld d, 0
            ld hl, sidbuf
            add hl, de
            ld a, c
            and 7
            inc a
            ld b, a
            ld a, (hl)
.s:         rrca
            djnz .s
            ld a, 0
            rla
            ld (cia_mode), a
            xor a                   ; PSID v2+: a $76-$77 jelzőszó 2-3. bitje az
            ld (ntsc), a            ; órajel (01 PAL, 10 NTSC, 11 mindkettő)
            ld a, (sidbuf + 5)
            cp 2
            ret c
            ld a, (sidbuf + 7)
            cp 7Ch
            ret c
            ld a, (sidbuf + 77h)
            and 0Ch
            cp 08h
            ret nz
            ld a, 1
            ld (ntsc), a
            ret
timer_start:
            ld a, 1
            ld (timer_on), a
            xor a
            ld (pending), a
timer_update:
            xor a
            ld (cia_dirty), a
            ld a, (cia_mode)
            or a
            ld hl, VBI_X
            ld a, (ntsc)
            or a
            jr z, .vp
            ld hl, VBI_X_NTSC
.vp:        ld a, (cia_mode)
            or a
            jr z, .x
            ld hl, (cia_lo)         ; x = (T + 1) * 12992 / 65536
            ld a, h
            or l
            jr nz, .t
            ld hl, CIA_DEFAULT
            ld a, (ntsc)
            or a
            jr z, .t
            ld hl, CIA_DEF_NTSC
.t:         inc hl
            ld de, CIA_MUL
            ld a, (ntsc)
            or a
            jr z, .m
            ld de, CIA_MUL_NTSC
.m:
            call mul16              ; DEHL = HL * DE
            ex de, hl               ; HL = a felső szó
.x:         push hl                 ; hívás / mp = 195312,5 / x (az időhöz)
            srl h
            rr l
            srl h
            rr l
            ld a, h
            or l
            jr nz, .x4
            inc l
.x4:        ex de, hl
            ld bc, 48828
            call div_bc_de
            ld (cps), bc
            ld (cps_cnt), bc
            pop hl
            ld c, 1                 ; IT-osztó: x / k <= 4090
.k:         push hl
            push bc
            call div16
            ld de, 4091
            or a
            sbc hl, de
            pop bc
            pop hl
            jr c, .kok
            inc c
            jr .k
.kok:       ld a, c
            ld (it_div), a
            ld (it_cnt), a
            call div16              ; HL = x / k
            ld a, h
            or a
            jr nz, .big
            ld a, l
            cp 2
            jr nc, .big
            ld hl, 2
.big:       ex de, hl               ; n = 4096 - x / k
            ld hl, 4096
            or a
            sbc hl, de
            di
            ld a, l
            out (P_PITCHLO), a
            ld a, (saved_p05)
            and 0C0h                ; magnómotorok
            or 20h                  ; hang-IT, hangjel ki (b4 = 0)
            or h
            ld (V_PORT05), a
            out (P_PITCHHI), a
            ld a, 0Ah               ; a kurzor-IT tiltása
            out (P_CRTCSEL), a
            ld a, 23h
            out (P_CRTCDAT), a
            in a, (P_TGRESET)
            out (P_ITCLR), a
            ei
            ret

; BC = BC / DE (16 bites, előjel nélkül), HL = maradék
div_bc_de:  ld hl, 0
            ld a, b
            ld b, 16
.l:         sli c
            rla
            adc hl, hl
            sbc hl, de
            jr nc, .n
            add hl, de
            dec c
.n:         djnz .l
            ld b, a
            ret

; DEHL = HL * DE (előjel nélkül)
mul16:      ld b, h
            ld c, l
            ld hl, 0
            ld a, 16
.l:         add hl, hl
            ex de, hl
            adc hl, hl
            ex de, hl
            jr nc, .n
            add hl, bc
            jr nc, .n
            inc de
.n:         dec a
            jr nz, .l
            ret

; A = a lenyomott dalválasztó billentyű szerinti dal (0: nincs):
; 1-9, 0 = 10. dal, jobbra/balra nyíl: következő/előző
read_song_key:
            ld c, 0
            call read_row
            ld hl, row0map
            call .scan
            ret nz
            ld c, 1
            call read_row
            ld hl, row1map
            call .scan
            ret nz
            ld c, 8
            call read_row
            ld b, a
            ld a, (song)
            bit 5, b                ; jobbra
            jr z, .next
            bit 6, b                ; balra
            jr z, .prev
            xor a
            ret
.next:      inc a
            ret
.prev:      dec a
            ret
.scan:      cpl
            ld b, 8
.l:         rrca
            jr nc, .n
            ld e, a
            ld a, (hl)
            or a
            ret nz
            ld a, e
.n:         inc hl
            djnz .l
            xor a
            ret
row0map:    db 5, 3, 2, 0, 6, 0, 1, 4       ; a 0. sor bitjei
row1map:    db 0, 8, 9, 0, 0, 0, 10, 7      ; az 1. sor bitjei

; A = a C. billentyűsor (0 = lenyomva)
read_row:   di
            ld a, (V_PORT03)
            and 0F0h
            or c
            out (P_KBDROW), a
            in a, (P_KBDIN)
            ld b, a
            ld a, (V_PORT03)
            out (P_KBDROW), a
            ei
            ld a, b
            ret

; A = a billentyűzet 7. sorának ESC/SPACE bitjei
read_keys:  di
            ld a, (V_PORT03)
            and 0F0h
            or 07h
            out (P_KBDROW), a
            in a, (P_KBDIN)
            and KEYMASK
            ld b, a
            ld a, (V_PORT03)
            out (P_KBDROW), a
            ei
            ld a, b
            ret

; HL kiírása 4 hexa jeggyel
prhex:      ld de, numbuf
            ld a, h
            call .byte
            ld a, l
            call .byte
            xor a
            ld (de), a
            ld hl, numbuf
            jp prstr
.byte:      push af
            rrca
            rrca
            rrca
            rrca
            call .nib
            pop af
.nib:       and 0Fh
            add a, '0'
            cp '9' + 1
            jr c, .d
            add a, 7
.d:         ld (de), a
            inc de
            ret

; SID regiszterek nullázása
sid_reset:  ld b, SID_REGS
            ld c, REG_VSID
.l:         ld a, c
.psel1:      out (0), a
            xor a
.pdat1:      out (0), a
            inc c
            djnz .l
            ret

; ---- 6502 memória ----------------------------------------------------------
; RT: lefoglalatlan lap -> ZEROPG (nullák), $D0-$DF -> IOSH. WT: 0 (lassú út).
mem_init:
            ld hl, RT
.rt:        ld (hl), ZEROPG >> 8
            inc l
            jr nz, .rt
            ld hl, WT
.wt:        ld (hl), 0
            inc l
            jr nz, .wt
            ld hl, RT + 0D0h
            ld b, 16
.io:        ld (hl), IOSH >> 8
            inc l
            djnz .io
            ld a, ZPG >> 8
            ld (RT + 0), a
            ld (WT + 0), a
            ld a, STKPG >> 8
            ld (RT + 1), a
            ld (WT + 1), a
            ld hl, ZPG              ; ZPG, STKPG, ZEROPG, IOSH nullázása
            ld de, ZPG + 1
            ld bc, 4 * 256 - 1
            ld (hl), 0
            ldir
            xor a
            ld (INV + (ZPG >> 8)), a
            inc a
            ld (INV + (STKPG >> 8)), a
            ; a lapkészlet: a zene fölött a memória tetejéig (a kártya lapjai)
            ld hl, pool_ranges
            ld a, (sidend + 1)
            inc a
            ld (hl), a
            inc hl
            ld a, 0FFh
            ld (hl), a
            dec hl
            cp (hl)                 ; üres tartomány?
            jr nc, .r2
            ld (hl), 1              ; üres: 1 > 0
            inc hl
            ld (hl), 0
            dec hl
.r2:        inc hl
            inc hl
            ld (hl), 0              ; a lista vége
            ld hl, pool_ranges
            ld (pool_ptr), hl
            ld a, 1
            ld (pool_cur), a
            xor a
            ld (pool_end), a
            ret

; lap foglalása a 6502 A. lapjához: A = a Z80-as lap (Z = 1: elfogyott)
; megőrzi: BC, DE
alloc_page:
            push de
            push bc
            ld e, a
.try:       ld a, (pool_end)
            ld hl, pool_cur
            cp (hl)
            jr nc, .ok              ; cur <= end
            ld hl, (pool_ptr)
.next:      ld a, (hl)
            or a
            jr z, .fail
            ld (pool_cur), a
            inc hl
            ld a, (hl)
            ld (pool_end), a
            inc hl
            ld (pool_ptr), hl
            jr .try
.ok:        ld a, (hl)
            ld d, a
            inc a
            jr nz, .noend           ; 0FFh után vége a tartománynak
            ld (pool_end), a        ; (0 < 1)
            inc a
.noend:     ld (pool_cur), a
            ld h, d                 ; a lap nullázása
            ld l, 0
            ld b, l
.z:         ld (hl), b
            inc l
            jr nz, .z
            ld h, RT >> 8
            ld l, e
            ld (hl), d
            inc h
            ld (hl), d              ; WT = RT + 256
            ld h, INV >> 8
            ld l, d
            ld (hl), e
            ld a, d
            or a
            pop bc
            pop de
            ret
.fail:      xor a
            pop bc
            pop de
            ret

; a .sid adatainak bemásolása a 6502 lapjaira; Cy = 1: nincs elég memória
load_image:
            ; A zene a pufferben marad: annyival feljebb csúszik (< 256 bájt), hogy
            ; a Z80-as cím alsó bájtja a 6502-es címével egyezzen. Így a lapjai a
            ; Z80 memóriájában is folytonosak (a PC INC DE-vel léptethető).
            ld a, (load_addr)
            ld hl, data_ptr
            sub (hl)
            ld c, a
            ld b, 0                 ; BC = eltolás
            ld hl, (data_ptr)
            add hl, bc
            ld (img_z80), hl
            ld a, c
            or a
            jr z, .nomove
            ld hl, (data_ptr)
            ld de, (data_len)
            add hl, de
            dec hl                  ; a forrás vége
            push hl
            add hl, bc
            ex de, hl               ; DE = a cél vége
            pop hl
            ld bc, (data_len)
            lddr
.nomove:    ld hl, (img_z80)        ; az első lap eleje a zenéig: 0
            ld a, l
            or a
            jr z, .nz1
            ld b, a
            ld l, 0
.z1:        ld (hl), 0
            inc l
            djnz .z1
.nz1:       ld hl, (img_z80)
            ld de, (data_len)
            add hl, de
            ld (sidend), hl
            ld a, l                 ; az utolsó lap maradéka: 0
            or a
            jr z, .nz2
.z2:        ld (hl), 0
            inc l
            jr nz, .z2
.nz2:       call mem_init
            ld hl, (load_addr)
            ld c, h                 ; C = 6502-es lap
            ld de, (data_len)
            add hl, de
            dec hl
            ld a, h
            ld (img_last), a
            ld a, (img_z80 + 1)
            ld b, a                 ; B = Z80-as lap
.pg:        ld a, c
            cp 2
            jr c, .skip             ; a nullás lap és a verem helye fix
            ld h, INV >> 8
            ld l, b
            ld (hl), c
            call is_iopage
            jr z, .skip             ; $D4-$D7: SID
            ld h, RT >> 8
            ld l, c
            ld (hl), b
            inc h
            ld (hl), b
.skip:      ld a, (img_last)
            cp c
            jr z, .done
            inc c
            inc b
            jr .pg
.done:      or a
            ret

; Z = 1, ha az A. lap a SID I/O tartománya ($D4-$D7)
is_iopage:  cp 0D4h
            jr c, .no
            cp 0D8h
            jr nc, .no
            cp a
            ret
.no:        or 1
            ret

; a kernal IT-kezelő kilépési pontjai: PLA TAY PLA TAX PLA RTI
install_stubs:
            ld hl, 0EA31h
            call .stub
            ld hl, 0EA81h
            call .stub
            ld hl, 0FEBCh
.stub:      ld a, h                 ; csak ha a lap üres (nem a zenéé)
            ld d, WT >> 8
            ld e, a
            ld a, (de)
            or a
            ret nz                  ; a zene lapja: nem nyúlunk hozzá
            ld a, h
            push hl
            call alloc_page
            pop hl
            ret z
            ld d, a
            ld e, l
            ld hl, stub_code
            ld bc, 6
            ldir
            ret
stub_code:  db 68h, 0A8h, 68h, 0AAh, 68h, 40h

; HL = a 6502-es (HL) szó
rd16:       ld a, l
            ld l, h
            ld h, RT >> 8
            ld h, (hl)
            ld l, a
            ld a, (hl)
            inc l
            ld h, (hl)
            ld l, a
            ret

; ---- a 6502-es kód hívása ------------------------------------------------
; JSR-ként: HL = cím, A = időkorlát (képkocka)
call_jsr:   call set_wd
            ld a, (rS)
            ld (stop_s), a
            sub 2
            ld (rS), a
            jr emu_run
; IT-ként: HL = cím; play_mode 1: PC, P; 2: PC, P, A, X, Y (kernal)
call_irq:   ld a, 8
            call set_wd
            ld a, (rS)
            ld (stop_s), a
            ld e, a
            ld d, STKPG >> 8
            xor a
            ld (de), a
            dec e
            ld (de), a
            dec e
            push hl
            call getp_saved
            pop hl
            ld (de), a
            dec e
            ld a, (play_mode)
            cp 2
            jr nz, .hw
            ld a, (rA)
            ld (de), a
            dec e
            ld a, (rX)
            ld (de), a
            dec e
            ld a, (rY)
            ld (de), a
            dec e
.hw:        ld a, e
            ld (rS), a
            ld a, 04h               ; I = 1
            ld (fI), a
            jr emu_run
getp_saved: ld a, (rF)
            ld l, a
            push hl
            pop af
            jp getp

; A = időkorlát (időzítő-IT-ben)
set_wd:     ld (irq_handler.wd_lim + 1), a
            ld a, (ticks)
            ld (wd_start), a
            ld a, 1
            ld (emu_on), a
            ret

; HL = a 6502-es PC; a regiszterek a változókból
emu_run:    ld (emu_sp), sp
            ld e, l
            ld l, h
            ld h, RT >> 8
            ld d, (hl)
            ld a, (rA)
            ld b, a
            ld a, (rX)
            ld ixl, a
            ld a, (rY)
            ld ixh, a
            ld c, OPHI >> 8         ; állandó a futás alatt (az elágazás táblája)
            ld a, (rF)
            ld l, a
            push hl
            pop af
            jp emu_next

emu_exit:   ld a, 0                 ; (a jelzők megmaradnak)
            jr emu_save
emu_brk:    ld a, 1
            jr emu_save
emu_timeout:
            ld a, 2
emu_save:   push af
            pop hl                  ; H = állapot, L = jelzők
            xor a
            ld (emu_on), a
            ld a, l
            ld (rF), a
            ld a, h
            ld (emu_status), a
            ld a, b
            ld (rA), a
            ld a, ixl
            ld (rX), a
            ld a, ixh
            ld (rY), a
            ret

; ---- írás lassú útja: L = a 6502-es lap, A = alsó bájt ----------------------
; Kimenet: HL = írható Z80-as cím, A = L (a hívó LD L,A-t hajt végre)
wslow_A:    ld h, a                 ; gyors út: STA a SID-be ($D400-$D7FF)
            ld a, l
            and 0FCh
            cp 0D4h
            jr nz, .gen
            ld a, h
            and 1Fh
            cp SID_REGS
            jr nc, .scr
.sw:        jp .inl                 ; NTSC zenénél: jp .conv (play_file írja át)
.inl:       add a, REG_VSID         ; PAL: közvetlenül a kártyára
.psel4:     out (0), a
            ld a, b
.pdat4:     out (0), a
            jr .scr
.conv:      push bc
            ld h, b
            call sid_out
            pop bc
.scr:       ld hl, SCRATCH
            ld a, l
            ret
.gen:       ld a, h
            push af
            ld a, b
            jr wslow_v
wslow_X:    push af
            ld a, ixl
            jr wslow_v
wslow_Y:    push af
            ld a, ixh
            jr wslow_v
wslow_SAX:  push af
            ld a, b
            and ixl
wslow_v:    ld h, a                 ; H = az írandó érték
            pop af
            push bc
            ld c, a                 ; C = alsó bájt
            ld a, l
            cp 0D0h
            jp c, ws_ram
            cp 0E0h
            jp nc, ws_ram
            cp 0DCh                 ; CIA1 A időzítő ($DC04/$DC05): a tempó
            jr nz, .nocia
            ld a, c
            and 0Fh
            cp 4
            jr z, .c4
            cp 5
            jr nz, ws_scratch
            ld a, h
            ld (cia_hi), a
            jr .cd
.c4:        ld a, h
            ld (cia_lo), a
.cd:        ld a, 1
            ld (cia_dirty), a
            jr ws_scratch
.nocia:     ld a, l
            call is_iopage
            jr nz, ws_scratch
            ld a, c
            and 1Fh
            cp SID_REGS
            jr nc, ws_scratch
            call sid_out
ws_scratch: pop bc
            ld hl, SCRATCH
            ld a, l
            ret
; STA $D4xx gyors útja (a generált kódból): A = alsó bájt, B = érték.
; Elrontja: A, H, L
sid_fast:   and 1Fh
            cp SID_REGS
            ret nc
.sw:        jp .inl                 ; NTSC zenénél: jp .conv (play_file írja át)
.inl:       add a, REG_VSID
.psel:      out (0), a
            ld a, b
.pdat:      out (0), a
            ret
.conv:      push bc
            ld h, b
            call sid_out
            pop bc
            ret

; A = SID-regiszter (0..24), H = érték -> a kártya vSID-je.
; NTSC zenénél a hangmagasság (0/1, 7/8, 14/15) a PAL órajelű vSID-hez
; átszámolva: f * 1022727 / 985248 = f * 1,03804 (f + f/32 + f/128 - f/1024).
; Elrontja: A, B, C, H, L
sid_out:    ld c, a
            ld a, (ntsc)
            or a
            jr z, .raw
            ld a, c
            cp 16
            jr nc, .raw
            ld b, 0
            push hl
            ld hl, freq_lo
            add hl, bc
            ld a, (hl)              ; a hangmagasság alsó bájtjának regisztere
            pop hl
            cp 0FFh
            jr z, .raw
            push de
            ld e, a
            ld a, h
            ld hl, sid_sh           ; a megírt bájt az árnyékba
            add hl, bc
            ld (hl), a
            ld c, e
            ld hl, sid_sh
            add hl, bc
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a                 ; HL = f
            ld d, h
            ld e, l
            srl d                   ; f / 32
            rr e
            srl d
            rr e
            srl d
            rr e
            srl d
            rr e
            srl d
            rr e
            add hl, de
            jr c, .max
            srl d                   ; f / 128
            rr e
            srl d
            rr e
            add hl, de
            jr c, .max
            srl d                   ; f / 1024
            rr e
            srl d
            rr e
            srl d
            rr e
            or a
            sbc hl, de
            jr .out
.max:       ld hl, 0FFFFh
.out:       pop de
            ld a, c
            add a, REG_VSID
.psel2:     out (0), a
            ld a, l
.pdat2:     out (0), a
            ld a, c
            add a, REG_VSID + 1
.psel3:     out (0), a
            ld a, h
.pdat3:     out (0), a
            ret
.raw:       ld a, c
            add a, REG_VSID
.psel:      out (0), a
            ld a, h
.pdat:      out (0), a
            ret
freq_lo:    db 0, 0, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 7, 7, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 14, 14

; olvasás-módosítás-írás: az I/O-ba nem ír
wslow_R:    push bc
            ld c, a
            ld a, l
            cp 0D0h
            jr c, ws_ram
            cp 0E0h
            jp c, ws_scratch
ws_ram:     ld a, l
            call alloc_page
            jp z, ws_scratch
            ld h, a
            ld l, c
            ld a, c
            pop bc
            ret

; ---- a kártya fájlkezelése (REG_USB_MSC_CMD, paraméterek az IO RAM-ban) -------
; az IO RAM ($D800-$DFFF) a kártya slotjának IOMEM-jében: U3 = IOMEM, a 03h
; port 6-7. bitje a slot; közben tiltott IT
io_on:      di
            push bc
            ld a, (V_PAGING)
            or 0C0h
            out (P_PAGING), a
            ld a, (V_PORT03)
            and 3Fh
            ld b, a
            ld a, (card_slot6)
            or b
            out (P_KBDROW), a
            pop bc
            ret
io_off:     ld a, (V_PAGING)
            out (P_PAGING), a
            ld a, (V_PORT03)
            out (P_KBDROW), a
            ei
            ret

; A = parancs; a kártya a regisztert 0-ra (kész) vagy hibakód + 80h-ra állítja
; ki: A = 0 és Z = 1, ha sikerült
card_cmd:   push bc
            ld b, a
            ld a, (card_base)
            ld c, a
            ld a, REG_MSC
            out (c), a
            inc c
            out (c), b
            dec c
.p:         ld a, REG_MSC
            out (c), a
            inc c
            in a, (c)
            dec c
            or a
            jr z, .ok
            cp 80h
            jr c, .p
.ok:        pop bc
            or a
            ret

; HL -> az IO RAM paraméterterülete (4 bájtos fájl/könyvtár azonosító)
put_handle: call io_on
            ld de, IO_PARAM
            ld bc, 4
            ldir
            jp io_off

; ---- fájlválasztó ---------------------------------------------------------
; A lista a sidbuf-ban: ENT_SIZE bájtos elemek (0: 1 = könyvtár, 1..: a név,
; 0-val zárva). Az első elem mindig a "..". A lejátszás felülírja, utána
; újraolvassuk.
ENT_SIZE    equ 48
ENT_MAX     equ 250
LIST_ROW    equ 3               ; a lista első sora a képernyőn
LIST_ROWS   equ 20
NAME_COLS   equ 23              ; a név a 3-25. oszlopban
KIND_COL    equ 28              ; "PSID" / "RSID" a 28-31. oszlopban
K_UP        equ 1
K_DOWN      equ 2
K_LEFT      equ 3
K_RIGHT     equ 4
K_ENTER     equ 5
K_ESC       equ 6
K_DRIVE     equ 7

browser:    xor a
            ld (cur), a
.rescan:    call scan_dir
            ld a, (ent_count)       ; a kurzor a listán belül
            dec a
            ld hl, cur
            cp (hl)
            jr nc, .draw
            ld (hl), a
.draw:      call calc_top
            ld (top), a
            call draw_all
            call wait_release
            xor a
            ld (last_key), a
.loop:      halt
            call get_key
            ld hl, last_key
            cp (hl)
            jr z, .same
            ld (hl), a
            ld hl, key_rep
            ld (hl), 15             ; az ismétlés késleltetése
            jr .act
.same:      cp K_UP                 ; csak a fel/le ismétlődik
            jr z, .rep
            cp K_DOWN
            jr nz, .loop
.rep:       ld hl, key_rep
            dec (hl)
            jr nz, .loop
            ld (hl), 3
.act:       or a
            jr z, .loop
            cp K_ESC
            jr z, .quit
            cp K_ENTER
            jr z, .enter
            cp K_DRIVE
            jr z, .drive
            ld c, a                 ; mozgás: az új kurzor A-ba
            ld a, (ent_count)
            dec a
            ld b, a                 ; B = az utolsó elem
            ld a, (cur)
            dec c
            jr nz, .n1
            or a                    ; fel
            jr z, .loop
            dec a
            jr .move
.n1:        dec c
            jr nz, .n2
            cp b                    ; le
            jr nc, .loop
            inc a
            jr .move
.n2:        dec c
            jr nz, .n3
            sub LIST_ROWS           ; balra: egy lappal feljebb
            jr nc, .move
            xor a
            jr .move
.n3:        add a, LIST_ROWS        ; jobbra: egy lappal lejjebb
            jr c, .last
            cp b
            jr c, .move
.last:      ld a, b
.move:      ld hl, cur
            cp (hl)
            jr z, .loop
            ld c, (hl)              ; C = a régi kurzor
            ld (hl), a
            call calc_top
            ld hl, top
            cp (hl)
            jr z, .mark
            ld (hl), a              ; másik lap: újrarajzolás
            call draw_all
            jp .loop
.mark:      ld a, c                 ; ugyanaz a lap: csak a jelölő
            ld e, ' '
            call draw_mark
            ld a, (cur)
            ld e, '>'
            call draw_mark
            jp .loop
.quit:      call unmap_card
            call screen_off         ; (törli is a képernyőt)
            ld hl, 0
            ret
.drive:     ld a, REG_DRIVE         ; a következő meghajtó: USB, PSRAM, flash
            call reg_read
            inc a
            cp 3
            jr c, .dok
            xor a
.dok:       ld b, a
            ld a, REG_DRIVE
            call reg_write
            jp browser
.enter:     call cur_entry          ; HL = az elem
            ld a, (hl)
            inc hl
            cp 1                    ; 1: könyvtár, a többi fájl (0 PSID, 2 RSID, 3 ?)
            jr nz, .file
            call set_name           ; könyvtár: belépünk
            call io_on
            ld hl, name_len
            ld de, IO_PARAM
            ld a, (hl)
            inc a
            ld c, a
            ld b, 0
            ldir
            call io_off
            ld a, 0Ch               ; MSC_CHDIR
            call card_cmd
            jp browser
.file:      call set_name
            xor a
            ld (song_req), a
.load:      call cls
            call load_file
            jr c, .err
            call play_file
            ld a, l
            cp 5                    ; dalváltás: újra beolvassuk a fájlt
            jr z, .load
            or a
            jp z, .rescan
.err:       ld hl, s_anykey         ; hiba: az üzenet a képernyőn marad
            call prstr
.wr:        halt                    ; előbb minden gomb fel (pl. az Enter)
            call any_key
            jr nz, .wr
.wk:        halt                    ; aztán bármelyik gomb (vagy joystick)
            call any_key
            jr z, .wk
            call wait_release
            jp .rescan

; a HL-en kezdődő (0-végű) név -> namebuf, name_len
set_name:   ld de, namebuf
            ld b, 0
.l:         ld a, (hl)
            ld (de), a
            or a
            jr z, .e
            inc hl
            inc de
            inc b
            jr .l
.e:         ld a, b
            ld (name_len), a
            ret

; HL = a kurzor alatti elem; cur_entry / A. elem: nth_entry
cur_entry:  ld a, (cur)
nth_entry:  ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl              ; * 16
            ld d, h
            ld e, l
            add hl, hl
            add hl, de              ; * 48
            assert ENT_SIZE == 48
            ld de, sidbuf
            add hl, de
            ret

; ---- az adatlap (32 oszlop, abszolút sorokban, hogy semmi ne törjön) -------
SONG_ROW    equ 13
INK_VAR     equ 0B4Dh           ; a ROM editor tinta- és papírszíne (palettaszám)
PAPER_VAR   equ 0B4Eh

PAL_LIST:   db 00h, 50h, 54h, 10h   ; lista: fekete, zöld, sárga, sötétzöld
PAL_PLAY:   db 00h, 50h, 54h, 41h   ; lejátszás: fekete, zöld, sárga, kék
C_BLACK     equ 0
C_GREEN     equ 1
C_YELLOW    equ 2
C_BLUE      equ 3
TIME_ROW    equ 16

; HL -> a 4 palettaregiszter
set_palette:
            push bc
            ld c, 60h
            ld b, 4
.p:         ld a, (hl)
            out (c), a
            inc hl
            inc c
            djnz .p
            pop bc
            ret
; tinta: L, papír: H (palettaszámok)
colors:     ld (INK_VAR), hl
            ret
; B oszlop, C sor -> kurzor; a színeket nem bántja
at:         jp gotoxy

draw_info:  ld hl, PAL_PLAY
            call set_palette
            ld hl, C_BLACK * 256 + C_GREEN
            call colors
            call cls
            ; 1. sor: fejléc, kék sávban sárgával
            ld bc, 0101h
            call at
            ld hl, C_BLUE * 256 + C_YELLOW
            call colors
            ld hl, s_head
            call center
            ; 3-5. sor: a zene neve sárgával, szerző és kiadás zölddel, középen
            ld hl, C_BLACK * 256 + C_YELLOW
            call colors
            ld bc, 0103h
            call at
            ld hl, sidbuf + 16h
            call center
            ld hl, C_BLACK * 256 + C_GREEN
            call colors
            ld bc, 0104h
            call at
            ld hl, sidbuf + 36h
            call center
            ld bc, 0105h
            call at
            ld hl, sidbuf + 56h
            call center
            ; 7. sor: elválasztó (kék vonal)
            ld hl, C_BLACK * 256 + C_BLUE
            call colors
            ld bc, 0107h
            call at
            ld hl, s_line
            call center
            ; 9-11. sor: típus, óra, cím (zöld címke, sárga érték)
            ld bc, 0309h
            call at
            call label
            ld hl, s_kind
            call prstr
            call value
            ld de, entbuf           ; "PSID" a fejléc első 4 bájtjából
            ld hl, sidbuf
            ld bc, 4
            ldir
            xor a
            ld (de), a
            ld hl, entbuf
            call prstr
            ld bc, 030Ah
            call at
            call label
            ld hl, s_clock
            call prstr
            call value
            call clock_name
            call prstr
            ld bc, 030Bh
            call at
            call label
            ld hl, s_info
            call prstr
            call value
            ld c, '$'
            call putc
            ld hl, (load_addr)
            call prhex
            ld hl, s_dash
            call prstr
            ld hl, (load_addr)
            ld de, (data_len)
            add hl, de
            dec hl
            call prhex
            ld a, (sidbuf)          ; RSID: nincs dal-sáv, idő és súgó
            cp 'R'
            jr z, .done
            ; 13. sor: a dal, sárga sávban feketével: "DAL  3 / 23"
            ld de, entbuf
            ld hl, s_song
            call copy_str
            ld a, (song)
            call put_dec
            ld hl, s_of
            call copy_str
            ld a, (songs)
            call put_dec
            xor a
            ld (de), a
            ld hl, C_YELLOW * 256 + C_BLACK
            call colors
            ld bc, 0100h + SONG_ROW
            call at
            ld hl, entbuf
            call center
            ; 16. sor: az idő
            xor a
            ld (secs), a
            ld (mins), a
            call show_time
            ; 22-23. sor: súgó
            ld hl, C_BLACK * 256 + C_GREEN
            call colors
            ld bc, 0116h
            call at
            ld hl, s_keys
            call prstr
.done:      ld hl, C_BLACK * 256 + C_GREEN
            jp colors
label:      ld hl, C_BLACK * 256 + C_GREEN
            jp colors
value:      ld hl, C_BLACK * 256 + C_YELLOW
            jp colors

; az eltelt idő a TIME_ROW. sorba, középre: "Idő:  1:23" (sárga)
show_time:  ld hl, C_BLACK * 256 + C_GREEN
            call colors
            ld bc, 0B00h + TIME_ROW
            call at
            ld hl, s_time
            call prstr
            ld hl, C_BLACK * 256 + C_YELLOW
            call colors
            ld a, (mins)
            call pr2
            ld c, ':'
            call putc
            ld a, (secs)
            call pr2
            ld hl, C_BLACK * 256 + C_GREEN
            jp colors
; A (0..99) két jeggyel
pr2:        ld b, '0' - 1
.t:         inc b
            sub 10
            jr nc, .t
            add a, '0' + 10
            push af
            ld c, b
            call putc
            pop af
            ld c, a
            jp putc

; HL = az órajel neve a fejléc szerint
clock_name: xor a                   ; v2+ fejléc: a $77. bájt 2-3. bitje
            ld b, a
            ld a, (sidbuf + 5)
            cp 2
            jr c, .k
            ld a, (sidbuf + 7)
            cp 7Ch
            jr c, .k
            ld a, (sidbuf + 77h)
            rrca
            rrca
            and 3
            ld b, a
.k:         ld a, b
            add a, a
            ld e, a
            ld d, 0
            ld hl, clock_names
            add hl, de
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            ret

; a HL-en kezdődő szöveg (0-ig, legfeljebb 32) középre igazítva, 32 oszlopon,
; az aktuális színekkel (a papírszín a sáv)
center:     push hl
            ld b, 32
            call field_len
            pop hl
            jp bar32

; A = a HL-en kezdődő név hossza (0-ig, legfeljebb B)
field_len:  ld c, 0
.l:         ld a, (hl)
            or a
            jr z, .e
            inc hl
            inc c
            djnz .l
.e:         ld a, c
            ret

; A hosszú szöveg (HL) középre igazítva, inverz, 32 oszlopos sávban
bar32:      push hl
            ld b, a
            ld a, 32
            sub b
            srl a                   ; bal oldali szóközök
            ld b, a
            pop hl
            ld e, 0                 ; E = kiírt karakterek
.p:         ld a, b
            or a
            jr z, .s
            ld c, ' '
            call putc
            inc e
            dec b
            jr .p
.s:         ld a, e
            cp 32
            jr nc, .f
            ld a, (hl)
            or a
            jr z, .f
            call printable
            ld c, a
            call putc
            inc hl
            inc e
            jr .s
.f:         ld a, e                 ; jobb oldal: szóközök a sáv végéig
            cp 32
            jr nc, .d
            ld c, ' '
            call putc
            inc e
            jr .f
.d:         ret

; PSID szövegmező (HL, legfeljebb 32 karakter, 0-ig) kiírása
pr_field:   ld b, 32
.l:         ld a, (hl)
            or a
            ret z
            call printable
            ld c, a
            call putc
            inc hl
            djnz .l
            ret

; A -> kiírható karakter (a vezérlőkódok és a 7Fh fölöttiek helyett '?')
printable:  cp 20h                  ; (a TVC ékezetes betűi, $80-$98, maradnak)
            jr c, .q
            cp 7Fh
            ret c
            cp 80h
            jr c, .q
            cp 99h
            ret c
.q:         ld a, '?'
            ret

; C karakter kiírása (megőrzi: BC, DE, HL)
putc:       push hl
            push de
            push bc
            rst 30h
            db 21h
            pop bc
            pop de
            pop hl
            ret

; tinta és papír cseréje (inverz be / ki)
inverse:    push hl
            ld hl, (INK_VAR)        ; L = tinta, H = papír
            ld a, l
            ld l, h
            ld h, a
            ld (INK_VAR), hl
            pop hl
            ret

; HL szöveg (0-ig) másolása DE-re (DE a végére mutat)
copy_str:   ld a, (hl)
            or a
            ret z
            ld (de), a
            inc hl
            inc de
            jr copy_str

; A (1..255) tízes számrendszerben a DE-re (DE a végére mutat)
put_dec:    push de
            ld l, a
            ld h, 0
            ld de, numbuf + 5
            xor a
            ld (de), a
.l:         dec de
            push de
            ld c, 10
            call div16
            pop de
            add a, '0'
            ld (de), a
            ld a, h
            or l
            jr nz, .l
            ex de, hl
            pop de
            jp copy_str

clock_names: dw s_clk0, s_clk1, s_clk2, s_clk3

; A = a kurzor lapjának első eleme
calc_top:   ld a, (cur)
            ld b, 0
.l:         sub LIST_ROWS
            jr c, .e
            inc b
            jr .l
.e:         ld a, b                 ; lap * LIST_ROWS
            add a, a
            add a, a
            add a, b
            add a, a
            add a, a
            assert LIST_ROWS == 20
            ret

cls:        rst 30h
            db 05h                  ; VIDEO CLS (az editort is alaphelyzetbe teszi)
            ret
; kurzor a B. oszlopba, C. sorba (1-től)
gotoxy:     rst 30h
            db 23h                  ; EDITOR CU-POS
            ret

; a jelölő (E karakter) az A. elem sorába
draw_mark:  ld hl, top
            sub (hl)
            add a, LIST_ROW
            ld c, a
            ld b, 1
            push de
            call gotoxy
            pop de
            ld c, e
            rst 30h
            db 21h
            ret

draw_all:   ld hl, PAL_LIST
            call set_palette
            ld hl, C_BLACK * 256 + C_GREEN
            call colors
            call cls
            ld hl, s_title
            call prstr
            ld a, REG_DRIVE
            call reg_read
            cp 4
            jr c, .dn
            ld a, 3
.dn:        add a, a                ; 8 karakteres nevek
            add a, a
            add a, a
            ld e, a
            ld d, 0
            ld hl, s_drives
            add hl, de
            call prstr
            ld bc, 0118h            ; a súgó a 24. sorban
            call gotoxy
            ld hl, s_help
            call prstr
            ld a, (scan_err)
            or a
            jr z, .list
            ld bc, 0100h + LIST_ROW + 2
            call gotoxy
            ld hl, s_noread
            jp prstr
.list:      ld a, (top)
            ld (draw_i), a
            ld a, LIST_ROW
            ld (draw_row), a
.row:       ld a, (draw_i)
            ld hl, ent_count
            cp (hl)
            ret nc
            ld a, (draw_row)
            cp LIST_ROW + LIST_ROWS
            ret nc
            ld c, a
            ld b, 1
            call gotoxy
            ld a, (draw_i)
            ld hl, cur
            cp (hl)
            ld c, ' '
            jr nz, .m
            ld c, '>'
.m:         rst 30h
            db 21h
            ld a, (draw_i)
            call nth_entry
            ld a, (hl)
            inc hl
            ld (draw_dir), a
            cp 1                    ; 1: könyvtár
            ld c, ' '
            jr nz, .b
            ld c, '['
.b:         push hl
            rst 30h
            db 21h
            ld a, (draw_dir)
            call set_ink
            pop hl
            ld b, NAME_COLS
.ch:        ld a, (hl)
            or a
            jr z, .end
            cp 20h
            jr c, .q
            cp 7Fh
            jr c, .pr
.q:         ld a, '?'
.pr:        push hl
            push bc
            ld c, a
            rst 30h
            db 21h
            pop bc
            pop hl
            inc hl
            djnz .ch
.end:       ld a, (draw_dir)
            cp 1
            jr nz, .kind
            ld c, ']'
            rst 30h
            db 21h
            jr .nx
.kind:      push af                 ; fájl: a típus a sor végére
            ld a, (draw_row)
            ld c, a
            ld b, KIND_COL
            call gotoxy
            pop af
            push af
            call set_ink            ; RSID: sötétzöld
            pop af
            ld hl, s_psid
            or a
            jr z, .pk
            ld hl, s_rsid
            cp 2
            jr z, .pk
            ld hl, s_qsid
.pk:        call prstr
            ld a, (norm_ink)        ; vissza a normál tintára
            ld (INK_VAR), a
.nx:        ld hl, draw_i
            inc (hl)
            ld hl, draw_row
            inc (hl)
            jp .row

; a listaelem típusa szerinti tinta: RSID (2) -> sötétzöld (3. paletta)
set_ink:    cp 2
            ld a, (norm_ink)
            jr nz, .s
            ld a, 3
.s:         ld (INK_VAR), a
            ret

; A képernyő a program alatt, függetlenül attól, hogyan indult: 4 színű mód
; (32 oszlop), paletta: 0 fekete, 1 zöld, 2 vörös, 3 sötétzöld; tinta 1,
; papír 0, fekete keret. Kilépéskor az eredeti mód (a ROM VID-MODE a palettát
; is a saját alapértékére állítja), tinta, papír és keret vissza.
V_MODE      equ 0B73h           ; a video üzemmód (0: 2, 1: 4, 2: 16 színű)
V_BORDER    equ 0B4Fh
P_BORDER    equ 00h

screen_on:  ld a, (V_MODE)
            ld (orig_mode), a
            ld hl, (INK_VAR)        ; tinta, papír
            ld (orig_ink), hl
            ld a, (V_BORDER)
            ld (orig_border), a
            ld c, 1                 ; VIDEO VID-MODE: 4 színű mód (törli is)
            rst 30h
            db 04h
            ld hl, PAL_LIST         ; I G R B a 6., 4., 2., 0. biten
            call set_palette
            ld hl, 0001h            ; tinta 1, papír 0
            ld (INK_VAR), hl
            ld a, 1
            ld (norm_ink), a
            xor a
            ld (V_BORDER), a
            out (P_BORDER), a
            ret
screen_off: ld a, (orig_mode)
            ld c, a
            rst 30h
            db 04h
            ld hl, (orig_ink)
            ld (INK_VAR), hl
            ld a, (orig_border)
            ld (V_BORDER), a
            out (P_BORDER), a
            ret

; A = a lenyomott billentyű (K_..., 0 = nincs)
; a 8. sor a kurzornyilak és az 1. joystick, a 9. sor a 2. joystick:
; 1. bit fel, 2. le, 6. balra, 5. jobbra, 3. tűz
get_key:    ld c, 8
            call .joy
            ret nz
            ld c, 9
            call .joy
            ret nz
            jr .keys
.joy:       call read_row
            ld b, a
            ld a, K_UP
            bit 1, b
            jr z, .hit
            inc a
            bit 2, b
            jr z, .hit
            inc a
            bit 6, b
            jr z, .hit
            inc a
            bit 5, b
            jr z, .hit
            ld a, K_ENTER
            bit 3, b                ; tűz: indítás
            jr z, .hit
            xor a
            ret
.hit:       or a                    ; Z = 0: van billentyű
            ret
.keys:      ld c, 5
            call read_row
            bit 4, a
            ld a, K_ENTER
            ret z
            ld c, 7
            call read_row
            bit 3, a
            ld a, K_ESC
            ret z
            ld c, 4
            call read_row
            bit 1, a
            ld a, K_DRIVE
            ret z
            xor a
            ret
; Z = 0, ha a billentyűzet (vagy joystick) bármelyik gombja le van nyomva
any_key:    ld c, 0
.r:         push bc
            call read_row
            pop bc
            inc a                   ; FFh: nincs lenyomva
            ret nz
            inc c
            ld a, c
            cp 10
            jr c, .r
            xor a
            ret
wait_release:
            halt
            call get_key
            or a
            jr nz, wait_release
            ret

; a kártya gyors RAM-lapjai a U2-be és a U3-ba (a TVC saját RAM-ja helyett)
map_card:   ld b, CARD_PG2
            ld a, REG_MEM_P2
            call reg_write
            ld b, CARD_PG3
            ld a, REG_MEM_P3
            jp reg_write
unmap_card: ld b, 0FFh
            ld a, REG_MEM_P2
            call reg_write
            ld b, 0FFh
            ld a, REG_MEM_P3
            jp reg_write

; a kártya A. regiszterének olvasása (A-ba) / írása (B)
reg_read:   push bc
            ld b, a
            ld a, (card_base)
            ld c, a
            out (c), b
            inc c
            in a, (c)
            pop bc
            ret
reg_write:  push bc
            push af
            ld a, (card_base)
            ld c, a
            pop af
            out (c), a
            inc c
            out (c), b
            pop bc
            ret

; az aktuális könyvtár beolvasása a listába: "..", könyvtárak, .sid fájlok
scan_dir:   xor a
            ld (scan_err), a
            ld hl, sidbuf           ; az első elem: ".."
            ld (hl), 1
            inc hl
            ld (hl), '.'
            inc hl
            ld (hl), '.'
            inc hl
            ld (hl), 0
            ld a, 1
            ld (ent_count), a
            call io_on
            ld hl, s_dot
            ld de, IO_PARAM
            ld bc, 3
            ldir
            call io_off
            ld a, 05h               ; MSC_OPENDIR
            call card_cmd
            jr z, .open
            ld a, 1
            ld (scan_err), a
            ret
.open:      call io_on
            ld hl, IO_RESULT
            ld de, dirh
            ld bc, 4
            ldir
            call io_off
.next:      ld a, (ent_count)
            cp ENT_MAX
            jr nc, .close
            ld hl, dirh
            call put_handle
            ld a, 07h               ; MSC_READDIR
            call card_cmd
            jr nz, .close
            call io_on
            ld a, (IO_RESULT)
            or a
            jr z, .end
            cp ENT_SIZE - 1         ; a túl hosszú név kimarad
            jr c, .len
            call io_off
            jr .next
.len:       ld c, a
            ld b, 0
            ld hl, IO_RESULT + 1
            ld de, entbuf + 1
            ldir
            xor a
            ld (de), a
            ld a, (IO_ATTR)
            ld b, a
            call io_off
            ld a, b
            and 10h                 ; könyvtár
            jr z, .f
            ld a, (entbuf + 1)      ; a "." és a ".." kimarad
            cp '.'
            jr z, .next
            ld a, 1
            jr .add
.f:         ld hl, entbuf + 1
            call is_sid
            jr nz, .next
            call sid_kind           ; A = 0 PSID, 2 RSID, 3 egyéb
.add:       ld (entbuf), a
            ld a, (ent_count)
            call nth_entry
            ex de, hl
            ld hl, entbuf
            ld bc, ENT_SIZE
            ldir
            ld hl, ent_count
            inc (hl)
            jr .next
.end:       call io_off
.close:     ld hl, dirh
            call put_handle
            ld a, 06h               ; MSC_CLOSEDIR
            jp card_cmd

; az entbuf nevű fájl első 4 bájtja: A = 0 "PSID", 2 "RSID", 3 egyéb vagy hiba
sid_kind:   ld hl, entbuf + 1
            call set_name
            call file_open
            ld a, 3
            ret nz
            ld hl, fileh
            call put_handle
            call io_on
            ld hl, 4
            ld (IO_PARAM + 4), hl
            call io_off
            ld a, 03h               ; MSC_FREAD
            call card_cmd
            ld b, 3
            jr nz, .cl
            call io_on
            ld hl, (IO_RESULT)      ; 4 bájt jött?
            ld de, -4
            add hl, de
            ld a, h
            or l
            jr nz, .x
            ld hl, (IO_RESULT + 3)  ; "SI", "D"
            ld de, -('I' * 256 + 'S')
            add hl, de
            ld a, h
            or l
            jr nz, .x
            ld a, (IO_RESULT + 5)
            cp 'D'
            jr nz, .x
            ld a, (IO_RESULT + 2)
            ld b, 0
            cp 'P'
            jr z, .x
            ld b, 2
            cp 'R'
            jr z, .x
            ld b, 3
.x:         call io_off
.cl:        push bc
            call file_close
            pop bc
            ld a, b
            ret

; a namebuf nevű fájl megnyitása olvasásra (fileh); Z = 1: sikerült
file_open:  call io_on
            ld hl, IO_PARAM
            ld (hl), 01h            ; FA_READ
            inc hl
            ld (hl), 0
            inc hl
            ld a, (name_len)
            ld (hl), a
            inc hl
            ex de, hl
            ld hl, namebuf
            ld c, a
            ld b, 0
            ldir
            call io_off
            ld a, 01h               ; MSC_FOPENFILE
            call card_cmd
            ret nz
            call io_on
            ld hl, IO_RESULT
            ld de, fileh
            ld bc, 4
            ldir
            call io_off
            xor a
            ret
file_close: ld hl, fileh
            call put_handle
            ld a, 02h               ; MSC_FCLOSEFILE
            jp card_cmd

; Z = 1, ha a HL-en kezdődő (0-végű) név ".sid"-re végződik (kisbetű/nagybetű)
is_sid:     ld b, 0
.len:       ld a, (hl)
            or a
            jr z, .e
            inc hl
            inc b
            jr .len
.e:         ld a, b
            cp 5
            jr c, .no
            ld de, -4
            add hl, de
            ld de, s_ext
            ld b, 4
.c:         ld a, (hl)
            cp 'A'
            jr c, .lc
            cp 'Z' + 1
            jr nc, .lc
            or 20h
.lc:        ex de, hl
            cp (hl)
            ex de, hl
            ret nz
            inc hl
            inc de
            djnz .c
            ret                     ; Z = 1
.no:        or 1
            ret

; a namebuf nevű fájl beolvasása a sidbuf-ba; Cy = 1: hiba (kiírva)
; A $8000 feletti rész a kártya gyors RAM-jában van (CARD_PG2/CARD_PG3 a U2-ben
; és a U3-ban): a $C000 alatti rész az IO RAM-on át (FREAD, a U2 közben is
; látszik), a $C000 fölötti egyben, közvetlenül a kártya RAM-jába (FREAD_DEST).
load_file:  call map_card
            call io_on
            ld hl, IO_PARAM
            ld (hl), 01h            ; FA_READ
            inc hl
            ld (hl), 0
            inc hl
            ld a, (name_len)
            ld (hl), a
            inc hl
            ex de, hl
            ld hl, namebuf
            ld c, a
            ld b, 0
            ldir
            call io_off
            ld a, 01h               ; MSC_FOPENFILE
            call card_cmd
            jr z, .opened
            ld hl, s_notfound
            call prstr
            scf
            ret
.opened:    call io_on
            ld hl, IO_RESULT
            ld de, fileh
            ld bc, 4
            ldir
            ld hl, (IO_RESULT + 4)  ; a fájl mérete
            ld (fsize), hl
            ld hl, (IO_RESULT + 6)
            call io_off
            ld a, h                 ; 64 KB fölött biztosan túl nagy
            or l
            jp nz, .big
            ld hl, (fsize)
            ld de, sidbuf
            add hl, de
            jp c, .big
            ex de, hl               ; DE = a fájl vége a memóriában
            ld hl, BUF_END
            or a
            sbc hl, de
            jp c, .big
            ld (sidend), de
            ld hl, sidbuf
            ld (dest), hl
.rd:        ld hl, (sidend)         ; maradék = vég - dest; n = min(maradék,
            ld de, (dest)           ; CHUNK, $C000 - dest)
            or a
            sbc hl, de
            jp z, .done
            ld b, h
            ld c, l
            ld hl, 0C000h
            or a
            sbc hl, de
            jr z, .dst              ; $C000-tól: egyben a kártya RAM-jába
            call .min
            ld hl, CHUNK
            call .min
            push bc
            ld hl, fileh
            call put_handle
            call io_on
            pop bc
            push bc
            ld (IO_PARAM + 4), bc
            call io_off
            ld a, 03h               ; MSC_FREAD
            call card_cmd
            pop bc
            jr nz, .short
            call io_on
            ld hl, (IO_RESULT)
            or a
            sbc hl, bc
            jr nz, .shortio         ; kevesebbet adott, mint kértük
            ld hl, IO_RESULT + 2
            ld de, (dest)
            ldir
            ld (dest), de
            call io_off
            jr .rd
.dst:       push bc                 ; BC = a maradék, a $C000 fölötti rész
            ld hl, fileh
            call put_handle
            call io_on
            pop bc
            push bc
            ld (IO_PARAM + 4), bc   ; 3 bájtos hossz
            xor a
            ld (IO_PARAM + 6), a
            ld hl, (dest)           ; cél: CARD_PG3 * 16K + (dest - $C000),
            ld (IO_PARAM + 7), hl   ; a 15. lapnál ez 3:dest
            ld a, 3
            ld (IO_PARAM + 9), a
            assert CARD_PG3 == 15
            call io_off
            ld a, 09h               ; MSC_FREAD_DEST
            call card_cmd
            pop bc
            jr nz, .short
            ld hl, (dest)
            add hl, bc
            ld (dest), hl
.done:      call .close
            ld hl, (sidend)
            ld de, sidbuf + 7Ch     ; legalább egy fejléc
            or a
            sbc hl, de
            ret nc
            ld hl, s_badfile
            call prstr
            scf
            ret
.shortio:   call io_off
.short:     call .close
            ld hl, s_readerr
            call prstr
            scf
            ret
.big:       call .close
            ld hl, s_toolarge
            call prstr
            scf
            ret
; BC = min(BC, HL)
.min:       or a
            sbc hl, bc
            ret nc
            add hl, bc
            ld b, h
            ld c, l
            ret
.close:     ld hl, fileh
            call put_handle
            ld a, 02h               ; MSC_FCLOSEFILE
            jp card_cmd

            include "cpu6502.asm"

; ---- adatok ----------------------------------------------------------------
slot_order: db 20h, 30h, 40h, 10h, 0FFh     ; a kártya portjai: 1., 2., 3., 0. slot
s_crlf:     db 13, 10, 0
            include "strings.inc"   ; a magyar szövegek (tools/gen_strings.py)
s_drives:   db "USB", 0, 0, 0, 0, 0, "PSRAM", 0, 0, 0, "FLASH", 0, 0, 0, "DSK", 0
cur:        db 0
top:        db 0
ent_count:  db 0
scan_err:   db 0
last_key:   db 0
key_rep:    db 0
draw_i:     db 0
draw_row:   db 0
draw_dir:   db 0
norm_ink:   db 1
cps:        dw 50
cps_cnt:    dw 50
secs:       db 0
mins:       db 0
orig_mode:  db 1
orig_ink:   dw 0001h
orig_border: db 0
s_sep:      db "  ", 0
s_dot:      db 2, "./"
s_ext:      db ".sid", 0
card_base:  db 0
saved_p05:  db 0
timer_on:   db 0
cia_mode:   db 0
cia_dirty:  db 0
cia_lo:     db 0
cia_hi:     db 0
            assert cia_hi == cia_lo + 1
it_div:     db 1
it_cnt:     db 1
card_slot6: db 0
fsize:      dw 0
ntsc:       db 0
            align 256
sid_sh:     ds 16                   ; a hangmagasság-regiszterek árnyéka (NTSC)
sidend:     dw 0
song_req:   db 0
dirh:       ds 4
fileh:      ds 4
dest:       dw 0
name_len:   db 0
namebuf:    ds 48
entbuf:     ds ENT_SIZE + 1
s_dash:     db "-$", 0
s_slash:    db "/", 0
s_psid:     db "PSID", 0
s_rsid:     db "RSID", 0
s_qsid:     db "????", 0
s_comma:    db ", ", 0
s_clk1:     db "PAL", 0
s_clk2:     db "NTSC", 0
s_clk3:     db "PAL/NTSC", 0

saved_sp:   dw 0
saved_paging: db 0
data_ptr:   dw 0
data_len:   dw 0
load_addr:  dw 0
init_addr:  dw 0
play_addr:  dw 0
play_mode:  db 0
songs:      db 0
song:       db 0
img_first:  db 0
img_last:   db 0
src:        dw 0
dst6502:    dw 0
remain:     dw 0
pool_ranges: ds 7
pool_ptr:   dw 0
pool_cur:   db 0
pool_end:   db 0
numbuf:     ds 6
emu_status: db 0
; a 6502 állapota
rA:         db 0
rX:         db 0
rY:         db 0
rS:         db 0
            db STKPG >> 8           ; LD HL,(rS): a verem Z80-as címe
rF:         db 0                    ; a Z80 jelzői (S = N, Z)
fC:         db 0
fV:         db 0
fD:         db 0
fI:         db 0
stop_s:     db 0
ticks:      db 0
emu_on:     db 0
emu_sp:     dw 0
key_cnt:    db 1
pending:    db 0
wd_start:   db 0
irq_on:     db 0
irq_save:   ds 3
img_z80:    dw 0
SCRATCH:    db 0

            ds 256
stack_top:
            align 256
RT:         ds 256
WT:         ds 256
            assert WT == RT + 256
ZPG:        ds 256
STKPG:      ds 256
ZEROPG:     ds 256
IOSH:       ds 256
INV:        ds 256                  ; Z80-as lap -> 6502-es lap

prog_end:
sidbuf:                             ; ide olvassuk a .sid fájlt (a HIMEM-ig)
