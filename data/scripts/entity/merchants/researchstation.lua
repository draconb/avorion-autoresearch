
package.path = package.path .. ";data/scripts/entity/merchants/?.lua;"
package.path = package.path .. ";data/scripts/lib/?.lua;"

require ("galaxy")
require ("utility")
require ("faction")
require ("player")
require ("randomext")
require ("stringutility")
local SellableInventoryItem = require ("sellableinventoryitem")
local TurretGenerator = require ("turretgenerator")
local Dialog = require("dialogutility")

local button

-- START DRACONIAN
local autoButton
local raritySelection
local systemSelection

local systemTypeNames = {
  "All",
  "Battery Upgrade",
  "Cargo Upgrade",
  "Energy To Shield Converter",
  "Engine Upgrade",
  "Generator Upgrade",
  "Hyperspace Upgrade",
  "Mining System",
  "Object Detector",
  "Radar Upgrade",
  "Scanner Upgrade",
  "Shield Booster",
  "Shield Reinforcer",
  "A-TCS",
  "C-TCS",
  "M-TCS",
  "Technology Fragment",
  "Tractor Beam",
  "Trading System",
  "Velocity Security"
}
-- END DRACONIAN

function initialize()
    if onClient() and EntityIcon().icon == "" then
        EntityIcon().icon = "data/textures/icons/pixel/research.png"
        InteractionText().text = Dialog.generateStationInteractionText(Entity(), random())
    end
end

function interactionPossible(playerIndex, option)
    return CheckFactionInteraction(playerIndex, - 25000)
end

function initUI()

    local res = getResolution()
    local size = vec2(800, 600)

    local menu = ScriptUI()
    local window = menu:createWindow(Rect(res * 0.5 - size * 0.5, res * 0.5 + size * 0.5))

    window.caption = "Research /* station title */"%_t
    window.showCloseButton = 1
    window.moveable = 1
    menu:registerWindow(window, "Research"%_t);

    local hsplit = UIHorizontalSplitter(Rect(window.size), 10, 10, 0.4)

    inventory = window:createInventorySelection(hsplit.bottom, 11)

    local vsplit = UIVerticalSplitter(hsplit.top, 10, 10, 0.4)

    local hsplitleft = UIHorizontalSplitter(vsplit.left, 10, 10, 0.5)

    hsplitleft.padding = 6
    local rect = hsplitleft.top
    rect.width = 220
    required = window:createSelection(rect, 3)

    local rect = hsplitleft.bottom
    rect.width = 150
    optional = window:createSelection(rect, 2)

    for _, sel in pairs({required, optional}) do
        sel.dropIntoEnabled = 1
        sel.entriesSelectable = 0
        sel.onReceivedFunction = "onRequiredReceived"
        sel.onDroppedFunction = "onRequiredDropped"
        sel.onClickedFunction = "onRequiredClicked"
    end

    inventory.dragFromEnabled = 1
    inventory.onClickedFunction = "onInventoryClicked"


    vsplit.padding = 30
    local rect = vsplit.right
    rect.width = 70
    rect.height = 70
    results = window:createSelection(rect, 1)
    results.entriesSelectable = 0
    results.dropIntoEnabled = 0
    results.dragFromEnabled = 0

    vsplit.padding = 10
    local organizer = UIOrganizer(vsplit.right)
    organizer.marginBottom = 5

    button = window:createButton(Rect(), "Research"%_t, "onClickResearch")
    button.width = 200
    -- START DRACONIAN
    --button.height = 40
    --organizer:placeElementBottom(button)
    button.height = 20
    organizer:placeElementBottomLeft(button)
    -- END DRACONIAN

    -- START DRACONIAN
    local autoSplitter = UIHorizontalSplitter(vsplit.right, 5, 5, 0.5)
    raritySelection = window:createComboBox(Rect(), "onRaritySelect")
    raritySelection.width = 150
    raritySelection.height = 25
    autoSplitter:placeElementTopLeft(raritySelection)

    raritySelection:addEntry("Common"%_t)
    raritySelection:addEntry("Uncommon"%_t)
    raritySelection:addEntry("Rare"%_t)
    raritySelection:addEntry("Exceptional"%_t)

    systemSelection = window:createComboBox(Rect(), "onSystemSelect")
    systemSelection.width = 200
    systemSelection.height = 30
    autoSplitter:placeElementTopRight(systemSelection)

    for i = 1, #systemTypeNames do
        systemSelection:addEntry(systemTypeNames[i]%_t)
    end

    autoButton = window:createButton(Rect(), "Auto Research"%_t, "onStartAutoResearch")
    autoButton.width = 200
    autoButton.height = 20
    autoSplitter:placeElementBottomRight(autoButton)
    -- END DRACONIAN
end

function removeItemFromMainSelection(key)
    local item = inventory:getItem(key)
    if not item then return end

    if item.amount then
        item.amount = item.amount - 1
        if item.amount == 0 then item.amount = nil end
    end

    inventory:remove(key)

    if item.amount then
        inventory:add(item, key)
    end

end

function addItemToMainSelection(item)
    if not item then return end

    if item.item.stackable then
        -- find the item and increase the amount
        for k, v in pairs(inventory:getItems()) do
            if v.item == item.item then
                v.amount = v.amount + 1

                inventory:remove(k)
                inventory:add(v, k)
                return
            end
        end

        item.amount = 1
    end

    -- when not found or not stackable, add it
    inventory:add(item)

end

function moveItem(item, from, to, fkey, tkey)
    if not item then return end

    if from.index == inventory.index then -- move from inventory to a selection
        -- first, move the item that might be in place back to the inventory
        if tkey then
            addItemToMainSelection(to:getItem(tkey))
            to:remove(tkey)
        end

        removeItemFromMainSelection(fkey)

        -- fix item amount, we don't want numbers in the upper selections
        item.amount = nil
        to:add(item, tkey)

    elseif to.index == inventory.index then
        -- move from selection to inventory
        addItemToMainSelection(item)
        from:remove(fkey)
    end
end

function onRequiredReceived(selectionIndex, fkx, fky, item, fromIndex, toIndex, tkx, tky)
    if not item then return end

    -- don't allow dragging from/into the left hand selections
    if fromIndex == optional.index or fromIndex == required.index then
        return
    end

    moveItem(item, inventory, Selection(selectionIndex), ivec2(fkx, fky), ivec2(tkx, tky))

    refreshButton()
    results:clear()
    results:addEmpty()
end

function onRequiredClicked(selectionIndex, fkx, fky, item, button)
    if button == 3 or button == 2 then
        moveItem(item, Selection(selectionIndex), inventory, ivec2(fkx, fky), nil)
        refreshButton()
    end
end

function onRequiredDropped(selectionIndex, kx, ky)
    local selection = Selection(selectionIndex)
    local key = ivec2(kx, ky)
    moveItem(selection:getItem(key), Selection(selectionIndex), inventory, key, nil)
    refreshButton()
end

function onInventoryClicked(selectionIndex, kx, ky, item, button)

    if button == 2 or button == 3 then
        -- fill required first, then, once it's full, fill optional
        local items = required:getItems()
        if tablelength(items) < 3 then
            moveItem(item, inventory, required, ivec2(kx, ky), nil)

            refreshButton()
            results:clear()
            results:addEmpty()
            return
        end

        local items = optional:getItems()
        if tablelength(items) < 2 then
            moveItem(item, inventory, optional, ivec2(kx, ky), nil)

            refreshButton()
            results:clear()
            results:addEmpty()
            return
        end
    end
end

function refreshButton()
    local items = required:getItems()
    button.active = (tablelength(items) == 3)

    if tablelength(items) ~= 3 then
        button.tooltip = "Place at least 3 items for research!"%_t
    else
        button.tooltip = "Transform into a new item"%_t
    end

    for _, items in pairs({items, optional:getItems()}) do
        for _, item in pairs(items) do
            if item.item.itemType ~= InventoryItemType.TurretTemplate
            and item.item.itemType ~= InventoryItemType.SystemUpgrade
            and item.item.itemType ~= InventoryItemType.Turret then

                button.active = false
                button.tooltip = "Invalid items in ingredients."%_t
            end
        end
    end

end

function onShowWindow()

    inventory:clear()
    required:clear()
    optional:clear()

    required:addEmpty()
    required:addEmpty()
    required:addEmpty()

    optional:addEmpty()
    optional:addEmpty()

    results:addEmpty()

    refreshButton()

    for i = 1, 50 do
        inventory:addEmpty()
    end

    local player = Player()
    local ship = player.craft
    local alliance = player.alliance

    if alliance and ship.factionIndex == player.allianceIndex then
        inventory:fill(alliance.index)
    else
        inventory:fill(player.index)
    end

end

function checkRarities(items) -- items must not be more than 1 rarity apart
    local min = math.huge
    local max = -math.huge

    for _, item in pairs(items) do
        if item.rarity.value < min then min = item.rarity.value end
        if item.rarity.value > max then max = item.rarity.value end
    end

    if max - min <= 1 then
        return true
    end

    return false
end

function getRarityProbabilities(items)

    local probabilities = {}

    -- for each item there is a 20% chance that the researched item has a rarity 1 better
    for _, item in pairs(items) do
        -- next rarity cannot exceed legendary
        local nextRarity = math.min(RarityType.Legendary, item.rarity.value + 1)

        local p = probabilities[nextRarity] or 0
        p = p + 0.2
        probabilities[nextRarity] = p
    end

    -- if the amount of items is < 5 then add their own rarities as a result as well
    if #items < 5 then
        local left = (1.0 - #items * 0.2)
        local perItem = left / #items

        for _, item in pairs(items) do
            local p = probabilities[item.rarity.value] or 0
            p = p + perItem
            probabilities[item.rarity.value] = p
        end
    end

    local sum = 0
    for _, p in pairs(probabilities) do
        sum = sum + p
    end

    return probabilities
end

function getTypeProbabilities(items)
    local probabilities = {}

    for _, item in pairs(items) do
        local p = probabilities[item.itemType] or 0
        p = p + 1
        probabilities[item.itemType] = p
    end

    return probabilities
end

-- since there are no more exact weapon types in the finished weapons,
-- we have to gather the weapon types by their stats, such as icons
function getWeaponTypesByIcon()
    if weaponTypes then return weaponTypes end
    weaponTypes = {}

    local weapons = Balancing_GetWeaponProbability(0, 0)

    for weaponType, _ in pairs(weapons) do
        local turret = GenerateTurretTemplate(Seed(1), weaponType, 15, 5, Rarity(RarityType.Common), Material(MaterialType.Iron))
        weaponTypes[turret.weaponIcon] = weaponType
    end

    return weaponTypes
end

function getWeaponProbabilities(items)
    local probabilities = {}
    local typesByIcons = getWeaponTypesByIcon()

    for _, item in pairs(items) do
        if item.itemType == InventoryItemType.Turret
        or item.itemType == InventoryItemType.TurretTemplate then

            local weaponType = typesByIcons[item.weaponIcon]
            local p = probabilities[weaponType] or 0
            p = p + 1
            probabilities[weaponType] = p
        end
    end

    return probabilities
end

function getWeaponMaterials(items)
    local probabilities = {}

    for _, item in pairs(items) do
        if item.itemType == InventoryItemType.Turret
        or item.itemType == InventoryItemType.TurretTemplate then

            local p = probabilities[item.material.value] or 0
            p = p + 1
            probabilities[item.material.value] = p
        end
    end

    return probabilities
end

function getAutoFires(items)
    local probabilities = {}

    for _, item in pairs(items) do
        if item.itemType == InventoryItemType.Turret
        or item.itemType == InventoryItemType.TurretTemplate then

            local p = probabilities[item.automatic] or 0
            p = p + 1
            probabilities[item.automatic] = p
        end
    end

    return probabilities
end

function getSystemProbabilities(items)
    local probabilities = {}

    for _, item in pairs(items) do
        if item.itemType == InventoryItemType.SystemUpgrade then
            local p = probabilities[item.script] or 0
            p = p + 1
            probabilities[item.script] = p
        end
    end

    return probabilities
end





function onClickResearch()

    local items = {}
    local itemIndices = {}

    for _, item in pairs(required:getItems()) do
        table.insert(items, item.item)

        local amount = itemIndices[item.index] or 0
        amount = amount + 1
        itemIndices[item.index] = amount
    end
    for _, item in pairs(optional:getItems()) do
        table.insert(items, item.item)

        local amount = itemIndices[item.index] or 0
        amount = amount + 1
        itemIndices[item.index] = amount
    end

    if not checkRarities(items) then
        displayChatMessage("Your items cannot be more than one rarity apart!"%_t, Entity().title, 1)
        return
    end

    invokeServerFunction("research", itemIndices)
end

-- START DRACONIAN
-- Auto Research
function getUIRarity()
    return Rarity(raritySelection.selectedIndex).value
end

function getUISystems()
    return systemSelection.selectedIndex
end

function onStartAutoResearch()
    autoButton.active = false
    local maxRarity = getUIRarity()
    local systemType = getUISystems()
    --print ("Rarity", maxRarity, "Systems", systemType)
    invokeServerFunction("autoResearch", maxRarity, systemType)
end

function onRaritySelect()
    -- TODO: Something here?
end


function onSystemSelect()
    -- TODO: Something here?
end

function autoResearchComplete()
    autoButton.active = true
end

function autoResearch(maxRarity, systemType)
    local buyer, ship, player = getInteractingFaction(callingPlayer, AlliancePrivilege.SpendResources)
    if not buyer then
        if player then
            invokeClientFunction(player, "autoResearchComplete")
        end
        return
    end

    local station = Entity()

    local errors = {}
    errors[EntityType.Station] = "You must be docked to the station to research items."%_T
    errors[EntityType.Ship] = "You must be closer to the ship to research items."%_T
    if not CheckPlayerDocked(player, station, errors) then
        if player then
            invokeClientFunction(player, "autoResearchComplete")
        end
        return
    end
    
    -- Get System Upgrade type name from selectedIndex
    if systemType >= 0 and systemType < #systemTypeNames then
        systemType = systemTypeNames[systemType+1]
    else
        systemType = systemTypeNames[1]
    end

    -- inventory:clear()
    -- for i = 1, 50 do
    --     inventory:addEmpty()
    -- end

    -- local player = Player()
    -- local ship = player.craft
    -- local alliance = player.alliance
    --
    -- if alliance and ship.factionIndex == player.allianceIndex then
    --     inventory:fill(alliance.index)
    -- else
    --     inventory:fill(player.index)
    -- end

    -- item.item.itemType == InventoryItemType.SystemUpgrade
    -- getItemsByType(InventoryItemType type)

    local items, itemIndices, player
    local min = 5
    local max = 5

    while true do
        items, itemIndices, player = getIndices(RarityType.Petty, min, max, systemType)
        if (#items < min) then
            --print ("Need to check common", systemType)
            items, itemIndices = getIndices(RarityType.Common, min, max, systemType)
        end
        if (#items < min and maxRarity >= RarityType.Uncommon) then
            --print ("Need to check uncommon", systemType)
            items, itemIndices = getIndices(RarityType.Uncommon, min, max, systemType)
        end
        if (#items < min and maxRarity >= RarityType.Rare) then
            --print ("Need to check rare", systemType)
            items, itemIndices = getIndices(RarityType.Rare, min, max, systemType)
        end
        if (#items < min and maxRarity >= RarityType.Exceptional) then
            --print ("Need to check exceptional", systemType)
            items, itemIndices = getIndices(RarityType.Exceptional, min, max, systemType)
        end
        
        if (#items >= min) then
            research(itemIndices)
        else
            break
        end
    end

    --print ("Only have", #items, "items")
    invokeClientFunction(player, "autoResearchComplete")

    --local common = getSystemsByRarity(RarityType.Common)
    --local uncommon = getSystemsByRarity(RarityType.Uncommon)
    --local rare = getSystemsByRarity(RarityType.Rare)

    -- local inventory = Faction(factionIndex):getInventory()
    -- local inventoryItems = inventory:getItemsByType(InventoryItemType.SystemUpgrade)
    --
    -- for i, inventoryItem in pairs(inventoryItems) do
    --     if (inventoryItem.item.rarity < RarityType.Rare) then
    --         print (i, tostring(inventoryItem.item.name))
    --     end
    -- end
end

function getIndices(rarity, min, max, systemType)
    local items = {}
    local itemIndices = {}
    local researchTime = false
    local grouped, player = getSystemsByRarity(rarity, systemType)

    --print ("Found", #grouped, rarity)
    for g, group in pairs(grouped) do
        --print ("Group Count", #group)
        itemIndices = {}
        items = {}
        if #group >= min then
            for i, itemInfo in pairs(group) do
                --print (i, itemInfo.item.name, itemInfo.index)
                items[i] = itemInfo.item
                itemIndices[itemInfo.index] = 1
                if #items == max then
                    researchTime = true
                    break
                end
            end
            if researchTime then break end
        end
    end
    local itemIndicesCount = 0
    for i, idx in pairs(itemIndices) do
        itemIndicesCount = itemIndicesCount + 1
    end
    --print ("Found items", #items, rarity, itemIndicesCount)

    return items, itemIndices, player
end

function getSystemsByRarity(rarityType, systemType)
    local buyer, ship, player = getInteractingFaction(callingPlayer, AlliancePrivilege.SpendResources)
    -- local faction = Faction(factionIndex)
    local inventory = buyer:getInventory()
    local inventoryItems = inventory:getItemsByType(InventoryItemType.SystemUpgrade)
    local grouped = {}
    --print ("Rarity Type", rarityType)
    --print ("Inventory Items", #inventoryItems)
    --print("Inventory Items", tostring(inventoryItems[0]), tostring(inventoryItems[1]), tostring(inventoryItems[2]), tostring(inventoryItems[3]))
    --printObj({inventoryItems})

    for i, inventoryItem in pairs(inventoryItems) do
        if (inventoryItem.item.rarity.value == rarityType and not inventoryItem.item.favorite)
        and (systemType == "All" or inventoryItem.item.name:find(systemType)) then
            --print ("Item [" .. i .. "]", inventoryItem.item.name, inventoryItem.item.rarity.value, inventoryItem.item.seed.int32)
            local existing = grouped[inventoryItem.item.name]
            if existing == nil then
                --print ("Adding new item", inventoryItem.item.name)
                grouped[inventoryItem.item.name] = {}
                grouped[inventoryItem.item.name][1] = { item = inventoryItem.item, index = i } --.seed.int32
            else
                --print ("Adding to existing", tostring(inventoryItem.item.name))
                existing[#existing + 1] = { item = inventoryItem.item, index = i } --.seed.int32
            end
            -- printObj(inventoryItem)
            -- print(inventoryItem.item)
            --print("Inventory Item", tostring(inventoryItem[0]), tostring(inventoryItem[1]), tostring(inventoryItem[2]), tostring(inventoryItem[3]))
        end
    end

    return grouped, player
end

function printObj(obj, hierarchyLevel)
    if (hierarchyLevel == nil) then
        hierarchyLevel = 0
    elseif (hierarchyLevel == 4) then
        return 0
    end

    -- for key, value in pairs(obj) do
    --     print("found member " .. tostring(key), tostring(value));
    -- end
    local whitespace = ""
    for i = 0, hierarchyLevel, 1 do
        whitespace = whitespace .. "-"
    end

    print(whitespace, tostring(obj))
    if (type(obj) == 'table') then
        for k, v in pairs(obj) do
            if k > 10 then break end
            io.write(whitespace .. "-")
            if (type(v) == 'table') and hierarchyLevel < 1 then
                printObj(v, hierarchyLevel + 1)
            else
                print(v)
            end
        end
    else
        print(obj)
    end
end

-- END DRACONIAN

function research(itemIndices)

    local buyer, ship, player = getInteractingFaction(callingPlayer, AlliancePrivilege.SpendResources)
    if not buyer then return end

    -- check if the player has enough of the items
    local items = {}

    for index, amount in pairs(itemIndices) do
        local item = buyer:getInventory():find(index)
        local has = buyer:getInventory():amount(index)

        if not item or has < amount then
            player:sendChatMessage(Entity().title, 1, "You dont have enough items!"%_t)
            return
        end

        for i = 1, amount do
            table.insert(items, item)
        end
    end

    if #items < 3 then
        player:sendChatMessage(Entity().title, 1, "You need at least 3 items to do research!"%_t)
        return
    end

    if not checkRarities(items) then
        player:sendChatMessage(Entity().title, 1, "Your items cannot be more than one rarity apart!"%_t)
        return
    end

    local station = Entity()

    local errors = {}
    errors[EntityType.Station] = "You must be docked to the station to research items."%_T
    errors[EntityType.Ship] = "You must be closer to the ship to research items."%_T
    if not CheckPlayerDocked(player, station, errors) then
        return
    end

    local result = transform(items)

    if result then
        for index, amount in pairs(itemIndices) do
            for i = 1, amount do
                buyer:getInventory():take(index)
            end
        end

        buyer:getInventory():add(result)

        invokeClientFunction(player, "receiveResult", result)
    else
        print ("no result")
    end


end

function researchTest(...)
    local indices = {}

    for _, index in pairs({...}) do
        local amount = indices[index] or 0
        indices[index] = amount + 1
    end

    research(indices)
end

function receiveResult(result)
    results:clear();

    local item = InventorySelectionItem()
    item.item = result

    results:add(item)
    onShowWindow()
end

function transform(items)

    local transformToKey

    if items[1].itemType == InventoryItemType.SystemUpgrade
    and items[2].itemType == InventoryItemType.SystemUpgrade
    and items[3].itemType == InventoryItemType.SystemUpgrade
    and items[1].rarity.value == RarityType.Legendary
    and items[2].rarity.value == RarityType.Legendary
    and items[3].rarity.value == RarityType.Legendary then

        local inputKeys = 0
        for _, item in pairs(items) do
            if string.match(item.script, "systems/teleporterkey") then
                inputKeys = inputKeys + 1
            end
        end

        if inputKeys <= 1 then
            transformToKey = true
        end
    end

    local result

    if transformToKey then
        result = SystemUpgradeTemplate("data/scripts/systems/teleporterkey2.lua", Rarity(RarityType.Legendary), random():createSeed())
    else
        local rarities = getRarityProbabilities(items)
        local types = getTypeProbabilities(items, "type")

        local itemType = selectByWeight(random(), types)
        local rarity = Rarity(selectByWeight(random(), rarities))


        if itemType == InventoryItemType.Turret
        or itemType == InventoryItemType.TurretTemplate then

            local weaponTypes = getWeaponProbabilities(items)
            local materials = getWeaponMaterials(items)
            local autoFires = getAutoFires(items)

            local weaponType = selectByWeight(random(), weaponTypes)
            local material = Material(selectByWeight(random(), materials))
            local autoFire = selectByWeight(random(), autoFires)

            local x, y = Sector():getCoordinates()
            result = TurretGenerator.generate(x, y, - 5, rarity, weaponType, material)

            if itemType == InventoryItemType.Turret then
                result = InventoryTurret(result)
            end

            result.automatic = autoFire or false

        elseif itemType == InventoryItemType.SystemUpgrade then
            local scripts = getSystemProbabilities(items)

            local script = selectByWeight(random(), scripts)

            result = SystemUpgradeTemplate(script, rarity, random():createSeed())
        end
    end

    return result
end
