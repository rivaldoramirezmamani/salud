extends Resource
class_name TransducerResource

enum FieldShape { ARC, RECTANGLE, FAN }
enum TransducerType { CONVEXO = 0, LINEAL = 1, SECTORIAL = 2 }

@export var transducer_name: String = "Convexo"
@export var transducer_type: TransducerType = TransducerType.CONVEXO
@export var field_shape: FieldShape = FieldShape.ARC
@export var frequency: float = 3.5
@export var num_rays: int = 96
@export var max_depth: float = 0.25
@export var field_angle: float = 60.0
@export var face_width: float = 0.04
@export var arc_radius: float = 0.01
