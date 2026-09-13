#!/usr/bin/env python3
"""LFD main-menu stage: dialog-lookalike with ASCII seagulls in the empty space."""
from __future__ import annotations

import curses
import os
import random
import sys
import time

RIGHT = [
    ("   \\\\    ", "__( .'>  "),
    ("   ==    ", "__( .'>  "),
    ("   //    ", "__( .'>  "),
]
LEFT = [
    ("    //   ", "  <'. )__"),
    ("    ==   ", "  <'. )__"),
    ("    \\\\   ", "  <'. )__"),
]
FAR = [">v<", "~v~", "^v^", "v.v"]
CLOUDS = [
    (
        "   .--.   ",
        " .-(  )-. ",
        "(________)",
    ),
    (
        "    .--.    ",
        ".-~(    )~-.",
        "(__________)",
    ),
    (
        "  .---.  ",
        " (     ) ",
        "  `---'  ",
    ),
]


def blit(stdscr, art, gy, gx, cols, rows, box, attr):
    y1, x1, y2, x2 = box
    for i, line in enumerate(art):
        yy = gy + i
        if yy < 1 or yy >= rows - 1:
            continue
        xx = int(gx)
        frag = line
        if xx < 0:
            frag = line[-xx:]
            xx = 0
        # skip chars that sit inside the dialog
        out = []
        for j, ch in enumerate(frag):
            cx = xx + j
            if cx >= cols:
                break
            if y1 <= yy <= y2 and x1 <= cx <= x2:
                continue
            try:
                stdscr.addch(yy, cx, ord(ch), attr)
            except curses.error:
                pass
            out.append(ch)


def read_menu():
    title = sys.stdin.readline().rstrip("\n") or "LFD"
    hint = sys.stdin.readline().rstrip("\n").replace("\\n", "\n")
    items = []
    for line in sys.stdin:
        line = line.rstrip("\n")
        if not line or "|" not in line:
            continue
        tag, label = line.split("|", 1)
        items.append((tag, label))
    return title, hint, items


class Cloud:
    def __init__(self, cols: int, rows: int, box):
        self.art = random.choice(CLOUDS)
        self.dir = random.choice((-1, 1))
        self.x = float(random.randint(0, max(1, cols - 12)))
        self.y = self._lane(rows, box)
        self.speed = random.uniform(0.08, 0.22) * self.dir

    def _lane(self, rows, box):
        y1, x1, y2, x2 = box
        # prefer sky (above the box) and a couple low ones
        high = [y for y in range(1, max(2, y1 - 3))]
        low = [y for y in range(min(rows - 4, y2 + 2), rows - 3)]
        lanes = high or low or [1]
        if low and random.random() < 0.25:
            lanes = low
        return random.choice(lanes)

    def step(self, cols, rows, box):
        self.x += self.speed
        w = len(self.art[0])
        if self.x < -w - 2 or self.x > cols + 2:
            self.dir *= -1
            self.speed = abs(self.speed) * self.dir
            self.x = -w if self.dir > 0 else float(cols + 1)
            self.y = self._lane(rows, box)
            self.art = random.choice(CLOUDS)

    def draw(self, stdscr, cols, rows, box):
        blit(stdscr, self.art, int(self.y), int(self.x), cols, rows, box, curses.color_pair(2) | curses.A_DIM)


class Gull:
    def __init__(self, cols: int, rows: int, box):
        self.far = random.random() < 0.45
        self.dir = random.choice((-1, 1))
        self.x = float(random.randint(0, max(1, cols - 8)))
        self.y = self._lane(rows, box)
        self.speed = random.uniform(0.35, 1.1) * self.dir
        if self.far:
            self.speed *= 0.55
        self.frame = random.randint(0, 2)
        self.tick = 0
        self.glyph = random.choice(FAR)

    def _lane(self, rows, box):
        y1, x1, y2, x2 = box
        lanes = [y for y in range(1, rows - 2) if y < y1 - 1 or y > y2 + 1]
        return random.choice(lanes) if lanes else 1

    def step(self, cols, rows, box):
        self.tick += 1
        if self.tick % 3 == 0:
            self.frame = (self.frame + 1) % 3
        self.x += self.speed
        if self.x < -10 or self.x > cols + 2:
            self.dir *= -1
            self.speed = abs(self.speed) * self.dir
            self.x = -8 if self.dir > 0 else float(cols + 1)
            self.y = self._lane(rows, box)
            self.glyph = random.choice(FAR)

    def draw(self, stdscr, cols, rows, box):
        y1, x1, y2, x2 = box
        if self.far:
            s = self.glyph
            gy, gx = int(self.y), int(self.x)
            if 0 <= gy < rows and 0 <= gx < cols:
                if not (y1 <= gy <= y2 and x1 <= gx <= x2):
                    try:
                        stdscr.addstr(gy, gx, s[: max(0, cols - gx)], curses.color_pair(2))
                    except curses.error:
                        pass
            return
        art = RIGHT[self.frame] if self.dir > 0 else LEFT[self.frame]
        gy = int(self.y)
        gx = int(self.x)
        for i, line in enumerate(art):
            yy = gy + i
            if yy < 0 or yy >= rows:
                continue
            if y1 <= yy <= y2:
                continue
            xx = max(0, gx)
            frag = line
            if gx < 0:
                frag = line[-gx:]
            frag = frag[: max(0, cols - xx)]
            if not frag:
                continue
            try:
                stdscr.addstr(yy, xx, frag, curses.color_pair(1))
            except curses.error:
                pass


def run(stdscr, title, hint, items):
    curses.curs_set(0)
    curses.start_color()
    curses.use_default_colors()
    curses.init_pair(1, curses.COLOR_RED, -1)
    curses.init_pair(2, curses.COLOR_WHITE, -1)
    curses.init_pair(3, curses.COLOR_BLACK, curses.COLOR_RED)
    curses.init_pair(4, curses.COLOR_RED, curses.COLOR_BLACK)
    stdscr.nodelay(True)
    stdscr.timeout(70)
    sel = 0
    rows, cols = stdscr.getmaxyx()
    bh, bw = min(22, rows - 2), min(76, cols - 4)
    by, bx = max(1, (rows - bh) // 2), max(1, (cols - bw) // 2)
    box = (by, bx, by + bh - 1, bx + bw - 1)
    n = max(4, min(10, (rows * cols) // 280))
    gulls = [Gull(cols, rows, box) for _ in range(n)]
    clouds = [Cloud(cols, rows, box) for _ in range(max(3, min(7, cols // 18)))]
    last = time.time()

    while True:
        rows, cols = stdscr.getmaxyx()
        bh, bw = min(22, max(12, rows - 2)), min(76, max(40, cols - 4))
        by, bx = max(1, (rows - bh) // 2), max(1, (cols - bw) // 2)
        box = (by, bx, by + bh - 1, bx + bw - 1)
        now = time.time()
        if now - last > 0.04:
            for cld in clouds:
                cld.step(cols, rows, box)
            for g in gulls:
                g.step(cols, rows, box)
            last = now
        stdscr.erase()
        try:
            stdscr.addstr(0, 0, " LFD · pakun   github.com/brazyqueso", curses.color_pair(1) | curses.A_BOLD)
        except curses.error:
            pass
        for cld in clouds:
            cld.draw(stdscr, cols, rows, box)
        for g in gulls:
            g.draw(stdscr, cols, rows, box)

        # dialog box
        red = curses.color_pair(1) | curses.A_BOLD
        for x in range(bx, bx + bw):
            try:
                stdscr.addch(by, x, curses.ACS_HLINE, red)
                stdscr.addch(by + bh - 1, x, curses.ACS_HLINE, red)
            except curses.error:
                pass
        for y in range(by, by + bh):
            try:
                stdscr.addch(y, bx, curses.ACS_VLINE, red)
                stdscr.addch(y, bx + bw - 1, curses.ACS_VLINE, red)
            except curses.error:
                pass
        for y, x, ch in (
            (by, bx, curses.ACS_ULCORNER),
            (by, bx + bw - 1, curses.ACS_URCORNER),
            (by + bh - 1, bx, curses.ACS_LLCORNER),
            (by + bh - 1, bx + bw - 1, curses.ACS_LRCORNER),
        ):
            try:
                stdscr.addch(y, x, ch, red)
            except curses.error:
                pass
        t = f"[ {title} ]"
        try:
            stdscr.addstr(by, bx + max(1, (bw - len(t)) // 2), t, red)
        except curses.error:
            pass
        hy = by + 1
        for line in hint.split("\n")[:3]:
            try:
                stdscr.addstr(hy, bx + 2, line[: bw - 4], curses.color_pair(1))
            except curses.error:
                pass
            hy += 1
        # inner list frame
        iy0, iy1 = hy, by + bh - 4
        try:
            for x in range(bx + 2, bx + bw - 2):
                stdscr.addch(iy0, x, curses.ACS_HLINE, red)
                stdscr.addch(iy1, x, curses.ACS_HLINE, red)
            for y in range(iy0, iy1 + 1):
                stdscr.addch(y, bx + 2, curses.ACS_VLINE, red)
                stdscr.addch(y, bx + bw - 3, curses.ACS_VLINE, red)
        except curses.error:
            pass
        vis = iy1 - iy0 - 1
        top = 0
        if sel >= top + vis:
            top = sel - vis + 1
        if sel < top:
            top = sel
        for i, (tag, label) in enumerate(items[top : top + vis]):
            y = iy0 + 1 + i
            idx = top + i
            line = f" {tag}  {label}"
            line = line[: bw - 8].ljust(bw - 8)
            attr = curses.color_pair(3) if idx == sel else curses.color_pair(1)
            try:
                stdscr.addstr(y, bx + 3, line, attr)
            except curses.error:
                pass
        ok = "<  OK  >"
        can = "<Cancel>"
        fy = by + bh - 2
        try:
            stdscr.addstr(fy, bx + bw // 2 - 14, ok, curses.color_pair(3))
            stdscr.addstr(fy, bx + bw // 2 + 2, can, curses.color_pair(1))
        except curses.error:
            pass
        stdscr.refresh()

        k = stdscr.getch()
        if k in (curses.KEY_UP, ord("k")):
            sel = (sel - 1) % len(items)
        elif k in (curses.KEY_DOWN, ord("j")):
            sel = (sel + 1) % len(items)
        elif k in (curses.KEY_ENTER, 10, 13, ord(" ")):
            return items[sel][0]
        elif k in (27, ord("q")):
            return "__CANCEL__"
        elif k != -1:
            ch = chr(k) if 32 <= k < 127 else ""
            for i, (tag, _) in enumerate(items):
                if tag == ch:
                    return tag


def main():
    title, hint, items = read_menu()
    if not items:
        return 1
    orig_out = os.dup(1)
    try:
        tty = os.open("/dev/tty", os.O_RDWR)
        os.dup2(tty, 0)
        os.dup2(tty, 1)
        os.dup2(tty, 2)
        picked = curses.wrapper(lambda s: run(s, title, hint, items))
    except Exception:
        return 1
    finally:
        try:
            os.dup2(orig_out, 1)
        except OSError:
            pass
    if picked == "__CANCEL__":
        return 2
    if not picked:
        return 1
    os.write(orig_out, (picked + "\n").encode())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
