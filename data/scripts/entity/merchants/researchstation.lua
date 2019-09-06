include("azimuthlib-uiproportionalsplitter")
local Azimuth = include("azimuthlib-basic")
local AutoResearchIntegration = include("AutoResearchIntegration")

-- all local variables are outside of 'onClient/onServer' blocks to make them accessible for other mods
local window, autoResearch_autoButton, autoResearch_itemTypeSelection, autoResearch_raritySelection, autoResearch_minAmountComboBox, autoResearch_maxAmountComboBox, autoResearch_materialSelection, autoResearch_separateAutoCheckBox, separateAutoLabel, autoResearch_typesRect, autoResearch_typesCheckBoxes, autoResearch_allTypesCheckBox -- client UI
local autoResearch_settingsReceived, autoResearch_systemTypeNames, autoResearch_systemTypeNameIndexes, autoResearch_turretTypeNames, autoResearch_turretTypeByName, autoResearch_typesCache, autoResearch_inProcess -- client
local autoResearch_type = 0 -- client
local AutoResearchConfig, AutoResearchLog, autoResearch_systemTypeScripts, autoResearch_playerLocks -- server
local autoResearch_initialize, autoResearch_onClickResearch -- extended functions

if onClient() then


autoResearch_systemTypeNames = {
  "Turret Control System A-TCS-${num}"%_t % {num = "X "},
  "Battery Upgrade"%_t,
  "T1M-LRD-Tech Cargo Upgrade MK ${mark}"%_t % {mark = "X "},
  "Turret Control System C-TCS-${num}"%_t % {num = "X "},
  "Defense Weapons System DWS-${num}"%_t % {num = "X "},
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

autoResearch_initialize = ResearchStation.initialize
function ResearchStation.initialize()
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

function ResearchStation.initUI() -- overridden
    local res = getResolution()
    local size = vec2(980, 600)

    local menu = ScriptUI()
    window = menu:createWindow(Rect(res * 0.5 - size * 0.5, res * 0.5 + size * 0.5))

    window.caption = "Research /* station title */"%_t
    window.showCloseButton = 1
    window.moveable = 1
    menu:registerWindow(window, "Research"%_t);

    local vPartitions = UIVerticalProportionalSplitter(Rect(window.size), 10, 10, {0.5, 250})

    local hsplit = UIHorizontalSplitter(vPartitions[1], 10, 0, 0.4)

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
    rect.position = rect.position - vec2(180, 0)
    results = window:createSelection(rect, 1)
    results.entriesSelectable = 0
    results.dropIntoEnabled = 0
    results.dragFromEnabled = 0

    vsplit.padding = 10
    local organizer = UIOrganizer(vsplit.right)
    organizer.marginBottom = 5

    button = window:createButton(Rect(), "Research"%_t, "onClickResearch")
    button.maxTextSize = 15
    button.width = 180
    button.height = 30
    organizer:placeElementBottomLeft(button)
    button.position = button.position + vec2(0, 20)

    local autoSplitter = UIHorizontalSplitter(Rect(vsplit.right.lower.x, vsplit.right.lower.y - 15, vsplit.right.upper.x + 15, vsplit.right.upper.y), 5, 5, 0.5)
    autoResearch_itemTypeSelection = window:createComboBox(Rect(), "autoResearch_onItemTypeChanged")
    autoResearch_itemTypeSelection.width = 145
    autoResearch_itemTypeSelection.height = 25
    autoSplitter:placeElementTopRight(autoResearch_itemTypeSelection)
    autoResearch_itemTypeSelection:addEntry("Systems"%_t)
    autoResearch_itemTypeSelection:addEntry("Turrets"%_t)

    autoResearch_typesRect = vPartitions[2]
    ResearchStation.autoResearch_finishInitUI()
    ResearchStation.autoResearch_fillSystems()

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
    
    autoResearch_separateAutoCheckBox = window:createCheckBox(Rect(), "", "")
    autoResearch_separateAutoCheckBox.checked = true
    autoResearch_separateAutoCheckBox.width = 25
    autoResearch_separateAutoCheckBox.height = 25
    autoSplitter:placeElementTopRight(autoResearch_separateAutoCheckBox)
    autoResearch_separateAutoCheckBox.position = autoResearch_separateAutoCheckBox.position + vec2(0, 140)
    autoResearch_separateAutoCheckBox.visible = false
    
    separateAutoLabel = window:createLabel(Rect(), "Research Auto/Non-auto turrets separately"%_t, 12)
    separateAutoLabel.width = 320
    separateAutoLabel.height = 25
    autoSplitter:placeElementTopRight(separateAutoLabel)
    separateAutoLabel.position = separateAutoLabel.position + vec2(-35, 137)
    separateAutoLabel:setRightAligned()
    separateAutoLabel.visible = false

    autoResearch_autoButton = window:createButton(Rect(), "Auto Research"%_t, "autoResearch_onStartAutoResearch")
    autoResearch_autoButton.maxTextSize = 15
    autoResearch_autoButton.width = 200
    autoResearch_autoButton.height = 30
    autoSplitter:placeElementBottomRight(autoResearch_autoButton)
    autoResearch_autoButton.position = autoResearch_autoButton.position + vec2(0, 20)
end

function ResearchStation.autoResearch_onItemTypeChanged()
    if autoResearch_itemTypeSelection.selectedIndex == 0 then -- Systems
        if autoResearch_type ~= 0 then
            ResearchStation.autoResearch_fillSystems()

            autoResearch_materialSelection.visible = false
            autoResearch_separateAutoCheckBox.visible = false
            separateAutoLabel.visible = false
            autoResearch_type = 0
        end
    else -- Turrets
        if autoResearch_type ~= 1 then
            local allStatus = true
            -- save selected turret types
            for i = 1, #autoResearch_systemTypeNames do
                autoResearch_typesCache.systems[i] = autoResearch_typesCheckBoxes[i].element.checked
            end
            -- restore selected system types
            local checkBox
            for i = 1, #autoResearch_turretTypeNames do
                checkBox = autoResearch_typesCheckBoxes[i]
                checkBox.caption = autoResearch_turretTypeNames[i]
                checkBox.element.caption = checkBox.caption
                checkBox.element.visible = true
                if not autoResearch_typesCache.turrets[i] then
                    allStatus = false
                end
                checkBox.element:setCheckedNoCallback(autoResearch_typesCache.turrets[i])
            end
            for i = #autoResearch_turretTypeNames + 1, #autoResearch_typesCheckBoxes do
                autoResearch_typesCheckBoxes[i].element.visible = false
            end
            autoResearch_allTypesCheckBox:setCheckedNoCallback(allStatus)

            autoResearch_materialSelection.visible = true
            autoResearch_separateAutoCheckBox.visible = true
            separateAutoLabel.visible = true
            autoResearch_type = 1
        end
    end
end

function ResearchStation.autoResearch_onMinAmountChanged()
    local minAmount = tonumber(autoResearch_minAmountComboBox.selectedEntry)
    local maxAmount = tonumber(autoResearch_maxAmountComboBox.selectedEntry)
    if minAmount > maxAmount then
        autoResearch_maxAmountComboBox.selectedIndex = autoResearch_minAmountComboBox.selectedIndex
    end
end

function ResearchStation.autoResearch_onMaxAmountChanged()
    local minAmount = tonumber(autoResearch_minAmountComboBox.selectedEntry)
    local maxAmount = tonumber(autoResearch_maxAmountComboBox.selectedEntry)
    if minAmount > maxAmount then
        autoResearch_minAmountComboBox.selectedIndex = autoResearch_maxAmountComboBox.selectedIndex
    end
end

autoResearch_onClickResearch = ResearchStation.onClickResearch
function ResearchStation.onClickResearch(...)
    if autoResearch_inProcess then return end

    autoResearch_onClickResearch(...)
end

function ResearchStation.autoResearch_onStartAutoResearch()
    if not autoResearch_inProcess then
        local itemType = autoResearch_itemTypeSelection.selectedIndex
        -- get system/turret indexex
        local selectedTypes = {}
        local checkBox
        local hasTypes = false
        if itemType == 0 then
            for i = 1, #autoResearch_systemTypeNames do
                checkBox = autoResearch_typesCheckBoxes[i]
                if checkBox.element.checked then
                    selectedTypes[autoResearch_systemTypeNameIndexes[checkBox.caption]] = true
                    hasTypes = true
                end
            end
        else
            for i = 1, #autoResearch_turretTypeNames do
                checkBox = autoResearch_typesCheckBoxes[i]
                if checkBox.element.checked then
                    selectedTypes[autoResearch_turretTypeByName[checkBox.caption]] = true
                    hasTypes = true
                end
            end
        end
        if not hasTypes then return end -- no types selected

        local minAmount = tonumber(autoResearch_minAmountComboBox.selectedEntry) or 5
        local maxAmount = tonumber(autoResearch_maxAmountComboBox.selectedEntry) or 5
        local materialType = autoResearch_materialSelection.selectedIndex - 1
        local separateAutoTurrets = autoResearch_separateAutoCheckBox.checked
        autoResearch_inProcess = true
        autoResearch_autoButton.caption = "Stop Auto Research"%_t

        invokeServerFunction("autoResearch_autoResearch", Rarity(autoResearch_raritySelection.selectedIndex).value, itemType, selectedTypes, materialType, minAmount, maxAmount, separateAutoTurrets)
    else -- stop auto research
        invokeServerFunction("autoResearch_stopAutoResearch")
    end
end

function ResearchStation.autoResearch_fillSystems()
    if autoResearch_settingsReceived and autoResearch_typesRect then -- if settings were already received and ui is ready
        local allStatus = true
        -- save selected turret types
        for i = 1, #autoResearch_turretTypeNames do
            autoResearch_typesCache.turrets[i] = autoResearch_typesCheckBoxes[i].element.checked
        end
        -- restore selected system types
        local checkBox
        for i = 1, #autoResearch_systemTypeNames do
            checkBox = autoResearch_typesCheckBoxes[i]
            checkBox.caption = autoResearch_systemTypeNames[i]
            checkBox.element.caption = checkBox.caption
            checkBox.element.visible = true
            if not autoResearch_typesCache.systems[i] then
                allStatus = false
            end
            checkBox.element:setCheckedNoCallback(autoResearch_typesCache.systems[i])
        end
        for i = #autoResearch_systemTypeNames + 1, #autoResearch_typesCheckBoxes do
            autoResearch_typesCheckBoxes[i].element.visible = false
        end
        autoResearch_allTypesCheckBox:setCheckedNoCallback(allStatus)
    end
end

function ResearchStation.autoResearch_finishInitUI()
    if autoResearch_settingsReceived and autoResearch_typesRect then
        local scrollFrame = window:createScrollFrame(autoResearch_typesRect)
        scrollFrame.scrollSpeed = 40
        local lister = UIVerticalLister(Rect(0, 0, autoResearch_typesRect.width, autoResearch_typesRect.height), 10, 10)
        lister.marginRight = 30
        local rect = lister:placeCenter(vec2(lister.inner.width, 26))
        autoResearch_allTypesCheckBox = scrollFrame:createCheckBox(Rect(rect.lower, rect.upper + vec2(0, -1)), "All"%_t, "autoResearch_selectAllTypes")
        autoResearch_allTypesCheckBox.fontSize = 11
        autoResearch_allTypesCheckBox.captionLeft = false
        autoResearch_allTypesCheckBox:setCheckedNoCallback(true)
        local line = scrollFrame:createLine(vec2(rect.lower.x, rect.upper.y), rect.upper)
        local linesAmount = math.max(#autoResearch_systemTypeNames, #autoResearch_turretTypeNames)
        local checkBox
        autoResearch_typesCheckBoxes = {}
        for i = 1, linesAmount do
            rect = lister:placeCenter(vec2(lister.inner.width, 25))
            checkBox = scrollFrame:createCheckBox(rect, "", "autoResearch_onTypeCheckBox")
            checkBox.fontSize = 11
            checkBox.captionLeft = false
            checkBox:setCheckedNoCallback(true)
            autoResearch_typesCheckBoxes[i] = { element = checkBox }
        end
    end
end

function ResearchStation.autoResearch_onTypeCheckBox(checkBox)
    if not checkBox.checked then
        autoResearch_allTypesCheckBox:setCheckedNoCallback(false)
    else
        local allStatus = true
        local num = autoResearch_type == 0 and #autoResearch_systemTypeNames or #autoResearch_turretTypeNames
        for i = 1, num do
            if not autoResearch_typesCheckBoxes[i].element.checked then
                allStatus = false
                break
            end
        end
        autoResearch_allTypesCheckBox:setCheckedNoCallback(allStatus)
    end
end

function ResearchStation.autoResearch_selectAllTypes(checkBox)
    local checked = checkBox.checked
    local num = autoResearch_type == 0 and #autoResearch_systemTypeNames or #autoResearch_turretTypeNames
    for i = 1, num do
        autoResearch_typesCheckBoxes[i].element:setCheckedNoCallback(checked)
    end
end

function ResearchStation.autoResearch_autoResearchComplete()
    autoResearch_inProcess = false
    autoResearch_autoButton.caption = "Auto Research"%_t
end

function ResearchStation.autoResearch_receiveSettings(systems)
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
    --
    autoResearch_typesCache = { systems = {}, turrets = {} }
    for i = 1, #autoResearch_systemTypeNames do
        autoResearch_typesCache.systems[i] = true
    end
    for i = 1, #autoResearch_turretTypeNames do
        autoResearch_typesCache.turrets[i] = true
    end
    --
    autoResearch_settingsReceived = true
    -- and add them to the combo box
    ResearchStation.autoResearch_finishInitUI()
    ResearchStation.autoResearch_fillSystems()
end


else -- onServer


autoResearch_systemTypeScripts = {
  "arbitrarytcs",
  "batterybooster",
  "cargoextension",
  "civiltcs",
  "defensesystem",
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
autoResearch_playerLocks = {} -- save player index in order to prevent from starting 2 researches at the same time

autoResearch_initialize = ResearchStation.initialize
function ResearchStation.initialize()
    autoResearch_initialize()

    local configOptions = {
      _version = { default = "1.2", comment = "Config version. Don't touch." },
      ConsoleLogLevel = { default = 2, min = 0, max = 4, format = "floor", comment = "0 - Disable, 1 - Errors, 2 - Warnings, 3 - Info, 4 - Debug." },
      FileLogLevel = { default = 2, min = 0, max = 4, format = "floor", comment = "0 - Disable, 1 - Errors, 2 - Warnings, 3 - Info, 4 - Debug." },
      CustomSystems = {
        default = {
          lootrangebooster = { name = "RCN-00 Tractor Beam Upgrade MK ${mark}", extra = { mark = "X " } } -- using Tractor Beam Upgrade as an example
        },
        comment = 'Here you can add custom systems. Format: "systemfilename" = { name = "System Display Name MK-${mark}", extra = { mark = "X" } }. "Extra" table holds additional name variables - just replace them all with "X ".'
      },
      ResearchGroupVolume = { default = 10, min = 5, format = "floor", comment = "Make a slight delay after specified amount of researches to prevent server from hanging." },
      DelayInterval = { default = 1, min = 0.05, comment = "Delay interval in seconds between research batches." }
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
    -- upgrade config
    if AutoResearchConfig._version == "1.1" then
        AutoResearchConfig._version = "1.2"
        isModified = true
        AutoResearchConfig.ResearchGroupVolume = 10
        AutoResearchConfig.DelayInterval = 1
    end
    if isModified then
        Azimuth.saveConfig("AutoResearch", AutoResearchConfig, configOptions)
    end
    AutoResearchLog = Azimuth.logs("AutoResearch", AutoResearchConfig.ConsoleLogLevel, AutoResearchConfig.FileLogLevel)

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

function ResearchStation.autoResearch_getIndices(inventory, rarity, min, max, itemType, selectedTypes, materialType, isAutoFire)
    local items = {}
    local itemIndices = {}
    local grouped
    local researchTime = false
    if itemType == 0 then
        grouped = ResearchStation.autoResearch_getSystemsByRarity(inventory, rarity, selectedTypes)
    else
        grouped = ResearchStation.autoResearch_getTurretsByRarity(inventory, rarity, selectedTypes, materialType, isAutoFire - 1)
    end

    local itemIndex
    for _, group in pairs(grouped) do
        --AutoResearchLog.Debug("getIndices: (min %s) %s => %s ==>> %s", tostring(min), tostring(_), #group, Azimuth.serialize(group))
        if #group >= min then
            itemIndices = {}
            items = {}
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

    --AutoResearchLog.Debug("getIndices - result: %s", Azimuth.serialize(items))
    return items, itemIndices
end

function ResearchStation.autoResearch_getSystemsByRarity(inventory, rarityType, selectedTypes)
    local inventoryItems = inventory:getItemsByType(InventoryItemType.SystemUpgrade)
    local grouped = {}

    local existing, length
    for i, inventoryItem in pairs(inventoryItems) do
        if (inventoryItem.item.rarity.value == rarityType and not inventoryItem.item.favorite)
          and selectedTypes[inventoryItem.item.script] then
            existing = grouped[inventoryItem.item.script]
            if existing == nil then
                grouped[inventoryItem.item.script] = {}
                grouped[inventoryItem.item.script][1] = { item = inventoryItem.item, index = i }
            else
                length = #existing + 1
                existing[length] = { item = inventoryItem.item, index = i }
                if length == 5 then -- no need to search for more, we already have 5 systems
                    return {existing}
                end
            end
        end
    end

    --AutoResearchLog.Debug("Systems: %s", Azimuth.serialize(grouped))
    return grouped
end

function ResearchStation.autoResearch_getTurretsByRarity(inventory, rarityType, selectedTypes, materialType, isAutoFire)
    local inventoryItems = inventory:getItemsByType(InventoryItemType.Turret)
    local turretTemplates = inventory:getItemsByType(InventoryItemType.TurretTemplate)
    for i, inventoryItem in pairs(turretTemplates) do
        inventoryItems[i] = inventoryItem
    end
    local grouped = {}

    local existing, weaponType, materialValue, groupKey, selectedKey
    for i, inventoryItem in pairs(inventoryItems) do
        if (inventoryItem.item.rarity.value == rarityType and not inventoryItem.item.favorite) then
            if isAutoFire == -1 or (isAutoFire == 0 and not inventoryItem.item.automatic) or (isAutoFire == 1 and inventoryItem.item.automatic) then
                weaponType = WeaponTypes.getTypeOfItem(inventoryItem.item)
                materialValue = inventoryItem.item.material.value
                if selectedTypes[weaponType] and (not materialType or materialValue <= materialType) then
                    groupKey = materialValue.."_"..weaponType
                    if not selectedKey or groupKey == selectedKey then
                        existing = grouped[groupKey] -- group by material, no need to mix iron and avorion
                        if existing == nil then
                            grouped[groupKey] = {}
                            existing = grouped[groupKey]
                        end
                        for j = 1, inventoryItem.amount do
                            existing[#existing+1] = { item = inventoryItem.item, index = i }
                        end
                        if not selectedKey and #existing >= 5 then -- we have 5+ of that turret type + material, just focus on these and remove others
                            selectedKey = groupKey
                            grouped = { [selectedKey] = existing }
                        end
                    end
                end
            end
        end
    end
    -- sort groups so low-dps weapons will be researched first
    for materialValue, group in pairs(grouped) do
        table.sort(group, function(a, b) return a.item.dps < b.item.dps end)
    end

    return grouped
end

function ResearchStation.autoResearch_sendSettings()
    invokeClientFunction(Player(callingPlayer), "autoResearch_receiveSettings", AutoResearchConfig.CustomSystems)
end
callable(ResearchStation, "autoResearch_sendSettings")

function ResearchStation.autoResearch_autoResearch(maxRarity, itemType, selectedTypes, materialType, minAmount, maxAmount, separateAutoTurrets)
    maxRarity = tonumber(maxRarity)
    itemType = tonumber(itemType)
    materialType = tonumber(materialType)
    if anynils(maxRarity, itemType, selectedTypes, materialType) then return end
    minAmount = tonumber(minAmount) or 5
    maxAmount = tonumber(maxAmount) or 5
    minAmount = math.min(minAmount, maxAmount)
    maxAmount = math.max(minAmount, maxAmount)

    local buyer, ship, player = getInteractingFaction(callingPlayer, AlliancePrivilege.SpendResources)
    if not player then return end
    if not buyer then
        invokeClientFunction(player, "autoResearch_autoResearchComplete")
        return
    end
    
    if not ResearchStation.interactionPossible(callingPlayer) then
        invokeClientFunction(player, "autoResearch_autoResearchComplete")
        return
    end

    local station = Entity()
    local errors = {}
    errors[EntityType.Station] = "You must be docked to the station to research items."%_T
    errors[EntityType.Ship] = "You must be closer to the ship to research items."%_T
    if not CheckPlayerDocked(player, station, errors) then
        invokeClientFunction(player, "autoResearch_autoResearchComplete")
        return
    end

    if autoResearch_playerLocks[callingPlayer] then -- auto research is already going
        invokeClientFunction(player, "autoResearch_autoResearchComplete")
        return
    end
    autoResearch_playerLocks[callingPlayer] = true
    
    -- Get System Upgrade script path from selectedIndex
    if itemType == 0 then
        local selectedSystems = {}
        for systemType in pairs(selectedTypes) do
            systemType = autoResearch_systemTypeScripts[math.max(1, math.min(#autoResearch_systemTypeScripts, systemType))]
            if systemType then
                selectedSystems["data/scripts/systems/"..systemType..".lua"] = true
            end
        end
        selectedTypes = selectedSystems
    end

    if materialType == -1 then
        materialType = nil
    end

    local inventory = buyer:getInventory() -- get just once
    AutoResearchLog.Debug("Player %i - Research started", callingPlayer)
    local result = deferredCallback(0, "autoResearch_deferred", callingPlayer, inventory, separateAutoTurrets, maxRarity, minAmount, maxAmount, itemType, selectedTypes, materialType, {{},{}})
    if not result then
        AutoResearchLog.Error("Player %i - Failed to defer research", callingPlayer)
        autoResearch_playerLocks[callingPlayer] = nil
        invokeClientFunction(player, "autoResearch_autoResearchComplete")
    end
end
callable(ResearchStation, "autoResearch_autoResearch")

function ResearchStation.autoResearch_stopAutoResearch()
    autoResearch_playerLocks[callingPlayer] = 2 -- mark to stop
end
callable(ResearchStation, "autoResearch_stopAutoResearch")

function ResearchStation.autoResearch_deferred(playerIndex, inventory, separateAutoTurrets, maxRarity, minAmount, maxAmount, itemType, selectedTypes, materialType, skipRarities)
    if AutoResearchLog.isDebug then
        AutoResearchLog.Debug("Player %i - Another iteration: inv %s, separate %s, min %i, max %i, itemtype %i, system %s, material %s, skipRarities %s", playerIndex, tostring(inventory), tostring(separateAutoTurrets), minAmount, maxAmount, itemType, Azimuth.serialize(selectedTypes), tostring(materialType), Azimuth.serialize(skipRarities))
    end

    if not Server():isOnline(playerIndex) then -- someone got bored and left..
        AutoResearchLog.Debug("Player %i - End of research (player offline/away)", playerIndex)
        autoResearch_playerLocks[playerIndex] = nil -- unlock
        return
    end

    local player = Player(playerIndex)

    local items, itemIndices, separateValue, itemsLength
    local separateCounter = 1
    if itemType == 1 and separateAutoTurrets then
        separateCounter = 2
    end
    local timer
    if AutoResearchLog.isDebug then
        timer = HighResolutionTimer()
        timer:start()
    end
    local j = 1
    for i = 1, separateCounter do -- if itemType is turret, research independently 2 times (no auto fire and auto fire)
        separateValue = i
        if not separateAutoTurrets then
            separateValue = 0 -- will turn into -1
        end
        while true do
            if j == AutoResearchConfig.ResearchGroupVolume then -- we need to make a small delay to prevent script from hanging
                goto autoResearch_finish
            end
            if not autoResearch_playerLocks[playerIndex] then
                break -- interrupted by player
            end

            itemsLength = 0
            if not skipRarities[i][RarityType.Petty] then
                items, itemIndices = ResearchStation.autoResearch_getIndices(inventory, RarityType.Petty, minAmount, maxAmount, itemType, selectedTypes, materialType, separateValue)
                itemsLength = #items
                if itemsLength < minAmount then
                    skipRarities[i][RarityType.Petty] = true -- skip this rarity in the future
                end
            end
            if itemsLength < minAmount and not skipRarities[i][RarityType.Common] then
                items, itemIndices = ResearchStation.autoResearch_getIndices(inventory, RarityType.Common, minAmount, maxAmount, itemType, selectedTypes, materialType, separateValue)
                itemsLength = #items
                if itemsLength < minAmount then
                    skipRarities[i][RarityType.Common] = true
                end
            end
            if itemsLength < minAmount and maxRarity >= RarityType.Uncommon and not skipRarities[i][RarityType.Uncommon] then
                items, itemIndices = ResearchStation.autoResearch_getIndices(inventory, RarityType.Uncommon, minAmount, maxAmount, itemType, selectedTypes, materialType, separateValue)
                itemsLength = #items
                if itemsLength < minAmount then
                    skipRarities[i][RarityType.Uncommon] = true
                end
            end
            if itemsLength < minAmount and maxRarity >= RarityType.Rare and not skipRarities[i][RarityType.Rare] then
                items, itemIndices = ResearchStation.autoResearch_getIndices(inventory, RarityType.Rare, minAmount, maxAmount, itemType, selectedTypes, materialType, separateValue)
                itemsLength = #items
                if itemsLength < minAmount then
                    skipRarities[i][RarityType.Rare] = true
                end
            end
            if itemsLength < minAmount and maxRarity >= RarityType.Exceptional and not skipRarities[i][RarityType.Exceptional] then
                items, itemIndices = ResearchStation.autoResearch_getIndices(inventory, RarityType.Exceptional, minAmount, maxAmount, itemType, selectedTypes, materialType, separateValue)
                itemsLength = #items
                if itemsLength < minAmount then
                    skipRarities[i][RarityType.Exceptional] = true
                end
            end
            if itemsLength < minAmount and maxRarity >= RarityType.Exotic and not skipRarities[i][RarityType.Exotic] then
                items, itemIndices = ResearchStation.autoResearch_getIndices(inventory, RarityType.Exotic, minAmount, maxAmount, itemType, selectedTypes, materialType, separateValue)
                itemsLength = #items
                if itemsLength < minAmount then
                    skipRarities[i][RarityType.Exotic] = true
                end
            end

            if itemsLength >= minAmount then
                callingPlayer = playerIndex -- make server think that player invoked usual research
                ResearchStation.research(itemIndices)
                callingPlayer = nil
            else
                break
            end
            j = j + 1
        end
    end
    ::autoResearch_finish::
    if AutoResearchLog.isDebug then
        timer:stop()
        AutoResearchLog.Debug("Iteration took %s", timer.secondsStr)
    end
    if itemsLength < minAmount then -- nothing more to research, end auto research
        AutoResearchLog.Debug("Player %i - End of research", playerIndex)
        autoResearch_playerLocks[playerIndex] = nil -- unlock
        invokeClientFunction(player, "autoResearch_autoResearchComplete")
    else -- continue a bit later
        if autoResearch_playerLocks[playerIndex] and autoResearch_playerLocks[playerIndex] == 2 then -- interrupted by player
            AutoResearchLog.Debug("Player %i - End of research (stopped by player)", playerIndex)
            autoResearch_playerLocks[playerIndex] = nil -- unlock
            invokeClientFunction(player, "autoResearch_autoResearchComplete")
            return
        end
        -- check if player still has good enough relations
        if not ResearchStation.interactionPossible(playerIndex) then
            AutoResearchLog.Debug("Player %i - End of research (bad relations)", playerIndex)
            autoResearch_playerLocks[playerIndex] = nil -- unlock
            invokeClientFunction(player, "autoResearch_autoResearchComplete")
            return
        end
        -- check if player is allowed to research alliance stuff to prevent endless loop
        if not getInteractingFaction(playerIndex, AlliancePrivilege.SpendResources) then
            AutoResearchLog.Debug("Player %i - End of research (no alliance permission / switched a sector)", playerIndex)
            autoResearch_playerLocks[playerIndex] = nil -- unlock
            invokeClientFunction(player, "autoResearch_autoResearchComplete")
            return
        end
        -- if player is not docked, stop immediately or we'll be stuck in a loop
        local errors = {}
        errors[EntityType.Station] = "You must be docked to the station to research items."%_T
        errors[EntityType.Ship] = "You must be closer to the ship to research items."%_T
        if not CheckPlayerDocked(player, Entity(), errors) then
            AutoResearchLog.Debug("Player %i - End of research (not docked)", playerIndex)
            autoResearch_playerLocks[playerIndex] = nil -- unlock
            invokeClientFunction(player, "autoResearch_autoResearchComplete")
            return
        end
        -- continue after a delay
        local result = deferredCallback(AutoResearchConfig.DelayInterval, "autoResearch_deferred", playerIndex, inventory, separateAutoTurrets, maxRarity, minAmount, maxAmount, itemType, selectedTypes, materialType, skipRarities)
        if not result then
            AutoResearchLog.Error("Player %i - Failed to defer research", playerIndex)
            autoResearch_playerLocks[playerIndex] = nil
            invokeClientFunction(player, "autoResearch_autoResearchComplete")
        end
    end
end

if not ResearchStation.updateServer then -- fixing deferredCallback
    function ResearchStation.updateServer() end
end


end