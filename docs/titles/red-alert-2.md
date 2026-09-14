# Red Alert 2 — Feature Reference

Base game (2000) in the unified engine. Exhaustive catalogs:
`docs/research/deep/ra2-core.md`, `ra2-gameplay.md`, `ra2-uiux.md` (+ first-pass
`docs/research/_raw/ra2.md`). Content package: `games/ra2` (new, **independent base**).

## Identity

- **Sides / countries:** 2 sides (Allied/Soviet) across **9 countries** with unique units and
  bonuses; `[Sides]` groups countries.
- **Resources:** **Ore and Gems** (no Tiberium in gameplay; legacy tag names survive).
- **Armor:** **11 classes** — `none, flak, plate, light, medium, heavy, wood, steel, concrete,
  special_1, special_2` (vs TS's 5).
- **Storage:** no ore silos — credit storage effectively unlimited (vs TS silos).
- **Theaters:** Temperate, Snow, Urban/New Urban.

## Signature systems

- **Build categories:** internal `BuildCat` (Power/Resource/Combat/Tech) surfaced in a **4-tab**
  sidebar (Structures; Defenses + support powers; Infantry; Vehicles — the last also holds
  aircraft and naval). 6-tab layouts belong to later titles, not RA2.
- **Prerequisites:** category buckets (`POWER`/`PROC`/`FACTORY`/`BARRACKS`/`RADAR`/`TECH`)
  resolved through `[General]`, plus `RequiredHouses`/`ForbiddenHouses` for country uniques.
- **Multiple-factory bonus** (`MultipleFactory=0.8`), factory exits + rally.
- **Garrison:** infantry occupy civilian/urban buildings ("urban combat") with stat bonuses.
- **Engineer capture** of civilian/tech buildings (hospitals, airports, oil derricks).
- **Naval warfare:** shipyard, destroyers, Aegis, amphibious transport hovercraft, subs.
- **Aircraft:** Harrier, Black Eagle, Kirov, Nighthawk transport; helipad/Airforce HQ.
- **Special abilities:** spy disguise + infiltration, attack-dog detection, Tanya C4, Crazy
  Ivan timed bombs, Boris laser-designated MiG strike, Desolator radiation, Mirage disguise,
  Terror Drone parasitism.
- **Weapon modes:** IFV role changes by embarked passenger; GI/Guardian GI deploy to emplacement;
  Tesla chain; Prism refraction/support beams.
- **Chrono:** Chronosphere mass teleport, Chrono Legionnaire erasure, Chrono Miner.
- **Iron Curtain** temporary invulnerability.
- **Gap Generator** radar/shroud blackout bubble; spy satellite full-map reveal.
- **Bridge destruction/repair; ice cracking; crush (`CrusherAll`/`OmniCrusher`).**
- **Crew/survivor escape**, service depot repair + ammo reload.

## Superweapons / support powers

Chronosphere (Allied), Weather Control (lightning storm), Spy Satellite, Iron Curtain (Soviet),
Nuclear Missile; support powers: American Paradrop, Spy Plane. Each building-mounted,
`BuildLimit=1`, `RevealToAll`.

## UI/UX

4-tab sidebar, cameo grid, credits + power bars, bottom-left radar/minimap with flash events,
selection panel (portrait/health/veteran chevrons), **9 control groups**, rally, guard/formation,
waypoint planning, context cursors, health bars + pips (passengers/ammo/storage), EVA per
faction, GUI sound set, message ticker, sell/repair modes.

## Campaign/scripting

Per-side campaigns (~12 missions each); map trigger system (events→actions), primary/secondary
objectives, briefing text/voice + in-mission videos; `aimd.ini` TaskForces/TeamTypes/
`AITriggerTypes`; waypoints 0–99, reinforcements, cinematic `[CameraScripts]`, trigger win/lose,
post-game score.

## Skirmish/meta

`SmartAI` houses, difficulty (Easy/Med/Hard, optionally 5), AI economy cheats
(`AIVirtualPurifiers`), `.mpr` maps with random starts, multiplayer 2–8 players with teams,
options (credits, crates, superweapons, MCV redeploy, short game, fog, no-rush timer), 8 house
colors, `AllyReveal`.

## Modding

`rules(md).ini` + `art(md).ini` + `aimd.ini`; section objects, list registration, `Image=`
reuse (no native inheritance — Ares/Phobos add it later); `.map`/`.mpr`/`.yrm`; per-theater
tilesets; country/house system; legacy Tiberium tag names alias ore.

## Yuri's Revenge delta

See `docs/titles/yuris-revenge.md`.
