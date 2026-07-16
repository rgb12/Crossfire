SoundQueuer = {}

---@enum SoundQueuerTarget
SoundQueuer.target = {
    COALITION = 0,
    GROUP = 1,
    UNIT = 2,
    ALL = 3
}

---@class SoundData
---@field sound string
---@field target SoundQueuerTarget
---@field target_id number|nil
---@field duration number
---@field tstart number|nil
---@field interval number|nil

---@type SoundData[]
SoundQueuer.sounds = {}

---@class SoundTransmission
---@field sound string
---@field target SoundQueuerTarget
---@field target_id number|nil
---@field duration number
---@field Tplay number
---@field interval number
---@field isplaying boolean
---@field Tstarted number|nil

SoundQueuer.default_duration = 1.5
SoundQueuer.default_gap = 0.12
SoundQueuer.dt = 0.05
---@type table<string, number>
SoundQueuer.sound_lengths = {}

---@param sound string
---@param seconds number
function SoundQueuer:setDuration(sound, seconds)
    if not sound or type(seconds) ~= "number" or seconds <= 0 then return end
    SoundQueuer.sound_lengths[sound] = seconds
end

---@param map table<string, number>
function SoundQueuer:setDurations(map)
    if not map then return end
    for sound, seconds in pairs(map) do
        SoundQueuer:setDuration(sound, seconds)
    end
end

---@param sound any
---@param time_to_play number
---@param point vec3
---@param modulation radio.modulation
---@param frequency number
---@param power number
---@param tx_name string|nil unique transmission name to prevent collisions
local function scheduleTransmission(sound,time_to_play,point,modulation,frequency, power,tx_name)

    --env.info(string.format("SoundQueuer schedule: %s (in %.2fs)", tostring(sound), time_to_play - timer.getTime()))

    timer.scheduleFunction(function()
        trigger.action.radioTransmission(sound, point,modulation,false,frequency, power,tx_name)
        --trigger.action.outSound(sound)

    end, nil, time_to_play)
end

---@param sounds string[]
function SoundQueuer:enqueueSequence(sounds,point, modulation, frequency, power,loop,start_delay)
    if not sounds or #sounds == 0 then
        return
    end

    local initial_delay = 3
    if start_delay and start_delay >= 0 then
        initial_delay = start_delay
    end

    -- Generate a unique sequence ID to prevent transmission collisions
    SoundQueuer.seq_counter = (SoundQueuer.seq_counter or 0) + 1
    local seq_id = string.format("SQ_%d_%d", math.floor(timer.getTime() * 1000), SoundQueuer.seq_counter)

    local wait = timer.getTime()+initial_delay+5 -- don't remove the +1, it solved the first sound not playing
    
    for i, sound in ipairs(sounds) do
        local duration = self.sound_lengths[sound] or SoundQueuer.default_duration

        -- Format the unique tx_name and pass it to scheduleTransmission
        local tx_name = string.format("%s_%03d", seq_id, i)
        scheduleTransmission(sound,wait,point,modulation,frequency,power, tx_name)
        
        wait = wait + duration + SoundQueuer.default_gap
    end
    
    if loop then
        timer.scheduleFunction(function ()
            -- Explicitly pass 0 as the start_delay to prevent the initial_delay from stacking on every loop
            SoundQueuer:enqueueSequence(sounds,point, modulation, frequency, power,loop, 0)
        end,nil,wait+5)
    end
end