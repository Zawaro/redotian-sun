# Deep Research Set (Pass 2) — Exhaustive Per-Title Catalogs

Web-researched, verification pass 2026-09-14. Supersedes the first-pass material in
`docs/research/_raw/`.

**Read this file first: it carries the errata that override the catalogs.**

## Method

- Web only (no local game data read). Primary shipped INIs hosted on GitHub, ModEnc,
  cnc.fandom.com, Project Perfect Mod, CnCNet, StrategyWiki, Ares/Phobos docs, and open
  reimplementations (OpenTS, Vanilla Conquer, FinalSun/FA2, TSpp/YRpp).
- Two adversarial verification agents re-checked the highest-stakes claims against independent
  sources and produced a conflict ledger. Where the verification disagrees with a catalog, the
  verification wins.
- No code snippets; logic described in prose.

## Files

| File | Lines | IDs | Covers |
|---|---:|---|---|
| `ts-core.md` | 2865 | TS-CORE-001…067 | TS simulation, formulas, warheads, projectiles, power, veterancy, crates, timing |
| `ts-gameplay.md` | 1360 | TS-GP-001…058 | TS economy, construction, production, full GDI/Nod rosters, movement, vision, special systems, AI, data arch |
| `ts-uiux.md` | 1828 | TS-UI-001…160 | TS screens, HUD, controls, cursors, EVA, voices, music, presentation, campaigns |
| `fs.md` | 745 | FS-000…033 | Firestorm delta (content, rules, 18 missions, CABAL) |
| `ra2-core.md` | 1256 | RA2-CORE-001…022 | RA2 simulation, 11 armor classes, 105 warheads, 50 projectiles, movement, power |
| `ra2-gameplay.md` | 1659 | RA2-GP-001…072 | RA2 economy, base, production, 9-country rosters, abilities, naval, AI, data arch |
| `ra2-uiux.md` | 1834 | RA2-UI-001…160 | RA2 screens, HUD, hotkeys, EVA, music, presentation, 24 missions |
| `yr-core.md` | 1467 | YR-CORE-001…045 | YR mechanics: mind control, gattling, superweapons, status, country bonuses, garrison, economy hooks |
| `yr-gameplay.md` | 1533 | YR-GP-001…402 | Yuri faction + Allied/Soviet additions, slave economy, 14 missions, modes |
| `yr-uiux.md` | 799 | YR-UI-100… | YR UI deltas, EVA, FMV, theaters, FX, campaign, meta |
| `cross-engine-source.md` | 981 | X-ENG-001…014 | Engine architecture ground truth (tick, object model, INI loader, movement, weapons, AI, save/load, netcode) |
| `cross-data-architecture.md` | 1575 | X-DATA-001…030 | Cross-title INI/schema/map/house/theater/localization model + unified mapping table |
| `verification-core.md` | 130 | — | Adversarial verification of core claims (ledger) |
| `verification-gameplay.md` | 205 | — | Adversarial verification of content/UI/campaign claims (ledger) |

**Total: ~18,000 lines.**

## Errata — verified corrections that override the catalogs

### Design-impacting (change how the engine must be built)

1. **Warhead `Verses` is editable in TS/FS too, not hardcoded.** The catalogs
   (`ts-gameplay.md` TS-GP-042/058) claim TS armor multipliers are hardcoded — false. What
   differs per title is the **armor enumeration** (TS = 5, RA2/YR = 11) and therefore the
   `Verses` array length. The unified engine must read a per-game armor table and a
   variable-length `Verses`, never assume TS sizing. *(High confidence.)*
2. **AI script action IDs differ per title.** RA2/YR insert `Eaten`/`Harvest` at 9/10 and shift
   every TS action ≥11 by +1, and add 26–32 (incl. YR-only Spyplane actions). The AI data layer
   must be keyed per game, not one shared enum. *(High.)*
3. **Animation arrays differ per title and YR has an enumeration bug.** TS `[Animations]` = 277
   (0–276, last `INVISO`). YR's array is ~607 entries and Westwood shifted entries +4 at #209.
   Any animation index / map-trigger port must be per-title. *(High.)*
4. **Data patching level matters.** Several YR cost errors trace to a retail **1.000** mirror;
   the final official patch is **1.001**. Target 1.001 values. *(High.)*
5. **`CellSpread` is a 3D lepton sphere, not a cell square**; a 3×3 building hit by CellSpread
   takes damage per covered cell (3×3 → 9×). *(High.)* And TS shroud is **local-player only**
   in the original engine, not per-house (our per-player `ShroudSystem` is a superset; keep the
   distinction in mind for parity). *(Med.)*
6. **Sub-cell occupancy = 5 sub-positions per cell** with a separate bridge mask. *(Med.)*

### Content / roster corrections

7. **RA2 sidebar = 4 tabs**, not 6: Structures; Defenses (+support powers); Infantry; Vehicles
   (the last also holds aircraft and naval). `ra2-gameplay.md` RA2-GP-021 is wrong; `ra2-uiux.md`
   RA2-UI-020 is right. (6–7 tabs are Tiberium Wars / Red Alert 3.)
8. **Slave Miner = $1750** (YR 1.001; 1500 = pre-patch 1.000). YR-only — RA2 has none.
   `ra2-gameplay.md` RA2-GP-002's `$1400` row is wrong.
9. **Chaos Drone = $1000** (YR 1.001; ROF 30→45). Catalog said 800.
10. **Siege Chopper = $1100** (YR 1.001). Catalog said 1400.
11. **Grand Cannon internal id = `GTGCAN`**, not `GAGCAN`.
12. **Korea's country unique = Black Eagle (`BEAG`, $1200)**; catalog said "none".
13. **TS Nod campaign = 13 main missions** (2 are either/or branches); the `15` in
    `ts-uiux.md` line 63 contradicts its own TS-UI-131. GDI = 15 main. FS = 9+9 = 18.
14. **TS `VeteranCap` default = 2** (catalog claimed default 1).
15. **FS `[JumpjetControls]` does set `CloakDetectionRadius=3`** (absent in base TS only).
16. **FS `[Warheads]` registry = 3** (`WebMass`, `LIMPY`, `CoreDefPlasmaWH`); TS+FS = 27.
17. **FS content gating is not a `Firestorm=yes` map flag** — the original gates via
    `expand01.mix` + `firestrm.ini` detection. Treat the map-flag idea as our own
    implementation choice, not original behavior.
18. **Control groups:** TS = 10, RA2 = 9 (Catalog correct; the "10" in the RA2 brief was wrong).

### Still open (do not treat as settled)

- TS `1% Verses` retaliation: two ModEnc pages conflict.
- `ProneDamage` applied before vs after `Verses`: ModEnc self-conflict.
- Type-list counts (TS 36/50/150; RA2 45/57) — asserted, not primary-counted; treat as approximate.
- OpenTS-reconstructed internals (exact damage step order, height lepton quantization).
- Elite Cadre cost 300 (INI) vs 350 (wiki).
- YR superweapon cooldown/runtime specifics (plausible, not independently re-derived).

## How to use this set

1. **Read this errata first.** The catalog files below it contain the known errors listed above.
2. For feature-level facts, go to the per-title catalog. For architecture decisions, go to the
   two `cross-*` files. For any number used in a spec, check `verification-*.md`.
3. The synthesized top-level docs (`docs/capability-matrix.md`, `docs/gap-analysis.md`,
   `docs/titles/*.md`) reflect these corrections; the raw catalogs may not.
