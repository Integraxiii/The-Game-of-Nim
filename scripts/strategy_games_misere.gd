extends "res://scripts/strategy_games_v2.gd"

# Misere versions of both classroom strategy games:
# - Matchstick Nim: whoever takes the final match loses.
# - Counting Ducks: whoever places the final target duck loses.

func _show_main_menu() -> void:
    super._show_main_menu()
    _apply_misere_text(screen_host)

func _show_nim_setup() -> void:
    super._show_nim_setup()
    _apply_misere_text(screen_host)

func _show_count_setup() -> void:
    super._show_count_setup()
    _apply_misere_text(screen_host)

func _prepare_nim_round() -> void:
    super._prepare_nim_round()
    _apply_misere_text(screen_host)

func _prepare_count_round() -> void:
    super._prepare_count_round()
    _apply_misere_text(screen_host)

func _update_count_ui() -> void:
    super._update_count_ui()
    if count_message_label != null and phase == Phase.PLAYER:
        count_message_label.text = "Duck %d loses the round. Avoid placing the last duck!" % count_target

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
        var winner := 3 - current_player
        _finish_round(winner, _actor_name(current_player) + " took the final match and loses the round.")

func _computer_nim_turn(serial: int) -> void:
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
        if serial != game_serial or phase != Phase.COMPUTER:
            return
        piles[row_index] -= 1
        _play_click_sound()
        _render_nim_rows()
        _update_nim_ui()

    if _nim_total() == 0:
        _finish_round(1, "The computer took the final match and loses the round.")
        return

    current_player = 1
    _begin_nim_turn()

func _best_nim_move() -> Vector2i:
    # Optimal misere Nim strategy.
    # When only single matches remain, odd/even parity matters.
    # With exactly one pile larger than 1, leave an odd number of 1-piles.
    # Otherwise use the usual XOR-to-zero move.
    var large_rows: Array[int] = []
    var ones := 0

    for row_index in range(piles.size()):
        if piles[row_index] > 1:
            large_rows.append(row_index)
        elif piles[row_index] == 1:
            ones += 1

    if large_rows.is_empty():
        for row_index in range(piles.size()):
            if piles[row_index] == 1:
                return Vector2i(row_index, 1)

    if large_rows.size() == 1:
        var row_index := large_rows[0]
        var target := 1 if ones % 2 == 0 else 0
        return Vector2i(row_index, piles[row_index] - target)

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
    var chosen_row := legal_rows[rng.randi_range(0, legal_rows.size() - 1)]
    return Vector2i(chosen_row, rng.randi_range(1, piles[chosen_row]))

func _on_count_choice(amount: int) -> void:
    if phase != Phase.PLAYER or game_mode != GameMode.COUNTING:
        return
    if amount < 1 or amount > COUNT_CHOICES:
        return

    amount = mini(amount, count_target - count_current)
    if amount <= 0:
        return

    _add_ducks_for_turn(current_player, amount)
    _play_click_sound()
    _render_ducks()
    _update_count_ui()

    if count_current == count_target:
        var winner := 3 - current_player
        _finish_round(winner, _actor_name(current_player) + " placed duck %d and loses the round." % count_target)
        return

    current_player = 3 - current_player
    _begin_count_turn()

func _computer_count_turn(serial: int) -> void:
    count_message_label.text = "Computer is choosing 1, 2, or 3 ducks..."
    await get_tree().create_timer(0.48).timeout
    if serial != game_serial or game_mode != GameMode.COUNTING or phase != Phase.COMPUTER:
        return

    var remaining := count_target - count_current
    var amount := 1

    # In the last-duck-loses version with choices 1-3, positions with
    # remaining ducks congruent to 1 mod 4 are losing positions.
    # The computer tries to leave one of those positions to its opponent.
    if remaining == 1:
        amount = 1
    else:
        var winning_amount := (remaining - 1) % (COUNT_CHOICES + 1)
        if winning_amount == 0:
            amount = rng.randi_range(1, mini(COUNT_CHOICES, remaining))
        else:
            amount = winning_amount

    var start_number := count_current + 1
    for _i in range(amount):
        await get_tree().create_timer(COMPUTER_DUCK_DELAY).timeout
        if serial != game_serial or game_mode != GameMode.COUNTING or phase != Phase.COMPUTER:
            return
        count_current += 1
        duck_owners.append(2)
        _play_click_sound()
        _render_ducks()
        _update_count_ui()

    count_turns.append({
        "player": 2,
        "amount": amount,
        "start": start_number,
        "end": count_current
    })
    _update_count_ui()

    if count_current == count_target:
        _finish_round(1, "The computer placed duck %d and loses the round." % count_target)
        return

    current_player = 1
    _begin_count_turn()

func _apply_misere_text(node: Node) -> void:
    if node == null:
        return

    if node is Label:
        var label := node as Label
        label.text = label.text.replace("Take the final match to win.", "Avoid the final match - taking it loses the game.")
        label.text = label.text.replace("Take the final match to win", "Avoid the final match - taking it loses")
        label.text = label.text.replace("The player who takes the final match wins.", "The player who takes the final match LOSES.")
        label.text = label.text.replace("The player who takes the FINAL match WINS.", "The player who takes the FINAL match LOSES.")
        label.text = label.text.replace("Taking the LAST match WINS", "Taking the LAST match LOSES")
        label.text = label.text.replace("Last match wins", "Last match loses")
        label.text = label.text.replace("player who reaches the target wins", "player who places the final duck loses")
        label.text = label.text.replace("Whoever places duck %d WINS." % count_target, "Whoever places duck %d LOSES." % count_target)
        label.text = label.text.replace("Watch the flock grow until someone reaches the target.", "Add ducks to the flock, but avoid placing the final target duck.")

    for child in node.get_children():
        _apply_misere_text(child)
