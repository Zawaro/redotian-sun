extends CanvasLayer

const POOL_SIZE := 30
const LINE_WIDTH := 1.0
const HEALTH_BAR_HEIGHT_WORLD := 0.1
const MAX_CARGO_SLOTS := 5
const MAX_PASSENGER_SLOTS := 5
const PIP_SLOT_W := 10.0
const PIP_SLOT_H := 8.0
const PIP_GAP := 1.0

var _pool: Array[Control] = []
var _used: int = 0


func _ready():
    layer = 128
    for _i in POOL_SIZE:
        var group := _create_group()
        _pool.append(group)
        add_child(group)
        group.visible = false


func _create_group() -> Control:
    var root := Control.new()
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.size = Vector2.ZERO

    for arm_name in [
        "BracketH_TL",
        "BracketV_TL",
        "BracketH_TR",
        "BracketV_TR",
        "BracketH_BL",
        "BracketV_BL",
        "BracketH_BR",
        "BracketV_BR",
    ]:
        var arm := ColorRect.new()
        arm.name = arm_name
        arm.color = Color.WHITE
        root.add_child(arm)

    var health_outline := ColorRect.new()
    health_outline.name = "HealthOutline"
    health_outline.color = Color.BLACK
    root.add_child(health_outline)

    var health_fill := ColorRect.new()
    health_fill.name = "HealthFill"
    root.add_child(health_fill)

    var pip_grid := ColorRect.new()
    pip_grid.name = "PipGrid"
    pip_grid.color = Color(0, 0, 0, 0.6)
    pip_grid.visible = false
    root.add_child(pip_grid)

    for i in MAX_CARGO_SLOTS:
        var slot := ColorRect.new()
        slot.name = "CargoPip_" + str(i)
        slot.color = Color(0.2, 0.2, 0.2)
        slot.visible = false
        root.add_child(slot)

    for i in range(1, MAX_CARGO_SLOTS):
        var div := ColorRect.new()
        div.name = "CargoDivider_" + str(i)
        div.color = Color(0, 0, 0, 0.8)
        div.visible = false
        root.add_child(div)

    for i in MAX_PASSENGER_SLOTS:
        var slot := ColorRect.new()
        slot.name = "PassPip_" + str(i)
        slot.color = Color(0.2, 0.2, 0.2)
        slot.visible = false
        root.add_child(slot)

    for i in range(1, MAX_PASSENGER_SLOTS):
        var div := ColorRect.new()
        div.name = "PassDivider_" + str(i)
        div.color = Color(0, 0, 0, 0.8)
        div.visible = false
        root.add_child(div)

    return root


func _process(_delta):
    _used = 0

    var camera := get_viewport().get_camera_3d()
    if not camera:
        return

    var tree := get_tree()
    if not tree:
        return

    for node in tree.get_nodes_in_group("selectable"):
        if _used >= POOL_SIZE:
            break
        var ent := node.get_node_or_null("SelectComponent") as SelectComponent
        if not ent or not (ent.is_selected or ent.is_hovering):
            continue
        if _layout_entity(ent, camera):
            _used += 1

    for i in range(_used, _pool.size()):
        _pool[i].visible = false


func _get_group() -> Control:
    if _used < _pool.size():
        return _pool[_used]
    var group := _create_group()
    _pool.append(group)
    add_child(group)
    return group


func _get_selection_size(ent: SelectComponent, parent: Node3D) -> Vector3:
    var art := parent.get_node_or_null("ArtComponent") as ArtComponent
    if art and art.art_data and art.art_data.placeholder_size != Vector3.ZERO:
        return art.art_data.placeholder_size
    return ent.outline_size


func _layout_entity(ent: SelectComponent, camera: Camera3D) -> bool:
    var parent := ent.get_parent() as Node3D
    if not parent:
        return false

    var is_structure := ent.select_box_type == 2
    if is_structure and not ent.is_selected:
        return false

    var size := _get_selection_size(ent, parent)
    var half_w := size.x / 2.0
    var half_h := size.y * 0.55

    var corners := PackedVector3Array(
        [
            parent.global_position + Vector3(-half_w, -half_h, 0),
            parent.global_position + Vector3(half_w, -half_h, 0),
            parent.global_position + Vector3(half_w, half_h, 0),
            parent.global_position + Vector3(-half_w, half_h, 0),
        ]
    )

    if camera.is_position_behind(parent.global_position):
        return false

    var screen_corners: Array[Vector2] = []
    for c in corners:
        screen_corners.append(camera.unproject_position(c))

    var min_s := screen_corners[0]
    var max_s := screen_corners[0]
    for p in screen_corners:
        min_s = min_s.min(p)
        max_s = max_s.max(p)

    var rect_size := max_s - min_s
    rect_size.x = max(rect_size.x, 24.0)
    rect_size.y = max(rect_size.y, 12.0)

    var rect := Rect2(min_s, rect_size)
    var is_hover := ent.is_hovering

    var group := _get_group()
    group.visible = true

    if is_structure:
        _layout_bracket(group, rect, false)
        return true

    _layout_bracket(group, rect, is_hover)
    _layout_health_bar(group, ent, rect, camera, parent, size)
    _layout_pips(group, parent, rect)
    return true


func _layout_bracket(group: Control, rect: Rect2, is_hover: bool):
    var show_bracket := not is_hover
    var corner_inset: float = min(rect.size.x, rect.size.y) * 0.35
    var lw := LINE_WIDTH

    var arm_names := [
        "BracketH_TL",
        "BracketV_TL",
        "BracketH_TR",
        "BracketV_TR",
        "BracketH_BL",
        "BracketV_BL",
        "BracketH_BR",
        "BracketV_BR",
    ]
    for arm_name in arm_names:
        var arm := group.get_node(arm_name) as ColorRect
        arm.visible = show_bracket
    if not show_bracket:
        return

    var tl := group.get_node("BracketH_TL") as ColorRect
    tl.position = rect.position
    tl.size = Vector2(corner_inset, lw)

    var vl := group.get_node("BracketV_TL") as ColorRect
    vl.position = rect.position
    vl.size = Vector2(lw, corner_inset)

    var arm_tr := group.get_node("BracketH_TR") as ColorRect
    arm_tr.position = Vector2(rect.end.x - corner_inset, rect.position.y)
    arm_tr.size = Vector2(corner_inset, lw)

    var vr := group.get_node("BracketV_TR") as ColorRect
    vr.position = Vector2(rect.end.x - lw, rect.position.y)
    vr.size = Vector2(lw, corner_inset)

    var bl := group.get_node("BracketH_BL") as ColorRect
    bl.position = Vector2(rect.position.x, rect.end.y - lw)
    bl.size = Vector2(corner_inset, lw)

    var brv := group.get_node("BracketV_BL") as ColorRect
    brv.position = Vector2(rect.position.x, rect.end.y - corner_inset)
    brv.size = Vector2(lw, corner_inset)

    var br := group.get_node("BracketH_BR") as ColorRect
    br.position = Vector2(rect.end.x - corner_inset, rect.end.y - lw)
    br.size = Vector2(corner_inset, lw)

    var trv := group.get_node("BracketV_BR") as ColorRect
    trv.position = Vector2(rect.end.x - lw, rect.end.y - corner_inset)
    trv.size = Vector2(lw, corner_inset)


func _layout_health_bar(
    group: Control,
    ent: SelectComponent,
    rect: Rect2,
    camera: Camera3D,
    parent: Node3D,
    size: Vector3
):
    var health_outline := group.get_node("HealthOutline") as ColorRect
    var health_fill := group.get_node("HealthFill") as ColorRect

    var half_w := size.x / 2.0
    var half_h := size.y * 0.55
    var corner_inset: float = min(half_w, half_h) * 0.35

    var bar_pos := (
        parent.global_position
        + Vector3(0, half_w + corner_inset + HEALTH_BAR_HEIGHT_WORLD + 0.12, 0)
    )

    if camera.is_position_behind(bar_pos):
        health_outline.visible = false
        health_fill.visible = false
        return

    var screen_pos := camera.unproject_position(bar_pos)
    var bar_height_world := HEALTH_BAR_HEIGHT_WORLD * 2.0
    var bottom_world := bar_pos + Vector3(0, -bar_height_world, 0)
    var bottom_screen := camera.unproject_position(bottom_world)
    var bar_height: float = max(screen_pos.y - bottom_screen.y, 4.0)

    var health_ratio := 1.0
    if is_instance_valid(ent.health_component):
        health_ratio = (
            float(ent.health_component.current_health) / float(ent.health_component.max_health)
        )

    var bar_width := rect.size.x

    health_outline.visible = true
    health_outline.position = Vector2(rect.position.x - 1, screen_pos.y - bar_height - 1)
    health_outline.size = Vector2(bar_width + 2, bar_height + 2)

    health_fill.visible = true
    health_fill.position = Vector2(rect.position.x, screen_pos.y - bar_height)
    health_fill.size = Vector2(bar_width * health_ratio, bar_height)
    health_fill.color = ent.get_health_color(health_ratio)


func _layout_pips(group: Control, parent: Node3D, rect: Rect2):
    var transport := parent.get_node_or_null("TransportComponent") as TransportComponent
    var has_cargo := transport and transport.resource_capacity > 0
    var has_passengers := transport and transport.passengers > 0

    var pip_grid := group.get_node("PipGrid") as ColorRect
    var cargo_pips: Array[ColorRect] = []
    for i in MAX_CARGO_SLOTS:
        cargo_pips.append(group.get_node("CargoPip_" + str(i)) as ColorRect)
    var cargo_dividers: Array[ColorRect] = []
    for i in range(1, MAX_CARGO_SLOTS):
        cargo_dividers.append(group.get_node("CargoDivider_" + str(i)) as ColorRect)
    var pass_pips: Array[ColorRect] = []
    for i in MAX_PASSENGER_SLOTS:
        pass_pips.append(group.get_node("PassPip_" + str(i)) as ColorRect)
    var pass_dividers: Array[ColorRect] = []
    for i in range(1, MAX_PASSENGER_SLOTS):
        pass_dividers.append(group.get_node("PassDivider_" + str(i)) as ColorRect)

    if not has_cargo and not has_passengers:
        pip_grid.visible = false
        for p in cargo_pips:
            p.visible = false
        for p in cargo_dividers:
            p.visible = false
        for p in pass_pips:
            p.visible = false
        for p in pass_dividers:
            p.visible = false
        return

    var num_rows := 1
    if has_cargo and has_passengers:
        num_rows = 2

    var grid_w := float(MAX_CARGO_SLOTS) * (PIP_SLOT_W + PIP_GAP) - PIP_GAP + 4.0
    var grid_h := float(num_rows) * (PIP_SLOT_H + PIP_GAP) - PIP_GAP + 4.0
    var grid_left := rect.position.x + 4.0
    var grid_top := rect.end.y - grid_h + 2.0

    pip_grid.visible = true
    pip_grid.position = Vector2(rect.position.x + 2.0, rect.end.y - grid_h - 2.0)
    pip_grid.size = Vector2(grid_w, grid_h)

    # Determine cargo color from first resource type
    var cargo_color := Color.WHITE
    if has_cargo and transport.cargo.size() > 0:
        var rules := EntityFactory.get_global_rules()
        if rules:
            var first_type: String = transport.cargo.keys()[0]
            var rt := rules.get_resource_type(first_type)
            if rt:
                cargo_color = rt.color

    var cargo_filled := transport.get_cargo_total() if has_cargo else 0

    for i in MAX_CARGO_SLOTS:
        var pip := cargo_pips[i]
        pip.visible = true
        pip.position = Vector2(grid_left + float(i) * (PIP_SLOT_W + PIP_GAP), grid_top)
        pip.size = Vector2(PIP_SLOT_W, PIP_SLOT_H)
        if i < cargo_filled:
            pip.color = cargo_color
        else:
            pip.color = Color(0.2, 0.2, 0.2)

    for i in range(1, MAX_CARGO_SLOTS):
        var div := cargo_dividers[i - 1]
        div.visible = true
        div.position = Vector2(grid_left + float(i) * (PIP_SLOT_W + PIP_GAP) - PIP_GAP, grid_top)
        div.size = Vector2(1, PIP_SLOT_H)

    var pass_row_y := grid_top
    if num_rows > 1:
        pass_row_y += PIP_SLOT_H + PIP_GAP

    for i in MAX_PASSENGER_SLOTS:
        var pip := pass_pips[i]
        pip.visible = has_passengers and i < transport.passengers
        pip.position = Vector2(grid_left + float(i) * (PIP_SLOT_W + PIP_GAP), pass_row_y)
        pip.size = Vector2(PIP_SLOT_W, PIP_SLOT_H)
        if has_passengers and i < transport.current_passengers:
            pip.color = Color.WHITE
        else:
            pip.color = Color(0.2, 0.2, 0.2)

    for i in range(1, MAX_PASSENGER_SLOTS):
        var div := pass_dividers[i - 1]
        div.visible = has_passengers
        div.position = Vector2(grid_left + float(i) * (PIP_SLOT_W + PIP_GAP) - PIP_GAP, pass_row_y)
        div.size = Vector2(1, PIP_SLOT_H)
