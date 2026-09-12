local Queue = require("queue")
local UI = require("ui")
-- establish important global variables
-- game window, is the game window
local game_window = ui.Interfaces:GetComponent(id.Component.TOPLEVEL_V2__PLUGIN_BUILD_LAYER_TOP)
-- setOfItemsAcquired is a table mapping ids to true or nil, true means you have acquired said item, nil means you haven't
local setOfAllItems = {}
local setOfItemsAcquired = PersistentDB:Get("acquiredItems")

if setOfItemsAcquired == nil then
    log("Persistent DB for setOfItemsAcquired was nil!")
    setOfItemsAcquired = {}
    setOfItemsAcquired[id.Obj.RS_BOND] = config.Obj.RS_BOND.name
    PersistentDB:Set("acquiredItems",setOfItemsAcquired)
end

local potionHandler = require("handlepotions")
local handlePotions = potionHandler.handlePotions

-- add all stockmarket items and stockmarket potiondoses (see handlepotions.lua) to setOfAllItems
for i=1,70000,1 do
    local object = config.Obj.FromID(i)
    if object == nil then
        goto continue
    end
    local potionStruct = object:HasParam(config.Param.POTION_STRUCT) and object:GetParamValue(config.Param.POTION_STRUCT) or nil -- if the potion has the param, use it. otherwise make nil as not valid.
    if potionStruct then
        handlePotions(potionStruct, setOfAllItems)
    elseif object.isTradeable and setOfAllItems[i] == nil then
        setOfAllItems[i] = object.name
    end
    ::continue::
end

UI.load(game_window, setOfItemsAcquired, setOfAllItems)


-- counterForCollectionPopup has a value [0..4] and will show the achievement popup at value 0, then increment by one
-- for each server tick, essentially making the collection log popup every 5 ticks.
local counterForCollectionPopup = 0

-- collectionPopupQueue is a queue for the achievement popup, making it go every 5 ticks with counterForCollectionPopup
local collectionPopupQueue = Queue.new()

local function addToAcquired(id, object, collectionPopupItem)
    if object == nil then
        return
    end
    local potionStruct = object:HasParam(config.Param.POTION_STRUCT) and object:GetParamValue(config.Param.POTION_STRUCT) or nil -- if the potion has the param, use it. otherwise make nil as not valid.
    if potionStruct then
        local potion = handlePotions(potionStruct, setOfItemsAcquired)
        if potion.isNewAddition then
        local collectionPopup = potion.collectionPopupItem
            if collectionPopupItem ~= nil then
                collectionPopupQueue:enqueue(collectionPopup)
            end
        end
        UI:rebuildFromSetOfAcquiredItems(setOfItemsAcquired)
        return
    end
    if not object.isTradeable then
        return
    end
    if setOfItemsAcquired[id] ~= nil then
        return
    end
    setOfItemsAcquired[id] = object.name
    if collectionPopupItem ~= nil then
        collectionPopupQueue:enqueue(collectionPopupItem)
    end
    PersistentDB:Set("acquiredItems",setOfItemsAcquired)
    UI:rebuildFromSetOfAcquiredItems(setOfItemsAcquired)
end

-- isRed is a boolean value that says whether it's red or not, this allows an early return on onMouseRepeat
local isRed = false
local isShowingAreaLoot = false

local loot_inventory = ui.Interfaces:GetComponent(id.Component.TOPLEVEL_V2__LOOT_INVENTORY_WINDOW)
local blocking_rectangle = ui.Rectangle.new(game_window)
blocking_rectangle:SetPos(loot_inventory.position.x,loot_inventory.position.y)
blocking_rectangle:SetSize(loot_inventory.size.width,loot_inventory.size.height)
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
        local acquired = setOfItemsAcquired[id] ~= nil
        if not acquired and config.Obj.FromID(id).isTradeable then
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
        if shouldConsumeAreaLoot() and isShowingAreaLoot then
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
        if setOfItemsAcquired[object.id] == nil then
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
local isShowingLootButton = true -- useful to prevent unnecessary actions
local loot_all_component
local loot_custom_component
-- loot component is useful because if the player closes the menu and opens it again, that is a new component, 
-- so we can do a check if the new is the same as the old

local loot_all_pos_x
local loot_all_pos_y

local loot_custom_pos_x
local loot_custom_pos_y

local initialized = false

local accept_button = ui.Interfaces:GetComponent(id.Component.TRADEMAIN__ACCEPT_BUTTON_LAYER)
local accept_button_x = 0
local accept_button_y = 0
if accept_button ~= nil then
    accept_button_x = accept_button.x
    accept_button_y = accept_button.y
    accept_button:SetPos(accept_button.position.x + 500, accept_button.position.y + 500)
end

local initializeLootButtons = false
local initializeAcceptButton = false
local function initializeComponents()
    if initializeAcceptButton then
        accept_button = ui.Interfaces:GetComponent(id.Component.TRADEMAIN__ACCEPT_BUTTON_LAYER)
        accept_button_x = accept_button.x
        accept_button_y = accept_button.y
        initializeAcceptButton = false
    end
    if initializeLootButtons then
        loot_all_component = ui.Interfaces:GetComponent(id.Component.TOPLEVEL_V2_LOOT__LOOT_ALL_BUTTON_LAYER)
        loot_custom_component = ui.Interfaces:GetComponent(id.Component.TOPLEVEL_V2_LOOT__LOOT_CUSTOM_BUTTON_LAYER)
        loot_all_pos_x = loot_all_component.x
        loot_all_pos_y = loot_all_component.y
        loot_custom_pos_x = loot_custom_component.x
        loot_custom_pos_y = loot_custom_component.y
        initializeLootButtons = false
        initialized = true
        isShowingLootButton = true
    end
end

Event.ServerLogic.Subscribe("initializeComponents", initializeComponents)

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
    initializeLootButtons = true
    isShowingAreaLoot = true
end

local function lootInvOpened(event)
    if event.inv.id == id.Inv.LOOT then
        initialized = false
        initializeLootButtons = true
        isShowingAreaLoot = true
    end
end
Event.InventoryAdded.Subscribe("lootInvOpened", lootInvOpened)

local function lootInvClosed(event)
    if event.inv.id == id.Inv.LOOT then
        isShowingAreaLoot = false
    end
end
Event.InventoryRemoved.Subscribe("lootInvClosed", lootInvClosed)

local function shouldShowAreaLoot()
    if not initialized then
        return
    end
    if not isShowingAreaLoot then
        return
    end
    local shouldShow = not shouldConsumeAreaLoot()
    if isShowingLootButton then
        if shouldShow then
            
        else
            -- this hides the components, which also makes it so that the user cannot click on them or
            -- use the keyboard to activate the area loot button
            loot_all_component:SetPos(loot_all_component.position.x + 100, loot_all_component.position.y + 100)
            loot_custom_component:SetPos(loot_custom_component.position.x + 100, loot_custom_component.position.y + 100)
            isShowingLootButton = false
        end
    else
        if shouldShow then
            loot_all_component:SetPos(loot_all_pos_x, loot_all_pos_y)
            loot_custom_component:SetPos(loot_custom_pos_x, loot_custom_pos_y)
            isShowingLootButton = true
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
            if object ~= nil then
                if setOfItemsAcquired[id] ~= nil then
                    goto continue
                end
                local potionStruct = object:HasParam(config.Param.POTION_STRUCT) and object:GetParamValue(config.Param.POTION_STRUCT) or nil -- if the potion has the param, use it. otherwise make nil as not valid.
                if potionStruct then
                    if handlePotions(potionStruct, setOfItemsAcquired).isNewAddition then
                        count = count + 1
                    end
                elseif not object.isTradeable then
                    local weaponStruct = object:HasParam(config.Param.INVENT_BASE_OBJECT) and object:GetParamValue(config.Param.INVENT_BASE_OBJECT) or nil
                    if weaponStruct ~= nil then
                        local weaponNew = weaponStruct:HasParam(config.Param.COMBATV2_SPECIAL_ATTACK_BASE_ITEM) and weaponStruct:GetParamValue(config.Param.COMBATV2_SPECIAL_ATTACK_BASE_ITEM) or nil
                        if weaponNew ~= nil then
                            if weaponNew.isTradeable then
                                if setOfItemsAcquired[weaponNew.id] ~= nil then
                                    count = count + 1
                                    setOfItemsAcquired[weaponNew.id] = weaponNew.name
                                end
                            end
                        end
                    end
                else
                    count = count + 1
                    setOfItemsAcquired[id] = slot.obj.name
                    -- don't use addToAcquired because that many function calls make this way too slow
                end
            end
        end
    ::continue::
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
        item = config.Obj.BANK_TUTOR_ICON_DUMMY,
        y = 50,
    }
    collectionPopupQueue:enqueue(collectionPopupItem)
end

local function inventoryAddedSwitch(event)
    local config = event.inv
    if config.id == id.Inv.BANK then
        addAllItemsFromTheBank(event)
    elseif config.id == id.Inv.TRADEOFFER then
        initializeAcceptButton = true
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
            local collectionPopupItem = {
                title = "Bronzeman log",
                text = string.format("New item obtained: %s", slot.obj.name),
                item = slot.obj,
                y = 50,
            }
            addToAcquired(id, slot.obj, collectionPopupItem)
        end
    end
end

local function disableAcceptIfNotBond(event)
    local tradeconfig = event.inv
    local trade = Inventory.Find(tradeconfig)
    if not trade.isValid then
        return
    end
    for _, slot in ipairs(trade:GetSlots()) do
        local itemId = slot.obj.id
        if itemId ~= -1 and itemId ~= id.Obj.REDBERRIES then
            accept_button:SetPos(accept_button.position.x + 500, accept_button.position.y + 500)
            return
        end
    end
    accept_button:SetPos(accept_button_x, accept_button_y)
end

local function inventoryUpdatedSwitch(event)
    local config = event.inv
    if config.id == id.Inv.INV then
        addAllItemsNewInTheInventory(event)
    elseif config.id == id.Inv.TRADEOFFER then
        disableAcceptIfNotBond(event)
    end
end

Event.InventoryUpdated.Subscribe("inventoryUpdatedSwitch", inventoryUpdatedSwitch)

local function printAllChildrens(input, static, level)
    if static then
        input:IterateStaticComponents(
            function (component, visible)
                log(string.format("Found static component with id: %d type: %d at level: %d, visibility: %s", component.staticID, component.type, level, tostring(visible)))
                if component.type == ui.ComponentType.SPRITE then
                    local id = component.associatedObjectID
                    if id ~= -1 then
                        if setOfItemsAcquired[id] ~= nil then
                            log(string.format("You are allowed to buy %s", config.Obj.FromID(id).name))
                        else
                            log(string.format("You are NOT allowed to buy %s", config.Obj.FromID(id).name))
                        end
                    end
                end
                if component.type == ui.ComponentType.LAYER then
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

local confirm_button_initialized = false
local confirm_button_visible = true
local confirm_button_click
local confirm_button_build
local confirm_button_click_x
local confirm_button_click_y
local confirm_button_build_x
local confirm_button_build_y

local function disableConfirmButton()
    local itemCurrentlyBeingSelected = ui.Interfaces:GetComponent(id.Component.STOCKMARKET__ITEM_AND_PRICE)
    if itemCurrentlyBeingSelected == nil then
        return
    else
        itemCurrentlyBeingSelected = itemCurrentlyBeingSelected:GetChild(227)
    end
    local selectedid = itemCurrentlyBeingSelected.associatedObjectID
    if selectedid ~= -1 then
        if not confirm_button_initialized then
            confirm_button_click = ui.Interfaces:GetComponent(id.Component.STOCKMARKET__MAKEOFFERBUTTON_CLICK)
            confirm_button_build = ui.Interfaces:GetComponent(id.Component.STOCKMARKET__MAKEOFFERBUTTON_BUILD)
            confirm_button_click_x = confirm_button_click.position.x
            confirm_button_click_y = confirm_button_click.position.y
            confirm_button_build_x = confirm_button_build.position.x
            confirm_button_build_y = confirm_button_build.position.y
            confirm_button_initialized = true
        end
        if setOfItemsAcquired[selectedid] ~= nil then
            if not confirm_button_visible and confirm_button_initialized then
                confirm_button_click:SetPos(confirm_button_click_x, confirm_button_click_y)
                confirm_button_build:SetPos(confirm_button_build_x, confirm_button_build_y)
                confirm_button_visible = true
            end
        else
            if confirm_button_visible and confirm_button_initialized then
                confirm_button_click:SetPos(confirm_button_click.position.x + 500, confirm_button_click.position.y + 500)
                confirm_button_build:SetPos(confirm_button_build.position.x + 500, confirm_button_build.position.y + 500)
                confirm_button_visible = false
            end
        end
    else
        if not confirm_button_visible and confirm_button_initialized then
            confirm_button_click:SetPos(confirm_button_click_x, confirm_button_click_y)
            confirm_button_click:SetPos(confirm_button_build_x, confirm_button_build_y)
            confirm_button_visible = true
        end
    end
end

Event.ServerLogic.Subscribe("disableConfirmButton", disableConfirmButton)

function PluginShutdown()
    if loot_all_component ~= nil then
        loot_all_component:SetPos(loot_all_pos_x, loot_all_pos_y)
    end
    if loot_custom_component ~= nil then
        loot_custom_component:SetPos(loot_custom_pos_x, loot_custom_pos_y)
    end
    if accept_button ~= nil then
        accept_button:SetPos(accept_button_x, accept_button_y)
    end
    if confirm_button_click ~= nil then
        confirm_button_click:SetPos(confirm_button_click_x, confirm_button_click_y)
    end
    if confirm_button_build ~= nil then
        confirm_button_build:SetPos(confirm_button_build_x, confirm_button_build_y)
    end
    UI:resetIconStuff()
end