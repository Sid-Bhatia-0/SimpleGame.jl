struct ShapeDrawable{S, C}
    shape::S
    color::C
end

struct Entity
    is_alive::Bool
    position::Vec
    velocity::Vec
    collision_box::AABB
    body_type::BodyType
    texture_index::TextureIndex
    animation_state::AnimationState
end

const NULL_POSITION = Vec(typemin(Int), typemin(Int))
const NULL_VELOCITY = Vec(0, 0)
const NULL_COLLISION_BOX = AABB(Vec(typemin(Int), typemin(Int)), typemin(Int), typemin(Int))

is_alive(entity) = entity.is_alive

is_drawable(entity) = entity.texture_index.start > zero(entity.texture_index.start)

is_animatable(entity) = entity.animation_state.num_frames > one(entity.animation_state.num_frames)

is_collidable(entity) = entity.collision_box != NULL_COLLISION_BOX

is_movable(entity) = entity.velocity != NULL_VELOCITY

SD.Point(vec::Vec) = SD.Point(vec.x, vec.y)

SD.Rectangle(aabb::AABB) = SD.Rectangle(SD.Point(aabb.position), aabb.x_width, aabb.y_width)

function add_entity!(entities, entity)
    for (i, entity_i) in enumerate(entities)
        if !is_alive(entity_i)
            entities[i] = entity
            return i
        end
    end

    push!(entities, entity)
    return length(entities)
end

move(position, velocity, dt) = position + velocity * dt

function move(position::Vec, velocity::Vec, dt)
    x = move(position.x, velocity.x, dt)
    y = move(position.y, velocity.y, dt)
    return Vec(x, y)
end

get_absolute_collision_box(collision_box, position) = AABB(Vec(collision_box.position.x + position.x - one(position.x), collision_box.position.y + position.y - one(position.y)), collision_box.x_width, collision_box.y_width)

function update!(entities, dt)
    while dt > zero(dt)
        push!(DEBUG_INFO.messages, "dt: $(dt)")
        null_collision = (0, 0, 0, 2, typemax(Int))
        first_collision = null_collision

        for i in 1 : length(entities) - 1
            if is_alive(entities[i]) && is_collidable(entities[i])
                absolute_collision_box_i = get_absolute_collision_box(entities[i].collision_box, entities[i].position)

                for j in i + 1 : length(entities)
                    if is_alive(entities[j]) && is_collidable(entities[j])
                        absolute_collision_box_j = get_absolute_collision_box(entities[j].collision_box, entities[j].position)

                        if !((entities[i].body_type == STATIC) && (entities[j].body_type == STATIC))
                            dx_ij = (entities[i].velocity.x - entities[j].velocity.x) * dt
                            dy_ij = (entities[i].velocity.y - entities[j].velocity.y) * dt

                            absolute_collision_box_j_expanded = get_relative_aabb(absolute_collision_box_i, absolute_collision_box_j)

                            hit_dimension, hit_direction, relative_hit_time = simulate(absolute_collision_box_i.position, absolute_collision_box_j_expanded, dx_ij, dy_ij)

                            if !iszero(hit_dimension) && !iszero(hit_direction) && (zero(relative_hit_time) <= relative_hit_time <= one(relative_hit_time)) # collision occurred
                                push!(DEBUG_INFO.messages, "Collision occurred")

                                push!(DEBUG_INFO.messages, "entities[i].body_type: $(entities[i].body_type)")
                                push!(DEBUG_INFO.messages, "absolute_collision_box_i: $(absolute_collision_box_i)")

                                push!(DEBUG_INFO.messages, "entities[j].body_type: $(entities[j].body_type)")
                                push!(DEBUG_INFO.messages, "absolute_collision_box_j: $(absolute_collision_box_j)")

                                hit_time = (relative_hit_time.num * dt) ÷ relative_hit_time.den
                                push!(DEBUG_INFO.messages, "i, j, hit_dimension, hit_direction, relative_hit_time, hit_time: $(i), $(j), $(hit_dimension), $(hit_direction), $(relative_hit_time), $(hit_time)")

                                if hit_time < first_collision[5]
                                    first_collision = (i, j, hit_dimension, hit_direction, relative_hit_time, hit_time)
                                end
                            end
                        end
                    end
                end
            end
        end

        push!(DEBUG_INFO.messages, "first_collision: $(first_collision)")
        if first_collision == null_collision
            integrate!(entities, dt)
            dt = zero(dt)
        else
            i, j, hit_dimension, hit_direction, relative_hit_time, hit_time = first_collision

            integrate!(entities, hit_time)

            if (entities[i].body_type == STATIC) && (entities[j].body_type == DYNAMIC)
                entities[i], entities[j] = handle_collision(entities[i], entities[j], first_collision)
            elseif (entities[j].body_type == STATIC) && (entities[i].body_type == DYNAMIC)
                entities[j], entities[i] = handle_collision(entities[j], entities[i], first_collision)
            elseif (body_type_i == DYNAMIC) && (body_type_j == DYNAMIC)
                error("Not implemented")
            end

            dt = dt - hit_time
        end
    end

    return nothing
end

function handle_collision(static_entity, dynamic_entity, collision_info)
    _, _, hit_dimension, hit_direction, relative_hit_time, hit_time = collision_info

    absolute_collision_box_static_entity = get_absolute_collision_box(static_entity.collision_box, static_entity.position)
    absolute_collision_box_dynamic_entity = get_absolute_collision_box(dynamic_entity.collision_box, dynamic_entity.position)

    if hit_dimension == 1
        new_velocity_dynamic_entity = Vec(static_entity.velocity.x, dynamic_entity.velocity.y)

        if hit_direction == 1
            new_position_dynamic_entity = Vec(dynamic_entity.position.x + get_x_min(absolute_collision_box_static_entity) - get_x_max(absolute_collision_box_dynamic_entity), dynamic_entity.position.y)
        else
            new_position_dynamic_entity = Vec(dynamic_entity.position.x - (get_x_min(absolute_collision_box_dynamic_entity) - get_x_max(absolute_collision_box_static_entity)), dynamic_entity.position.y)
        end
    else
        new_velocity_dynamic_entity = Vec(dynamic_entity.velocity.x, static_entity.velocity.y)

        if hit_direction == 1
            new_position_dynamic_entity = Vec(dynamic_entity.position.x, dynamic_entity.position.y + get_y_min(absolute_collision_box_static_entity) - get_y_max(absolute_collision_box_dynamic_entity))
        else
            new_position_dynamic_entity = Vec(dynamic_entity.position.x, dynamic_entity.position.y - (get_y_min(absolute_collision_box_dynamic_entity) - get_y_max(absolute_collision_box_static_entity)))
        end
    end

    dynamic_entity = typeof(dynamic_entity)(
        dynamic_entity.is_alive,
        new_position_dynamic_entity,
        new_velocity_dynamic_entity,
        dynamic_entity.collision_box,
        dynamic_entity.body_type,
        dynamic_entity.texture_index,
        dynamic_entity.animation_state,
    )

    return static_entity, dynamic_entity
end

function integrate!(entities, dt)
    for i in 1:length(entities)
        entity = entities[i]

        if is_movable(entity)
            position = entity.position
            velocity = entity.velocity

            dx = velocity.x * dt
            dy = velocity.y * dt

            new_position = Vec(position.x + dx, position.y + dy)
        else
            new_position = entity.position
        end

        if is_animatable(entity)
            new_animation_state = animate(entity.animation_state, dt)
        else
            new_animation_state = entity.animation_state
        end

        entities[i] = typeof(entity)(
            entity.is_alive,
            new_position,
            entity.velocity,
            entity.collision_box,
            entity.body_type,
            entity.texture_index,
            new_animation_state,
        )
    end

    return nothing
end

function drawing_system!(draw_list, entities, texture_atlas)
    for (i, entity) in enumerate(entities)
        if is_alive(entity)
            if is_drawable(entity)
                if is_animatable(entity)
                    push!(draw_list, SD.Image(SD.Point(get_block(entity.position, PIXEL_LENGTH)), get_texture(texture_atlas, entity.texture_index, entity.animation_state)))
                else
                    push!(draw_list, SD.Image(SD.Point(get_block(entity.position, PIXEL_LENGTH)), get_texture(texture_atlas, entity.texture_index)))
                end

            end

            if DEBUG_INFO.show_collision_boxes
                if is_collidable(entity)
                    point = SD.Point(get_block(entity.position, PIXEL_LENGTH))
                    rectangle = SD.Rectangle(SD.Point(get_block(entity.collision_box.position, PIXEL_LENGTH)), get_block(entity.collision_box.x_width, PIXEL_LENGTH), get_block(entity.collision_box.y_width, PIXEL_LENGTH))
                    push!(draw_list, ShapeDrawable(SD.move(rectangle, point.i - 1, point.j -1), COLORS[Integer(SI.COLOR_INDEX_TEXT)]))
                end
            end
        end
    end
end
