# Yuri's Revenge — Feature Reference

Expansion (2001) to Red Alert 2. Exhaustive catalogs: `docs/research/deep/yr-core.md`,
`yr-gameplay.md`, `yr-uiux.md` (+ first-pass `docs/research/_raw/yr.md`). Content package:
`games/yr` (new; **delta over `ra2`**).

## Model

YR ships a full replacement data baseline (`rulesmd.ini`/`artmd.ini`/`aimd.ini`), not an
overlay. In the unified engine, model it as `ra2` root + YR deltas (equivalent outcome,
simpler validation). **Target patch 1.001**, not the 1.000 mirror some sources used — that
accounts for several cost differences (e.g. Slave Miner $1750, Chaos Drone $1000, Siege
Chopper $1100).

## The Yuri faction (ThirdSide)

Identity: mind control, genetic engineering, slavery, recycling. Weak conventional air; mixed
mobility.

- **Structures:** ConYard, Bio Reactor (infantry-as-power + mind-control internment), Barracks,
  War Factory, Sub Pen, Psychic Radar (radar + attack-target reveal + spy reveal + Psychic
  Reveal), Grinder (recycle units → credits), Battle Lab, Citadel Wall, Tank Bunker (one
  garrisoned vehicle with combat bonuses), Gattling Cannon (3-stage spin-up, power-gated),
  Psychic Tower (auto mind-control up to 3), Cloning Vats (free duplicate infantry), Genetic
  Mutator (Mutation), Psychic Dominator (Domination).
- **Infantry:** Initiate, Engineer, Brute, Virus (toxic sniper), Yuri Clone, Yuri Prime
  (controls buildings, hero), Slave (from Slave Miner), Cosmonaut (campaign).
- **Vehicles:** Slave Miner (deployable economy, 5 Slaves), Lasher Light Tank, Gattling Tank,
  Chaos Drone (berserk gas), Magnetron (vehicle pull), MCV, Mastermind (controls 3, overflow
  self-destructs).
- **Aircraft:** Floating Disc (drains power / siphons credits / disables a defense).
- **Ships:** Amphibious Transport (12 slots), Boomer (torpedo + ground missiles).

## New mechanics engine-wide

- **Mind control:** temporary (warhead, capacity = `Damage`, `InfiniteMindControl` lifts cap),
  multi-target, permanent (`PsychicDominator`), immunity flags, release on death/power/overflow,
  building control by Yuri Prime, garrison blocker.
- **Garrisoning:** buildable Battle Bunker (infantry, repairable) and Tank Bunker (vehicle,
  bonuses); fire-from-transport (Battle Fortress 5 passengers fire); Bio Reactor internment.
- **Gattling weapon system:** `IsGattling`, `WeaponStages`, `WeaponCount`, `StageX`,
  `RateUp`/`RateDown` spin-up/spin-down.
- **Superweapons/support powers:** Psychic Dominator, Genetic Mutator (infantry→Brute),
  Force Shield (AoE invuln + self power-down), Psychic Reveal, Spy Plane; retained Nuke/Iron
  Curtain/Chronosphere/Weather Storm.
- **Economy:** slave-based Yuri economy, Grinder recycle, credit siphon (Floating Disc),
  Industrial Plant discount, per-country `IncomeMult`.
- **Power:** negative/drain power, power-gated mobile units (Robot Tank), forced blackout.
- **Status effects:** berserk gas, poison residue, mutation, mind control.
- **Side/country:** `ThirdSide` + `YuriCountry` (10 countries), per-country `VeteranXxx` /
  `YYYZZZMult` bonuses and per-country palettes.

## Campaign

Two campaigns only (Allied, Soviet), 7 missions each; no playable Yuri campaign. Dense
scripted ownership changes, Psychic Beacons (whole-base mind control), a lunar theater mission,
and a scripted T-Rex. `cooperative` mode token exists but no official co-op shipped.

## Skirmish/meta

Team Alliance replaces Siege; Battle/Megawealth/Land Rush/Meat Grind/Naval War retained;
10-country skirmish with side mixing; `.yrm` maps with `GameModes=` metadata.

## Unified-engine implications

YR forces these generic subsystems to be real: **control-link manager**, **garrison/occupancy**,
**staged weapon state machine**, **status-effect/aura framework**, **superweapon framework**
with convert/capture/invuln/reveal effects, **side→country→bonus registry**, and economy
**refund/siphon/modifier hooks**. See `docs/gap-analysis.md` §P1.
