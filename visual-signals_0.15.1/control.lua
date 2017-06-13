--control.lua
-- Condition on gui-signal-display for when to show the data if it is hidden
-- Configure update interval?
-- Search for signal

require "signal_gui"

-- Table with integer keys and gui-signal-displays (entity, title)
local combinatorsToUI = {}
local update_interval = 30


--Helper method for my debugging while coding
local function out(txt)
  debug = false
  if debug then
    game.print(txt)
  end
end

local function txtpos(pos)
  return "{" .. pos["x"] .. ", " .. pos["y"] .."}"
end

local function getNewId()
  local id = #combinatorsToUI
  while combinatorsToUI[id] do
    id = id + 1
  end
  return id
end

--Creates a new GUI and returns it's var
local function createGUI(uicomb, id, player)
  local top = player.gui.top
  if top["visual_signals"] == nil then
    top.add({type = "sprite-button", name = "visual_signals", style = "slot_button_style", sprite = "item/gui-signal-display"})
  end
  
  local centerpane = player.gui.left
  if centerpane["gui_signal_display"] == nil then
    centerpane.add({type = "frame", name = "gui_signal_display"})
    centerpane["gui_signal_display"].add({type = "flow", name = "gui_signal_panel", direction = "vertical"})
  end

  local newGui = centerpane["gui_signal_display"]["gui_signal_panel"].add({
    type = "scroll-pane", name = "panel" .. id, vertical_scroll_policy = "never", horizontal_scroll_policy = "auto",
    style = "gui_signal_display_scroll"
  })
  newGui.add({type = "label", name = "panel_label", caption = uicomb.title})
  CreateSignalGuiPanel(newGui, nil, "signals")
  return newGui
end

--We add all the belts in the game to our data
local function onInit()
  if not global.fum_uic then
    global.fum_uic = {}
  end
  combinatorsToUI = global.fum_uic

  local toRemove = {}
  for k, v in pairs(combinatorsToUI) do
    if v[1] then
      v.entity = v[1]
    end
    if v[2] then
      v.ui = v[2]
    end
    if not v.entity or not v.entity.valid then
        table.insert(toRemove, key)
    end
  end
  for k, v in pairs(toRemove) do
    destroyCombinator(k)
  end
  
end

--We store which belts are in the world for next time
local function onLoad()
  combinatorsToUI = global.fum_uic
end 

--Destroys a gui and removes from table
local function destroyGui(entity)
  --out("Tries to remove : " .. tostring(entity) .. "at : " .. txtpos(entity.position))
  for k, v in pairs(combinatorsToUI) do
    --out(tostring(v.entity) .. ", " .. tostring(v[2]))
    local ent = v.entity
    if ent and ent.valid then
        out(txtpos(ent.position))
    end
    if not ent or not ent.valid then
      out("no ent or not valid: " .. tostring(ent))
      destroyCombinator(k)
      return
    end
    if entity.valid and txtpos(ent.position) == txtpos(entity.position) then
      destroyCombinator(k)
      return
    end
  end
end

function destroyCombinator(key)
    local uicomb = combinatorsToUI[key]
    out("destroy " .. key .. " value " .. tostring(uicomb))
    combinatorsToUI[key] = nil
    for k, player in pairs(game.players) do
      local centerpane = player.gui.left
      if centerpane["gui_signal_display"] then
        if centerpane["gui_signal_display"]["gui_signal_panel"]["panel" .. key] then
          centerpane["gui_signal_display"]["gui_signal_panel"]["panel" .. key].destroy()
        end

        if #centerpane["gui_signal_display"]["gui_signal_panel"].children == 0 then
          centerpane["gui_signal_display"].destroy()
        end
      end
    end
end

--When we place a new gui-signal-display, it's stored. Value is {entity, ui}
local function onPlaceEntity(event)
  if event.created_entity.name == "gui-signal-display" then
    local id = getNewId()
    local uicomb = {entity = event.created_entity, title = "Signal Display " .. id}
    combinatorsToUI[id] = uicomb
    if event.robot then
      for k, player in pairs(event.robot.force.players) do
        createGUI(uicomb, id, player)
      end
    else
      local player = game.players[event.player_index]
      for k, player in pairs(player.force.players) do
        createGUI(uicomb, id, player)
      end
    end
    --out("Added : ".. tostring(event.created_entity) .. " at : " .. txtpos(event.created_entity.position) )
  end
end

--Entity removed from table when removed from world
local function onRemoveEntity(event)
  if event.entity.name == "gui-signal-display" then
    destroyGui(event.entity)
  end
end


--Updates UI based on blocks signals
local function updateUICombinator(key, uicomb)
  local entity = uicomb.entity
  if not entity then
    return false
  end
  if not entity.valid then
    destroyGui(entity)
    return false
  end
  local circuit = entity.get_circuit_network(defines.wire_type.red)
  if not circuit then
    circuit = entity.get_circuit_network(defines.wire_type.green)
  end
  local force = entity.force
  for k, player in ipairs(force.players) do
    if player.gui.left["gui_signal_display"] and player.gui.left["gui_signal_display"]["gui_signal_panel"] then
      local guiRoot = player.gui.left["gui_signal_display"]["gui_signal_panel"]
      if guiRoot["panel" .. key] then
        UpdateSignalGuiPanel(guiRoot["panel" .. key].signals, circuit)
      end
    end
  end
  return true
end


local function onTick()
  if 0 == game.tick % update_interval then
    for k, v in pairs(combinatorsToUI) do
      local updateOK = updateUICombinator(k, combinatorsToUI[k])
      if not updateOK then
        out("Removed something, skipping the rest")
        return
      end
    end
  end
end

local function onClickShownCheckbox(event)
  local player = game.players[event.player_index]
  local length = string.len("gui_signal_display_shown")
  local id = string.sub(event.element.name, length + 1)
  local guiRoot = player.gui.left["gui_signal_display"]["gui_signal_panel"]
  if guiRoot["panel" .. id] then
    guiRoot["panel" .. id].destroy()
  else
    local combui = combinatorsToUI[tonumber(id)]
    createGUI(combui, id, player)
  end
end

local function onClick(event)
  if string.find(event.element.name, "gui_signal_display_shown") then
    onClickShownCheckbox(event)
  end
  if event.element.name ~= "visual_signals" then
    return
  end
  local player = game.players[event.player_index]
  if player.gui.center["gui_signal_displayUI"] then
    player.gui.center["gui_signal_displayUI"].destroy()
  else
    local frameRoot = player.gui.center.add({type = "frame", name = "gui_signal_displayUI"})
    local frame = frameRoot.add({type = "scroll-pane", name = "gui_signal_scroll", style = "gui_signal_display_list"})
    local tableui = frame.add({type = "table", name = "table", colspan = 3})
    for k, v in pairs(combinatorsToUI) do
      out("combinatorsToUI has " .. k)
    end
    local guiRoot = player.gui.left["gui_signal_display"]["gui_signal_panel"]
    for k, v in pairs(guiRoot.children) do
      out("player has " .. v.name)
    end
    for k, v in pairs(combinatorsToUI) do
      if v.entity.force.name == player.force.name then
        tableui.add({type = "textfield", name = "gui_signal_display_nameEdit" .. k, text = v.title or ""})
      
        local circuit = v.entity.get_circuit_network(defines.wire_type.red)
        if not circuit then
          circuit = v.entity.get_circuit_network(defines.wire_type.green)
        end
      
        CreateSignalGuiPanel(tableui, circuit, "signals" .. k)
        local shown = guiRoot["panel" .. k] ~= nil
        out("checking if player has " .. k .. ": " .. tostring(shown))
        tableui.add({type = "checkbox", name = "gui_signal_display_shown" .. k, caption = "Show", state = shown})
      end
    end
    
    -- search
    -- general settings, show/hide left panel
    
    -- name
    -- signals
    -- show/hide
    -- show/hide condition
--    local list = frame.add({type = "scroll-pane", name = "list", vertical_scroll_policy = "always", horizontal_scroll_policy = "auto", style = "gui_signal_display_ui_list"})
  end
end

local function onPlayerChangedForce(event)
  local player = game.players[event.player_index]
  if player.gui.center["gui_signal_displayUI"] then
    player.gui.center["gui_signal_displayUI"].destroy()
  end
  if not player.gui.left["gui_signal_display"] then
    return
  end
  if not player.gui.left["gui_signal_display"]["gui_signal_panel"] then
    return
  end
  local guiRoot = player.gui.left["gui_signal_display"]["gui_signal_panel"]
  for k, v in pairs(combinatorsToUI) do
    if guiRoot["panel" .. k] then
      guiRoot["panel" .. k].destroy()
    end
  end
end

local function onTextChange(event)
  if string.find(event.element.name, "gui_signal_display_nameEdit") then
    local length = string.len("gui_signal_display_nameEdit")
    local id = tonumber(string.sub(event.element.name, length + 1))
    local uicomb = combinatorsToUI[id]
    local player = game.players[event.player_index]
    if not uicomb then
      player.print("No gui signal display for id " .. id)
      return
    end
    uicomb.title = event.element.text
    for k, p in pairs(game.players) do
      if player.gui.left["gui_signal_display"] and player.gui.left["gui_signal_display"]["gui_signal_panel"] then
        local rootGUI = player.gui.left["gui_signal_display"]["gui_signal_panel"]
        if rootGUI["panel" .. id] then
          rootGUI["panel" .. id]["panel_label"].caption = uicomb.title
        end
      end
    end
  end
end

script.on_init(onInit)
script.on_configuration_changed(onInit)
script.on_load(onLoad)

script.on_event(defines.events.on_built_entity, onPlaceEntity)
script.on_event(defines.events.on_robot_built_entity, onPlaceEntity)

script.on_event(defines.events.on_preplayer_mined_item, onRemoveEntity)
script.on_event(defines.events.on_robot_pre_mined, onRemoveEntity)
script.on_event(defines.events.on_entity_died, onRemoveEntity)

script.on_event(defines.events.on_tick, onTick)
script.on_event(defines.events.on_gui_click, onClick)

script.on_event(defines.events.on_player_changed_force, onPlayerChangedForce)
script.on_event(defines.events.on_gui_text_changed, onTextChange)