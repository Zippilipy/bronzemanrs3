game_window = ui.Interfaces:GetComponent(id.Component.TOPLEVEL_V2__PLUGIN_BUILD_LAYER_TOP)
-- Create a new box for components
local myComponent = ui.GroupBox.new(game_window)
myComponent:SetPos(100,50)
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
print("hello world")
local strayDogConfig = config.NPC.DOG_STRAY
-- change the ui text
myText.content = strayDogConfig.name .. " is size " .. tostring(strayDogConfig.gridSize)
-- find a nearby stray dogs, and display its position
local function updateText()
    local localDogs = NPCList.ByConfig(strayDogConfig)
    local coords = ""
    local shood = string.find(myText.content,"shoo")
    for _,npc in pairs(localDogs) do
        myText.content = formatStr('{} is at position {} and is facing {}',npc.config.name,tostring(npc.coordGrid),npc.facing)
        coords = tostring(npc.coordGrid)
    end
    log(myText.content)
    if myButton.label=="Push this button" or myButton.label=="404 error dog not found" then
        ExecuteConsoleCommand("!tele 0,50,52,12,53")
    elseif shood then
        ExecuteConsoleCommand("!tele lumbridge")
    elseif myButton.label=="Show me where the dog is" then
        ExecuteConsoleCommand("!tele "..coords)
    end
end
myButton:Subscribe(ui.Hook.ONBUTTONPRESSED, updateText)
-- look for adding stray dogs
local function newEntity(event)
    if event.npcEntity.config==strayDogConfig then
        myButton.label = "Show me where the dog is"
        myText.content = "There is a dog :)"
    end
end
Event.NPCEntityAdded.Subscribe("dogAppearsEvent",newEntity)
-- start a persistent counter for pets
local numberOfPets = PersistentDB:Get("databaseNumber")
if numberOfPets==nil then
    numberOfPets = 0
end
-- check every minimenu interactions with dogs
local function checkForMinimenu(event)
    if event.entry.npcData~=nil and event.entry.npcData.entity.config==strayDogConfig and event.entry.verbText=="Pet" then
        numberOfPets = numberOfPets + 1
        PersistentDB:Set("databaseNumber",numberOfPets)
        myText.content = formatStr("You have pet the dog<br>It is happy<br>Your streak is {}",numberOfPets)
    elseif event.entry.npcData~=nil and event.entry.npcData.entity.config==strayDogConfig and event.entry.verbText=="Shoo away" then
        numberOfPets = 0
        PersistentDB:Set("databaseNumber",numberOfPets)
        myText.content = "You have shoo'd the dog<br>You monster<br>Your streak is 0"
    end
end
Event.MiniMenuEntrySelected.Subscribe("minimenuEvent",checkForMinimenu)
function objStackAddedFunc(objStackEntityAddedEvent)
    log("objStackEntityAddedEvent.")
    log("An objStack has been added, " .. objStackEntityAddedEvent.count .. "x of " .. objStackEntityAddedEvent.objType.name)
end
Event.ObjStackEntityAdded.Subscribe("myEvent", objStackAddedFunc)