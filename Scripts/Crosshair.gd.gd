extends Control

@export var Size: int = 8		  # half-length of each arm in px
@export var gap: int = 3		   # gap from center
@export var thickness: int = 2
@export var color: Color = Color.WHITE

func _ready() -> void:
	# center and ignore resizing hassles
	anchor_left = 0.5; anchor_top = 0.5
	anchor_right = 0.5; anchor_bottom = 0.5
	pivot_offset = Vector2.ZERO
	offset_left = 0; offset_top = 0; offset_right = 0; offset_bottom = 0
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var c := Vector2.ZERO
	# horizontal
	draw_line(c + Vector2(gap, 0),	   c + Vector2(gap + Size, 0),	   color, thickness)
	draw_line(c + Vector2(-gap, 0),	  c + Vector2(-(gap + Size), 0),	color, thickness)
	# vertical
	draw_line(c + Vector2(0, gap),	   c + Vector2(0, gap + Size),	   color, thickness)
	draw_line(c + Vector2(0, -gap),	  c + Vector2(0, -(gap + Size)),	color, thickness)
