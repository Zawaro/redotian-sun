# Tiberian Sun — Feature Reference

Base game (1999) in the unified engine. Exhaustive catalogs: `docs/research/deep/ts-core.md`,
`ts-gameplay.md`, `ts-uiux.md` (+ first-pass `docs/research/_raw/ts-firestorm.md`). Content
package: `games/ts` (exists).

## Identity

- **Sides:** GDI, Nod, plus mutant/CABAL-adjacent hostiles.
- **Resources:** Tiberium — Green (Riparius), Blue (Vinifera), rare Red; Veins as
  resource/hazard.
- **Armor:** 5 classes — `none, wood, light, heavy, concrete`.
- **Theaters:** Temperate, Snow (look-only).

## Signature systems

- **Locomotors:** Foot, Track, Wheel, Hover, Amphibious, Fly, Jumpjet, Subterranean, Ship.
- **Deploy/undeploy:** MCV↔ConYard, Tick Tank, Juggernaut (FS), Limpet, sensor, EMP/stealth
  vehicles.
- **Power:** plants + low-power penalty (slowed production, disabled defenses).
- **Veterancy:** 2 levels beyond rookie, kill-ratio driven, per-unit elite abilities.
- **Shroud + fog:** two layers, shroud growth, blended fog, radar reveals.
- **Subterranean (Nod):** burrow/emerge, untargetable while underground, tunnel entrances.
- **Jumpjets (GDI):** `[JumpjetControls]`, air approach, immunity while airborne.
- **EMP:** disables mechanical targets.
- **Cloaking:** Nod stealth tank, Chameleon spy, sensor/jammer interplay.
- **Ice:** cracking + drowning.
- **Bridges:** destructible, repair huts.
- **Ion storms:** dynamic weather, disables radar/superweapons, lightning damage.
- **Crates:** money/heal/unit powerups.

## Superweapons / support powers

Ion Cannon (GDI), Multi-Missile + Chemical Missile (Nod), Hunter-Seeker drone, Drop Pods (GDI),
EMP superweapon, Firestorm Generator + Mobile EMP (FS), Mobile Stealth Generator (FS),
Laser Fence (Nod), CABAL Core Defender (FS), Veinhole monster.

## UI/UX

Right-hand tabbed sidebar (Structures/Defenses/Infantry/Vehicles/Aircraft), cameo grid, credits,
power bar, toggleable radar with events, health/condition colors, veteran pips, charge pips,
control groups, context cursors, guard/stop/scatter/deploy/capture/repair/sell/stances,
waypoints (`MaxWaypointPathLength`), factory rally.

## Campaig/scripting

Linear GDI/Nod campaigns (GDI 15 main, Nod 13 main incl. either/or branches); per-map trigger
INI (events→conditions→actions), objectives with primary/secondary, briefing FMV, `ai.ini`
TaskForces/TeamTypes/ScriptTypes, waypoints, reinforcements (land/sea/air/drop pod), cinematic
camera, trigger-driven win/lose, score screen.

## Skirmish/meta

Up to 8 players, `[AI]`/`[IQ]` skirmish AI with build ratios and difficulty gating,
`[MultiplayerDefaults]`, crates/shadow-grow/bases toggles, FS adds CABAL as a house.

## Modding

`rules.ini` / `art.ini` / `ai.ini`, list registration + section objects, `Image=` art reuse
(no general inheritance), `.map`/`.mpr` + sibling INI overrides, MIX archives, per-theater
tilesets.

## Firestorm delta

See `docs/titles/firestorm.md`.
