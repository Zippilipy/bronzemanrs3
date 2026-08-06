local UI = {}

local itemRibbon = nil

local settingsWindow = nil

local counterForItemSlot = 0

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
    settingsWindow:AddTitle("Settings")

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

    local divider = settingsWindow:AddDivider()

    local heading = settingsWindow:AddTitle("Your collected items")

    for id, _ in pairs(setOfItemsAcquired) do
        local object = config.Obj.FromID(id)
        addItemSlot(object)
    end
end

function addItemSlot(object)
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
    counterForItemSlot = (counterForItemSlot + 1) % 8
end

return UI