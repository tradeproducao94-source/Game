#!/usr/bin/env python3
"""Emulador mínimo de Atari 2600 para testar o Nhac-Nhac.

CPU: py65. Vídeo: TIA simplificado (playfield, 2 jogadores, bola, HMOVE),
suficiente para conferir o desenho e a contagem de linhas. Não é um emulador
completo: serve só para testes automáticos.
"""
import colorsys
import sys

from py65.devices.mpu6502 import MPU


def ntsc_palette():
    pal = []
    for i in range(128):
        hue, lum = i >> 3, i & 7
        v = 0.08 + lum / 7 * 0.9
        if hue == 0:
            pal.append((int(v * 255),) * 3)
        else:
            h = ((hue - 1) / 15 * 0.95 + 0.12) % 1.0
            r, g, b = colorsys.hsv_to_rgb(h, 0.75, v)
            pal.append((int(r * 255), int(g * 255), int(b * 255)))
    return pal


PAL = ntsc_palette()


class Memory:
    def __init__(self, emu):
        self.emu = emu

    def __getitem__(self, addr):
        return self.emu.read(addr)

    def __setitem__(self, addr, val):
        self.emu.write(addr, val)

    def __len__(self):
        return 0x10000


class Atari:
    def __init__(self, rom):
        assert len(rom) == 4096
        self.rom = rom
        self.ram = [0] * 128
        self.tia = [0] * 64
        self.cycles = 0          # ciclos de CPU totais
        self.line_start = 0      # ciclo em que a linha atual começou
        self.line = 0            # linha desde o último VSYNC
        self.timer = 0
        self.timer_int = 64
        self.timer_set_at = 0
        self.timer_val = 0
        self.joy = 0             # bits: 1 cima 2 baixo 4 esq 8 dir
        self.fire = False
        self.reset_sw = False
        self.frame_lines = []
        self.vsync_on = False
        self.writes = []         # (linha, ciclo na linha, reg, valor)
        self.frames = 0
        self.mpu = MPU(memory=Memory(self))
        self.mpu.reset()
        self.mpu.pc = rom[0xFFC] | rom[0xFFD] << 8
        self.pos = {"P0": 0, "P1": 0, "BL": 0}
        self.last_image = None
        self.max_cycle_at_wsync = 0
        self.render = False

    # ---- barramento ----
    def now(self):
        return self.cycles + (self.mpu.processorCycles - self.base_cycles)

    def read(self, addr):
        addr &= 0x1FFF
        if addr & 0x1000:
            return self.rom[addr & 0xFFF]
        if addr & 0x80 and not addr & 0x200:
            return self.ram[addr & 0x7F]
        if addr & 0x280 == 0x280:
            reg = addr & 0x7
            if reg == 0:  # SWCHA (ativo em zero, P0 nos bits 4-7)
                return (~(self.joy << 4)) & 0xFF
            if reg == 2:  # SWCHB
                return 0x0A | (0 if self.reset_sw else 1) | 0x08
            if reg == 4:  # INTIM
                el = self.now() - self.timer_set_at
                left = self.timer_val * self.timer_int - el
                if left >= 0:
                    return (left // self.timer_int) & 0xFF
                return (0x100 + left) & 0xFF if left > -256 else 0
            return 0
        reg = addr & 0x0F
        if reg == 0x0C:  # INPT4
            return 0x00 if self.fire else 0x80
        return 0

    def write(self, addr, val):
        addr &= 0x1FFF
        if addr & 0x1000:
            return
        if addr & 0x80 and not addr & 0x200:
            self.ram[addr & 0x7F] = val
            return
        if addr & 0x280 == 0x280:
            if (addr & 0x297) == 0x296 or (addr & 0x297) == 0x294 or (addr & 0x297) == 0x295 or (addr & 0x297) == 0x297:
                self.timer_int = {0x294: 1, 0x295: 8, 0x296: 64, 0x297: 1024}[addr & 0x297]
                self.timer_val = val
                self.timer_set_at = self.now()
            return
        reg = addr & 0x3F
        t = self.now()
        in_line = t - self.line_start
        if reg == 0x02:  # WSYNC
            self.max_cycle_at_wsync = max(self.max_cycle_at_wsync, in_line)
            self.pending_wsync = True
            return
        if reg == 0x00:  # VSYNC
            on = bool(val & 2)
            if on and not self.vsync_on:
                self.frame_lines.append(self.line)
                self.finish_frame()
                self.line = 0
                self.frames += 1
            self.vsync_on = on
        self.writes.append((self.line, in_line, reg, val))
        self.tia[reg] = val

    # ---- execução ----
    def run_frames(self, n):
        target = self.frames + n
        while self.frames < target:
            self.step()

    def step(self):
        self.pending_wsync = False
        self.base_cycles = self.mpu.processorCycles
        self.mpu.step()
        spent = self.mpu.processorCycles - self.base_cycles
        self.cycles += spent
        # linhas completas
        while self.cycles - self.line_start >= 76:
            self.line_start += 76
            self.line += 1
        if self.pending_wsync:
            self.line_start += 76
            self.cycles = self.line_start
            self.line += 1

    # ---- vídeo ----
    def finish_frame(self):
        """Desenha o quadro a partir das escritas registradas (se pedido)."""
        w = self.writes
        self.writes = []
        if not self.render:
            for _, c, reg, val in w:
                self.tia_frame_start = getattr(self, "tia_frame_start", [0] * 64)
                self.tia_frame_start[reg] = val
            return
        regs = list(self.tia_frame_start) if hasattr(self, "tia_frame_start") else [0] * 64
        pos = dict(self.pos)
        img = [[(0, 0, 0)] * 160 for _ in range(262)]
        hm = {"P0": 0x20, "P1": 0x21, "BL": 0x24}
        resreg = {0x10: "P0", 0x11: "P1", 0x14: "BL"}
        idx = 0
        lines = max([x[0] for x in w], default=0) + 1
        for line in range(min(lines, 262)):
            # aplica escritas da linha em ordem, desenhando os pixels conforme o tempo
            row = img[line]
            events = []
            while idx < len(w) and w[idx][0] == line:
                events.append(w[idx])
                idx += 1
            ev = 0
            for clock in range(228):
                cyc = clock / 3.0
                while ev < len(events) and events[ev][1] - 1 <= cyc:
                    _, c, reg, val = events[ev]
                    regs[reg] = val
                    if reg in resreg:
                        p = int(3 * (c - 1)) - 68
                        p = 3 if p < 0 else p + (5 if reg != 0x14 else 4)
                        pos[resreg[reg]] = p % 160
                    if reg == 0x2A:  # HMOVE
                        for k, r in hm.items():
                            m = regs[r] >> 4
                            m = m - 16 if m >= 8 else m
                            pos[k] = (pos[k] - m) % 160
                    ev += 1
                if clock < 68:
                    continue
                x = clock - 68
                if regs[0x01] & 2:
                    row[x] = (0, 0, 0)
                    continue
                col = PAL[(regs[0x09] >> 1) & 0x7F]
                # playfield
                pfx = x // 4
                half = pfx >= 20
                c20 = pfx - 20 if half else pfx
                if regs[0x0A] & 1 and half:
                    c20 = 19 - c20
                if c20 < 4:
                    bit = (regs[0x0D] >> (4 + c20)) & 1
                elif c20 < 12:
                    bit = (regs[0x0E] >> (7 - (c20 - 4))) & 1
                else:
                    bit = (regs[0x0F] >> (c20 - 12)) & 1
                if bit:
                    col = PAL[(regs[0x08] >> 1) & 0x7F]
                # bola
                if regs[0x1F] & 2:
                    size = 1 << ((regs[0x0A] >> 4) & 3)
                    if 0 <= (x - pos["BL"]) % 160 < size:
                        col = PAL[(regs[0x08] >> 1) & 0x7F]
                # jogadores
                for name, grp, colr, refl in (("P1", 0x1C, 0x07, 0x0C), ("P0", 0x1B, 0x06, 0x0B)):
                    d = (x - pos[name]) % 160
                    if d < 8:
                        b = d if regs[refl] & 8 else 7 - d
                        if (regs[grp] >> b) & 1:
                            col = PAL[(regs[colr] >> 1) & 0x7F]
                row[x] = col
        self.pos = pos
        self.tia_frame_start = regs
        self.last_image = img

    def save_png(self, path, crop=(30, 230)):
        from PIL import Image
        img = self.last_image
        y0, y1 = crop
        im = Image.new("RGB", (160, y1 - y0))
        for y in range(y0, y1):
            for x in range(160):
                im.putpixel((x, y - y0), img[y][x])
        im = im.resize((640, (y1 - y0) * 2), Image.NEAREST)
        im.save(path)


if __name__ == "__main__":
    a = Atari(open(sys.argv[1], "rb").read())
    a.run_frames(5)
    print("linhas por quadro:", a.frame_lines)
