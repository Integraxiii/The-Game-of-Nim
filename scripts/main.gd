extends Control

# Nim Lab — a browser-friendly Nim trainer for Math Society.
# Standard: take any positive number from one pile; last token wins.
# Misere/video mode: same moves, but taking the last token loses.

const BG := Color("#09101d")
const PANEL := Color("#111b2e")
const PANEL_2 := Color("#17233a")
const TEXT := Color("#eef4ff")
const MUTED := Color("#9caecc")
const ACCENT := Color("#6aa9ff")
const ACCENT_DARK := Color("#2f5f9d")
const GREEN := Color("#63d69a")
const RED := Color("#ff7d79")
const GOLD := Color("#f0bf68")

var rng := RandomNumberGenerator.new()
var piles: Array[int] = [3, 4, 5]
var initial_piles: Array[int] = [3, 4, 5]
var pile_inputs: Array[SpinBox] = []
var game_active := false
var player_turn := true
var game_over := false
var selected_pile := -1
var strategy_visible := false

var setup_panel: PanelContainer
var setup_pile_row: HBoxContainer
var setup_analysis: RichTextLabel
var game_panel: PanelContainer
var piles_grid: GridContainer
var removal_box: HBoxContainer
var status_label: Label
var position_label: Label
var message_label: RichTextLabel
var strategy_panel: PanelContainer
var strategy_text: RichTextLabel
var pile_count_option: OptionButton
var first_option: OptionButton
var ai_option: OptionButton
var rule_option: OptionButton
var random_max_option: OptionButton
var hint_button: Button
var strategy_button: Button

func _ready() -> void:
    rng.randomize()
    _build_ui()
    _rebuild_pile_inputs(3, [3, 4, 5])
    _update_setup_analysis()
    _render_game()

func _build_ui() -> void:
    var bg := ColorRect.new()
    bg.color = BG
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(bg)

    var scroll := ScrollContainer.new()
    scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    add_child(scroll)

    var outer := MarginContainer.new()
    outer.add_theme_constant_override("margin_left", 28)
    outer.add_theme_constant_override("margin_right", 28)
    outer.add_theme_constant_override("margin_top", 24)
    outer.add_theme_constant_override("margin_bottom", 32)
    outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(outer)

    var main := VBoxContainer.new()
    main.add_theme_constant_override("separation", 16)
    main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    outer.add_child(main)

    var title := Label.new()
    title.text = "NIM LAB"
    title.add_theme_color_override("font_color", TEXT)
    title.add_theme_font_size_override("font_size", 34)
    main.add_child(title)

    var subtitle := Label.new()
    subtitle.text = "Practice the strategy, vary the piles, and reveal the binary trick."
    subtitle.add_theme_color_override("font_color", MUTED)
    subtitle.add_theme_font_size_override("font_size", 16)
    main.add_child(subtitle)

    setup_panel = _make_panel(PANEL)
    main.add_child(setup_panel)
    _build_setup_contents()

    game_panel = _make_panel(PANEL)
    main.add_child(game_panel)
    _build_game_contents()

    strategy_panel = _make_panel(PANEL_2)
    strategy_panel.visible = false
    main.add_child(strategy_panel)
    var strategy_margin := _margin(18, 18, 14, 16)
    strategy_panel.add_child(strategy_margin)
    strategy_text = RichTextLabel.new()
    strategy_text.bbcode_enabled = true
    strategy_text.fit_content = true
    strategy_text.custom_minimum_size.y = 150
    strategy_text.add_theme_color_override("default_color", TEXT)
    strategy_margin.add_child(strategy_text)

func _build_setup_contents() -> void:
    var margin := _margin(18, 18, 16, 18)
    setup_panel.add_child(margin)
    var v := VBoxContainer.new()
    v.add_theme_constant_override("separation", 12)
    margin.add_child(v)

    var heading := Label.new()
    heading.text = "GAME SETUP"
    heading.add_theme_color_override("font_color", GOLD)
    heading.add_theme_font_size_override("font_size", 18)
    v.add_child(heading)

    var options := GridContainer.new()
    options.columns = 4
    options.add_theme_constant_override("h_separation", 14)
    options.add_theme_constant_override("v_separation", 8)
    v.add_child(options)

    pile_count_option = _labeled_option(options, "Piles", ["2", "3", "4", "5"], 1)
    pile_count_option.item_selected.connect(_on_pile_count_changed)
    first_option = _labeled_option(options, "Who goes first?", ["You", "Computer", "Random"], 0)
    first_option.item_selected.connect(func(_i: int): _update_setup_analysis())
    ai_option = _labeled_option(options, "Computer", ["Perfect", "Practice", "Random"], 1)
    rule_option = _labeled_option(options, "Rule", ["Last token wins", "Last token loses (video)"], 0)
    rule_option.item_selected.connect(func(_i: int): _update_setup_analysis())

    var pile_label := Label.new()
    pile_label.text = "Starting pile sizes"
    pile_label.add_theme_color_override("font_color", TEXT)
    v.add_child(pile_label)

    setup_pile_row = HBoxContainer.new()
    setup_pile_row.add_theme_constant_override("separation", 10)
    v.add_child(setup_pile_row)

    var utility := HBoxContainer.new()
    utility.add_theme_constant_override("separation", 10)
    v.add_child(utility)

    random_max_option = OptionButton.new()
    for text in ["Random max: 7", "Random max: 10", "Random max: 15"]:
        random_max_option.add_item(text)
    utility.add_child(random_max_option)

    var random_button := _make_button("RANDOM SETUP", false)
    random_button.pressed.connect(_randomize_setup)
    utility.add_child(random_button)

    var p1 := _make_button("3-4-5", false)
    p1.pressed.connect(_apply_preset.bind([3, 4, 5]))
    utility.add_child(p1)
    var p2 := _make_button("2-5-7", false)
    p2.pressed.connect(_apply_preset.bind([2, 5, 7]))
    utility.add_child(p2)
    var p3 := _make_button("7-3-3", false)
    p3.pressed.connect(_apply_preset.bind([7, 3, 3]))
    utility.add_child(p3)

    setup_analysis = RichTextLabel.new()
    setup_analysis.bbcode_enabled = true
    setup_analysis.fit_content = true
    setup_analysis.custom_minimum_size.y = 52
    setup_analysis.add_theme_color_override("default_color", MUTED)
    v.add_child(setup_analysis)

    var start_button := _make_button("START GAME", true)
    start_button.custom_minimum_size.y = 50
    start_button.pressed.connect(_start_game)
    v.add_child(start_button)

func _build_game_contents() -> void:
    var margin := _margin(18, 18, 16, 18)
    game_panel.add_child(margin)
    var v := VBoxContainer.new()
    v.add_theme_constant_override("separation", 12)
    margin.add_child(v)

    var top := HBoxContainer.new()
    top.add_theme_constant_override("separation", 12)
    v.add_child(top)

    status_label = Label.new()
    status_label.text = "Configure a game above"
    status_label.add_theme_color_override("font_color", TEXT)
    status_label.add_theme_font_size_override("font_size", 20)
    status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    top.add_child(status_label)

    position_label = Label.new()
    position_label.add_theme_color_override("font_color", GOLD)
    position_label.add_theme_font_size_override("font_size", 20)
    top.add_child(position_label)

    piles_grid = GridContainer.new()
    piles_grid.columns = 3
    piles_grid.add_theme_constant_override("h_separation", 12)
    piles_grid.add_theme_constant_override("v_separation", 12)
    v.add_child(piles_grid)

    var prompt := Label.new()
    prompt.text = "Choose ONE pile, then choose how many tokens to remove:"
    prompt.add_theme_color_override("font_color", MUTED)
    v.add_child(prompt)

    removal_box = HBoxContainer.new()
    removal_box.add_theme_constant_override("separation", 8)
    v.add_child(removal_box)

    message_label = RichTextLabel.new()
    message_label.bbcode_enabled = true
    message_label.fit_content = true
    message_label.custom_minimum_size.y = 64
    message_label.add_theme_color_override("default_color", TEXT)
    v.add_child(message_label)

    var actions := HBoxContainer.new()
    actions.add_theme_constant_override("separation", 10)
    v.add_child(actions)

    hint_button = _make_button("HINT", false)
    hint_button.pressed.connect(_show_hint)
    actions.add_child(hint_button)

    strategy_button = _make_button("SHOW 4-2-1 / BINARY", false)
    strategy_button.pressed.connect(_toggle_strategy)
    actions.add_child(strategy_button)

    var back_button := _make_button("BACK TO SETUP", false)
    back_button.pressed.connect(_back_to_setup)
    actions.add_child(back_button)

func _labeled_option(parent: GridContainer, label_text: String, items: Array[String], selected_index: int) -> OptionButton:
    var label := Label.new()
    label.text = label_text
    label.add_theme_color_override("font_color", MUTED)
    parent.add_child(label)
    var option := OptionButton.new()
    option.custom_minimum_size.x = 175
    for item in items:
        option.add_item(item)
    option.selected = selected_index
    parent.add_child(option)
    return option

func _rebuild_pile_inputs(count: int, values: Array[int] = []) -> void:
    _clear_container(setup_pile_row)
    pile_inputs.clear()
    for i in range(count):
        var col := VBoxContainer.new()
        var label := Label.new()
        label.text = "Pile %s" % _pile_name(i)
        label.add_theme_color_override("font_color", MUTED)
        col.add_child(label)
        var spin := SpinBox.new()
        spin.min_value = 0
        spin.max_value = 15
        spin.step = 1
        spin.custom_minimum_size.x = 92
        spin.value = values[i] if i < values.size() else mini(3 + i, 7)
        spin.value_changed.connect(func(_value: float): _update_setup_analysis())
        col.add_child(spin)
        setup_pile_row.add_child(col)
        pile_inputs.append(spin)

func _on_pile_count_changed(index: int) -> void:
    var old := _read_piles()
    _rebuild_pile_inputs(index + 2, old)
    _update_setup_analysis()

func _read_piles() -> Array[int]:
    var result: Array[int] = []
    for spin in pile_inputs:
        result.append(int(round(spin.value)))
    return result

func _update_setup_analysis() -> void:
    if setup_analysis == null or pile_inputs.is_empty():
        return
    var arr := _read_piles()
    if _total(arr) == 0:
        setup_analysis.text = "[color=#ff7d79]At least one pile must contain a token.[/color]"
        return
    var x := _nim_sum(arr)
    var winner := "Player 1" if _position_is_winning(arr, rule_option.selected == 1) else "Player 2"
    var special := ""
    if rule_option.selected == 1:
        special = " [color=#f0bf68](video / last-token-loses rule)[/color]"
    setup_analysis.text = "Position [b]%s[/b] • Nim-sum [b]%s[/b] • Perfect play favors [b]%s[/b].%s" % [_position_string(arr), _binary(x, _bit_width(arr)), winner, special]

func _randomize_setup() -> void:
    var max_values := [7, 10, 15]
    var max_n: int = max_values[random_max_option.selected]
    var values: Array[int] = []
    for _i in range(pile_inputs.size()):
        values.append(rng.randi_range(1, max_n))
    _rebuild_pile_inputs(pile_inputs.size(), values)
    _update_setup_analysis()

func _apply_preset(values: Array) -> void:
    pile_count_option.selected = 1
    var typed: Array[int] = []
    for n in values:
        typed.append(int(n))
    _rebuild_pile_inputs(3, typed)
    _update_setup_analysis()

func _start_game() -> void:
    piles = _read_piles()
    if _total(piles) == 0:
        piles[0] = 1
    initial_piles = piles.duplicate()
    selected_pile = -1
    game_active = true
    game_over = false
    strategy_visible = false
    strategy_panel.visible = false
    strategy_button.text = "SHOW 4-2-1 / BINARY"
    setup_panel.visible = false

    var first := first_option.selected
    if first == 2:
        first = rng.randi_range(0, 1)
    player_turn = first == 0

    var x := _nim_sum(piles)
    var theoretical := "Player 1" if _position_is_winning(piles, _is_misere()) else "Player 2"
    message_label.text = "Starting position: [b]%s[/b]. Nim-sum: [b]%s[/b]. Under perfect play, [b]%s[/b] has the winning strategy." % [_position_string(piles), _binary(x, _bit_width(piles)), theoretical]
    _render_game()
    if not player_turn:
        _computer_turn()

func _render_game() -> void:
    position_label.text = _position_string(piles)
    if not game_active:
        status_label.text = "Configure a game above"
    elif game_over:
        status_label.text = "Game over"
    elif player_turn:
        status_label.text = "YOUR TURN"
    else:
        status_label.text = "COMPUTER TURN"

    hint_button.disabled = not game_active or game_over or not player_turn
    piles_grid.columns = mini(3, piles.size())
    _clear_container(piles_grid)

    for i in range(piles.size()):
        var b := _make_button("", false)
        b.custom_minimum_size = Vector2(0, 118)
        b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        var token_line := ""
        for _j in range(piles[i]):
            token_line += "● "
        if token_line.is_empty():
            token_line = "—"
        b.text = "Pile %s    %d\n%s" % [_pile_name(i), piles[i], token_line]
        b.disabled = not game_active or game_over or not player_turn or piles[i] == 0
        if i == selected_pile:
            b.add_theme_stylebox_override("normal", _panel_style(Color("#203b61"), 10, ACCENT))
        b.pressed.connect(_select_pile.bind(i))
        piles_grid.add_child(b)

    _render_removal_buttons()
    _refresh_strategy()

func _select_pile(index: int) -> void:
    if not game_active or game_over or not player_turn or piles[index] <= 0:
        return
    selected_pile = index
    _render_game()

func _render_removal_buttons() -> void:
    _clear_container(removal_box)
    if selected_pile < 0 or selected_pile >= piles.size() or not player_turn or game_over:
        return
    for amount in range(1, piles[selected_pile] + 1):
        var b := _make_button(str(amount), false)
        b.custom_minimum_size.x = 48
        b.tooltip_text = "Remove %d from Pile %s" % [amount, _pile_name(selected_pile)]
        b.pressed.connect(_player_remove.bind(amount))
        removal_box.add_child(b)

func _player_remove(amount: int) -> void:
    if selected_pile < 0 or amount < 1 or amount > piles[selected_pile]:
        return
    var i := selected_pile
    var before := piles[i]
    piles[i] -= amount
    selected_pile = -1
    if _check_game_end(true):
        return
    var x := _nim_sum(piles)
    var zero_text := "[color=#63d69a]ZERO[/color]" if x == 0 else "[color=#ff7d79]non-zero[/color]"
    message_label.text = "You changed Pile %s: [b]%d → %d[/b]. Nim-sum: [b]%s[/b] (%s)." % [_pile_name(i), before, piles[i], _binary(x, _bit_width(piles)), zero_text]
    player_turn = false
    _render_game()
    _computer_turn()

func _computer_turn() -> void:
    await get_tree().create_timer(0.55).timeout
    if game_over or not game_active:
        return
    var move := _choose_ai_move()
    if move.is_empty():
        return
    var i: int = move[0]
    var target: int = move[1]
    var before := piles[i]
    piles[i] = target
    if _check_game_end(false):
        return
    var x := _nim_sum(piles)
    message_label.text = "Computer changed Pile %s: [b]%d → %d[/b]. Nim-sum: [b]%s[/b]. Your turn." % [_pile_name(i), before, target, _binary(x, _bit_width(piles))]
    player_turn = true
    _render_game()

func _choose_ai_move() -> Array[int]:
    var best := _winning_move(piles, _is_misere())
    match ai_option.selected:
        0:
            return best if not best.is_empty() else _random_move(piles)
        1:
            if not best.is_empty() and rng.randf() < 0.72:
                return best
            return _random_move(piles)
        _:
            return _random_move(piles)

func _winning_move(arr: Array[int], misere: bool) -> Array[int]:
    if misere:
        var large: Array[int] = []
        var ones := 0
        for i in range(arr.size()):
            if arr[i] > 1:
                large.append(i)
            elif arr[i] == 1:
                ones += 1
        if large.is_empty():
            if ones > 0 and ones % 2 == 0:
                for i in range(arr.size()):
                    if arr[i] == 1:
                        return [i, 0]
            return []
        if large.size() == 1:
            var i := large[0]
            var target := 1 if ones % 2 == 0 else 0
            if target < arr[i]:
                return [i, target]

    var x := _nim_sum(arr)
    if x == 0:
        return []
    for i in range(arr.size()):
        var target := arr[i] ^ x
        if target < arr[i]:
            return [i, target]
    return []

func _random_move(arr: Array[int]) -> Array[int]:
    var available: Array[int] = []
    for i in range(arr.size()):
        if arr[i] > 0:
            available.append(i)
    if available.is_empty():
        return []
    var index := available[rng.randi_range(0, available.size() - 1)]
    var take := rng.randi_range(1, arr[index])
    return [index, arr[index] - take]

func _check_game_end(mover_is_player: bool) -> bool:
    if _total(piles) != 0:
        return false
    game_over = true
    var player_wins: bool
    if _is_misere():
        player_wins = not mover_is_player
    else:
        player_wins = mover_is_player
    if player_wins:
        message_label.text = "[color=#63d69a][b]YOU WIN![/b][/color] " + ("The computer was forced to take the last token." if _is_misere() else "You took the last token.")
    else:
        message_label.text = "[color=#ff7d79][b]COMPUTER WINS.[/b][/color] " + ("You took the last token, so you lose in video mode." if _is_misere() else "The computer took the last token.")
    _render_game()
    return true

func _show_hint() -> void:
    if not game_active or game_over or not player_turn:
        return
    var move := _winning_move(piles, _is_misere())
    if move.is_empty():
        message_label.text = "[color=#f0bf68][b]HINT:[/b][/color] This is a losing position against perfect play. There is no guaranteed winning move; make a legal move and hope for a mistake."
        return
    var i: int = move[0]
    var target: int = move[1]
    message_label.text = "[color=#f0bf68][b]HINT:[/b][/color] Remove [b]%d[/b] from Pile %s (%d → %d)." % [piles[i] - target, _pile_name(i), piles[i], target]

func _toggle_strategy() -> void:
    strategy_visible = not strategy_visible
    strategy_panel.visible = strategy_visible
    strategy_button.text = "HIDE 4-2-1 / BINARY" if strategy_visible else "SHOW 4-2-1 / BINARY"
    _refresh_strategy()

func _refresh_strategy() -> void:
    if not strategy_visible or strategy_text == null:
        return
    var width := _bit_width(piles)
    var lines: Array[String] = []
    lines.append("[color=#f0bf68][b]BINARY / PAIRING REVEAL[/b][/color]")
    lines.append("Each column is a power of 2. In standard Nim, you want to hand your opponent a Nim-sum of zero.")
    lines.append("")
    var header := "Pile     "
    for bit in range(width - 1, -1, -1):
        header += "%4d" % (1 << bit)
    header += "      Binary"
    lines.append("[code]%s[/code]" % header)
    for i in range(piles.size()):
        var b := _binary(piles[i], width)
        var row := "%s = %-2d  " % [_pile_name(i), piles[i]]
        for ch in b:
            row += "%4s" % ch
        row += "      %s" % b
        lines.append("[code]%s[/code]" % row)
    var x := _nim_sum(piles)
    lines.append("[code]Nim-sum: %s[/code]" % _binary(x, width))
    if x == 0:
        lines.append("[color=#63d69a][b]ZERO POSITION:[/b][/color] every binary column has an even number of 1s.")
    else:
        lines.append("[color=#ff7d79][b]NON-ZERO POSITION:[/b][/color] look for a move that restores zero.")
    if _is_misere():
        lines.append("")
        lines.append("[color=#f0bf68][b]Video-rule exception:[/b][/color] when every remaining pile is 0 or 1, parity replaces the ordinary zero rule because the player taking the final token loses.")
    strategy_text.text = "\n".join(lines)

func _back_to_setup() -> void:
    game_active = false
    game_over = false
    selected_pile = -1
    setup_panel.visible = true
    strategy_visible = false
    strategy_panel.visible = false
    piles = initial_piles.duplicate()
    pile_count_option.selected = initial_piles.size() - 2
    _rebuild_pile_inputs(initial_piles.size(), initial_piles)
    _update_setup_analysis()
    message_label.text = "Adjust the setup and start another game."
    _render_game()

func _position_is_winning(arr: Array[int], misere: bool) -> bool:
    return not _winning_move(arr, misere).is_empty()

func _is_misere() -> bool:
    return rule_option.selected == 1

func _nim_sum(arr: Array[int]) -> int:
    var result := 0
    for n in arr:
        result ^= n
    return result

func _total(arr: Array[int]) -> int:
    var result := 0
    for n in arr:
        result += n
    return result

func _bit_width(arr: Array[int]) -> int:
    var max_n := 1
    for n in arr:
        max_n = maxi(max_n, n)
    var width := 1
    while (1 << width) <= max_n:
        width += 1
    return maxi(3, width)

func _binary(value: int, width: int) -> String:
    var out := ""
    for bit in range(width - 1, -1, -1):
        out += "1" if (value & (1 << bit)) != 0 else "0"
    return out

func _position_string(arr: Array[int]) -> String:
    var parts := PackedStringArray()
    for n in arr:
        parts.append(str(n))
    return " - ".join(parts)

func _pile_name(index: int) -> String:
    var names := ["A", "B", "C", "D", "E"]
    return names[clampi(index, 0, names.size() - 1)]

func _clear_container(container: Container) -> void:
    for child in container.get_children():
        container.remove_child(child)
        child.queue_free()

func _margin(left: int, right: int, top: int, bottom: int) -> MarginContainer:
    var m := MarginContainer.new()
    m.add_theme_constant_override("margin_left", left)
    m.add_theme_constant_override("margin_right", right)
    m.add_theme_constant_override("margin_top", top)
    m.add_theme_constant_override("margin_bottom", bottom)
    return m

func _make_panel(color: Color) -> PanelContainer:
    var p := PanelContainer.new()
    p.add_theme_stylebox_override("panel", _panel_style(color, 16))
    return p

func _panel_style(color: Color, radius: int, border_color: Color = Color.TRANSPARENT) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = color
    style.corner_radius_top_left = radius
    style.corner_radius_top_right = radius
    style.corner_radius_bottom_left = radius
    style.corner_radius_bottom_right = radius
    if border_color.a > 0.0:
        style.border_width_left = 1
        style.border_width_right = 1
        style.border_width_top = 1
        style.border_width_bottom = 1
        style.border_color = border_color
    return style

func _make_button(text_value: String, primary: bool) -> Button:
    var b := Button.new()
    b.text = text_value
    b.custom_minimum_size.y = 42
    b.add_theme_font_size_override("font_size", 15)
    b.add_theme_color_override("font_color", TEXT)
    if primary:
        b.add_theme_stylebox_override("normal", _panel_style(ACCENT_DARK, 10))
        b.add_theme_stylebox_override("hover", _panel_style(ACCENT, 10))
        b.add_theme_stylebox_override("pressed", _panel_style(Color("#244b7d"), 10))
    else:
        b.add_theme_stylebox_override("normal", _panel_style(PANEL_2, 10, Color("#334868")))
        b.add_theme_stylebox_override("hover", _panel_style(Color("#233653"), 10, ACCENT))
        b.add_theme_stylebox_override("pressed", _panel_style(Color("#1b2a43"), 10))
    return b
