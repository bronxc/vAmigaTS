## Summary
---

### diwtim1 - diwtim4

These test utilize the Copper to modify DIWSTRT and DIWSTOP at locations close to the old trigger coordinate. 


### diwtim1b - diwtim4b

These test utilize the Copper to write trigger coordinates into DIWSTRT and DIWSTOP that are close to the current location. 

### minmax 

This test was mentioned in vAmiga GitHub issue 710. It sets DIWSTRT and DIWSTOP to very small and very high values, respectively. It can be used to determine the smallest and largest meaningful coordinate.

### minmax2

A rectified and slightly enhanced variant of the minmax test.

### minmax3

This test is related to vAmiga GitHub issue #799. Background: The last possible DIW stop is position $1c7, because the DIW counter runs through the sequence $1c6, $1c7, 2, 3, etc.. As a result, values larger than $1c7 will not trigger the DIW logic, thus producing an overscan line. On ECS Denise and Lisa, this can be worked around, because the uppermost stop bit can be modified via DIWHIGH. Therefore, it is possible to use values such as 2, 3, ... as trigger coordinates. This trick is impossible on OCS machines since the uppermost stop bit for the DIW window is hard-coded to 1. This test case exploits the trick and produces a different image if an ECS Denise or Lisa chip is plugged in. 

### diwsub

DIWSTRT and DIWSTOP hold their horizontal coordinate in lores pixels, so the display window can only be placed on even hires pixels and on multiples of four in super hires. AGA adds two two-bit fields to DIWHIGH that supply the missing low bits — bits 4-3 for DIWSTRT, bits 12-11 for DIWSTOP. minmax3 above uses DIWHIGH's two *high* bits; these four low ones had no coverage at all.

The window edges are compared in super hires units and then masked down to the resolution being displayed, so the added bits survive only as far as the current mode can resolve them:

```
lores         all four settings identical, no movement at all
hires         0 and 1 identical, 2 and 3 identical, one hires pixel apart
super hires   four distinct positions, one super hires pixel apart
```

The lores section is the control. The regression reference cannot show the whole of the super hires case, because a screenshot texel covers one hires pixel and an odd super hires step lands on the same column — the section reads as two pairs rather than four positions. All four are visible on a real machine, which is what the A1200 photograph is for.

DIWSTRT sits at lores $90, deliberately **right** of the first bitplane pixel. The display window does not open at DIWSTRT but at the first BPL1DAT write, so a DIWSTRT left of the data would be invisible and the test would measure nothing (see Denise/Sprites/clip/diwclip).

All three recorded references — OCS, ECS and PLUS — show no movement anywhere, which is correct: these are AGA fields. That makes them negative controls, and vAmiga currently implements neither field, so the AGA photograph is where the answer has to come from.

### diwsub2

A successor to `diwsub`, same subject, different picture.

`diwsub` walks the four settings down the screen once per section, one long
block each. The effect it is chasing is at most three super hires pixels
wide, and a CRT bows the left edge of the image by considerably more than
that over the height of a section. In the A1200 photograph the *lores*
control section — where nothing may move — drifts by fourteen camera pixels
all by itself, which is wider than the signal. The photograph cannot answer
the question it was taken for.

`diwsub2` changes two things:

1. The setting is ramped fast, not once per screen. A ramp is eighteen
   rasterlines tall and every ramp is repeated, so the picture carries a
   sawtooth of a known short period. Tube geometry is smooth over that
   distance and cannot fake a sawtooth.
2. Every ramp opens with a two-line white baseline drawn with all four low
   bits cleared, right next to the steps being judged, so the comparison is
   local instead of spanning half the screen.

Layout: three sections, each introduced by a three-line tag stripe — dark
red for lores, dark green for hires, dark blue for super hires. Each section
holds two halves; the first ramps the DIWSTRT field and moves the LEFT edge,
the second ramps the DIWSTOP field and moves the RIGHT edge. Lores gets one
ramp per half, the other two get two. Inside a ramp the settings are colour
coded: white baseline, then blue, green, yellow, purple for settings 0 to 3.

Expected on AGA: lores straight, hires a square wave of amplitude one hires
pixel (0 and 1 together, 2 and 3 together), super hires a four-step
staircase. Expected on OCS and ECS: straight everywhere, since these are AGA
fields.

**The recorded `diwsub2_aga` reference is the broken behaviour, on purpose.**
Every edge in it sits at texel 92 / 571 on all 180 picture lines, which is
also exactly where the OCS, ECS and PLUS references put them — vAmiga
implements DIWHIGH bits 5 and 13 and nothing else, so its AGA picture is its
ECS picture. The reference is what the flaw looks like. Once
`Denise::setDIWHIGH` learns bits 4-3 and 12-11, this test starts to FAIL,
and the `diwsub2_aga_fail.tiff` it drops is the thing to check against the
A1200 photograph before promoting it to the new reference.

The reference resolves one hires pixel per texel, so it will show the hires
square wave exactly and the super hires staircase as two pairs rather than
four steps. All four steps are visible on a real machine.

Note that at the time of writing no AGA script in the suite runs at all:
`A1200_2MB` sets `Opt::CPU_OVERCLOCKING` to 2, and every AGA regression run
aborts with an exception during `wait`. The `diwsub2_aga` reference was
therefore recorded with that one line set back to 0, and matches a vAmiga
built from HEAD with that single change.

Two things the test guards against silently measuring nothing. DIWSTRT sits
at lores $90, deliberately right of the first bitplane pixel, because the
display window opens at the first BPL1DAT write rather than at DIWSTRT (see
`Denise/Sprites/clip/diwclip`). And each step colour is written to COLOR01
*and* COLOR05, because ECS Denise in super hires pairs plane bits across
neighbouring pixels and lands on register 5 — without the second write the
whole super hires section is black on the A500+ alone.

### diwswitch1

Can the extended DIWHIGH interpretation be switched off again? Yes -- and
this test found a real, present-day divergence in how vAmiga does it.

ECS Denise and Lisa read DIWSTRT/DIWSTOP's low byte exactly as OCS did, but
no longer hard-wire the missing 9th bit. OCS always used H8=0 for DIWSTRT
and H8=1 for DIWSTOP, confining the start edge to 0-255 and the stop edge
to 256-511. On ECS and AGA that bit instead comes from DIWHIGH -- bit 5 for
DIWSTRT, bit 13 for DIWSTOP -- letting a Copper list place either edge
anywhere across the full 0-511 range.

The interesting part is the latch behind it. WinUAE / Amiberry (`custom.cpp`,
`DIWSTRT()` / `DIWSTOP()` / `DIWHIGH()`) model this with one shared flag,
`diwhigh_written`: writing DIWHIGH sets it, and writing *either* DIWSTRT or
DIWSTOP clears it -- for **both** edges at once, not just the field being
written. `drawing.cpp`'s Denise-side copy of the same flag works the same
way for the horizontal edges.

vAmiga's `Denise::setDIWSTRT` / `setDIWSTOP` (and the vertical equivalents in
`Sequencer`) do force their own edge back to the OCS-hardcoded bit on every
write, which reproduces the same-field half of that rule. What they don't do
is touch the *other* edge: `setDIWSTRT` only ever calls `setHSTRT`, never
`setHSTOP`, and `setDIWSTOP` is the mirror image -- there is no shared flag,
just two independent ones.

This test drives DIWSTRT's H8 bit through six steps, then repeats the same
six steps for DIWSTOP with the roles swapped:

1. baseline -- DIWHIGH default, edge at the near position
2. switch ON -- DIWHIGH sets the bit, edge jumps to the far position
3. same-field rewrite -- the field under test is rewritten unchanged; both
   models agree this clears the bit, edge back to near
4. switch ON again -- confirms DIWHIGH re-enables it
5. **cross-field rewrite** -- the *other* field is rewritten unchanged. The
   WinUAE model says this clears the bit too (edge back to near); vAmiga's
   source only clears a field's own bit, so the edge should stay far
6. reset -- DIWHIGH default, closing out the section

Steps are bordered dark blue where the OCS-hardcoded bit should be in
effect, dark yellow where the extension should be active, and a muted
red-grey for step 5, which isn't given a predicted colour -- it's the
question the test exists to answer.

**Recorded result, on both the A500+ (ECS Denise) and the A1200 (AGA
Denise): the edge stays at the far position through step 5.** Section A's
DIWSTOP rewrite does not clear DIWSTRT's extension; section B's DIWSTRT
rewrite does not clear DIWSTOP's extension, either. So as it stands today,
vAmiga's cross-field behaviour does not match the WinUAE / Amiberry model --
each of the four "extend this edge" bits (V8-strt, V8-stop, H8-strt,
H8-stop) has its own independent on/off latch in vAmiga, where the reference
model uses one latch shared by all four. A500 (true OCS Denise) and
A500_ECS_1MB (ECS Agnus paired with OCS Denise, exactly like a real early
A500) both hold the edge at the near position throughout -- the correct
negative control, since the field only exists on ECS/AGA Denise.

No AGA photograph has confirmed which model real silicon follows; the
`diwswitch1_aga` reference is simply what vAmiga does today, recorded so a
future fix would show up as a FAIL here. As with `diwsub2`, the AGA
reference was recorded with `Opt::CPU_OVERCLOCKING` on the `A1200_2MB` scheme
set back to 0 -- see the note under diwsub2 above.

---
Dirk Hoffmann, 2022 - 2026
