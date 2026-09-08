extends Node

# Lightweight procedural puzzle-game soundtrack.
# Keeps playing throughout the match, including the result screen.

var music_player: AudioStreamPlayer

func _ready() -> void:
    music_player = AudioStreamPlayer.new()
    music_player.volume_db = -18.0
    add_child(music_player)
    music_player.stream = _make_music_loop()
    music_player.finished.connect(_restart_music)
    music_player.play()

func _unhandled_input(_event: InputEvent) -> void:
    # Web browsers may block autoplay until the first user interaction.
    if music_player != null and not music_player.playing:
        music_player.play()

func _restart_music() -> void:
    if music_player != null:
        music_player.play()

func _make_music_loop() -> AudioStreamWAV:
    var sample_rate := 22050
    var note_length := 0.24
    var melody: Array[float] = [
        523.25, 659.25, 783.99, 659.25,
        493.88, 659.25, 739.99, 659.25,
        440.00, 523.25, 659.25, 523.25,
        392.00, 493.88, 587.33, 493.88,
        523.25, 659.25, 783.99, 880.00,
        783.99, 659.25, 587.33, 659.25,
        523.25, 493.88, 440.00, 493.88,
        523.25, 392.00, 440.00, 493.88
    ]
    var bass: Array[float] = [
        130.81, 130.81, 130.81, 130.81,
        123.47, 123.47, 123.47, 123.47,
        110.00, 110.00, 110.00, 110.00,
        98.00, 98.00, 98.00, 98.00,
        130.81, 130.81, 130.81, 130.81,
        123.47, 123.47, 123.47, 123.47,
        110.00, 110.00, 110.00, 110.00,
        98.00, 98.00, 98.00, 98.00
    ]

    var samples_per_note := maxi(1, int(float(sample_rate) * note_length))
    var total_samples := samples_per_note * melody.size()
    var bytes := PackedByteArray()
    bytes.resize(total_samples * 2)

    for note_index in range(melody.size()):
        var melody_frequency := melody[note_index]
        var bass_frequency := bass[note_index]
        for sample_index in range(samples_per_note):
            var t := float(sample_index) / float(sample_rate)
            var progress := float(sample_index) / float(maxi(1, samples_per_note - 1))
            var attack := minf(1.0, progress * 10.0)
            var release := minf(1.0, (1.0 - progress) * 5.0)
            var envelope := attack * release

            var lead := sin(TAU * melody_frequency * t) * 0.16
            lead += sin(TAU * melody_frequency * 2.0 * t) * 0.035
            var low := sin(TAU * bass_frequency * t) * 0.10
            var sample := (lead + low) * envelope

            var pcm_value := int(clampf(sample, -1.0, 1.0) * 32767.0)
            var byte_offset := (note_index * samples_per_note + sample_index) * 2
            bytes.encode_s16(byte_offset, pcm_value)

    var stream := AudioStreamWAV.new()
    stream.format = AudioStreamWAV.FORMAT_16_BITS
    stream.mix_rate = sample_rate
    stream.stereo = false
    stream.data = bytes
    return stream
