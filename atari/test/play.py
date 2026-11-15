import sys, random
sys.path.insert(0, sys.path[0])
from emu import Atari
SYM = {}
for ln in open(sys.argv[2]):
    p = ln.split()
    if len(p) >= 2:
        try: SYM[p[0]] = int(p[1], 16)
        except ValueError: pass
a = Atari(open(sys.argv[1], "rb").read())
def ram(name, off=0): return a.ram[(SYM[name] + off) & 0x7F]
out = sys.argv[3]
a.run_frames(40)
a.save_png(f"{out}/title.png")
a.fire = True; a.run_frames(3); a.fire = False
a.run_frames(20)
a.save_png(f"{out}/start.png")
random.seed(1)
dirs = [1, 2, 4, 8]
log = []
bad = set()
for f in range(3000):
    if f % 25 == 0:
        a.joy = random.choice(dirs)
    a.run_frames(1)
    st = ram("state")
    if f in (60, 400, 1200):
        a.save_png(f"{out}/play{f}.png")
    if st == 4:  # fim de jogo: começa outra
        log.append(("gameover", f, ram("score"), ram("score", 1)))
        a.fire = True; a.run_frames(2); a.fire = False
    for e in range(2):
        x, y = ram("ex", e), ram("ey", e)
        if (y + 4) % 8 and x % 8: bad.add(("enemy-off-grid", x, y))
    hx, hy = ram("hx"), ram("hy")
    if (hy + 4) % 8 and hx % 8: bad.add(("hero-off-grid", hx, hy))
lines = a.frame_lines[3:]
print("linhas por quadro: min", min(lines), "max", max(lines))
print("ciclo máx. ao chegar no WSYNC:", a.max_cycle_at_wsync)
print("estado", ram("state"), "placar %02x%02x" % (ram("score"), ram("score", 1)), "vidas", ram("lives"), "fase", ram("level"), "restam", ram("left"))
print("eventos", log[:10])
print("problemas", sorted(bad)[:10])
