import GLFW
import SimpleIMGUI as SI

function get_time(reference_time)
    # get time (in units of 2^16 nanoseconds) since reference_time
    # places an upper bound on how much time can the program be running until time wraps around giving meaningless values
    # the conversion to Int will actually throw an error when that happens

    t = time_ns()

    if t >= reference_time
        return Int(t - reference_time) ÷ (2^16)
    else
        return Int(t + (typemax(t) - reference_time)) ÷ (2^16)
    end
end

function update_button(button, action)
    if action == GLFW.PRESS
        return SI.press(button)
    elseif action == GLFW.RELEASE
        return SI.release(button)
    else
        return button
    end
end
