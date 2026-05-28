extends Area3D

class_name PhantomRegion

enum Region { ABDOMEN, THORAX, PELVIS }

@export var region_type: Region = Region.ABDOMEN
@export var organs: Array = []

func get_random_tissue_profile() -> Array[AcousticProperties]:
	if organs.is_empty():
		return []
	var profile: Array[AcousticProperties] = []
	for organ in organs:
		if organ is AcousticProperties:
			profile.append(organ as AcousticProperties)
	return profile
