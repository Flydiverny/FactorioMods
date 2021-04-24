local tables = require("__flib__.table")
local misc = require("__flib__.misc")
local gui = require("__flib__.gui-beta")

local function handle_action(action, event)
    local player = game.players[event.player_index]
    if action.action == "icon" then
        local train_id = action.train_id
        local train_data = global.trains[train_id]
        local train = train_data.train
        player.zoom_to_world(train.front_stock.position, 0.5)
    end
end

local function sprite_button_type_name_amount(type, name, amount, color)
    local prototype = nil
    if type == "item" then
        prototype = game.item_prototypes[name]
    elseif type == "fluid" then
        prototype = game.fluid_prototypes[name]
    elseif type == "virtual-signal" then
        prototype = game.virtual_signal_prototypes[name]
    end
    return {
        type = "sprite-button",
        style = color and "flib_slot_button_" .. color or "flib_slot_button_default",
        sprite = type .. "/" .. name,
        number = amount,
        tooltip = prototype and prototype.localised_name or "No prototype for " .. type .. "/" .. name
    }
end

local function sprite_button_for_state(state)
    local description = ""
    if state == defines.train_state.on_the_path	then
        description = { "train-log.train_state-on_the_path" }
    elseif state == defines.train_state.path_lost then
        description = { "train-log.train_state-path_lost" }
    elseif state == defines.train_state.no_schedule then
        description = { "train-log.train_state-no_schedule" }
    elseif state == defines.train_state.no_path then
        description = { "train-log.train_state-no_path" }
    elseif state == defines.train_state.arrive_signal then
        description = { "train-log.train_state-arrive_signal" }
    elseif state == defines.train_state.wait_signal then
        description = { "train-log.train_state-wait_signal" }
    elseif state == defines.train_state.arrive_station then
        description = { "train-log.train_state-arrive_station" }
    elseif state == defines.train_state.wait_station then
        description = { "train-log.train_state-wait_station" }
    elseif state == defines.train_state.manual_control_stop then
        description = { "train-log.train_state-manual_control_stop" }
    elseif state == defines.train_state.manual_control then
        description = { "train-log.train_state-manual_control" }
    elseif state == defines.train_state.destination_full then
        description = { "train-log.train_state-destination_full" }
    end
    return {
        type = "sprite-button",
        style = color and "flib_slot_button_" .. color or "flib_slot_button_default",
        sprite = "item/iron-plate",
        number = state,
        tooltip = description
    }
end

local function signal_for_entity(entity)
    local empty_signal = { type = "virtual", name = "signal-0" }
    if not entity then return empty_signal end
    if not entity.valid then return empty_signal end

    k, v = next(entity.prototype.items_to_place_this)
    if k then
        return { type = "item", name = v.name }
    end
    return empty_signal
end

local function events_row(train_data, index, children)
    -- Show train icon, timestamp HMS, events

    local train_icon = { type = "empty-widget" }

    if train_data.train.valid and train_data.train.front_stock.valid then
        local prototype = train_data.train.front_stock.prototype
        train_icon = {
            type = "sprite-button",
            style = "slot_button",
            sprite = "item/" .. signal_for_entity(train_data.train.front_stock).name,
            number = train_data.train.id,
            tooltip = prototype.localised_name,
            actions = {
                on_click = { type = "table", action = "icon", train_id = train_data.train.id }
            }
        }
    end

    local last_change = train_data.started_at
    local timestamp = {
        type = "label",
        caption = misc.ticks_to_timestring(last_change, true)
    }

    local event_children = {}
    for _, event in pairs(train_data.events) do
        local delay = event.tick - last_change
        local delay_button = {
            type = "sprite-button",
            sprite = "train_log_timer-outline",
            tooltip = misc.ticks_to_timestring(last_change, true)
        }
        -- table.insert(event_children, delay_button)
        if event.state then
            table.insert(event_children, sprite_button_for_state(event.state))
        end
        if event.schedule then
            table.insert(event_children, {
                type = "sprite-button",
                sprite = "train_log_train",
                tooltip = {"train-log.schedule-change"}
            })
            if event.changed_by then
                table.insert(event_children, {
                    type = "sprite-button",
                    sprite = "train_log_train",
                    tooltip = {"train-log.schedule-changed-by", event.changed_by}
                })
            end
        end
        if event.station then
            table.insert(event_children, {
                type = "sprite-button",
                sprite = "entity/" .. event.station.name,
                tooltip = {"train-log.station-name", event.station.backer_name}
            })
        end
        if event.contents then
            for name, count in pairs(event.contents) do
                table.insert(event_children, sprite_button_type_name_amount("item", name, count))
            end
        end
        if event.fluids then
            for name, count in pairs(event.fluids) do
                table.insert(event_children, sprite_button_type_name_amount("fluid", name, count))
            end
        end
        last_change = event.tick
    end

    local event_flow = {
        type = "flow",
        direction = "horizontal",
        children = event_children
    }

    table.insert(children, train_icon)
    table.insert(children, timestamp)
    table.insert(children, event_flow)
end

local function create_result_guis(results, columns)
    local children = {}
    for _, column in pairs(columns) do
        table.insert(children, {
            type = "label",
            caption = column
        })
    end
    tables.for_each(results, function(result, index)
        events_row(result, index, children)
    end)
    return children
end

local function create_events_table(gui_id)
    -- Loop through train datas, start with oldest (easier to move newest to the end)
    -- Loop through all the histories first and then check current, sort by the tick of last entry
    local train_log_gui = global.guis[gui_id]
    local histories = {}
    local train_datas = global.trains
    for _, history in pairs(global.history) do
        if history.force_index == train_log_gui.player.force.index then
            table.insert(histories, history)
        end
    end
    for _, train_data in pairs(train_datas) do
        if train_data.force_index == train_log_gui.player.force.index then
            table.insert(histories, train_data)
        end
    end

    table.sort(histories, function(a, b) return a.last_change < b.last_change end)

    local children_guis = create_result_guis(histories, { "train", "timestamp", "events" })
    train_log_gui.gui.internal.clear()

    gui.build(train_log_gui.gui.internal, {
        {
            type = "scroll-pane",
            style = "flib_naked_scroll_pane_no_padding",
            style_mods = {height = 400},
            children = {
                {
                    type = "table",
                    ref = { "events_table" },
                    column_count = 3,
                    children = children_guis
                }
            }
        }
    })
end

return {
    handle_action = handle_action,
    create_events_table = create_events_table
}
