---@meta

---@class Airbase: CoalitionObject
---@field id_ integer
Airbase = {}
---@enum Airbase.Category
Airbase.Category = {
    AIRDROME = 0,
    HELIPAD = 1,
    SHIP = 2,
}

---Returns a localized string of the airbases's callsign.<br>
---In the case of airbases, the callsign of world airbases is defined by the game. Callsigns for units, farps, or ships can be specified by the user with the mission editor or scripting engine.
---@return string
function Airbase:getCallsign() end

function Airbase:getRunways() end

---@param name string
---@return Airbase|nil
function Airbase.getByName(name) end

---@return Airbase.Category
function Airbase:getCategory() end

---@return table
function Airbase:getWarehouse() end

---@param setting boolean
function Airbase:autoCapture(setting) end

---@param coalition coalition.side
function Airbase:setCoalition(coalition) end