-- This file allows to add Auto Research support for system upgrade entries.

local customSystems = {}

local function addSystemUpgrade(scriptName, systemName, extraArguments)
    customSystems[scriptName] = { name = systemName, extra = extraArguments }
end

--[[ Example:
-- System upgrade with a simple name.
addSystemUpgrade("energybooster", "Generator Upgrade")
-- System upgrade with a complex name. Just replace all these 'num's and 'mark's with something general like "X ".
addSystemUpgrade("arbitrarytcs", "Turret Control System A-TCS-${num}", {num = "X "})
]]

return customSystems