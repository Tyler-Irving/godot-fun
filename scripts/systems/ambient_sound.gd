extends AudioStreamPlayer
## Ambient background sound — plays a gentle procedural wind/nature loop.
##
## KEY GODOT CONCEPTS:
## - AudioStreamPlayer: A non-positional audio player. Plays sound at
##   uniform volume regardless of where the camera is.
## - AudioStreamWAV: A runtime-constructable audio stream. We generate
##   PCM sample data in code so no external audio files are needed.
## - PackedByteArray: Stores raw bytes. We write 16-bit PCM samples as
##   two bytes each (little-endian) to build the waveform.

## Volume in dB. Negative = quieter. -20 dB is a gentle background level.
const VOLUME_DB := -20.0
const SAMPLE_RATE := 22050
const DURATION := 4.0  # seconds per loop


func _ready() -> void:
	volume_db = VOLUME_DB
	stream = _generate_ambient_stream()
	autoplay = true
	play()


func _generate_ambient_stream() -> AudioStreamWAV:
	## Create a soft ambient drone by layering low sine waves with noise.
	var sample_count := int(SAMPLE_RATE * DURATION)
	var data := PackedByteArray()
	data.resize(sample_count * 2)  # 16-bit = 2 bytes per sample

	# Simple pseudo-random noise state
	var noise_state := 0.5

	for i in range(sample_count):
		var t := float(i) / SAMPLE_RATE

		# Low drone: two detuned sine waves
		var drone := sin(t * TAU * 55.0) * 0.15   # A1 (55 Hz)
		drone += sin(t * TAU * 82.5) * 0.08        # ~E2 (a fifth up)

		# Simple filtered noise for "wind" texture
		noise_state = fmod(noise_state * 1.032 + 0.7634, 1.0)
		var raw_noise := noise_state * 2.0 - 1.0
		var wind := raw_noise * 0.06

		# Combine and soft-clip
		var sample := clampf(drone + wind, -0.8, 0.8)

		# Fade in/out at loop boundaries for seamless looping (50ms crossfade)
		var fade_samples := int(SAMPLE_RATE * 0.05)
		if i < fade_samples:
			sample *= float(i) / fade_samples
		elif i > sample_count - fade_samples:
			sample *= float(sample_count - i) / fade_samples

		# Write 16-bit signed little-endian PCM
		var pcm := int(sample * 32000.0)
		data[i * 2] = pcm & 0xFF
		data[i * 2 + 1] = (pcm >> 8) & 0xFF

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = sample_count
	return stream
