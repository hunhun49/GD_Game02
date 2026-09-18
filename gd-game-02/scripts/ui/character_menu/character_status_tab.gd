class_name CharacterStatusTab
extends HBoxContainer

var _identity: VBoxContainer
var _stats: VBoxContainer

func _ready() -> void:
	add_theme_constant_override("separation", 28)
	_identity = CharacterMenuStyle.column(16)
	_identity.custom_minimum_size.x = 260
	add_child(_identity)
	_stats = CharacterMenuStyle.column(12)
	_stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_stats)

func present(data: Dictionary) -> void:
	CharacterMenuStyle.clear(_identity)
	CharacterMenuStyle.clear(_stats)
	_identity.add_child(CharacterMenuStyle.label("HAESOL HIGH SCHOOL", 14, CharacterMenuStyle.ACCENT))
	_identity.add_child(CharacterMenuStyle.label(data.get("name", "학생"), 38))
	_identity.add_child(CharacterMenuStyle.label("학생  /  " + data.get("location", "학교"), 17, CharacterMenuStyle.MUTED))
	var portrait := PanelContainer.new()
	portrait.custom_minimum_size = Vector2(230, 165)
	portrait.add_theme_stylebox_override("panel", CharacterMenuStyle.box(Color("2d4950"), 8))
	var symbol := CharacterMenuStyle.label("학생 기록", 30, CharacterMenuStyle.ACCENT)
	symbol.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	portrait.add_child(symbol)
	_identity.add_child(portrait)
	_identity.add_child(CharacterMenuStyle.label(data.get("clock", ""), 20))
	_identity.add_child(CharacterMenuStyle.label("지금의 몸 상태와 전투 능력을\n확인할 수 있습니다.", 15, CharacterMenuStyle.MUTED))
	_stats.add_child(CharacterMenuStyle.label("컨디션", 24))
	for stat in data.get("stats", []):
		var row := HBoxContainer.new()
		var name_label := CharacterMenuStyle.label(stat.name, 17)
		name_label.custom_minimum_size.x = 90
		row.add_child(name_label)
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(160, 20)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.max_value = stat.maximum
		bar.value = stat.value
		bar.show_percentage = false
		bar.add_theme_stylebox_override("background", CharacterMenuStyle.box(Color("263a44"), 5, Color.TRANSPARENT, 0))
		bar.add_theme_stylebox_override("fill", CharacterMenuStyle.box(Color("d6ae77") if stat.get("need", false) else CharacterMenuStyle.ACCENT, 5, Color.TRANSPARENT, 0))
		row.add_child(bar)
		var value := CharacterMenuStyle.label("%.0f / %.0f" % [stat.value, stat.maximum], 16)
		value.custom_minimum_size.x = 100
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(value)
		_stats.add_child(row)
	_stats.add_child(CharacterMenuStyle.label("허기·갈증·피로와 체간은 낮을수록 좋습니다.", 14, CharacterMenuStyle.MUTED))
	_stats.add_child(CharacterMenuStyle.label("상태 효과", 21))
	var effects := CharacterMenuStyle.label(data.get("effects", "정상 · 적용 중인 효과가 없습니다."), 16, CharacterMenuStyle.ACCENT)
	effects.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stats.add_child(effects)
