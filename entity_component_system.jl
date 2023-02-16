struct CollisionBox
    shape::SD.Rectangle{Int}
end

struct Position
    x::Float64
    y::Float64
end

struct Velocity
    x::Float64
    y::Float64
end

struct ShapeDrawable{S, C}
    shape::S
    color::C
end

struct Entity
    is_alive::Bool
    position::Position
    velocity::Velocity
    collision_box::CollisionBox
    texture_index::TextureIndex
    animation_state::AnimationState
end

is_alive(entity) = entity.is_alive

is_drawable(entity) = entity.texture_index.start > zero(entity.texture_index.start)

is_animatable(entity) = entity.animation_state.num_frames > one(entity.animation_state.num_frames)

null(::Type{CollisionBox}) = CollisionBox(SD.Rectangle(SD.Point(0, 0), 0, 0))

isnull(collision_box::CollisionBox) = collision_box == null(typeof(collision_box))

is_collidable(entity) = !isnull(entity.collision_box)

null(::Type{Velocity}) = Velocity(0.0, 0.0)

isnull(velocity::Velocity) = velocity == null(typeof(velocity))

is_movable(entity) = !isnull(entity.velocity)

get_point(position::Position) = SD.Point(round(Int, position.x, RoundDown), round(Int, position.y, RoundDown))

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

move(position, velocity, dt) = position + dt * velocity

function move(position::Position, velocity::Velocity, dt)
    i = move(position.x, velocity.x, dt)
    j = move(position.y, velocity.y, dt)
    return Position(i, j)
end

function update!(entities, dt)
    for (i, entity) in enumerate(entities)
        if is_alive(entity)
            if is_movable(entity)
                new_position = move(entity.position, entity.velocity, dt)
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
                entity.texture_index,
                new_animation_state,
            )
        end
    end
end

function drawing_system!(draw_list, entities, texture_atlas)
    for (i, entity) in enumerate(entities)
        if is_alive(entity)
            if is_drawable(entity)
                if is_animatable(entity)
                    push!(draw_list, SD.Image(get_point(entity.position), get_texture(texture_atlas, entity.texture_index, entity.animation_state)))
                else
                    push!(draw_list, SD.Image(get_point(entity.position), get_texture(texture_atlas, entity.texture_index)))
                end

            end

            if DEBUG_INFO.show_collision_boxes
                if is_collidable(entity)
                    point = get_point(entity.position)
                    push!(draw_list, ShapeDrawable(SD.move(entity.collision_box.shape, point.i - 1, point.j -1), COLORS[Integer(SI.COLOR_INDEX_TEXT)]))
                end
            end
        end
    end
end
