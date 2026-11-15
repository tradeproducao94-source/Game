; Gerado por gen.py - não edite

FR_HERO_SIDE = 0

FR_HERO_UP = 1

FR_HERO_DOWN = 2

FR_HERO_CLOSED = 3

FR_BUG_A = 4

FR_BUG_B = 5

FR_BUG_SCARED = 6

FR_BLANK = 7

FrameLo
    .byte <GFX_HERO_SIDE,<GFX_HERO_UP,<GFX_HERO_DOWN,<GFX_HERO_CLOSED,<GFX_BUG_A,<GFX_BUG_B,<GFX_BUG_SCARED

FrameHi
    .byte >GFX_HERO_SIDE,>GFX_HERO_UP,>GFX_HERO_DOWN,>GFX_HERO_CLOSED,>GFX_BUG_A,>GFX_BUG_B,>GFX_BUG_SCARED

SCInit
    .byte $F0,$50,$D0,$50,$D0,$50,$F0,$F0,$F0,$00,$F0,$F0,$F0,$50,$D0,$50,$70,$50,$D0,$50,$F0
    .byte $FF,$AA,$EF,$AA,$EE,$AE,$EF,$EE,$EE,$08,$EE,$EE,$EE,$AA,$EF,$EA,$EE,$AE,$FF,$AA,$FF
    .byte $FF,$D5,$D7,$55,$FF,$F5,$E7,$00,$FE,$06,$FE,$00,$FE,$D5,$D7,$55,$FF,$55,$F7,$55,$FF
    .byte $F0,$B0,$B0,$B0,$F0,$F0,$70,$00,$F0,$00,$F0,$00,$F0,$B0,$B0,$A0,$F0,$B0,$F0,$B0,$F0
    .byte $FF,$55,$7F,$55,$F7,$57,$7F,$07,$E7,$61,$E7,$07,$E7,$55,$7F,$55,$F7,$57,$7F,$55,$FF
    .byte $FF,$AA,$BE,$AA,$BE,$AA,$FE,$FE,$FE,$00,$FE,$FE,$FE,$AA,$BE,$AE,$EE,$AA,$BF,$AA,$FF

PELLETS_TOTAL = 167

PelOff
    .byte $FF,$00,$15,$15,$15,$15,$2A,$2A,$2A,$2A,$3F,$3F,$3F,$54,$54,$54,$54,$69,$69,$69

PelMask
    .byte $00,$40,$80,$20,$08,$02,$01,$04,$10,$40,$10,$20,$80,$40,$10,$04,$01,$02,$08,$20

PowC
    .byte 1,19,1,19

PowR
    .byte 2,2,15,15

PowIdx
    .byte 2,107,15,120

PowMask
    .byte $40,$20,$40,$20

WalkTbl
    .byte $00,$FE,$12,$FE,$52,$DE,$10,$D0,$50,$7F,$50,$D0,$50,$FE,$12,$F6,$54,$DE,$02,$FE,$00
    .byte $00,$FB,$1B,$FF,$40,$71,$11,$7F,$40,$C0,$40,$7F,$40,$FB,$1B,$FF,$40,$7F,$11,$FF,$00
    .byte $00,$0F,$09,$0F,$09,$0F,$01,$01,$01,$0F,$01,$01,$01,$0F,$09,$0D,$05,$0F,$08,$0F,$00

HERO_START_X = 76
HERO_START_Y = 120

Digits
    .byte $EE,$AA,$AA,$AA,$EE,$44,$CC,$44,$44,$EE
    .byte $EE,$22,$EE,$88,$EE,$EE,$22,$66,$22,$EE
    .byte $AA,$AA,$EE,$22,$22,$EE,$88,$EE,$22,$EE
    .byte $EE,$88,$EE,$AA,$EE,$EE,$22,$44,$44,$44
    .byte $EE,$AA,$EE,$AA,$EE,$EE,$AA,$EE,$22,$EE
    .byte $AA,$EE,$EE,$EE,$AA,$AA,$AA,$EE,$AA,$AA
    .byte $44,$AA,$EE,$AA,$AA,$EE,$88,$88,$88,$EE

DigitsR
    .byte $77,$55,$55,$55,$77,$22,$33,$22,$22,$77
    .byte $77,$44,$77,$11,$77,$77,$44,$66,$44,$77
    .byte $55,$55,$77,$44,$44,$77,$11,$77,$44,$77
    .byte $77,$11,$77,$55,$77,$77,$44,$22,$22,$22
    .byte $77,$55,$77,$55,$77,$77,$55,$77,$44,$77
    .byte $55,$77,$77,$77,$55,$55,$55,$77,$55,$55
    .byte $22,$55,$77,$55,$55,$77,$11,$11,$11,$77
