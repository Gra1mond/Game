extends SceneTree

func _initialize() -> void:
	var selected := ""
	var args := OS.get_cmdline_user_args()
	for i in range(args.size()):
		if args[i] == "--case" and i + 1 < args.size():
			selected = args[i + 1]
	var executed := 0
	var failures := 0
	var paths := DirAccess.get_files_at("res://tests/cases")
	for filename in paths:
		if not filename.ends_with(".gd") or (not selected.is_empty() and filename != "test_%s.gd" % selected):
			continue
		var script: Script = load("res://tests/cases/" + filename)
		if script == null or not script.can_instantiate():
			printerr("Cannot load ", filename)
			quit(1)
			return
		var suite: RefCounted = script.new()
		for method in suite.get_method_list():
			if not str(method.name).begins_with("test_"):
				continue
			executed += 1
			var errors: Array = suite.call(method.name)
			if errors.is_empty():
				print("PASS ", filename, " :: ", method.name)
			else:
				failures += 1
				printerr("FAIL ", filename, " :: ", method.name, " ", errors)
	print("RESULT: %d tests, %d failed" % [executed, failures])
	quit(1 if failures > 0 or executed == 0 else 0)
