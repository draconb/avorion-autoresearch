local Azimuth = include("azimuthlib-basic")
local AutoResearchIntegration = include("AutoResearchIntegration")

-- all local variables are outside of 'onClient/onServer' blocks to make them accessible for other mods
local autoResearch_autoButton, autoResearch_itemTypeSelection, autoResearch_raritySelection, autoResearch_systemSelection, autoResearch_minAmountComboBox, autoResearch_maxAmountComboBox, autoResearch_materialSelection -- client UI
local autoResearch_settingsReceived, autoResearch_systemTypeNames, autoResearch_systemTypeNameIndexes, autoResearch_turretTypeNames, autoResearch_turretTypeByName -- client
local AutoResearchConfig, autoResearch_systemTypeScripts -- server
local autoResearch_initialize -- extended functions

if onClient() then


autoResearch_systemTypeNames = {
  "Turret Control System A-TCS-${num}"%_t % {num = "X "},
  "Battery Upgrade"%_t,
  "T1M-LRD-Tech Cargo Upgrade MK ${mark}"%_t % {mark = "X "},
  "Turret Control System C-TCS-${num}"%_t % {num = "X "},
  "Generator Upgrade"%_t,
  "Energy to Shield Converter"%_t,
  "Engine Upgrade"%_t,
  "Quantum ${num}Hyperspace Upgrade"%_t % {num = "X "},
  --"RCN-00 Tractor Beam Upgrade MK ${mark}"%_t % {mark = "X "},
  "Turret Control System M-TCS-${num}"%_t % {num = "X "},
  "Mining System"%_t,
  "Radar Upgrade"%_t,
  "Scanner Upgrade"%_t,
  "Shield Booster"%_t,
  "Shield Reinforcer"%_t,
  "Trading System"%_t,
  "Transporter Software"%_t,
  "C43 Object Detector"%_t,
  "Velocity Security Control Bypass"%_t,
  "Xsotan Technology Fragment"%_t
}
autoResearch_systemTypeNameIndexes = {}

autoResearch_initialize = initialize
function initialize()
    autoResearch_initialize()

    autoResearch_turretTypeByName = {}
    autoResearch_turretTypeNames = {}
    for weaponType, weaponTypeName in pairs(WeaponTypes.nameByType) do
        autoResearch_turretTypeNames[#autoResearch_turretTypeNames+1] = weaponTypeName
        autoResearch_turretTypeByName[weaponTypeName] = weaponType
    end
    table.sort(autoResearch_turretTypeNames)

    invokeServerFunction("autoResearch_sendSettings")
end

function initUI() -- overridden
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
    rect.position = rect.position - vec2(145, 0)
    results = window:createSelection(rect, 1)
    results.entriesSelectable = 0
    results.dropIntoEnabled = 0
    results.dragFromEnabled = 0

    vsplit.padding = 10
    local organizer = UIOrganizer(vsplit.right)
    organizer.marginBottom = 5

    button = window:createButton(Rect(), "Research"%_t, "onClickResearch")
    button.width = 200
    button.height = 30
    organizer:placeElementBottomLeft(button)

    local autoSplitter = UIHorizontalSplitter(Rect(vsplit.right.lower.x, vsplit.right.lower.y - 15, vsplit.right.upper.x + 15, vsplit.right.upper.y), 5, 5, 0.5)
    autoResearch_itemTypeSelection = window:createComboBox(Rect(), "autoResearch_onItemTypeChanged")
    autoResearch_itemTypeSelection.width = 150
    autoResearch_itemTypeSelection.height = 25
    autoSplitter:placeElementTopLeft(autoResearch_itemTypeSelection)
    autoResearch_itemTypeSelection:addEntry("Systems"%_t)
    autoResearch_itemTypeSelection:addEntry("Turrets"%_t)

    autoResearch_systemSelection = window:createComboBox(Rect(), "")
    autoResearch_systemSelection.width = 270
    autoResearch_systemSelection.height = 25
    autoSplitter:placeElementTopRight(autoResearch_systemSelection)
    autoResearch_fillSystems()

    autoResearch_raritySelection = window:createComboBox(Rect(), "")
    autoResearch_raritySelection.width = 145
    autoResearch_raritySelection.height = 25
    autoSplitter:placeElementTopRight(autoResearch_raritySelection)
    autoResearch_raritySelection.position = autoResearch_raritySelection.position + vec2(0, 35)
    autoResearch_raritySelection:addEntry("Common"%_t)
    autoResearch_raritySelection:addEntry("Uncommon"%_t)
    autoResearch_raritySelection:addEntry("Rare"%_t)
    autoResearch_raritySelection:addEntry("Exceptional"%_t)
    autoResearch_raritySelection:addEntry("Exotic"%_t)

    autoResearch_materialSelection = window:createComboBox(Rect(), "")
    autoResearch_materialSelection.width = 115
    autoResearch_materialSelection.height = 25
    autoSplitter:placeElementTopRight(autoResearch_materialSelection)
    autoResearch_materialSelection.position = autoResearch_materialSelection.position + vec2(-autoResearch_raritySelection.width - 10, 35)
    autoResearch_materialSelection:addEntry("All"%_t)
    for i = 1, NumMaterials() do
        autoResearch_materialSelection:addEntry(Material(i-1).name)
    end
    autoResearch_materialSelection.visible = false

    autoResearch_minAmountComboBox = window:createComboBox(Rect(), "autoResearch_onMinAmountChanged")
    autoResearch_minAmountComboBox.width = 50
    autoResearch_minAmountComboBox.height = 25
    autoSplitter:placeElementTopRight(autoResearch_minAmountComboBox)
    autoResearch_minAmountComboBox.position = autoResearch_minAmountComboBox.position + vec2(0, 70)
    autoResearch_minAmountComboBox:addEntry(5)
    autoResearch_minAmountComboBox:addEntry(4)
    autoResearch_minAmountComboBox:addEntry(3)
    
    local amountLabel = window:createLabel(Rect(), "Min amount"%_t, 13)
    amountLabel.width = 100
    amountLabel.height = 25
    autoSplitter:placeElementTopRight(amountLabel)
    amountLabel.position = amountLabel.position + vec2(-60, 70)
    amountLabel:setRightAligned()
    
    autoResearch_maxAmountComboBox = window:createComboBox(Rect(), "autoResearch_onMaxAmountChanged")
    autoResearch_maxAmountComboBox.width = 50
    autoResearch_maxAmountComboBox.height = 25
    autoSplitter:placeElementTopRight(autoResearch_maxAmountComboBox)
    autoResearch_maxAmountComboBox.position = autoResearch_maxAmountComboBox.position + vec2(0, 105)
    autoResearch_maxAmountComboBox:addEntry(5)
    autoResearch_maxAmountComboBox:addEntry(4)
    autoResearch_maxAmountComboBox:addEntry(3)
    
    amountLabel = window:createLabel(Rect(), "Max amount"%_t, 13)
    amountLabel.width = 100
    amountLabel.height = 25
    autoSplitter:placeElementTopRight(amountLabel)
    amountLabel.position = amountLabel.position + vec2(-60, 105)
    amountLabel:setRightAligned()

    autoResearch_autoButton = window:createButton(Rect(), "Auto Research"%_t, "autoResearch_onStartAutoResearch")
    autoResearch_autoButton.width = 200
    autoResearch_autoButton.height = 30
    autoSplitter:placeElementBottomRight(autoResearch_autoButton)
end

function autoResearch_onItemTypeChanged()
    if autoResearch_itemTypeSelection.selectedIndex == 0 then -- Systems
        autoResearch_fillSystems()
        autoResearch_materialSelection.visible = false
    else -- Turrets
        autoResearch_systemSelection:clear()
        autoResearch_systemSelection:addEntry("All"%_t)
        for _, weaponTypeName in pairs(autoResearch_turretTypeNames) do
            autoResearch_systemSelection:addEntry(weaponTypeName)
        end
        autoResearch_materialSelection.visible = true
    end
end

function autoResearch_onMinAmountChanged()
    local minAmount = tonumber(autoResearch_minAmountComboBox.selectedEntry)
    local maxAmount = tonumber(autoResearch_maxAmountComboBox.selectedEntry)
    if minAmount > maxAmount then
        autoResearch_maxAmountComboBox.selectedIndex = autoResearch_minAmountComboBox.selectedIndex
    end
end

function autoResearch_onMaxAmountChanged()
    local minAmount = tonumber(autoResearch_minAmountComboBox.selectedEntry)
    local maxAmount = tonumber(autoResearch_maxAmountComboBox.selectedEntry)
    if minAmount > maxAmount then
        autoResearch_minAmountComboBox.selectedIndex = autoResearch_maxAmountComboBox.selectedIndex
    end
end

function autoResearch_onStartAutoResearch()
    autoResearch_autoButton.active = false
    local itemType = autoResearch_itemTypeSelection.selectedIndex
    -- get system index
    local systemType = -1
    if autoResearch_systemSelection.selectedIndex > 0 then
        if itemType == 0 then -- systems
            systemType = autoResearch_systemTypeNameIndexes[autoResearch_systemSelection.selectedEntry]
        else -- turrets
            systemType = autoResearch_turretTypeByName[autoResearch_systemSelection.selectedEntry]
        end
    end
    local minAmount = tonumber(autoResearch_minAmountComboBox.selectedEntry) or 5
    local maxAmount = tonumber(autoResearch_maxAmountComboBox.selectedEntry) or 5
    local materialType = autoResearch_materialSelection.selectedIndex - 1
    invokeServerFunction("autoResearch_autoResearch", Rarity(autoResearch_raritySelection.selectedIndex).value, itemType, systemType, materialType, minAmount, maxAmount)
end

function autoResearch_fillSystems()
    if autoResearch_settingsReceived and autoResearch_systemSelection then -- if settings were already received and ui is ready
        autoResearch_systemSelection:clear()
        autoResearch_systemSelection:addEntry("All"%_t)
        for i = 1, #autoResearch_systemTypeNames do
            autoResearch_systemSelection:addEntry(autoResearch_systemTypeNames[i])
        end
    end
end

function autoResearch_autoResearchComplete()
    autoResearch_autoButton.active = true
end

function autoResearch_receiveSettings(systems)
    local system
    for i = 1, #systems do
        system = systems[i]
        autoResearch_systemTypeNames[#autoResearch_systemTypeNames+1] = (system.name%_t) % (system.extra or {})
    end
    -- and now sort system names
    for i = 1, #autoResearch_systemTypeNames do
        autoResearch_systemTypeNameIndexes[autoResearch_systemTypeNames[i]] = i
    end
    table.sort(autoResearch_systemTypeNames)
    autoResearch_settingsReceived = true
    -- and add them to the combo box
    autoResearch_fillSystems()
end


else -- onServer


autoResearch_systemTypeScripts = {
  "arbitrarytcs",
  "batterybooster",
  "cargoextension",
  "civiltcs",
  "energybooster",
  "energytoshieldconverter",
  "enginebooster",
  "hyperspacebooster",
  --"lootrangebooster",
  "militarytcs",
  "miningsystem",
  "radarbooster",
  "scannerbooster",
  "shieldbooster",
  "shieldimpenetrator",
  "tradingoverview",
  "transportersoftware",
  "valuablesdetector",
  "velocitybypass",
  "wormholeopener"
}

autoResearch_initialize = initialize
function initialize()
    autoResearch_initialize()

    local configOptions = {
      _version = { default = "1.1", comment = "Config version. Don't touch." },
      CustomSystems = {
        default = {
          lootrangebooster = { name = "RCN-00 Tractor Beam Upgrade MK ${mark}", extra = { mark = "X " } } -- using Tractor Beam Upgrade as an example
        },
        comment = 'Here you can add custom systems. Format: "systemfilename" = { name = "System Display Name MK-${mark}", extra = { mark = "X" } }. "Extra" table holds additional name variables - just replace them all with "X ".'
      }
    }
    local isModified
    AutoResearchConfig, isModified = Azimuth.loadConfig("AutoResearch", configOptions)
    -- check 'CustomSystems'
    local t
    for k, v in pairs(AutoResearchConfig.CustomSystems) do
        if type(v) ~= "table" or not v.name then
            AutoResearchConfig.CustomSystems[k] = nil
            isModified = true
        elseif v.extra ~= nil and type(v.extra) ~= "table" then
            AutoResearchConfig.CustomSystems[k].extra = nil
            isModified = true
        end
    end
    if isModified then
        Azimuth.saveConfig("AutoResearch", AutoResearchConfig, configOptions)
    end

    -- add custom systems
    local systemNameList = {}
    for k, v in pairs(AutoResearchIntegration) do
        autoResearch_systemTypeScripts[#autoResearch_systemTypeScripts+1] = k
        systemNameList[#systemNameList+1] = v
    end
    for k, v in pairs(AutoResearchConfig.CustomSystems) do
        autoResearch_systemTypeScripts[#autoResearch_systemTypeScripts+1] = k
        systemNameList[#systemNameList+1] = v
    end
    -- clients only need display names
    AutoResearchConfig.CustomSystems = systemNameList
end

function autoResearch_getIndices(rarity, min, max, itemType, systemType, materialType)
    local items = {}
    local itemIndices = {}
    local researchTime = false
    local grouped, player
    if itemType == 0 then
        grouped, player = autoResearch_getSystemsByRarity(rarity, systemType)
    else
        grouped, player = autoResearch_getTurretsByRarity(rarity, systemType, materialType)
    end

    local itemIndex
    for g, group in pairs(grouped) do
        itemIndices = {}
        items = {}
        if #group >= min then
            for i, itemInfo in ipairs(group) do
                items[i] = itemInfo.item
                itemIndex = itemIndices[itemInfo.index]
                if not itemIndex then
                    itemIndices[itemInfo.index] = 1
                else
                    itemIndices[itemInfo.index] = itemIndex + 1
                end
                if #items == max then
                    researchTime = true
                    break
                end
            end
            if researchTime then break end
        end
    end

    return items, itemIndices, player
end

function autoResearch_getSystemsByRarity(rarityType, systemType)
    local buyer, ship, player = getInteractingFaction(callingPlayer, AlliancePrivilege.SpendResources)
    local inventory = buyer:getInventory()
    local inventoryItems = inventory:getItemsByType(InventoryItemType.SystemUpgrade)
    local grouped = {}

    for i, inventoryItem in pairs(inventoryItems) do
        if (inventoryItem.item.rarity.value == rarityType and not inventoryItem.item.favorite)
          and (not systemType or inventoryItem.item.script == systemType) then
            local existing = grouped[inventoryItem.item.name]
            if existing == nil then
                grouped[inventoryItem.item.name] = {}
                grouped[inventoryItem.item.name][1] = { item = inventoryItem.item, index = i }
            else
                existing[#existing + 1] = { item = inventoryItem.item, index = i }
            end
        end
    end

    return grouped, player
end

function autoResearch_getTurretsByRarity(rarityType, turretType, materialType)
    local buyer, ship, player = getInteractingFaction(callingPlayer, AlliancePrivilege.SpendResources)
    local inventory = buyer:getInventory()
    local inventoryItems = inventory:getItemsByType(InventoryItemType.Turret)
    local turretTemplates = inventory:getItemsByType(InventoryItemType.TurretTemplate)
    for i, inventoryItem in pairs(turretTemplates) do
        inventoryItems[i] = inventoryItem
    end
    local grouped = {}

    local weaponType, materialValue
    for i, inventoryItem in pairs(inventoryItems) do
        if (inventoryItem.item.rarity.value == rarityType and not inventoryItem.item.favorite) then
            weaponType = WeaponTypes.getTypeOfItem(inventoryItem.item)
            materialValue = inventoryItem.item.material.value
            if (not turretType or weaponType == turretType) and (not materialType or materialValue <= materialType) then
                local existing = grouped[materialValue] -- group by material, no need to mix iron and avorion
                if existing == nil then
                    grouped[materialValue] = {}
                    existing = grouped[materialValue]
                end
                for j = 1, inventoryItem.amount do
                    existing[#existing+1] = { item = inventoryItem.item, index = i }
                end
            end
        end
    end
    -- sort groups so low-dps weapons will be researched first
    for materialValue, group in pairs(grouped) do
        table.sort(group, function(a, b) return a.item.dps < b.item.dps end)
    end

    return grouped, player
end

function autoResearch_sendSettings()
    invokeClientFunction(Player(callingPlayer), "autoResearch_receiveSettings", AutoResearchConfig.CustomSystems)
end
callable(nil, "autoResearch_sendSettings")

function autoResearch_autoResearch(maxRarity, itemType, systemType, materialType, minAmount, maxAmount)
    maxRarity = tonumber(maxRarity)
    itemType = tonumber(itemType)
    systemType = tonumber(systemType)
    materialType = tonumber(materialType)
    if anynils(maxRarity, itemType, systemType, materialType) then return end
    minAmount = tonumber(minAmount) or 5
    maxAmount = tonumber(maxAmount) or 5
    minAmount = math.min(minAmount, maxAmount)
    maxAmount = math.max(minAmount, maxAmount)
    
    local buyer, ship, player = getInteractingFaction(callingPlayer, AlliancePrivilege.SpendResources)
    if not buyer then
        if player then
            invokeClientFunction(player, "autoResearch_autoResearchComplete")
        end
        return
    end

    local station = Entity()

    local errors = {}
    errors[EntityType.Station] = "You must be docked to the station to research items."%_T
    errors[EntityType.Ship] = "You must be closer to the ship to research items."%_T
    if not CheckPlayerDocked(player, station, errors) then
        if player then
            invokeClientFunction(player, "autoResearch_autoResearchComplete")
        end
        return
    end
    
    -- Get System Upgrade script path from selectedIndex
    if systemType == -1 then -- all
        systemType = nil
    else
        if itemType == 0 then -- systems
            systemType = autoResearch_systemTypeScripts[math.max(1, math.min(#autoResearch_systemTypeScripts, systemType))]
            systemType = "data/scripts/systems/"..systemType..".lua"
        end
    end

    if materialType == -1 then
        materialType = nil
    end

    local items, itemIndices, player
    while true do
        items, itemIndices, player = autoResearch_getIndices(RarityType.Petty, minAmount, maxAmount, itemType, systemType, materialType)
        if #items < minAmount then
            items, itemIndices = autoResearch_getIndices(RarityType.Common, minAmount, maxAmount, itemType, systemType, materialType)
        end
        if #items < minAmount and maxRarity >= RarityType.Uncommon then
            items, itemIndices = autoResearch_getIndices(RarityType.Uncommon, minAmount, maxAmount, itemType, systemType, materialType)
        end
        if #items < minAmount and maxRarity >= RarityType.Rare then
            items, itemIndices = autoResearch_getIndices(RarityType.Rare, minAmount, maxAmount, itemType, systemType, materialType)
        end
        if #items < minAmount and maxRarity >= RarityType.Exceptional then
            items, itemIndices = autoResearch_getIndices(RarityType.Exceptional, minAmount, maxAmount, itemType, systemType, materialType)
        end
        if #items < minAmount and maxRarity >= RarityType.Exotic then
            items, itemIndices = autoResearch_getIndices(RarityType.Exotic, minAmount, maxAmount, itemType, systemType, materialType)
        end
        
        if #items >= minAmount then
            research(itemIndices)
        else
            break
        end
    end

    invokeClientFunction(player, "autoResearch_autoResearchComplete")
end
callable(nil, "autoResearch_autoResearch")


end