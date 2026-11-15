; =====================================================================
;  NHAC-NHAC  -  Atari 2600 (NTSC), cartucho F8SC: 8 KB + 128 bytes de RAM
;  Mesmo labirinto da versão LÖVE (21 x 21 casas).
;  Monte com:  python3 gen.py && dasm nhacnhac.asm -f3 -onhacnhac.a26
;
;  Joystick: mover    Botão / RESET: começar
; =====================================================================
    processor 6502

VSYNC   = $00
VBLANK  = $01
WSYNC   = $02
COLUP0  = $06
COLUP1  = $07
COLUPF  = $08
COLUBK  = $09
CTRLPF  = $0A
REFP0   = $0B
REFP1   = $0C
PF0     = $0D
PF1     = $0E
PF2     = $0F
RESP0   = $10
RESP1   = $11
AUDC0   = $15
AUDC1   = $16
AUDF0   = $17
AUDF1   = $18
AUDV0   = $19
AUDV1   = $1A
GRP0    = $1B
GRP1    = $1C
HMP0    = $20
HMP1    = $21
HMOVE   = $2A
INPT4   = $0C
SWCHA   = $0280
SWCHB   = $0282
INTIM   = $0284
TIM64T  = $0296

SCW     = $F000         ; RAM extra: escrita
SCR     = $F080         ; RAM extra: leitura
BANK0   = $FFF8
BANK1   = $FFF9

D_UP    = 1
D_DOWN  = 2
D_LEFT  = 4
D_RIGHT = 8

ST_TITLE = 0
ST_PLAY  = 1
ST_DYING = 2
ST_CLEAR = 3
ST_OVER  = 4

LINES    = 168          ; 21 fileiras x 8 linhas
HOME_X   = 76           ; coluna 10
EXIT_Y   = 56           ; fileira 7 (em cima da toca)
HOUSE_Y  = 72           ; fileira 9 (dentro da toca)
KBOTTOM  = 3            ; linhas vazias no fim da tela

; =====================================================================
;  RAM principal
; =====================================================================
    SEG.U vars
    ORG $80
buf     ds 6            ; linha de pastilhas da fileira atual (kernel)
sc1     ds 5            ; placar montado
sc2     ds 5
sc3     ds 5
p0      ds 2            ; ponteiro do herói
p1      ds 2            ; ponteiro do besouro
hx      ds 1
hy      ds 1
hdir    ds 1
hwant   ds 1
hmoving ds 1
ex      ds 2
ey      ds 2
edir    ds 2
ewait   ds 2
eacc    ds 2
frame   ds 1
state   ds 1
timer   ds 1
score   ds 2
lives   ds 1
level   ds 1
left    ds 1
fright  ds 1
rnd     ds 1
snd0    ds 1
snd1    ds 1
snd1t   ds 1
lastfire ds 1
shown   ds 1
powEaten ds 1
wallcolor ds 1
order   ds 4
cabs    ds 2
tmp     ds 4

; =====================================================================
;  BANCO 0: kernel e gráficos
; =====================================================================
    SEG bank0
    ORG $0000
    RORG $F000
    ds 256, 0               ; janela da RAM extra

Kernel:
    SUBROUTINE
    ldx #4
.top:
    sta WSYNC
    dex
    bne .top
    lda #0
    sta CTRLPF
    sta PF0
    ; ---- placar: 5 fileiras x 2 linhas ----
.score:
    sta WSYNC
    lda sc1,x
    sta PF1
    lda sc2,x
    sta PF2
    jsr Wait12
    jsr Wait12
    nop
    lda sc3,x
    sta PF1
    lda #0
    sta PF2
    sta WSYNC
    lda sc1,x
    sta PF1
    lda sc2,x
    sta PF2
    jsr Wait12
    jsr Wait12
    nop
    lda sc3,x
    sta PF1
    lda #0
    sta PF2
    inx
    cpx #5
    bne .score
    sta WSYNC
    lda #0
    sta PF1
    sta PF2
    lda wallcolor
    sta COLUPF
    lda #1                  ; playfield espelhado (paredes)
    sta CTRLPF
    ldx #0
    ldy #LINES

; ---- uma fileira do labirinto = 8 linhas. X = fileira, Y = linha ----
RowLoop:
    SUBROUTINE
    ; linha 0: paredes da fileira (espelhadas)
    sta WSYNC
    lda WallPF0,x
    sta PF0
    lda WallPF1,x
    sta PF1
    lda WallPF2,x
    sta PF2
    lda (p0),y
    sta GRP0
    lda (p1),y
    sta GRP1
    dey
    ; linha 1: prepara as pastilhas (metade 1)
    sta WSYNC
    lda (p0),y
    sta GRP0
    lda (p1),y
    sta GRP1
    lda SCR,x
    sta buf
    lda SCR+21,x
    sta buf+1
    lda SCR+42,x
    sta buf+2
    dey
    ; linha 2: prepara as pastilhas (metade 2)
    sta WSYNC
    lda (p0),y
    sta GRP0
    lda (p1),y
    sta GRP1
    lda SCR+63,x
    sta buf+3
    lda SCR+84,x
    sta buf+4
    lda SCR+105,x
    sta buf+5
    dey
    ; linha 3: paredes + pastilhas (playfield assimétrico)
    sta WSYNC
    lda #0              ; 2
    sta CTRLPF          ; 5
    lda buf             ; 8
    sta PF0             ; 11
    lda buf+1           ; 14
    sta PF1             ; 17
    lda buf+2           ; 20
    sta PF2             ; 23
    lda (p0),y          ; 28+
    sta GRP0            ; 31
    lda (p1),y          ; 36+
    sta GRP1            ; 39
    lda buf+3           ; 42
    sta PF0             ; 45
    lda buf+4           ; 48
    sta PF1             ; 51
    lda buf+5           ; 54
    sta PF2             ; 57
    dey
    ; linha 4: igual à 3
    sta WSYNC
    lda #0
    sta CTRLPF
    lda buf
    sta PF0
    lda buf+1
    sta PF1
    lda buf+2
    sta PF2
    lda (p0),y
    sta GRP0
    lda (p1),y
    sta GRP1
    lda buf+3
    sta PF0
    lda buf+4
    sta PF1
    lda buf+5
    sta PF2
    dey
    ; linha 5: volta às paredes espelhadas
    sta WSYNC
    lda #1
    sta CTRLPF
    lda WallPF0,x
    sta PF0
    lda WallPF1,x
    sta PF1
    lda WallPF2,x
    sta PF2
    lda (p0),y
    sta GRP0
    lda (p1),y
    sta GRP1
    dey
    ; linha 6
    sta WSYNC
    lda (p0),y
    sta GRP0
    lda (p1),y
    sta GRP1
    dey
    ; linha 7
    sta WSYNC
    lda (p0),y
    sta GRP0
    lda (p1),y
    sta GRP1
    dey
    inx
    cpx #21
    beq MazeDone
    jmp RowLoop

MazeDone:
    SUBROUTINE
    sta WSYNC
    lda #0
    sta PF0
    sta PF1
    sta PF2
    sta GRP0
    sta GRP1
    sta CTRLPF
    sta WSYNC
    ; vidas: 4 linhas
    ldy lives
    cpy #4
    bcc .lv
    ldy #3
.lv:
    ldx #4
.lives:
    sta WSYNC
    lda LivesPF,y
    sta PF1
    jsr Wait12
    jsr Wait12
    nop
    nop
    nop
    nop
    nop
    lda #0
    sta PF1
    dex
    bne .lives
    sta WSYNC
    lda #0
    sta PF1
    ldx #KBOTTOM
.bot:
    sta WSYNC
    dex
    bne .bot
    rts

Wait12:
    SUBROUTINE
    rts

LivesPF:
    SUBROUTINE
    .byte %00000000, %11000000, %11011000, %11011011

    include "data0.inc"

; ---- trampolim: o banco 1 lê BANK0 em $FFC0 e continua aqui em $FFC3 ----
    ORG $0FC0
    RORG $FFC0
    lda BANK0
    jsr Kernel              ; $FFC3
    lda BANK1               ; $FFC6 -> continua no banco 1 em $FFC9
    rts

    ORG $0FE0
    RORG $FFE0
Start0:
    SUBROUTINE
    lda BANK1               ; -> banco 1, que continua em $FFE3
    jmp Start0

    ORG $0FFA
    RORG $FFFA
    .word Start0
    .word Start0
    .word Start0

; =====================================================================
;  BANCO 1: lógica do jogo
; =====================================================================
    SEG bank1
    ORG $1000
    RORG $F000
    ds 256, 0

Start:
    SUBROUTINE
    sei
    cld
    ldx #0
    txa
.clr:
    dex
    txs
    pha
    bne .clr
    lda #$5A
    sta rnd
    lda #1
    sta lastfire
    jsr ResetPellets
    jsr ResetPositions
    lda #ST_TITLE
    sta state

MainLoop:
    SUBROUTINE
    lda #2
    sta WSYNC
    sta VSYNC
    sta WSYNC
    sta WSYNC
    lda #0
    sta WSYNC
    sta VSYNC
    lda #2
    sta VBLANK
    lda #44
    sta TIM64T
    jsr PrepareFrame
    jsr VBLogic
.waitvb:
    lda INTIM
    bne .waitvb
    sta WSYNC
    lda #0
    sta VBLANK
    jsr CallKernel
    lda #2
    sta VBLANK
    lda #34
    sta TIM64T
    jsr GameUpdate
    jsr Sound
.waitos:
    lda INTIM
    bne .waitos
    jmp MainLoop

; =====================================================================
;  Preparação do quadro
; =====================================================================
PrepareFrame:
    SUBROUTINE
    ; ---- herói ----
    ldx #FR_HERO_CLOSED
    lda hmoving
    beq .hsel
    lda frame
    and #8
    beq .hsel
    ldx #FR_HERO_SIDE
    lda hdir
    cmp #D_UP
    bne .h1
    ldx #FR_HERO_UP
.h1:
    cmp #D_DOWN
    bne .hsel
    ldx #FR_HERO_DOWN
.hsel:
    lda state
    cmp #ST_DYING
    bne .hok
    lda timer
    and #4
    beq .hok
    ldx #FR_BLANK
.hok:
    lda #0
    ldy hdir
    cpy #D_LEFT
    bne .hr
    lda #8
.hr:
    sta REFP0
    lda hy
    ldy #0
    jsr SetPtrs

    ; ---- besouro deste quadro (alternando) ----
    lda frame
    and #1
    tay
    sty shown
    lda EnemyColor,y
    sta tmp+3
    ldx #FR_BUG_A
    lda frame
    and #8
    beq .eb
    ldx #FR_BUG_B
.eb:
    lda fright
    beq .enorm
    lda ewait,y
    bne .enorm
    ldx #FR_BUG_SCARED
    lda #$86
    sta tmp+3
    lda fright
    cmp #90
    bcs .enorm
    lda frame
    and #8
    beq .enorm
    lda #$0E
    sta tmp+3
.enorm:
    lda ewait,y
    beq .eshow
    lda frame
    and #2
    beq .eshow
    ldx #FR_BLANK
.eshow:
    lda state
    cmp #ST_DYING
    bne .eok
    ldx #FR_BLANK
.eok:
    lda ey,y
    ldy #2
    jsr SetPtrs
    lda tmp+3
    sta COLUP1
    lda #$CA
    sta COLUP0

    ; ---- posições ----
    lda hx
    ldx #0
    jsr PosObject
    ldy shown
    lda ex,y
    ldx #1
    jsr PosObject
    sta WSYNC
    sta HMOVE

    ; ---- placar / título ----
    lda state
    cmp #ST_TITLE
    bne .digits
    lda frame
    and #32
    bne .title
    lda #0
    ldx #14
.clrsc:
    sta sc1,x
    dex
    bpl .clrsc
    jmp .colors
.title:
    lda #0
    sta tmp+3
    ldx #10
    ldy #11
    jsr Pair1
    ldx #12
    ldy #13
    jsr Pair2
    lda #0
    ldx #4
.ct:
    sta sc3,x
    dex
    bpl .ct
    jmp .colors
.digits:
    lda #0
    sta tmp+3
    lda score
    lsr
    lsr
    lsr
    lsr
    tax
    lda score
    and #$0F
    tay
    jsr Pair1
    lda score+1
    lsr
    lsr
    lsr
    lsr
    tax
    lda score+1
    and #$0F
    tay
    jsr Pair2
    lda #10
    sta tmp+3
    lda level
    lsr
    lsr
    lsr
    lsr
    tax
    lda level
    and #$0F
    tay
    jsr Pair1
.colors:
    lda #$0E
    ldx state
    cpx #ST_TITLE
    bne .c1
    lda #$CA
.c1:
    sta COLUPF
    lda level
    and #3
    tax
    lda WallColors,x
    ldy state
    cpy #ST_CLEAR
    bne .c2
    lda timer               ; fase completa: labirinto pisca
    and #8
    beq .c2a
    lda #$0E
    bne .c2
.c2a:
    lda WallColors,x
.c2:
    sta wallcolor
    lda #0
    sta COLUBK
    rts

; X = quadro, A = y, Y = 0 (herói) ou 2 (besouro)
SetPtrs:
    SUBROUTINE
    cpx #FR_BLANK
    bne .norm
    lda #<GFX_BLANK
    sta p0,y
    lda #>GFX_BLANK
    sta p0+1,y
    rts
.norm:
    clc
    adc FrameLo,x
    sta p0,y
    lda FrameHi,x
    adc #0
    sta p0+1,y
    rts

; 5 bytes de PF1 com os glifos X (esq.) e Y (dir.) em sc1+tmp+3
Pair1:
    SUBROUTINE
    lda Mul5,x
    tax
    lda Mul5,y
    tay
    lda tmp+3
    sta tmp+2
.p1:
    lda Digits,x
    and #$F0
    sta tmp
    lda Digits,y
    and #$0F
    ora tmp
    sty tmp+1
    ldy tmp+2
    sta sc1,y
    ldy tmp+1
    inx
    iny
    inc tmp+2
    lda tmp+2
    sec
    sbc tmp+3
    cmp #5
    bne .p1
    rts

; 5 bytes de PF2 (bits invertidos) com os glifos X e Y em sc2
Pair2:
    SUBROUTINE
    lda Mul5,x
    tax
    lda Mul5,y
    tay
    lda #0
    sta tmp+2
.p2:
    lda DigitsR,x
    and #$0F
    sta tmp
    lda DigitsR,y
    and #$F0
    ora tmp
    sty tmp+1
    ldy tmp+2
    sta sc2,y
    ldy tmp+1
    inx
    iny
    inc tmp+2
    lda tmp+2
    cmp #5
    bne .p2
    rts

; A = x (0-159), X = objeto (0 = P0, 1 = P1)
PosObject:
    SUBROUTINE
    sta WSYNC
    sec
.div:
    sbc #15
    bcs .div
    eor #7
    asl
    asl
    asl
    asl
    sta HMP0,x
    sta RESP0,x
    rts

; =====================================================================
;  Lógica
; =====================================================================
GameUpdate:
    SUBROUTINE
    inc frame
    lda rnd
    lsr
    bcc .r1
    eor #$B4
.r1:
    sta rnd
    ; botão (fire ou RESET), só na hora que aperta
    lda #0
    sta tmp+3
    ldx #0
    lda INPT4
    bmi .nf
    ldx #1
.nf:
    lda SWCHB
    lsr
    bcs .nr
    ldx #1
.nr:
    txa
    beq .rel
    lda lastfire
    bne .rel
    lda #1
    sta tmp+3
.rel:
    stx lastfire
    lda state
    cmp #ST_PLAY
    beq UpdPlay
    cmp #ST_DYING
    bne .s3
    jmp UpdDying
.s3:
    cmp #ST_CLEAR
    bne .s4
    jmp UpdClear
.s4:
    lda tmp+3
    beq .idle
    jmp StartGame
.idle:
    rts

UpdPlay:
    SUBROUTINE
    jsr HeroMove
    jsr EatPellet
    ldx #0
    jsr EnemyUpdate
    jsr Collide
    jsr PowerBlink
    lda fright
    beq .nofr
    dec fright
.nofr:
    lda left
    bne .nc
    lda #ST_CLEAR
    sta state
    lda #120
    sta timer
    lda #3
    sta snd1t
    lda #60
    sta snd1
.nc:
    rts

; segundo besouro: calculado no VBLANK, onde sobra tempo
VBLogic:
    SUBROUTINE
    lda state
    cmp #ST_PLAY
    bne .x
    ldx #1
    jsr EnemyUpdate
    jsr Collide
.x:
    rts

UpdDying:
    SUBROUTINE
    dec timer
    bne .d1
    sed
    sec
    lda lives
    sbc #1
    sta lives
    cld
    bne .again
    lda #ST_OVER
    sta state
    rts
.again:
    jsr ResetPositions
    lda #ST_PLAY
    sta state
.d1:
    rts

UpdClear:
    SUBROUTINE
    dec timer
    bne .c1
    sed
    clc
    lda level
    adc #1
    sta level
    cld
    jsr ResetPellets
    jsr ResetPositions
    lda #ST_PLAY
    sta state
.c1:
    rts

StartGame:
    SUBROUTINE
    lda #0
    sta score
    sta score+1
    lda #3
    sta lives
    lda #1
    sta level
    jsr ResetPellets
    jsr ResetPositions
    lda #ST_PLAY
    sta state
    lda #4
    sta snd1t
    lda #40
    sta snd1
    rts

ResetPellets:
    SUBROUTINE
    ldx #125
.rp:
    lda SCInit,x
    sta SCW,x
    dex
    bpl .rp
    lda #PELLETS_TOTAL
    sta left
    lda #0
    sta powEaten
    rts

ResetPositions:
    SUBROUTINE
    lda #HERO_START_X
    sta hx
    lda #HERO_START_Y
    sta hy
    lda #D_LEFT
    sta hdir
    sta hwant
    sta edir
    lda #D_RIGHT
    sta edir+1
    lda #0
    sta hmoving
    sta fright
    sta eacc
    sta eacc+1
    sta ewait
    lda #HOME_X
    sta ex
    sta ex+1
    lda #EXIT_Y
    sta ey
    lda #HOUSE_Y
    sta ey+1
    lda #180
    sta ewait+1
    rts

; ---- herói ----
HeroMove:
    SUBROUTINE
    lda SWCHA
    eor #$FF
    lsr
    lsr
    lsr
    lsr
    beq .nojoy
    sta hwant
.nojoy:
    lda hx
    sta tmp
    lda hy
    sta tmp+1
    ldy #0
.try:
    lda DirList,y
    and hwant
    beq .next
    sty cabs
    jsr CanMove
    ldy cabs
    bcc .next
    lda DirList,y
    sta hdir
    jmp .go
.next:
    iny
    cpy #4
    bne .try
.go:
    lda #0
    sta hmoving
    lda hdir
    jsr CanMove
    bcc .stop
    inc hmoving
    lda hdir
    jsr Step
    lda tmp
    sta hx
    lda tmp+1
    sta hy
.stop:
    rts

; tmp = x, tmp+1 = y, A = direção  ->  C = 1 se pode andar. Preserva X.
CanMove:
    SUBROUTINE
    sta tmp+2
    txa
    pha
    lda tmp
    clc
    adc #4
    cmp #160
    bcc .w
    sbc #160
.w:
    sta tmp+3               ; x + 4 (alinhado quando múltiplo de 8)
    lda tmp+2
    and #D_LEFT|D_RIGHT
    beq .vert
    lda tmp+1
    and #7
    bne .no                 ; fora de uma fileira: não anda na horizontal
    lda tmp+3
    and #7
    bne .yes                ; no meio da casa: continua
    lda tmp+3
    lsr
    lsr
    lsr
    ldy tmp+2
    cpy #D_LEFT
    bne .right
    sec
    sbc #1
    bcs .cok
    lda #19
    bne .cok
.right:
    clc
    adc #1
    cmp #20
    bcc .cok
    lda #0
.cok:
    sta tmp+3
    lda tmp+1
    lsr
    lsr
    lsr
    jmp .check
.vert:
    lda tmp+3
    and #7
    bne .no
    lda tmp+1
    and #7
    bne .yes
    lda tmp+3
    lsr
    lsr
    lsr
    sta tmp+3
    lda tmp+1
    lsr
    lsr
    lsr
    ldy tmp+2
    cpy #D_UP
    bne .down
    sec
    sbc #1
    jmp .check
.down:
    clc
    adc #1
.check:                     ; A = fileira, tmp+3 = coluna
    sta tmp+2
    lda tmp+3
    lsr
    lsr
    lsr
    tax
    lda Mul21,x
    clc
    adc tmp+2
    tay
    lda tmp+3
    and #7
    tax
    lda WalkTbl,y
    and BitMask,x
    beq .no
.yes:
    pla
    tax
    sec
    rts
.no:
    pla
    tax
    clc
    rts

Step:
    SUBROUTINE
    cmp #D_UP
    bne .s1
    dec tmp+1
    rts
.s1:
    cmp #D_DOWN
    bne .s2
    inc tmp+1
    rts
.s2:
    cmp #D_LEFT
    bne .s3
    lda tmp
    bne .s21
    lda #160
.s21:
    sec
    sbc #1
    sta tmp
    rts
.s3:
    lda tmp
    clc
    adc #1
    cmp #160
    bcc .s31
    lda #0
.s31:
    sta tmp
    rts

EatPellet:
    SUBROUTINE
    lda hy
    and #7
    beq .e0
    rts
.e0:
    lda hx
    clc
    adc #4
    cmp #160
    bcc .e1
    sbc #160
.e1:
    tay
    and #7
    beq .e2
    rts
.e2:
    tya
    lsr
    lsr
    lsr
    bne .e3
    rts                     ; túnel
.e3:
    sta tmp                 ; coluna
    lda hy
    lsr
    lsr
    lsr
    sta tmp+1               ; fileira
    ; pastilha energética?
    ldx #3
.pw:
    lda PowC,x
    cmp tmp
    bne .pn
    lda PowR,x
    cmp tmp+1
    bne .pn
    lda powEaten
    and BitMask,x
    bne .done
    lda powEaten
    ora BitMask,x
    sta powEaten
    ldy PowIdx,x
    lda PowMask,x
    eor #$FF
    and SCR,y
    sta SCW,y
    dec left
    lda #$05
    jsr AddScore
    jmp Frighten
.pn:
    dex
    bpl .pw
    ; pastilha comum
    ldy tmp
    lda PelOff,y
    clc
    adc tmp+1
    tax
    lda PelMask,y
    and SCR,x
    beq .done
    lda PelMask,y
    eor #$FF
    and SCR,x
    sta SCW,x
    dec left
    lda #1
    jsr AddScore
    lda #5
    sta snd0
.done:
    rts

Frighten:
    SUBROUTINE
    lda level
    and #$0F
    cmp #7
    bcc .f1
    lda #7
.f1:
    tay
    lda FrightTime,y
    sta fright
    lda #5
    sta snd1t
    lda #30
    sta snd1
    ldx #1
.rev:
    lda ewait,x
    bne .rv
    ldy edir,x
    lda Opp,y
    sta edir,x
.rv:
    dex
    bpl .rev
    rts

; pastilhas energéticas piscam
PowerBlink:
    SUBROUTINE
    lda frame
    and #15
    bne .pb
    ldx #3
.pl:
    lda powEaten
    and BitMask,x
    bne .pk
    ldy PowIdx,x
    lda SCR,y
    eor PowMask,x
    sta SCW,y
.pk:
    dex
    bpl .pl
.pb:
    rts

AddScore:
    SUBROUTINE
    sed
    clc
    adc score+1
    sta score+1
    lda score
    adc #0
    sta score
    cld
    rts

; ---- besouros ----
EnemyUpdate:
    SUBROUTINE
    lda ewait,x
    beq .act
    dec ewait,x
    bne .w
    lda #HOME_X             ; sai da toca
    sta ex,x
    lda #EXIT_Y
    sta ey,x
    lda #D_LEFT
    sta edir,x
.w:
    rts
.act:
    lda fright
    beq .spd
    lda #120
    bne .acc
.spd:
    lda level
    and #$0F
    cmp #7
    bcc .sp1
    lda #7
.sp1:
    tay
    lda EnemySpeed,y
.acc:
    clc
    adc eacc,x
    sta eacc,x
    bcc .done
    lda ex,x
    sta tmp
    lda ey,x
    sta tmp+1
    lda ey,x
    and #7
    bne .cont
    lda ex,x
    clc
    adc #4
    and #7
    bne .cont
    jsr ChooseDir
.cont:
    lda edir,x
    jsr CanMove
    bcs .mv
    jsr ChooseDir
    lda edir,x
    jsr CanMove
    bcc .done
.mv:
    lda edir,x
    jsr Step
    lda tmp
    sta ex,x
    lda tmp+1
    sta ey,x
.done:
    rts

; persegue o herói (ou foge, se assustado). tmp/tmp+1 = posição do besouro
ChooseDir:
    SUBROUTINE
    lda ex,x
    lsr
    sta tmp+2
    lda hx
    lsr
    sec
    sbc tmp+2
    ldy #D_RIGHT
    cmp #$80
    bcc .h
    ldy #D_LEFT
    eor #$FF
    clc
    adc #1
.h:
    sty order
    sta cabs
    lda ey,x
    lsr
    sta tmp+2
    lda hy
    lsr
    sec
    sbc tmp+2
    ldy #D_DOWN
    cmp #$80
    bcc .v
    ldy #D_UP
    eor #$FF
    clc
    adc #1
.v:
    sty order+1
    sta cabs+1
    lda fright
    beq .nf
    ldy order
    lda Opp,y
    sta order
    ldy order+1
    lda Opp,y
    sta order+1
.nf:
    lda cabs
    cmp cabs+1
    bcs .hf
    lda order
    ldy order+1
    sta order+1
    sty order
.hf:
    ldy order+1
    lda Opp,y
    sta order+2
    ldy order
    lda Opp,y
    sta order+3
    cpx #1                  ; o segundo besouro às vezes vagueia
    bne .pick
    lda rnd
    cmp #60
    bcs .pick
    and #3
    tay
    lda DirList,y
    sta order
    lda DirList+1,y
    sta order+1
    lda DirList+2,y
    sta order+2
    lda DirList+3,y
    sta order+3
.pick:
    lda #0
    sta cabs
.loop:
    ldy cabs
    lda order,y
    sta cabs+1
    ldy edir,x
    cmp Opp,y
    beq .skip
    lda cabs+1
    jsr CanMove
    bcc .skip
    lda cabs+1
    sta edir,x
    rts
.skip:
    inc cabs
    lda cabs
    cmp #4
    bne .loop
    ldy edir,x
    lda Opp,y
    sta edir,x
    rts

Collide:
    SUBROUTINE
    ldx #1
.c:
    lda ewait,x
    bne .next
    lda hx
    sec
    sbc ex,x
    bcs .c1
    eor #$FF
    adc #1
.c1:
    cmp #6
    bcs .next
    lda hy
    sec
    sbc ey,x
    bcs .c2
    eor #$FF
    adc #1
.c2:
    cmp #6
    bcs .next
    lda fright
    beq .die
    lda #$20
    jsr AddScore
    lda #HOME_X
    sta ex,x
    lda #HOUSE_Y
    sta ey,x
    lda #150
    sta ewait,x
    lda #2
    sta snd1t
    lda #24
    sta snd1
.next:
    dex
    bpl .c
    rts
.die:
    lda #ST_DYING
    sta state
    lda #100
    sta timer
    lda #1
    sta snd1t
    lda #90
    sta snd1
    rts

; ---- sons ----
Sound:
    SUBROUTINE
    lda snd0
    beq .off0
    dec snd0
    lda #4
    sta AUDC0
    lda snd0
    asl
    asl
    adc #8
    sta AUDF0
    lda #5
    sta AUDV0
    jmp .ch1
.off0:
    lda #0
    sta AUDV0
.ch1:
    lda snd1
    beq .off1
    dec snd1
    lda #8
    sta AUDV1
    ldx snd1t
    cpx #1
    bne .t2
    lda #12
    sta AUDC1
    lda #92
    sec
    sbc snd1
    lsr
    lsr
    sta AUDF1
    rts
.t2:
    cpx #2
    bne .t5
    lda #4
    sta AUDC1
    lda snd1
    sta AUDF1
    rts
.t5:
    cpx #5
    bne .tune
    lda #4
    sta AUDC1
    lda snd1
    lsr
    sta AUDF1
    rts
.tune:
    lda #4
    sta AUDC1
    lda snd1
    lsr
    lsr
    lsr
    and #7
    tay
    lda Tune,y
    sta AUDF1
    rts
.off1:
    lda #0
    sta AUDV1
    rts

; ---- tabelas ----
DirList:
    SUBROUTINE
    .byte D_UP, D_DOWN, D_LEFT, D_RIGHT, D_UP, D_DOWN, D_LEFT, D_RIGHT
Opp:
    SUBROUTINE
    .byte 0, D_DOWN, D_UP, 0, D_RIGHT, 0, 0, 0, D_LEFT
BitMask:
    SUBROUTINE
    .byte 1, 2, 4, 8, 16, 32, 64, 128
Mul5:
    SUBROUTINE
    .byte 0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60, 65
Mul21:
    SUBROUTINE
    .byte 0, 21, 42
EnemyColor:
    SUBROUTINE
    .byte $46, $5A
EnemySpeed:
    SUBROUTINE
    .byte 190, 190, 205, 215, 225, 235, 242, 248
FrightTime:
    SUBROUTINE
    .byte 240, 240, 210, 180, 150, 130, 110, 90
WallColors:
    SUBROUTINE
    .byte $24, $84, $54, $C4
Tune:
    SUBROUTINE
    .byte 31, 23, 19, 15, 19, 23, 15, 12

    include "data1.inc"

; ---- trampolim para o kernel (banco 0) ----
    ORG $1FC0
    RORG $FFC0
CallKernel:
    SUBROUTINE
    lda BANK0               ; -> banco 0, que executa jsr Kernel / lda BANK1
    nop
    nop
    nop
    nop
    nop
    nop
    rts                     ; $FFC9 (de volta no banco 1)

    ORG $1FE0
    RORG $FFE0
Start1:
    SUBROUTINE
    lda BANK1
    jmp Start

    ORG $1FFA
    RORG $FFFA
    .word Start1
    .word Start1
    .word Start1
