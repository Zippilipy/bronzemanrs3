-- establish important global variables
-- game window, is the game window
ExecuteConsoleCommand("ppr bronzeman")
ExecuteConsoleCommand("ppe bronzeman trackingAccess")
local game_window = ui.Interfaces:GetComponent(id.Component.TOPLEVEL_V2__PLUGIN_BUILD_LAYER_TOP)
-- setOfItemsAcquired is a table mapping ids to <name> or nil, <name> means you have acquired said item, nil means you haven't
-- for a more in depth description of setOfItemsAcquired, see handlepotions.lua
local setOfAllItems = {}
local canPickUpTheseItems = {}
local Queue = require("queue")
local UI = require("ui")
local selectedid = -1

local potionHandler = require("handlepotions")
local handlePotions = potionHandler.handlePotions

-- add all tradeable items and tradeable potiondoses (see handlepotions.lua) to setOfAllItems
do
    local nilcounter = 0
    local i = 0
    while true do
        local object = config.Obj.FromID(i)
        if object == nil then
            nilcounter = nilcounter + 1
            if nilcounter > 100 then
                break
            end
            goto continue
        end
        do
            nilcounter = 0
            local potionStruct = object:HasParam(config.Param.POTION_STRUCT) and object:GetParamValue(config.Param.POTION_STRUCT) or nil -- if the potion has the param, use it. otherwise make nil as not valid.
            if potionStruct then
                handlePotions(potionStruct, setOfAllItems)
            elseif object.isStockmarket and setOfAllItems[i] == nil then
                setOfAllItems[i] = object.name
            end
        end
        ::continue::
        i = i + 1
    end
end

local setOfItemsAcquired = nil
local acquiredItemsIDName = nil
local playerTrackingID = nil
local UIHasLoaded = false
if Plugin.HasPermission(PluginPermissions.trackingAccess) then
    playerTrackingID = Player.GetTrackingID()
end
-- this function tries to obtain playertrackingid every tick until it finds it
local function obtainPlayerTrackingID()
    if Plugin.HasPermission(PluginPermissions.trackingAccess) then
        playerTrackingID = Player.GetTrackingID()
        if playerTrackingID ~= nil then
            acquiredItemsIDName = tostring(playerTrackingID) .. "acquiredItems"
            setOfItemsAcquired = PersistentDB:Get(acquiredItemsIDName)
            if setOfItemsAcquired == nil then
                log("Persistent DB for setOfItemsAcquired was nil!")
                setOfItemsAcquired = {}
                setOfItemsAcquired[id.Obj.RS_BOND] = config.Obj.RS_BOND.name
                PersistentDB:Set(acquiredItemsIDName,setOfItemsAcquired)
            end
            Event.ServerLogic.Unsubscribe("obtainPlayerTrackingID")
        end
    end
end
if playerTrackingID == nil then
    Event.ServerLogic.Subscribe("obtainPlayerTrackingID", obtainPlayerTrackingID)
else
    acquiredItemsIDName = tostring(playerTrackingID) .. "acquiredItems"
    setOfItemsAcquired = PersistentDB:Get(acquiredItemsIDName)
    if setOfItemsAcquired == nil then
        log("Persistent DB for setOfItemsAcquired was nil!")
        setOfItemsAcquired = {}
        setOfItemsAcquired[id.Obj.RS_BOND] = config.Obj.RS_BOND.name
        PersistentDB:Set(acquiredItemsIDName,setOfItemsAcquired)
    end
end

local function removeSetOfItemsAcquired()
    if acquiredItemsIDName ~= nil then
        PersistentDB:Delete(acquiredItemsIDName)
    end
end

local function onSettingsLayerReady(event) 
    local root_layer = event.component
    if setOfItemsAcquired == nil then
        return
    end
    if not UIHasLoaded then
        UI.load(game_window, root_layer, setOfItemsAcquired, setOfAllItems, removeSetOfItemsAcquired)
        UIHasLoaded = true
    else
        UI:OpenWindow(root_layer)
    end
end

Event.SettingsLayerReady.Subscribe("onSettingsLayerReady", onSettingsLayerReady)

-- counterForCollectionPopup has a value [0..4] and will show the achievement popup at value 0, then increment by one
-- for each server tick, essentially making the collection log popup every 5 ticks.
local counterForCollectionPopup = 0

-- collectionPopupQueue is a queue for the achievement popup, making it go every 5 ticks with counterForCollectionPopup
local collectionPopupQueue = Queue.new()

local function addToAcquired(id, object, collectionPopupItem)
    if setOfItemsAcquired == nil then
        return
    end
    if object == nil then
        return
    end
    if setOfItemsAcquired[id] ~= nil then
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
        if UIHasLoaded then
            UI:rebuildFromSetOfAcquiredItems(setOfItemsAcquired)
        end
        return
    end
    if not object.isStockmarket then
        return
    end
    setOfItemsAcquired[id] = object.name
    if collectionPopupItem ~= nil then
        collectionPopupQueue:enqueue(collectionPopupItem)
    end
    PersistentDB:Set(acquiredItemsIDName, setOfItemsAcquired)
    if UIHasLoaded then
        UI:rebuildFromSetOfAcquiredItems(setOfItemsAcquired)
    end
end

local isShowingAreaLoot = false

-- find all items in a 7 tile range for area loot
-- returns a list of item ids, the same type of ids stored in setOfItemsAcquired
local function findAllNearbyItemIds()
    local nearbyItemIds = {}
    local player = Player.GetEntity()
    if player == nil then 
        return nearbyItemIds
    end
    local coordGrid = player.coordGrid
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
    if setOfItemsAcquired == nil then
        return
    end
    -- this dung check is not needed when they fix isOwner
    if var.VarClient.RAND_PARTY_FLOOR.value > 0 then
        return false
    end
    local nearbyItemIds = findAllNearbyItemIds()
    for _,id in ipairs(nearbyItemIds) do
        local object = config.Obj.FromID(id)
        if canPickUpTheseItems[id] == nil and string.sub(object.configName, 1, 4) ~= "RAND" then
            return true
        end
    end
    return false
end

local geOpConfig = nil
function miniMenuReadyFunc(event)
    if setOfItemsAcquired == nil then
        return
    end
    if var.VarClient.RAND_PARTY_FLOOR.value > 0 then
        return
    end
    local entries = event.miniMenu.entries
    if entries == nil then
        return
    end
    local idxA = 0
    local idxB = 0
    for i, entry in pairs(entries) do
        if entry.actionEntryType == MiniMenuEntryType.INTERFACE or entry.actionEntryType == MiniMenuEntryType.NONE then
            if selectedid ~= -1 then -- DISABLE GE
                if setOfItemsAcquired[selectedid] == nil then
                    local componentData = entry.componentData
                    if not componentData or not componentData.component then 
                        goto continue
                    end
                    for opIndex = 0, 9 do 
                        if componentData.component.opConfig:GetOpName(opIndex) == "Confirm" then
                            geOpConfig = componentData.component.opConfig
                            geOpConfig:SetOpIDHidden(opIndex, true)
                        end
                    end
                else
                    local componentData = entry.componentData
                    if componentData and componentData.component then
                        geOpConfig = componentData.component.opConfig
                    end
                    if geOpConfig == nil then
                        goto continue
                    end
                    for opIndex = 0, 9 do
                        if geOpConfig:GetOpName(opIndex) == "Confirm" then
                            geOpConfig:SetOpIDHidden(opIndex, false)
                        end
                    end
                end
            else
                if entry.actionEntryType == MiniMenuEntryType.INTERFACE then
                    -- AREA LOOT
                    if not isShowingAreaLoot then
                        goto continue
                    end
                    local object = entry.componentData.objConfig
                    if object == nil then
                        goto continue
                    end
                    if string.sub(object.configName, 1, 4) == "RAND" then
                        goto continue
                    end
                    if canPickUpTheseItems[object.id] == nil then
                        if entry.actionVerbType == MiniMenuActionVerbType.OP then
                            local componentData = entry.componentData
                            if not componentData or not componentData.component then
                                goto continue
                            end
                            for opIndex = 0, 9 do
                                local arealootOpConfig = componentData.component.opConfig
                                if string.sub(arealootOpConfig:GetOpName(opIndex), 1, 4) == "Take" then
                                    arealootOpConfig:SetOpIDHidden(opIndex, true)
                                end
                            end
                        end
                    end
                end
            end
        else -- ITEMS ON THE GROUND
            if entry.actionEntryType ~= MiniMenuEntryType.OBJ then
                goto continue
            end
            local object = entry.objData.config
            if string.sub(object.configName, 1, 4) == "RAND" then
                goto continue
            end
            if canPickUpTheseItems[object.id] == nil then
                -- SetOpIDHidden isn't possible since this entry doesn't have an associated componentData
                -- So we use :Swap()
                if entry.actionVerbType == MiniMenuActionVerbType.OP then
                    idxA = i
                elseif entry.actionVerbType == MiniMenuActionVerbType.EXAMINE then
                    idxB = i
                end
            end
        end
        ::continue::
    end
    event.miniMenu:Swap(idxA, idxB)
end
Event.MiniMenuReady.Subscribe("myEvent", miniMenuReadyFunc)

local function addToItemAcquiredFromDrop(event)
    log(string.format("Saw %s drop, event.isOwner = %s", event.objType.name, tostring(event.isOwner)))
    if event.isOwner then
        canPickUpTheseItems[event.objType.id] = event.objType
    end
end
Event.ObjStackEntityAdded.Subscribe("dropEvent", addToItemAcquiredFromDrop)
local function addToItemAcquiredFromDropChanged(event)
    log(string.format("Saw %s drop, event.isOwner = %s", event.objType.name, tostring(event.isOwner)))
    if not event.isOwner then
        return
    end
    if event.oldCount > event.newCount then
        return
    end
    canPickUpTheseItems[event.objType.id] = event.objType
end
Event.ObjStackEntityChanged.Subscribe("dropEvent", addToItemAcquiredFromDropChanged)

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

Event.Logic.Subscribe("initializeComponents", initializeComponents)

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
    if var.VarClient.RAND_PARTY_FLOOR.value > 0 then
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
    if setOfItemsAcquired == nil then
        return
    end
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
                elseif not object.isStockmarket then
                    local weaponStruct = object:HasParam(config.Param.INVENT_BASE_OBJECT) and object:GetParamValue(config.Param.INVENT_BASE_OBJECT) or nil
                    if weaponStruct ~= nil then
                        local weaponNew = weaponStruct:HasParam(config.Param.COMBATV2_SPECIAL_ATTACK_BASE_ITEM) and weaponStruct:GetParamValue(config.Param.COMBATV2_SPECIAL_ATTACK_BASE_ITEM) or nil
                        if weaponNew ~= nil then
                            if weaponNew.isStockmarket then
                                if setOfItemsAcquired[weaponNew.id] ~= nil then
                                    count = count + 1
                                    setOfItemsAcquired[weaponNew.id] = weaponNew.name
                                end
                            end
                        end
                    end
                elseif not object.isStockmarket then
                    setOfItemsAcquired[id] = ""
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
    PersistentDB:Set(acquiredItemsIDName, setOfItemsAcquired)
    if UIHasLoaded then
        UI:rebuildFromSetOfAcquiredItems(setOfItemsAcquired)
    end
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

local tradeMenuIsOpen = ui.Interfaces:GetComponent(id.Component.TRADEMAIN__OTHER_OFFER_LAYER) ~= nil

local function inventoryAddedSwitch(event)
    local config = event.inv
    if config.id == id.Inv.BANK then
        addAllItemsFromTheBank(event)
    elseif config.id == id.Inv.TRADEOFFER then
        initializeAcceptButton = true
        tradeMenuIsOpen = true
    end
end

Event.InventoryAdded.Subscribe("inventoryAddedSwitch", inventoryAddedSwitch)

local function inventoryRemovedEvent(event)
    local config = event.inv
    if config.id == id.Inv.TRADEOFFER then
        tradeMenuIsOpen = false
    end
end

Event.InventoryRemoved.Subscribe("inventoryRemovedEvent", inventoryRemovedEvent)

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

local function addAllItemsInTheInventory()
    if setOfItemsAcquired == nil then
        return
    end
    local inv = Inventory.Find(config.Inv.INV)
    if not inv.isValid then
        return
    end
    local slots = inv:GetSlots()
    local count = 0
    local sizeOfAcquired = 0
    for _ in pairs(setOfItemsAcquired) do
        sizeOfAcquired = sizeOfAcquired + 1
    end
    for _, slot in ipairs(slots) do
        local id = slot.obj.id
        if id ~= -1 then
            addToAcquired(id, slot.obj, nil)
            local newSizeOfAcquired = 0
            for _ in pairs(setOfItemsAcquired) do
                newSizeOfAcquired = newSizeOfAcquired + 1
            end
            if newSizeOfAcquired > sizeOfAcquired then
                sizeOfAcquired = newSizeOfAcquired
                count = count + 1
            end
        end
    end
    if count == 0 then
        Event.ServerLogic.Unsubscribe("addAllItemsInTheInventory")
        return
    end
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
    Event.ServerLogic.Unsubscribe("addAllItemsInTheInventory")
end

Event.ServerLogic.Subscribe("addAllItemsInTheInventory", addAllItemsInTheInventory)

local function disableAcceptIfNotBond(event)
    if not tradeMenuIsOpen then
        return
    end
    local trade_offer_layer_other = ui.Interfaces:GetComponent(id.Component.TRADEMAIN__OTHER_OFFER_LAYER)
    local should_block = false
    trade_offer_layer_other:IterateDynamicComponents(
        function (component, visible)
            if component.type == ui.ComponentType.SPRITE then
                local objid = component.associatedObjectID
                if objid ~= -1 then
                    if objid ~= id.Obj.REDBERRIES then
                        if not should_block then
                            accept_button:SetPos(accept_button.position.x + 500, accept_button.position.y + 500)
                        end
                        should_block = true
                    else
                    end
                end
            end
        return false
    end)
    local trade_offer_layer_your = ui.Interfaces:GetComponent(id.Component.TRADEMAIN__YOUR_OFFER_LAYER)
    trade_offer_layer_your:IterateDynamicComponents(
        function (component, visible)
            if component.type == ui.ComponentType.SPRITE then
                local objid = component.associatedObjectID
                if objid ~= -1 then
                    if not should_block then
                        accept_button:SetPos(accept_button.position.x + 500, accept_button.position.y + 500)
                    end
                    should_block = true
                end
            end
        return false
    end)
    if not should_block then
        accept_button:SetPos(accept_button_x, accept_button_y)
    end
end

Event.ServerLogic.Subscribe("disableAcceptIfNotBond", disableAcceptIfNotBond)

local function inventoryUpdatedSwitch(event)
    if var.VarClient.RAND_PARTY_FLOOR.value > 0 then
        return
    end
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
            return false
            end)
    end
end

local function printAllChildren(input)
    printAllChildrens(input, true, 0)
    printAllChildrens(input, false, 0)
end

local function disableConfirmButton()
    if var.VarClient.TOPLEVEL_V2_OPEN_PARENT_REQUEST.value ~= 5 then
        return
    end
    local itemCurrentlyBeingSelected = ui.Interfaces:GetComponent(id.Component.STOCKMARKET__ITEM_AND_PRICE)
    if itemCurrentlyBeingSelected == nil then
        return
    else
        itemCurrentlyBeingSelected = itemCurrentlyBeingSelected:GetChild(154)
    end
    selectedid = itemCurrentlyBeingSelected.associatedObjectID
end

Event.Logic.Subscribe("disableConfirmButton", disableConfirmButton)

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
    UI:resetIconStuff()
    if UIHasLoaded then
        UI:destroyUIStuff()
    end
end