extends Control

# Matchstick Nim — 1, 3, 5, 7 rows.
# Misere rule used in the referenced video: taking the final match loses.

const TABLE := Color("#241813")
const TABLE_LIGHT := Color("#35251e")
const PAPER := Color("#f3ead6")
const PAPER_2 := Color("#e8dcc3")
const INK := Color("#29231f")
const MUTED := Color("#74685d")
const RED := Color("#8f3029")
const RED_DARK := Color("#68211d")
const GREEN := Color("#486f52")

const CLASSIC_PILES: Array[int] = [1, 3, 5, 7]
const COMPUTER_MATCH_DELAY := 0.5

enum Phase { WAIT_PLAYER, PLAYER, COMPUTER, GAME_OVER }

class MatchstickButton:
    extends Button

    var row_index: int = 0

    func _init() -> void:
        flat = true
        custom_minimum_size = Vector2(38, 106)
        focus_mode = Control.FOCUS_ALL
        mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
        tooltip_text = "Remove this match"
        add_theme_stylebox_override("focus", StyleBoxEmpty.new())

    func _draw() -> void:
        var cx := size.x * 0.5
        var shaft_top := 27.0
        var shaft_bottom := size.y - 8.0
        var shaft_height := maxf(44.0, shaft_bottom - shaft_top)
        var opacity := 1.0 if not disabled else 0.38
        draw_rect(Rect2(cx - 2.0, shaft_top + 3.0, 7.0, shaft_height), Color(0.16, 0.10, 0.06, 0.16 * opacity), true)
        draw_circle(Vector2(cx + 2.0, 19.0), 9.5, Color(0.16, 0.08, 0.05, 0.17 * opacity))
        draw_rect(Rect2(cx - 3.5, shaft_top, 7.0, shaft_height), Color(0.69, 0.50, 0.27, opacity), true)
        draw_rect(Rect2(cx - 1.5, shaft_top, 3.0, shaft_height), Color(0.91, 0.75, 0.46, opacity), true)
        draw_rect(Rect2(cx + 2.0, shaft_top, 1.5, shaft_height), Color(0.48, 0.31, 0.16, opacity), true)
        draw_circle(Vector2(cx, 18.0), 9.0, Color(0.40, 0.11, 0.09, opacity))
        draw_circle(Vector2(cx - 1.0, 16.5), 7.0, Color(0.58, 0.18, 0.15, opacity))
        draw_circle(Vector2(cx - 3.0, 13.5), 2.3, Color(0.78, 0.35, 0.28, opacity))
        if not disabled and is_hovered():
            draw_arc(Vector2(cx, 18.0), 13.0, 0.0, TAU, 24, Color(0.55, 0.19, 0.16, 0.75), 2.0)

    func set_enabled_for_turn(value: bool) -> void:
        disabled = not value
        mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if value else Control.CURSOR_ARROW
        queue_redraw()


var rng := RandomNumberGenerator.new()
var phase: Phase = Phase.WAIT_PLAYER
var piles: Array[int] = CLASSIC_PILES.duplicate()
var turn_start_piles: Array[int] = CLASSIC_PILES.duplicate()
var selected_row := -1
var removed_this_turn := 0
var game_serial := 0

var start_option: OptionButton
var status_label: Label
var substatus_label: Label
var rows_box: VBoxContainer
var match_rows: Array[HBoxContainer] = []
var count_labels: Array[Label] = []
var remaining_label: Label
var message_label: Label
var action_button: Button
var undo_button: Button

func _ready() -> void:
    rng.randomize()
    _build_ui()
    _start_new_game()

func _build_ui() -> void:
    var bg := ColorRect.new()
    bg.color = TABLE
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(bg)

    var scroll := ScrollContainer.new()
    scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    add_child(scroll)

    var outer := MarginContainer.new()
    outer.add_theme_constant_override("margin_left", 26)
    outer.add_theme_constant_override("margin_right", 26)
    outer.add_theme_constant_override("margin_top", 22)
    outer.add_theme_constant_override("margin_bottom", 28)
    outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(outer)

    var main := VBoxContainer.new()
    main.add_theme_constant_override("separation", 14)
    main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    outer.add_child(main)

    var header := HBoxContainer.new()
    header.add_theme_constant_override("separation", 18)
    main.add_child(header)

    var title_box := VBoxContainer.new()
    title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(title_box)

    var title := Label.new()
    title.text = "THE GAME OF NIM"
    title.add_theme_color_override("font_color", PAPER)
    title.add_theme_font_size_override("font_size", 34)
    title_box.add_child(title)

    var subtitle := Label.new()
    subtitle.text = "Matchstick edition • 1–3–5–7"
    subtitle.add_theme_color_override("font_color", Color("#cfbea9"))
    subtitle.add_theme_font_size_override("font_size", 15)
    title_box.add_child(subtitle)

    var controls := VBoxContainer.new()
    controls.alignment = BoxContainer.ALIGNMENT_END
    header.add_child(controls)

    var first_label := Label.new()
    first_label.text = "WHO GOES FIRST?"
    first_label.add_theme_color_override("font_color", Color("#cfbea9"))
    first_label.add_theme_font_size_override("font_size", 12)
    controls.add_child(first_label)

    var control_row := HBoxContainer.new()
    control_row.add_theme_constant_override("separation", 8)
    controls.add_child(control_row)

    start_option = OptionButton.new()
    start_option.add_item("Computer")
    start_option.add_item("You")
    start_option.selected = 0
    start_option.custom_minimum_size = Vector2(130, 42)
    control_row.add_child(start_option)

    var new_game := _make_button("NEW GAME", false)
    new_game.custom_minimum_size = Vector2(120, 42)
    new_game.pressed.connect(_start_new_game)
    control_row.add_child(new_game)

    var rule_panel := PanelContainer.new()
    rule_panel.add_theme_stylebox_override("panel", _style(TABLE_LIGHT, 12, 1, Color("#5a4337")))
    main.add_child(rule_panel)
    var rule_margin := _margin(14, 14, 10, 10)
    rule_panel.add_child(rule_margin)
    var rule_text := Label.new()
    rule_text.text = "Remove one or more matches from ONE row only. Taking the LAST match LOSES."
    rule_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    rule_text.add_theme_color_override("font_color", PAPER)
    rule_text.add_theme_font_size_override("font_size", 15)
    rule_margin.add_child(rule_text)

    var board := PanelContainer.new()
    board.add_theme_stylebox_override("panel", _style(PAPER, 18, 2, Color("#c6b594")))
    board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    main.add_child(board)
    var board_margin := _margin(20, 20, 18, 18)
    board.add_child(board_margin)
    var board_v := VBoxContainer.new()
    board_v.add_theme_constant_override("separation", 12)
    board_margin.add_child(board_v)

    var top := HBoxContainer.new()
    top.add_theme_constant_override("separation", 12)
    board_v.add_child(top)
    var status_box := VBoxContainer.new()
    status_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    top.add_child(status_box)

    status_label = Label.new()
    status_label.add_theme_font_size_override("font_size", 22)
    status_box.add_child(status_label)
    substatus_label = Label.new()
    substatus_label.add_theme_color_override("font_color", MUTED)
    substatus_label.add_theme_font_size_override("font_size", 14)
    substatus_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    status_box.add_child(substatus_label)

    remaining_label = Label.new()
    remaining_label.add_theme_color_override("font_color", MUTED)
    remaining_label.add_theme_font_size_override("font_size", 14)
    top.add_child(remaining_label)

    board_v.add_child(HSeparator.new())
    rows_box = VBoxContainer.new()
    rows_box.add_theme_constant_override("separation", 6)
    rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    board_v.add_child(rows_box)
    board_v.add_child(HSeparator.new())

    message_label = Label.new()
    message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    message_label.add_theme_color_override("font_color", INK)
    message_label.add_theme_font_size_override("font_size", 15)
    message_label.custom_minimum_size.y = 44
    board_v.add_child(message_label)

    var actions := HBoxContainer.new()
    actions.alignment = BoxContainer.ALIGNMENT_CENTER
    actions.add_theme_constant_override("separation", 10)
    board_v.add_child(actions)

    undo_button = _make_button("UNDO MY PICKS", false)
    undo_button.custom_minimum_size = Vector2(155, 48)
    undo_button.pressed.connect(_undo_player_turn)
    actions.add_child(undo_button)

    action_button = _make_button("START MY TURN", true)
    action_button.custom_minimum_size = Vector2(220, 52)
    action_button.pressed.connect(_on_action_button)
    actions.add_child(action_button)

    var hint := Label.new()
    hint.text = "Click individual matchsticks. Once you choose a row, the other rows lock until you end your turn."
    hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hint.add_theme_color_override("font_color", Color("#cdbca6"))
    hint.add_theme_font_size_override("font_size", 13)
    main.add_child(hint)

func _start_new_game() -> void:
    game_serial += 1
    piles = CLASSIC_PILES.duplicate()
    turn_start_piles = piles.duplicate()
    selected_row = -1
    removed_this_turn = 0
    _build_match_rows()
    if start_option.selected == 0:
        phase = Phase.COMPUTER
        message_label.text = "The computer goes first. Watch it remove matches one by one."
        _refresh_ui()
        _computer_turn(game_serial)
    else:
        phase = Phase.WAIT_PLAYER
        message_label.text = "You go first. Press START MY TURN when you're ready."
        _refresh_ui()

func _build_match_rows() -> void:
    _clear_container(rows_box)
    match_rows.clear()
    count_labels.clear()
    for row_index in range(piles.size()):
        var row := HBoxContainer.new()
        row.custom_minimum_size.y = 108
        row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        rows_box.add_child(row)

        var label_box := VBoxContainer.new()
        label_box.custom_minimum_size.x = 82
        label_box.alignment = BoxContainer.ALIGNMENT_CENTER
        row.add_child(label_box)
        var row_label := Label.new()
        row_label.text = "ROW %d" % (row_index + 1)
        row_label.add_theme_color_override("font_color", MUTED)
        row_label.add_theme_font_size_override("font_size", 12)
        label_box.add_child(row_label)
        var count_label := Label.new()
        count_label.text = str(piles[row_index])
        count_label.add_theme_color_override("font_color", INK)
        count_label.add_theme_font_size_override("font_size", 22)
        label_box.add_child(count_label)
        count_labels.append(count_label)

        var sticks := HBoxContainer.new()
        sticks.alignment = BoxContainer.ALIGNMENT_CENTER
        sticks.add_theme_constant_override("separation", 3)
        sticks.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        row.add_child(sticks)
        match_rows.append(sticks)

        for _index in range(piles[row_index]):
            var stick_button := MatchstickButton.new()
            stick_button.row_index = row_index
            stick_button.pressed.connect(_on_match_pressed.bind(row_index, stick_button))
            sticks.add_child(stick_button)
    _refresh_match_interaction()

func _on_action_button() -> void:
    match phase:
        Phase.WAIT_PLAYER:
            _begin_player_turn()
        Phase.PLAYER:
            _finish_player_turn()
        Phase.GAME_OVER:
            _start_new_game()
        _:
            pass

func _begin_player_turn() -> void:
    if phase != Phase.WAIT_PLAYER:
        return
    phase = Phase.PLAYER
    selected_row = -1
    removed_this_turn = 0
    turn_start_piles = piles.duplicate()
    message_label.text = "Click a matchstick to remove it. Keep taking from that same row, or end your turn."
    _refresh_ui()

func _on_match_pressed(row_index: int, stick_button: MatchstickButton) -> void:
    if phase != Phase.PLAYER:
        return
    if row_index < 0 or row_index >= piles.size() or piles[row_index] <= 0:
        return
    if selected_row != -1 and selected_row != row_index:
        return
    if selected_row == -1:
        selected_row = row_index
    piles[row_index] -= 1
    removed_this_turn += 1
    _animate_removal(stick_button)
    message_label.text = "You removed %d match%s from Row %d." % [removed_this_turn, "" if removed_this_turn == 1 else "es", row_index + 1]
    if _total_matches() == 0:
        _finish_game(false, "You took the final match. Taking the last match loses.")
        return
    _refresh_ui()

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
    message_label.text = "Your selections were restored. Choose a row again."
    _refresh_ui()

func _computer_turn(serial: int) -> void:
    if serial != game_serial:
        return
    phase = Phase.COMPUTER
    selected_row = -1
    removed_this_turn = 0
    _refresh_ui()
    await get_tree().create_timer(0.7).timeout
    if serial != game_serial or phase != Phase.COMPUTER:
        return
    var move := _choose_misere_move()
    var row_index: int = int(move.get("row", -1))
    var amount: int = int(move.get("amount", 0))
    if row_index < 0 or amount <= 0:
        return
    substatus_label.text = "Computer chose Row %d..." % (row_index + 1)
    for step in range(amount):
        if serial != game_serial or phase != Phase.COMPUTER or piles[row_index] <= 0:
            return
        piles[row_index] -= 1
        _remove_one_computer_match(row_index)
        message_label.text = "Computer removes match %d of %d from Row %d." % [step + 1, amount, row_index + 1]
        _refresh_counts_only()
        if _total_matches() == 0:
            await get_tree().create_timer(0.3).timeout
            if serial == game_serial:
                _finish_game(true, "The computer took the final match, so you win!")
            return
        if step < amount - 1:
            await get_tree().create_timer(COMPUTER_MATCH_DELAY).timeout
    if serial != game_serial:
        return
    phase = Phase.WAIT_PLAYER
    message_label.text = "Computer removed %d match%s from Row %d. Press START MY TURN." % [amount, "" if amount == 1 else "es", row_index + 1]
    _refresh_ui()

func _choose_misere_move() -> Dictionary:
    var big_count := 0
    var big_index := -1
    var ones_count := 0
    for i in range(piles.size()):
        if piles[i] > 1:
            big_count += 1
            big_index = i
        elif piles[i] == 1:
            ones_count += 1
    if big_count == 0:
        for i in range(piles.size()):
            if piles[i] == 1:
                return {"row": i, "amount": 1}
    if big_count == 1:
        if ones_count % 2 == 0:
            return {"row": big_index, "amount": piles[big_index] - 1}
        return {"row": big_index, "amount": piles[big_index]}
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
    var chosen_row: int = available[rng.randi_range(0, available.size() - 1)]
    return {"row": chosen_row, "amount": rng.randi_range(1, piles[chosen_row])}

func _nim_sum() -> int:
    var result := 0
    for value in piles:
        result = result ^ value
    return result

func _animate_removal(stick_button: MatchstickButton) -> void:
    if not is_instance_valid(stick_button):
        return
    stick_button.disabled = true
    var tween := create_tween()
    tween.set_parallel(true)
    tween.tween_property(stick_button, "modulate:a", 0.0, 0.2)
    tween.tween_property(stick_button, "position:y", stick_button.position.y + 16.0, 0.2)
    tween.set_parallel(false)
    tween.tween_callback(stick_button.queue_free)

func _remove_one_computer_match(row_index: int) -> void:
    if row_index < 0 or row_index >= match_rows.size():
        return
    var row := match_rows[row_index]
    var children := row.get_children()
    for i in range(children.size() - 1, -1, -1):
        var child := children[i]
        if child is MatchstickButton and not child.is_queued_for_deletion():
            _animate_removal(child)
            return

func _refresh_ui() -> void:
    _refresh_counts_only()
    _refresh_match_interaction()
    match phase:
        Phase.WAIT_PLAYER:
            status_label.text = "READY FOR YOUR TURN"
            status_label.add_theme_color_override("font_color", GREEN)
            substatus_label.text = "Press START MY TURN before touching the matches."
            action_button.text = "START MY TURN"
            action_button.disabled = false
            undo_button.disabled = true
        Phase.PLAYER:
            status_label.text = "YOUR TURN"
            status_label.add_theme_color_override("font_color", RED_DARK)
            substatus_label.text = "Choose one row." if selected_row == -1 else "Row %d is locked in." % (selected_row + 1)
            action_button.text = "END MY TURN →"
            action_button.disabled = removed_this_turn == 0
            undo_button.disabled = removed_this_turn == 0
        Phase.COMPUTER:
            status_label.text = "COMPUTER'S TURN"
            status_label.add_theme_color_override("font_color", RED_DARK)
            substatus_label.text = "The computer removes one match every 0.5 seconds."
            action_button.text = "COMPUTER'S TURN..."
            action_button.disabled = true
            undo_button.disabled = true
        Phase.GAME_OVER:
            status_label.text = "GAME OVER"
            status_label.add_theme_color_override("font_color", RED_DARK)
            substatus_label.text = "Press PLAY AGAIN for another 1–3–5–7 game."
            action_button.text = "PLAY AGAIN"
            action_button.disabled = false
            undo_button.disabled = true

func _refresh_counts_only() -> void:
    var remaining := _total_matches()
    remaining_label.text = "%d MATCH%s LEFT" % [remaining, "" if remaining == 1 else "ES"]
    for i in range(mini(count_labels.size(), piles.size())):
        count_labels[i].text = str(piles[i])

func _refresh_match_interaction() -> void:
    for row_index in range(match_rows.size()):
        var row_enabled := phase == Phase.PLAYER and (selected_row == -1 or selected_row == row_index)
        var row := match_rows[row_index]
        row.modulate = Color.WHITE if row_enabled or phase != Phase.PLAYER else Color(0.72, 0.68, 0.61, 0.55)
        for child in row.get_children():
            if child is MatchstickButton:
                child.set_enabled_for_turn(row_enabled)

func _finish_game(player_won: bool, explanation: String) -> void:
    phase = Phase.GAME_OVER
    game_serial += 1
    selected_row = -1
    removed_this_turn = 0
    message_label.text = ("YOU WIN!  " if player_won else "COMPUTER WINS.  ") + explanation
    _refresh_ui()

func _total_matches() -> int:
    var total := 0
    for value in piles:
        total += value
    return total

func _make_button(text_value: String, primary: bool) -> Button:
    var button := Button.new()
    button.text = text_value
    button.add_theme_font_size_override("font_size", 14)
    button.add_theme_color_override("font_color", PAPER if primary else INK)
    button.add_theme_color_override("font_hover_color", PAPER if primary else INK)
    button.add_theme_stylebox_override("normal", _style(RED if primary else PAPER_2, 9, 1, RED_DARK if primary else Color("#bba984")))
    button.add_theme_stylebox_override("hover", _style(RED_DARK if primary else Color("#ddcfb1"), 9, 1, RED_DARK if primary else Color("#a99570")))
    button.add_theme_stylebox_override("pressed", _style(Color("#57201c") if primary else Color("#d2c19f"), 9, 1, RED_DARK if primary else Color("#9f8a65")))
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
    style.content_margin_left = 12
    style.content_margin_right = 12
    style.content_margin_top = 8
    style.content_margin_bottom = 8
    return style

func _margin(left: int, right: int, top: int, bottom: int) -> MarginContainer:
    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", left)
    margin.add_theme_constant_override("margin_right", right)
    margin.add_theme_constant_override("margin_top", top)
    margin.add_theme_constant_override("margin_bottom", bottom)
    return margin

func _clear_container(container: Node) -> void:
    if container == null:
        return
    for child in container.get_children():
        child.queue_free()