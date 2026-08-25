local UI = {}

local itemRibbon = nil

local settingsWindow = nil

local counterForItemSlot = 0

local page

local pages = {}

local sortedIds

local sortedPosition

local totalslots = {}

local setOfItemsAcquired

local setOfAllItems

local pageNumber

local heading

local function addItemSlot(object, name)
    if (settingsWindow == nil) then
        return
    end
    if string.len(name) == 0 then
        return
    end
    local slot = nil
    if counterForItemSlot ~= 0 then
        slot = settingsWindow:AddItemSlot(object, {
        inline = true,
        tooltip = name,
        })
    else
        slot = settingsWindow:AddItemSlot(object, {
        tooltip = name,
        })
    end
    slot:SetObject(object)
    totalslots[object.id] = slot
    counterForItemSlot = (counterForItemSlot + 1) % 12
    return slot
end

local function destroyAllSlots()
    counterForItemSlot = 0
    for key, value in pairs(totalslots) do
        value:Destroy()
        totalslots[key] = nil
    end
end

local function createPages(setOfItemsAcquiredParameter)
    if sortedIds == nil then
        sortedIds = {}
        sortedPosition = {}
        for id, _ in pairs(setOfAllItems) do
            table.insert(sortedIds, id)
        end
        table.sort(sortedIds, function(a, b)
            local textA = setOfAllItems[a].name
            local textB = setOfAllItems[b].name

            local startsWithLetterA = string.match(textA, "^[A-Za-z]") ~= nil
            local startsWithLetterB = string.match(textB, "^[A-Za-z]") ~= nil

            if startsWithLetterA ~= startsWithLetterB then
                return startsWithLetterA
            end

            return string.lower(textA) < string.lower(textB)
        end)

        for position, id in ipairs(sortedIds) do
            sortedPosition[id] = position
        end
    end
    local sorted = {}
    for id, name in pairs(setOfItemsAcquiredParameter) do
        if string.len(name) ~= 0 then
            table.insert(sorted, id)
        end
    end
    table.sort(sorted, function(a, b)
        return sortedPosition[a] < sortedPosition[b]
    end)
    local page = 1
    local pages = {}
    pages[page] = {}
    local counterForNextPage = 0
    for _, id in ipairs(sorted) do
        counterForNextPage = counterForNextPage + 1
        table.insert(pages[page], id)
        if counterForNextPage >= 120 then
            page = page + 1
            pages[page] = {}
            counterForNextPage = 0
        end
    end
    return pages
end

local function addAllItemsFromPages()
    destroyAllSlots()
    for _, id in ipairs(pages[page]) do
        local object = config.Obj.FromID(id)
        addItemSlot(object, setOfItemsAcquired[id])
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
    addAllItemsFromPages()
end

local function updatePageNumber()
    local itemCount = 0

    for _, name in pairs(setOfItemsAcquired) do
        if name ~= "" then
            itemCount = itemCount + 1
        end
    end

    heading.content = string.format("Your collected items: %d", itemCount)
    local pageCount = 0
    for _ in pairs(pages) do
        pageCount = pageCount + 1
    end
    pageNumber.content = string.format("%d/%d", page, pageCount)
end

function UI.load(game_window, setOfItemsAcquiredParameter, setOfAllItemsParameter)
    setOfItemsAcquired = setOfItemsAcquiredParameter
    setOfAllItems = setOfAllItemsParameter
    settingsWindow = prettyui.Window.new(game_window, {
        title = "Plugin settings",
        x = -210,
        y = -150,
        xAnchor = 0.5,
        yAnchor = 0.5,
        width = 420*2,
        height = 300*2,
        minWidth = 320*2,
        minHeight = 220*2,
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

    local count = 0

    for _ in pairs(setOfItemsAcquiredParameter) do
        count = count + 1
    end

    heading = settingsWindow:AddTitle(string.format("Your collected items: %d", count))

    local previousText
    local search = settingsWindow:AddTextField({
        placeholder = "Bronze med helm",
        maxLength = 24,
        onChange = function(field, reason, text)
            if text == previousText then -- no reason to do duplicate work
                return
            end
            if reason == 4 then -- when you click away from search I don't want to count that
                return
            end
            previousText = text
            page = 1
            if string.len(text) == 0 then
                pages = createPages(setOfItemsAcquired)
                updatePageNumber()
                addAllItemsFromPages()
            else
                destroyAllSlots()
                local searchedSetOfItemsAcquired = {}
                local searchText = string.lower(text)
                for key, value in pairs(setOfItemsAcquired) do
                    local valueText = string.lower(value)
                    if string.find(valueText, searchText, 1, true) then
                        searchedSetOfItemsAcquired[key] = value
                    end
                end
                pages = createPages(searchedSetOfItemsAcquired)
                updatePageNumber()
                addAllItemsFromPages()
            end
        end,
    })

    categories = settingsWindow:AddComboBox({
        entries = {
            { label = "", id = 0},
            { label = "Miscellaneous", id = 1},
            { label = "Ammo", id = 2},
            { label = "Arrows", id = 3},
            { label = "Bolts", id = 4},
            { label = "Construction materials", id = 5},
            { label = "Construction products", id = 6},
            { label = "Cooking ingredients", id = 7},
            { label = "Costumes", id = 8},
            { label = "Crafting materials", id = 9},
            { label = "Familiars", id = 10},
            { label = "Farming produce", id = 11},
            { label = "Fletching materials", id = 12},
            { label = "Food and drink", id = 13},
            { label = "Herblore materials", id = 14},
            { label = "Hunting equipment", id = 15},
            { label = "Hunting produce", id = 16},
            { label = "Jewellery", id = 17},
            { label = "Mage armour", id = 18},
            { label = "Mage weapons", id = 19},
            { label = "Melee armour - low level", id = 20},
            { label = "Melee armour - mid level", id = 21},
            { label = "Melee armour - high level", id = 22},
            { label = "Melee weapons - low level", id = 23},
            { label = "Melee weapons - mid level", id = 24},
            { label = "Melee weapons - high level", id = 25},
            { label = "Mining and smithing", id = 26},
            { label = "Potions", id = 27},
            { label = "Prayer armour", id = 28},
            { label = "Prayer materials", id = 29},
            { label = "Range armour", id = 30},
            { label = "Range weapons", id = 31},
            { label = "Runecrafting", id = 32},
            { label = "Runes, spells and teleports", id = 33},
            { label = "Seeds", id = 34},
            { label = "Summoning scrolls", id = 35},
            { label = "Tools and containers", id = 36},
            { label = "Woodcutting product", id = 37},
            { label = "Pocket items", id = 38},
            { label = "Stone spirits", id = 39},
            { label = "Salvage", id = 40},
            { label = "Firemaking products", id = 41},
            { label = "Archaeology materials", id = 42},
            { label = "Wood spirits", id = 43},
            { label = "Necromancy armour", id = 44},
        },
        selectedID = 0,
        onChange = function(combo, id, label, eventType)
            if eventType ~= ui.SelectionChangeEvent.SELECTED then
                return
            end
            page = 1
            if id == 0 then
                pages = createPages(setOfItemsAcquired)
                updatePageNumber()
                addAllItemsFromPages()
                return
            end
            local selectedSetOfItems = {}
            for key, name in pairs(setOfItemsAcquired) do
                local object = config.Obj.FromID(key)
                if id == object:GetParamValue(config.Param.FromID(2195)) + 1 then -- 2195 is GE_CATEGORY
                    selectedSetOfItems[key] = name
                end
            end
            pages = createPages(selectedSetOfItems)
            updatePageNumber()
            addAllItemsFromPages()
        end,
    })

    local alpha = 0.04
    local leftButton = settingsWindow:AddSpriteButton("ARROW_LEFT", function()
        if page == 1 then
            return
        end
        page = page - 1
        updatePageNumber()
        addAllItemsFromPages()
    end, {xAnchor = 0.4 - alpha})
    pageNumber = settingsWindow:AddText({
        text = "1",
        inline = true,
        xAnchor = 0.4
    })
    local rightButton = settingsWindow:AddSpriteButton("ARROW_RIGHT", function(self, enabled)
        if pages[page + 1] == nil then
            return
        end
        page = page+1
        updatePageNumber()
        addAllItemsFromPages()
    end, {inline = true, xAnchor = 0.4 + alpha})

    local divider = settingsWindow:AddDivider()

    pages = createPages(setOfItemsAcquired)

    page = 1

    updatePageNumber()

    addAllItemsFromPages()
end

function UI:rebuildFromSetOfAcquiredItems(setOfItemsAcquiredParameter)
    setOfItemsAcquired = setOfItemsAcquiredParameter
    page = 1
    pages = createPages(setOfItemsAcquired)
    updatePageNumber()
    addAllItemsFromPages()
end

return UI