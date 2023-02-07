struct CollisionBox{I}
    shape::SD.Rectangle{I}
end

struct ShapeDrawable{S, C}
    shape::S
    color::C
end

struct Entity{I}
    is_alive::Bool
    position::SD.Point{I}
    collision_box::CollisionBox{I}
    texture_index::TextureIndex{I}
    animation_state::AnimationState{I}
end

is_alive(entity) = entity.is_alive

is_drawable(entity) = entity.texture_index.start > zero(entity.texture_index.start)

is_animatable(entity) = entity.animation_state.num_frames > one(entity.animation_state.num_frames)

null(::Type{CollisionBox{I}}) where {I} = CollisionBox(SD.Rectangle(SD.Point(zero(I), zero(I)), zero(I), zero(I)))

isnull(collision_box::CollisionBox) = collision_box == null(typeof(collision_box))

is_collidable(entity) = !isnull(entity.collision_box)

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

function animation_system!(entities, simulation_time)
    for (i, entity) in enumerate(entities)
        if is_alive(entity) && is_animatable(entity)
            entities[i] = typeof(entity)(
                entity.is_alive,
                entity.position,
                entity.collision_box,
                entity.texture_index,
                animate(entity.animation_state, simulation_time),
            )
        end
    end
end

function drawing_system!(draw_list, entities, texture_atlas)
    for (i, entity) in enumerate(entities)
        if is_alive(entity)
            if is_drawable(entity)
                if is_animatable(entity)
                    push!(draw_list, SD.Image(entity.position, get_texture(texture_atlas, entity.texture_index, entity.animation_state)))
                else
                    push!(draw_list, SD.Image(entity.position, get_texture(texture_atlas, entity.texture_index)))
                end

            end

            if DEBUG_INFO.show_collision_boxes
                if is_collidable(entity)
                    push!(draw_list, ShapeDrawable(SD.move(entity.collision_box.shape, entity.position.i - 1, entity.position.j -1), COLORS[Integer(SI.COLOR_INDEX_TEXT)]))
                end
            end
        end
    end
end
