## 1. Select and health preview

- [x] 1.1 Add `OVERLAY_SELECT` to the overlay registry, defaults, and overlay-name map
- [x] 1.2 Build the corner-bracket select box from `foundation × CELL_SIZE` (buildings) or mesh bounds
- [x] 1.3 Build the structure health bar as a full-depth Z span at the box top's left edge (`-90°` Y), buildings only
- [x] 1.4 Author both under `ObjectRoot` in centered local space; hide for terrain/overlay/smudge and audio/image

## 2. Theater selector

- [x] 2.1 Add a HUD dropdown listing `TerrainCatalog.get_all_theaters()` with the active theater preselected
- [x] 2.2 Switch via `TerrainCatalog.set_active_theater(id)` and refresh the preview; disable when only one theater
- [x] 2.3 Rebuild the theater list on `game_changed`

## 3. Rotation and camera

- [x] 3.1 Add `reset_rotation()` — restore authored base yaw, clear pitch — wired to a HUD button
- [x] 3.2 Compute default zoom once and on projection toggle; preserve user zoom across asset changes

## 4. Grounding helper

- [x] 4.1 Ground buildings on the foundation center so the min corner sits at the world origin
- [x] 4.2 Make `_collect_bounds` include the node it is given

## 5. Tests and validation

- [x] 5.1 Integration: zoom persistence across asset changes
- [x] 5.2 Integration: reset rotation returns to base yaw and clears pitch
- [x] 5.3 Integration: theater selector lists theaters
- [x] 5.4 Integration: building select box + health bar preview, top alignment, grounding min corner
- [x] 5.5 `openspec validate asset-browser-preview-controls --strict`, `gdlint`, `gdformat --check`, full headless suite green
