local Azimuth = include("azimuthlib-basic")
local AutoResearchIntegration = include("AutoResearchIntegration")
if not Azimuth then return end

local config
local autoButton
local raritySelection
local systemSelection
local settingsReceived = false

local systemTypeNames = {
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
local systemTypeNameIndexes = {}
local systemTypeScripts = {
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


local old_initialize = initialize
function initialize()
    old_initialize()
    if onServer() then -- load config
        -- load custom system names and script file names
        local configOptions = {
          _version = { default = "1.1", comment = "Config version. Don't touch." },
          CustomSystems = { default = {
            -- using Tractor Beam Upgrade as an example
            lootrangebooster = { name = "RCN-00 Tractor Beam Upgrade MK ${mark}", extra = { mark = "X " } }
          }, comment = 'Here you can add custom systems. Format: "systemfilename" = { name = "System Display Name MK-${mark}", extra = { mark = "X" } }. "Extra" table holds additional name variables - just replace them all with "X ".' }
        }
        local isModified
        config, isModified = Azimuth.loadConfig("AutoResearch", configOptions)
        -- check 'CustomSystems'
        local t
        for k, v in pairs(config.CustomSystems) do
            if type(v) ~= "table" or not v.name then
                config.CustomSystems[k] = nil
                isModified = true
            elseif v.extra ~= nil and type(v.extra) ~= "table" then
                config.CustomSystems[k].extra = nil
                isModified = true
            end
        end
        -- resave if necessary
        if isModified then
            Azimuth.saveConfig("AutoResearch", config, configOptions)
        end

        -- add custom systems
        local systemNameList = {}
        for k, v in pairs(AutoResearchIntegration) do
            systemTypeScripts[#systemTypeScripts+1] = k
            systemNameList[#systemNameList+1] = v
        end
        for k, v in pairs(config.CustomSystems) do
            systemTypeScripts[#systemTypeScripts+1] = k
            systemNameList[#systemNameList+1] = v
        end
        -- clients only need display names
        config.CustomSystems = systemNameList
    else -- CLIENT
        invokeServerFunction("sendAutoResearchSettings")
    end
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
    button.height = 30
    organizer:placeElementBottomLeft(button)

    local autoSplitter = UIHorizontalSplitter(vsplit.right, 5, 5, 0.5)
    raritySelection = window:createComboBox(Rect(), "")
    raritySelection.width = 150
    raritySelection.height = 25
    autoSplitter:placeElementTopLeft(raritySelection)

    raritySelection:addEntry("Common"%_t)
    raritySelection:addEntry("Uncommon"%_t)
    raritySelection:addEntry("Rare"%_t)
    raritySelection:addEntry("Exceptional"%_t)

    systemSelection = window:createComboBox(Rect(), "")
    systemSelection.width = 250
    systemSelection.height = 25
    autoSplitter:placeElementTopRight(systemSelection)
    
    if settingsReceived then -- if settings were already received
        systemSelection:addEntry("All"%_t)
        for i = 1, #systemTypeNames do
            systemSelection:addEntry(systemTypeNames[i])
        end
    end

    autoButton = window:createButton(Rect(), "Auto Research"%_t, "onStartAutoResearch")
    autoButton.width = 200
    autoButton.height = 30
    autoSplitter:placeElementBottomRight(autoButton)
end

function sendAutoResearchSettings()
    invokeClientFunction(Player(callingPlayer), "receiveAutoResearchSettings", config.CustomSystems)
end
callable(nil, "sendAutoResearchSettings")

function receiveAutoResearchSettings(systems)
    local system
    for i = 1, #systems do
        system = systems[i]
        systemTypeNames[#systemTypeNames+1] = (system.name%_t) % (system.extra or {})
    end
    -- and now sort system names
    for i = 1, #systemTypeNames do
        systemTypeNameIndexes[systemTypeNames[i]] = i
    end
    table.sort(systemTypeNames)
    -- and add them to the combo box
    if systemSelection then
        systemSelection:addEntry("All"%_t)
        for i = 1, #systemTypeNames do
            systemSelection:addEntry(systemTypeNames[i])
        end
    end
    settingsReceived = true
end

function onStartAutoResearch()
    autoButton.active = false
    -- get system index
    local systemType = 0
    if systemSelection.selectedIndex > 0 then
        systemType = systemTypeNameIndexes[systemSelection.selectedEntry]
    end
    invokeServerFunction("autoResearch", Rarity(raritySelection.selectedIndex).value, systemType)
end

function autoResearchComplete()
    autoButton.active = true
end

function autoResearch(maxRarity, systemType)
    maxRarity = tonumber(maxRarity)
    systemType = tonumber(systemType)
    if anynils(maxRarity, systemType) then return end
    
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
    
    -- Get System Upgrade script path from selectedIndex
    if systemType == 0 then -- all
        systemType = nil
    else
        systemType = systemTypeScripts[math.max(1, math.min(#systemTypeScripts, systemType))]
        systemType = "data/scripts/systems/"..systemType..".lua"
    end

    local items, itemIndices, player
    local min = 5
    local max = 5

    while true do
        items, itemIndices, player = getIndices(RarityType.Petty, min, max, systemType)
        if #items < min then
            items, itemIndices = getIndices(RarityType.Common, min, max, systemType)
        end
        if #items < min and maxRarity >= RarityType.Uncommon then
            items, itemIndices = getIndices(RarityType.Uncommon, min, max, systemType)
        end
        if #items < min and maxRarity >= RarityType.Rare then
            items, itemIndices = getIndices(RarityType.Rare, min, max, systemType)
        end
        if #items < min and maxRarity >= RarityType.Exceptional then
            items, itemIndices = getIndices(RarityType.Exceptional, min, max, systemType)
        end
        
        if #items >= min then
            research(itemIndices)
        else
            break
        end
    end

    invokeClientFunction(player, "autoResearchComplete")
end
callable(nil, "autoResearch")

function getIndices(rarity, min, max, systemType)
    local items = {}
    local itemIndices = {}
    local researchTime = false
    local grouped, player = getSystemsByRarity(rarity, systemType)

    for g, group in pairs(grouped) do
        itemIndices = {}
        items = {}
        if #group >= min then
            for i, itemInfo in pairs(group) do
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

    return items, itemIndices, player
end

function getSystemsByRarity(rarityType, systemType)
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