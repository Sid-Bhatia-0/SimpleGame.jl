struct ShapeDrawable{S, C}
    shape::S
    color::C
end

struct Entity
    is_alive::Bool
    is_jumpable::Bool
    is_platform::Bool
    is_touching_ground::Bool
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

is_jumpable(entity) = entity.is_jumpable

is_platform(entity) = entity.is_platform

is_gravity_active(entity) = !entity.is_touching_ground || (entity.velocity.x < zero(entity.velocity.x))

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
    # make sure all time gets consumed
    counter = 1
    while dt > zero(dt)
        push!(DEBUG_INFO.messages, "dt: $(dt)")
        null_collision = (0, 0, 0, 2, typemax(Int))
        first_collision = null_collision

        for i in 1 : length(entities) - 1
            if is_alive(entities[i]) && is_collidable(entities[i])

                for j in i + 1 : length(entities)
                    if is_alive(entities[j]) && is_collidable(entities[j])

                        k1, k2, entity1, entity2 = sort_dynamic_static(i, j, entities[i], entities[j])

                        if !((entity1.body_type == STATIC) && (entity2.body_type == STATIC))

                            absolute_collision_box1 = get_absolute_collision_box(entity1.collision_box, entity1.position)
                            absolute_collision_box2 = get_absolute_collision_box(entity2.collision_box, entity2.position)

                            if is_jumpable(entity1) && is_gravity_active(entity1)
                                inv_gravity = 20
                                new_velocity1 = Vec(entity1.velocity.x + dt ÷ inv_gravity, entity1.velocity.y)
                            else
                                new_velocity1 = entity1.velocity
                            end

                            if is_jumpable(entity2) && is_gravity_active(entity2)
                                inv_gravity = 20
                                new_velocity2 = Vec(entity2.velocity.x + dt ÷ inv_gravity, entity2.velocity.y)
                            else
                                new_velocity2 = entity2.velocity
                            end

                            dx12 = (new_velocity1.x - new_velocity2.x) * dt
                            dy12 = (new_velocity1.y - new_velocity2.y) * dt

                            absolute_collision_box2_expanded = get_relative_aabb(absolute_collision_box1, absolute_collision_box2)

                            hit_dimension, hit_direction, relative_hit_time = simulate(absolute_collision_box1.position, absolute_collision_box2_expanded, dx12, dy12)

                            if !iszero(hit_dimension) && !iszero(hit_direction) && (zero(relative_hit_time) <= relative_hit_time <= one(relative_hit_time)) # collision occurred
                                push!(DEBUG_INFO.messages, "Collision occurred")

                                push!(DEBUG_INFO.messages, "k1: $(k1)")
                                push!(DEBUG_INFO.messages, "entity1: $(entity1)")
                                push!(DEBUG_INFO.messages, "absolute_collision_box1: $(absolute_collision_box1)")

                                push!(DEBUG_INFO.messages, "k2: $(k2)")
                                push!(DEBUG_INFO.messages, "entity2: $(entity2)")
                                push!(DEBUG_INFO.messages, "absolute_collision_box2: $(absolute_collision_box2)")

                                hit_time = (relative_hit_time.num * dt) ÷ relative_hit_time.den
                                @show k1, k2, hit_dimension, hit_direction, relative_hit_time, hit_time
                                push!(DEBUG_INFO.messages, "k1, k2, hit_dimension, hit_direction, relative_hit_time, hit_time: $(k1), $(k2), $(hit_dimension), $(hit_direction), $(relative_hit_time), $(hit_time)")

                                if hit_time < first_collision[5]
                                    first_collision = (k1, k2, hit_dimension, hit_direction, relative_hit_time, hit_time)
                                end
                            end
                        end
                    end
                end
            end
        end

        push!(DEBUG_INFO.messages, "counter, first_collision: $(counter), $(first_collision)")
        if first_collision == null_collision
            integrate!(entities, dt)
            dt = zero(dt)
        else
            # here we need to do something about the repeated collisions at hit_time of 0
            # make it a geometric calculation. Check whether a jumpable entity is_touching_ground
            k1, k2, hit_dimension, hit_direction, relative_hit_time, hit_time = first_collision
            integrate!(entities, hit_time)
            entities[k1], entities[k2] = handle_collision(entities[k1], entities[k2], first_collision)
            dt = dt - hit_time
        end

        @show counter, dt
        counter += 1

        if counter >=10
            error("counter: $(counter)")
        end
    end

    return nothing
end

function sort_dynamic_static(i1, i2, entity1, entity2)
    if (entity1.body_type == STATIC) && (entity2.body_type == DYNAMIC)
        return i2, i1, entity2, entity1
    else
        return i1, i2, entity1, entity2
    end
end

function handle_collision(entity1, entity2, collision_info)
    @assert !((entity1.body_type == DYNAMIC) && (entity2.body_type == DYNAMIC))

    _, _, hit_dimension, hit_direction, relative_hit_time, hit_time = collision_info

    absolute_collision_box1 = get_absolute_collision_box(entity1.collision_box, entity1.position)
    absolute_collision_box2 = get_absolute_collision_box(entity2.collision_box, entity2.position)

    if hit_dimension == 1
        new_velocity1 = Vec(entity2.velocity.x, entity1.velocity.y)

        if hit_direction == 1
            new_position1 = Vec(entity1.position.x + get_x_min(absolute_collision_box2) - get_x_max(absolute_collision_box1), entity1.position.y)
            new_is_touching_ground = true
        else
            new_position1 = Vec(entity1.position.x - (get_x_min(absolute_collision_box1) - get_x_max(absolute_collision_box2)), entity1.position.y)
            new_is_touching_ground = entity1.is_touching_ground
        end
    else
        new_velocity1 = Vec(entity1.velocity.x, entity2.velocity.y)
        new_is_touching_ground = entity1.is_touching_ground

        if hit_direction == 1
            new_position1 = Vec(entity1.position.x, entity1.position.y + get_y_min(absolute_collision_box2) - get_y_max(absolute_collision_box1))
        else
            new_position1 = Vec(entity1.position.x, entity1.position.y - (get_y_min(absolute_collision_box1) - get_y_max(absolute_collision_box2)))
        end
    end

    entity1 = typeof(entity1)(
        entity1.is_alive,
        entity1.is_jumpable,
        entity1.is_platform,
        new_is_touching_ground,
        new_position1,
        new_velocity1,
        entity1.collision_box,
        entity1.body_type,
        entity1.texture_index,
        entity1.animation_state,
    )

    return entity1, entity2
end

function integrate!(entities, dt)
    # update is_touching_ground somewhere
    for i in 1:length(entities)
        entity = entities[i]

        if is_jumpable(entity) && is_gravity_active(entity)
            velocity = entity.velocity

            inv_gravity = 20

            new_velocity = Vec(velocity.x + dt ÷ inv_gravity, velocity.y)
        else
            new_velocity = entity.velocity
        end

        if is_movable(entity)
            position = entity.position

            dx = new_velocity.x * dt
            dy = new_velocity.y * dt

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
            entity.is_jumpable,
            entity.is_platform,
            entity.is_touching_ground,
            new_position,
            new_velocity,
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
