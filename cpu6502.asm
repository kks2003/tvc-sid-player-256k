; ============================================================================
; cpu6502.asm - GENERÁLT FÁJL (tools/gen6502.py), kézzel ne módosítsd!
; 6502-emulátor Z80-on a SID-lejátszóhoz.
; ============================================================================

; belépés: a regiszterek betöltve, DE = a PC (lásd sidplay.asm emu_run)
emu_next:
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
; elágazás: DE = az eltolás bájtja. Az előjel-kiterjesztés táblából, az
; ADD HL,DE pedig az S és Z jelzőt (a 6502 N és Z-jét) nem bántja.
br_taken_alt:
            ex af,af'
br_taken:   ld a,(de)
            inc de
            ld l,a
            ld h,SEXT>>8
            ld h,(hl)
            add hl,de
            ex de,hl
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
emu_exit_alt:
            ex af,af'
            jp emu_exit

; ADC/SBC: A = operandus
do_adc:     ld l,a
            ld a,(fD)
            or a
            jr nz,.dec
            ld a,(fC)
            rra
            ld a,b
            adc a,l
            ld b,a
            push af
            pop hl
            ld a,l
            ld (fC),a
            ld (fV),a
            ret
.dec:       ld a,(fC)
            rra
            ld a,b
            adc a,l
            daa
            ld b,a
            push af
            pop hl
            ld a,l
            ld (fC),a
            ret
do_sbc:     ld l,a
            ld a,(fD)
            or a
            jr nz,.dec
            ld a,(fC)
            cpl
            rra
            ld a,b
            sbc a,l
            ld b,a
            ccf
            push af
            pop hl
            ld a,l
            ld (fC),a
            ld (fV),a
            ret
.dec:       ld a,(fC)
            cpl
            rra
            ld a,b
            sbc a,l
            daa
            ld b,a
            ccf
            push af
            pop hl
            ld a,l
            ld (fC),a
            ret
; BIT: A = M; Z = (A and M) = 0, N = M 7. bitje, V = M 6. bitje
do_bit:     ld l,a
            and b
            push af
            ld a,l
            pop hl                  ; L = F, A = M
            ld h,a
            and 40h
            rrca
            rrca
            rrca
            rrca
            ld (fV),a
            ld a,l
            and 7Fh
            ld l,a
            ld a,h
            and 80h
            or l
            ld l,a
            push hl
            pop af
            ret
; a P regiszter összerakása A-ba az élő jelzőkből (B és 5. bit = 1)
getp:       push af
            pop hl
            ld a,l
            and 80h
            ld h,a
            bit 6,l
            jr z,.nz
            set 1,h
.nz:        ld a,(fV)
            and 4
            jr z,.nv
            set 6,h
.nv:        ld a,(fC)
            and 1
            or h
            ld h,a
            ld a,(fD)
            or h
            ld h,a
            ld a,(fI)
            or h
            or 30h
            ret
; A = P -> jelzők
setp:       ld l,a
            and 40h
            rrca
            rrca
            rrca
            rrca
            ld (fV),a
            ld a,l
            and 08h
            ld (fD),a
            ld a,l
            and 04h
            ld (fI),a
            ld a,l
            and 01h
            ld (fC),a
            ld a,l
            and 80h
            ld h,a
            ld a,l
            and 02h
            rrca
            rrca
            rrca
            or h
            ld l,a
            push hl
            pop af
            ret

            align 256
cpu_base:
            ds cpu_base + 0 - $
op_00:
            assert (op_00 & 255) == 0
; BRK imp
            jp emu_brk
            ds cpu_base + 3 - $
op_03:
            assert (op_03 & 255) == 3
; SLO indx
            ex af,af'
            ld a,(de)
            inc de
            add a,ixl
            ld l,a
            ld h,ZPG>>8
            ld a,(hl)
            inc l
            ld l,(hl)
            ld h,WT>>8
            ld h,(hl)
            inc h
            dec h
            jr z,.s1
.b1:
            ld l,a
            ex af,af'
            sla (hl)
            rla
            ld (fC),a
            ld a,(hl)
            or b
            ld b,a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
.s1:
            call wslow_R
            jr .b1
            ds cpu_base + 43 - $
op_2B:
            assert (op_2B & 255) == 43
; ANC imm
            ld a,(de)
            inc de
            and b
            ld b,a
            push af
            rlca
            and 1
            ld (fC),a
            pop af
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 61 - $
op_3D:
            assert (op_3D & 255) == 61
; AND absx
            ex de,hl
            ld a,(hl)
            inc hl
            ld e,(hl)
            inc hl
            ex de,hl
            add a,ixl
            jr c,.c1
.k1:
            ld h,RT>>8
            ld h,(hl)
            ld l,a
            ld a,(hl)
            and b
            ld b,a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
.c1:
            inc l
            jr .k1
            ds cpu_base + 87 - $
op_57:
            assert (op_57 & 255) == 87
; SRE zpx
            ex af,af'
            ld a,(de)
            inc de
            add a,ixl
            ld l,a
            ld h,ZPG>>8
            ex af,af'
            srl (hl)
            rla
            ld (fC),a
            ld a,(hl)
            xor b
            ld b,a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 111 - $
op_6F:
            assert (op_6F & 255) == 111
; RRA abs
            ex af,af'
            ex de,hl
            ld a,(hl)
            inc hl
            ld e,(hl)
            inc hl
            ex de,hl
            ld h,WT>>8
            ld h,(hl)
            inc h
            dec h
            jr z,.s1
.b1:
            ld l,a
            ex af,af'
            ld a,(fC)
            rra
            rr (hl)
            rla
            ld (fC),a
            ld a,(hl)
            call do_adc
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
.s1:
            call wslow_R
            jr .b1
            ds cpu_base + 152 - $
op_98:
            assert (op_98 & 255) == 152
; TYA imp
            ld a,ixh
            ld b,a
            or a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 162 - $
op_A2:
            assert (op_A2 & 255) == 162
; LDX imm
            ld a,(de)
            inc de
            ld ixl,a
            or a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 173 - $
op_AD:
            assert (op_AD & 255) == 173
; LDA abs
            ex de,hl
            ld a,(hl)
            inc hl
            ld e,(hl)
            inc hl
            ex de,hl
            ld h,RT>>8
            ld h,(hl)
            ld l,a
            ld a,(hl)
            ld b,a
            or a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 192 - $
op_C0:
            assert (op_C0 & 255) == 192
; CPY imm
            ld a,(de)
            inc de
            ld l,a
            ld a,ixh
            sub l
            ccf
            rla
            ld (fC),a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 209 - $
op_D1:
            assert (op_D1 & 255) == 209
; CMP indy
            ld a,(de)
            inc de
            ld l,a
            ld h,ZPG>>8
            ld a,(hl)
            inc l
            ld l,(hl)
            add a,ixh
            jr c,.c1
.k1:
            ld h,RT>>8
            ld h,(hl)
            ld l,a
            ld a,(hl)
            ld l,a
            ld a,b
            sub l
            ccf
            rla
            ld (fC),a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
.c1:
            inc l
            jr .k1
            ds cpu_base + 243 - $
op_F3:
            assert (op_F3 & 255) == 243
; ISC indy
            ex af,af'
            ld a,(de)
            inc de
            ld l,a
            ld h,ZPG>>8
            ld a,(hl)
            inc l
            ld l,(hl)
            add a,ixh
            jr c,.c1
.k1:
            ld h,WT>>8
            ld h,(hl)
            inc h
            dec h
            jr z,.s2
.b2:
            ld l,a
            ex af,af'
            inc (hl)
            ld a,(hl)
            call do_sbc
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
.s2:
            call wslow_R
            jr .b2
.c1:
            inc l
            jr .k1
            ds cpu_base + 284 - $
op_1C:
            assert (op_1C & 255) == 28
; NOPR absx
            inc de
            inc de
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 292 - $
op_24:
            assert (op_24 & 255) == 36
; BIT zp
            ld a,(de)
            inc de
            ld l,a
            ld h,ZPG>>8
            ld a,(hl)
            call do_bit
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 307 - $
op_33:
            assert (op_33 & 255) == 51
; RLA indy
            ex af,af'
            ld a,(de)
            inc de
            ld l,a
            ld h,ZPG>>8
            ld a,(hl)
            inc l
            ld l,(hl)
            add a,ixh
            jr c,.c1
.k1:
            ld h,WT>>8
            ld h,(hl)
            inc h
            dec h
            jr z,.s2
.b2:
            ld l,a
            ex af,af'
            ld a,(fC)
            rra
            rl (hl)
            rla
            ld (fC),a
            ld a,(hl)
            and b
            ld b,a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
.s2:
            call wslow_R
            jr .b2
.c1:
            inc l
            jr .k1
            ds cpu_base + 356 - $
op_64:
            assert (op_64 & 255) == 100
; NOPR zp
            inc de
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 363 - $
op_6B:
            assert (op_6B & 255) == 107
; KIL / nem támogatott
            jp emu_brk
            ds cpu_base + 366 - $
op_6E:
            assert (op_6E & 255) == 110
; ROR abs
            ex af,af'
            ex de,hl
            ld a,(hl)
            inc hl
            ld e,(hl)
            inc hl
            ex de,hl
            ld h,WT>>8
            ld h,(hl)
            inc h
            dec h
            jr z,.s1
.b1:
            ld l,a
            ex af,af'
            ld a,(fC)
            rra
            rr (hl)
            rla
            ld (fC),a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
.s1:
            call wslow_R
            jr .b1
            ds cpu_base + 403 - $
op_93:
            assert (op_93 & 255) == 147
; KIL / nem támogatott
            jp emu_brk
            ds cpu_base + 406 - $
op_96:
            assert (op_96 & 255) == 150
; STX zpy
            ex af,af'
            ld a,(de)
            inc de
            add a,ixh
            ld l,a
            ld h,ZPG>>8
            ex af,af'
            ld a,ixl
            ld (hl),a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 424 - $
op_A8:
            assert (op_A8 & 255) == 168
; TAY imp
            ld a,b
            ld ixh,a
            or a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 434 - $
op_B2:
            assert (op_B2 & 255) == 178
; KIL / nem támogatott
            jp emu_brk
            ds cpu_base + 437 - $
op_B5:
            assert (op_B5 & 255) == 181
; LDA zpx
            ld a,(de)
            inc de
            add a,ixl
            ld l,a
            ld h,ZPG>>8
            ld a,(hl)
            ld b,a
            or a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 453 - $
op_C5:
            assert (op_C5 & 255) == 197
; CMP zp
            ld a,(de)
            inc de
            ld l,a
            ld h,ZPG>>8
            ld a,(hl)
            ld l,a
            ld a,b
            sub l
            ccf
            rla
            ld (fC),a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 473 - $
op_D9:
            assert (op_D9 & 255) == 217
; CMP absy
            ex de,hl
            ld a,(hl)
            inc hl
            ld e,(hl)
            inc hl
            ex de,hl
            add a,ixh
            jr c,.c1
.k1:
            ld h,RT>>8
            ld h,(hl)
            ld l,a
            ld a,(hl)
            ld l,a
            ld a,b
            sub l
            ccf
            rla
            ld (fC),a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
.c1:
            inc l
            jr .k1
            ds cpu_base + 505 - $
op_F9:
            assert (op_F9 & 255) == 249
; SBC absy
            ex de,hl
            ld a,(hl)
            inc hl
            ld e,(hl)
            inc hl
            ex de,hl
            add a,ixh
            jr c,.c1
.k1:
            ld h,RT>>8
            ld h,(hl)
            ld l,a
            ld a,(hl)
            call do_sbc
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
.c1:
            inc l
            jr .k1
            ds cpu_base + 532 - $
op_14:
            assert (op_14 & 255) == 20
; NOPR zpx
            inc de
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 539 - $
op_1B:
            assert (op_1B & 255) == 27
; SLO absy
            ex af,af'
            ex de,hl
            ld a,(hl)
            inc hl
            ld e,(hl)
            inc hl
            ex de,hl
            add a,ixh
            jr c,.c1
.k1:
            ld h,WT>>8
            ld h,(hl)
            inc h
            dec h
            jr z,.s2
.b2:
            ld l,a
            ex af,af'
            sla (hl)
            rla
            ld (fC),a
            ld a,(hl)
            or b
            ld b,a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
.s2:
            call wslow_R
            jr .b2
.c1:
            inc l
            jr .k1
            ds cpu_base + 582 - $
op_46:
            assert (op_46 & 255) == 70
; LSR zp
            ld a,(de)
            inc de
            ld l,a
            ld h,ZPG>>8
            srl (hl)
            rla
            ld (fC),a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 600 - $
op_58:
            assert (op_58 & 255) == 88
; CLI imp
            ld a,0
            ld (fI),a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 611 - $
op_63:
            assert (op_63 & 255) == 99
; RRA indx
            ex af,af'
            ld a,(de)
            inc de
            add a,ixl
            ld l,a
            ld h,ZPG>>8
            ld a,(hl)
            inc l
            ld l,(hl)
            ld h,WT>>8
            ld h,(hl)
            inc h
            dec h
            jr z,.s1
.b1:
            ld l,a
            ex af,af'
            ld a,(fC)
            rra
            rr (hl)
            rla
            ld (fC),a
            ld a,(hl)
            call do_adc
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
.s1:
            call wslow_R
            jr .b1
            ds cpu_base + 656 - $
op_90:
            assert (op_90 & 255) == 144
; BCC rel
            ex af,af'
            ld a,(fC)
            rra
            jp nc,br_taken_alt
            ex af,af'
            inc de
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 672 - $
op_A0:
            assert (op_A0 & 255) == 160
; LDY imm
            ld a,(de)
            inc de
            ld ixh,a
            or a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 683 - $
op_AB:
            assert (op_AB & 255) == 171
; LAX imm
            ld a,(de)
            inc de
            ld b,a
            ld ixl,a
            or a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 695 - $
op_B7:
            assert (op_B7 & 255) == 183
; LAX zpy
            ld a,(de)
            inc de
            add a,ixh
            ld l,a
            ld h,ZPG>>8
            ld a,(hl)
            ld b,a
            ld ixl,a
            or a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 713 - $
op_C9:
            assert (op_C9 & 255) == 201
; CMP imm
            ld a,(de)
            inc de
            ld l,a
            ld a,b
            sub l
            ccf
            rla
            ld (fC),a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 730 - $
op_DA:
            assert (op_DA & 255) == 218
; NOP imp
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 736 - $
op_E0:
            assert (op_E0 & 255) == 224
; CPX imm
            ld a,(de)
            inc de
            ld l,a
            ld a,ixl
            sub l
            ccf
            rla
            ld (fC),a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 753 - $
op_F1:
            assert (op_F1 & 255) == 241
; SBC indy
            ld a,(de)
            inc de
            ld l,a
            ld h,ZPG>>8
            ld a,(hl)
            inc l
            ld l,(hl)
            add a,ixh
            jr c,.c1
.k1:
            ld h,RT>>8
            ld h,(hl)
            ld l,a
            ld a,(hl)
            call do_sbc
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
.c1:
            inc l
            jr .k1
            ds cpu_base + 782 - $
op_0E:
            assert (op_0E & 255) == 14
; ASL abs
            ex af,af'
            ex de,hl
            ld a,(hl)
            inc hl
            ld e,(hl)
            inc hl
            ex de,hl
            ld h,WT>>8
            ld h,(hl)
            inc h
            dec h
            jr z,.s1
.b1:
            ld l,a
            ex af,af'
            sla (hl)
            rla
            ld (fC),a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
.s1:
            call wslow_R
            jr .b1
            ds cpu_base + 815 - $
op_2F:
            assert (op_2F & 255) == 47
; RLA abs
            ex af,af'
            ex de,hl
            ld a,(hl)
            inc hl
            ld e,(hl)
            inc hl
            ex de,hl
            ld h,WT>>8
            ld h,(hl)
            inc h
            dec h
            jr z,.s1
.b1:
            ld l,a
            ex af,af'
            ld a,(fC)
            rra
            rl (hl)
            rla
            ld (fC),a
            ld a,(hl)
            and b
            ld b,a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
.s1:
            call wslow_R
            jr .b1
            ds cpu_base + 857 - $
op_59:
            assert (op_59 & 255) == 89
; EOR absy
            ex de,hl
            ld a,(hl)
            inc hl
            ld e,(hl)
            inc hl
            ex de,hl
            add a,ixh
            jr c,.c1
.k1:
            ld h,RT>>8
            ld h,(hl)
            ld l,a
            ld a,(hl)
            xor b
            ld b,a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
.c1:
            inc l
            jr .k1
            ds cpu_base + 883 - $
op_73:
            assert (op_73 & 255) == 115
; RRA indy
            ex af,af'
            ld a,(de)
            inc de
            ld l,a
            ld h,ZPG>>8
            ld a,(hl)
            inc l
            ld l,(hl)
            add a,ixh
            jr c,.c1
.k1:
            ld h,WT>>8
            ld h,(hl)
            inc h
            dec h
            jr z,.s2
.b2:
            ld l,a
            ex af,af'
            ld a,(fC)
            rra
            rr (hl)
            rla
            ld (fC),a
            ld a,(hl)
            call do_adc
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
.s2:
            call wslow_R
            jr .b2
.c1:
            inc l
            jr .k1
            ds cpu_base + 933 - $
op_A5:
            assert (op_A5 & 255) == 165
; LDA zp
            ld a,(de)
            inc de
            ld l,a
            ld h,ZPG>>8
            ld a,(hl)
            ld b,a
            or a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 947 - $
op_B3:
            assert (op_B3 & 255) == 179
; LAX indy
            ld a,(de)
            inc de
            ld l,a
            ld h,ZPG>>8
            ld a,(hl)
            inc l
            ld l,(hl)
            add a,ixh
            jr c,.c1
.k1:
            ld h,RT>>8
            ld h,(hl)
            ld l,a
            ld a,(hl)
            ld b,a
            ld ixl,a
            or a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
.c1:
            inc l
            jr .k1
            ds cpu_base + 978 - $
op_D2:
            assert (op_D2 & 255) == 210
; KIL / nem támogatott
            jp emu_brk
            ds cpu_base + 981 - $
op_D5:
            assert (op_D5 & 255) == 213
; CMP zpx
            ld a,(de)
            inc de
            add a,ixl
            ld l,a
            ld h,ZPG>>8
            ld a,(hl)
            ld l,a
            ld a,b
            sub l
            ccf
            rla
            ld (fC),a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 1003 - $
op_EB:
            assert (op_EB & 255) == 235
; SBC imm
            ld a,(de)
            inc de
            call do_sbc
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 1014 - $
op_F6:
            assert (op_F6 & 255) == 246
; INC zpx
            ex af,af'
            ld a,(de)
            inc de
            add a,ixl
            ld l,a
            ld h,ZPG>>8
            ex af,af'
            inc (hl)
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 1030 - $
op_06:
            assert (op_06 & 255) == 6
; ASL zp
            ld a,(de)
            inc de
            ld l,a
            ld h,ZPG>>8
            sla (hl)
            rla
            ld (fC),a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 1047 - $
op_17:
            assert (op_17 & 255) == 23
; SLO zpx
            ex af,af'
            ld a,(de)
            inc de
            add a,ixl
            ld l,a
            ld h,ZPG>>8
            ex af,af'
            sla (hl)
            rla
            ld (fC),a
            ld a,(hl)
            or b
            ld b,a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 1072 - $
op_30:
            assert (op_30 & 255) == 48
; BMI rel
            jp m,br_taken
            inc de
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 1082 - $
op_3A:
            assert (op_3A & 255) == 58
; NOP imp
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 1088 - $
op_40:
            assert (op_40 & 255) == 64
; RTI imp
            ld hl,(rS)
            inc l
            ld a,(hl)
            push af
            inc l
            ld e,(hl)
            inc l
            ld d,(hl)
            ld a,l
            ld (rS),a
            ld hl,stop_s
            cp (hl)
            jr z,.x
            ld l,d
            ld h,RT>>8
            ld d,(hl)
            pop af
            call setp
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
.x:
            pop af
            call setp
            jp emu_exit
            ds cpu_base + 1129 - $
op_69:
            assert (op_69 & 255) == 105
; ADC imm
            ld a,(de)
            inc de
            call do_adc
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 1140 - $
op_74:
            assert (op_74 & 255) == 116
; NOPR zpx
            inc de
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 1147 - $
op_7B:
            assert (op_7B & 255) == 123
; RRA absy
            ex af,af'
            ex de,hl
            ld a,(hl)
            inc hl
            ld e,(hl)
            inc hl
            ex de,hl
            add a,ixh
            jr c,.c1
.k1:
            ld h,WT>>8
            ld h,(hl)
            inc h
            dec h
            jr z,.s2
.b2:
            ld l,a
            ex af,af'
            ld a,(fC)
            rra
            rr (hl)
            rla
            ld (fC),a
            ld a,(hl)
            call do_adc
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
.s2:
            call wslow_R
            jr .b2
.c1:
            inc l
            jr .k1
            ds cpu_base + 1196 - $
op_AC:
            assert (op_AC & 255) == 172
; LDY abs
            ex de,hl
            ld a,(hl)
            inc hl
            ld e,(hl)
            inc hl
            ex de,hl
            ld h,RT>>8
            ld h,(hl)
            ld l,a
            ld a,(hl)
            ld ixh,a
            or a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 1217 - $
op_C1:
            assert (op_C1 & 255) == 193
; CMP indx
            ld a,(de)
            inc de
            add a,ixl
            ld l,a
            ld h,ZPG>>8
            ld a,(hl)
            inc l
            ld l,(hl)
            ld h,RT>>8
            ld h,(hl)
            ld l,a
            ld a,(hl)
            ld l,a
            ld a,b
            sub l
            ccf
            rla
            ld (fC),a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 1246 - $
op_DE:
            assert (op_DE & 255) == 222
; DEC absx
            ex af,af'
            ex de,hl
            ld a,(hl)
            inc hl
            ld e,(hl)
            inc hl
            ex de,hl
            add a,ixl
            jr c,.c1
.k1:
            ld h,WT>>8
            ld h,(hl)
            inc h
            dec h
            jr z,.s2
.b2:
            ld l,a
            ex af,af'
            dec (hl)
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
.s2:
            call wslow_R
            jr .b2
.c1:
            inc l
            jr .k1
            ds cpu_base + 1281 - $
op_01:
            assert (op_01 & 255) == 1
; ORA indx
            ld a,(de)
            inc de
            add a,ixl
            ld l,a
            ld h,ZPG>>8
            ld a,(hl)
            inc l
            ld l,(hl)
            ld h,RT>>8
            ld h,(hl)
            ld l,a
            ld a,(hl)
            or b
            ld b,a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 1304 - $
op_18:
            assert (op_18 & 255) == 24
; CLC imp
            ld a,0
            ld (fC),a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 1315 - $
op_23:
            assert (op_23 & 255) == 35
; RLA indx
            ex af,af'
            ld a,(de)
            inc de
            add a,ixl
            ld l,a
            ld h,ZPG>>8
            ld a,(hl)
            inc l
            ld l,(hl)
            ld h,WT>>8
            ld h,(hl)
            inc h
            dec h
            jr z,.s1
.b1:
            ld l,a
            ex af,af'
            ld a,(fC)
            rra
            rl (hl)
            rla
            ld (fC),a
            ld a,(hl)
            and b
            ld b,a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
.s1:
            call wslow_R
            jr .b1
            ds cpu_base + 1359 - $
op_4F:
            assert (op_4F & 255) == 79
; SRE abs
            ex af,af'
            ex de,hl
            ld a,(hl)
            inc hl
            ld e,(hl)
            inc hl
            ex de,hl
            ld h,WT>>8
            ld h,(hl)
            inc h
            dec h
            jr z,.s1
.b1:
            ld l,a
            ex af,af'
            srl (hl)
            rla
            ld (fC),a
            ld a,(hl)
            xor b
            ld b,a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
.s1:
            call wslow_R
            jr .b1
            ds cpu_base + 1397 - $
op_75:
            assert (op_75 & 255) == 117
; ADC zpx
            ld a,(de)
            inc de
            add a,ixl
            ld l,a
            ld h,ZPG>>8
            ld a,(hl)
            call do_adc
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 1414 - $
op_86:
            assert (op_86 & 255) == 134
; STX zp
            ld a,(de)
            inc de
            ld l,a
            ld h,ZPG>>8
            ld a,ixl
            ld (hl),a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 1428 - $
op_94:
            assert (op_94 & 255) == 148
; STY zpx
            ex af,af'
            ld a,(de)
            inc de
            add a,ixl
            ld l,a
            ld h,ZPG>>8
            ex af,af'
            ld a,ixh
            ld (hl),a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 1446 - $
op_A6:
            assert (op_A6 & 255) == 166
; LDX zp
            ld a,(de)
            inc de
            ld l,a
            ld h,ZPG>>8
            ld a,(hl)
            ld ixl,a
            or a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 1462 - $
op_B6:
            assert (op_B6 & 255) == 182
; LDX zpy
            ld a,(de)
            inc de
            add a,ixh
            ld l,a
            ld h,ZPG>>8
            ld a,(hl)
            ld ixl,a
            or a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 1479 - $
op_C7:
            assert (op_C7 & 255) == 199
; DCP zp
            ld a,(de)
            inc de
            ld l,a
            ld h,ZPG>>8
            dec (hl)
            ld a,(hl)
            ld l,a
            ld a,b
            sub l
            ccf
            rla
            ld (fC),a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 1500 - $
op_DC:
            assert (op_DC & 255) == 220
; NOPR absx
            inc de
            inc de
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 1508 - $
op_E4:
            assert (op_E4 & 255) == 228
; CPX zp
            ld a,(de)
            inc de
            ld l,a
            ld h,ZPG>>8
            ld a,(hl)
            ld l,a
            ld a,ixl
            sub l
            ccf
            rla
            ld (fC),a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 1530 - $
op_FA:
            assert (op_FA & 255) == 250
; NOP imp
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 1538 - $
op_02:
            assert (op_02 & 255) == 2
; KIL / nem támogatott
            jp emu_brk
            ds cpu_base + 1541 - $
op_05:
            assert (op_05 & 255) == 5
; ORA zp
            ld a,(de)
            inc de
            ld l,a
            ld h,ZPG>>8
            ld a,(hl)
            or b
            ld b,a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 1555 - $
op_13:
            assert (op_13 & 255) == 19
; SLO indy
            ex af,af'
            ld a,(de)
            inc de
            ld l,a
            ld h,ZPG>>8
            ld a,(hl)
            inc l
            ld l,(hl)
            add a,ixh
            jr c,.c1
.k1:
            ld h,WT>>8
            ld h,(hl)
            inc h
            dec h
            jr z,.s2
.b2:
            ld l,a
            ex af,af'
            sla (hl)
            rla
            ld (fC),a
            ld a,(hl)
            or b
            ld b,a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
.s2:
            call wslow_R
            jr .b2
.c1:
            inc l
            jr .k1
            ds cpu_base + 1601 - $
op_41:
            assert (op_41 & 255) == 65
; EOR indx
            ld a,(de)
            inc de
            add a,ixl
            ld l,a
            ld h,ZPG>>8
            ld a,(hl)
            inc l
            ld l,(hl)
            ld h,RT>>8
            ld h,(hl)
            ld l,a
            ld a,(hl)
            xor b
            ld b,a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 1626 - $
op_5A:
            assert (op_5A & 255) == 90
; NOP imp
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 1632 - $
op_60:
            assert (op_60 & 255) == 96
; RTS imp
            ex af,af'
            ld hl,(rS)
            inc l
            ld e,(hl)
            inc l
            ld d,(hl)
            ld a,l
            ld (rS),a
            ld hl,stop_s
            cp (hl)
            jp z,emu_exit_alt
            ld l,d
            ld h,RT>>8
            ld d,(hl)
            inc de
            ex af,af'
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 1663 - $
op_7F:
            assert (op_7F & 255) == 127
; RRA absx
            ex af,af'
            ex de,hl
            ld a,(hl)
            inc hl
            ld e,(hl)
            inc hl
            ex de,hl
            add a,ixl
            jr c,.c1
.k1:
            ld h,WT>>8
            ld h,(hl)
            inc h
            dec h
            jr z,.s2
.b2:
            ld l,a
            ex af,af'
            ld a,(fC)
            rra
            rr (hl)
            rla
            ld (fC),a
            ld a,(hl)
            call do_adc
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
.s2:
            call wslow_R
            jr .b2
.c1:
            inc l
            jr .k1
            ds cpu_base + 1711 - $
op_AF:
            assert (op_AF & 255) == 175
; LAX abs
            ex de,hl
            ld a,(hl)
            inc hl
            ld e,(hl)
            inc hl
            ex de,hl
            ld h,RT>>8
            ld h,(hl)
            ld l,a
            ld a,(hl)
            ld b,a
            ld ixl,a
            or a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 1732 - $
op_C4:
            assert (op_C4 & 255) == 196
; CPY zp
            ld a,(de)
            inc de
            ld l,a
            ld h,ZPG>>8
            ld a,(hl)
            ld l,a
            ld a,ixh
            sub l
            ccf
            rla
            ld (fC),a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 1755 - $
op_DB:
            assert (op_DB & 255) == 219
; DCP absy
            ex af,af'
            ex de,hl
            ld a,(hl)
            inc hl
            ld e,(hl)
            inc hl
            ex de,hl
            add a,ixh
            jr c,.c1
.k1:
            ld h,WT>>8
            ld h,(hl)
            inc h
            dec h
            jr z,.s2
.b2:
            ld l,a
            ex af,af'
            dec (hl)
            ld a,(hl)
            ld l,a
            ld a,b
            sub l
            ccf
            rla
            ld (fC),a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
.s2:
            call wslow_R
            jr .b2
.c1:
            inc l
            jr .k1
            ds cpu_base + 1799 - $
op_07:
            assert (op_07 & 255) == 7
; SLO zp
            ld a,(de)
            inc de
            ld l,a
            ld h,ZPG>>8
            sla (hl)
            rla
            ld (fC),a
            ld a,(hl)
            or b
            ld b,a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 1821 - $
op_1D:
            assert (op_1D & 255) == 29
; ORA absx
            ex de,hl
            ld a,(hl)
            inc hl
            ld e,(hl)
            inc hl
            ex de,hl
            add a,ixl
            jr c,.c1
.k1:
            ld h,RT>>8
            ld h,(hl)
            ld l,a
            ld a,(hl)
            or b
            ld b,a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
.c1:
            inc l
            jr .k1
            ds cpu_base + 1847 - $
op_37:
            assert (op_37 & 255) == 55
; RLA zpx
            ex af,af'
            ld a,(de)
            inc de
            add a,ixl
            ld l,a
            ld h,ZPG>>8
            ex af,af'
            ld a,(fC)
            rra
            rl (hl)
            rla
            ld (fC),a
            ld a,(hl)
            and b
            ld b,a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 1875 - $
op_53:
            assert (op_53 & 255) == 83
; SRE indy
            ex af,af'
            ld a,(de)
            inc de
            ld l,a
            ld h,ZPG>>8
            ld a,(hl)
            inc l
            ld l,(hl)
            add a,ixh
            jr c,.c1
.k1:
            ld h,WT>>8
            ld h,(hl)
            inc h
            dec h
            jr z,.s2
.b2:
            ld l,a
            ex af,af'
            srl (hl)
            rla
            ld (fC),a
            ld a,(hl)
            xor b
            ld b,a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
.s2:
            call wslow_R
            jr .b2
.c1:
            inc l
            jr .k1
            ds cpu_base + 1920 - $
op_80:
            assert (op_80 & 255) == 128
; NOPR imm
            inc de
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 1927 - $
op_87:
            assert (op_87 & 255) == 135
; SAX zp
            ld a,(de)
            inc de
            ld l,a
            ld h,ZPG>>8
            push af
            ld a,b
            and ixl
            ld (hl),a
            pop af
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 1945 - $
op_99:
            assert (op_99 & 255) == 153
; STA absy
            ex af,af'
            ex de,hl
            ld a,(hl)
            inc hl
            ld e,(hl)
            inc hl
            ex de,hl
            add a,ixh
            jr c,.c1
.k1:
            ld h,WT>>8
            ld h,(hl)
            inc h
            dec h
            jr z,.s2
.b2:
            ld l,a
            ex af,af'
            ld (hl),b
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
.s2:
            ld h,a
            ld a,l
            cp 0D4h
            jr nz,.g2
            ld a,h
            call sid_fast
            ex af,af'
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
.g2:
            ld a,h
            call wslow_A
            jr .b2
.c1:
            inc l
            jr .k1
            ds cpu_base + 1998 - $
op_CE:
            assert (op_CE & 255) == 206
; DEC abs
            ex af,af'
            ex de,hl
            ld a,(hl)
            inc hl
            ld e,(hl)
            inc hl
            ex de,hl
            ld h,WT>>8
            ld h,(hl)
            inc h
            dec h
            jr z,.s1
.b1:
            ld l,a
            ex af,af'
            dec (hl)
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
.s1:
            call wslow_R
            jr .b1
            ds cpu_base + 2026 - $
op_EA:
            assert (op_EA & 255) == 234
; NOP imp
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 2032 - $
op_F0:
            assert (op_F0 & 255) == 240
; BEQ rel
            jp z,br_taken
            inc de
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 2043 - $
op_FB:
            assert (op_FB & 255) == 251
; ISC absy
            ex af,af'
            ex de,hl
            ld a,(hl)
            inc hl
            ld e,(hl)
            inc hl
            ex de,hl
            add a,ixh
            jr c,.c1
.k1:
            ld h,WT>>8
            ld h,(hl)
            inc h
            dec h
            jr z,.s2
.b2:
            ld l,a
            ex af,af'
            inc (hl)
            ld a,(hl)
            call do_sbc
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
.s2:
            call wslow_R
            jr .b2
.c1:
            inc l
            jr .k1
            ds cpu_base + 2082 - $
op_22:
            assert (op_22 & 255) == 34
; KIL / nem támogatott
            jp emu_brk
            ds cpu_base + 2085 - $
op_25:
            assert (op_25 & 255) == 37
; AND zp
            ld a,(de)
            inc de
            ld l,a
            ld h,ZPG>>8
            ld a,(hl)
            and b
            ld b,a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 2100 - $
op_34:
            assert (op_34 & 255) == 52
; NOPR zpx
            inc de
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 2107 - $
op_3B:
            assert (op_3B & 255) == 59
; RLA absy
            ex af,af'
            ex de,hl
            ld a,(hl)
            inc hl
            ld e,(hl)
            inc hl
            ex de,hl
            add a,ixh
            jr c,.c1
.k1:
            ld h,WT>>8
            ld h,(hl)
            inc h
            dec h
            jr z,.s2
.b2:
            ld l,a
            ex af,af'
            ld a,(fC)
            rra
            rl (hl)
            rla
            ld (fC),a
            ld a,(hl)
            and b
            ld b,a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
.s2:
            call wslow_R
            jr .b2
.c1:
            inc l
            jr .k1
            ds cpu_base + 2154 - $
op_6A:
            assert (op_6A & 255) == 106
; ROR acc
            ld a,(fC)
            rra
            rr b
            rla
            ld (fC),a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 2170 - $
op_7A:
            assert (op_7A & 255) == 122
; NOP imp
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 2177 - $
op_81:
            assert (op_81 & 255) == 129
; STA indx
            ex af,af'
            ld a,(de)
            inc de
            add a,ixl
            ld l,a
            ld h,ZPG>>8
            ld a,(hl)
            inc l
            ld l,(hl)
            ld h,WT>>8
            ld h,(hl)
            inc h
            dec h
            jr z,.s1
.b1:
            ld l,a
            ex af,af'
            ld (hl),b
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
.s1:
            call wslow_A
            jr .b1
            ds cpu_base + 2209 - $
op_A1:
            assert (op_A1 & 255) == 161
; LDA indx
            ld a,(de)
            inc de
            add a,ixl
            ld l,a
            ld h,ZPG>>8
            ld a,(hl)
            inc l
            ld l,(hl)
            ld h,RT>>8
            ld h,(hl)
            ld l,a
            ld a,(hl)
            ld b,a
            or a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 2232 - $
op_B8:
            assert (op_B8 & 255) == 184
; CLV imp
            ld a,0
            ld (fV),a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 2243 - $
op_C3:
            assert (op_C3 & 255) == 195
; DCP indx
            ex af,af'
            ld a,(de)
            inc de
            add a,ixl
            ld l,a
            ld h,ZPG>>8
            ld a,(hl)
            inc l
            ld l,(hl)
            ld h,WT>>8
            ld h,(hl)
            inc h
            dec h
            jr z,.s1
.b1:
            ld l,a
            ex af,af'
            dec (hl)
            ld a,(hl)
            ld l,a
            ld a,b
            sub l
            ccf
            rla
            ld (fC),a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
.s1:
            call wslow_R
            jr .b1
            ds cpu_base + 2284 - $
op_EC:
            assert (op_EC & 255) == 236
; CPX abs
            ex de,hl
            ld a,(hl)
            inc hl
            ld e,(hl)
            inc hl
            ex de,hl
            ld h,RT>>8
            ld h,(hl)
            ld l,a
            ld a,(hl)
            ld l,a
            ld a,ixl
            sub l
            ccf
            rla
            ld (fC),a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 2312 - $
op_08:
            assert (op_08 & 255) == 8
; PHP imp
            push af
            call getp
            ld hl,(rS)
            ld (hl),a
            dec l
            ld a,l
            ld (rS),a
            pop af
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 2334 - $
op_1E:
            assert (op_1E & 255) == 30
; ASL absx
            ex af,af'
            ex de,hl
            ld a,(hl)
            inc hl
            ld e,(hl)
            inc hl
            ex de,hl
            add a,ixl
            jr c,.c1
.k1:
            ld h,WT>>8
            ld h,(hl)
            inc h
            dec h
            jr z,.s2
.b2:
            ld l,a
            ex af,af'
            sla (hl)
            rla
            ld (fC),a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
.s2:
            call wslow_R
            jr .b2
.c1:
            inc l
            jr .k1
            ds cpu_base + 2375 - $
op_47:
            assert (op_47 & 255) == 71
; SRE zp
            ld a,(de)
            inc de
            ld l,a
            ld h,ZPG>>8
            srl (hl)
            rla
            ld (fC),a
            ld a,(hl)
            xor b
            ld b,a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 2395 - $
op_5B:
            assert (op_5B & 255) == 91
; SRE absy
            ex af,af'
            ex de,hl
            ld a,(hl)
            inc hl
            ld e,(hl)
            inc hl
            ex de,hl
            add a,ixh
            jr c,.c1
.k1:
            ld h,WT>>8
            ld h,(hl)
            inc h
            dec h
            jr z,.s2
.b2:
            ld l,a
            ex af,af'
            srl (hl)
            rla
            ld (fC),a
            ld a,(hl)
            xor b
            ld b,a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
.s2:
            call wslow_R
            jr .b2
.c1:
            inc l
            jr .k1
            ds cpu_base + 2440 - $
op_88:
            assert (op_88 & 255) == 136
; DEY imp
            dec ixh
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 2449 - $
op_91:
            assert (op_91 & 255) == 145
; STA indy
            ex af,af'
            ld a,(de)
            inc de
            ld l,a
            ld h,ZPG>>8
            ld a,(hl)
            inc l
            ld l,(hl)
            add a,ixh
            jr c,.c1
.k1:
            ld h,WT>>8
            ld h,(hl)
            inc h
            dec h
            jr z,.s2
.b2:
            ld l,a
            ex af,af'
            ld (hl),b
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
.s2:
            call wslow_A
            jr .b2
.c1:
            inc l
            jr .k1
            ds cpu_base + 2489 - $
op_B9:
            assert (op_B9 & 255) == 185
; LDA absy
            ex de,hl
            ld a,(hl)
            inc hl
            ld e,(hl)
            inc hl
            ex de,hl
            add a,ixh
            jr c,.c1
.k1:
            ld h,RT>>8
            ld h,(hl)
            ld l,a
            ld a,(hl)
            ld b,a
            or a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
.c1:
            inc l
            jr .k1
            ds cpu_base + 2515 - $
op_D3:
            assert (op_D3 & 255) == 211
; DCP indy
            ex af,af'
            ld a,(de)
            inc de
            ld l,a
            ld h,ZPG>>8
            ld a,(hl)
            inc l
            ld l,(hl)
            add a,ixh
            jr c,.c1
.k1:
            ld h,WT>>8
            ld h,(hl)
            inc h
            dec h
            jr z,.s2
.b2:
            ld l,a
            ex af,af'
            dec (hl)
            ld a,(hl)
            ld l,a
            ld a,b
            sub l
            ccf
            rla
            ld (fC),a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
.s2:
            call wslow_R
            jr .b2
.c1:
            inc l
            jr .k1
            ds cpu_base + 2564 - $
op_04:
            assert (op_04 & 255) == 4
; NOPR zp
            inc de
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 2571 - $
op_0B:
            assert (op_0B & 255) == 11
; ANC imm
            ld a,(de)
            inc de
            and b
            ld b,a
            push af
            rlca
            and 1
            ld (fC),a
            pop af
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 2591 - $
op_1F:
            assert (op_1F & 255) == 31
; SLO absx
            ex af,af'
            ex de,hl
            ld a,(hl)
            inc hl
            ld e,(hl)
            inc hl
            ex de,hl
            add a,ixl
            jr c,.c1
.k1:
            ld h,WT>>8
            ld h,(hl)
            inc h
            dec h
            jr z,.s2
.b2:
            ld l,a
            ex af,af'
            sla (hl)
            rla
            ld (fC),a
            ld a,(hl)
            or b
            ld b,a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
.s2:
            call wslow_R
            jr .b2
.c1:
            inc l
            jr .k1
            ds cpu_base + 2634 - $
op_4A:
            assert (op_4A & 255) == 74
; LSR acc
            srl b
            rla
            ld (fC),a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 2646 - $
op_56:
            assert (op_56 & 255) == 86
; LSR zpx
            ex af,af'
            ld a,(de)
            inc de
            add a,ixl
            ld l,a
            ld h,ZPG>>8
            ex af,af'
            srl (hl)
            rla
            ld (fC),a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 2668 - $
op_6C:
            assert (op_6C & 255) == 108
; JMP ind
            ex de,hl
            ld a,(hl)
            inc hl
            ld e,(hl)
            inc hl
            ex de,hl
            ld h,RT>>8
            ld h,(hl)
            ld l,a
            ld a,(hl)
            inc l
            ld l,(hl)
            ld h,RT>>8
            ld h,(hl)
            ld l,a
            ex de,hl
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 2692 - $
op_84:
            assert (op_84 & 255) == 132
; STY zp
            ld a,(de)
            inc de
            ld l,a
            ld h,ZPG>>8
            ld a,ixh
            ld (hl),a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 2706 - $
op_92:
            assert (op_92 & 255) == 146
; KIL / nem támogatott
            jp emu_brk
            ds cpu_base + 2709 - $
op_95:
            assert (op_95 & 255) == 149
; STA zpx
            ex af,af'
            ld a,(de)
            inc de
            add a,ixl
            ld l,a
            ld h,ZPG>>8
            ex af,af'
            ld (hl),b
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 2727 - $
op_A7:
            assert (op_A7 & 255) == 167
; LAX zp
            ld a,(de)
            inc de
            ld l,a
            ld h,ZPG>>8
            ld a,(hl)
            ld b,a
            ld ixl,a
            or a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 2746 - $
op_BA:
            assert (op_BA & 255) == 186
; TSX imp
            ld a,(rS)
            ld ixl,a
            or a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 2758 - $
op_C6:
            assert (op_C6 & 255) == 198
; DEC zp
            ld a,(de)
            inc de
            ld l,a
            ld h,ZPG>>8
            dec (hl)
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 2772 - $
op_D4:
            assert (op_D4 & 255) == 212
; NOPR zpx
            inc de
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 2781 - $
op_DD:
            assert (op_DD & 255) == 221
; CMP absx
            ex de,hl
            ld a,(hl)
            inc hl
            ld e,(hl)
            inc hl
            ex de,hl
            add a,ixl
            jr c,.c1
.k1:
            ld h,RT>>8
            ld h,(hl)
            ld l,a
            ld a,(hl)
            ld l,a
            ld a,b
            sub l
            ccf
            rla
            ld (fC),a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
.c1:
            inc l
            jr .k1
            ds cpu_base + 2813 - $
op_FD:
            assert (op_FD & 255) == 253
; SBC absx
            ex de,hl
            ld a,(hl)
            inc hl
            ld e,(hl)
            inc hl
            ex de,hl
            add a,ixl
            jr c,.c1
.k1:
            ld h,RT>>8
            ld h,(hl)
            ld l,a
            ld a,(hl)
            call do_sbc
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
.c1:
            inc l
            jr .k1
            ds cpu_base + 2841 - $
op_19:
            assert (op_19 & 255) == 25
; ORA absy
            ex de,hl
            ld a,(hl)
            inc hl
            ld e,(hl)
            inc hl
            ex de,hl
            add a,ixh
            jr c,.c1
.k1:
            ld h,RT>>8
            ld h,(hl)
            ld l,a
            ld a,(hl)
            or b
            ld b,a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
.c1:
            inc l
            jr .k1
            ds cpu_base + 2869 - $
op_35:
            assert (op_35 & 255) == 53
; AND zpx
            ld a,(de)
            inc de
            add a,ixl
            ld l,a
            ld h,ZPG>>8
            ld a,(hl)
            and b
            ld b,a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 2885 - $
op_45:
            assert (op_45 & 255) == 69
; EOR zp
            ld a,(de)
            inc de
            ld l,a
            ld h,ZPG>>8
            ld a,(hl)
            xor b
            ld b,a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 2900 - $
op_54:
            assert (op_54 & 255) == 84
; NOPR zpx
            inc de
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 2908 - $
op_5C:
            assert (op_5C & 255) == 92
; NOPR absx
            inc de
            inc de
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 2917 - $
op_65:
            assert (op_65 & 255) == 101
; ADC zp
            ld a,(de)
            inc de
            ld l,a
            ld h,ZPG>>8
            ld a,(hl)
            call do_adc
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 2934 - $
op_76:
            assert (op_76 & 255) == 118
; ROR zpx
            ex af,af'
            ld a,(de)
            inc de
            add a,ixl
            ld l,a
            ld h,ZPG>>8
            ex af,af'
            ld a,(fC)
            rra
            rr (hl)
            rla
            ld (fC),a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 2959 - $
op_8F:
            assert (op_8F & 255) == 143
; SAX abs
            ex af,af'
            ex de,hl
            ld a,(hl)
            inc hl
            ld e,(hl)
            inc hl
            ex de,hl
            ld h,WT>>8
            ld h,(hl)
            inc h
            dec h
            jr z,.s1
.b1:
            ld l,a
            ex af,af'
            push af
            ld a,b
            and ixl
            ld (hl),a
            pop af
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
.s1:
            call wslow_SAX
            jr .b1
            ds cpu_base + 2992 - $
op_B0:
            assert (op_B0 & 255) == 176
; BCS rel
            ex af,af'
            ld a,(fC)
            rra
            jp c,br_taken_alt
            ex af,af'
            inc de
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 3010 - $
op_C2:
            assert (op_C2 & 255) == 194
; NOPR imm
            inc de
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 3018 - $
op_CA:
            assert (op_CA & 255) == 202
; DEX imp
            dec ixl
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 3030 - $
op_D6:
            assert (op_D6 & 255) == 214
; DEC zpx
            ex af,af'
            ld a,(de)
            inc de
            add a,ixl
            ld l,a
            ld h,ZPG>>8
            ex af,af'
            dec (hl)
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 3046 - $
op_E6:
            assert (op_E6 & 255) == 230
; INC zp
            ld a,(de)
            inc de
            ld l,a
            ld h,ZPG>>8
            inc (hl)
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 3058 - $
op_F2:
            assert (op_F2 & 255) == 242
; KIL / nem támogatott
            jp emu_brk
            ds cpu_base + 3061 - $
op_F5:
            assert (op_F5 & 255) == 245
; SBC zpx
            ld a,(de)
            inc de
            add a,ixl
            ld l,a
            ld h,ZPG>>8
            ld a,(hl)
            call do_sbc
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 3081 - $
op_09:
            assert (op_09 & 255) == 9
; ORA imm
            ld a,(de)
            inc de
            or b
            ld b,a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 3093 - $
op_15:
            assert (op_15 & 255) == 21
; ORA zpx
            ld a,(de)
            inc de
            add a,ixl
            ld l,a
            ld h,ZPG>>8
            ld a,(hl)
            or b
            ld b,a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 3110 - $
op_26:
            assert (op_26 & 255) == 38
; ROL zp
            ld a,(de)
            inc de
            ld l,a
            ld h,ZPG>>8
            ld a,(fC)
            rra
            rl (hl)
            rla
            ld (fC),a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 3132 - $
op_3C:
            assert (op_3C & 255) == 60
; NOPR absx
            inc de
            inc de
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 3140 - $
op_44:
            assert (op_44 & 255) == 68
; NOPR zp
            inc de
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 3147 - $
op_4B:
            assert (op_4B & 255) == 75
; ALR imm
            ld a,(de)
            inc de
            and b
            srl a
            ld b,a
            rla
            ld (fC),a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 3165 - $
op_5D:
            assert (op_5D & 255) == 93
; EOR absx
            ex de,hl
            ld a,(hl)
            inc hl
            ld e,(hl)
            inc hl
            ex de,hl
            add a,ixl
            jr c,.c1
.k1:
            ld h,RT>>8
            ld h,(hl)
            ld l,a
            ld a,(hl)
            xor b
            ld b,a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
.c1:
            inc l
            jr .k1
            ds cpu_base + 3191 - $
op_77:
            assert (op_77 & 255) == 119
; RRA zpx
            ex af,af'
            ld a,(de)
            inc de
            add a,ixl
            ld l,a
            ld h,ZPG>>8
            ex af,af'
            ld a,(fC)
            rra
            rr (hl)
            rla
            ld (fC),a
            ld a,(hl)
            call do_adc
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 3223 - $
op_97:
            assert (op_97 & 255) == 151
; SAX zpy
            ex af,af'
            ld a,(de)
            inc de
            add a,ixh
            ld l,a
            ld h,ZPG>>8
            ex af,af'
            push af
            ld a,b
            and ixl
            ld (hl),a
            pop af
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 3246 - $
op_AE:
            assert (op_AE & 255) == 174
; LDX abs
            ex de,hl
            ld a,(hl)
            inc hl
            ld e,(hl)
            inc hl
            ex de,hl
            ld h,RT>>8
            ld h,(hl)
            ld l,a
            ld a,(hl)
            ld ixl,a
            or a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 3272 - $
op_C8:
            assert (op_C8 & 255) == 200
; INY imp
            inc ixh
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 3280 - $
op_D0:
            assert (op_D0 & 255) == 208
; BNE rel
            jp nz,br_taken
            inc de
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 3295 - $
op_DF:
            assert (op_DF & 255) == 223
; DCP absx
            ex af,af'
            ex de,hl
            ld a,(hl)
            inc hl
            ld e,(hl)
            inc hl
            ex de,hl
            add a,ixl
            jr c,.c1
.k1:
            ld h,WT>>8
            ld h,(hl)
            inc h
            dec h
            jr z,.s2
.b2:
            ld l,a
            ex af,af'
            dec (hl)
            ld a,(hl)
            ld l,a
            ld a,b
            sub l
            ccf
            rla
            ld (fC),a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
.s2:
            call wslow_R
            jr .b2
.c1:
            inc l
            jr .k1
            ds cpu_base + 3340 - $
op_0C:
            assert (op_0C & 255) == 12
; NOPR abs
            inc de
            inc de
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 3350 - $
op_16:
            assert (op_16 & 255) == 22
; ASL zpx
            ex af,af'
            ld a,(de)
            inc de
            add a,ixl
            ld l,a
            ld h,ZPG>>8
            ex af,af'
            sla (hl)
            rla
            ld (fC),a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 3372 - $
op_2C:
            assert (op_2C & 255) == 44
; BIT abs
            ex de,hl
            ld a,(hl)
            inc hl
            ld e,(hl)
            inc hl
            ex de,hl
            ld h,RT>>8
            ld h,(hl)
            ld l,a
            ld a,(hl)
            call do_bit
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 3394 - $
op_42:
            assert (op_42 & 255) == 66
; KIL / nem támogatott
            jp emu_brk
            ds cpu_base + 3400 - $
op_48:
            assert (op_48 & 255) == 72
; PHA imp
            ex af,af'
            ld hl,(rS)
            ld (hl),b
            dec l
            ld a,l
            ld (rS),a
            ex af,af'
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 3422 - $
op_5E:
            assert (op_5E & 255) == 94
; LSR absx
            ex af,af'
            ex de,hl
            ld a,(hl)
            inc hl
            ld e,(hl)
            inc hl
            ex de,hl
            add a,ixl
            jr c,.c1
.k1:
            ld h,WT>>8
            ld h,(hl)
            inc h
            dec h
            jr z,.s2
.b2:
            ld l,a
            ex af,af'
            srl (hl)
            rla
            ld (fC),a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
.s2:
            call wslow_R
            jr .b2
.c1:
            inc l
            jr .k1
            ds cpu_base + 3465 - $
op_89:
            assert (op_89 & 255) == 137
; NOPR imm
            inc de
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 3482 - $
op_9A:
            assert (op_9A & 255) == 154
; TXS imp
            ld a,ixl
            ld (rS),a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 3497 - $
op_A9:
            assert (op_A9 & 255) == 169
; LDA imm
            ld a,(de)
            inc de
            ld b,a
            or a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 3508 - $
op_B4:
            assert (op_B4 & 255) == 180
; LDY zpx
            ld a,(de)
            inc de
            add a,ixl
            ld l,a
            ld h,ZPG>>8
            ld a,(hl)
            ld ixh,a
            or a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 3531 - $
op_CB:
            assert (op_CB & 255) == 203
; SBX imm
            ld a,(de)
            inc de
            ld l,a
            ld a,ixl
            and b
            sub l
            ld ixl,a
            ccf
            rla
            ld (fC),a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 3553 - $
op_E1:
            assert (op_E1 & 255) == 225
; SBC indx
            ld a,(de)
            inc de
            add a,ixl
            ld l,a
            ld h,ZPG>>8
            ld a,(hl)
            inc l
            ld l,(hl)
            ld h,RT>>8
            ld h,(hl)
            ld l,a
            ld a,(hl)
            call do_sbc
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 3580 - $
op_FC:
            assert (op_FC & 255) == 252
; NOPR absx
            inc de
            inc de
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 3594 - $
op_0A:
            assert (op_0A & 255) == 10
; ASL acc
            sla b
            rla
            ld (fC),a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 3610 - $
op_1A:
            assert (op_1A & 255) == 26
; NOP imp
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 3616 - $
op_20:
            assert (op_20 & 255) == 32
; JSR abs
            ex af,af'
            inc de
            ld h,INV>>8
            ld l,d
            ld a,(hl)
            ld hl,(rS)
            ld (hl),a
            dec l
            ld (hl),e
            dec l
            ld a,l
            ld (rS),a
            ex de,hl
            ld a,(hl)
            dec hl
            ld e,(hl)
            ld l,a
            ld h,RT>>8
            ld d,(hl)
            ex af,af'
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 3651 - $
op_43:
            assert (op_43 & 255) == 67
; SRE indx
            ex af,af'
            ld a,(de)
            inc de
            add a,ixl
            ld l,a
            ld h,ZPG>>8
            ld a,(hl)
            inc l
            ld l,(hl)
            ld h,WT>>8
            ld h,(hl)
            inc h
            dec h
            jr z,.s1
.b1:
            ld l,a
            ex af,af'
            srl (hl)
            rla
            ld (fC),a
            ld a,(hl)
            xor b
            ld b,a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
.s1:
            call wslow_R
            jr .b1
            ds cpu_base + 3693 - $
op_6D:
            assert (op_6D & 255) == 109
; ADC abs
            ex de,hl
            ld a,(hl)
            inc hl
            ld e,(hl)
            inc hl
            ex de,hl
            ld h,RT>>8
            ld h,(hl)
            ld l,a
            ld a,(hl)
            call do_adc
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 3714 - $
op_82:
            assert (op_82 & 255) == 130
; NOPR imm
            inc de
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 3722 - $
op_8A:
            assert (op_8A & 255) == 138
; TXA imp
            ld a,ixl
            ld b,a
            or a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 3739 - $
op_9B:
            assert (op_9B & 255) == 155
; KIL / nem támogatott
            jp emu_brk
            ds cpu_base + 3742 - $
op_9E:
            assert (op_9E & 255) == 158
; KIL / nem támogatott
            jp emu_brk
            ds cpu_base + 3747 - $
op_A3:
            assert (op_A3 & 255) == 163
; LAX indx
            ld a,(de)
            inc de
            add a,ixl
            ld l,a
            ld h,ZPG>>8
            ld a,(hl)
            inc l
            ld l,(hl)
            ld h,RT>>8
            ld h,(hl)
            ld l,a
            ld a,(hl)
            ld b,a
            ld ixl,a
            or a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 3772 - $
op_BC:
            assert (op_BC & 255) == 188
; LDY absx
            ex de,hl
            ld a,(hl)
            inc hl
            ld e,(hl)
            inc hl
            ex de,hl
            add a,ixl
            jr c,.c1
.k1:
            ld h,RT>>8
            ld h,(hl)
            ld l,a
            ld a,(hl)
            ld ixh,a
            or a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
.c1:
            inc l
            jr .k1
            ds cpu_base + 3799 - $
op_D7:
            assert (op_D7 & 255) == 215
; DCP zpx
            ex af,af'
            ld a,(de)
            inc de
            add a,ixl
            ld l,a
            ld h,ZPG>>8
            ex af,af'
            dec (hl)
            ld a,(hl)
            ld l,a
            ld a,b
            sub l
            ccf
            rla
            ld (fC),a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 3828 - $
op_F4:
            assert (op_F4 & 255) == 244
; NOPR zpx
            inc de
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 3838 - $
op_FE:
            assert (op_FE & 255) == 254
; INC absx
            ex af,af'
            ex de,hl
            ld a,(hl)
            inc hl
            ld e,(hl)
            inc hl
            ex de,hl
            add a,ixl
            jr c,.c1
.k1:
            ld h,WT>>8
            ld h,(hl)
            inc h
            dec h
            jr z,.s2
.b2:
            ld l,a
            ex af,af'
            inc (hl)
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
.s2:
            call wslow_R
            jr .b2
.c1:
            inc l
            jr .k1
            ds cpu_base + 3873 - $
op_21:
            assert (op_21 & 255) == 33
; AND indx
            ld a,(de)
            inc de
            add a,ixl
            ld l,a
            ld h,ZPG>>8
            ld a,(hl)
            inc l
            ld l,(hl)
            ld h,RT>>8
            ld h,(hl)
            ld l,a
            ld a,(hl)
            and b
            ld b,a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 3896 - $
op_38:
            assert (op_38 & 255) == 56
; SEC imp
            ld a,1
            ld (fC),a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 3913 - $
op_49:
            assert (op_49 & 255) == 73
; EOR imm
            ld a,(de)
            inc de
            xor b
            ld b,a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 3925 - $
op_55:
            assert (op_55 & 255) == 85
; EOR zpx
            ld a,(de)
            inc de
            add a,ixl
            ld l,a
            ld h,ZPG>>8
            ld a,(hl)
            xor b
            ld b,a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 3942 - $
op_66:
            assert (op_66 & 255) == 102
; ROR zp
            ld a,(de)
            inc de
            ld l,a
            ld h,ZPG>>8
            ld a,(fC)
            rra
            rr (hl)
            rla
            ld (fC),a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 3964 - $
op_7C:
            assert (op_7C & 255) == 124
; NOPR absx
            inc de
            inc de
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 3973 - $
op_85:
            assert (op_85 & 255) == 133
; STA zp
            ld a,(de)
            inc de
            ld l,a
            ld h,ZPG>>8
            ld (hl),b
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 3996 - $
op_9C:
            assert (op_9C & 255) == 156
; KIL / nem támogatott
            jp emu_brk
            ds cpu_base + 3999 - $
op_9F:
            assert (op_9F & 255) == 159
; KIL / nem támogatott
            jp emu_brk
            ds cpu_base + 4004 - $
op_A4:
            assert (op_A4 & 255) == 164
; LDY zp
            ld a,(de)
            inc de
            ld l,a
            ld h,ZPG>>8
            ld a,(hl)
            ld ixh,a
            or a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 4027 - $
op_BB:
            assert (op_BB & 255) == 187
; KIL / nem támogatott
            jp emu_brk
            ds cpu_base + 4030 - $
op_BE:
            assert (op_BE & 255) == 190
; LDX absy
            ex de,hl
            ld a,(hl)
            inc hl
            ld e,(hl)
            inc hl
            ex de,hl
            add a,ixh
            jr c,.c1
.k1:
            ld h,RT>>8
            ld h,(hl)
            ld l,a
            ld a,(hl)
            ld ixl,a
            or a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
.c1:
            inc l
            jr .k1
            ds cpu_base + 4066 - $
op_E2:
            assert (op_E2 & 255) == 226
; NOPR imm
            inc de
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 4073 - $
op_E9:
            assert (op_E9 & 255) == 233
; SBC imm
            ld a,(de)
            inc de
            call do_sbc
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 4087 - $
op_F7:
            assert (op_F7 & 255) == 247
; ISC zpx
            ex af,af'
            ld a,(de)
            inc de
            add a,ixl
            ld l,a
            ld h,ZPG>>8
            ex af,af'
            inc (hl)
            ld a,(hl)
            call do_sbc
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 4109 - $
op_0D:
            assert (op_0D & 255) == 13
; ORA abs
            ex de,hl
            ld a,(hl)
            inc hl
            ld e,(hl)
            inc hl
            ex de,hl
            ld h,RT>>8
            ld h,(hl)
            ld l,a
            ld a,(hl)
            or b
            ld b,a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 4135 - $
op_27:
            assert (op_27 & 255) == 39
; RLA zp
            ld a,(de)
            inc de
            ld l,a
            ld h,ZPG>>8
            ld a,(fC)
            rra
            rl (hl)
            rla
            ld (fC),a
            ld a,(hl)
            and b
            ld b,a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 4159 - $
op_3F:
            assert (op_3F & 255) == 63
; RLA absx
            ex af,af'
            ex de,hl
            ld a,(hl)
            inc hl
            ld e,(hl)
            inc hl
            ex de,hl
            add a,ixl
            jr c,.c1
.k1:
            ld h,WT>>8
            ld h,(hl)
            inc h
            dec h
            jr z,.s2
.b2:
            ld l,a
            ex af,af'
            ld a,(fC)
            rra
            rl (hl)
            rla
            ld (fC),a
            ld a,(hl)
            and b
            ld b,a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
.s2:
            call wslow_R
            jr .b2
.c1:
            inc l
            jr .k1
            ds cpu_base + 4208 - $
op_70:
            assert (op_70 & 255) == 112
; BVS rel
            ex af,af'
            ld a,(fV)
            and 4
            jp nz,br_taken_alt
            ex af,af'
            inc de
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 4227 - $
op_83:
            assert (op_83 & 255) == 131
; SAX indx
            ex af,af'
            ld a,(de)
            inc de
            add a,ixl
            ld l,a
            ld h,ZPG>>8
            ld a,(hl)
            inc l
            ld l,(hl)
            ld h,WT>>8
            ld h,(hl)
            inc h
            dec h
            jr z,.s1
.b1:
            ld l,a
            ex af,af'
            push af
            ld a,b
            and ixl
            ld (hl),a
            pop af
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
.s1:
            call wslow_SAX
            jr .b1
            ds cpu_base + 4266 - $
op_AA:
            assert (op_AA & 255) == 170
; TAX imp
            ld a,b
            ld ixl,a
            or a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 4285 - $
op_BD:
            assert (op_BD & 255) == 189
; LDA absx
            ex de,hl
            ld a,(hl)
            inc hl
            ld e,(hl)
            inc hl
            ex de,hl
            add a,ixl
            jr c,.c1
.k1:
            ld h,RT>>8
            ld h,(hl)
            ld l,a
            ld a,(hl)
            ld b,a
            or a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
.c1:
            inc l
            jr .k1
            ds cpu_base + 4312 - $
op_D8:
            assert (op_D8 & 255) == 216
; CLD imp
            ld a,0
            ld (fD),a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 4323 - $
op_E3:
            assert (op_E3 & 255) == 227
; ISC indx
            ex af,af'
            ld a,(de)
            inc de
            add a,ixl
            ld l,a
            ld h,ZPG>>8
            ld a,(hl)
            inc l
            ld l,(hl)
            ld h,WT>>8
            ld h,(hl)
            inc h
            dec h
            jr z,.s1
.b1:
            ld l,a
            ex af,af'
            inc (hl)
            ld a,(hl)
            call do_sbc
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
.s1:
            call wslow_R
            jr .b1
            ds cpu_base + 4367 - $
op_0F:
            assert (op_0F & 255) == 15
; SLO abs
            ex af,af'
            ex de,hl
            ld a,(hl)
            inc hl
            ld e,(hl)
            inc hl
            ex de,hl
            ld h,WT>>8
            ld h,(hl)
            inc h
            dec h
            jr z,.s1
.b1:
            ld l,a
            ex af,af'
            sla (hl)
            rla
            ld (fC),a
            ld a,(hl)
            or b
            ld b,a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
.s1:
            call wslow_R
            jr .b1
            ds cpu_base + 4406 - $
op_36:
            assert (op_36 & 255) == 54
; ROL zpx
            ex af,af'
            ld a,(de)
            inc de
            add a,ixl
            ld l,a
            ld h,ZPG>>8
            ex af,af'
            ld a,(fC)
            rra
            rl (hl)
            rla
            ld (fC),a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 4432 - $
op_50:
            assert (op_50 & 255) == 80
; BVC rel
            ex af,af'
            ld a,(fV)
            and 4
            jp z,br_taken_alt
            ex af,af'
            inc de
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 4449 - $
op_61:
            assert (op_61 & 255) == 97
; ADC indx
            ld a,(de)
            inc de
            add a,ixl
            ld l,a
            ld h,ZPG>>8
            ld a,(hl)
            inc l
            ld l,(hl)
            ld h,RT>>8
            ld h,(hl)
            ld l,a
            ld a,(hl)
            call do_adc
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 4473 - $
op_79:
            assert (op_79 & 255) == 121
; ADC absy
            ex de,hl
            ld a,(hl)
            inc hl
            ld e,(hl)
            inc hl
            ex de,hl
            add a,ixh
            jr c,.c1
.k1:
            ld h,RT>>8
            ld h,(hl)
            ld l,a
            ld a,(hl)
            call do_adc
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
.c1:
            inc l
            jr .k1
            ds cpu_base + 4509 - $
op_9D:
            assert (op_9D & 255) == 157
; STA absx
            ex af,af'
            ex de,hl
            ld a,(hl)
            inc hl
            ld e,(hl)
            inc hl
            ex de,hl
            add a,ixl
            jr c,.c1
.k1:
            ld h,WT>>8
            ld h,(hl)
            inc h
            dec h
            jr z,.s2
.b2:
            ld l,a
            ex af,af'
            ld (hl),b
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
.s2:
            ld h,a
            ld a,l
            cp 0D4h
            jr nz,.g2
            ld a,h
            call sid_fast
            ex af,af'
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
.g2:
            ld a,h
            call wslow_A
            jr .b2
.c1:
            inc l
            jr .k1
            ds cpu_base + 4581 - $
op_E5:
            assert (op_E5 & 255) == 229
; SBC zp
            ld a,(de)
            inc de
            ld l,a
            ld h,ZPG>>8
            ld a,(hl)
            call do_sbc
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 4600 - $
op_F8:
            assert (op_F8 & 255) == 248
; SED imp
            ld a,08h
            ld (fD),a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 4624 - $
op_10:
            assert (op_10 & 255) == 16
; BPL rel
            jp p,br_taken
            inc de
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 4648 - $
op_28:
            assert (op_28 & 255) == 40
; PLP imp
            ld hl,(rS)
            inc l
            ld a,l
            ld (rS),a
            ld a,(hl)
            call setp
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 4670 - $
op_3E:
            assert (op_3E & 255) == 62
; ROL absx
            ex af,af'
            ex de,hl
            ld a,(hl)
            inc hl
            ld e,(hl)
            inc hl
            ex de,hl
            add a,ixl
            jr c,.c1
.k1:
            ld h,WT>>8
            ld h,(hl)
            inc h
            dec h
            jr z,.s2
.b2:
            ld l,a
            ex af,af'
            ld a,(fC)
            rra
            rl (hl)
            rla
            ld (fC),a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
.s2:
            call wslow_R
            jr .b2
.c1:
            inc l
            jr .k1
            ds cpu_base + 4721 - $
op_71:
            assert (op_71 & 255) == 113
; ADC indy
            ld a,(de)
            inc de
            ld l,a
            ld h,ZPG>>8
            ld a,(hl)
            inc l
            ld l,(hl)
            add a,ixh
            jr c,.c1
.k1:
            ld h,RT>>8
            ld h,(hl)
            ld l,a
            ld a,(hl)
            call do_adc
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
.c1:
            inc l
            jr .k1
            ds cpu_base + 4750 - $
op_8E:
            assert (op_8E & 255) == 142
; STX abs
            ex af,af'
            ex de,hl
            ld a,(hl)
            inc hl
            ld e,(hl)
            inc hl
            ex de,hl
            ld h,WT>>8
            ld h,(hl)
            inc h
            dec h
            jr z,.s1
.b1:
            ld l,a
            ex af,af'
            ld a,ixl
            ld (hl),a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
.s1:
            call wslow_X
            jr .b1
            ds cpu_base + 4785 - $
op_B1:
            assert (op_B1 & 255) == 177
; LDA indy
            ld a,(de)
            inc de
            ld l,a
            ld h,ZPG>>8
            ld a,(hl)
            inc l
            ld l,(hl)
            add a,ixh
            jr c,.c1
.k1:
            ld h,RT>>8
            ld h,(hl)
            ld l,a
            ld a,(hl)
            ld b,a
            or a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
.c1:
            inc l
            jr .k1
            ds cpu_base + 4813 - $
op_CD:
            assert (op_CD & 255) == 205
; CMP abs
            ex de,hl
            ld a,(hl)
            inc hl
            ld e,(hl)
            inc hl
            ex de,hl
            ld h,RT>>8
            ld h,(hl)
            ld l,a
            ld a,(hl)
            ld l,a
            ld a,b
            sub l
            ccf
            rla
            ld (fC),a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 4839 - $
op_E7:
            assert (op_E7 & 255) == 231
; ISC zp
            ld a,(de)
            inc de
            ld l,a
            ld h,ZPG>>8
            inc (hl)
            ld a,(hl)
            call do_sbc
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 4863 - $
op_FF:
            assert (op_FF & 255) == 255
; ISC absx
            ex af,af'
            ex de,hl
            ld a,(hl)
            inc hl
            ld e,(hl)
            inc hl
            ex de,hl
            add a,ixl
            jr c,.c1
.k1:
            ld h,WT>>8
            ld h,(hl)
            inc h
            dec h
            jr z,.s2
.b2:
            ld l,a
            ex af,af'
            inc (hl)
            ld a,(hl)
            call do_sbc
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
.s2:
            call wslow_R
            jr .b2
.c1:
            inc l
            jr .k1
            ds cpu_base + 4905 - $
op_29:
            assert (op_29 & 255) == 41
; AND imm
            ld a,(de)
            inc de
            and b
            ld b,a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 4921 - $
op_39:
            assert (op_39 & 255) == 57
; AND absy
            ex de,hl
            ld a,(hl)
            inc hl
            ld e,(hl)
            inc hl
            ex de,hl
            add a,ixh
            jr c,.c1
.k1:
            ld h,RT>>8
            ld h,(hl)
            ld l,a
            ld a,(hl)
            and b
            ld b,a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
.c1:
            inc l
            jr .k1
            ds cpu_base + 4959 - $
op_5F:
            assert (op_5F & 255) == 95
; SRE absx
            ex af,af'
            ex de,hl
            ld a,(hl)
            inc hl
            ld e,(hl)
            inc hl
            ex de,hl
            add a,ixl
            jr c,.c1
.k1:
            ld h,WT>>8
            ld h,(hl)
            inc h
            dec h
            jr z,.s2
.b2:
            ld l,a
            ex af,af'
            srl (hl)
            rla
            ld (fC),a
            ld a,(hl)
            xor b
            ld b,a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
.s2:
            call wslow_R
            jr .b2
.c1:
            inc l
            jr .k1
            ds cpu_base + 5003 - $
op_8B:
            assert (op_8B & 255) == 139
; KIL / nem támogatott
            jp emu_brk
            ds cpu_base + 5055 - $
op_BF:
            assert (op_BF & 255) == 191
; LAX absy
            ex de,hl
            ld a,(hl)
            inc hl
            ld e,(hl)
            inc hl
            ex de,hl
            add a,ixh
            jr c,.c1
.k1:
            ld h,RT>>8
            ld h,(hl)
            ld l,a
            ld a,(hl)
            ld b,a
            ld ixl,a
            or a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
.c1:
            inc l
            jr .k1
            ds cpu_base + 5096 - $
op_E8:
            assert (op_E8 & 255) == 232
; INX imp
            inc ixl
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 5137 - $
op_11:
            assert (op_11 & 255) == 17
; ORA indy
            ld a,(de)
            inc de
            ld l,a
            ld h,ZPG>>8
            ld a,(hl)
            inc l
            ld l,(hl)
            add a,ixh
            jr c,.c1
.k1:
            ld h,RT>>8
            ld h,(hl)
            ld l,a
            ld a,(hl)
            or b
            ld b,a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
.c1:
            inc l
            jr .k1
            ds cpu_base + 5165 - $
op_2D:
            assert (op_2D & 255) == 45
; AND abs
            ex de,hl
            ld a,(hl)
            inc hl
            ld e,(hl)
            inc hl
            ex de,hl
            ld h,RT>>8
            ld h,(hl)
            ld l,a
            ld a,(hl)
            and b
            ld b,a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 5196 - $
op_4C:
            assert (op_4C & 255) == 76
; JMP abs
            ex de,hl
            ld a,(hl)
            inc hl
            ld e,(hl)
            inc hl
            ex de,hl
            ld h,RT>>8
            ld h,(hl)
            ld l,a
            ex de,hl
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 5218 - $
op_62:
            assert (op_62 & 255) == 98
; KIL / nem támogatott
            jp emu_brk
            ds cpu_base + 5223 - $
op_67:
            assert (op_67 & 255) == 103
; RRA zp
            ld a,(de)
            inc de
            ld l,a
            ld h,ZPG>>8
            ld a,(fC)
            rra
            rr (hl)
            rla
            ld (fC),a
            ld a,(hl)
            call do_adc
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 5260 - $
op_8C:
            assert (op_8C & 255) == 140
; STY abs
            ex af,af'
            ex de,hl
            ld a,(hl)
            inc hl
            ld e,(hl)
            inc hl
            ex de,hl
            ld h,WT>>8
            ld h,(hl)
            inc h
            dec h
            jr z,.s1
.b1:
            ld l,a
            ex af,af'
            ld a,ixh
            ld (hl),a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
.s1:
            call wslow_Y
            jr .b1
            ds cpu_base + 5324 - $
op_CC:
            assert (op_CC & 255) == 204
; CPY abs
            ex de,hl
            ld a,(hl)
            inc hl
            ld e,(hl)
            inc hl
            ex de,hl
            ld h,RT>>8
            ld h,(hl)
            ld l,a
            ld a,(hl)
            ld l,a
            ld a,ixh
            sub l
            ccf
            rla
            ld (fC),a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 5357 - $
op_ED:
            assert (op_ED & 255) == 237
; SBC abs
            ex de,hl
            ld a,(hl)
            inc hl
            ld e,(hl)
            inc hl
            ex de,hl
            ld h,RT>>8
            ld h,(hl)
            ld l,a
            ld a,(hl)
            call do_sbc
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 5394 - $
op_12:
            assert (op_12 & 255) == 18
; KIL / nem támogatott
            jp emu_brk
            ds cpu_base + 5418 - $
op_2A:
            assert (op_2A & 255) == 42
; ROL acc
            ld a,(fC)
            rra
            rl b
            rla
            ld (fC),a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 5453 - $
op_4D:
            assert (op_4D & 255) == 77
; EOR abs
            ex de,hl
            ld a,(hl)
            inc hl
            ld e,(hl)
            inc hl
            ex de,hl
            ld h,RT>>8
            ld h,(hl)
            ld l,a
            ld a,(hl)
            xor b
            ld b,a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 5480 - $
op_68:
            assert (op_68 & 255) == 104
; PLA imp
            ld hl,(rS)
            inc l
            ld a,l
            ld (rS),a
            ld a,(hl)
            ld b,a
            or a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 5501 - $
op_7D:
            assert (op_7D & 255) == 125
; ADC absx
            ex de,hl
            ld a,(hl)
            inc hl
            ld e,(hl)
            inc hl
            ex de,hl
            add a,ixl
            jr c,.c1
.k1:
            ld h,RT>>8
            ld h,(hl)
            ld l,a
            ld a,(hl)
            call do_adc
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
.c1:
            inc l
            jr .k1
            ds cpu_base + 5583 - $
op_CF:
            assert (op_CF & 255) == 207
; DCP abs
            ex af,af'
            ex de,hl
            ld a,(hl)
            inc hl
            ld e,(hl)
            inc hl
            ex de,hl
            ld h,WT>>8
            ld h,(hl)
            inc h
            dec h
            jr z,.s1
.b1:
            ld l,a
            ex af,af'
            dec (hl)
            ld a,(hl)
            ld l,a
            ld a,b
            sub l
            ccf
            rla
            ld (fC),a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
.s1:
            call wslow_R
            jr .b1
            ds cpu_base + 5678 - $
op_2E:
            assert (op_2E & 255) == 46
; ROL abs
            ex af,af'
            ex de,hl
            ld a,(hl)
            inc hl
            ld e,(hl)
            inc hl
            ex de,hl
            ld h,WT>>8
            ld h,(hl)
            inc h
            dec h
            jr z,.s1
.b1:
            ld l,a
            ex af,af'
            ld a,(fC)
            rra
            rl (hl)
            rla
            ld (fC),a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
.s1:
            call wslow_R
            jr .b1
            ds cpu_base + 5746 - $
op_72:
            assert (op_72 & 255) == 114
; KIL / nem támogatott
            jp emu_brk
            ds cpu_base + 5752 - $
op_78:
            assert (op_78 & 255) == 120
; SEI imp
            ld a,04h
            ld (fI),a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
            ds cpu_base + 5773 - $
op_8D:
            assert (op_8D & 255) == 141
; STA abs
            ex af,af'
            ex de,hl
            ld a,(hl)
            inc hl
            ld e,(hl)
            inc hl
            ex de,hl
            ld h,WT>>8
            ld h,(hl)
            inc h
            dec h
            jr z,.s1
.b1:
            ld l,a
            ex af,af'
            ld (hl),b
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
.s1:
            ld h,a
            ld a,l
            cp 0D4h
            jr nz,.g1
            ld a,h
            call sid_fast
            ex af,af'
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
.g1:
            ld a,h
            call wslow_A
            jr .b1
            ds cpu_base + 5870 - $
op_EE:
            assert (op_EE & 255) == 238
; INC abs
            ex af,af'
            ex de,hl
            ld a,(hl)
            inc hl
            ld e,(hl)
            inc hl
            ex de,hl
            ld h,WT>>8
            ld h,(hl)
            inc h
            dec h
            jr z,.s1
.b1:
            ld l,a
            ex af,af'
            inc (hl)
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
.s1:
            call wslow_R
            jr .b1
            ds cpu_base + 5937 - $
op_31:
            assert (op_31 & 255) == 49
; AND indy
            ld a,(de)
            inc de
            ld l,a
            ld h,ZPG>>8
            ld a,(hl)
            inc l
            ld l,(hl)
            add a,ixh
            jr c,.c1
.k1:
            ld h,RT>>8
            ld h,(hl)
            ld l,a
            ld a,(hl)
            and b
            ld b,a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
.c1:
            inc l
            jr .k1
            ds cpu_base + 5966 - $
op_4E:
            assert (op_4E & 255) == 78
; LSR abs
            ex af,af'
            ex de,hl
            ld a,(hl)
            inc hl
            ld e,(hl)
            inc hl
            ex de,hl
            ld h,WT>>8
            ld h,(hl)
            inc h
            dec h
            jr z,.s1
.b1:
            ld l,a
            ex af,af'
            srl (hl)
            rla
            ld (fC),a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
.s1:
            call wslow_R
            jr .b1
            ds cpu_base + 6014 - $
op_7E:
            assert (op_7E & 255) == 126
; ROR absx
            ex af,af'
            ex de,hl
            ld a,(hl)
            inc hl
            ld e,(hl)
            inc hl
            ex de,hl
            add a,ixl
            jr c,.c1
.k1:
            ld h,WT>>8
            ld h,(hl)
            inc h
            dec h
            jr z,.s2
.b2:
            ld l,a
            ex af,af'
            ld a,(fC)
            rra
            rr (hl)
            rla
            ld (fC),a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
.s2:
            call wslow_R
            jr .b2
.c1:
            inc l
            jr .k1
            ds cpu_base + 6127 - $
op_EF:
            assert (op_EF & 255) == 239
; ISC abs
            ex af,af'
            ex de,hl
            ld a,(hl)
            inc hl
            ld e,(hl)
            inc hl
            ex de,hl
            ld h,WT>>8
            ld h,(hl)
            inc h
            dec h
            jr z,.s1
.b1:
            ld l,a
            ex af,af'
            inc (hl)
            ld a,(hl)
            call do_sbc
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
.s1:
            call wslow_R
            jr .b1
            ds cpu_base + 6194 - $
op_32:
            assert (op_32 & 255) == 50
; KIL / nem támogatott
            jp emu_brk
            ds cpu_base + 6225 - $
op_51:
            assert (op_51 & 255) == 81
; EOR indy
            ld a,(de)
            inc de
            ld l,a
            ld h,ZPG>>8
            ld a,(hl)
            inc l
            ld l,(hl)
            add a,ixh
            jr c,.c1
.k1:
            ld h,RT>>8
            ld h,(hl)
            ld l,a
            ld a,(hl)
            xor b
            ld b,a
            ld a,(de)
            inc de
            ld l,a
            ld h,c
            ld h,(hl)
            jp (hl)
.c1:
            inc l
            jr .k1
            ds cpu_base + 6482 - $
op_52:
            assert (op_52 & 255) == 82
; KIL / nem támogatott
            jp emu_brk
op_end:

; előjel-kiterjesztés az elágazásokhoz: 0..7Fh -> 0, 80h..FFh -> FFh
            align 256
SEXT:
            ds 128, 0
            ds 128, 0FFh

; az utasításkezelők címének felső bájtja (az alsó az opkód)
            align 256
OPHI:
            db op_00 >> 8, op_01 >> 8, op_02 >> 8, op_03 >> 8, op_04 >> 8, op_05 >> 8, op_06 >> 8, op_07 >> 8
            db op_08 >> 8, op_09 >> 8, op_0A >> 8, op_0B >> 8, op_0C >> 8, op_0D >> 8, op_0E >> 8, op_0F >> 8
            db op_10 >> 8, op_11 >> 8, op_12 >> 8, op_13 >> 8, op_14 >> 8, op_15 >> 8, op_16 >> 8, op_17 >> 8
            db op_18 >> 8, op_19 >> 8, op_1A >> 8, op_1B >> 8, op_1C >> 8, op_1D >> 8, op_1E >> 8, op_1F >> 8
            db op_20 >> 8, op_21 >> 8, op_22 >> 8, op_23 >> 8, op_24 >> 8, op_25 >> 8, op_26 >> 8, op_27 >> 8
            db op_28 >> 8, op_29 >> 8, op_2A >> 8, op_2B >> 8, op_2C >> 8, op_2D >> 8, op_2E >> 8, op_2F >> 8
            db op_30 >> 8, op_31 >> 8, op_32 >> 8, op_33 >> 8, op_34 >> 8, op_35 >> 8, op_36 >> 8, op_37 >> 8
            db op_38 >> 8, op_39 >> 8, op_3A >> 8, op_3B >> 8, op_3C >> 8, op_3D >> 8, op_3E >> 8, op_3F >> 8
            db op_40 >> 8, op_41 >> 8, op_42 >> 8, op_43 >> 8, op_44 >> 8, op_45 >> 8, op_46 >> 8, op_47 >> 8
            db op_48 >> 8, op_49 >> 8, op_4A >> 8, op_4B >> 8, op_4C >> 8, op_4D >> 8, op_4E >> 8, op_4F >> 8
            db op_50 >> 8, op_51 >> 8, op_52 >> 8, op_53 >> 8, op_54 >> 8, op_55 >> 8, op_56 >> 8, op_57 >> 8
            db op_58 >> 8, op_59 >> 8, op_5A >> 8, op_5B >> 8, op_5C >> 8, op_5D >> 8, op_5E >> 8, op_5F >> 8
            db op_60 >> 8, op_61 >> 8, op_62 >> 8, op_63 >> 8, op_64 >> 8, op_65 >> 8, op_66 >> 8, op_67 >> 8
            db op_68 >> 8, op_69 >> 8, op_6A >> 8, op_6B >> 8, op_6C >> 8, op_6D >> 8, op_6E >> 8, op_6F >> 8
            db op_70 >> 8, op_71 >> 8, op_72 >> 8, op_73 >> 8, op_74 >> 8, op_75 >> 8, op_76 >> 8, op_77 >> 8
            db op_78 >> 8, op_79 >> 8, op_7A >> 8, op_7B >> 8, op_7C >> 8, op_7D >> 8, op_7E >> 8, op_7F >> 8
            db op_80 >> 8, op_81 >> 8, op_82 >> 8, op_83 >> 8, op_84 >> 8, op_85 >> 8, op_86 >> 8, op_87 >> 8
            db op_88 >> 8, op_89 >> 8, op_8A >> 8, op_8B >> 8, op_8C >> 8, op_8D >> 8, op_8E >> 8, op_8F >> 8
            db op_90 >> 8, op_91 >> 8, op_92 >> 8, op_93 >> 8, op_94 >> 8, op_95 >> 8, op_96 >> 8, op_97 >> 8
            db op_98 >> 8, op_99 >> 8, op_9A >> 8, op_9B >> 8, op_9C >> 8, op_9D >> 8, op_9E >> 8, op_9F >> 8
            db op_A0 >> 8, op_A1 >> 8, op_A2 >> 8, op_A3 >> 8, op_A4 >> 8, op_A5 >> 8, op_A6 >> 8, op_A7 >> 8
            db op_A8 >> 8, op_A9 >> 8, op_AA >> 8, op_AB >> 8, op_AC >> 8, op_AD >> 8, op_AE >> 8, op_AF >> 8
            db op_B0 >> 8, op_B1 >> 8, op_B2 >> 8, op_B3 >> 8, op_B4 >> 8, op_B5 >> 8, op_B6 >> 8, op_B7 >> 8
            db op_B8 >> 8, op_B9 >> 8, op_BA >> 8, op_BB >> 8, op_BC >> 8, op_BD >> 8, op_BE >> 8, op_BF >> 8
            db op_C0 >> 8, op_C1 >> 8, op_C2 >> 8, op_C3 >> 8, op_C4 >> 8, op_C5 >> 8, op_C6 >> 8, op_C7 >> 8
            db op_C8 >> 8, op_C9 >> 8, op_CA >> 8, op_CB >> 8, op_CC >> 8, op_CD >> 8, op_CE >> 8, op_CF >> 8
            db op_D0 >> 8, op_D1 >> 8, op_D2 >> 8, op_D3 >> 8, op_D4 >> 8, op_D5 >> 8, op_D6 >> 8, op_D7 >> 8
            db op_D8 >> 8, op_D9 >> 8, op_DA >> 8, op_DB >> 8, op_DC >> 8, op_DD >> 8, op_DE >> 8, op_DF >> 8
            db op_E0 >> 8, op_E1 >> 8, op_E2 >> 8, op_E3 >> 8, op_E4 >> 8, op_E5 >> 8, op_E6 >> 8, op_E7 >> 8
            db op_E8 >> 8, op_E9 >> 8, op_EA >> 8, op_EB >> 8, op_EC >> 8, op_ED >> 8, op_EE >> 8, op_EF >> 8
            db op_F0 >> 8, op_F1 >> 8, op_F2 >> 8, op_F3 >> 8, op_F4 >> 8, op_F5 >> 8, op_F6 >> 8, op_F7 >> 8
            db op_F8 >> 8, op_F9 >> 8, op_FA >> 8, op_FB >> 8, op_FC >> 8, op_FD >> 8, op_FE >> 8, op_FF >> 8
