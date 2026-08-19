local UI = {}

local itemRibbon = nil

local settingsWindow = nil

local counterForItemSlot = 0

local totalslots = {}

local function addItemSlot(object)
    if (settingsWindow == nil) then
        return
    end
    local slot = nil
    if counterForItemSlot ~= 0 then
        slot = settingsWindow:AddItemSlot(object, {
        inline = true,
        tooltip = object.name,
        })
    else
        slot = settingsWindow:AddItemSlot(object, {
        tooltip = object.name,
        })
    end
    slot:SetObject(object)
    totalslots[object.name] = {
        slot = slot,
        object = object,
        category = object:GetParamValue(config.Param.FromID(2195)) + 1 -- 2195 is GE_CATEGORY, +1 is needed for some reason
    }
    counterForItemSlot = (counterForItemSlot + 1) % 8
end

local function destroyAllSlots()
    for key, value in pairs(totalslots) do
        value.slot:Destroy()
    end
end

local function rebuildSlots(slots)
    counterForItemSlot = 0
    local keys = {}
    for key, value in pairs(slots) do
        table.insert(keys, key)
    end
    table.sort(keys)

    for _, key in ipairs(keys) do
        local value = slots[key]
        addItemSlot(value.object)
    end
end

local function resetAllSlots()
    destroyAllSlots()
    rebuildSlots(totalslots)
end

function UI.load(game_window, setOfItemsAcquired)
    settingsWindow = prettyui.Window.new(game_window, {
        title = "Plugin settings",
        x = -210,
        y = -150,
        xAnchor = 0.5,
        yAnchor = 0.5,
        width = 420,
        height = 300,
        minWidth = 320,
        minHeight = 220,
        scrollable = true,
        onClose = function(window)
            if itemRibbon ~= nil then
                itemRibbon:SetActive(false)
            end
        end,
    })

    settingsWindow:SetTitle("Bronzeman Mode")
    settingsWindow:SetSize(460, 320)
    settingsWindow:Close()

        
    -- Inventory artwork can be used instead of a built-in sprite.
    itemRibbon = prettyui.RibbonBar.Register({
        id = "bronzeman-plugin",
        object = config.Obj.BRONZE_MED_HELM,
        tooltip = "Open Bronzeman plugin",
        onClick = function(handle, active)
            settingsWindow.root.hidden = not active
        end,
    })

    local heading = settingsWindow:AddTitle("Your collected items")

    local search = settingsWindow:AddTextField({
        placeholder = "Bronze med helm",
        maxLength = 24,
        onChange = function(field, reason, text)
            if string.len(text) == 0 then
                resetAllSlots()
            else
                destroyAllSlots()
                local searchedslots = {}
                local searchText = string.lower(text)
                for key, value in pairs(totalslots) do
                    local keyText = string.lower(key)
                    if string.find(keyText, searchText, 1, true) then
                        searchedslots[key] = value
                    end
                end
                rebuildSlots(searchedslots)
            end
        end,
    })

    local categories = settingsWindow:AddComboBox({
        entries = {
            { label = "", id = 0},
            { label = "1", id = 1},
            { label = "2", id = 2},
            { label = "3", id = 3},
            { label = "4", id = 4},
            { label = "5", id = 5},
            { label = "6", id = 6},
            { label = "7", id = 7},
            { label = "8", id = 8},
            { label = "9", id = 9},
            { label = "10", id = 10},
            { label = "11", id = 11},
            { label = "12", id = 12},
            { label = "13", id = 13},
            { label = "14", id = 14},
            { label = "15", id = 15},
            { label = "16", id = 16},
            { label = "17", id = 17},
            { label = "18", id = 18},
            { label = "19", id = 19},
            { label = "20", id = 20},
            { label = "21", id = 21},
            { label = "22", id = 22},
            { label = "23", id = 23},
            { label = "24", id = 24},
            { label = "25", id = 25},
            { label = "26", id = 26},
            { label = "27", id = 27},
            { label = "28", id = 28},
            { label = "29", id = 29},
            { label = "30", id = 30},
            { label = "31", id = 31},
            { label = "32", id = 32},
            { label = "33", id = 33},
            { label = "34", id = 34},
            { label = "35", id = 35},
            { label = "36", id = 36},
            { label = "37", id = 37},
            { label = "38", id = 38},
            { label = "39", id = 39},
            { label = "40", id = 40},
            { label = "41", id = 41},
            { label = "42", id = 42},
            { label = "43", id = 43},
            { label = "44", id = 44},
        },
        selectedID = 0,
        onChange = function(combo, id, label)
            if label == "" then
                resetAllSlots()
            end
            if id ~= tonumber(label) then
                return
            end
            destroyAllSlots()
            local selectedslots = {}
            for key, value in pairs(totalslots) do
                if id == value.category then
                    selectedslots[key] = value
                end
            end
            rebuildSlots(selectedslots)
        end,
    })

    for id, _ in pairs(setOfItemsAcquired) do
        local object = config.Obj.FromID(id)
        addItemSlot(object)
    end
    resetAllSlots()
end

function UI:addItemSlot(object)
    addItemSlot(object)
    resetAllSlots()
end

return UI