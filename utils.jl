import GLFW
import SimpleIMGUI as SI

get_time(reference_time) = return time() - reference_time

function update_button(button, action)
    if action == GLFW.PRESS
        return SI.press(button)
    elseif action == GLFW.RELEASE
        return SI.release(button)
    else
        return button
    end
end
