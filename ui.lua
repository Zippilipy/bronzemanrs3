local UI = {}

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

local view

local view2

local settings = PersistentDB:Get("settings")
if settings == nil then
    log("Persistent DB for settings was nil!")
    -- default settings
    settings = {}
    PersistentDB:Set("settings", settings)
end

local defaultSettings = {
    shouldShowUnobtainedItems = "off",
    pkingAllowed = "off",
    showIcon = "on",
}

for key, defaultValue in pairs(defaultSettings) do
    if settings[key] == nil then
        settings[key] = defaultValue
    end
end


local shouldShowUnobtainedItems = settings["shouldShowUnobtainedItems"] == "on"
local pkingAllowed = settings["pkingAllowed"] == "on"
local showIcon = settings["showIcon"] == "on"

local pluginresource = Plugin.resources.images.icon.bronzemanicon
pluginresource:Load()

local chats = {
    [1] = id.Component.CHATDEFAULT__PLAYER_NAME,
    [2] = id.Component.CHATDEFAULT2__PLAYER_NAME,
    [3] = id.Component.CHATDEFAULT3__PLAYER_NAME,
    [4] = id.Component.CHATDEFAULT4__PLAYER_NAME,
    [5] = id.Component.CHATDEFAULT5__PLAYER_NAME,
    [6] = id.Component.CHATDEFAULT6__PLAYER_NAME,
    [8] = id.Component.CHATDEFAULT8__PLAYER_NAME,
}

local input = {
    [1] = id.Component.CHATDEFAULT__INPUTAREA,
    [2] = id.Component.CHATDEFAULT2__INPUTAREA,
    [3] = id.Component.CHATDEFAULT3__INPUTAREA,
    [4] = id.Component.CHATDEFAULT4__INPUTAREA,
    [5] = id.Component.CHATDEFAULT5__INPUTAREA,
    [6] = id.Component.CHATDEFAULT6__INPUTAREA,
    [8] = id.Component.CHATDEFAULT8__INPUTAREA,
}

local names = {}

local inputfields = {}

local namecomp = ui.Interfaces:GetComponent(id.Component.CHATDEFAULT__PLAYER_NAME)

local function bronzemanIcon()
    for _, value in pairs(names) do
        if value.component.x == value.x then
            value.component:SetPos(value.x + 9, value.y)
        end
    end
    for _, value in pairs(inputfields) do
        if value.component.x == value.x then
            value.component:SetPos(value.x + 9, value.y)
        end
    end
    if namecomp.content == "Search Wiki<img=3>:" then
        local value = names[1]
        value.component:SetPos(value.x , value.y)
        value.icon.hidden = true
    else
        local value = names[1]
        value.icon.hidden = false
    end
end

local icons = {}

local function addIconStuff()
    for key, value in pairs(chats) do
        local comp = ui.Interfaces:GetComponent(value)
        local icon = ui.Sprite.new(comp.parent)
        icon:SetSize(9, 11)
        icon.sprite = pluginresource
        icon:SetPos(comp.x, comp.y+7)
        names[key] = {component = comp, x = comp.x, y = comp.y, icon = icon}
        table.insert(icons, icon)
    end

    for key, value in pairs(input) do
        local comp = ui.Interfaces:GetComponent(value)
        inputfields[key] = {component = comp, x = comp.x, y = comp.y}
    end
end

local function resetIconStuff()
    for _, value in pairs(names) do
        if value.component.x ~= value.x then
            value.component:SetPos(value.x, value.y)
        end
        value.icon:Destroy()
    end
    for _, value in pairs(inputfields) do
        if value.component.x ~= value.x then
            value.component:SetPos(value.x, value.y)
        end
    end
    pluginresource:Unload()
end

if showIcon then
    addIconStuff()
    Event.Draw.Subscribe("bronzemanIcon", bronzemanIcon)
end

local function addItemSlot(object, name, obtained)
    if (settingsWindow == nil) then
        return
    end
    if string.len(name) == 0 then
        return
    end
    local slot = nil
    if counterForItemSlot ~= 0 then
        slot = view2:AddItemSlot(object, {
        inline = true,
        disabled = not obtained,
        tooltip = name
        })
    else
        slot = view2:AddItemSlot(object, {
        disabled = not obtained,
        tooltip = name
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

local function createPages(setOfItemsAcquiredParameter, useSetOfItemsEvenIfShowUnobtained)
    if sortedIds == nil then
        sortedIds = {}
        sortedPosition = {}
        for id, _ in pairs(setOfAllItems) do
            table.insert(sortedIds, id)
        end
        table.sort(sortedIds, function(a, b)
            local textA = setOfAllItems[a]
            local textB = setOfAllItems[b]

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
    if shouldShowUnobtainedItems and not useSetOfItemsEvenIfShowUnobtained then
        for _, value in ipairs(sortedIds) do
            if string.len(setOfAllItems[value]) ~= 0 then
                table.insert(sorted, value)
            end
        end
    else
        for id, name in pairs(setOfItemsAcquiredParameter) do
            if string.len(name) ~= 0 then
                table.insert(sorted, id)
            end
        end
    end
    local finalPosition = {}
    local itemCount = 100000 -- arbitrarily high number that is more than the highest id
    for _, id in ipairs(sorted) do
        finalPosition[id] = sortedPosition[id] + (setOfItemsAcquired[id] ~= nil and 0 or itemCount)
    end
    table.sort(sorted, function(a, b)
        return finalPosition[a] < finalPosition[b]
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
    if shouldShowUnobtainedItems then 
        for _, id in ipairs(pages[page]) do
            local object = config.Obj.FromID(id)
            addItemSlot(object, setOfAllItems[id], setOfItemsAcquired[id] ~= nil)
        end
    else
        for _, id in ipairs(pages[page]) do
            local object = config.Obj.FromID(id)
            addItemSlot(object, setOfItemsAcquired[id], true)
        end
    end
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

function UI.load(game_window, root_layer, setOfItemsAcquiredParameter, setOfAllItemsParameter)
    local base_height = 1009
    local scaleY = game_window.height / base_height
    local preset = 2
    if scaleY < 0.8 then
        preset = 1
    end
    local presets = {
        [1] = {
            height = 400,
            width = 615,
            view1height = 120,
            view2height = 140,
            view3height = 100,
            view3yterm = -5,
        },

        [2] = {
            height = 745,
            width = 615,
            view1height = 120,
            view2height = 500,
            view3height = 100,
            view3yterm = -20,
        },
    }
    local sizes = presets[preset]
    setOfItemsAcquired = setOfItemsAcquiredParameter
    setOfAllItems = setOfAllItemsParameter
    settingsWindow = prettyui.Window.new(game_window, {
        title = "Bronzeman Mode",
        x = -sizes.width/2,
        y = -sizes.height/2,
        xAnchor = 0.5,
        yAnchor = 0.5,
        width = sizes.width,
        height = sizes.height,
        scrollable = true,
    })

    settingsWindow:Close()

    OpenWindow(root_layer)

    local tabs = settingsWindow:AddTabs({
        { text = "Collected items"},
        { text = "About this plugin"},
    }, {
        height = sizes.height-70,
        activeIndex = 1,
        onChange = function(group, index, value, page)
        end,
    })

    local collectedItemsTab = tabs:GetPage(1)
    local aboutThisPluginTab = tabs:GetPage(2)

    local count = 0

    for _ in pairs(setOfItemsAcquired) do
        count = count + 1
    end

    local view1height = sizes.view1height
    local view2height = sizes.view2height
    local view3height = sizes.view3height

    local view1 = prettyui.SimpleView.new(collectedItemsTab.content, {
        width = sizes.width - 20,
        height = view1height,
        y = 0,
        inline = true,
    })
    view1.scrollbarVisible = false
    view1:SetScrollable(false)

    heading = view1:AddTitle(string.format("Your collected items: %d", count))

    local previousText
    local search = view1:AddTextField({
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
                pages = createPages(setOfItemsAcquired, false)
                updatePageNumber()
                addAllItemsFromPages()
            else
                destroyAllSlots()
                local searchedSetOfItems = {}
                local searchText = string.lower(text)
                if shouldShowUnobtainedItems then
                    for key, name in pairs(setOfAllItems) do
                        local valueText = string.lower(name)
                        if string.find(valueText, searchText, 1, true) then
                            searchedSetOfItems[key] = name
                        end
                    end
                else
                    for key, name in pairs(setOfItemsAcquired) do
                        local valueText = string.lower(name)
                        if string.find(valueText, searchText, 1, true) then
                            searchedSetOfItems[key] = name
                        end
                    end
                end
                pages = createPages(searchedSetOfItems, true)
                updatePageNumber()
                addAllItemsFromPages()
            end
        end,
    })

    local categories = view1:AddComboBox({
        entries = {
            { label = "All items", id = 0},
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
                pages = createPages(setOfItemsAcquired, false)
                updatePageNumber()
                addAllItemsFromPages()
                return
            end
            local selectedSetOfItems = {}
            if shouldShowUnobtainedItems then 
                for key, name in pairs(setOfAllItems) do
                    local object = config.Obj.FromID(key)
                    if id == object:GetParamValue(config.Param.GE_CATEGORY) + 1 then
                        selectedSetOfItems[key] = name
                    end
                end
            else
                for key, name in pairs(setOfItemsAcquired) do
                    local object = config.Obj.FromID(key)
                    if id == object:GetParamValue(config.Param.GE_CATEGORY) + 1 then
                        selectedSetOfItems[key] = name
                    end
                end
            end
            pages = createPages(selectedSetOfItems, true)
            updatePageNumber()
            addAllItemsFromPages()
        end,
    })

    view2 = prettyui.SimpleView.new(collectedItemsTab.content, {
        width = sizes.width - 20,
        height = view2height,
        y = view1height,
        scrollbarVisible = true,
    })

    local view3 = prettyui.SimpleView.new(collectedItemsTab.content, {
        width = sizes.width - 20,
        height = view3height,
        y = view1height + view2height + sizes.view3yterm,
    })

    local alpha = 0.04
    local leftButton = view3:AddSpriteButton("ARROW_LEFT", function()
        if page == 1 then
            return
        end
        page = page - 1
        updatePageNumber()
        addAllItemsFromPages()
    end, {xAnchor = 0.4 - alpha/3})
    pageNumber = view3:AddText({
        text = "1",
        inline = true,
        xAnchor = 0.4
    })
    local rightButton = view3:AddSpriteButton("ARROW_RIGHT", function(self, enabled)
        if pages[page + 1] == nil then
            return
        end
        page = page+1
        updatePageNumber()
        addAllItemsFromPages()
    end, {inline = true, xAnchor = 0.4 + alpha})

    pages = createPages(setOfItemsAcquired, false)

    page = 1

    updatePageNumber()

    addAllItemsFromPages()

    local aboutThisPluginView = prettyui.SimpleView.new(aboutThisPluginTab.content, {
        height = sizes.height-100,
        width = sizes.width - 20
    })

    aboutThisPluginView:AddText("Welcome to Bronzeman Mode").font = id.Font.MUSEO_SANS_19PT_BOLD
    aboutThisPluginView:AddText("Features:").font = id.Font.MUSEO_SANS_17PT_BOLD
    aboutThisPluginView:AddText("1. Restricts buying from the Grand Exchange until the item has been unlocked, see below")
    aboutThisPluginView:AddText("2. Restricts you from being able to pick up items that have not been unlocked")
    aboutThisPluginView:AddText("3. Trading is disabled, except being able to be traded bonds, for unlocking membership")
    aboutThisPluginView:AddText("What counts as an unlock?").font = id.Font.MUSEO_SANS_17PT_BOLD
    aboutThisPluginView:AddText("Any item that is obtained through skilling, pvming or pking if desired (see Settings)")
    aboutThisPluginView:AddText("Items can be unlocked without requiring the level to normally obtain it through skilling")
    aboutThisPluginView:AddText("This means you can unlock a potion that you don't have the skill level for")
    aboutThisPluginView:AddText("Unlocking a potion unlocks all potion doses that are tradeable on the Grand Exchange")
    aboutThisPluginView:AddText("Any item that is already in your bank will be automatically unlocked")
    aboutThisPluginView:AddText("Any item that enters your inventory will be unlocked")
end

function UI:rebuildFromSetOfAcquiredItems(setOfItemsAcquiredParameter)
    setOfItemsAcquired = setOfItemsAcquiredParameter
    page = 1
    pages = createPages(setOfItemsAcquired, false)
    updatePageNumber()
    addAllItemsFromPages()
end

function UI:resetIconStuff()
    Event.Draw.Unsubscribe("bronzemanIcon")
    resetIconStuff()
end

function OpenWindow(root_layer)
    view = prettyui.SimpleView.new(root_layer, {
        width = root_layer.width
    })

    view:AddSimpleButton("Bronzeman collection", function(self, active)
        settingsWindow:Show()
    end)

    view:AddText("Show unobtained items? (may cause lag when searching)", { inline = true })

    view:AddRadioButton({
        { text = "On", value = "on" },
        { text = "Off", value = "off" },
    }, {
        selectedValue = settings["shouldShowUnobtainedItems"],
        onChange = function(group, value)
            settings["shouldShowUnobtainedItems"] = value
            shouldShowUnobtainedItems = value == "on"
            PersistentDB:Set("settings", settings)
            UI:rebuildFromSetOfAcquiredItems(setOfItemsAcquired)
        end,
        inline = true,
    })

    view:AddText("Should PKing unlock items? (currently does nothing)", { inline = true })

    view:AddRadioButton({
        { text = "On", value = "on" },
        { text = "Off", value = "off" },
    }, {
        selectedValue = settings["pkingAllowed"],
        onChange = function(group, value)
            settings["pkingAllowed"] = value
            pkingAllowed = value == "on"
            PersistentDB:Set("settings", settings)
        end,
        inline = true,
    })

    view:AddText("Show Bronzeman icon?", {inline = true})

    view:AddRadioButton({
        { text = "On", value = "on" },
        { text = "Off", value = "off" },
    }, {
        selectedValue = settings["showIcon"],
        onChange = function(group, value)
            settings["showIcon"] = value
            showIcon = value == "on"
            PersistentDB:Set("settings", settings)
            if showIcon then
                addIconStuff()
                Event.Draw.Subscribe("bronzemanIcon", bronzemanIcon)
            else
                Event.Draw.Unsubscribe("bronzemanIcon")
                resetIconStuff()
            end
        end,
        inline = true,
    })
end

function UI:OpenWindow(root_layer)
    if view ~= nil then
        view:Destroy()
    end
    OpenWindow(root_layer)
end

function UI:destroyUIStuff()
    destroyAllSlots()
    settingsWindow:Destroy()
end

return UI