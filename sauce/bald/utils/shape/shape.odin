package shape

import "core:log"
import "core:math"
import "core:math/linalg"

import utils "../"

rect_get_center :: proc(a: Vector4) -> Vector2 {
	min := a.xy;
	max := a.zw;
	return { min.x + 0.5 * (max.x-min.x), min.y + 0.5 * (max.y-min.y) };
}

rect_make_with_pos :: proc(pos: Vector2, size: Vector2, pivot:= utils.Pivot.bottom_left) -> Vector4 {
	rect := (Vector4){0,0,size.x,size.y};
	rect = rect_shift(rect, pos - utils.scale_from_pivot(pivot) * size);
	return rect;
}
rect_make_with_size :: proc(size: Vector2, pivot: utils.Pivot) -> Vector4 {
	return rect_make({}, size, pivot);
}

rect_make :: proc{
	rect_make_with_pos,
	rect_make_with_size,
}

rect_shift :: proc(rect: Vector4, amount: Vector2) -> Vector4 {
	return {rect.x + amount.x, rect.y + amount.y, rect.z + amount.x, rect.w + amount.y};
}

rect_size :: proc(rect: Rect) -> Vector2 {
	return { abs(rect.x - rect.z), abs(rect.y - rect.w) }
}

rect_scale :: proc(_rect: Rect, scale: f32) -> Rect {
	rect := _rect
	origin := rect.xy
	rect = rect_shift(rect, -origin)
	scale_amount := (rect.zw * scale)-rect.zw
	rect.xy -= scale_amount / 2
	rect.zw += scale_amount / 2
	rect = rect_shift(rect, origin)
	return rect
}

rect_scale_v2 :: proc(_rect: Rect, scale: Vector2) -> Rect {
	rect := _rect
	origin := rect.xy
	rect = rect_shift(rect, -origin)

	// Calculate scale amount for each axis separately
	scale_amount := (rect.zw * scale) - rect.zw

	// Adjust rectangle while maintaining center position
	rect.xy -= scale_amount / 2
	rect.zw += scale_amount / 2

	rect = rect_shift(rect, origin)
	return rect
}

rect_expand :: proc(rect: Rect, amount: f32) -> Rect {{
	rect := rect
	rect.xy -= amount
	rect.zw += amount
	return rect
}}

circle_shift :: proc(circle: Circle, amount: Vector2) -> Circle {
  circle := circle
  circle.pos += amount
  return circle
}

shift :: proc(s: Shape, amount: Vector2) -> Shape {
	if s == {} || amount == {} {
		return s
	}

  switch shape in s {
    case Rect: return rect_shift(shape, amount)
    case Circle: return circle_shift(shape, amount)
    case: {
      log.error("unsupported shape shift", s)
      return {}
    }
  }
}
