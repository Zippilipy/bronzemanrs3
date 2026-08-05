-- establish important global variables
-- game window, is the game window
game_window = ui.Interfaces:GetComponent(id.Component.TOPLEVEL_V2__PLUGIN_BUILD_LAYER_TOP)
-- setOfItemsAcquired is a table mapping ids to true or nil, true means you have acquired said item, nil means you haven't
local setOfItemsAcquired = PersistentDB:Get("acquiredItems")
if setOfItemsAcquired==nil then
    log("Persistent DB was nil!")
    setOfItemsAcquired = {}
    setOfItemsAcquired[995] = true -- manually add coins to list
    setOfItemsAcquired[15272] = true -- manually add rocktail to list
    PersistentDB:Set("acquiredItems",setOfItemsAcquired)
end
local function addToAcquired(id, name, objType)
    if setOfItemsAcquired[id] == nil then
        setOfItemsAcquired[id] = true
        log(string.format("%s added to obtained items!", name))
        local popup = prettyui.AchievementPopup.show({
            title = "Bronzeman log",
            text = string.format("New item obtained: %s", name),
            item = objType,
            y = 50
        })
        PersistentDB:Set("acquiredItems",setOfItemsAcquired)
    end
end
local function hasAcquired(id)
    return setOfItemsAcquired[id] ~= nil
end
-- isRed is a boolean value that says whether it's red or not, this allows an early return on onMouseRepeat
local isRed = false
-- Create a new box for components
local myComponent = ui.GroupBox.new(game_window)
local thing_to_be_disabled = ui.Interfaces:GetComponent(id.Component.TOPLEVEL_V2__LOOT_INVENTORY_WINDOW) -- TOPLEVEL_V2__LOOT_INVENTORY_WINDOW
-- rectangle to block interaction
local blocking_rectangle = ui.Rectangle.new(game_window)
blocking_rectangle:SetPos(thing_to_be_disabled.position.x,thing_to_be_disabled.position.y)
blocking_rectangle:SetSize(thing_to_be_disabled.size.width,thing_to_be_disabled.size.height)
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
    local allObjects = ObjStackList.ByDistance(coordGrid, 7) -- area loot is 7 tiles
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
local function setTextBasedOnAreaLoot()
    -- I thought about doing an early return, based on if the player has moved and whether ObjStackEntityAdded
    -- event triggers but I'm not even sure it would be faster if the player moves a lot
    -- Certainly if the player is tanking afk a lot, but if so, I don't think the performance is an issue
    local shouldConsume = shouldConsumeAreaLoot()
    local text = "You are eligible to area loot"
    if shouldConsume then
        text = "You are NOT eligible to area loot"
    end
end
Event.ServerLogic.Subscribe("setTextBasedOnAreaLootEvent", setTextBasedOnAreaLoot)
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
local function consumeIfNotObtainedLootOnGround(event)
    local obj = event.entry.objData
    if (obj == nil) then
        return
    end
    local id = obj.config.id
    if not hasAcquired(id) then
        log("Consumed!")
    end
end
Event.MiniMenuEntrySelected.Subscribe("minimenuEvent", consumeIfNotObtainedLootOnGround)
local function addToItemAcquiredFromDrop(event)
    addToAcquired(event.objType.id, event.objType.name, event.objType)
end
Event.ObjStackEntityAdded.Subscribe("dropEvent", addToItemAcquiredFromDrop)