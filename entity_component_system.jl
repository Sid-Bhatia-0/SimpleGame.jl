struct ShapeDrawable{S, C}
    shape::S
    color::C
end

struct Entity
    is_alive::Bool
    position::Vec
    inv_velocity::Vec
    collision_box::AABB
    body_type::BodyType
    texture_index::TextureIndex
    animation_state::AnimationState
end

const NULL_POSITION = Vec(typemin(Int), typemin(Int))
const NULL_INV_VELOCITY = Vec(typemin(Int), typemin(Int))
const NULL_COLLISION_BOX = AABB(Vec(typemin(Int), typemin(Int)), typemin(Int), typemin(Int))

is_alive(entity) = entity.is_alive

is_drawable(entity) = entity.texture_index.start > zero(entity.texture_index.start)

is_animatable(entity) = entity.animation_state.num_frames > one(entity.animation_state.num_frames)

is_collidable(entity) = entity.collision_box != NULL_COLLISION_BOX

is_movable(entity) = entity.inv_velocity != NULL_INV_VELOCITY

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

move(position, inv_velocity, dt) = position + dt ÷ inv_velocity

function move(position::Vec, inv_velocity::Vec, dt)
    i = move(position.x, inv_velocity.x, dt)
    j = move(position.y, inv_velocity.y, dt)
    return Vec(i, j)
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
                inv_velocity_i = entity_i.inv_velocity

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
                        inv_velocity_j = entity_j.inv_velocity

                        if !((body_type_i == STATIC) && (body_type_j == STATIC))
                            dx_ij = dt ÷ inv_velocity_i.x - dt ÷ inv_velocity_j.x
                            dy_ij = dt ÷ inv_velocity_i.y - dt ÷ inv_velocity_j.y

                            absolute_collision_box_j_expanded = get_relative_aabb(absolute_collision_box_i, absolute_collision_box_j)

                            hit_dimension, relative_hit_time = simulate(absolute_collision_box_i.position, absolute_collision_box_j_expanded, dx_ij, dy_ij)

                            if !iszero(hit_dimension) && (zero(relative_hit_time) <= relative_hit_time <= one(relative_hit_time)) # collision occurred
                                push!(DEBUG_INFO.messages, "Collision occurred")

                                push!(DEBUG_INFO.messages, "body_type_i: $(body_type_i)")
                                push!(DEBUG_INFO.messages, "absolute_collision_box_i: $(absolute_collision_box_i)")
                                push!(DEBUG_INFO.messages, "inv_velocity_i: $(inv_velocity_i)")

                                push!(DEBUG_INFO.messages, "body_type_j: $(body_type_j)")
                                push!(DEBUG_INFO.messages, "absolute_collision_box_j: $(absolute_collision_box_j)")
                                push!(DEBUG_INFO.messages, "inv_velocity_j: $(inv_velocity_j)")

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
            inv_velocity_i = entity_i.inv_velocity

            body_type_j = entity_j.body_type
            inv_velocity_j = entity_j.inv_velocity

            if (entity_i.body_type == STATIC) && (entity_j.body_type == DYNAMIC)
                new_inv_velocity_i = inv_velocity_i

                if hit_dimension == 1
                    new_inv_velocity_j = Vec(inv_velocity_i.x, inv_velocity_j.y)
                else
                    new_inv_velocity_j = Vec(inv_velocity_j.x, inv_velocity_i.y)
                end
            elseif (body_type_i == DYNAMIC) && (body_type_j == STATIC)
                new_inv_velocity_j = inv_velocity_j

                if hit_dimension == 1
                    new_inv_velocity_i = Vec(inv_velocity_j.x, inv_velocity_i.y)
                else
                    new_inv_velocity_i = Vec(inv_velocity_i.x, inv_velocity_j.y)
                end
            elseif (body_type_i == DYNAMIC) && (body_type_j == DYNAMIC)
                error("Not implemented")
            end

            entities[i] = (Accessors.@set entity_i.inv_velocity = new_inv_velocity_i)
            entities[j] = (Accessors.@set entity_j.inv_velocity = new_inv_velocity_j)

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
            inv_velocity = entity.inv_velocity

            dx = dt ÷ inv_velocity.x
            dy = dt ÷ inv_velocity.y

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
            entity.inv_velocity,
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
                    push!(draw_list, SD.Image(SD.Point(entity.position), get_texture(texture_atlas, entity.texture_index, entity.animation_state)))
                else
                    push!(draw_list, SD.Image(SD.Point(entity.position), get_texture(texture_atlas, entity.texture_index)))
                end

            end

            if DEBUG_INFO.show_collision_boxes
                if is_collidable(entity)
                    point = SD.Point(entity.position)
                    rectangle = SD.Rectangle(entity.collision_box)
                    push!(draw_list, ShapeDrawable(SD.move(rectangle, point.i - 1, point.j -1), COLORS[Integer(SI.COLOR_INDEX_TEXT)]))
                end
            end
        end
    end
end
