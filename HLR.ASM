;Hyper Lode Runner (Game Boy) disassembly
;Game ©1989 Bandai
;Licensed from ©1983 Brøderbund Software & Doug Smith
;Game Boy version developed by TOSE Software Co Ltd.
;Disassembly by Will Trowbridge & DeepSeek

SECTION "hbank0", ROM0[$0000]


RST00_Reset:
    jp Main_Reset                  ; $0000  ; reset vector: jump to init code
    db $FF,$FF,$FF,$FF,$FF

RST08_Handler:
    jp Mode_Restart                ; $0008  ; rst $08: jump to helper
    db $FF,$FF,$FF,$FF,$FF

RST10_Dispatch:
    pop hl                         ; $0010  ; rst $10: pop return addr into hl
    add a                          ; $0011  ; double A to index 16-bit table
    ld c,a                         ; $0012  ; index low byte into c
    ld b,$00                       ; $0013  ; clear high byte of bc
    add hl,bc                      ; $0015  ; hl -> table entry A*2
    ld a,[hl+]                     ; $0016  ; load jump target low byte
    ld h,[hl]                      ; $0017  ; load jump target high byte
    ld l,a                         ; $0018  ; assemble target in hl
    jp hl                          ; $0019  ; jump to dispatcher entry
    rst $38                        ; $001A  ; FF pad byte
    db $FF,$FF,$FF,$FF,$FF

RST20_Dispatch:
    pop hl                         ; $0020  ; rst $20: pop return addr into hl
    ld c,a                         ; $0021  ; index low byte into c
    ld b,$00                       ; $0022  ; clear high byte of bc
    ld a,[hl+]                     ; $0024  ; read first table byte
    push hl                        ; $0025  ; save table pointer
    add hl,bc                      ; $0026  ; hl -> second table byte
    ld c,a                         ; $0027  ; keep first byte value in c
    ld a,[hl]                      ; $0028  ; read second table byte
    pop hl                         ; $0029  ; restore table pointer
    add hl,bc                      ; $002A  ; add first byte value to hl
    jp hl                          ; $002B  ; jump to computed target
    rst $38                        ; $002C  ; FF pad byte
    db $FF,$FF,$FF

RST30_SubMachine:
    pop hl                         ; $0030  ; rst $30: pop return addr into hl
    ld a,[hl+]                     ; $0031  ; read copy length byte
    ld b,a                         ; $0032  ; save byte count in b

RST30_CopyLoop:
    ld a,[hl+]                     ; $0033  ; loop: read source byte
    ld [de],a                      ; $0034  ; write byte to [de]
    inc de                         ; $0035  ; advance destination pointer
    dec b                          ; $0036  ; decrement counter
    jr nz,RST30_CopyLoop           ; $0037  ; loop until b=0
    jp hl                          ; $0039  ; return past the inline data
    rst $38                        ; $003A  ; FF pad byte
    rst $38                        ; $003B  ; FF pad byte
    db $FF,$FF,$FF,$FF

IRQ_VBlank_Vec:
    jp IRQ_VBlank                  ; $0040  ; VBlank IRQ: jump to main VBlank
    db $FF,$FF,$FF,$FF,$FF

IRQ_Stat_Vec:
    jp IRQ_Stat                    ; $0048  ; STAT IRQ: jump to handler
    db $FF,$FF,$FF,$FF,$FF

IRQ_Timer_Vec:
    jp IRQ_Timer                   ; $0050  ; Timer IRQ: jump to handler
    db $FF,$FF,$FF,$FF,$FF

IRQ_Serial_Vec:
    jp IRQ_Serial                  ; $0058  ; Serial IRQ: jump to handler

Input_ReadJoypad:
    ld a,$20                       ; $005B  ; joypad: select direction row
    ldh [$FF00],a                  ; $005D  ; write select to P1 reg
    ldh a,[$FF00]                  ; $005F  ; read pad (debounce read)
    ldh a,[$FF00]                  ; $0061  ; read directional button bits
    cpl                            ; $0063  ; invert (buttons active-low)
    and $0F                        ; $0064  ; mask direction buttons
    swap a                         ; $0066  ; move dirs to high nibble
    ld b,a                         ; $0068  ; save directions in b
    ld a,$10                       ; $0069  ; joypad: select button row
    ldh [$FF00],a                  ; $006B  ; write select to P1 reg
    ldh a,[$FF00]                  ; $006D  ; read pad (debounce read)
    ldh a,[$FF00]                  ; $006F  ; read pad (debounce read)
    ldh a,[$FF00]                  ; $0071  ; read pad (debounce read)
    ldh a,[$FF00]                  ; $0073  ; read pad (debounce read)
    ldh a,[$FF00]                  ; $0075  ; read pad (debounce read)
    ldh a,[$FF00]                  ; $0077  ; read button key bits
    cpl                            ; $0079  ; invert (buttons active-low)
    and $0F                        ; $007A  ; mask button keys
    or b                           ; $007C  ; merge dirs and buttons
    ld c,a                         ; $007D  ; return pad state in c
    ld a,$30                       ; $007E  ; joypad: deselect both rows
    ldh [$FF00],a                  ; $0080  ; restore P1 to idle
    ret                            ; $0082  ; return (c=state, b=dirs)

DMA_InitToHRAM:
    ld de,$FF80                    ; $0083  ; DMA init: dest = HRAM $FF80
    rst $30                        ; $0086  ; copy inline OAM DMA routine to HRAM
    db $0A,$3E,$DE,$E0,$46,$3E,$28,$3D
    db $20,$FD,$C9,$C9

IRQ_EnableVBlank:
    xor a                          ; $0093  ; clear control flag FF8C
    ldh [$FF8C],a                  ; $0094  ; clear accumulator
    ldh a,[$FFFF]                  ; $0096  ; read IE register
    set 0,a                        ; $0098  ; enable VBlank interrupt bit
    call IRQ_EnableStatTimer       ; $009A  ; enable STAT+Timer IRQ, clear IF
    call Lcd_On                    ; $009D  ; turn LCD on
    ei                             ; $00A0  ; enable interrupts
    ret                            ; $00A1  ; return

IRQ_EnableStatTimer:
    ld b,a                         ; $00A2  ; save IE value
    xor a                          ; $00A3  ; clear accumulator
    ldh [$FF0F],a                  ; $00A4  ; clear IF (interrupt flags)
    ld a,b                         ; $00A6  ; restore IE value
    or $0C                         ; $00A7  ; set STAT+Timer IRQ bits
    ldh [$FFFF],a                  ; $00A9  ; write IE register
    ret                            ; $00AB  ; return

Lcd_On:
    ldh a,[$FFCA]                  ; $00AC  ; read LCDC shadow
    set 7,a                        ; $00AE  ; set LCD enable bit
    ldh [$FFCA],a                  ; $00B0  ; update LCDC shadow
    ldh [$FF40],a                  ; $00B2  ; write real LCDC register
    ret                            ; $00B4  ; return

Lcd_WaitOff:
    ldh a,[$FF44]                  ; $00B5  ; wait: read LY scanline
    cp $91                         ; $00B7  ; compare to line $91
    jr nz,Lcd_WaitOff              ; $00B9  ; loop until past line $90
    ld hl,$FF40                    ; $00BB  ; point hl at LCDC
    res 7,[hl]                     ; $00BE  ; clear LCD enable bit (off)
    ld hl,$FFCA                    ; $00C0  ; point hl at LCDC shadow
    res 7,[hl]                     ; $00C3  ; clear LCD enable bit in shadow
    ret                            ; $00C5  ; return

Scroll_WindowUpdate:
    ldh a,[$FFCC]                  ; $00C6  ; read SCX shadow
    ldh [$FF43],a                  ; $00C8  ; write SCX (scroll X)
    ldh a,[$FFCE]                  ; $00CA  ; read SCY shadow
    ldh [$FF42],a                  ; $00CC  ; write SCY (scroll Y)
    ldh a,[$FFCF]                  ; $00CE  ; read WX value
    call WX_ComputeFromSCX         ; $00D0  ; adjust WX for window scroll
    ldh [$FF4B],a                  ; $00D3  ; write WX (window X)
    ldh a,[$FFD0]                  ; $00D5  ; read WY value
    ldh [$FF4A],a                  ; $00D7  ; write WY (window Y)
    ldh a,[$FFCA]                  ; $00D9  ; read LCDC shadow
    ldh [$FF40],a                  ; $00DB  ; write LCDC register
    ret                            ; $00DD  ; return

WX_ComputeFromSCX:
    push bc                        ; $00DE  ; save bc
    ld b,a                         ; $00DF  ; save WX base value
    cpl                            ; $00E0  ; invert
    and $07                        ; $00E1  ; keep low 3 bits
    ld c,a                         ; $00E3  ; save in c
    ldh a,[$FF43]                  ; $00E4  ; read SCX
    and $07                        ; $00E6  ; keep low 3 bits
    cp c                           ; $00E8  ; compare scroll bits
    jr nz,loc_00EC                 ; $00E9  ; skip if they differ
    inc b                          ; $00EB  ; bump WX by 1

loc_00EC:
    ld a,b                         ; $00EC  ; load result
    pop bc                         ; $00ED  ; restore bc
    ret                            ; $00EE  ; return

Mem_ZeroFill:
    xor a                          ; $00EF  ; clear fill value
    ld [hl+],a                     ; $00F0  ; write 0 and advance hl
    dec bc                         ; $00F1  ; decrement counter
    ld a,b                         ; $00F2  ; test high byte
    or c                           ; $00F3  ; OR with low byte
    jr nz,Mem_ZeroFill             ; $00F4  ; loop until bc=0
    ret                            ; $00F6  ; return
    rst $38                        ; $00F7  ; FF pad byte
    db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF

CartridgeHeader:
    ; Cartridge header: entry point nop; jp $0150
    nop
	jp $0150

NintendoLogo:
    ; Nintendo logo (48 bytes, checked by boot ROM)
    db $CE,$ED,$66,$66,$CC,$0D,$00,$0B
    db $03,$73,$00,$83,$00,$0C,$00,$0D
    db $00,$08,$11,$1F,$88,$89,$00,$0E
    db $DC,$CC,$6E,$E6,$DD,$DD,$D9,$99
    db $BB,$BB,$67,$63,$6E,$0E,$EC,$CC
    db $DD,$DC,$99,$9F,$BB,$B9,$33,$3E

GameTitle:
    ; Title: 'HYPERLODERUNNER'
    db "HYPERLODERUNNER"
	ds 4

CartridgeType:
    ; Cartridge type ($00 = ROM only, no MBC)
    db $00

ROMSize:
    ; ROM size ($00 = 32KB)
    db $00

RAMSize:
    ; RAM size ($00 = none on cart)
    db $00

DestinationCode:
    ; Destination code ($00 = Japan)
    db $00

LicenseeCode:
    ; Old licensee code ($B2 = Bandai)
    db $B2

VersionNumber:
    ; Mask ROM version ($01 = V1.1)
    db $01

HeaderChecksum:
    ; Header checksum ($AE)
    db $AE

GlobalChecksum:
    ; Global checksum ($86BF)
    db $86,$BF

Main_Reset:
    ld sp,$DFFF                    ; $0150  ; reset: set stack, call init chain
    call Lcd_WaitOff               ; $0153  ; wait for LCD off
    call DMA_InitToHRAM            ; $0156  ; install DMA + IRQ enable helpers
    call Init_GameMemory           ; $0159  ; clear game memory / variables
    call SoundEngine_InitWave      ; $015C  ; set up sound wave RAM
    ld de,$DEA2                    ; $015F  ; de=DEA2 (sound engine buffer?)
    rst $30                        ; $0162  ; rst $30: copy 0x1E bytes from following data
    db $03,$E4,$E4,$C4,$21,$AD,$CB,$01
    db $80,$04,$3E,$55,$22,$0B,$78,$B1
    db $20,$F8,$3E,$00

Mode_Restart:
    ldh [$FF8A],a                  ; $0177  ; restart entry: mode = A; set stack
    ld sp,$DFFF                    ; $0179  ; stack to top of WRAM
    xor a                          ; $017C  ; a=0
    call IRQ_EnableStatTimer       ; $017D  ; enable STAT + Timer interrupts
    ld a,$80                       ; $0180  ; a=80
    ldh [$FF40],a                  ; $0182  ; LCDC on
    call Lcd_WaitOff               ; $0184  ; wait for LCD off (sync)
    call SoundEngine_VBlank_Reset  ; $0187  ; power on sound + clear channel masks
    call Clear_Null                ; $018A  ; clear null vars
    ldh a,[$FF8A]                  ; $018D  ; get incoming mode number
    and $FE                        ; $018F  ; mask bit0
    cp $06                         ; $0191  ; cp 06
    call nz,Bg_ClearText           ; $0193  ; if mode!=6 call loc_3C64
    call Action_Dispatcher         ; $0196  ; update runner/object engine
    call loc_3B6F                  ; $0199  ; call 3B6F (scroll?)
    call BgPals_Load               ; $019C  ; call 3B59
    ld hl,$FFCA                    ; $019F  ; hl=FFCA (LCDC shadow)
    ld a,$03                       ; $01A2  ; a=03
    ld [hl+],a                     ; $01A4  ; FFCA=03 (LCDC init value)
    xor a                          ; $01A5  ; a=0
    ld [hl+],a                     ; $01A6  ; FFCB=0
    ld [hl+],a                     ; $01A7  ; FFCC=0
    ld [hl+],a                     ; $01A8  ; FFCD=0
    ld [hl],a                      ; $01A9  ; FFCE=0
    ldh [$FFC6],a                  ; $01AA  ; FFC6=0
    ldh [$FFC7],a                  ; $01AC  ; FFC7=0
    ldh [$FFC5],a                  ; $01AE  ; FFC5=0
    ldh [$FF98],a                  ; $01B0  ; FF98=0
    ldh [$FF8F],a                  ; $01B2  ; FF8F=0
    ldh [$FFD4],a                  ; $01B4  ; FFD4=0
    ldh [$FFD5],a                  ; $01B6  ; FFD5=0
    ldh a,[$FF90]                  ; $01B8  ; check FF90 bit3
    bit 3,a                        ; $01BA  ; if game mode bit clear
    call z,Score_UpdateBest        ; $01BC  ; call loc_33A5 (set bg palette)
    ldh a,[$FF8A]                  ; $01BF  ; dispatch on mode (FF8A)
    rst $10                        ; $01C1  ; rst $10: jump table 16 entries
    dw $0242,$0275,$02AD,$0327
    dw $0347,$03E0,$0408,$043A
    dw $0456,$046F,$03D1,$0480
    dw $0480,$0496,$0301,$0242

IRQ_VBlank:
    push af                        ; $01E2  ; VBlank interrupt: save regs
    push bc                        ; $01E3  ; save bc
    push de                        ; $01E4  ; save de
    push hl                        ; $01E5  ; save hl
    ldh a,[$FF8C]                  ; $01E6  ; if already in VBlank (FF8C)
    and a                          ; $01E8  ; test FF8C
    jp nz,IRQ_VBlank_QuickExit     ; $01E9  ; if set -> quick exit
    call $FF80                     ; $01EC  ; call DMA copy routine ($FF80)
    ei                             ; $01EF  ; enable interrupts
    ld a,$FF                       ; $01F0  ; FF8C=FF (mark in-vblank)
    ldh [$FF8C],a                  ; $01F2  ; FF8C busy flag
    inc a                          ; $01F4  ; a=0
    ld [$DEA0],a                   ; $01F5  ; DEA0=0
    call Sound_Dispatcher          ; $01F8  ; sound schedule / advance
    call Action_Dispatcher         ; $01FB  ; update runner engine
    ld a,[$DEA0]                   ; $01FE  ; read DEA0
    call loc_3C74                  ; $0201  ; call 3C74 (mode-specific update?)
    call Ctrl_ReadMerge            ; $0204  ; call 3B66
    call Serial_Poll               ; $0207  ; call 09D7
    call Title_CheckReset          ; $020A  ; call 3D35
    xor a                          ; $020D  ; a=0
    ldh [$FF8C],a                  ; $020E  ; FF8C=0 (clear in-vblank)
    pop hl                         ; $0210  ; restore hl
    pop de                         ; $0211  ; restore de
    pop bc                         ; $0212  ; restore bc
    pop af                         ; $0213  ; restore af
    reti                           ; $0214  ; return from interrupt

IRQ_VBlank_QuickExit:
    ldh a,[$FFCA]                  ; $0215  ; quick exit: restore LCDC shadow
    ldh [$FF40],a                  ; $0217  ; FF40=FFCA
    pop hl                         ; $0219  ; restore hl
    pop de                         ; $021A  ; restore de
    pop bc                         ; $021B  ; restore bc
    pop af                         ; $021C  ; restore af
    ret                            ; $021D  ; ret

IRQ_Stat:
    push af                        ; $021E  ; STAT interrupt: save regs
    push bc                        ; $021F
    push de                        ; $0220
    push hl                        ; $0221
    call STAT_Handler              ; $0222  ; call 0B73 (STAT handler)
    pop hl                         ; $0225  ; restore hl
    pop de                         ; $0226  ; restore de
    pop bc                         ; $0227  ; restore bc
    pop af                         ; $0228  ; restore af
    reti                           ; $0229  ; reti

IRQ_Timer:
    push af                        ; $022A  ; Timer interrupt: save regs
    push bc                        ; $022B
    push de                        ; $022C
    push hl                        ; $022D
    call Timer_Tick                ; $022E  ; call 0B5A (timer handler)
    pop hl                         ; $0231  ; restore hl
    pop de                         ; $0232  ; restore de
    pop bc                         ; $0233  ; restore bc
    pop af                         ; $0234  ; restore af
    reti                           ; $0235  ; reti

IRQ_Serial:
    push af                        ; $0236  ; Serial interrupt: save regs
    push bc                        ; $0237
    push de                        ; $0238
    push hl                        ; $0239
    call Serial_Handler            ; $023A  ; call 0939 (serial/joypad handler)
    pop hl                         ; $023D  ; restore hl
    pop de                         ; $023E  ; restore de
    pop bc                         ; $023F  ; restore bc
    pop af                         ; $0240  ; restore af
    reti                           ; $0241  ; reti

Mode_Title:
    call Gfx_LoadTileset_1800      ; $0242  ; title mode: draw title screen
    ld hl,$1A34                    ; $0245  ; hl=1A34 title bitmap
    call Bg_WriteBlock             ; $0248  ; call 3D05 (draw bg block)
    xor a                          ; $024B  ; a=0
    call Score_SetA1               ; $024C  ; call 3397 (clear palette/attr?)
    call Score_SetA4               ; $024F  ; call 339E
    ld a,$16                       ; $0252  ; a=16
    call Sfx_PlayB                 ; $0254  ; call 3E45 (play SFX 16)
    xor a                          ; $0257  ; a=0
    ldh [$FFD6],a                  ; $0258  ; FFD6=0
    ldh [$FF9C],a                  ; $025A  ; FF9C=0
    ldh [$FFAF],a                  ; $025C  ; FFAF=0
    ldh [$FFB0],a                  ; $025E  ; FFB0=0
    ldh [$FFB1],a                  ; $0260  ; FFB1=0
    ld [$C000],a                   ; $0262  ; C000=0
    ldh [$FF90],a                  ; $0265  ; FF90=0
    ld a,$80                       ; $0267  ; a=80
    ldh [$FF8D],a                  ; $0269  ; FF8D=80 (enable flag)
    call Serial_RecvByte           ; $026B  ; call 3C50
    xor a                          ; $026E  ; a=0
    call Mode_Set                  ; $026F  ; set mode 0 (title), restart

loc_0272:
    halt                           ; $0272  ; halt (wait for interrupt)
    jr loc_0272                    ; $0273  ; loop forever

Mode_NameEntry:
    call Gfx_LoadTileset_1800      ; $0275  ; name entry mode: draw screen
    ld hl,$1AF3                    ; $0278  ; hl=1AF3
    call Bg_WriteBlock             ; $027B  ; draw bg block
    ld hl,$1880                    ; $027E  ; hl=1880
    call Bg_WriteBlock             ; $0281  ; draw bg block
    ld bc,$0500                    ; $0284  ; bc=0500
    call Score_AddBCD              ; $0287  ; call 3359 (clear region)
    call Bonus_GenCode             ; $028A  ; call 3A56
    ld a,$40                       ; $028D  ; a=40
    ldh [$FF41],a                  ; $028F  ; STAT reg $FF41=40 (LYC mode)
    ld a,$0B                       ; $0291  ; a=0B
    ldh [$FFCA],a                  ; $0293  ; FFCA=0B (LCDC value)
    call STAT_Plain_Lyc            ; $0295  ; call 0C0B

loc_0298:
    ld a,$98                       ; $0298  ; a=98
    ldh [$FFD1],a                  ; $029A  ; FFD1=98 (scroll? target)
    xor a                          ; $029C  ; a=0
    call Player_Reset              ; $029D  ; call 33D2
    ld a,$02                       ; $02A0  ; a=2
    call IRQ_EnableStatTimer       ; $02A2  ; enable STAT/Timer
    ld a,$01                       ; $02A5  ; a=1
    call Mode_Set                  ; $02A7  ; set mode 1 (name entry), restart

loc_02AA:
    halt                           ; $02AA  ; halt loop
    jr loc_02AA                    ; $02AB  ; loop

Mode_LevelSelect:
    call Gfx_LoadTileset_1800      ; $02AD  ; level select mode: draw
    ld hl,$186E                    ; $02B0  ; hl=186E
    call Bg_WriteBlock             ; $02B3  ; draw bg block
    ld hl,$9849                    ; $02B6  ; hl=9849
    call Gfx_DrawBanner            ; $02B9  ; call 0507 (draw banner)
    ldh a,[$FFB4]                  ; $02BC  ; FFB4==0A?
    cp $0A                         ; $02BE  ; check FFB4
    jr z,loc_02EC                  ; $02C0  ; if 10 -> skip level select text
    ldh a,[$FF9D]                  ; $02C2  ; current level FF9D
    cp $0F                         ; $02C4  ; cp 0F
    jr c,loc_02D4                  ; $02C6  ; if level<15 skip
    ld hl,$185E                    ; $02C8  ; hl=185E
    call Bg_WriteBlock             ; $02CB  ; draw bg block (higher levels text)
    call Bonus_GenCode             ; $02CE  ; call 3A56
    call Title_WriteCode           ; $02D1  ; call 3A38

loc_02D4:
    ld bc,$0500                    ; $02D4  ; bc=0500
    call Score_AddBCD              ; $02D7  ; call 3359 (clear)
    ldh a,[$FF9D]                  ; $02DA  ; level FF9D
    cp $31                         ; $02DC  ; cp 31
    jr nc,loc_02E3                 ; $02DE  ; if >= 49 skip
    inc a                          ; $02E0  ; level++
    ldh [$FF9D],a                  ; $02E1  ; FF9D++

loc_02E3:
    ldh a,[$FFAA]                  ; $02E3  ; check FFAA
    cp $08                         ; $02E5  ; cp 08
    jr nc,loc_02EC                 ; $02E7  ; if >= 8 skip
    inc a                          ; $02E9  ; increment
    ldh [$FFAA],a                  ; $02EA  ; FFAA++

loc_02EC:
    ld a,$01                       ; $02EC  ; a=1
    call Player_Reset              ; $02EE  ; call 33D2
    call Gfx_SplitOn               ; $02F1  ; call 146D
    ld a,$02                       ; $02F4  ; a=2
    call IRQ_EnableStatTimer       ; $02F6  ; enable interrupts
    ld a,$02                       ; $02F9  ; a=2
    call Mode_Set                  ; $02FB  ; mode 2 restart

loc_02FE:
    halt                           ; $02FE  ; halt loop
    jr loc_02FE                    ; $02FF  ; loop

Mode_Options:
    call Gfx_LoadTileset_1800      ; $0301  ; options mode: draw screen
    ld hl,$18DD                    ; $0304  ; hl=18DD
    call Bg_WriteBlock             ; $0307  ; draw bg block
    ld hl,$1880                    ; $030A  ; hl=1880
    call Bg_WriteBlock             ; $030D  ; draw bg block
    ldh a,[$FF90]                  ; $0310  ; FF90 mask &CC
    and $CC                        ; $0312  ; clear option bits
    ldh [$FF90],a                  ; $0314  ; store FF90
    ld a,$02                       ; $0316  ; a=2
    call Player_Reset              ; $0318  ; call 33D2
    ldh [$FF96],a                  ; $031B  ; FF96=a (result?)
    ldh [$FF97],a                  ; $031D  ; FF97=a
    ld a,$0E                       ; $031F  ; a=0E
    call Mode_Set                  ; $0321  ; mode 0E restart

loc_0324:
    halt                           ; $0324  ; halt loop
    jr loc_0324                    ; $0325  ; loop

Mode_HighScore:
    call Gfx_LoadTileset_1800      ; $0327  ; high score mode: draw
    ld hl,$18B9                    ; $032A  ; hl=18B9
    call Bg_WriteBlock             ; $032D  ; draw bg block
    ld hl,$98EB                    ; $0330  ; hl=98EB
    call Text_PrintScore_D0_3      ; $0333  ; call 0542 (draw score line)
    ld hl,$992B                    ; $0336  ; hl=992B
    call Text_PrintScore_D0        ; $0339  ; call 0537 (draw score line)
    call Sfx_Credits               ; $033C  ; call 3462
    ld a,$03                       ; $033F  ; a=3
    call Mode_Set                  ; $0341  ; mode 3 restart

loc_0344:
    halt                           ; $0344  ; halt loop
    jr loc_0344                    ; $0345  ; loop

Mode_MainMenu:
    ld hl,$FF90                    ; $0347  ; main menu mode
    res 0,[hl]                     ; $034A  ; clear FF90 bit0
    ldh a,[$FFAA]                  ; $034C  ; check FFAA (state)
    and a                          ; $034E  ; test
    jr nz,Menu_Begin               ; $034F  ; if set skip start
    ld a,$03                       ; $0351  ; a=3
    rst $08                        ; $0353  ; rst $08: jump to mode 3 (restart as highscore)

Menu_Begin:
    call Gfx_LoadTileset_1800      ; $0354  ; menu: redraw
    ldh a,[$FF90]                  ; $0357  ; FF90 bit3?
    bit 3,a                        ; $0359  ; test
    jr nz,loc_0377                 ; $035B  ; if game running skip title
    ld hl,$17E7                    ; $035D  ; hl=17E7
    call Bg_WriteBlock             ; $0360  ; draw bg block
    ld hl,$9890                    ; $0363  ; hl=9890
    call Text_PutAttr_D0           ; $0366  ; call 0529
    ld hl,$98EB                    ; $0369  ; hl=98EB
    call Text_PrintScore_D0_3      ; $036C  ; call 0542
    ld hl,$992B                    ; $036F  ; hl=992B
    call Text_PrintScore_D0        ; $0372  ; call 0537
    jr Menu_DrawMenu               ; $0375  ; jump to menu draw

loc_0377:
    ld hl,$1841                    ; $0377  ; hl=1841
    call Bg_WriteBlock             ; $037A  ; draw bg block

Menu_DrawMenu:
    ldh a,[$FF90]                  ; $037D  ; menu: check options bits
    bit 3,a                        ; $037F  ; FF90 bit3
    jr z,Menu_Setup                ; $0381  ; if clear -> skip menu
    bit 4,a                        ; $0383  ; FF90 bit4
    jr z,Menu_StartGame            ; $0385  ; if clear -> 039E
    bit 2,a                        ; $0387  ; FF90 bit2
    ld a,$00                       ; $0389  ; a=0
    push af                        ; $038B  ; push flag
    call nz,Score_SetA1            ; $038C  ; if bit2 set call 3397
    pop af                         ; $038F  ; pop af
    call z,Score_SetA4             ; $0390  ; if bit2 clear call 339E
    ld a,$70                       ; $0393  ; a=70
    call FIFO_Push                 ; $0395  ; call 0A3E (play click?)
    xor a                          ; $0398  ; a=0
    ldh [$FF9C],a                  ; $0399  ; FF9C=0
    ld a,$05                       ; $039B  ; a=5
    rst $08                        ; $039D  ; rst $08: jump to mode 5

Menu_StartGame:
    xor a                          ; $039E  ; start game: clear attrs
    call Score_SetA1               ; $039F  ; call 3397
    call Score_SetA4               ; $03A2  ; call 339E
    call Serial_Send_Start         ; $03A5  ; call 0A07
    ld a,$B4                       ; $03A8  ; a=B4
    ldh [$FFAC],a                  ; $03AA  ; FFAC=B4
    ld a,$44                       ; $03AC  ; a=44
    call Timer_SetCount            ; $03AE  ; call 3C31
    xor a                          ; $03B1  ; a=0
    ldh [$FFAB],a                  ; $03B2  ; FFAB=0
    call Timer_SetCtrl             ; $03B4  ; call 3C37

Menu_Setup:
    ldh a,[$FF9D]                  ; $03B7  ; menu setup: save level
    ldh [$FF9E],a                  ; $03B9  ; FF9E=FF9D
    xor a                          ; $03BB  ; a=0
    ldh [$FFD6],a                  ; $03BC  ; FFD6=0
    ldh [$FF9C],a                  ; $03BE  ; FF9C=0
    ld hl,$D231                    ; $03C0  ; hl=D231
    ld b,$07                       ; $03C3  ; b=7

loc_03C5:
    ld [hl+],a                     ; $03C5  ; fill D231.. with 0
    dec b                          ; $03C6  ; loop
    jr nz,loc_03C5                 ; $03C7  ; until b=0
    ld a,$04                       ; $03C9  ; a=4
    call Mode_Set                  ; $03CB  ; mode 4 restart

loc_03CE:
    halt                           ; $03CE  ; halt loop
    jr loc_03CE                    ; $03CF  ; loop

Mode_GameEnter:
    ldh a,[$FF9F]                  ; $03D1  ; game enter mode
    and $06                        ; $03D3  ; FF9F &06
    ld e,$90                       ; $03D5  ; e=90
    call Mul16_AxDE                ; $03D7  ; call 3D68
    ld de,$CBAD                    ; $03DA  ; de=CBAD
    add hl,de                      ; $03DD  ; hl += CBAD
    jr loc_03E8                    ; $03DE  ; jump to 03E8

Mode_GameLoad:
    ldh a,[$FF9D]                  ; $03E0  ; game load mode
    ld hl,$4B56                    ; $03E2  ; hl=4B56 (level table)
    call Table16_Get               ; $03E5  ; call 3CBC (index by FF9D)

loc_03E8:
    call Level_Setup               ; $03E8  ; load level: call 120A
    call Scroll_Done               ; $03EB  ; call 14F0 (init level)

Mode_GameLoop:
    call Gfx_SplitOn               ; $03EE  ; game loop: update
    xor a                          ; $03F1  ; a=0
    ldh [$FFD7],a                  ; $03F2  ; FFD7=0
    ldh [$FFAD],a                  ; $03F4  ; FFAD=0
    ld hl,$FF90                    ; $03F6  ; hl=FF90
    res 6,[hl]                     ; $03F9  ; clear FF90 bit6
    ld a,$02                       ; $03FB  ; a=2
    call IRQ_EnableStatTimer       ; $03FD  ; enable interrupts
    ldh a,[$FF8A]                  ; $0400  ; mode FF8A
    call Mode_Set                  ; $0402  ; mode 6 restart

loc_0405:
    halt                           ; $0405  ; halt loop
    jr loc_0405                    ; $0406  ; loop

Mode_GameRender:
    call Gfx_LoadTileset_1000      ; $0408  ; game render mode
    ld de,$C96B                    ; $040B  ; de=C96B (level buffer)
    ld hl,$9C21                    ; $040E  ; hl=9C21 (VRAM tile map)
    ld c,$10                       ; $0411  ; c=16 rows

loc_0413:
    ld b,$12                       ; $0413  ; b=18 columns

loc_0415:
    ld a,[de]                      ; $0415  ; read buffer byte
    inc de                         ; $0416  ; next buffer
    and $0F                        ; $0417  ; low nibble
    cp $05                         ; $0419  ; cp 5
    jr c,loc_041F                  ; $041B  ; if <5 use value
    ld a,$3C                       ; $041D  ; else tile 3C

loc_041F:
    or $C0                         ; $041F  ; or C0 (flip/attr)
    ld [hl+],a                     ; $0421  ; write to VRAM
    dec b                          ; $0422  ; dec column
    jr nz,loc_0415                 ; $0423  ; loop columns
    ld a,l                         ; $0425  ; hl low + 0E
    add $0E                        ; $0426  ; advance to next row
    ld l,a                         ; $0428  ; store
    jr nc,loc_042C                 ; $0429  ; carry?
    inc h                          ; $042B  ; inc h

loc_042C:
    dec c                          ; $042C  ; dec row
    jr nz,loc_0413                 ; $042D  ; loop rows
    call Gfx_ShowFullScreen        ; $042F  ; show full screen
    ld a,$06                       ; $0432  ; a=6
    call Mode_Set                  ; $0434  ; mode 6 restart

loc_0437:
    halt                           ; $0437  ; halt loop
    jr loc_0437                    ; $0438  ; loop

Mode_GameStart:
    call Gfx_InitBank0             ; $043A  ; game start mode
    call Gfx_DrawHud               ; $043D  ; call 04BE (HUD)
    call Snd_StopFlag              ; $0440  ; call 3E3B
    ldh a,[$FF92]                  ; $0443  ; FF92 -> FF8A (next mode)
    ldh [$FF8A],a                  ; $0445  ; store mode
    ldh a,[$FF93]                  ; $0447  ; FF93 -> FFCC
    ldh [$FFCC],a                  ; $0449  ; store
    ldh a,[$FF94]                  ; $044B  ; FF94 -> FFCE
    ldh [$FFCE],a                  ; $044D  ; store
    ldh a,[$FF95]                  ; $044F  ; FF95 -> FF91
    ldh [$FF91],a                  ; $0451  ; store
    jp Mode_GameLoop               ; $0453  ; jump to game loop

Mode_Pause:
    ld hl,$FF90                    ; $0456  ; pause mode
    set 0,[hl]                     ; $0459  ; set FF90 bit0
    call Gfx_LoadTileset_1800      ; $045B  ; load tileset 1800
    ld hl,$182F                    ; $045E  ; hl=182F
    call Bg_WriteBlock             ; $0461  ; draw bg block
    xor a                          ; $0464  ; a=0
    ldh [$FF9C],a                  ; $0465  ; FF9C=0
    ld a,$08                       ; $0467  ; a=8
    call Mode_Set                  ; $0469  ; mode 8 restart

loc_046C:
    halt                           ; $046C  ; halt loop
    jr loc_046C                    ; $046D  ; loop

Mode_Credits:
    call Gfx_LoadTileset_1800      ; $046F  ; credits mode
    call Level_Preview             ; $0472  ; call 1526
    call Gfx_ShowFullScreen        ; $0475  ; show full screen
    ld a,$09                       ; $0478  ; a=9
    call Mode_Set                  ; $047A  ; mode 9 restart

loc_047D:
    halt                           ; $047D  ; halt loop
    jr loc_047D                    ; $047E  ; loop

Mode_GameRun:
    call Level_Retry               ; $0480  ; game run mode
    call Scroll_Done               ; $0483  ; call 12ED (update)
    call Gfx_SplitOn               ; $0486  ; call 14F0 (physics)
    ld a,$02                       ; $0489  ; call 146D (HUD update)
    call IRQ_EnableStatTimer       ; $048B  ; a=2
    ld a,$0C                       ; $048E  ; a=0C
    call Mode_Set                  ; $0490  ; mode 0C restart

loc_0493:
    halt                           ; $0493  ; halt loop
    jr loc_0493                    ; $0494  ; loop

Mode_NextGame:
    ldh a,[$FF90]                  ; $0496  ; next game mode
    bit 0,a                        ; $0498  ; FF90 bit0
    ld a,$05                       ; $049A  ; a=5
    jr z,Mode_SetAndJump           ; $049C  ; if not paused -> mode 5
    ld a,$0A                       ; $049E  ; else a=0A

Mode_SetAndJump:
    rst $08                        ; $04A0  ; jump via rst 08

Gfx_LoadTileset_1800:
    ld bc,$1800                    ; $04A1  ; load 0x1800 bytes tileset
    jr Gfx_LoadTileset_From677A    ; $04A4  ; jump to copy

Gfx_LoadTileset_1000:
    ld bc,$1000                    ; $04A6  ; load 0x1000 bytes tileset

Gfx_LoadTileset_From677A:
    ld hl,$677A                    ; $04A9  ; copy $677A -> $8000
    ld de,$8000                    ; $04AC  ; de=8000 VRAM
    jp Mem_CopyBC                  ; $04AF  ; jump to DMA copy

Gfx_ShowFullScreen:
    ldh a,[$FFCA]                  ; $04B2  ; show full screen (LCDC bit3)
    set 3,a                        ; $04B4  ; set bit3
    ldh [$FFCA],a                  ; $04B6  ; FFCA|=8
    ld hl,$19B7                    ; $04B8  ; hl=19B7
    jp Bg_WriteBlock               ; $04BB  ; draw bg block

Gfx_DrawHud:
    ldh a,[$FF90]                  ; $04BE  ; draw HUD (game mode)
    bit 3,a                        ; $04C0  ; FF90 bit3?
    jr z,Gfx_DrawHud_Plain         ; $04C2  ; if clear -> plain HUD
    ld hl,$1A22                    ; $04C4  ; hl=1A22
    call Bg_WriteBlock             ; $04C7  ; draw
    ld hl,$19F6                    ; $04CA  ; hl=19F6
    call Bg_WriteBlock             ; $04CD  ; draw
    ld hl,$1A0C                    ; $04D0  ; hl=1A0C
    call Bg_WriteBlock             ; $04D3  ; draw
    ld hl,$9C21                    ; $04D6  ; hl=9C21
    ld de,$FFA3                    ; $04D9  ; de=FFA3
    call Text_PrintScore_HL50      ; $04DC  ; call 055C (print number)
    ld hl,$9C29                    ; $04DF  ; hl=9C29
    call Text_PrintScore_100       ; $04E2  ; call 057A
    ld hl,$9C2D                    ; $04E5  ; hl=9C2D
    ld de,$FFA6                    ; $04E8  ; de=FFA6
    jp Text_PrintScore_HL50        ; $04EB  ; call 055C

Gfx_DrawHud_Plain:
    ld hl,$19D9                    ; $04EE  ; plain HUD: draw
    call Bg_WriteBlock             ; $04F1  ; hl=19D9
    ld hl,$9C21                    ; $04F4  ; draw bg block
    call Text_PrintScore_50        ; $04F7  ; hl=9C21
    ld hl,$9C2B                    ; $04FA  ; call 053E
    call Text_PutAttr_50           ; $04FD  ; hl=9C2B
    ld hl,$9C31                    ; $0500  ; call 0525
    ld e,$50                       ; $0503  ; e=50
    jr Text_PutChar_Attr           ; $0505  ; jump to put char

Gfx_DrawBanner:
    ld e,$D0                       ; $0507  ; banner draw: e=D0

Text_PutChar_Attr:
    ldh a,[$FF90]                  ; $0509  ; put char with attr
    bit 0,a                        ; $050B  ; FF90 bit0?
    jr z,Text_PrintDigitHigh       ; $050D  ; if clear -> ret
    ldh a,[$FF9F]                  ; $050F  ; FF9F srl
    srl a                          ; $0511  ; shift
    inc a                          ; $0513  ; inc a
    or e                           ; $0514  ; or e (attr)
    inc hl                         ; $0515  ; next char pos
    ld [hl],a                      ; $0516  ; write tile
    ret                            ; $0517  ; ret

Text_PrintDigitHigh:
    ldh a,[$FF9D]                  ; $0518  ; print 2-digit number at hl from FF9D+1
    inc a                          ; $051A  ; level+1
    call Div10_BC                  ; $051B  ; split into b/c digits
    ld a,b                         ; $051E  ; tens digit
    or e                           ; $051F  ; attr
    ld [hl+],a                     ; $0520  ; write tens tile
    ld a,c                         ; $0521  ; ones digit
    or e                           ; $0522  ; attr
    ld [hl],a                      ; $0523  ; write ones tile
    ret                            ; $0524  ; ret

Text_PutAttr_50:
    ld e,$50                       ; $0525  ; e=50 (white palette attr)
    jr Text_PutAttr                ; $0527  ; jump to put

Text_PutAttr_D0:
    ld e,$D0                       ; $0529  ; e=D0 (dark palette attr)

Text_PutAttr:
    ldh a,[$FF90]                  ; $052B  ; put single char tile at hl
    bit 0,a                        ; $052D  ; FF90 bit0?
    ret nz                         ; $052F  ; if paused skip
    ldh a,[$FFAA]                  ; $0530  ; FFAA low nibble
    and $0F                        ; $0532  ; value
    or e                           ; $0534  ; or attr
    ld [hl],a                      ; $0535  ; write tile
    ret                            ; $0536  ; ret

Text_PrintScore_D0:
    ld c,$D0                       ; $0537  ; c=D0 attr, de=FFA9
    ld de,$FFA9                    ; $0539  ; source FF..FF
    jr Text_PrintScore3            ; $053C  ; jump to print

Text_PrintScore_50:
    ld c,$50                       ; $053E  ; c=50 attr
    jr Text_PrintScore_From        ; $0540  ; jump to print

Text_PrintScore_D0_3:
    ld c,$D0                       ; $0542  ; c=D0 attr

Text_PrintScore_From:
    ld de,$FFA3                    ; $0544  ; de=FFA3

Text_PrintScore3:
    ld b,$03                       ; $0547  ; print 3 BCD digits at hl

Text_PrintScore_Loop:
    ld a,[de]                      ; $0549  ; loop: high nibble of [de]
    swap a                         ; $054A  ; swap
    and $0F                        ; $054C  ; low nibble
    or c                           ; $054E  ; or attr
    ld [hl+],a                     ; $054F  ; write tile
    ld a,[de]                      ; $0550  ; low nibble of [de]
    and $0F                        ; $0551  ; value
    or c                           ; $0553  ; or attr
    ld [hl+],a                     ; $0554  ; write tile
    dec de                         ; $0555  ; de--
    dec b                          ; $0556  ; loop count
    jr nz,Text_PrintScore_Loop     ; $0557  ; loop
    ld a,c                         ; $0559  ; attr
    ld [hl],a                      ; $055A  ; write blank tile
    ret                            ; $055B  ; ret

Text_PrintScore_HL50:
    ld c,$50                       ; $055C  ; c=50, print 3 digits
    jp Text_PrintScoreBcd          ; $055E  ; jump to bcd print

Text_PrintScore_HLD0:
    ld c,$D0                       ; $0561  ; c=D0 attr

Text_PrintScoreBcd:
    ld b,$03                       ; $0563  ; b=3 digits
    jr Text_PrintScoreBcd_Lo       ; $0565  ; jump into loop

Text_PrintScoreBcd_Loop:
    ld a,[de]                      ; $0567  ; loop: high nibble
    swap a                         ; $0568  ; swap
    and $0F                        ; $056A  ; value
    or c                           ; $056C  ; or attr
    ld [hl+],a                     ; $056D  ; write tile

Text_PrintScoreBcd_Lo:
    ld a,[de]                      ; $056E  ; low nibble
    and $0F                        ; $056F  ; value
    or c                           ; $0571  ; or attr
    ld [hl+],a                     ; $0572  ; write tile
    dec de                         ; $0573  ; de--
    dec b                          ; $0574  ; loop count
    jr nz,Text_PrintScoreBcd_Loop  ; $0575  ; loop
    ld a,c                         ; $0577  ; attr
    ld [hl],a                      ; $0578  ; write blank
    ret                            ; $0579  ; ret

Text_PrintScore_100:
    ld e,$50                       ; $057A  ; print score up to 100s
    ldh a,[$FFAC]                  ; $057C  ; FFAC-100
    sub $64                        ; $057E  ; borrow?
    push af                        ; $0580  ; save
    ld a,$FC                       ; $0581  ; a=FC (dash tile)
    jr c,Text_PrintScore_100_Put   ; $0583  ; if <100
    ld a,$01                       ; $0585  ; else a=01 (1 tile)
    or e                           ; $0587  ; or attr

Text_PrintScore_100_Put:
    ld [hl+],a                     ; $0588  ; write hundreds tile
    pop af                         ; $0589  ; restore
    jr nc,Text_PrintScore_100_Tail ; $058A  ; if >=100
    add $64                        ; $058C  ; add 100 back

Text_PrintScore_100_Tail:
    call Div10_BC                  ; $058E  ; split tens/ones
    ld a,b                         ; $0591  ; tens
    or e                           ; $0592  ; attr
    ld [hl+],a                     ; $0593  ; write
    ld a,c                         ; $0594  ; ones
    or e                           ; $0595  ; attr
    ld [hl],a                      ; $0596  ; write
    ret                            ; $0597  ; ret

Mode_Set:
    ldh [$FF8B],a                  ; $0598  ; set new mode in FF8B + restart
    call Scroll_WindowUpdate       ; $059A  ; scroll/window sync
    jp IRQ_EnableVBlank            ; $059D  ; jump to VBlank IRQ enable

Sound_Dispatcher:
    ldh a,[$FF8B]                  ; $05A0  ; sound/timer dispatcher on FF8B
    rst $10                        ; $05A2  ; rst $10: 16 sub-state handlers
    dw $05C3,$067B,$0684,$06BB
    dw $06C4,$0811,$08A4,$074B
    dw $08CF,$092D,$0811,$0936
    dw $0811,$05A0,$0690,$05A0

Sound_Update:
    ld a,$03                       ; $05C3  ; state 0: music/update core
    ldh [$FF42],a                  ; $05C5  ; SCY=3
    ldh a,[$FFD6]                  ; $05C7  ; FFD6 countdown
    and a                          ; $05C9  ; zero?
    jr z,Sound_Update_IO           ; $05CA  ; if 0 skip
    dec a                          ; $05CC  ; dec
    ldh [$FFD6],a                  ; $05CD  ; store
    jr z,Sound_Update_Reset        ; $05CF  ; if reached 0
    cp $10                         ; $05D1  ; ==16?
    jr nz,Sound_Update_Tw          ; $05D3  ; if not
    ldh a,[$FF90]                  ; $05D5  ; FF90 bit2
    bit 2,a                        ; $05D7  ; test
    call nz,Serial_Send            ; $05D9  ; call 3C3E
    jp Sound_Update_Dispatch2      ; $05DC  ; jump to dispatch

Sound_Update_Tw:
    cp $12                         ; $05DF  ; ==18?
    call z,Serial_RecvByte         ; $05E1  ; call 3C50
    jp Sound_Update_Dispatch2      ; $05E4  ; jump to dispatch

Sound_Update_Reset:
    ldh a,[$FF90]                  ; $05E7  ; countdown ended
    bit 3,a                        ; $05E9  ; FF90 bit3
    jr z,Sound_Update_IO           ; $05EB  ; if not in game
    xor a                          ; $05ED  ; a=0
    ldh [$FF9D],a                  ; $05EE  ; level=0
    dec a                          ; $05F0  ; a=FF
    ldh [$FFAA],a                  ; $05F1  ; FFAA=FF
    ld a,$04                       ; $05F3  ; a=4
    rst $08                        ; $05F5  ; mode 4

Sound_Update_IO:
    ldh a,[$FF02]                  ; $05F6  ; check serial transfer
    bit 7,a                        ; $05F8  ; FF02 bit7?
    jr nz,Sound_Update_Input       ; $05FA  ; if busy
    ld a,$80                       ; $05FC  ; a=80
    ldh [$FF8D],a                  ; $05FE  ; FF8D=80
    call Serial_RecvByte           ; $0600  ; call 3C50

Sound_Update_Input:
    call Cur_Debounce              ; $0603  ; read joypad
    jr c,Sound_Update_Dispatch2    ; $0606  ; if no input
    ldh a,[$FFC0]                  ; $0608  ; FFC0 bit3?
    bit 3,a                        ; $060A  ; if not A pressed
    jr z,Sound_Update_MenuSel2     ; $060C
    ldh a,[$FF98]                  ; $060E  ; FF98==2?
    cp $02                         ; $0610
    jr nz,Sound_Update_MenuSel     ; $0612  ; if not
    ldh a,[$FF90]                  ; $0614  ; FF90 high nibble
    and $F0                        ; $0616  ; keep high
    or $0C                         ; $0618  ; set low=0C
    ldh [$FF90],a                  ; $061A  ; store
    ld a,$14                       ; $061C  ; a=14
    ldh [$FFD6],a                  ; $061E  ; FFD6=14
    xor a                          ; $0620  ; a=0
    ldh [$FF8D],a                  ; $0621  ; FF8D=0
    call Serial_Send               ; $0623  ; call 3C3E
    jp Sound_Update_Dispatch2      ; $0626  ; done

Sound_Update_MenuSel:
    ld a,$03                       ; $0629  ; menu selection
    ldh [$FFAA],a                  ; $062B  ; FFAA=3
    xor a                          ; $062D  ; a=0
    ldh [$FF9D],a                  ; $062E  ; level=0
    ldh [$FF9F],a                  ; $0630  ; FF9F=0
    ldh a,[$FF98]                  ; $0632  ; FF98 rst $20 table
    rst $20                        ; $0634  ; table: menu/start modes
    db $03,$04,$08,$00,$CF

Sound_Update_MenuSel2:
    bit 2,a                        ; $063A  ; FFC0 bit2 (B btn)
    jr z,Sound_Update_LevelCheck   ; $063C  ; if not
    ldh a,[$FF98]                  ; $063E  ; FF98++
    inc a                          ; $0640  ; next
    cp $03                         ; $0641  ; >=3?
    jr c,Sound_Update_NextSfx      ; $0643  ; if wrap
    xor a                          ; $0645  ; a=0

Sound_Update_NextSfx:
    ldh [$FF98],a                  ; $0646  ; store
    xor a                          ; $0648  ; a=0
    call SoundEngine_PlayEffect    ; $0649  ; play SFX 0 (menu blip)

Sound_Update_LevelCheck:
    ld a,[$DD00]                   ; $064C  ; check DD00 (level flag)
    cp $FF                         ; $064F  ; ==FF?
    jr nz,Sound_Update_Dispatch2   ; $0651  ; if not
    ldh a,[$FF9D]                  ; $0653  ; level FF9D
    cp $08                         ; $0655  ; >=8?
    ld a,$0D                       ; $0657  ; a=0D
    jr z,Sound_Update_SetLevel     ; $0659  ; if high
    ld a,$08                       ; $065B  ; else a=08

Sound_Update_SetLevel:
    ldh [$FF9D],a                  ; $065D  ; store level
    ld a,$02                       ; $065F  ; a=2
    ldh [$FF90],a                  ; $0661  ; FF90=2
    ld a,$05                       ; $0663  ; a=5
    rst $08                        ; $0665  ; mode 5

Sound_Update_Dispatch2:
    ldh a,[$FF98]                  ; $0666  ; dispatch on FF98
    rst $20                        ; $0668  ; rst $20: mode table
    db $03,$35,$45,$55,$47,$0E,$34,$21
    db $76,$06,$C3,$C5,$3C,$00,$00,$7D
    db $00,$80

Mode_5_Update:
    call Title_StateDispatch       ; $067B  ; mode 1: title update
    call Scroll_WindowUpdate       ; $067E  ; scroll sync
    jp Player_StateDispatch        ; $0681  ; jump to 33DE

Mode_6_Update:
    call Gfx_LcdcUpdate            ; $0684  ; mode 2: name entry update
    call Scroll_Anim               ; $0687  ; call 14A3
    call Player_StateDispatch      ; $068A  ; jump 33DE
    jp Bonus2_AnimDispatch         ; $068D  ; jump 3505

Mode_7_Update:
    ld hl,$988B                    ; $0690  ; mode 3: high score update
    ld de,$FFA3                    ; $0693  ; de=FFA3
    call Text_PrintScore_HLD0      ; $0696  ; print score
    ld hl,$98CB                    ; $0699  ; hl=98CB
    ld de,$FFA6                    ; $069C  ; de=FFA6
    call Text_PrintScore_HLD0      ; $069F  ; print score
    call Gfx_LcdcUpdate            ; $06A2  ; update sprites
    call Scroll_Anim               ; $06A5  ; call 14A3
    call Player_StateDispatch      ; $06A8  ; jump 33DE
    ld a,[$C000]                   ; $06AB  ; C000==8?
    cp $08                         ; $06AE  ; if not
    jr z,Mode_7_Update_Ret         ; $06B0
    ldh a,[$FFC2]                  ; $06B2  ; FFC2 bit3
    bit 3,a                        ; $06B4  ; if not
    jr z,Mode_7_Update_Ret         ; $06B6
    xor a                          ; $06B8  ; a=0
    rst $08                        ; $06B9  ; mode 0

Mode_7_Update_Ret:
    ret                            ; $06BA  ; ret

Mode_8_Update:
    ldh a,[$FFC0]                  ; $06BB  ; mode 4: options update
    bit 3,a                        ; $06BD  ; FFC0 bit3
    jr z,Mode_8_Update_Ret         ; $06BF  ; if not
    xor a                          ; $06C1  ; a=0
    rst $08                        ; $06C2  ; mode 0

Mode_8_Update_Ret:
    ret                            ; $06C3  ; ret

Mode_9_Update:
    ldh a,[$FF90]                  ; $06C4  ; mode 5: level select
    bit 3,a                        ; $06C6  ; FF90 bit3
    ld hl,$9889                    ; $06C8  ; hl=9889
    jr z,Mode_9_Update_Draw        ; $06CB  ; if not
    ld hl,$98EC                    ; $06CD  ; hl=98EC

Mode_9_Update_Draw:
    call Gfx_DrawBanner            ; $06D0  ; draw banner
    ldh a,[$FFD6]                  ; $06D3  ; FFD6
    and a                          ; $06D5  ; zero?
    jr z,Mode_9_Update_Input       ; $06D6  ; if 0
    dec a                          ; $06D8  ; dec
    ldh [$FFD6],a                  ; $06D9  ; store
    jp nz,Mode_9_Update_Done       ; $06DB  ; if still nonzero
    ld a,$05                       ; $06DE  ; a=5
    rst $08                        ; $06E0  ; mode 5

Mode_9_Update_Input:
    call Cur_Debounce              ; $06E1  ; read joypad
    jr c,Mode_9_Update_Arrows      ; $06E4  ; if none
    ldh a,[$FFC0]                  ; $06E6  ; FFC0 bit3
    bit 3,a                        ; $06E8  ; if not A
    jr z,Mode_9_Update_Arrows      ; $06EA
    ldh a,[$FF9E]                  ; $06EC  ; current level
    ld b,a                         ; $06EE  ; save
    ldh a,[$FF9D]                  ; $06EF  ; FF9D
    cp b                           ; $06F1  ; cmp
    jr c,Mode_9_Update_Skip        ; $06F2  ; if <
    jr z,Mode_9_Update_Skip        ; $06F4  ; if ==
    cp $10                         ; $06F6  ; <16?
    jr c,Mode_9_Update_Skip        ; $06F8  ; if not
    ld a,$07                       ; $06FA  ; a=7
    ldh [$FF8B],a                  ; $06FC  ; FF8B=7
    jr Mode_9_Update_Done          ; $06FE  ; done

Mode_9_Update_Skip:
    ld a,$04                       ; $0700  ; a=4
    ldh [$FFD6],a                  ; $0702  ; FFD6=4
    jr Mode_9_Update_Done          ; $0704  ; done

Mode_9_Update_Arrows:
    ldh a,[$FF90]                  ; $0706  ; arrow keys
    and $0C                        ; $0708  ; FF90 &0C
    cp $08                         ; $070A  ; ==08 (up)?
    jr z,Mode_9_Update_Done        ; $070C  ; if so skip
    ld hl,$FF9D                    ; $070E  ; hl=FF9D
    call Btn_AutoB                 ; $0711  ; call 3BE9
    jr z,loc_071D                  ; $0714  ; if not left
    ld a,[hl]                      ; $0716  ; level
    and a                          ; $0717  ; zero?
    jr z,Mode_9_Update_Done        ; $0718  ; if 0
    dec [hl]                       ; $071A  ; dec level
    jr Mode_9_Update_Flash         ; $071B  ; done

loc_071D:
    call Btn_AutoA                 ; $071D  ; call 3BE1 (right)
    jr z,Mode_9_Update_Done        ; $0720  ; if not
    ld a,[hl]                      ; $0722  ; level
    cp $31                         ; $0723  ; >=49?
    jr nc,Mode_9_Update_Done       ; $0725  ; if so
    inc [hl]                       ; $0727  ; inc level

Mode_9_Update_Flash:
    ldh a,[$FF90]                  ; $0728  ; flash level number
    bit 3,a                        ; $072A  ; FF90 bit3
    jr z,Mode_9_Update_Done        ; $072C  ; if not
    ld a,[hl]                      ; $072E  ; level
    set 7,a                        ; $072F  ; set bit7
    call FIFO_Push                 ; $0731  ; call 0A3E (SFX)

Mode_9_Update_Done:
    ldh a,[$FF90]                  ; $0734  ; done
    and $0C                        ; $0736  ; FF90 &0C
    cp $08                         ; $0738  ; ==08?
    jr nz,Mode_9_Update_Ret        ; $073A  ; if not
    ldh a,[$FFC8]                  ; $073C  ; FFC8 bit7
    bit 7,a                        ; $073E  ; if not
    jr z,Mode_9_Update_Ret         ; $0740  ; clear bit7
    res 7,a                        ; $0742  ; clear
    cp $32                         ; $0744  ; >=50?
    jr nc,Mode_9_Update_Ret        ; $0746  ; if so
    ldh [$FF9D],a                  ; $0748  ; set level

Mode_9_Update_Ret:
    ret                            ; $074A  ; ret

Mode_10_Update:
    ldh a,[$FFD6]                  ; $074B  ; mode 6: countdown/bonus
    and a                          ; $074D  ; FFD6
    jr z,Mode_10_Update_Input      ; $074E  ; zero?
    dec a                          ; $0750  ; dec
    ldh [$FFD6],a                  ; $0751  ; store
    ret nz                         ; $0753  ; if nonzero ret
    ldh a,[$FF98]                  ; $0754  ; FF98 bit0
    bit 0,a                        ; $0756  ; test
    jr nz,Mode_10_Update_Bonus     ; $0758  ; if set skip
    ld a,$05                       ; $075A  ; a=5
    rst $08                        ; $075C  ; mode 5

Mode_10_Update_Bonus:
    ld hl,$181D                    ; $075D  ; bonus draw
    call Bg_WriteBlock             ; $0760  ; draw 181D
    ld a,$04                       ; $0763  ; a=4
    ldh [$FF8B],a                  ; $0765  ; FF8B=4
    ret                            ; $0767  ; ret

Mode_10_Update_Input:
    ldh a,[$FF90]                  ; $0768  ; read joypad
    and $0C                        ; $076A  ; FF90 &0C
    cp $08                         ; $076C  ; ==08?
    jp z,Mode_10_Update_Quick      ; $076E  ; if so -> quick
    ld hl,$180D                    ; $0771  ; draw 180D
    call Bg_WriteBlock             ; $0774  ; call 3D05
    ld hl,$99C7                    ; $0777  ; hl=99C7
    call loc_3A3B                  ; $077A  ; call 3A3B
    ld hl,$D237                    ; $077D  ; hl=D237 (cursor)
    ldh a,[$FFC0]                  ; $0780  ; FFC0 bit5
    bit 5,a                        ; $0782  ; test
    jr z,loc_078D                  ; $0784  ; if not
    ld a,[hl]                      ; $0786  ; cursor
    and a                          ; $0787  ; zero?
    jr z,Mode_10_Update_Cursor     ; $0788  ; if 0
    dec [hl]                       ; $078A  ; dec
    jr Mode_10_Update_Cursor       ; $078B  ; done

loc_078D:
    bit 4,a                        ; $078D  ; FFC0 bit4
    jr z,Mode_10_Update_Cursor     ; $078F  ; if not
    ld a,[hl]                      ; $0791  ; cursor
    cp $05                         ; $0792  ; >=5?
    jr nc,Mode_10_Update_Cursor    ; $0794  ; if so
    inc [hl]                       ; $0796  ; inc

Mode_10_Update_Cursor:
    ld hl,$D231                    ; $0797  ; hl=D231+sel
    ld a,[$D237]                   ; $079A  ; selection
    ld c,a                         ; $079D  ; c=a
    ld b,$00                       ; $079E  ; b=0
    add hl,bc                      ; $07A0  ; hl+=sel
    cp $02                         ; $07A1  ; >=2?
    ld d,$19                       ; $07A3  ; d=19 (limiter)
    jr c,loc_07A9                  ; $07A5  ; if not
    ld d,$09                       ; $07A7  ; d=09

loc_07A9:
    call Btn_AutoA                 ; $07A9  ; call 3BE1 (right?)
    jr z,loc_07B9                  ; $07AC  ; if not
    ld a,[hl]                      ; $07AE  ; val
    cp d                           ; $07AF  ; >=d?
    jr c,loc_07B6                  ; $07B0  ; if so
    xor a                          ; $07B2  ; a=0
    ld [hl],a                      ; $07B3  ; reset
    jr loc_07C7                    ; $07B4  ; done

loc_07B6:
    inc [hl]                       ; $07B6  ; inc
    jr loc_07C7                    ; $07B7  ; done

loc_07B9:
    call Btn_AutoB                 ; $07B9  ; call 3BE9 (left?)
    jr z,loc_07C7                  ; $07BC  ; if not
    ld a,[hl]                      ; $07BE  ; val
    and a                          ; $07BF  ; zero?
    jr nz,loc_07C6                 ; $07C0  ; if not
    ld a,d                         ; $07C2  ; a=d
    ld [hl],a                      ; $07C3  ; set max
    jr loc_07C7                    ; $07C4  ; done

loc_07C6:
    dec [hl]                       ; $07C6  ; dec

loc_07C7:
    ldh a,[$FFD4]                  ; $07C7  ; FFD4 bit4?
    and $10                        ; $07C9  ; test
    jr nz,Mode_10_Update_Sfx       ; $07CB  ; if set
    ld a,[$D237]                   ; $07CD  ; selection rst $20
    rst $20                        ; $07D0  ; D237 index: cursor table
    db $06,$38,$40,$50,$58,$60,$68,$4F
    db $06,$70,$21,$0C,$08,$CD,$C5,$3C

Mode_10_Update_Sfx:
    ldh a,[$FFC0]                  ; $07E1  ; FFC0 bit2 (B)
    bit 2,a                        ; $07E3  ; test
    ld b,$81                       ; $07E5  ; b=81 (sfx id)
    jr nz,loc_07F4                 ; $07E7  ; if set
    bit 3,a                        ; $07E9  ; FFC0 bit3 (A)
    jr z,Mode_10_Update_Ret        ; $07EB  ; if not
    call Code_Solve                ; $07ED  ; call 3AE5
    jr nc,Mode_10_Update_Ret       ; $07F0  ; if no carry
    ld b,$80                       ; $07F2  ; b=80

loc_07F4:
    ldh a,[$FF90]                  ; $07F4  ; FF90 bit3
    bit 3,a                        ; $07F6  ; test
    ld a,b                         ; $07F8  ; a=b
    call nz,FIFO_Push              ; $07F9  ; call 0A3E
    ld a,b                         ; $07FC  ; a=b
    jr Mode_10_Update_Set          ; $07FD  ; jump set

Mode_10_Update_Quick:
    ldh a,[$FFC8]                  ; $07FF  ; quick: FF8C?
    bit 7,a                        ; $0801  ; FFC8 bit7
    jr z,Mode_10_Update_Ret        ; $0803  ; if not

Mode_10_Update_Set:
    ldh [$FF98],a                  ; $0805  ; FF98=b
    ld a,$08                       ; $0807  ; a=8
    ldh [$FFD6],a                  ; $0809  ; FFD6=8

Mode_10_Update_Ret:
    ret                            ; $080B  ; ret
    nop                            ; $080C
    nop                            ; $080D
    db $FD                         ; $080E
    nop                            ; $080F
    add b                          ; $0810

Mode_Game:
    call Gfx_LcdcUpdate            ; $0811  ; game mode: update
    call Scroll_WindowUpdate       ; $0814  ; scroll sync
    call Level_VramWrite           ; $0817  ; call 10D6
    ldh a,[$FF90]                  ; $081A  ; FF90 bit3
    bit 3,a                        ; $081C  ; test
    jr z,Mode_Game_Plain           ; $081E  ; if not in game
    ld hl,$0870                    ; $0820  ; ret addr 0870
    push hl                        ; $0823  ; push
    ldh a,[$FFD4]                  ; $0824  ; FFD4 &3
    and $03                        ; $0826  ; value
    ld hl,$9C21                    ; $0828  ; hl=9C21
    ld de,$FFA3                    ; $082B  ; de=FFA3
    jp z,Text_PrintScore_HL50      ; $082E  ; if 0 print score
    cp $01                         ; $0831  ; ==1?
    ld hl,$9C2D                    ; $0833  ; hl=9C2D
    ld de,$FFA6                    ; $0836  ; de=FFA6
    jp z,Text_PrintScore_HL50      ; $0839  ; if 1 print score
    cp $02                         ; $083C  ; ==2?
    ld hl,$9C29                    ; $083E  ; hl=9C29
    jp z,Text_PrintScore_100       ; $0841  ; if 2 print score
    ldh a,[$FFD4]                  ; $0844  ; FFD4 bit4
    and $10                        ; $0846  ; test
    ld hl,$19F6                    ; $0848  ; hl=19F6
    jr z,Mode_Game_HudBg           ; $084B  ; if not
    ld hl,$1A02                    ; $084D  ; hl=1A02

Mode_Game_HudBg:
    ldh a,[$FF90]                  ; $0850  ; FF90 &0C
    and $0C                        ; $0852  ; value
    cp $0C                         ; $0854  ; ==0C?
    jr z,Mode_Game_HudBg2          ; $0856  ; if so
    ld bc,$0016                    ; $0858  ; bc=16
    add hl,bc                      ; $085B  ; hl+=16

Mode_Game_HudBg2:
    jp Bg_WriteBlock               ; $085C  ; draw hud bg

Mode_Game_Plain:
    ldh a,[$FF91]                  ; $085F  ; plain: FF91
    and a                          ; $0861  ; zero?
    jr z,Mode_Game_Update          ; $0862  ; if 0 skip
    ld hl,$9C21                    ; $0864  ; hl=9C21
    call Text_PrintScore_50        ; $0867  ; print score
    ld hl,$9C2B                    ; $086A  ; hl=9C2B
    call Text_PutAttr_50           ; $086D  ; put char

Mode_Game_Update:
    call Level_QueuePop            ; $0870  ; update runner/objects
    call Scroll_Anim               ; $0873  ; call 14A3
    ldh a,[$FF91]                  ; $0876  ; FF91
    and a                          ; $0878  ; zero?
    jr nz,Mode_Game_Update2        ; $0879  ; if set skip
    call Slot_Scan                 ; $087B  ; call 2E75
    call Guard_Update              ; $087E  ; call 2211
    call Player_Update             ; $0881  ; call 1BCB
    call BonusSlot_Dispatch        ; $0884  ; call 2C7F
    call BonusSlot2_Dispatch       ; $0887  ; call 2DED

Mode_Game_Update2:
    call Game_KeyHandler           ; $088A  ; update physics
    call Game_EnemyTimer           ; $088D  ; call 150C
    call Slot_Draw                 ; $0890  ; call 2F2E
    ldh a,[$FF96]                  ; $0893  ; FF96
    and a                          ; $0895  ; zero?
    jr nz,Mode_Game_Update3        ; $0896  ; if not skip
    call Player_Animate            ; $0898  ; call 1D11
    call Guard_DrawAll             ; $089B  ; call 2418

Mode_Game_Update3:
    call BonusSlot_Anim            ; $089E  ; call 2D6E
    jp BonusSlot2_Anim             ; $08A1  ; jump 2E4C

Mode_Pause_Update:
    call Cur_Debounce              ; $08A4  ; pause update
    jr c,Mode_Pause_Update2        ; $08A7  ; if input
    ldh a,[$FFC2]                  ; $08A9  ; FFC2 bit2
    bit 2,a                        ; $08AB  ; test
    jr z,loc_08B3                  ; $08AD  ; if not
    ld a,$FF                       ; $08AF  ; a=FF
    jr Mode_Pause_Set              ; $08B1  ; jump set

loc_08B3:
    bit 3,a                        ; $08B3  ; FFC2 bit3
    jr z,Mode_Pause_Update2        ; $08B5  ; if not
    xor a                          ; $08B7  ; a=0

Mode_Pause_Set:
    ldh [$FF95],a                  ; $08B8  ; FF95=a
    ld a,$07                       ; $08BA  ; a=7
    rst $08                        ; $08BC  ; mode 7

Mode_Pause_Update2:
    call Game_EnemyTimer           ; $08BD  ; continue game update
    call Slot_Draw                 ; $08C0  ; call 2F2E
    call Player_Animate            ; $08C3  ; call 1D11
    call Guard_DrawAll             ; $08C6  ; call 2418
    call BonusSlot_Anim            ; $08C9  ; call 2D6E
    jp BonusSlot2_Anim             ; $08CC  ; jump 2E4C

Mode_Credits_Update:
    ld hl,$98CC                    ; $08CF  ; credits: draw 98CC
    ldh a,[$FF9F]                  ; $08D2  ; FF9F srl
    srl a                          ; $08D4  ; shift
    push af                        ; $08D6  ; save carry
    inc a                          ; $08D7  ; inc
    or $D0                         ; $08D8  ; or D0
    ld [hl+],a                     ; $08DA  ; write tile
    ld a,$F5                       ; $08DB  ; a=F5
    ld [hl+],a                     ; $08DD  ; write tile
    pop af                         ; $08DE  ; restore
    ld a,$DA                       ; $08DF  ; a=DA
    jr nc,loc_08E5                 ; $08E1  ; if carry
    ld a,$DB                       ; $08E3  ; a=DB

loc_08E5:
    ld [hl+],a                     ; $08E5  ; write tile
    ldh a,[$FFC0]                  ; $08E6  ; FFC0 bit3
    bit 3,a                        ; $08E8  ; test
    jr z,Mode_Credits_Speed        ; $08EA  ; if not
    ldh a,[$FF98]                  ; $08EC  ; FF98+9
    add $09                        ; $08EE  ; add
    rst $08                        ; $08F0  ; mode

Mode_Credits_Speed:
    ld hl,$FF9F                    ; $08F1  ; FF9F
    bit 1,a                        ; $08F4  ; FFC0 bit1
    jr z,loc_08FF                  ; $08F6  ; if not
    ld a,[hl]                      ; $08F8  ; FF9F
    and a                          ; $08F9  ; zero?
    jr z,Mode_Credits_Sfx          ; $08FA  ; if 0
    dec [hl]                       ; $08FC  ; dec
    jr Mode_Credits_Sfx            ; $08FD  ; done

loc_08FF:
    bit 0,a                        ; $08FF  ; FFC0 bit0
    jr z,Mode_Credits_Sfx          ; $0901  ; if not
    ld a,[hl]                      ; $0903  ; FF9F
    cp $07                         ; $0904  ; >=7?
    jr nc,Mode_Credits_Sfx         ; $0906  ; if so
    inc [hl]                       ; $0908  ; inc

Mode_Credits_Sfx:
    ldh a,[$FFC0]                  ; $0909  ; FFC0 bit2
    bit 2,a                        ; $090B  ; test
    jr z,Mode_Credits_Dispatch     ; $090D  ; if not
    ldh a,[$FF98]                  ; $090F  ; FF98++
    inc a                          ; $0911  ; next
    cp $02                         ; $0912  ; >=2?
    jr c,loc_0917                  ; $0914  ; if wrap
    xor a                          ; $0916  ; a=0

loc_0917:
    ldh [$FF98],a                  ; $0917  ; store
    xor a                          ; $0919  ; a=0
    call SoundEngine_PlayEffect    ; $091A  ; play sfx 0

Mode_Credits_Dispatch:
    ldh a,[$FF98]                  ; $091D  ; FF98 rst $20
    rst $20                        ; $091F  ; credits mode table
    db $03,$30,$50,$70,$47,$0E,$2C,$21
    db $76,$06,$C3,$C5,$3C

Serial_Branch:
    call Gfx_DeferredWrite         ; $092D  ; serial branch
    call Game_CheckButtons         ; $0930  ; call 15C2
    jp Obj_Next                    ; $0933  ; jump 15D8

Serial_Branch2:
    jp Game_CheckButtons           ; $0936  ; jump 15C2

Serial_Handler:
    ldh a,[$FF8D]                  ; $0939  ; serial/2p handler
    bit 7,a                        ; $093B  ; FF8D bit7
    jr nz,loc_094A                 ; $093D  ; if set
    rst $10                        ; $093F  ; rst $10 state table
    dw $0964,$0969,$0990,$099E
    dw $09D0

loc_094A:
    rst $10                        ; $094A  ; second state table
    dw $0955,$0975,$0990,$09C2
    dw $09A5

Serial_Check:
    ldh a,[$FF01]                  ; $0955  ; check serial id
    ld b,a                         ; $0957  ; b=FF01
    ldh a,[$FF8A]                  ; $0958  ; FF8A or b
    or b                           ; $095A  ; if busy
    ret nz                         ; $095B
    ld a,$02                       ; $095C  ; a=2
    ldh [$FF98],a                  ; $095E  ; FF98=2
    ld a,$14                       ; $0960  ; a=14
    ldh [$FFD6],a                  ; $0962  ; FFD6=14

Serial_Tick:
    ld hl,$FF8D                    ; $0964  ; FF8D++
    inc [hl]                       ; $0967  ; next state
    ret                            ; $0968  ; ret

Serial_Recv:
    ldh a,[$FF01]                  ; $0969  ; recv: FF01
    cp $12                         ; $096B  ; ==12?
    jr z,Serial_NextState          ; $096D  ; if yes

Serial_Clear:
    xor a                          ; $096F  ; clear
    ldh [$FFD6],a                  ; $0970  ; FFD6=0
    ldh [$FF90],a                  ; $0972  ; FF90=0
    ret                            ; $0974  ; ret

Serial_RecvBtn:
    ldh a,[$FF01]                  ; $0975  ; recv btn
    bit 2,a                        ; $0977  ; FF01 bit2
    jr nz,Serial_RecvStart         ; $0979  ; if not
    xor a                          ; $097B  ; a=0
    ldh [$FF98],a                  ; $097C  ; FF98=0
    jr Serial_Clear                ; $097E  ; clear

Serial_RecvStart:
    ldh a,[$FF90]                  ; $0980  ; FF90 high
    and $F0                        ; $0982  ; mask
    or $08                         ; $0984  ; set 08
    ldh [$FF90],a                  ; $0986  ; store

Serial_NextState:
    ld hl,$FF8D                    ; $0988  ; FF8D+=2
    inc [hl]                       ; $098B  ; next
    inc [hl]                       ; $098C  ; next
    jp Serial_RecvByte             ; $098D  ; jump 3C50

Serial_Dummy:
    xor a                          ; $0990  ; dummy reads
    ld a,[$D02D]                   ; $0991  ; read D02D
    ld a,[$D02E]                   ; $0994  ; read D02E
    ld a,[$D12F]                   ; $0997  ; read D12F
    ld a,[$D130]                   ; $099A  ; read D130
    ret                            ; $099D  ; ret

Serial_Enable:
    ld a,$84                       ; $099E  ; a=84
    ldh [$FF8D],a                  ; $09A0  ; FF8D=84
    jp Serial_RecvByte             ; $09A2  ; jump 3C50

Serial_PlayMode:
    ld a,$03                       ; $09A5  ; a=3
    ldh [$FF8D],a                  ; $09A7  ; FF8D=3

Serial_StoreRecv:
    ld hl,$D131                    ; $09A9  ; store received byte to serial buffer D131
    ld a,[$D12F]                   ; $09AC  ; D12F index
    add l                          ; $09AF  ; hl += index
    ld l,a                         ; $09B0  ; low
    ld a,$00                       ; $09B1  ; a=0
    adc h                          ; $09B3  ; carry into h
    ld h,a                         ; $09B4  ; high
    ldh a,[$FF01]                  ; $09B5  ; FF01 (recv data)
    and a                          ; $09B7  ; zero?
    ret z                          ; $09B8  ; if empty ret
    ld [hl],a                      ; $09B9  ; store byte
    ld a,[$D12F]                   ; $09BA  ; D12F
    inc a                          ; $09BD  ; inc index
    ld [$D12F],a                   ; $09BE  ; store
    ret                            ; $09C1  ; ret

Serial_RecvState:
    ld a,$04                       ; $09C2  ; recv state 4
    ldh [$FF8D],a                  ; $09C4  ; FF8D=4
    call Serial_StoreRecv          ; $09C6  ; store recv byte
    call FIFO_Pop                  ; $09C9  ; pop from FIFO
    ld a,b                         ; $09CC  ; b
    jp Serial_Send                 ; $09CD  ; jump 3C3E

Serial_Stop:
    ld a,$83                       ; $09D0  ; stop serial
    ldh [$FF8D],a                  ; $09D2  ; FF8D=83
    jp Serial_RecvByte             ; $09D4  ; jump 3C50

Serial_Poll:
    ldh a,[$FF8D]                  ; $09D7  ; serial poll each vblank
    cp $03                         ; $09D9  ; FF8D==3?
    jr z,Serial_Poll_Chk           ; $09DB  ; if yes
    cp $84                         ; $09DD  ; ==84?
    ret nz                         ; $09DF  ; else ret
    ld a,$03                       ; $09E0  ; a=3
    ldh [$FF8D],a                  ; $09E2  ; FF8D=3
    ldh [$FF8E],a                  ; $09E4  ; FF8E=3
    ldh a,[$FFC9]                  ; $09E6  ; FFC9
    ld b,a                         ; $09E8  ; b=a
    jr Serial_Poll_Merge           ; $09E9  ; jump merge

Serial_Poll_Chk:
    xor a                          ; $09EB  ; FF8E=0
    ldh [$FF8E],a                  ; $09EC  ; clear
    call FIFO_Pop                  ; $09EE  ; pop FIFO
    ld a,b                         ; $09F1  ; b
    bit 7,a                        ; $09F2  ; bit7 set?
    jp nz,Serial_Send              ; $09F4  ; jump 3C3E

Serial_Poll_Merge:
    ldh a,[$FFD4]                  ; $09F7  ; merge controls
    and $01                        ; $09F9  ; FFD4 &1
    or b                           ; $09FB  ; or b
    ld b,a                         ; $09FC  ; b
    ldh a,[$FFC1]                  ; $09FD  ; FFC1 &0C
    and $0C                        ; $09FF  ; mask
    or b                           ; $0A01  ; or b
    ldh [$FFC9],a                  ; $0A02  ; FFC9
    jp Serial_Send                 ; $0A04  ; jump 3C3E

Serial_Send_Start:
    ldh a,[$FF90]                  ; $0A07  ; start serial send
    bit 3,a                        ; $0A09  ; FF90 bit3
    ret z                          ; $0A0B  ; if not in game ret
    bit 2,a                        ; $0A0C  ; FF90 bit2
    ld a,$02                       ; $0A0E  ; a=2
    jr nz,Serial_Send_Sync         ; $0A10  ; if set
    ld a,$82                       ; $0A12  ; a=82

Serial_Send_Sync:
    ldh [$FF8D],a                  ; $0A14  ; FF8D=a
    ei                             ; $0A16  ; enable interrupts

Serial_Send_Wait:
    ld a,$F0                       ; $0A17  ; send F0 or F1
    call Serial_RecvByte           ; $0A19  ; 3C50 set 8D/F0
    ld a,$F1                       ; $0A1C  ; a=F1
    call Serial_Send               ; $0A1E  ; 3C3E

Serial_Send_Poll:
    ldh a,[$FF02]                  ; $0A21  ; wait transfer done
    bit 7,a                        ; $0A23  ; FF02 bit7
    jr nz,Serial_Send_Poll         ; $0A25  ; loop
    ldh a,[$FF8D]                  ; $0A27  ; FF8D bit7
    bit 7,a                        ; $0A29  ; test
    ld b,$F0                       ; $0A2B  ; b=F0
    jr z,Serial_Send_Verify        ; $0A2D  ; if clear
    ld b,$F1                       ; $0A2F  ; b=F1

Serial_Send_Verify:
    ldh a,[$FF01]                  ; $0A31  ; verify FF01
    cp b                           ; $0A33  ; cmp
    jr nz,Serial_Send_Wait         ; $0A34  ; retry if wrong
    di                             ; $0A36  ; disable interrupts
    ld hl,$FF8D                    ; $0A37  ; hl=FF8D
    inc [hl]                       ; $0A3A  ; inc state
    jp Serial_RecvByte             ; $0A3B  ; jump 3C50

FIFO_Push:
    push hl                        ; $0A3E  ; push value to SFX FIFO D02F
    push af                        ; $0A3F  ; save
    ld hl,$D02F                    ; $0A40  ; hl=D02F base
    ld a,[$D02D]                   ; $0A43  ; D02D head
    add l                          ; $0A46  ; hl+=head
    ld l,a                         ; $0A47  ; low
    ld a,$00                       ; $0A48  ; a=0
    adc h                          ; $0A4A  ; carry
    ld h,a                         ; $0A4B  ; high
    pop af                         ; $0A4C  ; restore a
    ld [hl],a                      ; $0A4D  ; store value
    ld a,[$D02D]                   ; $0A4E  ; D02D
    inc a                          ; $0A51  ; inc head
    ld [$D02D],a                   ; $0A52  ; store
    pop hl                         ; $0A55  ; restore hl
    ret                            ; $0A56  ; ret

FIFO_Pop:
    ld a,[$D02E]                   ; $0A57  ; pop from SFX FIFO
    ld c,a                         ; $0A5A  ; c=tail
    ld a,[$D02D]                   ; $0A5B  ; head
    cp c                           ; $0A5E  ; cmp
    ld b,$00                       ; $0A5F  ; b=0
    ret z                          ; $0A61  ; if empty ret z
    ld hl,$D02F                    ; $0A62  ; hl=D02F
    add hl,bc                      ; $0A65  ; hl+=tail
    ld a,[hl]                      ; $0A66  ; value
    ld b,a                         ; $0A67  ; b=a
    ld a,c                         ; $0A68  ; tail
    inc a                          ; $0A69  ; inc
    ld [$D02E],a                   ; $0A6A  ; store
    bit 7,b                        ; $0A6D  ; bit7?
    ret nz                         ; $0A6F  ; if set ret nz
    set 1,b                        ; $0A70  ; set bit1
    ret                            ; $0A72  ; ret

Action_Dispatcher:
    ldh a,[$FF90]                  ; $0A73  ; dispatch player action from FFC8
    bit 3,a                        ; $0A75  ; FF90 bit3
    ret z                          ; $0A77  ; if not in game ret
    ldh a,[$FFC8]                  ; $0A78  ; FFC8
    cp $E0                         ; $0A7A  ; ==E0?
    jr z,Action_Switch             ; $0A7C  ; if yes
    bit 7,a                        ; $0A7E  ; bit7?
    ret nz                         ; $0A80  ; if set ret
    push af                        ; $0A81  ; save
    ldh a,[$FFC8]                  ; $0A82  ; FFC8 &0C
    and $0C                        ; $0A84  ; mask
    ldh [$FFC8],a                  ; $0A86  ; store
    pop af                         ; $0A88  ; restore

Action_Switch:
    and $70                        ; $0A89  ; FFC8 &70
    swap a                         ; $0A8B  ; swap (action*8)
    rst $10                        ; $0A8D  ; rst $10 table
    dw $0A9E,$0A9F,$0AA4,$0ABB
    dw $0ACA,$0B3C,$0AF5,$0B30

Action_Null:
    ret                            ; $0A9E  ; action 0: nothing

Action_Speed:
    ld bc,$0150                    ; $0A9F  ; action 1: speed (bc=0150)
    jr Action_Speed_Apply          ; $0AA2  ; jump apply

Action_SfxAnd:
    ld a,$2C                       ; $0AA4  ; action 2: play 2C + bc=0300
    call SoundEngine_PlayEffect    ; $0AA6  ; SFX 2C
    ld bc,$0300                    ; $0AA9  ; bc=0300

Action_Speed_Apply:
    ldh a,[$FF90]                  ; $0AAC  ; apply speed to FFA1/FFA4
    bit 2,a                        ; $0AAE  ; FF90 bit2
    ld hl,$FFA1                    ; $0AB0  ; hl=FFA1
    jr z,loc_0AB8                  ; $0AB3  ; if not
    ld hl,$FFA4                    ; $0AB5  ; hl=FFA4

loc_0AB8:
    jp Score_AddBCD_Shift          ; $0AB8  ; jump 3371 (store speed)

Action_Dig:
    ld a,$1C                       ; $0ABB  ; action 3: dig hole
    call SoundEngine_PlayEffect    ; $0ABD  ; SFX 1C
    ld a,$96                       ; $0AC0  ; a=96
    ld [$C00E],a                   ; $0AC2  ; C00E=96
    ld a,$A0                       ; $0AC5  ; a=A0
    jp Player_HoleSet              ; $0AC7  ; jump 1C86

Action_Rope:
    ld a,$1C                       ; $0ACA  ; action 4: use rope
    call SoundEngine_PlayEffect    ; $0ACC  ; SFX 1C
    ld hl,$FF90                    ; $0ACF  ; hl=FF90
    set 5,[hl]                     ; $0AD2  ; set bit5
    ld de,$C010                    ; $0AD4  ; de=C010
    call Action_Rope_Clr           ; $0AD7  ; clear rope obj A
    ld de,$C020                    ; $0ADA  ; de=C020
    call Action_Rope_Clr           ; $0ADD  ; clear obj B
    ld de,$C030                    ; $0AE0  ; de=C030

Action_Rope_Clr:
    xor a                          ; $0AE3  ; reset obj state
    ld hl,$000F                    ; $0AE4  ; hl=de+0F
    add hl,de                      ; $0AE7  ; addr
    ld [hl],a                      ; $0AE8  ; clear
    ld hl,$0000                    ; $0AE9  ; hl=de
    add hl,de                      ; $0AEC  ; state
    ld a,[hl]                      ; $0AED  ; ==3?
    cp $03                         ; $0AEE  ; if not
    ret nz                         ; $0AF0
    ld a,$02                       ; $0AF1  ; a=2
    ld [hl],a                      ; $0AF3  ; set state 2
    ret                            ; $0AF4  ; ret

Action_Alt:
    ld hl,$FF90                    ; $0AF5  ; action 5: alt dig
    ldh a,[$FFC8]                  ; $0AF8  ; FFC8
    bit 7,a                        ; $0AFA  ; bit7?
    jr nz,Action_Alt2              ; $0AFC  ; if set
    bit 6,[hl]                     ; $0AFE  ; FF90 bit6
    jr nz,Action_Alt_Set           ; $0B00  ; if set
    set 6,[hl]                     ; $0B02  ; set bit6
    ld bc,$3000                    ; $0B04  ; bc=3000
    call Action_Speed_Apply        ; $0B07  ; apply speed
    ld a,$60                       ; $0B0A  ; a=60
    call FIFO_Push                 ; $0B0C  ; push sfx

Action_Alt_Set:
    ld a,$08                       ; $0B0F  ; a=8
    ldh [$FFAD],a                  ; $0B11  ; FFAD=8
    ret                            ; $0B13  ; ret

Action_Alt2:
    ldh a,[$FFC8]                  ; $0B14  ; alt2
    and $0C                        ; $0B16  ; FFC8 &0C
    ldh [$FFC8],a                  ; $0B18  ; store
    bit 7,[hl]                     ; $0B1A  ; FF90 bit7
    jr nz,Action_Alt2_Set          ; $0B1C  ; if set
    set 7,[hl]                     ; $0B1E  ; set bit7
    ld bc,$3000                    ; $0B20  ; bc=3000
    call Action_Speed_Apply        ; $0B23  ; apply
    ld a,$E0                       ; $0B26  ; a=E0
    call FIFO_Push                 ; $0B28  ; push sfx

Action_Alt2_Set:
    ld a,$08                       ; $0B2B  ; a=8
    ldh [$FFAD],a                  ; $0B2D  ; FFAD=8
    ret                            ; $0B2F  ; ret

Action_Pal:
    ldh a,[$FF90]                  ; $0B30  ; action 7: palette
    bit 2,a                        ; $0B32  ; FF90 bit2
    ld a,$00                       ; $0B34  ; a=0
    jp z,Score_SetA1               ; $0B36  ; jump 3397
    jp Score_SetA4                 ; $0B39  ; jump 339E

Action_Kill:
    ld de,$C010                    ; $0B3C  ; action 6: kill guards
    call Action_Kill_Clr           ; $0B3F  ; clear obj C010
    ld de,$C020                    ; $0B42  ; de=C020
    call Action_Kill_Clr           ; $0B45  ; clear
    ld de,$C030                    ; $0B48  ; de=C030
    call Action_Kill_Clr           ; $0B4B  ; clear

Action_Kill_Snd:
    ld a,$50                       ; $0B4E  ; a=50
    jp FIFO_Push                   ; $0B50  ; push sfx

Action_Kill_Clr:
    ld a,[de]                      ; $0B53  ; clear obj if empty
    and a                          ; $0B54  ; state
    ret nz                         ; $0B55  ; if used ret
    pop af                         ; $0B56  ; pop ret addr
    jp Guard_Fall_Reborn           ; $0B57  ; jump 2643 (init enemy)

Timer_Tick:
    ld hl,$FF90                    ; $0B5A  ; timer IRQ: countdown FFAB/FFAC
    bit 4,[hl]                     ; $0B5D  ; FF90 bit4
    ret z                          ; $0B5F  ; if not ret
    ld hl,$FFAC                    ; $0B60  ; hl=FFAC
    ld a,[hl-]                     ; $0B63  ; a=[hl-]
    and a                          ; $0B64  ; zero?
    ret z                          ; $0B65  ; ret
    ld a,[hl]                      ; $0B66  ; a=FFAB
    dec a                          ; $0B67  ; dec
    bit 7,a                        ; $0B68  ; bit7
    jr z,Timer_Tick_St             ; $0B6A  ; if not
    inc hl                         ; $0B6C  ; hl=FFAC
    dec [hl]                       ; $0B6D  ; dec
    dec hl                         ; $0B6E  ; hl=FFAB
    ld a,$3B                       ; $0B6F  ; a=3B (reset)

Timer_Tick_St:
    ld [hl],a                      ; $0B71  ; store
    ret                            ; $0B72  ; ret

STAT_Handler:
    ldh a,[$FF8F]                  ; $0B73  ; STAT IRQ: dispatch on FF8F
    rst $10                        ; $0B75  ; rst $10 table 6
    dw $0B9A,$0B82,$0B9B,$0BB9
    dw $0BC3,$0BFA

STAT_Split:
    ldh a,[$FF96]                  ; $0B82  ; state 1: split scroll
    and a                          ; $0B84  ; FF96
    ret z                          ; $0B85  ; zero ret
    call Wait_LcdHBlank            ; $0B86  ; wait hblank
    res 5,a                        ; $0B89  ; clear bit5
    or $03                         ; $0B8B  ; set 03
    ldh [$FF40],a                  ; $0B8D  ; LCDC
    ldh a,[$FF96]                  ; $0B8F  ; FF96
    cpl                            ; $0B91  ; cpl
    add $8F                        ; $0B92  ; add 8F
    ldh [$FF45],a                  ; $0B94  ; LYC
    ld a,$02                       ; $0B96  ; a=2
    ldh [$FF8F],a                  ; $0B98  ; FF8F=2

STAT_Ret:
    ret                            ; $0B9A  ; ret

STAT_Window:
    call Wait_LcdHBlank            ; $0B9B  ; state 2: window
    set 5,a                        ; $0B9E  ; set bit5
    and $FC                        ; $0BA0  ; clear 03
    ldh [$FF40],a                  ; $0BA2  ; LCDC
    ld a,$07                       ; $0BA4  ; a=7
    call WX_ComputeFromSCX         ; $0BA6  ; WX compute
    ldh [$FF4B],a                  ; $0BA9  ; WX
    ldh a,[$FF96]                  ; $0BAB  ; FF96
    ldh [$FF45],a                  ; $0BAD  ; LYC
    cpl                            ; $0BAF  ; cpl
    add $8F                        ; $0BB0  ; add 8F
    ldh [$FF4A],a                  ; $0BB2  ; WY
    ld a,$01                       ; $0BB4  ; a=1
    ldh [$FF8F],a                  ; $0BB6  ; FF8F=1
    ret                            ; $0BB8  ; ret

STAT_Ext:
    call Wait_LcdHBlank            ; $0BB9  ; state 3: ext
    set 4,a                        ; $0BBC  ; set bit4
    res 1,a                        ; $0BBE  ; clear bit1
    ldh [$FF40],a                  ; $0BC0  ; LCDC
    ret                            ; $0BC2  ; ret

STAT_Scroll:
    call Wait_LcdHBlank            ; $0BC3  ; state 5: scroll control
    res 3,a                        ; $0BC6  ; clear bit3
    ldh [$FF40],a                  ; $0BC8  ; LCDC
    xor a                          ; $0BCA  ; a=0
    ldh [$FF43],a                  ; $0BCB  ; SCX=0
    ldh a,[$FFD4]                  ; $0BCD  ; FFD4 &3
    and $03                        ; $0BCF  ; mask
    ldh a,[$FFD1]                  ; $0BD1  ; FFD1
    jr nz,STAT_Scroll_Set          ; $0BD3  ; if nonzero
    and a                          ; $0BD5  ; zero?
    jr z,STAT_Scroll_Set           ; $0BD6  ; if zero
    inc a                          ; $0BD8  ; inc
    ldh [$FFD1],a                  ; $0BD9  ; FFD1++

STAT_Scroll_Set:
    ldh [$FF42],a                  ; $0BDB  ; SCY=FFD1
    ld a,[$C000]                   ; $0BDD  ; C000
    cp $04                         ; $0BE0  ; ==4?
    jr nz,STAT_Scroll_Mode         ; $0BE2  ; if not
    ldh a,[$FFD4]                  ; $0BE4  ; FFD4 &7
    and $07                        ; $0BE6  ; mask
    ldh [$FF42],a                  ; $0BE8  ; SCY

STAT_Scroll_Mode:
    ldh a,[$FFD1]                  ; $0BEA  ; FFD1
    and a                          ; $0BEC  ; zero?
    ld a,$70                       ; $0BED  ; a=70
    jr z,STAT_Scroll_Flag          ; $0BEF  ; if zero
    ld a,$77                       ; $0BF1  ; a=77

STAT_Scroll_Flag:
    ldh [$FF45],a                  ; $0BF3  ; LYC
    ld a,$05                       ; $0BF5  ; a=5
    ldh [$FF8F],a                  ; $0BF7  ; FF8F=5
    ret                            ; $0BF9  ; ret

STAT_Plain:
    call Wait_LcdHBlank            ; $0BFA  ; state 4: plain
    xor a                          ; $0BFD  ; a=0
    ldh [$FF43],a                  ; $0BFE  ; SCX=0
    ldh [$FF42],a                  ; $0C00  ; SCY=0
    ld a,[$C000]                   ; $0C02  ; C000
    cp $04                         ; $0C05  ; ==4?
    ld a,$0A                       ; $0C07  ; a=0A
    jr z,STAT_Plain_Set            ; $0C09  ; if yes

STAT_Plain_Lyc:
    ld a,$0D                       ; $0C0B  ; a=0D

STAT_Plain_Set:
    ldh [$FF45],a                  ; $0C0D  ; LYC
    ld a,$04                       ; $0C0F  ; a=4
    ldh [$FF8F],a                  ; $0C11  ; FF8F=4
    ret                            ; $0C13  ; ret

Wait_LcdHBlank:
    ldh a,[$FF41]                  ; $0C14  ; wait until LCD mode 0 (hblank)
    and $03                        ; $0C16  ; STAT &3
    jr nz,Wait_LcdHBlank           ; $0C18  ; busy loop
    ldh a,[$FFCA]                  ; $0C1A  ; return FFCA (LCDC shadow)
    ret                            ; $0C1C  ; ret

Gfx_InitBank0:
    ld hl,$8800                    ; $0C1D  ; clear tile RAM for bank0 mode
    ld bc,$0800                    ; $0C20  ; bc=800
    call Mem_ZeroFill              ; $0C23  ; zero fill 8800
    ld hl,$9500                    ; $0C26  ; hl=9500
    ld bc,$0300                    ; $0C29  ; bc=300
    call Mem_ZeroFill              ; $0C2C  ; zero fill
    jr Gfx_InitBank0_2             ; $0C2F  ; jump init tiles

Gfx_InitBank0_Full:
    ld hl,$8800                    ; $0C31  ; clear 1000 bytes at 8800
    ld bc,$1000                    ; $0C34  ; bc=1000
    call Mem_ZeroFill              ; $0C37  ; zero fill

Gfx_InitBank0_2:
    ld hl,$677A                    ; $0C3A  ; copy tileset 677A->8000
    ld de,$8000                    ; $0C3D  ; de=8000
    ld bc,$0800                    ; $0C40  ; bc=800
    call Mem_CopyBC                ; $0C43  ; copy
    ld hl,$C2C0                    ; $0C46  ; hl=C2C0
    ld bc,$0600                    ; $0C49  ; bc=600
    call Mem_ZeroFill              ; $0C4C  ; zero fill
    ld hl,$777A                    ; $0C4F  ; hl=777A
    ld de,$C2C0                    ; $0C52  ; de=C2C0
    ld c,$05                       ; $0C55  ; c=5 banks

Gfx_InitBank0_Tiles:
    push de                        ; $0C57  ; build tiles 5 rows
    ld b,$28                       ; $0C58  ; b=28
    call Mem_CopyB                 ; $0C5A  ; copy 28 bytes
    call Gfx_Skip8                 ; $0C5D  ; skip 8
    ld b,$08                       ; $0C60  ; b=8
    call Mem_CopyB                 ; $0C62  ; copy 8
    pop de                         ; $0C65  ; restore de
    inc d                          ; $0C66  ; next bank
    dec c                          ; $0C67  ; loop
    jr nz,Gfx_InitBank0_Tiles      ; $0C68  ; loop
    ld de,$C2C0                    ; $0C6A  ; de=C2C0
    ld c,$05                       ; $0C6D  ; c=5

Gfx_InitBank0_Expand:
    push de                        ; $0C6F  ; expand nibbles
    ld hl,$0040                    ; $0C70  ; hl=de+40
    add hl,de                      ; $0C73  ; addr
    ld b,$40                       ; $0C74  ; b=40

Gfx_InitBank0_ExpandLp:
    ld a,[de]                      ; $0C76  ; expand byte
    inc de                         ; $0C77  ; next
    swap a                         ; $0C78  ; swap
    and $0F                        ; $0C7A  ; low nibble
    ld [hl+],a                     ; $0C7C  ; store
    dec b                          ; $0C7D  ; loop
    jr nz,Gfx_InitBank0_ExpandLp   ; $0C7E  ; loop
    pop de                         ; $0C80  ; restore de
    push de                        ; $0C81  ; push
    call Gfx_MergeNibble           ; $0C82  ; merge
    ld b,$10                       ; $0C85  ; b=10

Gfx_InitBank0_Skip:
    inc de                         ; $0C87  ; skip
    inc hl                         ; $0C88  ; de++
    dec b                          ; $0C89  ; hl++
    jr nz,Gfx_InitBank0_Skip       ; $0C8A  ; loop
    call Gfx_MergeNibble           ; $0C8C  ; merge
    pop de                         ; $0C8F  ; restore
    inc d                          ; $0C90  ; next bank
    dec c                          ; $0C91  ; loop
    jr nz,Gfx_InitBank0_Expand     ; $0C92  ; loop
    ld de,$C2C0                    ; $0C94  ; de=C2C0
    ld c,$05                       ; $0C97  ; c=5

Gfx_InitBank0_Rearr:
    push de                        ; $0C99  ; duplicate tiles
    call Gfx_DupeTiles             ; $0C9A  ; dupe
    call Gfx_DupeTiles             ; $0C9D  ; dupe
    pop de                         ; $0CA0  ; restore de
    inc d                          ; $0CA1  ; next
    dec c                          ; $0CA2  ; loop
    jr nz,Gfx_InitBank0_Rearr      ; $0CA3  ; loop
    ld hl,$C2D0                    ; $0CA5  ; hl=C2D0
    ld de,$9500                    ; $0CA8  ; de=9500
    call Gfx_CopyTiles             ; $0CAB  ; copy tiles
    ld hl,$C370                    ; $0CAE  ; hl=C370
    call Gfx_CopyTiles             ; $0CB1  ; copy
    ld hl,$C2E0                    ; $0CB4  ; hl=C2E0
    call Gfx_CopyTiles             ; $0CB7  ; copy
    ld hl,$C330                    ; $0CBA  ; hl=C330
    call Gfx_CopyTiles             ; $0CBD  ; copy
    ld hl,$C300                    ; $0CC0  ; hl=C300
    ld de,$9500                    ; $0CC3  ; de=9500
    call Gfx_CopyTiles_Or          ; $0CC6  ; or-copy
    ld hl,$C3A0                    ; $0CC9  ; hl=C3A0
    call Gfx_CopyTiles_Or          ; $0CCC  ; or
    ld hl,$C340                    ; $0CCF  ; hl=C340
    call Gfx_CopyTiles_Or          ; $0CD2  ; or
    ld hl,$C390                    ; $0CD5  ; hl=C390
    call Gfx_CopyTiles_Or          ; $0CD8  ; or
    ld hl,$C2C0                    ; $0CDB  ; hl=C2C0
    ld de,$8E00                    ; $0CDE  ; de=8E00
    call Gfx_OrTiles               ; $0CE1  ; or to VRAM
    ld hl,$C310                    ; $0CE4  ; hl=C310
    call Gfx_OrTiles               ; $0CE7  ; or
    ld hl,$C360                    ; $0CEA  ; hl=C360
    call Gfx_OrTiles               ; $0CED  ; or
    ld hl,$C3B0                    ; $0CF0  ; hl=C3B0
    call Gfx_OrTiles               ; $0CF3  ; or
    ld hl,$76FA                    ; $0CF6  ; hl=76FA
    ld de,$8F80                    ; $0CF9  ; de=8F80
    ld b,$80                       ; $0CFC  ; b=80
    call Mem_CopyB                 ; $0CFE  ; copy
    ld hl,$747A                    ; $0D01  ; hl=747A
    ld de,$8500                    ; $0D04  ; de=8500
    ld bc,$0260                    ; $0D07  ; bc=260
    call Mem_CopyBC                ; $0D0A  ; copy
    ld hl,$18FF                    ; $0D0D  ; hl=18FF (font?)
    call Bg_WriteBlock             ; $0D10  ; draw bg
    ld hl,$9823                    ; $0D13  ; hl=9823
    xor a                          ; $0D16  ; a=0
    ld c,$08                       ; $0D17  ; c=8

loc_0D19:
    ld b,$09                       ; $0D19  ; row
    ld de,$0003                    ; $0D1B  ; b=9

loc_0D1E:
    ld [hl],a                      ; $0D1E  ; step3: write tile numbers
    inc a                          ; $0D1F
    add hl,de                      ; $0D20  ; a++
    dec b                          ; $0D21  ; hl+=3
    jr nz,loc_0D1E                 ; $0D22  ; loop
    ld de,$0045                    ; $0D24  ; de=45
    add hl,de                      ; $0D27  ; next row
    dec c                          ; $0D28  ; loop
    jr nz,loc_0D19                 ; $0D29  ; loop
    ret                            ; $0D2B  ; ret

Gfx_CopyTiles:
    ld a,$05                       ; $0D2C  ; copy 5 blocks from C2xx to VRAM

Gfx_CopyTiles_Rep:
    ldh [$FFD9],a                  ; $0D2E  ; repeat
    ld c,$06                       ; $0D30  ; c=6 rows

Gfx_CopyTiles_Row:
    push hl                        ; $0D32  ; row
    ld b,$10                       ; $0D33  ; b=10

Gfx_CopyTiles_RowLp:
    ld a,[hl+]                     ; $0D35  ; copy 16 bytes
    ld [de],a                      ; $0D36  ; store
    inc de                         ; $0D37  ; de++
    dec b                          ; $0D38  ; loop
    jr nz,Gfx_CopyTiles_RowLp      ; $0D39  ; loop
    call Gfx_WrapDe                ; $0D3B  ; wrap de
    pop hl                         ; $0D3E  ; restore hl
    dec c                          ; $0D3F  ; row
    jr nz,Gfx_CopyTiles_Row        ; $0D40  ; loop
    inc h                          ; $0D42  ; hl high++
    ldh a,[$FFD9]                  ; $0D43  ; FFD9
    dec a                          ; $0D45  ; repeat
    jr nz,Gfx_CopyTiles_Rep        ; $0D46  ; loop
    ld hl,$0060                    ; $0D48  ; de += 60
    add hl,de                      ; $0D4B  ; add
    push hl                        ; $0D4C  ; push
    pop de                         ; $0D4D  ; pop de
    ret                            ; $0D4E  ; ret

Gfx_CopyTiles_Or:
    ld b,$06                       ; $0D4F  ; or-copy 6 blocks

Gfx_CopyTiles_OrLp:
    push bc                        ; $0D51  ; loop
    push hl                        ; $0D52  ; push hl
    call Gfx_OrTiles               ; $0D53  ; or-copy
    pop hl                         ; $0D56  ; restore
    pop bc                         ; $0D57  ; restore bc
    dec b                          ; $0D58  ; loop
    jr nz,Gfx_CopyTiles_OrLp       ; $0D59  ; loop
    ret                            ; $0D5B  ; ret

Gfx_OrTiles:
    ld c,$05                       ; $0D5C  ; OR 16-byte tiles into VRAM

Gfx_OrTiles_Row:
    push hl                        ; $0D5E  ; c=5 rows
    ld b,$10                       ; $0D5F  ; push hl

Gfx_OrTiles_RowLp:
    ld a,[de]                      ; $0D61  ; merge byte
    or [hl]                        ; $0D62  ; or
    ld [de],a                      ; $0D63  ; store
    inc hl                         ; $0D64  ; hl++
    inc de                         ; $0D65  ; de++
    dec b                          ; $0D66  ; loop
    jr nz,Gfx_OrTiles_RowLp        ; $0D67  ; loop
    call Gfx_WrapDe                ; $0D69  ; wrap
    pop hl                         ; $0D6C  ; restore
    inc h                          ; $0D6D  ; hl high++
    dec c                          ; $0D6E  ; row
    jr nz,Gfx_OrTiles_Row          ; $0D6F  ; loop
    ld hl,$0010                    ; $0D71  ; de += 10
    add hl,de                      ; $0D74  ; add
    push hl                        ; $0D75  ; push
    pop de                         ; $0D76  ; pop de

Gfx_WrapDe:
    ld a,d                         ; $0D77  ; wrap de high to 88
    cp $98                         ; $0D78  ; d<98?
    ret c                          ; $0D7A  ; ret
    ld d,$88                       ; $0D7B  ; d=88
    ret                            ; $0D7D  ; ret

Gfx_DupeTiles:
    call Gfx_CopyRel               ; $0D7E  ; duplicate tiles block
    call Gfx_CopyRel               ; $0D81  ; dupe
    call Gfx_DupeTiles_T           ; $0D84  ; dupe

Gfx_DupeTiles_T:
    call Gfx_CopyRel_088           ; $0D87  ; dupe

Gfx_Skip8:
    ld b,$08                       ; $0D8A  ; skip 8 bytes

Gfx_Skip8Lp:
    inc de                         ; $0D8C  ; de++
    dec b                          ; $0D8D  ; loop
    jr nz,Gfx_Skip8Lp              ; $0D8E  ; loop
    ret                            ; $0D90  ; ret

Gfx_CopyRel:
    call Gfx_CopyRel_088           ; $0D91  ; copy 8 bytes with offset
    ld hl,$0098                    ; $0D94  ; hl=de+98

Gfx_CopyRel8:
    add hl,de                      ; $0D97  ; hl+=de
    ld b,$08                       ; $0D98  ; b=8

Gfx_CopyRel8Lp:
    ld a,[de]                      ; $0D9A  ; copy
    inc de                         ; $0D9B  ; de++
    ld [hl+],a                     ; $0D9C  ; store
    dec b                          ; $0D9D  ; loop
    jr nz,Gfx_CopyRel8Lp           ; $0D9E  ; loop
    ret                            ; $0DA0  ; ret

Gfx_CopyRel_088:
    ld hl,$0088                    ; $0DA1  ; hl=de+88
    jr Gfx_CopyRel8                ; $0DA4  ; jump copy

Gfx_MergeNibble:
    ld hl,$0050                    ; $0DA6  ; merge high nibble into [de+50]
    add hl,de                      ; $0DA9  ; hl=de+50
    ld b,$10                       ; $0DAA  ; b=10

Gfx_MergeNibbleLp:
    ld a,[de]                      ; $0DAC  ; merge
    inc de                         ; $0DAD  ; de++
    swap a                         ; $0DAE  ; swap
    and $F0                        ; $0DB0  ; high nibble
    or [hl]                        ; $0DB2  ; or [hl]
    ld [hl+],a                     ; $0DB3  ; store
    dec b                          ; $0DB4  ; loop
    jr nz,Gfx_MergeNibbleLp        ; $0DB5  ; loop
    ret                            ; $0DB7  ; ret

Level_Load:
    ld hl,$C96B                    ; $0DB8  ; load level into C96B
    ld b,$90                       ; $0DBB  ; b=90
    call Level_DecodeRow           ; $0DBD  ; decode to buffer
    ldh a,[$FF8A]                  ; $0DC0  ; FF8A
    cp $0A                         ; $0DC2  ; ==0A?
    ld bc,$0910                    ; $0DC4  ; bc=0910
    jr z,Level_Load_Build          ; $0DC7  ; if yes
    ldh a,[$FF9D]                  ; $0DC9  ; level
    sub $0F                        ; $0DCB  ; -0F
    jr c,Level_RenderBoard         ; $0DCD  ; if <0
    cp $0F                         ; $0DCF  ; ==0F?
    ld bc,$060C                    ; $0DD1  ; bc=060C
    jr c,Level_Load_Table2         ; $0DD4  ; if yes
    ld bc,$0910                    ; $0DD6  ; bc=0910

Level_Load_Table2:
    push bc                        ; $0DD9  ; load from table2 (4BBA)
    ld hl,$4BBA                    ; $0DDA  ; hl=4BBA
    call Table16_Get               ; $0DDD  ; index
    push hl                        ; $0DE0  ; push
    pop de                         ; $0DE1  ; pop de
    pop bc                         ; $0DE2  ; restore bc

Level_Load_Build:
    ld a,b                         ; $0DE3  ; build row flags
    ldh [$FFD9],a                  ; $0DE4  ; FFD9=b
    ld hl,$CB63                    ; $0DE6  ; hl=CB63
    ld b,$48                       ; $0DE9  ; b=48
    ld a,$01                       ; $0DEB  ; a=1

Level_Load_Fill:
    ld [hl+],a                     ; $0DED  ; fill CB63 with 1
    dec b                          ; $0DEE  ; loop
    jr nz,Level_Load_Fill          ; $0DEF  ; loop
    ld hl,$CA8B                    ; $0DF1  ; hl=CA8B

Level_Load_Decode:
    ldh a,[$FFD9]                  ; $0DF4  ; decode next row
    ld b,a                         ; $0DF6  ; b=FFD9
    call Level_DecodeRow           ; $0DF7
    ldh a,[$FFD9]                  ; $0DFA
    sub $09                        ; $0DFC
    jr z,loc_0E0A                  ; $0DFE
    cpl                            ; $0E00  ; negate: a = -(rowWidth-9)
    inc a                          ; $0E01  ; a = 9 - rowWidth
    ld b,a                         ; $0E02  ; b = columns to pad
    ld a,$01                       ; $0E03  ; filler tile 1

loc_0E05:
    ld [hl+],a                     ; $0E05  ; pad right edge col
    ld [hl+],a                     ; $0E06  ; pad 2nd col
    dec b                          ; $0E07  ; count
    jr nz,loc_0E05                 ; $0E08  ; loop pad

loc_0E0A:
    dec c                          ; $0E0A  ; next row
    jr nz,Level_Load_Decode        ; $0E0B  ; until all rows patched

Level_RenderBoard:
    ld c,$10                       ; $0E0D  ; render full board to VRAM: 16 cols

loc_0E0F:
    ld b,$12                       ; $0E0F  ; x 18 cells per col

loc_0E11:
    push bc                        ; $0E11  ; save cell counters
    call Level_BuildCell           ; $0E12  ; decode one grid cell to tiles
    call Level_VramWrite           ; $0E15  ; copy tile bytes to VRAM
    pop bc                         ; $0E18  ; restore counters
    ld a,[$C8C0]                   ; $0E19  ; C8C0 = grid index low
    add $01                        ; $0E1C  ; index++
    ld [$C8C0],a                   ; $0E1E  ; store low
    ld a,[$C8C1]                   ; $0E21  ; high byte
    adc $00                        ; $0E24  ; propagate carry
    ld [$C8C1],a                   ; $0E26  ; store high
    dec b                          ; $0E29  ; next cell
    jr nz,loc_0E11                 ; $0E2A  ; loop 18 cells
    dec c                          ; $0E2C  ; next column
    jr nz,loc_0E0F                 ; $0E2D  ; loop 16 columns
    jp Gfx_DrawHud                 ; $0E2F  ; refresh HUD after build

Level_DecodeRow:
    ld a,[de]                      ; $0E32  ; decode compressed row (hl=out, de=src, b=len)
    and $70                        ; $0E33  ; mask bits 4-6
    cp $60                         ; $0E35  ; literal if < $60
    ld a,[de]                      ; $0E37  ; reload byte
    jr c,loc_0E52                  ; $0E38  ; literal path
    cp $F2                         ; $0E3A  ; >= $F2: dense fill
    jr c,loc_0E67                  ; $0E3C  ; $60-$F1: run-length pattern
    sub $02                        ; $0E3E  ; a = byte - 2
    and $0F                        ; $0E40  ; low nibble
    bit 3,a                        ; $0E42  ; bit3 set?
    jr z,loc_0E4B                  ; $0E44  ; no: 3-tile fill
    and $07                        ; $0E46  ; yes: 7-tile fill
    ld [hl+],a                     ; $0E48  ; emit tile
    ld [hl+],a                     ; $0E49  ; emit tile
    dec b                          ; $0E4A  ; consume output count

loc_0E4B:
    ld [hl+],a                     ; $0E4B  ; emit
    ld [hl+],a                     ; $0E4C  ; emit
    dec b                          ; $0E4D  ; consume
    ld [hl+],a                     ; $0E4E  ; emit
    ld [hl+],a                     ; $0E4F  ; emit
    jr loc_0E55                    ; $0E50  ; next byte

loc_0E52:
    call Level_EmitNibbles         ; $0E52  ; expand literal byte -> 2 tiles

loc_0E55:
    inc de                         ; $0E55  ; advance source
    dec b                          ; $0E56  ; count
    jr nz,Level_DecodeRow          ; $0E57  ; next byte
    ret                            ; $0E59  ; ret

Level_EmitNibbles:
    push af                        ; $0E5A  ; expand byte into 2 tile bytes
    swap a                         ; $0E5B  ; high nibble first
    call Level_NibbleToTile        ; $0E5D  ; nibble -> tile
    ld [hl+],a                     ; $0E60  ; emit
    pop af                         ; $0E61  ; restore
    call Level_NibbleToTile        ; $0E62  ; low nibble -> tile
    ld [hl+],a                     ; $0E65  ; emit
    ret                            ; $0E66  ; ret

loc_0E67:
    bit 7,a                        ; $0E67  ; bit7 set: negative run
    jr nz,loc_0E6D                 ; $0E69  ; no: keep low 5 bits
    and $1F                        ; $0E6B  ; run length 1-31

loc_0E6D:
    and $3F                        ; $0E6D  ; mask run length
    add a                          ; $0E6F  ; x2 -> 16-bit table index
    push af                        ; $0E70  ; save index
    call Level_RlePattern          ; $0E71  ; emit pattern byte A
    call Level_EmitNibbles         ; $0E74  ; emit 2 tiles
    pop af                         ; $0E77  ; restore index
    inc a                          ; $0E78  ; next entry
    call Level_RlePattern          ; $0E79  ; emit pattern byte B
    dec b                          ; $0E7C  ; extra output consumed
    jr loc_0E52                    ; $0E7D  ; continue row decode

Level_RlePattern:
    push bc                        ; $0E7F  ; emit run pattern byte from table
    push hl                        ; $0E80  ; save output ptr
    rst $20                        ; $0E81  ; rst $20: table lookup (table at $0E82)
    db $64,$05,$50,$50,$05,$20,$02,$40
    db $00,$05,$55,$25,$55,$45,$55,$55
    db $54,$55,$50,$55,$52,$00,$55,$55
    db $00,$00,$05,$50,$00,$20,$00,$00
    db $02,$01,$01,$10,$10,$25,$25,$52
    db $52,$54,$54,$45,$45,$02,$02,$20
    db $20,$12,$12,$05,$05,$50,$50,$04
    db $04,$40,$40,$45,$54,$33,$35,$55
    db $25,$55,$45,$05,$52,$25,$54,$11
    db $12,$21,$11,$02,$05,$50,$02,$25
    db $50,$55,$20,$45,$52,$33,$32,$23
    db $33,$54,$55,$00,$20,$85,$55,$55
    db $58,$52,$55,$24,$22,$E1,$C1,$C9

Level_NibbleToTile:
    push bc                        ; $0EEA  ; nibble -> tile byte mapper
    push hl                        ; $0EEB  ; save output ptr
    and $0F                        ; $0EEC  ; low nibble
    rst $20                        ; $0EEE  ; rst $20: table lookup (table at $0EEF)
    db $0E,$00,$01,$02,$03,$04,$05,$05
    db $05,$25,$10,$85,$95,$A8,$B9,$E1
    db $C1,$C9

Level_BuildCell:
    call Level_CellCoords          ; $0F01  ; build one grid cell: tiles + VRAM dst
    ld a,[$C908]                   ; $0F04  ; row
    and $01                        ; $0F07  ; row parity
    bit 0,l                        ; $0F09  ; column parity
    jr z,loc_0F0F                  ; $0F0B  ; both even
    or $02                         ; $0F0D  ; flag bit1: odd column

loc_0F0F:
    ldh [$FFDB],a                  ; $0F0F  ; FFDB = tile flag 0-3
    ld c,a                         ; $0F11  ; c = flag
    cp $02                         ; $0F12  ; flag >= 2?
    jr c,loc_0F1B                  ; $0F14  ; below 2
    ld c,$12                       ; $0F16  ; c = $12 (row offset)
    jr z,loc_0F1B                  ; $0F18  ; flag == 2
    inc c                          ; $0F1A  ; c = $13

loc_0F1B:
    ld a,[$C8C0]                   ; $0F1B  ; C8C0 - c
    sub c                          ; $0F1E  ; index low
    ld c,a                         ; $0F1F  ; c
    ld a,[$C8C1]                   ; $0F20  ; high byte
    sbc $00                        ; $0F23  ; borrow
    ld b,a                         ; $0F25  ; b
    ld hl,$C96B                    ; $0F26  ; level buffer C96B
    add hl,bc                      ; $0F29  ; cell at index
    call Level_ReadNibbleHi        ; $0F2A  ; read high nibble
    ld b,a                         ; $0F2D  ; b
    call Level_ReadNibbleLo        ; $0F2E  ; read low nibble
    ld [$C8C2],a                   ; $0F31  ; C8C2 = tile A
    ld de,$0011                    ; $0F34  ; next row
    add hl,de                      ; $0F37  ; cell + $11
    call Level_ReadNibbleHi        ; $0F38  ; read high nibble
    ld [$C8C3],a                   ; $0F3B  ; C8C3 = tile B
    call Level_ReadNibbleLo        ; $0F3E  ; read low nibble
    ld [$C8C4],a                   ; $0F41  ; C8C4 = tile C
    ld c,$00                       ; $0F44  ; offset 0
    ld hl,$C2F0                    ; $0F46  ; tile bank C2F0
    add hl,bc                      ; $0F49  ; row stride
    push hl                        ; $0F4A  ; save src
    ld a,[$C8C2]                   ; $0F4B  ; tile A
    ld b,a                         ; $0F4E  ; b
    ld hl,$C320                    ; $0F4F  ; tile bank C320
    add hl,bc                      ; $0F52  ; + row
    ld de,$C90C                    ; $0F53  ; dest buffer C90C
    pop bc                         ; $0F56  ; restore src
    call Level_OrCopy8             ; $0F57  ; OR-merge 8 bytes
    ld a,[$C8C3]                   ; $0F5A  ; tile B
    ld b,a                         ; $0F5D  ; b
    ld c,$00                       ; $0F5E  ; offset 0
    ld hl,$C358                    ; $0F60  ; tile bank C358
    add hl,bc                      ; $0F63  ; + row
    push hl                        ; $0F64  ; save src
    ld a,[$C8C4]                   ; $0F65  ; tile C
    ld b,a                         ; $0F68  ; b
    ld hl,$C388                    ; $0F69  ; tile bank C388
    add hl,bc                      ; $0F6C  ; + row
    pop bc                         ; $0F6D  ; restore src
    call Level_OrCopy8             ; $0F6E  ; OR-merge 8 bytes
    ld a,[$C909]                   ; $0F71  ; column
    srl a                          ; $0F74  ; col / 2
    ld l,a                         ; $0F76  ; l
    sla a                          ; $0F77  ; col x4
    sla a                          ; $0F79  ; col x8
    sla a                          ; $0F7B  ; col x16
    add l                          ; $0F7D  ; col x17
    ld l,a                         ; $0F7E  ; l
    ld a,[$C908]                   ; $0F7F  ; row
    srl a                          ; $0F82  ; row / 2
    add l                          ; $0F84  ; combine
    swap a                         ; $0F85  ; nibble swap
    ld h,a                         ; $0F87  ; h
    and $F0                        ; $0F88  ; low nibble
    ld l,a                         ; $0F8A  ; l
    ld a,h                         ; $0F8B  ; h
    and $0F                        ; $0F8C
    ld h,a                         ; $0F8E  ; high nibble
    ld de,$9000                    ; $0F8F
    add hl,de                      ; $0F92  ; tile dst addr
    ld a,l                         ; $0F93  ; low
    ld [$C90B],a                   ; $0F94  ; C90B = dst low
    ld a,h                         ; $0F97  ; high
    ld [$C90A],a                   ; $0F98  ; C90A = dst high
    ld a,[$C909]                   ; $0F9B  ; column
    ld hl,$10B6                    ; $0F9E  ; column base table
    call Table16_Get               ; $0FA1  ; lookup column VRAM base
    ld a,[$C908]                   ; $0FA4  ; row
    srl a                          ; $0FA7  ; row / 2
    jr nc,loc_0FAC                 ; $0FA9  ; even row
    inc hl                         ; $0FAB  ; odd row: next tile row

loc_0FAC:
    ld b,a                         ; $0FAC  ; b = row/2
    sla a                          ; $0FAD  ; row x2
    add b                          ; $0FAF  ; row x3
    ld c,a                         ; $0FB0  ; c
    ld b,$00                       ; $0FB1  ; b = 0
    add hl,bc                      ; $0FB3  ; add row offset
    ld a,l                         ; $0FB4  ; low
    ld [$C91D],a                   ; $0FB5  ; C91D = dst low
    ld a,h                         ; $0FB8  ; high
    ld [$C91C],a                   ; $0FB9  ; C91C = dst high
    ldh a,[$FFDB]                  ; $0FBC  ; tile flag
    rst $20                        ; $0FBE  ; rst $20: dispatch tile flag (table at $0FBF)
    db $04,$20,$21,$20,$1F,$47,$F0,$DB
    db $CB,$4F,$20,$0E,$FA,$1D,$C9,$80
    db $EA,$21,$C9,$FA,$1C,$C9,$CE,$00
    db $18,$0C,$FA,$1D,$C9,$90,$EA,$21
    db $C9,$FA,$1C,$C9,$DE,$00,$EA,$20
    db $C9,$FA,$C0,$C8,$6F,$FA,$C1,$C8
    db $67,$11,$6B,$C9,$19,$7E,$CD,$03
    db $11,$F0,$DB,$FE,$01,$28,$17,$FE
    db $02,$28,$24,$FE,$03,$28,$37,$CD
    db $62,$10,$EA,$1F,$C9,$3E,$E0,$83
    db $EA,$1E,$C9,$2B,$18,$21,$2B,$CD
    db $62,$10,$EA,$1E,$C9,$CD,$AD,$10
    db $C6,$E6,$EA,$1F,$C9,$18,$2A,$CD
    db $69,$10,$EA,$1F,$C9,$3E,$EC,$83
    db $EA,$1E,$C9,$11,$ED,$FF,$19,$CD
    db $74,$10,$C6,$98,$18,$18,$2B,$CD
    db $69,$10,$EA,$1E,$C9,$CD,$AD,$10
    db $C6,$F2,$EA,$1F,$C9,$11,$EE,$FF
    db $19,$CD,$74,$10,$C6,$BC,$47,$11
    db $11,$00,$19,$CD,$AD,$10,$80,$EA
    db $22,$C9,$C9,$CD,$74,$10,$C6,$50
    db $18,$05,$CD,$74,$10,$C6,$74,$4F
    db $CD,$AD,$10,$81,$C9,$CD,$A4,$10
    db $5F,$CB,$27,$47,$CB,$27,$80,$C9

Level_CellCoords:
    ld a,[$C8C0]                   ; $107F  ; compute row/col from grid index
    ld l,a                         ; $1082  ; l = index low
    ld a,[$C8C1]                   ; $1083  ; h = index high
    ld h,a                         ; $1086  ; h
    ld a,$12                       ; $1087  ; divide by 18 (cells per column)
    call Div16_Mod                 ; $1089  ; divmod: quotient/remainder
    ld [$C908],a                   ; $108C  ; C908 = row (quotient)
    ld a,l                         ; $108F  ; l = remainder
    ld [$C909],a                   ; $1090  ; C909 = column
    ret                            ; $1093  ; ret

Level_OrCopy8:
    ld a,$08                       ; $1094  ; OR-merge 8 bytes: [de]=[bc]|[hl]

loc_1096:
    ldh [$FFD9],a                  ; $1096  ; count 8
    ld a,[bc]                      ; $1098  ; src A byte
    or [hl]                        ; $1099  ; OR src B
    ld [de],a                      ; $109A  ; store
    inc bc                         ; $109B  ; advance A
    inc de                         ; $109C  ; advance dst
    inc hl                         ; $109D  ; advance B
    ldh a,[$FFD9]                  ; $109E  ; count
    dec a                          ; $10A0  ; dec
    jr nz,loc_1096                 ; $10A1  ; loop
    ret                            ; $10A3  ; ret

Level_ReadNibbleHi:
    ld a,[hl+]                     ; $10A4  ; read cell high nibble (clamp 6+ to 5)
    and $0F                        ; $10A5  ; low nibble
    cp $06                         ; $10A7  ; < 6?
    ret c                          ; $10A9  ; keep
    ld a,$05                       ; $10AA  ; clamp to 5
    ret                            ; $10AC  ; ret

Level_ReadNibbleLo:
    ld a,[hl]                      ; $10AD  ; read cell low nibble (clamp 6+ to 5)
    and $0F                        ; $10AE  ; low nibble
    cp $06                         ; $10B0  ; < 6?
    ret c                          ; $10B2  ; keep
    ld a,$05                       ; $10B3  ; clamp to 5
    ret                            ; $10B5  ; ret

Level_ColTable:
    ld [bc],a                      ; $10B6  ; data: BG tilemap col base table (16 words)
    sbc b                          ; $10B7  ; col0 lo ($02)
    ld b,d                         ; $10B8  ; col1 lo ($42)
    sbc b                          ; $10B9  ; col1 hi ($98)
    ld h,d                         ; $10BA  ; col2 lo ($62)
    sbc b                          ; $10BB  ; col2 hi ($98)
    and d                          ; $10BC  ; col3 lo ($A2)
    sbc b                          ; $10BD  ; col3 hi ($98)
    jp nz,loc_0298                 ; $10BE  ; col4 word ($C2,$98)
    sbc c                          ; $10C1  ; col5 lo ($02)
    ld [hl+],a                     ; $10C2  ; col6 lo ($22)
    sbc c                          ; $10C3  ; col6 hi ($99)
    ld h,d                         ; $10C4  ; col7 lo ($62)
    sbc c                          ; $10C5  ; col7 hi ($99)
    add d                          ; $10C6  ; col8 lo ($82)
    sbc c                          ; $10C7  ; col8 hi ($99)
    jp nz,$E299                    ; $10C8  ; col9 word ($C2,$99)
    sbc c                          ; $10CB  ; col10 lo ($99)
    ld [hl+],a                     ; $10CC  ; col11 lo ($22)
    sbc d                          ; $10CD  ; col11 hi ($9A)
    ld b,d                         ; $10CE  ; col12 lo ($42)
    sbc d                          ; $10CF  ; col12 hi ($9A)
    add d                          ; $10D0  ; col13 lo ($82)
    sbc d                          ; $10D1  ; col13 hi ($9A)
    and d                          ; $10D2  ; col14 lo ($A2)
    sbc d                          ; $10D3  ; col14 hi ($9A)
    ld [$FF00+c],a                 ; $10D4  ; col15 lo ($E2)
    sbc d                          ; $10D5  ; col15 hi ($9A)

Level_VramWrite:
    ld hl,$C90A                    ; $10D6  ; write queued tile bytes to VRAM
    ld a,[hl]                      ; $10D9  ; dst high
    and a                          ; $10DA  ; valid?
    ret z                          ; $10DB  ; no dst -> ret
    ld d,a                         ; $10DC  ; d = high
    xor a                          ; $10DD  ; a = 0
    ld [hl+],a                     ; $10DE  ; consume flag
    ld a,[hl+]                     ; $10DF  ; dst low
    ld e,a                         ; $10E0  ; e = low
    ld b,$10                       ; $10E1  ; 16 bytes

loc_10E3:
    ld a,[hl+]                     ; $10E3  ; copy tile line
    ld [de],a                      ; $10E4  ; store
    inc de                         ; $10E5  ; advance
    dec b                          ; $10E6  ; count
    jr nz,loc_10E3                 ; $10E7  ; loop
    ld hl,$C91C                    ; $10E9  ; block2 ptr C91C
    ld a,[hl]                      ; $10EC  ; high
    and a                          ; $10ED  ; valid?
    ret z                          ; $10EE  ; no -> ret
    ld d,a                         ; $10EF  ; d = high
    xor a                          ; $10F0  ; a = 0
    ld [hl+],a                     ; $10F1  ; consume
    ld a,[hl+]                     ; $10F2  ; low
    ld e,a                         ; $10F3  ; e = low
    ld a,[hl+]                     ; $10F4  ; byte 1
    ld [de],a                      ; $10F5  ; store
    inc de                         ; $10F6  ; advance
    ld a,[hl+]                     ; $10F7  ; byte 2
    ld [de],a                      ; $10F8  ; store
    ld hl,$C920                    ; $10F9  ; block3 ptr C920
    ld a,[hl+]                     ; $10FC  ; high
    ld d,a                         ; $10FD  ; d = high
    ld a,[hl+]                     ; $10FE  ; low
    ld e,a                         ; $10FF  ; e = low
    ld a,[hl]                      ; $1100  ; byte
    ld [de],a                      ; $1101  ; store
    ret                            ; $1102  ; ret

Level_ModifyCell:
    cp $04                         ; $1103  ; handle dig/gold for cell value a
    jr nz,loc_111B                 ; $1105  ; value 4 (gold)?
    ldh a,[$FF90]                  ; $1107  ; FF90 bit5 (rope in use)
    bit 5,a                        ; $1109  ; rope active?
    jr nz,loc_1114                 ; $110B  ; no: count gold
    ldh a,[$FFB5]                  ; $110D  ; FFB5 collected gold
    inc a                          ; $110F  ; increment
    cp $FF                         ; $1110  ; cap at FF?
    jr c,loc_1118                  ; $1112  ; below cap

loc_1114:
    ld a,$05                       ; $1114  ; cap: remove tile
    ld [hl],a                      ; $1116  ; cell = 5 (empty)
    ret                            ; $1117  ; ret

loc_1118:
    ldh [$FFB5],a                  ; $1118  ; FFB5 = new count
    ret                            ; $111A  ; ret

loc_111B:
    bit 7,a                        ; $111B  ; dig marker (bit7)?
    ret z                          ; $111D  ; not dig -> ret
    push de                        ; $111E  ; save de
    cp $90                         ; $111F  ; < $90?
    jr nc,loc_1128                 ; $1121  ; player dig
    ld de,$C000                    ; $1123  ; de = player obj C000
    jr loc_1163                    ; $1126  ; attach hole

loc_1128:
    cp $A0                         ; $1128  ; < $A0?
    jr nc,loc_1153                 ; $112A  ; no
    ld de,$C010                    ; $112C  ; de = hole slot C010
    ldh a,[$FF98]                  ; $112F  ; active hole index
    and $0F                        ; $1131  ; low nibble
    cp $09                         ; $1133  ; == 9?
    jr z,loc_1163                  ; $1135  ; use C010
    ld a,[$C010]                   ; $1137  ; obj state
    and a                          ; $113A  ; free?
    jr z,loc_1163                  ; $113B  ; use C010
    ld de,$C020                    ; $113D  ; de = slot C020
    ldh a,[$FF98]                  ; $1140  ; index
    and $0F                        ; $1142  ; == 0A?
    cp $0A                         ; $1144  ; use
    jr z,loc_1163                  ; $1146  ; obj state
    ld a,[$C020]                   ; $1148  ; free?
    and a                          ; $114B  ; use C020
    jr z,loc_1163                  ; $114C  ; use
    ld de,$C030                    ; $114E  ; de = slot C030
    jr loc_1163                    ; $1151  ; attach

loc_1153:
    cp $B0                         ; $1153  ; < $B0?
    jr nc,loc_115C                 ; $1155  ; no
    ld de,$C040                    ; $1157  ; de = slot C040
    jr loc_1163                    ; $115A  ; attach

loc_115C:
    cp $C0                         ; $115C  ; < $C0?
    jr nc,loc_11A8                 ; $115E  ; no
    ld de,$C050                    ; $1160  ; de = slot C050

loc_1163:
    ldh a,[$FF9C]                  ; $1163  ; FF9C bits 0+4
    and $11                        ; $1165  ; mask
    cp $11                         ; $1167  ; both set?
    jr z,loc_11A8                  ; $1169  ; skip dig
    ldh a,[$FF9C]                  ; $116B  ; FF9C bits 1+5
    and $22                        ; $116D  ; mask
    cp $22                         ; $116F  ; both set?
    jr z,loc_11A8                  ; $1171  ; skip dig
    push hl                        ; $1173  ; save hl
    ld hl,$0000                    ; $1174  ; hl = slot base
    add hl,de                      ; $1177  ; slot
    ld a,[hl]                      ; $1178  ; obj state
    and a                          ; $1179  ; active?
    jr z,loc_1190                  ; $117A  ; inactive: create
    ld a,[$C8C0]                   ; $117C  ; C8C0 index low
    ld hl,$0006                    ; $117F  ; slot+6
    add hl,de                      ; $1182  ; stored low
    cp [hl]                        ; $1183  ; match?
    jr nz,loc_1190                 ; $1184  ; no
    ld a,[$C8C1]                   ; $1186  ; C8C1 high
    ld hl,$0007                    ; $1189  ; slot+7
    add hl,de                      ; $118C  ; stored high
    cp [hl]                        ; $118D  ; match?
    jr z,loc_11A7                  ; $118E  ; same hole

loc_1190:
    ld a,[$C8C0]                   ; $1190  ; index low
    ld hl,$0006                    ; $1193  ; slot+6
    add hl,de                      ; $1196  ; slot
    ld [hl],a                      ; $1197  ; store
    ld a,[$C8C1]                   ; $1198  ; index high
    ld hl,$0007                    ; $119B  ; slot+7
    add hl,de                      ; $119E  ; slot
    ld [hl],a                      ; $119F  ; store
    ld a,$01                       ; $11A0  ; active flag
    ld hl,$0000                    ; $11A2  ; slot+0
    add hl,de                      ; $11A5  ; slot
    ld [hl],a                      ; $11A6  ; store 1

loc_11A7:
    pop hl                         ; $11A7  ; restore hl

loc_11A8:
    pop de                         ; $11A8  ; restore de
    ldh a,[$FF8A]                  ; $11A9  ; mode FF8A
    cp $09                         ; $11AB  ; == 9 (title)?
    ret z                          ; $11AD  ; keep dig marker
    ld a,[hl]                      ; $11AE  ; cell value
    and $0F                        ; $11AF  ; clear dig bits
    ld [hl],a                      ; $11B1  ; store
    ret                            ; $11B2  ; ret

Level_QueuePush_Rel:
    ld bc,$C96B                    ; $11B3  ; level ptr = C96B + hl (offset)
    add hl,bc                      ; $11B6  ; add level base

Level_QueuePush:
    ld c,a                         ; $11B7  ; push cell update (hl=ptr, a=value)
    ld a,[$C906]                   ; $11B8  ; C906 head
    ld b,a                         ; $11BB  ; b
    ld a,[$C907]                   ; $11BC  ; C907 tail
    add $02                        ; $11BF  ; tail + 2
    and $1F                        ; $11C1  ; wrap 32
    cp b                           ; $11C3  ; head == tail?
    ret z                          ; $11C4  ; queue full -> ret
    ld [$C907],a                   ; $11C5  ; store new tail
    ld a,c                         ; $11C8  ; new cell value
    ld [hl],a                      ; $11C9  ; store in level cell
    ld a,l                         ; $11CA  ; offset low
    sub $6B                        ; $11CB  ; - $6B
    ld l,a                         ; $11CD  ; l
    ld a,h                         ; $11CE  ; high
    sbc $C9                        ; $11CF  ; - $C9
    ld h,a                         ; $11D1  ; h
    push hl                        ; $11D2  ; save offset
    ld hl,$C8C6                    ; $11D3  ; queue base C8C6
    ld a,[$C907]                   ; $11D6  ; tail
    sub $02                        ; $11D9  ; - 2
    and $1F                        ; $11DB  ; wrap
    ld c,a                         ; $11DD  ; c
    ld b,$00                       ; $11DE  ; b = 0
    add hl,bc                      ; $11E0  ; queue slot
    pop bc                         ; $11E1  ; restore offset
    ld a,c                         ; $11E2  ; low
    ld [hl+],a                     ; $11E3  ; store low
    ld a,b                         ; $11E4  ; high
    ld [hl],a                      ; $11E5  ; store high
    rlca                           ; $11E6  ; rotate (flag for caller)
    ret                            ; $11E7  ; ret

Level_QueuePop:
    ld a,[$C907]                   ; $11E8  ; pop next queued cell update
    ld b,a                         ; $11EB  ; tail
    ld a,[$C906]                   ; $11EC  ; head
    cp b                           ; $11EF  ; equal (empty)?
    ret z                          ; $11F0  ; empty -> ret
    ld c,a                         ; $11F1  ; c = head
    ld b,$00                       ; $11F2  ; b = 0
    add $02                        ; $11F4  ; head + 2
    and $1F                        ; $11F6  ; wrap
    ld [$C906],a                   ; $11F8  ; store new head
    ld hl,$C8C6                    ; $11FB  ; queue base
    add hl,bc                      ; $11FE  ; slot
    ld a,[hl+]                     ; $11FF  ; index low
    ld [$C8C0],a                   ; $1200  ; C8C0 = low
    ld a,[hl]                      ; $1203  ; index high
    ld [$C8C1],a                   ; $1204  ; C8C1 = high
    jp Level_BuildCell             ; $1207  ; re-render cell

Level_Setup:
    push hl                        ; $120A  ; start level: clear board, load level
    ld hl,$FF90                    ; $120B  ; FF90
    bit 1,[hl]                     ; $120E  ; bit1 (retry)?
    ld a,$11                       ; $1210  ; music id $11
    jr z,loc_1216                  ; $1212  ; not set
    ld a,$80                       ; $1214  ; music id $80

loc_1216:
    ldh [$FFAE],a                  ; $1216  ; FFAE = music
    xor a                          ; $1218  ; a = 0
    ld [$C8C0],a                   ; $1219  ; C8C0 = 0
    ld [$C8C1],a                   ; $121C  ; C8C1 = 0
    ldh [$FFB5],a                  ; $121F  ; FFB5 gold = 0
    ld [$C906],a                   ; $1221  ; queue head = 0
    ld [$C907],a                   ; $1224  ; queue tail = 0
    ldh [$FF91],a                  ; $1227  ; FF91 = 0
    ldh a,[$FF90]                  ; $1229  ; FF90
    bit 3,a                        ; $122B  ; bit3 (in game)?
    ld a,$3C                       ; $122D  ; Y bound $3C
    jr z,loc_1233                  ; $122F  ; not in game
    ld a,$4C                       ; $1231  ; Y bound $4C

loc_1233:
    ldh [$FFD3],a                  ; $1233  ; FFD3 = Y bound
    ld a,$54                       ; $1235  ; X bound $54
    ldh [$FFD2],a                  ; $1237  ; FFD2 = X bound
    ldh a,[$FF9C]                  ; $1239  ; FF9C bit0
    bit 0,a                        ; $123B  ; level already active?
    jr nz,Level_Setup_Keep         ; $123D  ; yes: keep objects
    ld hl,$FF90                    ; $123F  ; FF90
    res 5,[hl]                     ; $1242  ; clear rope flag
    ld hl,$C000                    ; $1244  ; object RAM C000
    ld bc,$02C0                    ; $1247  ; size $02C0
    call Mem_ZeroFill              ; $124A  ; zero fill objects
    call Gfx_InitBank0_Full        ; $124D  ; clear tile RAM
    pop de                         ; $1250  ; restore level ptr
    call Level_Load                ; $1251  ; load level into C96B
    ldh a,[$FF9C]                  ; $1254  ; FF9C mode
    and $8F                        ; $1256  ; keep high bits
    or $01                         ; $1258  ; set mode bit0
    ldh [$FF9C],a                  ; $125A  ; FF9C = 1
    xor a                          ; $125C  ; a = 0
    ld [$C8C0],a                   ; $125D  ; C8C0 = 0
    ld [$C8C1],a                   ; $1260  ; C8C1 = 0
    ldh [$FFCE],a                  ; $1263  ; FFCE camera Y = 0
    ld a,$08                       ; $1265  ; camera X = 8
    ldh [$FFCC],a                  ; $1267  ; FFCC camera X
    call Level_Setup_GuardTotal    ; $1269  ; add guards to total
    call Game_GoldTier             ; $126C  ; init scroll
    ld a,b                         ; $126F  ; b
    ldh [$FFB6],a                  ; $1270  ; FFB6 = scroll mode

Level_Setup_Bounds:
    ld a,[$C006]                   ; $1272  ; set camera from player pos
    ld l,a                         ; $1275  ; player X low
    ld a,[$C007]                   ; $1276  ; player X high
    ld h,a                         ; $1279  ; h
    ld a,$12                       ; $127A  ; grid width 18
    call Div16_Mod                 ; $127C  ; loc_3D8F divmod
    call Mul10_A                   ; $127F  ; player column
    add $16                        ; $1282  ; col + 22
    cp $50                         ; $1284  ; >= $50?
    jr nc,loc_128C                 ; $1286  ; no: near left edge
    ld a,$04                       ; $1288  ; camera X = 4
    jr loc_1296                    ; $128A  ; set

loc_128C:
    cp $A0                         ; $128C  ; >= $A0?
    jr c,loc_1294                  ; $128E  ; no
    ldh a,[$FFD2]                  ; $1290  ; use X bound
    jr loc_1296                    ; $1292  ; set

loc_1294:
    sub $4C                        ; $1294  ; centered: col - $4C

loc_1296:
    ldh [$FFCC],a                  ; $1296  ; FFCC = camera X
    ld a,l                         ; $1298  ; player row
    call Mul10_A                   ; $1299  ; row
    add $06                        ; $129C  ; row + 6
    cp $48                         ; $129E  ; >= $48?
    jr nc,loc_12A5                 ; $12A0  ; no: near top
    xor a                          ; $12A2  ; camera Y = 0
    jr loc_12AF                    ; $12A3  ; set

loc_12A5:
    cp $84                         ; $12A5  ; >= $84?
    jr c,loc_12AD                  ; $12A7  ; no
    ldh a,[$FFD3]                  ; $12A9  ; use Y bound
    jr loc_12AF                    ; $12AB  ; set

loc_12AD:
    sub $48                        ; $12AD  ; centered: row - $48

loc_12AF:
    ldh [$FFCE],a                  ; $12AF  ; FFCE = camera Y
    ret                            ; $12B1  ; ret

Level_Setup_Keep:
    pop hl                         ; $12B2  ; level active: keep objects
    call Game_SaveState            ; $12B3  ; init scroll
    call Gfx_InitBank0_Full        ; $12B6  ; clear tile RAM
    call Level_RenderBoard         ; $12B9  ; rebuild board to VRAM
    ldh a,[$FF9C]                  ; $12BC  ; FF9C mode
    and $8F                        ; $12BE  ; keep high bits
    ldh [$FF9C],a                  ; $12C0  ; FF9C = 0
    xor a                          ; $12C2  ; a = 0
    ld [$C8C0],a                   ; $12C3  ; C8C0 = 0
    ld [$C8C1],a                   ; $12C6  ; C8C1 = 0
    ld a,[$CBAB]                   ; $12C9  ; saved camera X
    ldh [$FFCC],a                  ; $12CC  ; FFCC = X
    ld a,[$CBAC]                   ; $12CE  ; saved camera Y
    ldh [$FFCE],a                  ; $12D1  ; FFCE = Y

Level_Setup_GuardTotal:
    ld hl,$FFB5                    ; $12D3  ; FFB4 = gold + guard count
    ld a,[hl-]                     ; $12D6  ; FFB5 gold
    ld [hl],a                      ; $12D7  ; FFB4 = gold
    ld a,[$C01F]                   ; $12D8  ; guard obj 1
    and a                          ; $12DB  ; active?
    jr z,loc_12DF                  ; $12DC  ; no
    inc [hl]                       ; $12DE  ; total++

loc_12DF:
    ld a,[$C02F]                   ; $12DF  ; guard obj 2
    and a                          ; $12E2  ; active?
    jr z,loc_12E6                  ; $12E3  ; no
    inc [hl]                       ; $12E5  ; total++

loc_12E6:
    ld a,[$C03F]                   ; $12E6  ; guard obj 3
    and a                          ; $12E9  ; active?
    ret z                          ; $12EA  ; no
    inc [hl]                       ; $12EB  ; total++
    ret                            ; $12EC  ; ret

Level_Retry:
    ld a,$12                       ; $12ED  ; retry: load current level
    ldh [$FFAE],a                  ; $12EF  ; FFAE = music $12
    call Game_SaveState            ; $12F1  ; init scroll
    ld a,$3C                       ; $12F4  ; timer = $3C
    ld [$C049],a                   ; $12F6  ; C049 = timer
    xor a                          ; $12F9  ; a = 0
    ld [$C8C0],a                   ; $12FA  ; C8C0 = 0
    ld [$C8C1],a                   ; $12FD  ; C8C1 = 0
    ldh [$FFB5],a                  ; $1300  ; FFB5 = 0
    ld [$C906],a                   ; $1302  ; queue head = 0
    ld [$C907],a                   ; $1305  ; queue tail = 0
    ldh a,[$FF90]                  ; $1308  ; FF90
    srl a                          ; $130A  ; shift bit0 -> carry
    ccf                            ; $130C  ; invert carry
    jr nc,loc_1313                 ; $130D  ; bit0 set: no test
    ldh a,[$FF9D]                  ; $130F  ; level number
    cp $1E                         ; $1311  ; < 30?

loc_1313:
    ld a,$0C                       ; $1313  ; Y bound $0C
    jr c,loc_1319                  ; $1315  ; small level
    ld a,$3C                       ; $1317  ; Y bound $3C

loc_1319:
    ldh [$FFD3],a                  ; $1319  ; FFD3 = Y scroll bound
    ld a,$08                       ; $131B  ; X bound $08
    jr c,loc_1321                  ; $131D  ; small level
    ld a,$54                       ; $131F  ; X bound $54

loc_1321:
    ldh [$FFD2],a                  ; $1321  ; FFD2 = X scroll bound
    ldh a,[$FF90]                  ; $1323  ; FF90
    bit 3,a                        ; $1325  ; bit3 in game
    jr z,loc_132F                  ; $1327  ; not in game
    ldh a,[$FFD3]                  ; $1329  ; Y bound
    add $10                        ; $132B  ; Y bound += $10
    ldh [$FFD3],a                  ; $132D  ; store

loc_132F:
    call Gfx_InitBank0_Full        ; $132F  ; clear tile RAM
    call Level_RenderBoard         ; $1332  ; rebuild board to VRAM
    ldh a,[$FF9C]                  ; $1335  ; FF9C mode
    bit 1,a                        ; $1337  ; bit1
    jr nz,loc_134C                 ; $1339  ; set: keep player
    ld a,[$C047]                   ; $133B  ; saved player X low
    ld [$C007],a                   ; $133E  ; C007 = X low
    ld a,[$C046]                   ; $1341  ; saved X high
    ld [$C006],a                   ; $1344  ; C006 = player X
    ld a,$01                       ; $1347  ; state = 1
    ld [$C000],a                   ; $1349  ; C000 = 1

loc_134C:
    ldh a,[$FF9C]                  ; $134C  ; FF9C
    and $8F                        ; $134E  ; mask high bits
    or $42                         ; $1350  ; mode $42
    ldh [$FF9C],a                  ; $1352  ; FF9C = mode
    xor a                          ; $1354  ; a = 0
    ld [$C8C0],a                   ; $1355  ; C8C0 = 0
    ld [$C8C1],a                   ; $1358  ; C8C1 = 0
    ldh [$FFCE],a                  ; $135B  ; camera Y = 0
    ld a,$08                       ; $135D  ; cam X = 8
    ldh [$FFCC],a                  ; $135F  ; FFCC = cam X
    ldh a,[$FF90]                  ; $1361  ; FF90
    srl a                          ; $1363  ; shift bit0 -> carry
    ccf                            ; $1365  ; invert carry
    jr nc,loc_136C                 ; $1366  ; skip bound adjust
    ldh a,[$FF9D]                  ; $1368  ; level number
    cp $1E                         ; $136A  ; < 30?

loc_136C:
    call nc,Level_Setup_Bounds     ; $136C  ; adjust camera to player
    call Level_Setup_GuardTotal    ; $136F  ; add guards to total
    call Game_GoldTier             ; $1372  ; calc gold tier
    ld a,b                         ; $1375  ; tier result
    ldh [$FFB7],a                  ; $1376  ; FFB7 = tier
    ret                            ; $1378  ; ret

Game_GoldTier:
    ld b,$00                       ; $1379  ; tier = 0
    ldh a,[$FFB5]                  ; $137B  ; gold collected
    cp $0B                         ; $137D  ; < 11?
    ret c                          ; $137F  ; tier 0
    inc b                          ; $1380  ; tier 1
    cp $15                         ; $1381  ; < 21?
    ret c                          ; $1383  ; tier 1
    inc b                          ; $1384  ; tier 2
    cp $1F                         ; $1385  ; < 31?
    ret c                          ; $1387  ; tier 2
    inc b                          ; $1388  ; tier 3
    ret                            ; $1389  ; ret

Game_SaveState:
    ld hl,$C000                    ; $138A  ; backup object RAM start
    ld de,$C160                    ; $138D  ; backup dst C160
    ld bc,$0160                    ; $1390  ; length 0x160
    call Mem_Swap                  ; $1393  ; copy objects to backup
    ld hl,$C96B                    ; $1396  ; backup level buffer
    ld de,$CA8B                    ; $1399  ; backup dst CA8B
    ld bc,$0120                    ; $139C  ; length 0x120
    jp Mem_Swap                    ; $139F  ; copy level buffer

Game_KeyHandler:
    ldh a,[$FFAD]                  ; $13A2  ; handle start/select keys, split screen
    and a                          ; $13A4  ; FFAD=0?
    ret nz                         ; $13A5  ; busy ret
    ldh a,[$FF97]                  ; $13A6  ; FF97 scroll seq
    and a                          ; $13A8  ; active?
    ret nz                         ; $13A9  ; busy ret
    ldh a,[$FF90]                  ; $13AA  ; FF90
    bit 3,a                        ; $13AC  ; bit3 in game?
    jr nz,loc_13B5                 ; $13AE  ; force split mode
    ldh a,[$FF91]                  ; $13B0  ; FF91 split flag
    and a                          ; $13B2  ; not split
    jr z,loc_13C0                  ; $13B3  ; skip

loc_13B5:
    ld a,$03                       ; $13B5  ; STAT mode 3 (split)
    ldh [$FF8F],a                  ; $13B7  ; FF8F = 3
    ld a,$7F                       ; $13B9  ; LYC = $7F
    ldh [$FF45],a                  ; $13BB  ; FF45 = $7F
    inc a                          ; $13BD  ; LYC + 1
    ldh [$FFD0],a                  ; $13BE  ; FFD0 = $80

loc_13C0:
    ldh a,[$FF91]                  ; $13C0  ; FF91 split?
    and a                          ; $13C2  ; not split
    jr z,loc_13DA                  ; $13C3  ; skip
    ldh a,[$FFC2]                  ; $13C5  ; FFC2 (select pressed)
    bit 2,a                        ; $13C7  ; bit2?
    jr z,loc_13F5                  ; $13C9  ; no
    ldh a,[$FF8A]                  ; $13CB  ; save mode
    ldh [$FF92],a                  ; $13CD  ; FF92 = mode
    ldh a,[$FFCC]                  ; $13CF  ; save cam X
    ldh [$FF93],a                  ; $13D1  ; FF93 = X
    ldh a,[$FFCE]                  ; $13D3  ; save cam Y
    ldh [$FF94],a                  ; $13D5  ; FF94 = Y
    ld a,$06                       ; $13D7  ; mode 6
    rst $08                        ; $13D9  ; jump mode 6 (rst $08)

loc_13DA:
    ldh a,[$FFC2]                  ; $13DA  ; FFC2 select?
    bit 2,a                        ; $13DC  ; bit2?
    jr z,loc_13F5                  ; $13DE  ; no
    ldh a,[$FF8A]                  ; $13E0  ; mode FF8A
    cp $0C                         ; $13E2  ; == $0C?
    jr nz,loc_13F2                 ; $13E4  ; else scroll
    ldh a,[$FF90]                  ; $13E6  ; FF90 bit0
    bit 0,a                        ; $13E8  ; in game?
    ld a,$05                       ; $13EA  ; mode $05
    jr z,loc_13F0                  ; $13EC  ; not in game
    ld a,$0A                       ; $13EE  ; mode $0A

loc_13F0:
    ldh [$FF8A],a                  ; $13F0  ; FF8A = new mode

loc_13F2:
    jp Scroll_Start                ; $13F2  ; start intro scroll

loc_13F5:
    ldh a,[$FFC2]                  ; $13F5  ; FFC2 (start pressed)
    bit 3,a                        ; $13F7  ; bit3?
    jr z,Game_ScrollCamera         ; $13F9  ; no: scroll
    ldh a,[$FF91]                  ; $13FB  ; FF91 split?
    and a                          ; $13FD  ; active?
    jr z,loc_1412                  ; $13FE  ; else setup 3
    xor a                          ; $1400  ; a = 0
    ldh [$FF91],a                  ; $1401  ; FF91 = 0
    ldh a,[$FF90]                  ; $1403  ; FF90
    bit 3,a                        ; $1405  ; bit3?
    jr nz,loc_140F                 ; $1407  ; in game ret1
    xor a                          ; $1409  ; a = 0
    ldh [$FFD0],a                  ; $140A  ; FFD0 = 0
    inc a                          ; $140C  ; a = 1
    ldh [$FF8F],a                  ; $140D  ; FF8F = 1

loc_140F:
    jp Snd_StopFlag                ; $140F  ; jump loc_3E3B

loc_1412:
    ld a,$07                       ; $1412  ; STAT mode 7
    ldh [$FFCF],a                  ; $1414  ; FFCF = 7
    ld a,$7F                       ; $1416  ; LYC = $7F
    ldh [$FF45],a                  ; $1418  ; FF45
    inc a                          ; $141A  ; a = $80
    ldh [$FFD0],a                  ; $141B  ; FFD0 = $80
    ld a,$03                       ; $141D  ; STAT mode 3
    ldh [$FF8F],a                  ; $141F  ; FF8F = 3
    ldh [$FF91],a                  ; $1421  ; FF91 = 3
    call SoundEngine_VBlank_Reset  ; $1423  ; reset sound
    ld a,$04                       ; $1426  ; sfx 4
    jp SoundEngine_PlayEffect      ; $1428  ; play sfx

Game_ScrollCamera:
    ldh a,[$FFD2]                  ; $142B  ; follow player: X axis
    cp $08                         ; $142D  ; X bound == 8?
    jr z,loc_144F                  ; $142F  ; no scroll
    ld hl,$FFCC                    ; $1431  ; hl = FFCC cam X
    ld a,[$C003]                   ; $1434  ; player X low
    sub [hl]                       ; $1437  ; X - cam
    cp $40                         ; $1438  ; >= $40?
    jr nc,loc_1444                 ; $143A  ; below
    ld a,[hl]                      ; $143C  ; cam
    cp $05                         ; $143D  ; < 5?
    jr c,loc_144F                  ; $143F  ; at edge
    dec [hl]                       ; $1441  ; cam X--
    jr loc_144F                    ; $1442  ; continue

loc_1444:
    cp $60                         ; $1444  ; >= $60?
    jr c,loc_144F                  ; $1446  ; mid
    ldh a,[$FFD2]                  ; $1448  ; X bound
    dec a                          ; $144A  ; bound - 1
    cp [hl]                        ; $144B  ; cam < bound?
    jr c,loc_144F                  ; $144C  ; capped
    inc [hl]                       ; $144E  ; cam X++

loc_144F:
    ld hl,$FFCE                    ; $144F  ; follow player: Y axis
    ld a,[$C005]                   ; $1452  ; player Y low
    sub [hl]                       ; $1455  ; Y - cam
    cp $38                         ; $1456  ; >= $38?
    jr nc,loc_1461                 ; $1458  ; below
    ld a,[hl]                      ; $145A  ; cam
    and a                          ; $145B  ; zero?
    jr z,loc_146C                  ; $145C  ; at top
    dec [hl]                       ; $145E  ; cam Y--
    jr loc_146C                    ; $145F  ; continue

loc_1461:
    cp $58                         ; $1461  ; >= $58?
    jr c,loc_146C                  ; $1463  ; mid
    ldh a,[$FFD3]                  ; $1465  ; Y bound
    dec a                          ; $1467  ; bound - 1
    cp [hl]                        ; $1468  ; cam < bound?
    jr c,loc_146C                  ; $1469  ; capped
    inc [hl]                       ; $146B  ; cam Y++

loc_146C:
    ret                            ; $146C  ; ret

Gfx_SplitOn:
    xor a                          ; $146D  ; enable LCD split mode
    ldh [$FFD0],a                  ; $146E  ; FFD0 = 0
    inc a                          ; $1470  ; a = 1
    ldh [$FF8F],a                  ; $1471  ; FF8F = 1
    ld a,$07                       ; $1473  ; STAT split line 7
    ldh [$FFCF],a                  ; $1475  ; FFCF = 7
    ld a,$40                       ; $1477  ; STAT = $40
    ldh [$FF41],a                  ; $1479  ; FF41 = $40
    ld a,$43                       ; $147B  ; LCDC = $43
    ldh [$FFCA],a                  ; $147D  ; FFCA = $43
    ret                            ; $147F  ; ret

Gfx_LcdcUpdate:
    ld hl,$FFCA                    ; $1480  ; sync LCDC shadow with flags
    ldh a,[$FF91]                  ; $1483  ; FF91 split?
    and a                          ; $1485  ; active?
    jr nz,loc_1497                 ; $1486  ; keep window
    ldh a,[$FF97]                  ; $1488  ; FF97 scroll seq
    and $7F                        ; $148A  ; & $7F
    ldh [$FF96],a                  ; $148C  ; FF96 = value
    and a                          ; $148E  ; zero?
    jr z,loc_149A                  ; $148F  ; else check game
    ldh [$FF45],a                  ; $1491  ; FF45 = LYC
    ld a,[hl]                      ; $1493  ; LCDC shadow
    and $FC                        ; $1494  ; clear bits 0-1
    ld [hl],a                      ; $1496  ; store

loc_1497:
    set 5,[hl]                     ; $1497  ; enable window (bit5)
    ret                            ; $1499  ; ret

loc_149A:
    ldh a,[$FF90]                  ; $149A  ; FF90
    bit 3,a                        ; $149C  ; bit3?
    jr nz,loc_1497                 ; $149E  ; in game: window
    res 5,[hl]                     ; $14A0  ; disable window
    ret                            ; $14A2  ; ret

Scroll_Anim:
    ld hl,$FF97                    ; $14A3  ; advance scroll sequence FF97
    ld a,[hl]                      ; $14A6  ; FF97
    and a                          ; $14A7  ; zero?
    ret z                          ; $14A8  ; idle ret
    bit 7,a                        ; $14A9  ; bit7 (countdown)?
    jr z,loc_14BC                  ; $14AB  ; else countup
    cp $81                         ; $14AD  ; == $81?
    jr z,loc_14B3                  ; $14AF  ; reset
    dec [hl]                       ; $14B1  ; FF97--
    ret                            ; $14B2  ; ret

loc_14B3:
    xor a                          ; $14B3  ; FF97 = 0
    ld [hl],a                      ; $14B4  ; store 0
    ldh a,[$FFCA]                  ; $14B5  ; LCDC shadow
    or $03                         ; $14B7  ; set bits 0-1
    ldh [$FFCA],a                  ; $14B9  ; FFCA = $43
    ret                            ; $14BB  ; ret

loc_14BC:
    ld a,[hl]                      ; $14BC  ; count up
    cp $46                         ; $14BD  ; >= $46?
    jr nc,loc_14C3                 ; $14BF  ; else
    inc [hl]                       ; $14C1  ; FF97++
    ret                            ; $14C2  ; ret

loc_14C3:
    ldh a,[$FF90]                  ; $14C3  ; FF90 bit1
    bit 1,a                        ; $14C5  ; set?
    ld a,$00                       ; $14C7  ; cmd $00
    jr nz,loc_14EF                 ; $14C9  ; direct jump
    ldh a,[$FF9C]                  ; $14CB  ; FF9C & $30
    and $30                        ; $14CD  ; mask
    jr z,loc_14DB                  ; $14CF  ; zero?
    cp $20                         ; $14D1  ; == $20?
    ld a,$0C                       ; $14D3  ; cmd $0C
    jr z,loc_14D9                  ; $14D5  ; set cmd
    ld a,$0D                       ; $14D7  ; cmd $0D

loc_14D9:
    jr loc_14EF                    ; $14D9  ; jump dispatch

loc_14DB:
    ldh a,[$FF8A]                  ; $14DB  ; mode FF8A
    cp $0C                         ; $14DD  ; == $0C?
    jr z,loc_14E9                  ; $14DF  ; cmd $0D
    cp $02                         ; $14E1  ; == $02?
    jr nz,loc_14ED                 ; $14E3  ; else
    ldh a,[$FFB4]                  ; $14E5  ; FFB4 total
    jr loc_14ED                    ; $14E7  ; use it

loc_14E9:
    ld a,$0D                       ; $14E9  ; cmd $0D
    jr loc_14EF                    ; $14EB  ; jump dispatch

loc_14ED:
    and $0C                        ; $14ED  ; & $0C

loc_14EF:
    rst $08                        ; $14EF  ; jt: scroll command

Scroll_Done:
    ld a,$C6                       ; $14F0  ; mark intro scroll done
    ldh [$FF96],a                  ; $14F2  ; FF96 = $C6
    ldh [$FF97],a                  ; $14F4  ; FF97 = $C6
    ld a,$06                       ; $14F6  ; sfx 6
    jp Sfx_PlayC                   ; $14F8  ; play sfx

Scroll_Start:
    ldh a,[$FF96]                  ; $14FB  ; begin intro scroll
    and a                          ; $14FD  ; FF96 busy?
    ret nz                         ; $14FE  ; done ret
    xor a                          ; $14FF  ; a = 0
    ldh [$FFD0],a                  ; $1500  ; FFD0 = 0
    inc a                          ; $1502  ; a = 1
    ldh [$FF97],a                  ; $1503  ; FF97 = 1
    ldh [$FF8F],a                  ; $1505  ; FF8F = 1
    ld a,$13                       ; $1507  ; sfx $13
    jp Sfx_PlayC                   ; $1509  ; play sfx

Game_EnemyTimer:
    ldh a,[$FF90]                  ; $150C  ; enemy respawn timer
    bit 3,a                        ; $150E  ; FF90 bit3?
    ret z                          ; $1510  ; not in game ret
    ldh a,[$FFAD]                  ; $1511  ; FFAD count
    and a                          ; $1513  ; running?
    jr z,loc_151D                  ; $1514  ; reload
    dec a                          ; $1516  ; count--
    ldh [$FFAD],a                  ; $1517  ; FFAD--
    ret nz                         ; $1519  ; ongoing ret
    ld a,$0E                       ; $151A  ; mode $0E
    rst $08                        ; $151C  ; trigger mode

loc_151D:
    ldh a,[$FFAC]                  ; $151D  ; FFAC?
    and a                          ; $151F  ; active ret
    ret nz                         ; $1520
    ld a,$08                       ; $1521  ; timer 8
    ldh [$FFAD],a                  ; $1523  ; FFAD = 8
    ret                            ; $1525  ; ret

Level_Preview:
    xor a                          ; $1526  ; draw level preview to VRAM
    ld [$C8C0],a                   ; $1527  ; grid index = 0
    ld [$C8C1],a                   ; $152A  ; C8C1 = 0
    ld [$C923],a                   ; $152D  ; defer write = 0
    ld [$C000],a                   ; $1530  ; player state = 0
    ld [$C010],a                   ; $1533  ; guard A = 0
    ld [$C020],a                   ; $1536  ; guard B = 0
    ld [$C030],a                   ; $1539  ; guard C = 0
    ld [$C040],a                   ; $153C  ; slot C040 = 0
    ld [$C050],a                   ; $153F  ; slot C050 = 0
    ld a,$6B                       ; $1542  ; out ptr low
    ldh [$FFD9],a                  ; $1544  ; FFD9 = $6B
    ld a,$C9                       ; $1546  ; out ptr high
    ldh [$FFDA],a                  ; $1548  ; FFDA = $C9
    ldh a,[$FF9F]                  ; $154A  ; preview level no
    ld e,$90                       ; $154C  ; row size $90
    call Mul16_AxDE                ; $154E  ; multiply: level * $90
    ld de,$CBAD                    ; $1551  ; preview data base
    add hl,de                      ; $1554  ; hl = level preview ptr
    ld de,$9C21                    ; $1555  ; VRAM dst $9C21
    ld c,$10                       ; $1558  ; 16 columns

loc_155A:
    ld b,$09                       ; $155A  ; 9 bytes per row

loc_155C:
    ld a,[hl]                      ; $155C  ; load cell
    swap a                         ; $155D  ; high nibble first
    call Level_PreviewTile         ; $155F  ; emit tile
    ld a,[hl+]                     ; $1562  ; reload cell
    call Level_PreviewTile         ; $1563  ; emit low nibble
    dec b                          ; $1566  ; row count
    jr nz,loc_155C                 ; $1567  ; row loop
    ld a,e                         ; $1569  ; dst low
    add $0E                        ; $156A  ; + $0E
    ld e,a                         ; $156C  ; e
    jr nc,loc_1570                 ; $156D  ; no carry
    inc d                          ; $156F  ; dst high++

loc_1570:
    dec c                          ; $1570  ; next col
    jr nz,loc_155A                 ; $1571  ; col loop
    xor a                          ; $1573  ; a = 0
    ld [$C8C0],a                   ; $1574  ; C8C0 = 0
    ld [$C8C1],a                   ; $1577  ; C8C1 = 0
    ret                            ; $157A  ; ret

Level_PreviewTile:
    and $0F                        ; $157B  ; emit preview tile from nibble
    push af                        ; $157D  ; save
    push bc                        ; $157E  ; save
    push hl                        ; $157F  ; save
    rst $20                        ; $1580  ; rst $20: nibble lookup + write
    db $0E,$00,$01,$02,$03,$04,$05,$05
    db $05,$25,$10,$85,$95,$A5,$B5,$F5
    db $F0,$D9,$6F,$C6,$01,$E0,$D9,$F0
    db $DA,$67,$CE,$00,$E0,$DA,$F1,$77
    db $CD,$03,$11,$FA,$C0,$C8,$C6,$01
    db $EA,$C0,$C8,$FA,$C1,$C8,$CE,$00
    db $EA,$C1,$C8,$E1,$C1,$F1,$F6,$C0
    db $FE,$C5,$20,$02,$3E,$FC,$12,$13
    db $C9

Game_CheckButtons:
    ldh a,[$FFC0]                  ; $15C2  ; check menu button
    bit 3,a                        ; $15C4  ; FFC0 bit3?
    ret z                          ; $15C6  ; none ret
    ld a,$08                       ; $15C7  ; mode 8
    rst $08                        ; $15C9  ; jump mode (rst $08)

Gfx_DeferredWrite:
    ld hl,$C923                    ; $15CA  ; write deferred VRAM byte
    ld a,[hl]                      ; $15CD  ; dst high
    and a                          ; $15CE  ; pending?
    ret z                          ; $15CF  ; none ret
    ld d,a                         ; $15D0  ; d = high
    xor a                          ; $15D1  ; a = 0
    ld [hl+],a                     ; $15D2  ; clear high
    ld a,[hl+]                     ; $15D3  ; dst low
    ld e,a                         ; $15D4  ; e = low
    ld a,[hl]                      ; $15D5  ; data byte
    ld [de],a                      ; $15D6  ; write to VRAM
    ret                            ; $15D7  ; ret

Obj_Next:
    call Obj_DrawSprite            ; $15D8  ; advance to next active object
    ldh a,[$FF98]                  ; $15DB  ; current slot FF98
    cp $08                         ; $15DD  ; < 8?
    jr c,loc_1643                  ; $15DF  ; wrap to 0
    jr nz,loc_15F5                 ; $15E1  ; > 8?
    ldh a,[$FF9F]                  ; $15E3  ; FF9F preview
    srl a                          ; $15E5  ; shift
    ld a,$09                       ; $15E7  ; slot 9
    jr c,loc_15F5                  ; $15E9  ; odd?
    ld a,[$C000]                   ; $15EB  ; player obj
    and a                          ; $15EE  ; active?
    ld a,$08                       ; $15EF  ; slot 8
    jr z,loc_15F5                  ; $15F1  ; inactive
    ld a,$09                       ; $15F3  ; slot 9

loc_15F5:
    cp $09                         ; $15F5  ; == 9?
    jr nz,loc_1603                 ; $15F7  ; else
    ld a,[$C010]                   ; $15F9  ; guard A
    and a                          ; $15FC  ; active?
    ld a,$09                       ; $15FD  ; slot 9
    jr z,loc_1603                  ; $15FF  ; inactive
    ld a,$0A                       ; $1601  ; slot $0A

loc_1603:
    cp $0A                         ; $1603  ; == $0A?
    jr nz,loc_1611                 ; $1605  ; else
    ld a,[$C020]                   ; $1607  ; guard B
    and a                          ; $160A  ; active?
    ld a,$0A                       ; $160B  ; slot $0A
    jr z,loc_1611                  ; $160D  ; inactive
    ld a,$0B                       ; $160F  ; slot $0B

loc_1611:
    cp $0B                         ; $1611  ; == $0B?
    jr nz,loc_161F                 ; $1613  ; else
    ld a,[$C030]                   ; $1615  ; guard C
    and a                          ; $1618  ; active?
    ld a,$0B                       ; $1619  ; slot $0B
    jr z,loc_161F                  ; $161B  ; inactive
    ld a,$0C                       ; $161D  ; slot $0C

loc_161F:
    cp $0C                         ; $161F  ; == $0C?
    jr nz,loc_162D                 ; $1621  ; else
    ld a,[$C040]                   ; $1623  ; slot C040
    and a                          ; $1626  ; active?
    ld a,$0C                       ; $1627  ; slot $0C
    jr z,loc_162D                  ; $1629  ; inactive
    ld a,$0D                       ; $162B  ; slot $0D

loc_162D:
    cp $0D                         ; $162D  ; == $0D?
    jr nz,loc_1643                 ; $162F  ; wrap
    ldh a,[$FF9F]                  ; $1631  ; FF9F preview
    srl a                          ; $1633  ; shift
    ld a,$00                       ; $1635  ; slot 0
    jr c,loc_1643                  ; $1637  ; odd?
    ld a,[$C050]                   ; $1639  ; slot C050
    and a                          ; $163C  ; active?
    ld a,$0D                       ; $163D  ; slot $0D
    jr z,loc_1643                  ; $163F  ; inactive
    ld a,$00                       ; $1641  ; slot 0

loc_1643:
    ldh [$FF98],a                  ; $1643  ; FF98 = slot
    and $0F                        ; $1645  ; & $0F
    rst $20                        ; $1647  ; rst $20: dispatch object
    db $0E,$C0,$C9,$C1,$C2,$C8,$C3,$C4
    db $FC,$CA,$CB,$CB,$CB,$CC,$CD,$EA
    db $0A,$9C,$FA,$C0,$C8,$6F,$FA,$C1
    db $C8,$67,$F0,$C0,$CB,$47,$CA,$11
    db $17,$3E,$0E,$CD,$4B,$3E,$E5,$F0
    db $98,$E6,$0F,$E7,$0E,$C0,$C9,$C1
    db $C2,$C8,$C3,$C4,$FC,$CA,$CB,$CB
    db $CB,$CC,$CD,$EA,$25,$C9,$CD,$7F
    db $10,$FA,$09,$C9,$1E,$20,$CD,$68
    db $3D,$FA,$08,$C9,$5F,$16,$00,$19
    db $11,$21,$9C,$19,$7C,$EA,$23,$C9
    db $7D,$EA,$24,$C9,$E1,$11,$6B,$C9
    db $19,$E5,$7E,$CB,$7F,$C4,$73,$17
    db $F0,$98,$E6,$0F,$E7,$0E,$00,$10
    db $01,$02,$22,$03,$04,$05,$85,$95
    db $95,$95,$A5,$B5,$E1,$77,$CD,$03
    db $11,$FA,$C0,$C8,$6F,$FA,$C1,$C8
    db $67,$CB,$3C,$CB,$1D,$3E,$00,$30
    db $02,$3E,$01,$E0,$D9,$11,$AD,$CB
    db $19,$E5,$F0,$9F,$1E,$90,$CD,$68
    db $3D,$D1,$19,$E5,$F0,$98,$E7,$0E
    db $00,$90,$10,$20,$80,$30,$40,$50
    db $A0,$B0,$B0,$B0,$C0,$D0,$47,$F0
    db $D9,$A7,$0E,$0F,$28,$04,$0E,$F0
    db $CB,$30,$E1,$7E,$A1,$B0,$77,$18
    db $61,$CB,$4F,$28,$23,$F0,$98,$E6
    db $0F,$FE,$09,$28,$04,$FE,$0A,$20
    db $02,$3E,$0B,$FE,$0D,$38,$06,$F0
    db $98,$E6,$F0,$18,$07,$3C,$47,$F0
    db $98,$E6,$F0,$B0,$E0,$98,$18,$3A
    db $CB,$6F,$28,$05,$11,$FF,$FF,$18
    db $11,$CB,$67,$28,$06,$11,$01,$00
    db $19,$18,$16,$CB,$77,$28,$0A,$11
    db $EE,$FF,$19,$CB,$7C,$28,$13,$18
    db $19,$CB,$7F,$28,$15,$11,$12,$00
    db $19,$7C,$A7,$28,$05,$7D,$FE,$20
    db $30,$08,$7D,$EA,$C0,$C8,$7C,$EA
    db $C1,$C8,$C9,$FE,$90,$30,$05,$11
    db $00,$C0,$18,$3B,$FE,$A0,$30,$2B
    db $FA,$C0,$C8,$6F,$FA,$C1,$C8,$67
    db $11,$10,$C0,$FA,$16,$C0,$BD,$20
    db $06,$FA,$17,$C0,$BC,$28,$20,$11
    db $20,$C0,$FA,$26,$C0,$BD,$20,$06
    db $FA,$27,$C0,$BC,$28,$11,$11,$30
    db $C0,$18,$0C,$FE,$B0,$30,$05,$11
    db $40,$C0,$18,$03,$11,$50,$C0,$AF
    db $21,$00,$00,$19,$77,$C9

Obj_DrawSprite:
    ldh a,[$FFD4]                  ; $17BE  ; draw object sprite
    and $07                        ; $17C0  ; FFD4 & 7
    cp $06                         ; $17C2  ; < 6?
    ret c                          ; $17C4  ; skip frame ret
    call Level_CellCoords          ; $17C5  ; row/col from index
    ld a,[$C909]                   ; $17C8  ; col
    sla a                          ; $17CB  ; col x2
    sla a                          ; $17CD  ; col x4
    sla a                          ; $17CF  ; col x8
    ld b,a                         ; $17D1  ; b = x8
    ld a,[$C908]                   ; $17D2  ; row
    sla a                          ; $17D5  ; row x2
    sla a                          ; $17D7  ; row x4
    sla a                          ; $17D9  ; row x8
    ld c,a                         ; $17DB  ; c = y8
    ld hl,$17E2                    ; $17DC  ; sprite cmd table
    jp Oam_PutFrame                ; $17DF  ; execute sprite draws
    db $08,$08,$FF,$00,$80,$F7,$01,$83
    db $98,$E5,$DE,$EF,$DE,$E5,$F7,$01
    db $8C,$98,$E6,$DE,$E7,$F7,$01,$E2
    db $98,$EC,$DC,$E8,$EB,$DE,$F7,$01
    db $22,$99,$E1,$E2,$EC,$DC,$E8,$EB
    db $DE,$F7,$00,$F7,$01,$85,$99,$E9
    db $DA,$EC,$EC,$FC,$FC,$F0,$E8,$EB
    db $DD,$F7,$00,$F7,$01,$85,$99,$F7
    db $02,$0A,$FC,$F7,$01,$C7,$99,$F7
    db $02,$07,$FC,$F7,$00,$F7,$01,$C7
    db $98,$DE,$DD,$E2,$ED,$F7,$01,$47
    db $99,$E0,$DA,$E6,$DE,$F7,$00,$F7
    db $01,$E6,$98,$E5,$DE,$EF,$DE,$E5
    db $F7,$00,$F7,$01,$43,$98,$E0,$DA
    db $E6,$DE,$FC,$DA,$E5,$E5,$FC,$DC
    db $E5,$DE,$DA,$EB,$F7,$01,$85,$98
    db $E9,$DA,$EC,$EC,$FC,$FC,$F0,$E8
    db $EB,$DD,$F7,$00,$F7,$01,$43,$98
    db $E5,$DE,$EF,$DE,$E5,$FC,$FC,$FC
    db $FC,$DC,$E5,$DE,$DA,$EB,$F7,$01
    db $E0,$99,$B4,$B3,$B4,$B3,$B4,$B3
    db $B4,$B3,$B4,$B5,$B8,$B7,$B3,$B4
    db $B3,$B4,$B3,$B4,$B3,$B4,$F7,$01
    db $00,$9A,$B3,$B4,$B3,$B4,$B3,$B4
    db $B3,$B4,$B3,$B5,$B8,$B6,$B4,$B3
    db $B4,$B3,$B4,$B3,$B4,$B3,$F7,$01
    db $29,$9A,$B5,$B8,$B9,$F7,$00,$F7
    db $01,$85,$98,$E0,$DA,$E6,$DE,$FC
    db $FC,$E8,$EF,$DE,$EB,$F7,$01,$E2
    db $98,$EC,$DC,$E8,$EB,$DE,$F7,$01
    db $22,$99,$E1,$E2,$EC,$DC,$E8,$EB
    db $DE,$F7,$00,$F7,$01,$46,$98,$E0
    db $DA,$E6,$DE,$FC,$DE,$E7,$DD,$F7
    db $01,$83,$98,$EC,$DC,$E8,$EB,$DE
    db $D1,$F7,$01,$C3,$98,$EC,$DC,$E8
    db $EB,$DE,$D2,$F7,$00,$F7,$20,$00
    db $98,$57,$FB,$7B,$57,$FB,$7B,$57
    db $FB,$7B,$57,$FB,$7B,$57,$FB,$7B
    db $57,$FB,$7B,$57,$FB,$7B,$57,$FB
    db $7B,$57,$FB,$F7,$20,$01,$98,$E7
    db $C3,$F3,$E7,$C3,$F3,$E7,$C3,$F3
    db $E7,$C3,$F3,$E7,$C3,$F3,$E7,$C3
    db $F3,$E7,$C3,$F3,$E7,$C3,$F3,$E7
    db $C3,$F7,$20,$1D,$98,$E1,$9F,$ED
    db $E1,$9F,$ED,$E1,$9F,$ED,$E1,$9F
    db $ED,$E1,$9F,$ED,$E1,$9F,$ED,$E1
    db $9F,$ED,$E1,$9F,$ED,$E1,$9F,$F7
    db $20,$1E,$98,$57,$FB,$7B,$57,$FB
    db $7B,$57,$FB,$7B,$57,$FB,$7B,$57
    db $FB,$7B,$57,$FB,$7B,$57,$FB,$7B
    db $57,$FB,$7B,$57,$FB,$F7,$01,$02
    db $9B,$E1,$57,$E7,$E1,$57,$E7,$E1
    db $57,$E7,$E1,$57,$E7,$E1,$57,$E7
    db $E1,$57,$E7,$E1,$57,$E7,$E1,$57
    db $E7,$E1,$57,$E7,$F7,$01,$22,$9B
    db $9F,$FB,$C3,$9F,$FB,$C3,$9F,$FB
    db $C3,$9F,$FB,$C3,$9F,$FB,$C3,$9F
    db $FB,$C3,$9F,$FB,$C3,$9F,$FB,$C3
    db $9F,$FB,$C3,$F7,$00,$F7,$01,$00
    db $9C,$F7,$02,$20,$FC,$F7,$20,$20
    db $9C,$F7,$02,$10,$C1,$F7,$20,$33
    db $9C,$F7,$02,$10,$C1,$F7,$01,$20
    db $9E,$F7,$02,$14,$C1,$F7,$00,$F7
    db $01,$00,$9C,$FC,$6C,$5C,$68,$6B
    db $5E,$FC,$FC,$FC,$66,$5E,$67,$FC
    db $FC,$65,$5E,$6F,$5E,$65,$F7,$02
    db $21,$FC,$F7,$00,$F7,$01,$01,$9C
    db $6C,$5C,$68,$6B,$5E,$51,$F7,$00
    db $F7,$01,$01,$9C,$F7,$02,$06,$FC
    db $F7,$00,$F7,$01,$0D,$9C,$6C,$5C
    db $68,$6B,$5E,$52,$F7,$00,$F7,$01
    db $0D,$9C,$F7,$02,$06,$FC,$F7,$00
    db $F7,$01,$00,$9C,$F7,$02,$08,$FC
    db $6D,$62,$66,$5E,$F7,$02,$28,$FC
    db $F7,$00,$F7,$01,$21,$98,$50,$51
    db $52,$53,$54,$55,$56,$57,$F7,$01
    db $41,$98,$58,$58,$59,$5A,$5B,$5C
    db $97,$9F,$F7,$01,$61,$98,$5D,$5E
    db $FC,$FC,$5D,$5E,$FC,$5D,$6D,$6E
    db $F7,$01,$81,$98,$5F,$60,$61,$62
    db $63,$64,$65,$5F,$6F,$70,$71,$72
    db $73,$74,$75,$76,$77,$78,$F7,$01
    db $A1,$98,$66,$67,$68,$69,$6A,$6B
    db $6C,$79,$7A,$7B,$7C,$7D,$7E,$7F
    db $80,$81,$82,$83,$84,$F7,$01,$E8
    db $98,$E0,$DA,$E6,$DE,$F7,$01,$28
    db $99,$DE,$DD,$E2,$ED,$F7,$01,$69
    db $99,$EF,$EC,$F7,$01,$A2,$99,$85
    db $86,$87,$88,$89,$8A,$8B,$FC,$8C
    db $8D,$8E,$8F,$AF,$B0,$B1,$B2,$F7
    db $01,$C4,$99,$F4,$FC,$90,$91,$92
    db $FC,$93,$94,$95,$96,$F7,$01,$E4
    db $99,$F4,$FC,$90,$91,$98,$FC,$99
    db $9A,$9B,$9C,$9D,$9E,$F7,$01,$04
    db $9A,$A0,$A1,$FC,$A2,$A3,$A4,$A5
    db $A6,$A7,$A8,$A9,$AA,$F7,$01,$24
    db $9A,$AB,$AD,$BA,$C5,$C6,$FC,$FA
    db $0F,$C7,$F7,$F7,$F8,$F9,$AC,$F7
    db $00,$F7,$01,$4B,$98,$2A,$10,$F7
    db $01,$69,$98,$11,$12,$13,$14,$15
    db $16,$F7,$01,$88,$98,$17,$18,$19
    db $3E,$3E,$1A,$1B,$1C,$F7,$01,$A1
    db $98,$1D,$1E,$FC,$FC,$FC,$FC,$FC
    db $1F,$20,$21,$22,$23,$24,$25,$26
    db $F7,$01,$C0,$98,$27,$28,$29,$34
    db $2B,$32,$34,$2B,$2C,$3E,$2D,$2E
    db $2F,$30,$3E,$31,$32,$34,$2B,$34
    db $F7,$01,$E0,$98,$35,$36,$37,$38
    db $3E,$3E,$3E,$3E,$3E,$3E,$3A,$3B
    db $3C,$4C,$3E,$42,$3E,$3F,$40,$41
    db $F7,$01,$00,$99,$3E,$42,$3E,$3E
    db $3E,$3E,$3E,$3E,$3E,$3E,$43,$3E
    db $44,$3E,$3E,$3E,$45,$46,$47,$4F
    db $F7,$01,$20,$99,$3E,$3E,$3E,$3E
    db $3E,$3E,$3E,$4C,$3E,$3E,$33,$4B
    db $39,$3E,$3E,$3E,$3E,$3E,$3E,$3E
    db $F7,$01,$40,$99,$3E,$48,$3E,$3E
    db $4C,$3E,$48,$3E,$3E,$4C,$3E,$3D
    db $3E,$3E,$3E,$3E,$48,$3E,$3E,$48
    db $F7,$01,$60,$99,$48,$49,$4A,$4C
    db $4A,$3E,$49,$4A,$48,$4A,$48,$4A
    db $3E,$4A,$48,$4C,$49,$4A,$48,$49
    db $F7,$01,$80,$99,$4E,$FC,$FC,$4D
    db $FC,$4E,$4D,$FC,$4D,$FC,$4D,$FC
    db $4E,$FC,$4D,$4E,$4D,$FC,$4D,$F7
    db $00

Player_Update:
    ldh a,[$FF96]                  ; $1BCB  ; player update dispatcher
    and a                          ; $1BCD  ; FF96 scroll?
    jr nz,loc_1BDC                 ; $1BCE  ; busy skip
    ldh a,[$FFAE]                  ; $1BD0  ; FFAE music
    bit 7,a                        ; $1BD2  ; bit7?
    jr nz,loc_1BDC                 ; $1BD4  ; skip
    call SoundEngine_PlayEffect    ; $1BD6  ; advance sfx
    call loc_3E34                  ; $1BD9  ; sound driver step

loc_1BDC:
    ld hl,$C00E                    ; $1BDC  ; dig/rope timer
    ld a,[hl]                      ; $1BDF  ; C00E timer
    and a                          ; $1BE0  ; running?
    jr z,loc_1BED                  ; $1BE1  ; skip
    ldh a,[$FFD4]                  ; $1BE3  ; FFD4
    and $03                        ; $1BE5  ; & 3
    jr nz,loc_1BED                 ; $1BE7  ; phase skip
    dec [hl]                       ; $1BE9  ; timer--
    call z,Player_HoleTimer        ; $1BEA  ; expire: reset hole

loc_1BED:
    ldh a,[$FF90]                  ; $1BED  ; FF90
    bit 3,a                        ; $1BEF  ; bit3?
    jr z,loc_1BF7                  ; $1BF1  ; menu
    ldh a,[$FFAD]                  ; $1BF3  ; FFAD timer
    and a                          ; $1BF5  ; running?
    ret nz                         ; $1BF6  ; busy ret

loc_1BF7:
    ld de,$C000                    ; $1BF7  ; de = player obj
    ld hl,$C000                    ; $1BFA  ; hl = player obj
    call State_DispatchGate        ; $1BFD  ; pre-move setup
    rst $10                        ; $1C00  ; rst $10: dispatch by state
    dw $1C0F,$1C14,$1C8D,$1CB5
    dw $1C8D,$1CC8,$1D10

Player_State0:
    xor a                          ; $1C0F  ; state 0: idle
    ld [$C001],a                   ; $1C10  ; C001 = 0
    ret                            ; $1C13  ; ret

Player_StateStart:
    call Slot_Place                ; $1C14  ; state 1: spawn player
    ld a,$20                       ; $1C17  ; sprite len $20
    ld [$C926],a                   ; $1C19  ; C926 = $20
    ld [$C92A],a                   ; $1C1C  ; C92A = $20
    ld a,$01                       ; $1C1F  ; frame = 1
    ld [$C927],a                   ; $1C21  ; C927 = 1
    ld [$C92B],a                   ; $1C24  ; C92B = 1
    ld a,$6B                       ; $1C27  ; ptr low $6B
    ld [$C928],a                   ; $1C29  ; C928 = $6B
    ld [$C92C],a                   ; $1C2C  ; C92C = $6B
    ld a,$C9                       ; $1C2F  ; ptr high $C9
    ld [$C929],a                   ; $1C31  ; C929 = $C9
    ld [$C92D],a                   ; $1C34  ; C92D = $C9
    xor a                          ; $1C37  ; a = 0
    ld [$C008],a                   ; $1C38  ; C008 = 0
    ld [$C00D],a                   ; $1C3B  ; C00D = 0
    ld [$C00E],a                   ; $1C3E  ; C00E = 0
    call Player_HoleTimer          ; $1C41  ; reset hole timer
    ldh a,[$FF96]                  ; $1C44  ; FF96 scroll?
    and a                          ; $1C46  ; busy ret
    ret nz                         ; $1C47
    ld hl,$FF90                    ; $1C48  ; FF90
    bit 3,[hl]                     ; $1C4B  ; bit3?
    jr z,loc_1C51                  ; $1C4D  ; skip
    set 4,[hl]                     ; $1C4F  ; set timer flag bit4

loc_1C51:
    ldh a,[$FFC2]                  ; $1C51  ; FFC2 input
    and a                          ; $1C53  ; none ret
    ret z                          ; $1C54
    ld bc,$C010                    ; $1C55  ; guard A base
    call Player_ResetGuard         ; $1C58  ; reset guard A
    ld bc,$C020                    ; $1C5B  ; guard B
    call Player_ResetGuard         ; $1C5E  ; reset B
    ld bc,$C030                    ; $1C61  ; guard C
    call Player_ResetGuard         ; $1C64  ; reset C
    ld a,$02                       ; $1C67  ; state 2
    ld [$C000],a                   ; $1C69  ; C000 = 2
    ret                            ; $1C6C  ; ret

Player_ResetGuard:
    ld a,[bc]                      ; $1C6D  ; reset one guard object
    and a                          ; $1C6E  ; active?
    ret z                          ; $1C6F  ; none ret
    ld a,$02                       ; $1C70  ; state 2
    ld [bc],a                      ; $1C72  ; [bc] = 2
    xor a                          ; $1C73  ; a = 0
    ld hl,$0002                    ; $1C74  ; field +2
    add hl,bc                      ; $1C77  ; offset
    ld [hl],a                      ; $1C78  ; clear
    ld hl,$0004                    ; $1C79  ; field +4
    add hl,bc                      ; $1C7C  ; offset
    ld [hl],a                      ; $1C7D  ; clear
    ld hl,$0008                    ; $1C7E  ; field +8
    add hl,bc                      ; $1C81  ; offset
    ld [hl],a                      ; $1C82  ; clear
    ret                            ; $1C83  ; ret

Player_HoleTimer:
    ld a,$F0                       ; $1C84  ; a = $F0

Player_HoleSet:
    ld [$C00A],a                   ; $1C86  ; hole timers = a
    ld [$C00B],a                   ; $1C89  ; C00B = a
    ret                            ; $1C8C  ; ret

Player_StateMove:
    call Player_ReadInput          ; $1C8D  ; state 2: move player
    call Player_Move               ; $1C90  ; input/AI prep
    ld a,[$C001]                   ; $1C93  ; C001 state
    sub $1D                        ; $1C96  ; - $1D
    cp $08                         ; $1C98  ; < 8?
    ld a,$00                       ; $1C9A  ; clr flag
    jr nc,loc_1CA8                 ; $1C9C  ; skip
    ld a,[$C00D]                   ; $1C9E  ; C00D anim
    cp $88                         ; $1CA1  ; >= $88?
    jr nc,loc_1CA8                 ; $1CA3  ; skip
    or $80                         ; $1CA5  ; flag bit7
    inc a                          ; $1CA7  ; +1

loc_1CA8:
    ld [$C00D],a                   ; $1CA8  ; C00D = anim
    call Player_Collect            ; $1CAB  ; apply physics
    call Game_ClearCheck           ; $1CAE  ; collision/guard
    call Player_RopeClear          ; $1CB1  ; hole/dig update
    ret                            ; $1CB4  ; ret

Player_StateDisabled:
    call Move_SteerY               ; $1CB5  ; state 3: falling/disable
    ld a,$03                       ; $1CB8  ; C001 = 3
    ld [$C001],a                   ; $1CBA  ; store
    ld hl,$C009                    ; $1CBD  ; C009 timer
    dec [hl]                       ; $1CC0  ; count--
    ret nz                         ; $1CC1  ; ongoing ret
    ld a,$02                       ; $1CC2  ; state 2
    ld [$C000],a                   ; $1CC4  ; C000 = 2
    ret                            ; $1CC7  ; ret

Player_StateBonus:
    ld a,[$C009]                   ; $1CC8  ; state 4: bonus text
    inc a                          ; $1CCB  ; count++
    ld [$C009],a                   ; $1CCC  ; C009++
    ld b,$29                       ; $1CCF  ; tile $29
    cp $0A                         ; $1CD1  ; < $0A?
    jr c,loc_1CE9                  ; $1CD3  ; use
    inc b                          ; $1CD5  ; tile $2A
    cp $14                         ; $1CD6  ; < $14?
    jr c,loc_1CE9                  ; $1CD8  ; use
    inc b                          ; $1CDA  ; tile $2B
    cp $1E                         ; $1CDB  ; < $1E?
    jr c,loc_1CE9                  ; $1CDD  ; use
    inc b                          ; $1CDF  ; tile $2C
    cp $28                         ; $1CE0  ; < $28?
    jr c,loc_1CE9                  ; $1CE2  ; use
    inc b                          ; $1CE4  ; tile $2D
    cp $32                         ; $1CE5  ; < $32?
    jr nc,Game_LevelClear          ; $1CE7  ; past -> next state

loc_1CE9:
    ld a,b                         ; $1CE9  ; C001 = tile
    ld [$C001],a                   ; $1CEA
    xor a                          ; $1CED  ; a = 0
    ld [$C008],a                   ; $1CEE  ; C008 anim flags = 0
    ret                            ; $1CF1  ; ret

Game_LevelClear:
    xor a                          ; $1CF2  ; level cleared: next stage
    ldh [$FF9C],a                  ; $1CF3  ; FF9C mode = 0
    call Scroll_Start              ; $1CF5  ; start intro scroll
    ldh a,[$FF8A]                  ; $1CF8  ; current mode
    cp $0C                         ; $1CFA  ; == $0C?
    jr nz,loc_1D0A                 ; $1CFC  ; next stage
    ldh a,[$FF90]                  ; $1CFE  ; FF90 bit0
    bit 0,a                        ; $1D00  ; in game?
    ld a,$05                       ; $1D02  ; mode $05
    jr z,loc_1D08                  ; $1D04  ; not in game
    ld a,$0A                       ; $1D06  ; mode $0A

loc_1D08:
    ldh [$FF8A],a                  ; $1D08  ; FF8A = new mode

loc_1D0A:
    ld a,$06                       ; $1D0A  ; player state 6
    ld [$C000],a                   ; $1D0C  ; C000 = 6
    ret                            ; $1D0F  ; ret

Player_State6:
    ret                            ; $1D10  ; state 6: no-op

Player_Animate:
    ld a,[$C00A]                   ; $1D11  ; pick player dig/fall anim
    cp $F0                         ; $1D14  ; hole timer active?
    jp z,Player_DrawFrame          ; $1D16  ; inactive: skip
    ld a,[$C001]                   ; $1D19  ; move state
    sub $05                        ; $1D1C  ; state - 5
    jr c,Player_DrawFrame          ; $1D1E  ; < 5: skip
    cp $20                         ; $1D20  ; >= $20: skip
    jr nc,Player_DrawFrame         ; $1D22  ; out of range
    srl a                          ; $1D24  ; state / 2
    bit 3,a                        ; $1D26  ; bit3?
    jr z,loc_1D36                  ; $1D28  ; no
    ld c,a                         ; $1D2A  ; c
    and $0C                        ; $1D2B  ; mask
    ld d,a                         ; $1D2D  ; d
    ld a,c                         ; $1D2E  ; a = c
    srl a                          ; $1D2F  ; shift
    jr c,Player_DrawFrame          ; $1D31  ; skip
    and $01                        ; $1D33  ; & 1
    or d                           ; $1D35  ; combine

loc_1D36:
    and $0D                        ; $1D36  ; frame index
    ld b,a                         ; $1D38  ; b = frame
    ld a,[$C008]                   ; $1D39  ; C008 flags
    bit 4,a                        ; $1D3C  ; bit4 (facing)?
    jr z,loc_1D42                  ; $1D3E  ; no
    inc b                          ; $1D40  ; frame += 2
    inc b                          ; $1D41  ; frame += 2

loc_1D42:
    ld a,b                         ; $1D42  ; frame
    cp $04                         ; $1D43  ; >= 4?
    jr nc,loc_1D4D                 ; $1D45  ; has input
    ldh a,[$FFC1]                  ; $1D47  ; FFC1 input
    and $30                        ; $1D49  ; & $30
    jr z,Player_DrawFrame          ; $1D4B  ; no input skip

loc_1D4D:
    ld a,b                         ; $1D4D  ; frame table
    ld hl,$1D5C                    ; $1D4E  ; table base
    call Table16_Get               ; $1D51  ; lookup frame ptr
    ld de,$C000                    ; $1D54  ; player obj
    call Slot_Show                 ; $1D57  ; draw sprite frame
    jr Player_DrawFrame            ; $1D5A  ; done
    db $80,$1D,$7C,$1D,$85,$1D,$81,$1D
    db $8A,$1D,$86,$1D,$8F,$1D,$8B,$1D
    db $86,$1D,$8B,$1D,$86,$1D,$8B,$1D
    db $86,$1D,$8B,$1D,$86,$1D,$8B,$1D
    db $08,$F4,$7A,$40,$80,$08,$04,$7A
    db $60,$80,$FB,$04,$7A,$20,$80,$FB
    db $F4,$7A,$00,$80

Player_DrawFrame:
    ld a,[$C000]                   ; $1D90  ; draw player sprite by state
    cp $01                         ; $1D93  ; player state
    jr nz,loc_1D9C                 ; $1D95  ; != 1
    ldh a,[$FFD4]                  ; $1D97  ; FFD4
    bit 3,a                        ; $1D99  ; bit3?
    ret z                          ; $1D9B  ; wait frame ret

loc_1D9C:
    ld a,[$C001]                   ; $1D9C  ; move state
    and a                          ; $1D9F  ; zero?
    ret z                          ; $1DA0  ; skip ret
    ld de,$C000                    ; $1DA1  ; de = player obj
    ld hl,$1FA1                    ; $1DA4  ; sprite shape table

loc_1DA7:
    ld b,a                         ; $1DA7  ; b = state
    ldh a,[$FF8A]                  ; $1DA8  ; mode FF8A
    cp $06                         ; $1DAA  ; == $06?
    jr nz,loc_1DBF                 ; $1DAC  ; else
    push hl                        ; $1DAE  ; save table
    ld hl,$0008                    ; $1DAF  ; obj+8
    add hl,de                      ; $1DB2  ; field
    ld a,[hl]                      ; $1DB3  ; flags
    pop hl                         ; $1DB4  ; restore
    bit 4,a                        ; $1DB5  ; bit4?
    jr z,loc_1DD0                  ; $1DB7  ; no
    ld bc,$0005                    ; $1DB9  ; offset +5
    add hl,bc                      ; $1DBC  ; next shape
    jr loc_1DD0                    ; $1DBD  ; draw

loc_1DBF:
    ld hl,$0008                    ; $1DBF  ; obj+8 flags
    add hl,de                      ; $1DC2  ; field
    ld a,[hl]                      ; $1DC3  ; bit4?
    bit 4,a                        ; $1DC4
    jr z,loc_1DC9                  ; $1DC6  ; no
    inc b                          ; $1DC8  ; state++

loc_1DC9:
    ld a,b                         ; $1DC9  ; state
    ld hl,$1DD3                    ; $1DCA  ; frame table
    call Table16_Get               ; $1DCD  ; lookup frame ptr

loc_1DD0:
    jp Slot_Show                   ; $1DD0  ; draw sprite via copier
    db $37,$1E,$2F,$1E,$38,$1E,$41,$1E
    db $4E,$1E,$5B,$1E,$64,$1E,$6D,$1E
    db $76,$1E,$7F,$1E,$88,$1E,$6D,$1E
    db $76,$1E,$91,$1E,$9A,$1E,$A3,$1E
    db $AC,$1E,$B5,$1E,$BE,$1E,$A3,$1E
    db $AC,$1E,$C7,$1E,$C7,$1E,$D8,$1E
    db $D8,$1E,$E9,$1E,$E9,$1E,$D8,$1E
    db $D8,$1E,$FA,$1E,$07,$1F,$14,$1F
    db $21,$1F,$2E,$1F,$3B,$1F,$14,$1F
    db $21,$1F,$48,$1F,$4D,$1F,$52,$1F
    db $57,$1F,$5C,$1F,$69,$1F,$76,$1F
    db $87,$1F,$94,$1F,$FC,$FC,$00,$00
    db $04,$FC,$10,$00,$80,$FC,$FC,$00
    db $20,$04,$FC,$10,$20,$80,$FC,$FC
    db $00,$00,$04,$FC,$06,$00,$04,$F4
    db $05,$00,$80,$FC,$FC,$00,$20,$04
    db $FC,$06,$20,$04,$04,$05,$20,$80
    db $00,$F7,$02,$20,$00,$FF,$01,$20
    db $80,$00,$F9,$01,$00,$00,$01,$02
    db $00,$80,$00,$F6,$02,$20,$00,$FE
    db $03,$20,$80,$00,$FA,$03,$00,$00
    db $02,$02,$00,$80,$00,$F5,$02,$20
    db $00,$FD,$04,$20,$80,$00,$FB,$04
    db $00,$00,$03,$02,$00,$80,$FB,$FC
    db $00,$00,$03,$FC,$11,$00,$80,$FB
    db $FC,$00,$20,$03,$FC,$11,$20,$80
    db $FC,$FC,$00,$00,$04,$FC,$12,$00
    db $80,$FC,$FC,$00,$20,$04,$FC,$12
    db $20,$80,$FB,$FC,$00,$00,$03,$FC
    db $13,$00,$80,$FB,$FC,$00,$20,$03
    db $FC,$13,$20,$80,$FC,$F8,$0A,$00
    db $04,$F8,$1A,$00,$FC,$00,$0B,$00
    db $04,$00,$1B,$00,$80,$FC,$F8,$0A
    db $00,$04,$F8,$1C,$00,$FC,$00,$0B
    db $00,$04,$00,$1C,$20,$80,$FC,$F8
    db $0A,$00,$04,$F8,$1B,$20,$FC,$00
    db $0B,$00,$04,$00,$1A,$20,$80,$FC
    db $FC,$00,$00,$04,$F8,$14,$00,$04
    db $00,$15,$00,$80,$FC,$FC,$00,$20
    db $04,$F8,$15,$20,$04,$00,$14,$20
    db $80,$FC,$FC,$00,$00,$04,$F8,$16
    db $00,$04,$00,$17,$00,$80,$FC,$FC
    db $00,$20,$04,$F8,$17,$20,$04,$00
    db $16,$20,$80,$FC,$FC,$00,$00,$04
    db $F8,$18,$00,$04,$00,$19,$00,$80
    db $FC,$FC,$00,$20,$04,$F8,$19,$20
    db $04,$00,$18,$20,$80,$02,$FC,$06
    db $00,$80,$02,$FC,$07,$00,$80,$02
    db $FC,$08,$00,$80,$02,$FC,$09,$00
    db $80,$FC,$FC,$07,$00,$04,$F8,$0F
    db $00,$04,$00,$0F,$20,$80,$FC,$FC
    db $08,$00,$04,$F8,$1D,$00,$04,$00
    db $1D,$20,$80,$FC,$F8,$09,$00,$04
    db $F8,$1E,$00,$FC,$00,$0C,$00,$04
    db $00,$1E,$20,$80,$FC,$FC,$0D,$00
    db $04,$F8,$1F,$00,$04,$00,$1F,$20
    db $80,$FC,$FC,$0E,$00,$04,$F8,$25
    db $00,$04,$00,$25,$20,$80,$08,$FA
    db $CA,$00,$80,$08,$FA,$CA,$20,$80

Player_ReadInput:
    ld bc,$0C00                    ; $1FAB  ; read movement input
    call Cell_Probe                ; $1FAE  ; cell below (bc=0C00)
    ld [$C92E],a                   ; $1FB1  ; C92E = result
    ld bc,$0600                    ; $1FB4  ; cell ahead (bc=0600)
    call Cell_Probe                ; $1FB7  ; query cell
    ld [$C00C],a                   ; $1FBA  ; C00C = result
    ret                            ; $1FBD  ; ret

Player_Move:
    ld a,b                         ; $1FBE  ; player movement logic
    cp $06                         ; $1FBF  ; state
    jr nz,loc_1FC9                 ; $1FC1  ; != 6
    ldh a,[$FFB8]                  ; $1FC3  ; FFB8 flags
    bit 7,a                        ; $1FC5  ; bit7?
    jr nz,loc_1FCC                 ; $1FC7  ; active

loc_1FC9:
    call Move_EdgeDrop             ; $1FC9  ; override move

loc_1FCC:
    call Player_ClimbCheck         ; $1FCC  ; check climb/rope
    ldh a,[$FFC1]                  ; $1FCF  ; input FFC1
    call Move_Bit7                 ; $1FD1  ; horizontal move
    ldh a,[$FFC1]                  ; $1FD4  ; input FFC1
    call Move_Bit5                 ; $1FD6  ; vertical move

loc_1FD9:
    ld hl,$000C                    ; $1FD9  ; set move state
    add hl,de                      ; $1FDC  ; obj+$0C
    ld a,[hl]                      ; $1FDD  ; cell type
    cp $02                         ; $1FDE  ; == 2?
    jr nz,loc_1FF2                 ; $1FE0  ; else
    ld bc,$0C00                    ; $1FE2  ; cell below
    call Cell_Probe                ; $1FE5  ; query
    cp $02                         ; $1FE8  ; == 2?
    ld b,$17                       ; $1FEA  ; state $17
    jr z,loc_1FF0                  ; $1FEC  ; yes
    ld b,$01                       ; $1FEE  ; state $01

loc_1FF0:
    jr loc_1FFA                    ; $1FF0  ; set state

loc_1FF2:
    ld b,$01                       ; $1FF2  ; state $01
    cp $03                         ; $1FF4  ; == 3?
    jr nz,loc_1FFA                 ; $1FF6  ; done
    ld b,$07                       ; $1FF8  ; state $07

loc_1FFA:
    ld a,b                         ; $1FFA  ; state
    ld hl,$0001                    ; $1FFB  ; obj+1
    add hl,de                      ; $1FFE  ; field
    ld [hl],a                      ; $1FFF  ; store state
    ret                            ; $2000  ; ret

Player_Collect:
    ld a,[$C00D]                   ; $2001  ; collect gold at cell
    and a                          ; $2004  ; anim flag C00D
    jr z,loc_200A                  ; $2005  ; none
    cp $88                         ; $2007  ; < $88?
    ret c                          ; $2009  ; busy ret

loc_200A:
    ld bc,$0600                    ; $200A  ; cell avg query
    call Cell_Probe                ; $200D  ; compute cell
    cp $04                         ; $2010  ; == 4? (loot)
    ret nz                         ; $2012  ; no
    ld a,b                         ; $2013  ; col
    sub $05                        ; $2014  ; -5
    cp $04                         ; $2016  ; >= 4?
    ret nc                         ; $2018  ; off-center
    ld a,c                         ; $2019  ; row
    sub $05                        ; $201A  ; -5
    cp $04                         ; $201C  ; >= 4?
    ret nc                         ; $201E  ; off-center
    ld a,$05                       ; $201F  ; tile 5
    call Level_QueuePush           ; $2021  ; queue cell update
    ld hl,$FFB4                    ; $2024  ; FFB4 total
    dec [hl]                       ; $2027  ; total--
    ldh a,[$FF90]                  ; $2028  ; FF90
    bit 3,a                        ; $202A  ; bit3 in game?
    jr nz,loc_2039                 ; $202C  ; in game: score
    ld bc,$0150                    ; $202E  ; speed +1
    call loc_335E                  ; $2031  ; set player speed
    ld a,$09                       ; $2034  ; sfx $09
    jp SoundEngine_PlayEffect      ; $2036  ; play collect sfx

loc_2039:
    ldh a,[$FF9C]                  ; $2039  ; adjust speed by tier
    bit 6,a                        ; $203B  ; FF9C bit6
    ldh a,[$FFB6]                  ; $203D  ; tier FFB6
    jr z,loc_2043                  ; $203F  ; not bit6
    ldh a,[$FFB7]                  ; $2041  ; tier FFB7

loc_2043:
    and $03                        ; $2043  ; & 3
    ldh [$FFD9],a                  ; $2045  ; FFD9 = tier
    rst $20                        ; $2047  ; rst $20: speed/score table
    db $04,$37,$4B,$50,$55,$CD,$AB,$3D
    db $38,$0C,$01,$50,$01,$CD,$5E,$33
    db $06,$09,$3E,$10,$18,$42,$F0,$D9
    db $E7,$04,$14,$0F,$0A,$05,$CD,$BC
    db $3D,$38,$0C,$01,$00,$03,$CD,$5E
    db $33,$06,$2C,$3E,$20,$18,$29,$F0
    db $D9,$E7,$04,$12,$08,$08,$08,$CD
    db $BC,$3D,$38,$06,$06,$2B,$3E,$30
    db $18,$16,$F0,$9C,$CB,$77,$21,$B6
    db $FF,$28,$03,$21,$B7,$FF,$CB,$7E
    db $20,$B8,$CB,$FE,$06,$19,$3E,$40
    db $CD,$3E,$0A,$78,$C3,$4B,$3E

Game_ClearCheck:
    ldh a,[$FFB4]                  ; $20A7  ; check level clear state
    and a                          ; $20A9  ; FFB4 total
    jr z,loc_20EF                  ; $20AA  ; zero: skip
    cp $FF                         ; $20AC  ; == FF (done)?
    ret nz                         ; $20AE  ; not done ret
    ld a,[$C005]                   ; $20AF  ; player Y
    cp $02                         ; $20B2  ; >= 2?
    ret nc                         ; $20B4  ; wait ret
    ld hl,$FF90                    ; $20B5  ; FF90
    bit 5,[hl]                     ; $20B8  ; bit5 rope?
    jp nz,Scroll_Start             ; $20BA  ; rope: scroll
    bit 3,[hl]                     ; $20BD  ; bit3 in game?
    jr z,loc_20E0                  ; $20BF  ; menu path
    bit 2,[hl]                     ; $20C1  ; bit2 alt?
    jr z,loc_20CE                  ; $20C3  ; else
    bit 6,[hl]                     ; $20C5  ; bit6 done?
    ret nz                         ; $20C7  ; already ret
    set 6,[hl]                     ; $20C8  ; set bit6
    ld a,$60                       ; $20CA  ; bonus $60
    jr loc_20D5                    ; $20CC  ; continue

loc_20CE:
    bit 7,[hl]                     ; $20CE  ; bit7 done?
    ret nz                         ; $20D0  ; already ret
    set 7,[hl]                     ; $20D1  ; set bit7
    ld a,$E0                       ; $20D3  ; bonus $E0

loc_20D5:
    push af                        ; $20D5  ; save bonus
    ld bc,$3000                    ; $20D6  ; speed 3000
    call loc_335E                  ; $20D9  ; set speed
    pop af                         ; $20DC  ; restore
    jp FIFO_Push                   ; $20DD  ; push bonus sfx

loc_20E0:
    ldh a,[$FF8A]                  ; $20E0  ; advance to next level
    ldh [$FFB4],a                  ; $20E2  ; FFB4 = mode
    ldh a,[$FF9D]                  ; $20E4  ; level no
    cp $31                         ; $20E6  ; == $31?
    ld a,$02                       ; $20E8  ; mode 2
    jr nz,loc_20EE                 ; $20EA  ; else
    ld a,$01                       ; $20EC  ; mode 1

loc_20EE:
    rst $08                        ; $20EE  ; jump mode (rst $08)

loc_20EF:
    ldh a,[$FF90]                  ; $20EF  ; FF90 rope?
    bit 5,a                        ; $20F1  ; bit5
    ret nz                         ; $20F3  ; rope ret
    ldh a,[$FF9C]                  ; $20F4  ; FF9C
    bit 7,a                        ; $20F6  ; bit7?
    jr z,Player_GoldScan           ; $20F8  ; not bit7
    bit 6,a                        ; $20FA  ; bit6?
    jr z,loc_210A                  ; $20FC  ; else
    bit 2,a                        ; $20FE  ; bit2?
    ret nz                         ; $2100  ; already ret
    set 2,a                        ; $2101  ; set bit2
    ldh [$FF9C],a                  ; $2103  ; FF9C = a

Game_ClearSfx:
    ld a,$21                       ; $2105  ; clear jingle $21
    jp Sfx_PlayB                   ; $2107  ; play sfx

loc_210A:
    ldh a,[$FF9C]                  ; $210A  ; FF9C
    bit 2,a                        ; $210C  ; bit2?
    ret z                          ; $210E  ; no ret

Player_GoldScan:
    push de                        ; $210F  ; scan level for leftover gold
    ld b,$20                       ; $2110  ; count 32
    ld a,[$C926]                   ; $2112  ; scan ptr low
    ld e,a                         ; $2115  ; e
    ld a,[$C927]                   ; $2116  ; ptr high
    ld d,a                         ; $2119  ; d
    ld a,[$C928]                   ; $211A  ; ptr low
    ld l,a                         ; $211D  ; l
    ld a,[$C929]                   ; $211E  ; ptr high
    ld h,a                         ; $2121  ; h

loc_2122:
    ld a,[hl]                      ; $2122  ; cell
    cp $25                         ; $2123  ; == $25 (gold)?
    jr nz,loc_2130                 ; $2125  ; no
    call ScanSave_C926             ; $2127  ; save scan ptr
    pop de                         ; $212A  ; restore de
    ld a,$02                       ; $212B  ; tile 2
    jp Level_QueuePush             ; $212D  ; queue cell change

loc_2130:
    inc hl                         ; $2130  ; next cell
    dec de                         ; $2131  ; count--
    ld a,d                         ; $2132  ; de low
    or e                           ; $2133  ; or de high
    jr z,loc_213E                  ; $2134  ; done scan
    dec b                          ; $2136  ; loop
    jr nz,loc_2122                 ; $2137  ; scan loop
    call ScanSave_C926             ; $2139  ; save scan ptr
    pop de                         ; $213C  ; restore de
    ret                            ; $213D  ; ret

loc_213E:
    ld a,$FF                       ; $213E  ; all collected
    ldh [$FFB4],a                  ; $2140  ; FFB4 = FF
    call Game_ClearSfx             ; $2142  ; play clear jingle
    pop de                         ; $2145  ; restore de
    ret                            ; $2146  ; ret

ScanSave_C926:
    ld a,e                         ; $2147  ; save gold scan ptr
    ld [$C926],a                   ; $2148  ; C926 = e
    ld a,d                         ; $214B  ; C927 = d
    ld [$C927],a                   ; $214C  ; store
    ld a,l                         ; $214F  ; C928 = l
    ld [$C928],a                   ; $2150  ; store
    ld a,h                         ; $2153  ; C929 = h
    ld [$C929],a                   ; $2154  ; store
    ret                            ; $2157  ; ret

Player_RopeClear:
    ldh a,[$FF90]                  ; $2158  ; rope clears soft tiles
    bit 5,a                        ; $215A  ; FF90 bit5 rope?
    ret z                          ; $215C  ; no ret
    ldh a,[$FFB4]                  ; $215D  ; FFB4
    inc a                          ; $215F  ; inc
    cp $02                         ; $2160  ; < 2?
    ret c                          ; $2162  ; reset ret
    push de                        ; $2163  ; save de
    ld b,$20                       ; $2164  ; count 32
    ld a,[$C92A]                   ; $2166  ; scan ptr low
    ld e,a                         ; $2169  ; e
    ld a,[$C92B]                   ; $216A  ; ptr high
    ld d,a                         ; $216D  ; d
    ld a,[$C92C]                   ; $216E  ; ptr low
    ld l,a                         ; $2171  ; l
    ld a,[$C92D]                   ; $2172  ; ptr high
    ld h,a                         ; $2175  ; h

loc_2176:
    ld a,[hl]                      ; $2176  ; cell
    cp $04                         ; $2177  ; == 4?
    jr nz,loc_2184                 ; $2179  ; no
    call ScanSave_C92A             ; $217B  ; save scan ptr
    pop de                         ; $217E  ; restore de
    ld a,$05                       ; $217F  ; tile 5
    jp Level_QueuePush             ; $2181  ; queue cell change

loc_2184:
    inc hl                         ; $2184  ; next cell
    dec de                         ; $2185  ; count--
    ld a,d                         ; $2186  ; de low
    or e                           ; $2187  ; or high
    jr z,loc_2192                  ; $2188  ; scan done
    dec b                          ; $218A  ; loop
    jr nz,loc_2176                 ; $218B  ; scan loop
    call ScanSave_C92A             ; $218D  ; save scan ptr
    pop de                         ; $2190  ; restore de
    ret                            ; $2191  ; ret

loc_2192:
    xor a                          ; $2192  ; reset FFB4
    ldh [$FFB4],a                  ; $2193  ; FFB4 = 0
    pop de                         ; $2195  ; restore de
    ret                            ; $2196  ; ret

ScanSave_C92A:
    ld a,e                         ; $2197  ; save rope scan ptr
    ld [$C92A],a                   ; $2198  ; C92A = e
    ld a,d                         ; $219B  ; C92B = d
    ld [$C92B],a                   ; $219C  ; store
    ld a,l                         ; $219F  ; C92C = l
    ld [$C92C],a                   ; $21A0  ; store
    ld a,h                         ; $21A3  ; C92D = h
    ld [$C92D],a                   ; $21A4  ; store
    ret                            ; $21A7  ; ret

Player_ClimbCheck:
    ldh a,[$FFC1]                  ; $21A8  ; check climb/rope grab
    bit 0,a                        ; $21AA  ; FFC1 bit0 (up)?
    jr z,loc_21B8                  ; $21AC  ; no
    ldh a,[$FFB8]                  ; $21AE  ; FFB8
    bit 4,a                        ; $21B0  ; bit4 climbing?
    ret nz                         ; $21B2  ; busy ret
    ld bc,$120C                    ; $21B3  ; cell query $120C
    jr loc_21C5                    ; $21B6  ; query

loc_21B8:
    ldh a,[$FFC1]                  ; $21B8  ; FFC1 bit1 (down)?
    bit 1,a                        ; $21BA  ; no ret
    ret z                          ; $21BC  ; down
    ldh a,[$FFB8]                  ; $21BD  ; FFB8
    bit 5,a                        ; $21BF  ; bit5?
    ret nz                         ; $21C1  ; busy ret
    ld bc,$12F4                    ; $21C2  ; cell query $12F4

loc_21C5:
    call Cell_Probe                ; $21C5  ; query cell
    and a                          ; $21C8  ; result
    ret nz                         ; $21C9  ; none ret
    ld a,b                         ; $21CA  ; col
    sub $04                        ; $21CB  ; -4
    cp $05                         ; $21CD  ; >= 5?
    ret nc                         ; $21CF  ; far ret
    ld bc,$FFEE                    ; $21D0  ; hl - $12
    add hl,bc                      ; $21D3  ; cell above
    ld a,[hl]                      ; $21D4  ; value
    and $0F                        ; $21D5  ; low nibble
    cp $05                         ; $21D7  ; < 5?
    ret c                          ; $21D9  ; no rope ret
    cp $08                         ; $21DA  ; >= 8?
    ret nc                         ; $21DC  ; no rope ret
    ldh a,[$FFC1]                  ; $21DD  ; FFC1
    bit 0,a                        ; $21DF  ; bit0?
    ld a,$03                       ; $21E1  ; sfx $03
    jr nz,loc_21E7                 ; $21E3  ; up
    ld a,$10                       ; $21E5  ; sfx $10

loc_21E7:
    call SoundEngine_PlayEffect    ; $21E7  ; play grab sfx
    ld a,$07                       ; $21EA  ; tile 7
    ld bc,$0012                    ; $21EC  ; hl += $12
    add hl,bc                      ; $21EF  ; cell
    call Level_QueuePush           ; $21F0  ; queue cell update
    push de                        ; $21F3  ; save de
    call Slot_ScanAll              ; $21F4  ; stop object
    pop de                         ; $21F7  ; restore de
    ldh a,[$FFC1]                  ; $21F8  ; FFC1
    bit 0,a                        ; $21FA  ; bit0?
    ld a,$10                       ; $21FC  ; anim $10
    jr nz,loc_2202                 ; $21FE  ; up
    ld a,$20                       ; $2200  ; anim $20

loc_2202:
    ld [$C008],a                   ; $2202  ; C008 = anim
    ld a,$14                       ; $2205  ; timer $14
    ld [$C009],a                   ; $2207  ; C009 = timer
    ld a,$03                       ; $220A  ; state 3
    ld [$C000],a                   ; $220C  ; C000 = 3
    pop af                         ; $220F  ; restore af
    ret                            ; $2210  ; ret

Guard_Update:
    ld a,[$C000]                   ; $2211  ; update guard objects
    cp $05                         ; $2214  ; player state
    ret nc                         ; $2216  ; >= 5 skip
    ldh a,[$FF90]                  ; $2217  ; FF90
    bit 3,a                        ; $2219  ; bit3?
    jr z,loc_2221                  ; $221B  ; menu
    ldh a,[$FFAD]                  ; $221D  ; FFAD timer
    and a                          ; $221F  ; active ret
    ret nz                         ; $2220

loc_2221:
    xor a                          ; $2221  ; a = 0
    ldh [$FFB8],a                  ; $2222  ; FFB8 = 0

loc_2224:
    ldh [$FFB2],a                  ; $2224  ; guard index
    swap a                         ; $2226  ; index x16
    ld e,a                         ; $2228  ; e
    ld d,$00                       ; $2229  ; d = 0
    ld hl,$C010                    ; $222B  ; guards base C010
    add hl,de                      ; $222E  ; guard slot
    push hl                        ; $222F  ; save
    pop de                         ; $2230  ; de = guard
    call Guard_State               ; $2231  ; dispatch guard state
    ldh a,[$FFB2]                  ; $2234  ; index
    inc a                          ; $2236  ; index++
    cp $03                         ; $2237  ; < 3?
    jr c,loc_2224                  ; $2239  ; loop guards
    ret                            ; $223B  ; ret

Guard_State:
    ld hl,$0000                    ; $223C  ; dispatch guard by state
    add hl,de                      ; $223F  ; obj = de
    call State_DispatchGate        ; $2240  ; pre-state setup
    rst $10                        ; $2243  ; rst $10: guard state table
    dw $2254,$225B,$227B,$228A
    dw $2299,$22E6,$2365,$2390

Guard_State0:
    xor a                          ; $2254  ; state 0: idle
    ld hl,$0001                    ; $2255  ; obj+1
    add hl,de                      ; $2258  ; field
    ld [hl],a                      ; $2259  ; clear sub-state
    ret                            ; $225A  ; ret

Guard_State1:
    call Slot_Place                ; $225B  ; state 1: spawn guard

loc_225E:
    xor a                          ; $225E  ; reset guard fields
    ld hl,$0008                    ; $225F  ; obj+8
    add hl,de                      ; $2262  ; clear timer
    ld [hl],a                      ; $2263  ; store
    ld hl,$0009                    ; $2264  ; obj+9
    add hl,de                      ; $2267  ; clear
    ld [hl],a                      ; $2268  ; store
    ld hl,$000F                    ; $2269  ; obj+$0F
    add hl,de                      ; $226C  ; clear
    ld [hl],a                      ; $226D  ; store
    ld a,$A0                       ; $226E  ; timer $A0
    ld hl,$000A                    ; $2270  ; obj+$0A
    add hl,de                      ; $2273  ; store
    ld [hl],a                      ; $2274  ; store
    ld hl,$000B                    ; $2275  ; obj+$0B
    add hl,de                      ; $2278  ; store timer
    ld [hl],a                      ; $2279  ; store
    ret                            ; $227A  ; ret

Guard_State2:
    call Guard_TouchPlayer         ; $227B  ; state 2: patrol
    call Guard_Step                ; $227E  ; AI tick
    call Guard_DigTimer            ; $2281  ; horizontal step
    call Guard_Fall                ; $2284  ; fall/timer
    jp Guard_Seek                  ; $2287  ; apply movement

Guard_State3:
    call Guard_TouchPlayer         ; $228A  ; state 3: patrol alt
    call Guard_Step                ; $228D  ; AI tick
    call Guard_InHole              ; $2290  ; vertical step
    call Guard_Fall                ; $2293  ; fall/timer
    jp Guard_Seek                  ; $2296  ; apply movement

Guard_State4:
    call Guard_TouchPlayer         ; $2299  ; state 4: chase/fall
    and $FE                        ; $229C  ; mask bit0
    cp $06                         ; $229E  ; == 6?
    jr nz,loc_22AA                 ; $22A0  ; else
    ld a,b                         ; $22A2  ; col
    cp c                           ; $22A3  ; == row?
    jr nz,loc_22AA                 ; $22A4  ; else
    cp $06                         ; $22A6  ; == 6?
    jr z,loc_22B5                  ; $22A8  ; aligned

loc_22AA:
    call Vel_AddX                  ; $22AA  ; knockback
    ld b,$1D                       ; $22AD  ; burst $1D
    call Obj_SetFrame              ; $22AF  ; apply knock
    call Move_SteerY               ; $22B2  ; draw guard

loc_22B5:
    ld hl,$0009                    ; $22B5  ; fall timer
    add hl,de                      ; $22B8  ; obj+9
    inc [hl]                       ; $22B9  ; timer++
    ld a,[hl]                      ; $22BA  ; timer
    cp $82                         ; $22BB  ; < $82?
    jr c,loc_22E0                  ; $22BD  ; continue
    ld hl,$0005                    ; $22BF  ; save X
    add hl,de                      ; $22C2  ; obj+6
    ld a,[hl]                      ; $22C3  ; X low
    ld hl,$0006                    ; $22C4  ; obj+7
    add hl,de                      ; $22C7  ; save X high
    ld [hl],a                      ; $22C8  ; store
    ld hl,$0003                    ; $22C9  ; save Y
    add hl,de                      ; $22CC  ; obj+3
    ld a,[hl]                      ; $22CD  ; Y low
    ld hl,$0007                    ; $22CE  ; obj+4
    add hl,de                      ; $22D1  ; save Y high
    ld [hl],a                      ; $22D2  ; store
    xor a                          ; $22D3  ; a = 0
    ld hl,$0009                    ; $22D4  ; obj+9
    add hl,de                      ; $22D7  ; clear timer
    ld [hl],a                      ; $22D8  ; store
    ld a,$07                       ; $22D9  ; state 7
    ld hl,$0000                    ; $22DB  ; obj+0
    add hl,de                      ; $22DE  ; state
    ld [hl],a                      ; $22DF  ; store 7

loc_22E0:
    call Guard_Fall                ; $22E0  ; fall/timer
    jp Guard_Seek                  ; $22E3  ; apply movement

Guard_State5:
    ld hl,$0009                    ; $22E6  ; state 5: escape hole
    add hl,de                      ; $22E9  ; obj+9
    ld a,[hl]                      ; $22EA  ; path timer
    push de                        ; $22EB  ; save de
    call loc_3319                  ; $22EC  ; random / timer
    call Rng_Next                  ; $22EF  ; scramble
    and $0F                        ; $22F2  ; & $0F
    inc a                          ; $22F4  ; +1
    ld c,a                         ; $22F5  ; c = offset
    ld b,$00                       ; $22F6  ; b = 0
    ld e,$12                       ; $22F8  ; probe count $12

loc_22FA:
    ld hl,$C930                    ; $22FA  ; grid scan base
    add hl,bc                      ; $22FD  ; cell

loc_22FE:
    ld a,[hl+]                     ; $22FE  ; cell value
    and $0F                        ; $22FF  ; low nibble
    cp $05                         ; $2301  ; == 5 (free)?
    jr z,loc_231C                  ; $2303  ; found
    dec e                          ; $2305  ; count--
    jr z,loc_2312                  ; $2306  ; ran out
    inc c                          ; $2308  ; offset++
    ld a,c                         ; $2309  ; offset
    cp $12                         ; $230A  ; < $12?
    jr c,loc_22FE                  ; $230C  ; continue
    ld c,$00                       ; $230E  ; wrap offset
    jr loc_22FA                    ; $2310  ; scan next

loc_2312:
    pop de                         ; $2312  ; advance path
    ld hl,$0009                    ; $2313  ; obj+9
    add hl,de                      ; $2316  ; timer
    ld a,[hl]                      ; $2317  ; timer
    add $0C                        ; $2318  ; + $0C
    ld [hl],a                      ; $231A  ; store
    ret                            ; $231B  ; ret

loc_231C:
    pop de                         ; $231C  ; free cell found
    sla c                          ; $231D  ; offset x2
    sla c                          ; $231F  ; x4
    ld a,c                         ; $2321  ; a = c
    sla c                          ; $2322  ; x8
    add c                          ; $2324  ; x10
    add $16                        ; $2325  ; + $16
    ld hl,$0003                    ; $2327  ; obj+3
    add hl,de                      ; $232A  ; Y dest
    ld [hl],a                      ; $232B  ; store Y
    ld hl,$0009                    ; $232C  ; obj+9
    add hl,de                      ; $232F  ; timer
    ld a,[hl]                      ; $2330  ; timer
    ld hl,$0005                    ; $2331  ; obj+5
    add hl,de                      ; $2334  ; store X
    ld [hl],a                      ; $2335  ; store
    call Guard_Layout              ; $2336  ; approach target
    ldh a,[$FFBD]                  ; $2339  ; FFBD flag
    and a                          ; $233B  ; zero?
    jr z,loc_2346                  ; $233C  ; normal
    ld a,$FF                       ; $233E  ; teleport Y
    ld hl,$0003                    ; $2340  ; obj+3
    add hl,de                      ; $2343  ; Y = $FF
    ld [hl],a                      ; $2344  ; store
    ret                            ; $2345  ; ret

loc_2346:
    xor a                          ; $2346  ; reset guard
    ld hl,$0002                    ; $2347  ; obj+2
    add hl,de                      ; $234A  ; clear vel
    ld [hl],a                      ; $234B  ; store
    ld hl,$0004                    ; $234C  ; obj+4
    add hl,de                      ; $234F  ; clear vel
    ld [hl],a                      ; $2350  ; store
    ld hl,$0001                    ; $2351  ; obj+1
    add hl,de                      ; $2354  ; clear
    ld [hl],a                      ; $2355  ; store
    call loc_225E                  ; $2356  ; reset fields
    ld a,$06                       ; $2359  ; state 6
    ld hl,$0000                    ; $235B  ; obj+0
    add hl,de                      ; $235E  ; state
    ld [hl],a                      ; $235F  ; store 6
    ld a,$0A                       ; $2360  ; sfx $0A
    jp SoundEngine_PlayEffect      ; $2362  ; play escape sfx

Guard_State6:
    ld hl,$0009                    ; $2365  ; state 6: re-spawn count
    add hl,de                      ; $2368  ; obj+9
    inc [hl]                       ; $2369  ; count++
    ld a,[hl]                      ; $236A  ; count
    ld b,$25                       ; $236B  ; tile $25
    cp $08                         ; $236D  ; < 8?
    jr c,Guard_RespawnTile         ; $236F  ; use tile
    inc b                          ; $2371  ; tile $26
    cp $10                         ; $2372  ; count < $10?
    jr c,Guard_RespawnTile         ; $2374  ; use tile
    inc b                          ; $2376  ; tile $27
    cp $18                         ; $2377  ; count < $18?
    jr c,Guard_RespawnTile         ; $2379  ; use tile
    inc b                          ; $237B  ; tile $28
    cp $20                         ; $237C  ; count < $20?
    jr c,Guard_RespawnTile         ; $237E  ; use tile
    ld a,$02                       ; $2380  ; state 2
    ld hl,$0000                    ; $2382  ; obj+0
    add hl,de                      ; $2385  ; field
    ld [hl],a                      ; $2386  ; state = 2 (patrol)
    ld b,$01                       ; $2387  ; sub-state 1

Guard_RespawnTile:
    ld a,b                         ; $2389  ; store tile/sub-state
    ld hl,$0001                    ; $238A  ; obj+1
    add hl,de                      ; $238D  ; field
    ld [hl],a                      ; $238E  ; obj+1 = b
    ret                            ; $238F  ; ret

Guard_State7:
    call Guard_TouchPlayer         ; $2390  ; state 7: line player up
    call Guard_Ai                  ; $2393  ; AI decision (FFBE)
    ld hl,$0009                    ; $2396  ; obj+9
    add hl,de                      ; $2399  ; timer field
    ld a,[hl]                      ; $239A  ; timer
    inc [hl]                       ; $239B  ; timer++
    cp $28                         ; $239C  ; >= $28?
    jr nc,Guard_State7_Chase       ; $239E  ; long: alternate route
    srl a                          ; $23A0  ; timer / 2 (parity)
    jp c,Guard_State7_Exit         ; $23A2  ; odd frame: skip move
    add $02                        ; $23A5  ; +2
    and $04                        ; $23A7  ; bit2 (direction selection)
    jr nz,Guard_State7_Alt         ; $23A9  ; alt step
    call Vel_SubY                  ; $23AB  ; move (subtract step)
    jr Guard_State7_Exit           ; $23AE  ; exit

Guard_State7_Alt:
    call Vel_AddY                  ; $23B0  ; alt step
    jr Guard_State7_Exit           ; $23B3  ; exit

Guard_State7_Chase:
    ldh a,[$FFD4]                  ; $23B5  ; frame counter
    and $01                        ; $23B7  ; parity bit
    jr z,Guard_State7_Move         ; $23B9  ; skip approach
    call Vel_SubX                  ; $23BB  ; turn toward player
    ld hl,$0005                    ; $23BE  ; obj+5 (X)
    add hl,de                      ; $23C1  ; field
    ld a,[hl]                      ; $23C2  ; X
    add $0C                        ; $23C3  ; X + $0C
    ld hl,$0006                    ; $23C5  ; obj+6 (limit)
    add hl,de                      ; $23C8  ; field
    cp [hl]                        ; $23C9  ; X+$0C vs limit
    jr c,Guard_State7_Next         ; $23CA  ; at edge: change state

Guard_State7_Move:
    ld hl,$0005                    ; $23CC  ; obj+5 (X)
    add hl,de                      ; $23CF  ; field
    ld a,[hl]                      ; $23D0  ; X
    add $07                        ; $23D1  ; X + $07
    ld hl,$0006                    ; $23D3  ; obj+6 (limit)
    add hl,de                      ; $23D6  ; field
    cp [hl]                        ; $23D7  ; X+$07 vs limit
    jr nc,Guard_State7_Exit        ; $23D8  ; in range: skip
    ldh a,[$FFBD]                  ; $23DA  ; FFBD block flags
    cpl                            ; $23DC  ; invert (allowed)
    ld b,a                         ; $23DD  ; mask
    ldh a,[$FFBE]                  ; $23DE  ; AI move (FFBE)
    and b                          ; $23E0  ; allowed moves
    ld hl,$0008                    ; $23E1  ; obj+8
    add hl,de                      ; $23E4  ; flags field
    ld [hl],a                      ; $23E5  ; obj+8 = moves
    bit 5,a                        ; $23E6  ; bit5 (right)?
    jr z,loc_23EF                  ; $23E8  ; no
    call Vel_SubY                  ; $23EA  ; move (subtract step)
    jr Guard_State7_Exit           ; $23ED  ; exit

loc_23EF:
    bit 4,a                        ; $23EF  ; bit4 (left)?
    call nz,Vel_AddY               ; $23F1  ; move (add step)
    jr Guard_State7_Exit           ; $23F4  ; exit

Guard_State7_Next:
    ld hl,$000F                    ; $23F6  ; obj+$0F flag
    add hl,de                      ; $23F9  ; field
    ld a,[hl]                      ; $23FA  ; flag
    and a                          ; $23FB  ; zero?
    ld a,$02                       ; $23FC  ; state 2
    jr z,Guard_State7_SetState     ; $23FE  ; use state 2
    ld a,$03                       ; $2400  ; state 3

Guard_State7_SetState:
    ld hl,$0000                    ; $2402  ; obj+0
    add hl,de                      ; $2405  ; field
    ld [hl],a                      ; $2406  ; set state
    xor a                          ; $2407  ; xor
    ld hl,$0009                    ; $2408  ; obj+9
    add hl,de                      ; $240B  ; field
    ld [hl],a                      ; $240C  ; timer = 0

Guard_State7_Exit:
    ld b,$15                       ; $240D  ; tile $15
    call Obj_SetFrame              ; $240F  ; set tile by frame
    call Guard_Fall                ; $2412  ; fall/clear check
    jp Guard_Seek                  ; $2415  ; seek player proximity

Guard_DrawAll:
    ld a,$20                       ; $2418  ; draw all guards
    ld [$DEA1],a                   ; $241A  ; DEA1 = $20 (guards active)
    xor a                          ; $241D  ; index = 0

Guard_DrawAll_Loop:
    ldh [$FFB2],a                  ; $241E  ; FFB2 = index
    swap a                         ; $2420  ; index * $10
    ld e,a                         ; $2422  ; e
    ld d,$00                       ; $2423  ; d = 0
    ld hl,$C010                    ; $2425  ; guards base C010
    add hl,de                      ; $2428  ; slot
    push hl                        ; $2429  ; save
    pop de                         ; $242A  ; de = guard slot
    ld hl,$0001                    ; $242B  ; obj+1
    add hl,de                      ; $242E  ; field
    ld a,[hl]                      ; $242F  ; tile
    and a                          ; $2430  ; active?
    ld hl,$2443                    ; $2431  ; sprite data table
    call nz,loc_1DA7               ; $2434  ; draw sprite frames
    ldh a,[$FFB2]                  ; $2437  ; index
    inc a                          ; $2439  ; index++
    cp $03                         ; $243A  ; < 3 guards?
    jr c,Guard_DrawAll_Loop        ; $243C  ; loop
    xor a                          ; $243E  ; xor
    ld [$DEA1],a                   ; $243F  ; DEA1 = 0
    ret                            ; $2442  ; ret
    db $08,$FA,$AB,$00,$80,$08,$FA,$AB
    db $20,$80

Guard_TouchPlayer:
    call PlayerDelta               ; $244D  ; player delta (b,c)
    ld a,b                         ; $2450  ; delta X
    add $06                        ; $2451  ; +6
    cp $0D                         ; $2453  ; < $0D?
    jr nc,Guard_Layout             ; $2455  ; far: skip
    ld a,c                         ; $2457  ; delta Y
    add $06                        ; $2458  ; +6
    cp $0D                         ; $245A  ; < $0D?
    jr nc,Guard_Layout             ; $245C  ; far: skip
    call Player_Capture            ; $245E  ; caught player

Guard_Layout:
    ld hl,$FFB9                    ; $2461  ; rel-buffer FFB9
    ld a,$80                       ; $2464  ; init $80
    ld [hl+],a                     ; $2466  ; FFB9 = $80
    ld [hl+],a                     ; $2467  ; FFBA = $80
    ld [hl+],a                     ; $2468  ; FFBB = $80
    ld [hl],a                      ; $2469  ; FFBC = $80
    ld bc,$FFB9                    ; $246A  ; bc = buffer
    ld hl,$C010                    ; $246D  ; guard slot 0
    call Guard_RelDist             ; $2470  ; relative pos
    ld hl,$C020                    ; $2473  ; guard slot 1
    call Guard_RelDist             ; $2476  ; relative pos
    ld hl,$C030                    ; $2479  ; guard slot 2
    call Guard_RelDist             ; $247C  ; relative pos
    call Guard_BlockFlags          ; $247F  ; build FFBD flags
    ld bc,$0600                    ; $2482  ; probe cell
    call Cell_Probe                ; $2485  ; query cell
    ld hl,$000C                    ; $2488  ; obj+$0C
    add hl,de                      ; $248B  ; field
    ld [hl],a                      ; $248C  ; cell type
    ret                            ; $248D  ; ret

Guard_RelDist:
    call Cmp16Eq_HlDe              ; $248E  ; same slot?
    ret z                          ; $2491  ; self: skip
    push de                        ; $2492  ; save
    push hl                        ; $2493  ; save
    ld hl,$0003                    ; $2494  ; obj+3 (Y)
    add hl,de                      ; $2497  ; field
    ld a,[hl]                      ; $2498  ; Y
    ld [bc],a                      ; $2499  ; buf = Y
    inc bc                         ; $249A  ; next
    ld hl,$0005                    ; $249B  ; obj+5 (X)
    add hl,de                      ; $249E  ; field
    ld a,[hl]                      ; $249F  ; X
    ld [bc],a                      ; $24A0  ; buf = X
    dec bc                         ; $24A1  ; back
    pop de                         ; $24A2  ; de = other guard
    ld hl,$0000                    ; $24A3  ; obj+0
    add hl,de                      ; $24A6  ; field
    ld a,[hl]                      ; $24A7  ; state
    and a                          ; $24A8  ; active?
    jr z,loc_24CE                  ; $24A9  ; else skip
    cp $07                         ; $24AB  ; state 7?
    jr nz,loc_24BE                 ; $24AD  ; no: use Y
    ld hl,$0009                    ; $24AF  ; obj+9
    add hl,de                      ; $24B2  ; field
    ld a,[hl]                      ; $24B3  ; timer
    cp $28                         ; $24B4  ; < $28?
    jr nc,loc_24BE                 ; $24B6  ; no: use Y
    ld hl,$0007                    ; $24B8  ; obj+7 (saved Y)
    add hl,de                      ; $24BB  ; field
    jr loc_24C2                    ; $24BC  ; relative

loc_24BE:
    ld hl,$0003                    ; $24BE  ; obj+3 (Y)
    add hl,de                      ; $24C1  ; other Y base

loc_24C2:
    ld a,[bc]                      ; $24C2  ; this Y
    sub [hl]                       ; $24C3  ; - other Y
    ld [bc],a                      ; $24C4  ; buf rel Y
    inc bc                         ; $24C5  ; next
    ld a,[bc]                      ; $24C6  ; this X
    ld hl,$0005                    ; $24C7  ; obj+5
    add hl,de                      ; $24CA  ; other X
    sub [hl]                       ; $24CB  ; - other X
    ld [bc],a                      ; $24CC  ; buf rel X
    inc bc                         ; $24CD  ; advance pair

loc_24CE:
    pop de                         ; $24CE  ; restore de
    ret                            ; $24CF  ; ret

Guard_BlockFlags:
    xor a                          ; $24D0  ; FFBD = 0
    ldh [$FFBD],a                  ; $24D1  ; clear
    ld hl,$FFB9                    ; $24D3  ; buffer
    ld a,[hl+]                     ; $24D6  ; rel Y (guard A)
    add $06                        ; $24D7  ; +6
    cp $0D                         ; $24D9  ; near?
    ld a,[hl+]                     ; $24DB  ; rel X (guard A)
    jr nc,loc_24E8                 ; $24DC  ; far: skip
    cp $F4                         ; $24DE  ; X >= $F4?
    call nc,Guard_BlockB7          ; $24E0  ; set bit7
    cp $0D                         ; $24E3  ; X < $0D?
    call c,Guard_BlockB6           ; $24E5  ; set bit6

loc_24E8:
    ld a,[hl+]                     ; $24E8  ; rel Y (guard B)
    add $06                        ; $24E9  ; +6
    cp $0D                         ; $24EB  ; near?
    jr nc,loc_24FA                 ; $24ED  ; far: skip
    ld a,[hl]                      ; $24EF  ; rel X (guard B)
    cp $F4                         ; $24F0  ; X >= $F4?
    call nc,Guard_BlockB7          ; $24F2  ; set bit7
    cp $0D                         ; $24F5  ; X < $0D?
    call c,Guard_BlockB6           ; $24F7  ; set bit6

loc_24FA:
    ld hl,$FFBA                    ; $24FA  ; restart pair
    ld a,[hl-]                     ; $24FD  ; rel X (guard A)
    add $06                        ; $24FE  ; +6
    cp $0D                         ; $2500  ; near?
    ld a,[hl]                      ; $2502  ; rel Y (guard A)
    jr nc,loc_250F                 ; $2503  ; far: skip
    cp $F4                         ; $2505  ; Y >= $F4?
    call nc,Guard_BlockB4          ; $2507  ; set bit4
    cp $0D                         ; $250A  ; Y < $0D?
    call c,Guard_BlockB5           ; $250C  ; set bit5

loc_250F:
    inc hl                         ; $250F  ; advance
    inc hl                         ; $2510  ; advance
    inc hl                         ; $2511  ; advance
    ld a,[hl-]                     ; $2512  ; rel X (guard B)
    add $06                        ; $2513  ; +6
    cp $0D                         ; $2515  ; near?
    ret nc                         ; $2517  ; far: done
    ld a,[hl]                      ; $2518  ; rel Y (guard B)
    cp $F4                         ; $2519  ; Y >= $F4?
    jr nc,Guard_BlockB4            ; $251B  ; set bit4
    cp $0D                         ; $251D  ; Y < $0D?
    ret nc                         ; $251F  ; far: done

Guard_BlockB5:
    push af                        ; $2520  ; FFBD bit5
    ldh a,[$FFBD]                  ; $2521  ; flags
    set 5,a                        ; $2523  ; set bit5
    ldh [$FFBD],a                  ; $2525  ; store
    pop af                         ; $2527  ; restore
    ret                            ; $2528  ; ret

Guard_BlockB4:
    push af                        ; $2529  ; FFBD bit4
    ldh a,[$FFBD]                  ; $252A  ; flags
    set 4,a                        ; $252C  ; set bit4
    ldh [$FFBD],a                  ; $252E  ; store
    pop af                         ; $2530  ; restore
    ret                            ; $2531  ; ret

Guard_BlockB6:
    push af                        ; $2532  ; FFBD bit6
    ldh a,[$FFBD]                  ; $2533  ; flags
    set 6,a                        ; $2535  ; set bit6
    ldh [$FFBD],a                  ; $2537  ; store
    pop af                         ; $2539  ; restore
    ret                            ; $253A  ; ret

Guard_BlockB7:
    push af                        ; $253B  ; FFBD bit7
    ldh a,[$FFBD]                  ; $253C  ; flags
    set 7,a                        ; $253E  ; set bit7
    ldh [$FFBD],a                  ; $2540  ; store
    pop af                         ; $2542  ; restore
    ret                            ; $2543  ; ret

Guard_Step:
    push bc                        ; $2544  ; AI decision
    call Guard_Ai                  ; $2545  ; AI (FFBE)
    pop bc                         ; $2548  ; restore bc
    ldh a,[$FFBD]                  ; $2549  ; FFBD
    bit 7,a                        ; $254B  ; bit7 blocked?
    jr nz,Guard_Step_Go            ; $254D  ; blocked: skip
    call Guard_FallCheck           ; $254F  ; check floor drop

Guard_Step_Go:
    ldh a,[$FFBD]                  ; $2552  ; FFBD
    cpl                            ; $2554  ; invert (allowed)
    ld b,a                         ; $2555  ; mask
    ldh a,[$FFBE]                  ; $2556  ; FFBE
    and b                          ; $2558  ; allowed
    call Move_Bit7                 ; $2559  ; move bit7/6
    ldh a,[$FFBD]                  ; $255C  ; FFBD
    cpl                            ; $255E  ; invert
    ld b,a                         ; $255F  ; mask
    ldh a,[$FFBE]                  ; $2560  ; FFBE
    and b                          ; $2562  ; allowed
    call Move_Bit5                 ; $2563  ; move bit5/3
    jp loc_1FD9                    ; $2566  ; set move state

Guard_DigTimer:
    ld hl,$0009                    ; $2569  ; obj+9 timer
    add hl,de                      ; $256C  ; field
    ld a,[hl]                      ; $256D  ; timer
    and a                          ; $256E  ; zero?
    jr z,Guard_DigHole             ; $256F  ; time to dig
    dec [hl]                       ; $2571  ; timer--
    ret                            ; $2572  ; ret

Guard_DigHole:
    ld bc,$0600                    ; $2573  ; probe cell
    call Cell_Probe                ; $2576  ; query
    cp $04                         ; $2579  ; cell $04?
    ret nz                         ; $257B  ; no: ret
    ld a,b                         ; $257C  ; row
    sub $05                        ; $257D  ; -5
    cp $03                         ; $257F  ; near center?
    ret nc                         ; $2581  ; no: ret
    ld a,c                         ; $2582  ; col
    sub $05                        ; $2583  ; -5
    cp $03                         ; $2585  ; near center?
    ret nc                         ; $2587  ; no: ret
    ld a,$05                       ; $2588  ; dig tile $05
    call Level_QueuePush           ; $258A  ; queue dig
    call Rng_Next                  ; $258D  ; rng
    or $10                         ; $2590  ; | $10
    ld hl,$0009                    ; $2592  ; obj+9
    add hl,de                      ; $2595  ; field
    ld [hl],a                      ; $2596  ; timer = rng|$10
    ld a,$FF                       ; $2597  ; $FF
    ld hl,$000F                    ; $2599  ; obj+$0F
    add hl,de                      ; $259C  ; field
    ld [hl],a                      ; $259D  ; flag = $FF
    ld a,$03                       ; $259E  ; state 3
    ld hl,$0000                    ; $25A0  ; obj+0
    add hl,de                      ; $25A3  ; field
    ld [hl],a                      ; $25A4  ; state = 3
    ret                            ; $25A5  ; ret

Guard_InHole:
    ld bc,$0C00                    ; $25A6  ; probe below
    call Cell_Probe                ; $25A9  ; query
    cp $05                         ; $25AC  ; cell $05?
    ret z                          ; $25AE  ; in hole: ret
    ld hl,$0000                    ; $25AF  ; obj+0
    add hl,de                      ; $25B2  ; field
    ld a,[hl]                      ; $25B3  ; state
    cp $04                         ; $25B4  ; state 4?
    jr nz,Guard_InHole_Next        ; $25B6  ; else wait
    ld hl,$000C                    ; $25B8  ; obj+$0C
    add hl,de                      ; $25BB  ; field
    ld a,[hl]                      ; $25BC  ; cell type
    cp $06                         ; $25BD  ; == $06?
    ret z                          ; $25BF  ; keep: ret
    ld bc,$0000                    ; $25C0  ; probe here
    call Cell_Probe                ; $25C3  ; query
    cp $05                         ; $25C6  ; cell $05?
    ret nz                         ; $25C8  ; no: ret
    push hl                        ; $25C9  ; save
    xor a                          ; $25CA  ; xor
    ld hl,$000F                    ; $25CB  ; obj+$0F
    add hl,de                      ; $25CE  ; field
    ld [hl],a                      ; $25CF  ; flag = 0
    pop hl                         ; $25D0  ; restore
    ld a,$04                       ; $25D1  ; tile $04
    jp Level_QueuePush             ; $25D3  ; queue refill

Guard_InHole_Next:
    ld hl,$0009                    ; $25D6  ; obj+9
    add hl,de                      ; $25D9  ; field
    dec [hl]                       ; $25DA  ; timer--
    ret nz                         ; $25DB  ; wait: ret
    call Rng_Next                  ; $25DC  ; rng
    and $3F                        ; $25DF  ; & $3F
    or $10                         ; $25E1  ; | $10
    ld hl,$0009                    ; $25E3  ; obj+9
    add hl,de                      ; $25E6  ; field
    ld [hl],a                      ; $25E7  ; new timer
    ld hl,$0001                    ; $25E8  ; obj+1
    add hl,de                      ; $25EB  ; field
    ld a,[hl]                      ; $25EC  ; tile
    sub $1D                        ; $25ED  ; - $1D
    cp $08                         ; $25EF  ; < 8?
    ret c                          ; $25F1  ; low: ret
    ld bc,$0600                    ; $25F2  ; probe below
    call Cell_Probe                ; $25F5  ; query
    cp $05                         ; $25F8  ; cell $05?
    ret nz                         ; $25FA  ; no: ret
    ld a,c                         ; $25FB  ; col
    and $FE                        ; $25FC  ; even col
    cp b                           ; $25FE  ; == row?
    ret nz                         ; $25FF  ; no: ret
    cp $06                         ; $2600  ; == $06?
    ret nz                         ; $2602  ; no: ret
    ld a,$04                       ; $2603  ; tile $04
    call Level_QueuePush           ; $2605  ; queue refill
    xor a                          ; $2608  ; xor
    ld hl,$000F                    ; $2609  ; obj+$0F
    add hl,de                      ; $260C  ; field
    ld [hl],a                      ; $260D  ; flag = 0
    ld a,$02                       ; $260E  ; state 2
    ld hl,$0009                    ; $2610  ; obj+9
    add hl,de                      ; $2613  ; field
    ld [hl],a                      ; $2614  ; timer = 2
    ld hl,$0000                    ; $2615  ; obj+0
    add hl,de                      ; $2618  ; field
    ld [hl],a                      ; $2619  ; state = 2
    ret                            ; $261A  ; ret

Guard_Fall:
    ld hl,$000C                    ; $261B  ; obj+$0C cell
    add hl,de                      ; $261E  ; field
    ld a,[hl]                      ; $261F  ; cell
    and a                          ; $2620  ; floor?
    ret nz                         ; $2621  ; standing: ret
    ld bc,$0050                    ; $2622  ; 50 pts
    call Score_AddBCD              ; $2625  ; add score
    ld hl,$000F                    ; $2628  ; obj+$0F
    add hl,de                      ; $262B  ; field
    ld a,[hl]                      ; $262C  ; flag
    and a                          ; $262D  ; zero?
    jr z,Guard_Fall_Chk            ; $262E  ; no bonus
    ld hl,$FFB4                    ; $2630  ; FFB4
    dec [hl]                       ; $2633  ; count--

Guard_Fall_Chk:
    ldh a,[$FF90]                  ; $2634  ; FF90
    bit 3,a                        ; $2636  ; bit3 (in game)?
    jr z,Guard_Fall_Reborn         ; $2638  ; menu: respawn
    xor a                          ; $263A  ; kill guard
    ld hl,$0000                    ; $263B  ; obj+0
    add hl,de                      ; $263E  ; field
    ld [hl],a                      ; $263F  ; state = 0
    jp Action_Kill_Snd             ; $2640  ; kill + sound

Guard_Fall_Reborn:
    ld a,$0C                       ; $2643  ; respawn timer $0C
    ld hl,$0009                    ; $2645  ; obj+9
    add hl,de                      ; $2648  ; field
    ld [hl],a                      ; $2649  ; timer
    ld a,$05                       ; $264A  ; state 5
    ld hl,$0000                    ; $264C  ; obj+0
    add hl,de                      ; $264F  ; field
    ld [hl],a                      ; $2650  ; state = 5 (escape)
    ret                            ; $2651  ; ret

Guard_Seek:
    call PlayerDelta               ; $2652  ; player delta
    ld a,c                         ; $2655  ; delta X
    add $06                        ; $2656  ; +6
    cp $0D                         ; $2658  ; < $0D?
    jr nc,Guard_Seek_Near          ; $265A  ; far: skip
    ld a,b                         ; $265C  ; delta Y
    cp $F4                         ; $265D  ; >= $F4?
    jr c,Guard_Seek_Near           ; $265F  ; skip
    ldh a,[$FFB8]                  ; $2661  ; FFB8
    set 7,a                        ; $2663  ; set bit7 (spotted)
    ldh [$FFB8],a                  ; $2665  ; store
    ret                            ; $2667  ; ret

Guard_Seek_Near:
    ld a,b                         ; $2668  ; delta X
    add $02                        ; $2669  ; +2
    cp $05                         ; $266B  ; < 3?
    ret nc                         ; $266D  ; far: ret
    ld a,c                         ; $266E  ; delta Y
    add $14                        ; $266F  ; +$14
    cp $29                         ; $2671  ; < $15?
    ret nc                         ; $2673  ; far: ret
    cp $14                         ; $2674  ; delta Y < $14?
    ldh a,[$FFB8]                  ; $2676  ; FFB8
    jr c,Guard_Seek_Left           ; $2678  ; player left
    set 5,a                        ; $267A  ; set bit5 (right)
    ldh [$FFB8],a                  ; $267C  ; store
    ret                            ; $267E  ; ret

Guard_Seek_Left:
    set 4,a                        ; $267F  ; set bit4 (left)
    ldh [$FFB8],a                  ; $2681  ; store
    ret                            ; $2683  ; ret

Guard_Ai:
    xor a                          ; $2684  ; FFBE = 0
    ldh [$FFBE],a                  ; $2685  ; clear
    ld hl,$000D                    ; $2687  ; obj+$0D
    add hl,de                      ; $268A  ; field
    ld a,[hl]                      ; $268B  ; AI state
    rst $10                        ; $268C  ; dispatch AI sub-state
    dw $2699,$26B9,$2802,$282A
    dw $2B36,$2B0B

Guard_Ai_Seek:
    call PlayerDelta               ; $2699  ; player delta
    ld a,$06                       ; $269C  ; +6
    add b                          ; $269E  ; delta X+6
    cp $0D                         ; $269F  ; aligned row?
    ld a,$01                       ; $26A1  ; AI state 1
    jr c,Guard_Ai_SeekSet          ; $26A3  ; yes: chase
    ld a,[hl]                      ; $26A5  ; player Y
    ld b,a                         ; $26A6  ; b = player Y
    ld hl,$0005                    ; $26A7  ; obj+5
    add hl,de                      ; $26AA  ; field
    ld a,[hl]                      ; $26AB  ; guard X
    sub b                          ; $26AC  ; - player Y
    ld a,$03                       ; $26AD  ; AI state 3
    jr c,Guard_Ai_SeekSet          ; $26AF  ; player above
    ld a,$04                       ; $26B1  ; AI state 4

Guard_Ai_SeekSet:
    ld hl,$000D                    ; $26B3  ; obj+$0D
    add hl,de                      ; $26B6  ; field
    ld [hl],a                      ; $26B7  ; store AI state
    ret                            ; $26B8  ; ret

Guard_Ai_Chase:
    xor a                          ; $26B9  ; obj+$0E = 0
    ld hl,$000E                    ; $26BA  ; field
    add hl,de                      ; $26BD  ; add
    ld [hl],a                      ; $26BE  ; clear flags
    ld a,$02                       ; $26BF  ; AI state 2
    ld hl,$000D                    ; $26C1  ; obj+$0D
    add hl,de                      ; $26C4  ; field
    ld [hl],a                      ; $26C5  ; store AI state
    call Guard_CellMap             ; $26C6  ; setup cell map
    ld a,[$C003]                   ; $26C9  ; player Y
    sub $10                        ; $26CC  ; -$10
    call CellIndex_BC              ; $26CE  ; coord to cell
    ld c,b                         ; $26D1  ; cell index
    ld b,$00                       ; $26D2  ; b = 0
    ld hl,$C958                    ; $26D4  ; ray table C958
    add hl,bc                      ; $26D7  ; offset
    ld a,$FF                       ; $26D8  ; sentinel $FF
    ld [hl],a                      ; $26DA  ; mark player cell
    ld a,[$C003]                   ; $26DB  ; player Y
    ld hl,$0003                    ; $26DE  ; obj+3
    add hl,de                      ; $26E1  ; field
    cp [hl]                        ; $26E2  ; guard vs player
    push af                        ; $26E3  ; save carry
    ld a,[hl]                      ; $26E4  ; guard Y
    sub $10                        ; $26E5  ; -$10
    call CellIndex_BC              ; $26E7  ; coord to cell
    ld c,b                         ; $26EA  ; cell index
    ld b,$00                       ; $26EB  ; b = 0
    ld hl,$C958                    ; $26ED  ; ray table
    add hl,bc                      ; $26F0  ; offset
    pop af                         ; $26F1  ; restore carry
    ld b,$20                       ; $26F2  ; dir up $20
    jr c,Guard_Ai_ChaseBack        ; $26F4  ; player above
    ld b,$10                       ; $26F6  ; dir down $10

Guard_Ai_ChaseLoop:
    ld a,[hl+]                     ; $26F8  ; scan next cell
    cp $FF                         ; $26F9  ; sentinel?
    jr z,Guard_Ai_ChaseRow         ; $26FB  ; reached player
    and a                          ; $26FD  ; blocked?
    jr nz,Guard_Ai_ChaseBlock      ; $26FE  ; blocked: turn
    jr Guard_Ai_ChaseLoop          ; $2700  ; scan on

Guard_Ai_ChaseBack:
    ld a,[hl-]                     ; $2702  ; scan prev cell
    cp $FF                         ; $2703  ; sentinel?
    jr z,Guard_Ai_ChaseRow         ; $2705  ; reached player
    and a                          ; $2707  ; blocked?
    jr nz,Guard_Ai_ChaseBlock      ; $2708  ; blocked: turn
    jr Guard_Ai_ChaseBack          ; $270A  ; scan on

Guard_Ai_ChaseRow:
    ld a,[$C005]                   ; $270C  ; player X
    ld hl,$0005                    ; $270F  ; obj+5
    add hl,de                      ; $2712  ; field
    sub [hl]                       ; $2713  ; delta X
    ld c,$40                       ; $2714  ; dir bit6 $40
    jr c,Guard_Ai_ChaseAlign       ; $2716  ; player left
    ld c,$80                       ; $2718  ; dir bit7 $80

Guard_Ai_ChaseAlign:
    add $01                        ; $271A  ; delta+1
    cp $03                         ; $271C  ; aligned?
    jr c,Guard_Ai_ChaseSet         ; $271E  ; aligned: skip
    ld a,b                         ; $2720  ; dir
    or c                           ; $2721  ; merge vertical
    ld b,a                         ; $2722  ; flag

Guard_Ai_ChaseSet:
    ld a,b                         ; $2723  ; movement bits
    ldh [$FFBE],a                  ; $2724  ; FFBE = move
    ld hl,$000E                    ; $2726  ; obj+$0E
    add hl,de                      ; $2729  ; field
    ld [hl],a                      ; $272A  ; store flags
    ret                            ; $272B  ; ret

Guard_Ai_ChaseBlock:
    ld a,b                         ; $272C  ; blocked dir
    ldh [$FFDC],a                  ; $272D  ; remember
    ld hl,$000C                    ; $272F  ; obj+$0C
    add hl,de                      ; $2732  ; field
    ld a,[hl]                      ; $2733  ; cell
    cp $02                         ; $2734  ; == 2?
    jr nz,Guard_Ai_ChaseGoto       ; $2736  ; no
    ld b,$40                       ; $2738  ; dir bit6 $40
    jr Guard_Ai_ChaseSet           ; $273A  ; set flags

Guard_Ai_ChaseGoto:
    call Guard_CellLook            ; $273C  ; AI helper
    ld c,a                         ; $273F  ; match value
    ldh a,[$FFD9]                  ; $2740  ; FFD9
    cp c                           ; $2742  ; match?
    jr nz,loc_274C                 ; $2743  ; no
    and a                          ; $2745  ; zero?
    ret z                          ; $2746  ; done
    ldh a,[$FFDC]                  ; $2747  ; saved dir
    ld b,a                         ; $2749  ; b = dir
    jr Guard_Ai_ChaseRow           ; $274A  ; chase row

loc_274C:
    ld b,$10                       ; $274C  ; dir bit4 $10
    cp $02                         ; $274E  ; == 2?
    jr z,Guard_Ai_ChaseRow         ; $2750  ; chase row
    ld a,c                         ; $2752  ; value
    and a                          ; $2753  ; zero?
    jr z,Guard_Ai_ChaseRow         ; $2754  ; chase row

Guard_Ai_ChaseLadder:
    ld b,$20                       ; $2756  ; chase tail: step up and test side
    cp $02                         ; $2758  ; cell == ladder?
    jr z,Guard_Ai_ChaseRow         ; $275A  ; ladder: chase row
    ldh a,[$FFD9]                  ; $275C  ; FFD9 = right look result
    and a                          ; $275E  ; open side?
    jr z,Guard_Ai_ChaseRow         ; $275F  ; open: chase row
    ret                            ; $2761  ; else keep position

Guard_CellMap:
    push de                        ; $2762  ; build guard solidity map for 18-cell window
    ld hl,$0005                    ; $2763  ; obj+5
    add hl,de                      ; $2766  ; X field
    ld a,[hl]                      ; $2767  ; X
    add $06                        ; $2768  ; +$06
    call Map_ScratchRow            ; $276A  ; copy tile map around X
    ld b,$12                       ; $276D  ; 18 cells
    ld de,$C930                    ; $276F  ; map base C930

Guard_CellMap_Loop:
    ld hl,$0014                    ; $2772  ; loop: +$14 neighbor cell
    add hl,de                      ; $2775  ; offset
    ld a,[hl]                      ; $2776  ; neighbor cell type
    cp $03                         ; $2777  ; <3?
    jr c,Guard_CellMap_Open        ; $2779  ; open neighbor
    and $FE                        ; $277B  ; mask low bit
    cp $06                         ; $277D  ; ==6?
    jr z,Guard_CellMap_Open        ; $277F  ; ladder-like: open
    ld a,[de]                      ; $2781  ; current cell type
    cp $02                         ; $2782  ; ==2?
    jr c,Guard_CellMap_Mark        ; $2784  ; <2: mark
    cp $04                         ; $2786  ; >=4?
    jr nc,Guard_CellMap_Mark       ; $2788  ; >=4: mark

Guard_CellMap_Open:
    xor a                          ; $278A  ; open: solidity flag 0
    jr Guard_CellMap_Store         ; $278B  ; store flag

Guard_CellMap_Mark:
    ld a,$80                       ; $278D  ; solid: solidity flag $80

Guard_CellMap_Store:
    ld hl,$0028                    ; $278F  ; +$28 solidity byte
    add hl,de                      ; $2792  ; offset flag
    ld [hl],a                      ; $2793  ; write solidity flag
    inc de                         ; $2794  ; next cell
    dec b                          ; $2795  ; count
    jr nz,Guard_CellMap_Loop       ; $2796  ; loop 18
    ld a,$01                       ; $2798  ; marker 1
    ld [$C957],a                   ; $279A  ; C957 dirty flag
    ld [$C96A],a                   ; $279D  ; C96A dirty flag
    pop de                         ; $27A0  ; restore de
    ret                            ; $27A1  ; ret

Guard_CellLook:
    push de                        ; $27A2  ; look both sides: right->FFD9, left->FFDA
    ld hl,$0003                    ; $27A3  ; obj+3
    add hl,de                      ; $27A6  ; Y field
    ld a,[hl]                      ; $27A7  ; Y
    sub $0A                        ; $27A8  ; -$0A
    call CellIndex_BC              ; $27AA  ; row index -> b
    ld c,b                         ; $27AD  ; row -> c
    ld b,$00                       ; $27AE  ; b = 0
    ld hl,$C958                    ; $27B0  ; solidity map base C958
    add hl,bc                      ; $27B3  ; row pointer
    push hl                        ; $27B4  ; save pointer
    pop de                         ; $27B5  ; de = solidity row
    ld hl,$C930                    ; $27B6  ; cell map base C930
    add hl,bc                      ; $27B9  ; row pointer
    push hl                        ; $27BA  ; save cell row
    push de                        ; $27BB  ; save solidity row

Guard_CellLook_Right:
    ld a,[hl+]                     ; $27BC  ; scan right: cell type
    cp $03                         ; $27BD  ; <3?
    jr c,Guard_CellLook_RightHit   ; $27BF  ; hit
    cp $10                         ; $27C1  ; == $10?
    jr z,Guard_CellLook_RightHit   ; $27C3  ; hit
    ld a,[de]                      ; $27C5  ; solidity flag
    and a                          ; $27C6  ; solid?
    jr nz,Guard_CellLook_RightFlag ; $27C7  ; solid: flag result
    inc de                         ; $27C9  ; next solidity
    jr Guard_CellLook_Right        ; $27CA  ; scan on

Guard_CellLook_RightHit:
    cp $02                         ; $27CC  ; hit: ladder cell?
    jr z,Guard_CellLook_RightSet   ; $27CE  ; ladder result
    xor a                          ; $27D0  ; blocked: result 0
    jr Guard_CellLook_RightSet     ; $27D1  ; store

Guard_CellLook_RightFlag:
    ld a,[hl]                      ; $27D3  ; flag result: cell == ladder?
    cp $02                         ; $27D4  ; == ladder?
    jr z,Guard_CellLook_RightSet   ; $27D6  ; keep cell value
    ld a,$01                       ; $27D8  ; open: result 1

Guard_CellLook_RightSet:
    ldh [$FFD9],a                  ; $27DA  ; FFD9 = right result
    pop de                         ; $27DC  ; restore solidity row
    pop hl                         ; $27DD  ; restore cell row
    dec hl                         ; $27DE  ; step back
    dec de                         ; $27DF  ; step back

Guard_CellLook_Left:
    ld a,[hl-]                     ; $27E0  ; scan left: cell type
    cp $03                         ; $27E1  ; <3?
    jr c,Guard_CellLook_LeftHit    ; $27E3  ; hit
    cp $10                         ; $27E5  ; == $10?
    jr z,Guard_CellLook_LeftHit    ; $27E7  ; hit
    ld a,[de]                      ; $27E9  ; solidity flag
    and a                          ; $27EA  ; solid?
    jr nz,Guard_CellLook_LeftFlag  ; $27EB  ; solid: flag result
    dec de                         ; $27ED  ; previous solidity
    jr Guard_CellLook_Left         ; $27EE  ; scan on

Guard_CellLook_LeftHit:
    cp $02                         ; $27F0  ; hit: ladder cell?
    jr z,Guard_CellLook_LeftSet    ; $27F2  ; ladder result
    xor a                          ; $27F4  ; blocked: result 0
    jr Guard_CellLook_LeftSet      ; $27F5  ; store

Guard_CellLook_LeftFlag:
    ld a,[hl]                      ; $27F7  ; flag result: cell == ladder?
    cp $02                         ; $27F8  ; == ladder?
    jr z,Guard_CellLook_LeftSet    ; $27FA  ; keep cell value
    ld a,$01                       ; $27FC  ; open: result 1

Guard_CellLook_LeftSet:
    ldh [$FFDA],a                  ; $27FE  ; FFDA = left result
    pop de                         ; $2800  ; restore de
    ret                            ; $2801  ; ret

Guard_Ai_Follow:
    ld hl,$000C                    ; $2802  ; AI state 2 handler: follow/settle on ladder
    add hl,de                      ; $2805  ; offset
    ld a,[hl]                      ; $2806  ; cell type
    cp $02                         ; $2807  ; == ladder?
    ld b,$00                       ; $2809  ; default move 0
    jr nz,Guard_Ai_Follow_Flags    ; $280B  ; not ladder: skip
    ld b,$40                       ; $280D  ; ladder: move $40

Guard_Ai_Follow_Flags:
    ld hl,$000E                    ; $280F  ; AI flags at obj+$0E
    add hl,de                      ; $2812  ; offset
    ld a,[hl]                      ; $2813  ; AI flags
    and a                          ; $2814  ; set?
    jr nz,Guard_Ai_Follow_Set      ; $2815  ; flags keep current FFBE
    ld a,b                         ; $2817  ; move bits

Guard_Ai_Follow_Set:
    ldh [$FFBE],a                  ; $2818  ; FFBE = move
    ldh a,[$FFB2]                  ; $281A  ; timer mask FFB2
    ld b,a                         ; $281C  ; b = timer mask
    ldh a,[$FFD4]                  ; $281D  ; frame counter
    and $03                        ; $281F  ; frame & 3
    cp b                           ; $2821  ; match?
    ret nz                         ; $2822  ; wait
    xor a                          ; $2823  ; state 0
    ld hl,$000D                    ; $2824  ; obj+$0D
    add hl,de                      ; $2827  ; offset
    ld [hl],a                      ; $2828  ; AI state -> 0 (seek)
    ret                            ; $2829  ; ret

Guard_Ai_Climb:
    xor a                          ; $282A  ; AI state 3 handler: climb/decent decision
    ld hl,$000E                    ; $282B  ; obj+$0E
    add hl,de                      ; $282E  ; offset
    ld [hl],a                      ; $282F  ; clear AI flags
    ld hl,$000D                    ; $2830  ; obj+$0D
    add hl,de                      ; $2833  ; offset
    ld a,[hl]                      ; $2834  ; current AI state
    ldh [$FFE2],a                  ; $2835  ; save -> FFE2
    ld a,$02                       ; $2837  ; state 2
    ld [hl],a                      ; $2839  ; AI state -> 2 (wait)
    call Guard_CellMap2            ; $283A  ; rebuild solidity map
    ld hl,$000C                    ; $283D  ; obj+$0C
    add hl,de                      ; $2840  ; offset
    ld a,[hl]                      ; $2841  ; cell type
    cp $03                         ; $2842  ; ==3?
    jp z,Guard_Climb_Row           ; $2844  ; row follow scan
    cp $02                         ; $2847  ; == ladder?
    jp z,Guard_Climb_Ladder        ; $2849  ; ladder path
    and $FE                        ; $284C  ; mask low bit
    cp $06                         ; $284E  ; ==6?
    jp z,Guard_Scan                ; $2850  ; descend scan
    ld bc,$0C00                    ; $2853  ; probe X+$0C cell
    call Cell_Probe                ; $2856  ; cell -> a
    cp $02                         ; $2859  ; <2?
    jp c,Guard_Scan                ; $285B  ; open: descend scan
    ldh [$FFD9],a                  ; $285E  ; FFD9 = cell
    and $FE                        ; $2860  ; mask low bit
    cp $06                         ; $2862  ; ==6?
    jp z,Guard_Scan                ; $2864  ; ladder-like: descend scan
    ld bc,$0B00                    ; $2867  ; probe X+$0B cell
    call Cell_Probe                ; $286A  ; cell -> a
    cp $02                         ; $286D  ; == ladder?
    jr z,Guard_Climb_Ladder        ; $286F  ; ladder path
    ldh a,[$FFD9]                  ; $2871  ; right probe cell
    cp $02                         ; $2873  ; == ladder?
    jp z,Guard_Scan                ; $2875  ; descend scan
    ret                            ; $2878  ; no move

Guard_Climb_Ladder:
    ld bc,$0C00                    ; $2879  ; on ladder: verify descent path
    call Cell_Probe                ; $287C  ; probe X+$0C cell
    cp $02                         ; $287F  ; result
    jp c,Guard_Scan                ; $2881  ; open: descend scan
    push hl                        ; $2884  ; save hl
    ld hl,$0005                    ; $2885  ; obj+5
    add hl,de                      ; $2888  ; X field
    ld a,[hl]                      ; $2889  ; guard X
    pop hl                         ; $288A  ; restore hl
    ld b,a                         ; $288B  ; guard X -> b
    ld a,[$C005]                   ; $288C  ; player X
    sub b                          ; $288F  ; delta X
    call CellIndex_BC              ; $2890  ; row offset -> b
    ld a,b                         ; $2893  ; row counter
    and a                          ; $2894  ; zero?
    jr z,Guard_Climb_Ladder_Align  ; $2895  ; aligned: no offset

Guard_Climb_Ladder_Loop:
    ld a,[hl]                      ; $2897  ; scan column: cell below
    cp $02                         ; $2898  ; == ladder?
    jr nz,Guard_Climb_Reverse      ; $289A  ; not ladder: reverse
    push de                        ; $289C  ; save de
    ld de,$0012                    ; $289D  ; row step $12
    add hl,de                      ; $28A0  ; next row
    ld de,$CA8B                    ; $28A1  ; compare endpoint
    call Cmp16_HlDe                ; $28A4  ; 16-bit cmp (hl vs endpoint)
    pop de                         ; $28A7  ; restore de
    jr nc,Guard_Climb_Ladder_Goal  ; $28A8  ; past player cell: goal
    dec b                          ; $28AA  ; dec row
    jr nz,Guard_Climb_Ladder_Loop  ; $28AB  ; loop rows

Guard_Climb_Ladder_Align:
    ld a,[$C005]                   ; $28AD  ; align: player X+$0C
    add $0C                        ; $28B0  ; X+$0C
    cp $C0                         ; $28B2  ; in bounds?
    jr nc,Guard_Climb_Ladder_Goal  ; $28B4  ; past field: goal
    ld c,$00                       ; $28B6  ; col offset 0
    call loc_30A7                  ; $28B8  ; probe cell
    cp $02                         ; $28BB  ; == ladder?
    jr nz,Guard_Climb_Reverse      ; $28BD  ; not ladder: reverse

Guard_Climb_Ladder_Goal:
    ld hl,$0003                    ; $28BF  ; goal confirmed: guard Y -> FFDC
    add hl,de                      ; $28C2  ; Y field
    ld a,[hl]                      ; $28C3  ; guard Y
    ldh [$FFDC],a                  ; $28C4  ; FFDC = Y
    ld a,[$C005]                   ; $28C6  ; player X
    add $12                        ; $28C9  ; X+$12
    cp $C0                         ; $28CB  ; in bounds?
    jr nc,Guard_Climb_Reverse      ; $28CD  ; past field: reverse
    ld c,$00                       ; $28CF  ; col offset 0
    call loc_30A7                  ; $28D1  ; probe cell
    cp $02                         ; $28D4  ; result
    jr c,Guard_Climb_Reverse       ; $28D6  ; open: reverse
    ldh a,[$FFDC]                  ; $28D8  ; guard Y
    cp $1C                         ; $28DA  ; near top edge?
    jr c,Guard_Climb_Ladder_Bounds ; $28DC  ; skip above check
    dec hl                         ; $28DE  ; cell above
    call Guard_Climb_Check         ; $28DF  ; check above
    inc hl                         ; $28E2  ; restore hl

Guard_Climb_Ladder_Bounds:
    ldh a,[$FFDC]                  ; $28E3  ; guard Y
    cp $DC                         ; $28E5  ; near bottom edge?
    jr nc,Guard_Climb_Ladder_Move  ; $28E7  ; skip below check
    inc hl                         ; $28E9  ; cell below
    call Guard_Climb_Check         ; $28EA  ; check below

Guard_Climb_Ladder_Move:
    ld b,$40                       ; $28ED  ; commit: move $40
    jp Guard_Ai_ChaseSet           ; $28EF  ; ChaseSet (write FFBE)

Guard_Climb_Check:
    ld a,[hl]                      ; $28F2  ; check cell and cell above row
    cp $02                         ; $28F3  ; cell <2?
    jr c,Guard_Climb_Check_Fail    ; $28F5  ; check fail
    and $FE                        ; $28F7  ; mask low bit
    cp $06                         ; $28F9  ; ==6?
    jr z,Guard_Climb_Check_Fail    ; $28FB  ; check fail
    push hl                        ; $28FD  ; save hl
    ld bc,$FFEE                    ; $28FE  ; -$12 (one row)
    add hl,bc                      ; $2901  ; cell above row
    ld a,[hl]                      ; $2902  ; above cell
    pop hl                         ; $2903  ; restore hl
    cp $03                         ; $2904  ; ==3?
    ret nz                         ; $2906  ; keep (nz)

Guard_Climb_Check_Fail:
    pop bc                         ; $2907  ; fail: pop bc

Guard_Climb_Reverse:
    ld b,$80                       ; $2908  ; reverse: move $80
    jp Guard_Ai_ChaseSet           ; $290A  ; ChaseSet (write FFBE)

Guard_Climb_Row:
    ld hl,$0005                    ; $290D  ; cell 3: follow row
    add hl,de                      ; $2910  ; X field
    ld a,[hl]                      ; $2911  ; guard X -> FFD9
    ldh [$FFD9],a                  ; $2912
    add $12                        ; $2914  ; X+$12
    cp $C0                         ; $2916  ; in bounds?
    jp nc,Guard_Scan_None          ; $2918  ; outside: rescan
    call loc_30A7                  ; $291B  ; probe cell
    ldh a,[$FFD9]                  ; $291E  ; guard X
    ld c,a                         ; $2920  ; c = guard X
    ld a,[$C005]                   ; $2921  ; player X
    sub c                          ; $2924  ; delta X
    call CellIndex_BC              ; $2925  ; row offset -> b
    inc b                          ; $2928  ; row +1

Guard_Climb_Row_Loop:
    ld a,[hl]                      ; $2929  ; scan column: cell
    cp $03                         ; $292A  ; <3?
    jr c,Guard_Climb_Reverse       ; $292C  ; open: reverse
    push de                        ; $292E  ; save de
    ld de,$0012                    ; $292F  ; row step $12
    add hl,de                      ; $2932  ; next row
    pop de                         ; $2933  ; restore de
    dec b                          ; $2934  ; dec row
    jr nz,Guard_Climb_Row_Loop     ; $2935  ; loop rows

Guard_Scan:
    ld hl,$0003                    ; $2937  ; descend scan: Y -> FFDE/FFDF
    add hl,de                      ; $293A  ; Y field
    ld a,[hl]                      ; $293B  ; guard Y
    ldh [$FFDE],a                  ; $293C  ; FFDE = Y
    ldh [$FFDF],a                  ; $293E  ; FFDF = Y
    sub $10                        ; $2940  ; Y-$10
    call CellIndex_BC              ; $2942  ; cell row -> b
    ld c,b                         ; $2945  ; row -> c
    xor a                          ; $2946  ; b = 0
    ld b,a                         ; $2947
    ldh [$FFDB],a                  ; $2948  ; FFDB = 0 (solid count)
    ldh [$FFDC],a                  ; $294A  ; FFDC = 0 (up count)
    ldh [$FFDD],a                  ; $294C  ; FFDD = 0 (down count)
    ld hl,$C958                    ; $294E  ; solidity map base C958
    add hl,bc                      ; $2951  ; row pointer
    push hl                        ; $2952  ; save row

Guard_Scan_Up:
    ldh a,[$FFDC]                  ; $2953  ; scan up: FFDC++
    inc a                          ; $2955
    ldh [$FFDC],a                  ; $2956  ; FFDC store
    ldh a,[$FFDE]                  ; $2958  ; FFDE-$0C
    sub $0C                        ; $295A
    ldh [$FFDE],a                  ; $295C  ; FFDE store
    ld a,[hl-]                     ; $295E  ; cell above
    ldh [$FFD9],a                  ; $295F  ; FFD9 = cell
    and a                          ; $2961  ; open (0)?
    jr z,Guard_Scan_Next           ; $2962  ; open: scan down
    cp $01                         ; $2964  ; ==1?
    jr z,Guard_Scan_Up             ; $2966  ; keep scanning up
    and $FE                        ; $2968  ; mask low bit
    cp $06                         ; $296A  ; ==6?
    jr z,Guard_Scan_Up             ; $296C  ; keep scanning up
    ldh a,[$FFDB]                  ; $296E  ; solid: FFDB++
    inc a                          ; $2970
    ldh [$FFDB],a                  ; $2971  ; FFDB store
    ldh a,[$FFDE]                  ; $2973  ; restore FFDE
    add $0C                        ; $2975
    ldh [$FFDE],a                  ; $2977  ; FFDE store

Guard_Scan_Next:
    pop hl                         ; $2979  ; scan down: restore row
    inc hl                         ; $297A  ; next cell

Guard_Scan_Down:
    ldh a,[$FFDD]                  ; $297B  ; scan down: FFDD++
    inc a                          ; $297D
    ldh [$FFDD],a                  ; $297E  ; FFDD store
    ldh a,[$FFDF]                  ; $2980  ; FFDF+$0C
    add $0C                        ; $2982
    ldh [$FFDF],a                  ; $2984  ; FFDF store
    ld a,[hl+]                     ; $2986  ; cell below
    ldh [$FFDA],a                  ; $2987  ; FFDA = cell
    and a                          ; $2989  ; open (0)?
    jr z,Guard_Scan_Eval           ; $298A  ; open: evaluate
    cp $01                         ; $298C  ; ==1?
    jr z,Guard_Scan_Down           ; $298E  ; keep scanning down
    and $FE                        ; $2990  ; mask low bit
    cp $06                         ; $2992  ; ==6?
    jr z,Guard_Scan_Down           ; $2994  ; keep scanning down
    ldh a,[$FFDB]                  ; $2996  ; solid: FFDB++
    inc a                          ; $2998
    ldh [$FFDB],a                  ; $2999  ; FFDB store

Guard_Scan_Eval:
    ldh a,[$FFD9]                  ; $299B  ; evaluate: up cell FFD9
    ld c,a                         ; $299D  ; c = up cell
    ldh a,[$FFDA]                  ; $299E  ; down cell FFDA
    or c                           ; $29A0  ; or c
    jp z,Guard_Scan_None           ; $29A1  ; both open: no path
    ldh a,[$FFDB]                  ; $29A4  ; FFDB solid count
    cp $01                         ; $29A6  ; ==1?
    jp z,Guard_Scan_Dn             ; $29A8  ; single solid: single scan
    ldh a,[$FFE2]                  ; $29AB  ; FFE2 = prior AI state
    cp $04                         ; $29AD  ; ==4?
    jp z,Guard_Scan_Block          ; $29AF  ; block resolved earlier: block scan

Guard_Scan_Mid:
    ld a,[$C005]                   ; $29B2  ; mid: player X+$0C
    add $0C                        ; $29B5  ; X+$0C
    cp $C0                         ; $29B7  ; in bounds?
    jp nc,Guard_Scan_Block         ; $29B9  ; past field: block scan
    ld b,a                         ; $29BC  ; X -> b
    ldh [$FFE0],a                  ; $29BD  ; FFE0 = X
    ldh a,[$FFDE]                  ; $29BF  ; FFDE = Y
    ld c,a                         ; $29C1  ; c = Y
    call Cell_MapLookup            ; $29C2  ; cell at (X, Y)
    cp $02                         ; $29C5  ; == ladder?
    call z,Guard_Probe_Vert_Dn     ; $29C7  ; ladder: extend probe
    ldh [$FFE1],a                  ; $29CA  ; FFE1 = cell
    ldh a,[$FFE0]                  ; $29CC  ; FFE0 = X
    ld b,a                         ; $29CE  ; b = X
    ldh a,[$FFDF]                  ; $29CF  ; FFDF = Y
    ld c,a                         ; $29D1  ; c = Y
    call Cell_MapLookup            ; $29D2  ; cell at (X, Y+..)
    cp $02                         ; $29D5  ; == ladder?
    call z,Guard_Probe_Vert        ; $29D7  ; ladder: extend probe
    cp $02                         ; $29DA  ; probe result
    jr c,Guard_Scan_Open           ; $29DC  ; open cell
    cp $06                         ; $29DE  ; ==6?
    jr z,Guard_Scan_Open           ; $29E0  ; open cell
    ldh a,[$FFE1]                  ; $29E2  ; FFE1 cell
    cp $02                         ; $29E4  ; <2?
    jr c,Guard_Scan_One            ; $29E6  ; single result
    cp $06                         ; $29E8  ; ==6?
    jr z,Guard_Scan_One            ; $29EA  ; single result
    jr Guard_Scan_Block            ; $29EC  ; block scan

Guard_Scan_Open:
    ldh a,[$FFE1]                  ; $29EE  ; open: FFE1
    cp $02                         ; $29F0  ; <2?
    jr c,Guard_Scan_Block          ; $29F2  ; block scan
    cp $06                         ; $29F4  ; ==6?
    jr z,Guard_Scan_Block          ; $29F6  ; block scan
    ld b,$10                       ; $29F8  ; move $10
    jr Guard_Climb_Commit          ; $29FA  ; commit

Guard_Scan_One:
    ld b,$20                       ; $29FC  ; single: move $20
    jr Guard_Climb_Commit          ; $29FE  ; commit

Guard_Scan_Block:
    ld b,$20                       ; $2A00  ; blocked ahead: move $20
    ld a,[$C92E]                   ; $2A02  ; cell C92E
    cp $02                         ; $2A05  ; ==2?
    jr c,Guard_Scan_Cmp            ; $2A07  ; compare counts
    jr nz,Guard_Climb_Commit       ; $2A09  ; keep
    ld a,[$C00C]                   ; $2A0B  ; player cell C00C
    cp $02                         ; $2A0E  ; ==2?
    jr z,Guard_Climb_Commit        ; $2A10  ; keep

Guard_Scan_Cmp:
    ldh a,[$FFDC]                  ; $2A12  ; compare up/down counts
    ld c,a                         ; $2A14  ; c = up count
    ldh a,[$FFDD]                  ; $2A15  ; down count FFDD
    cp c                           ; $2A17  ; down >= up?
    jr nc,Guard_Climb_Commit       ; $2A18  ; keep
    ld b,$10                       ; $2A1A  ; move $10
    jr Guard_Climb_Commit          ; $2A1C  ; commit

Guard_Scan_Dn:
    ld b,$20                       ; $2A1E  ; single: move $20
    ldh a,[$FFD9]                  ; $2A20  ; up cell FFD9
    and a                          ; $2A22  ; set?
    jr nz,Guard_Climb_Commit       ; $2A23  ; keep
    ldh a,[$FFDA]                  ; $2A25  ; down cell FFDA
    and a                          ; $2A27  ; set?
    jr z,Guard_Climb_Commit        ; $2A28  ; keep
    ld b,$10                       ; $2A2A  ; move $10

Guard_Climb_Commit:
    ld hl,$0001                    ; $2A2C  ; commit: read AI sub-state obj+1
    add hl,de                      ; $2A2F  ; offset
    ld a,[hl]                      ; $2A30  ; sub-state
    sub $1D                        ; $2A31  ; -$1D
    cp $08                         ; $2A33  ; <8?
    ret c                          ; $2A35  ; in window: keep current move
    ld a,$80                       ; $2A36  ; force flag $80
    or b                           ; $2A38  ; or move bits
    ld b,a                         ; $2A39  ; merge
    jp Guard_Ai_ChaseSet           ; $2A3A  ; ChaseSet (write FFBE)

Guard_Scan_None:
    call Guard_CellLook2           ; $2A3D  ; no clear path: rescan both sides
    ldh a,[$FFD9]                  ; $2A40  ; FFD9
    cp $02                         ; $2A42  ; == ladder?
    jp z,Guard_Ai_Block_Ladder     ; $2A44  ; enter ladder (region 9)
    ldh a,[$FFDA]                  ; $2A47  ; FFDA
    cp $02                         ; $2A49  ; == ladder?
    jp z,Guard_Ai_Block_Ladder     ; $2A4B  ; enter ladder (region 9)
    ret                            ; $2A4E  ; ret

Guard_Probe_Vert:
    ldh a,[$FFDF]                  ; $2A4F  ; vertical probe: FFDE = FFDF
    ldh [$FFDE],a                  ; $2A51  ; FFDE store

Guard_Probe_Vert_Dn:
    ldh a,[$FFDE]                  ; $2A53  ; vertical probe: FFDE-$0C
    sub $0C                        ; $2A55  ; Y-$0C
    cp $10                         ; $2A57  ; near top?
    jr c,Guard_Probe_Vert_Up       ; $2A59  ; skip up
    call Probe_XY                  ; $2A5B  ; probe (FFE0, A)
    cp $02                         ; $2A5E  ; result
    ret c                          ; $2A60  ; open: return
    and $FE                        ; $2A61  ; mask low bit
    cp $06                         ; $2A63  ; ==6?
    ret z                          ; $2A65  ; return

Guard_Probe_Vert_Up:
    ldh a,[$FFDE]                  ; $2A66  ; vertical probe: FFDE+$0C
    add $0C                        ; $2A68  ; Y+$0C
    cp $E8                         ; $2A6A  ; past bottom?
    ret nc                         ; $2A6C  ; return
    call Probe_XY                  ; $2A6D  ; probe (FFE0, A)
    cp $02                         ; $2A70  ; result
    ret c                          ; $2A72  ; open: return
    and $FE                        ; $2A73  ; mask low bit
    cp $06                         ; $2A75  ; ==6?
    ret                            ; $2A77  ; return

Guard_CellMap2:
    push de                        ; $2A78  ; rebuild cell map / solidity flags
    ld hl,$0005                    ; $2A79  ; obj+5
    add hl,de                      ; $2A7C  ; X field
    ld a,[hl]                      ; $2A7D  ; copy tile map around X
    call Map_ScratchRow            ; $2A7E
    ld b,$12                       ; $2A81  ; 18 cells
    ld de,$C930                    ; $2A83  ; map base C930

Guard_CellMap2_Loop:
    ld a,[de]                      ; $2A86  ; loop: cell type
    cp $02                         ; $2A87  ; <2?
    jr c,Guard_CellMap2_Open       ; $2A89  ; open flag
    cp $07                         ; $2A8B  ; ==7?
    jr z,Guard_CellMap2_Open       ; $2A8D  ; open flag
    ld a,$FF                       ; $2A8F  ; solid: flag $FF
    jr Guard_CellMap2_Mask         ; $2A91  ; mask store

Guard_CellMap2_Open:
    xor a                          ; $2A93  ; open: flag 0

Guard_CellMap2_Mask:
    ld c,a                         ; $2A94  ; flag -> c
    ld hl,$0014                    ; $2A95  ; +$14 neighbor cell
    add hl,de                      ; $2A98  ; offset
    ld a,[hl]                      ; $2A99  ; neighbor
    and a                          ; $2A9A  ; set?
    jr nz,Guard_CellMap2_Store     ; $2A9B  ; keep flag
    inc a                          ; $2A9D  ; inc -> 1

Guard_CellMap2_Store:
    and c                          ; $2A9E  ; and flag
    ld hl,$0028                    ; $2A9F  ; +$28 solidity byte
    add hl,de                      ; $2AA2  ; offset
    ld [hl],a                      ; $2AA3  ; write solidity flag
    inc de                         ; $2AA4  ; next cell
    dec b                          ; $2AA5  ; count
    jr nz,Guard_CellMap2_Loop      ; $2AA6  ; loop 18
    xor a                          ; $2AA8  ; value 0
    ld [$C957],a                   ; $2AA9  ; C957 clean
    ld [$C96A],a                   ; $2AAC  ; C96A clean
    pop de                         ; $2AAF  ; restore de
    ret                            ; $2AB0  ; ret

Guard_CellLook2:
    push de                        ; $2AB1  ; rescan both sides for ladders
    ld hl,$0003                    ; $2AB2  ; obj+3
    add hl,de                      ; $2AB5  ; Y field
    ld a,[hl]                      ; $2AB6  ; Y-$10
    sub $10                        ; $2AB7
    call CellIndex_BC              ; $2AB9  ; cell row -> b
    ld c,b                         ; $2ABC  ; row -> c
    xor a                          ; $2ABD  ; b = 0
    ld b,a                         ; $2ABE
    ldh [$FFDB],a                  ; $2ABF  ; FFDB = 0 (ladder count)
    ldh [$FFDC],a                  ; $2AC1  ; FFDC = 0
    ldh [$FFDD],a                  ; $2AC3  ; FFDD = 0
    ld hl,$C958                    ; $2AC5  ; solidity map base C958
    add hl,bc                      ; $2AC8  ; row pointer
    push hl                        ; $2AC9  ; save
    pop de                         ; $2ACA  ; de = solidity row
    ld hl,$C930                    ; $2ACB  ; cell map base C930
    add hl,bc                      ; $2ACE  ; row pointer
    push hl                        ; $2ACF  ; save cell row
    push de                        ; $2AD0  ; save solidity row

Guard_CellLook2_Right:
    ldh a,[$FFDC]                  ; $2AD1  ; scan right: FFDC++
    inc a                          ; $2AD3
    ldh [$FFDC],a                  ; $2AD4  ; FFDC store
    ld a,[hl+]                     ; $2AD6  ; cell
    cp $02                         ; $2AD7  ; == ladder?
    jr z,Guard_CellLook2_RightHit  ; $2AD9  ; hit
    ld a,[de]                      ; $2ADB  ; solidity flag
    inc de                         ; $2ADC  ; next
    and a                          ; $2ADD  ; solid?
    jr nz,Guard_CellLook2_Right    ; $2ADE  ; scan on

Guard_CellLook2_RightHit:
    ldh [$FFD9],a                  ; $2AE0  ; right hit: FFD9 = cell
    cp $02                         ; $2AE2  ; == ladder?
    jr nz,Guard_CellLook2_Left     ; $2AE4  ; scan left
    ldh a,[$FFDB]                  ; $2AE6  ; ladder: FFDB++
    inc a                          ; $2AE8
    ldh [$FFDB],a                  ; $2AE9  ; FFDB store

Guard_CellLook2_Left:
    pop de                         ; $2AEB  ; scan left: restore rows
    pop hl                         ; $2AEC  ; cell row
    dec hl                         ; $2AED  ; step back
    dec de                         ; $2AEE  ; step back

Guard_CellLook2_LeftLoop:
    ldh a,[$FFDD]                  ; $2AEF  ; scan left: FFDD++
    inc a                          ; $2AF1
    ldh [$FFDD],a                  ; $2AF2  ; FFDD store
    ld a,[hl-]                     ; $2AF4  ; cell
    cp $02                         ; $2AF5  ; == ladder?
    jr z,Guard_CellLook2_LeftHit   ; $2AF7  ; hit
    ld a,[de]                      ; $2AF9  ; solidity flag
    dec de                         ; $2AFA  ; previous
    and a                          ; $2AFB  ; solid?
    jr nz,Guard_CellLook2_LeftLoop ; $2AFC  ; scan on

Guard_CellLook2_LeftHit:
    ldh [$FFDA],a                  ; $2AFE  ; left hit: FFDA = cell
    cp $02                         ; $2B00  ; == ladder?
    jr nz,Guard_CellLook2_Done     ; $2B02  ; done
    ldh a,[$FFDB]                  ; $2B04  ; ladder: FFDB++
    inc a                          ; $2B06
    ldh [$FFDB],a                  ; $2B07  ; FFDB store

Guard_CellLook2_Done:
    pop de                         ; $2B09  ; done: restore de
    ret                            ; $2B0A  ; ret

Guard_Ai_Wait:
    ld hl,$000E                    ; $2B0B  ; AI state 5 handler: wait/stand
    add hl,de                      ; $2B0E  ; obj+$0E
    ld a,[hl]                      ; $2B0F  ; AI flags
    ldh [$FFBE],a                  ; $2B10  ; FFBE = flags (resume stored move)
    ld bc,$0C00                    ; $2B12  ; probe X+$0C cell
    call Cell_Probe                ; $2B15  ; cell -> a
    cp $02                         ; $2B18  ; <2?
    jr c,Guard_Ai_Wait_Open        ; $2B1A  ; open: prepare to stop
    and $FE                        ; $2B1C  ; mask low bit
    cp $06                         ; $2B1E  ; ==6?
    ret nz                         ; $2B20  ; solid: keep moving

Guard_Ai_Wait_Open:
    ld a,b                         ; $2B21  ; open: X within-cell residue
    and a                          ; $2B22  ; aligned to cell?
    ret nz                         ; $2B23  ; not aligned: keep
    ldh [$FFBE],a                  ; $2B24  ; FFBE = 0 (stand still)
    ldh a,[$FFB2]                  ; $2B26  ; timer mask FFB2
    ld b,a                         ; $2B28  ; b = timer mask
    ldh a,[$FFD4]                  ; $2B29  ; frame counter
    and $03                        ; $2B2B  ; frame & 3
    cp b                           ; $2B2D  ; match?
    ret nz                         ; $2B2E  ; wait

Guard_Ai_Wait_Done:
    xor a                          ; $2B2F  ; revert to state 0
    ld hl,$000D                    ; $2B30  ; obj+$0D
    add hl,de                      ; $2B33  ; offset
    ld [hl],a                      ; $2B34  ; AI state -> 0 (seek)
    ret                            ; $2B35  ; end of Guard_Ai_Wait_Done (region 8); AI state 4 handler follows

Guard_Ai_Block:
    xor a                          ; $2B36  ; AI state 4 (block): clear AI flags obj+$0E
    ld hl,$000E                    ; $2B37  ; hl = obj+$0E
    add hl,de                      ; $2B3A  ; add de
    ld [hl],a                      ; $2B3B  ; AI flags = 0
    ld hl,$000D                    ; $2B3C  ; hl = obj+$0D
    add hl,de                      ; $2B3F  ; add de
    ld a,[hl]                      ; $2B40  ; a = current AI state
    ldh [$FFE2],a                  ; $2B41  ; FFE2 = prior AI state
    ld a,$02                       ; $2B43  ; a = 2
    ld [hl],a                      ; $2B45  ; AI state = 2 (follow)
    call Guard_CellMap2            ; $2B46  ; rebuild cell map / solidity flags
    ld hl,$000C                    ; $2B49  ; hl = obj+$0C
    add hl,de                      ; $2B4C  ; add de
    ld a,[hl]                      ; $2B4D  ; a = obj+$0C (cell under guard)
    cp $02                         ; $2B4E  ; == 2 (open)?
    jr nz,Guard_Ai_Block_Scan      ; $2B50  ; not open: keep scanning
    ld bc,$0C00                    ; $2B52  ; bc = $0C00 (down 1 cell)
    call Cell_Probe                ; $2B55  ; probe cell at offset
    cp $02                         ; $2B58  ; == 2 (open below)?
    jr nz,Guard_Ai_Block_Scan      ; $2B5A  ; not open: keep scanning
    ld b,$40                       ; $2B5C  ; b = $40
    jp Guard_Ai_ChaseSet           ; $2B5E  ; chase with movement bits

Guard_Ai_Block_Scan:
    call Guard_LadderScan          ; $2B61  ; ladder column scan under guard
    ldh a,[$FFDA]                  ; $2B64  ; FFDA (cell above) == 2?
    cp $02                         ; $2B66  ; ladder above: align to it
    jr z,Guard_Ai_Block_Ladder     ; $2B68
    ldh a,[$FFD9]                  ; $2B6A  ; FFD9 (cell below) == 2?
    cp $02                         ; $2B6C  ; ladder below: align to it
    jp nz,Guard_Scan               ; $2B6E  ; no ladder in column: keep scanning

Guard_Ai_Block_Ladder:
    ldh a,[$FFDB]                  ; $2B71  ; column has ladder(s); pick a rung
    cp $01                         ; $2B73  ; FFDB == 1 (single ladder)?
    jr z,Guard_Ai_Block_Head       ; $2B75  ; single ladder: go to it
    ldh a,[$FFE2]                  ; $2B77  ; FFE2 = prior AI state
    cp $03                         ; $2B79  ; == 3 (was climbing)?
    jp z,Guard_Ai_Block_Mid        ; $2B7B  ; was climbing: check mid ladder
    ld a,[$C005]                   ; $2B7E  ; a = player X
    add $0C                        ; $2B81  ; + $0C (clamp offset)
    ld b,a                         ; $2B83  ; b = X probe
    ldh [$FFE0],a                  ; $2B84  ; FFE0 = X probe
    ldh a,[$FFDE]                  ; $2B86  ; FFDE = probe Y
    ld c,a                         ; $2B88  ; c = Y probe
    call Cell_MapLookup            ; $2B89  ; read cell at (X+$0C, FFDE)
    cp $02                         ; $2B8C  ; == 2 (open)?
    ld a,$FF                       ; $2B8E  ; a = $FF (not open)
    call z,Guard_Probe_Vert_Dn     ; $2B90  ; probe just below that cell
    ldh [$FFE1],a                  ; $2B93  ; FFE1 = below-probe result
    ldh a,[$FFE0]                  ; $2B95  ; b = X probe
    ld b,a                         ; $2B97  ; b = X probe again
    ldh a,[$FFDF]                  ; $2B98  ; FFDF = second probe Y
    ld c,a                         ; $2B9A  ; c = Y2
    call Cell_MapLookup            ; $2B9B  ; read cell at (X+$0C, FFDF)
    cp $02                         ; $2B9E  ; == 2 (open)?
    ld a,$FF                       ; $2BA0  ; a = $FF (not open)
    call z,Guard_Probe_Vert        ; $2BA2  ; probe vertically
    cp $02                         ; $2BA5  ; a < 2 (open path)?
    jr c,Guard_Ai_Block_Climb      ; $2BA7  ; open: climb check
    cp $06                         ; $2BA9  ; == 6 (solid)?
    jr z,Guard_Ai_Block_Climb      ; $2BAB  ; solid: climb check
    ldh a,[$FFE1]                  ; $2BAD  ; FFE1 (deep probe) < 2?
    cp $02                         ; $2BAF  ; open below: descend check
    jr c,Guard_Ai_Block_Dn         ; $2BB1  ; == 6 (solid)?
    cp $06                         ; $2BB3  ; solid: descend check
    jr z,Guard_Ai_Block_Dn         ; $2BB5
    jr Guard_Ai_Block_Mid          ; $2BB7  ; else: mid-ladder check

Guard_Ai_Block_Climb:
    ldh a,[$FFE1]                  ; $2BB9  ; climb up: confirm below path open
    cp $02                         ; $2BBB  ; FFE1 < 2?
    jr c,Guard_Ai_Block_Mid        ; $2BBD  ; open: mid check
    cp $06                         ; $2BBF  ; == 6?
    jr z,Guard_Ai_Block_Mid        ; $2BC1  ; solid: mid check
    ld b,$10                       ; $2BC3  ; b = $10 (climb up)
    jr Guard_Ai_Block_Go           ; $2BC5  ; commit movement

Guard_Ai_Block_Dn:
    ld b,$20                       ; $2BC7  ; climb down: b = $20
    jr Guard_Ai_Block_Go           ; $2BC9  ; commit movement

Guard_Ai_Block_Mid:
    ld b,$20                       ; $2BCB  ; mid ladder: b = $20
    ld a,[$C92E]                   ; $2BCD  ; a = [C92E] (guard at ladder?)
    cp $02                         ; $2BD0  ; < 2?
    jr c,Guard_Ai_Block_MidGap     ; $2BD2  ; no guard: gap check
    jr nz,Guard_Ai_Block_Go        ; $2BD4  ; != 2 (open?): commit
    ld a,[$C00C]                   ; $2BD6  ; a = [C00C]
    cp $02                         ; $2BD9  ; == 2 (open): commit
    jr z,Guard_Ai_Block_Go         ; $2BDB  ; fall through to gap check

Guard_Ai_Block_MidGap:
    ldh a,[$FFDD]                  ; $2BDD  ; compare scan counts FFDD vs FFDC
    ld c,a                         ; $2BDF  ; c = FFDD
    ldh a,[$FFDC]                  ; $2BE0  ; a = FFDC
    cp c                           ; $2BE2  ; FFDC >= FFDD?
    jr nc,Guard_Ai_Block_Go        ; $2BE3  ; commit
    ld b,$10                       ; $2BE5  ; b = $10 (up)
    jr Guard_Ai_Block_Go           ; $2BE7  ; commit

Guard_Ai_Block_Head:
    ldh a,[$FFDA]                  ; $2BE9  ; lone ladder above: FFDA == 2?
    cp $02                         ; $2BEB  ; == 2?
    ld b,$20                       ; $2BED  ; b = $20 (down)
    jr z,Guard_Ai_Block_Go         ; $2BEF  ; ladder below: commit
    ld b,$10                       ; $2BF1  ; b = $10 (up)

Guard_Ai_Block_Go:
    ld a,b                         ; $2BF3  ; a = movement bits
    or $40                         ; $2BF4  ; | $40 (chase flag)
    ld b,a                         ; $2BF6  ; b = movement bits
    jp Guard_Ai_ChaseSet           ; $2BF7  ; chase with movement bits

Guard_LadderScan:
    push de                        ; $2BFA  ; scan ladder column: from guard Y, map cell row
    ld hl,$0003                    ; $2BFB  ; hl = obj+3
    add hl,de                      ; $2BFE  ; add de
    ld a,[hl]                      ; $2BFF  ; a = Y pixel
    ldh [$FFDE],a                  ; $2C00  ; FFDE = scan Y (up direction)
    ldh [$FFDF],a                  ; $2C02  ; FFDF = scan Y (down direction)
    sub $10                        ; $2C04  ; Y - $10
    call CellIndex_BC              ; $2C06  ; row index from Y
    ld c,b                         ; $2C09  ; c = row offset
    xor a                          ; $2C0A  ; a = 0
    ld b,a                         ; $2C0B  ; b = 0
    ldh [$FFDB],a                  ; $2C0C  ; FFDB = 0 (ladder count)
    ldh [$FFDC],a                  ; $2C0E  ; FFDC = 0 (down count)
    ldh [$FFDD],a                  ; $2C10  ; FFDD = 0 (up count)
    ld hl,$C930                    ; $2C12  ; hl = C930 (map) + row
    add hl,bc                      ; $2C15  ; + bc
    push hl                        ; $2C16  ; push column start
    pop de                         ; $2C17  ; de = column ptr
    push de                        ; $2C18  ; keep start on stack

Guard_LadderScan_Down:
    ldh a,[$FFDC]                  ; $2C19  ; down loop: next cell row
    inc a                          ; $2C1B  ; FFDC + 1
    ldh [$FFDC],a                  ; $2C1C  ; FFDC = count
    ldh a,[$FFDF]                  ; $2C1E  ; FFDF + $0C
    add $0C                        ; $2C20  ; next row down
    ldh [$FFDF],a                  ; $2C22  ; FFDF = Y
    ld a,[de]                      ; $2C24  ; a = cell [de]
    cp $02                         ; $2C25  ; == 2 (ladder)?
    jr z,Guard_LadderScan_DnHit    ; $2C27  ; ladder: record hit
    ld hl,$0028                    ; $2C29  ; hl = solidity cell +$28
    add hl,de                      ; $2C2C  ; + de
    inc de                         ; $2C2D  ; de + 1
    ld a,[hl]                      ; $2C2E  ; a = solidity value
    and a                          ; $2C2F  ; == 0 (empty)?
    jr z,Guard_LadderScan_DnHit    ; $2C30  ; empty: record
    cp $03                         ; $2C32  ; < 3?
    jr c,Guard_LadderScan_Down     ; $2C34  ; soft: keep scanning
    and $FE                        ; $2C36  ; a & $FE
    cp $06                         ; $2C38  ; == 6 (solid)?
    jr z,Guard_LadderScan_Down     ; $2C3A  ; solid: keep scanning

Guard_LadderScan_DnHit:
    ldh [$FFD9],a                  ; $2C3C  ; FFD9 = last interesting cell below
    cp $02                         ; $2C3E  ; == 2 (ladder)?
    jr nz,Guard_LadderScan_Up      ; $2C40  ; not ladder: skip count
    ldh a,[$FFDB]                  ; $2C42  ; FFDB + 1
    inc a                          ; $2C44  ; inc
    ldh [$FFDB],a                  ; $2C45  ; FFDB = count
    ldh a,[$FFDF]                  ; $2C47  ; FFDF - $0C
    sub $0C                        ; $2C49  ; undo extra row
    ldh [$FFDF],a                  ; $2C4B  ; FFDF = Y

Guard_LadderScan_Up:
    pop de                         ; $2C4D  ; pop start; step up
    dec de                         ; $2C4E  ; de - 1 (cell above)

Guard_LadderScan_UpLoop:
    ldh a,[$FFDD]                  ; $2C4F  ; up loop: previous cell row
    inc a                          ; $2C51  ; FFDD + 1
    ldh [$FFDD],a                  ; $2C52  ; FFDD = count
    ldh a,[$FFDE]                  ; $2C54  ; FFDE - $0C
    sub $0C                        ; $2C56  ; prev row up
    ldh [$FFDE],a                  ; $2C58  ; FFDE = Y
    ld a,[de]                      ; $2C5A  ; a = cell [de]
    cp $02                         ; $2C5B  ; == 2 (ladder)?
    jr z,Guard_LadderScan_UpHit    ; $2C5D  ; ladder: record hit
    ld hl,$0028                    ; $2C5F  ; hl = solidity cell +$28
    add hl,de                      ; $2C62  ; + de
    dec de                         ; $2C63  ; de - 1
    ld a,[hl]                      ; $2C64  ; a = solidity value
    and a                          ; $2C65  ; == 0 (empty)?
    jr z,Guard_LadderScan_UpHit    ; $2C66  ; empty: record
    cp $03                         ; $2C68  ; < 3?
    jr c,Guard_LadderScan_UpLoop   ; $2C6A  ; soft: keep scanning
    and $FE                        ; $2C6C  ; a & $FE
    cp $06                         ; $2C6E  ; == 6?
    jr z,Guard_LadderScan_UpLoop   ; $2C70  ; solid: keep scanning

Guard_LadderScan_UpHit:
    ldh [$FFDA],a                  ; $2C72  ; FFDA = last interesting cell above
    cp $02                         ; $2C74  ; == 2 (ladder)?
    jr nz,Guard_LadderScan_Done    ; $2C76  ; not ladder: done
    ldh a,[$FFDB]                  ; $2C78  ; FFDB + 1
    inc a                          ; $2C7A  ; inc
    ldh [$FFDB],a                  ; $2C7B  ; FFDB = count

Guard_LadderScan_Done:
    pop de                         ; $2C7D  ; pop scan ptr; done
    ret                            ; $2C7E  ; ret

BonusSlot_Dispatch:
    ld de,$C040                    ; $2C7F  ; dispatch C040 bonus slot state machine
    ld hl,$C040                    ; $2C82  ; hl = C040 (state)
    call State_DispatchGate        ; $2C85  ; skip while scrolling or state < 2
    rst $10                        ; $2C88  ; rst $10 table by C040 state
    dw $2C95,$2C9C,$2CB9,$2CBF
    dw $2D07,$2D4F

BonusSlot_Clr:
    xor a                          ; $2C95  ; state 0: clear bonus slot
    ldh [$FF9C],a                  ; $2C96  ; FF9C = 0
    ld [$C041],a                   ; $2C98  ; C041 = 0 (sub state)
    ret                            ; $2C9B  ; ret

BonusSlot_Spawn:
    call Slot_Place                ; $2C9C  ; state 1: spawn bonus slot
    ld hl,$FF9C                    ; $2C9F  ; hl = FF9C
    set 7,[hl]                     ; $2CA2  ; FF9C bit7 = active
    bit 6,[hl]                     ; $2CA4  ; FF9C bit6 (second spawn)?
    ld a,$01                       ; $2CA6  ; a = 1
    jr z,BonusSlot_Spawn_Flag      ; $2CA8  ; bit6 set: a = 4
    ld a,$04                       ; $2CAA

BonusSlot_Spawn_Flag:
    ld [$C041],a                   ; $2CAC  ; C041 = 1 or 4 (variant)
    ld a,$02                       ; $2CAF  ; a = 2
    jr z,BonusSlot_Spawn_State     ; $2CB1  ; bit6 set: a = 4
    ld a,$04                       ; $2CB3

BonusSlot_Spawn_State:
    ld [$C040],a                   ; $2CB5  ; C040 = 2 or 4 (next state)
    ret                            ; $2CB8  ; ret

BonusSlot_TimerSet:
    ld a,$1E                       ; $2CB9  ; state 2: C049 = $1E (countdown start)
    ld [$C049],a                   ; $2CBB  ; C049 = $1E
    ret                            ; $2CBE  ; ret

BonusSlot_Tick:
    ld a,[$C049]                   ; $2CBF  ; state 3: countdown tick
    and a                          ; $2CC2  ; a = C049
    jr z,BonusSlot_Trigger         ; $2CC3  ; == 0?
    dec a                          ; $2CC5  ; timer - 1
    ld [$C049],a                   ; $2CC6  ; C049 = timer
    ld b,$02                       ; $2CC9  ; b = 2 (speed tier)
    cp $14                         ; $2CCB  ; timer >= $14?
    jr nc,BonusSlot_Tick_Speed     ; $2CCD  ; skip
    inc b                          ; $2CCF  ; b = 3
    cp $0A                         ; $2CD0  ; timer >= $0A?
    jr nc,BonusSlot_Tick_Speed     ; $2CD2  ; skip
    inc b                          ; $2CD4  ; b = 4

BonusSlot_Tick_Speed:
    ld a,b                         ; $2CD5  ; C041 = tier
    ld [$C041],a                   ; $2CD6  ; C041 = tier

BonusSlot_Trigger:
    ld a,[$C041]                   ; $2CD9  ; only act when C041 == 4 (urgent)
    cp $04                         ; $2CDC  ; a = C041
    ret nz                         ; $2CDE  ; != 4: ret
    ldh a,[$FFC1]                  ; $2CDF  ; FFC1 joypad
    bit 6,a                        ; $2CE1  ; bit 6 (action button)
    ret z                          ; $2CE3  ; not pressed: ret
    call PlayerDelta               ; $2CE4  ; player delta (b,c)
    ld a,b                         ; $2CE7  ; b + $04
    add $04                        ; $2CE8  ; +4
    cp $09                         ; $2CEA  ; >= 9 (player far)?
    ret nc                         ; $2CEC  ; far: ret
    ld a,c                         ; $2CED  ; c + $04
    add $04                        ; $2CEE  ; +4
    cp $09                         ; $2CF0  ; >= 9?
    ret nc                         ; $2CF2  ; far: ret
    ldh a,[$FFCC]                  ; $2CF3  ; FFCC = player X
    ld [$CBAB],a                   ; $2CF5  ; CBAB = player X
    ldh a,[$FFCE]                  ; $2CF8  ; FFCE = player Y
    ld [$CBAC],a                   ; $2CFA  ; CBAC = player Y
    call Scroll_Start              ; $2CFD  ; begin intro scroll (catch)
    ldh a,[$FF9C]                  ; $2D00  ; FF9C flags
    set 5,a                        ; $2D02  ; bit5 set (caught)
    ldh [$FF9C],a                  ; $2D04  ; FF9C = flags
    ret                            ; $2D06  ; ret

BonusSlot_Timeout:
    ldh a,[$FFD4]                  ; $2D07  ; state 4: global countdown, every 64 frames
    and $3F                        ; $2D09  ; FFD4 (frame) & $3F
    jr nz,BonusSlot_Timeout_Speed  ; $2D0B  ; not frame multiple: skip
    ld hl,$C049                    ; $2D0D  ; hl = C049
    dec [hl]                       ; $2D10  ; timer - 1
    jr nz,BonusSlot_Timeout_Speed  ; $2D11  ; not expired: skip
    ld a,$1E                       ; $2D13  ; a = $1E
    ld [hl],a                      ; $2D15  ; timer = $1E (reset)
    ld a,$05                       ; $2D16  ; a = 5
    ld [$C040],a                   ; $2D18  ; C040 = 5 (time-up flag)
    ld a,$08                       ; $2D1B  ; a = $08
    jp SoundEngine_PlayEffect      ; $2D1D  ; play sfx $08 (time out)

BonusSlot_Timeout_Speed:
    ld a,[hl]                      ; $2D20  ; speed by remaining time
    cp $14                         ; $2D21  ; timer >= $14?
    jr nc,BonusSlot_Timeout_Trig   ; $2D23  ; fast enough
    ld b,$04                       ; $2D25  ; b = 4
    cp $0A                         ; $2D27  ; >= $0A?
    jr nc,loc_2D2D                 ; $2D29  ; skip
    ld b,$02                       ; $2D2B  ; b = 2

loc_2D2D:
    ld a,b                         ; $2D2D  ; DD6D = speed
    ld [$DD6D],a                   ; $2D2E  ; DD6D = speed

BonusSlot_Timeout_Trig:
    ldh a,[$FFC1]                  ; $2D31  ; catch check: FFC1 bit6
    bit 6,a                        ; $2D33  ; test action button
    ret z                          ; $2D35  ; unpressed: ret
    call PlayerDelta               ; $2D36  ; player delta
    ld a,b                         ; $2D39  ; b + $04
    add $04                        ; $2D3A  ; +4
    cp $09                         ; $2D3C  ; >= 9?
    ret nc                         ; $2D3E  ; far: ret
    ld a,c                         ; $2D3F  ; c + $04
    add $04                        ; $2D40  ; +4
    cp $09                         ; $2D42  ; >= 9?
    ret nc                         ; $2D44  ; far: ret
    call Scroll_Start              ; $2D45  ; begin intro scroll
    ldh a,[$FF9C]                  ; $2D48  ; FF9C flags
    set 4,a                        ; $2D4A  ; bit4 set (caught)
    ldh [$FF9C],a                  ; $2D4C  ; FF9C = flags
    ret                            ; $2D4E  ; ret

BonusSlot_Catch:
    ld a,$02                       ; $2D4F  ; state 5: catch-up speed
    ld [$DD6D],a                   ; $2D51  ; DD6D = 2
    ld a,[$C049]                   ; $2D54  ; a = C049
    and a                          ; $2D57  ; == 0?
    ret z                          ; $2D58  ; done: ret
    dec a                          ; $2D59  ; timer - 1
    ld [$C049],a                   ; $2D5A  ; C049 = timer
    ld b,$03                       ; $2D5D  ; b = 3
    cp $14                         ; $2D5F  ; >= $14?
    jr nc,BonusSlot_Catch_Store    ; $2D61  ; skip
    dec b                          ; $2D63  ; b = 2
    cp $0A                         ; $2D64  ; >= $0A?
    jr nc,BonusSlot_Catch_Store    ; $2D66  ; skip
    dec b                          ; $2D68  ; b = 1

BonusSlot_Catch_Store:
    ld a,b                         ; $2D69  ; C041 = tier
    ld [$C041],a                   ; $2D6A  ; C041 = tier
    ret                            ; $2D6D  ; ret

BonusSlot_Anim:
    ld de,$C040                    ; $2D6E  ; draw bonus slot: de = C040
    ldh a,[$FF8A]                  ; $2D71  ; FF8A mode
    cp $06                         ; $2D73  ; == 6?
    ld hl,$2D86                    ; $2D75  ; hl = frame table A
    jr nz,BonusSlot_Anim_Go        ; $2D78  ; not mode 6: table A
    ld hl,$2DD4                    ; $2D7A  ; hl = frame table B

BonusSlot_Anim_Go:
    ld a,[$C041]                   ; $2D7D  ; a = C041 (index)
    call Table16_Get               ; $2D80  ; fetch frame ptr by index
    jp Slot_Show                   ; $2D83  ; draw sprite frame
    ; Bonus slot frame pointer table A (index by C041; FF8A != $06): [$2DA0,$2D90,$2DA1,$2DB2,$2DC3]
    db $A0,$2D,$90,$2D,$A1,$2D,$B2,$2D
    db $C3,$2D,$00,$FA,$2C,$80,$00,$02
    db $2D,$80,$08,$FA,$40,$80,$08,$02
    db $41,$80,$80,$00,$FA,$46,$80,$00
    db $02,$2D,$80,$08,$FA,$47,$80,$08
    db $02,$41,$80,$80,$00,$FA,$48,$80
    db $00,$02,$2D,$80,$08,$FA,$49,$80
    db $08,$02,$41,$80,$80,$00,$FA,$2E
    db $80,$00,$02,$2F,$80,$08,$FA,$42
    db $80,$08,$02,$43,$80,$80
    ; Bonus slot frame pointer table B (index by C041; FF8A == $06): [$2DE2,$2DDE,$2DE3,$2DE3,$2DE8]
    db $E2,$2D,$DE,$2D,$E3,$2D,$E3,$2D
    db $E8,$2D,$08,$FA,$CC,$00,$80,$08
    db $FA,$CE,$00,$80,$08,$FA,$CF,$00
    db $80

BonusSlot2_Dispatch:
    ld de,$C050                    ; $2DED  ; dispatch C050 bonus slot state machine
    ld hl,$C050                    ; $2DF0  ; hl = C050 (state)
    call State_DispatchGate        ; $2DF3  ; skip while scrolling or state < 2
    rst $10                        ; $2DF6  ; rst $10 table by C050 state
    dw $2DFF,$2E04,$2E0D,$2E47

BonusSlot2_Clr:
    xor a                          ; $2DFF  ; state 0: clear bonus slot 2
    ld [$C051],a                   ; $2E00  ; C051 = 0
    ret                            ; $2E03  ; ret

BonusSlot2_Spawn:
    call Slot_Place                ; $2E04  ; state 1: spawn bonus slot 2
    ld a,$02                       ; $2E07  ; a = 2
    ld [$C050],a                   ; $2E09  ; C050 = 2 (next state)
    ret                            ; $2E0C  ; ret

BonusSlot2_Check:
    ld a,[$C00D]                   ; $2E0D  ; state 2: check player at slot
    and a                          ; $2E10  ; a = [C00D] (level ready)
    jr z,BonusSlot2_Near           ; $2E11  ; == 0? skip
    cp $88                         ; $2E13  ; < $88?
    ret c                          ; $2E15  ; not ready: ret

BonusSlot2_Near:
    call PlayerDelta               ; $2E16  ; player delta (b,c)
    ld a,$02                       ; $2E19  ; a = 2
    add b                          ; $2E1B  ; + b
    cp $05                         ; $2E1C  ; >= 5 (far)?
    ret nc                         ; $2E1E  ; far: ret
    ld a,$02                       ; $2E1F  ; a = 2
    add c                          ; $2E21  ; + c
    cp $05                         ; $2E22  ; >= 5?
    ret nc                         ; $2E24  ; far: ret
    ld bc,$0250                    ; $2E25  ; bc = $0250 (points)
    call Score_AddBCD              ; $2E28  ; add score (BCD)
    ld hl,$0006                    ; $2E2B  ; hl = obj+6
    add hl,de                      ; $2E2E  ; + de
    ld a,[hl+]                     ; $2E2F  ; a = map addr lo
    ld c,a                         ; $2E30  ; c = lo
    ld a,[hl]                      ; $2E31  ; a = map addr hi
    ld b,a                         ; $2E32  ; b = hi
    push bc                        ; $2E33  ; push bc
    pop hl                         ; $2E34  ; hl = map address
    ld a,$05                       ; $2E35  ; a = 5
    call Level_QueuePush_Rel       ; $2E37  ; queue level op (clear cell)
    ld a,$03                       ; $2E3A  ; a = 3
    ld [$C040],a                   ; $2E3C  ; C040 = 3
    ld [$C050],a                   ; $2E3F  ; C050 = 3
    ld a,$0C                       ; $2E42  ; a = $0C
    jp Sfx_PlayC                   ; $2E44  ; play sfx $0C (collect)

BonusSlot2_Clr2:
    xor a                          ; $2E47  ; clear again
    ld [$C051],a                   ; $2E48  ; C051 = 0
    ret                            ; $2E4B  ; ret

BonusSlot2_Anim:
    ld a,[$C051]                   ; $2E4C  ; draw bonus slot 2: a = C051
    and a                          ; $2E4F  ; C051 == 0?
    ret z                          ; $2E50  ; inactive: ret
    ld de,$C050                    ; $2E51  ; de = C050
    ldh a,[$FF8A]                  ; $2E54  ; FF8A mode
    cp $06                         ; $2E56  ; == 6?
    ld hl,$2E63                    ; $2E58  ; frame data A
    jr nz,BonusSlot2_Anim_Go       ; $2E5B  ; not mode 6: data A
    ld hl,$2E70                    ; $2E5D  ; frame data B

BonusSlot2_Anim_Go:
    jp Slot_Show                   ; $2E60  ; draw sprite frame
    ; Bonus slot 2 frame data A (FF8A != $06)
    db $00,$FA,$77,$00,$00,$02,$78,$00
    db $08,$FE,$79,$00,$80
    ; Bonus slot 2 frame data B (FF8A == $06)
    db $08,$FA,$CD,$00,$80

Slot_Scan:
    ldh a,[$FFD4]                  ; $2E75  ; staggered slot scan (offset = frame & 3)
    and $03                        ; $2E77  ; FFD4 & 3

Slot_ScanLoop:
    ldh [$FFB3],a                  ; $2E79  ; loop start: seed FFB3 offset
    swap a                         ; $2E7B  ; swap (offset * 16)
    ld e,a                         ; $2E7D  ; e = offset
    ld d,$00                       ; $2E7E  ; d = 0
    ld hl,$C060                    ; $2E80  ; hl = C060 (slots)
    add hl,de                      ; $2E83  ; + offset*16
    push hl                        ; $2E84  ; push slot
    pop de                         ; $2E85  ; de = slot ptr
    call Slot_ScanSlot             ; $2E86  ; update slot
    ldh a,[$FFB3]                  ; $2E89  ; offset + 4
    add $04                        ; $2E8B  ; + 4
    cp $10                         ; $2E8D  ; >= $10 (all 4)?
    jr c,Slot_ScanLoop             ; $2E8F  ; scan next slot
    ret                            ; $2E91  ; ret

Slot_ScanSlot:
    ld hl,$0000                    ; $2E92  ; slot: state == 0?
    add hl,de                      ; $2E95  ; + de
    ld a,[hl]                      ; $2E96  ; a = state
    and a                          ; $2E97  ; != 0?
    jr nz,Slot_Update              ; $2E98  ; active: update
    xor a                          ; $2E9A  ; a = 0
    ld hl,$0001                    ; $2E9B  ; hl = slot+1
    add hl,de                      ; $2E9E  ; + de
    ld [hl],a                      ; $2E9F  ; flag = 0
    ret                            ; $2EA0  ; ret

Slot_Update:
    ldh a,[$FF96]                  ; $2EA1  ; slot update: pause while scroll (FF96)
    and a                          ; $2EA3  ; FF96 != 0?
    ret nz                         ; $2EA4  ; scrolling: ret
    ld hl,$0009                    ; $2EA5  ; hl = slot+9
    add hl,de                      ; $2EA8  ; + de
    ld a,[hl]                      ; $2EA9  ; a = slot+9 (count)
    cp $14                         ; $2EAA  ; >= $14?
    jr nc,Slot_Update_Hold         ; $2EAC  ; not near player: skip
    call PlayerDelta               ; $2EAE  ; player delta
    ld a,b                         ; $2EB1  ; b + $06
    add $06                        ; $2EB2  ; + 6
    cp $0D                         ; $2EB4  ; >= $0D (far)?
    jr nc,Slot_Update_Hold         ; $2EB6  ; far: skip
    ld a,c                         ; $2EB8  ; c + $06
    add $06                        ; $2EB9  ; + 6
    cp $0D                         ; $2EBB  ; >= $0D?
    jr nc,Slot_Update_Hold         ; $2EBD  ; far: skip
    call Player_Capture            ; $2EBF  ; trigger collect effect

Slot_Update_Hold:
    ld hl,$0009                    ; $2EC2  ; slot+9 == $C4?
    add hl,de                      ; $2EC5  ; hl = slot+9
    ld a,[hl]                      ; $2EC6
    cp $C4                         ; $2EC7  ; a = slot+9
    jr nz,Slot_Update_Tier         ; $2EC9  ; != $C4: skip
    ld bc,$0600                    ; $2ECB  ; bc = $0600 offset
    call Cell_Probe                ; $2ECE  ; probe cell
    ld a,$06                       ; $2ED1  ; a = 6
    ld [hl],a                      ; $2ED3  ; cell = 6 (solid)

Slot_Update_Tier:
    ld hl,$0009                    ; $2ED4  ; tier by count: slot+1
    add hl,de                      ; $2ED7  ; + de
    ld a,[hl]                      ; $2ED8  ; a = slot+9
    ld b,$01                       ; $2ED9  ; b = 1
    cp $05                         ; $2EDB  ; < $05?
    jr c,Slot_Update_Store         ; $2EDD  ; tier 1
    inc b                          ; $2EDF  ; b = 2
    cp $0A                         ; $2EE0  ; < $0A?
    jr c,Slot_Update_Store         ; $2EE2  ; tier 2
    inc b                          ; $2EE4  ; b = 3
    cp $0F                         ; $2EE5  ; < $0F?
    jr c,Slot_Update_Store         ; $2EE7  ; tier 3
    inc b                          ; $2EE9  ; b = 4
    cp $14                         ; $2EEA  ; < $14?
    jr c,Slot_Update_Store         ; $2EEC  ; tier 4
    inc b                          ; $2EEE  ; b = 5
    cp $19                         ; $2EEF  ; < $19?
    jr c,Slot_Update_Store         ; $2EF1  ; tier 5
    ld b,$01                       ; $2EF3  ; b = 1
    cp $CF                         ; $2EF5  ; >= $CF?
    jr nc,Slot_Update_Store        ; $2EF7  ; tier 1
    inc b                          ; $2EF9  ; b = 2
    cp $CC                         ; $2EFA  ; >= $CC?
    jr nc,Slot_Update_Store        ; $2EFC  ; tier 2
    inc b                          ; $2EFE  ; b = 3
    cp $C9                         ; $2EFF  ; >= $C9?
    jr nc,Slot_Update_Store        ; $2F01  ; tier 3
    inc b                          ; $2F03  ; b = 4
    cp $C6                         ; $2F04  ; >= $C6?
    jr nc,Slot_Update_Store        ; $2F06  ; tier 4
    inc b                          ; $2F08  ; b = 5
    cp $C3                         ; $2F09  ; >= $C3?
    jr nc,Slot_Update_Store        ; $2F0B  ; tier 5
    ld b,$00                       ; $2F0D  ; b = 0 (max tier)

Slot_Update_Store:
    ld a,b                         ; $2F0F  ; slot+1 = tier
    ld hl,$0001                    ; $2F10  ; hl = slot+1
    add hl,de                      ; $2F13  ; + de
    ld [hl],a                      ; $2F14  ; flag = tier
    ld hl,$0009                    ; $2F15  ; hl = slot+9
    add hl,de                      ; $2F18  ; + de
    dec [hl]                       ; $2F19  ; slot+9 - 2
    dec [hl]                       ; $2F1A  ; slot+9 - 2
    ret nz                         ; $2F1B  ; not 0 yet: ret
    ld hl,$0006                    ; $2F1C  ; hl = slot+6 (map addr)
    add hl,de                      ; $2F1F  ; + de
    ld a,[hl+]                     ; $2F20  ; a = lo
    ld h,[hl]                      ; $2F21  ; hl = map address
    ld l,a                         ; $2F22  ; hl = map address
    xor a                          ; $2F23  ; a = 0
    call Level_QueuePush_Rel       ; $2F24  ; queue level op (restore cell)
    xor a                          ; $2F27  ; a = 0
    ld hl,$0000                    ; $2F28  ; hl = slot+0
    add hl,de                      ; $2F2B  ; + de
    ld [hl],a                      ; $2F2C  ; state = 0
    ret                            ; $2F2D  ; ret

Slot_Draw:
    xor a                          ; $2F2E  ; draw all active C060 slots

Slot_DrawLoop:
    ldh [$FFB3],a                  ; $2F2F  ; slot loop: seed FFB3 offset
    swap a                         ; $2F31  ; swap (offset*16)
    ld e,a                         ; $2F33  ; e = offset
    ld d,$00                       ; $2F34  ; d = 0
    ld hl,$C060                    ; $2F36  ; hl = C060 (slots)
    add hl,de                      ; $2F39  ; + offset*16
    push hl                        ; $2F3A  ; push slot
    pop de                         ; $2F3B  ; de = slot ptr
    ld hl,$0001                    ; $2F3C  ; hl = slot+1
    add hl,de                      ; $2F3F  ; + de
    ld a,[hl]                      ; $2F40  ; a = active flag
    and a                          ; $2F41  ; == 0?
    jr z,Slot_Draw_Next            ; $2F42  ; inactive: next slot
    ldh a,[$FF8A]                  ; $2F44  ; FF8A mode
    cp $06                         ; $2F46  ; == 6?
    ld a,[hl]                      ; $2F48  ; a = flag (substate index)
    ld hl,$2F5F                    ; $2F49  ; hl = frame table A
    jr nz,Slot_Draw_Go             ; $2F4C  ; not mode 6: table A
    ld hl,$2F6B                    ; $2F4E  ; hl = frame table B

Slot_Draw_Go:
    call Table16_Get               ; $2F51  ; fetch frame ptr by substate
    call Slot_Show                 ; $2F54  ; draw sprite frame

Slot_Draw_Next:
    ldh a,[$FFB3]                  ; $2F57  ; FFB3 offset
    inc a                          ; $2F59  ; offset + 1
    cp $10                         ; $2F5A  ; >= $10 (all 16)?
    jr c,Slot_DrawLoop             ; $2F5C  ; draw next slot
    ret                            ; $2F5E  ; ret
    ; Slot frame pointer table A (index by slot+1 substate; FF8A != $06): [$2F87,$2F77,$2F88,$2F99,$2FAA]
    db $87,$2F,$77,$2F,$88,$2F,$99,$2F
    db $AA,$2F,$B3,$2F
    ; Slot frame pointer table B (index by slot+1 substate; FF8A == $06): [$2F87,$2FBC,$2FC1,$2FC6,$2FCB]
    db $87,$2F,$BC,$2F,$C1,$2F,$C6,$2F
    db $CB,$2F,$D0,$2F
    ; Slot sprite frame / animation data
    db $00,$FA,$3D,$00,$00,$02,$3E,$00
    db $08,$FA,$44,$00,$08,$02,$45,$00
    db $80,$00,$FA,$3F,$00,$00,$02,$4A
    db $00,$08,$FA,$44,$00,$08,$02,$45
    db $00,$80,$00,$FA,$4B,$00,$00,$02
    db $4C,$00,$08,$FA,$44,$00,$08,$02
    db $45,$00,$80,$08,$FA,$4D,$00,$08
    db $02,$4E,$00,$80,$08,$FA,$4F,$00
    db $08,$02,$76,$00,$80,$08,$FA,$BB
    db $00,$80,$08,$FA,$BC,$00,$80,$08
    db $FA,$BD,$00,$80,$08,$FA,$BE,$00
    db $80,$08,$FA,$BF,$00,$80

Slot_ScanAll:
    xor a                          ; $2FD5  ; Slot_ScanAll: iterate all 16 slots (C060+idx*16); FFB3 = slot index

Slot_ScanAll_Next:
    ldh [$FFB3],a                  ; $2FD6  ; FFB3 = current slot index
    swap a                         ; $2FD8  ; index*16 -> slot object offset
    ld e,a                         ; $2FDA  ; e = low byte of offset
    ld d,$00                       ; $2FDB  ; d = 0
    ld hl,$C060                    ; $2FDD  ; slot buffer base C060
    add hl,de                      ; $2FE0  ; hl = slot address
    push hl                        ; $2FE1  ; copy slot address to de
    pop de                         ; $2FE2  ; de = slot address
    call Slot_Spawn                ; $2FE3  ; spawn into this slot if it is empty
    ldh a,[$FFB3]                  ; $2FE6  ; a = slot index
    inc a                          ; $2FE8  ; next slot
    cp $10                         ; $2FE9  ; all 16 slots scanned?
    jr c,Slot_ScanAll_Next         ; $2FEB  ; loop
    ret                            ; $2FED  ; no empty slot found

Slot_Spawn:
    ld hl,$0000                    ; $2FEE  ; Slot_Spawn: check slot state at obj+$00
    add hl,de                      ; $2FF1  ; obj+$00
    ld a,[hl]                      ; $2FF2  ; slot state
    and a                          ; $2FF3  ; occupied?
    ret nz                         ; $2FF4  ; occupied: return to scan loop normally
    inc [hl]                       ; $2FF5  ; state = 1 (spawning)
    ld a,$D2                       ; $2FF6  ; frame/tile $D2
    ld hl,$0009                    ; $2FF8  ; obj+$09
    add hl,de                      ; $2FFB  ; obj+$09
    ld [hl],a                      ; $2FFC  ; obj+9 = $D2
    ld a,c                         ; $2FFD  ; packed X coord (from caller)
    ld hl,$0006                    ; $2FFE  ; obj+$06
    add hl,de                      ; $3001  ; obj+$06
    ld [hl+],a                     ; $3002  ; obj+6 = X cell
    ld a,b                         ; $3003  ; packed Y coord
    ld [hl],a                      ; $3004  ; obj+7 = Y cell
    call Slot_Place                ; $3005  ; place: compute screen X/Y from packed coords
    pop af                         ; $3008  ; drop the call's return address so control returns to the caller of Slot_ScanAll (a = FFB3 = slot index below)
    ldh a,[$FFB3]                  ; $3009  ; slot index handled in a (returned to Slot_ScanAll caller)
    ret                            ; $300B  ; return on top of Slot_ScanAll's own return

Slot_Place:
    ld hl,$0007                    ; $300C  ; Slot_Place: unpack packed map coordinate in obj+6/obj+7 to screen X (obj+5) and Y (obj+3), activate slot
    add hl,de                      ; $300F  ; obj+$07
    ld a,[hl]                      ; $3010  ; low packed coord
    ld c,a                         ; $3011  ; c = low
    ld hl,$0006                    ; $3012  ; obj+$06
    add hl,de                      ; $3015  ; obj+$06
    ld a,[hl]                      ; $3016  ; high packed coord
    srl c                          ; $3017  ; combine obj+6/obj+7 into 16-bit packed value and shift right 1
    rr a                           ; $3019  ; a = packed >> 1 (low byte)
    rl c                           ; $301B  ; c = high bits
    ld b,$00                       ; $301D  ; column counter = 0

Slot_Place_ColLoop:
    cp $09                         ; $301F  ; divide packed by $09: column index
    jr c,Slot_Place_Store          ; $3021  ; remainder reached
    sub $09                        ; $3023  ; subtract one column
    inc b                          ; $3025  ; column++
    jr Slot_Place_ColLoop          ; $3026  ; loop

Slot_Place_Store:
    push af                        ; $3028  ; remainder saved (row within cell)
    sla b                          ; $3029  ; column * 12
    sla b                          ; $302B  ; column * 2
    ld a,b                         ; $302D  ; column * 4
    sla b                          ; $302E  ; column * 8
    add b                          ; $3030  ; column * 12
    ld hl,$0005                    ; $3031  ; obj+$05
    add hl,de                      ; $3034  ; obj+$05
    ld [hl],a                      ; $3035  ; obj+5 = screen X
    pop af                         ; $3036  ; restore remainder
    sla a                          ; $3037  ; combine remainder with carried high bits
    add c                          ; $3039  ; + carried bits
    sla a                          ; $303A  ; *2
    sla a                          ; $303C  ; *4
    ld c,a                         ; $303E  ; save
    sla a                          ; $303F  ; *8 for *6 total
    add c                          ; $3041  ; total *6
    add $16                        ; $3042  ; +$16 (sprite/map offset)
    ld hl,$0003                    ; $3044  ; obj+$03
    add hl,de                      ; $3047  ; obj+$03
    ld [hl],a                      ; $3048  ; obj+3 = screen Y
    xor a                          ; $3049  ; 0
    ld hl,$0002                    ; $304A  ; obj+$02
    add hl,de                      ; $304D  ; obj+$02
    ld [hl],a                      ; $304E  ; clear Y fraction (16-bit Y at obj+2/obj+3)
    ld hl,$0004                    ; $304F  ; obj+$04
    add hl,de                      ; $3052  ; obj+$04
    ld [hl],a                      ; $3053  ; clear X fraction (16-bit X at obj+4/obj+5)
    inc a                          ; $3054  ; 1
    ld hl,$0001                    ; $3055  ; obj+$01
    add hl,de                      ; $3058  ; obj+$01
    ld [hl],a                      ; $3059  ; obj+1 = 1 (active)
    ret                            ; $305A  ; return

Slot_Show:
    push hl                        ; $305B  ; Slot_Show: draw slot sprite via OAM (X=b, Y=c -> loc_3CCC)
    ld hl,$0005                    ; $305C  ; obj+$05
    add hl,de                      ; $305F  ; obj+$05
    ldh a,[$FF8A]                  ; $3060  ; game mode
    cp $06                         ; $3062  ; mode $06 (special layout)?
    jr z,Slot_Show_Special         ; $3064  ; yes: special coordinate conversion
    ld a,[hl]                      ; $3066  ; X
    ld b,a                         ; $3067  ; b = X
    ld hl,$0003                    ; $3068  ; obj+$03
    add hl,de                      ; $306B  ; obj+$03
    ld a,[hl]                      ; $306C  ; Y
    ld c,a                         ; $306D  ; c = Y
    pop hl                         ; $306E  ; restore sprite pointer
    jp Oam_PutFrameScroll          ; $306F  ; OAM place

Slot_Show_Special:
    ld a,[hl]                      ; $3072  ; Slot_Show_Special: convert tile coords to pixels for the special (5x9) layout
    push af                        ; $3073  ; save X
    ld hl,$0003                    ; $3074  ; obj+$03
    add hl,de                      ; $3077  ; obj+$03
    ld a,[hl]                      ; $3078  ; Y
    ld e,$08                       ; $3079  ; multiplier 8
    call Mul16_AxDE                ; $307B  ; Y*8 (loc_3D68)
    ld a,$0C                       ; $307E  ; divisor $0C
    call Div16_Mod                 ; $3080  ; Y*8/$0C (pixel row)
    pop af                         ; $3083  ; restore X
    push hl                        ; $3084  ; save Y result
    ld e,$08                       ; $3085  ; multiplier 8
    call Mul16_AxDE                ; $3087  ; X*8
    ld a,$0C                       ; $308A  ; divisor $0C
    call Div16_Mod                 ; $308C  ; X*8/$0C (pixel column)
    ld b,l                         ; $308F  ; b = X pixel
    pop hl                         ; $3090  ; Y result
    ld c,l                         ; $3091  ; c = Y pixel
    pop hl                         ; $3092  ; restore sprite pointer
    jp Oam_PutFrameScroll          ; $3093  ; OAM place

Probe_XY:
    ld c,a                         ; $3096  ; Probe_XY: cell probe from global base FFE0 (X) with Y offset in a
    ldh a,[$FFE0]                  ; $3097  ; X base from FFE0
    ld b,a                         ; $3099  ; b = X
    ld a,c                         ; $309A  ; Y offset
    jr Cell_Probe_Check            ; $309B  ; continue validation/map lookup

Cell_Probe:
    ld hl,$0005                    ; $309D  ; Cell_Probe: b/X offset c/Y offset against object -> a = cell value, b = X in cell, c = Y in cell
    add hl,de                      ; $30A0  ; obj+$05
    ld a,[hl]                      ; $30A1  ; obj X
    add b                          ; $30A2  ; X + offset
    cp $C0                         ; $30A3  ; screen bounds
    jr nc,Cell_OOB                 ; $30A5  ; out: return wall sentinel

loc_30A7:
    ld b,a                         ; $30A7  ; b = query X
    ld hl,$0003                    ; $30A8  ; obj+$03
    add hl,de                      ; $30AB  ; obj+$03
    ld a,[hl]                      ; $30AC  ; obj Y
    add c                          ; $30AD  ; Y + offset

Cell_Probe_Check:
    cp $10                         ; $30AE  ; Y within play area ($10-$E7)?
    jr c,Cell_OOB                  ; $30B0  ; above: wall sentinel
    cp $E8                         ; $30B2  ; below
    jr nc,Cell_OOB                 ; $30B4  ; below: wall sentinel
    ld c,a                         ; $30B6  ; c = query Y

Cell_MapLookup:
    push de                        ; $30B7  ; Cell_MapLookup: map cell at (b=X, c=Y); row stride $12, two halves of $6C rows
    ld a,b                         ; $30B8  ; a = X
    ld hl,$C96B                    ; $30B9  ; map base C96B
    ld de,$0012                    ; $30BC  ; row stride $12
    cp $60                         ; $30BF  ; left half (< $60)?
    jr c,Cell_MapLookup_Col        ; $30C1  ; skip
    sub $60                        ; $30C3  ; right half base
    ld hl,$C9FB                    ; $30C5  ; second half of map C9FB

Cell_MapLookup_Col:
    sub $0C                        ; $30C8  ; advance stride per column
    jr c,Cell_MapLookup_Row        ; $30CA  ; column done
    add hl,de                      ; $30CC  ; next column line
    jr Cell_MapLookup_Col          ; $30CD  ; loop

Cell_MapLookup_Row:
    add $0C                        ; $30CF  ; b = X within cell (mod $0C)
    ld b,a                         ; $30D1  ; b = X mod $0C
    ld a,c                         ; $30D2  ; Y
    sub $10                        ; $30D3  ; Y - $10 (map area offset)
    cp $6C                         ; $30D5  ; top half (< $6C)?
    jr c,Cell_MapLookup_RowLoop    ; $30D7  ; skip
    sub $6C                        ; $30D9  ; bottom half
    ld de,$0009                    ; $30DB  ; row half stride $09
    add hl,de                      ; $30DE  ; second row half

Cell_MapLookup_RowLoop:
    sub $0C                        ; $30DF  ; advance one row per $0C
    jr c,Cell_MapLookup_Get        ; $30E1  ; row done
    inc hl                         ; $30E3  ; next row
    jr Cell_MapLookup_RowLoop      ; $30E4  ; loop

Cell_MapLookup_Get:
    add $0C                        ; $30E6  ; c = Y mod $0C (within cell)
    ld c,a                         ; $30E8  ; c = Y mod $0C
    ld a,[hl]                      ; $30E9  ; cell value
    pop de                         ; $30EA  ; restore de
    ret                            ; $30EB  ; return cell in a

Cell_OOB:
    ld a,$01                       ; $30EC  ; Cell_OOB: out-of-bounds/solid sentinel: cell $01, offsets 0
    ld bc,$0000                    ; $30EE  ; zero offsets
    ret                            ; $30F1  ; return

PlayerDelta:
    push de                        ; $30F2  ; PlayerDelta: b = playerX - objX, c = playerY - objY (player at C000)
    ld hl,$0003                    ; $30F3  ; obj+$03
    add hl,de                      ; $30F6  ; obj+$03
    ld a,[hl]                      ; $30F7  ; obj Y
    ld c,a                         ; $30F8  ; c = obj Y
    ld hl,$0005                    ; $30F9  ; obj+$05
    add hl,de                      ; $30FC  ; obj+$05
    ld a,[hl]                      ; $30FD  ; obj X
    ld b,a                         ; $30FE  ; b = obj X
    ld de,$C000                    ; $30FF  ; player object C000
    ld hl,$0003                    ; $3102  ; player+$03
    add hl,de                      ; $3105  ; player+$03
    ld a,[hl]                      ; $3106  ; player Y
    sub c                          ; $3107  ; playerY - objY
    ld c,a                         ; $3108  ; c = Y delta
    ld hl,$0005                    ; $3109  ; player+$05
    add hl,de                      ; $310C  ; player+$05
    ld a,[hl]                      ; $310D  ; player X
    sub b                          ; $310E  ; playerX - objX
    ld b,a                         ; $310F  ; b = X delta
    pop de                         ; $3110  ; restore de
    ret                            ; $3111  ; return

Player_Capture:
    ld a,[$C000]                   ; $3112  ; Player_Capture: guard touched player -> capture
    cp $05                         ; $3115  ; player state 5 (captured)?
    ret z                          ; $3117  ; already captured: ret
    cp $06                         ; $3118  ; player state 6 (climbing)?
    ret z                          ; $311A  ; climbing: immune, ret
    ldh a,[$FFAA]                  ; $311B  ; lives counter FFAA
    dec a                          ; $311D  ; lose one life
    ldh [$FFAA],a                  ; $311E  ; FFAA--
    xor a                          ; $3120  ; 0
    ld [$C009],a                   ; $3121  ; clear player timer C009
    ld a,$05                       ; $3124  ; state 5
    ld [$C000],a                   ; $3126  ; C000 = 5 (captured)
    ld a,$15                       ; $3129  ; capture effect
    jp SoundEngine_PlayEffect      ; $312B  ; play capture sfx, never return here

Vel_AddX:
    ld hl,$000B                    ; $312E  ; Vel_AddX: 16-bit X at obj+4/obj+5 += velocity byte at obj+$0B (low nibble = frac, high nibble = int)
    add hl,de                      ; $3131  ; obj+$0B
    ld a,[hl]                      ; $3132  ; velocity byte
    and $0F                        ; $3133  ; low nibble = X fraction
    ld b,a                         ; $3135  ; b = fraction
    ld a,[hl]                      ; $3136  ; velocity byte
    and $F0                        ; $3137  ; high nibble = X integer
    ld hl,$0004                    ; $3139  ; obj+$04 (16-bit X accumulator)
    add hl,de                      ; $313C  ; obj+$04
    add [hl]                       ; $313D  ; add fraction byte
    ld [hl+],a                     ; $313E  ; store low, hl -> high
    ld a,[hl]                      ; $313F  ; high byte
    adc b                          ; $3140  ; add integer + carry
    ld [hl],a                      ; $3141  ; store high
    ret                            ; $3142  ; return

Vel_SubX:
    ld hl,$000B                    ; $3143  ; Vel_SubX: X 16-bit at obj+4/obj+5 -= velocity byte at obj+$0B
    add hl,de                      ; $3146  ; obj+$0B
    ld a,[hl]                      ; $3147  ; velocity byte
    and $0F                        ; $3148  ; fraction
    ld b,a                         ; $314A  ; b = fraction
    ld a,[hl]                      ; $314B  ; velocity byte
    and $F0                        ; $314C  ; integer
    ld c,a                         ; $314E  ; c = integer
    ld hl,$0004                    ; $314F  ; obj+$04
    add hl,de                      ; $3152  ; obj+$04
    ld a,[hl]                      ; $3153  ; low byte
    sub c                          ; $3154  ; subtract fraction
    ld [hl+],a                     ; $3155  ; store low, hl -> high
    ld a,[hl]                      ; $3156  ; high byte
    sbc b                          ; $3157  ; subtract integer + borrow
    ld [hl],a                      ; $3158  ; store high
    ret                            ; $3159  ; return

Vel_AddY:
    ld hl,$000A                    ; $315A  ; Vel_AddY: 16-bit Y at obj+2/obj+3 += velocity byte at obj+$0A (low nibble frac, high nibble int)
    add hl,de                      ; $315D  ; obj+$0A
    ld a,[hl]                      ; $315E  ; velocity byte
    and $0F                        ; $315F  ; fraction
    ld b,a                         ; $3161  ; b = fraction
    ld a,[hl]                      ; $3162  ; velocity byte
    and $F0                        ; $3163  ; integer
    ld hl,$0002                    ; $3165  ; obj+$02 (16-bit Y accumulator)
    add hl,de                      ; $3168  ; obj+$02
    add [hl]                       ; $3169  ; add fraction
    ld [hl+],a                     ; $316A  ; store low, hl -> high
    ld a,[hl]                      ; $316B  ; high byte
    adc b                          ; $316C  ; add integer + carry
    ld [hl],a                      ; $316D  ; store high
    ret                            ; $316E  ; return

Vel_SubY:
    ld hl,$000A                    ; $316F  ; Vel_SubY: Y 16-bit at obj+2/obj+3 -= velocity byte at obj+$0A
    add hl,de                      ; $3172  ; obj+$0A
    ld a,[hl]                      ; $3173  ; velocity byte
    and $0F                        ; $3174  ; fraction
    ld b,a                         ; $3176  ; b = fraction
    ld a,[hl]                      ; $3177  ; velocity byte
    and $F0                        ; $3178  ; integer
    ld c,a                         ; $317A  ; c = integer
    ld hl,$0002                    ; $317B  ; obj+$02
    add hl,de                      ; $317E  ; obj+$02
    ld a,[hl]                      ; $317F  ; low byte
    sub c                          ; $3180  ; subtract fraction
    ld [hl+],a                     ; $3181  ; store low, hl -> high
    ld a,[hl]                      ; $3182  ; high byte
    sbc b                          ; $3183  ; subtract integer + borrow
    ld [hl],a                      ; $3184  ; store high
    ret                            ; $3185  ; return

Move_AlignX:
    ld hl,$0005                    ; $3186  ; Move_AlignX: snap X to $0C cell centers by +/- velocity
    add hl,de                      ; $3189  ; obj+$05
    ld a,[hl]                      ; $318A  ; X
    call CellIndex_BC              ; $318B  ; X/$0C (b) + X mod $0C (a)
    and a                          ; $318E  ; aligned already?
    ret z                          ; $318F  ; centered: ret
    cp $06                         ; $3190  ; offset less than half cell?
    jr c,Vel_SubX                  ; $3192  ; below center: X -= velocity
    jr Vel_AddX                    ; $3194  ; above center: X += velocity

Cell_YOffset:
    ld hl,$0003                    ; $3196  ; Cell_YOffset: c = (Y-$10) mod $0C (vertical offset within current cell)
    add hl,de                      ; $3199  ; obj+$03
    ld a,[hl]                      ; $319A  ; Y
    sub $10                        ; $319B  ; Y - $10 (map offset)
    call CellIndex_BC              ; $319D  ; mod $0C
    ld c,a                         ; $31A0  ; c = offset
    ret                            ; $31A1  ; return

Move_SteerY:
    call Cell_YOffset              ; $31A2  ; Move_SteerY: nudge vertical position toward cell center (offset $06)
    cp $07                         ; $31A5  ; offset >= 7 (below center)?
    jr nc,Vel_SubY                 ; $31A7  ; move up: Y -= velocity
    cp $06                         ; $31A9  ; offset < 6 (above center)?
    jr c,Vel_AddY                  ; $31AB  ; move down: Y += velocity
    ret                            ; $31AD  ; centered: ret

Move_Bit7:
    bit 7,a                        ; $31AE  ; Move_Bit7: FFC1 bit7 input - step toward +X (probe (X+$0C, Y))
    jr z,Move_Bit6                 ; $31B0  ; bit7 clear: check bit6 (Move_Bit6)
    ld bc,$0C00                    ; $31B2  ; probe (X+$0C, Y): cell to the right
    call Cell_Probe                ; $31B5  ; cell probe
    cp $02                         ; $31B8  ; cell ahead
    jr nc,Move_Bit7_Step           ; $31BA  ; open (>= 2): step
    ld a,b                         ; $31BC  ; X offset in cell
    and a                          ; $31BD  ; edge-aligned?
    ret z                          ; $31BE  ; blocked at cell edge: stop

Move_Bit7_Step:
    call Vel_AddX                  ; $31BF  ; advance: X += velocity

Move_Step_End:
    pop af                         ; $31C2  ; drop move return address -> callers after the move call are skipped
    call Move_SteerY               ; $31C3  ; steer Y to cell center
    ld b,$15                       ; $31C6  ; frame base $15
    call Obj_SetFrame              ; $31C8  ; set sprite frame
    ld a,e                         ; $31CB  ; player is slot 0 (de low = 0)?
    cp $00                         ; $31CC  ; e == 0?
    ret nz                         ; $31CE  ; not player: no footstep sfx
    ldh a,[$FFD4]                  ; $31CF  ; global frame counter
    and $0F                        ; $31D1  ; every 16 frames
    ret nz                         ; $31D3  ; skip
    ld a,$05                       ; $31D4  ; footstep effect
    jp SoundEngine_PlayEffect      ; $31D6  ; play footstep

Move_Bit6:
    bit 6,a                        ; $31D9  ; Move_Bit6: FFC1 bit6 input - step toward -X (probe (X-1, Y))
    ret z                          ; $31DB  ; bit6 clear: ret
    ld bc,$FF00                    ; $31DC  ; probe (X-1, Y): cell to the left
    call Cell_Probe                ; $31DF  ; cell probe
    cp $02                         ; $31E2  ; cell ahead
    ret c                          ; $31E4  ; blocked: stop
    ld hl,$000C                    ; $31E5  ; own cell type obj+$0C
    add hl,de                      ; $31E8  ; obj+$0C
    ld a,[hl]                      ; $31E9  ; own cell
    cp $02                         ; $31EA  ; on ladder?
    jr z,Move_Bit6_Step            ; $31EC  ; ladder: step
    ld a,b                         ; $31EE  ; X offset in cell
    cp $0B                         ; $31EF  ; at right edge ($0B)?
    ret z                          ; $31F1  ; stop

Move_Bit6_Step:
    call Vel_SubX                  ; $31F2  ; step: X -= velocity
    jr Move_Step_End               ; $31F5  ; finish (pop, steer, frame)

Move_Bit5:
    bit 5,a                        ; $31F7  ; Move_Bit5: FFC1 bit5 input - step toward -Y (probe (X+4, Y-7) / (X+8, Y-7))
    jr z,Move_Bit4                 ; $31F9  ; bit5 clear: check bit4 (Move_Bit4)
    ld hl,$0008                    ; $31FB  ; obj+$08
    add hl,de                      ; $31FE  ; obj+$08
    ld [hl],a                      ; $31FF  ; cache input in obj+8
    ld bc,$04F9                    ; $3200  ; probe (X+4, Y-7): cell above sprite center
    call Cell_Probe                ; $3203  ; cell probe
    and $0F                        ; $3206  ; cell low nibble
    cp $02                         ; $3208  ; cell type
    ret c                          ; $320A  ; solid: stop
    cp $07                         ; $320B  ; blocking type $07?
    ret z                          ; $320D  ; stop
    ld bc,$08F9                    ; $320E  ; probe (X+8, Y-7): cell above sprite right
    call Cell_Probe                ; $3211  ; cell probe
    and $0F                        ; $3214  ; cell low nibble
    cp $02                         ; $3216  ; cell type
    ret c                          ; $3218  ; solid: stop
    cp $07                         ; $3219  ; blocking type $07?
    ret z                          ; $321B  ; stop
    call Vel_SubY                  ; $321C  ; move up: Y -= velocity

Move_Vert_End:
    pop af                         ; $321F  ; drop move return address -> callers after the move call are skipped
    call Move_AlignX               ; $3220  ; align X to cell center
    ld hl,$000C                    ; $3223  ; own cell type obj+$0C
    add hl,de                      ; $3226  ; obj+$0C
    ld a,[hl]                      ; $3227  ; own cell
    cp $03                         ; $3228  ; type $03?
    ld b,$05                       ; $322A  ; frame base $05
    jr z,Move_FrameSet             ; $322C  ; picked
    ld b,$0D                       ; $322E  ; frame base $0D

Move_FrameSet:
    call Obj_SetFrame              ; $3230  ; set sprite frame
    ld a,e                         ; $3233  ; player slot 0?
    cp $00                         ; $3234  ; e == 0?
    ret nz                         ; $3236  ; not player: ret
    ldh a,[$FFD4]                  ; $3237  ; frame counter
    and $0F                        ; $3239  ; every 16 frames
    ret nz                         ; $323B  ; skip
    ld hl,$000C                    ; $323C  ; own cell type obj+$0C
    add hl,de                      ; $323F  ; obj+$0C
    ld a,[hl]                      ; $3240  ; own cell
    cp $03                         ; $3241  ; type $03?
    ld a,$02                       ; $3243  ; effect $02
    jr z,Move_StepSfx              ; $3245  ; selected
    ld a,$0B                       ; $3247  ; effect $0B

Move_StepSfx:
    jp SoundEngine_PlayEffect      ; $3249  ; play footstep (different pitch by cell type)

Move_Bit4:
    bit 4,a                        ; $324C  ; Move_Bit4: FFC1 bit4 input - step toward +Y (probe (X+4, Y+6) / (X+8, Y+6))
    ret z                          ; $324E  ; bit4 clear: ret
    ld hl,$0008                    ; $324F  ; obj+$08
    add hl,de                      ; $3252  ; obj+$08
    ld [hl],a                      ; $3253  ; cache input in obj+8
    ld bc,$0406                    ; $3254  ; probe (X+4, Y+6): cell below sprite center
    call Cell_Probe                ; $3257  ; cell probe
    and $0F                        ; $325A  ; cell low nibble
    cp $02                         ; $325C  ; cell type
    ret c                          ; $325E  ; solid: stop
    cp $07                         ; $325F  ; blocking type $07?
    ret z                          ; $3261  ; stop
    ld bc,$0806                    ; $3262  ; probe (X+8, Y+6): cell below sprite right
    call Cell_Probe                ; $3265  ; cell probe
    and $0F                        ; $3268  ; cell low nibble
    cp $02                         ; $326A  ; cell type
    ret c                          ; $326C  ; solid: stop
    cp $07                         ; $326D  ; blocking type $07?
    ret z                          ; $326F  ; stop
    call Vel_AddY                  ; $3270  ; move down: Y += velocity
    jp Move_Vert_End               ; $3273  ; finish vertical move

Move_EdgeDrop:
    ld hl,$000C                    ; $3276  ; Move_EdgeDrop: auto walk-off ledges (called ahead of climb check); probes (X+$0C, Y)
    add hl,de                      ; $3279  ; obj+$0C
    ld a,[hl]                      ; $327A  ; own cell type
    cp $02                         ; $327B  ; on ladder?
    ret z                          ; $327D  ; no drop
    cp $03                         ; $327E  ; type $03?
    jr nz,Move_EdgeDrop_Probe      ; $3280  ; skip
    ld a,b                         ; $3282  ; X offset
    cp $06                         ; $3283  ; offset $06?
    ret z                          ; $3285  ; no drop

Move_EdgeDrop_Probe:
    ld bc,$0C00                    ; $3286  ; probe (X+$0C, Y): cell to the right
    call Cell_Probe                ; $3289  ; cell probe
    cp $03                         ; $328C  ; cell type
    ret c                          ; $328E  ; solid: stop
    and $FE                        ; $328F  ; mask low bit
    cp $06                         ; $3291  ; empty cell type $06?
    jr z,Move_EdgeDrop_Step        ; $3293  ; gap ahead: drop
    ldh a,[$FFC1]                  ; $3295  ; input FFC1
    and $30                        ; $3297  ; horizontal input bits
    jr z,Move_EdgeDrop_Step        ; $3299  ; no input: still drop
    bit 5,a                        ; $329B  ; input bit5?
    ld bc,$0CFE                    ; $329D  ; probe (X+$0C, Y-2)
    jr nz,Move_EdgeDrop_Side       ; $32A0  ; selected
    ld bc,$0C02                    ; $32A2  ; probe (X+$0C, Y+2)

Move_EdgeDrop_Side:
    call Cell_Probe                ; $32A5  ; cell probe
    cp $03                         ; $32A8  ; cell type
    ret c                          ; $32AA  ; solid: stop

Move_EdgeDrop_Step:
    pop af                         ; $32AB  ; drop: X += velocity
    call Vel_AddX                  ; $32AC  ; X += velocity
    ld b,$1D                       ; $32AF  ; frame base $1D
    call Obj_SetFrame              ; $32B1  ; set sprite frame
    call Move_SteerY               ; $32B4  ; steer Y
    ldh a,[$FFD4]                  ; $32B7  ; frame counter
    and $07                        ; $32B9  ; every 8 frames
    ret nz                         ; $32BB  ; skip
    inc a                          ; $32BC  ; effect 1
    jp SoundEngine_PlayEffect      ; $32BD  ; play drop sfx

Guard_FallCheck:
    ld hl,$000C                    ; $32C0  ; Guard_FallCheck: guard walking edge/trap check (called $254F)
    add hl,de                      ; $32C3  ; obj+$0C
    ld a,[hl]                      ; $32C4  ; own cell type
    cp $02                         ; $32C5  ; on ladder?
    ret z                          ; $32C7  ; no check
    cp $03                         ; $32C8  ; type $03?
    jr nz,Guard_FallCheck_Probe    ; $32CA  ; skip
    ld a,b                         ; $32CC  ; X offset
    cp $06                         ; $32CD  ; offset $06?
    ret z                          ; $32CF  ; no fall

Guard_FallCheck_Probe:
    ld bc,$0C00                    ; $32D0  ; probe (X+$0C, Y): cell to the right
    call Cell_Probe                ; $32D3  ; cell probe
    cp $03                         ; $32D6  ; cell type
    ret c                          ; $32D8  ; solid: stop
    and $FE                        ; $32D9  ; mask low bit
    cp $06                         ; $32DB  ; empty cell type $06?
    jr z,Guard_Trap                ; $32DD  ; hole below: trap

Guard_FallCheck_Step:
    pop af                         ; $32DF  ; fall: X += velocity
    call Vel_AddX                  ; $32E0  ; X += velocity
    ld b,$1D                       ; $32E3  ; frame base $1D
    call Obj_SetFrame              ; $32E5  ; set sprite frame
    jp Move_SteerY                 ; $32E8  ; steer Y

Guard_Trap:
    xor a                          ; $32EB  ; Guard_Trap: guard fell into a hole - respawn + award player point
    ld hl,$0009                    ; $32EC  ; obj+$09
    add hl,de                      ; $32EF  ; obj+$09
    ld [hl],a                      ; $32F0  ; clear timer
    ld a,$04                       ; $32F1  ; state 4
    ld hl,$0000                    ; $32F3  ; obj+$00
    add hl,de                      ; $32F6  ; obj+$00
    ld [hl],a                      ; $32F7  ; guard state = 4 (respawn)
    ld bc,$0050                    ; $32F8  ; +$50 score to player
    call Score_AddBCD              ; $32FB  ; BCD score add
    jr Guard_FallCheck_Step        ; $32FE  ; continue fall move

Obj_SetFrame:
    ldh a,[$FFD4]                  ; $3300  ; Obj_SetFrame: sprite frame = b + ((global frame counter >> 2) & 6) at obj+1
    and $18                        ; $3302  ; frame counter bits 3-4
    srl a                          ; $3304  ; >> 1
    srl a                          ; $3306  ; >> 2 (0,2,4,6)
    add b                          ; $3308  ; + frame base
    ld hl,$0001                    ; $3309  ; obj+$01
    add hl,de                      ; $330C  ; obj+$01
    ld [hl],a                      ; $330D  ; store frame
    ret                            ; $330E  ; return

Map_ScratchRow:
    push af                        ; $330F  ; Map_ScratchRow: copy a $0C map column window into scratch buffer (C92F/C943) for collision/gfx
    add $0C                        ; $3310  ; X + $0C (right edge)
    ld hl,$C943                    ; $3312  ; scratch buffer C943
    call Map_ScratchRow_Copy       ; $3315  ; copy column run
    pop af                         ; $3318  ; restore X

loc_3319:
    ld hl,$C92F                    ; $3319  ; scratch buffer C92F (X itself)

Map_ScratchRow_Copy:
    push de                        ; $331C  ; copy 9-cell window at column into scratch hl
    cp $C0                         ; $331D  ; off right edge?
    jr nc,Map_ScratchRow_Fill      ; $331F  ; fill with walls
    call CellIndex_BC              ; $3321  ; column index b, X mod $0C in a
    ld a,b                         ; $3324  ; column base
    sla a                          ; $3325  ; *2
    ld c,a                         ; $3327  ; c = *2
    sla a                          ; $3328  ; *4
    sla a                          ; $332A  ; *8
    sla a                          ; $332C  ; *16
    add c                          ; $332E  ; + *2 = *18 (=$12 row stride * col)
    ld c,a                         ; $332F  ; c = offset
    ld b,$00                       ; $3330  ; 0
    rl b                           ; $3332  ; carry out to upper byte
    push hl                        ; $3334  ; scratch addr
    pop de                         ; $3335  ; de = scratch
    ld hl,$C96B                    ; $3336  ; map base C96B
    add hl,bc                      ; $3339  ; row address
    ld a,$01                       ; $333A  ; wall byte $01
    ld [de],a                      ; $333C  ; left sentinel
    inc de                         ; $333D  ; advance
    ld b,$09                       ; $333E  ; 9 cells (18 bytes)

Map_ScratchRow_Loop:
    ld a,[hl+]                     ; $3340  ; copy cell word
    ld [de],a                      ; $3341  ; store
    inc de                         ; $3342  ; advance
    ld a,[hl+]                     ; $3343  ; second byte
    ld [de],a                      ; $3344  ; store
    inc de                         ; $3345  ; advance
    dec b                          ; $3346  ; cell count
    jr nz,Map_ScratchRow_Loop      ; $3347  ; loop
    ld a,$01                       ; $3349  ; wall byte
    ld [de],a                      ; $334B  ; right sentinel
    pop de                         ; $334C  ; restore de
    ret                            ; $334D  ; return

Map_ScratchRow_Fill:
    ld a,$01                       ; $334E  ; off-map: fill scratch window with all walls ($01)
    ld b,$0A                       ; $3350  ; 10 cells (20 bytes)

Map_ScratchRow_FillLoop:
    ld [hl+],a                     ; $3352  ; fill wall byte
    ld [hl+],a                     ; $3353  ; second byte
    dec b                          ; $3354  ; count
    jr nz,Map_ScratchRow_FillLoop  ; $3355  ; loop
    pop de                         ; $3357  ; restore de
    ret                            ; $3358  ; return

Score_AddBCD:
    ldh a,[$FF90]                  ; $3359  ; Score_AddBCD: +bc to BCD score at FFA1 (or FFA4 if FF90 bit0) - continues at $3362
    bit 3,a                        ; $335B  ; FF90 bit3 (bonus screen)?
    ret nz                         ; $335D  ; skip score

loc_335E:
    ldh a,[$FF90]                  ; $335E  ; FF90 flags
    bit 1,a                        ; $3360  ; FF90 bit1 gate (score add continues in region 11)
    ret nz                         ; $3362  ; part of Score_AddBCD ($3359): FF90 bit1 set -> return without adding
    ld hl,$FFA1                    ; $3363  ; hl = FFA1 (player-1 score) default add target
    bit 3,a                        ; $3366  ; bit3 of FF90: 'which score register' select
    jr z,Score_AddBCD_Shift        ; $3368  ; bit3 clear -> use FFA1
    bit 2,a                        ; $336A  ; bit2 of FF90
    jr nz,Score_AddBCD_Shift       ; $336C  ; bit2 set -> use FFA1 (default target)
    ld hl,$FFA4                    ; $336E  ; bit3 set + bit2 clear -> target FFA4 (player-2 score)

Score_AddBCD_Shift:
    srl b                          ; $3371  ; shared entry (also jp $0AB8 from action 'speed'): shift addend right 4
    rr c                           ; $3373  ; bc >>= 4: move carry down
    srl b                          ; $3375  ; shift upper byte
    rr c                           ; $3377  ; rotate carry into low byte (2nd)
    srl b                          ; $3379  ; shift upper byte (3rd)
    rr c                           ; $337B  ; rotate carry into low byte
    srl b                          ; $337D  ; shift upper byte (4th)
    rr c                           ; $337F  ; rotate carry into low byte: bc now = value/16
    ld a,[hl]                      ; $3381  ; BCD add: low digit + low addend (carry 0)
    add c                          ; $3382  ; add c (low byte of shifted value)
    daa                            ; $3383  ; decimal adjust
    ld [hl+],a                     ; $3384  ; store low digit
    ld a,[hl]                      ; $3385  ; BCD add: middle digit + high addend + carry
    adc b                          ; $3386  ; adc b
    daa                            ; $3387  ; decimal adjust
    ld [hl+],a                     ; $3388  ; store middle digit
    ld a,[hl]                      ; $3389  ; BCD add: high digit + carry-in
    adc $00                        ; $338A  ; propagate carry
    daa                            ; $338C  ; decimal adjust
    ld [hl],a                      ; $338D  ; store high digit
    ret nc                         ; $338E  ; no arithmetic overflow -> done
    ldh a,[$FF90]                  ; $338F  ; overflow: check FF90 bit2 (which register to saturate)
    bit 2,a                        ; $3391  ; FF90 bit2
    ld a,$99                       ; $3393  ; saturation value $99
    jr z,Score_SetA4               ; $3395  ; bit2 clear -> saturate FFA4-6

Score_SetA1:
    ldh [$FFA1],a                  ; $3397  ; write a to P1 score regs FFA1-FFA3 ($99 saturate, or $00 clear via call at $024C/$039F)
    ldh [$FFA2],a                  ; $3399  ; middle digit
    ldh [$FFA3],a                  ; $339B  ; high digit
    ret                            ; $339D  ; return (P1 path)

Score_SetA4:
    ldh [$FFA4],a                  ; $339E  ; write a to P2 score regs FFA4-FFA6 ($99 saturate, or $00 clear via call $024F/$03A2, jp $0B39)
    ldh [$FFA5],a                  ; $33A0  ; middle digit
    ldh [$FFA6],a                  ; $33A2  ; high digit
    ret                            ; $33A4  ; return (P2 path)

Score_UpdateBest:
    ld hl,$FFA9                    ; $33A5  ; update stored best score: if FFA1-3 > FFA7-9, copy FFA1-3 into FFA7-9
    ldh a,[$FFA3]                  ; $33A8  ; current score low digit (FFA3)
    cp [hl]                        ; $33AA  ; vs stored best low digit (FFA9)
    ret c                          ; $33AB  ; current smaller -> keep stored best
    jr nz,loc_33BA                 ; $33AC  ; current != stored -> current larger
    dec hl                         ; $33AE  ; next digit
    ldh a,[$FFA2]                  ; $33AF  ; current middle digit (FFA2)
    cp [hl]                        ; $33B1  ; vs stored middle (FFA8)
    ret c                          ; $33B2  ; current smaller -> keep stored
    jr nz,loc_33BA                 ; $33B3  ; current != stored -> larger
    dec hl                         ; $33B5  ; next digit
    ldh a,[$FFA1]                  ; $33B6  ; current high digit (FFA1)
    cp [hl]                        ; $33B8  ; vs stored high (FFA7)
    ret c                          ; $33B9  ; current smaller -> keep stored

loc_33BA:
    ldh a,[$FFA1]                  ; $33BA  ; store current score as best (copy FFA1-3 -> FFA7-9)
    ldh [$FFA7],a                  ; $33BC  ; low digit
    ldh a,[$FFA2]                  ; $33BE  ; current middle
    ldh [$FFA8],a                  ; $33C0  ; copy to best
    ldh a,[$FFA3]                  ; $33C2  ; current high
    ldh [$FFA9],a                  ; $33C4  ; copy to best
    ret                            ; $33C6  ; done

State_DispatchGate:
    ld a,[hl]                      ; $33C7  ; gate for state objects: hl = state addr; skip a state run while screen is scrolling
    cp $02                         ; $33C8  ; read state byte
    ret c                          ; $33CA  ; state < 2 -> run state now
    ldh a,[$FF96]                  ; $33CB  ; scrolling flag FF96
    and a                          ; $33CD  ; FF96 == 0 -> run state now
    ld a,[hl]                      ; $33CE  ; state still in a
    ret z                          ; $33CF  ; not scrolling -> dispatch state
    pop af                         ; $33D0  ; state >= 2 while scrolling: pop the caller return address
    ret                            ; $33D1  ; ...so the dispatch is skipped and we return to the caller's caller

Player_Reset:
    ldh [$FF99],a                  ; $33D2  ; init gameplay: FF99 = mode select flag, clear timers/states
    xor a                          ; $33D4  ; zero
    ldh [$FF9A],a                  ; $33D5  ; FF9A = 0 (delta timer)
    ld [$C000],a                   ; $33D7  ; player state motor C000 = 0
    ld [$C050],a                   ; $33DA  ; bonus slot 2 state C050 = 0
    ret                            ; $33DD  ; done

Player_StateDispatch:
    ld hl,$3567                    ; $33DE  ; player state dispatch: push return thunk, C000 -> handler via rst $10 (9-entry table)
    push hl                        ; $33E1  ; push Player_DrawThunk $3567 so state handler's 'ret' lands there
    ld a,[$C000]                   ; $33E2  ; state byte
    rst $10                        ; $33E5  ; rst $10: jump through 16-bit table at $33E6
    dw $33F8,$3467,$34AC,$34C5
    dw $34CB,$34D3,$34F1,$34FF
    dw $341D

Player_State0_Spawn:
    pop hl                         ; $33F8  ; state 0 (spawn): pop pushed draw-thunk
    ld a,$4A                       ; $33F9  ; Y base
    ld [$C003],a                   ; $33FB  ; obj+1 (Y) = $4A
    ld a,$98                       ; $33FE  ; X base
    ld [$C005],a                   ; $3400  ; obj+5 (X) = $98
    ldh a,[$FF99]                  ; $3403  ; mode select flag FF99
    cp $02                         ; $3405  ; FF99 == 2?
    jr z,loc_340F                  ; $3407  ; yes -> timed spawn
    ld a,$01                       ; $3409  ; else: enter state 1 (walk-in)
    ld [$C000],a                   ; $340B  ; C000 = 1
    ret                            ; $340E  ; return (normal spawn)

loc_340F:
    ld a,$04                       ; $340F  ; FF99==2: death/continue spawn
    ld [$C001],a                   ; $3411  ; C001 frame = 4
    ld a,$08                       ; $3414  ; state 8
    ld [$C000],a                   ; $3416  ; C000 = 8
    ld [$C009],a                   ; $3419  ; C009 countdown = 8 frames
    ret                            ; $341C  ; done

Player_State8_Decide:
    ld a,[$C009]                   ; $341D  ; state 8 (game-over/decision): decrement C009 countdown
    dec a                          ; $3420  ; timer -1
    ld [$C009],a                   ; $3421  ; store
    ret nz                         ; $3424  ; still counting -> wait
    ld a,$60                       ; $3425  ; decision time: X position
    ld [$C005],a                   ; $3427  ; C005 (X) = $60
    ldh a,[$FF90]                  ; $342A  ; FF90 bit2 selects score register to compare
    bit 2,a                        ; $342C  ; hl/de pick opposite registers
    ld hl,$FFA3                    ; $342E  ; hl = primary score (FFA3)
    jr nz,loc_3436                 ; $3431  ; bit2 set -> hl=FFA3, de=FFA6
    ld hl,$FFA6                    ; $3433  ; bit2 clear: hl = FFA6

loc_3436:
    ld de,$FFA3                    ; $3436  ; de = the other score register (FFA3)
    jr z,loc_343E                  ; $3439  ; bit2 clear -> de=FFA3
    ld de,$FFA6                    ; $343B  ; bit2 set: de = FFA6

loc_343E:
    call loc_34A2                  ; $343E  ; play state sfx (unless mode 1)
    ld a,$05                       ; $3441  ; default next state = 5 (idle)
    ld [$C000],a                   ; $3443  ; C000 = 5
    ld a,[de]                      ; $3446  ; compare other score vs primary (low digit)
    cp [hl]                        ; $3447  ; cp [hl]
    ret c                          ; $3448  ; other smaller -> stay in state 5
    jr nz,loc_345D                 ; $3449  ; other larger -> go to state 6
    dec hl                         ; $344B  ; walk digits up
    dec de                         ; $344C  ; --de
    ld a,[de]                      ; $344D  ; compare middle digit
    cp [hl]                        ; $344E  ; cp [hl]
    ret c                          ; $344F  ; other smaller -> keep state 5
    jr nz,loc_345D                 ; $3450  ; other larger -> state 6
    dec hl                         ; $3452  ; walk digits up
    dec de                         ; $3453  ; --de
    ld a,[de]                      ; $3454  ; compare high digit
    cp [hl]                        ; $3455  ; cp [hl]
    ret c                          ; $3456  ; other smaller -> keep state 5
    jr nz,loc_345D                 ; $3457  ; other larger -> state 6
    ld a,$07                       ; $3459  ; scores equal -> state 7
    jr loc_345F                    ; $345B  ; jump store

loc_345D:
    ld a,$06                       ; $345D  ; scores differ -> state 6

loc_345F:
    ld [$C000],a                   ; $345F  ; C000 = result state (6/7)

Sfx_Credits:
    ld a,$27                       ; $3462  ; play sfx $27 (credits/hall of fame blip)
    jp Sfx_PlayA                   ; $3464  ; jump to loc_3E42 (which calls SoundEngine_PlayEffect)

Player_State1_Walk:
    ldh a,[$FFD4]                  ; $3467  ; state 1 (walk-in): FFD4 bits 3-4 -> tbl index 0..3 (walk blink frame)
    and $18                        ; $3469  ; & $18 isolate bits 3/4
    srl a                          ; $346B  ; a >>= 1
    srl a                          ; $346D  ; a >>= 1
    srl a                          ; $346F  ; a >>= 1: index = (FFD4 & $18) >> 3
    rst $20                        ; $3471  ; rst $20: byte table at $3472 (count=4, frames 01 02 01 03); resumes at $3477
    ; rst $20 byte table (RST20_Dispatch at $0020): count=$04, values $01/$02/$01/$03 -> C001 (walk blink frames); code resumes at $3477
    db $04,$01,$02,$01,$03

loc_3477:
    ld [$C001],a                   ; $3477  ; store selected walk frame into C001
    ldh a,[$FFD4]                  ; $347A  ; FFD4 low nibble
    and $0F                        ; $347C  ; & $0F every 16 frames
    ld a,$05                       ; $347E  ; sfx id 5 (step)
    call z,SoundEngine_PlayEffect  ; $3480  ; play step whenever low nibble == 0
    ldh a,[$FFD4]                  ; $3483  ; FFD4 & $03 (every 4 frames)
    and $03                        ; $3485  ; only move on frames where low 2 bits == 0
    ret nz                         ; $3487  ; low bits non-zero -> wait (not on 4-frame boundary)
    ld a,[$C005]                   ; $3488  ; current X
    dec a                          ; $348B  ; X - 1
    ld [$C005],a                   ; $348C  ; store
    cp $61                         ; $348F  ; keep walking while X >= $61... only past window when X < $60
    ret nc                         ; $3491  ; X still was >= $61 -> keep walking (ret nc)
    xor a                          ; $3492  ; reached end of walk: clear C009
    ld [$C009],a                   ; $3493  ; clear C009 (walk finished)
    ldh a,[$FF99]                  ; $3496  ; FF99 select flag
    and a                          ; $3498  ; FF99 != 0?
    ld a,$02                       ; $3499  ; state 2
    jr nz,loc_349F                 ; $349B  ; not -> state 3
    ld a,$03                       ; $349D  ; state 3

loc_349F:
    ld [$C000],a                   ; $349F  ; C000 = next state (2/3)

loc_34A2:
    ldh a,[$FF8A]                  ; $34A2  ; play state-change sfx: skip when mode == 1 (title)
    cp $01                         ; $34A4  ; mode FF8A
    ret z                          ; $34A6  ; title mode -> no sfx
    ld a,$1D                       ; $34A7  ; sfx id $1D
    jp Sfx_PlayA                   ; $34A9  ; jump to loc_3E42 (SoundEngine_PlayEffect)

Player_State2_GameStart:
    ld a,[$C051]                   ; $34AC  ; state 2 (game start): frame = $07 if C051 near-end else $04
    cp $07                         ; $34AF  ; C051 == 7?
    ld a,$04                       ; $34B1  ; frame 4
    jr nz,loc_34B7                 ; $34B3  ; not 7 -> frame 4
    ld a,$07                       ; $34B5  ; 7 -> frame 7

loc_34B7:
    ld [$C001],a                   ; $34B7  ; C001 = frame
    ldh a,[$FFC0]                  ; $34BA  ; FFC0 bit3 = 'game started'
    bit 3,a                        ; $34BC  ; test
    ret z                          ; $34BE  ; not started -> wait
    call SoundEngine_VBlank_Reset  ; $34BF  ; reset sound engine (stop current sfx)
    jp Scroll_Start                ; $34C2  ; start the level scroll

Player_State3_Static:
    ld a,$09                       ; $34C5  ; state 3: static frame $09
    ld [$C001],a                   ; $34C7  ; C001 = 9
    ret                            ; $34CA  ; done

Player_State4_Latch:
    ld hl,$FF98                    ; $34CB  ; state 4: one-shot latch of FF98 (0 -> 1) used to signal 'level ready'
    ld a,[hl]                      ; $34CE  ; read FF98
    and a                          ; $34CF  ; already latched?
    ret nz                         ; $34D0  ; skip
    inc [hl]                       ; $34D1  ; latch trigger
    ret                            ; $34D2  ; done

Player_State5_Idle:
    ld a,[$C009]                   ; $34D3  ; state 5 (idle standing): C009 timer picks idle frame
    inc a                          ; $34D6  ; timer +1
    cp $0F                         ; $34D7  ; at $0F
    ld b,$04                       ; $34D9  ; frame 4 base
    jr c,loc_34E9                  ; $34DB  ; < $0F -> frame 4
    ld b,$07                       ; $34DD  ; >= $0F frame 7
    cp $19                         ; $34DF  ; at $19
    jr c,loc_34E9                  ; $34E1  ; < $19 -> frame 7
    inc b                          ; $34E3  ; frame 8
    cp $2D                         ; $34E4  ; at $2D
    jr c,loc_34E9                  ; $34E6  ; < $2D -> keep frame 8
    xor a                          ; $34E8  ; >= $2D: reset timer

loc_34E9:
    ld [$C009],a                   ; $34E9  ; C009 = 0 (or current value)
    ld a,b                         ; $34EC  ; frame in b
    ld [$C001],a                   ; $34ED  ; C001 = selected idle frame
    ret                            ; $34F0  ; done

Player_State6_Blink:
    ldh a,[$FFD4]                  ; $34F1  ; state 6 (blinking): FFD4 bit4 flips C001 $0A/$0B
    and $10                        ; $34F3  ; FFD4 & $10
    ld a,$0A                       ; $34F5  ; frame $0A
    jr z,loc_34FB                  ; $34F7  ; not set -> frame $0A
    ld a,$0B                       ; $34F9  ; set -> frame $0B

loc_34FB:
    ld [$C001],a                   ; $34FB  ; C001 = blink frame
    ret                            ; $34FE  ; done

Player_State7_Static:
    ld a,$04                       ; $34FF  ; state 7: static frame $04
    ld [$C001],a                   ; $3501  ; C001 = 4
    ret                            ; $3504  ; done

Bonus2_AnimDispatch:
    ld a,[$C050]                   ; $3505  ; bonus-slot 2 animation dispatch (level-clear bar; C050 state -> 3-entry table)
    rst $10                        ; $3508  ; rst $10: table at $3509
    dw $350F,$352A,$3564

Bonus2_AnimInit:
    ldh a,[$FF9D]                  ; $350F  ; state 0 (start anim): gate on level FF9D < $31
    cp $31                         ; $3511  ; level FF9D
    ret nc                         ; $3513  ; levels >= $31 -> finished (draw loop)
    ld a,$40                       ; $3514  ; X base $40
    ld [$C055],a                   ; $3516  ; C055 = $40
    ld a,$4A                       ; $3519  ; Y base $4A
    ld [$C053],a                   ; $351B  ; C053 = $4A
    xor a                          ; $351E  ; reset timer
    ld [$C059],a                   ; $351F  ; C059 = 0
    inc a                          ; $3522  ; first frame = 1
    ld [$C051],a                   ; $3523  ; C051 = 1
    ld [$C050],a                   ; $3526  ; state 1
    ret                            ; $3529  ; done

Bonus2_AnimTim:
    ldh a,[$FF96]                  ; $352A  ; state 1 (anim): pause while scrolling
    and a                          ; $352C  ; FF96
    jr nz,Bonus2_AnimDraw          ; $352D  ; scrolling -> draw only
    ld a,[$C000]                   ; $352F  ; player state C000
    cp $02                         ; $3532  ; >= 2 (game started)?
    jr c,Bonus2_AnimDraw           ; $3534  ; not started -> draw only
    ld hl,$C059                    ; $3536  ; countdown timer C059
    inc [hl]                       ; $3539  ; timer++
    ld a,[hl]                      ; $353A  ; read
    ld b,$01                       ; $353B  ; frame stage
    cp $78                         ; $353D  ; at $78
    jr c,loc_3560                  ; $353F  ; stage stays 1
    inc b                          ; $3541  ; stage 2
    cp $87                         ; $3542  ; at $87
    jr c,loc_3560                  ; $3544  ; stage 2
    inc b                          ; $3546  ; stage 3
    cp $96                         ; $3547  ; at $96
    jr c,loc_3560                  ; $3549  ; stage 3
    inc b                          ; $354B  ; stage 4
    cp $A5                         ; $354C  ; at $A5
    jr c,loc_3560                  ; $354E  ; stage 4
    inc b                          ; $3550  ; stage 5
    cp $B4                         ; $3551  ; at $B4
    jr c,loc_3560                  ; $3553  ; stage 5
    inc b                          ; $3555  ; stage 6
    cp $C3                         ; $3556  ; at $C3
    jr c,loc_3560                  ; $3558  ; stage 6
    ld a,$02                       ; $355A  ; finished (>= $C3): state 2
    ld [$C050],a                   ; $355C  ; C050 = 2 (bar full)
    inc b                          ; $355F  ; stage 7

loc_3560:
    ld a,b                         ; $3560  ; frame stage in a
    ld [$C051],a                   ; $3561  ; C051 = frame stage

Bonus2_AnimDraw:
    jp Bonus2_Draw                 ; $3564  ; jump to bar draw (loc_357B)

Player_DrawThunk:
    ld a,[$C001]                   ; $3567  ; Player_DrawThunk (return target pushed at $33E1): draw player at current frame
    ld hl,$358F                    ; $356A  ; frame table $358F (C001 -> OAM entry)
    call Table16_Get               ; $356D  ; loc_3CBC: read frame data pointer (16-bit table)
    ld a,[$C003]                   ; $3570  ; obj+1 (Y)
    ld c,a                         ; $3573  ; -> c
    ld a,[$C005]                   ; $3574  ; obj+5 (X)
    ld b,a                         ; $3577  ; -> b
    jp Oam_PutFrame                ; $3578  ; jump to OAM writer loc_3CC5

Bonus2_Draw:
    ld a,[$C051]                   ; $357B  ; bonus-bar draw: C051 frame -> $36C8 table
    ld hl,$36C8                    ; $357E  ; table base $36C8
    call Table16_Get               ; $3581  ; loc_3CBC: frame data pointer
    ld a,[$C053]                   ; $3584  ; C053 (Y)
    ld c,a                         ; $3587  ; -> c
    ld a,[$C055]                   ; $3588  ; C055 (X)
    ld b,a                         ; $358B  ; -> b
    jp Oam_PutFrame                ; $358C  ; jump to OAM writer loc_3CC5
    db $C7,$35,$A7,$35,$C8,$35,$E9,$35
    db $0A,$36,$23,$36,$23,$36,$23,$36
    db $44,$36,$6D,$36,$8E,$36,$AF,$36
    db $00,$00,$68,$00,$00,$08,$6B,$00
    db $08,$F8,$56,$00,$08,$00,$5A,$00
    db $08,$08,$5A,$20,$08,$10,$56,$20
    db $10,$00,$61,$00,$10,$08,$61,$20
    db $80,$00,$00,$68,$00,$00,$08,$69
    db $00,$08,$F8,$56,$00,$08,$00,$5A
    db $00,$08,$08,$5B,$00,$06,$10,$75
    db $00,$10,$00,$61,$00,$10,$08,$71
    db $00,$80,$00,$00,$6A,$00,$00,$08
    db $6B,$00,$06,$F8,$75,$20,$08,$00
    db $5B,$20,$08,$08,$5A,$20,$08,$10
    db $56,$20,$10,$00,$71,$20,$10,$08
    db $61,$20,$80,$00,$00,$50,$00,$00
    db $08,$51,$00,$08,$00,$60,$00,$08
    db $08,$60,$20,$10,$00,$70,$00,$10
    db $08,$70,$20,$80,$01,$00,$50,$00
    db $01,$08,$51,$00,$08,$F8,$56,$00
    db $08,$00,$57,$00,$08,$08,$57,$20
    db $08,$10,$56,$20,$10,$00,$61,$00
    db $10,$08,$61,$20,$80,$EA,$00,$50
    db $00,$EA,$08,$51,$00,$F0,$F8,$58
    db $00,$F0,$00,$59,$00,$F0,$08,$59
    db $20,$F0,$10,$58,$20,$F8,$F8,$66
    db $00,$F8,$00,$67,$00,$F8,$08,$67
    db $20,$F8,$10,$66,$20,$80,$00,$00
    db $68,$00,$00,$08,$6B,$00,$08,$F8
    db $56,$00,$08,$00,$5A,$00,$08,$08
    db $5A,$20,$08,$10,$56,$20,$10,$00
    db $6F,$00,$10,$08,$6F,$20,$80,$00
    db $F8,$7A,$00,$00,$10,$7A,$20,$01
    db $00,$5D,$00,$01,$08,$6C,$00,$08
    db $00,$5C,$00,$08,$08,$5C,$20,$10
    db $00,$61,$00,$10,$08,$71,$00,$80
    db $00,$00,$5D,$00,$00,$08,$6C,$00
    db $08,$00,$5C,$00,$08,$08,$5C,$20
    db $10,$00,$71,$20,$10,$08,$61,$20
    db $80,$E8,$36,$D8,$36,$E9,$36,$16
    db $37,$47,$37,$78,$37,$A5,$37,$CA
    db $37,$00,$00,$52,$00,$00,$08,$53
    db $00,$08,$00,$62,$00,$08,$08,$63
    db $00,$80,$00,$00,$54,$00,$00,$08
    db $55,$00,$08,$00,$64,$00,$08,$08
    db $65,$00,$08,$F8,$72,$00,$08,$10
    db $72,$20,$10,$F0,$73,$00,$10,$F8
    db $73,$20,$10,$00,$72,$00,$10,$08
    db $73,$20,$10,$10,$73,$00,$80,$00
    db $00,$54,$00,$00,$08,$55,$00,$08
    db $00,$64,$00,$08,$08,$65,$00,$08
    db $F0,$73,$00,$10,$F8,$72,$20,$10
    db $00,$74,$00,$10,$08,$74,$20,$10
    db $10,$73,$00,$18,$F8,$73,$00,$18
    db $08,$72,$00,$18,$10,$72,$20,$80
    db $00,$00,$54,$00,$00,$08,$55,$00
    db $08,$00,$64,$00,$08,$08,$65,$00
    db $10,$F0,$73,$20,$10,$F8,$72,$20
    db $10,$00,$74,$00,$10,$08,$74,$20
    db $10,$10,$73,$20,$18,$F8,$72,$00
    db $18,$08,$73,$20,$18,$10,$72,$00
    db $80,$00,$00,$54,$00,$00,$08,$55
    db $00,$08,$00,$64,$00,$08,$08,$65
    db $00,$10,$F0,$72,$00,$10,$00,$74
    db $00,$10,$08,$74,$20,$10,$10,$73
    db $00,$18,$F8,$73,$00,$18,$08,$72
    db $00,$18,$10,$72,$20,$80,$00,$00
    db $54,$00,$00,$08,$55,$00,$08,$00
    db $64,$00,$08,$08,$65,$00,$10,$00
    db $74,$00,$10,$08,$74,$20,$18,$F8
    db $73,$20,$18,$08,$72,$20,$20,$10
    db $73,$20,$80,$00,$00,$54,$00,$00
    db $08,$55,$00,$08,$00,$64,$00,$08
    db $08,$65,$00,$10,$00,$74,$00,$10
    db $08,$74,$20,$80

Title_StateDispatch:
    ld a,[$C000]                   ; $37E3  ; title screen state dispatch (called from mode-1 update at $067B): C000 states 3/4/5
    cp $04                         ; $37E6  ; state index
    jp nz,Title_State5_Code        ; $37E8  ; not 4 -> check states 5/3

Title_State4_Blend:
    ldh a,[$FF98]                  ; $37EB  ; state 4 (glow blend): FF98 < $0F -> play bump sfx every 8 frames
    cp $0F                         ; $37ED  ; FF98 marker
    jr nc,loc_37FA                 ; $37EF  ; >= $0F -> skip sfx
    ldh a,[$FFD4]                  ; $37F1  ; FFD4 & $07 = every 8 frames
    and $07                        ; $37F3  ; && frame timer
    ld a,$1A                       ; $37F5  ; sfx id $1A
    call z,SoundEngine_PlayEffect  ; $37F7  ; play bump on boundary

loc_37FA:
    ldh a,[$FFD4]                  ; $37FA  ; compute blend tile source: FF98*4 + (FFD4&3)*16 + (FFD4>>2&3)*4
    and $03                        ; $37FC  ; FFD4 & $03 column
    swap a                         ; $37FE  ; column * 16
    sla a                          ; $3800  ; * 16 (x4 into high nibble... multiplier)
    sla a                          ; $3802  ; *16 again
    ld l,a                         ; $3804  ; low byte of src offset
    ldh a,[$FFD4]                  ; $3805  ; FFD4 & $0C row
    and $0C                        ; $3807  ; isolate FFD4 row bits (& $0C)
    srl a                          ; $3809  ; row >>= 1
    srl a                          ; $380B  ; row >>= 2
    add $91                        ; $380D  ; src high byte = $91 (tile data bank)
    ld h,a                         ; $380F  ; tile data pointer hl = $91xx + offset
    ldh a,[$FF98]                  ; $3810  ; FF98 relative index
    sub $04                        ; $3812  ; -4
    jr nc,loc_3817                 ; $3814  ; >= 0 -> use it
    xor a                          ; $3816  ; index < 4 -> use 0

loc_3817:
    swap a                         ; $3817  ; dest row/col: index >> 4 ... compute $385E + (index/16)
    srl a                          ; $3819  ; >>= 1
    srl a                          ; $381B  ; >>= 1
    add $5E                        ; $381D  ; +$5E
    ld e,a                         ; $381F  ; low byte of source graphic in $38xx
    ld a,$00                       ; $3820  ; high byte carry
    adc $38                        ; $3822  ; +$38 -> de = $385E + index/16 (partially blended source)
    ld d,a                         ; $3824  ; d = $38 (high byte of blend source addr)
    ld c,$08                       ; $3825  ; write 4 rows x 8 cols blend

loc_3827:
    ld b,$04                       ; $3827  ; column counter
    push de                        ; $3829  ; need de

loc_382A:
    ld a,[de]                      ; $382A  ; blend: dest tile = source & dest (AND mask)
    and [hl]                       ; $382B  ; dest &= src byte
    ld [hl+],a                     ; $382C  ; write
    ld a,[de]                      ; $382D  ; next src byte
    inc de                         ; $382E  ; inc de
    and [hl]                       ; $382F  ; blend second tile of row
    ld [hl+],a                     ; $3830  ; write
    dec b                          ; $3831  ; row counter -1
    jr nz,loc_382A                 ; $3832  ; loop rows
    pop de                         ; $3834  ; restore de
    dec c                          ; $3835  ; col counter -1
    jr nz,loc_3827                 ; $3836  ; loop columns
    ldh a,[$FFD4]                  ; $3838  ; FFD4 & $0F = every 16 frames advance marker
    and $0F                        ; $383A  ; && timer
    ret nz                         ; $383C  ; wait 16 frames
    ldh a,[$FF98]                  ; $383D  ; FF98 marker
    and a                          ; $383F  ; at 0?
    ret z                          ; $3840  ; wait
    cp $13                         ; $3841  ; >= $13?
    jr nc,loc_3849                 ; $3843  ; don't wrap yet
    inc a                          ; $3845  ; marker +1
    ldh [$FF98],a                  ; $3846  ; FF98++
    ret                            ; $3848  ; done

loc_3849:
    xor a                          ; $3849  ; blend complete ($13): reset marker, next title phase
    ldh [$FF98],a                  ; $384A  ; FF98 = 0
    ld a,$05                       ; $384C  ; state 5 (code)
    ld [$C000],a                   ; $384E  ; C000 = 5
    call SoundEngine_VBlank_Reset  ; $3851  ; reset sound engine
    ld a,$24                       ; $3854  ; sfx id $24
    call Sfx_PlayB                 ; $3856  ; play via loc_3E45
    ld a,$11                       ; $3859  ; sfx id $11
    jp SoundEngine_PlayEffect      ; $385B  ; play (fanfare)
    db $FF,$FF,$FF,$FF,$77,$FF,$FF,$FF
    db $77,$FF,$DD,$FF,$55,$FF,$55,$FF
    db $55,$BB,$55,$EE,$55,$AA,$55,$EE
    db $55,$AA,$55,$AA,$11,$AA,$44,$AA
    db $11,$88,$44,$22,$00,$88,$00,$22
    db $00,$08,$00,$20,$00,$00,$00,$00

Title_State5_Code:
    cp $05                         ; $388E  ; state 5 (code display): one-shot latch then draw code block
    jr nz,Title_State3_Text        ; $3890  ; state 3? -> check
    ld hl,$FF98                    ; $3892  ; FF98 latch
    ld a,[hl]                      ; $3895  ; already run?
    and a                          ; $3896  ; and a: test FF98 latch
    ret nz                         ; $3897  ; skip
    inc [hl]                       ; $3898  ; one-shot: run once
    ld hl,$184C                    ; $3899  ; title block graphic $184C
    call Bg_WriteBlock             ; $389C  ; draw bg block via loc_3D05
    jp Title_WriteCode             ; $389F  ; write the code digits via loc_3A38

Title_State3_Text:
    cp $03                         ; $38A2  ; state 3 (scrolling text): gate on FFDB/FFD1 and slow timer
    ret nz                         ; $38A4  ; not state 3 -> return
    ldh a,[$FFD1]                  ; $38A5  ; FFD1 busy flag
    and a                          ; $38A7  ; and a
    ret nz                         ; $38A8  ; busy flag set -> return
    ldh a,[$FFD4]                  ; $38A9  ; FFD4 & $03 slow step
    and $03                        ; $38AB  ; && timer
    ret nz                         ; $38AD  ; every 4 frames
    ld a,$02                       ; $38AE  ; split mode flag
    ldh [$FFCE],a                  ; $38B0  ; FFCE = 2
    ldh a,[$FFCC]                  ; $38B2  ; scroll counter FFCC
    inc a                          ; $38B4  ; +1
    ldh [$FFCC],a                  ; $38B5  ; FFCC++
    and $07                        ; $38B7  ; && $07 -> wait 8 steps
    ret nz                         ; $38B9  ; only every 8 frames
    ldh a,[$FF98]                  ; $38BA  ; next tile column index (FF98 + $15) & $1F
    add $15                        ; $38BC  ; + $15
    and $1F                        ; $38BE  ; & $1F
    ld c,a                         ; $38C0  ; column offset
    ld b,$00                       ; $38C1  ; row 0
    ld hl,$9C20                    ; $38C3  ; BG map base $9C20
    add hl,bc                      ; $38C6  ; target address
    push hl                        ; $38C7  ; push hl
    pop de                         ; $38C8  ; pop de -> de = write address
    ldh a,[$FF98]                  ; $38C9  ; table index FF98
    ld c,a                         ; $38CB  ; -> c
    inc a                          ; $38CC  ; index +1
    ldh [$FF98],a                  ; $38CD  ; FF98++

Title_TextRead:
    ld hl,$38E1                    ; $38CF  ; table base $38E1
    add hl,bc                      ; $38D2  ; + index
    ld a,[hl]                      ; $38D3  ; next tile id
    and a                          ; $38D4  ; 0 = end of text
    jr z,Title_TextEnd             ; $38D5  ; -> switch to state 4
    ld [de],a                      ; $38D7  ; write tile to BG map
    ret                            ; $38D8  ; done

Title_TextEnd:
    ldh [$FF98],a                  ; $38D9  ; text ended: reset marker, enter state 4 (glow blend)
    ld a,$04                       ; $38DB  ; a = 0
    ld [$C000],a                   ; $38DD  ; C000 = 4
    ret                            ; $38E0  ; done
    ; Intro title scroll tile-id table (read via ld hl,$38E1 at $38CF; streamed to BG map $9C20); 0 marks the end
    db $DA,$ED,$FC,$E5,$DA,$EC,$ED,$AE
    db $FC,$DA,$E5,$E5,$FC,$ED,$E1,$DE
    db $FC,$ED,$EB,$DA,$E9,$EC,$FC,$E1
    db $DA,$EF,$DE,$FC,$DB,$DE,$DE,$E7
    db $FC,$DD,$DE,$E6,$E8,$E5,$E2,$EC
    db $E1,$DE,$DD,$F6,$FC,$E6,$DA,$E7
    db $E4,$E2,$E7,$DD,$FC,$E2,$EC,$FC
    db $DF,$EB,$DE,$DE,$FC,$DF,$EB,$E8
    db $E6,$FC,$ED,$E1,$DE,$FC,$E6,$DA
    db $E0,$E2,$DC,$DA,$E5,$FC,$E9,$E8
    db $F0,$DE,$EB,$FC,$E8,$DF,$FC,$ED
    db $E1,$DE,$FC,$DD,$DA,$EB,$E4,$FC
    db $EC,$F0,$E8,$EB,$DD,$F6,$FC,$FC
    db $FC,$FC,$FC,$FC,$FC,$FC,$FC,$FC
    db $FC,$FC,$FC,$FC,$FC,$FC,$FC,$FC
    db $FC,$FC,$00

Title_ScriptPlay:
    ldh a,[$FF96]                  ; $395C  ; title scripted joypad: glitch-free auto-play of title buttons (FF9D selects script)
    and a                          ; $395E  ; FF96 scrolling? stay paused
    ret nz                         ; $395F  ; scrolling -> stay paused
    ldh a,[$FF9D]                  ; $3960  ; which script: FF9D < $08 -> script A ($399E) else script B ($39E7)
    cp $08                         ; $3962  ; level < 8?
    ld hl,$399E                    ; $3964  ; script A base
    jr z,loc_396C                  ; $3967  ; use script A
    ld hl,$39E7                    ; $3969  ; script B base

loc_396C:
    ldh a,[$FFAF]                  ; $396C  ; script pointer FFAF:B0 (16-bit)
    ld e,a                         ; $396E  ; low
    ldh a,[$FFB0]                  ; $396F  ; high
    ld d,a                         ; $3971  ; de = script pointer (FFB0)
    add hl,de                      ; $3972  ; hl = script base + pointer
    ld a,[hl+]                     ; $3973  ; read event byte
    cp $FF                         ; $3974  ; terminal marker $FF?
    jp z,loc_3BDD                  ; $3976  ; -> jp loc_3BDD (script finished: start game)
    ldh [$FFD9],a                  ; $3979  ; store button-hold delay into FFD9
    ldh a,[$FFB1]                  ; $397B  ; FFB1 current delay counter
    and a                          ; $397D  ; counter already active?
    jr nz,loc_3982                 ; $397E  ; not counting -> reload
    ldh a,[$FFD9]                  ; $3980  ; reload delay

loc_3982:
    dec a                          ; $3982  ; delay -1
    ldh [$FFB1],a                  ; $3983  ; FFB1 = remaining frames
    ld a,[hl]                      ; $3985  ; next byte: button mask
    ld c,a                         ; $3986  ; -> c
    jr nz,loc_3994                 ; $3987  ; still counting down -> hold current script entry
    ld hl,$FFAF                    ; $3989  ; advance script pointer by 2
    ld a,[hl]                      ; $398C  ; low
    add $02                        ; $398D  ; +2
    ld [hl+],a                     ; $398F  ; store low
    ld a,[hl]                      ; $3990  ; high
    adc $00                        ; $3991  ; carry
    ld [hl],a                      ; $3993  ; store high

loc_3994:
    ldh a,[$FFC1]                  ; $3994  ; edge detection: FFC2 = (mask & ~FFC1)
    xor c                          ; $3996  ; xor c
    and c                          ; $3997  ; and c
    ldh [$FFC2],a                  ; $3998  ; pressed-edges FFC2
    ld a,c                         ; $399A  ; update held buttons
    ldh [$FFC1],a                  ; $399B  ; FFC1 = mask
    ret                            ; $399D  ; done
    db $01,$00,$1F,$10,$89,$00,$15,$20
    db $09,$60,$2A,$40,$73,$60,$01,$40
    db $01,$42,$08,$02,$15,$00,$07,$20
    db $3C,$00,$49,$40,$0C,$60,$02,$40
    db $9F,$60,$02,$62,$04,$42,$02,$02
    db $19,$00,$0F,$20,$17,$00,$11,$20
    db $DD,$60,$04,$20,$09,$01,$16,$00
    db $0B,$10,$14,$50,$05,$10,$15,$00
    db $03,$40,$BD,$60,$04,$20,$6A,$00
    db $FF,$01,$00,$1A,$00,$05,$20,$01
    db $00,$14,$20,$02,$00,$6D,$40,$02
    db $00,$0E,$10,$17,$00,$0B,$80,$4B
    db $00,$16,$20,$5F,$40,$01,$50,$19
    db $10,$09,$00,$0B,$80,$28,$00,$46
    db $20,$03,$00,$5E,$40,$02,$00,$26
    db $10,$02,$00,$0B,$80,$4F,$00,$30
    db $20,$61,$40,$02,$50,$3F,$10,$03
    db $00,$0A,$80,$4F,$00,$38,$20,$34
    db $00,$5F,$10,$02,$00,$14,$80,$CF
    db $00,$FF

Title_WriteCode:
    ld hl,$98C7                    ; $3A38  ; write title code text: fix hl=$98C7 then fall through

loc_3A3B:
    ld de,$D231                    ; $3A3B  ; (hl preset) code string from D231-236 -> BG tiles at hl
    ld a,[de]                      ; $3A3E  ; first letter (D231)
    inc de                         ; $3A3F  ; next
    add $DA                        ; $3A40  ; tile id = digit + $DA (letter)
    ld [hl+],a                     ; $3A42  ; write
    ld a,[de]                      ; $3A43  ; second letter (D232)
    inc de                         ; $3A44  ; next
    add $DA                        ; $3A45  ; tile id = digit + $DA
    ld [hl+],a                     ; $3A47  ; write
    ld a,$F5                       ; $3A48  ; separator tile $F5
    ld [hl+],a                     ; $3A4A  ; write (colon/spacer)
    ld b,$04                       ; $3A4B  ; 4 digits loop

loc_3A4D:
    ld a,[de]                      ; $3A4D  ; digit byte
    inc de                         ; $3A4E  ; next
    or $D0                         ; $3A4F  ; tile = digit | $D0
    ld [hl+],a                     ; $3A51  ; write
    dec b                          ; $3A52  ; loop 4
    jr nz,loc_3A4D                 ; $3A53  ; done
    ret                            ; $3A55  ; return

Bonus_GenCode:
    ldh a,[$FF9D]                  ; $3A56  ; generate bonus code digits from level FF9D (scramble) into D233-236 + target D231/232
    add $55                        ; $3A58  ; FF9D + $55
    and $3F                        ; $3A5A  ; & $3F: 6-bit part -> b
    ld b,a                         ; $3A5C  ; b = 6-bit scramble part
    ldh a,[$FFA0]                  ; $3A5D  ; FF9D + $AA second scramble
    add $AA                        ; $3A5F  ; + carry value
    sla a                          ; $3A61  ; * 2
    sla a                          ; $3A63  ; * 4
    srl b                          ; $3A65  ; merge b into high bits (b >> 1)
    rr a                           ; $3A67  ; rotate
    srl b                          ; $3A69  ; b >>= 1 (second)
    rr a                           ; $3A6B  ; rotate: combined scramble in a
    ld l,a                         ; $3A6D  ; low byte
    call Rng_Next                  ; $3A6E  ; advance PRNG (loc_3D45, seed FFD7)
    and $10                        ; $3A71  ; bit4 of PRNG -> $10 mask
    ldh [$FFD9],a                  ; $3A73  ; FFD9 = PRNG bit
    or b                           ; $3A75  ; combine with b
    ld h,a                         ; $3A76  ; hl high byte
    push hl                        ; $3A77  ; save scrambled 16-bit value
    ld b,$00                       ; $3A78  ; tens loop counter

CodeSplit_Thousand:
    ld a,l                         ; $3A7A  ; split thousands: repeated subtract $03E8
    sub $E8                        ; $3A7B  ; low - $E8
    ld e,a                         ; $3A7D  ; target low
    ld a,h                         ; $3A7E  ; high - 3
    sbc $03                        ; $3A7F  ; sbc high
    jr c,loc_3A88                  ; $3A81  ; can't subtract any more?
    ld h,a                         ; $3A83  ; keep high
    ld l,e                         ; $3A84  ; keep low
    inc b                          ; $3A85  ; thousands count +1
    jr CodeSplit_Thousand          ; $3A86  ; loop

loc_3A88:
    ld a,b                         ; $3A88  ; thousands count
    ld [$D233],a                   ; $3A89  ; D233 = thousands digit
    ld b,$00                       ; $3A8C  ; hundreds index

CodeSplit_Hundred:
    ld a,l                         ; $3A8E  ; split hundreds: repeated subtract $64
    sub $64                        ; $3A8F  ; low - $64
    ld e,a                         ; $3A91  ; target low
    ld a,h                         ; $3A92  ; high - 0
    sbc $00                        ; $3A93  ; sbc high
    jr c,loc_3A9C                  ; $3A95  ; cannot subtract?
    ld h,a                         ; $3A97  ; keep high
    ld l,e                         ; $3A98  ; keep low
    inc b                          ; $3A99  ; +1
    jr CodeSplit_Hundred           ; $3A9A  ; loop

loc_3A9C:
    ld a,b                         ; $3A9C  ; hundreds count
    ld [$D234],a                   ; $3A9D  ; D234 = hundreds digit
    ld b,$00                       ; $3AA0  ; tens index

CodeSplit_Ten:
    ld a,l                         ; $3AA2  ; split tens: repeated subtract $0A
    sub $0A                        ; $3AA3  ; low - $0A
    ld e,a                         ; $3AA5  ; target low
    ld a,h                         ; $3AA6  ; high - 0
    sbc $00                        ; $3AA7  ; sbc high
    jr c,CodeSplit_Units           ; $3AA9  ; cannot subtract -> done
    ld h,a                         ; $3AAB  ; keep high
    ld l,e                         ; $3AAC  ; keep low
    inc b                          ; $3AAD  ; +1
    jr CodeSplit_Ten               ; $3AAE  ; loop

CodeSplit_Units:
    ld a,b                         ; $3AB0  ; tens count
    ld [$D235],a                   ; $3AB1  ; D235 = tens digit
    ld a,l                         ; $3AB4  ; remainder (units)
    ld [$D236],a                   ; $3AB5  ; D236 = units digit
    pop hl                         ; $3AB8  ; restore scrambled value
    call Code_Normalize            ; $3AB9  ; normalize via loc_3AC5 (xor $10, -$02A4, /26)
    ld a,b                         ; $3ABC  ; row part
    ld [$D231],a                   ; $3ABD  ; D231 = target row
    ld a,l                         ; $3AC0  ; remainder
    ld [$D232],a                   ; $3AC1  ; D232 = target remainder
    ret                            ; $3AC4  ; done

Code_Normalize:
    ld a,h                         ; $3AC5  ; normalize puzzle value: hl = ((hl xor $1000) - $02A4); result b=rows, l=rem-26
    xor $10                        ; $3AC6  ; flip high nibble
    ld h,a                         ; $3AC8  ; store

loc_3AC9:
    ld a,l                         ; $3AC9  ; subtract $02A4 loop
    sub $A4                        ; $3ACA  ; low - $A4
    ld e,a                         ; $3ACC  ; target low
    ld a,h                         ; $3ACD  ; high - 2
    sbc $02                        ; $3ACE  ; sbc high
    jr c,loc_3AD6                  ; $3AD0  ; done subtracting
    ld h,a                         ; $3AD2  ; keep high
    ld l,e                         ; $3AD3  ; keep low
    jr loc_3AC9                    ; $3AD4  ; loop

loc_3AD6:
    ld b,$00                       ; $3AD6  ; divide remaining by $1A (26) -> b = count

loc_3AD8:
    ld a,l                         ; $3AD8  ; low - $1A
    sub $1A                        ; $3AD9  ; low byte - 0x1A (26)
    ld e,a                         ; $3ADB  ; low result (target remainder-26)
    ld a,h                         ; $3ADC  ; high - 0
    sbc $00                        ; $3ADD  ; sbc high
    ret c                          ; $3ADF  ; no more
    ld h,a                         ; $3AE0  ; keep high
    ld l,e                         ; $3AE1  ; keep low
    inc b                          ; $3AE2  ; +1
    jr loc_3AD8                    ; $3AE3  ; loop

Code_Solve:
    ld hl,$0000                    ; $3AE5  ; solve bonus code: rebuild 16-bit value from digits, verify vs target D231/232
    ld a,[$D233]                   ; $3AE8  ; thousands digit
    ld de,$03E8                    ; $3AEB  ; mul 1000
    call Mul_HlDeA                 ; $3AEE  ; hl += D233 * $03E8 (loc_3B51)
    ld a,[$D234]                   ; $3AF1  ; hundreds digit
    ld de,$0064                    ; $3AF4  ; mul 100
    call Mul_HlDeA                 ; $3AF7  ; hl += D234 * $64
    ld a,[$D235]                   ; $3AFA  ; tens digit
    ld de,$000A                    ; $3AFD  ; mul 10
    call Mul_HlDeA                 ; $3B00  ; hl += D235 * $0A
    ld a,[$D236]                   ; $3B03  ; units digit
    ld de,$0001                    ; $3B06  ; mul 1
    call Mul_HlDeA                 ; $3B09  ; hl += D236 * 1
    push hl                        ; $3B0C  ; push hl
    call Code_Normalize            ; $3B0D  ; normalize solved value
    ld c,l                         ; $3B10  ; remainder
    pop hl                         ; $3B11  ; pop original hl
    ld a,[$D231]                   ; $3B12  ; target row (D231)
    cp b                           ; $3B15  ; row matches?
    jr nz,Code_SolveFail           ; $3B16  ; no -> wrong answer (loc_3B49)
    ld a,[$D232]                   ; $3B18  ; target remainder (D232)
    cp c                           ; $3B1B  ; remainder matches?
    jr nz,Code_SolveFail           ; $3B1C  ; no -> wrong answer (loc_3B49)
    ld a,l                         ; $3B1E  ; correct: derive new level-offset from remainder
    sub $AA                        ; $3B1F  ; - $AA
    and $3F                        ; $3B21  ; & $3F
    ldh [$FFA0],a                  ; $3B23  ; FFA0 = solved code (level offset)
    add hl,hl                      ; $3B25  ; hl *= 4... (continues into region 12 at $3B28 and beyond)
    add hl,hl                      ; $3B26  ; hl *= 4 (used by solving post-processing)
    ld a,h                         ; $3B27  ; high byte of *4 result (region 12 tail continues)3487	low bits non-zero -> wait (not on 4-frame boundary)
    sub $55                        ; $3B28  ; puzzle-solution accepted tail (continues Code_Solve $3AE5): validate high byte h
    and $3F                        ; $3B2A  ; h - $55 masked $3F
    cp $32                         ; $3B2C  ; must be < $32
    jr nc,Code_SolveFail           ; $3B2E  ; too big -> fail (loc_3B49)
    ld b,a                         ; $3B30  ; base row value
    inc b                          ; $3B31  ; row + 1
    ldh a,[$FF9D]                  ; $3B32  ; current level FF9D
    cp b                           ; $3B34  ; compare with row
    jr z,loc_3B39                  ; $3B35  ; equal -> accepted
    jr nc,Code_SolveFail           ; $3B37  ; level >= row -> fail

loc_3B39:
    ld a,$1B                       ; $3B39  ; accepted: play sfx $1B (success)
    call SoundEngine_PlayEffect    ; $3B3B  ; call SFX engine
    ldh a,[$FFA0]                  ; $3B3E  ; FFA0 code counter
    cp $3F                         ; $3B40  ; cap at $3F
    jr z,loc_3B45                  ; $3B42  ; at cap -> skip increment
    inc a                          ; $3B44  ; advance code

loc_3B45:
    ldh [$FFA0],a                  ; $3B45  ; FFA0 = updated code
    scf                            ; $3B47  ; return carry SET (valid)
    ret                            ; $3B48  ; ret

Code_SolveFail:
    ld a,$0F                       ; $3B49  ; puzzle-solution rejected (also jr target from Code_Solve): play error buzz
    call SoundEngine_PlayEffect    ; $3B4B  ; play sfx $0F (error)
    scf                            ; $3B4E  ; skip
    ccf                            ; $3B4F  ; clear carry
    ret                            ; $3B50  ; return carry CLEAR (invalid)

Mul_HlDeA:
    and a                          ; $3B51  ; 16-bit mul-add: hl += de * a (loop a times)
    ret z                          ; $3B52  ; a == 0 -> done
    ld b,a                         ; $3B53  ; loop counter

loc_3B54:
    add hl,de                      ; $3B54  ; add de
    dec b                          ; $3B55  ; --counter
    jr nz,loc_3B54                 ; $3B56  ; loop
    ret                            ; $3B58  ; done

BgPals_Load:
    ld hl,$DEA2                    ; $3B59  ; load BG palettes from 3-byte table at $DEA2 (FF47/48/49)
    ld a,[hl+]                     ; $3B5C  ; BGP
    ldh [$FF47],a                  ; $3B5D  ; FF47 = [DEA2]
    ld a,[hl+]                     ; $3B5F  ; OBP0
    ldh [$FF48],a                  ; $3B60  ; FF48 = [DEA3]
    ld a,[hl]                      ; $3B62  ; OBP1
    ldh [$FF49],a                  ; $3B63  ; FF49 = [DEA4]
    ret                            ; $3B65  ; done

Ctrl_ReadMerge:
    call SoundEngine_ChannelInit   ; $3B66  ; VBlank control merge: sound + RNG + joypad + script/restart logic (called $0204)
    call Rng_Next                  ; $3B69  ; advance RNG seed FFD7
    call Frame_Tick                ; $3B6C  ; advance global frame counter FFD4 (16-bit)

loc_3B6F:
    call Input_ReadJoypad          ; $3B6F  ; read joypad hardware
    ldh a,[$FFC1]                  ; $3B72  ; held buttons FFC1
    xor c                          ; $3B74  ; xor with new
    and c                          ; $3B75  ; mask edges
    ldh [$FFC2],a                  ; $3B76  ; FFC2 = newly pressed edges
    ld a,c                         ; $3B78  ; store held
    ldh [$FFC1],a                  ; $3B79  ; FFC1 = current state
    ldh a,[$FF90]                  ; $3B7B  ; FF90 bit3 = scripted-controls mode flag
    bit 3,a                        ; $3B7D  ; test
    jr z,loc_3B9D                  ; $3B7F  ; not set -> use raw controls
    ld a,[$D130]                   ; $3B81  ; script ptr counter D130
    ldh [$FFD9],a                  ; $3B84  ; FFD9 = D130
    ld c,a                         ; $3B86  ; c = index
    ld a,[$D12F]                   ; $3B87  ; script length D12F
    cp c                           ; $3B8A  ; index reached length?
    ld b,$00                       ; $3B8B  ; b = 0
    jr z,loc_3B9A                  ; $3B8D  ; at end -> zero byte
    ld hl,$D131                    ; $3B8F  ; script byte table D131
    add hl,bc                      ; $3B92  ; + index
    ld a,[hl]                      ; $3B93  ; byte
    ld b,a                         ; $3B94  ; b = script byte
    ld a,c                         ; $3B95  ; index
    inc a                          ; $3B96  ; advance
    ld [$D130],a                   ; $3B97  ; D130 = index + 1

loc_3B9A:
    ld a,b                         ; $3B9A  ; script byte into a
    ldh [$FFC8],a                  ; $3B9B  ; FFC8 = scripted control byte (overrides pad)

loc_3B9D:
    ldh a,[$FF90]                  ; $3B9D  ; FF90 & $0C: which control-merge flavor
    and $0C                        ; $3B9F  ; mask bits 2/3
    cp $08                         ; $3BA1  ; == $08 (special flavor)?
    jr z,loc_3BAF                  ; $3BA3  ; yes -> alt path
    ldh a,[$FFC1]                  ; $3BA5  ; plain: FFC1 -> FFBF (P1 held)
    ldh [$FFBF],a                  ; $3BA7  ; FFBF = FFC1
    ldh a,[$FFC2]                  ; $3BA9  ; FFC2 -> FFC0 (P1 edges)
    ldh [$FFC0],a                  ; $3BAB  ; FFC0 = FFC2
    jr loc_3BD2                    ; $3BAD  ; jump store-prev

loc_3BAF:
    ldh a,[$FFD9]                  ; $3BAF  ; alt path: header
    ld b,a                         ; $3BB1  ; b = FFD9 (index)
    ld a,[$D12F]                   ; $3BB2  ; script length
    cp b                           ; $3BB5  ; index == length -> no script byte
    jr z,loc_3BBE                  ; $3BB6  ; equal -> skip
    ldh a,[$FFC8]                  ; $3BB8  ; FFC8 script byte
    bit 7,a                        ; $3BBA  ; bit7 (sign)?
    jr z,loc_3BC4                  ; $3BBC  ; no -> resolve normally

loc_3BBE:
    ldh a,[$FFC3]                  ; $3BBE  ; last controls FFC3
    ld c,a                         ; $3BC0  ; -> c
    xor a                          ; $3BC1  ; edge = zero
    jr loc_3BCB                    ; $3BC2  ; skip resolve

loc_3BC4:
    and $0C                        ; $3BC4  ; script byte high bits -> c
    ld c,a                         ; $3BC6  ; c = FFC8 & $0C
    ldh a,[$FFC3]                  ; $3BC7  ; FFC3 last
    xor c                          ; $3BC9  ; xor c
    and c                          ; $3BCA  ; mask

loc_3BCB:
    ldh [$FFC0],a                  ; $3BCB  ; FFC0 = resolved edges
    ld a,c                         ; $3BCD  ; held chord
    ldh [$FFBF],a                  ; $3BCE  ; FFBF = c
    ldh [$FFC3],a                  ; $3BD0  ; FFC3 = c (latch last controls)

loc_3BD2:
    ldh a,[$FF90]                  ; $3BD2  ; FF90 bit1 (script-stop flag)
    bit 1,a                        ; $3BD4  ; test
    ret z                          ; $3BD6  ; clear -> done (normal return)
    ldh a,[$FFC0]                  ; $3BD7  ; FFC0 any press?
    and a                          ; $3BD9  ; test
    jp z,Title_ScriptPlay          ; $3BDA  ; none -> re-run title script (jp Title_ScriptPlay $395C)

loc_3BDD:
    xor a                          ; $3BDD  ; script finished and a press happened: stop script
    ldh [$FF90],a                  ; $3BDE  ; FF90 = 0
    rst $08                        ; $3BE0  ; restart current mode (rst $08)

Btn_AutoA:
    push hl                        ; $3BE1  ; cursor auto-repeat (bit0/Start held): debounce+repeat counter FFC6
    ld b,$01                       ; $3BE2  ; repeat bit value
    ld hl,$FFC6                    ; $3BE4  ; counter FFC6
    jr loc_3BEF                    ; $3BE7  ; join common path

Btn_AutoB:
    push hl                        ; $3BE9  ; cursor auto-repeat (bit1/Select held): counter FFC7 (b=$02)
    ld b,$02                       ; $3BEA  ; repeat bit value
    ld hl,$FFC7                    ; $3BEC  ; counter FFC7

loc_3BEF:
    ldh a,[$FFC2]                  ; $3BEF  ; pressed this frame?
    and b                          ; $3BF1  ; test edge
    jr nz,loc_3C04                 ; $3BF2  ; yes -> trigger now
    ldh a,[$FFC1]                  ; $3BF4  ; held this frame?
    and b                          ; $3BF6  ; test hold
    jr z,loc_3BFF                  ; $3BF7  ; not held -> reset counter
    ld a,[hl]                      ; $3BF9  ; counter value
    inc a                          ; $3BFA  ; ++ counter
    cp $0A                         ; $3BFB  ; reached repeat threshold $0A?
    jr nc,loc_3C04                 ; $3BFD  ; yes -> trigger now

loc_3BFF:
    ld [hl],a                      ; $3BFF  ; store counter
    xor a                          ; $3C00  ; return with Z set (below threshold)
    and b                          ; $3C01  ; clear flags
    pop hl                         ; $3C02  ; pop saved hl
    ret                            ; $3C03  ; done

loc_3C04:
    xor a                          ; $3C04  ; trigger: reset repeat counter
    ld [hl],a                      ; $3C05  ; counter = 0
    ld a,b                         ; $3C06  ; repeat bit
    and b                          ; $3C07  ; signals action (NZ)
    pop hl                         ; $3C08  ; pop saved hl
    ret                            ; $3C09  ; done

Cur_Debounce:
    ldh a,[$FF90]                  ; $3C0A  ; pause/edge limiter: FFC5 counter gate for repeated action
    bit 3,a                        ; $3C0C  ; FF90 bit3
    jr z,loc_3C1C                  ; $3C0E  ; must be clear
    bit 2,a                        ; $3C10  ; FF90 bit2
    jr z,loc_3C1C                  ; $3C12  ; must be clear
    ldh a,[$FF8E]                  ; $3C14  ; permission flag FF8E
    and a                          ; $3C16  ; must be zero
    jr z,loc_3C1C                  ; $3C17  ; enabled: keep limiting
    xor a                          ; $3C19  ; reset counter
    ldh [$FFC5],a                  ; $3C1A  ; FFC5 = 0

loc_3C1C:
    ldh a,[$FFC5]                  ; $3C1C  ; FFC5 counter
    cp $04                         ; $3C1E  ; at limit $04?
    ret nc                         ; $3C20  ; at limit -> block
    inc a                          ; $3C21  ; advance
    ldh [$FFC5],a                  ; $3C22  ; FFC5++
    ret                            ; $3C24  ; return (allowed while < $04)

Frame_Tick:
    ld hl,$FFD4                    ; $3C25  ; advance 16-bit frame counter FFD4/FFD5
    ld a,[hl]                      ; $3C28  ; low byte
    add $01                        ; $3C29  ; + 1
    ld [hl+],a                     ; $3C2B  ; store low
    ld a,[hl]                      ; $3C2C  ; high byte
    adc $00                        ; $3C2D  ; + carry
    ld [hl],a                      ; $3C2F  ; store high
    ret                            ; $3C30  ; done

Timer_SetCount:
    cpl                            ; $3C31  ; config countdown timer: TIMA = TMA = ~a (FF05/FF06)
    ldh [$FF06],a                  ; $3C32  ; FF06 (TMA) = ~a
    ldh [$FF05],a                  ; $3C34  ; FF05 (TIMA) = ~a
    ret                            ; $3C36  ; done

Timer_SetCtrl:
    ldh [$FF07],a                  ; $3C37  ; config timer control: FF07 (TAC) = a, then enable (set bit2)
    set 2,a                        ; $3C39  ; enable timer bit
    ldh [$FF07],a                  ; $3C3B  ; FF07 (TAC) = a | 4
    ret                            ; $3C3D  ; done

Serial_Send:
    ld b,a                         ; $3C3E  ; serial send: FF8D bit7 guard, write a to SB (FF01) + start (FF02=$81)
    ldh a,[$FF8D]                  ; $3C3F  ; serial busy/status FF8D
    bit 7,a                        ; $3C41  ; bit7 set -> busy, abort
    ret nz                         ; $3C43  ; abort
    ld a,$01                       ; $3C44  ; SC start bits
    ldh [$FF02],a                  ; $3C46  ; FF02 = $01
    ld a,b                         ; $3C48  ; byte in b
    ldh [$FF01],a                  ; $3C49  ; FF01 (SB) = data
    ld a,$81                       ; $3C4B  ; SC value $81
    ldh [$FF02],a                  ; $3C4D  ; FF02 = $81 (start transfer)
    ret                            ; $3C4F  ; done

Serial_RecvByte:
    ld b,a                         ; $3C50  ; serial receive: FF8D bit7 required, read a from SB via SC=$80
    ldh a,[$FF8D]                  ; $3C51  ; serial busy FF8D
    bit 7,a                        ; $3C53  ; bit7 set -> transfer active
    ret z                          ; $3C55  ; abort if not set
    di                             ; $3C56  ; disable interrupts
    ld a,$00                       ; $3C57  ; SC nibble
    ldh [$FF02],a                  ; $3C59  ; FF02 = $00
    ld a,b                         ; $3C5B  ; byte
    ldh [$FF01],a                  ; $3C5C  ; FF01 (SB) = a
    ld a,$80                       ; $3C5E  ; SC = $80 (listen)
    ldh [$FF02],a                  ; $3C60  ; write SC
    ei                             ; $3C62  ; enable interrupts
    ret                            ; $3C63  ; done

Bg_ClearText:
    ld hl,$9800                    ; $3C64  ; fill text BG map $9800-$9FFF with tile $FC (blank)
    ld bc,$0800                    ; $3C67  ; region size 0x800 tiles

loc_3C6A:
    ld a,$FC                       ; $3C6A  ; fill tile
    ld [hl+],a                     ; $3C6C  ; write
    dec bc                         ; $3C6D  ; --count
    ld a,b                         ; $3C6E  ; check
    or c                           ; $3C6F  ; b| c
    jr nz,loc_3C6A                 ; $3C70  ; loop
    ret                            ; $3C72  ; done

Clear_Null:
    xor a                          ; $3C73  ; Clear_Null (already labeled): clear OAM sprite buffer table DE00-DE9F

loc_3C74:
    ld l,a                         ; $3C74  ; base = 0
    ld h,$DE                       ; $3C75  ; h = DE (OAM buffer high byte)
    ld a,$A0                       ; $3C77  ; DExx high byte
    sub l                          ; $3C79  ; size check (A0 - l)
    ret z                          ; $3C7A  ; done when l == $A0
    srl a                          ; $3C7B  ; size/4 -> iterations
    srl a                          ; $3C7D  ; >> 1
    ld b,a                         ; $3C7F  ; b = 40 (16-byte rows / 4)
    ld de,$0003                    ; $3C80  ; stride 3
    xor a                          ; $3C83  ; clear byte

loc_3C84:
    ld [hl+],a                     ; $3C84  ; write
    add hl,de                      ; $3C85  ; skip to next group
    dec b                          ; $3C86  ; --count
    jr nz,loc_3C84                 ; $3C87  ; loop
    ret                            ; $3C89  ; done

Init_GameMemory:
    ld hl,$C000                    ; $3C8A  ; init: clear high RAM, set FF8A-8B etc
    ld bc,$1F80                    ; $3C8D  ; 16k count
    call Mem_ZeroFill              ; $3C90  ; zero-fill via Mem_ZeroFill
    ld hl,$FF8A                    ; $3C93  ; start of HRAM work area
    ld b,$74                       ; $3C96  ; 74 bytes (FF8A-FFFD)

loc_3C98:
    ld [hl+],a                     ; $3C98  ; write 0
    dec b                          ; $3C99  ; --count
    jr nz,loc_3C98                 ; $3C9A  ; loop
    ret                            ; $3C9C  ; done

Mem_CopyBC:
    ld a,[hl+]                     ; $3C9D  ; copy bc bytes from hl to de (DMA-style)
    ld [de],a                      ; $3C9E  ; byte
    inc de                         ; $3C9F  ; advance de
    dec bc                         ; $3CA0  ; --count
    ld a,b                         ; $3CA1  ; check
    or c                           ; $3CA2  ; b| c
    jr nz,Mem_CopyBC               ; $3CA3  ; loop
    ret                            ; $3CA5  ; done

Mem_CopyB:
    ld a,[hl+]                     ; $3CA6  ; copy b bytes from hl to de
    ld [de],a                      ; $3CA7  ; byte
    inc de                         ; $3CA8  ; --count
    dec b                          ; $3CA9  ; loop
    jr nz,Mem_CopyB                ; $3CAA  ; loop
    ret                            ; $3CAC  ; done

Mem_Swap:
    ld a,[hl]                      ; $3CAD  ; swap hl<->de byte-by-byte (bc count) using FFD9
    ldh [$FFD9],a                  ; $3CAE  ; save byte
    ld a,[de]                      ; $3CB0  ; other
    ld [hl+],a                     ; $3CB1  ; write
    ldh a,[$FFD9]                  ; $3CB2  ; restore
    ld [de],a                      ; $3CB4  ; write back
    inc de                         ; $3CB5  ; both pointers forward
    dec bc                         ; $3CB6  ; --count
    ld a,b                         ; $3CB7  ; check
    or c                           ; $3CB8  ; b| c
    jr nz,Mem_Swap                 ; $3CB9  ; loop
    ret                            ; $3CBB  ; done

Table16_Get:
    add a                          ; $3CBC  ; Table16_Get: hl=base, a=index -> hl = word at base + a*2 (frame pointer lookup)
    ld c,a                         ; $3CBD  ; index*2
    ld b,$00                       ; $3CBE  ; high 0
    add hl,bc                      ; $3CC0  ; + base
    ld a,[hl+]                     ; $3CC1  ; low
    ld h,[hl]                      ; $3CC2  ; high
    ld l,a                         ; $3CC3  ; hl = entry word
    ret                            ; $3CC4  ; done

Oam_PutFrame:
    ld a,b                         ; $3CC5  ; Oam_PutFrame (so-called): write 4-byte sprite frame from hl into DEA0 shadow OAM
    add $10                        ; $3CC6  ; Y base + $10
    ld b,a                         ; $3CC8  ; store Y base
    ld a,c                         ; $3CC9  ; X base
    jr loc_3CD9                    ; $3CCA  ; join common

Oam_PutFrameScroll:
    ldh a,[$FFCE]                  ; $3CCC  ; Oam_PutFrameScroll (entry at $306F/$3093): same, with LCD scroll offsets FFCE/FFCC
    ld e,a                         ; $3CCE  ; Y scroll FFCE
    ld a,b                         ; $3CCF  ; Y base into a
    sub e                          ; $3CD0  ; Y minus scroll
    add $10                        ; $3CD1  ; fixed +$10 (sprite coords)
    ld b,a                         ; $3CD3  ; store Y
    ldh a,[$FFCC]                  ; $3CD4  ; X scroll FFCC
    ld e,a                         ; $3CD6  ; -> e
    ld a,c                         ; $3CD7  ; X base
    sub e                          ; $3CD8  ; X minus scroll

loc_3CD9:
    add $08                        ; $3CD9  ; X + $08 (sprite origin offset)
    ld c,a                         ; $3CDB  ; store X base
    ld a,[$DEA0]                   ; $3CDC  ; shadow OAM write pointer DEA0
    cp $A0                         ; $3CDF  ; already full ($A0)?
    ret z                          ; $3CE1  ; abort
    ld e,a                         ; $3CE2  ; e = DEA0 (note: e only tracks low byte within DE00-DFFF)
    ld d,$DE                       ; $3CE3  ; d = DE

loc_3CE5:
    ld a,[hl+]                     ; $3CE5  ; read frame byte
    cp $80                         ; $3CE6  ; marker $80 = end?
    jr z,loc_3D00                  ; $3CE8  ; finish
    add b                          ; $3CEA  ; Y byte + base Y
    ld [de],a                      ; $3CEB  ; write to shadow OAM
    inc e                          ; $3CEC  ; e++
    ld a,[hl+]                     ; $3CED  ; X byte
    add c                          ; $3CEE  ; + base X
    ld [de],a                      ; $3CEF  ; write
    inc e                          ; $3CF0  ; e++
    ld a,[$DEA1]                   ; $3CF1  ; attr base DEA1
    add [hl]                       ; $3CF4  ; tile = attr + frame tile offset
    inc hl                         ; $3CF5  ; next
    ld [de],a                      ; $3CF6  ; write tile
    inc e                          ; $3CF7  ; e++
    ld a,[hl+]                     ; $3CF8  ; frame attr byte
    ld [de],a                      ; $3CF9  ; write attr
    inc e                          ; $3CFA  ; e++
    ld a,e                         ; $3CFB  ; written bytes
    cp $A0                         ; $3CFC  ; at $A0 limit?
    jr nz,loc_3CE5                 ; $3CFE  ; loop

loc_3D00:
    ld a,e                         ; $3D00  ; save pointer
    ld [$DEA0],a                   ; $3D01  ; DEA0 = bytes written
    ret                            ; $3D04  ; done

Bg_WriteBlock:
    ld a,[hl+]                     ; $3D05  ; Bg_WriteBlock: stream tile data from hl into map de (stride c) with F7 command byte
    cp $F7                         ; $3D06  ; read byte
    jr z,loc_3D13                  ; $3D08  ; F7 = command prefix?

loc_3D0A:
    ld [de],a                      ; $3D0A  ; write tile byte
    ld a,e                         ; $3D0B  ; advance by stride
    add c                          ; $3D0C  ; += c
    ld e,a                         ; $3D0D  ; store
    jr nc,Bg_WriteBlock            ; $3D0E  ; no carry -> loop
    inc d                          ; $3D10  ; map row carry
    jr Bg_WriteBlock               ; $3D11  ; loop

loc_3D13:
    ld a,[hl+]                     ; $3D13  ; command byte after F7
    cp $F7                         ; $3D14  ; F7 again -> repeat last?
    jr z,loc_3D0A                  ; $3D16  ; loop back
    cp $02                         ; $3D18  ; repeat command (byte $02)?
    jr z,loc_3D25                  ; $3D1A  ; custom repeat block
    and a                          ; $3D1C  ; F7,00 ends block
    ret z                          ; $3D1D  ; done
    ld c,a                         ; $3D1E  ; c = repeat count
    ld a,[hl+]                     ; $3D1F  ; repeat data address low
    ld e,a                         ; $3D20  ; low byte
    ld a,[hl+]                     ; $3D21  ; high byte
    ld d,a                         ; $3D22  ; cnt
    jr Bg_WriteBlock               ; $3D23  ; jump loop

loc_3D25:
    ld a,[hl+]                     ; $3D25  ; repeat-block: count byte -> b
    ld b,a                         ; $3D26  ; tile count

loc_3D27:
    ld a,[hl]                      ; $3D27  ; write tile
    ld [de],a                      ; $3D28  ; to map
    ld a,e                         ; $3D29  ; advance
    add c                          ; $3D2A  ; += c
    ld e,a                         ; $3D2B  ; store
    jr nc,loc_3D2F                 ; $3D2C  ; carry
    inc d                          ; $3D2E  ; map row carry

loc_3D2F:
    dec b                          ; $3D2F  ; --count
    jr nz,loc_3D27                 ; $3D30  ; loop
    inc hl                         ; $3D32  ; next
    jr Bg_WriteBlock               ; $3D33  ; loop

Title_CheckReset:
    ldh a,[$FF90]                  ; $3D35  ; reset-to-title check: FF90 bit3 clear + hold Select&Start + any press -> restart mode 0
    bit 3,a                        ; $3D37  ; FF90 bit3 must be clear
    ret nz                         ; $3D39  ; not -> return
    ldh a,[$FFBF]                  ; $3D3A  ; read merged held controls FFBF
    cp $0C                         ; $3D3C  ; == $0C (select+start held)?
    ret nz                         ; $3D3E  ; not held -> return
    ldh a,[$FFC0]                  ; $3D3F  ; read press edges FFC0
    and a                          ; $3D41  ; test press
    ret z                          ; $3D42  ; no press -> return
    xor a                          ; $3D43  ; reset request
    rst $08                        ; $3D44  ; rst $08: mode 0 restart

Rng_Next:
    push bc                        ; $3D45  ; Rng_Next: FFD7 = FFD7*5 + $0B (LFSR pseudo-random step)
    ldh a,[$FFD7]                  ; $3D46  ; seed
    ld b,a                         ; $3D48  ; SEED in b
    add a                          ; $3D49  ; *2
    add a                          ; $3D4A  ; *4
    add b                          ; $3D4B  ; + b = *5
    add $0B                        ; $3D4C  ; + $0B
    ldh [$FFD7],a                  ; $3D4E  ; FFD7 = next
    pop bc                         ; $3D50  ; restore
    ret                            ; $3D51  ; done

Div10_BC:
    ld b,$00                       ; $3D52  ; Split10: a -> b = a/10, a = a mod 10 (digits)

loc_3D54:
    sub $0A                        ; $3D54  ; subtract 10
    jr c,loc_3D5B                  ; $3D56  ; below 0 -> done
    inc b                          ; $3D58  ; ++ quotient
    jr loc_3D54                    ; $3D59  ; loop

loc_3D5B:
    add $0A                        ; $3D5B  ; restore remainder +10
    ld c,a                         ; $3D5D  ; c = remainder
    ret                            ; $3D5E  ; done

Mul10_A:
    sla a                          ; $3D5F  ; Mul10: a = a * 10 (2 bytes via shifts)
    sla a                          ; $3D61  ; *2
    ld b,a                         ; $3D63  ; b = a*2
    sla a                          ; $3D64  ; *4 more
    add b                          ; $3D66  ; + b = a*10
    ret                            ; $3D67  ; done

Mul16_AxDE:
    ld d,$00                       ; $3D68  ; Mul16_AxDE: hl = de * a (16-bit shift-add multiply)
    ld hl,$0000                    ; $3D6A  ; accumulator 0
    ld b,$08                       ; $3D6D  ; 8 bits

loc_3D6F:
    rrca                           ; $3D6F  ; rotate bit into carry
    jr nc,loc_3D73                 ; $3D70  ; bit clear -> skip add
    add hl,de                      ; $3D72  ; hl += de

loc_3D73:
    sla e                          ; $3D73  ; de <<= 1
    rl d                           ; $3D75  ; de <<= 1 (high)
    dec b                          ; $3D77  ; --bitcount
    jr nz,loc_3D6F                 ; $3D78  ; loop
    ret                            ; $3D7A  ; hl = product

CellIndex_BC:
    ld b,$00                       ; $3D7B  ; cursor-to-cell: a -> b = a/12, a = a mod 12 (grid of 12 wide, $6C = row 9 base)
    cp $6C                         ; $3D7D  ; >= 9 rows worth ($6C)?
    jr c,loc_3D85                  ; $3D7F  ; no -> normal
    sub $6C                        ; $3D81  ; subtract base $6C
    ld b,$09                       ; $3D83  ; b = 9 (row offset)

loc_3D85:
    sub $0C                        ; $3D85  ; subtract 12 repeatedly
    jr c,loc_3D8C                  ; $3D87  ; done
    inc b                          ; $3D89  ; ++ row
    jr loc_3D85                    ; $3D8A  ; loop

loc_3D8C:
    add $0C                        ; $3D8C  ; +12 restore remainder
    ret                            ; $3D8E  ; b = row index, a = column offset

Div16_Mod:
    ld c,a                         ; $3D8F  ; Div16_Mod: hl = hl / c, remainder in a (16-bit restore division)
    xor a                          ; $3D90  ; remainder 0
    ld b,$10                       ; $3D91  ; 16 bits

loc_3D93:
    add hl,hl                      ; $3D93  ; shift dividend
    rla                            ; $3D94  ; carry into remainder
    jr c,loc_3D9A                  ; $3D95  ; overflow -> subtract
    cp c                           ; $3D97  ; remainder < divisor?
    jr c,loc_3D9C                  ; $3D98  ; skip subtract (restore)

loc_3D9A:
    sub c                          ; $3D9A  ; subtract divisor
    inc l                          ; $3D9B  ; quotient LSB

loc_3D9C:
    dec b                          ; $3D9C  ; --bitcount
    jr nz,loc_3D93                 ; $3D9D  ; loop
    ret                            ; $3D9F  ; hl = quotient, a = remainder

Cmp16_HlDe:
    ld a,l                         ; $3DA0  ; cmp16: set flags for hl vs de (a=hl-de low, then high)
    sub e                          ; $3DA1  ; low subtract
    ld a,h                         ; $3DA2  ; high byte into a
    sbc d                          ; $3DA3  ; high sbc
    ret                            ; $3DA4  ; flags ready

Cmp16Eq_HlDe:
    ld a,l                         ; $3DA5  ; cmp16 eq: Z set iff hl == de
    sub e                          ; $3DA6  ; low
    ret nz                         ; $3DA7  ; differ -> done
    ld a,h                         ; $3DA8  ; high
    sbc d                          ; $3DA9  ; sbc
    ret                            ; $3DAA  ; done

Chance_Test:
    ldh [$FFD8],a                  ; $3DAB  ; chance test: FFD8 = a; success if FFD8 < $64 and RNG < l (a*2.5) -> C
    cp $64                         ; $3DAD  ; store FFD8
    ret nc                         ; $3DAF  ; >= $64 -> fail
    ld b,a                         ; $3DB0  ; b = a
    srl b                          ; $3DB1  ; b/2
    add a                          ; $3DB3  ; a*2
    add b                          ; $3DB4  ; + b = a*2.5
    ld l,a                         ; $3DB5  ; l = comparison threshold
    call Rng_Next                  ; $3DB6  ; next RNG
    cp l                           ; $3DB9  ; RNG vs threshold
    ccf                            ; $3DBA  ; CCF -> C set on success
    ret                            ; $3DBB  ; done

Chance_Accum:
    ld hl,$FFD8                    ; $3DBC  ; chance accum: FFD8 += a (cap $64), success if FFD7 < l -> C
    add [hl]                       ; $3DBF  ; += a
    ld [hl],a                      ; $3DC0  ; FFD8 = sum
    cp $64                         ; $3DC1  ; cap $64
    ret nc                         ; $3DC3  ; fail
    ld b,a                         ; $3DC4  ; b = a
    srl b                          ; $3DC5  ; b/2
    add a                          ; $3DC7  ; a*2
    add b                          ; $3DC8  ; + b
    ld l,a                         ; $3DC9  ; l threshold
    ldh a,[$FFD7]                  ; $3DCA  ; RNG seed FFD7
    cp l                           ; $3DCC  ; vs threshold
    ccf                            ; $3DCD  ; CCF -> C on success
    ret                            ; $3DCE  ; done

SoundEngine_InitWave:
    ld de,$FF30                    ; $3DCF  ; set wave RAM $FF30, expand nibble tables into $DA00/$DB90
    rst $30                        ; $3DD2  ; rst $30: copy 16-byte wave data (inline at $3DD3) to FF30-FF3F, then jp past it
    ; Wave RAM init data block $3DD3-$3E16: first byte $10 = copy length (rst $30 copies to FF30-FF3F); following bytes are the wave samples plus inline code that expands nibble tables from $D542 into tile data at $DA00 (SoundEngine_InitWave should end at $3E16)
    db $10,$00,$01,$12,$35,$8A,$CD,$EE
    db $FF,$FF,$FE,$ED,$CA,$85,$32,$11
    db $00,$21,$00,$DA,$11,$D5,$42,$06
    db $C8,$1A,$E6,$F0,$22,$1A,$E6,$0F
    db $CB,$37,$22,$13,$05,$20,$F2,$06
    db $40,$1A,$E6,$F0,$CB,$37,$CB,$5F
    db $28,$02,$F6,$F0,$22,$1A,$E6,$0F
    db $CB,$5F,$28,$02,$F6,$F0,$22,$13
    db $05,$20,$E6,$C9

SoundEngine_VBlank_Reset:
    ld a,$80                       ; $3E17  ; power on sound, clear channel masks
    ldh [$FF26],a                  ; $3E19  ; NR52 = $80 (sound on)
    xor a                          ; $3E1B  ; NR51 = 0
    ldh [$FF25],a                  ; $3E1C  ; clear output select
    ld [$DD7F],a                   ; $3E1E  ; DD7F = 0 (master state)
    ld a,$77                       ; $3E21  ; NR50 = $77 (full volume)
    ldh [$FF24],a                  ; $3E23  ; write volume
    ld hl,$DD00                    ; $3E25  ; channel slot base DD00
    ld de,$0015                    ; $3E28  ; 21-byte stride
    ld b,$06                       ; $3E2B  ; 6 slots
    ld a,$FF                       ; $3E2D  ; fill value $FF

loc_3E2F:
    ld [hl],a                      ; $3E2F  ; store
    add hl,de                      ; $3E30  ; next slot
    dec b                          ; $3E31  ; --slot
    jr nz,loc_3E2F                 ; $3E32  ; loop

loc_3E34:
    ldh a,[$FFAE]                  ; $3E34  ; FFAE sound-on flag
    set 7,a                        ; $3E36  ; set bit7
    ldh [$FFAE],a                  ; $3E38  ; FFAE |= $80
    ret                            ; $3E3A  ; done

Snd_StopFlag:
    ldh a,[$FFAE]                  ; $3E3B  ; power-off helper: clear FFAE bit7 (mark sound stopped)
    res 7,a                        ; $3E3D  ; clear bit7
    ldh [$FFAE],a                  ; $3E3F  ; FFAE &= ~$80
    ret                            ; $3E41  ; done

Sfx_PlayA:
    call SoundEngine_PlayEffect    ; $3E42  ; Sfx_PlayA: relay entry (jp $3464/$34A9) for sfx in a

Sfx_PlayB:
    call SoundEngine_PlayEffect    ; $3E45  ; trigger (play sfx in a quickly for title blips)

Sfx_PlayC:
    call SoundEngine_PlayEffect    ; $3E48  ; trigger (high-pitch footstep/collect blips via jp $14F8/$1509/$2E44)

SoundEngine_PlayEffect:
    push bc                        ; $3E4B  ; a=sfx id: header at SFX_Header_Table[a*4]=[slot,?,ptr]
    push de                        ; $3E4C  ; save regs
    push hl                        ; $3E4D  ; save hl
    ld [$DD86],a                   ; $3E4E  ; DD86 = effect id
    ld l,a                         ; $3E51  ; index -> hl
    ld h,$00                       ; $3E52  ; hl = a
    add hl,hl                      ; $3E54  ; *2
    add hl,hl                      ; $3E55  ; *4
    ld de,$43DD                    ; $3E56  ; header table base $43DD (SFX_Header_Table)
    add hl,de                      ; $3E59  ; + a*4
    push hl                        ; $3E5A  ; save header ptr
    pop de                         ; $3E5B  ; de = &header[0]
    ld a,[de]                      ; $3E5C  ; channel slot id
    inc de                         ; $3E5D  ; next
    ld c,a                         ; $3E5E  ; c = slot
    ld b,$00                       ; $3E5F  ; b = 0
    ld hl,$DD00                    ; $3E61  ; channel state base DD00
    add hl,bc                      ; $3E64  ; + slot
    xor a                          ; $3E65  ; zero state byte
    ld [hl+],a                     ; $3E66  ; write
    ld a,[de]                      ; $3E67  ; second header id
    inc de                         ; $3E68  ; next header
    ld [hl+],a                     ; $3E69  ; store channel 2nd
    ld a,[de]                      ; $3E6A  ; third header id
    inc de                         ; $3E6B  ; next header
    ld [hl+],a                     ; $3E6C  ; store channel 3rd
    ld a,[de]                      ; $3E6D  ; fourth header id
    inc de                         ; $3E6E  ; next header
    ld [hl],a                      ; $3E6F  ; channel state stores
    ld a,[$DD86]                   ; $3E70  ; effect id
    inc a                          ; $3E73  ; ++ (return value marker)
    pop hl                         ; $3E74  ; restore
    pop de                         ; $3E75  ; restore
    pop bc                         ; $3E76  ; restore
    ret                            ; $3E77  ; done

SoundEngine_ChannelInit:
    xor a                          ; $3E78  ; start channel: copy DDxx state into FFE8+
    ld [$DD7E],a                   ; $3E79  ; DD7E = 0 (start count)
    ld [$DD85],a                   ; $3E7C  ; DD85 = 0 (progress)
    ld hl,$DD84                    ; $3E7F  ; DD84
    inc [hl]                       ; $3E82  ; ++ frame/step counter
    ld hl,$DD00                    ; $3E83  ; state source DD00

loc_3E86:
    push hl                        ; $3E86  ; save base
    ld de,$FFE8                    ; $3E87  ; copy destination FFE8
    ld b,$15                       ; $3E8A  ; 21 bytes

loc_3E8C:
    ld a,[hl+]                     ; $3E8C  ; byte
    ld [de],a                      ; $3E8D  ; store
    inc e                          ; $3E8E  ; next
    dec b                          ; $3E8F  ; --count
    jr nz,loc_3E8C                 ; $3E90  ; loop
    ldh a,[$FFE9]                  ; $3E92  ; channel select (FFE9)
    and $03                        ; $3E94  ; & $03
    ld [$DD80],a                   ; $3E96  ; DD80 = channel
    ld b,a                         ; $3E99  ; b = channel
    add a                          ; $3E9A  ; *2
    add a                          ; $3E9B  ; *4
    add b                          ; $3E9C  ; + b = *5
    ld [$DD83],a                   ; $3E9D  ; DD83 = 5*channel (wave offset)
    inc b                          ; $3EA0  ; ++ (bit position)
    ld a,$88                       ; $3EA1  ; bit mask start $88

loc_3EA3:
    rlca                           ; $3EA3  ; rotate to channel bit
    dec b                          ; $3EA4  ; --count
    jr nz,loc_3EA3                 ; $3EA5  ; loop
    ld [$DD81],a                   ; $3EA7  ; DD81 = channel mask
    ld [$DD82],a                   ; $3EAA  ; DD82 = channel mask (2P copy)
    ldh a,[$FFE8]                  ; $3EAD  ; state id byte (FFE8)
    and a                          ; $3EAF  ; 0 = idle
    jr z,SoundEngine_StreamStart   ; $3EB0  ; -> idle branch (loc_3F11)
    cp $FF                         ; $3EB2  ; $FF = stop?
    jr z,loc_3EFA                  ; $3EB4  ; -> stop branch (loc_3EFA)
    call loc_417A                  ; $3EB6  ; active: run envelope advance loc_417A
    call loc_41BF                  ; $3EB9  ; run freq advance loc_41BF (both in region 13+)
    ldh a,[$FFF4]                  ; $3EBC  ; save progress nibble FFF4
    ld b,a                         ; $3EBE  ; b = FFF4 (branch: channel update continues past $3EBF)
    ldh a,[$FFF5]                  ; $3EBF  ; region 13 continues channel update
    inc a                          ; $3EC1  ; channel step clock FFF5: ++progress counter
    cp b                           ; $3EC2  ; compare high-nibble speed FFF4
    jr c,loc_3EC6                  ; $3EC3  ; below cap -> use
    ld a,b                         ; $3EC5  ; clamp to cap (b)

loc_3EC6:
    ldh [$FFF5],a                  ; $3EC6  ; FF F5 = progress (pitch glide position)
    ld hl,$FFED                    ; $3EC8  ; channel duration counter FFED
    dec [hl]                       ; $3ECB  ; duration -1
    ld a,[hl]                      ; $3ECC  ; read
    bit 7,a                        ; $3ECD  ; negative = expired
    jr z,loc_3EE2                  ; $3ECF  ; not expired -> next
    ldh a,[$FFEC]                  ; $3ED1  ; read FFEC (duration reload + control byte)
    and $0F                        ; $3ED3  ; low nibble = base duration
    ld [hl],a                      ; $3ED5  ; reload duration
    call SoundEngine_Vibrato       ; $3ED6  ; run vibrato stage
    ld hl,$FFEF                    ; $3ED9  ; step counter FFEF
    dec [hl]                       ; $3EDC  ; -1
    jr nz,loc_3EE2                 ; $3EDD  ; still counting -> next

loc_3EDF:
    call SoundEngine_Step          ; $3EDF  ; next note command via SoundEngine_Step

loc_3EE2:
    ld a,[$DD81]                   ; $3EE2  ; sound-active mask: DD7E |= DD81 (mark channel busy)
    ld b,a                         ; $3EE5  ; channel bit mask DD81
    ld a,[$DD7E]                   ; $3EE6  ; active mask DD7E
    or b                           ; $3EE9  ; merge
    ld [$DD7E],a                   ; $3EEA  ; DD7E = active mask
    pop hl                         ; $3EED  ; hl = channel state base (pushed by ChannelInit)
    push hl                        ; $3EEE  ; keep
    ld de,$FFE8                    ; $3EEF  ; copy window FFE8-FFFC back
    ld b,$15                       ; $3EF2  ; 21 bytes

loc_3EF4:
    ld a,[de]                      ; $3EF4  ; copy byte
    ld [hl+],a                     ; $3EF5  ; write back
    inc e                          ; $3EF6  ; next
    dec b                          ; $3EF7  ; -1
    jr nz,loc_3EF4                 ; $3EF8  ; loop

loc_3EFA:
    pop hl                         ; $3EFA  ; hl popped = channel base
    ld de,$0015                    ; $3EFB  ; + $15 = next channel slot
    add hl,de                      ; $3EFE  ; next channel base
    ld a,[$DD85]                   ; $3EFF  ; channel-update counter DD85
    inc a                          ; $3F02  ; +1
    ld [$DD85],a                   ; $3F03  ; DD85++
    cp $06                         ; $3F06  ; 6 channels updated?
    jp c,loc_3E86                  ; $3F08  ; not yet -> continue ChannelInit loop
    ld a,[$DD7F]                   ; $3F0B  ; master output mask DD7F
    ldh [$FF25],a                  ; $3F0E  ; NR51 (FF25) = channel output select
    ret                            ; $3F10  ; frame done

SoundEngine_StreamStart:
    ldh a,[$FFEA]                  ; $3F11  ; stream initialize (idle/stop entry): load first stream bytes into channel window
    ld l,a                         ; $3F13  ; stream ptr low FFE9
    ldh a,[$FFEB]                  ; $3F14  ; stream ptr high FFEB
    ld h,a                         ; $3F16  ; hl = note stream pointer
    ld a,[hl+]                     ; $3F17  ; first byte
    and $0F                        ; $3F18  ; low nibble = length
    ldh [$FFED],a                  ; $3F1A  ; FFED = duration
    ld d,a                         ; $3F1C  ; save a
    ld a,[$DD80]                   ; $3F1D  ; channel number DD80
    cp $02                         ; $3F20  ; wave channel (2)?
    jr z,loc_3F4D                  ; $3F22  ; yes -> wave init
    ld a,[hl+]                     ; $3F24  ; next byte
    rrca                           ; $3F25  ; >> rotate
    rrca                           ; $3F26  ; >> rotate
    and $C0                        ; $3F27  ; keep top 2 bits
    or d                           ; $3F29  ; merge length

loc_3F2A:
    ldh [$FFEC],a                  ; $3F2A  ; FFEC = control+duration byte
    ld a,[hl+]                     ; $3F2C  ; next byte
    swap a                         ; $3F2D  ; swap nibbles
    ldh [$FFEE],a                  ; $3F2F  ; FFEE = volume / wave index
    ld a,[$DD80]                   ; $3F31  ; channel#
    cp $02                         ; $3F34  ; wave?
    jr z,loc_3F3B                  ; $3F36  ; wave -> skip pitch
    ld a,[hl+]                     ; $3F38  ; next byte
    ldh [$FFF0],a                  ; $3F39  ; FF F0 = pitch slide

loc_3F3B:
    xor a                          ; $3F3B  ; clear window
    ldh [$FFF1],a                  ; $3F3C  ; FF F1 = 0 (speed A)
    ldh [$FFF2],a                  ; $3F3E  ; FF F2 = 0 (speed B)
    ldh [$FFF3],a                  ; $3F40  ; FF F3 = 0 (bend/ratio)
    ldh [$FFF6],a                  ; $3F42  ; FF F6 = 0 (vibrato)
    dec a                          ; $3F44  ; a = -1
    ldh [$FFFC],a                  ; $3F45  ; FF FC = $FF (no pending)
    ld a,$02                       ; $3F47  ; first run count
    ldh [$FFE8],a                  ; $3F49  ; FF E8 = 2 (start at step 2)
    jr loc_3EDF                    ; $3F4B  ; run one note step

loc_3F4D:
    ld a,[hl+]                     ; $3F4D  ; wave channel (Ch1/Ch2 special): negate pitch slide
    cpl                            ; $3F4E  ; invert
    inc a                          ; $3F4F  ; +1
    ldh [$FFF0],a                  ; $3F50  ; FF F0 = -pitch slide
    ld a,d                         ; $3F52  ; length in a
    jr loc_3F2A                    ; $3F53  ; join common init

SoundEngine_Step:
    ldh a,[$FFE8]                  ; $3F55  ; SoundEngine_Step: index stream by FFE8
    ld l,a                         ; $3F57  ; step index low (l)
    ld h,$00                       ; $3F58  ; zero high
    add hl,hl                      ; $3F5A  ; x2 (two bytes per stream command)
    ldh a,[$FFEA]                  ; $3F5B  ; sequence ptr low FFEA
    ld e,a                         ; $3F5D  ; e = ptr low
    ldh a,[$FFEB]                  ; $3F5E  ; sequence ptr high FFEB
    ld d,a                         ; $3F60  ; d = ptr high
    add hl,de                      ; $3F61  ; hl = stream + 2*step

SoundEngine_NextCommand:
    ldh a,[$FFE8]                  ; $3F62  ; dispatch: >=D0 env, >=B0 rest, >=A0 bank1 cmds, else note
    inc a                          ; $3F64  ; step+1
    ldh [$FFE8],a                  ; $3F65  ; FFE8 = next step (advance past this command)
    ld a,[hl+]                     ; $3F67  ; read command byte
    cp $D0                         ; $3F68  ; >= D0?
    jr nc,SoundEngine_EnvOp        ; $3F6A  ; env op (vibrato / loop / stop)
    cp $B0                         ; $3F6C  ; >= B0?
    jr nc,SoundEngine_RestOp       ; $3F6E  ; rest/length control
    cp $A0                         ; $3F70  ; >= A0?
    jp nc,SoundEngine_CmdBank1     ; $3F72  ; bank-1 extended command
    jp SoundEngine_Nrxx_Set        ; $3F75  ; note play (register write path)

loc_3F78:
    cp $FD                         ; $3F78  ; FD = loop marker?
    jr nz,loc_3F83                 ; $3F7A  ; not loop -> check FF
    ldh a,[$FFE8]                  ; $3F7C  ; step at loop marker
    ldh [$FFFB],a                  ; $3F7E  ; FFFB = loop position (saved)

loc_3F80:
    inc hl                         ; $3F80  ; skip operand byte
    jr SoundEngine_NextCommand     ; $3F81  ; continue to next command

loc_3F83:
    cp $FF                         ; $3F83  ; FF = stop track?
    jr nz,loc_3F80                 ; $3F85  ; not stop -> just skip
    ldh [$FFE8],a                  ; $3F87  ; FFE8 = FF (state=stop)
    call SoundEngine_MaskOff       ; $3F89  ; clear channel from output mask
    ret                            ; $3F8C  ; done

SoundEngine_EnvOp:
    cp $F0                         ; $3F8D  ; SoundEngine_EnvOp
    jr nc,loc_3F78                 ; $3F8F  ; >= F0 = loop/stop family
    cp $E0                         ; $3F91  ; >= E0 = negative vibrato
    jr nc,loc_3F99                 ; $3F93  ; -> loc_3F99
    and $0F                        ; $3F95  ; low nibble = vibrato amount (positive E0)
    jr loc_3F9D                    ; $3F97  ; common

loc_3F99:
    and $0F                        ; $3F99  ; low nibble = vibrato amount (positive)
    cpl                            ; $3F9B  ; invert (negative vibrato)
    inc a                          ; $3F9C  ; +1

loc_3F9D:
    ld b,a                         ; $3F9D  ; b = signed vibrato rate
    ld a,[$DD80]                   ; $3F9E  ; channel type DD80
    cp $02                         ; $3FA1  ; wave channel (2) skips duty/vibrato?
    jr z,loc_3FAD                  ; $3FA3  ; wave -> skip vibrato setup
    ld a,b                         ; $3FA5  ; rate
    ldh [$FFF6],a                  ; $3FA6  ; FFF6 = vibrato rate (signed)
    ld a,[hl]                      ; $3FA8  ; operand = vibrato depth
    ldh [$FFF7],a                  ; $3FA9  ; FFF7 = depth
    ldh [$FFF8],a                  ; $3FAB  ; FFF8 = vibrato counter (reset to depth)

loc_3FAD:
    inc hl                         ; $3FAD  ; skip operand
    jr SoundEngine_NextCommand     ; $3FAE  ; next command

loc_3FB0:
    and $0F                        ; $3FB0  ; C0+ / D0-family: low nibble = tick count
    ld b,a                         ; $3FB2  ; b = op count
    ld a,[$DD80]                   ; $3FB3  ; channel type
    cp $02                         ; $3FB6  ; wave?
    jr z,loc_3FC8                  ; $3FB8  ; wave -> skip
    ldh a,[$FFEE]                  ; $3FBA  ; volume FFEE
    and $0F                        ; $3FBC  ; low nibble
    jr nz,loc_3FC8                 ; $3FBE  ; nonzero volume -> skip rest-control setup
    ld a,[hl]                      ; $3FC0  ; operand = tempo
    ldh [$FFF4],a                  ; $3FC1  ; FFF4 = tempo (pitch glide ratio)
    ld a,b                         ; $3FC3  ; op count
    swap a                         ; $3FC4  ; nibble swap
    ldh [$FFF3],a                  ; $3FC6  ; FFF3 = glide control (op<<4)

loc_3FC8:
    inc hl                         ; $3FC8  ; skip operand
    jr SoundEngine_NextCommand     ; $3FC9  ; next command

SoundEngine_RestOp:
    cp $C0                         ; $3FCB  ; SoundEngine_RestOp
    jr nc,loc_3FB0                 ; $3FCD  ; >= C0 -> rest-control (loc_3FB0)
    and $0F                        ; $3FCF  ; B0+n: low nibble = rest length
    jr z,loc_3FF6                  ; $3FD1  ; zero -> no rest, continue
    ld e,a                         ; $3FD3  ; e = rest length
    ld a,[hl]                      ; $3FD4  ; operand = repeat count (0=forever)
    and a                          ; $3FD5  ; nonzero repeat?
    jr nz,loc_3FE8                 ; $3FD6  ; finite repeats -> use FFF2
    ldh a,[$FFF1]                  ; $3FD8  ; FFF1 = rest timer A
    dec a                          ; $3FDA  ; frames-1 (countdown)
    ldh [$FFF1],a                  ; $3FDB  ; save
    jr z,loc_3FFE                  ; $3FDD  ; expired -> release
    bit 7,a                        ; $3FDF  ; negative means repeat count exhausted -> hold
    jr z,loc_3FF6                  ; $3FE1  ; still counting -> keep
    ld a,e                         ; $3FE3  ; reload e
    ldh [$FFF1],a                  ; $3FE4  ; restart
    jr loc_3FF6                    ; $3FE6  ; continue

loc_3FE8:
    ldh a,[$FFF2]                  ; $3FE8  ; FFF2 = rest timer B (finite repeat)
    dec a                          ; $3FEA  ; -1
    ldh [$FFF2],a                  ; $3FEB  ; save
    jr z,loc_3FFE                  ; $3FED  ; done -> release
    bit 7,a                        ; $3FEF  ; ran out
    jr z,loc_3FF6                  ; $3FF1  ; keep counting
    ld a,e                         ; $3FF3  ; reload e
    ldh [$FFF2],a                  ; $3FF4  ; restart

loc_3FF6:
    ld a,[hl]                      ; $3FF6  ; read entry (0 = loop forever)
    and a                          ; $3FF7  ; nonzero -> plain end
    jr nz,loc_3FFC                 ; $3FF8  ; tail -> seek loop point
    ldh a,[$FFFB]                  ; $3FFA  ; saved loop pos FFFB

loc_3FFC:
    ldh [$FFE8],a                  ; $3FFC  ; FFE8 = loop point (restart stream)

loc_3FFE:
    db $C3,$55

SECTION "hbank1", ROMX[$4000], BANK[$01]

    db $3F

SoundEngine_CmdBank1:
    cp $A0                         ; $4001  ; command A0-AF handler entry
    jr nz,loc_400D                 ; $4003  ; A0 = set volume?
    ld a,[hl+]                     ; $4005  ; operand = wave/volume index
    swap a                         ; $4006  ; high nibble -> volume
    ldh [$FFEE],a                  ; $4008  ; FFEE = volume
    jp SoundEngine_NextCommand     ; $400A  ; next

loc_400D:
    cp $A1                         ; $400D  ; A1 = pitch?
    jr nz,loc_4017                 ; $400F  ; not A1
    ld a,[hl+]                     ; $4011  ; operand
    ldh [$FFF0],a                  ; $4012  ; FFF0 = pitch slide
    jp SoundEngine_NextCommand     ; $4014  ; next

loc_4017:
    cp $A2                         ; $4017  ; A2 = duty/volume selection
    jr nz,loc_403A                 ; $4019  ; not A2
    ld a,[$DD80]                   ; $401B  ; channel type
    cp $02                         ; $401E  ; wave?
    jr z,loc_4032                  ; $4020  ; wave -> negate path
    ld a,[hl+]                     ; $4022  ; operand = duty mask
    rrca                           ; $4023  ; << rotate
    rrca                           ; $4024  ; << rotate
    and $C0                        ; $4025  ; keep top 2 bits (duty)
    ld d,a                         ; $4027  ; save
    ldh a,[$FFEC]                  ; $4028  ; current NRx0 FFEC
    and $3F                        ; $402A  ; clear duty bits
    or d                           ; $402C  ; merge duty
    ldh [$FFEC],a                  ; $402D  ; save
    jp SoundEngine_NextCommand     ; $402F  ; next

loc_4032:
    ld a,[hl+]                     ; $4032  ; operand = pitch
    cpl                            ; $4033  ; invert (wave chan negative pitch)
    inc a                          ; $4034  ; +1
    ldh [$FFF0],a                  ; $4035  ; FFF0 = pitch
    jp SoundEngine_NextCommand     ; $4037  ; next

loc_403A:
    cp $A3                         ; $403A  ; A3 = duty cycle
    jr nz,loc_4058                 ; $403C  ; not A3
    ld a,[hl+]                     ; $403E  ; operand = duty
    bit 7,a                        ; $403F  ; bit7 set = keep current duty?
    jr nz,loc_4052                 ; $4041  ; keep -> clear bits path
    and $70                        ; $4043  ; high bits
    ld e,a                         ; $4045  ; e = duty pattern
    ldh a,[$FFE9]                  ; $4046  ; current header FFE9
    and $0F                        ; $4048  ; low nibble (channel type)
    or e                           ; $404A  ; merge duty
    or $80                         ; $404B  ; flag active

loc_404D:
    ldh [$FFE9],a                  ; $404D  ; FFE9 = header (duty + channel)
    jp SoundEngine_NextCommand     ; $404F  ; next

loc_4052:
    ldh a,[$FFE9]                  ; $4052  ; no operand change
    and $0F                        ; $4054  ; keep low nibble
    jr loc_404D                    ; $4056  ; merge

loc_4058:
    cp $A5                         ; $4058  ; A5 = decay control
    jr nz,loc_406A                 ; $405A  ; not A5
    ld a,[hl+]                     ; $405C  ; operand = decay
    cp $01                         ; $405D  ; decay==1 -> swap FFFC
    jr nz,loc_4065                 ; $405F  ; normal decay
    ldh a,[$FFFC]                  ; $4061  ; current decay FFFC
    swap a                         ; $4063  ; swap nibbles

loc_4065:
    ldh [$FFFC],a                  ; $4065  ; save
    jp SoundEngine_NextCommand     ; $4067  ; next

loc_406A:
    cp $A6                         ; $406A  ; A6 = master volume
    jr nz,loc_4074                 ; $406C  ; not A6
    ld a,[hl+]                     ; $406E  ; operand = volume
    ldh [$FF24],a                  ; $406F  ; NR50 FF24 = master volume
    jp SoundEngine_NextCommand     ; $4071  ; next

loc_4074:
    cp $AF                         ; $4074  ; AF = set duration
    jr nz,loc_4088                 ; $4076  ; not AF
    ld a,[hl+]                     ; $4078  ; operand = duration
    and $0F                        ; $4079  ; low nibble
    ldh [$FFED],a                  ; $407B  ; FFED = duration
    ld b,a                         ; $407D  ; save
    ldh a,[$FFEC]                  ; $407E  ; NRx0 FFEC
    and $F0                        ; $4080  ; clear duration nibble
    or b                           ; $4082  ; merge duration
    ldh [$FFEC],a                  ; $4083  ; save
    jp SoundEngine_NextCommand     ; $4085  ; next

loc_4088:
    inc hl                         ; $4088  ; unknown command: skip operand
    jp SoundEngine_NextCommand     ; $4089  ; next

loc_408C:
    call SoundEngine_MaskOff       ; $408C  ; SoundEngine_MaskOff helper: clear channel from mix (also invalid note path)
    ret                            ; $408F  ; ret

SoundEngine_Nrxx_Set:
    ld b,a                         ; $4090  ; SoundEngine_Nrxx_Set: b = note command byte
    ld a,[hl]                      ; $4091  ; operand = note/steps
    ldh [$FFEF],a                  ; $4092  ; FFEF = note step count
    ld a,[$DD80]                   ; $4094  ; channel type DD80
    cp $03                         ; $4097  ; noise channel (3)?
    jr nz,SoundEngine_Load_FreqTable ; $4099  ; not noise -> frequency table
    ld a,b                         ; $409B  ; noise: b = command
    cp $10                         ; $409C  ; noise pattern index >= 16?
    jr nc,loc_408C                 ; $409E  ; invalid -> mask off
    bit 3,a                        ; $40A0  ; bit3 = one of 8 special patterns?
    jr z,loc_40A8                  ; $40A2  ; normal pattern
    and $07                        ; $40A4  ; low bits
    add $50                        ; $40A6  ; + $50 (special noise base)

loc_40A8:
    add $10                        ; $40A8  ; + $10 (noise pattern register)
    ld l,a                         ; $40AA  ; l = NR43 pattern byte
    ld h,$00                       ; $40AB  ; h = 0
    jr loc_40C2                    ; $40AD  ; common write path

SoundEngine_Load_FreqTable:
    ld a,b                         ; $40AF  ; note 0-11 -> Freq_Table pointer, write NR13/14
    and $0F                        ; $40B0  ; note index low nibble (0-11 = semitone)
    cp $0C                         ; $40B2  ; >= 12?
    jr nc,loc_408C                 ; $40B4  ; invalid -> mask off
    ld a,b                         ; $40B6  ; b = command
    add a                          ; $40B7  ; x2 (word per entry)
    ld e,a                         ; $40B8  ; e = offset
    ld d,$00                       ; $40B9  ; d = 0
    ld hl,$4215                    ; $40BB  ; Freq_Table_S1 base $4215
    add hl,de                      ; $40BE  ; entry address
    ld a,[hl+]                     ; $40BF  ; freq low
    ld h,[hl]                      ; $40C0  ; freq high
    ld l,a                         ; $40C1  ; hl = 16-bit frequency word

loc_40C2:
    xor a                          ; $40C2  ; common register-write path
    ldh [$FFF5],a                  ; $40C3  ; FFF5 = 0 (reset slide clock)
    call SoundEngine_SfxActive_Check ; $40C5  ; skip if channel inactive
    ld a,[$DD80]                   ; $40C8  ; channel type
    cp $02                         ; $40CB  ; wave channel (2)?
    jr nz,loc_40D6                 ; $40CD  ; not wave -> skip
    xor a                          ; $40CF  ; a = 0
    ldh [$FF1A],a                  ; $40D0  ; NR30 off (wave RAM)
    ld a,$80                       ; $40D2  ; restart bit
    ldh [$FF1A],a                  ; $40D4  ; NR30 re-enabled (restart wave)

loc_40D6:
    push hl                        ; $40D6  ; push freq
    call loc_419F                  ; $40D7  ; write channel handle regs (loc_419F)
    pop hl                         ; $40DA  ; restore freq
    ld a,[$DD80]                   ; $40DB  ; channel type DD80
    and a                          ; $40DE  ; is Ch1/Ch2 (tone with sweep)?
    ldh a,[$FFF0]                  ; $40DF  ; pitch slide
    ld c,$10                       ; $40E1  ; Ch1 sweep reg NR10
    call z,loc_41B6                ; $40E3  ; write NR10 if channel 1
    ld a,l                         ; $40E6  ; freq low
    ld c,$13                       ; $40E7  ; NR13 (freq low)
    call loc_41B6                  ; $40E9  ; write
    ld a,l                         ; $40EC  ; freq low again
    cp $02                         ; $40ED  ; < 2?
    jr c,loc_40F9                  ; $40EF  ; valid low
    cp $FE                         ; $40F1  ; < $FE?
    jr c,loc_40FB                  ; $40F3  ; keep
    ld a,$FD                       ; $40F5  ; clamp high ($FD)
    jr loc_40FB                    ; $40F7  ; write

loc_40F9:
    ld a,$02                       ; $40F9  ; clamp low ($02)

loc_40FB:
    ldh [$FFF9],a                  ; $40FB  ; FFF9 = freq low (clamped)
    ld a,[$DD80]                   ; $40FD  ; channel type
    cp $02                         ; $4100  ; wave channel (2)?
    jr z,loc_4130                  ; $4102  ; wave -> separate path
    cp $02                         ; $4104  ; >2 = noise -> skip NR11
    jr nc,loc_4111                 ; $4106  ; not noise
    ldh a,[$FFEC]                  ; $4108  ; NRx0 FFEC
    and $C0                        ; $410A  ; duty/length bits
    ld c,$11                       ; $410C  ; NR11 (length/duty)
    call loc_41B6                  ; $410E  ; write

loc_4111:
    ld a,h                         ; $4111  ; freq high
    and $07                        ; $4112  ; top 3 bits only
    or $80                         ; $4114  ; set trigger bit

loc_4116:
    ldh [$FFFA],a                  ; $4116  ; FFFA = freq high + trigger
    ld c,$14                       ; $4118  ; NR14 (freq high + trigger)
    call loc_41B6                  ; $411A  ; write
    ld a,[$DD82]                   ; $411D  ; channel mask DD82
    ld b,a                         ; $4120  ; save
    cpl                            ; $4121  ; invert
    ld c,a                         ; $4122  ; c = ~mask
    ldh a,[$FFFC]                  ; $4123  ; current flag FFFC
    and b                          ; $4125  ; surviving bits
    ld b,a                         ; $4126  ; b = kept flags
    ld a,[$DD7F]                   ; $4127  ; mix mask DD7F
    and c                          ; $412A  ; clear channel from mix
    or b                           ; $412B  ; re-add kept flags
    ld [$DD7F],a                   ; $412C  ; DD7F = updated mix enable
    ret                            ; $412F  ; done

loc_4130:
    ldh a,[$FFF0]                  ; $4130  ; wave channel (2): length
    ldh [$FF1B],a                  ; $4132  ; NR31 length
    ld a,h                         ; $4134  ; freq high
    and $07                        ; $4135  ; top 3 bits
    or $C0                         ; $4137  ; set trigger + 3 bits
    jr loc_4116                    ; $4139  ; common high write (loc_4116)

SoundEngine_Vibrato:
    ld a,[$DD80]                   ; $413B  ; SoundEngine_Vibrato
    cp $02                         ; $413E  ; wave channel?
    ret z                          ; $4140  ; no vibrato on wave
    ldh a,[$FFF6]                  ; $4141  ; vibrato rate FFF6
    and a                          ; $4143  ; rate==0?
    ret z                          ; $4144  ; disabled
    ld hl,$FFF8                    ; $4145  ; FFF8 = vibrato timer
    dec [hl]                       ; $4148  ; -1
    ret nz                         ; $4149  ; not yet due
    ldh a,[$FFEE]                  ; $414A  ; volume FFEE
    swap a                         ; $414C  ; swap (high nibble = volume)
    cp $10                         ; $414E  ; >= $10 = no vibrato
    ret nc                         ; $4150  ; skip
    and $0F                        ; $4151  ; low nibble = vibrato index
    ld b,a                         ; $4153  ; b = index
    ldh a,[$FFF7]                  ; $4154  ; depth FFF7
    ldh [$FFF8],a                  ; $4156  ; reload counter
    ld hl,$FFF6                    ; $4158  ; rate FFF6
    ld a,[hl]                      ; $415B  ; read
    bit 7,a                        ; $415C  ; negative = downward sweep
    jr nz,loc_416E                 ; $415E  ; down -> decay
    dec [hl]                       ; $4160  ; up: rate-1
    ld a,b                         ; $4161  ; index
    cp $0F                         ; $4162  ; at max ($0F)?
    ret z                          ; $4164  ; stop vibrato
    ldh a,[$FFEE]                  ; $4165  ; volume FFEE
    add $10                        ; $4167  ; +$10 (raise volume)
    ldh [$FFEE],a                  ; $4169  ; save
    jp SoundEngine_Write_ChannelRegs ; $416B  ; push new volume to registers

loc_416E:
    inc [hl]                       ; $416E  ; downward: rate+1
    ld a,b                         ; $416F  ; index
    and a                          ; $4170  ; at 0?
    ret z                          ; $4171  ; stop
    ldh a,[$FFEE]                  ; $4172  ; volume FFEE
    sub $10                        ; $4174  ; -$10 (lower volume)
    ldh [$FFEE],a                  ; $4176  ; save
    jr SoundEngine_Write_ChannelRegs ; $4178  ; write registers

loc_417A:
    call SoundEngine_SfxActive_Check ; $417A  ; envelope/portamento advance (called by step loop)
    ld a,[$DD80]                   ; $417D  ; channel type DD80
    cp $03                         ; $4180  ; noise?
    ret z                          ; $4182  ; no envelope for noise
    ldh a,[$FFE9]                  ; $4183  ; header FFE9
    bit 7,a                        ; $4185  ; bit7 = signed channel?
    ret z                          ; $4187  ; plain channel
    and $70                        ; $4188  ; pattern bits
    ld b,a                         ; $418A  ; b = pattern
    ld a,[$DD84]                   ; $418B  ; wave index low nibble DD84
    and $0F                        ; $418E  ; low nibble
    or b                           ; $4190  ; pattern + wave index
    ld e,a                         ; $4191  ; e = table offset
    ld d,$00                       ; $4192  ; d = 0
    ld hl,$DB90                    ; $4194  ; $DB90 = wave blend base
    add hl,de                      ; $4197  ; entry
    ldh a,[$FFF9]                  ; $4198  ; portamento offset FFF9
    add [hl]                       ; $419A  ; add blend value
    ld c,$13                       ; $419B  ; NR13 (freq low)
    jr loc_41B6                    ; $419D  ; write

loc_419F:
    ld a,[$DD80]                   ; $419F  ; channel register helper: vector to write or slide-compute
    cp $02                         ; $41A2  ; wave channel?
    jr z,loc_41AB                  ; $41A4  ; wave -> plain volume write
    ldh a,[$FFF3]                  ; $41A6  ; glide control FFF3
    and a                          ; $41A8  ; no glide?
    jr nz,loc_41CC                 ; $41A9  ; plain -> compute freq

loc_41AB:
    ldh a,[$FFEE]                  ; $41AB  ; volume FFEE

SoundEngine_Write_ChannelRegs:
    ld c,$12                       ; $41AD  ; write a to FF00+c (c=reg#-off, DD83 base)
    call loc_41B6                  ; $41AF  ; write volume to registers
    ldh a,[$FFFA]                  ; $41B2  ; freq high FFFA
    ld c,$14                       ; $41B4  ; NR14

loc_41B6:
    ld b,a                         ; $41B6  ; write_reg helper: FF00+DD83+c = a (reg base + offset)
    ld a,[$DD83]                   ; $41B7  ; channel reg base DD83
    add c                          ; $41BA  ; + offset
    ld c,a                         ; $41BB  ; c = base+offset
    ld a,b                         ; $41BC  ; value
    ld [$FF00+c],a                 ; $41BD  ; write to sound reg
    ret                            ; $41BE  ; ret

loc_41BF:
    ldh a,[$FFF3]                  ; $41BF  ; frequency advance (called after envelope)
    and a                          ; $41C1  ; glide control FFF3
    ret z                          ; $41C2  ; no glide -> skip
    ld a,[$DD80]                   ; $41C3  ; channel type
    cp $02                         ; $41C6  ; wave channel?
    ret z                          ; $41C8  ; wave -> skip bend
    call SoundEngine_SfxActive_Check ; $41C9  ; skip if channel inactive

loc_41CC:
    ld e,$00                       ; $41CC  ; divide: e = 4-bit result of FFF5/FFF4 (proportion)
    ldh a,[$FFF4]                  ; $41CE  ; divisor = tempo FFF4
    ld c,a                         ; $41D0  ; c = divisor
    ldh a,[$FFF5]                  ; $41D1  ; dividend = slide clock FFF5
    ld b,$04                       ; $41D3  ; 4 bits

loc_41D5:
    sla a                          ; $41D5  ; shift and compare (long-division)
    cp c                           ; $41D7  ; >= divisor?
    jr c,loc_41DB                  ; $41D8  ; skip subtract
    sub c                          ; $41DA  ; subtract

loc_41DB:
    ccf                            ; $41DB  ; compl. carry
    rl e                           ; $41DC  ; shift result into e
    dec b                          ; $41DE  ; next bit
    jr nz,loc_41D5                 ; $41DF  ; loop
    ldh a,[$FFF3]                  ; $41E1  ; glide control FFF3
    or e                           ; $41E3  ; merge proportion
    ld e,a                         ; $41E4  ; e = combined slide index
    ld d,$00                       ; $41E5  ; d = 0
    ld hl,$DAF0                    ; $41E7  ; $DAF0 = slide/wave table
    add hl,de                      ; $41EA  ; entry
    ldh a,[$FFEE]                  ; $41EB  ; volume FFEE
    swap a                         ; $41ED  ; swap
    and $0F                        ; $41EF  ; low nibble
    or [hl]                        ; $41F1  ; blend table nibble
    ld e,a                         ; $41F2  ; e = wave byte index
    ld hl,$DA00                    ; $41F3  ; wave data $DA00
    add hl,de                      ; $41F6  ; byte
    ld a,[hl]                      ; $41F7  ; vol = wave byte
    jr SoundEngine_Write_ChannelRegs ; $41F8  ; write to channel regs (volume)

SoundEngine_MaskOff:
    call SoundEngine_SfxActive_Check ; $41FA  ; SoundEngine_MaskOff: clear channel's mix bit
    ld a,[$DD81]                   ; $41FD  ; channel mask DD81
    cpl                            ; $4200  ; invert
    ld b,a                         ; $4201  ; b = ~mask
    ld a,[$DD7F]                   ; $4202  ; mix mask DD7F
    and b                          ; $4205  ; clear channel from mix
    ld [$DD7F],a                   ; $4206  ; save
    ret                            ; $4209  ; done

SoundEngine_SfxActive_Check:
    ld a,[$DD81]                   ; $420A  ; if DD81 off, pop ret (suppress double update)
    ld b,a                         ; $420D  ; channel mask DD81
    ld a,[$DD7E]                   ; $420E  ; active mask DD7E
    and b                          ; $4211  ; channel live?
    ret z                          ; $4212  ; yes -> continue normally
    pop af                         ; $4213  ; not active: pop return addr (suppress the work)
    ret                            ; $4214  ; ret

Freq_Table_S1:
    ; Freq ramp table #1 (12 notes x2b): C..B for instrument 0
    db $2C,$00,$9C,$00,$07,$01,$6B,$01
    db $C9,$01,$23,$02,$77,$02,$C6,$02
    db $10,$03,$58,$03,$9B,$03,$DA,$03
    db $00,$00,$00,$00,$00,$00,$00,$00
    ; Freq ramp table #2
    db $16,$04,$4E,$04,$83,$04,$B5,$04
    db $E4,$04,$11,$05,$3B,$05,$63,$05
    db $88,$05,$AC,$05,$CD,$05,$ED,$05
    db $00,$00,$00,$00,$00,$00,$00,$00
    ; Freq ramp table #3
    db $0B,$06,$27,$06,$42,$06,$5B,$06
    db $72,$06,$89,$06,$9E,$06,$B1,$06
    db $C4,$06,$D6,$06,$E7,$06,$F5,$06
    db $00,$00,$00,$00,$00,$00,$00,$00
    ; Freq ramp table #4
    db $05,$07,$13,$07,$21,$07,$2D,$07
    db $39,$07,$44,$07,$4F,$07,$59,$07
    db $62,$07,$6B,$07,$73,$07,$7B,$07
    db $00,$00,$00,$00,$00,$00,$00,$00
    ; Freq ramp table #5
    db $83,$07,$8A,$07,$90,$07,$97,$07
    db $9D,$07,$A2,$07,$A7,$07,$AC,$07
    db $B1,$07,$B5,$07,$BA,$07,$BE,$07
    db $00,$00,$00,$00,$00,$00,$00,$00
    ; Freq ramp table #6
    db $C1,$07,$C5,$07,$C8,$07,$CB,$07
    db $CE,$07,$D1,$07,$D4,$07,$D6,$07
    db $D8,$07,$DB,$07,$DD,$07,$DF,$07
    db $00,$00,$00,$00,$00,$00,$00,$00

Wave_Table:
    ; Waveform data (nibble->byte, 0xC8 then 0x40 items)
    db $00,$00,$00,$00,$00,$00,$00,$00
    db $00,$00,$00,$00,$11,$11,$11,$11
    db $00,$00,$11,$11,$11,$11,$22,$22
    db $00,$01,$11,$11,$22,$22,$23,$33
    db $00,$11,$11,$22,$22,$33,$33,$44
    db $00,$11,$12,$22,$33,$34,$44,$55
    db $00,$11,$22,$23,$34,$44,$55,$66
    db $00,$11,$22,$33,$44,$55,$66,$77
    db $01,$12,$23,$34,$45,$56,$67,$78
    db $01,$12,$23,$44,$55,$67,$78,$89
    db $01,$12,$33,$45,$56,$77,$89,$9A
    db $01,$12,$34,$45,$67,$78,$9A,$AB
    db $01,$22,$34,$56,$67,$89,$AA,$BC
    db $01,$23,$34,$56,$78,$9A,$AB,$CD
    db $01,$23,$45,$67,$78,$9A,$BC,$DE
    db $01,$23,$45,$67,$89,$AB,$CD,$EF
    db $FE,$DC,$BA,$98,$76,$54,$32,$10
    db $01,$23,$45,$67,$89,$AB,$CD,$EF
    db $FE,$DC,$BA,$98,$89,$AB,$CD,$EF
    db $89,$AB,$CD,$EF,$FE,$DC,$BA,$98
    db $FD,$B9,$75,$31,$EC,$A8,$64,$20
    db $FE,$DC,$CD,$ED,$CA,$86,$42,$10
    db $FD,$B9,$AB,$97,$65,$43,$21,$10
    db $44,$44,$44,$46,$67,$8A,$CF,$B8
    db $FF,$A8,$FF,$A8,$77,$66,$55,$42
    db $00,$11,$00,$FF,$00,$11,$00,$FF
    db $00,$00,$11,$11,$00,$00,$FF,$FF
    db $01,$21,$0F,$EF,$01,$21,$0F,$EF
    db $00,$11,$22,$11,$00,$FF,$EE,$FF
    db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
    db $EE,$EE,$EE,$EE,$EE,$EE,$EE,$EE
    db $11,$11,$11,$11,$11,$11,$11,$11
    db $22,$22,$22,$22,$22,$22,$22,$22

SFX_Header_Table:
    ; SFX/song header table: [slot(0/15/2A/3F/54/69), flags, ptrlo, ptrhi]
    db $15,$01,$91,$44,$15,$01,$9C,$44
    db $54,$00,$A3,$44,$54,$00,$B0,$44
    db $00,$00,$BF,$44,$54,$00,$CE,$44
    db $00,$00,$D7,$44,$15,$01,$FC,$44
    db $00,$00,$23,$45,$00,$00,$2E,$45
    db $00,$00,$35,$45,$54,$00,$40,$45
    db $00,$00,$49,$45,$15,$01,$58,$45
    db $00,$00,$69,$45,$00,$00,$74,$45
    db $54,$00,$7F,$45,$69,$02,$8E,$45
    db $69,$02,$15,$46,$00,$00,$5E,$46
    db $15,$01,$83,$46,$00,$00,$AA,$46
    db $00,$00,$B7,$46,$2A,$02,$20,$47
    db $3F,$03,$CD,$47,$00,$00,$43,$4B
    db $3F,$03,$2B,$4B,$15,$01,$34,$4B
    db $00,$00,$0B,$4A,$00,$00,$BC,$49
    db $15,$01,$7C,$48,$2A,$02,$B3,$48
    db $3F,$03,$D4,$48,$00,$00,$F7,$48
    db $2A,$02,$0C,$49,$3F,$03,$25,$49
    db $00,$00,$16,$4A,$15,$01,$83,$4A
    db $3F,$03,$F8,$4A,$00,$00,$36,$49
    db $15,$01,$5B,$49,$2A,$02,$7E,$49
    db $3F,$03,$A1,$49,$00,$00,$FA,$49
    db $00,$00,$F1,$49

Sound_Sequence_Data:
    ; SFX 00 sequence data (SFX_Header_Table id(00) == $4491; also Sound_Sequence_Data)
    db $00,$02,$5B,$00,$C5,$04,$30,$01
    db $30,$02,$FF

Sfx_Seq_01:
    ; SFX 01 sequence data (SFX_Header_Table id(01) == $449C)
    db $01,$02,$27,$00,$49,$01,$FF

Sfx_Seq_02:
    ; SFX 02 sequence data (SFX_Header_Table id(02) == $44A3)
    db $01,$02,$A8,$25,$C2,$02,$37,$02
    db $A1,$2D,$3B,$02,$FF

Sfx_Seq_03:
    ; SFX 03 sequence data (SFX_Header_Table id(03) == $44B0)
    db $01,$02,$59,$16,$A5,$0F,$C9,$03
    db $27,$01,$1F,$01,$B5,$02,$FF

Sfx_Seq_04:
    ; SFX 04 sequence data (SFX_Header_Table id(04) == $44BF)
    db $01,$01,$3B,$00,$C1,$40,$30,$02
    db $34,$02,$37,$02,$40,$02,$FF

Sfx_Seq_05:
    ; SFX 05 sequence data (SFX_Header_Table id(05) == $44CE)
    db $01,$02,$26,$89,$37,$01,$47,$01
    db $FF

Sfx_Seq_06:
    ; SFX 06 sequence data (SFX_Header_Table id(06) == $44D7)
    db $01,$02,$01,$00,$1F,$01,$DF,$04
    db $37,$01,$1F,$03,$38,$01,$1F,$03
    db $39,$01,$1F,$03,$3A,$01,$1F,$03
    db $3B,$01,$1F,$03,$40,$01,$1F,$03
    db $41,$01,$1F,$03,$FF

Sfx_Seq_07:
    ; SFX 07 sequence data (SFX_Header_Table id(07) == $44FC)
    db $01,$02,$01,$00,$1F,$01,$DF,$06
    db $1F,$01,$37,$01,$1F,$03,$38,$01
    db $1F,$03,$39,$01,$1F,$03,$3A,$01
    db $1F,$03,$3B,$01,$1F,$03,$40,$01
    db $1F,$03,$41,$01,$1F,$03,$FF

Sfx_Seq_08:
    ; SFX 08 sequence data (SFX_Header_Table id(08) == $4523)
    db $03,$02,$07,$3A,$EF,$03,$40,$04
    db $BE,$03,$FF

Sfx_Seq_09:
    ; SFX 09 sequence data (SFX_Header_Table id(09) == $452E)
    db $03,$02,$47,$36,$37,$04,$FF

Sfx_Seq_0A:
    ; SFX 0A sequence data (SFX_Header_Table id(0A) == $4535)
    db $07,$00,$05,$2C,$EE,$02,$C2,$02
    db $30,$08,$FF

Sfx_Seq_0B:
    ; SFX 0B sequence data (SFX_Header_Table id(0B) == $4540)
    db $00,$02,$49,$27,$C9,$02,$10,$01
    db $FF

Sfx_Seq_0C:
    ; SFX 0C sequence data (SFX_Header_Table id(0C) == $4549)
    db $01,$02,$39,$00,$EF,$01,$FD,$FE
    db $49,$01,$52,$01,$B7,$00,$FF

Sfx_Seq_0D:
    ; SFX 0D sequence data (SFX_Header_Table id(0D) == $4558)
    db $01,$02,$39,$00,$C9,$02,$EF,$01
    db $FD,$FE,$49,$01,$52,$01,$B7,$00
    db $FF

Sfx_Seq_0E:
    ; SFX 0E sequence data (SFX_Header_Table id(0E) == $4569)
    db $01,$02,$2C,$36,$C5,$04,$42,$01
    db $52,$03,$FF

Sfx_Seq_0F:
    ; SFX 0F sequence data (SFX_Header_Table id(0F) == $4574)
    db $01,$00,$6D,$2F,$FD,$FE,$36,$01
    db $BA,$00,$FF

Sfx_Seq_10:
    ; SFX 10 sequence data (SFX_Header_Table id(10) == $457F)
    db $01,$02,$59,$16,$A5,$F0,$C9,$03
    db $27,$01,$1F,$01,$B5,$02,$FF

Sfx_Seq_11:
    ; SFX 11 sequence data (SFX_Header_Table id(11) == $458E)
    db $08,$20,$02,$00,$35,$01,$1F,$02
    db $35,$01,$1F,$01,$29,$01,$2A,$01
    db $2B,$01,$30,$01,$35,$01,$1F,$01
    db $37,$01,$1F,$01,$35,$01,$35,$01
    db $30,$01,$FD,$FE,$25,$01,$1F,$02
    db $30,$01,$30,$01,$1F,$02,$25,$01
    db $25,$01,$1F,$02,$30,$01,$1F,$01
    db $30,$01,$23,$01,$24,$01,$B1,$00
    db $FD,$FE,$2A,$01,$1F,$02,$35,$01
    db $35,$01,$1F,$02,$2A,$01,$2A,$01
    db $1F,$02,$35,$01,$1F,$01,$35,$01
    db $28,$01,$29,$01,$B1,$00,$FE,$FE
    db $FD,$FE,$27,$01,$27,$01,$27,$01
    db $32,$01,$1F,$01,$32,$01,$2A,$01
    db $2B,$01,$30,$01,$30,$01,$30,$01
    db $37,$01,$1F,$01,$37,$01,$1F,$01
    db $30,$01,$B1,$00,$B0,$02,$FF

Sfx_Seq_12:
    ; SFX 12 sequence data (SFX_Header_Table id(12) == $4615)
    db $06,$25,$02,$00,$FD,$FE,$27,$02
    db $32,$01,$1F,$01,$31,$02,$32,$01
    db $1F,$09,$27,$02,$32,$01,$1F,$01
    db $31,$02,$32,$01,$1F,$01,$35,$03
    db $34,$03,$30,$02,$B2,$00,$22,$01
    db $27,$01,$32,$01,$21,$01,$27,$01
    db $31,$01,$20,$01,$27,$01,$30,$01
    db $1A,$01,$27,$01,$2A,$01,$27,$01
    db $17,$01,$27,$01,$17,$01,$B0,$02
    db $FF

Sfx_Seq_13:
    ; SFX 13 sequence data (SFX_Header_Table id(13) == $465E)
    db $01,$02,$08,$00,$1F,$01,$EF,$03
    db $42,$01,$1F,$03,$41,$01,$1F,$03
    db $40,$01,$1F,$03,$3B,$01,$1F,$03
    db $3A,$01,$1F,$03,$39,$01,$1F,$03
    db $38,$01,$1F,$03,$FF

Sfx_Seq_14:
    ; SFX 14 sequence data (SFX_Header_Table id(14) == $4683)
    db $01,$02,$07,$00,$1F,$01,$EF,$02
    db $1F,$01,$42,$01,$1F,$03,$41,$01
    db $1F,$03,$40,$01,$1F,$03,$3B,$01
    db $1F,$03,$3A,$01,$1F,$02,$39,$01
    db $1F,$03,$38,$01,$1F,$03,$FF

Sfx_Seq_15:
    ; SFX 15 sequence data (SFX_Header_Table id(15) == $46AA)
    db $02,$02,$0A,$2C,$ED,$01,$37,$01
    db $1F,$02,$B6,$02,$FF

Sfx_Seq_16:
    ; SFX 16 sequence data (SFX_Header_Table id(16) == $46B7)
    db $06,$03,$2A,$00,$A3,$21,$1F,$10
    db $FD,$FE,$33,$02,$34,$01,$1F,$01
    db $36,$01,$1F,$02,$34,$01,$33,$02
    db $34,$01,$38,$01,$1F,$01,$34,$02
    db $32,$11,$34,$02,$37,$01,$35,$01
    db $1F,$01,$34,$01,$1F,$01,$32,$01
    db $1F,$01,$30,$01,$1F,$01,$2B,$01
    db $1F,$01,$32,$01,$2B,$01,$30,$01
    db $31,$01,$31,$01,$39,$01,$39,$01
    db $31,$01,$31,$01,$39,$01,$39,$01
    db $32,$01,$32,$01,$32,$01,$32,$01
    db $1F,$04,$B2,$00,$FD,$FE,$29,$01
    db $1F,$02,$B1,$00,$29,$01,$29,$01
    db $FF

Sfx_Seq_17:
    ; SFX 17 sequence data (SFX_Header_Table id(17) == $4720)
    db $06,$1A,$02,$00,$A5,$0F,$24,$01
    db $24,$01,$A5,$01,$54,$01,$54,$01
    db $A5,$01,$34,$01,$34,$01,$A5,$01
    db $54,$01,$54,$01,$A5,$FF,$24,$01
    db $1F,$01,$1B,$01,$24,$01,$1F,$01
    db $24,$01,$26,$01,$28,$01,$FD,$FE
    db $19,$01,$1F,$02,$24,$01,$24,$01
    db $1F,$02,$18,$01,$19,$01,$1F,$01
    db $24,$01,$1F,$02,$24,$01,$19,$01
    db $18,$01,$17,$01,$1F,$02,$22,$01
    db $22,$01,$1F,$02,$16,$01,$17,$01
    db $1F,$01,$22,$01,$1F,$01,$22,$01
    db $22,$01,$23,$01,$24,$01,$25,$01
    db $1F,$02,$20,$01,$20,$01,$1F,$02
    db $16,$01,$17,$01,$1F,$02,$22,$01
    db $22,$01,$1F,$02,$17,$01,$A5,$0F
    db $19,$01,$A5,$F0,$19,$01,$1F,$02
    db $A5,$0F,$19,$01,$A5,$F0,$19,$01
    db $1F,$02,$A5,$FF,$24,$01,$24,$01
    db $24,$01,$24,$01,$1F,$04,$B2,$00
    db $FD,$FE,$19,$01,$1F,$02,$B1,$00
    db $19,$01,$19,$01,$FF

Sfx_Seq_18:
    ; SFX 18 sequence data (SFX_Header_Table id(18) == $47CD)
    db $06,$00,$14,$00,$FD,$FE,$03,$01
    db $03,$01,$01,$01,$01,$01,$B1,$00
    db $FD,$FE,$03,$01,$01,$01,$01,$01
    db $B1,$00,$03,$01,$01,$01,$FD,$FE
    db $03,$01,$1F,$01,$01,$01,$03,$01
    db $1F,$01,$01,$01,$03,$01,$1F,$01
    db $01,$01,$01,$01,$03,$01,$1F,$01
    db $01,$01,$03,$01,$1F,$01,$01,$01
    db $03,$01,$1F,$01,$01,$01,$03,$01
    db $1F,$01,$01,$01,$03,$01,$1F,$01
    db $01,$01,$01,$01,$03,$01,$1F,$01
    db $03,$01,$1F,$01,$01,$01,$01,$01
    db $03,$01,$1F,$01,$01,$01,$03,$01
    db $1F,$01,$01,$01,$03,$01,$1F,$01
    db $01,$01,$01,$01,$03,$01,$1F,$01
    db $01,$01,$03,$01,$1F,$01,$01,$01
    db $05,$01,$05,$01,$01,$01,$01,$01
    db $05,$01,$05,$01,$01,$01,$01,$01
    db $05,$01,$05,$01,$05,$01,$05,$01
    db $02,$01,$02,$01,$05,$01,$03,$01
    db $B2,$10,$FD,$FE,$05,$01,$1F,$02
    db $B1,$00,$05,$01,$05,$01,$FF

Sfx_Seq_1E:
    ; SFX 1E sequence data (SFX_Header_Table id(1E) == $487C)
    db $05,$00,$27,$00,$36,$01,$1F,$01
    db $36,$01,$1F,$01,$36,$01,$36,$01
    db $1F,$01,$36,$01,$1F,$01,$36,$01
    db $1F,$01,$36,$01,$36,$01,$1F,$01
    db $36,$01,$1F,$01,$FE,$FE,$FD,$FE
    db $36,$01,$36,$01,$1F,$01,$34,$01
    db $1F,$02,$B1,$00,$36,$02,$FF

Sfx_Seq_1F:
    ; SFX 1F sequence data (SFX_Header_Table id(1F) == $48B3)
    db $05,$10,$02,$00,$FD,$FE,$22,$01
    db $22,$01,$29,$01,$32,$01,$B3,$00
    db $FD,$FE,$32,$01,$32,$01,$1F,$01
    db $29,$01,$1F,$02,$B1,$00,$32,$02
    db $FF

Sfx_Seq_20:
    ; SFX 20 sequence data (SFX_Header_Table id(20) == $48D4)
    db $05,$00,$14,$00,$FD,$FE,$03,$01
    db $01,$01,$08,$01,$01,$01,$B3,$00
    db $FD,$FE,$08,$01,$08,$01,$FE,$FE
    db $02,$01,$09,$02,$1F,$01,$B1,$00
    db $08,$02,$FF

Sfx_Seq_21:
    ; SFX 21 sequence data (SFX_Header_Table id(21) == $48F7)
    db $06,$01,$48,$00,$A3,$21,$37,$01
    db $36,$01,$37,$01,$39,$01,$46,$01
    db $49,$01,$47,$04,$FF

Sfx_Seq_22:
    ; SFX 22 sequence data (SFX_Header_Table id(22) == $490C)
    db $06,$12,$04,$00,$30,$01,$30,$01
    db $30,$01,$30,$01,$34,$01,$35,$01
    db $37,$01,$27,$01,$27,$01,$27,$01
    db $FF

Sfx_Seq_23:
    ; SFX 23 sequence data (SFX_Header_Table id(23) == $4925)
    db $06,$00,$15,$00,$FD,$FE,$07,$01
    db $05,$01,$01,$01,$B2,$00,$05,$01
    db $FF

Sfx_Seq_27:
    ; SFX 27 sequence data (SFX_Header_Table id(27) == $4936)
    db $05,$03,$58,$00,$A3,$20,$AE,$80
    db $34,$01,$30,$01,$29,$01,$33,$01
    db $2B,$01,$28,$01,$32,$01,$2A,$01
    db $27,$01,$31,$01,$28,$01,$26,$01
    db $2A,$03,$2A,$01,$FF

Sfx_Seq_28:
    ; SFX 28 sequence data (SFX_Header_Table id(28) == $495B)
    db $05,$02,$36,$00,$A3,$10,$34,$01
    db $30,$01,$29,$01,$33,$01,$2B,$01
    db $28,$01,$32,$01,$2A,$01,$27,$01
    db $31,$01,$28,$01,$26,$01,$2A,$03
    db $2A,$01,$FF

Sfx_Seq_29:
    ; SFX 29 sequence data (SFX_Header_Table id(29) == $497E)
    db $05,$10,$02,$00,$15,$01,$20,$01
    db $25,$01,$16,$01,$21,$01,$26,$01
    db $17,$01,$22,$01,$27,$01,$18,$01
    db $23,$01,$28,$01,$A2,$7E,$1A,$03
    db $2A,$01,$FF

Sfx_Seq_2A:
    ; SFX 2A sequence data (SFX_Header_Table id(2A) == $49A1)
    db $05,$00,$25,$00,$FD,$FE,$A0,$44
    db $01,$01,$A0,$24,$01,$01,$03,$01
    db $B3,$00,$A0,$44,$09,$02,$01,$01
    db $09,$01,$FF

Sfx_Seq_1D:
    ; SFX 1D sequence data (SFX_Header_Table id(1D) == $49BC)
    db $05,$00,$27,$00,$39,$01,$1F,$01
    db $39,$01,$1F,$01,$3A,$01,$3A,$01
    db $1F,$01,$3B,$01,$1F,$01,$3B,$01
    db $1F,$01,$3B,$01,$3A,$01,$1F,$01
    db $3A,$01,$1F,$01,$FD,$FE,$39,$01
    db $39,$01,$1F,$01,$39,$01,$1F,$02
    db $B1,$00,$39,$02,$FF

Sfx_Seq_2C:
    ; SFX 2C sequence data (SFX_Header_Table id(2C) == $49F1)
    db $01,$02,$48,$46,$37,$04,$37,$05
    db $FF

Sfx_Seq_2B:
    ; SFX 2B sequence data (SFX_Header_Table id(2B) == $49FA)
    db $03,$00,$08,$00,$EF,$02,$32,$01
    db $37,$01,$42,$01,$47,$01,$B3,$02
    db $FF

Sfx_Seq_1C:
    ; SFX 1C sequence data (SFX_Header_Table id(1C) == $4A0B)
    db $02,$00,$49,$54,$31,$01,$1F,$01
    db $B4,$02,$FF

Sfx_Seq_24:
    ; SFX 24 sequence data (SFX_Header_Table id(24) == $4A16)
    db $08,$02,$28,$00,$A3,$21,$35,$01
    db $1F,$02,$35,$01,$1F,$01,$29,$01
    db $2A,$01,$2B,$01,$30,$01,$35,$01
    db $1F,$01,$37,$01,$1F,$01,$35,$01
    db $35,$02,$FD,$FE,$1F,$01,$30,$01
    db $40,$02,$3B,$01,$3A,$02,$39,$02
    db $1F,$04,$30,$01,$32,$01,$35,$01
    db $B1,$00,$FD,$FE,$1F,$01,$35,$01
    db $45,$02,$44,$01,$43,$02,$42,$02
    db $1F,$04,$35,$01,$37,$01,$3A,$01
    db $B1,$00,$FD,$FE,$32,$02,$3B,$01
    db $32,$02,$3B,$01,$32,$01,$34,$02
    db $40,$02,$34,$01,$40,$02,$34,$02
    db $B1,$00,$B0,$02,$FF

Sfx_Seq_25:
    ; SFX 25 sequence data (SFX_Header_Table id(25) == $4A83)
    db $08,$00,$17,$00,$A3,$31,$25,$01
    db $1F,$02,$25,$01,$1F,$01,$19,$01
    db $1A,$01,$1B,$01,$20,$01,$25,$01
    db $1F,$01,$27,$01,$1F,$01,$25,$01
    db $25,$02,$FD,$FE,$1F,$01,$29,$01
    db $39,$01,$1F,$01,$38,$01,$37,$01
    db $1F,$01,$35,$01,$1F,$05,$27,$01
    db $29,$01,$30,$01,$B1,$00,$FD,$FE
    db $1F,$01,$32,$01,$42,$01,$1F,$01
    db $41,$01,$40,$01,$1F,$01,$3A,$01
    db $1F,$05,$30,$01,$32,$01,$35,$01
    db $B1,$00,$FD,$FE,$2B,$02,$37,$01
    db $2B,$02,$37,$01,$2B,$01,$30,$02
    db $37,$02,$30,$01,$37,$02,$30,$02
    db $B1,$00,$B0,$02,$FF

Sfx_Seq_26:
    ; SFX 26 sequence data (SFX_Header_Table id(26) == $4AF8)
    db $08,$00,$13,$00,$1F,$0D,$05,$01
    db $05,$01,$09,$01,$FD,$FE,$04,$01
    db $02,$01,$01,$01,$04,$01,$02,$01
    db $01,$01,$04,$01,$02,$01,$01,$01
    db $01,$01,$04,$01,$02,$01,$04,$01
    db $02,$01,$01,$01,$04,$01,$B5,$00
    db $B0,$02,$FF

Sfx_Seq_1A:
    ; SFX 1A sequence data (SFX_Header_Table id(1A) == $4B2B)
    db $03,$00,$37,$00,$0A,$01,$09,$04
    db $FF

Sfx_Seq_1B:
    ; SFX 1B sequence data (SFX_Header_Table id(1B) == $4B34)
    db $02,$02,$07,$00,$EF,$02,$44,$01
    db $47,$01,$50,$01,$BF,$02,$FF

Sfx_Seq_19:
    ; SFX 19 sequence data (SFX_Header_Table id(19) == $4B43)
    db $02,$00,$28,$00,$27,$02,$26,$02
    db $27,$02,$30,$02,$34,$02,$35,$02
    db $37,$06,$FF

Level_Pointer_Table:
    ; Level pointer table (index by FF9D)
    db $00,$4C,$51,$4C,$A3,$4C,$FC,$4C
    db $58,$4D,$B2,$4D,$05,$4E,$56,$4E
    db $AC,$4E,$19,$4F,$62,$4F,$B2,$4F
    db $1E,$67,$04,$50,$65,$50,$B8,$50
    db $3C,$51,$BF,$51,$52,$52,$D8,$52
    db $78,$53,$D4,$53,$5A,$54,$D9,$54
    db $61,$55,$F5,$55,$7E,$56,$05,$57
    db $83,$57,$0F,$58,$94,$66,$E7,$58
    db $93,$59,$5F,$5A,$21,$5B,$DC,$5B
    db $88,$5C,$44,$5D,$DC,$5D,$9A,$5E
    db $3E,$5F,$FF,$5F,$C3,$60,$8A,$61
    db $43,$62,$EC,$62,$A5,$63,$14,$65
    db $63,$64,$DF,$65

Level_Pointer_Table_Hi:
    ; Second level pointer table (harder levels)
    db $0F,$51,$8E,$51,$16,$52,$A1,$52
    db $45,$53,$EC,$66,$29,$54,$A7,$54
    db $2F,$55,$C4,$55,$59,$56,$D4,$56
    db $57,$57,$D8,$57,$6C,$58,$9A,$58
    db $38,$59,$F6,$59,$C1,$5A,$8B,$5B
    db $32,$5C,$E6,$5C,$8E,$5D,$43,$5E
    db $F8,$5E,$A1,$5F,$60,$60,$2D,$61
    db $E4,$61,$92,$62,$43,$63,$05,$64
    db $BC,$64,$7E,$65,$35,$66

Level_00_Map:
    ; Level 00 map stream (compressed tilemap; Level_Pointer_Table id(00) == $4C00)
    db $85,$FF,$FF,$F7,$85,$FF,$FF,$F7
    db $85,$FF,$FF,$F7,$23,$FD,$FD,$7E
    db $2B,$FF,$FF,$5B,$55,$00,$65,$54
    db $F7,$04,$F2,$40,$65,$00,$60,$63
    db $40,$00,$25,$FF,$FA,$00,$40,$25
    db $A5,$E0,$FF,$55,$FA,$25,$00,$74
    db $74,$04,$45,$50,$65,$70,$70,$F2
    db $20,$25,$FF,$75,$F2,$20,$25,$F7
    db $50,$F2,$F2,$62,$F7,$50,$04,$40
    db $04,$44,$24,$02,$FF,$F2,$FA,$FA
    db $FA

Level_01_Map:
    ; Level 01 map stream (compressed tilemap; Level_Pointer_Table id(01) == $4C51)
    db $85,$FF,$FF,$EF,$23,$FD,$FD,$EA
    db $25,$F7,$5B,$FF,$69,$25,$F7,$50
    db $40,$FF,$52,$65,$54,$7B,$04,$F7
    db $52,$65,$7C,$7C,$66,$52,$65,$7B
    db $7B,$64,$52,$E7,$7C,$7C,$40,$69
    db $E2,$7B,$7B,$04,$69,$E7,$7C,$7C
    db $40,$69,$65,$7B,$7B,$64,$52,$65
    db $50,$7C,$40,$F7,$52,$25,$F7,$7B
    db $05,$F7,$52,$25,$F7,$50,$40,$FF
    db $52,$2A,$FF,$05,$F7,$B5,$52,$FA
    db $FA,$FA

Level_02_Map:
    ; Level 02 map stream (compressed tilemap; Level_Pointer_Table id(02) == $4CA3)
    db $FF,$FF,$F7,$58,$FF,$FF,$F7,$58
    db $FF,$FF,$F7,$58,$75,$45,$74,$55
    db $74,$58,$72,$25,$73,$69,$32,$00
    db $72,$25,$73,$25,$22,$52,$04,$22
    db $7F,$73,$73,$52,$00,$72,$25,$73
    db $73,$52,$04,$72,$B2,$25,$73,$73
    db $00,$70,$01,$10,$25,$74,$54,$B4
    db $69,$F7,$E7,$FA,$E1,$6A,$25,$F4
    db $52,$22,$02,$79,$7F,$F1,$52,$25
    db $05,$02,$64,$25,$22,$72,$22,$02
    db $04,$64,$22,$A5,$EC,$24,$FA,$FA
    db $FA

Level_03_Map:
    ; Level 03 map stream (compressed tilemap; Level_Pointer_Table id(03) == $4CFC)
    db $FF,$FF,$EF,$55,$67,$25,$F7,$88
    db $88,$EE,$55,$42,$F7,$58,$FF,$55
    db $54,$25,$FF,$85,$FF,$52,$45,$F7
    db $58,$74,$5B,$52,$7F,$A5,$75,$FA
    db $25,$00,$52,$FA,$55,$66,$52,$55
    db $65,$4B,$54,$6B,$45,$25,$02,$55
    db $51,$F3,$15,$40,$E1,$02,$74,$FF
    db $00,$45,$25,$FA,$20,$64,$40,$E1
    db $F2,$76,$64,$00,$45,$25,$F2,$76
    db $64,$40,$E1,$F2,$76,$64,$00,$45
    db $25,$00,$44,$05,$42,$05,$FF,$52
    db $FA,$F2,$71,$71

Level_04_Map:
    ; Level 04 map stream (compressed tilemap; Level_Pointer_Table id(04) == $4D58)
    db $FF,$FF,$F7,$58,$FF,$53,$FD,$33
    db $08,$E0,$4A,$52,$FF,$55,$08,$FA
    db $02,$F7,$75,$08,$54,$66,$52,$FF
    db $55,$08,$00,$09,$FA,$25,$F7,$08
    db $55,$75,$66,$25,$F7,$08,$00,$09
    db $FA,$00,$65,$08,$54,$5B,$74,$F7
    db $25,$5B,$08,$FA,$00,$6D,$02,$00
    db $08,$FF,$7A,$69,$EF,$21,$F3,$20
    db $50,$69,$55,$48,$21,$E0,$20,$50
    db $52,$02,$F2,$21,$FB,$50,$52,$76
    db $04,$25,$75,$4B,$69,$76,$05,$FA
    db $FA,$FA

Level_05_Map:
    ; Level 05 map stream (compressed tilemap; Level_Pointer_Table id(05) == $4DB2)
    db $FF,$FF,$F7,$58,$55,$5B,$FF,$FF
    db $58,$FA,$65,$54,$E0,$58,$45,$6D
    db $25,$52,$FB,$11,$FA,$6F,$25,$FF
    db $FF,$F7,$52,$FF,$54,$67,$E0,$50
    db $EB,$A5,$FA,$FA,$25,$F7,$54,$E0
    db $05,$F7,$25,$75,$F2,$E5,$F7,$25
    db $F7,$54,$5B,$52,$54,$64,$25,$F2
    db $20,$FA,$05,$20,$2A,$64,$25,$74
    db $55,$05,$77,$02,$00,$FA,$E5,$77
    db $52,$04,$EC,$5B,$F0,$77,$52,$05
    db $FA,$FA,$FA

Level_06_Map:
    ; Level 06 map stream (compressed tilemap; Level_Pointer_Table id(06) == $4E05)
    db $F7,$85,$FF,$FF,$5B,$45,$85,$FF
    db $FF,$6E,$64,$75,$FF,$25,$F7,$20
    db $F2,$FF,$25,$F7,$25,$FF,$F7,$6F
    db $7F,$F7,$7D,$55,$69,$54,$25,$B5
    db $52,$F2,$05,$69,$F2,$E1,$FF,$69
    db $FF,$52,$74,$55,$69,$55,$66,$FA
    db $02,$69,$F2,$FF,$69,$20,$6C,$FF
    db $55,$E1,$25,$75,$F7,$5B,$55,$E5
    db $20,$FA,$FA,$05,$02,$65,$54,$E0
    db $A5,$55,$02,$04,$70,$70,$70,$01
    db $F2

Level_07_Map:
    ; Level 07 map stream (compressed tilemap; Level_Pointer_Table id(07) == $4E56)
    db $FF,$FF,$EF,$55,$FF,$F7,$5B,$EF
    db $55,$FD,$33,$31,$70,$01,$02,$75
    db $75,$51,$FF,$52,$7E,$7E,$51,$20
    db $71,$10,$74,$74,$51,$25,$FF,$53
    db $33,$53,$33,$51,$70,$01,$02,$75
    db $75,$51,$FF,$52,$7E,$7E,$51,$20
    db $71,$10,$74,$74,$51,$25,$FF,$70
    db $70,$91,$70,$01,$02,$FF,$FF,$55
    db $B5,$52,$20,$71,$71,$71,$71,$25
    db $FF,$FF,$F7,$70,$70,$70,$70,$02
    db $5B,$55,$5A,$FF,$F7,$52

Level_08_Map:
    ; Level 08 map stream (compressed tilemap; Level_Pointer_Table id(08) == $4EAC)
    db $FF,$FF,$F7,$85,$FF,$FF,$F7,$85
    db $67,$55,$7D,$67,$5A,$85,$20,$FA
    db $FA,$00,$25,$E2,$55,$4B,$54,$E0
    db $50,$24,$20,$FA,$F2,$02,$40,$25
    db $25,$7D,$55,$66,$02,$50,$24,$20
    db $FA,$00,$24,$02,$40,$25,$25,$F7
    db $B5,$50,$25,$02,$50,$24,$00,$6E
    db $02,$40,$24,$02,$40,$25,$55,$65
    db $02,$50,$25,$02,$50,$24,$20,$41
    db $25,$02,$40,$24,$02,$40,$25,$40
    db $21,$24,$02,$50,$25,$02,$50,$24
    db $20,$41,$25,$02,$40,$24,$02,$40
    db $25,$40,$21,$24,$02,$50,$25,$02
    db $50,$24,$FA,$FA,$FA

Level_09_Map:
    ; Level 09 map stream (compressed tilemap; Level_Pointer_Table id(09) == $4F19)
    db $FF,$FF,$F7,$58,$FF,$FF,$F7,$58
    db $F7,$75,$E0,$B4,$BB,$18,$20,$FA
    db $FA,$00,$08,$25,$66,$EC,$7D,$EF
    db $FA,$FA,$F2,$28,$F7,$66,$66,$66
    db $28,$20,$FA,$FA,$F2,$25,$FF,$EC
    db $7D,$55,$FA,$FA,$F2,$02,$FF,$55
    db $75,$F7,$42,$64,$20,$FA,$FA,$F2
    db $25,$A5,$66,$54,$E0,$02,$6F,$F2
    db $09,$FA,$04,$62,$FF,$FF,$FA,$FA
    db $FA

Level_10_Map:
    ; Level 10 map stream (compressed tilemap; Level_Pointer_Table id(10) == $4F62)
    db $FF,$FF,$F7,$58,$FF,$FF,$74,$58
    db $FF,$50,$FA,$6F,$F7,$50,$67,$B5
    db $74,$52,$F7,$50,$FA,$F2,$02,$E8
    db $25,$A5,$EC,$74,$52,$E8,$FA,$FA
    db $02,$E8,$44,$50,$55,$66,$E9,$E8
    db $FA,$FA,$02,$E8,$44,$75,$B5,$74
    db $52,$E8,$FA,$FA,$02,$E8,$55,$44
    db $50,$55,$75,$B2,$05,$20,$50,$F2
    db $20,$FA,$F2,$20,$44,$45,$20,$FA
    db $00,$40,$20,$FA,$FA,$FA,$FA,$FA

Level_11_Map:
    ; Level 11 map stream (compressed tilemap; Level_Pointer_Table id(11) == $4FB2)
    db $FF,$FF,$F7,$58,$55,$4B,$54,$FF
    db $F7,$58,$20,$FA,$F2,$F7,$58,$25
    db $F7,$51,$F7,$EC,$48,$25,$F7,$10
    db $FA,$F2,$23,$FD,$FD,$EA,$FF,$FF
    db $F7,$52,$55,$7D,$E0,$FF,$52,$FA
    db $F2,$05,$F7,$52,$FF,$FF,$4B,$54
    db $52,$05,$5A,$52,$64,$20,$FA,$F2
    db $02,$64,$25,$FF,$F2,$02,$FA,$02
    db $F7,$04,$55,$62,$F7,$52,$F7,$05
    db $02,$6F,$55,$75,$45,$B5,$FA,$01
    db $FB,$F3

Level_13_Map:
    ; Level 13 map stream (compressed tilemap; Level_Pointer_Table id(13) == $5004)
    db $85,$FF,$FF,$EF,$85,$FF,$FF,$EF
    db $23,$FD,$FD,$EA,$24,$44,$FF,$FF
    db $52,$24,$55,$44,$45,$44,$66,$44
    db $52,$65,$7D,$55,$7D,$69,$65,$7D
    db $55,$7D,$69,$65,$7D,$67,$66,$52
    db $25,$FF,$FF,$69,$23,$F5,$32,$22
    db $23,$F5,$32,$2A,$FF,$FF,$5B,$B2
    db $20,$08,$FF,$F7,$80,$02,$20,$52
    db $08,$54,$E0,$80,$28,$02,$20,$58
    db $52,$02,$44,$20,$25,$85,$02,$20
    db $58,$58,$58,$55,$85,$85,$85,$02
    db $20,$58,$48,$48,$55,$84,$84,$85
    db $02

Level_14_Map:
    ; Level 14 map stream (compressed tilemap; Level_Pointer_Table id(14) == $5065)
    db $FF,$55,$5B,$FF,$58,$A3,$FD,$F5
    db $F7,$58,$25,$F7,$51,$EC,$5B,$58
    db $08,$E7,$40,$50,$FA,$00,$08,$65
    db $04,$05,$FF,$EF,$E7,$7C,$FF,$EF
    db $65,$7B,$05,$75,$52,$08,$65,$50
    db $40,$FA,$6F,$25,$F7,$6C,$FF,$52
    db $FA,$00,$08,$FA,$02,$FF,$EF,$04
    db $20,$69,$45,$F7,$50,$28,$60,$69
    db $FA,$6E,$01,$10,$F2,$FF,$25,$FF
    db $68,$45,$F7,$E2,$52,$92,$54,$50
    db $FA,$FA,$FA

Level_15_Map:
    ; Level 15 map stream (compressed tilemap; Level_Pointer_Table id(15) == $50B8)
    db $FF,$EE,$58,$FF,$FF,$8B,$5C,$58
    db $FF,$FF,$20,$10,$12,$FF,$FF,$24
    db $5D,$52,$FF,$F7,$52,$71,$10,$25
    db $F7,$F7,$52,$75,$45,$25,$F7,$F7
    db $20,$71,$10,$12,$F7,$F7,$25,$75
    db $4B,$52,$F7,$69,$71,$71,$10,$65
    db $69,$67,$55,$66,$65,$E8,$71,$71
    db $10,$12,$55,$7F,$5B,$75,$75,$F0
    db $52,$71,$71,$71,$10,$25,$F0,$75
    db $75,$75,$25,$20,$71,$71,$71,$10
    db $12,$65,$74,$54,$A5,$66,$52

Level_Hard_00_Map:
    ; Level 15 (hard set, FF9D=0F) map stream (Level_Pointer_Table_Hi id(00) == $510F)
    db $55,$7D,$67,$5C,$20,$FB,$11,$10
    db $65,$66,$EC,$00,$FB,$11,$02,$FF
    db $F7,$52,$20,$FB,$11,$00,$65,$66
    db $45,$B5,$00,$FB,$11,$02,$F7,$7D
    db $69,$20,$FB,$11,$00,$65,$45,$4B
    db $EC,$00,$FB,$11,$00

Level_16_Map:
    ; Level 16 map stream (compressed tilemap; Level_Pointer_Table id(16) == $513C)
    db $FF,$FF,$FF,$23,$FD,$FD,$EA,$E2
    db $E0,$B5,$45,$74,$52,$E7,$FA,$F2
    db $50,$52,$25,$51,$FB,$F3,$15,$52
    db $25,$74,$E0,$74,$54,$52,$E7,$FA
    db $F2,$50,$52,$25,$51,$FB,$F3,$15
    db $52,$25,$5D,$55,$75,$54,$F7,$52
    db $E7,$FA,$F2,$E1,$25,$51,$FB,$F3
    db $15,$52,$25,$5C,$55,$66,$75,$69
    db $E7,$FA,$F2,$E1,$25,$51,$FB,$F3
    db $15,$52,$2A,$FF,$F7,$5B,$69,$FA
    db $FA,$FA

Level_Hard_01_Map:
    ; Level 16 (hard set, FF9D=10) map stream (Level_Pointer_Table_Hi id(01) == $518E)
    db $5B,$75,$75,$45,$FC,$FC,$42,$22
    db $42,$24,$F6,$24,$24,$F4,$F1,$22
    db $42,$F4,$F1,$22,$42,$F4,$F1,$22
    db $42,$F1,$F1,$22,$42,$F4,$F1,$FC
    db $FC,$25,$24,$25,$24,$25,$22,$72
    db $72,$25,$22,$24,$25,$24,$2B,$24
    db $2C

Level_17_Map:
    ; Level 17 map stream (compressed tilemap; Level_Pointer_Table id(17) == $51BF)
    db $85,$F7,$74,$55,$B5,$F7,$20,$FA
    db $FA,$6C,$65,$EC,$75,$B5,$F7,$20
    db $F2,$77,$FA,$25,$65,$54,$24,$25
    db $45,$F7,$25,$20,$F2,$77,$F2,$11
    db $15,$25,$F7,$72,$EC,$1C,$55,$FA
    db $77,$F2,$11,$15,$55,$33,$20,$72
    db $FF,$55,$F7,$20,$25,$24,$55,$4B
    db $EC,$6C,$20,$25,$FA,$F2,$6C,$20
    db $65,$45,$74,$55,$6C,$20,$FA,$F2
    db $02,$55,$D2,$25,$5A,$55,$66,$E9
    db $69,$FA,$FA,$00,$FA,$FA,$FA

Level_Hard_02_Map:
    ; Level 17 (hard set, FF9D=11) map stream (Level_Pointer_Table_Hi id(02) == $5216)
    db $45,$43,$55,$43,$75,$12,$05,$E5
    db $12,$1C,$52,$45,$42,$54,$52,$22
    db $52,$76,$E3,$22,$45,$42,$52,$45
    db $25,$22,$10,$05,$15,$00,$24,$42
    db $52,$54,$25,$45,$62,$02,$00,$6E
    db $44,$42,$F7,$25,$45,$01,$02,$B5
    db $45,$6E,$02,$42,$F3,$FC,$22,$E0
    db $25,$52,$B5,$25

Level_18_Map:
    ; Level 18 map stream (compressed tilemap; Level_Pointer_Table id(18) == $5252)
    db $85,$FF,$FF,$EF,$23,$FD,$FD,$EA
    db $25,$5B,$75,$67,$B5,$E9,$25,$FA
    db $50,$FA,$52,$25,$74,$FF,$F7,$52
    db $25,$FB,$F7,$66,$52,$25,$FF,$51
    db $FB,$52,$25,$FA,$FF,$E9,$25,$64
    db $7A,$FA,$52,$25,$05,$D5,$7A,$55
    db $C5,$50,$52,$25,$FA,$50,$FA,$52
    db $65,$A5,$68,$FF,$52,$FA,$F2,$20
    db $FA,$EC,$75,$55,$6E,$04,$54,$FA
    db $F2,$08,$40,$F2,$FA,$FA,$FA

Level_Hard_03_Map:
    ; Level 18 (hard set, FF9D=12) map stream (Level_Pointer_Table_Hi id(03) == $52A1)
    db $F7,$B5,$F7,$5C,$F5,$23,$F5,$32
    db $54,$35,$E2,$53,$32,$35,$55,$24
    db $67,$55,$43,$55,$23,$35,$33,$55
    db $55,$3B,$7F,$75,$43,$32,$55,$65
    db $33,$69,$54,$23,$23,$54,$E9,$33
    db $45,$25,$33,$55,$42,$F7,$25,$45
    db $23,$32,$F5,$EB,$25,$FF,$F7

Level_19_Map:
    ; Level 19 map stream (compressed tilemap; Level_Pointer_Table id(19) == $52D8)
    db $B2,$24,$24,$FC,$F3,$18,$21,$71
    db $F3,$22,$F1,$18,$FC,$22,$E4,$10
    db $12,$C2,$12,$F3,$12,$22,$B2,$22
    db $11,$02,$78,$F1,$F3,$12,$22,$12
    db $22,$11,$10,$78,$E4,$78,$22,$12
    db $22,$12,$22,$F1,$E3,$D2,$12,$22
    db $12,$21,$10,$78,$11,$01,$12,$E3
    db $21,$22,$78,$24,$12,$22,$42,$22
    db $11,$78,$78,$12,$11,$01,$12,$14
    db $78,$12,$11,$12,$F4,$78,$78,$22
    db $21,$12,$11,$21,$78,$12,$22,$12
    db $21,$22,$14,$F4,$78,$E3,$21,$78
    db $12,$F4,$12,$22,$2A,$22,$B2,$E3
    db $F3,$12,$11,$21,$12

Level_Hard_04_Map:
    ; Level 19 (hard set, FF9D=13) map stream (Level_Pointer_Table_Hi id(04) == $5345)
    db $25,$FF,$7F,$EB,$B0,$B3,$33,$25
    db $65,$79,$7F,$E7,$45,$40,$55,$24
    db $25,$04,$67,$05,$25,$20,$FA,$00
    db $24,$EB,$50,$53,$33,$25,$65,$79
    db $55,$24,$E7,$45,$40,$7F,$25,$04
    db $5C,$54,$05,$24,$20,$FA,$00,$25
    db $25,$FF,$7F

Level_20_Map:
    ; Level 20 map stream (compressed tilemap; Level_Pointer_Table id(20) == $5378)
    db $85,$FF,$FF,$F7,$85,$FF,$53,$F5
    db $32,$52,$85,$FF,$55,$AC,$52,$7F
    db $84,$54,$68,$55,$76,$E1,$80,$FA
    db $55,$02,$04,$05,$25,$85,$54,$FF
    db $76,$E1,$F2,$EE,$35,$04,$E5,$25
    db $EE,$85,$F7,$76,$E1,$20,$FA,$85
    db $02,$0D,$05,$25,$20,$05,$54,$50
    db $85,$F3,$15,$52,$FA,$00,$85,$FF
    db $52,$F2,$54,$50,$85,$FF,$52,$FA
    db $00,$85,$FF,$52,$E0,$F7,$85,$FF
    db $52,$75,$45,$44,$80,$25,$5B,$5B
    db $52,$FA,$FA,$FA

Level_21_Map:
    ; Level 21 map stream (compressed tilemap; Level_Pointer_Table id(21) == $53D4)
    db $FF,$FF,$FF,$20,$FA,$F2,$6E,$0D
    db $24,$FC,$24,$ED,$F2,$20,$FA,$02
    db $ED,$F2,$20,$FA,$02,$ED,$F2,$20
    db $40,$F2,$02,$00,$6E,$0C,$21,$FB
    db $11,$FA,$00,$FC,$24,$21,$FB,$11
    db $FA,$00,$24,$42,$F4,$24,$FD,$30
    db $20,$FA,$00,$FE,$40,$6E,$02,$24
    db $00,$04,$FA,$23,$EA,$F2,$FA,$00
    db $24,$44,$42,$7D,$FB,$FB,$12,$05
    db $00,$5B,$BB,$55,$5A,$F7,$52,$05
    db $00,$FA,$FA,$E5,$00

Level_Hard_06_Map:
    ; Level 21 (hard set, FF9D=15) map stream (Level_Pointer_Table_Hi id(06) == $5429)
    db $FF,$F7,$C5,$EC,$74,$6E,$6F,$FA
    db $00,$54,$52,$FF,$45,$09,$FA,$6E
    db $55,$4B,$35,$7F,$45,$6E,$92,$F2
    db $90,$25,$E9,$75,$45,$6F,$00,$09
    db $02,$00,$55,$42,$74,$52,$45,$02
    db $00,$90,$F2,$02,$52,$E0,$5B,$54
    db $52

Level_22_Map:
    ; Level 22 map stream (compressed tilemap; Level_Pointer_Table id(22) == $545A)
    db $FF,$FF,$F7,$58,$C4,$FF,$55,$7D
    db $5A,$58,$F2,$20,$FA,$FA,$67,$65
    db $54,$FF,$55,$F2,$20,$FA,$F2,$02
    db $FF,$66,$45,$F7,$52,$68,$FA,$FA
    db $02,$45,$FF,$FF,$69,$6F,$FF,$FF
    db $52,$0B,$02,$F7,$45,$42,$FA,$6F
    db $E8,$F2,$05,$F7,$04,$02,$55,$65
    db $52,$05,$B5,$45,$6F,$FA,$02,$FA
    db $04,$02,$68,$0D,$02,$FF,$6F,$F7
    db $6F,$FF,$FA,$FA,$FA

Level_Hard_07_Map:
    ; Level 22 (hard set, FF9D=16) map stream (Level_Pointer_Table_Hi id(07) == $54A7)
    db $C5,$FF,$F7,$23,$7E,$55,$EA,$25
    db $7E,$53,$35,$42,$24,$55,$33,$54
    db $69,$25,$66,$33,$25,$42,$24,$FF
    db $23,$32,$25,$32,$5B,$54,$65,$23
    db $52,$F5,$E2,$B5,$52,$7D,$23,$32
    db $23,$32,$F7,$E9,$E2,$FF,$52,$25
    db $FF,$69

Level_23_Map:
    ; Level 23 map stream (compressed tilemap; Level_Pointer_Table id(23) == $54D9)
    db $FF,$F7,$85,$FF,$FF,$F7,$85,$FF
    db $F5,$55,$53,$33,$85,$FF,$65,$00
    db $64,$25,$FF,$65,$00,$64,$25,$FF
    db $F0,$02,$64,$24,$FF,$F0,$02,$64
    db $65,$5B,$55,$65,$02,$64,$25,$FF
    db $65,$02,$01,$F2,$65,$B5,$F0,$02
    db $33,$F3,$02,$F7,$52,$6B,$03,$F5
    db $00,$65,$65,$00,$64,$54,$00,$65
    db $65,$00,$0D,$68,$00,$65,$52,$6B
    db $05,$F7,$00,$65,$F0,$FA,$6C,$25
    db $5C,$A2,$55,$FA,$6A,$6E

Level_Hard_08_Map:
    ; Level 23 (hard set, FF9D=17) map stream (Level_Pointer_Table_Hi id(08) == $552F)
    db $54,$FF,$55,$5C,$22,$FF,$55,$22
    db $45,$22,$F7,$22,$55,$6A,$25,$52
    db $F7,$B5,$E9,$E2,$52,$F2,$55,$6E
    db $02,$FF,$65,$52,$75,$5B,$22,$E8
    db $02,$F2,$25,$22,$50,$02,$F7,$65
    db $50,$05,$25,$52,$F7,$50,$E1,$25
    db $74,$55

Level_24_Map:
    ; Level 24 map stream (compressed tilemap; Level_Pointer_Table id(24) == $5561)
    db $C5,$FF,$FF,$F7,$EB,$EB,$23,$22
    db $23,$F5,$25,$45,$24,$54,$25,$24
    db $52,$A4,$54,$65,$65,$72,$55,$65
    db $25,$52,$65,$25,$24,$55,$65,$25
    db $73,$F0,$65,$23,$35,$72,$73,$55
    db $65,$24,$55,$24,$24,$55,$65,$65
    db $65,$22,$B5,$55,$22,$55,$24,$55
    db $65,$72,$55,$22,$55,$65,$25,$33
    db $72,$55,$72,$65,$E2,$24,$F0,$72
    db $24,$55,$65,$25,$52,$7F,$52,$65
    db $6E,$24,$55,$24,$24,$52,$24,$52
    db $50,$0D,$65,$72,$B5,$22,$2B,$6B
    db $FA,$FA,$FA

Level_Hard_09_Map:
    ; Level 24 (hard set, FF9D=18) map stream (Level_Pointer_Table_Hi id(09) == $55C4)
    db $63,$02,$69,$2C,$20,$F4,$00,$76
    db $77,$02,$04,$76,$20,$24,$76,$76
    db $6E,$76,$62,$FC,$FC,$F2,$76,$76
    db $42,$02,$B2,$76,$02,$22,$02,$FA
    db $42,$22,$02,$20,$42,$04,$02,$22
    db $02,$40,$22,$76,$42,$22,$6F,$22
    db $42

Level_25_Map:
    ; Level 25 map stream (compressed tilemap; Level_Pointer_Table id(25) == $55F5)
    db $55,$B5,$FF,$FF,$A8,$52,$05,$FF
    db $F7,$50,$28,$E8,$55,$65,$F0,$02
    db $58,$53,$32,$02,$53,$7E,$20,$23
    db $38,$52,$45,$20,$67,$55,$02,$54
    db $28,$73,$52,$03,$33,$30,$72,$28
    db $B2,$52,$E8,$D5,$02,$54,$25,$28
    db $76,$6F,$00,$6E,$77,$73,$FC,$FC
    db $22,$73,$55,$02,$45,$20,$55,$72
    db $73,$50,$65,$52,$0B,$72,$73,$02
    db $53,$7E,$20,$72,$52,$7F,$54,$F7
    db $52,$05,$25,$42,$02,$52,$FD,$25
    db $20,$24,$20,$65,$25,$5C,$52,$69
    db $02,$FA,$FA,$FA

Level_Hard_10_Map:
    ; Level 25 (hard set, FF9D=19) map stream (Level_Pointer_Table_Hi id(10) == $5659)
    db $FF,$FF,$55,$5B,$BB,$65,$5C,$FA
    db $20,$F2,$FF,$25,$F7,$FF,$25,$F7
    db $FA,$00,$6E,$FF,$55,$65,$FF,$55
    db $65,$55,$FA,$6E,$F7,$EC,$65,$FF
    db $55,$65,$69,$F2,$64

Level_26_Map:
    ; Level 26 map stream (compressed tilemap; Level_Pointer_Table id(26) == $567E)
    db $FF,$55,$88,$FF,$55,$B5,$67,$55
    db $88,$55,$66,$A5,$FA,$00,$22,$FA
    db $00,$5D,$74,$55,$22,$55,$75,$45
    db $FC,$FC,$FC,$52,$E0,$52,$7F,$54
    db $7F,$55,$65,$25,$E9,$69,$55,$55
    db $73,$FF,$72,$55,$F7,$65,$66,$52
    db $F7,$55,$73,$FF,$72,$55,$B5,$25
    db $45,$65,$52,$54,$52,$5B,$FC,$22
    db $44,$FC,$22,$85,$FF,$22,$FF,$58
    db $85,$FF,$22,$FF,$58,$85,$FF,$FF
    db $EF,$85,$FF,$C5,$FF,$58

Level_Hard_11_Map:
    ; Level 26 (hard set, FF9D=1A) map stream (Level_Pointer_Table_Hi id(11) == $56D4)
    db $FF,$C5,$F7,$6E,$6F,$64,$20,$55
    db $02,$50,$65,$20,$45,$05,$40,$25
    db $5B,$25,$FA,$ED,$20,$42,$05,$40
    db $6F,$21,$FB,$55,$02,$20,$90,$F2
    db $55,$02,$25,$FF,$55,$02,$25,$FF
    db $54,$02,$25,$F7,$B5,$E6,$FA,$F2
    db $42

Level_27_Map:
    ; Level 27 map stream (compressed tilemap; Level_Pointer_Table id(27) == $5705)
    db $FF,$FF,$F7,$58,$55,$5B,$FF,$F7
    db $5A,$58,$20,$FA,$FA,$F2,$25,$FF
    db $FF,$F7,$E7,$F2,$05,$EC,$66,$25
    db $00,$0D,$FA,$FA,$25,$FA,$00,$54
    db $66,$B5,$E7,$FA,$FA,$00,$25,$45
    db $FF,$FF,$55,$F2,$25,$F7,$20,$85
    db $EC,$F7,$25,$66,$20,$80,$F2,$F7
    db $FA,$20,$EE,$58,$45,$B5,$55,$66
    db $20,$F2,$08,$FA,$F2,$20,$65,$58
    db $C5,$54,$67,$E8,$25,$45,$48,$FA
    db $FA,$FA

Level_Hard_12_Map:
    ; Level 27 (hard set, FF9D=1B) map stream (Level_Pointer_Table_Hi id(12) == $5757)
    db $C5,$FF,$F7,$F2,$24,$F7,$B5,$F7
    db $20,$FA,$F7,$25,$F7,$54,$FA,$02
    db $B0,$00,$FD,$33,$6E,$20,$55,$F2
    db $04,$55,$20,$50,$FA,$02,$20,$50
    db $54,$E0,$52,$20,$50,$FA,$02,$23
    db $FD,$EA,$FF,$FF

Level_28_Map:
    ; Level 28 map stream (compressed tilemap; Level_Pointer_Table id(28) == $5783)
    db $5A,$FF,$FF,$EF,$F2,$64,$53,$FD
    db $38,$63,$64,$50,$25,$F7,$58,$FF
    db $45,$B0,$25,$F7,$50,$20,$FA,$00
    db $65,$6D,$25,$FF,$7F,$61,$D5,$FA
    db $02,$7F,$00,$51,$11,$FF,$52,$7F
    db $FF,$FA,$02,$F2,$25,$F7,$55,$66
    db $52,$F7,$25,$F7,$20,$FA,$55,$FA
    db $02,$25,$FF,$55,$64,$B4,$02,$F2
    db $62,$50,$FA,$02,$E0,$25,$52,$F7
    db $04,$54,$02,$F2,$6E,$64,$F2,$02
    db $C5,$7F,$54,$FF,$69

Level_Hard_13_Map:
    ; Level 28 (hard set, FF9D=1C) map stream (Level_Pointer_Table_Hi id(13) == $57D8)
    db $FF,$F7,$5C,$23,$FD,$EA,$00,$68
    db $04,$52,$00,$24,$B5,$55,$62,$54
    db $62,$55,$24,$52,$00,$25,$73,$00
    db $52,$45,$24,$62,$45,$E6,$00,$24
    db $52,$6A,$42,$54,$62,$4B,$52,$00
    db $00,$25,$42,$00,$52,$54,$54,$25
    db $6A,$42,$00,$E6,$B5,$20,$64

Level_29_Map:
    ; Level 29 map stream (compressed tilemap; Level_Pointer_Table id(29) == $580F)
    db $FF,$55,$A5,$54,$FF,$02,$04,$E8
    db $FA,$02,$50,$02,$6C,$25,$FF,$00
    db $2D,$F0,$05,$6E,$50,$45,$02,$20
    db $50,$24,$55,$24,$7A,$6F,$50,$50
    db $FA,$00,$F7,$F0,$67,$20,$55,$B5
    db $52,$F2,$02,$F2,$20,$F2,$E5,$42
    db $02,$64,$25,$F7,$E5,$76,$02,$F2
    db $02,$E1,$55,$02,$42,$F0,$B5,$76
    db $6C,$76,$6E,$76,$02,$79,$05,$02
    db $65,$76,$02,$5C,$05,$6F,$00,$04
    db $76,$F2,$05,$54,$B2,$66,$52,$02
    db $FF,$6F,$FA,$FA,$FA

Level_Hard_14_Map:
    ; Level 29 (hard set, FF9D=1D) map stream (Level_Pointer_Table_Hi id(14) == $586C)
    db $C5,$EC,$66,$45,$20,$FA,$6E,$E2
    db $55,$B5,$24,$55,$F2,$20,$FA,$F7
    db $25,$FF,$02,$6F,$55,$75,$52,$B4
    db $50,$FA,$6E,$64,$66,$24,$55,$40
    db $20,$F2,$00,$6E,$20,$52,$04,$7F
    db $50,$20,$52,$05,$FA,$FA

Level_Hard_15_Map:
    ; Level 30 (hard set, FF9D=1E) map stream (Level_Pointer_Table_Hi id(15) == $589A)
    db $FF,$FF,$F7,$5C,$FF,$FF,$F7,$52
    db $FF,$54,$B5,$F7,$52,$02,$20,$FA
    db $FA,$F2,$E2,$FF,$E0,$F7,$FA,$20
    db $FA,$6F,$FF,$65,$45,$F7,$52,$F2
    db $45,$21,$FA,$6F,$63,$05,$21,$FF
    db $55,$02,$F2,$45,$21,$FA,$6F,$63
    db $05,$21,$E0,$F7,$02,$F2,$45,$21
    db $FF,$55,$02,$63,$05,$6E,$50,$F2
    db $02,$F2,$55,$21,$FB,$E3,$FF,$25
    db $FF,$69,$FA,$FA,$FA

Level_31_Map:
    ; Level 31 map stream (compressed tilemap; Level_Pointer_Table id(31) == $58E7)
    db $85,$FF,$FF,$F7,$EE,$FD,$FD,$35
    db $85,$FF,$50,$F7,$5D,$02,$85,$FF
    db $50,$FA,$02,$85,$75,$FF,$5B,$BB
    db $02,$F2,$05,$FA,$6D,$52,$FA,$FA
    db $6D,$02,$FB,$10,$F2,$6D,$02,$74
    db $5C,$50,$F2,$6D,$02,$20,$FA,$6D
    db $6D,$02,$23,$20,$F2,$63,$6D,$02
    db $25,$20,$F2,$63,$6D,$02,$55,$23
    db $F5,$31,$FF,$52,$FF,$55,$51,$FF
    db $52,$FF,$61,$55,$A5,$69,$FB,$FB
    db $FB

Level_Hard_16_Map:
    ; Level 31 (hard set, FF9D=1F) map stream (Level_Pointer_Table_Hi id(16) == $5938)
    db $FF,$FF,$FF,$FF,$B5,$54,$5B,$54
    db $F7,$F7,$52,$FA,$FA,$F7,$52,$FF
    db $67,$00,$74,$52,$FA,$60,$04,$6E
    db $02,$00,$63,$05,$54,$00,$65,$52
    db $FA,$60,$04,$20,$FA,$63,$05,$54
    db $00,$65,$B5,$00,$90,$FA,$00,$6E
    db $02,$64,$75,$F7,$25,$C5,$52,$05
    db $20,$F2,$25,$45,$20,$F2,$05,$25
    db $F7,$6E,$25,$FF,$25,$F7,$25,$45
    db $20,$FA,$E2,$55,$6E,$25,$20,$52
    db $ED,$05,$6F,$45,$24,$20,$42,$04
    db $50,$FA,$00

Level_32_Map:
    ; Level 32 map stream (compressed tilemap; Level_Pointer_Table id(32) == $5993)
    db $58,$FF,$FF,$F7,$EE,$51,$20,$85
    db $EC,$66,$58,$01,$11,$20,$FA,$00
    db $08,$EE,$41,$20,$55,$7D,$EF,$58
    db $11,$01,$20,$FA,$F2,$EE,$41,$20
    db $FF,$F7,$58,$01,$11,$20,$FF,$F7
    db $EE,$41,$20,$23,$FD,$32,$58,$11
    db $01,$20,$65,$35,$55,$32,$EE,$41
    db $20,$65,$7A,$52,$58,$01,$11,$20
    db $E4,$00,$D0,$52,$EE,$51,$20,$21
    db $44,$F2,$52,$C8,$15,$41,$20,$25
    db $11,$04,$00,$52,$F3,$01,$20,$FA
    db $6F,$55,$5B,$7F,$A5,$5B,$B5,$69
    db $FA,$FA,$FA

Level_Hard_17_Map:
    ; Level 32 (hard set, FF9D=20) map stream (Level_Pointer_Table_Hi id(17) == $59F6)
    db $F5,$32,$F5,$32,$F5,$32,$F7,$52
    db $F7,$52,$B5,$69,$F2,$52,$F2,$02
    db $6A,$02,$64,$02,$64,$02,$6A,$02
    db $05,$54,$E5,$54,$02,$79,$02,$F2
    db $52,$F2,$02,$04,$05,$02,$64,$02
    db $64,$02,$60,$02,$05,$54,$02,$64
    db $02,$60,$02,$F2,$52,$05,$5B,$E5
    db $54,$02,$6C,$52,$F2,$02,$6D,$52
    db $60,$52,$64,$02,$55,$E1,$64,$02
    db $04,$55,$02,$55,$E1,$64,$02,$F2
    db $02,$55,$E1,$05,$54,$02,$64,$02
    db $55,$E1,$0C,$50,$52,$64,$02,$54
    db $04,$52,$6C,$52,$04,$55,$02,$6D
    db $52

Level_33_Map:
    ; Level 33 map stream (compressed tilemap; Level_Pointer_Table id(33) == $5A5F)
    db $23,$FD,$FD,$EA,$25,$58,$85,$85
    db $85,$85,$85,$58,$52,$25,$EE,$88
    db $85,$85,$85,$58,$52,$25,$58,$85
    db $85,$85,$88,$85,$58,$52,$25,$FF
    db $FF,$85,$52,$65,$B0,$90,$6B,$0B
    db $69,$65,$00,$90,$FA,$69,$25,$6D
    db $FC,$6C,$52,$65,$00,$FF,$00,$69
    db $02,$68,$04,$44,$40,$64,$20,$02
    db $F7,$F2,$90,$F7,$20,$50,$25,$FF
    db $F7,$52,$05,$50,$65,$54,$44,$D5
    db $69,$05,$55,$02,$FF,$F7,$20,$55
    db $68,$65,$A5,$69,$64,$C5,$E9,$FA
    db $25,$74

Level_Hard_18_Map:
    ; Level 33 (hard set, FF9D=21) map stream (Level_Pointer_Table_Hi id(18) == $5AC1)
    db $23,$FD,$FD,$EA,$25,$FF,$FF,$69
    db $65,$52,$F2,$64,$F2,$65,$52,$04
    db $54,$64,$04,$54,$25,$C5,$52,$F2
    db $64,$F2,$25,$10,$FA,$F2,$05,$20
    db $25,$14,$54,$F2,$04,$54,$05,$20
    db $25,$F3,$FA,$6C,$20,$25,$15,$53
    db $F2,$05,$F7,$20,$25,$14,$54,$04
    db $54,$05,$F7,$20,$25,$F3,$F2,$05
    db $F7,$50,$25,$14,$54,$02,$55,$F2
    db $02,$00,$25,$F3,$12,$55,$04,$54
    db $76,$25,$F7,$F0,$F2,$76,$25,$F7
    db $52,$BB,$B5,$68,$42,$FA,$FA,$FA

Level_34_Map:
    ; Level 34 map stream (compressed tilemap; Level_Pointer_Table id(34) == $5B21)
    db $85,$FF,$FF,$EF,$83,$FD,$FD,$33
    db $38,$2B,$EF,$FF,$85,$69,$20,$05
    db $58,$EE,$58,$85,$E6,$6E,$B5,$58
    db $55,$85,$6B,$02,$20,$80,$E1,$7F
    db $50,$08,$02,$20,$55,$6A,$22,$55
    db $6A,$02,$20,$45,$50,$08,$44,$80
    db $05,$54,$02,$25,$04,$58,$00,$99
    db $00,$85,$40,$52,$E7,$45,$85,$99
    db $58,$54,$E1,$65,$04,$54,$99,$45
    db $40,$69,$25,$00,$58,$40,$55,$04
    db $85,$00,$52,$25,$05,$54,$64,$50
    db $45,$50,$52,$25,$7A,$FF,$79,$52
    db $65,$95,$FF,$59,$69,$2C,$FF,$5A
    db $FF,$D2

Level_Hard_19_Map:
    ; Level 34 (hard set, FF9D=22) map stream (Level_Pointer_Table_Hi id(19) == $5B8B)
    db $FF,$FF,$F7,$5C,$F2,$25,$FF,$55
    db $6E,$F7,$00,$65,$52,$00,$65,$FF
    db $65,$F0,$65,$44,$5B,$55,$6E,$02
    db $55,$24,$55,$6F,$E0,$FF,$6E,$68
    db $02,$FF,$20,$65,$F7,$52,$FA,$72
    db $55,$75,$FF,$F7,$E2,$6F,$FF,$F7
    db $6E,$68,$02,$E0,$6E,$65,$F7,$52
    db $F2,$65,$E2,$FF,$E0,$F7,$6E,$67
    db $52,$FA,$72,$55,$42,$6F,$67,$55
    db $72,$55,$00,$44,$B5,$55,$6E,$0B
    db $E2

Level_35_Map:
    ; Level 35 map stream (compressed tilemap; Level_Pointer_Table id(35) == $5BDC)
    db $FF,$EF,$FF,$55,$FF,$EF,$FF,$55
    db $FF,$55,$D8,$45,$FF,$21,$FB,$18
    db $FB,$12,$25,$FF,$58,$FF,$52,$25
    db $FF,$48,$67,$69,$E4,$00,$01,$18
    db $21,$10,$F3,$25,$FF,$58,$25,$FF
    db $25,$FF,$48,$E2,$F7,$E4,$00,$01
    db $18,$11,$19,$E3,$25,$FF,$58,$FF
    db $52,$25,$FF,$C8,$67,$69,$E4,$00
    db $01,$18,$11,$10,$E3,$25,$FF,$58
    db $FF,$55,$E2,$55,$A5,$58,$BB,$B5
    db $EC,$21,$70,$70,$70,$70

Level_Hard_20_Map:
    ; Level 35 (hard set, FF9D=23) map stream (Level_Pointer_Table_Hi id(20) == $5C32)
    db $FF,$FF,$FF,$F7,$52,$B5,$F7,$25
    db $F7,$F7,$72,$55,$73,$F7,$69,$55
    db $04,$44,$40,$55,$65,$69,$68,$00
    db $64,$65,$55,$65,$7A,$F7,$F0,$55
    db $65,$7A,$F7,$F0,$55,$65,$7A,$F7
    db $F0,$F0,$44,$66,$54,$44,$7F,$F0
    db $22,$24,$55,$42,$22,$7F,$52,$F7
    db $52,$7F,$F7,$25,$52,$FF,$FF,$7F
    db $7F,$F7,$25,$F7,$F0,$69,$65,$5B
    db $55,$B2,$24,$02,$C2,$FA,$FA,$02
    db $04,$FA,$FA,$00,$04,$02

Level_36_Map:
    ; Level 36 map stream (compressed tilemap; Level_Pointer_Table id(36) == $5C88)
    db $FF,$FF,$F7,$58,$5C,$BB,$B4,$54
    db $F7,$EC,$58,$21,$FB,$91,$FB,$18
    db $25,$FF,$FF,$EF,$22,$25,$FD,$7E
    db $45,$58,$24,$25,$F7,$66,$F2,$28
    db $22,$45,$F7,$45,$FF,$28,$F4,$6E
    db $40,$F7,$54,$28,$F1,$50,$6C,$52
    db $00,$90,$28,$22,$24,$6D,$69,$F7
    db $58,$F4,$55,$66,$52,$F7,$58,$F4
    db $F7,$53,$32,$67,$58,$65,$20,$6C
    db $52,$F2,$58,$25,$45,$20,$5D,$E1
    db $64,$58,$25,$A5,$20,$55,$E1,$05
    db $54,$58,$20,$FA,$FA,$F2

Level_Hard_21_Map:
    ; Level 36 (hard set, FF9D=24) map stream (Level_Pointer_Table_Hi id(21) == $5CE6)
    db $FF,$FF,$FF,$55,$53,$C2,$FA,$25
    db $35,$55,$7F,$00,$FF,$90,$F0,$52
    db $50,$FF,$F7,$05,$25,$25,$05,$FF
    db $F7,$50,$52,$20,$EB,$6D,$66,$50
    db $52,$20,$65,$64,$00,$66,$02,$05
    db $E7,$FF,$64,$02,$05,$E7,$55,$64
    db $64,$02,$05,$25,$64,$04,$50,$67
    db $02,$04,$25,$64,$61,$68,$52,$50
    db $25,$05,$FF,$68,$52,$50,$E7,$FF
    db $55,$E1,$20,$65,$00,$54,$45,$00
    db $69,$25,$60,$05,$00,$09,$F7,$52
    db $7A,$64,$5B,$B5,$20,$F2

Level_37_Map:
    ; Level 37 map stream (compressed tilemap; Level_Pointer_Table id(37) == $5D44)
    db $85,$FF,$FF,$F7,$23,$FD,$FD,$33
    db $55,$25,$FF,$FF,$F7,$65,$64,$75
    db $75,$45,$25,$FA,$F2,$09,$F2,$25
    db $FF,$FF,$F7,$65,$50,$E0,$74,$E0
    db $E7,$FA,$90,$FA,$25,$FF,$FF,$F7
    db $25,$F7,$05,$7D,$F7,$45,$65,$FA
    db $00,$09,$F2,$25,$FF,$FF,$F7,$25
    db $F7,$0D,$74,$74,$55,$65,$50,$FA
    db $FA,$25,$FF,$FF,$F7,$2A,$FF,$FF
    db $BB,$BC

Level_Hard_22_Map:
    ; Level 37 (hard set, FF9D=25) map stream (Level_Pointer_Table_Hi id(22) == $5D8E)
    db $FF,$FF,$FF,$FF,$FF,$FF,$C5,$F7
    db $B5,$FF,$F7,$FA,$FA,$F2,$02,$FF
    db $FF,$F7,$52,$FF,$F7,$FA,$02,$FF
    db $F7,$05,$7D,$52,$FF,$F7,$FA,$02
    db $FF,$02,$55,$7D,$5B,$52,$20,$F2
    db $02,$FA,$6F,$20,$74,$52,$FF,$69
    db $20,$F2,$02,$55,$B5,$F7,$52,$25
    db $F7,$52,$10,$6F,$6F,$25,$F7,$52
    db $14,$20,$52,$44,$52,$25,$F7,$02
    db $15,$62,$6F,$FA,$FA,$FA

Level_38_Map:
    ; Level 38 map stream (compressed tilemap; Level_Pointer_Table id(38) == $5DDC)
    db $FF,$FF,$F7,$58,$A5,$FF,$FF,$EF
    db $F2,$55,$BB,$EC,$5B,$53,$38,$09
    db $00,$42,$F2,$E8,$05,$58,$09,$69
    db $68,$E8,$05,$58,$09,$00,$6B,$20
    db $55,$6E,$58,$0D,$6C,$45,$20,$55
    db $6E,$58,$05,$F7,$54,$20,$E8,$04
    db $58,$02,$11,$01,$71,$55,$62,$58
    db $22,$F7,$03,$7E,$22,$02,$58,$25
    db $E6,$04,$F7,$52,$02,$58,$24,$E6
    db $00,$04,$09,$76,$58,$11,$54,$02
    db $6B,$E1,$02,$58,$11,$FA,$6F,$6F
    db $58,$11,$00,$5C,$44,$E9,$6F,$48
    db $11,$00,$F3,$70,$11,$10,$00

Level_Hard_23_Map:
    ; Level 38 (hard set, FF9D=26) map stream (Level_Pointer_Table_Hi id(23) == $5E43)
    db $FF,$FF,$FF,$FF,$FF,$FF,$C5,$F5
    db $54,$FF,$F7,$02,$F7,$FA,$25,$F7
    db $22,$44,$FA,$6F,$F7,$25,$6D,$FF
    db $00,$24,$55,$E7,$F7,$B5,$68,$02
    db $55,$25,$F7,$F2,$04,$E6,$55,$22
    db $68,$FA,$6F,$55,$22,$54,$00,$F5
    db $6E,$02,$55,$52,$61,$F7,$22,$6F
    db $55,$22,$61,$F7,$52,$62,$55,$22
    db $50,$04,$FF,$62,$55,$25,$6D,$95
    db $55,$42,$6F,$55,$65,$03,$32,$FA
    db $00,$25,$65,$52,$FA,$60,$02

Level_39_Map:
    ; Level 39 map stream (compressed tilemap; Level_Pointer_Table id(39) == $5E9A)
    db $85,$FF,$FF,$F7,$85,$C5,$45,$FD
    db $FF,$80,$F2,$F7,$52,$F7,$5A,$85
    db $F7,$66,$52,$D0,$F2,$85,$F7,$00
    db $69,$50,$F2,$85,$45,$02,$F7,$52
    db $50,$F2,$80,$6F,$55,$4B,$7F,$F2
    db $85,$54,$02,$F2,$05,$24,$00,$40
    db $80,$6F,$75,$05,$25,$F7,$84,$55
    db $02,$F2,$05,$25,$F2,$80,$6F,$75
    db $E1,$6D,$85,$54,$02,$F2,$E1,$50
    db $40,$80,$6F,$75,$05,$02,$66,$85
    db $45,$02,$F2,$05,$FA,$80,$6F,$F7
    db $54,$B5,$75,$FA,$FA,$FA

Level_Hard_24_Map:
    ; Level 39 (hard set, FF9D=27) map stream (Level_Pointer_Table_Hi id(24) == $5EF8)
    db $C5,$FF,$FF,$F7,$FA,$FA,$F2,$02
    db $FA,$F2,$F2,$E1,$54,$5B,$EC,$FA
    db $6F,$FA,$FA,$F2,$02,$FA,$FA,$F2
    db $02,$FA,$FA,$F2,$02,$F2,$B5,$E0
    db $FA,$02,$FA,$F2,$44,$B5,$55,$02
    db $FA,$FA,$F2,$02,$FA,$FA,$F2,$02
    db $FA,$00,$75,$F2,$02,$FA,$FA,$F2
    db $02,$FA,$FA,$F2,$02,$FA,$FA,$F2
    db $02,$FA,$F2,$05,$F7,$52

Level_40_Map:
    ; Level 40 map stream (compressed tilemap; Level_Pointer_Table id(40) == $5F3E)
    db $F0,$F5,$FF,$F7,$25,$6A,$A5,$25
    db $FF,$55,$25,$00,$04,$FA,$FF,$25
    db $6D,$F3,$10,$05,$F7,$EB,$D1,$F7
    db $51,$00,$F7,$85,$50,$12,$F7,$52
    db $09,$64,$85,$50,$12,$2B,$69,$09
    db $64,$85,$50,$52,$65,$52,$09,$64
    db $85,$E6,$52,$69,$09,$64,$85,$E6
    db $52,$69,$09,$64,$85,$E6,$B5,$25
    db $52,$09,$64,$85,$E6,$7F,$52,$09
    db $64,$85,$E6,$55,$73,$09,$64,$85
    db $E6,$54,$73,$09,$64,$85,$E6,$E0
    db $22,$59,$F7,$85,$5C,$01,$10,$01
    db $11,$00,$64

Level_Hard_25_Map:
    ; Level 40 (hard set, FF9D=28) map stream (Level_Pointer_Table_Hi id(25) == $5FA1)
    db $05,$FF,$FF,$EB,$02,$0C,$FF,$55
    db $11,$65,$22,$F2,$05,$F7,$15,$21
    db $45,$20,$F2,$14,$EC,$15,$21,$02
    db $6E,$40,$10,$F2,$15,$21,$02,$20
    db $F7,$14,$EC,$15,$21,$02,$20,$F7
    db $F3,$10,$15,$21,$02,$20,$FF,$5B
    db $F7,$21,$02,$65,$42,$45,$02,$64
    db $21,$02,$65,$02,$E3,$F2,$01,$02
    db $20,$45,$02,$69,$02,$F5,$32,$6E
    db $02,$45,$25,$F7,$64,$20,$FA,$64
    db $FA,$25,$FF,$FF,$67,$2B,$40,$E2
    db $B4,$66,$F2,$FA,$FA,$FA

Level_41_Map:
    ; Level 41 map stream (compressed tilemap; Level_Pointer_Table id(41) == $5FFF)
    db $80,$05,$A5,$FF,$FF,$80,$F2,$25
    db $45,$FF,$55,$80,$FA,$6C,$75,$55
    db $88,$80,$FA,$FA,$25,$00,$84,$55
    db $05,$F7,$5B,$7F,$00,$80,$20,$42
    db $FA,$F2,$00,$80,$20,$6A,$7D,$B5
    db $55,$88,$80,$2D,$50,$FA,$F2,$80
    db $F2,$50,$23,$FD,$30,$80,$64,$C5
    db $65,$65,$50,$80,$05,$F2,$64,$25
    db $F2,$85,$5B,$F7,$04,$00,$25,$F2
    db $FA,$02,$F7,$25,$00,$40,$04,$02
    db $55,$02,$F7,$25,$F2,$79,$52,$F2
    db $40,$F0,$40,$05,$02,$FA,$00,$F0
    db $50

Level_Hard_26_Map:
    ; Level 41 (hard set, FF9D=29) map stream (Level_Pointer_Table_Hi id(26) == $6060)
    db $FF,$55,$5B,$FF,$55,$F7,$21,$F3
    db $25,$FF,$F7,$21,$45,$21,$20,$54
    db $E0,$F7,$E4,$21,$20,$FA,$F7,$21
    db $05,$21,$25,$FF,$21,$FB,$6E,$02
    db $64,$65,$51,$45,$E2,$52,$F2,$25
    db $B5,$51,$11,$65,$F0,$5C,$21,$00
    db $21,$45,$65,$02,$F2,$21,$40,$E4
    db $6E,$02,$ED,$21,$F3,$45,$21,$45
    db $21,$44,$24,$65,$51,$11,$E4,$E4
    db $21,$6F,$01,$45,$21,$45,$21,$44
    db $24,$F2,$E4,$E4,$E4,$21,$04,$55
    db $21,$4B,$21,$45,$21,$44,$24,$60
    db $20,$FA,$FA

Level_42_Map:
    ; Level 42 map stream (compressed tilemap; Level_Pointer_Table id(42) == $60C3)
    db $85,$FF,$FF,$F7,$8A,$F7,$BB,$F7
    db $5B,$F7,$20,$43,$F5,$7D,$33,$43
    db $25,$25,$05,$66,$05,$20,$55,$05
    db $25,$25,$52,$00,$EC,$22,$5C,$E8
    db $25,$52,$68,$25,$02,$50,$40,$25
    db $25,$52,$F7,$24,$52,$25,$04,$55
    db $25,$42,$7E,$20,$7F,$50,$55,$25
    db $6A,$74,$45,$25,$43,$35,$65,$54
    db $50,$55,$05,$25,$64,$25,$45,$20
    db $68,$00,$54,$67,$22,$03,$25,$FF
    db $50,$F7,$52,$F7,$02,$D3,$34,$55
    db $33,$45,$52,$33,$66,$60,$65,$05
    db $69,$E5,$F7,$F4,$55,$69,$08,$FF
    db $EF,$55

Level_Hard_27_Map:
    ; Level 42 (hard set, FF9D=2A) map stream (Level_Pointer_Table_Hi id(27) == $612D)
    db $FF,$FF,$FF,$F7,$53,$FD,$F5,$32
    db $55,$C5,$5B,$FF,$F7,$52,$F3,$15
    db $FF,$F7,$52,$FF,$50,$FA,$E1,$6E
    db $25,$FF,$F7,$52,$20,$40,$25,$51
    db $FB,$15,$52,$7A,$55,$51,$F5,$32
    db $15,$52,$F2,$05,$FF,$52,$69,$F2
    db $05,$51,$E0,$42,$15,$52,$F2,$05
    db $51,$F7,$52,$15,$52,$05,$45,$05
    db $51,$E0,$42,$15,$52,$F2,$05,$51
    db $F7,$52,$15,$52,$55,$66,$51,$F3
    db $01,$15,$52,$67,$FF,$FF,$52,$FA
    db $00,$5B,$B0,$F2,$02

Level_43_Map:
    ; Level 43 map stream (compressed tilemap; Level_Pointer_Table id(43) == $618A)
    db $58,$FF,$FF,$A5,$55,$58,$FF,$55
    db $FA,$00,$58,$74,$E0,$05,$66,$00
    db $52,$FB,$11,$02,$F2,$04,$52,$E0
    db $5B,$69,$FF,$ED,$FA,$80,$FA,$7F
    db $45,$F7,$85,$B5,$E0,$6F,$00,$08
    db $00,$08,$FA,$69,$33,$38,$EF,$FF
    db $54,$52,$54,$58,$4B,$F3,$15,$55
    db $02,$01,$11,$81,$11,$15,$54,$6D
    db $52,$F7,$84,$E0,$11,$6E,$52,$50
    db $FA,$F2,$20,$0D,$20,$50,$C5,$FF
    db $54,$65,$25,$61,$FF,$00,$6E,$FA
    db $FA,$FA

Level_Hard_28_Map:
    ; Level 43 (hard set, FF9D=2B) map stream (Level_Pointer_Table_Hi id(28) == $61E4)
    db $4C,$50,$BB,$FF,$FF,$6E,$F7,$75
    db $FF,$E7,$55,$FB,$FB,$25,$F7,$12
    db $55,$51,$55,$75,$20,$6A,$12,$15
    db $51,$20,$6C,$20,$66,$12,$14,$51
    db $20,$EC,$20,$6A,$12,$21,$51,$20
    db $11,$14,$20,$66,$51,$21,$55,$65
    db $14,$20,$6A,$03,$21,$F3,$15,$15
    db $20,$6A,$25,$FF,$15,$15,$21,$65
    db $FB,$12,$15,$55,$21,$24,$55,$FC
    db $22,$10,$00,$21,$25,$FF,$F7,$10
    db $00,$E4,$55,$FB,$11,$14,$40,$25
    db $FF,$FF,$6D,$20,$FA,$FA,$F2

Level_44_Map:
    ; Level 44 map stream (compressed tilemap; Level_Pointer_Table id(44) == $6243)
    db $85,$FF,$FF,$F7,$EE,$5B,$F7,$75
    db $E0,$FA,$6F,$FA,$00,$FF,$69,$FF
    db $55,$FA,$25,$52,$FF,$45,$55,$02
    db $40,$20,$52,$68,$F2,$D5,$60,$6E
    db $09,$05,$EB,$FA,$20,$F7,$50,$65
    db $FA,$20,$FA,$64,$F7,$5A,$24,$55
    db $66,$7A,$FA,$FA,$20,$05,$00,$F7
    db $66,$66,$25,$6D,$20,$FA,$F2,$05
    db $00,$C5,$25,$FF,$FF,$F2,$65,$7D
    db $F7,$4B,$55,$5B,$FA,$FA,$FA

Level_Hard_29_Map:
    ; Level 44 (hard set, FF9D=2C) map stream (Level_Pointer_Table_Hi id(29) == $6292)
    db $FF,$FF,$FF,$FF,$45,$F7,$66,$B5
    db $FA,$FA,$F2,$02,$74,$50,$F7,$44
    db $50,$45,$02,$ED,$6A,$12,$F2,$55
    db $02,$51,$25,$F7,$12,$74,$E3,$51
    db $65,$20,$FA,$6F,$51,$65,$2B,$E0
    db $F7,$02,$51,$20,$54,$FA,$05,$6F
    db $51,$E4,$33,$25,$75,$52,$02,$51
    db $23,$7E,$20,$F2,$76,$51,$F7,$54
    db $20,$F7,$52,$02,$51,$F7,$51,$20
    db $54,$41,$11,$02,$51,$FB,$FB,$E3
    db $C5,$FF,$FF,$55,$B2,$00,$EC,$66
    db $20,$FA

Level_45_Map:
    ; Level 45 map stream (compressed tilemap; Level_Pointer_Table id(45) == $62EC)
    db $FF,$FF,$FF,$45,$FA,$25,$FF,$52
    db $FA,$ED,$40,$04,$6F,$05,$40,$F2
    db $20,$FA,$02,$6C,$45,$ED,$05,$75
    db $02,$FA,$ED,$FA,$02,$FA,$ED,$55
    db $B0,$40,$22,$FA,$ED,$55,$A0,$50
    db $25,$55,$75,$55,$65,$B0,$00,$25
    db $FA,$02,$F7,$51,$12,$25,$FF,$52
    db $F2,$54,$12,$55,$C5,$F7,$52,$02
    db $0D,$51,$12,$55,$64,$E6,$79,$52
    db $22,$55,$52,$FC,$F2,$58,$F7,$FF
    db $FF,$58,$F7,$FF,$FF,$58,$F7

Level_Hard_30_Map:
    ; Level 45 (hard set, FF9D=2D) map stream (Level_Pointer_Table_Hi id(30) == $6343)
    db $FF,$55,$5B,$55,$B5,$55,$5C,$ED
    db $FA,$FA,$20,$77,$04,$F2,$04,$F6
    db $22,$20,$55,$04,$FA,$6F,$12,$02
    db $6C,$00,$50,$F2,$02,$12,$02,$04
    db $05,$00,$50,$04,$40,$20,$12,$E5
    db $04,$7A,$FA,$12,$F3,$10,$00,$50
    db $FA,$12,$25,$F7,$50,$40,$FA,$12
    db $6E,$01,$21,$51,$FB,$12,$20,$55
    db $51,$25,$FF,$69,$77,$01,$25,$FF
    db $69,$77,$41,$20,$F2,$64,$52,$77
    db $51,$20,$52,$04,$F2,$25,$77,$51
    db $20,$52,$05,$04,$50,$25,$FA,$FA
    db $05,$E5

Level_46_Map:
    ; Level 46 map stream (compressed tilemap; Level_Pointer_Table id(46) == $63A5)
    db $FF,$FF,$F7,$58,$A5,$55,$B5,$69
    db $14,$F6,$48,$FA,$6F,$12,$F2,$08
    db $55,$75,$E9,$12,$6E,$58,$FB,$11
    db $02,$11,$24,$40,$58,$54,$44,$F7
    db $25,$11,$52,$F2,$F2,$02,$6C,$E3
    db $F7,$55,$44,$52,$15,$F7,$12,$EC
    db $50,$71,$12,$04,$00,$F3,$12,$F7
    db $B4,$78,$E0,$5B,$12,$FA,$12,$10
    db $FA,$12,$FF,$52,$15,$75,$E9,$75
    db $6E,$10,$F2,$E1,$F2,$65,$10,$F2
    db $02,$00,$45,$30,$25,$44,$1C,$F7
    db $52,$0D,$7A,$20,$F2,$64,$52,$00

Level_Hard_31_Map:
    ; Level 46 (hard set, FF9D=2E) map stream (Level_Pointer_Table_Hi id(31) == $6405)
    db $F7,$5B,$50,$FF,$F7,$50,$FA,$00
    db $2B,$B5,$55,$02,$FF,$5C,$55,$FA
    db $02,$51,$FB,$14,$FE,$52,$55,$44
    db $F2,$01,$FB,$12,$6D,$54,$63,$25
    db $45,$6F,$50,$F2,$05,$44,$20,$F2
    db $02,$50,$FA,$ED,$04,$6F,$50,$F2
    db $75,$20,$60,$02,$50,$04,$44,$FA
    db $00,$04,$52,$50,$FA,$05,$44,$F2
    db $02,$6D,$44,$24,$52,$FA,$02,$6D
    db $20,$40,$F2,$45,$00,$42,$6D,$40
    db $20,$FA,$44,$02,$6D,$20,$45,$FA
    db $6F,$50,$FA,$74,$E0,$52

Level_48_Map:
    ; Level 48 map stream (compressed tilemap; Level_Pointer_Table id(48) == $6463)
    db $85,$FF,$FF,$45,$5A,$EE,$BB,$B4
    db $74,$50,$F2,$80,$FA,$FA,$F2,$85
    db $F7,$05,$75,$FF,$85,$50,$25,$FA
    db $FA,$F2,$25,$FF,$FF,$F7,$20,$54
    db $44,$55,$FA,$20,$FA,$FA,$ED,$65
    db $51,$F3,$FF,$25,$25,$30,$65,$51
    db $C5,$F7,$2D,$E7,$65,$51,$15,$68
    db $11,$E7,$25,$00,$25,$F3,$10,$11
    db $23,$50,$23,$55,$65,$66,$45,$68
    db $65,$42,$FA,$00,$ED,$05,$45,$12
    db $64,$20,$55,$ED,$63,$E5,$44,$20
    db $45

Level_Hard_32_Map:
    ; Level 47 (hard set, FF9D=2F) map stream (Level_Pointer_Table_Hi id(32) == $64BC)
    db $FF,$FF,$FF,$5C,$54,$75,$67,$44
    db $F7,$21,$FA,$09,$FA,$00,$21,$55
    db $75,$FF,$F7,$21,$FB,$15,$20,$F2
    db $04,$21,$74,$F7,$65,$54,$45,$21
    db $FA,$25,$20,$F2,$04,$21,$54,$E0
    db $72,$67,$45,$21,$20,$F2,$15,$20
    db $F2,$04,$21,$25,$45,$4B,$15,$65
    db $54,$45,$21,$FB,$15,$20,$F2,$04
    db $E2,$55,$66,$65,$54,$45,$FA,$6C
    db $20,$F2,$05,$FF,$F7,$25,$FF,$FF
    db $F7,$25,$5B,$B5,$55,$FA,$FA,$FA

Level_47_Map:
    ; Level 47 map stream (compressed tilemap; Level_Pointer_Table id(47) == $6514)
    db $00,$B5,$FF,$FF,$55,$F7,$88,$88
    db $82,$FA,$00,$5A,$55,$81,$E3,$5B
    db $55,$75,$11,$55,$81,$55,$6E,$02
    db $F2,$65,$81,$00,$65,$02,$F7,$21
    db $55,$81,$D0,$65,$02,$55,$C5,$21
    db $55,$81,$50,$25,$52,$F2,$02,$21
    db $FB,$F3,$F7,$52,$25,$FF,$68,$20
    db $44,$52,$20,$F2,$64,$50,$21,$F3
    db $20,$F2,$05,$6E,$25,$F7,$20,$04
    db $40,$05,$20,$40,$20,$F2,$20,$F2
    db $05,$20,$40,$20,$04,$55,$23,$00
    db $04,$45,$20,$50,$20,$F2,$F7,$61
    db $20,$0B,$20,$04,$55,$FA,$05,$6E
    db $E5,$45

Level_Hard_33_Map:
    ; Level 48 (hard set, FF9D=30) map stream (Level_Pointer_Table_Hi id(33) == $657E)
    db $54,$E0,$B4,$55,$75,$55,$5C,$76
    db $76,$92,$76,$92,$02,$52,$42,$42
    db $73,$73,$73,$77,$77,$77,$77,$20
    db $72,$72,$72,$72,$25,$76,$92,$76
    db $76,$76,$42,$52,$42,$52,$42,$52
    db $42,$73,$77,$77,$29,$77,$77,$72
    db $2B,$25,$24,$24,$25,$24,$25,$76
    db $76,$76,$76,$02,$73,$73,$73,$73
    db $52,$77,$29,$77,$77,$77,$25,$24
    db $25,$24,$25,$24,$25,$24,$25,$76
    db $76,$76,$76,$02,$52,$42,$73,$B2
    db $52,$42,$42,$52,$78,$78,$78,$78
    db $12

Level_49_Map:
    ; Level 49 map stream (compressed tilemap; Level_Pointer_Table id(49) == $65DF)
    db $55,$15,$FF,$FF,$55,$55,$1C,$FA
    db $ED,$F2,$55,$FB,$F3,$20,$12,$0D
    db $A5,$FF,$F7,$20,$55,$05,$6F,$FA
    db $00,$FB,$69,$5B,$55,$7D,$54,$B5
    db $55,$21,$FA,$FA,$02,$12,$21,$FF
    db $FF,$52,$12,$21,$20,$FA,$FA,$12
    db $21,$25,$45,$FF,$F7,$12,$21,$6F
    db $66,$54,$F2,$12,$24,$54,$6F,$55
    db $6E,$45,$42,$20,$FA,$88,$FA,$02
    db $21,$FA,$84,$FA,$12,$21,$FF,$FF
    db $55,$12,$21,$FB,$FB,$E3

Level_Hard_34_Map:
    ; Level 49 (hard set, FF9D=31) map stream (Level_Pointer_Table_Hi id(34) == $6635)
    db $74,$66,$74,$54,$F7,$71,$10,$12
    db $FB,$15,$5C,$54,$66,$52,$15,$F7
    db $52,$00,$F3,$E4,$15,$67,$42,$55
    db $F7,$24,$45,$15,$54,$40,$02,$0B
    db $20,$44,$E4,$04,$40,$F2,$02,$E4
    db $14,$45,$6C,$75,$52,$65,$E6,$F2
    db $09,$F2,$2B,$F2,$02,$53,$F5,$F7
    db $FA,$22,$50,$F7,$6E,$FF,$E7,$6C
    db $20,$44,$20,$04,$54,$20,$50,$6C
    db $6E,$25,$FA,$50,$6C,$6E,$25,$FF
    db $50,$E0,$20,$54,$25,$5B,$55,$44
    db $50,$6C,$20,$55,$FA,$FA,$FA

Level_30_Map:
    ; Level 30 map stream (compressed tilemap; Level_Pointer_Table id(30) == $6694)
    db $85,$FF,$F7,$75,$45,$8B,$BB,$75
    db $52,$FA,$00,$50,$FA,$02,$A5,$FF
    db $55,$7D,$68,$6F,$75,$50,$FA,$65
    db $6D,$20,$F7,$66,$F2,$25,$45,$25
    db $51,$11,$10,$02,$EC,$F2,$02,$FF
    db $6D,$02,$F7,$52,$55,$C5,$FF,$50
    db $F2,$20,$50,$6C,$FF,$F7,$25,$50
    db $54,$05,$F7,$52,$74,$25,$6D,$64
    db $44,$52,$FA,$55,$75,$20,$F2,$FF
    db $20,$F2,$05,$F7,$20,$F2,$25,$F7
    db $52,$64,$20,$04,$D0,$FA,$FA,$FA

Level_Hard_05_Map:
    ; Level 20 (hard set, FF9D=14) map stream (Level_Pointer_Table_Hi id(05) == $66EC)
    db $23,$FD,$EA,$25,$B5,$F7,$5B,$52
    db $25,$7B,$7C,$52,$E7,$40,$04,$E1
    db $25,$04,$F2,$40,$52,$25,$10,$F2
    db $01,$52,$25,$51,$F3,$15,$52,$65
    db $52,$65,$52,$72,$25,$73,$52,$25
    db $22,$2C,$52,$22,$52,$25,$FF,$69
    db $FA,$FA

Level_12_Map:
    ; Level 12 map stream (compressed tilemap; Level_Pointer_Table id(12) == $671E)
    db $FF,$FF,$FF,$FA,$02,$FF,$F7,$A5
    db $55,$43,$30,$00,$02,$FF,$0B,$BB
    db $08,$33,$55,$FA,$08,$F2,$08,$55
    db $43,$35,$F7,$58,$F7,$08,$88,$08
    db $54,$33,$EF,$F7,$F2,$08,$80,$85
    db $EF,$F7,$64,$F2,$85,$43,$88,$F7
    db $64,$60,$88,$05,$88,$F7,$64,$60
    db $00,$05,$88,$F7,$64,$60,$55,$05
    db $84,$FF,$FF,$EF,$82,$50,$21,$FB
    db $F3,$18,$00,$50,$20,$FA,$F2,$08
    db $00,$40,$20,$FA,$F2,$08,$00,$40
    db $20,$FA,$FA,$00,$00,$00,$00,$00
    db $00,$00,$00,$00,$3D,$3D,$C3,$FF
    db $87,$FD,$7E,$56,$36,$36,$79,$79
    db $7B,$74,$33,$2D,$63,$5C,$62,$5F
    db $22,$3F,$1D,$1D,$60,$60,$A0,$E0
    db $90,$70,$90,$F0,$90,$70,$D0,$F0
    db $E0,$A0,$70,$70,$63,$63,$FC,$FC
    db $F1,$FE,$33,$2D,$63,$5C,$22,$3F
    db $1E,$1F,$01,$01,$83,$83,$FC,$FC
    db $E4,$DF,$E1,$DF,$63,$5C,$22,$3F
    db $1E,$1F,$01,$01,$00,$00,$00,$00
    db $00,$00,$01,$01,$01,$01,$03,$03
    db $04,$04,$00,$00,$79,$57,$7E,$46
    db $C3,$BD,$41,$3D,$41,$7D,$FE,$C2
    db $3C,$3C,$7E,$7E,$00,$00,$00,$00
    db $00,$00,$00,$00,$BD,$BD,$C3,$FF
    db $BD,$E7,$BD,$E7,$00,$00,$00,$00
    db $00,$00,$02,$02,$89,$88,$02,$1A
    db $BC,$A6,$BD,$E7,$00,$00,$00,$00
    db $00,$00,$00,$00,$02,$02,$00,$01
    db $02,$12,$03,$06,$00,$00,$00,$00
    db $00,$00,$00,$00,$0B,$0B,$0C,$0F
    db $0C,$0B,$0C,$0B,$00,$00,$00,$00
    db $00,$00,$00,$00,$D0,$D0,$30,$F0
    db $30,$D0,$30,$D0,$00,$00,$00,$00
    db $00,$00,$00,$80,$00,$00,$20,$A0
    db $C8,$40,$50,$70,$00,$00,$00,$00
    db $00,$00,$02,$02,$20,$20,$02,$12
    db $AC,$A4,$10,$02,$00,$00,$00,$00
    db $00,$00,$08,$08,$20,$20,$02,$02
    db $28,$20,$00,$00,$1F,$19,$27,$25
    db $1C,$13,$0C,$0F,$14,$17,$1F,$18
    db $1F,$1F,$00,$00,$79,$57,$7E,$46
    db $C3,$BD,$81,$BD,$81,$BD,$7E,$42
    db $3C,$3C,$7E,$7E,$79,$57,$BE,$86
    db $81,$B9,$61,$59,$F6,$EA,$FF,$F3
    db $6F,$6F,$07,$07,$79,$57,$7E,$46
    db $0E,$32,$42,$72,$42,$72,$3C,$24
    db $1C,$1C,$3C,$3C,$79,$57,$7E,$46
    db $01,$3D,$42,$66,$47,$63,$7F,$4F
    db $73,$73,$F0,$F0,$0F,$0D,$17,$14
    db $0C,$0B,$04,$07,$04,$07,$1F,$1C
    db $1F,$1F,$0C,$0C,$90,$70,$E8,$68
    db $30,$D0,$20,$E0,$20,$E0,$F8,$38
    db $F8,$F8,$30,$30,$07,$05,$0F,$0C
    db $14,$13,$0C,$0F,$04,$07,$1F,$1C
    db $1F,$1F,$0C,$0C,$90,$70,$F0,$70
    db $28,$C8,$30,$F0,$20,$E0,$F8,$38
    db $F8,$F8,$30,$30,$07,$05,$07,$04
    db $04,$07,$0C,$0B,$08,$0B,$07,$04
    db $1F,$1F,$0E,$0E,$90,$70,$E0,$60
    db $20,$E0,$30,$D0,$10,$D0,$E0,$20
    db $F8,$F8,$70,$70,$18,$1F,$2F,$27
    db $1C,$1B,$04,$07,$1E,$1D,$1F,$1E
    db $01,$01,$00,$00,$10,$F0,$E0,$E0
    db $30,$D0,$28,$E8,$38,$F8,$E0,$20
    db $E0,$E0,$70,$70,$08,$0F,$1F,$1F
    db $24,$23,$1C,$1F,$04,$07,$07,$04
    db $03,$03,$07,$07,$0B,$09,$27,$25
    db $08,$03,$0C,$2F,$14,$17,$1F,$18
    db $15,$15,$00,$00,$23,$01,$0B,$09
    db $00,$23,$0C,$0E,$04,$05,$27,$20
    db $14,$04,$00,$01,$01,$01,$09,$09
    db $02,$02,$08,$0A,$00,$00,$25,$20
    db $04,$04,$00,$00,$00,$00,$00,$00
    db $00,$00,$00,$00,$3C,$3C,$72,$4E
    db $FD,$83,$FD,$F3,$36,$36,$7F,$49
    db $7E,$48,$2F,$3B,$7F,$4A,$7F,$46
    db $3E,$23,$1D,$1D,$C0,$C0,$E0,$A0
    db $F0,$90,$F0,$90,$F0,$10,$D0,$30
    db $20,$E0,$C0,$C0,$73,$73,$FF,$8C
    db $6F,$59,$5F,$69,$7F,$46,$3F,$22
    db $1E,$1F,$01,$01,$83,$83,$FF,$FC
    db $DF,$A4,$DF,$A9,$7F,$6E,$1F,$12
    db $0E,$0F,$01,$01,$00,$00,$08,$08
    db $00,$00,$02,$00,$00,$08,$00,$00
    db $02,$02,$00,$00,$00,$00,$00,$00
    db $10,$10,$38,$28,$10,$10,$00,$00
    db $00,$00,$00,$00,$00,$00,$00,$00
    db $18,$18,$3C,$24,$3C,$24,$18,$18
    db $00,$00,$00,$00,$00,$00,$18,$18
    db $3C,$24,$6E,$42,$7E,$42,$3C,$24
    db $18,$18,$00,$00,$18,$18,$7E,$66
    db $6E,$42,$DB,$85,$FB,$85,$76,$4A
    db $7E,$66,$18,$18,$00,$00,$00,$00
    db $00,$00,$00,$00,$03,$03,$07,$04
    db $0F,$08,$0F,$08,$00,$00,$00,$00
    db $00,$00,$00,$00,$C0,$C0,$A0,$60
    db $D0,$30,$D0,$30,$1F,$1F,$20,$21
    db $5F,$5F,$50,$5F,$A7,$B8,$AF,$B0
    db $AF,$B0,$AF,$B8,$80,$80,$40,$40
    db $A0,$E0,$A0,$A0,$D0,$70,$D0,$70
    db $D0,$70,$D0,$70,$1F,$1F,$20,$21
    db $5F,$5F,$50,$50,$A0,$A0,$A0,$A0
    db $A0,$A0,$A0,$A0,$80,$80,$40,$40
    db $A0,$E0,$A0,$A0,$50,$70,$50,$70
    db $50,$70,$50,$70,$5F,$51,$7E,$4E
    db $FF,$BD,$FF,$C3,$FF,$C3,$66,$7E
    db $3C,$24,$7E,$7E,$5F,$51,$FF,$CF
    db $FF,$B9,$7F,$45,$DA,$A6,$FF,$D9
    db $6F,$6B,$06,$06,$5F,$51,$7E,$4E
    db $3E,$3A,$7E,$52,$7E,$4A,$26,$3E
    db $1E,$12,$3E,$3E,$5F,$51,$7E,$5E
    db $3F,$25,$7F,$57,$7B,$5D,$4F,$77
    db $79,$49,$F8,$F8,$0D,$0D,$1F,$14
    db $0F,$0B,$07,$04,$07,$04,$1E,$1F
    db $1F,$13,$0C,$0C,$F0,$10,$F8,$E8
    db $F0,$D0,$E0,$20,$E0,$20,$78,$F8
    db $F8,$C8,$30,$30,$05,$05,$0F,$0C
    db $1F,$13,$0F,$0C,$07,$04,$1E,$1F
    db $1F,$13,$0C,$0C,$F0,$10,$F0,$F0
    db $F8,$C8,$F0,$30,$E0,$20,$78,$F8
    db $F8,$C8,$30,$30,$0D,$0D,$07,$04
    db $0F,$0B,$1F,$14,$0F,$0C,$1E,$1F
    db $1F,$13,$0C,$0C,$F0,$10,$E0,$E0
    db $F0,$D0,$F8,$28,$F0,$30,$78,$F8
    db $F8,$C8,$30,$30,$1F,$18,$3F,$27
    db $1F,$1C,$07,$04,$0D,$0E,$0F,$09
    db $0E,$0E,$00,$00,$F0,$10,$E0,$E0
    db $F0,$30,$F8,$28,$F0,$30,$20,$E0
    db $E0,$A0,$F0,$F0,$0F,$08,$1F,$1F
    db $3F,$24,$1F,$1C,$07,$04,$04,$07
    db $03,$02,$07,$07,$80,$00,$E0,$E0
    db $00,$FC,$00,$FF,$00,$FF,$FF,$FF
    db $FF,$00,$FF,$EF,$30,$00,$30,$10
    db $70,$50,$70,$D0,$70,$D0,$F0,$D0
    db $F0,$00,$F0,$F0,$00,$00,$00,$00
    db $00,$80,$00,$C0,$00,$E0,$F8,$F8
    db $FF,$00,$FF,$EF,$A7,$B8,$AF,$B0
    db $AF,$B0,$AF,$B0,$00,$00,$00,$00
    db $00,$00,$00,$00,$D0,$70,$D0,$70
    db $D0,$70,$D0,$70,$00,$00,$00,$00
    db $00,$00,$00,$00,$A0,$A0,$A0,$A0
    db $A0,$A0,$A0,$A0,$00,$00,$00,$00
    db $00,$00,$00,$00,$50,$70,$50,$70
    db $50,$70,$50,$70,$00,$00,$00,$00
    db $00,$00,$00,$00,$38,$EF,$38,$EF
    db $38,$EF,$FF,$EF,$00,$00,$00,$00
    db $00,$00,$00,$00,$00,$F0,$00,$F0
    db $00,$F0,$F0,$F0,$00,$00,$00,$00
    db $00,$00,$00,$00,$1F,$1F,$20,$21
    db $5F,$5F,$50,$57,$A3,$A4,$A7,$A0
    db $A7,$A0,$A3,$A4,$A3,$A4,$A7,$A0
    db $A7,$A0,$A7,$A0,$00,$00,$00,$00
    db $00,$00,$00,$00,$1F,$1F,$20,$21
    db $5F,$5F,$50,$51,$A0,$A1,$A0,$A1
    db $A0,$A1,$A1,$A0,$A1,$A0,$A1,$A0
    db $A1,$A0,$A1,$A0,$00,$00,$00,$00
    db $00,$00,$00,$00,$00,$00,$00,$00
    db $10,$10,$30,$10,$70,$50,$70,$50
    db $F0,$00,$F0,$F0,$00,$00,$00,$00
    db $00,$00,$00,$00,$00,$00,$80,$80
    db $F0,$00,$FF,$EF,$00,$00,$00,$00
    db $00,$00,$00,$00,$10,$10,$70,$50
    db $70,$00,$F0,$F0,$20,$E0,$38,$E9
    db $38,$EF,$FF,$EF,$00,$00,$00,$00
    db $00,$00,$00,$00,$00,$70,$00,$F0
    db $00,$F0,$F0,$F0,$00,$00,$00,$00
    db $00,$00,$00,$00,$00,$00,$00,$C0
    db $00,$C0,$FD,$ED,$00,$00,$00,$00
    db $00,$00,$00,$00,$67,$67,$78,$5F
    db $70,$5F,$7A,$7F,$40,$7F,$7F,$7F
    db $2F,$32,$2F,$32,$E6,$E6,$1E,$FA
    db $3E,$CA,$16,$EE,$06,$FE,$F4,$FC
    db $F4,$4C,$F4,$4C,$07,$07,$08,$08
    db $11,$10,$25,$20,$2D,$20,$2F,$20
    db $2D,$20,$2F,$20,$E0,$E0,$F0,$90
    db $F8,$88,$FC,$84,$F4,$8C,$F4,$8C
    db $D4,$AC,$F4,$8C,$0F,$0F,$30,$30
    db $45,$40,$5B,$41,$BF,$83,$BD,$85
    db $B9,$8D,$B3,$95,$00,$00,$B8,$B8
    db $FC,$C4,$FE,$E2,$9F,$F1,$0F,$F9
    db $8F,$79,$87,$7D,$00,$00,$01,$01
    db $03,$02,$02,$02,$02,$02,$02,$02
    db $01,$01,$00,$00,$2F,$32,$CF,$F0
    db $3F,$30,$2F,$2F,$73,$7C,$71,$1E
    db $F5,$9A,$71,$7E,$03,$03,$04,$04
    db $04,$04,$02,$02,$01,$01,$00,$00
    db $00,$00,$00,$00,$AF,$B2,$6F,$72
    db $4F,$70,$3F,$30,$7F,$4F,$F3,$9C
    db $75,$5A,$31,$3E,$20,$3F,$C7,$FF
    db $F0,$3F,$EF,$2F,$73,$FC,$70,$9F
    db $F0,$9F,$70,$7F,$06,$FC,$E3,$FE
    db $0C,$FE,$FE,$F9,$CF,$39,$0E,$FA
    db $0C,$FC,$08,$F8,$C1,$81,$E3,$82
    db $FF,$8F,$73,$5C,$31,$3E,$15,$1A
    db $11,$1E,$15,$1A,$67,$67,$78,$5F
    db $70,$5F,$7A,$7F,$40,$7F,$7F,$7F
    db $33,$32,$61,$61,$CF,$F0,$3F,$30
    db $3F,$3F,$3E,$03,$FE,$81,$7E,$41
    db $F4,$FF,$14,$1F,$F2,$0E,$FC,$0C
    db $F0,$F0,$10,$F0,$10,$F0,$10,$F0
    db $08,$F8,$08,$F8,$4F,$70,$3F,$30
    db $0F,$0F,$33,$3C,$71,$5E,$75,$5A
    db $F1,$9E,$95,$9A,$1F,$1F,$1F,$10
    db $3F,$20,$3F,$23,$3F,$21,$1E,$1E
    db $7E,$7E,$7E,$7E,$2F,$20,$17,$10
    db $08,$0B,$07,$07,$00,$00,$00,$00
    db $00,$00,$00,$00,$D4,$AC,$C8,$B8
    db $90,$F0,$E0,$E0,$00,$00,$00,$00
    db $00,$00,$00,$00,$EA,$A4,$4A,$44
    db $14,$02,$24,$02,$40,$12,$08,$11
    db $88,$11,$84,$21,$C7,$BD,$E6,$9E
    db $7C,$44,$B8,$38,$84,$00,$84,$10
    db $42,$10,$20,$10,$00,$00,$00,$00
    db $06,$06,$07,$07,$07,$07,$03,$03
    db $03,$03,$01,$01,$15,$1A,$11,$1E
    db $3F,$3F,$FF,$C0,$FF,$C0,$FF,$E7
    db $F8,$F8,$C0,$C0,$00,$00,$67,$67
    db $78,$5F,$70,$5F,$70,$5F,$70,$5F
    db $70,$5F,$20,$3F,$00,$00,$E6,$E6
    db $1E,$FA,$6E,$9A,$6E,$9A,$0E,$FA
    db $0F,$FB,$04,$FC,$00,$00,$67,$67
    db $78,$5F,$70,$5F,$70,$5F,$70,$5F
    db $F0,$DF,$20,$3F,$00,$00,$E6,$E6
    db $1E,$FA,$6E,$9A,$6E,$9A,$0E,$FA
    db $0E,$FA,$04,$FC,$E6,$E6,$1E,$FA
    db $3E,$CA,$16,$EE,$06,$FE,$F4,$FC
    db $CC,$4C,$86,$86,$00,$00,$00,$00
    db $00,$00,$00,$00,$00,$00,$00,$00
    db $00,$00,$00,$00,$7F,$70,$8F,$88
    db $8F,$8F,$BE,$83,$FE,$C1,$BE,$A1
    db $74,$7F,$14,$1F,$1F,$1F,$1F,$10
    db $1F,$10,$1F,$11,$1F,$11,$0F,$0F
    db $3F,$3F,$3F,$3F,$9F,$9F,$7F,$70
    db $1F,$10,$1F,$11,$1F,$11,$0F,$0F
    db $3F,$3F,$3F,$3F,$FC,$FC,$FE,$02
    db $FE,$0E,$FE,$FE,$1F,$1F,$1F,$1F
    db $00,$00,$00,$00,$01,$00,$01,$00
    db $60,$00,$00,$00,$00,$04,$00,$04
    db $00,$40,$00,$40,$00,$00,$00,$04
    db $20,$04,$20,$00,$00,$00,$0C,$00
    db $00,$00,$00,$00,$84,$22,$00,$22
    db $10,$24,$12,$04,$12,$40,$21,$00
    db $21,$00,$40,$00,$80,$80,$C0,$40
    db $40,$40,$40,$40,$80,$80,$80,$80
    db $00,$00,$00,$00,$00,$10,$00,$30
    db $00,$70,$F0,$F0,$00,$00,$00,$00
    db $00,$00,$00,$00,$38,$38,$7C,$44
    db $FE,$BA,$EE,$AA,$FE,$BA,$7C,$44
    db $3E,$32,$0F,$09,$00,$00,$00,$00
    db $00,$00,$00,$00,$00,$00,$00,$00
    db $40,$40,$E0,$A0,$7F,$49,$3E,$26
    db $1E,$12,$0C,$0C,$00,$00,$00,$00
    db $00,$00,$00,$00,$00,$00,$00,$00
    db $00,$0E,$00,$06,$00,$01,$00,$00
    db $00,$0C,$00,$00,$00,$00,$00,$00
    db $00,$00,$00,$00,$00,$00,$00,$00
    db $00,$00,$00,$00,$00,$00,$00,$00
    db $00,$00,$00,$00,$00,$00,$00,$00
    db $00,$00,$00,$00,$60,$60,$78,$78
    db $7C,$7C,$7E,$7E,$7C,$7C,$78,$78
    db $60,$60,$00,$00,$1F,$1F,$7F,$70
    db $7F,$78,$7F,$7C,$7F,$7F,$40,$40
    db $00,$00,$00,$00,$F9,$F9,$FF,$07
    db $FF,$0F,$FF,$0F,$FF,$FF,$00,$00
    db $00,$00,$00,$00
    ; Graphics/bitmap data block ($6F7A-$7779, 0x800 bytes): repeated 0x0E-byte patterns (row masks/digit tiles); not referenced by code directly
    db $EF,$28,$EF,$28,$DF,$50,$DF,$50
    db $DF,$50,$DF,$50,$EF,$28,$E7,$E7
    db $FF,$7F,$C6,$46,$FE,$3A,$FE,$02
    db $FE,$02,$FE,$02,$FC,$04,$F8,$F8
    db $7F,$41,$7F,$41,$FE,$82,$FE,$82
    db $FE,$82,$FE,$82,$FF,$81,$7F,$7F
    db $00,$00,$00,$00,$00,$00,$7D,$7D
    db $11,$11,$11,$11,$11,$11,$11,$11
    db $00,$00,$00,$00,$00,$00,$10,$10
    db $B0,$B0,$50,$50,$10,$10,$10,$10
    db $C3,$C3,$C6,$C6,$C6,$C6,$C6,$C6
    db $C6,$C6,$C6,$C6,$F3,$F3,$00,$00
    db $39,$39,$B5,$B5,$B5,$B5,$B5,$B5
    db $B5,$B5,$B5,$B5,$39,$39,$00,$00
    db $E0,$E0,$80,$80,$80,$80,$C0,$C0
    db $80,$80,$80,$80,$E0,$E0,$00,$00
    db $E6,$E6,$D6,$D6,$D6,$D6,$E6,$E6
    db $D6,$D6,$D6,$D6,$D3,$D3,$00,$00
    db $B2,$B2,$B2,$B2,$BA,$BA,$BE,$BE
    db $B6,$B6,$B2,$B2,$32,$32,$00,$00
    db $CB,$CB,$CB,$CB,$EB,$EB,$FB,$FB
    db $DB,$DB,$CB,$CB,$CB,$CB,$00,$00
    db $DC,$DC,$1A,$1A,$1A,$1A,$9C,$9C
    db $1A,$1A,$1A,$1A,$DA,$DA,$00,$00
    db $C0,$C0,$C0,$C0,$E6,$E6,$D3,$D3
    db $D1,$D1,$D7,$D7,$E6,$E6,$00,$00
    db $03,$03,$03,$03,$43,$43,$43,$43
    db $83,$83,$03,$03,$03,$03,$00,$00
    db $80,$80,$40,$40,$54,$54,$9D,$9D
    db $59,$59,$59,$59,$98,$98,$00,$00
    db $03,$03,$03,$03,$C7,$C7,$AB,$AB
    db $AB,$AB,$AB,$AB,$C7,$C7,$00,$00
    db $E7,$E7,$6D,$6D,$6D,$6D,$67,$67
    db $61,$61,$6D,$6D,$67,$67,$00,$00
    db $1C,$1C,$B6,$B6,$B6,$B6,$9C,$9C
    db $B6,$B6,$B6,$B6,$1C,$1C,$00,$00
    db $70,$70,$D8,$D8,$D8,$D8,$78,$78
    db $18,$18,$D8,$D8,$70,$70,$00,$00
    db $E3,$E3,$D3,$D3,$D5,$D5,$E5,$E5
    db $D7,$D7,$D5,$D5,$E5,$E5,$00,$00
    db $32,$32,$32,$32,$BA,$BA,$BE,$BE
    db $B6,$B6,$B2,$B2,$B2,$B2,$00,$00
    db $E3,$E3,$D3,$D3,$D5,$D5,$D5,$D5
    db $D7,$D7,$D5,$D5,$E5,$E5,$00,$00
    db $30,$30,$30,$30,$B0,$B0,$B0,$B0
    db $B0,$B0,$B0,$B0,$B0,$B0,$00,$00
    db $F3,$F2,$F3,$D2,$E7,$24,$C7,$C7
    db $00,$00,$00,$00,$00,$00,$00,$00
    db $70,$70,$D8,$D8,$18,$18,$30,$30
    db $18,$18,$D8,$D8,$70,$70,$00,$00
    db $E0,$E0,$D0,$D0,$D3,$D3,$D6,$D6
    db $D6,$D6,$D6,$D6,$E3,$E3,$00,$00
    db $00,$00,$00,$00,$35,$35,$B5,$B5
    db $B4,$B4,$B5,$B5,$1D,$1D,$01,$01
    db $00,$00,$D0,$D0,$A0,$A0,$A0,$A0
    db $C0,$C0,$E0,$E0,$90,$90,$E0,$E0
    db $70,$70,$D8,$D8,$C3,$C3,$73,$73
    db $1B,$1B,$DB,$DB,$73,$73,$00,$00
    db $00,$00,$06,$06,$B1,$B1,$56,$56
    db $56,$56,$56,$56,$56,$56,$00,$00
    db $0C,$0C,$CC,$CC,$EE,$EE,$CD,$CD
    db $CD,$CD,$CD,$CD,$CD,$CD,$00,$00
    db $E0,$20,$E0,$20,$F0,$10,$F0,$F0
    db $00,$00,$00,$00,$00,$00,$00,$00
    db $03,$03,$03,$03,$05,$05,$05,$05
    db $07,$07,$08,$08,$08,$08,$00,$00
    db $1B,$1B,$1B,$1B,$9B,$9B,$9B,$9B
    db $9B,$9B,$DB,$DB,$DB,$DB,$00,$00
    db $06,$06,$00,$00,$56,$56,$76,$76
    db $66,$66,$66,$66,$66,$66,$00,$00
    db $03,$03,$6B,$6B,$D3,$D3,$D3,$D3
    db $63,$63,$F3,$F3,$CB,$CB,$F0,$F0
    db $00,$00,$0C,$0C,$9E,$9E,$4C,$4C
    db $4C,$4C,$4C,$4C,$4C,$4C,$00,$00
    db $00,$00,$00,$00,$70,$70,$C0,$C0
    db $F0,$F0,$30,$30,$E0,$E0,$00,$00
    db $00,$00,$00,$00,$53,$53,$76,$76
    db $67,$67,$66,$66,$63,$63,$00,$00
    db $00,$00,$00,$00,$0E,$0E,$98,$98
    db $9E,$9E,$06,$06,$9C,$9C,$00,$00
    db $00,$00,$00,$00,$65,$65,$D7,$D7
    db $F6,$F6,$C6,$C6,$76,$76,$00,$00
    db $00,$00,$00,$00,$64,$64,$65,$65
    db $65,$65,$29,$29,$10,$10,$00,$00
    db $03,$03,$03,$03,$C7,$C7,$AB,$AB
    db $EB,$EB,$8B,$8B,$E7,$E7,$00,$00
    db $00,$00,$C6,$C6,$C6,$C6,$C6,$C6
    db $C6,$C6,$C6,$C6,$C6,$C6,$F6,$F6
    db $00,$00,$C6,$C6,$AD,$AD,$AD,$AD
    db $AD,$AD,$AD,$AD,$AD,$AD,$C6,$C6
    db $00,$00,$77,$77,$D6,$D6,$C6,$C6
    db $C7,$C7,$C6,$C6,$D6,$D6,$77,$77
    db $00,$00,$00,$00,$00,$00,$00,$00
    db $30,$30,$30,$30,$10,$10,$20,$20
    db $00,$00,$00,$00,$32,$32,$6B,$6B
    db $7B,$7B,$63,$63,$3B,$3B,$00,$00
    db $30,$30,$30,$30,$B9,$B9,$B5,$B5
    db $35,$35,$35,$35,$39,$39,$00,$00
    db $00,$00,$00,$00,$AE,$AE,$AD,$AD
    db $AD,$AD,$AD,$AD,$CD,$CD,$00,$00
    db $18,$18,$18,$18,$38,$38,$58,$58
    db $58,$58,$58,$58,$3A,$3A,$00,$00
    db $FF,$00,$FF,$FE,$03,$FE,$03,$FE
    db $03,$FE,$03,$FE,$03,$FE,$FF,$FE
    db $FF,$00,$FF,$FF,$80,$FF,$80,$FF
    db $80,$FF,$80,$FF,$80,$FF,$FF,$FF
    db $FF,$00,$FF,$00,$E0,$3F,$C0,$20
    db $C0,$20,$C0,$20,$C0,$20,$C0,$20
    db $F7,$08,$F7,$0E,$33,$CE,$33,$0E
    db $33,$0E,$33,$0E,$33,$0E,$33,$0E
    db $F7,$08,$F7,$0F,$30,$CF,$30,$0F
    db $30,$0F,$30,$0F,$30,$0F,$37,$0F
    db $FF,$00,$FF,$00,$00,$FF,$00,$00
    db $00,$00,$00,$00,$00,$00,$00,$00
    db $F0,$08,$F0,$08,$30,$C8,$30,$08
    db $30,$08,$30,$08,$30,$08,$30,$08
    db $00,$00,$B2,$B2,$32,$32,$3A,$3A
    db $3E,$3E,$36,$36,$32,$32,$B2,$B2
    db $81,$00,$00,$C3,$0C,$FB,$FF,$FB
    db $FF,$00,$C0,$BF,$C0,$BF,$FF,$BF
    db $00,$00,$00,$81,$00,$C3,$FF,$FB
    db $FF,$00,$C0,$BF,$C0,$BF,$FF,$BF
    db $00,$00,$00,$00,$00,$80,$81,$81
    db $F3,$00,$C0,$BF,$C0,$BF,$FF,$BF
    db $00,$00,$00,$00,$00,$00,$80,$80
    db $81,$00,$C0,$A3,$C0,$BF,$FF,$BF
    db $00,$00,$00,$00,$00,$00,$00,$00
    db $00,$00,$80,$81,$C0,$A7,$FF,$BF
    db $FF,$00,$0C,$FB,$0C,$FB,$FF,$FB
    db $FF,$00,$C0,$BF,$C0,$BF,$FF,$BF
    db $FE,$01,$81,$7F,$81,$7F,$81,$7F
    db $81,$7F,$81,$7F,$81,$7F,$7F,$FF
    db $82,$41,$FE,$01,$82,$7D,$82,$41
    db $82,$41,$FE,$01,$82,$7D,$82,$41
    db $00,$00,$FF,$00,$00,$FF,$00,$00
    db $00,$00,$00,$00,$00,$00,$00,$00
    db $00,$00,$18,$08,$24,$1C,$74,$0C
    db $6A,$16,$FA,$0E,$B5,$4F,$EA,$17
    db $00,$00,$67,$67,$D6,$D6,$C6,$C6
    db $67,$67,$36,$36,$B6,$B6,$67,$67
    db $00,$00,$B8,$B8,$34,$34,$34,$34
    db $34,$34,$34,$34,$34,$34,$B8,$B8
    db $00,$00,$CB,$CB,$CB,$CB,$EB,$EB
    db $FB,$FB,$DB,$DB,$CB,$CB,$CB,$CB
    db $41,$C3,$01,$FF,$7D,$FF,$41,$C3
    db $41,$C3,$01,$FF,$7D,$FF,$41,$C3
    db $81,$00,$40,$C1,$40,$C3,$E3,$E3
    db $E7,$00,$E0,$A7,$E0,$A7,$E7,$A7
    db $00,$00,$3D,$3D,$C3,$FF,$87,$FD
    db $7E,$56,$79,$57,$7E,$46,$38,$38
    db $00,$00,$3C,$3C,$72,$4E,$FD,$83
    db $FD,$F3,$5F,$51,$7E,$4E,$3C,$3C
    db $3C,$3C,$7E,$42,$C3,$BD,$C3,$BD
    db $D3,$AD,$C3,$BD,$C3,$BD,$FF,$FF
    db $70,$70,$F8,$88,$F8,$A8,$FA,$8A
    db $7F,$65,$1E,$12,$0F,$09,$06,$06
    db $3C,$3C,$7E,$42,$C3,$85,$C3,$8D
    db $CB,$85,$C3,$8D,$C3,$8D,$FF,$FF
    db $3C,$3C,$7E,$42,$C3,$81,$C3,$81
    db $C3,$81,$C3,$81,$C3,$81,$FF,$FF
    db $7C,$7C,$CE,$CE,$C6,$C6,$C6,$C6
    db $C6,$C6,$E6,$E6,$7C,$7C,$00,$00
    db $30,$30,$70,$70,$30,$30,$30,$30
    db $30,$30,$30,$30,$FC,$FC,$00,$00
    db $7C,$7C,$C6,$C6,$06,$06,$0C,$0C
    db $38,$38,$60,$60,$FE,$FE,$00,$00
    db $7C,$7C,$C6,$C6,$06,$06,$3C,$3C
    db $06,$06,$C6,$C6,$7C,$7C,$00,$00
    db $3C,$3C,$6C,$6C,$CC,$CC,$8C,$8C
    db $FE,$FE,$0C,$0C,$0C,$0C,$00,$00
    db $FE,$FE,$80,$80,$FC,$FC,$06,$06
    db $06,$06,$C6,$C6,$7C,$7C,$00,$00
    db $7C,$7C,$C0,$C0,$C0,$C0,$FC,$FC
    db $C6,$C6,$C6,$C6,$7C,$7C,$00,$00
    db $FE,$FE,$C6,$C6,$0C,$0C,$0C,$0C
    db $18,$18,$18,$18,$18,$18,$00,$00
    db $7C,$7C,$C6,$C6,$C6,$C6,$7C,$7C
    db $C6,$C6,$C6,$C6,$7C,$7C,$00,$00
    db $7C,$7C,$C6,$C6,$C6,$C6,$7E,$7E
    db $06,$06,$0C,$0C,$78,$78,$00,$00
    db $38,$38,$6C,$6C,$C6,$C6,$C6,$C6
    db $FE,$FE,$C6,$C6,$C6,$C6,$00,$00
    db $FC,$FC,$C6,$C6,$C6,$C6,$FC,$FC
    db $C6,$C6,$C6,$C6,$FC,$FC,$00,$00
    db $7C,$7C,$E6,$E6,$C0,$C0,$C0,$C0
    db $C0,$C0,$E6,$E6,$7C,$7C,$00,$00
    db $FC,$FC,$CE,$CE,$C6,$C6,$C6,$C6
    db $C6,$C6,$CE,$CE,$FC,$FC,$00,$00
    db $FE,$FE,$C0,$C0,$C0,$C0,$FC,$FC
    db $C0,$C0,$C0,$C0,$FE,$FE,$00,$00
    db $FE,$FE,$C0,$C0,$C0,$C0,$FC,$FC
    db $C0,$C0,$C0,$C0,$C0,$C0,$00,$00
    db $7C,$7C,$EE,$EE,$C0,$C0,$DE,$DE
    db $C6,$C6,$E6,$E6,$7E,$7E,$00,$00
    db $C6,$C6,$C6,$C6,$C6,$C6,$FE,$FE
    db $C6,$C6,$C6,$C6,$C6,$C6,$00,$00
    db $FC,$FC,$30,$30,$30,$30,$30,$30
    db $30,$30,$30,$30,$FC,$FC,$00,$00
    db $7E,$7E,$18,$18,$18,$18,$18,$18
    db $18,$18,$98,$98,$F0,$F0,$00,$00
    db $C6,$C6,$CC,$CC,$D8,$D8,$F0,$F0
    db $D8,$D8,$CC,$CC,$C6,$C6,$00,$00
    db $C0,$C0,$C0,$C0,$C0,$C0,$C0,$C0
    db $C0,$C0,$C0,$C0,$FE,$FE,$00,$00
    db $C6,$C6,$EE,$EE,$FE,$FE,$D6,$D6
    db $C6,$C6,$C6,$C6,$C6,$C6,$00,$00
    db $C6,$C6,$E6,$E6,$F6,$F6,$FE,$FE
    db $DE,$DE,$CE,$CE,$C6,$C6,$00,$00
    db $7C,$7C,$EE,$EE,$C6,$C6,$C6,$C6
    db $C6,$C6,$EE,$EE,$7C,$7C,$00,$00
    db $FC,$FC,$C6,$C6,$C6,$C6,$FC,$FC
    db $C0,$C0,$C0,$C0,$C0,$C0,$00,$00
    db $7C,$7C,$C6,$C6,$C6,$C6,$C6,$C6
    db $CA,$CA,$E4,$E4,$7A,$7A,$00,$00
    db $FC,$FC,$C6,$C6,$C6,$C6,$DC,$DC
    db $D8,$D8,$CC,$CC,$C6,$C6,$00,$00
    db $7C,$7C,$C6,$C6,$C0,$C0,$7C,$7C
    db $06,$06,$C6,$C6,$7C,$7C,$00,$00
    db $7E,$7E,$18,$18,$18,$18,$18,$18
    db $18,$18,$18,$18,$18,$18,$00,$00
    db $C6,$C6,$C6,$C6,$C6,$C6,$C6,$C6
    db $C6,$C6,$EE,$EE,$7C,$7C,$00,$00
    db $C6,$C6,$C6,$C6,$C6,$C6,$C6,$C6
    db $6C,$6C,$38,$38,$10,$10,$00,$00
    db $C6,$C6,$C6,$C6,$C6,$C6,$D6,$D6
    db $D6,$D6,$6C,$6C,$6C,$6C,$00,$00
    db $C2,$C2,$E4,$E4,$78,$78,$38,$38
    db $3C,$3C,$4E,$4E,$86,$86,$00,$00
    db $CC,$CC,$CC,$CC,$CC,$CC,$78,$78
    db $30,$30,$30,$30,$30,$30,$00,$00
    db $FE,$FE,$0E,$0E,$1C,$1C,$38,$38
    db $70,$70,$E0,$E0,$FE,$FE,$00,$00
    db $00,$00,$38,$38,$44,$44,$BA,$BA
    db $A2,$A2,$BA,$BA,$44,$44,$38,$38
    db $00,$00,$00,$00,$00,$00,$FE,$FE
    db $00,$00,$00,$00,$00,$00,$00,$00
    db $00,$00,$00,$00,$00,$00,$00,$00
    db $00,$00,$60,$60,$60,$60,$00,$00
    db $00,$00,$65,$65,$64,$64,$74,$74
    db $7C,$7C,$6C,$6C,$64,$64,$64,$64
    db $00,$00,$EF,$EF,$CC,$CC,$CC,$CC
    db $CE,$CE,$CC,$CC,$CC,$CC,$CF,$CF
    db $00,$00,$65,$65,$65,$65,$75,$75
    db $7D,$7D,$6D,$6D,$65,$65,$65,$65
    db $00,$00,$E6,$E6,$D6,$D6,$D6,$D6
    db $E3,$E3,$D3,$D3,$D3,$D3,$E3,$E3
    db $18,$F7,$18,$F7,$18,$F7,$F7,$FF
    db $EF,$10,$18,$F7,$18,$F7,$18,$F7
    db $00,$00,$00,$00,$00,$00,$00,$00
    db $00,$00,$00,$00,$00,$00,$00,$00
    db $FF,$00,$FF,$00,$FF,$00,$FF,$00
    db $FF,$00,$FF,$00,$FF,$00,$FF,$00
    db $00,$FF,$00,$FF,$00,$FF,$00,$FF
    db $00,$FF,$00,$FF,$00,$FF,$00,$FF
    db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
    db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
    ; Tile bank data block copied to $C2C0 banks 0-4 by loc_0C4F loop ($0C4F: 5 rows x (0x28 copy + 0x08 copy per bank))
    db $FF,$00,$FF,$FF,$00,$FF,$00,$FF
    db $00,$FF,$FF,$FF,$FF,$00,$FF,$EF
    db $F0,$00,$F0,$D0,$70,$D0,$70,$D0
    db $70,$D0,$F0,$D0,$F0,$00,$F0,$F0
    db $38,$EF,$38,$EF,$38,$EF,$FF,$EF
    db $00,$F0,$00,$F0,$00,$F0,$F0,$F0
    db $FF,$00,$80,$7F,$80,$7F,$80,$7F
    db $80,$7F,$80,$7F,$80,$7F,$80,$7F
    db $E0,$10,$10,$F0,$10,$F0,$10,$F0
    db $10,$F0,$10,$F0,$10,$F0,$10,$F0
    db $80,$7F,$80,$7F,$80,$7F,$7F,$FF
    db $10,$F0,$10,$F0,$10,$F0,$F0,$F0
    db $80,$40,$80,$40,$FF,$00,$C0,$40
    db $80,$40,$80,$40,$80,$40,$80,$40
    db $20,$10,$20,$10,$E0,$10,$20,$10
    db $20,$10,$20,$10,$20,$10,$20,$10
    db $FF,$00,$C0,$40,$80,$40,$80,$40
    db $E0,$10,$20,$10,$20,$10,$20,$10
    db $00,$00,$FF,$00,$00,$FF,$00,$00
    db $00,$00,$00,$00,$00,$00,$00,$00
    db $00,$00,$F0,$00,$00,$F0,$00,$00
    db $00,$00,$00,$00,$00,$00,$00,$00
    db $00,$00,$00,$00,$00,$00,$00,$00
    db $00,$00,$00,$00,$00,$00,$00,$00
    db $00,$00,$06,$00,$0D,$03,$16,$09
    db $1F,$02,$3A,$05,$2D,$13,$7A,$05
    db $00,$00,$00,$00,$00,$00,$80,$80
    db $80,$80,$40,$C0,$40,$C0,$E0,$E0
    db $7C,$03,$6B,$15,$F9,$06,$D5,$2B
    db $20,$E0,$60,$E0,$B0,$F0,$50,$F0
    db $00,$00,$40,$40,$40,$40,$80,$80
    db $80,$80,$00,$00,$00,$00,$00,$00
    db $00,$00,$00,$00,$00,$00,$F0,$F0
    db $D0,$D0,$D0,$D0,$E0,$E0,$D0,$D0
    db $00,$00,$03,$03,$05,$05,$0B,$0B
    db $0B,$0B,$04,$04,$03,$03,$0F,$0F
    db $00,$00,$03,$03,$E2,$E2,$FE,$FE
    db $7F,$7F,$55,$55,$1F,$1F,$CB,$CB
    db $7F,$7F,$85,$85,$5F,$5F,$BF,$BF
    db $BF,$BF,$FF,$FF,$BF,$BF,$FF,$FF
    db $F0,$F0,$EE,$EE,$F1,$F1,$FE,$FE
    db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
    db $00,$00,$00,$00,$80,$80,$80,$80
    db $8F,$8F,$7F,$7F,$FE,$FF,$B6,$B6
    db $00,$00,$00,$00,$00,$00,$7C,$7C
    db $D2,$D2,$FA,$FA,$FA,$FA,$D3,$D3
    db $00,$00,$00,$00,$03,$03,$04,$04
    db $0F,$0D,$1A,$13,$24,$3F,$24,$3F
    db $37,$37,$D8,$DF,$60,$7F,$80,$FF
    db $00,$FF,$00,$FF,$00,$FF,$00,$FF
    db $B3,$F3,$0B,$FB,$0B,$FB,$17,$F7
    db $11,$F1,$17,$F7,$1F,$FF,$2F,$EF
    db $F6,$F6,$31,$31,$8E,$8F,$F0,$FF
    db $C0,$FF,$C0,$FF,$C0,$FF,$E0,$FF
    db $0C,$0C,$FF,$FF,$00,$FF,$00,$FF
    db $00,$FF,$00,$FF,$00,$FF,$00,$FF
    db $80,$80,$60,$60,$98,$98,$64,$E4
    db $14,$F4,$0A,$FA,$0A,$FA,$09,$F9
    db $00,$00,$00,$00,$00,$00,$01,$01
    db $02,$02,$04,$04,$08,$08,$11,$11
    db $00,$00,$00,$00,$00,$00,$80,$80
    db $60,$60,$10,$10,$98,$98,$C8,$C8
    db $28,$3F,$68,$7F,$68,$7F,$78,$7F
    db $74,$7F,$7C,$7F,$7F,$7F,$7F,$7F
    db $00,$FF,$3F,$FF,$13,$F3,$0B,$F8
    db $04,$FC,$02,$FE,$01,$FF,$C0,$FF
    db $30,$F0,$EF,$EF,$DF,$DF,$FC,$FC
    db $F8,$78,$78,$78,$30,$30,$B0,$B0
    db $3C,$3C,$DB,$DB,$E7,$E7,$7F,$7F
    db $1F,$1F,$1E,$1E,$1C,$1C,$1C,$1C
    db $17,$17,$FF,$FF,$FF,$FF,$FF,$FF
    db $83,$83,$01,$01,$00,$00,$00,$00
    db $E0,$FF,$E0,$FF,$FF,$FF,$7F,$7F
    db $FF,$FC,$BE,$B0,$F8,$E0,$F1,$E1
    db $00,$FF,$00,$FF,$F0,$FF,$90,$9F
    db $21,$3F,$46,$7E,$99,$F9,$E7,$E7
    db $11,$F1,$29,$E9,$51,$D1,$B9,$B9
    db $7D,$7D,$F9,$F9,$FD,$FD,$F9,$F9
    db $01,$01,$02,$02,$04,$04,$09,$09
    db $0E,$0E,$17,$17,$2F,$2F,$40,$40
    db $F7,$F7,$3E,$3E,$0F,$0F,$87,$87
    db $D7,$D7,$F3,$F3,$BA,$BA,$DA,$DA
    db $C8,$C8,$E4,$E4,$E7,$E7,$64,$64
    db $A7,$A7,$47,$47,$37,$37,$1F,$1F
    db $00,$00,$00,$00,$00,$00,$03,$03
    db $05,$05,$07,$07,$07,$07,$0B,$0B
    db $0F,$0F,$F0,$F0,$00,$00,$E8,$E8
    db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
    db $BF,$BF,$3F,$3F,$1F,$1F,$1F,$1F
    db $9F,$9F,$EF,$EF,$EF,$EF,$F7,$F7
    db $F8,$F8,$1C,$FC,$3F,$FF,$BF,$FF
    db $BF,$FF,$B1,$F1,$B2,$F2,$B6,$F6
    db $3C,$3C,$7E,$7E,$E7,$E7,$E1,$E1
    db $C0,$C0,$C1,$C1,$87,$87,$99,$99
    db $00,$00,$01,$01,$07,$07,$FF,$FF
    db $FF,$FF,$F3,$F3,$12,$12,$1A,$1A
    db $E6,$E6,$CB,$CB,$B7,$B7,$F7,$F7
    db $F7,$F7,$F7,$F7,$F7,$F7,$F7,$F7
    db $FC,$FC,$F8,$F8,$FD,$FD,$FC,$FC
    db $F8,$F8,$F9,$F9,$F3,$F3,$F7,$F7
    db $FE,$FE,$83,$83,$00,$00,$1F,$1F
    db $7F,$7F,$FF,$FF,$FF,$FF,$FF,$FF
    db $B6,$F6,$DC,$FC,$FA,$FA,$FD,$FD
    db $EE,$FE,$FF,$FF,$F7,$FF,$FF,$FF
    db $00,$00,$F8,$F8,$07,$07,$F8,$F8
    db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
    db $46,$46,$BF,$BF,$17,$17,$89,$89
    db $82,$82,$DD,$DD,$EE,$EE,$F6,$F6
    db $6A,$6A,$33,$33,$BF,$BF,$BF,$BF
    db $77,$77,$FF,$FF,$F7,$F7,$E4,$E4
    db $E7,$E7,$F0,$F0,$E9,$E9,$FD,$FD
    db $EF,$EF,$C0,$C0,$1F,$1F,$7F,$7F
    db $1F,$1F,$E3,$E3,$F8,$F8,$FD,$FD
    db $F3,$F3,$0F,$0F,$FF,$FF,$FF,$FF
    db $F9,$89,$FF,$07,$FF,$07,$FF,$0F
    db $FF,$1F,$FF,$3F,$FF,$7F,$FF,$FF
    db $BD,$FD,$F9,$F9,$D9,$F9,$EE,$FE
    db $FF,$F7,$EF,$F3,$EF,$F9,$DF,$F6
    db $61,$61,$22,$22,$52,$52,$CC,$CC
    db $87,$87,$FF,$FF,$FF,$FC,$FF,$03
    db $25,$25,$A3,$A3,$AF,$AF,$7F,$7E
    db $FF,$EC,$FF,$98,$FC,$68,$E8,$E8
    db $FF,$01,$FF,$03,$FF,$07,$FF,$0F
    db $FF,$1F,$FF,$3F,$FF,$7F,$FF,$FF
    db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
    db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
    db $FC,$FC,$F8,$F8,$FB,$FB,$F7,$F7
    db $F7,$F7,$F7,$F7,$F6,$F6,$F6,$F6
    db $1C,$1C,$10,$10,$17,$17,$AF,$AF
    db $AF,$AF,$5F,$5F,$DF,$DF,$DC,$DC
    db $3F,$3F,$1F,$1F,$11,$11,$40,$40
    db $A0,$A0,$6C,$6C,$5E,$5E,$DD,$DD
    db $EF,$EF,$DF,$DF,$3F,$3F,$FF,$FF
    db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
    db $DF,$F7,$A9,$E8,$AB,$E9,$53,$D3
    db $53,$D3,$72,$F2,$6B,$EB,$BA,$FA
    db $E8,$E8,$E8,$E8,$D1,$D1,$D1,$D1
    db $D1,$D1,$A1,$A1,$A1,$A1,$F1,$D1
    db $FF,$FF,$FC,$FC,$F0,$F0,$83,$83
    db $C7,$C7,$F7,$F7,$F9,$F9,$FE,$FE
    db $F1,$F1,$1C,$1C,$07,$07,$EF,$EF
    db $F7,$F7,$FF,$FF,$E0,$E0,$0F,$0F
    db $D3,$D3,$CF,$CF,$FF,$FF,$FF,$FF
    db $FF,$FF,$FB,$FB,$79,$79,$C0,$C0
    db $FF,$FF,$FF,$FF,$FE,$FE,$EE,$EE
    db $DE,$DE,$DC,$DC,$DC,$DC,$D8,$D8
    db $B8,$B8,$B1,$B1,$B3,$B3,$77,$77
    db $65,$65,$AD,$AD,$B9,$B9,$A1,$A1
    db $FF,$FF,$EF,$EF,$E7,$E7,$C7,$C7
    db $C7,$C7,$C2,$C2,$82,$82,$00,$00
    db $FE,$FE,$F3,$F3,$CF,$CC,$3F,$30
    db $FF,$C0,$FF,$80,$FF,$00,$FF,$00
    db $FB,$FB,$FB,$FB,$FB,$FB,$FF,$FF
    db $FF,$FF,$F7,$F7,$F7,$F7,$F7,$F7
    db $31,$31,$90,$90,$90,$90,$80,$80
    db $80,$80,$10,$10,$00,$00,$00,$00
    db $73,$73,$31,$31,$11,$11,$00,$00
    db $10,$10,$10,$10,$08,$08,$08,$08
    db $DD,$DD,$DB,$DB,$C6,$C6,$FD,$FD
    db $FB,$FB,$FB,$FB,$F8,$F8,$FF,$FF
    db $3F,$3F,$3F,$20,$1F,$11,$1F,$11
    db $3E,$22,$3F,$23,$3F,$20,$3F,$23
    db $BF,$BF,$BF,$A0,$1F,$11,$1F,$11
    db $3E,$22,$FE,$E2,$FE,$02,$FE,$E2
    db $80,$80,$80,$80,$00,$00,$00,$00
    db $FE,$FE,$FE,$82,$7C,$44,$3E,$22
    db $00,$00,$00,$00,$00,$00,$00,$00
    db $FB,$FB,$FB,$8A,$71,$51,$E3,$A2
    db $00,$00,$00,$00,$00,$00,$00,$00
    db $DE,$DE,$FF,$21,$FF,$00,$FF,$18
    db $00,$00,$00,$00,$00,$00,$00,$00
    db $07,$07,$0F,$08,$9F,$91,$BF,$A0
    db $00,$00,$00,$00,$00,$00,$00,$00
    db $F3,$F3,$FB,$0A,$F9,$C9,$F9,$19
    db $00,$00,$00,$00,$00,$00,$00,$00
    db $EF,$EF,$FF,$11,$FF,$03,$FE,$1E
    db $7C,$44,$7C,$44,$FE,$82,$FE,$FE
    db $00,$00,$00,$00,$00,$00,$00,$00
    db $1F,$11,$0F,$08,$07,$05,$0E,$0A
    db $7C,$74,$F8,$88,$F0,$90,$60,$60
    db $C3,$42,$83,$82,$07,$04,$07,$04
    db $07,$04,$0F,$08,$1F,$10,$1F,$1F
    db $FF,$30,$FF,$01,$FE,$3E,$C0,$40
    db $C0,$40,$C0,$40,$E0,$20,$E0,$E0
    db $BF,$A3,$3F,$21,$1F,$10,$0F,$0F
    db $00,$00,$00,$00,$00,$00,$00,$00
    db $00,$00,$00,$00,$3F,$3F,$3F,$20
    db $1F,$10,$1F,$10,$1F,$10,$1F,$10
    db $00,$00,$00,$00,$C0,$C0,$E0,$20
    db $E0,$20,$E0,$20,$E0,$20,$E0,$20
    db $3F,$20,$3F,$20,$3F,$20,$3F,$20
    db $3F,$20,$7F,$40,$7F,$40,$7F,$40
    db $C0,$40,$C0,$40,$C0,$40,$C0,$40
    db $C0,$40,$81,$81,$81,$81,$81,$81
    db $3F,$3F,$7F,$40,$FF,$80,$FF,$80
    db $FF,$84,$FF,$08,$FF,$08,$FF,$08
    db $83,$83,$C7,$44,$EF,$28,$EF,$28
    db $EF,$28,$FF,$30,$DF,$50,$DF,$50
    db $FF,$E0,$FF,$00,$FF,$00,$FF,$00
    db $FF,$20,$FF,$40,$FF,$40,$FF,$40
    db $C7,$47,$CF,$48,$DF,$50,$DF,$50
    db $DF,$50,$BF,$A0,$BF,$A0,$BF,$A0
    db $F8,$F8,$FC,$04,$FE,$02,$FE,$02
    db $FE,$C2,$FE,$82,$FC,$04,$FC,$04
    db $7F,$40,$7F,$40,$FF,$80,$FF,$80
    db $FF,$80,$FF,$80,$FF,$80,$7F,$7F
    db $81,$81,$9B,$9A,$FB,$EA,$FB,$0A
    db $FB,$0A,$FB,$0A,$F9,$09,$F0,$F0
    db $FF,$08,$FF,$08,$FF,$10,$FF,$00
    db $FF,$00,$FF,$00,$FF,$01,$FE,$FE
    db $DF,$50,$DF,$50,$FF,$60,$BF,$A0
    db $BF,$A0,$BF,$A0,$1F,$10,$0F,$0F
    db $FF,$40,$FF,$40,$FF,$81,$FF,$81
    db $FF,$01,$FF,$01,$FF,$80,$7F,$7F
    db $BF,$A1,$BF,$A1,$7F,$40,$7F,$40
    db $7F,$40,$7F,$40,$BF,$A0,$9F,$9F
    db $FC,$FC,$18,$18,$F8,$E8,$F8,$08
    db $F8,$08,$F8,$08,$F0,$10,$E0,$E0
    db $00,$00,$00,$00,$FC,$FC,$FF,$03
    db $FF,$00,$FF,$00,$FF,$C0,$BF,$A0
    db $00,$00,$00,$00,$00,$00,$00,$00
    db $80,$80,$80,$80,$80,$80,$80,$80
    db $BF,$A0,$BF,$A0,$FF,$C0,$FF,$01
    db $FF,$01,$FE,$02,$FC,$0C,$F8,$08
    db $BF,$BF,$BF,$A0,$9F,$90,$1F,$10
    db $1F,$10,$3F,$20,$3F,$20,$3F,$20
    db $7E,$7E,$FF,$81,$FF,$41,$FF,$41
    db $FF,$41,$FE,$82,$FE,$82,$FE,$82
    db $FE,$FE,$FF,$81,$7F,$40,$7F,$40
    db $7F,$40,$FF,$82,$FF,$82,$FF,$82
    db $FB,$FB,$FF,$06,$FD,$05,$FD,$05
    db $FD,$05,$FB,$0A,$FB,$0A,$FB,$0A
    db $FB,$FB,$FF,$04,$FF,$00,$FF,$00
    db $FF,$00,$FF,$08,$FF,$08,$FF,$08
    db $E1,$E1,$F3,$12,$F7,$14,$F7,$14
    db $F7,$14,$EF,$28,$EF,$28,$EF,$28
    db $FE,$FE,$FF,$01,$FF,$00,$FF,$00
    db $FF,$30,$FF,$20,$FF,$01,$FF,$01
    db $7F,$7F,$7F,$40,$BF,$A0,$BF,$A0
    db $BF,$A0,$FF,$C1,$7F,$41,$7F,$41
    db $7C,$7C,$FC,$84,$FC,$04,$F8,$08
    db $F8,$08,$F0,$F0,$00,$00,$00,$00
    db $7F,$41,$7F,$41,$FE,$82,$FE,$82
    db $FE,$82,$FE,$82,$FF,$81,$7F,$7F
    db $FC,$04,$FC,$04,$FF,$83,$FF,$81
    db $FF,$81,$7F,$41,$7F,$41,$3E,$3E
    db $3F,$20,$3F,$20,$7F,$41,$7F,$40
    db $7F,$40,$7F,$40,$7F,$41,$3E,$3E
    db $FE,$82,$FE,$82,$FD,$05,$FD,$05
    db $FD,$05,$FD,$05,$FF,$03,$FE,$FE
    db $FF,$82,$FF,$82,$FF,$04,$FF,$04
    db $FF,$04,$FF,$04,$FF,$02,$FF,$FF
    db $FB,$0A,$FB,$0A,$F7,$14,$F7,$14
    db $F7,$14,$F7,$14,$FB,$0A,$FB,$FB
    db $FF,$08,$FF,$08,$FF,$10,$FF,$10
    db $FF,$10,$FF,$10,$FF,$08,$FF,$FF
    ; 0xFF fill / ROM padding through end ($7FFF)
    db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
    db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
    db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
    db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
    db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
    db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
    db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
    db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
    db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
    db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
    db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
    db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
    db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
    db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
    db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
    db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
    db $FF,$FF,$FF,$FF,$FF,$FF
