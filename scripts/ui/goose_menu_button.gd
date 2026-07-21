class_name GooseMenuButton
extends Button

@export var label_text := "Button":
	set(value):
		label_text = value
		text = value

@export var button_icon: Texture2D:
	set(value):
		button_icon = value
		icon = value


func _ready() -> void:
	text = label_text
	icon = button_icon
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	flat = true
