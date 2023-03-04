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

function update!(entities, dt)
    while dt > zero(dt)
        push!(DEBUG_INFO.messages, "dt: $(dt)")
        null_collision = (0, 0, 0, 2, typemax(Int))
        first_collision = null_collision

        for i in 1 : length(entities) - 1
            entity_i = entities[i]

            if is_alive(entity_i) && is_collidable(entity_i)
                body_type_i = entity_i.body_type
                collision_box_i = entity_i.collision_box
                absolute_collision_box_i = AABB(
                    Vec(
                        collision_box_i.position.x + entity_i.position.x - one(entity_i.position.x),
                        collision_box_i.position.y + entity_i.position.y - one(entity_i.position.y),
                    ),
                    collision_box_i.x_width,
                    collision_box_i.y_width,
                )
                velocity_i = entity_i.velocity

                for j in i + 1 : length(entities)
                    entity_j = entities[j]

                    if is_alive(entity_j) && is_collidable(entity_j)
                        body_type_j = entity_j.body_type
                        collision_box_j = entity_j.collision_box
                        absolute_collision_box_j = AABB(
                            Vec(
                                collision_box_j.position.x + entity_j.position.x - one(entity_j.position.x),
                                collision_box_j.position.y + entity_j.position.y - one(entity_j.position.y),
                            ),
                            collision_box_j.x_width,
                            collision_box_j.y_width,
                        )
                        velocity_j = entity_j.velocity

                        if !((body_type_i == STATIC) && (body_type_j == STATIC))
                            dx_ij = (velocity_i.x - velocity_j.x) * dt
                            dy_ij = (velocity_i.y - velocity_j.y) * dt

                            absolute_collision_box_j_expanded = get_relative_aabb(absolute_collision_box_i, absolute_collision_box_j)

                            hit_dimension, relative_hit_time = simulate(absolute_collision_box_i.position, absolute_collision_box_j_expanded, dx_ij, dy_ij)

                            if !iszero(hit_dimension) && (zero(relative_hit_time) <= relative_hit_time <= one(relative_hit_time)) # collision occurred
                                push!(DEBUG_INFO.messages, "Collision occurred")

                                push!(DEBUG_INFO.messages, "body_type_i: $(body_type_i)")
                                push!(DEBUG_INFO.messages, "absolute_collision_box_i: $(absolute_collision_box_i)")
                                push!(DEBUG_INFO.messages, "velocity_i: $(velocity_i)")

                                push!(DEBUG_INFO.messages, "body_type_j: $(body_type_j)")
                                push!(DEBUG_INFO.messages, "absolute_collision_box_j: $(absolute_collision_box_j)")
                                push!(DEBUG_INFO.messages, "velocity_j: $(velocity_j)")

                                hit_time = (relative_hit_time.num * dt) ÷ relative_hit_time.den
                                push!(DEBUG_INFO.messages, "i, j, hit_dimension, relative_hit_time, hit_time: $(i), $(j), $(hit_dimension), $(relative_hit_time), $(hit_time)")

                                if hit_time < first_collision[5]
                                    first_collision = (i, j, hit_dimension, relative_hit_time, hit_time)
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
            i, j, hit_dimension, relative_hit_time, hit_time = first_collision

            integrate!(entities, hit_time)

            entity_i = entities[i]
            entity_j = entities[j]

            body_type_i = entity_i.body_type
            velocity_i = entity_i.velocity

            body_type_j = entity_j.body_type
            velocity_j = entity_j.velocity

            if (entity_i.body_type == STATIC) && (entity_j.body_type == DYNAMIC)
                new_velocity_i = velocity_i

                if hit_dimension == 1
                    new_velocity_j = Vec(velocity_i.x, velocity_j.y)
                else
                    new_velocity_j = Vec(velocity_j.x, velocity_i.y)
                end
            elseif (body_type_i == DYNAMIC) && (body_type_j == STATIC)
                new_velocity_j = velocity_j

                if hit_dimension == 1
                    new_velocity_i = Vec(velocity_j.x, velocity_i.y)
                else
                    new_velocity_i = Vec(velocity_i.x, velocity_j.y)
                end
            elseif (body_type_i == DYNAMIC) && (body_type_j == DYNAMIC)
                error("Not implemented")
            end

            entities[i] = (Accessors.@set entity_i.velocity = new_velocity_i)
            entities[j] = (Accessors.@set entity_j.velocity = new_velocity_j)

            dt = dt - hit_time
        end
    end

    return nothing
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
