local Queue = require("queue")
local UI = require("ui")
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

UI.load(game_window, setOfItemsAcquired)

-- counterForCollectionPopup has a value [0..4] and will show the achievement popup at value 0, then increment by one
-- for each server tick, essentially making the collection log popup every 5 ticks.
local counterForCollectionPopup = 0

-- collectionPopupQueue is a queue for the achievement popup, making it go every 5 ticks with counterForCollectionPopup
local collectionPopupQueue = Queue.new()

-- counterForItemSlot has a value [0..7] which will make it so the bronzeman collection log displays 8 items in a row
-- then switches to a new row
local counterForItemSlot = 0

local function addToAcquired(id, name, objType)
    if setOfItemsAcquired[id] == nil then
        setOfItemsAcquired[id] = true
        log(string.format("%s added to obtained items!", name))
        local collectionPopupItem = {
            title = "Bronzeman log",
            text = string.format("New item obtained: %s", name),
            item = objType,
            y = 50,
        }
        collectionPopupQueue:enqueue(collectionPopupItem)
        PersistentDB:Set("acquiredItems",setOfItemsAcquired)
        local object = config.Obj.FromID(id)
        UI.addItemSlot(object)
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

-- Right now does nothing, but if I can consume events then this will consume any attempt to click 'loot'
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

-- addToItemAcquiredFromDrop and addToItemAcquiredFromDropChanged both add from items on the ground
-- I need a way to check ownership of the drop, right now it just counts anything on the ground
local function addToItemAcquiredFromDrop(event)
    addToAcquired(event.objType.id, event.objType.name, event.objType)
end
Event.ObjStackEntityAdded.Subscribe("dropEvent", addToItemAcquiredFromDrop)
local function addToItemAcquiredFromDropChanged(event)
    if event.oldCount > event.newCount then
        return
    end
    addToAcquired(event.objType.id, event.objType.name, event.objType)
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