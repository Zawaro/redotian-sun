class_name SplineUtil


static func evaluate(waypoints: PackedVector3Array, t: float) -> Vector3:
    var n := waypoints.size()
    var seg := clampi(floori(t), 0, maxi(0, n - 2))
    var local_t := clampf(t - float(seg), 0.0, 1.0)
    var p0 := waypoints[maxi(0, seg - 1)]
    var p1 := waypoints[seg]
    var p2 := waypoints[min(n - 1, seg + 1)]
    var p3 := waypoints[min(n - 1, seg + 2)]
    return _catmull_rom(p0, p1, p2, p3, local_t)


static func tangent(waypoints: PackedVector3Array, t: float) -> Vector3:
    var n := waypoints.size()
    var seg := clampi(floori(t), 0, maxi(0, n - 2))
    var local_t := clampf(t - float(seg), 0.0, 1.0)
    var p0 := waypoints[maxi(0, seg - 1)]
    var p1 := waypoints[seg]
    var p2 := waypoints[min(n - 1, seg + 1)]
    var p3 := waypoints[min(n - 1, seg + 2)]
    return _catmull_rom_tangent(p0, p1, p2, p3, local_t)


static func _catmull_rom(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
    var t2 := t * t
    var t3 := t2 * t
    return (
        0.5
        * (
            (2.0 * p1)
            + (-p0 + p2) * t
            + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
            + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3
        )
    )


static func _catmull_rom_tangent(
    p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float
) -> Vector3:
    var t2 := t * t
    return (
        0.5
        * (
            (-p0 + p2)
            + 2.0 * (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t
            + 3.0 * (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t2
        )
    )
