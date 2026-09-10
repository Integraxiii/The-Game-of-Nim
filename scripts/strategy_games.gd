extends Control

# Math Society Strategy Games
# Includes normal-play Matchstick Nim and a counting-to-a-target strategy game.

const TABLE := Color("#241813")
const PAPER := Color("#f3ead6")
const PAPER_2 := Color("#e8dcc3")
const INK := Color("#29231f")
const MUTED := Color("#74685d")
const RED := Color("#8f3029")
const RED_DARK := Color("#68211d")
const GREEN := Color("#486f52")
const GREEN_LIGHT := Color("#86c995")
const LOSE_RED := Color("#e37a70")
const COMPUTER_MATCH_DELAY := 0.36
const COMPUTER_COUNT_DELAY := 0.24
const FIXED_NIM_PILES: Array[int] = [3, 5, 7]

enum GameMode { NONE, NIM, COUNTING }
enum Phase { WAITING, PLAYER, COMPUTER, GAME_OVER }

class MatchstickButton:
    extends Button
    var row_index := 0

    func _init() -> void:
        flat = true
        custom_minimum_size = Vector2(34, 66)
        focus_mode = Control.FOCUS_NONE
        mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
        add_theme_stylebox_override("focus", StyleBoxEmpty.new())

    func _draw() -> void:
        var cx := size.x * 0.5
        var opacity := 1.0 if not disabled else 0.34
        var shaft_top := 19.0
        var shaft_height := maxf(30.0, size.y - 24.0)
        draw_rect(Rect2(cx - 2.0, shaft_top + 2.0, 6.0, shaft_height), Color(0.16, 0.10, 0.06, 0.14 * opacity), true)
        draw_rect(Rect2(cx - 3.0, shaft_top, 6.0, shaft_height), Color(0.69, 0.50, 0.27, opacity), true)
        draw_rect(Rect2(cx - 1.2, shaft_top, 2.4, shaft_height), Color(0.91, 0.75, 0.46, opacity), true)
        draw_circle(Vector2(cx, 13.0), 7.0, Color(0.40, 0.11, 0.09, opacity))
        draw_circle(Vector2(cx - 0.8, 12.2), 5.3, Color(0.58, 0.18, 0.15, opacity))
        if not disabled and is_hovered():
            draw_arc(Vector2(cx, 13.0), 10.0, 0.0, TAU, 24, Color(0.55, 0.19, 0.16, 0.75), 2.0)

    func set_turn_enabled(value: bool) -> void:
        disabled = not value
        mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if value else Control.CURSOR_ARROW
        queue_redraw()

var rng := RandomNumberGenerator.new()
var game_mode: GameMode = GameMode.NONE
var phase: Phase = Phase.WAITING
var screen_host: Control
var game_serial := 0

# Shared opponent/turn state. Player 1 = human 1 / You. Player 2 = human 2 / Computer.
var versus_computer := true
var current_player := 1
var first_player := 1

# Setup controls
var nim_opponent_select: OptionButton
var nim_arrangement_select: OptionButton
var nim_first_select: OptionButton
var count_opponent_select: OptionButton
var count_target_select: OptionButton
var count_custom_target: SpinBox
var count_max_step: SpinBox
var count_first_select: OptionButton

# Nim state / controls
var nim_random_setup := false
var piles: Array[int] = FIXED_NIM_PILES.duplicate()
var turn_start_piles: Array[int] = []
var selected_row := -1
var removed_this_turn := 0
var nim_rows_box: VBoxContainer
var nim_status_label: Label
var nim_substatus_label: Label
var nim_remaining_label: Label
var nim_setup_label: Label
var nim_message_label: Label
var nim_action_button: Button
var nim_undo_button: Button

# Counting state / controls
var count_target := 21
var count_max_per_turn := 3
var count_current := 0
var count_history: Array[String] = []
var count_status_label: Label
var count_substatus_label: Label
var count_number_label: Label
var count_progress_label: Label
var count_history_label: Label
var count_choice_buttons: Array[Button] = []
var count_message_label: Label

# Overlays
var ready_overlay: Control
var result_overlay: Control
var result_panel: PanelContainer
var result_title: Label
var result_subtitle: Label

# Audio
var effect_player: AudioStreamPlayer
var result_sound_player: AudioStreamPlayer
var click_sound: AudioStreamWAV
var win_sound: AudioStreamWAV
var lose_sound: AudioStreamWAV

func _ready() -> void:
    rng.randomize()
    _build_base()
    _build_audio()
    _show_main_menu()

func _build_base() -> void:
    var bg := ColorRect.new()
    bg.color = TABLE
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(bg)

    screen_host = Control.new()
    screen_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(screen_host)

func _build_audio() -> void:
    effect_player = AudioStreamPlayer.new()
    effect_player.volume_db = -6.0
    add_child(effect_player)

    result_sound_player = AudioStreamPlayer.new()
    result_sound_player.volume_db = -2.0
    add_child(result_sound_player)

    click_sound = _make_tone_sequence([2200.0, 3350.0], 0.024, 0.22)
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

func _play_click_sound() -> void:
    if effect_player == null or click_sound == null:
        return
    effect_player.stream = click_sound
    effect_player.pitch_scale = rng.randf_range(0.93, 1.07)
    effect_player.play()

func _play_result_sound(human_win: bool) -> void:
    if result_sound_player == null:
        return
    result_sound_player.stream = win_sound if human_win else lose_sound
    result_sound_player.pitch_scale = 1.0
    result_sound_player.play()

# -----------------------------------------------------------------------------
# Main menu / setup screens
# -----------------------------------------------------------------------------

func _show_main_menu() -> void:
    game_serial += 1
    game_mode = GameMode.NONE
    phase = Phase.WAITING
    _clear_screen()

    var outer := MarginContainer.new()
    outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    outer.add_theme_constant_override("margin_left", 80)
    outer.add_theme_constant_override("margin_right", 80)
    outer.add_theme_constant_override("margin_top", 42)
    outer.add_theme_constant_override("margin_bottom", 42)
    screen_host.add_child(outer)

    var main := VBoxContainer.new()
    main.alignment = BoxContainer.ALIGNMENT_CENTER
    main.add_theme_constant_override("separation", 18)
    outer.add_child(main)

    var eyebrow := Label.new()
    eyebrow.text = "MATH SOCIETY"
    eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    eyebrow.add_theme_color_override("font_color", Color("#cfbea9"))
    eyebrow.add_theme_font_size_override("font_size", 16)
    main.add_child(eyebrow)

    var title := Label.new()
    title.text = "STRATEGY GAMES"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_color_override("font_color", PAPER)
    title.add_theme_font_size_override("font_size", 46)
    main.add_child(title)

    var subtitle := Label.new()
    subtitle.text = "Choose a game, set up the round, then see if you can discover the winning pattern."
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle.add_theme_color_override("font_color", Color("#cfbea9"))
    subtitle.add_theme_font_size_override("font_size", 15)
    main.add_child(subtitle)

    var cards := HBoxContainer.new()
    cards.alignment = BoxContainer.ALIGNMENT_CENTER
    cards.add_theme_constant_override("separation", 24)
    cards.custom_minimum_size.y = 310
    main.add_child(cards)

    cards.add_child(_make_game_card(
        "MATCHSTICK NIM",
        "Remove one or more matches from ONE row.\nControl the board and take the final match to win.",
        "CHOOSE NIM",
        _show_nim_setup
    ))
    cards.add_child(_make_game_card(
        "COUNTING GAME",
        "Count upward toward a target.\nChoose how many numbers to say and try to land on the target.",
        "CHOOSE COUNTING",
        _show_count_setup
    ))

    var footer := Label.new()
    footer.text = "Two games. Same idea: find the positions that put your opponent in trouble."
    footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    footer.add_theme_color_override("font_color", Color("#a9957d"))
    footer.add_theme_font_size_override("font_size", 12)
    main.add_child(footer)

func _make_game_card(title_text: String, body_text: String, button_text: String, callback: Callable) -> PanelContainer:
    var card := PanelContainer.new()
    card.custom_minimum_size = Vector2(470, 270)
    card.add_theme_stylebox_override("panel", _style(PAPER, 16, 2, Color("#c6b594")))

    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 30)
    margin.add_theme_constant_override("margin_right", 30)
    margin.add_theme_constant_override("margin_top", 26)
    margin.add_theme_constant_override("margin_bottom", 26)
    card.add_child(margin)

    var box := VBoxContainer.new()
    box.alignment = BoxContainer.ALIGNMENT_CENTER
    box.add_theme_constant_override("separation", 18)
    margin.add_child(box)

    var title := Label.new()
    title.text = title_text
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_color_override("font_color", INK)
    title.add_theme_font_size_override("font_size", 28)
    box.add_child(title)

    var body := Label.new()
    body.text = body_text
    body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    body.size_flags_vertical = Control.SIZE_EXPAND_FILL
    body.add_theme_color_override("font_color", MUTED)
    body.add_theme_font_size_override("font_size", 15)
    box.add_child(body)

    var choose := _make_button(button_text, true)
    choose.custom_minimum_size = Vector2(250, 48)
    choose.pressed.connect(callback)
    box.add_child(choose)
    return card

func _show_nim_setup() -> void:
    game_serial += 1
    game_mode = GameMode.NIM
    phase = Phase.WAITING
    _clear_screen()

    var panel := _make_setup_shell("MATCHSTICK NIM", "Choose the opponent and starting arrangement.", _show_main_menu)
    var body = panel.get_meta("body")

    nim_opponent_select = _add_option_row(body, "OPPONENT", ["Player vs Player", "Player vs Computer"], 1)
    nim_opponent_select.item_selected.connect(_on_nim_opponent_changed)

    nim_arrangement_select = _add_option_row(body, "ARRANGEMENT", ["3 - 5 - 7", "Random (3 piles, 1-7 each)"], 0)
    nim_first_select = _add_option_row(body, "FIRST TURN", ["You", "Computer"], 0)

    var rule_note := Label.new()
    rule_note.text = "Rule: remove one or more matches from exactly ONE row. The player who takes the final match wins."
    rule_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    rule_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    rule_note.add_theme_color_override("font_color", MUTED)
    rule_note.add_theme_font_size_override("font_size", 13)
    body.add_child(rule_note)

    var play := _make_button("PLAY NIM", true)
    play.custom_minimum_size = Vector2(260, 48)
    play.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    play.pressed.connect(_accept_nim_setup)
    body.add_child(play)

func _on_nim_opponent_changed(_index: int) -> void:
    if nim_first_select == null:
        return
    nim_first_select.clear()
    if nim_opponent_select.selected == 1:
        nim_first_select.add_item("You")
        nim_first_select.add_item("Computer")
    else:
        nim_first_select.add_item("Player 1")
        nim_first_select.add_item("Player 2")
    nim_first_select.selected = 0

func _accept_nim_setup() -> void:
    versus_computer = nim_opponent_select.selected == 1
    nim_random_setup = nim_arrangement_select.selected == 1
    first_player = nim_first_select.selected + 1
    _prepare_nim_round()

func _show_count_setup() -> void:
    game_serial += 1
    game_mode = GameMode.COUNTING
    phase = Phase.WAITING
    _clear_screen()

    var panel := _make_setup_shell("COUNTING GAME", "Choose the opponent, target, and how many numbers can be said each turn.", _show_main_menu)
    var body = panel.get_meta("body")

    count_opponent_select = _add_option_row(body, "OPPONENT", ["Player vs Player", "Player vs Computer"], 1)
    count_opponent_select.item_selected.connect(_on_count_opponent_changed)

    count_target_select = _add_option_row(body, "TARGET", ["21", "31", "Custom"], 0)

    var custom_row := HBoxContainer.new()
    custom_row.alignment = BoxContainer.ALIGNMENT_CENTER
    custom_row.add_theme_constant_override("separation", 14)
    body.add_child(custom_row)
    var custom_label := Label.new()
    custom_label.text = "CUSTOM TARGET"
    custom_label.custom_minimum_size.x = 180
    custom_label.add_theme_color_override("font_color", MUTED)
    custom_label.add_theme_font_size_override("font_size", 12)
    custom_row.add_child(custom_label)
    count_custom_target = SpinBox.new()
    count_custom_target.min_value = 5
    count_custom_target.max_value = 99
    count_custom_target.step = 1
    count_custom_target.value = 21
    count_custom_target.custom_minimum_size = Vector2(220, 38)
    custom_row.add_child(count_custom_target)
    var hint := Label.new()
    hint.text = "Used when Target = Custom"
    hint.add_theme_color_override("font_color", MUTED)
    hint.add_theme_font_size_override("font_size", 11)
    custom_row.add_child(hint)

    var max_row := HBoxContainer.new()
    max_row.alignment = BoxContainer.ALIGNMENT_CENTER
    max_row.add_theme_constant_override("separation", 14)
    body.add_child(max_row)
    var max_label := Label.new()
    max_label.text = "NUMBERS PER TURN"
    max_label.custom_minimum_size.x = 180
    max_label.add_theme_color_override("font_color", MUTED)
    max_label.add_theme_font_size_override("font_size", 12)
    max_row.add_child(max_label)
    count_max_step = SpinBox.new()
    count_max_step.min_value = 2
    count_max_step.max_value = 6
    count_max_step.step = 1
    count_max_step.value = 3
    count_max_step.custom_minimum_size = Vector2(220, 38)
    max_row.add_child(count_max_step)
    var max_hint := Label.new()
    max_hint.text = "Example: 3 means choose +1, +2, or +3"
    max_hint.add_theme_color_override("font_color", MUTED)
    max_hint.add_theme_font_size_override("font_size", 11)
    max_row.add_child(max_hint)

    count_first_select = _add_option_row(body, "FIRST TURN", ["You", "Computer"], 0)

    var rule_note := Label.new()
    rule_note.text = "The target number WINS. Each choice says that many consecutive numbers."
    rule_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    rule_note.add_theme_color_override("font_color", MUTED)
    rule_note.add_theme_font_size_override("font_size", 13)
    body.add_child(rule_note)

    var play := _make_button("PLAY COUNTING GAME", true)
    play.custom_minimum_size = Vector2(290, 48)
    play.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    play.pressed.connect(_accept_count_setup)
    body.add_child(play)

func _on_count_opponent_changed(_index: int) -> void:
    if count_first_select == null:
        return
    count_first_select.clear()
    if count_opponent_select.selected == 1:
        count_first_select.add_item("You")
        count_first_select.add_item("Computer")
    else:
        count_first_select.add_item("Player 1")
        count_first_select.add_item("Player 2")
    count_first_select.selected = 0

func _accept_count_setup() -> void:
    versus_computer = count_opponent_select.selected == 1
    first_player = count_first_select.selected + 1
    if count_target_select.selected == 0:
        count_target = 21
    elif count_target_select.selected == 1:
        count_target = 31
    else:
        count_target = int(count_custom_target.value)
    count_max_per_turn = int(count_max_step.value)
    count_max_per_turn = mini(count_max_per_turn, maxi(1, count_target - 1))
    _prepare_count_round()

func _make_setup_shell(title_text: String, subtitle_text: String, back_callback: Callable) -> PanelContainer:
    var outer := MarginContainer.new()
    outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    outer.add_theme_constant_override("margin_left", 190)
    outer.add_theme_constant_override("margin_right", 190)
    outer.add_theme_constant_override("margin_top", 42)
    outer.add_theme_constant_override("margin_bottom", 42)
    screen_host.add_child(outer)

    var panel := PanelContainer.new()
    panel.add_theme_stylebox_override("panel", _style(PAPER, 16, 2, Color("#c6b594")))
    outer.add_child(panel)

    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 38)
    margin.add_theme_constant_override("margin_right", 38)
    margin.add_theme_constant_override("margin_top", 24)
    margin.add_theme_constant_override("margin_bottom", 24)
    panel.add_child(margin)

    var body := VBoxContainer.new()
    body.alignment = BoxContainer.ALIGNMENT_CENTER
    body.add_theme_constant_override("separation", 12)
    margin.add_child(body)

    var top := HBoxContainer.new()
    body.add_child(top)
    var back := _make_button("< MAIN MENU", false)
    back.custom_minimum_size = Vector2(135, 34)
    back.pressed.connect(back_callback)
    top.add_child(back)
    var spacer := Control.new()
    spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    top.add_child(spacer)

    var title := Label.new()
    title.text = title_text
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_color_override("font_color", INK)
    title.add_theme_font_size_override("font_size", 32)
    body.add_child(title)

    var subtitle := Label.new()
    subtitle.text = subtitle_text
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle.add_theme_color_override("font_color", MUTED)
    subtitle.add_theme_font_size_override("font_size", 14)
    body.add_child(subtitle)
    body.add_child(HSeparator.new())

    panel.set_meta("body", body)
    return panel

func _add_option_row(parent: VBoxContainer, label_text: String, items: Array, selected_index: int) -> OptionButton:
    var row := HBoxContainer.new()
    row.alignment = BoxContainer.ALIGNMENT_CENTER
    row.add_theme_constant_override("separation", 14)
    parent.add_child(row)

    var label := Label.new()
    label.text = label_text
    label.custom_minimum_size.x = 180
    label.add_theme_color_override("font_color", MUTED)
    label.add_theme_font_size_override("font_size", 12)
    row.add_child(label)

    var option := OptionButton.new()
    option.custom_minimum_size = Vector2(340, 38)
    for item in items:
        option.add_item(item)
    option.selected = selected_index
    row.add_child(option)
    return option

# -----------------------------------------------------------------------------
# Matchstick Nim
# -----------------------------------------------------------------------------

func _prepare_nim_round() -> void:
    game_serial += 1
    game_mode = GameMode.NIM
    phase = Phase.WAITING
    current_player = first_player
    if nim_random_setup:
        piles = [rng.randi_range(1, 7), rng.randi_range(1, 7), rng.randi_range(1, 7)]
    else:
        piles = FIXED_NIM_PILES.duplicate()
    turn_start_piles = piles.duplicate()
    selected_row = -1
    removed_this_turn = 0
    _build_nim_game_screen()
    _show_ready_popup(
        "READY TO PLAY?",
        "Remove one or more matches from exactly ONE row during your turn.\nThe player who takes the FINAL match WINS.",
        _start_nim_after_ready
    )

func _build_nim_game_screen() -> void:
    _clear_screen()

    var outer := MarginContainer.new()
    outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    outer.add_theme_constant_override("margin_left", 12)
    outer.add_theme_constant_override("margin_right", 12)
    outer.add_theme_constant_override("margin_top", 8)
    outer.add_theme_constant_override("margin_bottom", 8)
    screen_host.add_child(outer)

    var main := VBoxContainer.new()
    main.size_flags_vertical = Control.SIZE_EXPAND_FILL
    main.add_theme_constant_override("separation", 5)
    outer.add_child(main)

    var header := HBoxContainer.new()
    header.custom_minimum_size.y = 48
    main.add_child(header)

    var title_box := VBoxContainer.new()
    title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(title_box)
    var title := Label.new()
    title.text = "MATCHSTICK NIM"
    title.add_theme_color_override("font_color", PAPER)
    title.add_theme_font_size_override("font_size", 25)
    title_box.add_child(title)
    var subtitle := Label.new()
    subtitle.text = ("Player vs Computer" if versus_computer else "Player vs Player") + "  •  " + ("Random setup" if nim_random_setup else "3 - 5 - 7") + "  •  Last match wins"
    subtitle.add_theme_color_override("font_color", Color("#cfbea9"))
    subtitle.add_theme_font_size_override("font_size", 11)
    title_box.add_child(subtitle)

    var menu_button := _make_button("GAME SETUP", false)
    menu_button.custom_minimum_size = Vector2(120, 34)
    menu_button.pressed.connect(_show_nim_setup)
    header.add_child(menu_button)
    var main_menu := _make_button("MAIN MENU", false)
    main_menu.custom_minimum_size = Vector2(115, 34)
    main_menu.pressed.connect(_show_main_menu)
    header.add_child(main_menu)

    var board := PanelContainer.new()
    board.size_flags_vertical = Control.SIZE_EXPAND_FILL
    board.add_theme_stylebox_override("panel", _style(PAPER, 12, 2, Color("#c6b594")))
    main.add_child(board)

    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 14)
    margin.add_theme_constant_override("margin_right", 14)
    margin.add_theme_constant_override("margin_top", 10)
    margin.add_theme_constant_override("margin_bottom", 10)
    board.add_child(margin)

    var board_v := VBoxContainer.new()
    board_v.size_flags_vertical = Control.SIZE_EXPAND_FILL
    board_v.add_theme_constant_override("separation", 2)
    margin.add_child(board_v)

    var top := HBoxContainer.new()
    top.custom_minimum_size.y = 40
    board_v.add_child(top)
    var status_box := VBoxContainer.new()
    status_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    top.add_child(status_box)
    nim_status_label = Label.new()
    nim_status_label.add_theme_color_override("font_color", INK)
    nim_status_label.add_theme_font_size_override("font_size", 18)
    status_box.add_child(nim_status_label)
    nim_substatus_label = Label.new()
    nim_substatus_label.add_theme_color_override("font_color", MUTED)
    nim_substatus_label.add_theme_font_size_override("font_size", 10)
    status_box.add_child(nim_substatus_label)

    var info := VBoxContainer.new()
    top.add_child(info)
    nim_remaining_label = Label.new()
    nim_remaining_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    nim_remaining_label.add_theme_color_override("font_color", MUTED)
    nim_remaining_label.add_theme_font_size_override("font_size", 11)
    info.add_child(nim_remaining_label)
    nim_setup_label = Label.new()
    nim_setup_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    nim_setup_label.add_theme_color_override("font_color", INK)
    nim_setup_label.add_theme_font_size_override("font_size", 11)
    info.add_child(nim_setup_label)

    var rule := Label.new()
    rule.text = "Remove one or more matches from ONE row only  •  Taking the LAST match WINS"
    rule.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    rule.add_theme_color_override("font_color", MUTED)
    rule.add_theme_font_size_override("font_size", 10)
    board_v.add_child(rule)
    board_v.add_child(HSeparator.new())

    nim_rows_box = VBoxContainer.new()
    nim_rows_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
    nim_rows_box.add_theme_constant_override("separation", 0)
    board_v.add_child(nim_rows_box)
    board_v.add_child(HSeparator.new())

    nim_message_label = Label.new()
    nim_message_label.custom_minimum_size.y = 24
    nim_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    nim_message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    nim_message_label.add_theme_color_override("font_color", INK)
    nim_message_label.add_theme_font_size_override("font_size", 11)
    board_v.add_child(nim_message_label)

    var actions := HBoxContainer.new()
    actions.custom_minimum_size.y = 38
    actions.alignment = BoxContainer.ALIGNMENT_CENTER
    actions.add_theme_constant_override("separation", 8)
    board_v.add_child(actions)
    nim_undo_button = _make_button("UNDO PICKS", false)
    nim_undo_button.custom_minimum_size = Vector2(120, 34)
    nim_undo_button.pressed.connect(_undo_nim_turn)
    actions.add_child(nim_undo_button)
    nim_action_button = _make_button("END TURN", true)
    nim_action_button.custom_minimum_size = Vector2(180, 36)
    nim_action_button.pressed.connect(_end_nim_turn)
    actions.add_child(nim_action_button)

    _render_nim_rows()
    _update_nim_ui()

func _start_nim_after_ready() -> void:
    _hide_ready_popup()
    _begin_nim_turn()

func _begin_nim_turn() -> void:
    if game_mode != GameMode.NIM or phase == Phase.GAME_OVER:
        return
    selected_row = -1
    removed_this_turn = 0
    turn_start_piles = piles.duplicate()
    if _is_computer_turn():
        phase = Phase.COMPUTER
        _update_nim_ui()
        var serial := game_serial
        _computer_nim_turn(serial)
    else:
        phase = Phase.PLAYER
        _update_nim_ui()
        _render_nim_rows()

func _render_nim_rows() -> void:
    if nim_rows_box == null:
        return
    _clear_container(nim_rows_box)

    for row_index in range(piles.size()):
        var row := HBoxContainer.new()
        row.custom_minimum_size.y = 78
        row.alignment = BoxContainer.ALIGNMENT_CENTER
        row.add_theme_constant_override("separation", 2)
        nim_rows_box.add_child(row)

        var row_label := Label.new()
        row_label.text = "ROW %d" % (row_index + 1)
        row_label.custom_minimum_size.x = 100
        row_label.add_theme_color_override("font_color", MUTED)
        row_label.add_theme_font_size_override("font_size", 13)
        row.add_child(row_label)

        var pile_holder := HBoxContainer.new()
        pile_holder.custom_minimum_size.x = 430
        pile_holder.alignment = BoxContainer.ALIGNMENT_CENTER
        pile_holder.add_theme_constant_override("separation", 2)
        row.add_child(pile_holder)

        for _match_index in range(piles[row_index]):
            var match_button := MatchstickButton.new()
            match_button.row_index = row_index
            match_button.set_turn_enabled(phase == Phase.PLAYER and (selected_row == -1 or selected_row == row_index))
            match_button.pressed.connect(_on_nim_match_pressed.bind(row_index))
            pile_holder.add_child(match_button)

        var count := Label.new()
        count.text = "%d left" % piles[row_index]
        count.custom_minimum_size.x = 90
        count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        count.add_theme_color_override("font_color", INK)
        count.add_theme_font_size_override("font_size", 12)
        row.add_child(count)

func _on_nim_match_pressed(row_index: int) -> void:
    if phase != Phase.PLAYER or game_mode != GameMode.NIM:
        return
    if row_index < 0 or row_index >= piles.size() or piles[row_index] <= 0:
        return
    if selected_row != -1 and selected_row != row_index:
        nim_message_label.text = "You already chose a row this turn. Finish or undo before changing rows."
        return

    selected_row = row_index
    piles[row_index] -= 1
    removed_this_turn += 1
    _play_click_sound()
    _render_nim_rows()
    _update_nim_ui()

    if _nim_total() == 0:
        _finish_round(current_player, _actor_name(current_player) + " took the final match.")

func _undo_nim_turn() -> void:
    if phase != Phase.PLAYER or removed_this_turn == 0:
        return
    piles = turn_start_piles.duplicate()
    selected_row = -1
    removed_this_turn = 0
    nim_message_label.text = "Turn restored. Choose any one row."
    _render_nim_rows()
    _update_nim_ui()

func _end_nim_turn() -> void:
    if phase != Phase.PLAYER or removed_this_turn <= 0 or _nim_total() == 0:
        return
    current_player = 3 - current_player
    _begin_nim_turn()

func _computer_nim_turn(serial: int) -> void:
    if phase != Phase.COMPUTER:
        return
    nim_message_label.text = "Computer is thinking..."
    await get_tree().create_timer(0.48).timeout
    if serial != game_serial or game_mode != GameMode.NIM or phase != Phase.COMPUTER:
        return

    var move := _best_nim_move()
    var row_index := move.x
    var amount := move.y
    nim_message_label.text = "Computer chose row %d." % (row_index + 1)

    for _i in range(amount):
        await get_tree().create_timer(COMPUTER_MATCH_DELAY).timeout
        if serial != game_serial or game_mode != GameMode.NIM or phase != Phase.COMPUTER:
            return
        piles[row_index] -= 1
        _play_click_sound()
        _render_nim_rows()
        _update_nim_ui()

    if _nim_total() == 0:
        _finish_round(2, "The computer took the final match.")
        return

    current_player = 1
    _begin_nim_turn()

func _best_nim_move() -> Vector2i:
    var nim_sum := 0
    for pile in piles:
        nim_sum = nim_sum ^ pile

    if nim_sum != 0:
        for row_index in range(piles.size()):
            var target := piles[row_index] ^ nim_sum
            if target < piles[row_index]:
                return Vector2i(row_index, piles[row_index] - target)

    var legal_rows: Array[int] = []
    for row_index in range(piles.size()):
        if piles[row_index] > 0:
            legal_rows.append(row_index)
    var random_row := legal_rows[rng.randi_range(0, legal_rows.size() - 1)]
    return Vector2i(random_row, rng.randi_range(1, piles[random_row]))

func _nim_total() -> int:
    var total := 0
    for pile in piles:
        total += pile
    return total

func _update_nim_ui() -> void:
    if nim_status_label == null:
        return
    nim_remaining_label.text = "%d matches remaining" % _nim_total()
    var setup_parts: Array[String] = []
    for pile in piles:
        setup_parts.append(str(pile))
    nim_setup_label.text = "Current: " + " - ".join(PackedStringArray(setup_parts))

    if phase == Phase.WAITING:
        nim_status_label.text = "ROUND READY"
        nim_substatus_label.text = "Press START ROUND in the popup."
        nim_message_label.text = "Board locked until the round starts."
    elif phase == Phase.COMPUTER:
        nim_status_label.text = "COMPUTER'S TURN"
        nim_substatus_label.text = "Watch the computer remove matches one at a time."
    elif phase == Phase.PLAYER:
        nim_status_label.text = _actor_name(current_player).to_upper() + "'S TURN"
        if removed_this_turn == 0:
            nim_substatus_label.text = "Choose a row and remove one or more matches."
            nim_message_label.text = "Click a match to remove it."
        else:
            nim_substatus_label.text = "You may keep removing from row %d, then end the turn." % (selected_row + 1)
            nim_message_label.text = "%d removed this turn." % removed_this_turn

    if nim_action_button != null:
        nim_action_button.disabled = phase != Phase.PLAYER or removed_this_turn == 0
    if nim_undo_button != null:
        nim_undo_button.disabled = phase != Phase.PLAYER or removed_this_turn == 0

# -----------------------------------------------------------------------------
# Counting game
# -----------------------------------------------------------------------------

func _prepare_count_round() -> void:
    game_serial += 1
    game_mode = GameMode.COUNTING
    phase = Phase.WAITING
    current_player = first_player
    count_current = 0
    count_history.clear()
    _build_count_game_screen()
    _show_ready_popup(
        "READY TO COUNT?",
        "Start at 0. On each turn, choose to advance by 1 to %d.\nWhoever reaches %d WINS." % [count_max_per_turn, count_target],
        _start_count_after_ready
    )

func _build_count_game_screen() -> void:
    _clear_screen()

    var outer := MarginContainer.new()
    outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    outer.add_theme_constant_override("margin_left", 12)
    outer.add_theme_constant_override("margin_right", 12)
    outer.add_theme_constant_override("margin_top", 8)
    outer.add_theme_constant_override("margin_bottom", 8)
    screen_host.add_child(outer)

    var main := VBoxContainer.new()
    main.size_flags_vertical = Control.SIZE_EXPAND_FILL
    main.add_theme_constant_override("separation", 5)
    outer.add_child(main)

    var header := HBoxContainer.new()
    header.custom_minimum_size.y = 48
    main.add_child(header)
    var title_box := VBoxContainer.new()
    title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(title_box)
    var title := Label.new()
    title.text = "COUNTING GAME"
    title.add_theme_color_override("font_color", PAPER)
    title.add_theme_font_size_override("font_size", 25)
    title_box.add_child(title)
    var subtitle := Label.new()
    subtitle.text = ("Player vs Computer" if versus_computer else "Player vs Player") + "  •  Target: %d  •  Choose +1 to +%d  •  Target wins" % [count_target, count_max_per_turn]
    subtitle.add_theme_color_override("font_color", Color("#cfbea9"))
    subtitle.add_theme_font_size_override("font_size", 11)
    title_box.add_child(subtitle)

    var setup_button := _make_button("GAME SETUP", false)
    setup_button.custom_minimum_size = Vector2(120, 34)
    setup_button.pressed.connect(_show_count_setup)
    header.add_child(setup_button)
    var main_menu := _make_button("MAIN MENU", false)
    main_menu.custom_minimum_size = Vector2(115, 34)
    main_menu.pressed.connect(_show_main_menu)
    header.add_child(main_menu)

    var board := PanelContainer.new()
    board.size_flags_vertical = Control.SIZE_EXPAND_FILL
    board.add_theme_stylebox_override("panel", _style(PAPER, 12, 2, Color("#c6b594")))
    main.add_child(board)

    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 22)
    margin.add_theme_constant_override("margin_right", 22)
    margin.add_theme_constant_override("margin_top", 12)
    margin.add_theme_constant_override("margin_bottom", 12)
    board.add_child(margin)

    var board_v := VBoxContainer.new()
    board_v.size_flags_vertical = Control.SIZE_EXPAND_FILL
    board_v.add_theme_constant_override("separation", 5)
    margin.add_child(board_v)

    var top := HBoxContainer.new()
    top.custom_minimum_size.y = 42
    board_v.add_child(top)
    var status_box := VBoxContainer.new()
    status_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    top.add_child(status_box)
    count_status_label = Label.new()
    count_status_label.add_theme_color_override("font_color", INK)
    count_status_label.add_theme_font_size_override("font_size", 18)
    status_box.add_child(count_status_label)
    count_substatus_label = Label.new()
    count_substatus_label.add_theme_color_override("font_color", MUTED)
    count_substatus_label.add_theme_font_size_override("font_size", 10)
    status_box.add_child(count_substatus_label)

    count_progress_label = Label.new()
    count_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    count_progress_label.add_theme_color_override("font_color", MUTED)
    count_progress_label.add_theme_font_size_override("font_size", 12)
    top.add_child(count_progress_label)

    var center := HBoxContainer.new()
    center.size_flags_vertical = Control.SIZE_EXPAND_FILL
    center.add_theme_constant_override("separation", 24)
    board_v.add_child(center)

    var number_panel := PanelContainer.new()
    number_panel.custom_minimum_size = Vector2(460, 300)
    number_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    number_panel.add_theme_stylebox_override("panel", _style(PAPER_2, 12, 1, Color("#c6b594")))
    center.add_child(number_panel)
    var number_box := VBoxContainer.new()
    number_box.alignment = BoxContainer.ALIGNMENT_CENTER
    number_box.add_theme_constant_override("separation", 12)
    number_panel.add_child(number_box)
    var target_label := Label.new()
    target_label.text = "TARGET %d" % count_target
    target_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    target_label.add_theme_color_override("font_color", MUTED)
    target_label.add_theme_font_size_override("font_size", 16)
    number_box.add_child(target_label)
    count_number_label = Label.new()
    count_number_label.text = "0"
    count_number_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    count_number_label.add_theme_color_override("font_color", RED_DARK)
    count_number_label.add_theme_font_size_override("font_size", 92)
    number_box.add_child(count_number_label)
    var choose_hint := Label.new()
    choose_hint.text = "How many numbers will you say?"
    choose_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    choose_hint.add_theme_color_override("font_color", MUTED)
    choose_hint.add_theme_font_size_override("font_size", 12)
    number_box.add_child(choose_hint)

    var choices := HBoxContainer.new()
    choices.alignment = BoxContainer.ALIGNMENT_CENTER
    choices.add_theme_constant_override("separation", 8)
    number_box.add_child(choices)
    count_choice_buttons.clear()
    for amount in range(1, count_max_per_turn + 1):
        var choice := _make_button("+%d" % amount, true)
        choice.custom_minimum_size = Vector2(68, 44)
        choice.pressed.connect(_on_count_choice.bind(amount))
        choices.add_child(choice)
        count_choice_buttons.append(choice)

    var history_panel := PanelContainer.new()
    history_panel.custom_minimum_size = Vector2(470, 300)
    history_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    history_panel.add_theme_stylebox_override("panel", _style(Color("#fffaf0"), 12, 1, Color("#c6b594")))
    center.add_child(history_panel)
    var history_margin := MarginContainer.new()
    history_margin.add_theme_constant_override("margin_left", 18)
    history_margin.add_theme_constant_override("margin_right", 18)
    history_margin.add_theme_constant_override("margin_top", 14)
    history_margin.add_theme_constant_override("margin_bottom", 14)
    history_panel.add_child(history_margin)
    var history_box := VBoxContainer.new()
    history_box.add_theme_constant_override("separation", 8)
    history_margin.add_child(history_box)
    var history_title := Label.new()
    history_title.text = "TURN HISTORY"
    history_title.add_theme_color_override("font_color", INK)
    history_title.add_theme_font_size_override("font_size", 16)
    history_box.add_child(history_title)
    count_history_label = Label.new()
    count_history_label.text = "No turns yet."
    count_history_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    count_history_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
    count_history_label.add_theme_color_override("font_color", MUTED)
    count_history_label.add_theme_font_size_override("font_size", 14)
    history_box.add_child(count_history_label)

    count_message_label = Label.new()
    count_message_label.custom_minimum_size.y = 26
    count_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    count_message_label.add_theme_color_override("font_color", INK)
    count_message_label.add_theme_font_size_override("font_size", 12)
    board_v.add_child(count_message_label)

    _update_count_ui()

func _start_count_after_ready() -> void:
    _hide_ready_popup()
    _begin_count_turn()

func _begin_count_turn() -> void:
    if game_mode != GameMode.COUNTING or phase == Phase.GAME_OVER:
        return
    if _is_computer_turn():
        phase = Phase.COMPUTER
        _update_count_ui()
        var serial := game_serial
        _computer_count_turn(serial)
    else:
        phase = Phase.PLAYER
        _update_count_ui()

func _on_count_choice(amount: int) -> void:
    if phase != Phase.PLAYER or game_mode != GameMode.COUNTING:
        return
    if amount < 1 or amount > count_max_per_turn or count_current + amount > count_target:
        return

    var spoken := _advance_count(amount)
    count_history.append(_actor_name(current_player) + ": " + spoken)
    _play_click_sound()
    _update_count_ui()

    if count_current == count_target:
        _finish_round(current_player, _actor_name(current_player) + " reached %d." % count_target)
        return

    current_player = 3 - current_player
    _begin_count_turn()

func _computer_count_turn(serial: int) -> void:
    if phase != Phase.COMPUTER:
        return
    count_message_label.text = "Computer is choosing..."
    await get_tree().create_timer(0.5).timeout
    if serial != game_serial or game_mode != GameMode.COUNTING or phase != Phase.COMPUTER:
        return

    var remaining := count_target - count_current
    var amount := mini(count_max_per_turn, remaining)
    if remaining > count_max_per_turn:
        var winning_amount := remaining % (count_max_per_turn + 1)
        if winning_amount == 0:
            amount = rng.randi_range(1, mini(count_max_per_turn, remaining))
        else:
            amount = winning_amount

    var start_number := count_current + 1
    for _i in range(amount):
        await get_tree().create_timer(COMPUTER_COUNT_DELAY).timeout
        if serial != game_serial or game_mode != GameMode.COUNTING or phase != Phase.COMPUTER:
            return
        count_current += 1
        _play_click_sound()
        _update_count_ui()

    var spoken_numbers: Array[String] = []
    for value in range(start_number, count_current + 1):
        spoken_numbers.append(str(value))
    count_history.append("Computer: " + ", ".join(PackedStringArray(spoken_numbers)))
    _update_count_ui()

    if count_current == count_target:
        _finish_round(2, "The computer reached %d." % count_target)
        return

    current_player = 1
    _begin_count_turn()

func _advance_count(amount: int) -> String:
    var spoken_numbers: Array[String] = []
    for _i in range(amount):
        count_current += 1
        spoken_numbers.append(str(count_current))
    return ", ".join(PackedStringArray(spoken_numbers))

func _update_count_ui() -> void:
    if count_status_label == null:
        return
    count_number_label.text = str(count_current)
    count_progress_label.text = "%d / %d" % [count_current, count_target]

    if phase == Phase.WAITING:
        count_status_label.text = "ROUND READY"
        count_substatus_label.text = "Press START ROUND in the popup."
        count_message_label.text = "Game locked until the round starts."
    elif phase == Phase.COMPUTER:
        count_status_label.text = "COMPUTER'S TURN"
        count_substatus_label.text = "The computer will count automatically."
        count_message_label.text = "Computer is choosing a move."
    elif phase == Phase.PLAYER:
        count_status_label.text = _actor_name(current_player).to_upper() + "'S TURN"
        count_substatus_label.text = "Choose how many consecutive numbers to say."
        count_message_label.text = "Reach %d to win." % count_target

    if count_history.is_empty():
        count_history_label.text = "No turns yet."
    else:
        var start_index := maxi(0, count_history.size() - 8)
        var recent: Array[String] = []
        for index in range(start_index, count_history.size()):
            recent.append(count_history[index])
        count_history_label.text = "\n".join(PackedStringArray(recent))

    var remaining := count_target - count_current
    for index in range(count_choice_buttons.size()):
        var amount := index + 1
        count_choice_buttons[index].disabled = phase != Phase.PLAYER or amount > remaining

# -----------------------------------------------------------------------------
# Ready + result overlays
# -----------------------------------------------------------------------------

func _show_ready_popup(title_text: String, body_text: String, start_callback: Callable) -> void:
    _hide_ready_popup()
    ready_overlay = Control.new()
    ready_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    ready_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    ready_overlay.z_index = 200
    screen_host.add_child(ready_overlay)

    var dim := ColorRect.new()
    dim.color = Color(0.05, 0.035, 0.025, 0.75)
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    dim.mouse_filter = Control.MOUSE_FILTER_STOP
    ready_overlay.add_child(dim)

    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    center.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ready_overlay.add_child(center)

    var panel := PanelContainer.new()
    panel.custom_minimum_size = Vector2(560, 260)
    panel.add_theme_stylebox_override("panel", _style(PAPER, 18, 3, Color("#c6b594")))
    center.add_child(panel)

    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 36)
    margin.add_theme_constant_override("margin_right", 36)
    margin.add_theme_constant_override("margin_top", 28)
    margin.add_theme_constant_override("margin_bottom", 28)
    panel.add_child(margin)

    var box := VBoxContainer.new()
    box.alignment = BoxContainer.ALIGNMENT_CENTER
    box.add_theme_constant_override("separation", 18)
    margin.add_child(box)

    var title := Label.new()
    title.text = title_text
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_color_override("font_color", INK)
    title.add_theme_font_size_override("font_size", 32)
    box.add_child(title)

    var body := Label.new()
    body.text = body_text
    body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    body.add_theme_color_override("font_color", MUTED)
    body.add_theme_font_size_override("font_size", 15)
    box.add_child(body)

    var start_button := _make_button("START ROUND", true)
    start_button.custom_minimum_size = Vector2(250, 50)
    start_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    start_button.pressed.connect(start_callback)
    box.add_child(start_button)

func _hide_ready_popup() -> void:
    if ready_overlay != null and is_instance_valid(ready_overlay):
        if ready_overlay.get_parent() != null:
            ready_overlay.get_parent().remove_child(ready_overlay)
        ready_overlay.queue_free()
    ready_overlay = null

func _finish_round(winner: int, explanation: String) -> void:
    phase = Phase.GAME_OVER
    if game_mode == GameMode.NIM:
        _render_nim_rows()
        _update_nim_ui()
    elif game_mode == GameMode.COUNTING:
        _update_count_ui()
    _show_result_overlay(winner, explanation)

func _show_result_overlay(winner: int, explanation: String) -> void:
    if result_overlay != null and is_instance_valid(result_overlay):
        result_overlay.queue_free()

    result_overlay = Control.new()
    result_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    result_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    result_overlay.z_index = 300
    screen_host.add_child(result_overlay)

    var dim := ColorRect.new()
    dim.color = Color(0.05, 0.035, 0.025, 0.76)
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    dim.mouse_filter = Control.MOUSE_FILTER_STOP
    result_overlay.add_child(dim)

    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    center.mouse_filter = Control.MOUSE_FILTER_IGNORE
    result_overlay.add_child(center)

    result_panel = PanelContainer.new()
    result_panel.custom_minimum_size = Vector2(610, 300)
    center.add_child(result_panel)

    var human_win := not versus_computer or winner == 1
    result_panel.add_theme_stylebox_override("panel", _style(Color("#241813"), 18, 3, Color("#6f9f78") if human_win else Color("#a84b43")))

    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 34)
    margin.add_theme_constant_override("margin_right", 34)
    margin.add_theme_constant_override("margin_top", 26)
    margin.add_theme_constant_override("margin_bottom", 26)
    result_panel.add_child(margin)

    var box := VBoxContainer.new()
    box.alignment = BoxContainer.ALIGNMENT_CENTER
    box.add_theme_constant_override("separation", 12)
    margin.add_child(box)

    result_title = Label.new()
    if versus_computer:
        result_title.text = "YOU WIN!" if winner == 1 else "COMPUTER WINS"
    else:
        result_title.text = "PLAYER %d WINS!" % winner
    result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    result_title.add_theme_color_override("font_color", GREEN_LIGHT if human_win else LOSE_RED)
    result_title.add_theme_font_size_override("font_size", 52)
    box.add_child(result_title)

    result_subtitle = Label.new()
    result_subtitle.text = explanation
    result_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    result_subtitle.add_theme_color_override("font_color", PAPER)
    result_subtitle.add_theme_font_size_override("font_size", 17)
    box.add_child(result_subtitle)

    var hint := Label.new()
    hint.text = "Play again keeps the same settings and shows the START ROUND popup again."
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hint.add_theme_color_override("font_color", Color("#d6c9b8"))
    hint.add_theme_font_size_override("font_size", 11)
    box.add_child(hint)

    var actions := HBoxContainer.new()
    actions.alignment = BoxContainer.ALIGNMENT_CENTER
    actions.add_theme_constant_override("separation", 8)
    box.add_child(actions)

    var again := _make_button("PLAY AGAIN", true)
    again.custom_minimum_size = Vector2(150, 42)
    again.pressed.connect(_play_again)
    actions.add_child(again)
    var setup := _make_button("GAME SETUP", false)
    setup.custom_minimum_size = Vector2(145, 42)
    setup.pressed.connect(_return_to_current_setup)
    actions.add_child(setup)
    var menu := _make_button("MAIN MENU", false)
    menu.custom_minimum_size = Vector2(140, 42)
    menu.pressed.connect(_show_main_menu)
    actions.add_child(menu)

    result_overlay.modulate.a = 0.0
    var tween := create_tween()
    tween.tween_property(result_overlay, "modulate:a", 1.0, 0.22)
    _play_result_sound(human_win)

func _play_again() -> void:
    if game_mode == GameMode.NIM:
        _prepare_nim_round()
    elif game_mode == GameMode.COUNTING:
        _prepare_count_round()

func _return_to_current_setup() -> void:
    if game_mode == GameMode.NIM:
        _show_nim_setup()
    elif game_mode == GameMode.COUNTING:
        _show_count_setup()

# -----------------------------------------------------------------------------
# Shared helpers
# -----------------------------------------------------------------------------

func _actor_name(player: int) -> String:
    if versus_computer:
        return "You" if player == 1 else "Computer"
    return "Player %d" % player

func _is_computer_turn() -> bool:
    return versus_computer and current_player == 2

func _clear_screen() -> void:
    ready_overlay = null
    result_overlay = null
    if screen_host == null:
        return
    _clear_container(screen_host)

func _clear_container(container: Node) -> void:
    for child in container.get_children():
        container.remove_child(child)
        child.queue_free()

func _style(bg: Color, radius: int = 10, border_width: int = 0, border_color: Color = Color.TRANSPARENT) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = bg
    style.corner_radius_top_left = radius
    style.corner_radius_top_right = radius
    style.corner_radius_bottom_left = radius
    style.corner_radius_bottom_right = radius
    if border_width > 0:
        style.border_width_left = border_width
        style.border_width_right = border_width
        style.border_width_top = border_width
        style.border_width_bottom = border_width
        style.border_color = border_color
    return style

func _make_button(text_value: String, primary: bool) -> Button:
    var button := Button.new()
    button.text = text_value
    button.focus_mode = Control.FOCUS_NONE
    button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    button.add_theme_font_size_override("font_size", 14)
    button.add_theme_color_override("font_color", PAPER if primary else INK)
    button.add_theme_color_override("font_hover_color", PAPER if primary else INK)
    button.add_theme_color_override("font_pressed_color", PAPER if primary else INK)
    button.add_theme_color_override("font_disabled_color", Color("#998f82"))
    if primary:
        button.add_theme_stylebox_override("normal", _style(RED, 9, 1, RED_DARK))
        button.add_theme_stylebox_override("hover", _style(Color("#a63b33"), 9, 1, RED_DARK))
        button.add_theme_stylebox_override("pressed", _style(RED_DARK, 9, 1, RED_DARK))
        button.add_theme_stylebox_override("disabled", _style(Color("#aa938d"), 9, 1, Color("#8f817d")))
    else:
        button.add_theme_stylebox_override("normal", _style(PAPER_2, 9, 1, Color("#b9a88a")))
        button.add_theme_stylebox_override("hover", _style(Color("#f7edda"), 9, 1, Color("#9f8b69")))
        button.add_theme_stylebox_override("pressed", _style(Color("#d9cbb0"), 9, 1, Color("#9f8b69")))
        button.add_theme_stylebox_override("disabled", _style(Color("#d4c8b4"), 9, 1, Color("#b9aa92")))
    return button
