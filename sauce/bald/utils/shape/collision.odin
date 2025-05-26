package shape

import "core:log"
import "core:math"
import "core:math/linalg"

collide :: proc(a, b: Shape) -> (colliding: bool, depth: Vector2) {
	if a == {} || b == {} {
		return false, 0.0
	}

	switch a_shape in a {

		case Rect:
			switch b_shape in b {
				case Rect: return rect_collide_rect(a_shape, b_shape)

				case Circle: return rect_collide_circle(a_shape, b_shape)
			}

		case Circle:
		#partial switch b_shape in b {
			case Rect: return rect_collide_circle(b_shape, a_shape)
		}
			
	}

	log.error("unsupported shape collision", a, "against", b)
	return false, {}
}

rect_contains :: proc(rect: Vector4, p: Vector2) -> bool {
	return (p.x >= rect.x) && (p.x <= rect.z) && (p.y >= rect.y) && (p.y <= rect.w);
}

rect_collide_circle :: proc(aabb: Rect, circle: Circle) -> (bool, Vector2) {
	// Find the point on the AABB closest to the circle center
	closest_point := (Vector2){
		math.clamp(circle.pos.x, aabb.x, aabb.z),
		math.clamp(circle.pos.y, aabb.y, aabb.w)
	}

	// Calculate the distance between the closest point and the circle center
	distance := linalg.length(closest_point - circle.pos);

	// Check if the distance is less than or equal to the radius of the circle
	return distance <= circle.radius, {};
}

rect_collide_rect :: proc(a: Rect, b: Rect) -> (bool, Vector2) {
	// Calculate overlap on each axis
	dx := (a.z + a.x) / 2 - (b.z + b.x) / 2;
	dy := (a.w + a.y) / 2 - (b.w + b.y) / 2;

	overlap_x := (a.z - a.x) / 2 + (b.z - b.x) / 2 - abs(dx);
	overlap_y := (a.w - a.y) / 2 + (b.w - b.y) / 2 - abs(dy);

	// If there is no overlap on any axis, there is no collision
	if overlap_x <= 0 || overlap_y <= 0 {
		return false, Vector2{};
	}

	// Find the penetration vector
	penetration := Vector2{};
	if overlap_x < overlap_y {
		penetration.x = overlap_x if dx > 0 else -overlap_x;
	} else {
		penetration.y = overlap_y if dy > 0 else -overlap_y;
	}

	return true, penetration;
}