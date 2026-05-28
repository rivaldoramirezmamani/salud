extends Node

signal transducer_changed(type: int)

var transducers: Dictionary = {}
var current_type: int = -1
var current_transducer_resource: TransducerResource = null

func _ready():
	load_all_transducers()
	select_transducer(TransducerResource.TransducerType.CONVEXO)

func load_all_transducers():
	var paths = {
		TransducerResource.TransducerType.CONVEXO: "res://resources/transducers/convexo.tres",
		TransducerResource.TransducerType.LINEAL: "res://resources/transducers/lineal.tres",
		TransducerResource.TransducerType.SECTORIAL: "res://resources/transducers/sectorial.tres"
	}
	for type in paths:
		var res = load(paths[type])
		if res:
			transducers[type] = res
			print("TransducerController: loaded ", res.transducer_name, " for type ", type)
		else:
			print("TransducerController: failed to load resource at ", paths[type])

func select_transducer(type: int):
	if type == current_type:
		print("TransducerController: select_transducer called with same type", type)
		return
	if not transducers.has(type):
		print("TransducerController: select_transducer - type not found:", type)
		return
	current_type = type
	current_transducer_resource = transducers[type]
	print("TransducerController: selected ", current_transducer_resource.transducer_name)
	transducer_changed.emit(type)

func get_current() -> TransducerResource:
	return current_transducer_resource

func get_transducer(type: int) -> TransducerResource:
	return transducers.get(type)
