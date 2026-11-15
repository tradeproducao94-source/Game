#!/usr/bin/env python3
"""Gera data.inc (labirinto, sprites e dígitos) para o Nhac-Nhac de Atari 2600.

Tela do labirinto: 40 colunas de playfield (4 px cada). Cada "casa" do jogo
ocupa 2 colunas (8 px, a largura de um sprite), então há 20 casas por linha.
Faixas horizontais alternam entre PAREDES (10) e CORREDORES (9). Os corredores
são abertos de ponta a ponta (com passagem pelas bordas); as paredes têm
aberturas de 1 casa que ligam um corredor ao outro.
"""
import os

HERE = os.path.dirname(os.path.abspath(__file__))

# Aberturas das paredes 1..8 na metade esquerda (casas 2..9). A metade direita é
# o espelho (casa s <-> 21-s). Casas 0,1,10,11 são sempre parede.
GAPS_LEFT = {
    1: [3, 7],
    2: [2, 5, 9],
    3: [4, 8],
    4: [2, 6, 9],
    5: [3, 7],
    6: [2, 5, 9],
    7: [4, 8],
    8: [2, 6, 9],
}


def wall_slots(j):
    slots = ["#"] * 20
    for s in GAPS_LEFT.get(j, []):
        slots[s] = "."
        slots[21 - s] = "."
    return slots


def pf_bytes(slots):
    cols = []
    for s in slots:
        cols += [1 if s == "#" else 0] * 2
    def pf0(c):  # bits 4..7, coluna esquerda = bit 4
        return sum(cols[c + i] << (4 + i) for i in range(4))
    def pf1(c):  # bit 7 = coluna esquerda
        return sum(cols[c + i] << (7 - i) for i in range(8))
    def pf2(c):  # bit 0 = coluna esquerda
        return sum(cols[c + i] << i for i in range(8))
    l0, r0 = pf0(0), pf0(20)
    assert l0 == r0, "PF0 precisa ser igual nas duas metades"
    return l0, pf1(4), pf2(12), pf1(24), pf2(32)


def sprite(rows):
    assert len(rows) == 8
    out = []
    for r in rows:
        assert len(r) == 8
        out.append(sum((1 if ch == "#" else 0) << (7 - i) for i, ch in enumerate(r)))
    return out


# Nhac-Nhac: bichinho redondo com um broto na cabeça e um olho
FRAMES = {
    "hero_side": [  # boca aberta para a direita (para a esquerda usa REFP0)
        "....##..",
        "..####..",
        ".##.###.",
        "#####...",
        "####....",
        "#####...",
        ".######.",
        "..####..",
    ],
    "hero_up": [
        ".#....#.",
        "##....##",
        "###..###",
        "########",
        "##.#####",
        "########",
        ".######.",
        "..####..",
    ],
    "hero_down": [
        "..####..",
        ".######.",
        "#####.##",
        "########",
        "###..###",
        "##....##",
        ".#....#.",
        "........",
    ],
    "hero_closed": [
        "....##..",
        "..####..",
        ".##.###.",
        "########",
        "########",
        "########",
        ".######.",
        "..####..",
    ],
    # Besouros
    "bug_a": [
        ".#....#.",
        "..#..#..",
        ".######.",
        "##.##.##",
        "########",
        ".######.",
        "#.####.#",
        ".#....#.",
    ],
    "bug_b": [
        ".#....#.",
        "..#..#..",
        ".######.",
        "##.##.##",
        "########",
        ".######.",
        ".#.##.#.",
        "#......#",
    ],
    "bug_scared": [
        "........",
        "..#..#..",
        ".######.",
        "#.####.#",
        "########",
        "#.#..#.#",
        ".######.",
        "#..##..#",
    ],
    "blank": ["........"] * 8,
}
FRAME_ORDER = ["hero_side", "hero_up", "hero_down", "hero_closed", "bug_a", "bug_b", "bug_scared"]

PAD = 68  # zeros entre quadros (y do sprite vai de 4 a 68; o kernel lê 76 pares)

# Dígitos 3x5 (nibble: bit3 = coluna esquerda) + letras N H A C para o título
GLYPHS = {
    "0": ["111", "101", "101", "101", "111"],
    "1": ["010", "110", "010", "010", "111"],
    "2": ["111", "001", "111", "100", "111"],
    "3": ["111", "001", "011", "001", "111"],
    "4": ["101", "101", "111", "001", "001"],
    "5": ["111", "100", "111", "001", "111"],
    "6": ["111", "100", "111", "101", "111"],
    "7": ["111", "001", "010", "010", "010"],
    "8": ["111", "101", "111", "101", "111"],
    "9": ["111", "101", "111", "001", "111"],
    "N": ["101", "111", "111", "111", "101"],
    "H": ["101", "101", "111", "101", "101"],
    "A": ["010", "101", "111", "101", "101"],
    "C": ["111", "100", "100", "100", "111"],
}
GLYPH_ORDER = list("0123456789NHAC")


def rev4(n):
    return int(f"{n:04b}"[::-1], 2)


def table(name, values, per_line=16):
    lines = [f"{name}"]
    for i in range(0, len(values), per_line):
        chunk = values[i:i + per_line]
        lines.append("    .byte " + ",".join(f"${v:02X}" for v in chunk))
    return "\n".join(lines) + "\n"


def main():
    out = ["; Gerado por gen.py - não edite à mão\n"]

    walls = [pf_bytes(wall_slots(j)) for j in range(10)]
    out.append(table("WPF0", [w[0] for w in walls]))
    out.append(table("WPF1L", [w[1] for w in walls]))
    out.append(table("WPF2L", [w[2] for w in walls]))
    out.append(table("WPF1R", [w[3] for w in walls]))
    out.append(table("WPF2R", [w[4] for w in walls]))

    # Mapa de aberturas: GapTbl[j + 10*g], bit (s & 7) para casas s = 8g..8g+7
    gap = [0] * 30
    for j in range(10):
        for s, ch in enumerate(wall_slots(j)):
            if ch == ".":
                gap[j + 10 * (s >> 3)] |= 1 << (s & 7)
    out.append(table("GapTbl", gap))

    # Pastilhas: casa s -> deslocamento no bloco de RAM e máscara de bit
    pel_off, pel_mask = [], []
    for s in range(20):
        col = 2 * s
        if 4 <= col <= 11:
            pel_off.append(0); pel_mask.append(1 << (7 - (col - 4)))
        elif 12 <= col <= 19:
            pel_off.append(9); pel_mask.append(1 << (col - 12))
        elif 24 <= col <= 31:
            pel_off.append(18); pel_mask.append(1 << (7 - (col - 24)))
        elif 32 <= col <= 39:
            pel_off.append(27); pel_mask.append(1 << (col - 32))
        else:
            pel_off.append(0xFF); pel_mask.append(0)
    out.append(table("PelOff", pel_off, 20))
    out.append(table("PelMask", pel_mask, 20))
    full = [0, 0, 0, 0]
    for s in range(20):
        if pel_off[s] != 0xFF:
            full[pel_off[s] // 9] |= pel_mask[s]
    out.append(table("PelFull", full))
    out.append(f"PELLETS_TOTAL = {sum(bin(v).count('1') for v in full) * 9}\n")

    # Sprites: duas regiões (linhas pares e ímpares), cada quadro guardado ao
    # contrário e cercado de zeros, para o kernel ler com (ponteiro),y sem testes.
    even, odd = [0] * PAD, [0] * PAD
    starts = []
    for name in FRAME_ORDER:
        rows = sprite(FRAMES[name])
        starts.append(len(even))
        even += list(reversed(rows[0::2])) + [0] * PAD
        odd += list(reversed(rows[1::2])) + [0] * PAD
    # quadro vazio: ponteiro fixo numa sequência de >= 76 zeros no fim
    blank = len(even) - PAD
    even += [0] * (77 - PAD)
    odd += [0] * (77 - PAD)
    out.append(table("GfxEven", even))
    out.append(table("GfxOdd", odd))
    for i, name in enumerate(FRAME_ORDER):
        out.append(f"FR_{name.upper()} = {i}\n")
    out.append(f"FR_BLANK = {len(FRAME_ORDER)}\n")
    out.append(f"BlankE = GfxEven+{blank}-1\nBlankO = GfxOdd+{blank}-1\n")
    # Ponteiro = início do quadro - 73 + y
    out.append("FrameELo\n    .byte " + ",".join(f"<(GfxEven+{s}-73)" for s in starts) + "\n")
    out.append("FrameEHi\n    .byte " + ",".join(f">(GfxEven+{s}-73)" for s in starts) + "\n")
    out.append("FrameOLo\n    .byte " + ",".join(f"<(GfxOdd+{s}-73)" for s in starts) + "\n")
    out.append("FrameOHi\n    .byte " + ",".join(f">(GfxOdd+{s}-73)" for s in starts) + "\n")

    dig, digr = [], []
    for g in GLYPH_ORDER:
        for row in GLYPHS[g]:
            n = int(row + "0", 2)  # 3 colunas + 1 de espaço
            dig.append(n << 4 | n)
            r = rev4(n)
            digr.append(r << 4 | r)
    out.append(table("Digits", dig, 10))
    out.append(table("DigitsR", digr, 10))

    with open(os.path.join(HERE, "data.inc"), "w") as f:
        f.write("\n".join(out))

    print("Labirinto:")
    for j in range(10):
        print("  " + "".join(c * 2 for c in wall_slots(j)))
        if j < 9:
            print("  " + "".join(("o" if pel_off[s] != 0xFF else " ") + " " for s in range(20)))


if __name__ == "__main__":
    main()
