# Red Alert 2 — UI/UX, Presentation, Campaign & Meta: Web Research Reference

Scope: *Command & Conquer: Red Alert 2* (Westwood Pacific, October 2000) and, where it diverges, its expansion
*Yuri's Revenge* (2001). This is a **web-only** reference; no game files on this machine were read. It feeds the unified,
data-driven engine in `/mnt/work2/Redot/redotian-sun` targeting TS, Firestorm, RA2 and YR.

Method: SearXNG web search + direct page reads. Primary sources: the RA2/YR **user manual** (ManualShelf text mirror),
ModEnc / ModEnc² (the INI-flag encyclopaedia), the Command & Conquer Wiki on Fandom (`cnc.fandom.com`, mirror
`cnc-central.fandom.com`), Project Perfect Mod (PPM) forums (cursor frame indices, pip internals), CnCNet community
forums, CnCmaps, DefKey, the Red Alert Archive campaign walkthrough, the public `rules.ini` text of YR, the OpenPeon RA2
voice pack, and Frank Klepacki's official site / the C&C Wiki soundtrack list. StrategyWiki returned HTTP 403 to every
reader attempt; its control content is cross-checked against DefKey, CnCmaps and the manual.

Confidence legend: **high** = primary engine data (rules.ini/art.ini semantics) or the official manual or ≥2 independent
sources; **med** = single credible source or a clean-room/community reconstruction; **low** = community claim, single
anecdote, or inferred.

Conflict legend: where sources disagree the block carries a **Conflicts** note.

**Note on indexing:** RA2 rules live in `rules.ini` (RA2) / `rulesmd.ini` (YR); art lives in `art.ini` / `artmd.ini`;
strings in `ra2.csf` / `ra2md.csf`. Where this doc cites rule values it is citing the shipped *Yuri's Revenge*
`rulesmd.ini` text unless stated otherwise.

---

## A. Screens and Dialogs

### RA2-UI-001 Main Menu / Shell

**What** — Full-screen shell reached at boot after a short intro cinematic of the Soviet invasion of the US. Buttons:
*Single Player*, *Internet*, *Network*, *Movies & Credits*, *Options*, *Exit Game*. Animated/looping menu theme and an
SNES-era 800×600/1024×768-era blittered UI (later re-releases show a launcher/config step first). The menu is the entry
point for all modes.

**Data keys** — Mode routing (Single Player → New Campaign / Load Saved Game / Skirmish). Music theme selection; the
shell uses its own palette/mix art. `Movies & Credits` plays the FMV reels and the credits scroll.

**Numbers** — Manual lists six main buttons. Menu music plays as a looping track. No resolution lock in retail (options
set video mode).

**Edge cases** — `Internet` routes to the now-dead Westwood Online (CnCNet/XWIS replaced it); `Network` opens LAN
setup. Re-releases (Ultimate Collection / Steam) may present a config launcher before this screen. Esc backs out of
sub-menus.

**Kind** — shell / modal navigation.

**Sources** — https://www.manualshelf.com/manual/games-pc/command-conquer-red-alert-2/user-guide-english.html ·
https://cnc.fandom.com/wiki/Command_%26_Conquer:_Red_Alert_2

**Confidence** — high.

---

### RA2-UI-002 Single Player Menu / Campaign Select

**What** — "Single Player" opens a sub-menu with *New Campaign*, *Load Saved Game*, *Skirmish*, and a *Main Menu*
button bottom-right. *New Campaign* opens the **Campaign menu** where the player picks the Allied or Soviet campaign
(then a difficulty). RA2's campaign structure is "alternate ending": both full campaigns exist independently, only the
Allied one is canon (it leads into YR).

**Data keys** — Campaign (Allied/Soviet), difficulty (Easy/Medium/Hard), mission index, unlock graph. Tutorial
"Boot Camp" is a separate 2-map training campaign.

**Numbers** — Allied campaign: **12 missions**; Soviet campaign: **12 missions**; Boot Camp: **2 missions**. YR adds 7
Allied + 7 Soviet + a Yuri side plus co-op campaigns.

**Edge cases** — Difficulty can be changed post-hoc by editing `RA2.ini`/`RA2MD.ini` under `[Options]`. The mission
picker (world map) only appears once a campaign/difficulty is chosen. Boot Camp maps are `Boot Camp - Day 1/2`.

**Kind** — campaign meta / level select.

**Sources** — https://www.manualshelf.com/manual/games-pc/command-conquer-red-alert-2/user-guide-english.html ·
https://cnc.fandom.com/wiki/Command_%26_Conquer:_Red_Alert_2 · `Template:Red Alert 2 Missions` (cnc.fandom raw)

**Confidence** — high.

---

### RA2-UI-003 Country Selection

**What** — Before a skirmish/multiplayer match the player picks a **country (sub-faction)** within a side. Countries
grant one unique unit or support power; all other roster content is shared per side. The country list is data-driven
from `[Countries]` in rules.ini (not hardcoded), ordered by side.

**Data keys** — `[Countries]` list order; `Side=`; unique unit / support power per country.

**Numbers** — Allies: **America** (Paradrop/Airborne), **Korea** (Black Eagle), **France** (Grand Cannon), **Germany**
(Tank Destroyer), **Britain** (Sniper). Soviets: **Russia** (Tesla Tank), **Iraq** (Desolator), **Cuba** (Terrorist),
**Libya** (Demolition Truck). YR adds a **Yuri** side (with clone/initiate/etc. country variants).

**Edge cases** — The list shown follows `[Countries]` order, so mods can add/remove nations freely. Some special
countries (e.g. the mission-only `AMRADR`) exist in data but are not player-selectable. Per CnCNet, allied nation
bonuses were historically "fixed" to Germany-like behaviour on some ladders (balance claim, low confidence).

**Kind** — setup / roster modifier.

**Sources** — https://modenc.renegadeprojects.com/Countries · https://cncmaps.net/factions-of-red-alert-2 ·
https://cnc.fandom.com/wiki/Command_%26_Conquer:_Red_Alert_2_manual

**Confidence** — high (mechanism), med (competitive balance claims).

---

### RA2-UI-004 Skirmish Setup

**What** — Single-window offline-vs-AI setup. The human is always host and sets: player name, country, colour, map
(including a built-in **random map generator**), number of AI opponents (up to 7), per-opponent country/colour/team, AI
difficulty, starting credits, and scenario conditions. Team assignment is a column of numbered rows.

**Data keys** — Scenario conditions (from manual + rules.ini): **MCV Repacks**, **Crates Appear**, **Superweapons**,
**Short Game**, **Build off Ally Conyards** (YR), plus **Starting Units** in YR. Starting credits slider.

**Numbers** — Vanilla slider range roughly 2 500–10 000 (CnCNet raises the cap); PPM notes a max of **20 000** in one
vanilla context and a popular mod asking to raise it to 50 000. Default skirmish starting credits are commonly
**10 000**.

**Edge cases** — Random map generator is integrated in TS/RA2/YR skirmish & MP. Skirmish progress could not be saved in
vanilla (fan patches added it). Special game types from the manual include **Meat Grinder** (infantry+tanks only) and
**Naval War** (small islands), plus **Cooperative** (2 friends vs preset AI; "five campaigns"). Map list length affects
load time.

**Kind** — setup / game-rule configuration.

**Sources** — https://www.manualshelf.com/manual/games-pc/command-conquer-red-alert-2/user-guide-english.html ·
https://cnc.fandom.com/wiki/Skirmish · https://forums.cncnet.org/topic/9080-adding-settings-to-the-cooperative-gamemode ·
https://ppmforums.com/topic-47521/change-skirmish-max-starting-cash-from-20000-to-50000

**Confidence** — high (options), med (exact slider bounds).

---

### RA2-UI-005 Options

**What** — Options menu (also reachable in-game) with tabbed pages: **Display/Visual**, **Audio/Sound**, **User
Interface**, **Keyboard**, and **Network**. Display options include *Visual Detail* (Low→High) and a game-speed control
(hidden/disabled in campaign by default; re-enable by editing the INI). User-interface options include *Tooltips*
(shown when a cursor rests on an object for 2 s), *Target Lines* (a line drawn from unit to move/attack target), and a
*Reset All* keyboard-defaults button. Network tab configures protocol settings.

**Data keys** — Video detail level, resolution, colour depth, sound/music volume, tooltips on/off, target lines on/off,
scroll rate, game speed, keyboard bindings, LAN protocol (IPX in retail; UDP via community patch).

**Numbers** — Tooltip delay = **2 seconds**. Visual detail Low→High. Game speed exposed as a slider in-game when the
INI flag is present (normally disabled for campaign).

**Edge cases** — CnCNet's launcher and the in-game options can fall "out of sync" (known issue). Border-resizing via
DxWnd repositions the window weirdly. The `Network` tab is for experienced users only.

**Kind** — modal settings.

**Sources** — https://www.manualshelf.com/manual/games-pc/command-conquer-red-alert-2/user-guide-english.html ·
https://steamcommunity.com/app/2229850/discussions/0/4333105405784044716 ·
https://forums.cncnet.org/topic/12625-options-menu-out-of-sync-red-alert-2-solved

**Confidence** — high.

---

### RA2-UI-006 Load / Save Dialog

**What** — Campaign (and patched skirmish) save list. The manual instructs saving each mission to separate slots so the
player can return to difficult parts. Load Saved Game is reached from the Single Player menu. Typically shows slot
thumbnail/name/mission and a date/save time.

**Data keys** — Save slot list, mission name/id, timestamp, player side/country.

**Numbers** — No fixed slot count exposed by sources; multiple named slots are supported.

**Edge cases** — *Save* is not available in multiplayer LAN/Internet games; campaign auto-saves at a checkpoint that can
be resumed by starting the campaign. Skirmish saves require a fan patch (CnCNet).

**Kind** — file/session management.

**Sources** — https://www.manualshelf.com/manual/games-pc/command-conquer-red-alert-2/user-guide-english.html ·
https://cnc.fandom.com/wiki/Skirmish

**Confidence** — med.

---

### RA2-UI-007 Pause / In-Game Game Menu

**What** — Esc / F10 (or the P pause key in some references) opens the in-game menu: Resume, Options, Restart Mission
(campaign), Save/Load, and Return to Main Menu / Quit. The game freezes; a translucent overlay sits over the tactical
map. The manual also refers to an "in-game options menu (esc or F10)".

**Data keys** — Current mission/scenario id, side/country, game speed, difficulty.

**Numbers** — none meaningful.

**Edge cases** — Restart Mission is campaign-only. "Return to Main Menu" may warn about unsaved progress. The
pause/menu key reads differently across sources: DefKey lists `P` = Pause and `Esc` = Game menu; CnCmaps lists no `P`.
Treat `Esc` as the reliable menu key.

**Kind** — modal pause.

**Sources** — https://defkey.com/command-conquer-red-alert-2-shortcuts ·
https://steamcommunity.com/app/2229850/discussions/0/596279056135113836

**Confidence** — med.

---

### RA2-UI-007b Briefing Screen

**What** — At mission start (and via the in-game **Briefing button** at the very top of the command bar in single
player/co-op) the objective list is reviewed. The mission intro is an EVA-text briefing popup, sometimes with an FMV;
objectives can be added mid-mission ("New Objective Received", "watch for new mission objectives").

**Data keys** — Objective tokens (primary/optional), mission timer, briefing text, new-objective triggers.

**Numbers** — Some missions carry an explicit timer (e.g. Allied M8 "appointed time" Chronosphere experiment; Allied
M2 "25 minutes" convoy). Timers display red when under `TimerWarning=2` minutes.

**Edge cases** — In multiplayer the Briefing button is replaced by a **Diplomacy** button (Tab). New objectives and
targets of opportunity are scripted per map.

**Kind** — modal/in-game overlay.

**Sources** — https://www.manualshelf.com/manual/games-pc/command-conquer-red-alert-2/user-guide-english.html ·
http://ra.afraid.org/html/ra/a_wt.html · https://cnc.fandom.com/wiki/Lone_Guardian

**Confidence** — high.

---

### RA2-UI-008 Score Screen / Post-Game

**What** — After a mission/match, a statistics screen summarises the outcome (and, in skirmish/MP, ranking). Campaign
missions show success/failure and continue/unlock. Sources are thin on the exact fields; RTS-standard fields are time,
units built/lost, kills, credits harvested, buildings destroyed.

**Data keys** — Per-player score components; win/lose flag; medals/par times (re-release context).

**Numbers** — Not authoritatively enumerated for RA2. The manual's `CampaignMoneyDelta` and score are separate systems.
A per-mission "par time" exists for re-release/remaster scoring but is not documented for retail RA2.

**Edge cases** — Skirmish end screen can be reached without playing if a game instantly resolves (known CnCNet bug
thread). Score graphs appear on some score screens.

**Kind** — post-game modal.

**Sources** — https://forums.cncnet.org/topic/9981-red-alert-2-skirmish-gameplay-issue-skips-game-to-end-stats-screen ·
https://www.reddit.com/r/commandandconquer/comments/h9go5e/how_are_the_end_screen_totals_calculated

**Confidence** — low.

---

### RA2-UI-009 Quit / Confirmation Dialog

**What** — `Exit Game` on the main menu terminates to the desktop; leaving a live match prompts a confirmation
(yes/no). Standard modal "are you sure" pattern.

**Data keys** — none.

**Numbers** — none.

**Edge cases** — `GameClosed=GameClosed` is the "game closed" audio hook in rules.ini; exiting mid-match may warn
about lost progress.

**Kind** — modal confirmation.

**Sources** — https://www.manualshelf.com/manual/games-pc/command-conquer-red-alert-2/user-guide-english.html

**Confidence** — med.

---

### RA2-UI-010 Multiplayer / Network Lobby

**What** — Two paths: **Internet** (Westwood Online) and **Network** (LAN). Both lead to a lobby where players chat,
pick country/colour/team, set the map and scenario conditions, and the host starts the game. Online supported
tournaments, private/public games, ladder ranking and a chat system, and the **World Domination Tour** mode (first seen
in Firestorm).

**Data keys** — Player list rows (name, country, colour, team, ready), host flags, map, scenario conditions, chat
channel, ladder/rank flags.

**Numbers** — Up to 8 players per game. Five co-op campaigns in RA2.

**Edge cases** — Westwood Online shut down in 2005 and was replaced by XWIS, then CnCNet. LAN used obsolete **IPX**;
a community patch swaps it for UDP (Tunngle/Hamachi era). Lobby chat commands: Enter = all chat, Backspace = team
chat; beacons can be placed and clicked to message allies.

**Kind** — networked lobby.

**Sources** — https://cnc.fandom.com/wiki/Command_%26_Conquer:_Red_Alert_2 ·
https://www.manualshelf.com/manual/games-pc/command-conquer-red-alert-2/user-guide-english.html ·
https://cnc.fandom.com/wiki/World_Domination_Tour

**Confidence** — high (flows), med (per-version details).

---

### RA2-UI-011 Map Selection / Random Map

**What** — Map list with preview (name, size, number of players, starting positions). The built-in random map generator
can produce a fresh map from a seed, integrated into skirmish and multiplayer.

**Data keys** — Map file (`.map`/`.mpr`), size (S/M/L/XL), player count, random-map seed & tile set, "Use map settings".

**Numbers** — Map sizes commonly Small/Medium/Large/Huge; official map packs exist (12 map packs in the ModDB pack).
Random maps exist in TS, RA2 and YR.

**Edge cases** — Added maps lengthen the roster load. Some official pre-release/E3 maps survive on the disc but are
unusable due to engine changes.

**Kind** — setup.

**Sources** — https://cnc.fandom.com/wiki/Skirmish · https://www.moddb.com/games/cc-red-alert-2/addons/cc-red-alert-2-map-packs ·
https://cnc.fandom.com/wiki/Command_%26_Conquer:_Red_Alert_2

**Confidence** — med.

---

## B. In-Game HUD

### RA2-UI-020 Sidebar Layout and Tabs

**What** — The RA2 sidebar sits on the **right** edge. Top-to-bottom: **credits**, **radar/minimap (or side logo if
radar is offline)**, **repair (wrench) / sell ($) buttons**, then the build area. RA2 replaces TS's single queue with
**four tabs**: **Structures** (Q), **Armory/Defenses + support powers** (W), **Infantry** (E), **Vehicles** (R; includes
aircraft and naval). Below the minimap is the **Briefing** button (single-player) or **Diplomacy** button (multiplayer).
The bottom of the screen has the selected-object info strip and an "Advanced Command Bar" tab.

**Data keys** — `BuildCat` determines which tab a structure appears in: `Combat`, `Resource`, `Power`, `Tech`,
`Infrastructure`, `DontCare` (the last displays as partly-built). `Tab=`/sidebar icons are per-object cameos.
`BuildCat` is a RA2-new key; its precise effect on tab assignment is not fully determined by ModEnc.

**Numbers** — 4 tabs (RA2/YR). TS had a 2-strip layout; TW/RA3 later had 6–7 tabs. Some third-party docs describe the
sidebar as "6-tab" for later engine variants; RA2 itself is **4**.

**Edge cases** — **Conflicts:** the task brief calls RA2 a "6-tab sidebar". The authoritative engine behaviour and the
C&C Wiki both say RA2/YR is **4 tabs** (Structures, Defenses/Armory, Infantry, Vehicles). The 6–7 tab layout belongs to
Tiberium Wars / Red Alert 3. Defenses build independently of the structure queue in RA2. Sidebar can be visually toggled
in later games (End key in TW), not vanilla RA2.

**Kind** — persistent HUD.

**Sources** — https://cnc.fandom.com/wiki/Sidebar · https://modenc2.markjfox.net/BuildCat ·
https://www.manualshelf.com/manual/games-pc/command-conquer-red-alert-2/user-guide-english.html ·
https://vinifera.readthedocs.io/en/latest/User-Interface.html

**Confidence** — high.

---

### RA2-UI-021 Cameo Grid and Scrolling

**What** — Each buildable object has a **cameo** (sidebar image) in its tab. The grid is scrollable with the **mouse
wheel** (since TS). Clicking a cameo starts production; clicking a partial/queued cameo stacks more.

**Data keys** — `Cameo=filename` (art.ini, no extension, `.SHP` assumed, case-insensitive) and `AltCameo=` (veteran
cameo, usually `____uico.shp`). Missing cameo falls back to `XXICON`. Cameos are 60×48 (RA2/YR) vs 64×48 (TS).

**Numbers** — TS cameo 64×48; **RA2/YR cameo 60×48**. RA2 tolerates 64×48 and 64×64 without obvious failure.
`gclock2.shp` charge overlay should have **55 frames**.

**Edge cases** — AltCameo "upgrade" bugs: after a War Factory is infiltrated, naval `Trainable` vehicle cameos show the
veteran art although they do not start veteran (fixed by Ares); units that start veteran via `VeteranUnits`/
`VeteranInfantry` do *not* show the upgraded cameo.

**Kind** — HUD grid.

**Sources** — https://modenc2.markjfox.net/Cameo · https://modenc2.markjfox.net/AltCameo ·
https://cnc.fandom.com/wiki/Sidebar

**Confidence** — high.

---

### RA2-UI-022 Per-Cameo States

**What** — A cameo can render several states: normal, hover/pressed, **build-in-progress** (darkened with a progress
sweep), **ready/charged**, **unaffordable** (greyed), **queued ×N** (a small count badge/stack), **primary building**
(indicator), and **charged superweapon** (charging indicator sweep/clock). Veteran cameos replace normal art when the
produced unit will be veteran.

**Data keys** — `Cameo`, `AltCameo`, `Cameo Charging Indicator` (gclock2.shp overlay), queue count, `BuildCat=DontCare`
(pseudo partial-build art), `Primary` (factory primary selection).

**Numbers** — Charging overlay animation `gclock2.shp` from `sidec0#(md).mix`, drawn with `sidebar.pal`; expected
**55 frames**. `Side` chooses the mix number (GDI 1, Nod 2, ThirdSide 3 with `LoadSpecialYuriUI`).

**Edge cases** — The "percentage complete" overlay is applied to *all* cameos while anything is being built/charged.
Mis-sized SHP causes visual glitches.

**Kind** — HUD state rendering.

**Sources** — https://modenc2.markjfox.net/Cameo_Charging_Indicator · https://modenc2.markjfox.net/Cameo

**Confidence** — high.

---

### RA2-UI-023 Queue Display / Production Strip

**What** — RA2 raises the per-type unit queue from TS's 5 to a long queue (wiki: "raised from 5 to 30"). A maximum of
30 queued objects is enforced (`MaximumQueuedObjects=29`, i.e. 29 + the in-progress item). Multiple clicks on a cameo
stack identical units; a queue strip/stack of mini-icons or a count is shown. Structures are single-queue ("a building
under construction renders all other building buttons unusable" until finished).

**Data keys** — Queue per object type, production progress, factory list (primary building), `MultipleFactory` speed
multiplier.

**Numbers** — **30** queued objects (RA2/YR). `MaximumQueuedObjects=29`. `MultipleFactory=0.8` (each extra factory
multiplies build time by 0.8 cumulatively). `BuildSpeed=.7` minutes to build a 1000-credit item.

**Edge cases** — Producing from multiple factories speeds all units of that queue but the AI gets per-factory queues
(players do not). Only buildings block the structure queue; units can be queued in parallel.

**Kind** — HUD queue.

**Sources** — https://cnc.fandom.com/wiki/Sidebar ·
https://forums.cncnet.org/topic/8696-how-to-get-rid-of-maximum-30-units-build-queue · `rulesmd.ini` General section

**Confidence** — high.

---

### RA2-UI-024 Credits Counter

**What** — Numeric credit balance at the top of the sidebar, with tick-up/tick-down sounds (`CreditTicks=CreditUp,
CreditDown`) and a "cash stolen"/"credits" visual when money changes. Ore/gems are harvested by miners and refined.

**Data keys** — House credits, harvester storage, refinery/purifier bonuses, `RefundPercent`, `SoloCrateMoney`.

**Numbers** — `RefundPercent=50%` on sale. `PurifierBonus=.25` (Ore Purifier +25%). Money crate $2000 (crate
contents) / `SoloCrateMoney=5000` in solo missions. Spy steals up to 50% (`SpyMoneyStealPercent=.5`, wiki says 20%).

**Edge cases** — **Conflicts:** wiki says a Spy steals "20% of the targeted player's funds"; the shipped
`SpyMoneyStealPercent=.5`. Trust the INI for YR (50%).

**Kind** — HUD readout.

**Sources** — `rulesmd.ini` General / AudioVisual · https://cnc.fandom.com/wiki/Crate_(Red_Alert_2) ·
https://cnc.fandom.com/wiki/Spy_(Red_Alert_2)

**Confidence** — high.

---

### RA2-UI-025 Power Bar

**What** — A thin vertical meter on the **far left** of the sidebar. Green = surplus, yellow = small shortfall, red =
underpowered (red lights rise above green/yellow). When total drain exceeds supply, production slows and radar (and
some weapons) may go offline.

**Data keys** — Per-building `Power=` (negative drain / positive supply); `Power` pips have no display effect
(`PipScale=Power` = no pips). Low-power production model keys: `MinLowPowerProductionSpeed=.5`,
`MaxLowPowerProductionSpeed=.8`, `LowPowerPenaltyModifier=1`.

**Numbers** — Low-power production floor **50%**, max **80%** (so ~99% supplied still treated as 80%). Colours: green /
yellow / red.

**Edge cases** — Losing power disables radar and slow-fires many defenses. Spy power sabotage cuts power 30–60 s
(wiki) / `SpyPowerBlackout=1000` frames (INI). Low power causes trivial structure damage over time (`DamageDelay=1` min).

**Kind** — HUD meter / game state.

**Sources** — https://cnc.fandom.com/wiki/Sidebar · `rulesmd.ini` General ·
https://cnc.fandom.com/wiki/Spy_(Red_Alert_2)

**Confidence** — high.

---

### RA2-UI-026 Repair and Sell Buttons

**What** — Above the build area: **Repair** (wrench, K) and **Sell** ($, L). Repair turns the cursor into a wrench;
clicking a damaged friendly building repairs it over time while draining credits (`RepairPercent`, `RepairRate`,
`RepairStep`), showing a wrench above the building. Sell turns the cursor into a `$`; clicking a building deconstructs
it instantly, refunding `RefundPercent` and often spawning a few free infantry ("survivors").

**Data keys** — `RefundPercent=50%`, `RepairPercent=15%`, `RepairRate=.016`, `RepairStep=8`, `SellSound`,
`SurvivorRate`, `AlliedSurvivorDivisor=500`, `SovietSurvivorDivisor=250`, `ThirdSurvivorDivisor=750`.

**Numbers** — Sell refund **50%**; full repair costs **15%** of build cost; repair tick **8 HP** / `.016` min. Survivor
count = sell cost ÷ side divisor.

**Edge cases** — Tech/civilian buildings cannot be sold. Repaired buildings clear damaged frames and fire animation.
Selling is the standard way to clear blocked build plots.

**Kind** — HUD action.

**Sources** — https://cnc.fandom.com/wiki/Sidebar ·
https://www.manualshelf.com/manual/games-pc/command-conquer-red-alert-2/user-guide-english.html · `rulesmd.ini` General

**Confidence** — high.

---

### RA2-UI-027 Lower Bar / Selected-Unit Information Panel

**What** — The bottom strip shows selected-unit portraits/icons, current health bar, veterancy pips and (where
applicable) cargo pips. The **Advanced Command Bar** (opened by the tab at the bottom of the battle display) exposes
team-creation buttons, waypoint-mode, beacon button, guard/scatter/deploy, and other commands. Object names come from
CSF via `UIName=Name:<id>`.

**Data keys** — `UIName`, selection set, health, veterancy rank, pips, team slots (1–9 / 0), command buttons.

**Numbers** — Advanced bar team buttons = 10 slots (Ctrl+1–9, and often 0). Health colour thresholds 50/25 %. Tooltip
delay 2 s.

**Edge cases** — Multiple-selection shows a grid of cameos/health bars; health of the "weakest" member is often the
aggregate shown. Enemy health bars only appear if `EnemyHealth=yes` (default yes) and when selected/hovered.

**Kind** — HUD info panel.

**Sources** — https://www.manualshelf.com/manual/games-pc/command-conquer-red-alert-2/user-guide-english.html ·
https://modenc2.markjfox.net/UIName · `rulesmd.ini` AudioVisual (`EnemyHealth=yes`)

**Confidence** — high.

---

### RA2-UI-028 Message Ticker / Chat Overlay

**What** — Transient text messages appear over the tactical map ("message ticker"): multiplayer chat (all/team), AI
taunts, beacons, and system messages. Enter opens all-chat, Backspace opens team-chat; messages are typed with a
`TextBleep` sound per character and fade after `MessageDelay`.

**Data keys** — `IncomingMessage=MessageText`, `MessageCharTyped=TextBleep`, `MessageDelay=.6`, `SystemError`,
`PlayerJoined`, `GameClosed`.

**Numbers** — `MessageDelay=.6` (time display duration). Chat character bleep per keystroke.

**Edge cases** — Campaign taunts use F1–F8 (see hotkeys; conflicts with bookmarks). Beacons are visible only to
allies; clicking a beacon + Enter messages allies.

**Kind** — HUD overlay / chat.

**Sources** — https://www.manualshelf.com/manual/games-pc/command-conquer-red-alert-2/user-guide-english.html ·
`rulesmd.ini` AudioVisual · https://cncmaps.net/red-alert-2-hotkeys

**Confidence** — med.

---

## C. Radar / Minimap

### RA2-UI-040 Radar and Minimap

**What** — The square minimap at the top of the sidebar (under credits) shows explored terrain, units, buildings and
ore, colour-coded per house. When the radar provider is absent, unpowered, destroyed or jammed, it is replaced by the
side logo and cannot be clicked. Clicking the minimap **moves the camera** to that point; in campaign the radar also
doubles as a **video screen** for briefings/transmissions.

**Data keys** — Radar provider per side: Allies = **Air Force Command Headquarters** (and **Spy Satellite Uplink**
revealing the whole map); Soviets = **Radar Tower** (YR: periodic Spy Plane); Yuri = **Psychic Radar** (Psychic Reveal).
`LocalRadarColor=0,255,0` (your blip is always green). `RadarOn`/`RadarOff` audio.

**Numbers** — Radar event visibility `RadarEventVisibilityDurations=200` frames, duration `=400`, suppression
distance `=8` cells, `RadarEventMinRadius=8`, `FlashFrameTime=7`, `RadarCombatFlashTime=49`.

**Edge cases** — Losing the Spy Satellite Uplink resets shroud. Losing radar does not lose the map memory (shroud stays
explored) but disables minimap interaction. Submerged subs and cloaked units are hidden from radar unless detected.

**Kind** — minimap / strategic overlay.

**Sources** — https://cnc.fandom.com/wiki/Radar · `rulesmd.ini` radar-event block

**Confidence** — high.

---

### RA2-UI-041 Radar Events, Flash and Suppression

**What** — Radar events draw an animated pulse/flash on the minimap and optionally pan the view to draw attention.
YR's rules enumerate **six** event types in order: (1) Generic Combat, (2) Generic Noncombat, (3) Dropzone,
(4) Base Under Attack, (5) Harvester Under Attack, (6) Enemy Object Sensed. "Base Under Attack" also triggers a siren
(`BaseUnderAttackSiren`).

**Data keys** — `RadarEventSuppressionDistances`, `RadarEventVisibilityDurations`, `RadarEventDurations`,
`FlashFrameTime`, `RadarCombatFlashTime`, `RadarEventMinRadius`, `RadarEventSpeed`, `RadarEventRotationSpeed`,
`RadarEventColorSpeed`.

**Numbers** — Each of the six events has its own visibility (200 f), duration (400 f) and suppression (8 cells,
6 for sensed). `RadarCombatFlashTime / FlashFrameTime` must be odd.

**Edge cases** — Repeated events within the suppression radius do not re-flash. Combat flash is drawn as an expanding
ring; event colour/speed are tunable.

**Kind** — minimap feedback.

**Sources** — `rulesmd.ini` General (Controls for radar events)

**Confidence** — high.

---

### RA2-UI-042 Radar Destructibility and Blackout

**What** — Radar is **destructible and power-dependent**. It blacks out when: the provider is destroyed, base power is
insufficient, a **Gap Generator** jams the area, a **Spy** infiltrates a radar building (resets shroud), or a
**Lightning Storm** is active (the Weather Control Device disables *all* radars — friendly and enemy — for the storm's
duration). Yuri's **Psychic Radar** can pitch in with temporary reveals.

**Data keys** — Gap Generator `GAGAP`: generates shroud in a **10-tile** radius; requires Battle Lab; `-100` power;
`SuperGapRadiusInCells` (unused deploy). Spy infiltration on `GAAIRC`/`NARADR`/`NAPSIS` resets shroud (no effect if a
working Spy Satellite Uplink exists).

**Numbers** — Gap Generator shroud radius **10 tiles**. Spy power blackout 30–60 s (wiki) / `SpyPowerBlackout=1000`
frames. Lightning Storm duration `LightningStormDuration=180` frames default, `LightningDeferment=250`,
`LightningCellSpread=10`.

**Edge cases** — The Spy Satellite Uplink reveals the map but is itself jammed by a Gap Generator. NightHawk Transports
and Crazy Ivans are hidden from radar; submerged ships are too.

**Kind** — game state / counter system.

**Sources** — https://cnc.fandom.com/wiki/Gap_generator_(Red_Alert_2) ·
https://cnc.fandom.com/wiki/Weather_control_device_(Red_Alert_2) · https://cnc.fandom.com/wiki/Radar ·
`rulesmd.ini`

**Confidence** — high.

---

## D. Selection and Information

### RA2-UI-050 Single and Box Selection

**What** — Left-click selects a single object; left-drag a rubber-band box to select many. Ctrl+click adds/removes.
Double-click / `T` selects all same-type *on screen*; `T` twice selects all same-type **on the map**. `P` selects all
eligible units. `Y` cycles selection by veterancy. `U` cycles by health. `N`/`M` jump between units.

**Data keys** — Selection set, same-type filter, veterancy filter, health filter, control groups 1–9.

**Numbers** — Control groups: **9** (Ctrl+1–9); some docs also describe Ctrl+0. Max on-screen selection is
engine-limited, not documented; the queue cap is 30.

**Edge cases** — Box select prioritises combat units and ignores civilians unless nothing else is in the box. Selecting
a building shows its production/primary controls. Right-click clears selection / cancels modes.

**Kind** — input / selection.

**Sources** — https://cncmaps.net/red-alert-2-hotkeys · https://defkey.com/command-conquer-red-alert-2-shortcuts ·
https://strategywiki.org/wiki/Command_%26_Conquer:_Red_Alert_2/Controls (cross-checked, page 403)

**Confidence** — med.

---

### RA2-UI-051 Selection Brackets

**What** — Selected objects get a four-corner bracket (green for own units, red for enemies in some games). Air units,
buildings and infantry all bracket; brackets scale to the object's footprint/mesh. Health bars sit under the bracket.

**Data keys** — Selection overlay flags; bracket colour by relation; building footprint (`Foundation`).

**Numbers** — None documented precisely.

**Edge cases** — Multi-select draws brackets around every member plus an aggregate info panel. Box-select over many
units can show only a subset due to the info panel's icon grid.

**Kind** — HUD overlay.

**Sources** — https://cnc.fandom.com/wiki/Sidebar (health/selection conventions); general C&C UI

**Confidence** — low/med.

---

### RA2-UI-052 Health Bars and Condition Colours

**What** — Health is drawn as a horizontal bar that shifts **green → yellow → red** as the object loses hit points.
Buildings show damaged frames and an on-fire animation when below the yellow/red thresholds; `CanBeOccupied` buildings
catch fire only in the red. Smoke-type damage particles and the building-damage sound are hardcoded to start below 50 %.

**Data keys** — `ConditionYellow=50%`, `ConditionRed=25%`. Related: `DamageFireTypes=FIRE01,FIRE02,FIRE03`,
`ActiveAnimDamaged`, `ConditionYellowSparkingProbability`, `ConditionRedSparkingProbability`, `SelfHealing`,
`DamageDelay`, `Culling`.

**Numbers** — Yellow at **50 %**, red at **25 %** of original `Strength`. Smoke/spark particles appear on entering
yellow or red (a change is required).

**Edge cases** — Civilian (`TechLevel=-1`) and `CanBeOccupied` buildings only animate fire in red. Repairs/self-heal
back to green remove the smoke particle. `EnemyHealth=yes` (default) shows enemy bars when selected/hovered.

**Kind** — HUD / condition system.

**Sources** — https://modenc2.markjfox.net/index.php?title=ConditionYellow&action=raw ·
https://modenc2.markjfox.net/index.php?title=ConditionRed&action=raw · `rulesmd.ini` AudioVisual

**Confidence** — high.

---

### RA2-UI-053 Veteran / Elite Chevrons

**What** — Two veterancy ranks above rookie: **Veteran** (one chevron) and **Elite** (three chevrons). Promotions play
the EVA line "unit promoted" and a sound (`UpgradeVeteranSound`/`UpgradeEliteSound`); a new Elite flashes
(`EliteFlashTimer`). Promoted units get damage/armour/speed/ROF bonuses; Elites self-heal and gain improved weapons
(e.g. elite GI outranges a Sentry Gun; elite Tesla Trooper bolts bounce).

**Data keys** — `VeteranRatio=3.0`, `VeteranCombat=1.1`, `VeteranSpeed=1.2`, `VeteranArmor=1.5`, `VeteranROF=0.6`,
`VeteranCap=2`, `InitialVeteran`, `Trainable`, `VeteranAbilities`/`EliteAbilities`.

**Numbers** — Promotion threshold = destroy **3×** the unit's own cost (RA2; TS was 10×). Bonuses at veteran:
**×1.1 damage, ×1.2 speed, ×1.5 armour, ×0.6 ROF delay (≈+66 % fire rate)**; elite self-heals.

**Edge cases** — Some units cannot gain veterancy (e.g. TS Cyborg Commando etc.; in RA2, crate veterancy can promote
units that normally cannot rank, per wiki). Spy infiltration of a Barracks/War Factory makes newly produced infantry/
vehicles start at veteran. Elite abilities are unit-specific.

**Kind** — HUD pips / progression.

**Sources** — https://cnc.fandom.com/wiki/Veterancy · `rulesmd.ini` General (veteran factors)

**Confidence** — high.

---

### RA2-UI-054 Charge / Timer Pips

**What** — Special units build a charge shown as pips or as a floating indicator — e.g. TS mobile EMP `PipScale=charge`
(eight pips, 12.5 % each); RA2/YR superweapons charge on their cameo; the Iron Curtain/Chronosphere show charge rings.
Charge-up animations run before a charged shot (Obelisk charge animation in TS; RA2 uses weapon charge visuals).

**Data keys** — `PipScale=charge` (TS/FS only), `MaxCharge`, cameo charging indicator (`gclock2.shp`), superweapon
`RechargeTime`/`ChargeTime`.

**Numbers** — TS mobile EMP: **8 pips** × 12.5 %. `gclock2.shp` expected **55 frames**.

**Edge cases** — `PipScale=power` is parsed but displays nothing. Charging overlay is shared by building and
superweapon cameos.

**Kind** — HUD pips / superweapon state.

**Sources** — https://modenc2.markjfox.net/PipScale · https://modenc2.markjfox.net/Cameo_Charging_Indicator

**Confidence** — high.

---

### RA2-UI-055 Passenger / Cargo / Ammo Pips

**What** — Vehicles display up to a row of **pips** for cargo (`PipScale=Passengers`), ammo (`PipScale=Ammo`), and
harvested ore (`PipScale=Tiberium`), using `pips.shp`/`pips2.shp` frames. YR adds `PipScale=MindControl` pips showing
how many units a mind-controller holds. Pip art is remapped per house.

**Data keys** — `PipScale`, `Passengers`, `SizeLimit`, `Size`, `Ammo`, `Storage`, `Harvester`, `Weeder`, `PipWrap`,
`Pip`, `MaxNumberOccupants` (building occupancy pips), `InfiniteMindControl`, `OverloadDamage`.

**Numbers** — Passenger pips: count = `Passengers`; a Size>1 passenger consumes that many pips. Ammo (RA2, `PipWrap=0`)
draws one pip per round using pips2 frame 14 (15 in YR). Tiberium: exactly **5 pips** × 20 % of `Storage` (vehicles),
3 pips for enslaved infantry in YR. MindControl pips = weapon `Damage`. TS ammo draws max **5** pips (each 20 %).

**Edge cases** — Passenger pips override ammo pips. `PipScale=Ammo` + `Passengers` together distorts rendering
(known bug). `PipScale=MindControl` with huge `Damage`/`Range`/`GuardRange` can slow the game badly. Infantry pips in
occupied buildings always use the 4th frame of `pips.shp`, one per infantry regardless of Size.

**Kind** — HUD pips.

**Sources** — https://modenc2.markjfox.net/PipScale · https://modenc2.markjfox.net/PipWrap ·
https://ppmforums.com/topic-39416/infantry-pip-in-red-alert-2

**Confidence** — high.

---

### RA2-UI-056 Enemy Health Bar Option

**What** — `EnemyHealth=yes` in `[AudioVisual]` (default) enables the health-bar graph on enemy objects when
selected/hovered. When off, enemy health is hidden until the object is selected.

**Data keys** — `EnemyHealth`.

**Numbers** — default **yes**.

**Edge cases** — Own/ally health always shows; the option only governs enemies. Damage numbers are not shown (RA2 has
no floating combat text).

**Kind** — HUD option.

**Sources** — `rulesmd.ini` AudioVisual · https://modenc2.markjfox.net/index.php?title=ConditionYellow&action=raw

**Confidence** — high.

---

## E. Full Control Scheme

### RA2-UI-060 Default Hotkeys and Assignable Actions

**What** — RA2's default bindings. The Keyboard options tab allows rebinding and a Reset All. Tables below consolidate
CnCmaps, DefKey and the manual; **conflicts are flagged**.

**Catalog** — see the hotkey table in §H/§E below (Consolidated hotkey table).

**Numbers** — 9 control groups; 4 sidebar tabs (Q/W/E/R); 4 bookmarks (F1–F8 or Ctrl+F1–F4 depending on source);
F1–F8 taunts vs bookmarks conflict.

**Edge cases** — `Tab` = Diplomacy menu (CnCmaps) vs `Tab` = select next idle unit (DefKey). `Y` = cycle elite/veteran/
regular (CnCmaps) vs `Y` used elsewhere; `U` = cycle by health. F1–F8 = taunts (CnCmaps) vs bookmarks (DefKey/manual).

**Kind** — input mapping.

**Sources** — https://cncmaps.net/red-alert-2-hotkeys · https://defkey.com/command-conquer-red-alert-2-shortcuts ·
https://www.manualshelf.com/manual/games-pc/command-conquer-red-alert-2/user-guide-english.html

**Confidence** — med (conflicts noted).

---

### RA2-UI-061 Control Groups

**What** — Ctrl+1–9 assigns the current selection to a numbered team; pressing 1–9 recalls it. Groups persist across
the match and show a numbered badge. Double-tapping a group number centres the camera on it. Some builds also support
group 0.

**Data keys** — 9 group slots; per-group composition.

**Numbers** — **9** groups (Ctrl+1–9).

**Edge cases** — Assigning an empty selection clears the group. Dead units drop out. Groups can mix unit types. The
manual also provides the Advanced Command Bar team buttons (10 buttons incl. 0 in some layouts).

**Kind** — input / selection.

**Sources** — https://www.manualshelf.com/manual/games-pc/command-conquer-red-alert-2/user-guide-english.html ·
https://cncmaps.net/red-alert-2-hotkeys

**Confidence** — high.

---

### RA2-UI-062 Camera Controls

**What** — Scroll by moving the cursor to a screen edge (green arrow cursor), with arrow keys / numpad also panning.
Page Up/Down zoom in/out. `H` centres on the primary base/MCV. `F` follows the selected unit. Clicking the minimap
jumps the view. `Space` goes to the last alert/action. Bookmarks store camera positions.

**Data keys** — `ScrollMultiplier=.07`, edge-scroll enabled, zoom levels, `CameraRange=9` (spy camera), bookmarks.

**Numbers** — `ScrollMultiplier=.07` multiplier to default scroll speed. Spy-plane camera `SpyPlaneCameraFrames=16`
(reveal `CameraRange=9` cells around the snapshot).

**Edge cases** — Edge scroll can be disabled/tuned. `H` targets the "primary base" object (`BaseUnit=AMCV,SMCV,PCV`).
Some releases bind game speed to a scrollbar rather than zoom.

**Kind** — camera input.

**Sources** — https://defkey.com/command-conquer-red-alert-2-shortcuts · `rulesmd.ini` AudioVisual ·
https://www.manualshelf.com/manual/games-pc/command-conquer-red-alert-2/user-guide-english.html

**Confidence** — med/high.

---

### RA2-UI-063 Right vs Left Click Semantics

**What** — **Left-click** = select / act (select object, issue move/attack order, start production, place building).
**Right-click** = deselect / cancel (clears selection, exits build/repair/sell/deploy modes, cancels wall/planning).
Ctrl+left-click = force-fire on a point (even non-enemy); Ctrl+Shift+left-click = attack-move (cursor rotates);
Alt+left-click = force a crush on a crushable target; Ctrl+Alt+left-click = area-guard/defend. Ctrl+left-click on a
selected unit of the same type applies the command to all of that type.

**Data keys** — Input mode state machine; modifier bits; `AttackCursorOnDisguise=yes` — the attack cursor still
appears over a disguised Spy as if undisguised.

**Numbers** — none.

**Edge cases** — Right-click during a chat/beacon message cancels the message. Force-fire is how you destroy bridges/
walls. The cursor shape is the primary feedback for the current mode (see §F).

**Kind** — input semantics.

**Sources** — https://cncmaps.net/red-alert-2-hotkeys · https://defkey.com/command-conquer-red-alert-2-shortcuts ·
https://www.manualshelf.com/manual/games-pc/command-conquer-red-alert-2/user-guide-english.html
(`AttackCursorOnDisguise` from `rulesmd.ini`)

**Confidence** — high.

---

### RA2-UI-064 Stances, Guard, Rally and Deploy

**What** — `G` = Guard (unit actively scans and attacks in an area). `S` = Stop. `X` = Scatter. `D` = Deploy/undeploy
(GI sandbags, Desolator, Yuri; also exits transports/garrisoned buildings). `Ctrl+Alt+click` = area guard/defend.
Buildings accept **rally points** by selecting the building then clicking the battlefield (a dotted line appears;
produced units auto-move there). `Ctrl+Shift+click` = attack-move.

**Data keys** — `GuardRange`, `GuardModeStray=2.0` cells, `GuardAreaTargetingDelay=36`, `NormalTargetingDelay=27`,
`MaximumCheerRate=300`, rally point per building.

**Numbers** — Guard stray **2.0 cells**; `MaximumCheerRate=300` frames. `CloseEnough=2.25` cells abort threshold.
`Stray=2.0`/`RelaxedStray=3.0` team scatter.

**Edge cases** — `C` = Cheer (units play a cheer animation; limited to once per `MaximumCheerRate`). `D` on a
garrisoned building evacuates occupants (cursor becomes "deploy"). Engineers set to area-guard auto-repair red-health
buildings.

**Kind** — unit orders / AI.

**Sources** — https://cncmaps.net/red-alert-2-hotkeys ·
https://www.manualshelf.com/manual/games-pc/command-conquer-red-alert-2/user-guide-english.html ·
https://modenc2.markjfox.net/index.php?title=ConditionRed&action=raw

**Confidence** — high.

---

### RA2-UI-065 Waypoints and Planning Mode

**What** — Hold `Z` and left-click to drop waypoint nodes; release `Z` and the units follow the path. There is also a
Way Points mode button on the Advanced Command Bar; delete a node by clicking the mode button, selecting the node and
pressing `Del`. Planning-mode sounds exist (`StartPlanningModeSound`, `AddPlanningModeCommandSound`, `ExecutePlanSound`).
Shift+click queues orders.

**Data keys** — `MaxWaypointPathLength=15`, `WaypointAnimationSpeed=10`, planning-mode sound hooks.

**Numbers** — Max waypoint path **15** nodes; animation speed 10.

**Edge cases** — Waypoints let multiple groups attack different points simultaneously. Plan nodes join neighbours when
deleted. Waypoint mode can be held (`Z`) or toggled (button).

**Kind** — input / planning.

**Sources** — https://www.manualshelf.com/manual/games-pc/command-conquer-red-alert-2/user-guide-english.html ·
https://cncmaps.net/red-alert-2-hotkeys · `rulesmd.ini` General/AudioVisual

**Confidence** — high.

---

### RA2-UI-066 Keyboard Configuration Screen

**What** — The Options → Keyboard tab lists all bindable actions with current keys and a **Reset All** button. Bindings
persist in the game's INI (`RA2.ini`/`RA2MD.ini`). The screen is reached from both the main menu and the in-game pause
menu.

**Data keys** — Keybinding table, Reset All.

**Numbers** — 32 bindings counted by DefKey.

**Edge cases** — Some bindings conflict by default across sources (Tab, F1–F8). Game-speed control must be enabled by
editing the INI; it then appears in "Game Controls".

**Kind** — settings.

**Sources** — https://www.manualshelf.com/manual/games-pc/command-conquer-red-alert-2/user-guide-english.html ·
https://defkey.com/command-conquer-red-alert-2-shortcuts

**Confidence** — high.

---

### Consolidated hotkey table

| Key | Action | Source | Confidence |
|-----|--------|--------|-----------|
| Esc / F10 | Game menu / in-game options | manual, DefKey | high |
| P | Pause (DefKey) | DefKey | med |
| Enter | All chat / messages | CnCmaps, manual | high |
| Backspace | Team chat | CnCmaps | high |
| Tab | Diplomacy menu (CnCmaps) / next idle unit (DefKey) | **conflict** | med |
| T | Select all same type on screen; TT = on map | CnCmaps, Steam | high |
| Y | Cycle selection: elite/veteran/regular | CnCmaps | med |
| U | Cycle units by health (red→yellow→green) | DefKey, GameFAQs | med |
| N / M | Next / previous unit | CnCmaps, DefKey | med |
| P | Select all units (CnCmaps) | CnCmaps | med |
| H | Centre on primary base / MCV | CnCmaps, manual | high |
| F | Follow selected unit | CnCmaps | med |
| Space | Go to last alert / beacon action | CnCmaps | med |
| Z + LMB | Waypoint mode | CnCmaps, manual | high |
| X | Scatter | CnCmaps, DefKey | high |
| S | Stop | CnCmaps | high |
| G | Guard | CnCmaps | high |
| D | Deploy / undeploy / exit | CnCmaps, manual | high |
| K | Repair mode | CnCmaps, DefKey | high |
| L | Sell mode | CnCmaps, DefKey | high |
| Q / W / E / R | Structures / Defenses / Infantry / Vehicles tabs | CnCmaps, DefKey, manual | high |
| Ctrl+1–9 | Assign control group | all | high |
| 1–9 (0) | Select control group | all | high |
| Ctrl+LMB | Force fire; on same-type applies to all | CnCmaps, DefKey, manual | high |
| Ctrl+Shift+LMB | Attack-move | CnCmaps, DefKey | high |
| Alt+LMB | Run over / crush | CnCmaps, DefKey | high |
| Ctrl+Alt+LMB | Area guard / defend | CnCmaps | med |
| Shift+LMB / ↑ | Queue/append order | DefKey, Steam | med |
| F1–F8 | Taunts (CnCmaps) / bookmarks (DefKey) | **conflict** | low |
| Ctrl+F1–F4 | Bookmark assignment (DefKey); Ctrl+F9–F12 (CnCmaps) | **conflict** | low |
| B | Place beacon | CnCmaps, manual | high |
| A / N | Ally / next | CnCmaps | low |
| Arrow keys / numpad | Pan camera | DefKey, manual | high |
| Page Up/Down | Zoom in/out | DefKey | med |
| Del | Delete waypoint (in waypoint mode) | manual | high |

---

## F. Cursors

### RA2-UI-070 Cursor State Catalog and Targeting Rules

**What** — RA2 blits its cursor as a sprite (`mouse.shp` / `mouse.sha`) rather than using the OS pointer. It changes
shape to communicate the current action/mode: select arrow, move (green), attack (crosshair), no-move/invalid, attack-
move (rotating crosshair), force-attack, repair wrench, sell `$`, deploy, enter/garrison, guard, waypoint, rally,
beacon, mind-control, C4, chrono, spy-disguise, spy-infiltrate, Ivan-bomb, squid-grapple, and more. Many art frames
exist in the file but are **unused** by the retail engine (a list from DeeZire is reproduced below).

**Data keys** — `mouse.shp` / `mouse.sha` frame indices; input mode state; `AttackCursorOnDisguise=yes`; `DefaultMirage
Disguises` and `InfantryBlinkDisguiseTime=20` (blinking fake-tree reveals Mirages); `DisabledDisguiseDetectionPercent`.

**Numbers / frame map (DeeZire + CCHyper + Atomic_Noodles, PPM):**

| Frames | Meaning | Used? |
|--------|---------|-------|
| 78–87 | Desolator deploy | yes |
| 88 | Invalid tote/Carryall pickup | engine-dependent |
| 120–128 | Structure deploy/undeploy | **unused** (no engine support) |
| 199–204 | Mirage Tank disguise (not animated) | — |
| 204–208 | Ivan bomb target (only 1 frame used; should animate) | partial |
| 209–213 | Mind Control (Yuri) | yes |
| 214 | Squid Grapple | yes |
| 215–218 | Squid grapple invalid target | yes |
| 219–223 | force move / crush | unknown |
| 224–228 | Spy disguise as target | yes |
| 229–233 | Spy infiltrate structure | yes |
| 239–248 | GI/GGI deploy into sandbags | yes |
| 249–258 | Chronowarp destination (game reuses Chronosphere art) | partial |
| 269–278 | Set rally point (game uses Move cursor) | **unused** |
| 299–308 | Detonate Ivan bomb (game uses C4 cursor) | **unused** |
| 329–338 | teleporting-unit move cursor (Chrono Legionnaire) | — |
| 345 | invalid teleport move destination | — |
| 351–355 | TS Medic heal (reversed, 5 frames cut) | unused |
| 413–421 | Evacuate garrisoned building | — |
| 422–430 | Enter cloning vat | — |
| 431 | Invalid mind-control target | — |
| 432 | Invalid rally point (from building) | — |
| 461–469 | Invalid Force Shield target | yes |

**Edge cases** — Targeting rules: attack-on-disguise is controlled by `AttackCursorOnDisguise`; the cursor still shows
attack over a disguised Spy. A fake-blinking Mirage Tank reveals itself (`InfantryBlinkDisguiseTime=20`, must be >8 to
be reliable) and nearby units may detect it (`DisabledDisguiseDetectionPercent=15,5,2` h/m/e per unit). Mind-control
units show a different invalid-target cursor when the target is immune (e.g. Tanya in YR). Cursor editing requires
Ares to add brand-new cursors. `mouse.sha` has no shadow frames (SHP Builder shows the second half as shadows).

**Kind** — cursor / targeting.

**Sources** — https://ppmforums.com/topic-33959/unused-mouse-shashp-frames ·
https://modenc.renegadeprojects.com/Cursor (page later deleted; content reconstructed from PPM) ·
`rulesmd.ini` (`AttackCursorOnDisguise`, `DefaultMirageDisguises`) · https://github.com/gitTerebi/ra2-hwcursor-wasd

**Confidence** — med (frame map is community-reconstructed).

---

## G. EVA

### RA2-UI-080 EVA per Faction and Line Catalog

**What** — "EVA" is the in-game announcer: **Lt. Eva Lee** for the Allies (Athena Massey), **Lt. Zofia** for the
Soviets (Aleksandra Kaniak, in the FMV cast), and the **Yuri Announcer** in YR. Lines cover mission flow, economy,
combat warnings, infiltration, superweapons and support powers. Advice repeats after `SpeakDelay=2` minutes.

**Data keys** — EVA line IDs in `ra2.csf`/`ra2md.csf`; `SpeakDelay=2`, `MessageDelay=.6`; per-faction voice sets;
`EVA` warnings are triggered by game events (superweapon detection/ready, base under attack, etc.).

**Numbers** — `SpeakDelay=2` minutes between repeated advice; `TimerWarning=2` min (mission timer turns red).

**Edge cases** — Allied vs Soviet lines differ in delivery but share most functional strings; some lines are
faction-specific ("Battle Control Online" etc.). Robot Tanks produce "Robot Tanks Offline/Back Online" (YR China?).
"Additional Resources" line label is uncertain (listed as unknown in the source).

**Catalog** — see the EVA table below.

**Kind** — audio / announcer.

**Sources** — https://www.myredstone.top/en/archives/2515 · https://cnc.fandom.com/wiki/Eva_Lee ·
https://cnc.fandom.com/wiki/Zofia · https://www.youtube.com/watch?v=LMTpw5RUmaU (EVA comparison) ·
`rulesmd.ini` AudioVisual

**Confidence** — high (catalog), med (exact faction attribution of each line).

---

### EVA line catalog

| Category | Lines (paraphrased/verbatim from the MyRedstone transcript) |
|----------|--------------------------------------------------------------|
| Mission start/flow | Establish Battlefield Control, Stand By · Battle Control Online · Incoming Transmission · New Objective Received · Objective Complete · Mission Accomplished · Mission Failed · Reinforcements Have Arrived · Battle Control Terminated |
| Loss warnings | Unit Lost · Critical Unit Lost · Critical Structure Lost · Our Base Is Under Attack · Our Ally Is Under Attack |
| Economy | Ore Miner Under Attack · Insufficient Funds · Additional Resources (label uncertain) |
| Production | Building (under construction) · Training · Unable To Comply, Building in Progress · On Hold · Canceled · Low Power · Construction Complete · Unit Ready · New Construction Options |
| Buildings/factories | New Rally Point Established · Primary Building Selected · Structure Sold · Repairing · Unit Repaired · Structure Repaired · Bridge Repaired |
| Capture/infiltration | Building Captured · Tech Building Captured · Hospital Captured · Machine Shop Captured · Airfield Captured · Secret Lab Captured · Oil Refinery Captured · Repair Facility Captured · Tech Building Lost · Building Infiltrated · Radar Sabotaged · Cash Stolen · Power Sabotaged · Enemy Power Restored |
| Occupancy | Structure Garrisoned · Structure Abandoned · All Infantry Units Are Now Auto-Heal · All Vehicles Are Now Auto-Repair · You Can Recruit Para-Troopers · New Technology Available |
| Superweapons | Warning: Iron Curtain Detected/Activated · Iron Curtain Ready · Warning: Nuclear Silo Detected · Warning: Nuclear Missile Launched · Nuclear Missile Ready · Warning: Chronosphere Detected/Activated · Chronosphere Ready · Warning: Weather Control Device Detected · Warning: Lightning Storm Created · Lightning Storm Ready · Warning: Genetic Mutator Detected/Activated · Genetic Mutator Ready · Warning: Psychic Dominator Detected/Activated/Ready |
| Support powers | Force Shield Ready · Reinforcements Ready · Spy Plane Ready · Select Target |
| Promotion/misc | Unit Promoted · Unit Armor Upgraded · Unit Firepower Upgraded · Unit Speed Upgraded · Cannot Deploy Here · Robot Tanks Offline/Back Online · Player Defeated · You Are Victorious · You Have Lost |

---

## H. Unit Voices

### RA2-UI-090 Voice Categories and Idle Behaviour

**What** — Each unit type has a CESP-style voice set organised by event: **created**, **selected**, **move order**,
**attack order**, **task acknowledgement**, **task complete**, **under fire/suppressed**, **death cry**, and unit-
specific lines. Idle infantry occasionally play idle barks (`IdleActionFrequency=.15` min). Different sides have
distinct voice sets; YR Tanya is the only unit in the series with two entirely different in-game voice sets (RA2 vs YR).

**Data keys** — Per-unit voice set IDs (`VoiceSelect`, `VoiceMove`, `VoiceAttack`, `VoiceSpecialAttack`, `VoiceDie`,
`VoiceFeedback`, `CreateSound`, `DieSound`, `MoveSound`, `AttackSound`, `VoiceIFVRepair`); `IdleActionFrequency=.15`.

**Numbers** — Idle action every ~**0.15 minutes**. OpenPeon catalogues **438 sounds across 9 categories** for the RA2
pack (session start, task acknowledge/progress/complete/error, input required, resource limit, user spam, session end).

**Edge cases** — Voices play over the announcer; suppression plays a distinct "under fire" category. Vehicles/aircraft/
vessels each have a "reporting" created line. Dogs and civilians have limited sets. The CnCNet community maintains a
spreadsheet of all spoken/ambient lines (offsite Google Drive).

**Catalog (categories + representative lines):**

| Category | Example lines |
|----------|---------------|
| Created/ready | Agent ready · Conscript reporting · Kirov reporting · Black Eagle reporting · Tesla suit ready · Seal ready · Vessel ready |
| Selected (input.required) | Orders · Orders comrade · Mission sir · Give me a job · Pick a spot · Awaiting orders · Commander? |
| Move (task.progress) | Moving out · On my way · Da! · For the Union! · Operation underway · Bound forward |
| Attack (task.complete) | Attacking · Fire at will · Cha-ching · Bag 'em up · Locked and loaded · He's fried |
| Under fire (task.error) | I'm hit · We're being attacked · Mommy! · Mayday mayday · We're going down · Watch my 6 |
| Death | (cry) · unit-specific death line |
| Idle/spam | Why don't you drive · I'm just one man · Where's the party · Tanya laugh · I'm cold |
| Special | Mind control ("His mind is weak") · Disguise ready · Spy infiltrate lines |

**Kind** — audio / VO.

**Sources** — https://openpeon.com/packs/ra2_peon · https://cnc.fandom.com/wiki/Tanya_(Red_Alert_2) ·
https://cnc.fandom.com/wiki/Conscript_(Red_Alert_2) · https://forums.cncnet.org/topic/12109-in-game-audio-database-transcript ·
`rulesmd.ini` (IdleActionFrequency)

**Confidence** — high (categories), med (complete per-unit line coverage — offsite spreadsheet).

---

## I. Music

### RA2-UI-100 Track List and Dynamic Behaviour

**What** — Score by **Frank Klepacki**. The in-game playlist shuffles the available tracks continuously in all modes;
RA2 (unlike RA1) makes the **entire soundtrack available from the start** (no gradual Allied/Soviet unlock). The track
"Jank" is used as the **mission loading theme**. There is no adaptive combat-music layer documented for RA2 (music does
not switch on combat — a flat shuffled playlist).

**Data keys** — Track list in `ra2.csf` (theme labels); menu/loading themes; random shuffle with skip/next (in-game
track selection is not player-exposed in vanilla beyond the internal playlist).

**Numbers** — OST disc: **16 tracks**, length **1:02:55**. Three unlisted tracks + **10 YR tracks** (plus a trailer
remix). "Jank" = loading theme.

**Edge cases** — "Ready the Army", "Probing" and "C&C in the House" are on the disc but **not used in-game**.
"Jank" is used only for mission loading. A known bug drops the Counterstrike track "Arazoid" (RA1 context). RA2 extras
appear in the Remastered/community packs.

**Catalog** — see the music table below.

**Kind** — audio / music.

**Sources** — https://cnc.fandom.com/wiki/Command_%26_Conquer:_Red_Alert_2_soundtrack ·
https://www.frankklepacki.com/ost/vg/cnc-ra2 ·
https://steamcommunity.com/app/2229850/discussions/0/802341528343296802 ·
https://www.discogs.com/release/1194136-Frank-Klepacki-Command-Conquer-Red-Alert-2-The-Soundtrack

**Confidence** — high.

---

### RA2 / YR music tracks

| # | Track | Length | Used in-game? |
|---|-------|--------|---------------|
| 1 | Hell March 2 | 3:46 | yes |
| 2 | Industrofunk | 3:14 | yes |
| 3 | Ready the Army | 4:59 | no (disc only) |
| 4 | Grinder | 2:29 | yes |
| 5 | In Deep | 3:26 | yes |
| 6 | Motorized | 4:04 | yes |
| 7 | Power | 3:58 | yes |
| 8 | 200 Meters | 4:14 | yes |
| 9 | Destroy | 4:40 | yes |
| 10 | Burn | 4:39 | yes |
| 11 | Probing | 4:21 | no (disc only) |
| 12 | Blow It Up | 3:13 | yes |
| 13 | Eagle Hunter | 4:18 | yes |
| 14 | Fortification | 4:04 | yes |
| 15 | Jank | 3:48 | loading theme only |
| 16 | C&C in the House | 4:06 | no (disc only) |
| U1 | Tension | 4:05 | unlisted |
| U2 | Militant Force 2 | 1:09 | unlisted |
| U3 | Optical (Credits) | 2:53 | credits |
| Y1 | Drok | 2:36 | YR |
| Y2 | Bully Kit | 4:15 | YR |
| Y3 | Brain Freeze | 4:01 | YR |
| Y4 | Defend the Base | 4:26 | YR |
| Y5 | Phat Attack | 3:54 | YR |
| Y6 | Tactics | 4:59 | YR |
| Y7 | Trance L. Vania | 3:28 | YR |
| Y8 | Deceiver | 3:58 | YR |
| Y9 | Yuri's Revenge Credits | 1:50 | YR credits |
| Y10 | Yuri's Revenge Score | 1:50 | YR |

---

## J. Presentation

### RA2-UI-110 Voxel / SHP Pipeline

**What** — RA2 is a 2.5D engine. **Vehicles and building turrets** are rendered as **voxels** (`.VXL` + `.HVA`),
rotated and cached on demand; **infantry and buildings** are **SHP** sprites (isometric pre-rendered frames). Voxels
tilt on slopes; SHPs do not. Turrets of SHP buildings are usually voxels so they can rotate 360°.

**Data keys** — `Image=`, `Voxel=yes`, `TurretAnim`, `TurretAnimIsVoxel`, `VoxelBarrelFile`, `TurretAnimX/Y/ZAdjust`,
`TurretAnimDamaged`, `.VXL`/`.HVA` files.

**Numbers** — A voxel model has **32 facings per axis = 32 768 possible facings**, rendered only on demand and cached.
Voxel→pixel ratio is **1:1** when parallel to view. RA2 cell ≈ **42.4264 voxels** (TS = 33.94112). **1 voxel ≈ 6.03397
leptons**. Voxels cannot exceed **255×255×255** (artifacting beyond). SHP turrets use **32 frames**, may animate
shadows; `LoopStart=0/LoopEnd=32/LoopCount=-1/Rate=0`. `gclock2.shp` 55 frames.

**Edge cases** — Voxel models must have an HVA or the game crashes ("internal error"). Drawing order for multi-section
voxels is by canvas proximity to camera; turret is always above body, barrel above turret when facing camera. A
building with no real turret but a valid `TurretAnim` + charged weapon uses the turret art as a **charge animation**
(Obelisk in TS).

**Kind** — rendering / art pipeline.

**Sources** — https://modenc2.markjfox.net/index.php?title=Voxel&action=raw ·
https://modenc2.markjfox.net/index.php?title=TurretAnim&action=raw · https://tcrf.net/Command_%26_Conquer:_Red_Alert_2_(Windows)/Unused_Graphics

**Confidence** — high.

---

### RA2-UI-111 Building Build-Up ("MK") Animations

**What** — When a structure is placed, a **build-up animation** plays that grows/assembles the building out of the
ground. `BuildupTime=.06` controls average duration. Buildings also have **active/idle animations** (flags, doors,
spinners, lights) that may require power (`ActiveAnimPowered`), and **damaged variants** (`ActiveAnimDamaged`) shown in
yellow/red health. YR adds **power-up animations** (`PowerUp1/2/3Anim`) for upgraded structures.

**Data keys** — `BuildupTime`, `MakeAnim`/build-up SHP (art.ini `Buildup`), `ActiveAnim`, `ActiveAnimPowered`,
`ActiveAnimDamaged`, `ActiveAnimTwo/Three`, `PowerUp1Anim…PowerUp3Anim` with Loc/YSort offsets.

**Numbers** — `BuildupTime=.06` minutes average; power-up offsets include Z-adjust and Y-sort (e.g. `PowerUp1LocZZ=-30`,
`PowerUp2YSort=50`).

**Edge cases** — Build-up plays for structures captured from enemies too. Placing a building too close/blocked retries
after `PlacementDelay=.05` min. Damaged frames can be tied to power state (`ActiveAnim…PoweredLight`).

**Kind** — animation / presentation.

**Sources** — `rulesmd.ini` General; `art(md).ini` comments (PowerUp/ActiveAnim)
(https://modenc2.markjfox.net/, https://modenc.renegadeprojects.com/)

**Confidence** — high.

---

### RA2-UI-112 Death, Explosion and Debris

**What** — Destroyed objects play explosion animations per cell, spawn debris and smoke, and leave rubble/smudges.
Buildings explode across each occupied cell; vehicles can explode (often leaving scrap/tires); bridges explode in
sections. Warhead `Explosion=` selects an explosion animation set (bullet/fire/AP/HE/nuclear).

**Data keys** — `Explosion=` (warhead, 0–6), `Explosion=` on TechnoTypes (list of death anims), `MetallicDebris`
list, `ExplosiveVoxelDebris=GASTANK,PIECE`, `TireVoxelDebris=TIRE`, `ScrapVoxelDebris=PIECE`,
`DebrisSmokeSystem`, `BuildingDieSound=BuildingGenericDie`, `BridgeExplosions`, `BridgeVoxelMax=3`,
`CrewEscape=50%`.

**Numbers** — Warhead `Explosion`: 0 none, 1 single bullet, 2 multiple bullet, 3 fire/napalm, 4 armour-piercing,
5 high-explosive, 6 nuclear. `BridgeVoxelMax=3` debris per bridge section. `CrewEscape=50%` chance a crewman bails
out. `AtomDamage=1000`.

**Edge cases** — Explosion anims for buildings are placed on each footprint cell. Vehicles with `Explodes` (or elite
ability) and ammo always use the **last** listed explosion anim. A War Factory infiltration "upgrades" naval cameos
(bug). Buildings leave smudges/rubble that can block rebuild placement (community complaint).

**Kind** — VFX / combat feedback.

**Sources** — https://modenc2.markjfox.net/index.php?title=Explosion&action=raw · `rulesmd.ini` General/AudioVisual ·
https://modenc2.markjfox.net/index.php?title=VoxelAnims&action=raw

**Confidence** — high.

---

### RA2-UI-113 Craters / Scorch Marks / Smudges

**What** — Explosions and fire weapons leave **smudge** overlays on the ground: **craters** (`Craters=CR1…CR6`,
`Crater=yes` smudges) and **scorch marks** (`Scorches=BURN01…BURN16`, in 4 size tiers). Smudge size scales with weapon
damage. Terrain types Water/Beach/Ice/Rock reject smudges.

**Data keys** — `Craters`, `Scorches/Scorches1…Scorches4`, `Burn=yes`, `Crater=yes`, `SmudgeTypes` section,
`CraterLevel=1` (meteor craters 0–4), `[SmudgeTypes]` `Width/Height`.

**Numbers** — 6 crater smudges; 16 scorch smudges in 4 tiers; `CraterLevel=1` default (0–4).

**Edge cases** — **Conflicts:** the RA2 `Scorch=yes` *animation flag* is explicitly obsolete/non-functional in RA2/YR,
**but** scorch smudges are still produced via the `[CombatDamage] Scorches` lists and `Burn=yes` smudges — so scorch
marks *do* appear in RA2, just not through that flag. Smudges only render if `H(FireFLH) ≤ 29`.

**Kind** — decals / persistence.

**Sources** — https://modenc2.markjfox.net/index.php?title=Scorch&action=raw ·
https://modenc2.markjfox.net/index.php?title=Crater&action=raw · `rulesmd.ini` CombatDamage

**Confidence** — high (with conflict noted).

---

### RA2-UI-114 Particle Systems / Damage Effects

**What** — Damage particles are managed by `ParticleSystems` and attached via `DamageParticleSystems`: **smoke** appears
when an object enters yellow/red health (removed when repaired to green), **sparks** fire probabilistically in yellow/
red health. Buildings use `OKBuildingSmokeSystem`, `DamagedBuildingSmokeSystem`, `DamagedUnitSmokeSystem`,
`DebrisSmokeSystem`. Weather/superweapon effects use dedicated cloud/bolt particle systems.

**Data keys** — `DamageParticleSystems`, `DamageSmokeOffset`, `ConditionYellowSparkingProbability`,
`ConditionRedSparkingProbability`, `DefaultSparkSystem`, `OnFire`/`SmallFire`, `WeatherConClouds`,
`WeatherConBolts`, `DominatorFirstAnim/SecondAnim`.

**Numbers** — Smoke/spark trigger thresholds = yellow (50 %) / red (25 %). `ConditionRed=25%`, `ConditionYellow=50%`.

**Edge cases** — Infantry can only use spark particles if `Cyborg=yes` and the section is present in the map file.
Robot Tanks constantly spawn spark systems when deactivated (hardcoded). Smoke is not removed by every repair path
(e.g. some self-heals leave it until it expires).

**Kind** — VFX.

**Sources** — https://modenc2.markjfox.net/index.php?title=DamageParticleSystems&action=raw · `rulesmd.ini` AudioVisual

**Confidence** — high.

---

### RA2-UI-115 Lighting and Spotlights

**What** — Ambient lighting is recomputed over time (`AmbientChangeRate=.2`, `AmbientChangeStep=.2`), and units receive
extra light for readability (`ExtraUnitLight=.2`, `ExtraInfantryLight=.2`, `ExtraAircraftLight=.2`). A **spotlight**
system can sweep searchlights (`SpotlightSpeed`, `SpotlightMovementRadius`, `SpotlightLocationRadius`,
`SpotlightAcceleration`, `SpotlightAngle`). Nuke/weather events darken or flash ambient lighting gradually.

**Data keys** — ambient change keys, spotlight keys, `ExtraUnitLight`, `ExtraInfantryLight`, `ExtraAircraftLight`,
`LaserTargetColor`, `BombTickingSound`, tint colours in `[ColorAdd]`.

**Numbers** — `AmbientChangeRate=.2` min, `AmbientChangeStep=.2`; extra light **.2** per unit class; spotlight speed
`.015` rad, movement radius `2000`, location radius `1000`, acceleration `.0025`, angle `.5` rad.

**Edge cases** — `AmbientChangeStep` was historically `.1`; YR comments note a faster nuke flash. Spotlight sweeps are
mostly cinematic/ambient and tied to specific maps/buildings.

**Kind** — lighting / atmosphere.

**Sources** — `rulesmd.ini` AudioVisual / General

**Confidence** — high.

---

### RA2-UI-116 Weather and Environmental Effects

**What** — RA2 has **no dynamic weather system** for rain/fog by default; the main weather event is the Allied
**Weather Control Device** superweapon (Lightning Storm), which spawns cloud and bolt particle systems, damages
structures/units, and **disables all radar** during the storm. RA2 also has a **snow theater** (snow tileset) and the
`ShroudGrow`/`FogRate` shroud systems. Ion storms, meteorites and visceroids can be toggled in rules but are **off**
(`IonStorms=no`, `Meteorites=no`, `Visceroids=no`).

**Data keys** — `WeatherConClouds`, `WeatherConBolts`, `WeatherConBoltExplosion`, `LightningStormDuration`,
`LightningDeferment`, `LightningDamage`, `LightningWarhead`, `LightningHitDelay`, `LightningScatterDelay`,
`LightningCellSpread`, `LightningSeparation`, `IonStorms`, `Meteorites`, `Visceroids`, `FogOfWar=no` (RA2 skirmish),
`ShroudGrow=no`, `ShroudRate`, `FogRate`, `IceGrowthRate`, `IceSolidifyFrameTime`.

**Numbers** — Lightning Storm default duration **180 frames**, deferment **250**, damage **250**, hit delay 10,
scatter delay 5, cell spread **10**, separation 3. `FogOfWar=no` in YR skirmish rules. `FogRate=.01`, `ShroudRate=4`.

**Edge cases** — Lightning Storm cannot be started while another is active. Its structure can't be one-shot by the
other superweapons. Nuke warhead uses `NukeWarhead=Nuke`, `NukeDown=NukeDown`, `NukeTakeOff=NUKETO`. Weather Control
Device disables both allied and enemy radar during the storm.

**Kind** — superweapon / atmosphere / shroud.

**Sources** — https://cnc.fandom.com/wiki/Weather_control_device_(Red_Alert_2) · `rulesmd.ini` General/AudioVisual

**Confidence** — high.

---

### RA2-UI-117 Screen Shake and Camera Feedback

**What** — RA2's `[AudioVisual] ShakeScreen=400` (divide object strength by this to decide whether the screen shakes
when destroyed) exists in the INI, but **ModEnc states the shake routine no longer has any effect in TS/RA2** — screen
shake is effectively a *disabled/vestigial* feature. Camera feedback otherwise consists of view-pan to alerts, the
"move destination" ring (`MoveFlash=RING`), and the target-line overlay.

**Data keys** — `ShakeScreen=400`, `MoveFlash=RING`, `TargetSpecialThreat`, direct-rocking keys (`DirectRockingCoefficient`,
`FallBackCoefficient`) which rock a vehicle's sprite on heavy hits.

**Numbers** — `ShakeScreen=400`; `DirectRockingCoefficient=1.5`, `FallBackCoefficient=0.1`.

**Edge cases** — **Conflicts:** the rules comment describes screen shake as functional, but the engine flag is parsed
and ignored (ModEnc). Community "add screen shake" threads exist precisely because vanilla has none. Treat screen shake
as **not present** in retail RA2.

**Kind** — camera feedback / legacy flag.

**Sources** — https://modenc.renegadeprojects.com/ShakeScreen · https://ppmforums.com/topic-18687/screen-shake ·
`rulesmd.ini` AudioVisual

**Confidence** — high (flag exists), high (no effect).

---

### RA2-UI-118 Gore, Bodies and Death Animations

**What** — Infantry death plays a per-warhead animation selected by `InfDeath` (0–10), after which a persistent
**dead body** animation is chosen at random from `DeadBodies=DEATH_A…DEATH_F`. Bodies linger then vanish. YR adds
special deaths: head-pop, nuked, virus (spawns a particle / can turn to a unit), mutate (Genetic Mutator), and brute.

**Data keys** — `InfDeath` (0–10), `Die1`/`Die2` sub-sequences, `NotHuman`, `DeathAnims`, `DeadBodies`,
`InfantryExplode`, `FlamingInfantry`, `InfantryHeadPop`, `InfantryNuked`, `InfantryVirus`, `InfantryMutate`,
`InfantryBrute`, `MakeInfantry=BRUTE`, `AnimToInfantry=BRUTE`.

**Numbers** — InfDeath: 0 none; 1 small-arms (Die1); 2 high-explosive (Die2); 3 flying (InfantryExplode, spawns);
4 burn (FlamingInfantry, spawns); 5 electro (2nd `[Animations]` entry, spawns); 6 head-pop (RA2+); 7 nuked (RA2+);
8 virus (YR, player-owned spawn); 9 mutate (YR, hardcoded no-damage to airborne); 10 brute (YR); 11+ requires
`DeathAnims`. `DeadBodies` has **6** variants. `MakeInfantry` index 0 = `BRUTE`.

**Edge cases** — `NotHuman=yes` forces Die1 (unless Phobos/`NotHuman.DeathSequence`). Infantry killed while
paradropping force `InfDeath=3`; LaserFence force `InfDeath=5`. InfDeath 8 assumes `SpawnsParticle` is set (else
crash). InfDeath 9 does nothing to airborne infantry. Bodies disappearing is a known community complaint; corpses are
short-lived by design.

**Kind** — gore / death VFX.

**Sources** — https://modenc2.markjfox.net/index.php?title=InfDeath&action=raw ·
https://modenc2.markjfox.net/index.php?title=DeadBodies&action=raw (DeadBodies list from rules.ini) ·
`rulesmd.ini` General (`DeadBodies`)

**Confidence** — high.

---

## K. Campaign

### RA2-UI-130 Allied Campaign — Full Mission List

**What** — 12 missions. Story: rescue Einstein, repel the invasion, the Psychic Beacon/Amplifier arc, the nuclear
silo raid, the Chinook/Florida Keys Chronosphere, and the final Moscow assault. Objectives and briefings below are
from the Red Alert Archive walkthrough (mission briefings reproduced nearly verbatim).

**Data keys** — Mission id/name, objectives, triggers, reinforcements, timers, cinematic cameras, win/lose.

**Numbers** — 12 missions. Some timers: M2 convoy (25 min).

**Catalog** —

| # | Mission | Briefing / key objectives | Notable scripted events |
|---|---------|---------------------------|--------------------------|
| 1 | **Lone Guardian** | Rescue Einstein from a Soviet complex; evacuate via helicopter at the signal flare; keep Einstein and Tanya alive; destroy the westmost power plants to disarm Tesla Coils | Enemy infantry attack; Tanya arrives by aircraft; cruiser missiles bombard the base once Einstein is rescued |
| 2 | **Eagle Dawn** | A supply convoy is due in 25 minutes; Soviet roadblocks must be cleared; the convoy comes from the NW | Timed convoy spawn; base persists into M4 |
| 3 | **Hail to the Chief** | Destroy all nearby bridges before the Soviets can advance; Tanya must survive | Medic under fire intro; artillery + Tanya micro; enemy infantry hide behind trees |
| 4 | **Last Chance** | Hold the pass and destroy all Soviet units/buildings in the region (reuses the M2 base) | Persistent base from M2; ore-truck raid option |
| 5 | **Dark Night** | Spy infiltrates a weapons factory to free Tanya; destroy SAM sites on the island; then destroy remaining Soviet forces | Three map variants (European map choice); spy vs dogs; reinforcements incl. engineers; capture a Soviet base |
| 6 | **Liberty** | Establish a base, spy into a Soviet tech centre to steal Iron Curtain data; then wipe out everything | MCV deploy; south attack; capture barracks; naval yard |
| 7 | **Deep Sea** | Investigate the secret Bornholm base; capture the radar centre and destroy sub production | Minelayer anti-ore-truck tactic; capture & sell radar |
| 8 | **Free Gateway** | Protect the Chronosphere and advanced-tech centre; keep the base fully powered at the appointed time | Timed experiment; minefields; destroyers |
| 9 | **Sun Temple** | Spy infiltrates the Soviet command centre to contact defector Kosygin; escort him home | Attack dogs; APC/transport insertion; defector escort |
| 10 | **Mirage** (a/b) | Take Stalin's main atomic weapons plant offline; then deactivate launch control centres before the missiles launch | Mission 10b: indoor infantry/Tanya segment; timed missile launch; engineers disable control centres |
| 11 | **Fallout** | Clear the Volga river bottleneck near Volograd so warships can move | Two MCVs; sonar pulse; submarine wolfpack; naval assault |
| 12 | **Chrono Storm** | Capture all technology centres; destroy the Iron Curtain prototype(s); Longbow helicopter support | Final mission; superweapon-heavy; cut-scene Chrono Storm |

**Kind** — campaign missions.

**Sources** — http://ra.afraid.org/html/ra/a_wt.html · `Template:Red Alert 2 Missions` (cnc.fandom raw) ·
https://cnc.fandom.com/wiki/Command_%26_Conquer:_Red_Alert_2

**Confidence** — high (mission order/objectives), med (verbatim briefing text is from a fan walkthrough mirroring the
in-game text).

---

### RA2-UI-131 Soviet Campaign — Full Mission List

**What** — 12 missions (non-canon). Story: invade Washington, take New York with a Psychic Beacon, defend the
motherland, energise the Eiffel Tower, Hawaii, Urals Chronosphere defence, Yuri's coup, and the final invasion of
England.

**Data keys** — as Allied.

**Numbers** — 12 missions. Some timers: M7 nuclear meltdown (30 min).

**Catalog** —

| # | Mission | Briefing / key objectives | Notable scripted events |
|---|---------|---------------------------|--------------------------|
| 1 | **Red Dawn** | A resistance blockades a village; kill them all and destroy their homes; Yaks available | Barrel chains; heal crate under the church; "New Objective"; civilians must die |
| 2 | **Hostile Shore** | Protect the facility from Allied attacks; keep the Command Center intact; destroy Allied fortifications | Convoys; ore truck; Yaks |
| 3 | **Big Apple** | An Allied spy has damaged the base and is escaping; hunt him with attack dogs | Civilian traps; no radar (per "No Radar" missions); Zofia intro; psychic beacon arc begins |
| 4 | **Home Front** | Destroy the problematic Allied base; crush their communications | MCV deploy; spy plane; paratroopers; gap generator |
| 5 | **City of Lights** | Capture the Allied radar centre on Khalkis island; deny the Allies their ore base | Island assault; capture Con Yard; Yaks/naval |
| 6 | **Sub-Divide** | Escort special cargo trucks to a base in the NE; repair the bridge or use naval assets | Convoy escort; attack subs; cruisers |
| 7 | **Chrono Defense** | Allied saboteurs are causing a nuclear meltdown; guide technicians to 4 coolant stations then the main computer within 30 minutes | Timed; dogs; flame turrets; indoor segment |
| 8 | **Desecration** | Destroy all Allied units on/around Elba island; punish the collaborating civilians | Civilian flares; minelayers; ore-truck starvation |
| 9 | **The Fox and the Hound** | Destroy the captured truck carrying secret weapon parts before the Allies escape with it | Capture enemy base; bridge ambush; paratroopers; convoy chase |
| 10 | **Weathered Alliance** | Defend a convoy moving through Allied territory with MiGs and Yaks; at least one truck must reach the far side | Convoy shepherd mechanic; AA-gun removal; capture repair bay |
| 11 | **Red Revolution** | Destroy the Allied naval fleet refuelling at the base along with the base itself | Sub wolfpack; bridges; Hind/MiG air support |
| 12 | **Polar Storm** | Capture the Chronosphere (capture tech centres first to defuse booby traps); destroy all Allied forces | Final mission; Iron Curtain; mammoth tanks; naval landing |

**Kind** — campaign missions.

**Sources** — http://ra.afraid.org/html/ra/s_wt.html · `Template:Red Alert 2 Missions` (cnc.fandom raw) ·
https://cnc.fandom.com/wiki/Command_%26_Conquer:_Red_Alert_2

**Confidence** — high (order/objectives), med (verbatim text).

---

### RA2-UI-132 Boot Camp and Cooperative Campaigns

**What** — Two tutorial missions (**Boot Camp - Day 1/2**) teach movement, building, and combat. Online **Co-operative**
play offers five short campaigns vs preset AI ("some harder than others"): allied ones **Texas DMZ**, **European
Theater**, **Guardians of the East**, **Red Storm**; Soviet **African Warlords**. YR adds Allied/Soviet/Yuri co-op
missions.

**Data keys** — Tutorial map ids; co-op campaign maps with pinned sides/countries/teams; "France locked on mission 1"
in one co-op (CnCNet report).

**Numbers** — 2 tutorial maps; 5 RA2 co-op campaigns; YR co-op mission sets.

**Edge cases** — Co-op missions restrict selectable countries and use preset conditions (Start Units, Crates,
Superweapons, Short Game, MCV Repacks, Build off Ally Conyards).

**Kind** — campaign / co-op meta.

**Sources** — `Template:Red Alert 2 Missions` · https://www.manualshelf.com/manual/games-pc/command-conquer-red-alert-2/user-guide-english.html ·
https://forums.cncnet.org/topic/9080-adding-settings-to-the-cooperative-gamemode

**Confidence** — high (existence/names), med (details).

---

### RA2-UI-133 Trigger / Event / Action Structure

**What** — Campaign logic is data-driven via map triggers: **events** (time elapsed, object destroyed, enter/exit
region, health below, etc.), optional **conditions**, and **actions** (reinforce, spawn, reveal, play movie/sound,
set objective, win/lose, change house, text trigger). Mission scripts reference TeamTypes, AITriggers, and cell tags.
The in-game **Objective** display is driven by these triggers ("New Objective Received").

**Data keys** — Triggers (event/condition/action), TeamTypes, TaskForces, ScriptTypes, AITriggers, cell tags,
`[Basic]`/`[Map]` settings, `RevealTriggerRadius=9`, `DropZoneRadius=4`.

**Numbers** — `RevealTriggerRadius=9` (max 10); `DropZoneRadius=4` cells around a drop-zone flare.

**Edge cases** — A `Reveal around waypoint` trigger is the standard "ping the map" device. Triggers can add objectives,
move camera, and gate win/lose independently of the "destroy all" default. Broken triggers historically made some
fan missions unwinnable.

**Kind** — mission scripting.

**Sources** — https://modenc.renegadeprojects.com/DeeZire%27s_Red_Alert_2_and_Yuris_Revenge_INI_Editing_Guide ·
`rulesmd.ini` General · https://cnc.fandom.com/wiki/Command_%26_Conquer:_Red_Alert_2_manual

**Confidence** — med (structure known, exact schema not enumerated in a single web source).

---

### RA2-UI-134 Reinforcements

**What** — Missions deliver reinforcements via triggers: paradrops, chrono/chrono-legionnaire arrivals, transport
landings, airdrops, and scripted "reinforcements have arrived" moments. Certain units are campaign-only (Navy SEAL,
Psi Commando, Chrono Commando/Chrono Ivan, Yuri Prime). The EVA line "Reinforcements Have Arrived" fires on trigger.

**Data keys** — Reinforce TeamType action, `ChronoReinfDelay=180`, `ChronoDelay=60`, `ChronoDistanceFactor=48`,
`ChronoMinimumDelay=16`, `ChronoTrigger=yes`; paradrop keys (`AmerParaDropInf`, `AllyParaDropInf`, `SovParaDropInf`,
`YuriParaDropInf` with counts 8/6/9/6).

**Numbers** — Chrono reinforcement delay **180 frames**, unit chrono delay **60**, minimum 16, distance divisor 48
(256/48 ≈ 5.33 frames/cell). Paradrops: America **8** GIs, other Allies **6**, Soviets **9** conscripts, Yuri **6**
initiates.

**Edge cases** — Reinforcements can be pre-placed on transports; capturing a Tech Airport enables periodic paradrops.
Chrono arrivals can be delayed/scattered. Some missions hand the player a pre-built base (M4 reuses M2).

**Kind** — mission scripting / pacing.

**Sources** — `rulesmd.ini` General (Reinforcement/Chrono + ParaDrop blocks) · http://ra.afraid.org/html/ra/a_wt.html

**Confidence** — high (engine values), med (per-mission script specifics).

---

### RA2-UI-135 Cinematic Camera

**What** — Campaign missions use scripted camera moves ("camera targets") during briefings, FMV interstitials and
scripted events; the radar/minimap surface can show video during campaign. The **Reveal around waypoint** trigger and
camera actions focus the player's view. MP/co-op replaces briefing with diplomacy.

**Data keys** — Camera trigger actions, waypoint ids, `RevealTriggerRadius=9`, radar-as-video in campaign.

**Numbers** — `RevealTriggerRadius=9` (max 10).

**Edge cases** — Cinematic camera is disabled in multiplayer. Some missions temporarily take control away via camera
pans during dialogue.

**Kind** — presentation / scripting.

**Sources** — `rulesmd.ini` General · https://cnc.fandom.com/wiki/Sidebar ·
https://www.manualshelf.com/manual/games-pc/command-conquer-red-alert-2/user-guide-english.html

**Confidence** — med.

---

### RA2-UI-136 Win / Lose Conditions

**What** — Default win = destroy all enemy units and structures (and sometimes specific objectives, e.g. destroy the
Iron Curtain, capture the Chronosphere, escort the convoy). Loss = all your forces/base destroyed, a timer expires
(nuclear meltdown, missile launch), or a protect-target dies (Einstein, Tanya, the Chronosphere). Some missions have
"critical unit/structure lost" fail states (EVA "Critical Unit Lost").

**Data keys** — Win/lose trigger actions, mission timer, critical-object flags, `SavourDelay=.1` (delay between
scenario end and ending movie), `You Are Victorious`/`You Have Lost`/`Mission Failed` lines.

**Numbers** — `TimerWarning=2` minutes (timer turns red); `SavourDelay=.1` min.

**Edge cases** — Some missions end when the last enemy unit dies even if that wasn't the stated objective (Soviet M13
walkthrough notes this). Selling all buildings at the end is a common AI behaviour. "Objective reached" can precede a
spurious fail (reported bug in Soviet M13).

**Kind** — mission rules.

**Sources** — http://ra.afraid.org/html/ra/a_wt.html · http://ra.afraid.org/html/ra/s_wt.html ·
`rulesmd.ini` AudioVisual

**Confidence** — med/high.

---

### RA2-UI-137 Difficulty

**What** — Three levels: **Easy / Medium / Hard** (`FineDiffControl=no` disables a 5-level option). Difficulty tunes AI
aggression and economy, not unit stats. Campaign missions also contain *specific difficulty-gated triggers*. Skirmish
AI difficulty adds starting-unit/credit and attack-timing differences.

**Data keys** — `TeamDelays=2000,2500,3500` (E/N/H frames between team checks), `AIHateDelays=30,50,70`,
`MultiplayerAICM=400,0,0`, `AIVirtualPurifiers=4,2,0`, `AISlaveMinerNumber=4,3,2`, `HarvestersPerRefinery=2,2,1`,
`AIExtraRefineries=2,1,0`, `MinimumAIDefensiveTeams`/`MaximumAIDefensiveTeams=2,2,2`, `TotalAITeamCap=30,30,30`,
`AlliedBaseDefenseCounts=25,20,6`, `SovietBaseDefenseCounts=25,22,6`, `AIPickWallDefensePercent=50,25,10`,
`DisabledDisguiseDetectionPercent=15,5,2`.

**Numbers** — Team delay E/N/H = **2000/2500/3500** frames (hard checks more often → faster response). AI hate delay
**30/50/70** frames. Base-defense counts hard **25**, etc. Campaign money delta E/H = **0/0** in shipped YR.

**Edge cases** — **Conflicts:** players report Hard campaign is much harder, but the shipped `CampaignMoneyDeltaEasy=0`
and `CampaignMoneyDeltaHard=0` imply the *default* money handicap is zero for both — difficulty acts through
triggers/AI-team timing, not a raw credit bonus. Hard grants AI *fewer* virtual purifiers (4/2/0) yet more defense
buildings; interpret totals carefully. Mod authors tune these values.

**Kind** — difficulty tuning.

**Sources** — `rulesmd.ini` General · https://www.reddit.com/r/redalert2/comments/ynh4yt/whats_the_diference_between_easymediumhard_in_the ·
https://www.reddit.com/r/redalert2/comments/ldddz3/if_i_started_the_campaign_on_easy_can_i_change

**Confidence** — high (values), med (player-facing effect).

---

### RA2-UI-138 Campaign Money Deltas

**What** — The editor places a base credit amount per mission ("the amount given in the editor will be for Normal").
`CampaignMoneyDeltaEasy` and `CampaignMoneyDeltaHard` are added for all `PlayerControl` houses. In the shipped YR
rules both are **0**.

**Data keys** — `CampaignMoneyDeltaEasy=0`, `CampaignMoneyDeltaHard=0`, per-mission editor credits.

**Numbers** — Default deltas **0 / 0**.

**Edge cases** — Because the values are read before the player house is known, deltas apply to all player-controlled
houses. Mods use these to create true difficulty-based income (community mods exist for exactly this). RA2
(non-YR) `rules.ini` values were not verified and may differ.

**Kind** — campaign economy.

**Sources** — `rulesmd.ini` General (`CampaignMoneyDelta*`) ·
https://gist.github.com/bashkirtsevich/b2a5b2f32b39f8abb2f0f37c40f1294c

**Confidence** — med (YR verified; RA2 unverified).

---

## L. Skirmish / Multiplayer UI Flows and Options

### RA2-UI-150 Skirmish and Multiplayer Flows

**What** — Flow: Main Menu → Single Player → Skirmish **or** Main Menu → Internet/Network → lobby. Setup screen fields:
name, side/country, colour, team, map (+ random map), AI count, AI difficulty, starting credits, and scenario
conditions. Host launches; loading screen plays "Jank"; end screen shows stats. Diplomacy (Tab) allows ally/declare
war in-game; beacons and chat support coordination.

**Data keys** — Scenario toggles: **Short Game**, **Superweapons**, **Crates**, **MCV Repacks**, **Starting Units**
(YR), **Build off Ally Conyards** (YR). Player colour list; team list; ladder flags; map list.

**Numbers** — Up to **8** players; 7 AI opponents. Starting credits default commonly **10 000** (slider up to
20 000 vanilla / CnCNet higher). Colours drawn from the standard C&C palette (multiple shades of Yellow/Red/White/
Orange plus exotics in TS; RA2 uses fixed house colours, no remap for civilians).

**Edge cases** — Random crates can spawn on water (Yuri/YR). FFA vs teams; allied shared vision
(`AllyReveal=yes`). Ladder ranking, private/public games and tournaments existed on Westwood Online. Co-op lobby
restricts countries. In-game build restrictions: no saving in MP.

**Kind** — setup / networked flow.

**Sources** — https://www.manualshelf.com/manual/games-pc/command-conquer-red-alert-2/user-guide-english.html ·
https://cnc.fandom.com/wiki/Skirmish · https://cnc.fandom.com/wiki/Command_%26_Conquer:_Red_Alert_2 ·
`rulesmd.ini` (AllyReveal, CrateRules)

**Confidence** — high (flows), med (exact default credit value & per-game toggles).

---

## M. Accessibility and Localization

### RA2-UI-160 CSF String Tables, UIName and Localization

**What** — All in-game text lives in **CSF** string tables: `ra2.csf` (RA2) and `ra2md.csf` (YR), stored in
`language.mix`/`langmd.mix`. Object display names are resolved via `UIName=Name:<id>` (rules.ini) → `Name:<id>` entry
in the CSF. Campaign dialogue subtitles exist for the Traditional Chinese localization (the only official localization
without dubbed cutscenes). Official localizations: English, French, German, Korean, Chinese (Simplified/Traditional),
with full voice casts per language.

**Data keys** — `UIName=Name:<id>` on Infantry/Vehicle/Aircraft/Building/Country/SuperWeapon types; CSF labels
(`Name:`, `GUI:`, `TXT_`, `THEME:`, etc.); `stringtableXX.csf` (xx 01–99) may override a MIXed CSF. Tooling: XCC String
Table Editor, RA2StrEdit, Ra2CsfToolsGUI, CSF-Studio (open source). Format encoded as: label, value, extra value
(when a string contains formatting), all text UTF-16.

**Numbers** — `ra2.csf` (RA2), `ra2md.csf` (YR); external override filenames `stringtable01.csf`–`stringtable99.csf`.
CSF IDs are case-insensitive; string *content* is case-sensitive.

**Edge cases** — Editing the CSF changes the hover name but **not the cameo art**. Missing `UIName`/`Name:` falls back
to the internal ID. The `[General] UIName` has no effect. Third-party open-source libraries exist to read/write CSF
(`ra2csf`, `Ra2CsfFile`). Accessibility features (colourblind modes, subtitles on/off, remappable UI scaling) are not
documented for retail RA2 — the UI is fixed-scale and colour-coded by house.

**Kind** — localization / string system.

**Sources** — https://modenc2.markjfox.net/index.php?title=CSF&action=raw ·
https://modenc2.markjfox.net/index.php?title=UIName&action=raw ·
https://modenc.renegadeprojects.com/CSF_File_Format · https://github.com/FS-21/CSF-Studio ·
https://pypi.org/project/ra2csf · https://cnc.fandom.com/wiki/Command_%26_Conquer:_Red_Alert_2

**Confidence** — high.

---

## Coverage Checklist

| # | Requested area | Covered by | Status |
|---|----------------|-----------|--------|
| 1 | Every screen/dialog (main menu, campaign select, country, skirmish, options, load/save, pause, briefing, score, quit, MP lobby) | RA2-UI-001…011 | covered |
| 2 | In-game HUD: sidebar tabs, cameo grid, per-cameo states, queue strip, credits/power, repair/sell, info panel | RA2-UI-020…028 | covered |
| 3 | Radar/minimap: events, flash, destructibility, click-to-move, blackout (gap/spy) | RA2-UI-040…042 | covered |
| 4 | Selection & info: box select, brackets, health thresholds, veteran chevrons, pips, enemy health | RA2-UI-050…056 | covered |
| 5 | Full control scheme: hotkeys, 10 control groups, camera, L/R click, rally, guard/formation, waypoints, stances | RA2-UI-060…066 + table | covered (9 groups — see note) |
| 6 | Every cursor state and targeting rules (mind-control / attack-on-disguise) | RA2-UI-070 | covered (community frame map) |
| 7 | EVA per faction; message ticker | RA2-UI-080 + EVA table + RA2-UI-028 | covered |
| 8 | Unit voices; GUI sound set | RA2-UI-090 + RA2-UI-110…117 audio hooks | covered |
| 9 | Music track list + dynamic behaviour | RA2-UI-100 + music table | covered |
| 10 | Presentation: voxel/SHP, build-up, fire/smoke, death/explosion/debris, craters/scorch, particles/weather, lighting, screen shake, bodies/gore | RA2-UI-110…118 | covered |
| 11 | Campaign: full Allied & Soviet mission lists, objectives, briefings, scripted events, reinforcements, cinematic camera, win/lose, difficulty, money deltas | RA2-UI-130…138 | covered |
| 12 | Skirmish/MP UI flows and options (all defaults) | RA2-UI-150 | covered (some defaults med) |
| 13 | Accessibility/localization (CSF, UIName) | RA2-UI-160 | covered |

---

## Open Questions / Top Uncertainties

1. **Sidebar tab count.** The task brief says "6-tab sidebar"; all engine/wiki sources say RA2/YR is **4 tabs**
   (Structures, Defenses/Armory, Infantry, Vehicles). The 6–7 tab layout is Tiberium Wars / Red Alert 3. Confirm
   whether the intended target is RA2 (4) or a later engine convention.
2. **Control-group count.** Sources show **9** groups (Ctrl+1–9); whether group `0` exists in retail RA2 is
   unconfirmed. "10 control groups" in the brief may count the Advanced Bar's 10 team buttons (including 0).
3. **Per-cameo queue-strip visuals.** The exact glyph for "×N queued" (count badge vs stacked mini-cameos) is not
   documented; RA2's queue was raised to 30 but the strip rendering is only described qualitatively.
4. **Campaign starting credits per mission.** Only the *delta* keys (`CampaignMoneyDeltaEasy/Hard`) are documented;
   the base per-mission amounts are set in the map editor and are not published in a single web source.
5. **Full per-unit voice line catalog.** OpenPeon categories are solid; the exhaustive per-unit transcript lives in an
   offsite CnCNet Google Drive spreadsheet that could not be read directly.
6. **Cursor frame→action mapping.** Reconstructed from a 2013 PPM thread (DeeZire/CCHyper); some ranges are explicitly
   "unknown". A definitive modern `mouse.shp` index list would sharpen §F.
7. **Score screen fields.** No authoritative enumeration of RA2's end-of-mission score components was found.
8. **Music dynamic behaviour.** Confirmed: RA2 shuffles the full soundtrack from the start (no gradual faction
   unlock), "Jank" is the loading theme, no adaptive combat layer. Whether the *campaign* and *skirmish* draw from
   different playlists is a user claim with no definitive answer found.
9. **Screen shake.** `ShakeScreen=400` exists but ModEnc says it no longer functions in TS/RA2; verify on a retail
   build before relying on it.
10. **RA2 (non-YR) rules values.** Several numbers (deltas, spy steal %, queue cap) were read from shipped *YR*
    `rulesmd.ini`; the base RA2 `rules.ini` may differ.
11. **Trigger/event/action schema.** Known conceptually but not enumerated from an authoritative RA2 source; the
    FinalAlert 2 trigger list would be the primary reference.
12. **Accessibility.** No colourblind modes, subtitle toggles, or UI-scaling options are documented for retail RA2
    beyond the Chinese subtitle system.

---

## Source Index

- Manual (text mirror): https://www.manualshelf.com/manual/games-pc/command-conquer-red-alert-2/user-guide-english.html
- Manual (alternate): https://manualmachine.com/gamespc/commandconquerredalert2/1117998-user-manual
- ModEnc / ModEnc²: https://modenc.renegadeprojects.com/ · https://modenc2.markjfox.net/
  (Cameo, AltCameo, Cameo Charging Indicator, BuildCat, Voxel, TurretAnim, ConditionYellow, ConditionRed, Scorch,
  Crater, SmudgeTypes, DamageParticleSystems, Explosion, VoxelAnims, PipScale, PipWrap, InfDeath, DeadBodies, Cursor,
  ShakeScreen, CSF, UIName, Countries)
- C&C Wiki: https://cnc.fandom.com/ (Sidebar, Skirmish, Radar, Veterancy, Spy, Gap generator, Weather control device,
  Mind control, Crate, soundtrack, RA2, manual, mission pages, transcripts)
- Mirror: https://cnc-central.fandom.com/ (Crate (Red Alert 2), mission pages)
- Rules.ini text (YR): https://gist.github.com/bashkirtsevich/b2a5b2f32b39f8abb2f0f37c40f1294c
- Project Perfect Mod: cursor frame list https://ppmforums.com/topic-33959/unused-mouse-shashp-frames ;
  pips https://ppmforums.com/topic-39416/infantry-pip-in-red-alert-2
- CnCNet forums: audio database https://forums.cncnet.org/topic/12109-in-game-audio-database-transcript ;
  queue cap https://forums.cncnet.org/topic/8696-how-to-get-rid-of-maximum-30-units-build-queue ;
  co-op settings https://forums.cncnet.org/topic/9080-adding-settings-to-the-cooperative-gamemode
- CnCmaps: https://cncmaps.net/red-alert-2-hotkeys · https://cncmaps.net/factions-of-red-alert-2
- DefKey: https://defkey.com/command-conquer-red-alert-2-shortcuts
- Red Alert Archive walkthroughs: http://ra.afraid.org/html/ra/a_wt.html · http://ra.afraid.org/html/ra/s_wt.html
- OpenPeon RA2 voice pack: https://openpeon.com/packs/ra2_peon
- EVA line transcript: https://www.myredstone.top/en/archives/2515
- Frank Klepacki: https://www.frankklepacki.com/ost/vg/cnc-ra2
- Discogs: https://www.discogs.com/release/1194136-Frank-Klepacki-Command-Conquer-Red-Alert-2-The-Soundtrack
- StrategyWiki RA2 controls (403): https://strategywiki.org/wiki/Command_%26_Conquer:_Red_Alert_2/Controls
- TCRF unused graphics: https://tcrf.net/Command_%26_Conquer:_Red_Alert_2_(Windows)/Unused_Graphics
- Hardware-cursor reverse-engineering: https://github.com/gitTerebi/ra2-hwcursor-wasd
