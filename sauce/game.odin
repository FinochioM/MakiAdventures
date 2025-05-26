#+feature dynamic-literals
package main

/*

This is the file where you actually make the game.

It will grow pretty phat. This is where the magic happens.

GAMEPLAY O'CLOCK !

*/

import "bald:input"
import "bald:draw"
import "bald:sound"
import "bald:utils"
import "bald:utils/color"
import "bald:utils/shape"

import "core:log"
import "core:fmt"
import "core:mem"
import "core:math"
import "core:math/linalg"

import sapp "bald:sokol/app"
import spall "core:prof/spall"

VERSION :string: "v0.0.1"
WINDOW_TITLE :: "Makis Adventures"
GAME_RES_WIDTH :: 480
GAME_RES_HEIGHT :: 270
window_w := 1280
window_h := 720

when NOT_RELEASE {
	// can edit stuff in here to be whatever for testing
	PROFILE :: false
} else {
	// then this makes sure we've got the right settings for release
	PROFILE :: false
}

//
// epic game state

Game_State :: struct {
	ticks: u64,
	game_time_elapsed: f64,
	cam_pos: Vec2, // this is used by the renderer

	// entity system
	entity_top_count: int,
	latest_entity_id: int,
	entities: [MAX_ENTITIES]Entity,
	entity_free_list: [dynamic]int,

	// sloppy state dump
	player_handle: Entity_Handle,

	time_of_day: f32, // 0.0 -> 1.0 (0.0 night, 1.0 day)
	day_cycle_speed: f32, // how fast time passes

	lights: [dynamic]Light_Source,
	max_lights: int,

	scratch: struct {
		all_entities: []Entity_Handle,
	}
}

//
// action -> key mapping

action_map: map[Input_Action]input.Key_Code = {
	.left = .A,
	.right = .D,
	.up = .W,
	.down = .S,
	.click = .LEFT_MOUSE,
	.use = .RIGHT_MOUSE,
	.interact = .E,
}

Input_Action :: enum u8 {
	left,
	right,
	up,
	down,
	click,
	use,
	interact,
}

Light_Source :: struct {
	pos: Vec2,
	radius: f32,
	intensity: f32,
	color: Vec4,
	active: bool,
	flicker: bool,
	flicker_speed: f32,
	flicker_amount: f32,
}

//
// entity system

Entity :: struct {
	handle: Entity_Handle,
	kind: Entity_Kind,

	// todo, move this into static entity data
	update_proc: proc(^Entity),
	draw_proc: proc(Entity),

	// big sloppy entity state dump.
	// add whatever you need in here.
	pos: Vec2,
	last_known_x_dir: f32,
	flip_x: bool,
	draw_offset: Vec2,
	draw_pivot: Pivot,
	rotation: f32,
	hit_flash: Vec4,
	sprite: Sprite_Name,
	anim_index: int,
  	next_frame_end_time: f64,
  	loop: bool,
  	frame_duration: f32,

	health: f32,
	max_health: f32,
	hunger: f32,
	max_hunger: f32,
	time_since_last_hunger_damage: f32,
	running_time: f32,

	light_index: int,

	state: enum {
		alive,
		dying,
		dead,
	},

	// this gets zeroed every frame. Useful for passing data to other systems.
	scratch: struct {
		col_override: Vec4,
	}
}

Entity_Kind :: enum {
	nil,
	player,
	thing1,
	torch,
}

entity_setup :: proc(e: ^Entity, kind: Entity_Kind) {
	// entity defaults
	e.draw_proc = draw_entity_default
	e.draw_pivot = .bottom_center

	switch kind {
		case .nil:
		case .player: setup_player(e)
		case .thing1: setup_thing1(e)
		case .torch:  setup_torch(e)
	}
}

//
// main game procs

app_init :: proc() {

}

app_frame :: proc() {

	// right now we are just calling the game update, but in future this is where you'd do a big
	// "UX" switch for startup splash, main menu, settings, in-game, etc

	{
		// ui space example
		draw.push_coord_space(get_screen_space())

		x, y := screen_pivot(.top_left)
		x += 2
		y -= 2
		//draw.draw_text({x, y}, "hello world.", z_layer=.ui, pivot=Pivot.top_left)
	}

	//sound.play_continuously("event:/ambiance", "")

	game_update()
	game_draw()

	volume :f32= 0.75
	sound.update(get_player().pos, volume)
}

app_shutdown :: proc() {
	// called on exit
}

game_update :: proc() {
	ctx.gs.scratch = {} // auto-zero scratch for each update
	defer {
		// update at the end
		ctx.gs.game_time_elapsed += f64(ctx.delta_t)
		ctx.gs.ticks += 1
	}

	// this'll be using the last frame's camera position, but it's fine for most things
	draw.push_coord_space(get_world_space())

	// setup world for first game tick
	if ctx.gs.ticks == 0 {
		init_lightning()

		torch := entity_create(.torch)
		torch.pos = Vec2{20,20}

		player := entity_create(.player)
		ctx.gs.player_handle = player.handle


		ctx.gs.day_cycle_speed = 0.005 // 200 seconds
		ctx.gs.time_of_day = 0.0
	}

	rebuild_scratch_helpers()

	// big :update time
	for handle in get_all_ents() {
		e := entity_from_handle(handle)

		update_entity_animation(e)

		if e.update_proc != nil {
			e.update_proc(e)
		}
	}

	if input.key_pressed(.LEFT_MOUSE) {
		input.consume_key_pressed(.LEFT_MOUSE)

		pos := mouse_pos_in_current_space()
		log.info("schloop at", pos)
		sound.play("event:/schloop", pos=pos)
	}

	utils.animate_to_target_v2(&ctx.gs.cam_pos, get_player().pos, ctx.delta_t, rate=10)

	// ... add whatever other systems you need here to make epic game

	// day & night
	ctx.gs.time_of_day += ctx.delta_t * ctx.gs.day_cycle_speed
	if ctx.gs.time_of_day >= 1.0 {
		ctx.gs.time_of_day -= 1.0
	}

	update_lights()

	// TESTING DAY AND NIGHT
	if input.key_pressed(.L) {
		ctx.gs.day_cycle_speed *= 0.5
		input.consume_key_pressed(.L)
	}
	if input.key_pressed(.J) {
		ctx.gs.day_cycle_speed *= 2.0
		input.consume_key_pressed(.J)
	}
}

rebuild_scratch_helpers :: proc() {
	// construct the list of all entities on the temp allocator
	// that way it's easier to loop over later on
	all_ents := make([dynamic]Entity_Handle, 0, len(ctx.gs.entities), allocator=context.temp_allocator)
	for &e in ctx.gs.entities {
		if !is_valid(e) do continue
		append(&all_ents, e.handle)
	}
	ctx.gs.scratch.all_entities = all_ents[:]
}

game_draw :: proc() {

	// this is so we can get the current pixel in the shader in world space (VERYYY useful)
	draw.draw_frame.ndc_to_world_xform = get_world_space_camera() * linalg.inverse(get_world_space_proj())
	draw.draw_frame.bg_repeat_tex0_atlas_uv = draw.atlas_uv_from_sprite(.bg_repeat_tex0)

	// background thing
	{
		// identity matrices, so we're in clip space
		draw.push_coord_space({proj=Matrix4(1), camera=Matrix4(1)})

		// draw rect that covers the whole screen
		draw.draw_rect(Rect{ -1, -1, 1, 1}, flags=.background_pixels) // we leave it in the hands of the shader
	}

	// world
	{
		draw.push_coord_space(get_world_space())

		draw.draw_sprite({10, 10}, .player_still, col_override=Vec4{1,0,0,0.4})
		draw.draw_sprite({-10, 10}, .player_still)

		draw.draw_text({0, -50}, "sugon", pivot=.bottom_center, col={0,0,0,0.5})

		for handle in get_all_ents() {
			e := entity_from_handle(handle)
			e.draw_proc(e^)
		}
	}

	// ui?
	{
		draw.push_coord_space(get_screen_space())

		player := get_player()

		bar_width := f32(100)
		bar_height := f32(10)
		bar_spacing := f32(10)
		x, y := screen_pivot(.top_left)
		x += 2
		y -= 20
		bar_x := x
		health_bar_y := y
		hunger_bar_y := y - 12

		health_bg_rect := Rect{bar_x, health_bar_y, bar_x + bar_width, health_bar_y + bar_height}
		draw.draw_rect(health_bg_rect, col = Vec4{0.2, 0.2, 0.2, 0.9})

		health_fill_width := (player.health / player.max_health) * bar_width
		health_fill_rect := Rect{bar_x, health_bar_y, bar_x + health_fill_width, health_bar_y + bar_height}
		draw.draw_rect(health_fill_rect, col = Vec4{1.0, 0.0, 0.0, 0.8})

		hunger_bg_rect := Rect{bar_x, hunger_bar_y, bar_x + bar_width, hunger_bar_y + bar_height}
		draw.draw_rect(hunger_bg_rect, col = Vec4{0.2, 0.2, 0.2, 0.9})

		hunger_fill_width := (player.hunger / player.max_hunger) * bar_width
		hunger_fill_rect := Rect{bar_x, hunger_bar_y, bar_x + hunger_fill_width, hunger_bar_y + bar_height}
		draw.draw_rect(hunger_fill_rect, col = Vec4{0.8, 0.6, 0.0, 0.8})

		time_str := fmt.tprintf("Time: %.2f", ctx.gs.time_of_day)
		time_x, time_y := screen_pivot(.top_right)
		time_x -= 10
		time_y -= 30
		draw.draw_text({time_x, time_y}, time_str, z_layer = .ui, pivot = .top_right)
	}
}

//
// ~ Gameplay Slop Waterline ~
//
// From here on out, it's gameplay slop time.
// Structure beyond this point just slows things down.
//
// No point trying to make things 'reusable' for future projects.
// It's trivially easy to just copy and paste when needed.
//

// shorthand for getting the player
get_player :: proc() -> ^Entity {
	return entity_from_handle(ctx.gs.player_handle)
}

setup_player :: proc(e: ^Entity) {
	e.kind = .player

	e.max_health = 20.0
	e.health = e.max_health
	e.max_hunger = 10.0
	e.hunger = e.max_hunger
	e.time_since_last_hunger_damage = 0.0
	e.running_time = 0.0
	e.state = .alive

	// this offset is to take it from the bottom center of the aseprite document
	// and center it at the feet
	e.draw_offset = Vec2{0.5, 5}
	e.draw_pivot = .bottom_center

	e.update_proc = proc(e: ^Entity) {
		if e.state == .dying {
			if e.anim_index > get_frame_count(.player_death) - 1 && end_time_up(e.next_frame_end_time) {
				e.state = .dead
				respawn_player(e)
				return
			}

			return
		}

		if e.state == .alive && e.health <= 0 {
			e.state = .dying
			entity_set_animation(e, .player_death, 0.2, looping = false)
			// play sound here
			return
		}

		if e.state == .alive {
			input_dir := get_input_vector()
			is_running := input_dir != {}

			e.pos += input_dir * 100.0 * ctx.delta_t

			if input_dir.x != 0 {
				e.last_known_x_dir = input_dir.x
			}

			e.flip_x = e.last_known_x_dir < 0

			if !is_running  {
				entity_set_animation(e, .player_idle, 0.3)
				e.running_time = 0.0 // reset when not running
			} else {
				entity_set_animation(e, .player_run, 0.1)

				e.running_time += ctx.delta_t

				if e.running_time > 1.0 {
					e.hunger -= (ctx.delta_t / 30.0)
					if e.hunger < 0.0 {
						e.hunger = 0.0
					}
				}
			}

			if e.hunger <= 0.0 {
				e.time_since_last_hunger_damage += ctx.delta_t
				if e.time_since_last_hunger_damage >= 2.0 {
					e.health -= 1.0
					e.time_since_last_hunger_damage = 0.0

					e.hit_flash = Vec4{1, 0, 0, 0.5}
				}
			}

			if input.key_pressed(.H) {
				e.health -= 1.0
				input.consume_key_pressed(.H)

				e.hit_flash = Vec4{1, 0, 0, 0.5}
			}

			if e.health < 0.0 {
				e.health = 0.0
			}

			if e.hit_flash.a > 0.0 {
				e.hit_flash.a -= ctx.delta_t * 2.0
				if e.hit_flash.a < 0.0 {
					e.hit_flash.a = 0.0
				}
			}

			e.scratch.col_override = Vec4{0,0,1,0.2}
		}

		e.draw_proc = proc(e: Entity) {
			draw.draw_sprite(e.pos, .shadow_medium, col={1,1,1,0.2})
			draw_entity_default(e)
		}
	}
}

respawn_player :: proc(e: ^Entity) {
	e.health = 20.0
	e.hunger = 10.0

	e.pos = Vec2{0, 0}

	e.state = .alive

	entity_set_animation(e, .player_idle, 0.3)

	// play sound
}

setup_thing1 :: proc(using e: ^Entity) {
	kind = .thing1
}

entity_set_animation :: proc(e: ^Entity, sprite: Sprite_Name, frame_duration: f32, looping:=true) {
	if e.sprite != sprite {
		e.sprite = sprite
		e.loop = looping
		e.frame_duration = frame_duration
		e.anim_index = 0
		e.next_frame_end_time = 0
	}
}

update_entity_animation :: proc(e: ^Entity) {
	if e.frame_duration == 0 do return

	frame_count := get_frame_count(e.sprite)

	is_playing := true
	if !e.loop {
		is_playing = e.anim_index + 1 <= frame_count
	}

	if is_playing {

		if e.next_frame_end_time == 0 {
			e.next_frame_end_time = now() + f64(e.frame_duration)
		}

		if end_time_up(e.next_frame_end_time) {
			e.anim_index += 1
			e.next_frame_end_time = 0
			//e.did_frame_advance = true
			if e.anim_index >= frame_count {

				if e.loop {
					e.anim_index = 0
				}

			}
		}
	}
}

init_lightning :: proc() {
	ctx.gs.max_lights = 8
	ctx.gs.lights = make([dynamic]Light_Source, 0, ctx.gs.max_lights)
}

add_light :: proc(pos: Vec2, radius: f32, color: Vec4, intensity: f32, flicker: bool = false) -> int {
	if len(ctx.gs.lights) >= ctx.gs.max_lights {
		return -1
	}

	light := Light_Source {
		pos = pos,
		radius = radius,
		color = color,
		intensity = intensity,
		active = true,
		flicker = flicker,
		flicker_speed = 5.0,
		flicker_amount = 0.2,
	}

	append(&ctx.gs.lights, light)
	return len(ctx.gs.lights) - 1
}

update_light_position :: proc(index: int, pos: Vec2) {
	if index >= 0 && index < len(ctx.gs.lights) {
		ctx.gs.lights[index].pos = pos
	}
}

set_light_active :: proc(index: int, active: bool) {
	if index >= 0 && index < len(ctx.gs.lights) {
		ctx.gs.lights[index].active = active
	}
}

update_lights :: proc() {
	for i := 0; i < len(ctx.gs.lights); i += 1 {
		light := &ctx.gs.lights[i]

		if light.flicker && light.active {
			flicker_value := math.sin(f32(app_now()) * light.flicker_speed) * light.flicker_amount
			light.color.a = light.intensity * (1.0 + flicker_value)
		} else {
			light.color.a = light.intensity
		}
	}

	for i := 0; i < ctx.gs.max_lights; i += 1 {
		draw.draw_frame.shader_data.light_positions[i] = {}
		draw.draw_frame.shader_data.light_colors[i] = {}
	}

	light_count := 0
	for i := 0; i < len(ctx.gs.lights); i += 1 {
		light := ctx.gs.lights[i]

		if light.active {
			draw.draw_frame.shader_data.light_positions[light_count] = {light.pos.x, light.pos.y, 0, light.radius}
			draw.draw_frame.shader_data.light_colors[light_count] = light.color
			light_count += 1
		}
	}

	draw.draw_frame.shader_data.light_count = i32(light_count)
	draw.draw_frame.shader_data.time_of_day = ctx.gs.time_of_day
}

setup_torch :: proc(e: ^Entity) {
	e.kind = .torch
	e.sprite = .torch
	e.draw_pivot = .bottom_center

	light_radius := f32(200)
	light_color := Vec4{1.0, 0.7, 0.3, 0.8}

	e.light_index = add_light(e.pos, light_radius, light_color, 0.8, flicker = true)

	e.update_proc = proc(e: ^Entity) {
		is_night := ctx.gs.time_of_day >= 0.5 || ctx.gs.time_of_day < 0.1

		set_light_active(e.light_index, is_night)

		update_light_position(e.light_index, e.pos)
	}
}