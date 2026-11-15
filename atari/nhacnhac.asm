; =====================================================================
;  NHAC-NHAC  -  jogo de labirinto para Atari 2600 (4 KB, NTSC)
;  Monte com:  dasm nhacnhac.asm -f3 -onhacnhac.a26
;
;  Joystick: mover    Botão / RESET: começar
;  Coma todas as pastilhas e fuja dos besouros. A bolinha piscante deixa
;  os besouros azuis por alguns segundos: aí dá para comê-los.
; =====================================================================
    processor 6502

; ---- TIA (escrita) ----
VSYNC   = $00
VBLANK  = $01
WSYNC   = $02
NUSIZ0  = $04
NUSIZ1  = $05
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
RESBL   = $14
AUDC0   = $15
AUDC1   = $16
AUDF0   = $17
AUDF1   = $18
AUDV0   = $19
AUDV1   = $1A
GRP0    = $1B
GRP1    = $1C
ENABL   = $1F
HMP0    = $20
HMP1    = $21
HMBL    = $24
HMOVE   = $2A
HMCLR   = $2B
CXCLR   = $2C
; ---- TIA (leitura) ----
INPT4   = $0C
; ---- RIOT ----
SWCHA   = $0280
SWCHB   = $0282
INTIM   = $0284
TIM64T  = $0296

; ---- Direções (mesmo formato do joystick invertido) ----
D_UP    = 1
D_DOWN  = 2
D_LEFT  = 4
D_RIGHT = 8

; ---- Estados ----
ST_TITLE = 0
ST_PLAY  = 1
ST_DYING = 2
ST_CLEAR = 3
ST_OVER  = 4

HERO_START_X = 80
HERO_START_Y = 68       ; corredor 8 (de baixo)

; =====================================================================
;  RAM ($80-$FF)
; =====================================================================
    SEG.U vars
    ORG $80
pellets ds 36           ; 4 blocos de 9 corredores: PF1 esq, PF2 esq, PF1 dir, PF2 dir
LP1L = pellets
LP2L = pellets+9
LP1R = pellets+18
LP2R = pellets+27
sc1     ds 5            ; placar já montado para o kernel
sc2     ds 5
sc3     ds 5
p0a     ds 2            ; ponteiros dos sprites (linhas pares / ímpares)
p0b     ds 2
p1a     ds 2
p1b     ds 2
hx      ds 1            ; herói
hy      ds 1
hdir    ds 1
hwant   ds 1
hmoving ds 1
ex      ds 2            ; besouros
ey      ds 2
edir    ds 2
ewait   ds 2            ; >0: esperando na toca
eacc    ds 2            ; acumulador de velocidade
frame   ds 1
state   ds 1
timer   ds 1
score   ds 2            ; BCD: score = milhar/centena, score+1 = dezena/unidade
lives   ds 1
level   ds 1            ; BCD
left    ds 1            ; pastilhas restantes
fright  ds 1            ; quadros de besouro assustado
ballLane ds 1           ; $FF = sem bolinha
ballX   ds 1
ballT   ds 1
bdisp   ds 1            ; corredor onde a bolinha aparece neste quadro
rnd     ds 1
snd0    ds 1
snd1    ds 1
snd1t   ds 1
combo   ds 1
lastfire ds 1
shown   ds 1            ; besouro desenhado neste quadro
wallcolor ds 1
pelcolor ds 1
order   ds 4            ; ordem de direções a tentar (besouros)
cabs    ds 2
tmp     ds 4

; =====================================================================
;  ROM
; =====================================================================
    SEG code
    ORG $F000

; ---- Faixa de PAREDE (8 linhas). X = índice da parede ----
WallBand:
    SUBROUTINE
    lda WPF0,x
    sta PF0
WallA:
    sta WSYNC
    lda WPF1L,x         ; 4
    sta PF1             ; 7
    lda WPF2L,x         ; 11
    sta PF2             ; 14
    lda (p0a),y         ; 19+
    sta GRP0            ; 22
    lda (p1a),y         ; 27+
    sta GRP1            ; 30
    nop                 ; 32
    nop                 ; 34
    nop                 ; 36
    nop                 ; 38
    lda WPF1R,x         ; 42
    sta PF1             ; 45
    lda WPF2R,x         ; 49
    sta PF2             ; 52
    sta WSYNC
    lda WPF1L,x
    sta PF1
    lda WPF2L,x
    sta PF2
    lda (p0b),y
    sta GRP0
    lda (p1b),y
    sta GRP1            ; 30
    dey                 ; 32
    nop                 ; 34
    nop                 ; 36
    nop                 ; 38
    lda WPF1R,x         ; 42
    sta PF1             ; 45
    lda WPF2R,x         ; 49
    sta PF2             ; 52
    tya                 ; 54
    and #3              ; 56
    bne WallA           ; 59
    cpx #9              ; 60
    bne LaneBand        ; 63
    jmp MazeDone
; ---- Faixa de CORREDOR (8 linhas). X = índice do corredor ----
LaneBand:
    SUBROUTINE
    lda #0
    sta PF0
    sta WSYNC
    ; linha 0
    lda #0
    sta PF1
    sta PF2
    lda (p0a),y
    sta GRP0
    lda (p1a),y
    sta GRP1
    sta WSYNC
    ; linha 1
    lda (p0b),y
    sta GRP0
    lda (p1b),y
    sta GRP1
    dey
    lda pelcolor
    sta COLUPF
    lda #0
    cpx bdisp
    bne .nob
    lda #2
.nob:
    sta ENABL
    sta WSYNC
    ; linha 2
    lda (p0a),y
    sta GRP0
    lda (p1a),y
    sta GRP1
    sta WSYNC
    ; linha 3 (pastilhas)
    lda LP1L,x          ; 4
    sta PF1             ; 7
    lda LP2L,x          ; 11
    sta PF2             ; 14
    lda (p0b),y         ; 19+
    sta GRP0            ; 22
    lda (p1b),y         ; 27+
    sta GRP1            ; 30
    dey                 ; 32
    nop                 ; 34
    nop                 ; 36
    nop                 ; 38
    lda LP1R,x          ; 42
    sta PF1             ; 45
    lda LP2R,x          ; 49
    sta PF2             ; 52
    sta WSYNC
    ; linha 4 (pastilhas)
    lda LP1L,x
    sta PF1
    lda LP2L,x
    sta PF2
    lda (p0a),y
    sta GRP0
    lda (p1a),y
    sta GRP1            ; 30
    nop
    nop
    nop
    nop                 ; 38
    lda LP1R,x          ; 42
    sta PF1             ; 45
    lda LP2R,x          ; 49
    sta PF2             ; 52
    lda #0              ; 54
    nop                 ; 56
    nop                 ; 58
    nop                 ; 60
    nop                 ; 62
    nop                 ; 64
    nop                 ; 66
    sta PF1             ; 69 (depois do fim do PF1 direito)
    sta WSYNC
    ; linha 5
    lda #0
    sta PF2
    lda (p0b),y
    sta GRP0
    lda (p1b),y
    sta GRP1
    dey
    sta WSYNC
    ; linha 6
    lda (p0a),y
    sta GRP0
    lda (p1a),y
    sta GRP1
    lda #0
    sta ENABL
    lda wallcolor
    sta COLUPF
    sta WSYNC
    ; linha 7
    lda (p0b),y
    sta GRP0
    lda (p1b),y
    sta GRP1
    dey
    inx
    jsr Wait12
    jsr Wait12
    jmp WallBand


    MAC SLEEP2
    nop
    ENDM

Reset:
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
    jsr ResetPellets
    jsr ResetPositions
    lda #ST_TITLE
    sta state
    lda #1
    sta lastfire

; ---------------------------------------------------------------------
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

.waitvb:
    lda INTIM
    bne .waitvb
    sta WSYNC
    lda #0
    sta VBLANK

    jsr Kernel

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
;  KERNEL (192 linhas visíveis)
; =====================================================================
Kernel:
    SUBROUTINE
    ; 8 linhas vazias
    ldx #8
.top:
    sta WSYNC
    dex
    bne .top

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
    sta WSYNC               ; linha 19
    lda #0
    sta PF1
    sta PF2
    lda wallcolor
    sta COLUPF
    lda #$30                ; bolinha de 8 px, sem espelhar o playfield
    sta CTRLPF
    sta WSYNC               ; 20
    sta WSYNC               ; 21
    sta WSYNC               ; 22
    ldx #0
    ldy #76
    jsr Wait12              ; escreve o PF0 da 1a parede só depois do meio da linha
    jsr Wait12
    jsr Wait12
    jsr Wait12
    jmp WallBand

MazeDone:
    SUBROUTINE
    sta WSYNC               ; fim da última linha do labirinto (174)
    lda #0
    sta PF0
    sta PF1
    sta PF2
    sta GRP0
    sta GRP1
    sta ENABL
    sta WSYNC               ; 175
    sta WSYNC               ; 176
    sta WSYNC               ; 177
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
    sta WSYNC               ; 182
    lda #0
    sta PF1
    ldx #10
.bot:
    sta WSYNC
    dex
    bne .bot                ; 191
    rts

Wait12:
    SUBROUTINE
    rts                     ; jsr+rts = 12 ciclos

; =====================================================================
;  Preparação do quadro (no VBLANK)
; =====================================================================
PrepareFrame:
    SUBROUTINE
    ; ---- herói ----
    ldx #FR_HERO_CLOSED
    lda hmoving
    beq .hclosed
    lda frame
    and #8
    beq .hclosed
    ldx #FR_HERO_SIDE
    lda hdir
    cmp #D_UP
    bne .h1
    ldx #FR_HERO_UP
.h1:
    cmp #D_DOWN
    bne .hclosed
    ldx #FR_HERO_DOWN
.hclosed:
    lda state
    cmp #ST_DYING
    bne .hnotdying
    lda timer               ; pisca enquanto morre
    and #4
    beq .hnotdying
    ldx #FR_BLANK
.hnotdying:
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

    ; ---- besouro deste quadro (alterna para mostrar os dois) ----
    lda frame
    and #1
    tay
    sty shown
    lda EnemyColor,y
    sta tmp
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
    sta tmp
    lda fright
    cmp #90
    bcs .enorm
    lda frame
    and #8
    beq .enorm
    lda #$0E
    sta tmp
.enorm:
    lda ewait,y             ; na toca: pisca
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
    ldy shown
    lda ey,y
    ldy #4
    jsr SetPtrs
    lda tmp
    sta COLUP1
    lda #$CA
    sta COLUP0

    ; ---- posições horizontais ----
    lda hx
    ldx #0
    jsr PosObject
    ldy shown
    lda ex,y
    ldx #1
    jsr PosObject
    lda ballX
    ldx #4
    jsr PosObject
    sta WSYNC
    sta HMOVE

    ; ---- bolinha ----
    lda #$FF
    ldx ballLane
    bmi .nb
    lda frame
    and #8
    beq .nb2
    txa
    .byte $2C               ; pula o próximo lda #$FF
.nb2:
    lda #$FF
.nb:
    sta bdisp

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
    ldx #10                 ; N H A C
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
    lda #10                 ; fase no lado direito (sc3)
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
    sta wallcolor
    lda #$1C
    sta pelcolor
    lda #0
    sta COLUBK
    rts

; Monta 5 bytes de PF1 com os glifos X (esq.) e Y (dir.) em sc1+tmp+3
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

; Monta sc2 (PF2 esquerdo, bits invertidos) com os glifos X e Y
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

; X = quadro, A = y, Y = 0 (herói) ou 4 (besouro)
SetPtrs:
    SUBROUTINE
    cpx #FR_BLANK
    bne .norm
    lda #<BlankE
    sta p0a,y
    lda #>BlankE
    sta p0a+1,y
    lda #<BlankO
    sta p0b,y
    lda #>BlankO
    sta p0b+1,y
    rts
.norm:
    sta tmp+1
    lda FrameELo,x
    clc
    adc tmp+1
    sta p0a,y
    lda FrameEHi,x
    adc #0
    sta p0a+1,y
    lda FrameOLo,x
    clc
    adc tmp+1
    sta p0b,y
    lda FrameOHi,x
    adc #0
    sta p0b+1,y
    rts

; A = posição x (0-159), X = objeto (0=P0, 1=P1, 4=BL)
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
;  Lógica (no overscan)
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

    ; botão: fire ou RESET (só conta quando acabou de apertar)
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
.st:
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
    ; título ou fim de jogo: espera o botão
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
    ldx #1
    jsr EnemyUpdate
    jsr Collide
    jsr BallUpdate
    lda fright
    beq .nofr
    dec fright
.nofr:
    lda left
    bne .notclear
    lda #ST_CLEAR
    sta state
    lda #120
    sta timer
    lda #3
    sta snd1t
    lda #60
    sta snd1
.notclear:
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
    ldx #8
.rp:
    lda PelFull
    sta LP1L,x
    lda PelFull+1
    sta LP2L,x
    lda PelFull+2
    sta LP1R,x
    lda PelFull+3
    sta LP2R,x
    dex
    bpl .rp
    lda #PELLETS_TOTAL
    sta left
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
    lda #0
    sta hmoving
    sta fright
    sta eacc
    sta eacc+1
    lda #80
    sta ex
    sta ex+1
    lda #4                  ; corredor 0
    sta ey
    lda #36                 ; corredor 4
    sta ey+1
    lda #D_LEFT
    sta edir
    lda #D_RIGHT
    sta edir+1
    lda #30
    sta ewait
    lda #150
    sta ewait+1
    lda #$FF
    sta ballLane
    lda #200
    sta ballT
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
    ; tenta as direções desejadas (cima, baixo, esquerda, direita)
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

; Entrada: tmp=x, tmp+1=y, A=direção. Saída: C=1 se pode andar. Preserva X.
CanMove:
    SUBROUTINE
    sta tmp+2
    txa
    pha
    lda tmp+1
    clc
    adc #4
    and #7
    tax                     ; X = 0 se alinhado num corredor
    lda tmp+2
    and #D_LEFT|D_RIGHT
    beq .vert
    txa
    bne .no
.yes:
    pla
    tax
    sec
    rts
.vert:
    lda tmp
    and #7
    bne .no
    txa
    bne .yes                ; no meio da passagem: pode seguir
    lda tmp+1
    sec
    sbc #4
    lsr
    lsr
    lsr                     ; corredor k
    tay
    lda tmp+2
    and #D_DOWN
    beq .up
    iny                     ; parede de baixo = k+1
.up:
    sty tmp+3
    lda tmp
    lsr
    lsr
    lsr                     ; casa s
    pha
    lsr
    lsr
    lsr                     ; grupo 0..2
    tax
    lda Mul10,x
    clc
    adc tmp+3
    tay
    pla
    and #7
    tax
    lda GapTbl,y
    and BitMask,x
    beq .no
    jmp .yes
.no:
    pla
    tax
    clc
    rts

; Aplica um passo na direção A sobre tmp/tmp+1
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
    lda hx
    and #7
    bne .ne
    lda hy
    clc
    adc #4
    and #7
    bne .ne
    lda hy
    sec
    sbc #4
    lsr
    lsr
    lsr
    sta tmp                 ; corredor
    lda hx
    lsr
    lsr
    lsr
    tay                     ; casa
    lda PelOff,y
    bmi .ne
    clc
    adc tmp
    tax
    lda PelMask,y
    and pellets,x
    beq .ne
    lda PelMask,y
    eor #$FF
    and pellets,x
    sta pellets,x
    dec left
    lda #1
    jsr AddScore
    lda #5
    sta snd0
.ne:
    rts

; Soma A (BCD) ao placar
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

; ---- besouros (X = 0 ou 1) ----
EnemyUpdate:
    SUBROUTINE
    lda ewait,x
    beq .act
    dec ewait,x
    rts
.act:
    lda fright
    beq .spd
    lda #130
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
    ; ponto de decisão?
    lda tmp
    and #7
    bne .cont
    lda tmp+1
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

; Escolhe a direção do besouro X: persegue o herói (ou foge quando assustado).
; Entrada: tmp/tmp+1 = posição do besouro.
ChooseDir:
    SUBROUTINE
    lda ex,x
    lsr
    sta tmp+2
    lda hx
    lsr
    sec
    sbc tmp+2               ; dx/2 (com sinal)
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
    lda hy
    sec
    sbc ey,x                ; dy (com sinal)
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
    lda fright              ; assustado: inverte as preferências (foge)
    beq .nf
    ldy order
    lda Opp,y
    sta order
    ldy order+1
    lda Opp,y
    sta order+1
.nf:
    lda cabs                ; a maior distância vem primeiro
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
    ; o segundo besouro às vezes vagueia
    cpx #1
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
    cmp Opp,y               ; nunca dá meia-volta por escolha
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
    ldy edir,x              ; beco: dá meia-volta
    lda Opp,y
    sta edir,x
    rts

; ---- colisões herói x besouros ----
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
    cmp #3
    bcs .next
    lda fright
    beq .die
    ; come o besouro
    lda #$20
    jsr AddScore
    lda #80
    sta ex,x
    lda #36
    sta ey,x
    lda #D_LEFT
    sta edir,x
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

; ---- bolinha de poder ----
BallUpdate:
    SUBROUTINE
    lda ballLane
    bpl .active
    dec ballT
    bne .r
    lda rnd                 ; aparece num corredor e casa sorteados
    and #7
    sta ballLane
    lda rnd
    lsr
    lsr
    lsr
    and #15
    tay
    lda BallSlotX,y
    sta ballX
    lda #255
    sta ballT
.r:
    rts
.active:
    dec ballT
    bne .chk
    lda #$FF
    sta ballLane
    lda #220
    sta ballT
    rts
.chk:
    lda hy
    sec
    sbc #4
    sta tmp
    and #7
    bne .r
    lda tmp
    lsr
    lsr
    lsr
    cmp ballLane
    bne .r
    lda hx
    sec
    sbc ballX
    bcs .b1
    eor #$FF
    adc #1
.b1:
    cmp #6
    bcs .r
    ; pegou!
    lda #$FF
    sta ballLane
    lda #230
    sta ballT
    lda level
    and #$0F
    cmp #7
    bcc .b2
    lda #7
.b2:
    tay
    lda FrightTime,y
    sta fright
    lda #$05
    jsr AddScore
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
    lda #12                 ; morte: som descendo
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
    lda #4                  ; comeu besouro: subindo
    sta AUDC1
    lda snd1
    sta AUDF1
    rts
.t5:
    cpx #5
    bne .tune
    lda #4                  ; bolinha
    sta AUDC1
    lda snd1
    lsr
    sta AUDF1
    rts
.tune:
    lda #4                  ; musiquinha (início / fase completa)
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

; =====================================================================
;  Tabelas
; =====================================================================
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
Mul10:
    SUBROUTINE
    .byte 0, 10, 20
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
LivesPF:
    SUBROUTINE
    .byte %00000000, %11000000, %11011000, %11011011
BallSlotX:
    SUBROUTINE
    .byte 16, 24, 32, 40, 48, 56, 64, 72, 96, 104, 112, 120, 128, 136, 144, 152
Tune:
    SUBROUTINE
    .byte 31, 23, 19, 15, 19, 23, 15, 12

    include "data.inc"

    ORG $FFFA
    .word Reset
    .word Reset
    .word Reset
