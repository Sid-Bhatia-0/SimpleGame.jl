import SimpleDraw as SD

include("collision_detection.jl")

function SD.Rectangle(aabb::AABB)
    return SD.Rectangle(SD.Point(aabb.position.x, aabb.position.y), aabb.x_width, aabb.y_width)
end

function start()
    image = falses(64, 64)
    num_aabbs = 6
    num_steps = 1
    aabbs = Vector{AABB}(undef, num_aabbs)
    body_types = Vector{BodyType}(undef, num_aabbs)
    velocities = Vector{Point}(undef, num_aabbs)
    collisions = Vector{Tuple{Int, Int, Int, Rational{Int}}}()

    aabbs[1] = AABB(Point(1, 1), 64, 8)
    body_types[1] = STATIC
    velocities[1] = Point(0, 0)

    aabbs[2] = AABB(Point(1, 64 - 8 + 1), 64, 8)
    body_types[2] = STATIC
    velocities[2] = Point(0, 0)

    aabbs[3] = AABB(Point(1, 8 + 1), 8, 64 - 2 * 8)
    body_types[3] = STATIC
    velocities[3] = Point(0, 0)

    aabbs[4] = AABB(Point(64 - 8 + 1, 8 + 1), 8, 64 - 2 * 8)
    body_types[4] = STATIC
    velocities[4] = Point(0, 0)

    aabbs[5] = AABB(Point(29, 29), 8, 8)
    body_types[5] = STATIC
    velocities[5] = Point(0, 0)

    aabbs[6] = AABB(Point(13, 13), 8, 8)
    body_types[6] = DYNAMIC
    velocities[6] = Point(2, 1)

    @show aabbs
    println()
    @show body_types
    println()
    @show velocities
    println()

    dt = 20

    fill!(image, false)
    for aabb in aabbs
        SD.draw!(image, SD.Rectangle(aabb), true)
    end
    SD.visualize(image)

    while dt > zero(dt)
        @show dt
        null_collision = (0, 0, 0, 2, typemax(Int))
        first_collision = null_collision

        for i in 1 : length(aabbs) - 1
            body_type_i = body_types[i]
            aabb_i = aabbs[i]
            velocity_i = velocities[i]

            for j in i + 1 : length(aabbs)
                body_type_j = body_types[j]
                aabb_j = aabbs[j]
                velocity_j = velocities[j]

                if !((body_type_i == STATIC) && (body_type_j == STATIC))
                    velocity_ij = Point(velocity_i.x - velocity_j.x, velocity_i.y - velocity_j.y)
                    aabb_j_expanded = get_relative_aabb(aabb_i, aabb_j)

                    hit_dimension, relative_hit_time = simulate(aabb_i.position, aabb_j_expanded, velocity_ij.x * dt, velocity_ij.y * dt)

                    if !iszero(hit_dimension) && (zero(relative_hit_time) <= relative_hit_time <= one(relative_hit_time)) # collision occurred
                        @info "Collision occurred"

                        @show body_type_i
                        @show aabb_i
                        @show velocity_i

                        @show body_type_j
                        @show aabb_j
                        @show velocity_j

                        hit_time = (relative_hit_time.num * dt) ÷ relative_hit_time.den
                        @show (i, j, hit_dimension, relative_hit_time, hit_time)

                        if hit_time < first_collision[5]
                            first_collision = (i, j, hit_dimension, relative_hit_time, hit_time)
                        end
                    end
                end
            end
        end

        @show first_collision
        if first_collision == null_collision
            for k in 1:length(aabbs)
                aabbs[k] = AABB(Point(aabbs[k].position.x + velocities[k].x * dt, aabbs[k].position.y + velocities[k].y * dt), aabbs[k].x_width, aabbs[k].y_width) 
            end

            dt = zero(dt)
        else
            i, j, hit_dimension, relative_hit_time, hit_time = first_collision

            for k in 1:length(aabbs)
                aabbs[k] = AABB(Point(aabbs[k].position.x + velocities[k].x * hit_time, aabbs[k].position.y + velocities[k].y * hit_time), aabbs[k].x_width, aabbs[k].y_width) 
            end

            body_type_i = body_types[i]
            aabb_i = aabbs[i]
            velocity_i = velocities[i]

            body_type_j = body_types[j]
            aabb_j = aabbs[j]
            velocity_j = velocities[j]

            if (body_type_i == STATIC) && (body_type_j == DYNAMIC)
                if hit_dimension == 1
                    velocities[j] = Point(-velocities[j].x, velocities[j].y)
                else
                    velocities[j] = Point(velocities[j].x, -velocities[j].y)
                end
            elseif (body_type_i == DYNAMIC) && (body_type_j == STATIC)
                if hit_dimension == 1
                    velocities[i] = Point(-velocities[i].x, velocities[i].y)
                else
                    velocities[i] = Point(velocities[i].x, -velocities[i].y)
                end
            elseif (body_type_i == DYNAMIC) && (body_type_j == DYNAMIC)
                error("Not implemented")
            end

            dt = dt - hit_time
        end

        fill!(image, false)
        for aabb in aabbs
            SD.draw!(image, SD.Rectangle(aabb), true)
        end
        SD.visualize(image)
    end

    return nothing
end

start()
