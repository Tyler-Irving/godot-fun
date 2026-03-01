extends CanvasModulate
## Day/night cycle — smoothly transitions between daytime and nighttime tints.
##
## KEY GODOT CONCEPTS:
## - CanvasModulate: Multiplies a color tint onto everything rendered on the
##   same canvas. At Color(1,1,1) it has no effect (full daylight); at darker
##   colors the whole world darkens. Only one CanvasModulate is active at a time.
## - fmod(): Floating-point modulo — wraps elapsed time so the cycle repeats.
## - TAU: Constant for 2*PI (a full circle in radians). Used with sin() to
##   create a smooth oscillation for the sun's brightness curve.

## Emitted every frame with the current normalized time (0.0–1.0).
signal time_changed(time_of_day: float)

## Duration in seconds for one full day/night cycle.
@export var cycle_duration: float = 120.0

## The darkest color at midnight. CanvasModulate multiplies this onto the scene.
@export var night_color := Color(0.05, 0.06, 0.15)

## Elapsed time in seconds, wraps at cycle_duration.
var elapsed: float = 0.0


func _ready() -> void:
	color = Color.WHITE


func _process(delta: float) -> void:
	elapsed = fmod(elapsed + delta, cycle_duration)
	var time_of_day := elapsed / cycle_duration  # 0.0 to 1.0

	# Sine curve maps time to brightness:
	#   time 0.0 = sunrise, 0.25 = midday, 0.5 = sunset, 0.75 = midnight
	var sun_value := sin(time_of_day * TAU - PI / 2.0)  # -1 at midnight, +1 at midday
	var brightness := (sun_value + 1.0) / 2.0            # 0.0 at midnight, 1.0 at midday

	# Lerp between midnight darkness and full daylight
	color = night_color.lerp(Color.WHITE, brightness)

	time_changed.emit(time_of_day)
