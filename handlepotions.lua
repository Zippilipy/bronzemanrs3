local doseLookup = {
    [1]  = config.Param.POTIONDOSES_1.id,
    [2]  = config.Param.POTIONDOSES_2.id,
    [3]  = config.Param.POTIONDOSES_3.id,
    [4]  = config.Param.POTIONDOSES_4.id,
    [5]  = config.Param.POTIONDOSES_5.id,
    [6]  = config.Param.POTIONDOSES_6.id,
    [7]  = config.Param.POTIONDOSES_7.id,
    [8]  = config.Param.POTIONDOSES_8.id,
    [9]  = config.Param.POTIONDOSES_9.id,
    [10] = config.Param.POTIONDOSES_10.id,
    [11] = config.Param.POTIONDOSES_11.id,
    [12] = config.Param.POTIONDOSES_12.id,

    [13] = config.Param.BIGPOT_DOSES1.id,
    [14] = config.Param.BIGPOT_DOSES2.id,
    [15] = config.Param.BIGPOT_DOSES3.id,
    [16] = config.Param.BIGPOT_DOSES4.id,
    [17] = config.Param.BIGPOT_DOSES5.id,
    [18] = config.Param.BIGPOT_DOSES6.id,
}

local doseIndexById = {}

for index, id in pairs(doseLookup) do
    doseIndexById[id] = index
end

local potionHandler = {}

--- Finds the highest-dose potion and adds all stockmarket potionDoses to setOfItems
--- Regular potion doses are prioritized over potion flasks
--- Any potion that is stockmarket but is not the highest-dose will be given a empty string "" name
--- This way, the item is still unlocked but will not be displayed
--- Furthermore, the item that is the highest dose will be given the name of the potion without ()
--- So a 'Super restore (4)' will actually be stored as 'Super restore'
--- setOfItems[3024] = "Super restore (4)" will be made into setOfItems[3024] = "Super restore"
--- setOfItems[3026] = "Super restore (3)" will be made into setOfItems[3026] = ""
--- @param potionStruct POTION_STRUCT The potion struct parameter of the given item
--- @param setOfItems table<number, string> Table of items, mapping the id of the item to the name
--- @return { collectionPopupItem: table|nil, isNewAddition: boolean }
function potionHandler.handlePotions(potionStruct, setOfItems)
    local isNewAddition = false
    local p = potionStruct.params
    local potionName = ""
    local bestPotionDoseNumber = -1
    local bestBigPotionDoseNumber = -1
    local isExchangeable = false
    for _, v in ipairs(p) do
        if v.valueType ~= ValueType.OBJ then
            goto continue
        end
        local objectConfig = potionStruct:GetParamValue(v)
        if not objectConfig.isStockmarket then
            goto continue
        end
        local dose = doseIndexById[v.id]
        if dose == nil then
            goto continue
        end
        isExchangeable = true
        if dose <= 12 then
            if dose > bestPotionDoseNumber then
                bestPotionDoseNumber = dose
            end
        else
            local bigDose = dose - 12 -- 13 - 18 => 1 - 6
            if bigDose > bestBigPotionDoseNumber then
                bestBigPotionDoseNumber = bigDose
            end
        end
        ::continue::
    end
    local bestObject = nil
    local bestNumber = bestPotionDoseNumber
    if bestNumber == -1 then
        bestNumber = bestBigPotionDoseNumber + 12
    end
    if bestNumber == -1 + 12 then
        if isExchangeable then
            log("no best potion found!")
        end
        return {
            collectionPopupItem = nil,
            isNewAddition = false
        }
    end
    local bestPotionDoseNumberId = doseLookup[bestNumber]
    for _,v in ipairs(p) do
        if v.valueType == ValueType.OBJ then
            local objectConfig = potionStruct:GetParamValue(v)
            local idConfig = potionStruct:GetParamValue(v).id
            local itemConfig = potionStruct:GetParamValue(v).name
            if v.id ~= bestPotionDoseNumberId then
                if objectConfig.isStockmarket then
                    setOfItems[idConfig] = "" -- empty means item is unlocked but shouldn't be displayed
                end
            else
                potionName = itemConfig:match("^(.-)%s*%(%d+%)$")
                if potionName == nil then
                    potionName = itemConfig
                end
                bestObject = objectConfig
                if setOfItems[idConfig] == nil then
                    setOfItems[idConfig] = potionName
                    isNewAddition = true
                end
            end
        end
    end
    local collectionPopupItem = {
        title = "Bronzeman log",
        text = string.format("New item obtained: %s", potionName),
        item = bestObject,
        y = 50,
    }
    return {
        collectionPopupItem = collectionPopupItem,
        isNewAddition = isNewAddition
    }
end

return potionHandler