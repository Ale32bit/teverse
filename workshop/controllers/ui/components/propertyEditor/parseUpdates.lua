-- these functions are responsible for updating the property editor gui
-- when the selection’s members are updated by 3rd party source 

local themer = require("tevgit:workshop/controllers/ui/core/themer.lua")

return {
  block = function (instance, gui, value)

  end,
  boolean = function (instance, gui, value)
    gui.input.texture = value and "fa:s-toggle-on" or "fa:s-toggle-off"
    themer.registerGui(gui.input, value and "successImage" or "errorImage")
  end,
  number = function (instance, gui, value)
    gui.input.text = tostring(value)
  end,
  string = function (instance, gui, value)
    gui.input.text = value
  end,
  vector3 = function(instance, gui, value)
    gui.x.text = string.format("%.3f", value.x)
    gui.y.text = string.format("%.3f", value.y)
    gui.z.text = string.format("%.3f", value.z)
  end,
  vector2 = function(instance, gui, value)
    gui.x.text = string.format("%.3f", value.x)
    gui.y.text = string.format("%.3f", value.y)
  end,
  colour = function(instance, gui, value)
    gui.r.text = string.format("%.5f", value.r)
    gui.g.text = string.format("%.5f", value.g)
    gui.b.text = string.format("%.5f", value.b)
    gui.col.backgroundColour = value
  end,
  quaternion = function(instance, gui, value)
    local euler = value:getEuler()
    gui.x.text = string.format("%.3f", math.deg(euler.x))
    gui.y.text = string.format("%.3f", math.deg(euler.y))
    gui.z.text = string.format("%.3f", math.deg(euler.z))
    --gui.w.text = tostring(value.w)
  end,
  guiCoord = function(instance, gui, value)
    gui.scaleX.text = tostring(value.scaleX)
    gui.offsetX.text = tostring(value.offsetX)
    gui.scaleY.text = tostring(value.scaleY)
    gui.offsetY.text = tostring(value.offsetY)
  end,
}