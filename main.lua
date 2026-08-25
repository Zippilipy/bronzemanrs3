local Queue = require("queue")
local UI = require("ui")
-- establish important global variables
-- game window, is the game window
game_window = ui.Interfaces:GetComponent(id.Component.TOPLEVEL_V2__PLUGIN_BUILD_LAYER_TOP)

-- setOfItemsAcquired is a table mapping ids to true or nil, true means you have acquired said item, nil means you haven't
local setOfAllItems = {}
PersistentDB:Clear()
local setOfItemsAcquired = PersistentDB:Get("acquiredItems")
if setOfItemsAcquired==nil then
    log("Persistent DB was nil!")
    setOfItemsAcquired = {}
    setOfItemsAcquired[id.Obj.LRC_ROCKTAIL_COOKED] = config.Obj.FromID(id.Obj.LRC_ROCKTAIL_COOKED).name -- manually add rocktail to list
    setOfItemsAcquired[id.Obj.STRENGTH4] = config.Obj.FromID(id.Obj.STRENGTH4).name
    setOfItemsAcquired[id.Obj._3DOSE1STRENGTH] = config.Obj.FromID(id.Obj._3DOSE1STRENGTH).name
    PersistentDB:Set("acquiredItems",setOfItemsAcquired)
end

for i=1,100000,1 do
    local object = config.Obj.FromID(i)
    if object == nil or not object.isStockmarket then
        goto continue
    end
    local value = false
    if setOfItemsAcquired[i] ~= nil then
        value = true
    end
    setOfAllItems[i] = {
        name = object.name,
        obtained = value
    }
    ::continue::
end

UI.load(game_window, setOfItemsAcquired, setOfAllItems)


-- counterForCollectionPopup has a value [0..4] and will show the achievement popup at value 0, then increment by one
-- for each server tick, essentially making the collection log popup every 5 ticks.
local counterForCollectionPopup = 0

-- collectionPopupQueue is a queue for the achievement popup, making it go every 5 ticks with counterForCollectionPopup
local collectionPopupQueue = Queue.new()

local function standardPopup(object)
    local collectionPopupItem = {
        title = "Bronzeman log",
        text = string.format("New item obtained: %s", object.name),
        item = object,
        y = 50,
    }
    return collectionPopupItem
end

local function addToAcquired(id, object, collectionPopupItem)
    if object == nil or not object.isStockmarket then
        return
    end
    if setOfItemsAcquired[id] ~= nil then
        return
    end
    setOfItemsAcquired[id] = object.name
    PersistentDB:Set("acquiredItems",setOfItemsAcquired)
    if collectionPopupItem ~= nil then
        collectionPopupQueue:enqueue(collectionPopupItem)
    end
    UI:rebuildFromSetOfAcquiredItems(setOfItemsAcquired)
end

local function hasAcquired(id)
    return setOfItemsAcquired[id] ~= nil
end

-- isRed is a boolean value that says whether it's red or not, this allows an early return on onMouseRepeat
local isRed = false

-- Create a new box for components
local myComponent = ui.GroupBox.new(game_window)
local thing_to_be_blocked = ui.Interfaces:GetComponent(id.Component.TOPLEVEL_V2__LOOT_INVENTORY_WINDOW)

-- rectangle to block interaction
local blocking_rectangle = ui.Rectangle.new(game_window)
blocking_rectangle:SetPos(thing_to_be_blocked.position.x,thing_to_be_blocked.position.y)
blocking_rectangle:SetSize(thing_to_be_blocked.size.width,thing_to_be_blocked.size.height)
blocking_rectangle.clickthrough = true
blocking_rectangle.colour = Vector4.new(0,0,0,0)
blocking_rectangle.fill = true

-- find all items in a 7 tile range for area loot
-- returns a list of item ids, the same type of ids stored in setOfItemsAcquired
local function findAllNearbyItemIds()
    local nearbyItemIds = {}
    local self = Player.GetEntity()
    if self == nil then 
        return nearbyItemIds
    end
    local coordGrid = self.coordGrid
    local allObjects = ObjStackList.ByDistance(coordGrid, 11) -- area loot is 7 tiles
    if #allObjects == 0 then 
        return nearbyItemIds
    end
    for _,objStackEntity in ipairs(allObjects) do
        for i=1,objStackEntity.stackSize do
            local entry = objStackEntity:GetEntry(i)
            local name = entry.config.configName
            local id = entry.config.id
            table.insert(nearbyItemIds, id)
        end
    end
    return nearbyItemIds
end

-- uses findAllNearbyItemIds to determine whether or not the area loot event should be consumed
-- returns true if it should be consumed, that is, the event should not be sent to the server
-- returns false if it should not be consumed and will continue to the server
local function shouldConsumeAreaLoot()
    local nearbyItemIds = findAllNearbyItemIds()
    for _,id in ipairs(nearbyItemIds) do
        local acquired = hasAcquired(id)
        if not acquired then
            return true
        end
    end
    return false
end

--subscrtibe to mouserepeat events for the blocking rectangle
blocking_rectangle:Subscribe(ui.Hook.ONMOUSEREPEAT, "mouseEnterHook",
    function (self)
        if isRed then -- early return since this is a mouserepeat
            return
        end
        if shouldConsumeAreaLoot() then
            isRed = true
            self.clickthrough = false
            self.colour = Vector4.new(0.5,0,0,0.5)
        end
    end
)
blocking_rectangle:Subscribe(ui.Hook.ONMOUSELEAVE, "mouseLeaveHook",
    function (self)
        isRed = false
        self.clickthrough = true
        self.colour = Vector4.new(0,0,0,0)
    end
)

function miniMenuReadyFunc(event)
    -- Make changes to the minimenu
    local entries = event.miniMenu.entries
    if entries == nil then
        return
    end
    local idxA = 0
    local idxB = 0
    for i, entry in pairs(entries) do
        if entry.actionEntryType ~= MiniMenuEntryType.OBJ then
            goto continue
        end
        local object = entry.objData.config
        if not object.isTradeable then -- you should be able to pick up your own untradeable stuff
            goto continue
        end
        if not hasAcquired(object.id) then
            if entry.actionVerbType == 2 then
                idxA = i
            elseif entry.actionVerbType == 1 then
                idxB = i
            end
        end
        ::continue::
    end
    event.miniMenu:Swap(idxA, idxB)
end
Event.MiniMenuReady.Subscribe("myEvent", miniMenuReadyFunc)

local mouse_blocking_rectangle = ui.Rectangle.new(game_window)
local side = 100
--mouse_blocking_rectangle:SetPos(thing_to_be_blocked.position.x,thing_to_be_blocked.position.y)
mouse_blocking_rectangle:SetSize(side,side)
mouse_blocking_rectangle.clickthrough = true
mouse_blocking_rectangle.colour = Vector4.new(0,0,0,0)
mouse_blocking_rectangle.fill = true
local isredtwo = false
local function removeEntry(event)
    if event.entry.actionEntryType == MiniMenuEntryType.OBJ then
        local object = event.entry.objData.config
        if not object.isTradeable then -- you should be able to pick up your own untradeable stuff
            return
        end
        if not hasAcquired(object.id) then
            --don't allow you to pick it up
            local position = Mouse.GetPosition()
            if position == nil then
                return
            end
            local x, y = position.x, position.y
            mouse_blocking_rectangle:SetPos(x-side/2, y-side/2)
            isredtwo = true
            mouse_blocking_rectangle.clickthrough = false
            mouse_blocking_rectangle.colour = Vector4.new(0.5,0,0,0.5)
        end
    end
end

mouse_blocking_rectangle:Subscribe(ui.Hook.ONMOUSEREPEAT, "mouseEnterHook",
    function (self)
        if isredtwo then -- early return since this is a mouserepeat
            return
        end
        if shouldConsumeAreaLoot() then
            isredtwo = true
            self.clickthrough = false
            self.colour = Vector4.new(0.5,0,0,0.5)
        end
    end
)
mouse_blocking_rectangle:Subscribe(ui.Hook.ONMOUSELEAVE, "mouseLeaveHook",
    function (self)
        isredtwo = false
        self.clickthrough = true
        self.colour = Vector4.new(0,0,0,0)
    end
)

--Event.MiniMenuEntryAdded.Subscribe("removeEntry", removeEntry)

-- addToItemAcquiredFromDrop and addToItemAcquiredFromDropChanged both add from items on the ground
-- I need a way to check ownership of the drop, right now it just counts anything on the ground
--local function addToItemAcquiredFromDrop(event)
--    addToAcquired(event.objType.id, event.objType.name, event.objType)
--end
--Event.ObjStackEntityAdded.Subscribe("dropEvent", addToItemAcquiredFromDrop)
--local function addToItemAcquiredFromDropChanged(event)
--    if event.oldCount > event.newCount then
--        return
--    end
--    addToAcquired(event.objType.id, event.objType.name, event.objType)
--end
--Event.ObjStackEntityChanged.Subscribe("dropEvent", addToItemAcquiredFromDropChanged)

-- Here's my super duper non-threading solution to simultaneous collectionPopupEvents, I store them in a queue
-- then dequeue every 5 ticks
local function showAchievementPopup()
    if counterForCollectionPopup ~= 0 then
        counterForCollectionPopup = (counterForCollectionPopup + 1) % 5
        return
    end
    if collectionPopupQueue:isEmpty() then
        return
    end
    local collectionPopupItem = collectionPopupQueue:dequeue()
    local popup = prettyui.AchievementPopup.show({
        title = collectionPopupItem.title,
        text = collectionPopupItem.text,
        item = collectionPopupItem.item,
        y = collectionPopupItem.y
    })
    counterForCollectionPopup = 1
    end
Event.ServerLogic.Subscribe("showAchievementPopupEvent", showAchievementPopup)

-- establish important variables for the shouldShowAreaLoot 
local isShowing = true -- useful to prevent unnecessary actions
local loot_all_component
local loot_custom_component
-- loot component is useful because if the player closes the menu and opens it again, that is a new component, 
-- so we can do a check if the new is the same as the old

local loot_all_pos_x
local loot_all_pos_y

local loot_custom_pos_x
local loot_custom_pos_y

local initialized = false
local doubleinit = false

local hasHitADynamic = false
local function isTheLootInterfaceOpen()
    -- if we can find a dynamic child component then that means that the loot interface is open
    local function doesItHitADynamic(input, static)
        if static then 
            input:IterateStaticComponents(
                function (component, visible)
                    if component.type == ui.ComponentType.LAYER then 
                        doesItHitADynamic(component, true)
                        doesItHitADynamic(component, false)
                    end
                return false
                end)
        else
            input:IterateDynamicComponents(
                function (component, visible)
                    hasHitADynamic = true
                    return false
                end)
        end
    end
    doesItHitADynamic(ui.Interfaces:GetComponent(id.Component.TOPLEVEL_V2_LOOT__BUTTONS_LAYER), true)
    return hasHitADynamic
end

-- if the loot interface is open as the plugin starts, then we can initialize immedietaly, instead of waiting
-- for the user to open the loot interface
if isTheLootInterfaceOpen() then
    loot_all_component = ui.Interfaces:GetComponent(id.Component.TOPLEVEL_V2_LOOT__LOOT_ALL_BUTTON_LAYER)
    loot_custom_component = ui.Interfaces:GetComponent(id.Component.TOPLEVEL_V2_LOOT__LOOT_CUSTOM_BUTTON_LAYER)
    isShowing = true
    if not initialized then
        initialized = true
    end
end

local function lootINV(event)
    if event.inv.id == id.Inv.LOOT then
        loot_all_component = ui.Interfaces:GetComponent(id.Component.TOPLEVEL_V2_LOOT__LOOT_ALL_BUTTON_LAYER)
        loot_custom_component = ui.Interfaces:GetComponent(id.Component.TOPLEVEL_V2_LOOT__LOOT_CUSTOM_BUTTON_LAYER)
        isShowing = true
        if not initialized then
            initialized = true
        end
    end
end
Event.InventoryAdded.Subscribe("LootInvOpened", lootINV)

local function shouldShowAreaLoot()
    if not initialized then
        return
    end
    if not doubleinit then -- this function will return the next tick after initialized is set to true
        loot_all_pos_x = loot_all_component.x
        loot_all_pos_y = loot_all_component.y
        loot_custom_pos_x = loot_custom_component.x
        loot_custom_pos_y = loot_custom_component.y
        doubleinit = true
    end
    local shouldShow = not shouldConsumeAreaLoot()
    if isShowing then
        if shouldShow then
            
        else
            -- this hides the components, which also makes it so that the user cannot click on them or
            -- use the keyboard to activate the area loot button
            loot_all_component:SetPos(loot_all_component.position.x + 100, loot_all_component.position.y + 100)
            loot_custom_component:SetPos(loot_custom_component.position.x + 100, loot_custom_component.position.y + 100)
            isShowing = false
        end
    else
        if shouldShow then
            loot_all_component:SetPos(loot_all_pos_x, loot_all_pos_y)
            loot_custom_component:SetPos(loot_custom_pos_x, loot_custom_pos_y)
            isShowing = true
        end
    end
end
Event.ServerLogic.Subscribe("shouldShowAreaLoot", shouldShowAreaLoot)

local function addAllItemsFromTheBank(event)
    local bankconfig = event.inv
    local count = 0
    local bank = Inventory.Find(bankconfig)
    if not bank.isValid then
        return
    end
    local slots = bank:GetSlots()
    for _, slot in ipairs(slots) do
        local id = slot.obj.id
        if id ~= -1 then
            local object = slot.obj
            if object ~= nil and object.isStockmarket then
                if setOfItemsAcquired[id] == nil then
                    count = count + 1
                    setOfItemsAcquired[id] = slot.obj.name
                end
            end
        end
    end
    if count == 0 then
        return
    end
    PersistentDB:Set("acquiredItems",setOfItemsAcquired)
    UI:rebuildFromSetOfAcquiredItems(setOfItemsAcquired)
    local text = string.format("%d new items added", count)
    if count == 1 then
        text = string.format("%d new item added", count)
    end
    local collectionPopupItem = {
        title = "Bronzeman log",
        text = text,
        item = config.Obj.FromID(id.Obj.BANK_TUTOR_ICON_DUMMY),
        y = 50,
    }
    collectionPopupQueue:enqueue(collectionPopupItem)
end

local function inventoryAddedSwitch(event)
    local config = event.inv
    if config.id == id.Inv.BANK then
        addAllItemsFromTheBank(event)
    end
end

Event.InventoryAdded.Subscribe("inventoryAddedSwitch", inventoryAddedSwitch)

local function addAllItemsNewInTheInventory(event)
    local invconfig = event.inv
    local inv = Inventory.Find(invconfig)
    if not inv.isValid then
        return
    end
    local slots = {}
    for _, slotid in ipairs(event.slotsUpdated) do
        table.insert(slots, inv:GetSlot(slotid))
    end
    for _, slot in ipairs(slots) do
        local id = slot.obj.id
        if id ~= -1 then
            addToAcquired(id, slot.obj, standardPopup(slot.obj))
        end
    end
end

local function inventoryUpdatedSwitch(event)
    local config = event.inv
    if config.id == id.Inv.INV then
        addAllItemsNewInTheInventory(event)
    end
end

Event.InventoryUpdated.Subscribe("inventoryUpdatedSwitch", inventoryUpdatedSwitch)

function PluginShutdown()
    if loot_all_component == nil then
        return
    end
    if loot_custom_component == nil then
        return
    end
    loot_all_component:SetPos(loot_all_pos_x, loot_all_pos_y)
    loot_custom_component:SetPos(loot_custom_pos_x, loot_custom_pos_y)
end

local function printAllChildrens(input, static, level)
    if static then
        input:IterateStaticComponents(
            function (component, visible)
                log(string.format("Found static component with id: %d type: %d at level: %d, visibility: %s", component.staticID, component.type, level, tostring(visible)))
                if component.type == 20 then
                    printAllChildrens(component, true, level+1)
                    printAllChildrens(component, false, level+1)
                end
            return false
            end)
    else 
        input:IterateDynamicComponents(
            function (component, visible)
                log(string.format("Found dynamic component with id: %d type: %d at level: %d, visibility: %s", component.dynamicID, component.type, level, tostring(visible)))
            return false
            end)
    end
end