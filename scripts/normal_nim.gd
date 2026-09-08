extends Control

# Matchstick Nim — normal play.
# Remove one or more matches from one row. Taking the final match WINS.

const TABLE := Color("#241813")
const PAPER := Color("#f3ead6")
const PAPER_2 := Color("#e8dcc3")
const INK := Color("#29231f")
const MUTED := Color("#74685d")
const RED := Color("#8f3029")
const RED_DARK := Color("#68211d")
const GREEN := Color("#486f52")
const COMPUTER_MATCH_DELAY := 0.5
const ROW_COUNT := 4
const MIN_MATCHES := 1
const MAX_MATCHES := 7

enum Phase { PLAYER, COMPUTER, GAME_OVER }

class MatchstickButton:
    extends Button
    var row_index := 0

    func _init() -> void:
        flat = true
        custom_minimum_size = Vector2(32, 62)
        focus_mode = Control.FOCUS_NONE
        mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
        add_theme_stylebox_override("focus", StyleBoxEmpty.new())

    func _draw() -> void:
        var cx := size.x * 0.5
        var opacity := 1.0 if not disabled else 0.34
        var shaft_top := 18.0
        var shaft_height := maxf(28.0, size.y - 22.0)
        draw_rect(Rect2(cx - 2.0, shaft_top + 2.0, 6.0, shaft_height), Color(0.16, 0.10, 0.06, 0.14 * opacity), true)
        draw_rect(Rect2(cx - 3.0, shaft_top, 6.0, shaft_height), Color(0.69, 0.50, 0.27, opacity), true)
        draw_rect(Rect2(cx - 1.2, shaft_top, 2.4, shaft_height), Color(0.91, 0.75, 0.46, opacity), true)
        draw_circle(Vector2(cx, 12.5), 6.8, Color(0.40, 0.11, 0.09, opacity))
        draw_circle(Vector2(cx - 0.8, 11.8), 5.2, Color(0.58, 0.18, 0.15, opacity))
        if not disabled and is_hovered():
            draw_arc(Vector2(cx, 12.5), 9.7, 0.0, TAU, 24, Color(0.55, 0.19, 0.16, 0.75), 2.0)

    func set_turn_enabled(value: bool) -> void:
        disabled = not value
        mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if value else Control.CURSOR_ARROW
        queue_redraw()


var rng := RandomNumberGenerator.new()
var phase: Phase = Phase.PLAYER
var piles: Array[int] = [1, 3, 5, 7]
var turn_start_piles: Array[int] = []
var selected_row := -1
var removed_this_turn := 0
var game_serial := 0

var start_option: OptionButton
var status_label: Label
var substatus_label: Label
var remaining_label: Label
var setup_label: Label
var rows_box: VBoxContainer
var match_rows: Array[HBoxContainer] = []
var count_labels: Array[Label] = []
var message_label: Label
var action_button: Button
var undo_button: Button

var match_sound_player: AudioStreamPlayer
var result_sound_player: AudioStreamPlayer
var match_sound: AudioStreamWAV
var win_sound: AudioStreamWAV
var lose_sound: AudioStreamWAV

var result_overlay: Control
var result_panel: PanelContainer
var result_title: Label
var result_subtitle: Label


func _ready() -> void:
    rng.randomize()
    _build_ui()
    _build_audio()
    _build_result_overlay()
    _start_new_game()


func _build_ui() -> void:
    var bg := ColorRect.new()
    bg.color = TABLE
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(bg)

    var outer := MarginContainer.new()
    outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    outer.add_theme_constant_override("margin_left", 12)
    outer.add_theme_constant_override("margin_right", 12)
    outer.add_theme_constant_override("margin_top", 7)
    outer.add_theme_constant_override("margin_bottom", 7)
    add_child(outer)

    var main := VBoxContainer.new()
    main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    main.size_flags_vertical = Control.SIZE_EXPAND_FILL
    main.add_theme_constant_override("separation", 4)
    outer.add_child(main)

    var header := HBoxContainer.new()
    header.custom_minimum_size.y = 42
    header.add_theme_constant_override("separation", 10)
    main.add_child(header)

    var title_box := VBoxContainer.new()
    title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(title_box)
    var title := Label.new()
    title.text = "THE GAME OF NIM"
    title.add_theme_color_override("font_color", PAPER)
    title.add_theme_font_size_override("font_size", 24)
    title_box.add_child(title)
    var subtitle := Label.new()
    subtitle.text = "Matchstick edition  •  4 random rows  •  Last match wins"
    subtitle.add_theme_color_override("font_color", Color("#cfbea9"))
    subtitle.add_theme_font_size_override("font_size", 11)
    title_box.add_child(subtitle)

    var controls := HBoxContainer.new()
    controls.alignment = BoxContainer.ALIGNMENT_END
    controls.add_theme_constant_override("separation", 6)
    header.add_child(controls)
    var first_label := Label.new()
    first_label.text = "FIRST:"
    first_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    first_label.add_theme_color_override("font_color", Color("#cfbea9"))
    first_label.add_theme_font_size_override("font_size", 11)
    controls.add_child(first_label)
    start_option = OptionButton.new()
    start_option.add_item("Computer")
    start_option.add_item("You")
    start_option.selected = 0
    start_option.custom_minimum_size = Vector2(108, 34)
    controls.add_child(start_option)
    var new_game := _make_button("NEW RANDOM GAME", false)
    new_game.custom_minimum_size = Vector2(145, 34)
    new_game.pressed.connect(_start_new_game)
    controls.add_child(new_game)

    var board := PanelContainer.new()
    board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    board.size_flags_vertical = Control.SIZE_EXPAND_FILL
    board.add_theme_stylebox_override("panel", _style(PAPER, 11, 2, Color("#c6b594")))
    main.add_child(board)

    var margin := MarginContainer.new()
    for key in ["margin_left", "margin_right"]:
        margin.add_theme_constant_override(key, 11)
    for key in ["margin_top", "margin_bottom"]:
        margin.add_theme_constant_override(key, 7)
    board.add_child(margin)

    var board_v := VBoxContainer.new()
    board_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    board_v.size_flags_vertical = Control.SIZE_EXPAND_FILL
    board_v.add_theme_constant_override("separation", 2)
    margin.add_child(board_v)

    var top := HBoxContainer.new()
    top.custom_minimum_size.y = 36
    board_v.add_child(top)
    var status_box := VBoxContainer.new()
    status_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    top.add_child(status_box)
    status_label = Label.new()
    status_label.add_theme_font_size_override("font_size", 17)
    status_box.add_child(status_label)
    substatus_label = Label.new()
    substatus_label.add_theme_color_override("font_color", MUTED)
    substatus_label.add_theme_font_size_override("font_size", 10)
    status_box.add_child(substatus_label)

    var info := VBoxContainer.new()
    info.alignment = BoxContainer.ALIGNMENT_CENTER
    top.add_child(info)
    remaining_label = Label.new()
    remaining_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    remaining_label.add_theme_color_override("font_color", MUTED)
    remaining_label.add_theme_font_size_override("font_size", 11)
    info.add_child(remaining_label)
    setup_label = Label.new()
    setup_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    setup_label.add_theme_color_override("font_color", INK)
    setup_label.add_theme_font_size_override("font_size", 11)
    info.add_child(setup_label)

    var rule := Label.new()
    rule.text = "Remove one or more matches from ONE row only  •  Taking the LAST match WINS"
    rule.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    rule.add_theme_color_override("font_color", MUTED)
    rule.add_theme_font_size_override("font_size", 10)
    board_v.add_child(rule)
    board_v.add_child(HSeparator.new())

    rows_box = VBoxContainer.new()
    rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    rows_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
    rows_box.add_theme_constant_override("separation", 0)
    board_v.add_child(rows_box)
    board_v.add_child(HSeparator.new())

    message_label = Label.new()
    message_label.custom_minimum_size.y = 22
    message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    message_label.add_theme_color_override("font_color", INK)
    message_label.add_theme_font_size_override("font_size", 11)
    board_v.add_child(message_label)

    var actions := HBoxContainer.new()
    actions.custom_minimum_size.y = 36
    actions.alignment = BoxContainer.ALIGNMENT_CENTER
    actions.add_theme_constant_override("separation", 7)
    board_v.add_child(actions)
    undo_button = _make_button("UNDO PICKS", false)
    undo_button.custom_minimum_size = Vector2(115, 34)
    undo_button.pressed.connect(_undo_player_turn)
    actions.add_child(undo_button)
    action_button = _make_button("END MY TURN →", true)
    action_button.custom_minimum_size = Vector2(185, 36)
    action_button.pressed.connect(_on_action_button)
    actions.add_child(action_button)


func _build_audio() -> void:
    match_sound_player = AudioStreamPlayer.new()
    match_sound_player.volume_db = -6.0
    add_child(match_sound_player)

    result_sound_player = AudioStreamPlayer.new()
    result_sound_player.volume_db = -2.0
    add_child(result_sound_player)

    # Two quick high partials give each removal a small metallic clink/tink.
    match_sound = _make_tone_sequence([2200.0, 3350.0], 0.024, 0.22)
    win_sound = _make_tone_sequence([523.25, 659.25, 783.99, 1046.50], 0.12, 0.32)
    lose_sound = _make_tone_sequence([392.0, 311.13, 246.94, 196.0], 0.15, 0.30)


func _make_tone_sequence(frequencies: Array, note_length: float, volume: float) -> AudioStreamWAV:
    var sample_rate := 22050
    var samples_per_note := maxi(1, int(float(sample_rate) * note_length))
    var total_samples := samples_per_note * frequencies.size()
    var bytes := PackedByteArray()
    bytes.resize(total_samples * 2)

    for note_index in range(frequencies.size()):
        var frequency := float(frequencies[note_index])
        for sample_index in range(samples_per_note):
            var t := float(sample_index) / float(sample_rate)
            var progress := float(sample_index) / float(maxi(1, samples_per_note - 1))
            var envelope := sin(PI * progress)
            var sample := sin(TAU * frequency * t) * envelope * volume
            var pcm_value := int(clampf(sample, -1.0, 1.0) * 32767.0)
            var byte_offset := (note_index * samples_per_note + sample_index) * 2
            bytes.encode_s16(byte_offset, pcm_value)

    var stream := AudioStreamWAV.new()
    stream.format = AudioStreamWAV.FORMAT_16_BITS
    stream.mix_rate = sample_rate
    stream.stereo = false
    stream.data = bytes
    return stream


func _play_match_sound() -> void:
    if match_sound_player == null or match_sound == null:
        return
    match_sound_player.stream = match_sound
    match_sound_player.pitch_scale = rng.randf_range(0.93, 1.07)
    match_sound_player.play()


func _play_result_sound(player_won: bool) -> void:
    if result_sound_player == null:
        return
    result_sound_player.stream = win_sound if player_won else lose_sound
    result_sound_player.pitch_scale = 1.0
    result_sound_player.play()


func _build_result_overlay() -> void:
    result_overlay = Control.new()
    result_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    result_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
    result_overlay.visible = false
    result_overlay.z_index = 100
    add_child(result_overlay)

    var dim := ColorRect.new()
    dim.color = Color(0.05, 0.035, 0.025, 0.72)
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
    result_overlay.add_child(dim)

    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    center.mouse_filter = Control.MOUSE_FILTER_IGNORE
    result_overlay.add_child(center)

    result_panel = PanelContainer.new()
    result_panel.custom_minimum_size = Vector2(520, 190)
    result_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    center.add_child(result_panel)

    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 32)
    margin.add_theme_constant_override("margin_right", 32)
    margin.add_theme_constant_override("margin_top", 24)
    margin.add_theme_constant_override("margin_bottom", 24)
    margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
    result_panel.add_child(margin)

    var result_box := VBoxContainer.new()
    result_box.alignment = BoxContainer.ALIGNMENT_CENTER
    result_box.add_theme_constant_override("separation", 8)
    result_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
    margin.add_child(result_box)

    result_title = Label.new()
    result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    result_title.add_theme_font_size_override("font_size", 64)
    result_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
    result_box.add_child(result_title)

    result_subtitle = Label.new()
    result_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    result_subtitle.add_theme_color_override("font_color", PAPER)
    result_subtitle.add_theme_font_size_override("font_size", 18)
    result_subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
    result_box.add_child(result_subtitle)

    var again_hint := Label.new()
    again_hint.text = "Press PLAY AGAIN below for a new random board"
    again_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    again_hint.add_theme_color_override("font_color", Color("#d6c9b8"))
    again_hint.add_theme_font_size_override("font_size", 12)
    again_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
    result_box.add_child(again_hint)


func _show_result_overlay(player_won: bool, explanation: String) -> void:
    if result_overlay == null:
        return

    result_title.text = "YOU WIN!" if player_won else "YOU LOSE"
    result_title.add_theme_color_override("font_color", Color("#86c995") if player_won else Color("#e37a70"))
    result_subtitle.text = explanation
    result_panel.add_theme_stylebox_override(
        "panel",
        _style(Color("#241813"), 18, 3, Color("#6f9f78") if player_won else Color("#a84b43"))
    )

    result_overlay.modulate.a = 0.0
    result_overlay.visible = true
    var tween := create_tween()
    tween.tween_property(result_overlay, "modulate:a", 1.0, 0.22)


func _hide_result_overlay() -> void:
    if result_overlay != null:
        result_overlay.visible = false
        result_overlay.modulate.a = 1.0
    if result_sound_player != null:
        result_sound_player.stop()


func _randomize_piles() -> Array[int]:
    var result: Array[int] = []
    for _i in range(ROW_COUNT):
        result.append(rng.randi_range(MIN_MATCHES, MAX_MATCHES))
    return result


func _start_new_game() -> void:
    _hide_result_overlay()
    game_serial += 1
    piles = _randomize_piles()
    selected_row = -1
    removed_this_turn = 0
    _build_match_rows()
    if start_option.selected == 0:
        phase = Phase.COMPUTER
        message_label.text = "New board: %s. Computer goes first." % _position_string()
        _refresh_ui()
        _computer_turn(game_serial)
    else:
        _begin_player_turn("New board: %s. You go first." % _position_string())


func _begin_player_turn(message: String = "Your turn. Remove matches from one row.") -> void:
    phase = Phase.PLAYER
    selected_row = -1
    removed_this_turn = 0
    turn_start_piles = piles.duplicate()
    message_label.text = message
    _refresh_ui()


func _build_match_rows() -> void:
    _clear_container(rows_box)
    match_rows.clear()
    count_labels.clear()
    for row_index in range(piles.size()):
        var row := HBoxContainer.new()
        row.custom_minimum_size.y = 60
        row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        row.size_flags_vertical = Control.SIZE_EXPAND_FILL
        rows_box.add_child(row)

        var label_box := VBoxContainer.new()
        label_box.custom_minimum_size.x = 58
        label_box.alignment = BoxContainer.ALIGNMENT_CENTER
        row.add_child(label_box)

        var row_label := Label.new()
        row_label.text = "ROW %d" % (row_index + 1)
        row_label.add_theme_color_override("font_color", MUTED)
        row_label.add_theme_font_size_override("font_size", 9)
        label_box.add_child(row_label)

        var count_label := Label.new()
        count_label.text = str(piles[row_index])
        count_label.add_theme_color_override("font_color", INK)
        count_label.add_theme_font_size_override("font_size", 16)
        label_box.add_child(count_label)
        count_labels.append(count_label)

        var sticks := HBoxContainer.new()
        sticks.alignment = BoxContainer.ALIGNMENT_CENTER
        sticks.add_theme_constant_override("separation", 3)
        sticks.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        sticks.size_flags_vertical = Control.SIZE_EXPAND_FILL
        row.add_child(sticks)
        match_rows.append(sticks)

        for _index in range(piles[row_index]):
            var stick_button := MatchstickButton.new()
            stick_button.row_index = row_index
            stick_button.pressed.connect(_on_match_pressed.bind(row_index, stick_button))
            sticks.add_child(stick_button)

    _refresh_match_interaction()


func _on_match_pressed(row_index: int, stick_button: MatchstickButton) -> void:
    if phase != Phase.PLAYER:
        return
    if selected_row != -1 and selected_row != row_index:
        return
    if selected_row == -1:
        selected_row = row_index

    piles[row_index] -= 1
    removed_this_turn += 1
    _play_match_sound()
    _animate_removal(stick_button)

    if _total_matches() == 0:
        _finish_game(true, "You took the final match!")
        return

    message_label.text = "You removed %d match%s from Row %d." % [removed_this_turn, "" if removed_this_turn == 1 else "es", row_index + 1]
    _refresh_ui()


func _on_action_button() -> void:
    if phase == Phase.PLAYER:
        _finish_player_turn()
    elif phase == Phase.GAME_OVER:
        _start_new_game()


func _finish_player_turn() -> void:
    if phase != Phase.PLAYER or removed_this_turn <= 0:
        return
    phase = Phase.COMPUTER
    message_label.text = "Your turn is complete. Watch the computer."
    _refresh_ui()
    _computer_turn(game_serial)


func _undo_player_turn() -> void:
    if phase != Phase.PLAYER or removed_this_turn <= 0:
        return
    piles = turn_start_piles.duplicate()
    selected_row = -1
    removed_this_turn = 0
    _build_match_rows()
    message_label.text = "Your picks were restored."
    _refresh_ui()


func _computer_turn(serial: int) -> void:
    if serial != game_serial:
        return

    phase = Phase.COMPUTER
    _refresh_ui()
    await get_tree().create_timer(0.55).timeout
    if serial != game_serial:
        return

    var move := _choose_normal_move()
    var row_index: int = int(move.get("row", -1))
    var amount: int = int(move.get("amount", 0))
    if row_index < 0 or amount <= 0:
        return

    for step in range(amount):
        if serial != game_serial or phase != Phase.COMPUTER:
            return

        piles[row_index] -= 1
        _play_match_sound()
        _remove_one_computer_match(row_index)
        message_label.text = "Computer removes match %d of %d from Row %d." % [step + 1, amount, row_index + 1]
        _refresh_counts_only()

        if _total_matches() == 0:
            await get_tree().create_timer(0.2).timeout
            if serial == game_serial:
                _finish_game(false, "The computer took the final match.")
            return

        if step < amount - 1:
            await get_tree().create_timer(COMPUTER_MATCH_DELAY).timeout

    if serial == game_serial:
        _begin_player_turn("Computer removed %d match%s from Row %d. Your turn." % [amount, "" if amount == 1 else "es", row_index + 1])


func _choose_normal_move() -> Dictionary:
    var x := _nim_sum()
    if x != 0:
        for i in range(piles.size()):
            var target := piles[i] ^ x
            if target < piles[i]:
                return {"row": i, "amount": piles[i] - target}

    var available: Array[int] = []
    for i in range(piles.size()):
        if piles[i] > 0:
            available.append(i)

    if available.is_empty():
        return {"row": -1, "amount": 0}

    var chosen := available[rng.randi_range(0, available.size() - 1)]
    return {"row": chosen, "amount": rng.randi_range(1, piles[chosen])}


func _nim_sum() -> int:
    var result := 0
    for value in piles:
        result = result ^ value
    return result


func _animate_removal(stick_button: MatchstickButton) -> void:
    stick_button.disabled = true
    var tween := create_tween()
    tween.set_parallel(true)
    tween.tween_property(stick_button, "modulate:a", 0.0, 0.16)
    tween.tween_property(stick_button, "position:y", stick_button.position.y + 8.0, 0.16)
    tween.set_parallel(false)
    tween.tween_callback(stick_button.queue_free)


func _remove_one_computer_match(row_index: int) -> void:
    var children := match_rows[row_index].get_children()
    for i in range(children.size() - 1, -1, -1):
        var child := children[i]
        if child is MatchstickButton and not child.is_queued_for_deletion():
            _animate_removal(child)
            return


func _refresh_ui() -> void:
    _refresh_counts_only()
    _refresh_match_interaction()

    match phase:
        Phase.PLAYER:
            status_label.text = "YOUR TURN"
            status_label.add_theme_color_override("font_color", GREEN)
            substatus_label.text = "Click a match to choose a row." if selected_row == -1 else "Row %d is locked in." % (selected_row + 1)
            action_button.text = "END MY TURN →"
            action_button.disabled = removed_this_turn == 0
            undo_button.disabled = removed_this_turn == 0
        Phase.COMPUTER:
            status_label.text = "COMPUTER'S TURN"
            status_label.add_theme_color_override("font_color", RED_DARK)
            substatus_label.text = "One match every 0.5 seconds."
            action_button.text = "COMPUTER'S TURN..."
            action_button.disabled = true
            undo_button.disabled = true
        Phase.GAME_OVER:
            status_label.text = "GAME OVER"
            status_label.add_theme_color_override("font_color", RED_DARK)
            substatus_label.text = "Press PLAY AGAIN for a new random board."
            action_button.text = "PLAY AGAIN"
            action_button.disabled = false
            undo_button.disabled = true


func _refresh_counts_only() -> void:
    remaining_label.text = "%d MATCH%s LEFT" % [_total_matches(), "" if _total_matches() == 1 else "ES"]
    setup_label.text = "ROWS: %s" % _position_string()
    for i in range(mini(count_labels.size(), piles.size())):
        count_labels[i].text = str(piles[i])


func _refresh_match_interaction() -> void:
    for row_index in range(match_rows.size()):
        var enabled := phase == Phase.PLAYER and (selected_row == -1 or selected_row == row_index)
        var row := match_rows[row_index]
        row.modulate = Color.WHITE if enabled or phase != Phase.PLAYER else Color(0.72, 0.68, 0.61, 0.55)
        for child in row.get_children():
            if child is MatchstickButton:
                child.set_turn_enabled(enabled)


func _finish_game(player_won: bool, explanation: String) -> void:
    phase = Phase.GAME_OVER
    game_serial += 1
    selected_row = -1
    removed_this_turn = 0
    message_label.text = ("YOU WIN!  " if player_won else "COMPUTER WINS.  ") + explanation
    _refresh_ui()
    _show_result_overlay(player_won, explanation)
    _play_result_sound(player_won)


func _total_matches() -> int:
    var total := 0
    for value in piles:
        total += value
    return total


func _position_string() -> String:
    var parts: Array[String] = []
    for value in piles:
        parts.append(str(value))
    return "–".join(parts)


func _make_button(text_value: String, primary: bool) -> Button:
    var button := Button.new()
    button.text = text_value
    button.add_theme_font_size_override("font_size", 11)
    button.add_theme_color_override("font_color", PAPER if primary else INK)
    button.add_theme_color_override("font_hover_color", PAPER if primary else INK)
    button.add_theme_stylebox_override("normal", _style(RED if primary else PAPER_2, 7, 1, RED_DARK if primary else Color("#bba984")))
    button.add_theme_stylebox_override("hover", _style(RED_DARK if primary else Color("#ddcfb1"), 7, 1, RED_DARK if primary else Color("#a99570")))
    button.add_theme_stylebox_override("pressed", _style(Color("#57201c") if primary else Color("#d2c19f"), 7, 1, RED_DARK if primary else Color("#9f8a65")))
    return button


func _style(bg: Color, radius: int, border: int = 0, border_color: Color = Color.TRANSPARENT) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = bg
    style.corner_radius_top_left = radius
    style.corner_radius_top_right = radius
    style.corner_radius_bottom_left = radius
    style.corner_radius_bottom_right = radius
    style.border_width_left = border
    style.border_width_top = border
    style.border_width_right = border
    style.border_width_bottom = border
    style.border_color = border_color
    style.content_margin_left = 8
    style.content_margin_right = 8
    style.content_margin_top = 4
    style.content_margin_bottom = 4
    return style


func _clear_container(container: Node) -> void:
    for child in container.get_children():
        child.queue_free()
