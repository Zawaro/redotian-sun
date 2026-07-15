extends CanvasLayer

## Draws selection brackets, health bars, and cargo/passenger pips
## directly via CanvasItem primitives — zero per-selection node allocations.

const LINE_WIDTH := 1.0
const MAX_CARGO_SLOTS := 10
const MAX_PASSENGER_SLOTS := 5
const PIP_GAP_RATIO := 0.002
const SEGMENT_WIDTH_RATIO := 0.05


class DrawNode:
    extends Node2D

    func _draw():
        (get_parent() as SelectionOverlay)._do_draw(self)


class HealthBarNode:
    extends Node2D

    func _draw():
        (get_parent() as SelectionOverlay)._do_draw_health_bars(self)


var _draw_node: Node2D
var _health_bar_node: Node2D
var _entities: Array[Dictionary] = []


func _ready():
    layer = 128
    _health_bar_node = HealthBarNode.new()
    _health_bar_node.name = "HealthBarNode"
    var shader := load("res://shaders/ui/health_bar_segment.gdshader")
    var mat := ShaderMaterial.new()
    mat.shader = shader
    _health_bar_node.material = mat
    add_child(_health_bar_node)

    _draw_node = DrawNode.new()
    add_child(_draw_node)


func _process(_delta):
    _entities.clear()
    _collect_entities()
    _draw_node.queue_redraw()
    _health_bar_node.queue_redraw()


func _do_draw(node: Node2D):
    for e in _entities:
        _draw_health_bar_outline(node, e.bracket_rect)
        _draw_brackets(node, e.bracket_rect, e.is_selected)
        _draw_pips(node, e.rect, e.cargo_pips, e.cargo_color, e.pass_pips)


func _do_draw_health_bars(node: Node2D):
    var mat := node.material as ShaderMaterial
    for e in _entities:
        var bar_height: float = e.rect.size.y * 0.053
        var bar_y: float = e.bracket_rect.position.y - bar_height - e.rect.size.y * 0.02
        var num_segs: float = 1.0 / SEGMENT_WIDTH_RATIO

        mat.set_shader_parameter("num_segments", num_segs)
        var c: Color = e.health_color
        (
            node
            . draw_rect(
                Rect2(e.rect.position.x, bar_y, e.rect.size.x, bar_height),
                Color(c.r, c.g, c.b, e.health_ratio),
            )
        )


func _collect_entities():
    var camera := get_viewport().get_camera_3d()
    if not camera:
        return

    var tree := get_tree()
    if not tree:
        return

    for ent_node in tree.get_nodes_in_group("selectable"):
        var ent := ent_node.get_node_or_null("SelectComponent") as SelectComponent
        if not ent or not (ent.is_selected or ent.is_hovering):
            continue
        if ent.select_box_type == 2:
            continue

        var parent: Node3D = ent.get_parent() as Node3D
        if not parent:
            continue
        if camera.is_position_behind(parent.global_position):
            continue

        var size := _get_selection_size(ent, parent)
        var rect: Variant = _project_entity(parent, camera, size)
        if not rect:
            continue

        var bracket_rect: Rect2 = rect
        bracket_rect.position.y -= rect.size.y * 0.1

        var health_ratio := 1.0
        var health_color := Color.WHITE
        if is_instance_valid(ent.health_component):
            health_ratio = (
                float(ent.health_component.current_health) / float(ent.health_component.max_health)
            )
            health_color = ent.get_health_color(health_ratio)

        var cargo_pips: Array[Dictionary] = []
        var cargo_color := Color.WHITE
        var pass_pips: Array[Dictionary] = []

        var transport := parent.get_node_or_null("TransportComponent") as TransportComponent
        if transport and transport.storage > 0 and transport.cargo.size() > 0:
            var rules := EntityFactory.get_global_rules()
            if rules:
                var first_type: String = transport.cargo.keys()[0]
                var rt := rules.get_resource_type(first_type)
                if rt:
                    cargo_color = rt.color

        _gather_pips(parent, rect, bracket_rect, cargo_pips, pass_pips)

        (
            _entities
            . append(
                {
                    "rect": rect,
                    "bracket_rect": bracket_rect,
                    "is_selected": ent.is_selected,
                    "health_ratio": health_ratio,
                    "health_color": health_color,
                    "cargo_pips": cargo_pips,
                    "cargo_color": cargo_color,
                    "pass_pips": pass_pips,
                }
            )
        )


func _get_selection_size(ent: SelectComponent, parent: Node3D) -> float:
    if ent.outline_2d_size != Vector2.ZERO:
        return ent.outline_2d_size.x

    var art := parent.get_node_or_null("ArtComponent") as ArtComponent
    if art and art.art_data and art.art_data.outline_2d_size != Vector2.ZERO:
        return art.art_data.outline_2d_size.x

    return 2.0


func _project_entity(parent: Node3D, camera: Camera3D, size: float) -> Variant:
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
    var min_size := 12.0
    rect_size.x = max(rect_size.x, min_size)
    rect_size.y = max(rect_size.y, min_size)

    return Rect2(min_s, rect_size)


func _draw_brackets(node: Node2D, rect: Rect2, is_selected: bool):
    if not is_selected:
        return

    var corner_inset: float = min(rect.size.x, rect.size.y) * 0.35
    var col := Color.WHITE

    (
        node
        . draw_line(
            rect.position,
            rect.position + Vector2(corner_inset, 0),
            col,
            LINE_WIDTH,
        )
    )
    (
        node
        . draw_line(
            rect.position,
            rect.position + Vector2(0, corner_inset),
            col,
            LINE_WIDTH,
        )
    )
    (
        node
        . draw_line(
            Vector2(rect.end.x, rect.position.y),
            Vector2(rect.end.x - corner_inset, rect.position.y),
            col,
            LINE_WIDTH,
        )
    )
    (
        node
        . draw_line(
            Vector2(rect.end.x, rect.position.y),
            Vector2(rect.end.x, rect.position.y + corner_inset),
            col,
            LINE_WIDTH,
        )
    )
    (
        node
        . draw_line(
            Vector2(rect.position.x, rect.end.y),
            Vector2(rect.position.x + corner_inset, rect.end.y),
            col,
            LINE_WIDTH,
        )
    )
    (
        node
        . draw_line(
            Vector2(rect.position.x, rect.end.y),
            Vector2(rect.position.x, rect.end.y - corner_inset),
            col,
            LINE_WIDTH,
        )
    )
    (
        node
        . draw_line(
            rect.end,
            rect.end - Vector2(corner_inset, 0),
            col,
            LINE_WIDTH,
        )
    )
    (
        node
        . draw_line(
            rect.end,
            rect.end - Vector2(0, corner_inset),
            col,
            LINE_WIDTH,
        )
    )


func _draw_health_bar_outline(node: Node2D, rect: Rect2):
    var bar_height: float = rect.size.y * 0.053
    var bar_width: float = rect.size.x
    var bar_y: float = rect.position.y - bar_height - rect.size.y * 0.02
    (
        node
        . draw_rect(
            Rect2(rect.position.x - 1, bar_y - 1, bar_width + 2, bar_height + 2),
            Color.BLACK,
            false,
            1.0,
        )
    )


func _gather_pips(
    parent: Node3D,
    rect: Rect2,
    bracket_rect: Rect2,
    cargo_pips: Array[Dictionary],
    pass_pips: Array[Dictionary],
):
    var transport := parent.get_node_or_null("TransportComponent") as TransportComponent
    var has_cargo := transport and transport.storage > 0
    var has_passengers := transport and transport.passengers > 0

    if not has_cargo and not has_passengers:
        return

    var num_cargo_pips := MAX_CARGO_SLOTS
    var art := parent.get_node_or_null("ArtComponent") as ArtComponent
    if art and art.art_data and art.art_data.pip_count > 0:
        num_cargo_pips = clampi(art.art_data.pip_count, 1, MAX_CARGO_SLOTS)

    var pip_w := rect.size.x * 0.075
    var pip_h := pip_w * 0.8
    var pip_gap: float = rect.size.x * PIP_GAP_RATIO

    var num_rows := 1
    if has_cargo and has_passengers:
        num_rows = 2

    var grid_h := float(num_rows) * (pip_h + pip_gap) - pip_gap
    var grid_left := bracket_rect.position.x + pip_w * 0.2
    var grid_top := bracket_rect.end.y - grid_h - pip_h * 0.1

    var cargo_filled: float = transport.get_cargo_total() if has_cargo else 0.0
    var filled_pips := 0
    if has_cargo and transport.storage > 0:
        var ratio := float(cargo_filled) / float(transport.storage)
        filled_pips = int(ceil(ratio * float(num_cargo_pips)))

    for i in num_cargo_pips:
        var pip_x: float = grid_left + float(i) * (pip_w + pip_gap)
        var filled := i < filled_pips
        (
            cargo_pips
            . append(
                {
                    "rect": Rect2(pip_x, grid_top, pip_w, pip_h),
                    "filled": filled,
                }
            )
        )

    var pass_row_y := grid_top
    if num_rows > 1:
        pass_row_y += pip_h + pip_gap

    for i in MAX_PASSENGER_SLOTS:
        var pip_x: float = grid_left + float(i) * (pip_w + pip_gap)
        var visible_pip := has_passengers and i < transport.passengers
        var filled := visible_pip and i < transport.current_passengers
        if visible_pip:
            (
                pass_pips
                . append(
                    {
                        "rect": Rect2(pip_x, pass_row_y, pip_w, pip_h),
                        "filled": filled,
                    }
                )
            )


func _draw_pips(
    node: Node2D,
    _rect: Rect2,
    cargo_pips: Array[Dictionary],
    cargo_color: Color,
    pass_pips: Array[Dictionary],
):
    for pip in cargo_pips:
        var r: Rect2 = pip.rect
        node.draw_rect(r, Color.BLACK, false, 1.0)
        if pip.filled:
            (
                node
                . draw_rect(
                    Rect2(r.position + Vector2(1, 1), r.size - Vector2(2, 2)),
                    cargo_color,
                )
            )

    for pip in pass_pips:
        var r: Rect2 = pip.rect
        node.draw_rect(r, Color.BLACK, false, 1.0)
        if pip.filled:
            (
                node
                . draw_rect(
                    Rect2(r.position + Vector2(1, 1), r.size - Vector2(2, 2)),
                    Color.WHITE,
                )
            )
