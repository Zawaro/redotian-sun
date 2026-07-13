extends CanvasLayer

const POOL_SIZE := 30
const LINE_WIDTH := 1.0
const MAX_CARGO_SLOTS := 5
const MAX_PASSENGER_SLOTS := 5

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

    for i in MAX_CARGO_SLOTS:
        var panel := Panel.new()
        panel.name = "CargoPip_" + str(i)
        var style := StyleBoxFlat.new()
        style.bg_color = Color(0, 0, 0, 0)
        style.set_border_width_all(1)
        style.border_color = Color.BLACK
        panel.add_theme_stylebox_override("panel", style)
        panel.visible = false
        root.add_child(panel)

    for i in MAX_PASSENGER_SLOTS:
        var panel := Panel.new()
        panel.name = "PassPip_" + str(i)
        var style := StyleBoxFlat.new()
        style.bg_color = Color(0, 0, 0, 0)
        style.set_border_width_all(1)
        style.border_color = Color.BLACK
        panel.add_theme_stylebox_override("panel", style)
        panel.visible = false
        root.add_child(panel)

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
        if ent.select_box_type == 2:
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


func _get_selection_size(ent: SelectComponent, parent: Node3D = null) -> float:
    if ent.outline_2d_size != Vector2.ZERO:
        return ent.outline_2d_size.x

    if parent:
        var art := parent.get_node_or_null("ArtComponent") as ArtComponent
        if art and art.art_data and art.art_data.outline_2d_size != Vector2.ZERO:
            return art.art_data.outline_2d_size.x

    return 2.0


func _layout_entity(ent: SelectComponent, camera: Camera3D) -> bool:
    var parent := ent.get_parent() as Node3D
    if not parent:
        return false

    var size := _get_selection_size(ent, parent)

    if camera.is_position_behind(parent.global_position):
        return false

    var center_screen := camera.unproject_position(parent.global_position)
    var ref_screen := camera.unproject_position(parent.global_position + Vector3(size, 0, 0))
    var screen_half: float = center_screen.distance_to(ref_screen) / 2.0

    var corners_screen := PackedVector2Array(
        [
            center_screen + Vector2(-screen_half, -screen_half),
            center_screen + Vector2(screen_half, -screen_half),
            center_screen + Vector2(screen_half, screen_half),
            center_screen + Vector2(-screen_half, screen_half),
        ]
    )

    var corners := PackedVector3Array()
    for cs in corners_screen:
        var ray_origin := camera.project_ray_origin(cs)
        var ray_dir := camera.project_ray_normal(cs)
        if absf(ray_dir.y) < 0.001:
            corners.append(parent.global_position)
            continue
        var t: float = -ray_origin.y / ray_dir.y
        corners.append(ray_origin + ray_dir * t)

    var screen_corners: Array[Vector2] = []
    for c in corners:
        screen_corners.append(camera.unproject_position(c))

    var min_s := screen_corners[0]
    var max_s := screen_corners[0]
    for p in screen_corners:
        min_s = min_s.min(p)
        max_s = max_s.max(p)

    var rect_size := max_s - min_s
    print(" rect_size: ", rect_size, " screen_half: ", screen_half)
    var min_size := 12.0
    rect_size.x = max(rect_size.x, min_size)
    rect_size.y = max(rect_size.y, min_size)

    var rect := Rect2(min_s, rect_size)

    var group := _get_group()
    group.visible = true

    var bracket_rect := rect
    bracket_rect.position.y -= rect.size.y * 0.1
    _layout_bracket(group, bracket_rect, ent.is_selected)
    _layout_health_bar(group, ent, rect, camera, parent, size)
    _layout_pips(group, parent, rect)
    return true


func _layout_bracket(group: Control, rect: Rect2, is_selected: bool):
    var show_bracket := is_selected
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
    _camera: Camera3D,
    _parent: Node3D,
    _size: float,
):
    var health_outline := group.get_node("HealthOutline") as ColorRect
    var health_fill := group.get_node("HealthFill") as ColorRect

    var bar_height: float = rect.size.y * 0.08
    var bar_width := rect.size.x
    var bar_y: float = rect.position.y - bar_height - 10.0

    var health_ratio := 1.0
    if is_instance_valid(ent.health_component):
        health_ratio = (
            float(ent.health_component.current_health) / float(ent.health_component.max_health)
        )

    health_outline.visible = true
    health_outline.position = Vector2(rect.position.x - 1, bar_y - 1)
    health_outline.size = Vector2(bar_width + 2, bar_height + 2)

    health_fill.visible = true
    health_fill.position = Vector2(rect.position.x, bar_y)
    health_fill.size = Vector2(bar_width * health_ratio, bar_height)
    health_fill.color = ent.get_health_color(health_ratio)


func _layout_pips(group: Control, parent: Node3D, rect: Rect2):
    var transport := parent.get_node_or_null("TransportComponent") as TransportComponent
    var has_cargo := transport and transport.resource_capacity > 0
    var has_passengers := transport and transport.passengers > 0

    var cargo_pips: Array[Panel] = []
    for i in MAX_CARGO_SLOTS:
        cargo_pips.append(group.get_node("CargoPip_" + str(i)) as Panel)
    var pass_pips: Array[Panel] = []
    for i in MAX_PASSENGER_SLOTS:
        pass_pips.append(group.get_node("PassPip_" + str(i)) as Panel)

    if not has_cargo and not has_passengers:
        for p in cargo_pips:
            p.visible = false
        for p in pass_pips:
            p.visible = false
        return

    var pip_w := rect.size.x / ((MAX_CARGO_SLOTS + 1) * 2)
    var pip_h := pip_w * 0.8
    var pip_gap: float = 0.0

    var num_rows := 1
    if has_cargo and has_passengers:
        num_rows = 2

    var grid_w := float(MAX_CARGO_SLOTS) * (pip_w + pip_gap) - pip_gap + pip_w * 0.4
    var grid_h := float(num_rows) * (pip_h + pip_gap) - pip_gap + pip_w * 0.4
    var grid_left := rect.position.x + pip_w * 0.2
    var pip_offset: float = pip_h * 0.5
    var bracket_end_y := rect.end.y - rect.size.y * 0.07
    var grid_top := bracket_end_y - grid_h - pip_w * 0.1

    var cargo_color := Color.WHITE
    if has_cargo and transport.cargo.size() > 0:
        var rules := EntityFactory.get_global_rules()
        if rules:
            var first_type: String = transport.cargo.keys()[0]
            var rt := rules.get_resource_type(first_type)
            if rt:
                cargo_color = rt.color

    var cargo_filled := transport.get_cargo_total() if has_cargo else 0
    var filled_pips := 0
    if has_cargo and transport.resource_capacity > 0:
        var ratio := float(cargo_filled) / float(transport.resource_capacity)
        filled_pips = int(ceil(ratio * float(MAX_CARGO_SLOTS)))

    for i in MAX_CARGO_SLOTS:
        var pip := cargo_pips[i]
        var pip_x: float = grid_left + float(i) * (pip_w + pip_gap)
        var filled := i < filled_pips

        var style: StyleBoxFlat = pip.get_theme_stylebox("panel") as StyleBoxFlat
        if filled:
            style.bg_color = cargo_color
        else:
            style.bg_color = Color(0, 0, 0, 0)

        pip.visible = true
        pip.position = Vector2(pip_x, grid_top)
        pip.size = Vector2(pip_w, pip_h)

    var pass_row_y := grid_top
    if num_rows > 1:
        pass_row_y += pip_h + pip_gap

    for i in MAX_PASSENGER_SLOTS:
        var pip := pass_pips[i]
        var pip_x: float = grid_left + float(i) * (pip_w + pip_gap)
        var filled := has_passengers and i < transport.current_passengers

        var style: StyleBoxFlat = pip.get_theme_stylebox("panel") as StyleBoxFlat
        if filled:
            style.bg_color = Color.WHITE
        else:
            style.bg_color = Color(0, 0, 0, 0)

        pip.visible = has_passengers and i < transport.passengers
        pip.position = Vector2(pip_x, pass_row_y)
        pip.size = Vector2(pip_w, pip_h)
