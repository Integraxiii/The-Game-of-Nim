extends Control

# The Game of Nim — matchstick edition.
# Classic 1-3-5-7 layout using the video's misere rule: taking the last match loses.

const TABLE := Color("#241813")
const TABLE_LIGHT := Color("#35251e")
const PAPER := Color("#f3ead6")
const PAPER_2 := Color("#e8dcc3")
const INK := Color("#29231f")
const MUTED := Color("#74685d")
const RED := Color("#8f3029")
const RED_DARK := Color("#68211d")
const GOLD := Color("#c49345")
const GREEN := Color("#486f52")
const DISABLED := Color("#b7aa96")

const CLASSIC_PILES: Array[int] = [1, 3, 5, 7]
const COMPUTER_MATCH_DELAY := 0.5

enum Phase {
    WAIT_PLAYER,
    PLAYER,
    COMPUTER,
    GAME_OVER
}

class MatchstickButton:
    extends Button

    var row_index: int = 0
    var match_index: int = 0
    var active_match: bool = true

    func _init() -> void:
        flat = true
        custom_minimum_size = Vector2(34, 104)
        focus_mode = Control.FOCUS_ALL
        mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
        tooltip_text = "Remove this match"
        add_theme_stylebox_override("focus", StyleBoxEmpty.new())

    func set_active(value: bool) -> void:
        active_match = value
        disabled = not value
        mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if value else Control.CURSOR_ARROW
        queue_redraw()

    func _draw() -> void:
        var cx := size.x * 0.5
        var shaft_top := 26.0
        var shaft_bottom := size.y - 7.0
        var shaft_height := maxf(44.0, shaft_bottom - shaft_top)
        var alpha := 1.0 if active_match else 0.45

        # soft shadow
        draw_rect(Rect2(cx - 2.0, shaft_top + 3.0, 7.0, shaft_height), Color(0.16, 0.10, 0.06, 0.18 * alpha), true)
        draw_circle(Vector2(cx + 2.0, 19.0), 9.5, Color(0.16, 0.08, 0.05, 0.18 * alpha))

        # wooden shaft with a light centre stripe
        draw_rect(Rect2(cx - 3.5, shaft_top, 7.0, shaft_height), Color(0.69, 0.50, 0.27, alpha), true)
        draw_rect(Rect2(cx - 1.5, shaft_top, 3.0, shaft_height), Color(0.91, 0.75, 0.46, alpha), true)
        draw_rect(Rect2(cx + 2.0, shaft_top, 1.5, shaft_height), Color(0.48, 0.31, 0.16, alpha), true)

        # match head
        draw_circle(Vector2(cx, 18.0), 9.0, Color(0.40, 0.11, 0.09, alpha))
        draw_circle(Vector2(cx - 1.0, 16.5), 7.0, Color(0.58, 0.18, 0.15, alpha))
        draw_circle(Vector2(cx - 3.2, 13.8), 2.4, Color(0.78, 0.35, 0.28, alpha))

        if active_match and is_hovered():
            draw_arc(Vector2(cx, 18.0), 13.0, 0.0, TAU, 24, Color(0.55, 0.19, 0.16, 0.75), 2.0)


var rng := RandomNumberGenerator.new()
var phase: Phase = Phase.WAIT_PLAYER
var piles: Array[int] = CLASSIC_PILES.duplicate()
var turn_start_piles: Array[int] = CLASSIC_PILES.duplicate()
var selected_row := -1
var removed_this_turn := 0
var game_serial := 0

var start_option: OptionButton
var new_game_button: Button
var status_label: Label
var substatus_label: Label
var board_panel: PanelContainer
var rows_box: VBoxContainer
var match_rows: Array[HBoxContainer] = []
var count_labels: Array[Label] = []
var action_button: Button
var undo_button: Button
var message_label: Label
var remaining_label: Label


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
    outer.add_theme_constant_override("margin_left", 24)
    outer.add_theme_constant_override("margin_right", 24)
    outer.add_theme_constant_override("margin_top", 22)
    outer.add_theme_constant_override("margin_bottom", 28)
    outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(outer)

    var main := VBoxContainer.new()
    main.add_theme_constant_override("separation", 14)
    main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    outer.add_child(main)

    var header := HBoxContainer.new()
    header.add_theme_constant_override("separation", 16)
    main.add_child(header)

    var title_block := VBoxContainer.new()
    title_block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    title_block.add_theme_constant_override("separation", 2)
    header.add_child(title_block)

    var title := Label.new()
    title.text = "THE GAME OF NIM"
    title.add_theme_color_override("font_color", PAPER)
    title.add_theme_font_size_override("font_size", 32)
    title_block.add_child(title)

    var subtitle := Label.new()
    subtitle.text = "Matchstick edition • classic 1–3–5–7 board"
    subtitle.add_theme_color_override("font_color", Color("#cfbea9"))
    subtitle.add_theme_font_size_override("font_size", 15)
    title_block.add_child(subtitle)

    var setup := VBoxContainer.new()
    setup.alignment = BoxContainer.ALIGNMENT_END
    setup.add_theme_constant_override("separation", 4)
    header.add_child(setup)

    var who_label := Label.new()
    who_label.text = "WHO GOES FIRST?"
    who_label.add_theme_color_override("font_color", Color("#cfbea9"))
    who_label.add_theme_font_size_override("font_size", 12)
    setup.add_child(who_label)

    var setup_row := HBoxContainer.new()
    setup_row.add_theme_constant_override("separation", 8)
    setup.add_child(setup_row)

    start_option = OptionButton.new()
    start_option.add_item("Computer")
    start_option.add_item("You")
    start_option.selected = 0
    start_option.custom_minimum_size = Vector2(130, 42)
    setup_row.add_child(start_option)

    new_game_button = _make_button("NEW GAME", false)
    new_game_button.custom_minimum_size = Vector2(122, 42)
    new_game_button.pressed.connect(_start_new_game)
    setup_row.add_child(new_game_button)

    var rule_panel := PanelContainer.new()
    rule_panel.add_theme_stylebox_override("panel", _style(TABLE_LIGHT, 12, 1, Color("#5a4337")))
    main.add_child(rule_panel)

    var rule_margin := _margin(14, 14, 10, 10)
    rule_panel.add_child(rule_margin)

    var rule_text := Label.new()
    rule_text.text = "RULES  •  Remove one or more matches from ONE row only.  •  Taking the LAST match LOSES."
    rule_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    rule_text.add_theme_color_override("font_color", PAPER)
    rule_text.add_theme_font_size_override("font_size", 15)
    rule_margin.add_child(rule_text)

    board_panel = PanelContainer.new()
    board_panel.add_theme_stylebox_override("panel", _style(PAPER, 18, 2, Color("#c6b594")))
    board_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    main.add_child(board_panel)

    var board_margin := _margin(20, 20, 18, 18)
    board_panel.add_child(board_margin)

    var board_v := VBoxContainer.new()
    board_v.add_theme_constant_override("separation", 12)
    board_margin.add_child(board_v)

    var board_top := HBoxContainer.new()
    board_top.add_theme_constant_override("separation", 12)
    board_v.add_child(board_top)

    var status_box := VBoxContainer.new()
    status_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    status_box.add_theme_constant_override("separation", 2)
    board_top.add_child(status_box)

    status_label = Label.new()
    status_label.text = "YOUR TURN"
    status_label.add_theme_color_override("font_color", RED_DARK)
    status_label.add_theme_font_size_override("font_size", 22)
    status_box.add_child(status_label)

    substatus_label = Label.new()
    substatus_label.text = "Press Start My Turn when you're ready."
    substatus_label.add_theme_color_override("font_color", MUTED)
    substatus_label.add_theme_font_size_override("font_size", 14)
    substatus_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    status_box.add_child(substatus_label)

    remaining_label = Label.new()
    remaining_label.add_theme_color_override("font_color", MUTED)
    remaining_label.add_theme_font_size_override("font_size", 14)
    board_top.add_child(remaining_label)

    var divider := HSeparator.new()
    divider.add_theme_color_override("separator", Color("#cdbf9f"))
    board_v.add_child(divider)

    rows_box = VBoxContainer.new()
    rows_box.add_theme_constant_override("separation", 5)
    rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    board_v.add_child(rows_box)

    var divider2 := HSeparator.new()
    divider2.add_theme_color_override("separator", Color("#cdbf9f"))
    board_v.add_child(divider2)

    message_label = Label.new()
    message_label.text = ""
    message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    message_label.add_theme_color_override("font_color", INK)
    message_label.add_theme_font_size_override("font_size", 15)
    message_label.custom_minimum_size.y = 42
    board_v.add_child(message_label)

    var actions := HBoxContainer.new()
    actions.add_theme_constant_override("separation", 10)
    actions.alignment = BoxContainer.ALIGNMENT_CENTER
    board_v.add_child(actions)

    undo_button = _make_paper_button("UNDO MY PICKS")
    undo_button.custom_minimum_size = Vector2(150, 48)
    undo_button.disabled = true
    undo_button.pressed.connect(_undo_player_turn)
    actions.add_child(undo_button)

    action_button = _make_action_button("START MY TURN")
    action_button.custom_minimum_size = Vector2(220, 52)
    action_button.pressed.connect(_on_action_button)
    actions.add_child(action_button)

    var note := Label.new()
    note.text = "Tip: once you remove the first match, the other rows lock. Keep taking from that same row, then end your turn."
    note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    note.add_theme_color_override("font_color", Color("#bcae9b"))
    note.add_theme_font_size_override("font_size", 13)
    main.add_child(note)


func _start_new_game() -> void:
    game_serial += 1
    piles = CLASSIC_PILES.duplicate()
    turn_start_piles = piles.duplicate()
    selected_row = -1
    removed_this_turn = 0
    _build_match_rows()

    if start_option.selected == 0:
        phase = Phase.COMPUTER
        message_label.text = "The computer goes first. Watch the matches — it removes them one at a time."
        _refresh_ui()
        _computer_turn(game_serial)
    else:
        phase = Phase.WAIT_PLAYER
        message_label.text = "You go first. Press START MY TURN when you're ready to touch the matches."
        _refresh_ui()


func _build_match_rows() -> void:
    _clear_container(rows_box)
    match_rows.clear()
    count_labels.clear()

    for row_index in range(piles.size()):
        var row := HBoxContainer.new()
        row.add_theme_constant_override("separation", 8)
        row.custom_minimum_size.y = 108
        row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        rows_box.add_child(row)

        var label_box := VBoxContainer.new()
        label_box.custom_minimum_size.x = 78
        label_box.alignment = BoxContainer.ALIGNMENT_CENTER
        row.add_child(label_box)

        var row_label := Label.new()
        row_label.text = "ROW %d" % (row_index + 1)
        row_label.add_theme_color_override("font_color", MUTED)
        row_label.add_theme_font_size_override("font_size", 12)
        label_box.add_child(row_label)

        var count := Label.new()
        count.text = str(piles[row_index])
        count.add_theme_color_override("font_color", INK)
        count.add_theme_font_size_override("font_size", 22)
        label_box.add_child(count)
        count_labels.append(count)

        var matches := HBoxContainer.new()
        matches.alignment = BoxContainer.ALIGNMENT_CENTER
        matches.add_theme_constant_override("separation", 2)
        matches.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        row.add_child(matches)
        match_rows.append(matches)

        for match_index in range(piles[row_index]):
            var match := MatchstickButton.new()
            match.row_index = row_index
            match.match_index = match_index
            match.pressed.connect(_on_match_pressed.bind(row_index, match))
            matches.add_child(match)

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
    message_label.text = "Click a match to remove it. You may keep removing matches from that same row."
    _refresh_ui()


func _on_match_pressed(row_index: int, match: MatchstickButton) -> void:
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
    _animate_match_removal(match)
    message_label.text = "You removed %d match%s from Row %d. Keep clicking this row or press END MY TURN." % [removed_this_turn, "" if removed_this_turn == 1 else "es", row_index + 1]

    if _total_matches() == 0:
        _finish_game(false, "You took the final match. Under the video rule, the player who takes the last match loses.")
        return

    _refresh_ui()


func _finish_player_turn() -> void:
    if phase != Phase.PLAYER or removed_this_turn <= 0:
        return
    phase = Phase.COMPUTER
    message_label.text = "You removed %d match%s from Row %d. Now watch the computer's turn." % [removed_this_turn, "" if removed_this_turn == 1 else "es", selected_row + 1]
    _refresh_ui()
    _computer_turn(game_serial)


func _undo_player_turn() -> void:
    if phase != Phase.PLAYER or removed_this_turn <= 0:
        return
    piles = turn_start_piles.duplicate()
    selected_row = -1
    removed_this_turn = 0
    _build_match_rows()
    message_label.text = "Your picks were restored. Choose a row again."
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

    status_label.text = "COMPUTER'S TURN"
    substatus_label.text = "Computer chose Row %d…" % (row_index + 1)

    for step in range(amount):
        if serial != game_serial or phase != Phase.COMPUTER:
            return
        if piles[row_index] <= 0:
            break

        piles[row_index] -= 1
        _remove_one_computer_match(row_index)
        message_label.text = "Computer removes match %d of %d from Row %d." % [step + 1, amount, row_index + 1]
        _refresh_counts_only()

        if _total_matches() == 0:
            await get_tree().create_timer(0.3).timeout
            if serial == game_serial:
                _finish_game(true, "The computer took the final match, so the computer loses. You win!")
            return

        if step < amount - 1:
            await get_tree().create_timer(COMPUTER_MATCH_DELAY).timeout

    if serial != game_serial:
        return

    phase = Phase.WAIT_PLAYER
    message_label.text = "Computer removed %d match%s from Row %d. Press START MY TURN when you're ready." % [amount, "" if amount == 1 else "es", row_index + 1]
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

    # Endgame: every remaining heap is a singleton.
    if big_count == 0:
        for i in range(piles.size()):
            if piles[i] == 1:
                return {"row": i, "amount": 1}

    # Exactly one heap is larger than one. Leave an odd number of singletons.
    if big_count == 1:
        if ones_count % 2 == 0:
            return {"row": big_index, "amount": piles[big_index] - 1}
        return {"row": big_index, "amount": piles[big_index]}

    # With two or more large heaps, misere Nim uses the normal XOR move.
    var x := _nim_sum()
    if x != 0:
        for i in range(piles.size()):
            var target := piles[i] ^ x
            if target < piles[i]:
                return {"row": i, "amount": piles[i] - target}

    # A zero Nim-sum is a losing position under perfect play. Make a varied legal move.
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
    for n in piles:
        result = result ^ n
    return result


func _animate_match_removal(match: MatchstickButton) -> void:
    if not is_instance_valid(match):
        return
    match.disabled = true
    var tween := create_tween()
    tween.set_parallel(true)
    tween.tween_property(match, "modulate:a", 0.0, 0.18)
    tween.tween_property(match, "position:y", match.position.y + 16.0, 0.18)
    tween.set_parallel(false)
    tween.tween_callback(match.queue_free)


func _remove_one_computer_match(row_index: int) -> void:
    if row_index < 0 or row_index >= match_rows.size():
        return
    var row := match_rows[row_index]
    var children := row.get_children()
    for i in range(children.size() - 1, -1, -1):
        var child := children[i]
        if child is MatchstickButton and not child.is_queued_for_deletion():
            _animate_match_removal(child)
            return


func _refresh_ui() -> void:
    _refresh_counts_only()
    _refresh_match_interaction()

    match phase:
        Phase.WAIT_PLAYER:
            status_label.text = "READY FOR YOUR TURN"
            status_label.add_theme_color_override("font_color", GREEN)
            substatus_label.text = "The board is paused until you press START MY TURN."
            action_button.text = "START MY TURN"
            action_button.disabled = false
            undo_button.disabled = true
        Phase.PLAYER:
            status_label.text = "YOUR TURN"
            status_label.add_theme_color_override("font_color", RED_DARK)
            if selected_row == -1:
                substatus_label.text = "Choose one row by clicking any match."
            else:
                substatus_label.text = "Row %d is locked in. Remove more from this row or end your turn." % (selected_row + 1)
            action_button.text = "END MY TURN →"
            action_button.disabled = removed_this_turn == 0
            undo_button.disabled = removed_this_turn == 0
        Phase.COMPUTER:
            status_label.text = "COMPUTER'S TURN"
            status_label.add_theme_color_override("font_color", RED_DARK)
            substatus_label.text = "Watch closely — the computer removes one match every 0.5 seconds."
            action_button.text = "COMPUTER'S TURN…"
            action_button.disabled = true
            undo_button.disabled = true
        Phase.GAME_OVER:
            status_label.text = "GAME OVER"
            status_label.add_theme_color_override("font_color", RED_DARK)
            substatus_label.text = "Start another classic 1–3–5–7 game whenever you're ready."
            action_button.text = "PLAY AGAIN"
            action_button.disabled = false
            undo_button.disabled = true


func _refresh_counts_only() -> void:
    remaining_label.text = "%d MATCH%s LEFT" % [_total_matches(), "" if _total_matches() == 1 else "ES"]
    for i in range(mini(count_labels.size(), piles.size())):
        count_labels[i].text = str(piles[i])


func _refresh_match_interaction() -> void:
    for row_index in range(match_rows.size()):
        var row_active := phase == Phase.PLAYER and (selected_row == -1 or selected_row == row_index)
        var row := match_rows[row_index]
        row.modulate = Color.WHITE if row_active or phase != Phase.PLAYER else Color(0.72, 0.68, 0.61, 0.55)
        for child in row.get_children():
            if child is MatchstickButton:
                child.set_active(row_active)


func _finish_game(player_won: bool, explanation: String) -> void:
    phase = Phase.GAME_OVER
    game_serial += 1
    selected_row = -1
    removed_this_turn = 0
    if player_won:
        message_label.text = "YOU WIN!  " + explanation
    else:
        message_label.text = "COMPUTER WINS.  " + explanation
    _refresh_ui()


func _total_matches() -> int:
    var total := 0
    for n in piles:
        total += n
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


func _make_paper_button(text_value: String) -> Button:
    return _make_button(text_value, false)


func _make_action_button(text_value: String) -> Button:
    return _make_button(text_value, true)


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
