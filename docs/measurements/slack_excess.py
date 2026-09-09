#!/usr/bin/env python3
"""Inserted silence, in descriptors, from a sndslack mode-2 dump.

Completions land on the kernel's descriptor grid (8192 B = 46.44 ms at
44100 stereo S16), so each interval between two SNDWait returns is an
integer number of descriptors.  Summing round(interval/d) and subtracting
what was actually submitted (one buffer per completion, T/d descriptors)
gives the silence the kernel padded in -- immune to the stall's own length
and to clock drift.  No-stall noise floor measured at 0.8 over 479 intervals.

    python3 slack_excess.py file...
"""
import sys, re

D_US = 8192 / (44100 * 4) * 1e6          # one descriptor, microseconds

def analyse(path):
    frames = None; rows = []
    for line in open(path):
        m = re.match(r'# frames (\d+)', line)
        if m: frames = int(m.group(1)); continue
        if line.startswith('#') or not line.strip(): continue
        f = line.split()
        # the program writes its own progress to stderr and the harness
        # merges the two streams; a data line is three integers and
        # nothing else.
        if len(f) < 3: continue
        try:
            rows.append((int(f[0]), int(f[1]), int(f[2])))
        except ValueError:
            continue
    if frames is None or len(rows) < 3:
        return None
    per_buf = frames * 4 / 8192.0        # descriptors submitted per completion
    excess = 0.0; n = 0; stalls = 0; starved = 0; run_excess = 0.0
    for (k0, t0, s0), (k1, t1, s1) in zip(rows[1:], rows[2:]):
        dt = t1 - t0
        e = round(dt / D_US) - per_buf
        excess += e; run_excess += e; n += 1
        if s0:                             # a stall was taken after event k0
            stalls += 1
    # No per-stall attribution: a normal run alternates 1- and 2-descriptor
    # intervals (mean T/d = 1.3457), so any short window can legitimately show
    # +1 of "excess" and a per-stall test fires on the grid itself.  The
    # run total is the statistic; the noise floor is 0.5-0.8 over ~480
    # intervals (mode1-5512.txt, and the no-stall runs).
    return dict(intervals=n, stalls=stalls, excess=excess)

for p in sys.argv[1:]:
    r = analyse(p)
    if r is None:
        print("%-28s unreadable" % p); continue
    verdict = "STARVES" if r['excess'] > 3 else ("marginal" if r['excess'] > 1 else "fits")
    per = r['excess'] / r['stalls'] if r['stalls'] else 0.0
    print("%-24s intervals %4d  stalls %2d  excess %6.1f descr (%.2f/stall)  -> %s"
          % (p.split('/')[-1], r['intervals'], r['stalls'], r['excess'], per, verdict))
