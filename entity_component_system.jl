struct ShapeDrawable{S, C}
    shape::S
    color::C
end

struct Entity
    is_alive::Bool
    is_jumpable::Bool
    is_platform::Bool
    is_on_platform::Bool
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

const MAX_ENTITIES = 6

@enum EntityIndex begin
    INDEX_BACKGROUND = 1
    INDEX_PLAYER
    INDEX_GROUND
    INDEX_LEFT_BOUNDARY_WALL
    INDEX_RIGHT_BOUNDARY_WALL
    INDEX_TOP_BOUNDARY_WALL
end

is_alive(entity) = entity.is_alive

is_jumpable(entity) = entity.is_jumpable

is_platform(entity) = entity.is_platform

is_on_platform(entity) = entity.is_on_platform

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

const NULL_COLLISION = (0, 0, 0, 2, typemax(Int))

function is_on(entity1, entity2)
    absolute_collision_box1 = get_absolute_collision_box(entity1.collision_box, entity1.position)
    absolute_collision_box2 = get_absolute_collision_box(entity2.collision_box, entity2.position)
    absolute_collision_box2_expanded = get_relative_aabb(absolute_collision_box1, absolute_collision_box2)

    x = absolute_collision_box1.position.x
    y = absolute_collision_box1.position.y
    x_min, x_max = get_x_extrema(absolute_collision_box2_expanded)
    y_min, y_max = get_y_extrema(absolute_collision_box2_expanded)

    return (x == x_min) && (y > y_min) && (y < y_max)
end

function update!(entities, dt)
    # make sure all time gets consumed
    while dt > zero(dt)
        push!(DEBUG_INFO.messages, "dt: $(dt)")

        # update is_on_platform for all relevant entities
        for i in 1 : length(entities)
            if is_alive(entities[i]) && is_jumpable(entities[i])
                new_is_on_platform = false

                for j in 1 : length(entities)
                    if is_alive(entities[j]) && is_platform(entities[j]) && is_on(entities[i], entities[j])
                        ei = entities[i]
                        new_is_on_platform = true
                    end
                end

                entity_i = entities[i]
                entities[i] = (Accessors.@set entity_i.is_on_platform = new_is_on_platform)
            end
        end

        null_collision = (0, 0, 0, 2, typemax(Int))
        first_collision = null_collision

        # get first collision
        for i in 1 : length(entities)
            if is_alive(entities[i]) && is_collidable(entities[i])
                for j in 1 : length(entities)
                    if is_alive(entities[j]) && is_collidable(entities[j]) && entities[i].body_type != entities[j].body_type
                        i1, i2, entity1, entity2 = sort_dynamic_static(i, j, entities[i], entities[j])

                        absolute_collision_box1 = get_absolute_collision_box(entity1.collision_box, entity1.position)
                        absolute_collision_box2 = get_absolute_collision_box(entity2.collision_box, entity2.position)
                        absolute_collision_box2_expanded = get_relative_aabb(absolute_collision_box1, absolute_collision_box2)

                        dx = entity1.velocity.x * dt
                        dy = entity1.velocity.y * dt

                        if is_jumpable(entity1) && !is_on_platform(entity1)
                            inv_gravity = 20
                            dx = dx + (dt * dt) ÷ inv_gravity
                        end

                        hit_dimension, hit_direction, relative_hit_time = simulate(absolute_collision_box1.position, absolute_collision_box2_expanded, dx, dy)

                        if !iszero(hit_dimension) && !iszero(hit_direction) && (zero(relative_hit_time) <= relative_hit_time <= one(relative_hit_time)) # collision occurred
                            hit_time = (relative_hit_time.num * dt) ÷ relative_hit_time.den

                            if hit_time < first_collision[5]
                                first_collision = (i1, i2, hit_dimension, hit_direction, relative_hit_time, hit_time)
                            end

                            if IS_DEBUG
                                push!(DEBUG_INFO.messages, "Collision occurred")

                                push!(DEBUG_INFO.messages, "i1: $(i1)")
                                push!(DEBUG_INFO.messages, "entity1: $(entity1)")
                                push!(DEBUG_INFO.messages, "absolute_collision_box1: $(absolute_collision_box1)")

                                push!(DEBUG_INFO.messages, "i2: $(i2)")
                                push!(DEBUG_INFO.messages, "entity2: $(entity2)")
                                push!(DEBUG_INFO.messages, "absolute_collision_box2: $(absolute_collision_box2)")

                                push!(DEBUG_INFO.messages, "i1, i2, hit_dimension, hit_direction, relative_hit_time, hit_time: $(i1), $(i2), $(hit_dimension), $(hit_direction), $(relative_hit_time), $(hit_time)")
                            end
                        end
                    end
                end
            end
        end

        if IS_DEBUG
            push!(DEBUG_INFO.messages, "counter, first_collision: $(counter), $(first_collision)")
        end

        if first_collision == null_collision
            integrate!(entities, dt)
            dt = zero(dt)
        else
            i1, i2, hit_dimension, hit_direction, relative_hit_time, hit_time = first_collision
            integrate!(entities, hit_time)
            entities[i1], entities[i2] = handle_collision(entities[i1], entities[i2], first_collision)
            dt = dt - hit_time
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
    @assert (entity1.body_type == DYNAMIC) && (entity2.body_type == STATIC)

    _, _, hit_dimension, hit_direction, relative_hit_time, hit_time = collision_info

    absolute_collision_box1 = get_absolute_collision_box(entity1.collision_box, entity1.position)
    absolute_collision_box2 = get_absolute_collision_box(entity2.collision_box, entity2.position)

    if hit_dimension == 1
        new_velocity1 = Vec(entity2.velocity.x, entity1.velocity.y)

        if hit_direction == 1
            new_position1 = Vec(entity1.position.x + get_x_min(absolute_collision_box2) - get_x_max(absolute_collision_box1), entity1.position.y)
            new_is_on_platform = true
        else
            new_position1 = Vec(entity1.position.x - (get_x_min(absolute_collision_box1) - get_x_max(absolute_collision_box2)), entity1.position.y)
            new_is_on_platform = entity1.is_on_platform
        end
    else
        new_velocity1 = Vec(entity1.velocity.x, entity2.velocity.y)
        new_is_on_platform = entity1.is_on_platform

        if hit_direction == 1
            new_position1 = Vec(entity1.position.x, entity1.position.y + get_y_min(absolute_collision_box2) - get_y_max(absolute_collision_box1))
        else
            new_position1 = Vec(entity1.position.x, entity1.position.y - (get_y_min(absolute_collision_box1) - get_y_max(absolute_collision_box2)))
        end
    end

    new_entity1 = typeof(entity1)(
        entity1.is_alive,
        entity1.is_jumpable,
        entity1.is_platform,
        new_is_on_platform,
        new_position1,
        new_velocity1,
        entity1.collision_box,
        entity1.body_type,
        entity1.texture_index,
        entity1.animation_state,
    )

    return new_entity1, entity2
end

function integrate!(entities, dt)
    for i in 1:length(entities)
        entity = entities[i]

        if is_alive(entity)
            if is_movable(entity)
                if is_jumpable(entity) && !is_on_platform(entity)
                    inv_gravity = 20
                    new_velocity = Vec(entity.velocity.x + dt ÷ inv_gravity, entity.velocity.y)
                else
                    new_velocity = entity.velocity
                end

                dx = new_velocity.x * dt
                dy = new_velocity.y * dt

                new_position = Vec(entity.position.x + dx, entity.position.y + dy)
            else
                new_velocity = entity.velocity
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
                entity.is_on_platform,
                new_position,
                new_velocity,
                entity.collision_box,
                entity.body_type,
                entity.texture_index,
                new_animation_state,
            )
        end
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
