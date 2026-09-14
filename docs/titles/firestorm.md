# Firestorm — Feature Reference

Expansion (2000) to Tiberian Sun. Exhaustive catalog: `docs/research/deep/fs.md`
(+ first-pass `docs/research/_raw/ts-firestorm.md`). Content package: `games/fs`
(new; **delta over `ts`**).

## Model

`games/fs` should list the `ts` data-set root first, then its own overrides (last-wins).
The original game gates FS content via `expand01.mix` + `firestrm.ini` detection, **not** a
`Firestorm=yes` map flag — a per-map/per-package roster gate is our own design choice.
Also note: `CraterLevel`/veinhole tuning are **not** in the FS INI, and the "mutate" superweapon
from early notes was a misattribution (it is the Tiberium Floater lifeform, `JFISH`).

## New GDI

- **Juggernaut** (`JUGG` → deploy `DJUGG`) — triple 90 mm, deploy-to-fire, radar prereq.
- **Mobile EMP** (`MOBILEMP`) — charge meter, area EMP pulse.
- **Mobile War Factory** (`MOBWARG` → `DGWEAP`) — `BuildLimit=1`.
- **Firestorm Generator** (`GAFIRE`) — `FirestormSpecial` defensive barrier.
- **Limpet Drone** (`LIMPET` → `DLIMPET`) — attach/scout/slow vehicles.

## New Nod

- **Cyborg Reaper** (`REAPER`) — spider walker, QuadLauncher + WebLauncher (web immobilizes).
- **Mobile Stealth Generator** (`SGEN` → `MSTL`) — cloak radius, sensors.
- **Mobile War Factory** (`MOBWARN` → `DNWEAP`).
- **AA Obelisk** (`AAOB`), Laser Fence (`NAPOST`/`NAFNCE`).

## New CABAL faction

- **Core Defender** (`DEFENDER` → `DDEFD`) — super-heavy, immune.
- **CABAL Obelisk** (`CROB`), **Cabal Core** (`CORE`). Playable/enemy house.

## Rules / general changes

- Drop pod infantry 3/5 → 12/15; `BallisticScatter` 1.5 → 2.0; `EngineerCaptureLevel=1.0`,
  `EngineerDamage=0.0`.
- New warheads (WebMass, LIMPY, CoreDefPlasmaWH, Super2, MobileEMPulse, WeakGass, Stinger,
  MeteorWH, ARTYHEX, Gas2); new particles (Web, WeakGasCloud, SmokeStackPuff).
- Firestorm defense params (`ChargeToDrainRatio`, `DamageToFirestormDamageCoefficient`).
- New "mutated" ecology tiles; veinhole tuning (`VeinholeGrowthRate/ShrinkRate`).
- Meteor/terrain crater controls (`CraterLevel`).

## Unified-engine implications

FS is the proof-of-concept for the **delta game package**: no new engine subsystems beyond TS
are required — only additional data plus the `Firestorm` scenario gate and the superweapon
framework (shared with all titles).
