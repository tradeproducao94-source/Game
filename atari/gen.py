#!/usr/bin/env python3
"""Gera os dados do Nhac-Nhac para Atari 2600 (cartucho F8SC: 8 KB + 128 bytes de RAM).

O labirinto é lido de ../src/main.lua (o mesmo da versão LÖVE): 21 x 21 casas.
Na tela do Atari cada casa tem 8 px x 8 linhas; as colunas de borda (0 e 20)
têm só 4 px, assim as 21 casas cabem nas 40 colunas do playfield:
  casa 0 -> coluna 0 ; casa t (1..19) -> colunas 2t-1 e 2t ; casa 20 -> coluna 39

Saída:
  data0.inc  (banco 0: kernel)  paredes espelhadas por fileira e desenhos dos sprites
  data1.inc  (banco 1: lógica)  estado inicial da RAM extra (paredes+pastilhas),
                                mapa de onde dá para andar, pastilhas e dígitos
"""
import os
import re
from collections import deque

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "..", "src", "main.lua")


def read_maze():
    text = open(SRC, encoding="utf-8").read()
    block = re.search(r"local MAZE = \{(.*?)\n\}", text, re.S).group(1)
    rows = re.findall(r'"([^"]*)"', block)
    assert len(rows) == 21 and all(len(r) == 21 for r in rows)
    return rows


MAZE = read_maze()
W = H = 21


def passable(ch):
    return ch not in "#-G"


def reachable():
    start = next((x, y) for y in range(H) for x in range(W) if MAZE[y][x] == "P")
    seen = {start}
    q = deque([start])
    while q:
        x, y = q.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = (x + dx) % W, y + dy
            if 0 <= ny < H and passable(MAZE[ny][nx]) and (nx, ny) not in seen:
                seen.add((nx, ny))
                q.append((nx, ny))
    return seen, start


REACH, START = reachable()


def is_wall_drawn(x, y):
    ch = MAZE[y][x]
    if ch in "#-":
        return True
    if ch == "G":
        return False          # interior da toca: vazio
    return (x, y) not in REACH  # espaço fora do labirinto: desenha como parede


def tile_cols(t):
    if t == 0:
        return [0]
    if t == 20:
        return [39]
    return [2 * t - 1, 2 * t]


def pellet_col(t):
    return 2 * t if t <= 10 else 2 * t - 1


def col_reg(col):
    """(registrador 0..5, máscara) para uma coluna de playfield não espelhado."""
    if col < 4:
        return 0, 1 << (4 + col)
    if col < 12:
        return 1, 1 << (7 - (col - 4))
    if col < 20:
        return 2, 1 << (col - 12)
    if col < 24:
        return 3, 1 << (4 + col - 20)
    if col < 32:
        return 4, 1 << (7 - (col - 24))
    return 5, 1 << (col - 32)


def row_cols(y):
    cols = [0] * 40
    for t in range(W):
        if is_wall_drawn(t, y):
            for c in tile_cols(t):
                cols[c] = 1
    return cols


def table(name, values, per_line=16):
    lines = [name]
    for i in range(0, len(values), per_line):
        lines.append("    .byte " + ",".join(f"${v:02X}" for v in values[i:i + per_line]))
    return "\n".join(lines) + "\n"


# ---------------------------------------------------------------- sprites
FRAMES = {
    "hero_side": ["....##..", "..####..", ".##.###.", "#####...", "####....", "#####...", ".######.", "..####.."],
    "hero_up": [".#....#.", "##....##", "###..###", "########", "##.#####", "########", ".######.", "..####.."],
    "hero_down": ["..####..", ".######.", "#####.##", "########", "###..###", "##....##", ".#....#.", "........"],
    "hero_closed": ["....##..", "..####..", ".##.###.", "########", "########", "########", ".######.", "..####.."],
    "bug_a": [".#....#.", "..#..#..", ".######.", "##.##.##", "########", ".######.", "#.####.#", ".#....#."],
    "bug_b": [".#....#.", "..#..#..", ".######.", "##.##.##", "########", ".######.", ".#.##.#.", "#......#"],
    "bug_scared": ["........", "..#..#..", ".######.", "#.####.#", "########", "#.#..#.#", ".######.", "#..##..#"],
}
FRAME_ORDER = ["hero_side", "hero_up", "hero_down", "hero_closed", "bug_a", "bug_b", "bug_scared"]
LINES = 168     # linhas do labirinto (21 x 8)
PAD = 160       # zeros antes/depois de cada quadro (y do sprite vai de 0 a 160)

GLYPHS = {
    "0": ["111", "101", "101", "101", "111"], "1": ["010", "110", "010", "010", "111"],
    "2": ["111", "001", "111", "100", "111"], "3": ["111", "001", "011", "001", "111"],
    "4": ["101", "101", "111", "001", "001"], "5": ["111", "100", "111", "001", "111"],
    "6": ["111", "100", "111", "101", "111"], "7": ["111", "001", "010", "010", "010"],
    "8": ["111", "101", "111", "101", "111"], "9": ["111", "101", "111", "001", "111"],
    "N": ["101", "111", "111", "111", "101"], "H": ["101", "101", "111", "101", "101"],
    "A": ["010", "101", "111", "101", "101"], "C": ["111", "100", "100", "100", "111"],
}
GLYPH_ORDER = list("0123456789NHAC")


def sprite_bytes(rows):
    return [sum((ch == "#") << (7 - i) for i, ch in enumerate(r)) for r in rows]


def main():
    # simetria (necessária para o playfield espelhado)
    for y in range(H):
        for x in range(W):
            assert is_wall_drawn(x, y) == is_wall_drawn(20 - x, y), (x, y)

    d0, d1 = ["; Gerado por gen.py - não edite\n"], ["; Gerado por gen.py - não edite\n"]

    # ---- banco 0: paredes espelhadas (metade esquerda) ----
    pf = [[], [], []]
    for y in range(H):
        cols = row_cols(y)
        v = [0, 0, 0]
        for c in range(20):
            if cols[c]:
                r, m = col_reg(c)
                v[r] |= m
        for i in range(3):
            pf[i].append(v[i])
    d0.append(table("WallPF0", pf[0], 21))
    d0.append(table("WallPF1", pf[1], 21))
    d0.append(table("WallPF2", pf[2], 21))

    # ---- banco 0: sprites com zeros em volta (lidos com (ptr),y) ----
    gfx = [0] * PAD
    starts = []
    for name in FRAME_ORDER:
        starts.append(len(gfx))
        gfx += list(reversed(sprite_bytes(FRAMES[name]))) + [0] * PAD
    blank = len(gfx) - PAD
    gfx += [0] * (LINES + 1 - PAD)
    d0.append(table("Gfx", gfx))
    d0.append(f"GFX_BLANK = Gfx+{blank}-1\n")
    for i, s in enumerate(starts):
        d0.append(f"GFX_{FRAME_ORDER[i].upper()} = Gfx+{s}-161\n")

    # ---- banco 1 ----
    for i, n in enumerate(FRAME_ORDER):
        d1.append(f"FR_{n.upper()} = {i}\n")
    d1.append(f"FR_BLANK = {len(FRAME_ORDER)}\n")
    d1.append("FrameLo\n    .byte " + ",".join(f"<GFX_{n.upper()}" for n in FRAME_ORDER) + "\n")
    d1.append("FrameHi\n    .byte " + ",".join(f">GFX_{n.upper()}" for n in FRAME_ORDER) + "\n")

    # RAM extra: 6 registros x 21 fileiras (paredes + pastilhas, playfield não espelhado)
    sc = [[0] * 21 for _ in range(6)]
    total = 0
    powers = []
    for y in range(H):
        cols = row_cols(y)
        for c in range(40):
            if cols[c]:
                r, m = col_reg(c)
                sc[r][y] |= m
        for t in range(1, 20):
            ch = MAZE[y][t]
            if ch in ".o":
                r, m = col_reg(pellet_col(t))
                assert not sc[r][y] & m
                sc[r][y] |= m
                total += 1
                if ch == "o":
                    powers.append((t, y))
    flat = [v for reg in sc for v in reg]
    d1.append(table("SCInit", flat, 21))
    d1.append(f"PELLETS_TOTAL = {total}\n")

    # pastilha por coluna lógica c (0..19): deslocamento do registrador e máscara
    reg_off, reg_mask = [], []
    for c in range(20):
        if c == 0:
            reg_off.append(0xFF); reg_mask.append(0)
        else:
            r, m = col_reg(pellet_col(c))
            reg_off.append(r * 21); reg_mask.append(m)
    d1.append(table("PelOff", reg_off, 20))
    d1.append(table("PelMask", reg_mask, 20))

    assert len(powers) == 4
    d1.append("PowC\n    .byte " + ",".join(str(t) for t, _ in powers) + "\n")
    d1.append("PowR\n    .byte " + ",".join(str(y) for _, y in powers) + "\n")
    d1.append("PowIdx\n    .byte " + ",".join(str(reg_off[t] + y) for t, y in powers) + "\n")
    d1.append("PowMask\n    .byte " + ",".join(f"${reg_mask[t]:02X}" for t, _ in powers) + "\n")

    # onde dá para andar: WalkTbl[r + 21*(c>>3)], bit (c & 7); coluna lógica 0 = casas 0/20
    walk = [0] * 63
    for y in range(H):
        for c in range(20):
            if (c, y) in REACH:
                walk[y + 21 * (c >> 3)] |= 1 << (c & 7)
    d1.append(table("WalkTbl", walk, 21))
    sx, sy = START
    d1.append(f"HERO_START_X = {(8 * sx - 4) % 160}\nHERO_START_Y = {8 * sy}\n")

    dig, digr = [], []
    rev4 = lambda n: int(f"{n:04b}"[::-1], 2)
    for g in GLYPH_ORDER:
        for row in GLYPHS[g]:
            n = int(row + "0", 2)
            dig.append(n << 4 | n)
            digr.append(rev4(n) << 4 | rev4(n))
    d1.append(table("Digits", dig, 10))
    d1.append(table("DigitsR", digr, 10))

    open(os.path.join(HERE, "data0.inc"), "w").write("\n".join(d0))
    open(os.path.join(HERE, "data1.inc"), "w").write("\n".join(d1))

    print(f"pastilhas: {total}, energéticas: {powers}, início: {START}")
    for y in range(H):
        print("  " + "".join("#" if c else "." for c in row_cols(y)))


if __name__ == "__main__":
    main()
