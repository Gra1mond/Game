extends Control

var paused: bool = false
var status: Label

func _ready() -> void:
	var layout := VBoxContainer.new()
	layout.position = Vector2(40, 40)
	add_child(layout)
	status = Label.new()
	status.text = "Маяки в тумане — берег ждёт"
	layout.add_child(status)
	var pause_button := Button.new()
	pause_button.text = "Пауза / продолжить [Пробел]"
	pause_button.pressed.connect(_toggle_pause)
	layout.add_child(pause_button)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		_toggle_pause()

func _toggle_pause() -> void:
	paused = not paused
	status.text = "Пауза" if paused else "Маяки в тумане — берег ждёт"
