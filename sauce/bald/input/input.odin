package input

/*

Platform independent input package, built on top of Sokol.

Just plug in event_callback in sokol setup and call it a day.

*/

import "core:log"

import sapp "bald:sokol/app"

// points to the input state all high level calls will act upon
state: ^Input

Input :: struct {
	keys: [MAX_KEYCODES]bit_set[Input_Flag],
	mouse_x, mouse_y: f32,
	scroll_x, scroll_y: f32,
}

Input_Flag :: enum u8 {
	down,
	pressed,
	released,
	repeat, // just for keysssssssssssss (after the first press. needed for text input stuff)
}

reset_input_state :: proc(input: ^Input) {
	for &key in input.keys {
		key -= ~{.down} // clear all except down flag
	}
	input.scroll_x = 0
	input.scroll_y = 0
}

add_input :: proc(dest: ^Input, src: Input) {
	dest.mouse_x = src.mouse_x
	dest.mouse_y = src.mouse_y
	dest.scroll_x += src.scroll_x
	dest.scroll_y += src.scroll_y
	for flags, key in src.keys {
		dest.keys[key] += flags
	}
}

key_pressed :: proc(code: Key_Code) -> bool {
	return .pressed in state.keys[code]
}
key_released :: proc(code: Key_Code) -> bool {
	return .released in state.keys[code]
}
key_down :: proc(code: Key_Code) -> bool {
	return .down in state.keys[code]
}
key_repeat :: proc(code: Key_Code) -> bool {
	return .repeat in state.keys[code]
}

// consuming keys is a very helpful pattern that simplifies gameplay / UI input a shit ton
consume_key_pressed :: proc(code: Key_Code) {
	state.keys[code] -= { .pressed }
}
consume_key_released :: proc(code: Key_Code) {
	state.keys[code] -= { .released }
}

any_key_press_and_consume :: proc() -> bool {

	for &key_flag, key in state.keys {
		if key >= int(Key_Code.LEFT_MOUSE) do continue // skip mouse keys

		if .pressed in key_flag {
			key_flag -= {.pressed} // consume
			return true
		}
	}

	return false
}

window_resize_callback: proc(width: int, height: int)

_actual_input_state: Input

import "bald:utils/logger"

// takes all the incoming input events
event_callback :: proc "c" (event: ^sapp.Event) { // events example: https://floooh.github.io/sokol-html5/events-sapp.html
	context = logger.get_context_for_logging() // only needed because we error down below

	input_state := &_actual_input_state

	#partial switch event.type {

		case .RESIZED:
		if window_resize_callback == nil {
			log.error("no window_resize_callback defined for input package")
		} else {
			window_resize_callback(int(event.window_width), int(event.window_height))
		}

		case .MOUSE_SCROLL:
		input_state.scroll_x = event.scroll_x
		input_state.scroll_y = event.scroll_y

		case .MOUSE_MOVE:
		input_state.mouse_x = event.mouse_x
		input_state.mouse_y = event.mouse_y

		case .MOUSE_UP:
		if .down in input_state.keys[map_sokol_mouse_button(event.mouse_button)] {
			input_state.keys[map_sokol_mouse_button(event.mouse_button)] -= { .down }
			input_state.keys[map_sokol_mouse_button(event.mouse_button)] += { .released }
		}
		case .MOUSE_DOWN:
		if !(.down in input_state.keys[map_sokol_mouse_button(event.mouse_button)]) {
			input_state.keys[map_sokol_mouse_button(event.mouse_button)] += { .down, .pressed }
		}

		case .KEY_UP:
		if .down in input_state.keys[event.key_code] {
			input_state.keys[event.key_code] -= { .down }
			input_state.keys[event.key_code] += { .released }
		}
		case .KEY_DOWN:
		if !event.key_repeat && !(.down in input_state.keys[event.key_code]) {
			input_state.keys[event.key_code] += { .down, .pressed }
		}
		if event.key_repeat {
			input_state.keys[event.key_code] += { .repeat }
		}
	}
}

//
// copied this enum from sokol_app to merge sapp.Keycode and sapp.Mousebutton
// This way, we can do a simple map Key_Code -> Action kinda vibe.
// Also cleans up our usage code a bit.

MAX_KEYCODES :: sapp.MAX_KEYCODES
Key_Code :: enum {
	INVALID = 0,
	SPACE = 32,
	APOSTROPHE = 39,
	COMMA = 44,
	MINUS = 45,
	PERIOD = 46,
	SLASH = 47,
	_0 = 48,
	_1 = 49,
	_2 = 50,
	_3 = 51,
	_4 = 52,
	_5 = 53,
	_6 = 54,
	_7 = 55,
	_8 = 56,
	_9 = 57,
	SEMICOLON = 59,
	EQUAL = 61,
	A = 65,
	B = 66,
	C = 67,
	D = 68,
	E = 69,
	F = 70,
	G = 71,
	H = 72,
	I = 73,
	J = 74,
	K = 75,
	L = 76,
	M = 77,
	N = 78,
	O = 79,
	P = 80,
	Q = 81,
	R = 82,
	S = 83,
	T = 84,
	U = 85,
	V = 86,
	W = 87,
	X = 88,
	Y = 89,
	Z = 90,
	LEFT_BRACKET = 91,
	BACKSLASH = 92,
	RIGHT_BRACKET = 93,
	GRAVE_ACCENT = 96,
	WORLD_1 = 161,
	WORLD_2 = 162,
	ESC = 256,
	ENTER = 257,
	TAB = 258,
	BACKSPACE = 259,
	INSERT = 260,
	DELETE = 261,
	RIGHT = 262,
	LEFT = 263,
	DOWN = 264,
	UP = 265,
	PAGE_UP = 266,
	PAGE_DOWN = 267,
	HOME = 268,
	END = 269,
	CAPS_LOCK = 280,
	SCROLL_LOCK = 281,
	NUM_LOCK = 282,
	PRINT_SCREEN = 283,
	PAUSE = 284,
	F1 = 290,
	F2 = 291,
	F3 = 292,
	F4 = 293,
	F5 = 294,
	F6 = 295,
	F7 = 296,
	F8 = 297,
	F9 = 298,
	F10 = 299,
	F11 = 300,
	F12 = 301,
	F13 = 302,
	F14 = 303,
	F15 = 304,
	F16 = 305,
	F17 = 306,
	F18 = 307,
	F19 = 308,
	F20 = 309,
	F21 = 310,
	F22 = 311,
	F23 = 312,
	F24 = 313,
	F25 = 314,
	KP_0 = 320,
	KP_1 = 321,
	KP_2 = 322,
	KP_3 = 323,
	KP_4 = 324,
	KP_5 = 325,
	KP_6 = 326,
	KP_7 = 327,
	KP_8 = 328,
	KP_9 = 329,
	KP_DECIMAL = 330,
	KP_DIVIDE = 331,
	KP_MULTIPLY = 332,
	KP_SUBTRACT = 333,
	KP_ADD = 334,
	KP_ENTER = 335,
	KP_EQUAL = 336,
	LEFT_SHIFT = 340,
	LEFT_CONTROL = 341,
	LEFT_ALT = 342,
	LEFT_SUPER = 343,
	RIGHT_SHIFT = 344,
	RIGHT_CONTROL = 345,
	RIGHT_ALT = 346,
	RIGHT_SUPER = 347,
	MENU = 348,

	// randy: adding the mouse buttons on the end here so we can unify the enum and not need to use sapp.Mousebutton
	LEFT_MOUSE = 400,
	RIGHT_MOUSE = 401,
	MIDDLE_MOUSE = 402,
}

map_sokol_mouse_button :: proc "c" (sokol_mouse_button: sapp.Mousebutton) -> Key_Code {
	#partial switch sokol_mouse_button {
		case .LEFT: return .LEFT_MOUSE
		case .RIGHT: return .RIGHT_MOUSE
		case .MIDDLE: return .MIDDLE_MOUSE
	}
	return nil
}

Vec2 :: [2]f32
Vec3 :: [3]f32
Vec4 :: [4]f32