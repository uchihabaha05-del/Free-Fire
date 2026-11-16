extends Node3D

# MASS BATTLE — visual battlefield upgrade.
# Large crowds remain GPU-instanced so the scene can scale on mobile.

const MAX_UNITS := 10000
const FIELD_WIDTH := 110.0
const FIELD_DEPTH := 72.0
const TERRAIN_X := 100
const TERRAIN_Z := 68

var team_a_count := 500
var team_b_count := 500
var team_a_alive := 500
var team_b_alive := 500
var battle_running := false
var battle_time := 0.0
var battle_speed := 1.0
var ui_refresh_timer := 0.0
var rng := RandomNumberGenerator.new()

var team_a_mesh: MultiMeshInstance3D
var team_b_mesh: MultiMeshInstance3D
var status_label: Label
var a_spin: SpinBox
var b_spin: SpinBox
var speed_slider: HSlider
var start_button: Button

func _ready() -> void:
    rng.randomize()
    _build_world()
    _build_ui()
    _setup_armies()
    _apply_visible_counts()
    _refresh_ui()

func _build_world() -> void:
    var env := WorldEnvironment.new()
    var environment := Environment.new()
    environment.background_mode = Environment.BG_SKY
    var sky := Sky.new()
    var sky_material := ProceduralSkyMaterial.new()
    sky_material.sky_top_color = Color(0.19, 0.31, 0.43)
    sky_material.sky_horizon_color = Color(0.66, 0.72, 0.76)
    sky_material.ground_bottom_color = Color(0.12, 0.15, 0.13)
    sky_material.ground_horizon_color = Color(0.48, 0.52, 0.48)
    sky.sky_material = sky_material
    environment.sky = sky
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
    environment.ambient_light_energy = 0.65
    environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    environment.tonemap_exposure = 1.05
    env.environment = environment
    add_child(env)

    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-48, -28, 0)
    sun.light_energy = 1.25
    sun.shadow_enabled = true
    add_child(sun)

    _create_terrain()
    _create_battlefield_details()
    _create_camera()

func _create_terrain() -> void:
    var noise := FastNoiseLite.new()
    noise.seed = 4812
    noise.frequency = 0.035
    noise.fractal_octaves = 3

    var surface := SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    var step_x := FIELD_WIDTH / float(TERRAIN_X)
    var step_z := FIELD_DEPTH / float(TERRAIN_Z)

    for z in range(TERRAIN_Z):
        for x in range(TERRAIN_X):
            var x0 := -FIELD_WIDTH * 0.5 + float(x) * step_x
            var x1 := x0 + step_x
            var z0 := -FIELD_DEPTH * 0.5 + float(z) * step_z
            var z1 := z0 + step_z
            var p00 := Vector3(x0, _terrain_height(noise, x0, z0), z0)
            var p10 := Vector3(x1, _terrain_height(noise, x1, z0), z0)
            var p01 := Vector3(x0, _terrain_height(noise, x0, z1), z1)
            var p11 := Vector3(x1, _terrain_height(noise, x1, z1), z1)
            _add_terrain_vertex(surface, p00, Vector2(float(x) / TERRAIN_X, float(z) / TERRAIN_Z))
            _add_terrain_vertex(surface, p01, Vector2(float(x) / TERRAIN_X, float(z + 1) / TERRAIN_Z))
            _add_terrain_vertex(surface, p10, Vector2(float(x + 1) / TERRAIN_X, float(z) / TERRAIN_Z))
            _add_terrain_vertex(surface, p10, Vector2(float(x + 1) / TERRAIN_X, float(z) / TERRAIN_Z))
            _add_terrain_vertex(surface, p01, Vector2(float(x) / TERRAIN_X, float(z + 1) / TERRAIN_Z))
            _add_terrain_vertex(surface, p11, Vector2(float(x + 1) / TERRAIN_X, float(z + 1) / TERRAIN_Z))

    surface.generate_normals()
    var terrain := MeshInstance3D.new()
    terrain.mesh = surface.commit()
    terrain.material_override = _make_ground_material()
    add_child(terrain)

func _terrain_height(noise: FastNoiseLite, x: float, z: float) -> float:
    var edge_falloff := clampf(1.0 - absf(z) / (FIELD_DEPTH * 0.62), 0.0, 1.0)
    return noise.get_noise_2d(x, z) * 1.35 * edge_falloff

func _add_terrain_vertex(surface: SurfaceTool, point: Vector3, uv: Vector2) -> void:
    surface.set_uv(uv)
    surface.add_vertex(point)

func _make_ground_material() -> StandardMaterial3D:
    var image := Image.create(256, 256, false, Image.FORMAT_RGB8)
    var noise := FastNoiseLite.new()
    noise.seed = 771
    noise.frequency = 0.055
    for y in range(256):
        for x in range(256):
            var n := noise.get_noise_2d(float(x), float(y))
            var fleck := rng.randf_range(-0.035, 0.035)
            var shade := clampf(0.5 + n * 0.34 + fleck, 0.0, 1.0)
            var color := Color(0.19 + shade * 0.12, 0.22 + shade * 0.14, 0.13 + shade * 0.08)
            image.set_pixel(x, y, color)
    var texture := ImageTexture.create_from_image(image)
    var material := StandardMaterial3D.new()
    material.albedo_texture = texture
    material.roughness = 1.0
    material.uv1_scale = Vector3(13.0, 13.0, 1.0)
    return material

func _create_battlefield_details() -> void:
    _add_box(Vector3(FIELD_WIDTH, 0.16, 0.35), Vector3(0, -0.25, -FIELD_DEPTH * 0.5), Color(0.22, 0.25, 0.22))
    _add_box(Vector3(FIELD_WIDTH, 0.16, 0.35), Vector3(0, -0.25, FIELD_DEPTH * 0.5), Color(0.22, 0.25, 0.22))

    # Worn dirt road through the centre of the battlefield.
    var road := _add_box(Vector3(13.0, 0.035, FIELD_DEPTH - 3.0), Vector3(0, 0.04, 0), Color(0.28, 0.25, 0.19))
    road.rotation_degrees.y = 1.5

    # Defensive earth berms and sandbag barricades.
    for side in [-1, 1]:
        for row in range(3):
            var z := float(side) * (13.0 + float(row) * 8.0)
            _add_box(Vector3(25.0 - float(row) * 3.0, 1.05, 1.6), Vector3(float(side) * (7.0 - float(row) * 1.5), 0.45, z), Color(0.30, 0.29, 0.23))
        for i in range(7):
            var x := -42.0 + float(i) * 14.0
            _add_box(Vector3(4.0, 0.72, 1.0), Vector3(x, 0.34, float(side) * 25.0), Color(0.49, 0.43, 0.31))

    _add_scatter(_make_tree_mesh(), 145, 43.0, 31.0, 0.0, Color(0.30, 0.43, 0.25), true)
    _add_scatter(_make_rock_mesh(), 110, 49.0, 31.0, 0.0, Color(0.38, 0.39, 0.36), false)
    _add_scatter(_make_crate_mesh(), 42, 38.0, 26.0, 0.0, Color(0.39, 0.29, 0.18), false)

func _create_camera() -> void:
    var camera := Camera3D.new()
    camera.position = Vector3(0, 66, 78)
    camera.rotation_degrees = Vector3(-42, 0, 0)
    camera.current = true
    camera.fov = 54
    camera.far = 220.0
    add_child(camera)

func _add_box(size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    node.mesh = mesh
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = 0.92
    node.material_override = material
    node.position = pos
    add_child(node)
    return node

func _make_tree_mesh() -> Mesh:
    var surface := SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    var trunk := CylinderMesh.new()
    trunk.top_radius = 0.16
    trunk.bottom_radius = 0.25
    trunk.height = 2.5
    _append_part(surface, trunk, Vector3(0, 1.25, 0), Vector3.ONE, Vector3.ZERO)
    var crown := SphereMesh.new()
    crown.radius = 1.15
    crown.height = 2.3
    _append_part(surface, crown, Vector3(0, 2.9, 0), Vector3(1.0, 1.15, 1.0), Vector3.ZERO)
    var mesh := surface.commit()
    return mesh

func _make_rock_mesh() -> Mesh:
    var surface := SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    var rock := SphereMesh.new()
    rock.radius = 1.0
    rock.height = 1.7
    _append_part(surface, rock, Vector3.ZERO, Vector3(1.0, 0.65, 0.8), Vector3(0.2, 0.4, 0.1))
    return surface.commit()

func _make_crate_mesh() -> Mesh:
    var surface := SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    var crate := BoxMesh.new()
    crate.size = Vector3(1.25, 1.15, 1.25)
    _append_part(surface, crate, Vector3.ZERO, Vector3.ONE, Vector3.ZERO)
    return surface.commit()

func _append_part(surface: SurfaceTool, mesh: Mesh, position: Vector3, scale: Vector3, rotation: Vector3) -> void:
    var transform := Transform3D(Basis.from_euler(rotation).scaled(scale), position)
    surface.append_from(mesh, 0, transform)

func _add_scatter(mesh: Mesh, count: int, range_x: float, range_z: float, y: float, base_color: Color, trees: bool) -> void:
    var multimesh := MultiMesh.new()
    multimesh.transform_format = MultiMesh.TRANSFORM_3D
    multimesh.use_colors = true
    multimesh.mesh = mesh
    multimesh.instance_count = count
    for i in range(count):
        var x := rng.randf_range(-range_x, range_x)
        var z := rng.randf_range(-range_z, range_z)
        if absf(x) < 9.0 and absf(z) < 17.0:
            x += signf(x if x != 0.0 else 1.0) * 12.0
        var scale := rng.randf_range(0.72, 1.32)
        if trees:
            scale *= rng.randf_range(0.85, 1.25)
        var rotation := Basis(Vector3.UP, rng.randf_range(0.0, TAU))
        multimesh.set_instance_transform(i, Transform3D(rotation.scaled(Vector3.ONE * scale), Vector3(x, y, z)))
        multimesh.set_instance_color(i, base_color * rng.randf_range(0.82, 1.18))
    var node := MultiMeshInstance3D.new()
    node.multimesh = multimesh
    var material := StandardMaterial3D.new()
    material.albedo_color = Color.WHITE
    material.vertex_color_use_as_albedo = true
    material.roughness = 1.0
    node.material_override = material
    add_child(node)

func _build_ui() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)

    var panel := PanelContainer.new()
    panel.position = Vector2(18, 18)
    panel.custom_minimum_size = Vector2(310, 0)
    layer.add_child(panel)

    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 8)
    panel.add_child(column)

    var title := Label.new()
    title.text = "MASS BATTLE"
    title.add_theme_font_size_override("font_size", 26)
    column.add_child(title)

    var subtitle := Label.new()
    subtitle.text = "REAL-TIME BATTLEFIELD SIMULATION"
    subtitle.add_theme_font_size_override("font_size", 10)
    column.add_child(subtitle)
    column.add_child(HSeparator.new())

    column.add_child(_make_label("BLUE ARMY — SOLDIERS"))
    a_spin = _make_spin(500)
    column.add_child(a_spin)
    column.add_child(_make_label("RED ARMY — SOLDIERS"))
    b_spin = _make_spin(500)
    column.add_child(b_spin)

    var speed_row := HBoxContainer.new()
    var speed_text := Label.new()
    speed_text.text = "Battle speed"
    speed_row.add_child(speed_text)
    speed_slider = HSlider.new()
    speed_slider.min_value = 0.25
    speed_slider.max_value = 4.0
    speed_slider.step = 0.25
    speed_slider.value = 1.0
    speed_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    speed_slider.value_changed.connect(func(value: float) -> void:
        battle_speed = value
    )
    speed_row.add_child(speed_slider)
    column.add_child(speed_row)

    status_label = Label.new()
    status_label.text = "Ready"
    status_label.add_theme_font_size_override("font_size", 14)
    column.add_child(status_label)

    start_button = Button.new()
    start_button.text = "START BATTLE"
    start_button.custom_minimum_size.y = 42
    start_button.pressed.connect(_start_battle)
    column.add_child(start_button)

    var reset_button := Button.new()
    reset_button.text = "RESET ARMIES"
    reset_button.pressed.connect(_reset_battle)
    column.add_child(reset_button)

    var note := Label.new()
    note.text = "Detailed instanced troops • 10,000 per side target"
    note.add_theme_font_size_override("font_size", 10)
    column.add_child(note)

func _make_label(value: String) -> Label:
    var label := Label.new()
    label.text = value
    label.add_theme_font_size_override("font_size", 11)
    return label

func _make_spin(initial: int) -> SpinBox:
    var spin := SpinBox.new()
    spin.min_value = 1
    spin.max_value = MAX_UNITS
    spin.step = 50
    spin.value = initial
    spin.custom_minimum_size.x = 260
    return spin

func _setup_armies() -> void:
    team_a_mesh = _create_army(Color(0.18, 0.38, 0.70), -1)
    team_b_mesh = _create_army(Color(0.70, 0.20, 0.16), 1)
    add_child(team_a_mesh)
    add_child(team_b_mesh)

func _create_army(color: Color, side: int) -> MultiMeshInstance3D:
    var instance := MultiMeshInstance3D.new()
    var multimesh := MultiMesh.new()
    multimesh.transform_format = MultiMesh.TRANSFORM_3D
    multimesh.use_colors = true
    multimesh.mesh = _make_soldier_mesh()
    multimesh.instance_count = MAX_UNITS

    for i in range(MAX_UNITS):
        var columns := 100
        var row := int(i / columns)
        var col := i % columns
        var x := (float(col) / float(columns - 1) - 0.5) * (FIELD_WIDTH - 16.0)
        var z := float(side) * (5.5 + float(row) * 0.40)
        var angle := 0.0 if side < 0 else PI
        var basis := Basis(Vector3.UP, angle).scaled(Vector3.ONE * rng.randf_range(0.88, 1.08))
        multimesh.set_instance_transform(i, Transform3D(basis, Vector3(x + rng.randf_range(-0.12, 0.12), 0.0, z + rng.randf_range(-0.12, 0.12))))
        multimesh.set_instance_color(i, color.lightened(rng.randf_range(-0.08, 0.12)))

    instance.multimesh = multimesh
    var material := StandardMaterial3D.new()
    material.albedo_color = Color.WHITE
    material.vertex_color_use_as_albedo = true
    material.roughness = 0.88
    instance.material_override = material
    return instance

func _make_soldier_mesh() -> Mesh:
    var surface := SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)

    var torso := CapsuleMesh.new()
    torso.radius = 0.22
    torso.height = 0.92
    torso.radial_segments = 8
    torso.rings = 4
    _append_part(surface, torso, Vector3(0, 1.05, 0), Vector3(0.88, 1.0, 0.58), Vector3.ZERO)

    var head := SphereMesh.new()
    head.radius = 0.17
    head.height = 0.34
    _append_part(surface, head, Vector3(0, 1.72, 0.015), Vector3.ONE, Vector3.ZERO)

    var helmet := SphereMesh.new()
    helmet.radius = 0.19
    helmet.height = 0.19
    _append_part(surface, helmet, Vector3(0, 1.84, 0.015), Vector3(1.0, 0.58, 1.0), Vector3.ZERO)

    var backpack := BoxMesh.new()
    backpack.size = Vector3(0.28, 0.40, 0.18)
    _append_part(surface, backpack, Vector3(0, 1.10, -0.22), Vector3.ONE, Vector3.ZERO)

    var limb := CapsuleMesh.new()
    limb.radius = 0.075
    limb.height = 0.62
    limb.radial_segments = 6
    _append_part(surface, limb, Vector3(-0.25, 1.10, 0.0), Vector3.ONE, Vector3(0, 0, -0.22))
    _append_part(surface, limb, Vector3(0.25, 1.10, 0.0), Vector3.ONE, Vector3(0, 0, 0.22))
    _append_part(surface, limb, Vector3(-0.12, 0.38, 0.0), Vector3(0.92, 1.1, 0.92), Vector3(0, 0, -0.08))
    _append_part(surface, limb, Vector3(0.12, 0.38, 0.0), Vector3(0.92, 1.1, 0.92), Vector3(0, 0, 0.08))

    var rifle := BoxMesh.new()
    rifle.size = Vector3(0.09, 0.10, 0.76)
    _append_part(surface, rifle, Vector3(0.19, 1.22, 0.36), Vector3.ONE, Vector3(-0.12, 0, 0))
    var barrel := CylinderMesh.new()
    barrel.top_radius = 0.025
    barrel.bottom_radius = 0.025
    barrel.height = 0.34
    _append_part(surface, barrel, Vector3(0.19, 1.23, 0.86), Vector3.ONE, Vector3(PI * 0.5, 0, 0))

    surface.generate_normals()
    return surface.commit()

func _start_battle() -> void:
    if battle_running:
        battle_running = false
        start_button.text = "RESUME BATTLE"
        return
    if team_a_alive <= 0 or team_b_alive <= 0:
        _reset_battle()
    else:
        team_a_count = clampi(int(a_spin.value), 1, MAX_UNITS)
        team_b_count = clampi(int(b_spin.value), 1, MAX_UNITS)
        if battle_time == 0.0:
            team_a_alive = team_a_count
            team_b_alive = team_b_count
            _apply_visible_counts()
    battle_running = true
    start_button.text = "PAUSE BATTLE"
    _refresh_ui()

func _reset_battle() -> void:
    battle_running = false
    battle_time = 0.0
    team_a_count = clampi(int(a_spin.value), 1, MAX_UNITS)
    team_b_count = clampi(int(b_spin.value), 1, MAX_UNITS)
    team_a_alive = team_a_count
    team_b_alive = team_b_count
    start_button.text = "START BATTLE"
    _apply_visible_counts()
    _refresh_ui()

func _apply_visible_counts() -> void:
    team_a_mesh.multimesh.visible_instance_count = team_a_alive
    team_b_mesh.multimesh.visible_instance_count = team_b_alive

func _process(delta: float) -> void:
    if not battle_running:
        return
    battle_time += delta * battle_speed
    var a_power := sqrt(float(team_a_alive)) * 2.0
    var b_power := sqrt(float(team_b_alive)) * 2.0
    var damage_to_a := maxf(1.0, b_power * delta * battle_speed * 0.8)
    var damage_to_b := maxf(1.0, a_power * delta * battle_speed * 0.8)
    team_a_alive = maxi(0, team_a_alive - int(damage_to_a))
    team_b_alive = maxi(0, team_b_alive - int(damage_to_b))
    _apply_visible_counts()
    ui_refresh_timer += delta
    if ui_refresh_timer >= 0.15:
        ui_refresh_timer = 0.0
        _refresh_ui()
    if team_a_alive == 0 or team_b_alive == 0:
        battle_running = false
        start_button.text = "BATTLE FINISHED — RESET"
        status_label.text = _winner_text()

func _winner_text() -> String:
    if team_a_alive > team_b_alive:
        return "BLUE TEAM WINS!  •  %d survivors" % team_a_alive
    if team_b_alive > team_a_alive:
        return "RED TEAM WINS!  •  %d survivors" % team_b_alive
    return "DRAW — BOTH ARMIES ELIMINATED"

func _refresh_ui() -> void:
    if status_label == null:
        return
    if not battle_running and (team_a_alive == 0 or team_b_alive == 0):
        status_label.text = _winner_text()
    else:
        status_label.text = "BLUE: %d / %d     RED: %d / %d\nTime: %.1fs" % [
            team_a_alive, team_a_count, team_b_alive, team_b_count, battle_time
        ]
