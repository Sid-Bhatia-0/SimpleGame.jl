struct ShapeDrawable{S, C}
    shape::S
    color::C
end

struct Entity
    is_alive::Bool
    position::Vec
    inv_velocity::Vec
    collision_box::AABB
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
    for (i, entity) in enumerate(entities)
        if is_alive(entity)
            if is_movable(entity)
                new_position = move(entity.position, entity.inv_velocity, dt)
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
