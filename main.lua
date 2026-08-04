-- establish important global variables
-- game window, is the game window
-- setOfItemsAcquired is a table mapping ids to true or nil, true means you have acquired said item, nil means you haven't
game_window = ui.Interfaces:GetComponent(id.Component.TOPLEVEL_V2__PLUGIN_BUILD_LAYER_TOP)
local setOfItemsAcquired = PersistentDB:Get("acquiredItems")
if setOfItemsAcquired==nil then
    log("Persistent DB was nil!")
    setOfItemsAcquired = {}
    setOfItemsAcquired[995] = true -- manually add coins to list
    setOfItemsAcquired[15272] = true -- manually add rocktail to list
    PersistentDB:Set("acquiredItems",setOfItemsAcquired)
end
local function hasAcquired(id)
    return setOfItemsAcquired[id] ~= nil
end
-- Create a new box for components
local myComponent = ui.GroupBox.new(game_window)
myComponent:SetPos(100,200)
myComponent:SetSize(250,200)
myComponent.stylesheetID = id.StyleSheet.GROUPBOX_CONTENT_PANEL
-- Add some text
local myText = ui.Text.new(myComponent)
myText:SetPos(0,0)
myText:SetSize(0,0,1.0,0.5)
myText.content = "Hello world!"
myText.font = id.Font.MUSEO_SANS_15PT_REGULAR
myText:AlignTo(ui.AlignMode.CENTRE)
-- Add a button
local myButton = ui.Button.new(myComponent)
myButton:SetPos(0,0,0.0,0.5)
myButton:SetSize(0,0,1.0,0.5)
myButton.label = "Push this button"
myButton.stylesheetID = id.StyleSheet.BUTTON_DEFAULT
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
        log("no items nearby")
        return nearbyItemIds
    end
    for _,objStackEntity in ipairs(allObjects) do
        for i=1,objStackEntity.stackSize do
            local entry = objStackEntity:GetEntry(i)
            local name = entry.config.configName
            local id = entry.config.id
            table.insert(nearbyItemIds, id)
            log(string.format("There is a %s with id %d. Have you acquired this item? Answer: %s", name, id, tostring(hasAcquired(id))))
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
            log(true)
            return true
        end
    end
    log(false)
    return false
end
myButton:Subscribe(ui.Hook.ONBUTTONPRESSED, shouldConsumeAreaLoot)
local function setTextBasedOnAreaLoot()
    -- I thought about doing an early return, based on if the player has moved and whether ObjStackEntityAdded
    -- event triggers but I'm not even sure it would be faster if the player moves a lot
    -- Certainly if the player is tanking afk a lot, but if so, I don't think the performance is an issue
    local shouldConsume = shouldConsumeAreaLoot()
    local text = "You are eligible to area loot"
    if shouldConsume then
        text = "You are NOT eligible to area loot"
    end
    myText.content = text
end
Event.ServerLogic.Subscribe("setTextBasedOnAreaLootEvent", setTextBasedOnAreaLoot)