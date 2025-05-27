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
import "core:math/noise"

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

	enemy_spawn_timer: f32,
	enemy_spawn_interval: f32,
	max_enemies: int,
	current_enemy_count: int,
	last_night_check: bool,

	world_tiles: [WORLD_SIZE][WORLD_SIZE]World_Tile,
	world_generated: bool,
	terrain_seed: i64,
	moisture_seed: i64,
	fertility_seed: i64,

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

WORLD_SIZE :: 512
TILE_SIZE :: 32

Tile_Type :: enum u8 {
	grass,
	dirt,
	stone,
	water,
	sand,
}

Biome_Type :: enum {
	grassland,
	forest,
	desert,
	swamp,
	rocky,
}

World_Tile :: struct {
	type: Tile_Type,
	biome: Biome_Type,
	fertility: f32, // affects resource spawning
	moisture: f32, // affects what can grow and what cannot
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

	// enemy fields
	speed: f32,
	damage: f32,
	sunlight_damage_timer: f32,
	sunlight_damage_interval: f32,
	last_damage_time: f64,
	damage_cooldown: f32,

	// player attack
	attack_damage: f32,
	attack_cooldown: f32,
	last_attack_time: f64,
    show_attack_rect: bool,
    attack_rect_pos: Vec2,
    attack_rect_size: Vec2,
    attack_rect_duration: f32,
    attack_rect_timer: f32,

	// this gets zeroed every frame. Useful for passing data to other systems.
	scratch: struct {
		col_override: Vec4,
	}
}

Entity_Kind :: enum {
	nil,
	player,
	torch,
	enemy,
	tree,
	rock,
}

entity_setup :: proc(e: ^Entity, kind: Entity_Kind) {
	// entity defaults
	e.draw_proc = draw_entity_default
	e.draw_pivot = .bottom_center

	switch kind {
		case .nil:
		case .player: setup_player(e)
		case .torch:  setup_torch(e)
		case .enemy:  setup_enemy(e)
		case .tree:   setup_tree(e)
		case .rock:   setup_rock(e)
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
		generate_world()

		init_lightning()

		torch := entity_create(.torch)
		torch.pos = Vec2{40,20}

		torch1 := entity_create(.torch)
		torch1.pos = Vec2{-60,20}

		player := entity_create(.player)
		ctx.gs.player_handle = player.handle

		ctx.gs.day_cycle_speed = 0.005 // 200 seconds -> 0.005
		ctx.gs.time_of_day = 0.0

		ctx.gs.enemy_spawn_interval = 3.0
		ctx.gs.enemy_spawn_timer = 0.0
		ctx.gs.max_enemies = 10
		ctx.gs.current_enemy_count = 0
		ctx.gs.last_night_check = false
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

	utils.animate_to_target_v2(&ctx.gs.cam_pos, get_player().pos, ctx.delta_t, rate=10)

	//constrain_camera_to_world_bounds()

	// ... add whatever other systems you need here to make epic game

	// day & night
	ctx.gs.time_of_day += ctx.delta_t * ctx.gs.day_cycle_speed
	if ctx.gs.time_of_day >= 1.0 {
		ctx.gs.time_of_day -= 1.0
	}

	update_lights()

	is_night := ctx.gs.time_of_day >= 0.5 || ctx.gs.time_of_day < 0.1

	if is_night {
		ctx.gs.enemy_spawn_timer += ctx.delta_t
		if ctx.gs.enemy_spawn_timer >= ctx.gs.enemy_spawn_interval {
			spawn_enemy()
			ctx.gs.enemy_spawn_timer = 0.0
		}
	} else {
		ctx.gs.enemy_spawn_timer = 0.0
	}

	/*
	if !ctx.gs.last_night_check && !is_night {
		log.info("Dawn breaks")
	}
	*/

	ctx.gs.last_night_check = is_night

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

	/*
	// background thing
	{
		// identity matrices, so we're in clip space
		draw.push_coord_space({proj=Matrix4(1), camera=Matrix4(1)})

		// draw rect that covers the whole screen
		draw.draw_rect(Rect{ -1, -1, 1, 1}, flags=.background_pixels) // we leave it in the hands of the shader
	}
	*/

   {
        draw.push_coord_space(get_world_space())

        render_world_tiles()

        draw.push_z_layer(.shadow)
        for handle in get_all_ents() {
            e := entity_from_handle(handle)
            if e.kind == .player || e.kind == .enemy {
                draw.draw_sprite(e.pos, .shadow_medium, col={1,1,1,0.2})
            }
        }

        draw.push_z_layer(.playspace)
        for handle in get_all_ents() {
            e := entity_from_handle(handle)
            e.draw_proc(e^)
        }
    }

	// ui?
	{
		draw.push_coord_space(get_screen_space())

		player := get_player()

		flags := Quad_Flags.ui_element

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
		draw.draw_rect(health_bg_rect, col = Vec4{0.2, 0.2, 0.2, 0.9}, flags = flags, z_layer = .ui)

		health_fill_width := (player.health / player.max_health) * bar_width
		health_fill_rect := Rect{bar_x, health_bar_y, bar_x + health_fill_width, health_bar_y + bar_height}
		draw.draw_rect(health_fill_rect, col = Vec4{1.0, 0.0, 0.0, 0.8}, flags = flags, z_layer = .ui)

		hunger_bg_rect := Rect{bar_x, hunger_bar_y, bar_x + bar_width, hunger_bar_y + bar_height}
		draw.draw_rect(hunger_bg_rect, col = Vec4{0.2, 0.2, 0.2, 0.9}, flags = flags, z_layer = .ui)

		hunger_fill_width := (player.hunger / player.max_hunger) * bar_width
		hunger_fill_rect := Rect{bar_x, hunger_bar_y, bar_x + hunger_fill_width, hunger_bar_y + bar_height}
		draw.draw_rect(hunger_fill_rect, col = Vec4{0.8, 0.6, 0.0, 0.8}, flags = flags, z_layer = .ui)

		time_str := fmt.tprintf("Time: %.2f", ctx.gs.time_of_day)
		time_x, time_y := screen_pivot(.top_right)
		time_x -= 10
		time_y -= 30
		draw.draw_text({time_x, time_y}, time_str, z_layer = .ui, pivot = .top_right, flags = flags)
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

	e.attack_damage = 1.0
	e.attack_cooldown = 0.5
	e.last_attack_time = 0.0

    e.show_attack_rect = false
    e.attack_rect_duration = 0.3
    e.attack_rect_timer = 0

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

			update_player_bounds(e)

			if e.hunger <= 0.0 {
				e.time_since_last_hunger_damage += ctx.delta_t
				if e.time_since_last_hunger_damage >= 2.0 {
					e.health -= 1.0
					e.time_since_last_hunger_damage = 0.0

					e.hit_flash = Vec4{1, 0, 0, 0.5}
				}
			}

			if is_action_pressed(.click) {
				current_time := now()
				if current_time - e.last_attack_time >= f64(e.attack_cooldown) {
					player_attack(e)
					e.last_attack_time = current_time
				}
			}

			if is_action_pressed(.interact) {
				interact_with_world(e)
			}

            if e.show_attack_rect {
                e.attack_rect_timer += ctx.delta_t
                if e.attack_rect_timer >= e.attack_rect_duration {
                    e.show_attack_rect = false
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

           if e.show_attack_rect {
                // Calculate alpha based on remaining time
                alpha := 1.0 - (e.attack_rect_timer / e.attack_rect_duration)

                // Create rect and draw it
                attack_rect := shape.rect_make(e.attack_rect_pos, e.attack_rect_size, utils.Pivot.center_center)
                draw.draw_rect(attack_rect, col=Vec4{1, 0, 0, alpha * 0.5}, outline_col=Vec4{1, 0, 0, alpha}, z_layer = .playspace)
            }
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
		flicker_amount = 0.05,
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

setup_enemy :: proc(e: ^Entity) {
	e.kind = .enemy
	e.sprite = .player_idle
	e.health = 3.0
	e.max_health = 3.0
	e.speed = 30.0
	e.damage = 2.0
	e.damage_cooldown = 1.0
	e.sunlight_damage_interval = 0.5
	e.sunlight_damage_timer = 0.0
	e.last_damage_time = 0.0

	e.draw_offset = Vec2{0.5, 5}
	e.draw_pivot = .bottom_center

	ctx.gs.current_enemy_count += 1

	e.update_proc = proc(e: ^Entity) {
		player := get_player()
		if player == nil || player.state != .alive {
			return
		}

		is_day := ctx.gs.time_of_day > 0.1 && ctx.gs.time_of_day < 0.5
		if is_day {
			e.sunlight_damage_timer += ctx.delta_t
			if e.sunlight_damage_timer >= e.sunlight_damage_interval {
				e.health -= 1.0
				e.sunlight_damage_timer = 0.0
				e.hit_flash = Vec4{1, 1, 0, 0.8}
			}
		}

		if e.health <= 0 {
			ctx.gs.current_enemy_count -= 1
			entity_destroy(e)
			return
		}

		direction := linalg.normalize(player.pos - e.pos)
		e.pos += direction * e.speed * ctx.delta_t

		if direction.x != 0 {
			e.flip_x = direction.x < 0
		}

		entity_set_animation(e, .player_run, 0.15)

		enemy_rect := shape.rect_make(e.pos - Vec2{8, 0}, Vec2{16, 16}, Pivot.center_center)
		player_rect := shape.rect_make(player.pos - Vec2{8, 0}, Vec2{16, 16}, Pivot.center_center)

		if colliding, _:= shape.collide(enemy_rect, player_rect); colliding {
			current_time := now()
			if current_time - e.last_damage_time >= f64(e.damage_cooldown) {
				player.health -= e.damage
				player.hit_flash = Vec4{1, 0, 0, 0.8}
				e.last_damage_time = current_time

				// play hit sound
			}
		}

		if e.hit_flash.a > 0.0 {
			e.hit_flash.a -= ctx.delta_t * 3.0
			if e.hit_flash.a < 0.0 {
				e.hit_flash.a = 0.0
			}
		}
	}

	e.draw_proc = proc(e: Entity) {
		e := e
		draw.draw_sprite(e.pos, .shadow_medium, col = {1, 1, 1, 0.2})

		col_override := Vec4{0.8, 0.2, 0.2, 0.6}
		if e.hit_flash.a > 0.0 {
			col_override = Vec4{
				max(col_override.r, e.hit_flash.r),
				max(col_override.g, e.hit_flash.g),
				max(col_override.b, e.hit_flash.b),
				max(col_override.a, e.hit_flash.a),
			}
		}

		draw_sprite_entity(&e, e.pos, e.sprite,
							flip_x = e.flip_x,
							draw_offset = e.draw_offset,
							pivot = e.draw_pivot,
							anim_index = e.anim_index,
							col_override = col_override)
	}
}

get_spawn_position_offscreen :: proc() -> Vec2 {
	cam_pos := ctx.gs.cam_pos
	zoom := get_camera_zoom()
	viewport_width := f32(window_w) / zoom
	viewport_height := f32(window_h) / zoom

	spawn_distance := f32(100)

	side := utils.rand_int(4)

	spawn_pos: Vec2

	switch side {
	case 0: // Top
		spawn_pos.x = cam_pos.x + utils.rand_f32_range(-viewport_width/2 - spawn_distance, viewport_width/2 + spawn_distance)
		spawn_pos.y = cam_pos.y + viewport_height/2 + spawn_distance
	case 1: // Right
		spawn_pos.x = cam_pos.x + viewport_width/2 + spawn_distance
		spawn_pos.y = cam_pos.y + utils.rand_f32_range(-viewport_height/2 - spawn_distance, viewport_height/2 + spawn_distance)
	case 2: // Bottom
		spawn_pos.x = cam_pos.x + utils.rand_f32_range(-viewport_width/2 - spawn_distance, viewport_width/2 + spawn_distance)
		spawn_pos.y = cam_pos.y - viewport_height/2 - spawn_distance
	case 3: // Left
		spawn_pos.x = cam_pos.x - viewport_width/2 - spawn_distance
		spawn_pos.y = cam_pos.y + utils.rand_f32_range(-viewport_height/2 - spawn_distance, viewport_height/2 + spawn_distance)
	}

	return spawn_pos
}

spawn_enemy :: proc() {
	if ctx.gs.current_enemy_count >= ctx.gs.max_enemies {
		return
	}

	enemy := entity_create(.enemy)
	enemy.pos = get_spawn_position_offscreen()
}

player_attack :: proc(player: ^Entity) {
    mouse_pos := mouse_pos_in_current_space()

    max_attack_range := f32(20.0)
    sprite_size := Vec2{16.0, 16.0}
    player_visual_center := player.pos + Vec2{0, sprite_size.y * 0.5 - player.draw_offset.y}

    center_to_mouse_dist := linalg.length(player_visual_center - mouse_pos)

    attack_pos := mouse_pos
    if center_to_mouse_dist > max_attack_range {
        attack_dir := linalg.normalize(mouse_pos - player_visual_center)
        attack_pos = player_visual_center + attack_dir * max_attack_range
    }

    attack_size := Vec2{20.0, 20.0}
    attack_rect := shape.rect_make(attack_pos - attack_size / 2, attack_size, utils.Pivot.center_center)

    player.show_attack_rect = true
    player.attack_rect_pos = attack_pos
    player.attack_rect_size = attack_size
    player.attack_rect_timer = 0
    player.attack_rect_duration = 0.3

    for handle in get_all_ents() {
        e := entity_from_handle(handle)

        if e.kind != .enemy || e.health <= 0 {
            continue
        }

        enemy_circle := shape.Circle{
            pos = e.pos,
            radius = 16.0,
        }

        if colliding, _ := shape.collide(attack_rect, enemy_circle); colliding {
            e.health -= player.attack_damage
            e.hit_flash = Vec4{1, 0.5, 0, 0.8}
            break
        }
    }
}

generate_world :: proc() {
    ctx.gs.terrain_seed = 12345
    ctx.gs.moisture_seed = 54321
    ctx.gs.fertility_seed = 98765

    log.info("Generating world...")

    for y in 0..<WORLD_SIZE {
        for x in 0..<WORLD_SIZE {
            tile := &ctx.gs.world_tiles[x][y]

            world_x := f32(x) / f32(WORLD_SIZE)
            world_y := f32(y) / f32(WORLD_SIZE)

            terrain_noise := noise.noise_2d(ctx.gs.terrain_seed, {auto_cast world_x * 8, auto_cast world_y * 8}) * 0.5 +
                           noise.noise_2d(ctx.gs.terrain_seed, {auto_cast world_x * 16, auto_cast world_y * 16}) * 0.3 +
                           noise.noise_2d(ctx.gs.terrain_seed, {auto_cast world_x * 32, auto_cast world_y * 32}) * 0.2

            moisture_noise := noise.noise_2d(ctx.gs.moisture_seed, {auto_cast world_x * 6, auto_cast world_y * 6})
            fertility_noise := noise.noise_2d(ctx.gs.fertility_seed, {auto_cast world_x * 4, auto_cast world_y * 4})

            terrain_value := (terrain_noise + 1.0) * 0.5
            tile.moisture = (moisture_noise + 1.0) * 0.5
            tile.fertility = (fertility_noise + 1.0) * 0.5

            if tile.moisture > 0.7 && terrain_value < 0.3 {
                tile.biome = .swamp
                tile.type = .water
            } else if tile.moisture < 0.3 && terrain_value > 0.6 {
                tile.biome = .desert
                tile.type = .sand
            } else if terrain_value > 0.8 {
                tile.biome = .rocky
                tile.type = .stone
            } else if tile.fertility > 0.6 {
                tile.biome = .forest
                tile.type = .grass
            } else {
                tile.biome = .grassland
                tile.type = .grass
            }
        }
    }

    place_world_resources()

    ctx.gs.world_generated = true
    log.info("World generation complete!")
}

place_world_resources :: proc() {
    tree_count := 0
    rock_count := 0

    for y in 0..<WORLD_SIZE {
        for x in 0..<WORLD_SIZE {
            tile := ctx.gs.world_tiles[x][y]
            world_pos := tile_to_world(x, y)

            if tile.type == .water {
                continue
            }

            spawn_chance := tile.fertility * 0.1

            #partial switch tile.biome {
            case .forest:
                if utils.pct_chance(spawn_chance * 3.0) && tree_count < 1000 {
                    tree := entity_create(.tree)
                    tree.pos = world_pos + Vec2{
                        utils.rand_f32_range(0, TILE_SIZE),
                        utils.rand_f32_range(0, TILE_SIZE)
                    }
                    tree_count += 1
                }

            case .rocky:
                if utils.pct_chance(spawn_chance * 2.0) && rock_count < 500 {
                    rock := entity_create(.rock)
                    rock.pos = world_pos + Vec2{
                        utils.rand_f32_range(0, TILE_SIZE),
                        utils.rand_f32_range(0, TILE_SIZE)
                    }
                    rock_count += 1
                }

            case .grassland:
                if utils.pct_chance(spawn_chance * 0.5) && tree_count < 1000 {
                    tree := entity_create(.tree)
                    tree.pos = world_pos + Vec2{
                        utils.rand_f32_range(0, TILE_SIZE),
                        utils.rand_f32_range(0, TILE_SIZE)
                    }
                    tree_count += 1
                }

            case .desert:
                if utils.pct_chance(spawn_chance * 0.2) && rock_count < 500 {
                    rock := entity_create(.rock)
                    rock.pos = world_pos + Vec2{
                        utils.rand_f32_range(0, TILE_SIZE),
                        utils.rand_f32_range(0, TILE_SIZE)
                    }
                    rock_count += 1
                }
            }
        }
    }

    log.info("Placed resources: trees={}, rocks={}", tree_count, rock_count)
}

get_tile_at_pos :: proc(world_pos: Vec2) -> ^World_Tile {
    tile_x, tile_y := world_to_tile(world_pos)

    if tile_x < 0 || tile_x >= WORLD_SIZE || tile_y < 0 || tile_y >= WORLD_SIZE {
        return nil
    }

    return &ctx.gs.world_tiles[tile_x][tile_y]
}

render_world_tiles :: proc() {
    cam_pos := ctx.gs.cam_pos
    zoom := get_camera_zoom()
    viewport_width := f32(window_w) / zoom
    viewport_height := f32(window_h) / zoom

    cam_tile_x, cam_tile_y := world_to_tile(cam_pos)

    padding := int(TILE_SIZE)

    tiles_in_view_x := int(viewport_width / TILE_SIZE) + 2
    tiles_in_view_y := int(viewport_height / TILE_SIZE) + 2

    start_x := cam_tile_x - tiles_in_view_x/2
    end_x := cam_tile_x + tiles_in_view_x/2
    start_y := cam_tile_y - tiles_in_view_y/2
    end_y := cam_tile_y + tiles_in_view_y/2

    start_x = max(0, start_x)
    end_x = min(WORLD_SIZE - 1, end_x)
    start_y = max(0, start_y)
    end_y = min(WORLD_SIZE - 1, end_y)

    tiles_width := end_x - start_x + 1
    tiles_height := end_y - start_y + 1
    total_tiles := tiles_width * tiles_height

    max_tiles_to_render := 7000

    if total_tiles > max_tiles_to_render {
        center_x := (start_x + end_x) / 2
        center_y := (start_y + end_y) / 2

        max_dimension := int(math.sqrt(f32(max_tiles_to_render)))
        half_width := max_dimension / 2
        half_height := max_dimension / 2

        start_x = max(0, center_x - half_width)
        end_x = min(WORLD_SIZE - 1, center_x + half_width)
        start_y = max(0, center_y - half_height)
        end_y = min(WORLD_SIZE - 1, center_y + half_height)
    }

    pixel_overlap := f32(0.5)

    for y in start_y..=end_y {
        for x in start_x..=end_x {
            tile := ctx.gs.world_tiles[x][y]

            world_pos := tile_to_world(x, y)

            adjusted_pos := Vec2{
                world_pos.x - pixel_overlap,
                world_pos.y - pixel_overlap
            }

            size_adjust := Vec2{TILE_SIZE + pixel_overlap * 2, TILE_SIZE + pixel_overlap * 2}

            sprite := get_sprite_for_tile_type(tile.type)
            if sprite != .nil {
                rect := shape.rect_make(adjusted_pos, size_adjust, Pivot.bottom_left)
                draw.draw_rect(
                    rect,
                    sprite = sprite,
                    z_layer = .background
                )
            }
        }
    }
}

get_sprite_for_tile_type :: proc(tile_type: Tile_Type) -> Sprite_Name {
	switch tile_type {
		case .grass: return .tile_grass
		case .dirt: return .tile_dirt
		case .stone: return .tile_stone
		case .water: return .tile_water
		case .sand: return .tile_sand
	}

	return nil
}

setup_tree :: proc(e: ^Entity) {
	e.kind = .tree
	e.sprite = .tree
	e.health = 3.0
	e.draw_pivot = .bottom_center

	e.update_proc = proc(e: ^Entity) {
		if e.health <= 0 {
			entity_destroy(e)
		}
	}
}

setup_rock :: proc(e: ^Entity) {
	e.kind = .rock
	e.sprite = .rock
	e.health = 5.0
	e.draw_pivot = .bottom_center

	e.update_proc = proc(e: ^Entity) {
		if e.health <= 0 {
			entity_destroy(e)
		}
	}
}

interact_with_world :: proc(player: ^Entity) {
    interact_range := f32(40.0)

    for handle in get_all_ents() {
        e := entity_from_handle(handle)

        if e.kind != .tree && e.kind != .rock {
            continue
        }

        distance := linalg.length(player.pos - e.pos)
        if distance <= interact_range {
            e.health -= 1.0
            e.hit_flash = Vec4{1, 1, 1, 0.5}

            // Play interaction sound here
            break
        }
    }
}

update_player_bounds :: proc(player: ^Entity) {
    world_size_pixels := f32(WORLD_SIZE * TILE_SIZE)
    half_size := world_size_pixels / 2

    margin := f32(1)

    player.pos.x = math.clamp(player.pos.x, -half_size + margin, half_size - margin)
    player.pos.y = math.clamp(player.pos.y, -half_size + margin, half_size - margin)
}

constrain_camera_to_world_bounds :: proc() {
    zoom := get_camera_zoom()
    viewport_width := f32(window_w) / zoom
    viewport_height := f32(window_h) / zoom

    world_bounds := f32(WORLD_SIZE * TILE_SIZE)

    half_viewport_width := viewport_width / 2
    half_viewport_height := viewport_height / 2

    min_cam_x := half_viewport_width
    min_cam_y := half_viewport_height
    max_cam_x := world_bounds - half_viewport_width
    max_cam_y := world_bounds - half_viewport_height

    ctx.gs.cam_pos.x = math.clamp(ctx.gs.cam_pos.x, min_cam_x, max_cam_x)
    ctx.gs.cam_pos.y = math.clamp(ctx.gs.cam_pos.y, min_cam_y, max_cam_y)
}

world_to_tile :: proc(world_pos: Vec2) -> (int, int) {
    world_size_pixels := WORLD_SIZE * TILE_SIZE
    half_size := world_size_pixels / 2

    adjusted_x := world_pos.x + auto_cast half_size
    adjusted_y := world_pos.y + auto_cast half_size

    tile_x := int(adjusted_x / TILE_SIZE)
    tile_y := int(adjusted_y / TILE_SIZE)

    return tile_x, tile_y
}

tile_to_world :: proc(tile_x, tile_y: int) -> Vec2 {
    world_size_pixels := WORLD_SIZE * TILE_SIZE
    half_size := world_size_pixels / 2

    world_x := f32(tile_x * TILE_SIZE) - auto_cast half_size
    world_y := f32(tile_y * TILE_SIZE) - auto_cast half_size

    return Vec2{world_x, world_y}
}