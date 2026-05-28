extends SubViewport

class_name UltrasoundImage

var raw_image: Image
var raw_texture: ImageTexture
var raycaster: UltrasoundRaycaster = null
var display_rect: ColorRect = null
var bg_textures: Dictionary = {}

func _ready():
	display_rect = $ColorRect
	_load_bg_textures()
	var res = TransducerController.current_transducer_resource
	if res:
		setup_image(res)

func _load_bg_textures():
	bg_textures[TransducerResource.TransducerType.CONVEXO] = load("res://f_convexo.svg")
	bg_textures[TransducerResource.TransducerType.LINEAL] = load("res://f_lineal.svg")
	bg_textures[TransducerResource.TransducerType.SECTORIAL] = load("res://f_sectorial.svg")

func get_shader_mat() -> ShaderMaterial:
	if display_rect and display_rect.material is ShaderMaterial:
		return display_rect.material as ShaderMaterial
	return null

func setup_image(res: TransducerResource):
	var w = res.num_rays
	var h = 400
	raw_image = Image.create(w, h, false, Image.FORMAT_R8)
	raw_image.fill(Color(0, 0, 0, 1))
	raw_texture = ImageTexture.create_from_image(raw_image)
	var mat = get_shader_mat()
	if mat:
		mat.set_shader_parameter("raw_data", raw_texture)
		mat.set_shader_parameter("depth_m", res.max_depth)
		mat.set_shader_parameter("transducer_type", res.transducer_type)
	set_bg_for_type(res.transducer_type)

func update_image(data: PackedFloat32Array, res: TransducerResource):
	if raw_image == null or data.is_empty():
		return
	var w = res.num_rays
	var h = 400
	if w <= 0 or h <= 0:
		return
	var expected = w * h
	if data.size() < expected:
		return
	for y in h:
		for x in w:
			var idx = x * h + y
			var val = data[idx] if idx < data.size() else 0.0
			raw_image.set_pixel(x, y, Color(val, 0, 0, 1))
	raw_texture.update(raw_image)

func set_gain(val: float):
	var mat = get_shader_mat()
	if mat:
		mat.set_shader_parameter("gain", val)

func set_depth(val: float):
	var mat = get_shader_mat()
	if mat:
		mat.set_shader_parameter("depth_m", val)

func set_transducer_type(t: int):
	var mat = get_shader_mat()
	if mat:
		mat.set_shader_parameter("transducer_type", t)
	set_bg_for_type(t)

func set_bg_for_type(t: int):
	var mat = get_shader_mat()
	if mat and bg_textures.has(t):
		mat.set_shader_parameter("bg_image", bg_textures[t])

func _process(_delta):
	var mat = get_shader_mat()
	if mat:
		mat.set_shader_parameter("time", Time.get_ticks_msec() / 1000.0)
	if raycaster and raycaster.active:
		var res = TransducerController.current_transducer_resource
		if res:
			update_image(raycaster.get_display_data(), res)
