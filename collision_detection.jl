struct Vec
    x::Int
    y::Int
end

struct AABB
    position::Vec
    x_width::Int
    y_width::Int
end

@enum BodyType begin
    STATIC = 1
    DYNAMIC
end

# @enum InteractionType begin
    # NONE = 1
    # CONTACT
    # NORMAL_PENETRATION
    # ANGULAR_PENETRATION
    # SLIDING
# end

get_relative_aabb(aabb1::AABB, aabb2::AABB) = AABB(Vec(aabb2.position.x - aabb1.x_width, aabb2.position.y - aabb1.y_width), aabb2.x_width + aabb1.x_width, aabb2.y_width + aabb1.y_width) # shrink aabb1 to a point and expand aabb2 to get new aabb21

@enum AABBIntersectionType begin
    NO_INTERSECTION = 1
    POINT_INTERSECTION
    LINE_INTERSECTION
    REGION_INTERSECTION
end

get_x_min(point::Vec) = point.x
get_x_max(point::Vec) = point.x

get_y_min(point::Vec) = point.y
get_y_max(point::Vec) = point.y

get_x_min(aabb::AABB) = aabb.position.x
get_x_max(aabb::AABB) = aabb.position.x + aabb.x_width

get_y_min(aabb::AABB) = aabb.position.y
get_y_max(aabb::AABB) = aabb.position.y + aabb.y_width

get_x_extrema(shape) = (get_x_min(shape), get_x_max(shape))
get_y_extrema(shape) = (get_y_min(shape), get_y_max(shape))

is_valid(aabb::AABB) = (aabb.x_width >= zero(aabb.x_width)) || (aabb.y_width >= zero(aabb.y_width))

is_reducible(aabb::AABB) = iszero(aabb.x_width) || iszero(aabb.y_width)

function get_intersection_type(point::Vec, aabb::AABB)
    @assert is_valid(aabb)
    @assert !is_reducible(aabb)

    x = point.x
    y = point.y
    x_min, x_max = get_x_extrema(aabb)
    y_min, y_max = get_y_extrema(aabb)

    if (x < x_min) || (x > x_max)
        return NO_INTERSECTION
    elseif (x == x_min) || (x == x_max)
        if (y < y_min) || (y > y_max)
            return NO_INTERSECTION
        elseif (y == y_min) || (y == y_max)
            return POINT_INTERSECTION
        else
            return LINE_INTERSECTION
        end
    else
        if (y < y_min) || (y > y_max)
            return NO_INTERSECTION
        elseif (y == y_min) || (y == y_max)
            return LINE_INTERSECTION
        else
            return REGION_INTERSECTION
        end
    end
end

function get_intersection_type(aabb1::AABB, aabb2::AABB)
    aabb21 = get_relative_aabb(aabb2, aabb1)
    return get_intersection_type(aabb1.position, aabb21)
end

# each movable body will move one at a time. And after each body tries to move, it will check for collisions with everything else and resolve them.
function simulate(point::Vec, aabb::AABB, dx, dy)
    @assert is_valid(aabb)
    @assert !is_reducible(aabb)

    intersection_type = get_intersection_type(point, aabb)
    @assert intersection_type != REGION_INTERSECTION

    x_0 = point.x
    y_0 = point.y

    x_min, x_max = get_x_extrema(aabb)
    y_min, y_max = get_y_extrema(aabb)

    hit_dimension = 0
    relative_hit_time = 0 // 1

    if (iszero(dx) && (iszero(dy))) ||
        (iszero(dx) && ((x_0 <= x_min) || (x_0 >= x_max))) ||
        (iszero(dy) && ((y_0 <= y_min) || (y_0 >= y_max)))
        return hit_dimension, relative_hit_time
    end

    t_x_min = (x_min - x_0) // dx
    t_x_max = (x_max - x_0) // dx
    t_x_entry, t_x_exit = minmax(t_x_min, t_x_max)

    t_y_min = (y_min - y_0) // dy
    t_y_max = (y_max - y_0) // dy
    t_y_entry, t_y_exit = minmax(t_y_min, t_y_max)

    if (t_x_entry < t_y_exit) && (t_y_entry < t_x_exit)
        if t_x_entry <= t_y_entry
            hit_dimension = 2
            relative_hit_time = t_y_entry
        else
            hit_dimension = 1
            relative_hit_time = t_x_entry
        end
    end

    return hit_dimension, relative_hit_time
end
