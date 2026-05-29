extends Node3D

var raycaster: UltrasoundRaycaster = null
var transducer_nodes: Dictionary = {}
var wave_meshes: Dictionary = {}
var ui: UltrasoundUI = null
var active_node: Node3D = null
var transducer_speed: float = 1.5
var _positioned: bool = false

var _anim_descending: bool = false
var _anim_pending: bool = false
var _anim_elapsed: float = 0.0
var _anim_duration: float = 2.0
const MANNEQUIN_Y: float = 0.2
const TRANSDUCER_HOVER_Y: float = 2.2
const TRANSDUCER_SURFACE_Y: float = 1.5

var cam_target: Vector3 = Vector3(3.68, 1.0, 1.6)
var cam_dist: float = 6.0
var cam_rot_x: float = 0.6
var cam_rot_y: float = 0.15

@onready var objetos = $objetos
@onready var cam = $Camera3D

func _ready():
	if not objetos:
		print("Main: 'objetos' node not found")
		return
	if DisplayServer.window_get_size().x < 100:
		DisplayServer.window_set_size(Vector2i(1280, 720))
		DisplayServer.window_set_position(Vector2i(
			(DisplayServer.screen_get_size().x - 1280) / 2,
			(DisplayServer.screen_get_size().y - 720) / 2
		))
	var mannequin = objetos.find_child("M_echado", true, false)
	if mannequin:
		var t = mannequin.transform
		t.origin = Vector3(3.68, 0.2, 1.6)
		mannequin.transform = t
		_set_skin_color(mannequin)
	else:
		print("Main: M_echado not found")
	setup_phantom_regions()
	setup_transducers()
	setup_ui()
	activate_transducer(TransducerController.current_type)
	TransducerController.transducer_changed.connect(activate_transducer)
	position_transducers_near_mannequin()

func _set_skin_color(node: Node3D):
	var skin_mat = StandardMaterial3D.new()
	skin_mat.albedo_color = Color(0.94, 0.78, 0.62)
	skin_mat.roughness = 0.7
	for mesh in node.find_children("*", "MeshInstance3D", true, false):
		mesh.material_override = skin_mat

func setup_phantom_regions():
	if not objetos:
		print("Main: 'objetos' node not found")
		return
	var mannequin = objetos.get_node_or_null("M_echado")
	if not mannequin:
		return
	var skin = preload("res://resources/acoustic/skin.tres")
	var fat = preload("res://resources/acoustic/fat.tres")
	var muscle = preload("res://resources/acoustic/muscle.tres")
	var liver = preload("res://resources/acoustic/liver.tres")
	var bone = preload("res://resources/acoustic/bone.tres")
	var vessel = preload("res://resources/acoustic/vessel.tres")
	var air = preload("res://resources/acoustic/air.tres")

	var body_y = 0.05
	var abdomen = PhantomRegion.new()
	abdomen.name = "RegionAbdomen"
	abdomen.region_type = PhantomRegion.Region.ABDOMEN
	abdomen.organs = [skin, fat, muscle, liver, vessel, fat]
	var abd_collision = CollisionShape3D.new()
	var abd_shape = BoxShape3D.new()
	abd_shape.size = Vector3(0.28, 0.15, 0.18)
	abd_collision.shape = abd_shape
	abd_collision.transform.origin = Vector3(0, body_y, 0.1)
	abdomen.add_child(abd_collision)
	mannequin.add_child(abdomen)
	abdomen.owner = self

	var torax = PhantomRegion.new()
	torax.name = "RegionTorax"
	torax.region_type = PhantomRegion.Region.THORAX
	torax.organs = [skin, muscle, bone, air, muscle]
	var tor_collision = CollisionShape3D.new()
	var tor_shape = BoxShape3D.new()
	tor_shape.size = Vector3(0.24, 0.18, 0.2)
	tor_collision.shape = tor_shape
	tor_collision.transform.origin = Vector3(0, body_y, 0.4)
	torax.add_child(tor_collision)
	mannequin.add_child(torax)
	torax.owner = self

	var cabeza = PhantomRegion.new()
	cabeza.name = "RegionCabeza"
	cabeza.region_type = PhantomRegion.Region.THORAX
	cabeza.organs = [skin, bone, air]
	var cab_collision = CollisionShape3D.new()
	var cab_shape = BoxShape3D.new()
	cab_shape.size = Vector3(0.16, 0.18, 0.16)
	cab_collision.shape = cab_shape
	cab_collision.transform.origin = Vector3(0, body_y + 0.02, 0.85)
	cabeza.add_child(cab_collision)
	mannequin.add_child(cabeza)
	cabeza.owner = self

	var pelvis = PhantomRegion.new()
	pelvis.name = "RegionPelvis"
	pelvis.region_type = PhantomRegion.Region.PELVIS
	pelvis.organs = [skin, fat, muscle, vessel, bone]
	var pel_collision = CollisionShape3D.new()
	var pel_shape = BoxShape3D.new()
	pel_shape.size = Vector3(0.22, 0.16, 0.16)
	pel_collision.shape = pel_shape
	pel_collision.transform.origin = Vector3(0, body_y, -0.2)
	pelvis.add_child(pel_collision)
	mannequin.add_child(pelvis)
	pelvis.owner = self

	var piernas = PhantomRegion.new()
	piernas.name = "RegionPiernas"
	piernas.region_type = PhantomRegion.Region.PELVIS
	piernas.organs = [skin, muscle, bone]
	var pie_collision = CollisionShape3D.new()
	var pie_shape = BoxShape3D.new()
	pie_shape.size = Vector3(0.16, 0.18, 0.35)
	pie_collision.shape = pie_shape
	pie_collision.transform.origin = Vector3(0, body_y, -0.7)
	piernas.add_child(pie_collision)
	mannequin.add_child(piernas)
	piernas.owner = self

func setup_transducers():
	var type_names = {
		TransducerResource.TransducerType.CONVEXO: "convexo",
		TransducerResource.TransducerType.LINEAL: "lineal",
		TransducerResource.TransducerType.SECTORIAL: "sectorial"
	}
	var wave_shader = preload("res://shaders/ultrasound_waves.gdshader")
	for type in type_names:
		var node = objetos.get_node_or_null(type_names[type])
		if node:
			var rc = UltrasoundRaycaster.new()
			rc.name = "Raycaster"
			rc.configure(TransducerController.get_transducer(type))
			node.add_child(rc)
			rc.owner = self
			transducer_nodes[type] = rc
			rc.set_active(false)
			rc.space_state = get_world_3d().direct_space_state

			var wave = MeshInstance3D.new()
			wave.name = "WaveEffect"
			var quad = QuadMesh.new()
			quad.size = Vector2(1.4, 2.0)
			wave.mesh = quad
			wave.visible = false
			var mat = ShaderMaterial.new()
			mat.shader = wave_shader
			mat.set_shader_parameter("transducer_type", type)
			mat.set_shader_parameter("wave_speed", 1.5)
			var wave_count = 14.0
			if type == TransducerResource.TransducerType.LINEAL:
				wave_count = 16.0
			mat.set_shader_parameter("wave_count", wave_count)
			mat.set_shader_parameter("brightness", 1.2)
			wave.material_override = mat
			objetos.add_child(wave)
			wave.owner = self
			wave_meshes[type] = wave

func setup_ui():
	var ui_scene = preload("res://scenes/ultrasound_ui.tscn")
	var ui_instance = ui_scene.instantiate() as UltrasoundUI
	add_child(ui_instance)
	ui_instance.owner = self
	ui = ui_instance

func activate_transducer(type: int):
	for t in transducer_nodes:
		var rc = transducer_nodes[t] as UltrasoundRaycaster
		if rc:
			rc.set_active(t == type)
			if t == type:
				raycaster = rc
				var res = TransducerController.get_transducer(t)
				if res:
					rc.configure(res)
	var transducer_names = {
		TransducerResource.TransducerType.CONVEXO: "convexo",
		TransducerResource.TransducerType.LINEAL: "lineal",
		TransducerResource.TransducerType.SECTORIAL: "sectorial"
	}
	active_node = null
	for t_name in transducer_names.values():
		var n = objetos.get_node_or_null(t_name)
		if n:
			n.visible = (t_name == transducer_names[type])
			if t_name == transducer_names[type]:
				active_node = n
	for t in wave_meshes:
		var w = wave_meshes[t] as MeshInstance3D
		if w:
			w.visible = (t == type)
	var combined = objetos.get_node_or_null("traductores")
	if combined:
		combined.visible = false
	var m_echado = objetos.get_node_or_null("M_echado")
	if m_echado:
		m_echado.visible = true
	var m_parado = objetos.get_node_or_null("M_parado")
	if m_parado:
		m_parado.visible = false
	if ui:
		ui.raycaster = raycaster
		if ui.viewport:
			ui.viewport.raycaster = raycaster
		ui.update_buttons()
	_anim_pending = true
	if active_node:
		active_node.position.y = TRANSDUCER_HOVER_Y
		var w = wave_meshes.get(type)
		if w:
			w.scale = Vector3(1, 1, 1)
			var transducer_y = active_node.global_position.y
			var wave_y = (transducer_y + MANNEQUIN_Y) * 0.5
			w.global_position = Vector3(active_node.global_position.x, wave_y, active_node.global_position.z)

func _start_descent():
	if not active_node:
		return
	_anim_descending = true
	_anim_pending = false
	_anim_elapsed = 0.0

func _update_descent(delta):
	if not active_node:
		_anim_descending = false
		return
	_anim_elapsed += delta
	var t = clamp(_anim_elapsed / _anim_duration, 0.0, 1.0)
	active_node.position.y = lerp(TRANSDUCER_HOVER_Y, TRANSDUCER_SURFACE_Y, t)
	var w = wave_meshes.get(TransducerController.current_type)
	if w:
		var transducer_y = active_node.global_position.y
		var mid_y = (transducer_y + MANNEQUIN_Y) * 0.5
		var wave_y = lerp(mid_y, transducer_y, t)
		w.global_position = Vector3(active_node.global_position.x, wave_y, active_node.global_position.z)
		var s = lerp(1.0, 0.03, t)
		w.scale = Vector3(s, s, s)
	if t >= 1.0:
		_anim_descending = false

func position_transducers_near_mannequin():
	var transducer_names = ["convexo", "lineal", "sectorial"]
	var mannequin = objetos.find_child("M_echado", true, false)
	var base_pos = Vector3(3.68, 0.2, 1.6)
	if mannequin:
		var t = mannequin.transform
		t.origin = Vector3(3.68, 0.2, 1.6)
		mannequin.transform = t
		base_pos = Vector3(3.68, 0.2, 1.6)
	var y_offset = 2.0
	var center_pos = Vector3(base_pos.x, base_pos.y + y_offset, base_pos.z)
	for name in transducer_names:
		var node = objetos.find_child(name, true, false)
		if node:
			var nt = node.transform
			nt.origin = center_pos
			node.transform = nt

	var transducer_y = center_pos.y
	var mannequin_y = base_pos.y
	var wave_y = (transducer_y + mannequin_y) * 0.5
	for type in wave_meshes:
		var w = wave_meshes[type] as MeshInstance3D
		if w:
			w.global_position = Vector3(base_pos.x, wave_y, base_pos.z)

func _process(delta):
	if not _positioned:
		_positioned = true
		var m = objetos.find_child("M_echado", true, false)
		if m:
			var t = m.transform
			t.origin = Vector3(3.68, 0.2, 1.6)
			m.transform = t
		position_transducers_near_mannequin()
	if _anim_pending:
		_start_descent()
	update_camera()
	if _anim_descending:
		_update_descent(delta)
	move_transducer(delta)
	billboard_waves()

func billboard_waves():
	for type in wave_meshes:
		var w = wave_meshes[type] as MeshInstance3D
		if w and w.visible:
			w.look_at(cam.global_position, Vector3.UP)

func update_camera():
	var x = cam_dist * cos(cam_rot_y) * sin(cam_rot_x)
	var y = cam_dist * sin(cam_rot_y)
	var z = cam_dist * cos(cam_rot_y) * cos(cam_rot_x)
	cam.position = cam_target + Vector3(x, y, z)
	cam.look_at(cam_target)

func move_transducer(delta):
	if not active_node:
		return
	var move = Vector3.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		move.z -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		move.z += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		move.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		move.x += 1
	if Input.is_key_pressed(KEY_SPACE):
		move.y += 1
	if Input.is_key_pressed(KEY_SHIFT):
		move.y -= 1
	if move.length() > 0:
		active_node.position += move.normalized() * transducer_speed * delta
		var w = wave_meshes.get(TransducerController.current_type)
		if w:
			var transducer_y = active_node.global_position.y
			var mannequin_y = 0.2
			var wave_y = (transducer_y + mannequin_y) * 0.5
			w.global_position = Vector3(active_node.global_position.x, wave_y, active_node.global_position.z)
	if Input.is_key_pressed(KEY_Q):
		active_node.rotate_y(transducer_speed * delta)
	if Input.is_key_pressed(KEY_E):
		active_node.rotate_y(-transducer_speed * delta)

func _input(event):
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		cam_rot_x -= event.relative.x * 0.005
		cam_rot_y -= event.relative.y * 0.005
		cam_rot_y = clamp(cam_rot_y, -1.4, 1.4)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			cam_dist = max(1.0, cam_dist - 0.3)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			cam_dist += 0.3
