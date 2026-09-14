# Tiberian Sun — UI/UX, Presentation, Campaign & Meta: Web Research Reference

Scope: *Command & Conquer: Tiberian Sun* (Westwood, 1999) and its expansion *Firestorm*, with engine-level notes that also
apply to Red Alert 2 / Yuri's Revenge (shared codebase). This is a **web-only** reference; no game files on this machine
were read. It feeds the unified, data-driven engine in `/mnt/work2/Redot/redotian-sun` targeting TS, Firestorm, RA2 and YR.

Method: SearXNG web search + direct page reads. Primary sources: ModEnc (modding encyclopedia, rules/art/map INI semantics),
the Command & Conquer Wiki on Fandom (`cnc.fandom.com` and its mirror `cnc-central.fandom.com`), the reverse-engineered
OpenRA "Tiberian Sun" mod (cursor/faction data), the released *CNC_TS_and_RA2_Mission_Editor* source (EA open release) and
its DeepWiki, the `Vinifera-Developers/Tiberian-Sun-INIs` archive of original INI files, CnCNet/StrategyWiki/community
guides, Frank Klepacki's official site and Discogs for music. StrategyWiki returned HTTP 403 to the reader; its content is
cross-checked against community guides where possible.

Confidence legend: **high** = primary engine source or multiple independent corroborating sources; **med** = single
credible source or reconstructed from a clean-room reimplementation; **low** = community claim, single anecdote, or
inferred.

Conflict legend: where sources disagree the block carries a **Conflicts** note.

---

## A. Screens and Dialogs

### TS-UI-001 Main Menu / Shell

**What** — Full-screen shell reached at boot and via Esc→"Main Menu". Displays the animated TS title, the "Main Menu"
theme (`INTRO`, looped), and a vertical list of buttons: *New Game / Campaign*, *Load Game*, *Skirmish* (retail TS shipped
with a Skirmish and Multiplayer option), *Multiplayer / Network*, *Options*, *Intro / Cinematic replay*, *Quit*. Firestorm
adds its own shell art and `FS Menu` theme. All shell screens are 640×480-era (later re-releases/variants stretched to
1920×1080).

**Data keys** — Game mode routing; difficulty selection; save-game list. Shell art is side-mix-driven (GDI/Nod sidebar and
cameo mix files per `Side=` in ModEnc *Side*/*Sides*). Firestorm menu theme declared in `THEME01.INI`; TS in `THEME.INI`.

**Numbers** — Classic shell resolution 640×480; 8-bit palette UI; menu music `INTRO` length 3.27 min (loop). Firestorm menu
theme ~2:49.

**Edge cases** — Firestorm is a separate executable/add-on with its own menu theme and background; the mission picker only
appears once a campaign is chosen. Re-releases (Steam/Ultimate Collection) add a launcher/config step before the shell.
Startup reads `THEME.INI`; with Firestorm installed `THEME01.INI` is merged into the same INI database before the theme list
is built, so later definitions update rather than duplicate theme IDs.

**Kind** — shell / modal navigation.

**Sources** — https://cnc.fandom.com/wiki/Command_%26_Conquer:_Tiberian_Sun_soundtrack ·
https://raw.githubusercontent.com/Vinifera-Developers/Tiberian-Sun-INIs/master/THEME.INI ·
https://github.com/OpenTS-Developers/OpenTS/blob/main/manual/content/formats/theme-ini.md

**Confidence** — high (music/shell art), med (exact button ordering differs between editions).

---

### TS-UI-002 New Game / Campaign Select

**What** — Campaign selection: choose GDI campaign (*Evolutionary Response*) or Nod campaign (*Deus ex Kane*). Then a
world/region map screen shows mission nodes grouped by theatre (North America, Northern Europe, Mediterranean); completed
missions unlock successors, and optional (bonus) missions branch from the main line. Selecting a node opens a briefing
popup (EVA text + optional FMV) with an explicit objective list.

**Data keys** — Campaign/mission ID, theatre grouping, mission unlock graph, difficulty (Easy/Normal/Hard), bonus-mission
flags. Mission briefing text and objective tokens (`Objective One/Two/Three`) are per-map; map triggers gate win/lose.

**Numbers** — GDI main line: 15 missions (plus bonus missions), Nod main line: 15 missions (plus bonuses and one
either/or pair). Firestorm adds 9 missions per side. See TS-UI-130/131/132.

**Edge cases** — Nod campaign begins chronologically before GDI; one Nod slot is an either/or choice (*Capture Umagon*
Provo **or** New Detroit; *Reestablish Nod Presence* **or** *Protect Waste Convoys*). Bonus missions are optional and
skippable. Firestorm is a separate mission set launched from its own menu.

**Kind** — campaign meta / level select.

**Sources** — https://cnc.fandom.com/wiki/Category:Tiberian_Sun_GDI_missions ·
https://cnc.fandom.com/wiki/Category:Tiberian_Sun_Nod_missions · https://cnc.fandom.com/wiki/Reinforce_Phoenix_Base

**Confidence** — high.

---

### TS-UI-003 Skirmish Setup

**What** — Single-window offline-vs-AI setup. The player is always host and can set: player name, faction (GDI/Nod), colour,
map (including a built-in random-map generator), number of AI opponents, AI difficulty per opponent, starting credits,
crates on/off, "No baddy crates", Short Game, Multi-Engineer, and Superweapons on/off (plus Firestorm-specific toggles such
as firestorm). Team assignments are made in the lobby list rows.

**Data keys** — "Scenario conditions": Crates, Baddy Crates, Short Game, Multi Engineer, Starting Credits, Superweapons.
Crate contents: credits, Tiberium, units, unit powerups, air strikes, area heal, global heal, booby traps. `MultiEngineer`
forces three Engineers to capture a structure instead of one.

**Numbers** — Default starting credits commonly 10,000 (editable); AI difficulty levels Easy/Normal/Hard; random map
templates; coop/skirmish saver via later patches.

**Edge cases** — Skirmish save is **not** supported in vanilla TS (only campaign saves); fan patches/CnCNet add it. Short
Game = match ends when all enemy structures are destroyed; if off, a player is only defeated when every unit/structure is
gone. Crates appear at random spots; "No baddy crates" removes harmful crates only. Multi-Engineer is a scenario condition,
not a per-building rule.

**Kind** — modal game setup.

**Sources** — https://ppmforums.com/topic-42849/explanation-of-settings-in-skirmish ·
https://tiberiansunguide.wixsite.com/tiberiansunguide/game-settings · https://cnc.fandom.com/wiki/Skirmish

**Confidence** — high.

---

### TS-UI-004 Options (Video / Audio / Controls / Game)

**What** — Pause-accessible (and shell-accessible) options tree. Top-level tabs/sections: *Video*, *Audio*, *Game Controls*
(Keyboard, Mouse, Network/Game options), *Game*, and *Multiplayer Only Keys*. Keyboard editor exposes five hotkey
categories: **Chat, Control, Interface, Selection, Team** (per tiberiansunguide). Video: resolution, brightness/gamma;
Audio: SFX/voice/music volumes, possibly subtitles/captions; Game: game speed, scroll speed, difficulty, detail level.

**Data keys** — Keyboard bindings are editable in-game and persisted to `KEYBOARD.INI` (numeric key scancodes, hard to read
by hand). Resolution, volumes, scroll rate, game speed. Campaign/Options difficulty slider feeds trigger `EASY/NORMAL/HARD`
flags (see TS-UI-133).

**Numbers** — Game default speed is 15 FPS tick logic (many trigger/INI times are "seconds at default game speed"); campaign
difficulty has Easy/Normal/Hard.

**Edge cases** — In online multiplayer the game is **not** paused while editing hotkeys (it keeps running), unlike a
solitary skirmish. Some keys are hard-wired and not assignable (community reports cite Q, Ctrl, Alt). The Steam re-release
had a period of "missing hotkey options" relative to original.

**Kind** — modal configuration.

**Sources** — https://tiberiansunguide.wixsite.com/tiberiansunguide/hotkeys ·
https://steamcommunity.com/app/2229880/discussions/0/600764072244295183

**Confidence** — high (categories), med (exact tab naming).

---

### TS-UI-005 Load / Save Dialog

**What** — Campaign save/load list with save slots (thumbnails/screenshot + mission name + date); supports save, load and
delete. Accessible from the shell and from the in-game menu. It is a Windows-dialog-like modal inside the shell.

**Data keys** — Save file per slot; mission ID; game state (all units/structures, tiberium, triggers, variables, timers).
Original TS patches added "Save, Load, and Delete" from the options/keyboard context; later re-releases added quick-save
hotkeys (e.g. Ctrl+S / Ctrl+L, commonly remapped).

**Numbers** — Save slot count in the shell list (scrollable); file sizes grow with map complexity.

**Edge cases** — Vanilla skirmish/multiplayer progress cannot be saved; only campaign (and patched skirmish) can. Loading a
save during an online session and then toggling the in-game Information Panel can crash the game (community-reported).

**Kind** — modal persistence UI.

**Sources** — https://groups.google.com/g/alt.games.tiberian-sun/c/_k9fdRxgmCw ·
https://tiberiansunguide.wixsite.com/tiberiansunguide/hotkeys

**Confidence** — med.

---

### TS-UI-006 In-Game Pause / Game Menu

**What** — Pressing Esc during a solo game pauses and opens the in-game menu: *Resume*, *Options*, *Restart*, *Load/Save*,
*Abort Mission / Surrender* (in campaign it aborts to the shell; in multiplayer it offers Surrender/Abort), *Main Menu*.
Multiplayer pause menu differs (no pause; has surrender/abort and chat).

**Data keys** — Menu actions routed to game state; "Abort" vs "Surrender" semantics. Mission `Lose` action/`Force End` can
also end the game from triggers (TS-UI-133).

**Numbers** — n/a.

**Edge cases** — Multiplayer does not pause; the menu shows resign options. Alt+F4 is a common community workaround to
abort. In 2022+ CnCNet discussion, quit semantics (Abort vs Surrender) are a recurring complaint.

**Kind** — modal pause.

**Sources** — https://forums.cncnet.org/topic/12235-hotkeys-ts · https://modenc.renegadeprojects.com/Actions_(maps)/TSFS

**Confidence** — high.

---

### TS-UI-007 Briefing Screen

**What** — Per-mission briefing presented either as an in-engine overlay over the world map or as an FMV with EVA voice plus
an objective list. The in-game radar/minimap window doubles as a video screen for in-engine story beats during missions
(Action "Play Ingame Movie", and the radar as an "in-game video screen" per the Sidebar article).

**Data keys** — `[Briefing]` / `[Digest]` map sections (ModEnc lists a `[Briefing]` section), per-mission FMV ID, objective
strings, EVA briefing audio. `tutorial.ini` provides indexed text strings shown by Action 11 "Text Trigger".

**Numbers** — Each mission lists 2–3 explicit objectives (`Objective One/Two/Three`).

**Edge cases** — Some briefings are pure text; others are FMV. Firestorm mission briefings reference CABAL. Objectives can
change mid-mission (triggered by events) and can be added by reinforcements/events.

**Kind** — pre-mission narrative overlay.

**Sources** — https://modenc.renegadeprojects.com/Triggers · https://cnc.fandom.com/wiki/Reinforce_Phoenix_Base ·
https://cnc.fandom.com/wiki/Weather_the_Storm

**Confidence** — med.

---

### TS-UI-008 Score Screen / Post-Game

**What** — End-of-match results screen showing per-player statistics (units built/lost, structures built/lost, credits
harvested, kills, etc.), used in multiplayer/skirmish and after campaign missions. Shell/`Score Screen` music theme plays.

**Data keys** — Player stats aggregation; `Score` theme (`SCORE`, normal=no, repeat=yes). The "score screen" is also the
subject of community mods that replace its art.

**Numbers** — n/a (per-match).

**Edge cases** — Campaign missions typically show a mission-complete FMV/score; skirmish shows the multiplayer scoreboard.
Community "Giants Super PRO" replacements exist for the 1920×1080 loading/score art.

**Kind** — post-game modal.

**Sources** — https://raw.githubusercontent.com/Vinifera-Developers/Tiberian-Sun-INIs/master/THEME.INI ·
https://forums.cncnet.org/topic/12582-new-loading-screen-for-resolution-1920x1080-and-giants-sidebar-2023

**Confidence** — med.

---

### TS-UI-009 Quit / Confirmation Dialog

**What** — Standard confirm dialog ("Are you sure?") for Quit and for destructive actions (surrender/abort, deleting a save,
overwriting a save).

**Data keys** — n/a.

**Numbers** — n/a.

**Edge cases** — Alt+F4 bypasses the dialog and is a known "instant quit" used online.

**Kind** — modal confirm.

**Sources** — https://forums.cncnet.org/topic/12235-hotkeys-ts

**Confidence** — low/med.

---

### TS-UI-010 World Map / Mission Picker (campaign meta)

**What** — Post-briefing strategic map showing the current theatre and available mission node(s). Missions are grouped under
regional headers (North America, Northern Europe, Mediterranean). Completing a node reveals the next; optional missions
appear off the main chain.

**Data keys** — Node graph per campaign; theatre strings; completion flags.

**Numbers** — GDI: NA (6 main + bonuses), NE (6), Mediterranean (3). Nod: Mediterranean (4), NA (4 + either/or), NE (5 +
either/or). Counts from the two category pages.

**Edge cases** — Some nodes are mutually exclusive; the world map may not show a bonus mission until its prerequisite fires.

**Kind** — campaign meta screen.

**Sources** — https://cnc.fandom.com/wiki/Category:Tiberian_Sun_GDI_missions ·
https://cnc.fandom.com/wiki/Category:Tiberian_Sun_Nod_missions

**Confidence** — high.

---

### TS-UI-011 Multiplayer / Network Lobby

**What** — CnCNet/Westwood Online-style lobby: player list with faction/colour/team/ready status, chat pane, game options,
map selection, and start. "Grant Control / Shared Control" is a lobby option enabling allied unit control hotkeys in-game.

**Data keys** — Player/team/faction/colour, game options, shared-control flag, chat channels (all/allies/individual player).
`F4` in the game lobby quickly adds AI units; in the main lobby `F4` toggles "away".

**Numbers** — Team colours (e.g., blue/red/yellow/green/etc. per game), up to 8 players (classic).

**Edge cases** — Hotkey edits are not paused in online play. "Page user" hotkey does not work during a match; F1–F8 are
chat to individual/all players instead. CnCNet replaces the retired Westwood Online service.

**Kind** — networked modal lobby.

**Sources** — https://tiberiansunguide.wixsite.com/tiberiansunguide/hotkeys · https://cnc.fandom.com/wiki/Vanilla_Conquer

**Confidence** — med.

---

### TS-UI-012 Map Selection / Random Map Generator

**What** — Skirmish/multiplayer map picker showing map thumbnails (`[Preview]` / `[PreviewPack]`), size, and player count.
TS/RA2 integrate a **random map generator** (in the skirmish and multiplayer modes) that synthesises terrain on demand.

**Data keys** — `[Preview]`/`[PreviewPack]` map INI sections; map section `[Map]`; random-map parameters. "Map Selection"
theme (`MAPS`, normal=no, repeat=yes) plays in the picker.

**Numbers** — Random map size dialogs (community "make a random map with the editor; use the 1.13 version to make the map"
notes). TS map preview thumbnails.

**Edge cases** — Random maps may be impossible to regenerate identically; some terrain/trigger features aren't generated.
"FinalSun" is the TS map editor (data files `FSData.ini`, `FSLanguage.ini`).

**Kind** — modal map browser.

**Sources** — https://cnc.fandom.com/wiki/Skirmish · https://modenc.renegadeprojects.com/Triggers ·
https://deepwiki.com/electronicarts/CNC_TS_and_RA2_Mission_Editor/5.2-finalsun-data-(fsdata.ini-fslanguage.ini)

**Confidence** — high.

---

## B. In-Game HUD

### TS-UI-020 Sidebar Layout and Tabs

**What** — Vertical right-edge command bar. Top-to-bottom in the classic TS layout: credits counter, radar/minimap screen
(if radar building present and powered; otherwise faction logo), repair button (wrench), sell button (dollar), building
queue, defence/unit list, power meter on the far left edge. TS was the **last** C&C to keep a single combined unit list;
RA2 introduced four tabs (Buildings, Defences+Support, Infantry, Vehicles) selectable with Q/W/E/R. Vinifera (open TS
extension) back-ports RA2-style tabs to TS.

**Data keys** — Sidebar mix files: `sidec01.mix` (GDI), `sidec02.mix` (Nod), `sidec03.mix` (RA2/YR third side). Cameo
charging indicator `gclock2.shp` from the side's mix, palette `sidebar.pal`. `Side=` in `[Sides]`. Vinifera adds tab
configuration/defence-tab heuristics.

**Numbers** — Cameo size 64×48 px (TS), 60×48 (RA2/YR); `gclock2.shp` charging overlay should have 55 frames (modders
report breakage otherwise); sidebar can be scrolled by mouse wheel; TS is 200/800/… list scrolling.

**Edge cases** — The sidebar can be toggled on/off (RA1 allowed it; TS/RA2 family use it constantly). Buildings block other
building buttons while constructing, units do not (unit queue can hold multiple types). Vinifera groups base defences in
the building tab "in the absence of a dedicated Defense tab".

**Kind** — persistent HUD panel.

**Sources** — https://cnc.fandom.com/wiki/Sidebar · https://modenc.renegadeprojects.com/Cameo_Charging_Indicator ·
https://vinifera.readthedocs.io/en/latest/User-Interface.html · https://modenc.renegadeprojects.com/Sides

**Confidence** — high.

---

### TS-UI-021 Cameo Grid and Scrolling

**What** — Grid of square "cameos" (sidebar images) representing buildable buildings/units. Each cameo is an SHP named by
the `Cameo=` art flag (extension `.SHP` assumed; `XXICON` used as fallback). Hovering shows a tooltip; clicking starts
production. Scroll via wheel, arrow buttons, Page Up/Down and the structure/unit list scroll hotkeys.

**Data keys** — Art flag `Cameo=` (filename, case-insensitive); `AltCameo=` for the alternate (usually deployed) form;
`UIName=` display string; `Name=` internal ID; `Image=` art mapping. Prerequisite system controls visibility.

**Numbers** — TS cameo 64×48; RA2/YR 60×48; RA2 tolerates 64×48 and 64×64. Fallback cameo file `XXICON`.

**Edge cases** — Missing/misnamed cameo silently falls back to XXICON. Deployed vs undeployed vehicles have different
cameos (`AltCameo`). `T` (select same type) treats deployed and undeployed vehicles as different types.

**Kind** — HUD widget grid.

**Sources** — https://modenc.renegadeprojects.com/Cameo · https://modenc.renegadeprojects.com/Cameo_Charging_Indicator

**Confidence** — high.

---

### TS-UI-022 Per-Cameo States

**What** — States a cameo can be in: (a) **not yet available/greyed** (prerequisites unmet or tech level too low);
(b) **available** (clickable, full colour); (c) **building/clocking** (darkened with the `gclock2.shp` percentage-complete
radial animation overlaid, counts down radially); (d) **on hold / paused** (queue paused, often with a hold marker);
(e) **ready / "READY"** (finished building/unit awaiting placement/deploy — highlighted text, click then place);
(f) **insufficient funds** (cost shown in red / click triggers EVA "Insufficient funds" and refuses); (g) **unable to
build more** (queue full or cap reached; EVA "Unable to build more").

**Data keys** — `gclock2.shp` (55 frames, charging overlay) + `sidebar.pal`; queue length key
`[General] MaximumQueuedObjects` (adds only to non-building training queues, **plus one additional slot**); `Cost=`;
prerequisite/tier keys.

**Numbers** — `MaximumQueuedObjects` default 0 (value is "maximum queued + 1"); TS community default/known value is 5 for
infantry/vehicles/aircraft (queue of 5, editable); RA2 raised the unit queue to 30.

**Edge cases** — Buildings are never queued more than one at a time (`MaximumQueuedObjects` does not apply to BuildingTypes).
Selecting a unit for construction does not lock other unit buttons (unlike buildings). Credit drain is continuous while
building; cancelling refunds progressively. Hold/unhold: "Repeat Build" can unhold a paused building but cannot pause a
building still under construction. "Wrong1"/"WRONG1" sound plays when the build queue is full.

**Kind** — HUD state machine.

**Sources** — https://modenc.renegadeprojects.com/MaximumQueuedObjects · https://modenc.renegadeprojects.com/Cameo \
https://cnc.fandom.com/wiki/Sidebar · https://cnc.fandom.com/wiki/Electronic_Video_Agent

**Confidence** — high (keys/states), med (exact TS default queue = 5).

---

### TS-UI-023 Queue Display

**What** — Below/around the sidebar, the active production queues are represented by cameos: a building being built shows
under the building list, units group-by-type in the unit queue. Multiple unit types can be queued in order; the first
factory type to finish produces the next unit, and more factories speed production. Primary-building concept: the first
producing structure is "primary" and receives newly queued units (used for rallying).

**Data keys** — `MaximumQueuedObjects`; per-factory production; "Repeat Building" hotkey re-queues the same structure;
rally point (Ctrl+Alt+click) on a production building.

**Numbers** — TS queue per type = 5 (editable); `MaximumQueuedObjects` adds one extra slot beyond the configured number
(i.e., value 5 → 6 slots including the in-progress one, per ModEnc wording).

**Edge cases** — Buildings: choosing one disables other building buttons until done. Units: selecting a new unit while one
is building is allowed (multi-type queue). A full queue plays the "wrong" sound and EVA "Unable to build more". Vinifera
adds shift-queueing to append orders.

**Kind** — HUD production feedback.

**Sources** — https://modenc.renegadeprojects.com/MaximumQueuedObjects · https://cnc.fandom.com/wiki/Sidebar \
https://moddb.com/mods/tiberian-sun-rubicon/videos/sidebar-improvements-tabs-queuing-descriptions

**Confidence** — high.

---

### TS-UI-024 Credits Counter

**What** — Numeric credits readout at the top of the sidebar, ticking as harvesters offload and as construction drains it.
Positive/negative ticks play distinct sounds.

**Data keys** — Per-player credits (EconomyManager equivalent); `[General]` starting credits; refinery/silo storage
(`Storage=`, `TiberiumStorage` style); `Credit transfer` mechanic. `CREDUP1` (positive), `CREDDWN1` (negative) sounds.

**Numbers** — Starting credits commonly 10,000 (skirmish editable). Refinery/silo internal storage caps affect when
unloading pauses.

**Edge cases** — "Insufficient funds" EVA fires when a build/repair can't be afforded; repair halts if credits run out
(e.g., Service Depot repairs stop until credits return). Selling refunds a fraction of cost. Cash tick sound spams under
heavy income.

**Kind** — HUD numeric widget.

**Sources** — https://cnc.fandom.com/wiki/Sidebar · https://cnc.fandom.com/wiki/Service_depot_(Tiberian_Sun) ·
https://raw.githubusercontent.com/Vinifera-Developers/Tiberian-Sun-INIs/master/SOUND.INI

**Confidence** — high.

---

### TS-UI-025 Power Bar

**What** — Thin vertical meter on the far-left edge of the sidebar. Shows power supply (green/yellow) versus demand (red
rises over it). When red exceeds supply the base is "low power": production of units/buildings slows significantly and
some structures (radar, stealth generator, defensive turrets) go offline. EVA warns "Low power"/"Insufficient power".

**Data keys** — `Power=`/`Power output` per building, `[General]` power constants, `ProducesPower`; low-power state; super
weapon/turret disable rules. Power-down/power-up of individual buildings via "Power Mode" hotkey.

**Numbers** — Meter is a discrete series of lights; exact light count is HUD-art dependent.

**Edge cases** — Low power can be partial (some structures off, others functional). Power turbines/advanced power plants
raise supply. In RA2/YR the bar becomes red/green only; TS keeps the three-colour supply/demand meter. Ion storms and
certain weapons can affect power.

**Kind** — HUD meter + gameplay state.

**Sources** — https://cnc.fandom.com/wiki/Sidebar · https://raw.githubusercontent.com/Vinifera-Developers/Tiberian-Sun-INIs/master/SOUND.INI

**Confidence** — high.

---

### TS-UI-026 Repair and Sell Buttons

**What** — Repair (wrench) and Sell (dollar) buttons sit above the build lists. Repair switches the cursor to a wrench;
friendly damaged buildings clicked slowly auto-repair, draining credits per HP, with a wrench icon floating over the
building. Sell switches to the sell cursor; clicking a friendly building deconstructs it and refunds part of its cost.

**Data keys** — Repair cursor (`goldwrench.shp`/`repair`), sell cursor (`sell`); per-HP repair cost; sell refund fraction;
`RepairSell=` AI logic; `ConditionRed` triggers auto-repair for area-guard engineers.

**Numbers** — Repair cost per HP and sell refund percentage are rules values (fraction of cost). Repair icon floats until
full health.

**Edge cases** — Repairs stop if credits run out. Engineers can fully repair a building (golden wrench cursor) and repair
bridges at repair huts. Selling can be a tactical "sell to deny capture". Condition red forces occupants out and triggers
engineer auto-repair behaviour.

**Kind** — HUD mode buttons.

**Sources** — https://cnc.fandom.com/wiki/Sidebar · https://modenc.renegadeprojects.com/ConditionRed \
https://modenc.renegadeprojects.com/Cameo_Charging_Indicator

**Confidence** — high.

---

### TS-UI-027 Lower Bar / Selected-Unit Information Panel

**What** — TS/RA2 keep the sidebar rather than a bottom bar, but add informational surfaces: on-screen selection brackets,
floating health bars and a togglable **Information Panel** at the bottom of the sidebar with three pages. Page 1: game
timer, FPS, APM, EFF, Showkey, Space. Page 2: unit type, HP, speed, weapon, weapon bonus, armour type, armour bonus,
veteran. Page 3: network/RH/loss statistics. The info panel covers some build options and should be toggled off most of
the time.

**Data keys** — InfoPanel toggle hotkey; page counters (3 pages); game timer; network stats. Selected-object info derives
from `Strength`, `Armor`, weapon data, `VeteranAbilities`/`EliteAbilities`.

**Numbers** — 3 info pages; APM/EFF derived stats.

**Edge cases** — Loading a save in an online session then enabling the InfoPanel can crash (community-reported). The panel
overlays cameos.

**Kind** — HUD diagnostic panel.

**Sources** — https://tiberiansunguide.wixsite.com/tiberiansunguide/hotkeys

**Confidence** — med.

---

### TS-UI-028 Message Ticker / Chat Overlay

**What** — On-screen text messages (EVA mission text, tutorial strings, multiplayer chat) appear as a ticker/overlay;
chat has a configurable text background colour; Enter = chat all, Backspace = chat allies, F1–F8 = chat specific players.

**Data keys** — `tutorial.ini` indexed strings (Action 11 "Text Trigger"); chat background colour setting; per-player chat
keys.

**Numbers** — n/a.

**Edge cases** — "Page user" does not work during a match; F1–F7 chat individual players, F8 chat all (FN may be needed on
laptops).

**Kind** — HUD text overlay.

**Sources** — https://tiberiansunguide.wixsite.com/tiberiansunguide/hotkeys · https://modenc.renegadeprojects.com/Actions_(maps)/TSFS

**Confidence** — med.

---

## C. Radar / Minimap

### TS-UI-040 Radar and Minimap

**What** — Square minimap at the top of the sidebar. If the player owns a powered radar structure, it shows explored
terrain, structures, units (colour-coded per player/ally/enemy), Tiberium and topography; a click moves the camera.
If radar is absent/unpowered, the minimap is replaced by the faction logo. The radar also serves as an in-engine video
screen for story beats. A radar toggle hotkey exists (commonly Tab) and community reports say Tab toggles radar/map.

**Data keys** — Radar building (e.g., `GARADR`/`NARADR`) + power; `RadarInvisible=` (objects hidden from radar);
`[RadarEvent]` types (Action 55 "Create Radar Event" takes a Radar Event type + waypoint); `RadarColor`/team colour.
Goto-radar-event hotkey (commonly V).

**Numbers** — Radar zoom levels (Action 39 "Change Zoom Level": 1 normal, 2 zoomed out); cursor minimap hotspots use
dedicated minimap cursor frames.

**Edge cases** — Radar is disabled during an Ion Storm (no minimap, no air, hover units grounded). Stealth/cloaked units
and `RadarInvisible` objects do not appear. Destroying the radar structure drops the sidebar to the faction logo. Player
can toggle minimap/score with Tab in some contexts (community). "Grow shroud"/"Reshroud Map" actions affect what the
minimap shows.

**Kind** — HUD minimap + gameplay system.

**Sources** — https://cnc.fandom.com/wiki/Sidebar · https://modenc.renegadeprojects.com/Ion_Storm \
https://modenc.renegadeprojects.com/Actions_(maps)/TSFS · https://raw.githubusercontent.com/treiber-88/OpenRA-Tiberian-Sun-/main/mods/ts/cursors.yaml

**Confidence** — high.

---

## D. Selection and Information

### TS-UI-050 Single and Box Selection

**What** — Left-click selects a single object; left-drag draws a selection box selecting multiple friendly units/
structures within it. `E` selects all units in view. Double-click/`T` select-same-type. Shift adds to selection. Grouped
selection shows a combined set of brackets and, on hover/selection, a summary.

**Data keys** — `Selectable=` (can it be selected), `LegalTarget=`, selection limits (per-unit), `Insignificant=` (excluded
from selection/score), `[General]` selection/box constants. Selection sounds per object.

**Numbers** — Drag box picks all eligible units inside; `E` picks everything visible on screen.

**Edge cases** — `T` select-same-type only works for units currently on screen, excludes units in tunnels and underground
units (though an underground unit can seed selection of above-ground same types). It treats deployed vs undeployed as
different. It works on buildings too (e.g., all Helipads) and on allies' units under shared control. `E` may not include
allied units even with Grant Control.

**Kind** — input/selection.

**Sources** — https://tiberiansunguide.wixsite.com/tiberiansunguide/hotkeys · https://modenc.renegadeprojects.com/Sidebar

**Confidence** — high.

---

### TS-UI-051 Selection Brackets

**What** — Animated corner brackets drawn around selected objects (the `select` cursor animation, frames 18–29 of
`mouse.shp` also drive the marquee). Brackets are per-object; a health bar appears above when damaged (and always for the
pointer target / with enemy-health option).

**Data keys** — Selection overlay art; health-bar SHP (`pips.shp` frames for condition pips); `[AudioVisual]` health-bar
settings; `IsDefender=` per community note affects which units show health bars.

**Numbers** — Brackets animate; health-bar pips use `pips.shp` frames (frame 16 for yellow, 17 for red in TS-era;
17/18 in YR).

**Edge cases** — Health bar can be disabled per-object family with flags (community "IsDefender" workaround) or by editing
the SHP; modifying SHP health bars still allows online play per CnCNet discussion.

**Kind** — selection feedback overlay.

**Sources** — https://raw.githubusercontent.com/treiber-88/OpenRA-Tiberian-Sun-/main/mods/ts/cursors.yaml ·
https://modenc.renegadeprojects.com/ConditionRed · https://forums.cncnet.org/topic/12576-health-bars

**Confidence** — high (brackets), med (health-bar SHP specifics).

---

### TS-UI-052 Health Bars and Condition Colours

**What** — Floating health bars colour-code damage: green > yellow > red. Thresholds come from `[AudioVisual]`
`ConditionYellow` and `ConditionRed` (percent of `Strength`). Damaged buildings show damaged frames; in RA2/YR they also
show fire. Condition red has gameplay side effects.

**Data keys** — `[AudioVisual] ConditionYellow=` / `ConditionRed=` (percentage or float); `pips.shp` frames; damaged-art
frames; `ConditionRedSparkingProbability=`; `IsDefender=` (community); building fire animation.

**Numbers** — `ConditionRed` default **50%** (ModEnc, RA `[General]`); community TS guide lists `ConditionYellow=50` and a
lower red threshold (commonly 25%). Condition yellow/red frames in `pips.shp` are frames 16/17 (TS-YR era).

**Edge cases** — Occupants evacuate a `CanBeOccupied` building at condition red; area-guard engineers auto-repair
condition-red buildings; AI sells via `RepairSell`. **Conflict:** ModEnc's `ConditionRed` default 50% vs the community
guide's `ConditionYellow=50%`; the two thresholds are adjacent values and the TS defaults are best confirmed from the
active game's `rules.ini [AudioVisual]` before hard-coding.

**Kind** — HUD feedback + gameplay thresholds.

**Sources** — https://modenc.renegadeprojects.com/ConditionRed · https://modenc.renegadeprojects.com/ConditionYellow ·
https://tiberian.iwarp.com/editingguidetots.htm

**Confidence** — high (existence/mechanics), low (exact TS default percentages — sources conflict).

---

### TS-UI-053 Veteran Pips

**What** — Units gain veterancy by kills; a pip (chevron) row grows as the unit levels. TS has three ranks: Rookie (0
pips), Veteran (1), Elite (2). Veterancy increases health/damage/rate of fire and can unlock `VeteranAbilities`/
`EliteAbilities` (e.g., self-heal, more ammo, faster reload).

**Data keys** — `VeteranAbilities`/`EliteAbilities` lists; `VeteranRatio=`/veterancy thresholds; `pips.shp` veteran pip
frames; `VETERAN` animation (frame index 64 in the TS `[Animations]` array) plays on promotion.

**Numbers** — Per-community data, each rank ≈ +20% rate of fire and +10% damage; health +20% at rank 1, +10% at rank 2,
+20% at rank 3 (Fandom Veterancy). Max 2 pips in TS.

**Edge cases** — Elite units can gain self-repair to the "first bit of green" health (community). Veterancy pip art shares
`pips.shp` with condition pips, which is a common modding confusion. InfoPanel page 2 shows veteran status.

**Kind** — HUD pips + progression.

**Sources** — https://cnc.fandom.com/wiki/Veterancy · https://modenc.renegadeprojects.com/Animations \
https://tiberiansunguide.wixsite.com/tiberiansunguide/hotkeys

**Confidence** — high (mechanics), med (exact percentages).

---

### TS-UI-054 Charge / Timer Pips

**What** — Superweapons and charged abilities (Ion Cannon, EMP, Firestorm, Nod Missile, Hunter-Seeker) display a charging
overlay on their cameo/button; some show a numeric or radial timer. Charging uses the same percentage overlay concept as
production.

**Data keys** — Super weapon charge time; `ShowTimer`; `gclock2.shp` radial overlay; Action 33/34 "Add 1-time / repeating
super weapon".

**Numbers** — Charge times are mission/rules values; the charging SHP uses 55 frames.

**Edge cases** — Superweapons can be granted by triggers (one-time or repeating) and targeted at a `[QuarryTypes]` preferred
target (Action 35). Ion storm delays/changes some abilities.

**Kind** — HUD charge indicator.

**Sources** — https://modenc.renegadeprojects.com/Cameo_Charging_Indicator · https://modenc.renegadeprojects.com/Actions_(maps)/TSFS

**Confidence** — med.

---

### TS-UI-055 Passenger / Cargo Pips

**What** — Transports and harvesters show occupancy/cargo indicators. TS uses `PipScale=`/`PipsDraw`-style art and
`pips.shp` for passenger/cargo pips; harvesters show Tiberium fill via their cargo art.

**Data keys** — `Passengers=` (capacity), `PipScale=`, `pips.shp` pip frames, `Storage=`/`TiberiumStorage` for harvester
fill, `Gunner=`/`OpenTransport` semantics. Loading uses the blue "enter" cursor; unloading uses the "deploy" cursor.

**Numbers** — Amphibious APC carries 5 infantry (manual); other capacities are rules values.

**Edge cases** — An APC cannot unload while in water. `T` treats deployed/undeployed differently. Passenger pips differ by
pip scale/config; some objects draw pips per-slot differently than per-unit.

**Kind** — HUD pips.

**Sources** — https://cnc.fandom.com/wiki/Command_%26_Conquer:_Tiberian_Sun_manual · https://modenc.renegadeprojects.com/ParticleSystems

**Confidence** — med.

---

### TS-UI-056 Enemy Health Bar Option

**What** — TS shows health bars on hovered/selected enemies according to the `[AudioVisual]` settings; community discussion
covers whether enemy health bars are always shown or need a flag, and how to make them larger/clearer via `pips.shp`
edits or `IsDefender=`.

**Data keys** — Health-bar art and `[AudioVisual]` health-bar flags; `IsDefender=` workaround.

**Numbers** — n/a.

**Edge cases** — Modifying health-bar SHP is compatible with online play (CnCNet). The exact vanilla toggle for enemy bars
is a known community pain point.

**Kind** — HUD option/feedback.

**Sources** — https://forums.cncnet.org/topic/12576-health-bars

**Confidence** — low/med.

---

## E. Full Control Scheme

### TS-UI-060 Default Hotkeys and Assignable Actions

**What** — TS hotkeys are fully rebindable in Options → Game Controls → Keyboard, split into five categories (Chat,
Control, Interface, Selection, Team). A handful of keys are reportedly hard-wired (Q, Ctrl, Alt in community testing).
Pressing Space shows the current hotkey overlay. The table below lists the action set and the commonly-attested default
where one exists; keys in this table marked *assignable* may ship unbound or differ by edition.

| Category | Action | Common default | Notes |
|---|---|---|---|
| Chat | Chat to all | Enter | |
| Chat | Chat to allies | Backspace | |
| Chat | Chat to player | F1–F7 (F8 = all) | Page-user disabled in-match |
| Chat | Chat background colour | — | cosmetic |
| Control | Alliance | A | propose alliance |
| Control | Deploy object | D | MCV/APC/unit deploy |
| Control | Grant control | (unbound) | needs Shared Control lobby option |
| Control | Guard | G | units auto-engage near targets |
| Control | Scatter | X | only when stopped |
| Control | Select one less unit | (unbound) | micro trick |
| Control | Stop object | S | also works on Laser/Obelisk/Vulcan/RPG upgrades |
| Interface | Delete waypoint | Delete | |
| Interface | Follow | F | camera follows unit; Ctrl+Alt+click = follow target |
| Interface | Goto radar event | V | jumps to last radar event |
| Interface | Options menu | Esc | pause / game menu |
| Interface | Place building | (assignable) | fast placement |
| Interface | Power mode | P | toggle building power |
| Interface | Radar toggle | Tab | |
| Interface | Repair mode | (assignable) | |
| Interface | Repeat building | (assignable) | re-queues last structure |
| Interface | Screen capture | Ctrl+C | screenshot |
| Interface | Scroll N/S/E/W | (assignable) | slow |
| Interface | Sell mode | (assignable) | |
| Interface | Set bookmark 1–4 | (assignable) | map camera bookmarks |
| Interface | Sidebar up/down/page | PageUp/PageDown | |
| Interface | Structure list up/down/page | (assignable) | |
| Interface | Toggle help | Space | shows hotkeys |
| Interface | Toggle info panel | (e.g. M) | 3 pages |
| Interface | Unit list up/down/page | (assignable) | |
| Interface | View bookmark 1–4 | (assignable) | |
| Interface | Waypoint mode | W | click map to chain |
| Selection | Center base | H | |
| Selection | Center view | Num+5 | |
| Selection | Next / previous object | N/B | cycles units |
| Selection | Select same type | T | on-screen only |
| Selection | Select view (all on screen) | E | |
| Team | Create team 1–10 | Ctrl+0–9 | |
| Team | Add to team 1–10 | Shift+0–9 (or Shift+click) | |
| Team | Select team 1–10 | 0–9 | |
| Team | Center team 1–10 | Alt+0–9 | |
| Selection | Save camera location F9–F12 | Ctrl+F9–F12 | community guide |
| Multiplayer | Ask alliance | A | as above |
| General | Toggle score/map | Tab | community |

**Data keys** — Bindings persisted in `KEYBOARD.INI` (scancode ints); hard-wired keys. `[General]` game speed.

**Numbers** — 5 hotkey categories; 10 control groups.

**Edge cases / conflicts** — Community guides disagree on several defaults (e.g., Ctrl+click = force-fire/attack-ground,
Alt+click = move-as-close-as-possible, Shift+click = patrol, Ctrl+Alt+click = rally point). **Vanilla TS has no true
attack-move**; "attack-move" (Q+click or Ctrl+Shift+click) is a RA2 behaviour commonly ported by community patches/OpenTS.
Treat the table's defaults as *likely* and rebind-test against the running build; the authoritative artefact is the action
list, not the key letters.

**Kind** — input mapping catalog.

**Sources** — https://tiberiansunguide.wixsite.com/tiberiansunguide/hotkeys · https://www.magicgameworld.com/controls-for-command-conquer-tiberian-sun-and-firestorm ·
https://steamcommunity.com/app/2229880/discussions/0/4293690852343110961 · https://forums.cncnet.org/topic/12054-tiberian-sun-hotkeys-tutorial-beginners-guide ·
https://www.moddb.com/games/cc-tiberian-sun/addons/opents-based-attack-move-for-tiberian-sun

**Confidence** — high (action categories/existence), low/med (individual key letters).

---

### TS-UI-061 Control Groups

**What** — Ten numbered groups. Ctrl+number creates a group from the current selection; number selects it; Alt+number
centres the camera; Shift+number (or Shift+click) adds to an existing group. Groups can hold units or buildings.

**Data keys** — Per-player group table (10 slots); group number bindings.

**Numbers** — 10 groups (0–9).

**Edge cases** — Adding to a team with Shift; `T` select-same-type ignores groups. Mixed deployed/undeployed units may
separate by type. "Select one less unit" is used to peel one unit off a group.

**Kind** — input management.

**Sources** — https://tiberiansunguide.wixsite.com/tiberiansunguide/hotkeys · https://www.magicgameworld.com/controls-for-command-conquer-tiberian-sun-and-firestorm

**Confidence** — high.

---

### TS-UI-062 Camera Controls

**What** — Edge-scroll by pushing the pointer to the screen edge; fast scroll by dragging with the right mouse button held;
small on-screen scroll arrows change direction without moving the pointer. Camera can be centred on base (H), on a group
(Alt+number), on a bookmark (Ctrl+F9–F12 set, view bookmark to recall), followed (F). `Num+5` centres view. Scroll
N/S/E/W hotkeys exist. The minimap click jumps the camera.

**Data keys** — Scroll speed option; bookmark slots (4); `[Map] LocalSize=`/Action 40 "Resize Player View" for cutscene
framing.

**Numbers** — 4 map bookmarks; scroll speed configurable.

**Edge cases** — "Follow" toggles; Ctrl+Alt+click makes one unit follow another. Cinematic missions lock/steer the camera
via triggers (Action 48 "Center Camera at waypoint" with speed 0–4).

**Kind** — camera input.

**Sources** — https://tiberiansunguide.wixsite.com/tiberiansunguide/hotkeys · https://modenc.renegadeprojects.com/Actions_(maps)/TSFS

**Confidence** — high.

---

### TS-UI-063 Right vs Left Click Semantics

**What** — Left click = select / act: select objects, issue move/attack orders, start production, place buildings. Right
click = deselect / cancel: clears the selection, cancels a mode (repair/sell/power), aborts a building placement, cancels
production in some contexts. **No unit command is ever issued on right click.** Dragging with the right button fast-scrolls.

**Data keys** — Modal cursors (repair, sell, power); placement mode; selection manager.

**Numbers** — n/a.

**Edge cases** — Some later RTS conventions reverse this; TS is fixed. Right-drag scroll vs right-click cancel can be
confused under fast input (community bug reports about clicks "not registering"). See TS-UI-070 for cursor transitions.

**Kind** — input semantics.

**Sources** — https://forums.cncnet.org/topic/5939-mouse-issue · https://tiberiansunguide.wixsite.com/tiberiansunguide/hotkeys

**Confidence** — high.

---

### TS-UI-064 Stances and Orders

**What** — Order/stance set: move, attack, guard (G), stop (S), scatter (X), deploy/undeploy (D), capture (engineer),
repair (engineer/service depot), sell, waypoint, patrol (patrol routes commonly Shift+click), force-fire/attack-ground
(Ctrl+click), attack-move (patched only), rally point (Ctrl+Alt+click). "Guard" makes units auto-attack nearby valid
targets; area-guard (Ctrl+Alt in some builds) makes engineers auto-repair.

**Data keys** — `Guard`/`Area_guard`, `Scatter`, `Deploy`/`Undeploy`, `Capture`, `Repair`, `Sell`, `Patrol`, `RallyPoint`,
`Flee`, `Hunt`, `Sleep`/`Harmless` (broken by trigger Actions 81–83 "Wakeup Self / All Sleepers / All Harmless"),
`IonSensitive` weapons disabled in storms.

**Numbers** — Waypoint chain length (community planning limits; "waypoint length" is a per-map/engine cap — see TS-UI-065).

**Edge cases** — Scatter only works when units are stopped (stop then scatter). Deploy hotkey doubles for MCV; `T`
select-same-type treats deployed/undeployed as separate. Trigger Actions 6 "All to Hunt", 5 "Destroy Team", 81–84 wakeup
actions drive AI stance externally.

**Kind** — command/order system.

**Sources** — https://tiberiansunguide.wixsite.com/tiberiansunguide/hotkeys · https://modenc.renegadeprojects.com/Actions_(maps)/TSFS

**Confidence** — high.

---

### TS-UI-065 Waypoints and Planning Mode

**What** — Waypoint mode (W) lets the player queue a multi-segment movement path by clicking successive points; clicking
again or pressing W exits; Delete removes a waypoint. There is a hard cap on simultaneous waypoints/movement planning
length per unit or per player (community planning limit).

**Data keys** — Waypoint mode toggle; waypoint delete; `[Waypoints]` map section (0–702 waypoints in TS; 0–255 in RA2 for
editor parameter lists); trigger Actions/Events reference waypoint indices.

**Numbers** — TS map waypoint index space 0–702 (per Mission Editor param population); RA2 0–255. Movement-planning chain
length is engine-limited (community).

**Edge cases** — Waypoints are also map data (spawn points for reinforcements/AI). `T` ignores units inside tunnels; waypoint
chains can be exploited for patrol loops (an "air unit patrol over water" example in a CnCNet post). Trigger event 34
"Comes near waypoint" uses 5-cell (1280 lepton) proximity.

**Kind** — planning input + map data.

**Sources** — https://deepwiki.com/electronicarts/CNC_TS_and_RA2_Mission_Editor/2.6-trigger-and-scripting-system ·
https://tiberiansunguide.wixsite.com/tiberiansunguide/hotkeys · https://modenc.renegadeprojects.com/Events/TSFS

**Confidence** — high (existence), low (exact chain cap).

---

### TS-UI-066 Keyboard Configuration Screen

**What** — The rebinding UI: Options → Game Controls → Keyboard, listing the five categories with rows of action/current
key and a "press a key" capture. Bindings are stored in `KEYBOARD.INI`; changing them mid-online-game does not pause play.

**Data keys** — `KEYBOARD.INI` scancode bindings; hard-wired keys; five category groups.

**Numbers** — 10 team slots × several team actions; 4 bookmarks; page/scroll actions per list.

**Edge cases** — Scancodes make hand-editing `KEYBOARD.INI` unintuitive. Steam re-release temporarily lacked some rebind
options. Some keys (Q/Ctrl/Alt) cannot be reassigned.

**Kind** — configuration UI.

**Sources** — https://steamcommunity.com/app/2229880/discussions/0/600764072244295183 ·
https://tiberiansunguide.wixsite.com/tiberiansunguide/hotkeys

**Confidence** — high.

---

## F. Cursors

### TS-UI-070 Cursor State Catalog

**What** — Every cursor is an animated SHP sequence in `mouse.shp` (and auxiliary `attackmove.shp`, `assaultmove.shp`),
driven by the current action/target/validity. Notable families: default pointer, edge-scroll arrows (8 dirs) plus blocked
variants, selection, move (valid/rough/blocked), attack, attack-outside-range, harvest, enter/capture, C4, guard, heal,
ability, deploy/undeploy, gold wrench (engineer repair), ion cannon, nuke, EMP, sell, repair, power-down, and joystick
blocked variants.

**Data keys** — `mouse.shp` frame ranges: `default` (0), `default-minimap` (1), scroll-t (2)…scroll-tl (9), blocked 10–17,
`select` start 18 length 12, `move` 31 len 10, `move-blocked` 41, minimap move 42 len 10, `attack` 53 len 5,
attack-outsiderange 58 len 5, guard 68 len 5, ability 78 len 10, enter/capture 89 len 10, enter-blocked 99, deploy 110
len 9, undeploy 120 len 9, sell 129 len 10 / sell2 139, sell-blocked 149, goldwrench 150 len 20, repair 170 len 20,
repair-blocked/goldwrench-blocked 190, ioncannon 279 len 20, nuke 319 len 9, powerdown 329 len 15, emp 357 len 19,
emp-blocked 377, joystick-all 378 + blocked 379–386. Harvester harvest minimap 134 len 8; `enter-minimap` 100 len 10;
`c4` 309 len 10 / c4-minimap 121 len 3.

**Numbers** — Frame counts/lengths as above; TS cameo 64×48; cursor SHPs share `sidebar.pal` for sidebar-mode cursors.

**Edge cases** — Some cursor states are `# TODO: unused` in OpenRA's TS data (attack-blocked, sell-minimap), indicating
vanilla never showed them or the reimplementation did not wire them. Move-rough vs move-blocked distinguishes passable
terrain. Repair vs gold-wrench distinguishes building repair vs engineer repair. Targeting validity changes the cursor
(valid = animated, blocked = static/red variant). Minimap has its own cursor frames.

**Kind** — input cursor catalog.

**Sources** — https://raw.githubusercontent.com/treiber-88/OpenRA-Tiberian-Sun-/main/mods/ts/cursors.yaml ·
https://github.com/treiber-88/OpenRA-Tiberian-Sun-/blob/main/mods/common-content/cursors.yaml

**Confidence** — med/high (clean-room reconstruction, matches manual cursor descriptions).

---

## G. EVA

### TS-UI-080 EVA Line Catalog and Announcer Behaviour

**What** — EVA/announcer voice warnings and confirmations for both sides. GDI uses EVA (Jessica Straus in TS/FS); Nod uses
CABAL (and a stolen GDI EVA after CABAL's betrayal). TS lines cover production, combat losses, captures, power, funds,
superweapons, and mission events. Mission triggers can disable/enable EVA announcements (Actions 102/103). Meteor/ion
events play the "Meteor storm approaching" speech.

| Event category | Example line(s) | Trigger | Side |
|---|---|---|---|
| Session start | "Establishing battlefield control, standby." / "Welcome back, commander." | Start | both |
| Session end | "Battle control terminated." | End/abort | both |
| Construction started | "Building." / "Construction started." | Click build | both |
| Construction complete | "Construction complete." | Structure done | both |
| New options | "New construction options." / "New construction options available." | Tier up | both |
| Unit ready | "Unit ready." | Unit produced | both |
| On hold | "On hold." | Pause build | both |
| Cancelled | "Cancelled." | Cancel build | both |
| Insufficient funds | "Insufficient funds." | Can't afford | both |
| Queue limit | "Unable to build more." (sound `WRONG1`) | Queue full | both |
| Low power | "Low power." / "Insufficient power." | Power deficit | both |
| Silos | "Silos needed." | Storage full | both |
| Unit lost | "Unit lost." | Friendly unit dies | both |
| Structure lost | "Structure lost." | Friendly building dies | both |
| Base under attack | "Our base is under attack." | Friendly structure hit | both |
| Ally under attack | "Our ally is under attack." | Teammate structure hit (since TS) | both |
| Building captured | "Building captured." | Enemy captures friendly | both |
| Being captured | "Our building is being captured." | Capture in progress | both |
| Vehicle stolen | "Vehicle stolen." | Hijacker/steal | both |
| Repairing | "Repairing." | Repair mode | both |
| Deploy blocked | "Cannot deploy here." | Invalid placement | both |
| Superweapon ready | e.g. "Ion cannon ready." / "Nuclear warhead ready." | Charge full | GDI/Nod |
| Superweapon incoming | "Nuclear warhead approaching." | Nuke launch | Nod |
| Mission win/lose | "Mission accomplished." / win & lose announcements | Actions 67/68 | both |
| Reinforcement | "Reinforcements have arrived." | Action 7/80 | both |
| Meteor/ion | "Meteor storm approaching." | Actions 43/58 | both |
| Select target | "Select target." | Targeting mode | both |

**Data keys** — EVA speech IDs live in `Speech01.mix` (GDI) / `Speech02.mix` (Nod), side-loaded per `Side=`; `Speech01.mix`
naming uses an `i`/`n` letter to split GDI/Nod. Events are referenced by trigger Actions (speech IDs), and global
enable/disable via Actions 102 (Disable Speech) / 103 (Enable Speech). Voice IDs in `SOUND.INI` follow a numeric scheme
(`15-I0xx` mission/unit lines, `11-I0xx` Oxanna, `12-I0xx` Slavik, `13-I0xx` Tratos, `14-I0xx` Ghostalker, `21-I0xx` spy,
`22-I0xx` cyborg, `23-I0xx` cyborg commando, `24-I0xx` mutant hijacker, `32-I0xx` Banshee, etc.). `KLAX1` = klaxon,
`WRONG1` = queue full.

**Numbers** — OpenPeon catalogues 23 EVA sounds across 8 hook categories; the audio-hooks project transcribes a 306-line
speech corpus for both sides.

**Edge cases** — Nod's announcer role shifts: in vanilla TS the "Nod EVA" is voiced by CABAL; after the Firestorm Conflict
(betrayal) Nod uses a stolen GDI EVA. Twisted Insurrection notes GDI and Nod EVA are taken from original TS, with Nod voiced
by CABAL. `Disable Speech` suppresses EVA during scripted moments (e.g., ion storm missions). Mission objectives are voiced
via mission-specific lines, not the generic set.

**Kind** — audio/announcer system.

**Sources** — https://cnc.fandom.com/wiki/Electronic_Video_Agent · https://openpeon.com/packs/tiberian-sun-eva ·
https://github.com/samhayek-code/tiberian-sun-audio-hooks/blob/main/README.md ·
https://raw.githubusercontent.com/Vinifera-Developers/Tiberian-Sun-INIs/master/SOUND.INI · https://modenc.renegadeprojects.com/Actions_(maps)/TSFS

**Confidence** — high (categories), med (exact line wording).

---

## H. Unit Voices

### TS-UI-090 Voice Categories and Idle Behaviour

**What** — Every unit has selection, move/order, attack, feedback and death voice sets, plus "reporting"/"unit ready"
lines. The `SOUND.INI` voice-ID scheme confirms distinct banks per character/unit type and ordered slots (select/move/
attack etc.). Units occasionally play "idle" lines when left alone; EVA/tutorial triggers can play character speech
(Oxanna, Slavik, Tratos, Umagon, Ghostalker). Death screams and squish sounds (`DEDMAN*`, `DEDGIRL*`, `SQUISH*`) are
separate.

| Category | Example bank / IDs | Notes |
|---|---|---|
| GDI generic infantry select | `15-I000` reporting, `15-I004` awaiting order, `15-I006` "Sir?", `15-I010` ready, `15-I038` standing by | mission/unit bank |
| Move | `15-I018` moving out, `15-I020` advancing, `15-I022` on my way | |
| Acknowledge | `15-I012` yes sir, `15-I016` orders received, `15-I024` you got it, `15-I050` good as done | |
| Attack / combat | `15-I058` "I'm taking heavy fire", `15-I060` "Move! Move! Move!", `15-I064` "MEDIC!" | |
| Deployment | `27-I002` unit deploy response | |
| Nod character | `11-I0xx` Oxanna, `12-I0xx` Slavik, `13-I0xx` Tratos, `14-I0xx` Ghostalker | campaign |
| Nod units | `21-I0xx` spy, `22-I0xx` cyborg, `23-I0xx` cyborg commando, `24-I0xx` mutant hijacker, `32-I0xx` Banshee | |
| Umagon / engineer | `10-I0xx` Umagon, `19-I0xx` engineer | |
| Death | `DEDMAN1–6`, `DEDGIRL1–4`, `SQUISH*` | generic |
| Stub | `BOOP` used for all unsigned sound triggers | |

**Data keys** — `SOUND.INI` `[SoundList]` (index = voice name) and per-sound `Priority=`/`Volume=` overrides (voice lines
default priority 10; many voices overridden to 100). `Report=` in `rules.ini` points weapons/objects to sounds; `Voice=`
/ `VoiceAttack=` etc. select banks per unit. `CrushSound=`, `AmbientSound=` per object.

**Numbers** — Voice priority typically 100 (highest), explosions 50–75, cash/notify 15. GDI/Nod split uses `i`/`n` letter.
306 transcribed lines across both sides (audio-hooks).

**Edge cases** — Random selection among multiple acknowledged lines. Idle/taunt lines can repeat; "Select one less unit" is
a micro exploit, not a voice feature. Mission triggers play character speech via Action 21 "Play speech". Some sounds are
"unsigned"/unused and fall back to `BOOP`. Team colours do not change voices.

**Kind** — audio voice system.

**Sources** — https://raw.githubusercontent.com/Vinifera-Developers/Tiberian-Sun-INIs/master/SOUND.INI ·
https://github.com/samhayek-code/tiberian-sun-audio-hooks/blob/main/README.md · https://openpeon.com/packs/tiberian-sun-cabal

**Confidence** — high (ID scheme), med (category-to-slot mapping).

---

## I. Music

### TS-UI-100 Track List and Dynamic Switching

**What** — TS ships a dark ambient OST. Music is declared in `THEME.INI` (TS) and `THEME01.INI` (Firestorm), merged at
startup. Tracks have display name, length, `Normal` (appears in the in-game play list), `Scenario` (availability), `Side`
(GDI/Nod restriction) and `Repeat` (loops forever). Some tracks are side-locked; the score/map/ion-storm-ambient themes are
non-playlist loops. In-game the player can skip/select themes from the playlist; the engine rotates scenario-appropriate
music. Firestorm restores a more upbeat style.

| ID | Theme name | File base | Length | Normal | Side | Repeat |
|---|---|---|---|---|---|---|
| 1 | Intro | INTRO | 3.27 | no | — | yes |
| 2 | Valves | VALVES1B | 3.27 | yes | — | — |
| 3 | Dusk Hour | DUSKHOUR | 4.11 | yes | GDI | — |
| 4 | Flurry | FLURRY | 4.11 | yes | — | — |
| 5 | Mutants | MUTANTS | 4.11 | yes | GDI | — |
| 6 | Approach | APPROACH | 4.42 | yes | — | — |
| 7 | Gloom | GLOOM | 3.37 | yes | — | — |
| 8 | Infrared | INFRARED | 4.26 | yes | — | — |
| 9 | Mad Rap | MADRAP | 4.29 | yes | — | — |
| 10 | Red Sky | REDSKY | 2.22 | yes | — | — |
| 11 | Ion Storm | STORM | 4.14 | yes | — | — |
| 12 | Time Bomb | TIMEBOMB | 2.04 | yes | — | — |
| 13 | What Lurks | WHATLURK | 5.13 | yes | — | — |
| 14 | Defense | DEFENSE | 4.03 | yes | Nod | — |
| 15 | Heroism | HEROISM | 4.06 | yes | — | — |
| 16 | Lone Troop | LONETROP | 4.39 | yes | GDI | — |
| 17 | Nod Crush | NODCRUSH | 3.45 | yes | Nod | — |
| 18 | Pharotek | PHAROTEK | 4.38 | yes | Nod | — |
| 19 | Scout | SCOUT | 4.14 | yes | — | — |
| 20 | Score Screen | SCORE | — | no | — | yes |
| 21 | Map Selection | MAPS | — | no | — | yes |
| 22 | Ion Storm Ambient | IONSTORM | — | no | — | yes |

**Data keys** — `[Themes]` list (ID = section name = AUD file base), and per-section `Name`, `Length`, `Normal`, `Scenario`,
`Side`, `Repeat`. `THEME.INI` (TS) + `THEME01.INI` (FS) merged before the theme list is built. Official OST CD tracks not
all present in-game (e.g., "Stomp" cut, used in Renegade; "Storm Coming" = in-game "Ion Storm"). Side-locked tracks can be
"removed" by rewriting `Side=` (community trick: set `Side=Nod` to hide from GDI list and vice versa).

**Numbers** — 22 declared TS themes; 11 Firestorm tracks (FS Menu, FS Map, Slave To The System, Rain in the Night Part 2,
Link Up, Killing Machine, Infiltration, Hacker, Elusive, Deploy Machines, Initiate); OST CD 16 tracks, ~1:06:39.

**Edge cases** — `Normal` and `Repeat` interaction: non-normal themes never appear in the play list but loop for score/map/
ambient. Scenario gating means some tracks are mission-gated. Firestorm is a separate INI; adding tracks requires placing
the edited INI in a new `expand##.mix`. YR can be made to play the TS OST via a playlist converter (community tool).

**Kind** — music/audio catalog + runtime selection.

**Sources** — https://raw.githubusercontent.com/Vinifera-Developers/Tiberian-Sun-INIs/master/THEME.INI ·
https://cnc.fandom.com/wiki/Command_%26_Conquer:_Tiberian_Sun_soundtrack ·
https://www.frankklepacki.com/ost/vg/cnc-ts · https://github.com/OpenTS-Developers/OpenTS/blob/main/manual/content/formats/theme-ini.md ·
https://steamcommunity.com/app/2229880/discussions/0/7252559325158976500

**Confidence** — high.

---

## J. Presentation

### TS-UI-110 Voxel / Sprite Pipeline

**What** — TS renders vehicles and turrets as **voxels** (`.VXL` + `.HVA`) and infantry/buildings as **SHP** sprites.
Voxels are 3D volumetric pixels lit with surface normals; HVA files define section placement/animation and rotation
origin. Voxel units tilt on slopes; SHP units (Titan, Wolverine) do not. Turrets can be voxels on SHP buildings to get
360° rotation. Rendering caches each of 32,768 possible facings (32 per axis) on demand.

**Data keys** — Art flags: `Voxel=yes`, `Image=`, `Turret=yes` (auto-loads `<artname>barl/*.vxl/.hva`), `Shadow=`, `Layer=`,
`AltPalette=`, `UseLineTrail=`/`LineTrailColor=`/`LineTrailColorDecrement=`. Voxel file format: 5 values per voxel
(X,Y,Z, colour index, normal index). HVA required (missing HVA = internal error). Multi-section voxels (Mammoth Mk II has
13 sections: body, upper/lower legs, feet).

**Numbers** — Voxel max 255³ (artefacts at extreme sizes). TS cell ≈ 33.94 voxels (34 fits a cell); RA2 cell ≈ 42.43
(43 fits). One voxel ≈ 6.03397 leptons. 32 facings per axis (32,768 total). Layers: turret always above body; barrel above
turret only when facing the camera.

**Edge cases** — Aircraft cannot use turret HVA animation in TS. Voxel bounds/HVA can scale spacing. Palette errors on
huge voxels. `NoSpawnAlt=` suppresses the spawn debris alt-frame for voxel units.

**Kind** — rendering/asset pipeline.

**Sources** — https://modenc.renegadeprojects.com/Voxel · https://modenc.renegadeprojects.com/Image

**Confidence** — high.

---

### TS-UI-111 Building Build-Up ("MK") Animations

**What** — Newly placed structures play a build-up animation (SHP frames) instead of popping in instantly, plus an idle
loop and damage frames. Build-up files use the `…MK` suffix (e.g., `GACNSTMK`, `NATMPLMK`, `GADPSAMK`, `GATICKMK`,
`GATICKMK`, `GACNSTMK`), declared in the `[Animations]` array so they can be referenced and cached.

**Data keys** — `[Animations]` entries with `…MK`; art `Buildup=`/normal frames; `[AudioVisual]` constants; `FACBLD1`
("<FACTORY GOES ONLINE>") sound; `PLACE2` (place building sound). Trigger/actions can play animations at waypoints
(Action 41 "Play Anim At").

**Numbers** — In TS `[Animations]`, build-up entries include index 87 `GACNSTMK`, 99 `NATMPLMK`, 171 `GADPSAMK`, 185
`GATICKMK`, 193 `GAICBMMK`, 431? (RA2) etc. Full TS array in TS-UI-118.

**Edge cases** — A building with no `Explosion=` uses the first `[Animations]` entry (`TWLT100`) as placeholder. Damage
frames appear under condition yellow/red. `GACNST` (Construction Yard) has multiple build-up/damage variants.

**Kind** — animation.

**Sources** — https://modenc.renegadeprojects.com/Animations · https://modenc.renegadeprojects.com/Explosion

**Confidence** — high.

---

### TS-UI-112 Death / Explosion Animations

**What** — When an object dies it plays an explosion animation chosen from its `Explosion=` list; buildings play one random
explosion per foundation cell. Vehicles with `Explodes=yes` fire their primary weapon at their own cell on death.
Warhead `Explosion=` selects preset impact families (0 none, 1 single bullet, 2 multiple bullets, 3 fire/napalm, 4 AP,
5 HE, 6 nuclear). Infantry death animations depend on `InfDeath=` (e.g., InfDeath=5 = electric `ELECTRO`). Air units may
play the death animation twice (in air + on impact) unless `DeathWeapon` handles landing.

**Data keys** — `Explosion=` (list, on TechnoTypes), `Explodes=yes`, `DeathWeapon=`, `InfDeath=`, `BalloonHover=`,
`Locomotor=Jumpjet`, warhead `Explosion=`. Animations: `EXPLOSML`, `EXPLOMED`, `EXPLOLRG`, `INFDIE`, `DEATH_A…F`,
`FLAMEGUY`, `DEATH_*`, debris `DBRIS1LG…DBRS10SM`, `XGRY*`, `DIRTEXPL`.

**Numbers** — Warhead explosion families 0–6; six `DEATH_A`–`DEATH_F` infantry bodies; 10 debris size pairs; `Explosion=`
building = one per foundation cell.

**Edge cases** — `Explosion=` does not work on InfantryTypes. Vehicles with `Explodes` or the matching veteran/elite ability
(and units not out of ammo) consistently use the last list entry. Air units crash-landing can double-play. Death during
faction defeat can add an extra middle play. `GENERAL` death etc. for RA2.

**Kind** — animation/effects.

**Sources** — https://modenc.renegadeprojects.com/Explosion · https://modenc.renegadeprojects.com/Explodes ·
https://modenc.renegadeprojects.com/Animations

**Confidence** — high.

---

### TS-UI-113 Smudges / Craters / Scorch

**What** — Terrain "smudges" (craters, scorch marks, debris) are `SmudgeTypes` overlaid on cells, pre-placed via the map
`[Smudge]` section or created at runtime by explosions. Animation art flags `Scorch=`, `Crater=`, `ForceBigCraters=`,
`Sticky=` control whether an animation leaves a smudge.

**Data keys** — `[Smudge] Index=SMUDGE_ID,X,Y,IGNORE`; `[SmudgeTypes]` definitions; animation flags `Scorch`, `Crater`,
`ForceBigCraters`, `Sticky`, `Layer` (smudges sit below objects).

**Numbers** — Smudge X/Y = top-corner cell of the smudge footprint; `IGNORE` non-zero suppresses creation.

**Edge cases** — Smudges persist on the terrain and can be built over by pavement (community "build on craters" trick).
They do not block movement. Pre-placed smudges are editor data; runtime craters depend on warhead/animation.

**Kind** — terrain/effects.

**Sources** — https://modenc.renegadeprojects.com/Smudge · https://modenc.renegadeprojects.com/Animations

**Confidence** — high.

---

### TS-UI-114 Particle Systems

**What** — `[ParticleSystems]` in rules lists all particle systems; each references a `Particles` (HoldsWhat), behaviour
(`BehavesLike`), spawn cadence, lifetime, and lighting. Used for smoke, sparks, fire, ion storm, weather, and weapon
trails. Actions 88/89 spawn/remove particle systems at waypoints.

**Data keys** — `HoldsWhat` (particle), `Spawns`, `SpawnFrames`, `ParticleCap` (default 500), `SpawnRadius`, `Slowdown`,
`SpawnCutoff`, `SpawnTranslucencyCutoff`, `LifeTime`, `BehavesLike`, `SpawnDirection` (XYZ), `ParticlesPerCoord`,
`SpiralDeltaPerCoord`, `SpiralRadius`, `PositionPerturbationCoefficient`, `MovementPerturbationCoefficient`,
`VelocityPerturbationCoefficient`, `Laser`/`LaserColor`, `SparkSpawnFrames`, `LightSize`, `OneFrameLight`,
`SpawnSparkPercentage`.

**Numbers** — `ParticleCap` default 500; `SpawnFrames` 1; `SpiralRadius` 2.890625; `ParticlesPerCoord` 0.1.

**Edge cases** — `[ParticleSystems]` section list is YR-accurate per ModEnc; TS uses a different flag set. Unlisted systems
are not initialised and unusable. Particle systems can emit lights (`LightSize`, `OneFrameLight`) and sparks.

**Kind** — VFX system.

**Sources** — https://modenc.renegadeprojects.com/ParticleSystems · https://modenc.renegadeprojects.com/Actions_(maps)/TSFS

**Confidence** — med (flag table is YR-labelled).

---

### TS-UI-115 Lighting and Spotlights

**What** — Map `[Lighting]` controls global ambient RGB, ground, and level, plus ion-storm and Dominator/nuke overrides
(`Ion*`, `Dominator*`, `NukeAmbientChangeRate`). Buildings such as the Obelisk, light posts and some defences cast
spotlights whose behaviour is switchable via Action 52 "Change Light Behavior" (0 none, 1 obey rules.ini, 2 circle,
3 follow). Trigger Events 45/46 detect ambient light below/above a percentage.

**Data keys** — `[Lighting] Ambient`, `Red`, `Green`, `Blue`, `Ground`, `Level`, `IonAmbient`, `IonRed`, `IonGreen`,
`IonBlue`, `IonGround`, `IonLevel`, `DominatorAmbient/Red/Green/Blue/Ground/Level`, `DominatorAmbientChangeRate`,
`NukeAmbientChangeRate`. Actions 71/72/73 set ambient step/rate/level. Object flags `Spotlight`/`LightSize`.
`IonSensitive=` weapons disabled in storms; Ion Storm disables coloured-light components of lamps.

**Numbers** — Defaults 1.0 for ambient/RGB; ion-storm `IonAmbient` default 1.0 (lower = darker); spotlight circle/follow
modes 0–3.

**Edge cases** — Day/night loop settings are map data (PPM threads). Ion storm alters map lighting and disables lamp
colour. `Ambient light below/above` events drive missions (e.g., dusk). Lightning lights the map.

**Kind** — lighting/atmosphere.

**Sources** — https://modenc.renegadeprojects.com/Lighting · https://modenc.renegadeprojects.com/Ion_Storm ·
https://modenc.renegadeprojects.com/Actions_(maps)/TSFS · https://modenc2.markjfox.net/IonAmbient

**Confidence** — high.

---

### TS-UI-116 Weather and Ion Storm Visuals

**What** — Ion storms are a recurring TS/FS weather event with heavy gameplay and visual impact: darkening, lightning
bolts striking random cells, radar/air/hover disablement, `IonSensitive` weapons disabled, coloured lamp components off,
some units (jumpjets) exploding if airborne. Started/stopped/forced by triggers.

**Data keys** — `[General]` `IonLightningFrequency`, `IonLightningRandomness`, `IonLightningDamage`, `IonStormDuration`,
`IonStormWarning`, `IonStorms` (obsolete), `IonStormWarhead`, `LightningRod=` per object, `IonSensitive=` per weapon;
map `[SpecialFlags] IonStorms=`, `[TeamType] IonImmune=`; `[Lighting] Ion*`. Actions 43 "Ion Storm start" (duration),
44/45 start/stop, 58 "Meteor Shower", 90 "Lightning Strike At", 94 Ion Cannon Strike, 95 Nuke Strike, 96 Chem Missile.
`LightningSounds=` for bolt SFX. EVA "Meteor storm approaching".

**Numbers** — `IonStormDuration`; meteor shower size 0–3; lightning damage and frequency are rules values; ambient fade
step/rate are floats (hex-encoded in trigger params).

**Edge cases** — Jumpjet units crash/explode at storm onset (fixed by CnCNet patch for a jumpjet crash). Aircraft in flight
crash. Lightning can strike anywhere. Storm can abate mid-mission (Weather the Storm) then resume. Ion-storm missions
disable radar (no minimap) and hover/air units.

**Kind** — weather/gameplay + VFX.

**Sources** — https://modenc.renegadeprojects.com/Ion_Storm · https://cnc.fandom.com/wiki/Weather_the_Storm ·
https://modenc.renegadeprojects.com/LightningSounds · https://modenc2.markjfox.net/IonAmbient

**Confidence** — high.

---

### TS-UI-117 Screen Shake and Camera Feedback

**What** — Explosions (meteors, ion strikes, nukes, large building deaths) produce brief screen shake and light flashes.
Triggers provide explicit light-flash actions and camera moves.

**Data keys** — Action 64/65/66 "Small/Medium/Large Light Flash" at waypoint; Action 48 "Center Camera at waypoint"
(speed 0–4); Action 40 "Resize Player View"; Action 46/47 "Lock/Unlock input"; Action 49/50 zoom. Explosion/light
definitions in anims (`FIREPOWR`, `DRBI*`, `MININUKE`).

**Numbers** — Light flash sizes 3 tiers; camera speed 0–4; resize view X/Y/width/height.

**Edge cases** — Screen shake is bound to explosion-type animations; mission scripted flashes do not always coincide with
damage. "Lock input" is used for cinematic moments.

**Kind** — camera/effects.

**Sources** — https://modenc.renegadeprojects.com/Actions_(maps)/TSFS

**Confidence** — med.

---

### TS-UI-118 TS `[Animations]` Array (Complete)

**What** — The complete TS `[Animations]` table (0-based) cached at load and referenced by map triggers and `[AudioVisual]`.
`INVISO` (index 276) is a special case: the game does not read animations beyond it, and it bounds the animation count.

Index → name (TS): 0 TWLT100 · 1 ELECTRO · 2 TWLT026 · 3 TWLT036 · 4 TWLT050 · 5 TWLT070 · 6 TWLT070T · 7 TWLT100I ·
8 S_BANG16 · 9 S_BANG24 · 10 S_BANG34 · 11 S_BANG48 · 12 S_BRNL20 · 13 S_BRNL30 · 14 S_BRNL40 · 15 S_BRNL58 · 16 S_CLSN16 ·
17 S_CLSN22 · 18 S_CLSN30 · 19 S_CLSN42 · 20 S_CLSN58 · 21 S_TUMU22 · 22 S_TUMU30 · 23 S_TUMU42 · 24 S_TUMU60 · 25 RING1 ·
26 IONBEAM · 27 SMOKEY · 28 BURN-S · 29 BURN-M · 30 BURN-L · 31 H2O_EXP1 · 32 H2O_EXP2 · 33 H2O_EXP3 · 34 PARACH ·
35 PARABOMB · 36 RING · 37 PIFF · 38 PIFFPIFF · 39 FIRE3 · 40 FIRE2 · 41 FIRE1 · 42 FIRE4 · 43 GUNFIRE · 44 TWINKLE1 ·
45 TWINKLE2 · 46 TWINKLE3 · 47 MONEY · 48 MLTIMISL · 49 HEALONE · 50 HEALALL · 51 ARMOR · 52 CHEMISLE · 53 CLOAK ·
54 FIREPOWR · 55 MGUN-N · 56 MGUN-NE · 57 MGUN-E · 58 MGUN-SE · 59 MGUN-S · 60 MGUN-SW · 61 MGUN-W · 62 MGUN-NW ·
63 SMOKLAND · 64 VETERAN · 65 REVEAL · 66 SHROUDX · 67 GAPOWR_A · 68 GAPOWR_AD · 69 NARADR_A · 70 NARADR_AD · 71 GAWEAP_1 ·
72 GAWEAP_2 · 73 GAWEAP_A · 74 GAWEAP_B · 75 GAWEAP_C · 76 GAWEAP_D · 77 GAPILE_A · 78 GAPILE_B · 79 NAPULS_A ·
80 GACTWR_A · 81 GACTWR_B · 82 GACTWR_C · 83 GACTWR_D · 84 GAPILE_C · 85 NASTLH_A · 86 NASTLH_AD · 87 GACNSTMK ·
88 GACNST_A · 89 GACNST_AD · 90 GACNST_B · 91 GACNST_C · 92 GACNST_CD · 93 GACNST_D · 94 NAHAND_A · 95 NAHAND_B ·
96 NAHAND_BD · 97 GAPILE_CD · 98 NATMPL_A · 99 NATMPLMK · 100 NAREFN_A · 101 NAREFN_B · 102 NAREFN_C · 103 GAHPAD_A ·
104 GAHPAD_AD · 105 GAPOWR_B · 106 GADEPT_A · 107 GADEPT_AD · 108 GADEPT_B · 109 GATECH_A · 110 GATECH_AD · 111 NATECH_A ·
112 NAWAST_A · 113 NAWAST_AD · 114 NAWAST_B · 115 NAWAST_BD · 116 NAOBEL_A · 117 NAMISL_A · 118 NAMISL_AD · 119 NAMISL_B ·
120 NAMISL_BD · 121 GAFIRE_A · 122 GAFIRE_B · 123 GAFIRE_C · 124 NAREFN_AR · 125 NAPOST_A · 126 NAPOST_AD · 127 NAPOST_B ·
128 WA01X · 129 WA02X · 130 WA03X · 131 WA04X · 132 WB01X · 133 WB02X · 134 WB03X · 135 WB04X · 136 WC01X · 137 WC02X ·
138 WC03X · 139 WC04X · 140 WD01X · 141 WD02X · 142 WD03X · 143 WD04X · 144 TREESPRD · 145 NAOBEL_B · 146 GADEPT_C1 ·
147 GADEPT_C2 · 148 GADEPT_C3 · 149 GADEPT_D · 150 GADEPT_DD · 151 GASILO_A · 152 GASILO_AD · 153 GASILO_B · 154 GASILO_BD ·
155 NAPOWR_A · 156 NAPOWR_AD · 157 CAHOSP_A · 158 NAAPWR_A · 159 NAAPWR_AD · 160 GASPOT_A · 161 GASPOT_AD · 162 CTDAM_A ·
163 CTDAM_AD · 164 TUNTOP01 · 165 TUNTOP02 · 166 TUNTOP03 · 167 TUNTOP04 · 168 NTPYRA_A · 169 NTPYRA_AD · 170 PULSEFX1 ·
171 GADPSAMK · 172 METLARGE · 173 METSMALL · 174 METDEBRI · 175 METSTRAL · 176 METLTRAL · 177 PULSBALL · 178 GAFSDF_A ·
179 FSIDLE · 180 FSAIR · 181 FSGRND · 182 CAARMR_A · 183 GADPSA_A · 184 GATICK_A · 185 GATICKMK · 186 CAARAY_A ·
187 CAARAY_B · 188 CAARAY_C · 189 CAARAY_CD · 190 CAARAY_D · 191 CAARAY_DD · 192 GAICBM_A · 193 GAICBMMK · 194 NAHPAD_A ·
195 NAHPAD_AD · 196 GAKODK_A · 197 GAKODK_AD · 198 GAKODK_B · 199 GAKODK_C · 200 GAKODK_CD · 201 NAMNTK_A · 202 CTDAM_B ·
203 CTDAM_BD · 204 CARYLAND · 205 DROPLAND · 206 GAPLUG_A · 207 GAPLUG_B · 208 GAPLUG_BD · 209 GAPLUG_C · 210 GAPLUG_D ·
211 GAPLUG_E · 212 GAPLUG_F · 213 GARADR_A · 214 GARADR_AD · 215 NASAM_A · 216 EMP_FX01 · 217 DIG · 218 VEINATAC ·
219 INFDIE · 220 DIRTEXPL · 221 PULSEFX2 · 222 DBRIS1LG · 223 DBRIS1SM · 224 DBRIS2LG · 225 DBRIS2SM · 226 DBRIS3LG ·
227 DBRIS3SM · 228 DBRIS4LG · 229 DBRIS4SM · 230 DBRIS5LG · 231 DBRIS5SM · 232 DBRIS6LG · 233 DBRIS6SM · 234 DBRIS7LG ·
235 DBRIS7SM · 236 DBRIS8LG · 237 DBRIS8SM · 238 DBRIS9LG · 239 DBRIS9SM · 240 DBRS10LG · 241 DBRS10SM · 242 DEATH_A ·
243 DEATH_B · 244 DEATH_C · 245 DEATH_D · 246 DEATH_E · 247 DEATH_F · 248 DROPPOD · 249 DROPPOD2 · 250 FLAMEGUY ·
251 EXPLOSML · 252 EXPLOMED · 253 EXPLOLRG · 254 XGRYMED1 · 255 XGRYMED2 · 256 XGRYSML1 · 257 XGRYSML2 · 258 STEAMPUF ·
259 SMOKEY2 · 260 PULSE · 261 WAKE1 · 262 WAKE2 · 263 BEACON · 264 PODRING · 265 CLDRNGL1 · 266 CLDRNGL2 · 267 CLDRNGMD ·
268 CLDRNGSM · 269 CRYSTAL1 · 270 CRYSTAL2 · 271 CRYSTAL3 · 272 CRYSTAL4 · 273 BIGBLUE · 274 SGRYSMK1 · 275 DROPEXP ·
276 INVISO (special: end marker).

**Data keys** — `[Animations]` index list. Entries used by `[AudioVisual]`, `Explosion=`, warhead impact families, and
map-trigger animation actions. All SHP animations used in-game must be listed or internal errors occur.

**Numbers** — 277 entries (0–276), last is `INVISO`.

**Edge cases** — Index 0 (`TWLT100`) is the placeholder explosion for buildings without `Explosion=`. Index 1 (`ELECTRO`) is
the InfDeath=5 (electric) infantry death. RA2/YR have different, differently-ordered arrays (YR inserts `OLD_###` fillers
and shifts after #209); never assume TS indices in other games.

**Kind** — animation registry.

**Sources** — https://modenc.renegadeprojects.com/Animations

**Confidence** — high.

---

## K. Campaign

### TS-UI-130 GDI Campaign — Full Mission List

**What** — Campaign *Evolutionary Response*. Theatre order and objectives:

| # | Mission | Theatre | Objective (abridged) |
|---|---|---|---|
| 1 | Reinforce Phoenix Base | North America | Build a Tiberium Refinery; build a Barracks; destroy all Nod forces |
| 2 | Secure the Region | North America | Establish/secure the region |
| 3 | Secure Crash Site | North America | Secure the crashed vessel; (bonus: Capture Train Station) |
| 4 | Defend Crash Site | North America | Defend the crash site |
| 5 | Rescue Tratos | North America | Rescue Tratos; (bonus: Destroy Radar Array) |
| 6 | Destroy Vega's Base | North America | Destroy Vega's base; (bonus: Destroy Vega's Dam) |
| 7 | Capture Hammerfest Base | Northern Europe | Capture Hammerfest Base |
| 8 | Retrieve Disruptor Crystals | Northern Europe | Retrieve the disruptor crystals |
| 9 | Rescue Prisoners | Northern Europe | Rescue the prisoners |
| 10 | Destroy Chemical Supply | Northern Europe | Destroy the chemical supply |
| 11 | Mine Power Grid | Northern Europe | Mine/disable the power grid |
| 12 | Destroy Chemical Missile Plant | Northern Europe | Destroy the chemical missile plant |
| 13 | Destroy Prototype Facility | Mediterranean | Destroy the Banshee prototype facility |
| 14 | Weather the Storm | Mediterranean | Protect the Kodiak at all costs; destroy all Nod forces (ion storm) |
| 15 | Final Conflict | Mediterranean | Stop the World Altering Missile / final battle |

Bonus/side missions in parentheses are optional. Demo missions: *Initiation*, *Clean Sweep*.

**Data keys** — Per-mission map INI with `[Briefing]`/`[Basic]`, triggers/events/actions, `[Houses]`, `[TeamTypes]`,
waypoint spawns. Mission end via Actions "Win"/"Lose"/"Announce Win"/"Announce Lose"/"Force End" (1, 2, 67, 68, 69).

**Numbers** — 15 main + 3 bonus + 2 demo GDI missions.

**Edge cases** — Some objectives are one-time (refinery/barracks), others dynamic. Weather the Storm forces the ion storm to
persist (radar/air/hover disabled) with a mid-mission abatement. Bonus missions are skippable. Difficulty gates triggers
via EASY/NORMAL/HARD flags.

**Kind** — campaign content.

**Sources** — https://cnc.fandom.com/wiki/Category:Tiberian_Sun_GDI_missions · https://cnc.fandom.com/wiki/Reinforce_Phoenix_Base ·
https://cnc.fandom.com/wiki/Weather_the_Storm · https://strategywiki.org/wiki/Command_%26_Conquer:_Tiberian_Sun/Table_of_Contents

**Confidence** — high (names/order), med (objective text of non-fetched missions).

---

### TS-UI-131 Nod Campaign — Full Mission List

**What** — Campaign *Deus ex Kane*. Nod begins chronologically before GDI.

| # | Mission | Theatre | Objective (abridged) |
|---|---|---|---|
| 1 | The Messiah Returns | Mediterranean | Re-establish Kane's return; secure area |
| 2 | Retaliation | Mediterranean | Retaliate against GDI |
| 3 | Destroy Hassan's Temple | Mediterranean | Destroy Hassan's temple; (bonus: Free Rebel Commander) |
| 4 | Eviction Notice | Mediterranean | Evict/kill GDI presence; (bonus: Blackout) |
| 5 | Salvage Operation | North America | Salvage operation |
| 6 | Capture Umagon | North America | Capture Umagon at Provo **or** New Detroit (either/or) |
| 7 | Sheep's Clothing | North America | Infiltration/steal GDI tech |
| 8 | Destroy GDI Research Facility | North America | Destroy the research facility; (bonus: Escort Bio-toxin Trucks) |
| 9 | Villainess in Distress | Northern Europe | Capture/rescue the VIP |
| 10 | Reestablish Nod Presence | Northern Europe | Reestablish presence **or** Protect Waste Convoys (either/or) |
| 11 | Destroy Mammoth Mk. II Prototype | Northern Europe | Destroy the Mammoth Mk. II prototype |
| 12 | Capture Jake McNeil | Northern Europe | Capture Jake McNeil |
| 13 | A New Beginning | Northern Europe | Kane's new beginning; (bonus: Illegal Data Transfer) |

**Data keys** — same trigger/team system as GDI; Nod-specific `[Houses]` and stealth/superweapon logic.

**Numbers** — 13–14 main missions + bonuses + either/or branches.

**Edge cases** — Two either/or selections (Umagon location; Reestablish/Protect). Nod missions lean on stealth, subterranean
units and CABAL voice.

**Kind** — campaign content.

**Sources** — https://cnc.fandom.com/wiki/Category:Tiberian_Sun_Nod_missions · https://cnc-central.fandom.com/wiki/Category:Tiberian_Sun_Nod_Missions

**Confidence** — high (names), med (abridged objectives).

---

### TS-UI-132 Firestorm Campaign

**What** — Expansion content. GDI campaign *Desperate Measures* and Nod campaign *From the Ashes*, each 9 missions, plus
the CABAL cyborg threat. Introduces Firestorm defence generator/walls, the Limpet Drone bug mechanic, and new units.

| GDI (Desperate Measures) | Nod (From the Ashes) |
|---|---|
| Recover the Tacitus | Operation Reboot |
| Party Crashers | Seeds of Destruction |
| Quell the Civilian Riots | Tratos' Final Act |
| In the Box | Mutant Extermination |
| Dogma Day Afternoon | Escape from CABAL |
| Escape from CABAL | The Needs of the Many |
| The Cyborgs are Coming | Determined Retribution |
| Factory Recall | Harvester Hunting |
| Core of the Problem | Core of the Problem |

**Data keys** — FS-specific triggers: `Firestorm` activation (Actions 92/93), Limpet bug event 55, `Paralyzed` event 53,
EMP/web. `THEME01.INI` music.

**Numbers** — 9 + 9 missions; 11 FS music tracks.

**Edge cases** — CABAL is the antagonist; some FS features are flagged "FS/2.x patched only" in ModEnc (events 53–55).
Firestorm defence can be toggled by trigger.

**Kind** — expansion campaign.

**Sources** — https://cnc.fandom.com/wiki/Category:Tiberian_Sun_GDI_missions · https://modenc.renegadeprojects.com/Events/TSFS ·
https://cnc.fandom.com/wiki/Command_%26_Conquer:_Tiberian_Sun_soundtrack

**Confidence** — high.

---

### TS-UI-133 Trigger / Event / Action Structure

**What** — Campaign logic is data-driven via map INI sections. Hierarchy: CellTag → Tag → Trigger → Event(s) + Action(s).
Triggers also carry per-difficulty enable flags. Events are the conditions; Actions the consequences; both are ID-matched
to the trigger. TS allows multiple events (up to 2 params each) and up to 7-parameter actions.

**Data keys** — Trigger row format (TS/FS/RA2/YR): `ID=HOUSE,LINKED_TRIGGER,NAME,DISABLED,EASY,NORMAL,HARD,PERSISTENCE`.
Persistence is legacy (tag persistence is used). Events have `P1` (boolean: 1 = P2 is a TeamType) and `P2`. Actions have
P1–P7 (P7 often a waypoint or a literal letter, 0→A, 25→Z, 26→AA). Parameter types in the Mission Editor:
`PARAMTYPE_HOUSE`, `PARAMTYPE_TEAMTYPE`, `PARAMTYPE_WAYPOINT` (0–702 TS / 0–255 RA2), `PARAMTYPE_UNITTYPE`
(infantry+vehicles+aircraft+buildings), `PARAMTYPE_TRIGGER`. Entities: `CTriggers`, `CTriggerEventsDlg`,
`CTriggerActionsDlg`, `CScriptTypes` (`[Scripts]`/`[ScriptTypes]`), `CTaskForce` (`[TaskForces]`), `CTeamTypes`
(`[TeamTypes]`: House + TaskForce + Script + flags like `Reinforcable`, `Aggressive`, `Autocreate`), `CAITriggerTypes`
(`[AITriggerTypes]` global AI logic, hex-encoded, weighted) and `[AITriggerTypesEnable]`.

**Event catalog (TS/FS)** — 0 No Event · 1 Entered by (house) · 2 Spied Upon · 3 Thieved by (obsolete) · 4 Discovered or
destroyed · 5 House Discovered · 6 Attacked by any house · 7 Destroyed by enemy · 8 Any event · 9 Destroyed, Units All ·
10 Destroyed, Buildings All · 11 Destroyed, All · 12 Credits exceed · 13 Elapsed time · 14 Mission timer expired ·
15 Destroyed Buildings # · 16 Destroyed Units # · 17 No factories left · 18 Civilians evacuated · 19 Build building type ·
20 Build unit type · 21 Build infantry type · 22 Build aircraft type · 23 Leaves map (team) · 24 Zone entry by · 25 Crosses
horizontal line · 26 Crosses vertical line · 27 Global set · 28 Global clear · 29 Captured or destroyed · 30 Low power ·
31 Attached bridge destroyed · 32 Building exists · 33 Selected by player · 34 Comes near waypoint · 35 Enemy in spotlight
(sticky) · 36 Local set · 37 Local clear · 38 First damaged (combat) · 39 Half health (combat) · 40 Quarter health (combat) ·
41 First damaged (any) · 42 Half health (any) · 43 Quarter health (any) · 44 Attacked by (house) · 45 Ambient light below ·
46 Ambient light above · 47 Elapsed Scenario Time · 48 Captured/Destroyed/Infiltrated · 49 Pickup Crate · 50 Pickup Crate
(any) · 51 Random delay · 52 Credits below · 53 Paralyzed (FS) · 54 Enemy in spotlight non-sticky (FS) · 55 Attached object
bugged (FS).

**Action catalog (TS/FS)** — 0 No Action · 1 Win · 2 Lose · 3 Production Begins · 4 Create Team · 5 Destroy Team · 6 All to
Hunt · 7 Reinforcement · 8 Drop Zone Flare · 9 Fire Sale · 10 Play Movie · 11 Text Trigger · 12 Destroy Trigger ·
13 Autocreate Begins (obsolete) · 14 Change House · 15 Allow Win (obsolete) · 16 Reveal all map · 17 Reveal around waypoint ·
18 Reveal waypoint zone · 19 Play sound effect · 20 Play music theme · 21 Play speech · 22 Force Trigger · 23 Timer Start ·
24 Timer Stop · 25 Timer Extend · 26 Timer Shorten · 27 Timer Set · 28 Global Set · 29 Global Clear · 30 Auto Base Building ·
31 Grow shroud · 32 Destroy Attached Object · 33 Add 1-time super weapon · 34 Add repeating super weapon · 35 Preferred
target · 36 All change house · 37 Make ally · 38 Make enemy · 39 Change Zoom Level · 40 Resize Player View · 41 Play Anim At ·
42 Fire Weapon At · 43 Meteor Impact At · 44 Ion Storm start · 45 Ion Storm stop · 46 Lock input · 47 Unlock input ·
48 Center Camera at waypoint · 49 Zoom in · 50 Zoom out · 51 Reshroud Map · 52 Change Light Behavior · 53 Enable Trigger ·
54 Disable Trigger · 55 Create Radar Event · 56 Local Set · 57 Local Clear · 58 Meteor Shower · 59 Reduce Tiberium ·
60 Sell Building · 61 Turn Off Building · 62 Turn On Building · 63 Apply 100 Damage · 64/65/66 Small/Medium/Large Light
Flash · 67 Announce Win · 68 Announce Lose · 69 Force End · 70 Destroy Tag · 71 Set Ambient Step · 72 Set Ambient Rate ·
73 Set Ambient Light · 74 AI Triggers Begin · 75 AI Triggers Stop · 76 Ratio of AI Trigger Teams · 77 Ratio of Team
Aircraft · 78 Ratio of Team Infantry · 79 Ratio of Team Units · 80 Reinforcement Team At · 81 Wakeup Self · 82 Wakeup All
Sleepers · 83 Wakeup All Harmless · 84 Wakeup Group (bugged) · 85 Vein Growth · 86 Tiberium Growth · 87 Ice Growth ·
88 Particle System Anim At · 89 Remove Particle System Anim At · 90 Lightning Strike At · 91 Go Berzerk · 92 Activate
Firestorm · 93 Deactivate Firestorm · 94 Ion Cannon Strike · 95 Nuke Strike · 96 Chem Missile strike · 97 Toggle Train
Cargo · 98 Play Sound Effect Random · 99 Play Sound Effect At · 100 Play Ingame Movie · 101 Flash Team (FS) · 102 Disable
Speech (FS) · 103 Enable Speech (FS) · 104 Set Team ID (FS) · 105 Talk Bubble (FS).

**Numbers** — Events 0–55; Actions 0–105 (TS/FS). Waypoints 0–702 (TS). Action/Event times in seconds at 15 FPS default.
`Flash Team` duration in frames; `Talk Bubble` frame index 1-based.

**Edge cases** — Events 27/28/36/37 (variable checks) have higher priority and reset preceding events. Local/global vars
superseded "Allow Win". Event 8 "Any event" can override simultaneous events (prefer timer 0). Event 35 cannot coexist with
attack/destroy events on the same trigger (freeze). Event 55 = Limpet bug (FS only). Persistence column is obsolete in TS+.
`Reference items`: params ending in `#` use list indices; otherwise IDs. P7 literals use spreadsheet-style letters.

**Kind** — scripting/data model.

**Sources** — https://modenc.renegadeprojects.com/Triggers · https://modenc.renegadeprojects.com/Events/TSFS ·
https://modenc.renegadeprojects.com/Actions_(maps)/TSFS ·
https://deepwiki.com/electronicarts/CNC_TS_and_RA2_Mission_Editor/2.6-trigger-and-scripting-system

**Confidence** — high.

---

### TS-UI-134 Reinforcements

**What** — Reinforcements are spawned by Actions: 7 "Reinforcement" (team arrives from the nearest map edge to its origin
waypoint), 80 "Reinforcement Team At" (spawns magically at a waypoint; inside a building/transport if one is on the
waypoint), and 4 "Create Team" (recruits from existing/produced units). Parachute/drop-pod landings use animations
`PARACH`, `PARABOMB`, `DROPPOD`, `DROPPOD2`, `DROPLAND`, `CARYLAND`, `DROPEXP`.

**Data keys** — `[TeamTypes]` (members), `[TaskForces]`, `[ScriptTypes]`, waypoints; `DissolveUnfilledTeamDelay` for
unfilled teams; `Edge=` per house; tunnel locomotor spawns underground and emerges.

**Numbers** — Reinforcement team sizes/taskforce quantities are data; `DissolveUnfilledTeamDelay` is a rules time.

**Edge cases** — Non-burrowing ground units may spawn oddly (opposite map edge) when a clear spot outside view can't be
found. Subterranean units emerge at/nearest the waypoint. Transports keep passengers unless a script ejects them. Teams
regard themselves "killed" for events 29/48 if destroyed by Action 5.

**Kind** — campaign mechanic.

**Sources** — https://modenc.renegadeprojects.com/Actions_(maps)/TSFS · https://modenc.renegadeprojects.com/Animations

**Confidence** — high.

---

### TS-UI-135 Cinematic Camera

**What** — Missions use camera-control actions during scripted sequences: lock/unlock input, centre camera at a waypoint
with speed, resize the player view, zoom in/out, and play full-screen movies (Action 10) or minimap-window movies
(Action 100). Briefing FMVs replay via Action 10/Play Movie.

**Data keys** — Actions 10, 40, 46, 47, 48, 49, 50, 100; `[Map] LocalSize=` and `Resize Player View` (X offset, Y offset,
width, height); `[Basic]` movie IDs.

**Numbers** — Camera speed 0–4; view resizes in cells; movie duration is external.

**Edge cases** — Input lock is global; the minimap can keep playing a movie while the player retains control. Cinematics
often disable EVA speech (Action 102).

**Kind** — cinematic presentation.

**Sources** — https://modenc.renegadeprojects.com/Actions_(maps)/TSFS

**Confidence** — high.

---

### TS-UI-136 Win / Lose Conditions

**What** — A mission ends via trigger Actions: 1 Win, 2 Lose, 67 Announce Win, 68 Announce Lose, 69 Force End. Campaigns
use local/global variables to sequence objectives and determine when a win becomes "allowed". "Short Game" changes skirmish
end conditions.

**Data keys** — Actions 1/2/67/68/69; local/global variables; `[Basic]`; per-difficulty trigger flags.

**Numbers** — n/a.

**Edge cases** — "Allow Win" (15) is obsolete in TS (replaced by variables but kept for RA/older maps). "Force End" ends
without the win/lose announcement. Defeat can be triggered by timers/protect-objectives (e.g., Kodiak destroyed).
Destruction of all buildings triggers Short Game end in skirmish only.

**Kind** — mission state.

**Sources** — https://modenc.renegadeprojects.com/Actions_(maps)/TSFS · https://tiberiansunguide.wixsite.com/tiberiansunguide/game-settings

**Confidence** — high.

---

### TS-UI-137 Difficulty

**What** — Easy/Normal/Hard selected in campaign/options, plus a skirmish AI-difficulty slider per opponent. Triggers carry
EASY/NORMAL/HARD enable flags so map logic (extra enemies, timers, reinforcements) can vary by difficulty. AI cheats are
difficulty-scaled.

**Data keys** — Trigger row columns EASY/NORMAL/HARD (0/1); `[IQ]` and AI settings; `RepairSell=`; campaign difficulty
slider.

**Numbers** — 3 levels.

**Edge cases** — The campaign difficulty slider and skirmish difficulty are separate controls; ModEnc notes the trigger
columns reference the campaign slider or the Options slider. Community discussion repeatedly flags AI cheating at higher
difficulty.

**Kind** — game setting.

**Sources** — https://modenc.renegadeprojects.com/Triggers · https://tiberiansunguide.wixsite.com/tiberiansunguide/game-settings

**Confidence** — high.

---

## L. Skirmish / Multiplayer UI Flows and Options

### TS-UI-150 Skirmish and Multiplayer Flows

**What** — Skirmish: player = host, same setup as multiplayer minus network. Multiplayer: lobby → map pick → game options →
start. In-game: chat, alliances, shared control (Grant Control), radar events, surrender/abort. Community clients (CnCNet)
replace the retired Westwood Online and add matchmaking, custom maps and patches. TS Client adds side-specific sidebar/
speech/cameo mix overrides for new sides.

**Data keys** — Lobby player rows (name/faction/colour/team/ready), chat channels, Shared Control flag, `[Multiplayer]`
game options (crates, short game, multi-engineer, superweapons, starting credits), map list. Side mix files per fraction
(`sidec0#.mix`, `speech0#.mix`, cameo packs). Debug stats in the InfoPanel page 3 (network/RH/loss).

**Numbers** — Classic max 8 players; colours per game; multiple AI difficulty levels.

**Edge cases** — No pause online; hotkey edits run live; save/load not supported in vanilla online. Different side `.mix`
files require correct `Side=` indices. CnCNet patched the jumpjet/ion-storm crash and other engine bugs.

**Kind** — multiplayer meta.

**Sources** — https://cnc.fandom.com/wiki/Skirmish · https://forums.cncnet.org/topic-57515/clarification-on-adding-specific-mix-files-for-new-sides ·
https://github.com/samhayek-code/tiberian-sun-audio-hooks/blob/main/README.md · https://cnc.fandom.com/wiki/Vanilla_Conquer

**Confidence** — high.

---

## M. Accessibility and Localization

### TS-UI-160 Accessibility and Localization UI

**What** — Vanilla TS offers limited accessibility: adjustable volumes, game/scroll speed, brightness/gamma, and rebindable
keys. There is no documented colour-blind mode, subtitle toggle, or screen-reader support in the original. Localization is
via localized text/audio sets; FinalSun/FinalAlert language INIs (`FSLanguage.ini`, `FALanguage.ini`) localize the map
editors. The Steam/Ultimate Collection re-releases preserve the original UI scale and may add compatibility patches.

**Data keys** — Video: resolution/brightness/gamma; Audio: SFX/voice/music volumes; Game Controls: keyboard/mouse; Game:
speed/difficulty/detail. Map-editor localization: `FSLanguage.ini`, `FALanguage.ini`. Per-game `UIName=` strings and
`tutorial.ini` text are the in-game localizable strings.

**Numbers** — Classic UI 640×480; remaster-era community loading screens at 1920×1080.

**Edge cases** — The ion storm deliberately removes the radar (a visual-accessibility stressor). Colour coding (player
colours, condition colours) has no vanilla alternative palette. Some strings live in side mixes and would need per-language
mix swaps. Firestorm adds its own localized menu art.

**Kind** — accessibility/localization review.

**Sources** — https://deepwiki.com/electronicarts/CNC_TS_and_RA2_Mission_Editor/5.2-finalsun-data-(fsdata.ini-fslanguage.ini) ·
https://cnc.fandom.com/wiki/Command_%26_Conquer:_Tiberian_Sun_manual · https://forums.cncnet.org/topic/12582-new-loading-screen-for-resolution-1920x1080-and-giants-sidebar-2023

**Confidence** — low/med (little dedicated documentation exists; largely inferred).

---

## Coverage Checklist

- [x] Main menu / shell — TS-UI-001
- [x] New game / campaign select + world map — TS-UI-002, TS-UI-010
- [x] Skirmish setup — TS-UI-003, TS-UI-150
- [x] Options (video/audio/controls/game) — TS-UI-004
- [x] Load / save — TS-UI-005
- [x] In-game pause / game menu — TS-UI-006
- [x] Briefing — TS-UI-007
- [x] Score / post-game — TS-UI-008
- [x] Quit / confirm — TS-UI-009
- [x] Multiplayer lobby — TS-UI-011, TS-UI-150
- [x] Map select / random map generator — TS-UI-012
- [x] Sidebar layout and tabs — TS-UI-020
- [x] Cameo grid — TS-UI-021
- [x] Per-cameo states (ready/clocking/greyed/insufficient) — TS-UI-022
- [x] Queue display + `MaximumQueuedObjects` — TS-UI-023
- [x] Credits counter — TS-UI-024
- [x] Power bar — TS-UI-025
- [x] Repair / sell — TS-UI-026
- [x] Lower bar / info panel — TS-UI-027
- [x] Message ticker — TS-UI-028
- [x] Radar / minimap (toggle, blips, events, shroud, click, destructibility) — TS-UI-040
- [x] Single/box selection — TS-UI-050
- [x] Selection brackets — TS-UI-051
- [x] Health bars + colour thresholds — TS-UI-052
- [x] Veteran pips — TS-UI-053
- [x] Charge pips — TS-UI-054
- [x] Passenger / cargo pips — TS-UI-055
- [x] Enemy health option — TS-UI-056
- [x] Full hotkey catalog + control groups + camera + right/left click semantics — TS-UI-060 to TS-UI-063
- [x] Stances/orders (guard, stop, scatter, deploy, capture, repair, sell, waypoint) — TS-UI-064
- [x] Planning / waypoint length — TS-UI-065
- [x] Keyboard config screen — TS-UI-066
- [x] Every cursor state / action cursor + targeting rules — TS-UI-070
- [x] EVA catalog per side + ticker — TS-UI-028, TS-UI-080
- [x] Unit voice categories + idle/taunt — TS-UI-090
- [x] Music track list + dynamic switching — TS-UI-100
- [x] Voxel / sprite pipeline — TS-UI-110
- [x] Build-up animations — TS-UI-111
- [x] Death / explosion animations — TS-UI-112
- [x] Smudges / craters — TS-UI-113
- [x] Particle list — TS-UI-114
- [x] Lighting / spotlights — TS-UI-115
- [x] Weather / ion storm visuals — TS-UI-116
- [x] Screen shake — TS-UI-117
- [x] Complete animation registry — TS-UI-118
- [x] GDI mission list + objectives — TS-UI-130
- [x] Nod mission list + objectives — TS-UI-131
- [x] Firestorm campaigns — TS-UI-132
- [x] Trigger / event / action structure — TS-UI-133
- [x] Reinforcements — TS-UI-134
- [x] Cinematic camera — TS-UI-135
- [x] Win / lose — TS-UI-136
- [x] Difficulty — TS-UI-137
- [x] Skirmish / multiplayer UI flows and options — TS-UI-150
- [x] Accessibility / localization UI — TS-UI-160

## Open Questions / Top Uncertainties

1. **TS default condition thresholds.** ModEnc gives `ConditionRed` default 50% (inherited from RA `[General]`) while the
   community TS guide states `ConditionYellow=50%`. The TS `[AudioVisual]` defaults for `ConditionYellow`/`ConditionRed`
   could not be read from a primary file here (hard rule: no local game files). Confirm against the active `rules.ini`.
2. **Exact default key letters.** Community tables disagree (attack-move, force-fire, patrol, rally). The authoritative
   artefact is the five-category action list; per-key defaults must be read from the running build / `KEYBOARD.INI`.
3. **Vanilla attack-move.** Multiple sources indicate vanilla TS has no attack-move; Q+click / Ctrl+Shift are RA2 or
   patched/OpenTS behaviours. Needs a definitive engine check before replicating.
4. **Waypoint chain cap.** Map waypoint index space (0–702 TS) is documented, but the per-unit planning chain limit is
   only community-attested.
5. **`MaximumQueuedObjects` semantics.** ModEnc says "maximum … plus one additional slot" and default 0. The effective
   TS shipped value (commonly cited as 5) and whether the +1 is inclusive could not be confirmed from a primary source.
6. **EVA verbatim lines.** Category coverage is solid; exact wording per line is drawn from fan transcriptions and may
   differ slightly from retail audio.
7. **Particle-system flag table** on ModEnc is labelled YR-accurate; TS uses a different flag set. The TS-specific list is
   not fully enumerated online in one page.
8. **Full mission objectives** for missions not individually fetched (most of the GDI/Nod lists) are abridged from
   mission names and the category nav, not from each mission page.
9. **Accessibility/localization** has very little dedicated documentation; TS-UI-160 is largely inferred from the manual
   and editor language INIs.
10. **Shell button ordering / edition differences** (original vs Firestorm vs Steam/Ultimate Collection re-releases) were
    not fully enumerated; the shell changed across patches and bundles.

## Source Index

- ModEnc (modding encyclopedia): https://modenc.renegadeprojects.com/ — Sidebar-related, `MaximumQueuedObjects`, `Voxel`,
  `Image`, `Cameo`, `Cameo_Charging_Indicator`, `Animations`, `Explosion`, `Explodes`, `Smudge`, `ParticleSystems`,
  `Themes`, `Ion_Storm`, `ConditionRed`, `ConditionYellow`, `Triggers`, `Events/TSFS`, `Actions_(maps)/TSFS`, `Lighting`,
  `Sides`, `Side`, `LightningSounds`.
- Command & Conquer Wiki (Fandom): https://cnc.fandom.com/ — soundtrack, GDI/Nod mission categories, Electronic Video Agent,
  Skirmish, Sidebar, Veterancy, Vanilla Conquer, the TS Operations Manual transcript, mission pages (Reinforce Phoenix
  Base, Weather the Storm). Mirror: https://cnc-central.fandom.com/.
- OpenRA "Tiberian Sun" (clean-room reimplementation): cursor YAML
  https://raw.githubusercontent.com/treiber-88/OpenRA-Tiberian-Sun-/main/mods/ts/cursors.yaml
- EA-released Mission Editor source + DeepWiki: https://github.com/electronicarts/CNC_TS_and_RA2_Mission_Editor and
  https://deepwiki.com/electronicarts/CNC_TS_and_RA2_Mission_Editor/
- Original INI archive (Vinifera Developers): https://github.com/Vinifera-Developers/Tiberian-Sun-INIs (`THEME.INI`,
  `SOUND.INI`); Vinifera engine docs https://vinifera.readthedocs.io/en/latest/User-Interface.html
- OpenTS manual: https://github.com/OpenTS-Developers/OpenTS/blob/main/manual/content/formats/theme-ini.md
- Squad/tooling sources: https://openpeon.com/packs/tiberian-sun-eva;
  https://github.com/samhayek-code/tiberian-sun-audio-hooks
- Community guides: https://tiberiansunguide.wixsite.com/tiberiansunguide/{hotkeys,game-settings}; MagicGameWorld controls;
  CnCNet forums (hotkeys, health bars, settings, attack-move); Steam Community discussions (hotkeys, Dusk Hour/Flurry);
  PPM forums (skirmish settings, music); StrategyWiki TS Table of Contents (blocked to reader, cited for structure).
- Music: https://cnc.fandom.com/wiki/Command_%26_Conquer:_Tiberian_Sun_soundtrack; https://www.frankklepacki.com/ost/vg/cnc-ts;
  https://www.discogs.com/master/14534
