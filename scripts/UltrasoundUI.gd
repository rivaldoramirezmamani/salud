extends CanvasLayer

class_name UltrasoundUI

@onready var panel: Panel = $Panel
@onready var image_display: SubViewportContainer = $Panel/VBox/ImageContainer
@onready var viewport: UltrasoundImage = $Panel/VBox/ImageContainer/UltrasoundImage
@onready var gain_slider: HSlider = $Panel/VBox/Controls/GainSlider
@onready var depth_slider: HSlider = $Panel/VBox/Controls/DepthSlider
@onready var freeze_btn: Button = $Panel/VBox/Controls/FreezeBtn
@onready var convexo_btn: Button = $Panel/VBox/Controls/TransducerButtons/ConvexoBtn
@onready var lineal_btn: Button = $Panel/VBox/Controls/TransducerButtons/LinealBtn
@onready var sectorial_btn: Button = $Panel/VBox/Controls/TransducerButtons/SectorialBtn
@onready var transducer_label: Label = $Panel/VBox/Controls/TransducerLabel
@onready var freq_label: Label = $Panel/VBox/Controls/FreqLabel
@onready var use_label: Label = $Panel/VBox/Controls/UseLabel
@onready var badge_label: Label = $Panel/VBox/Controls/BadgeLabel
@onready var depth_label: Label = $Panel/VBox/Controls/DepthLabel
@onready var gain_label: Label = $Panel/VBox/Controls/GainLabel
var raycaster: UltrasoundRaycaster = null

func _ready():
	convexo_btn.toggled.connect(_on_convexo)
	lineal_btn.toggled.connect(_on_lineal)
	sectorial_btn.toggled.connect(_on_sectorial)
	gain_slider.value_changed.connect(_on_gain)
	depth_slider.value_changed.connect(_on_depth)
	freeze_btn.pressed.connect(_on_freeze)
	TransducerController.transducer_changed.connect(_on_transducer_changed)
	_on_transducer_changed(TransducerController.current_type)

func _on_transducer_changed(_type: int):
	print("UltrasoundUI: transducer_changed ->", _type)
	var res = TransducerController.current_transducer_resource
	if res:
		transducer_label.text = res.transducer_name.to_upper()
		viewport.set_transducer_type(res.transducer_type)
		viewport.setup_image(res)
		depth_slider.value = res.max_depth
		_on_depth(res.max_depth)
		if raycaster:
			raycaster.configure(res)
		update_buttons()
		var transducer_info = {
			TransducerResource.TransducerType.CONVEXO: { "freq": "3.5-5 MHz  B A J A   F R E C U E N C I A", "use": "CORAZON  CEREBRO  INTERCOSTAL", "badge": "POCUS CARDIACO" },
			TransducerResource.TransducerType.LINEAL: { "freq": "5-10 MHz  A L T A   F R E C U E N C I A", "use": "MUSCULO  TEJIDOS BLANDOS  VASCULAR", "badge": "POCUS VASCULAR" },
			TransducerResource.TransducerType.SECTORIAL: { "freq": "2-5 MHz  B A J A   F R E C U E N C I A", "use": "ABDOMEN  PELVIS  OBSTETRICIA", "badge": "POCUS ABDOMINAL" }
		}
		var info = transducer_info.get(res.transducer_type, transducer_info[TransducerResource.TransducerType.CONVEXO])
		freq_label.text = info.freq
		use_label.text = info.use
		badge_label.text = info.badge

func update_buttons():
	var t = TransducerController.current_type
	convexo_btn.set_pressed_no_signal(t == TransducerResource.TransducerType.CONVEXO)
	lineal_btn.set_pressed_no_signal(t == TransducerResource.TransducerType.LINEAL)
	sectorial_btn.set_pressed_no_signal(t == TransducerResource.TransducerType.SECTORIAL)

func _on_convexo(toggled_on: bool):
	if toggled_on:
		print("UI: Convexo toggled on")
		TransducerController.select_transducer(TransducerResource.TransducerType.CONVEXO)

func _on_lineal(toggled_on: bool):
	if toggled_on:
		print("UI: Lineal toggled on")
		TransducerController.select_transducer(TransducerResource.TransducerType.LINEAL)

func _on_sectorial(toggled_on: bool):
	if toggled_on:
		print("UI: Sectorial toggled on")
		TransducerController.select_transducer(TransducerResource.TransducerType.SECTORIAL)

func _on_gain(val: float):
	viewport.set_gain(val)
	gain_label.text = "GANANCIA: %d%%" % int(val * 100)

func _on_depth(val: float):
	var depth_cm = val * 100.0
	depth_label.text = "PROF: %.1f cm" % depth_cm
	viewport.set_depth(val)

func _on_freeze():
	if raycaster:
		raycaster.toggle_freeze()
		var frozen = raycaster.freeze
		freeze_btn.text = "REANUDAR" if frozen else "CONGELAR"
		gain_slider.editable = not frozen
		depth_slider.editable = not frozen
		convexo_btn.disabled = frozen
		lineal_btn.disabled = frozen
		sectorial_btn.disabled = frozen
