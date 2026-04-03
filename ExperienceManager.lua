ExperienceManager = {}
do
    ExperienceManager.EventHandler = {}

    ---@class UserData
    ---@field name string
    ---@field id number
    ---@field xp number
    ---@field missions_completed number
    ---@field tokens number
    ---@field rank string
    ---@field unclaimed_tokens number
    ---@field unclaimed_xp number

    ---@type UserData[]
    ExperienceManager.user_data = {}

    ExperienceManager.airbone_users = {}

    function ExperienceManager.EventHandler:onEvent(event)
        if not Config.reward_system.enable then return end

        if event.id == world.event.S_EVENT_KILL then
            -- Adds XP to the player who made the kill
            local target = event.target
            local initiator = event.initiator
            if target and initiator and initiator.getPlayerName and initiator:getPlayerName()
            and target.getCoalition and initiator:getCoalition() then
                
                local user = ExperienceManager:fetchUser(initiator)
                if not user then return end

                -- Checks if target is not friendly
                if target:getCoalition() == initiator:getCoalition() then
                    trigger.action.outTextForUnit(user.id,"Fatricide, hold fire!",10)
                    ExperienceManager:redXP(user,Config.reward_system.xp_lost_per_kill_fatricide)
                    MissionLogger:info("Fratricide committed!: "..user.name)
                    return
                end

                if target:hasAttribute('Planes') then
                    trigger.action.outTextForUnit(user.id,"Aircraft destroyed, +" .. Config.reward_system.xp_per_aircraft_destroyed .. "XP",5)
                    user.unclaimed_xp = user.unclaimed_xp + Config.reward_system.xp_per_aircraft_destroyed
                elseif target:hasAttribute('Helicopters') then
                    trigger.action.outTextForUnit(user.id,"Helicopter destroyed, +" .. Config.reward_system.xp_per_helicopter_destroyed .. "XP",5)
                    user.unclaimed_xp = user.unclaimed_xp + Config.reward_system.xp_per_helicopter_destroyed
                elseif target:hasAttribute('Infantry') then
                    trigger.action.outTextForUnit(user.id,"Infantry kill, +" .. Config.reward_system.xp_per_infantry_kill .. "XP",5)
                    user.unclaimed_xp = user.unclaimed_xp + Config.reward_system.xp_per_infantry_kill
                elseif (target:hasAttribute('SAM SR') or target:hasAttribute('SAM TR') or target:hasAttribute('IR Guided SAM')) then
                    trigger.action.outTextForUnit(user.id,"SAM unit kill, +" .. Config.reward_system.xp_per_sam_destroyed .. "XP",5)
                    user.unclaimed_xp = user.unclaimed_xp + Config.reward_system.xp_per_sam_destroyed
                elseif target:hasAttribute('Ships') then
                    trigger.action.outTextForUnit(user.id,"Ship destroyed, +" .. Config.reward_system.xp_per_ship_sunk .. "XP",5)
                    user.unclaimed_xp = user.unclaimed_xp + Config.reward_system.xp_per_ship_sunk
                elseif target:hasAttribute('Ground Units') then
                    trigger.action.outTextForUnit(user.id,"Vehicle destroyed, +" .. Config.reward_system.xp_per_vehicle_destroyed .. "XP",5)
                    user.unclaimed_xp = user.unclaimed_xp + Config.reward_system.xp_per_vehicle_destroyed
                else return end
            end
        elseif event.id == world.event.S_EVENT_TAKEOFF then
            if event.initiator and event.initiator.getPlayerName and event.initiator:getPlayerName() then
                local player_name=event.initiator:getPlayerName()
                ExperienceManager.airbone_users[player_name] = {
                    take_off_time = timer.getTime()
                }
                MissionLogger:info("USER: "..player_name .. " took off")
            end
        elseif event.id == world.event.S_EVENT_LAND then
            if event.initiator and event.initiator.getPlayerName and event.initiator:getPlayerName() then

                local unit_name = event.initiator:getName()
                local player_name = event.initiator:getPlayerName()
                local now = timer.getTime()
                local airborne_user = ExperienceManager.airbone_users[player_name]
                local airtime = 0
                if airborne_user then
                    airtime = now - (airborne_user.take_off_time or now)
                    ExperienceManager.airbone_users[player_name] = nil
                end
                local airtime_xp_bonus = 0
                if airtime > 20*60 then
                    if airtime < 30*60 then
                        airtime_xp_bonus = 200
                    elseif airtime < 40*60 then
                        airtime_xp_bonus = 400
                    elseif airtime < 50*60 then
                        airtime_xp_bonus = 600
                    elseif airtime < 60*60 then
                        airtime_xp_bonus = 900
                    elseif airtime >= 60*60 then
                        airtime_xp_bonus = 200 * math.floor(airtime/(600))
                    end
                end
                timer.scheduleFunction(function()
                    
                    local unit_check = Unit.getByName(unit_name)
                    if unit_check and unit_check:isExist() and unit_check:getLife() > 0 and unit_check.getCoalition then
                        local user = ExperienceManager:fetchUser(unit_check)
                        if not user then return end

                        MissionLogger:info("USER: "..player_name .. " landed, time airborne: "..airtime..",    mission XP: "..user.unclaimed_xp .. "     , airtime bonus XP: "..airtime_xp_bonus)
                        
                        if user.unclaimed_xp>0 or airtime_xp_bonus>0 then
                            local u_id = unit_check:getID()
                            trigger.action.outTextForUnit(u_id, "Post-Flight Debrief: +".. user.unclaimed_xp+airtime_xp_bonus .. " XP",10)
                            trigger.action.outSoundForUnit(u_id,"radio click.ogg")
                            
                            ExperienceManager:addXP(user, user.unclaimed_xp+airtime_xp_bonus) -- checks for rank up
                            user.unclaimed_xp = 0
                        end
                    end
                end, {}, timer.getTime() + Config.reward_system.landing_time)


            end
        end

    end

    ---@param unit Unit
    function ExperienceManager:addUser(unit)
        if not Config.reward_system.enable then return end
        if not (unit.getPlayerName and unit:getPlayerName()) then return end

        local user_name = unit:getPlayerName()
        local user_id = unit:getID()

        if not ExperienceManager.user_data[user_name] then
            ExperienceManager.user_data[user_name] = {
                name = user_name,
                id = user_id,
                xp = 0,
                unclaimed_xp = 0,
                missions_completed = 0,
                tokens = 0,
                unclaimed_tokens = 0,
                rank = Config.reward_system.ranks[1].name,
            }
        else
            -- Update runtime ID when player rejoins
            ExperienceManager.user_data[user_name].id = user_id
        end
    end

    ---@param unit Unit
    function ExperienceManager:delUser(unit)
        if not (unit.getPlayerName and unit:getPlayerName()) then return end
        local user_name = unit:getPlayerName()
        ExperienceManager.user_data[user_name] = nil
    end

    ---@param unit Unit
    ---@return UserData|nil
    function ExperienceManager:fetchUser(unit)
        if not Config.reward_system.enable then return nil end
        if not (unit.getPlayerName and unit:getPlayerName()) then return nil end
        local user_name = unit:getPlayerName()
        return ExperienceManager.user_data[user_name]
    end

    ---@param user UserData
    ---@param amount number
    ---@return boolean
    function ExperienceManager:addXP(user, amount)
        if user then
            user.xp = user.xp + amount
            -- check for rank up
            local new_rank = ExperienceManager:getRankfromXP(user.xp)
            MissionLogger:info(user.rank.. " -> "..new_rank)
            if new_rank ~= user.rank then
                user.rank = new_rank

                trigger.action.outSoundForUnit(user.id,"rank_up.ogg")
                trigger.action.outTextForUnit(user.id,"Rank Up! New Rank: " .. new_rank.."",10)
            end
            return true
        end
        return false
    end

    --- Remove XP from user
    ---@param user UserData
    ---@param amount number
    ---@return boolean
    function ExperienceManager:redXP(user,amount)
        if user then
            user.xp = math.max(user.xp - amount,0)
            -- check for rank down
            local new_rank = ExperienceManager:getRankfromXP(user.xp)
            MissionLogger:info(user.rank.. " -> "..new_rank)
            if new_rank ~= user.rank then
                user.rank = new_rank
            end
            return true
        end
        return false
    end

    ---@param xp number
    ---@return string
    function ExperienceManager:getRankfromXP(xp)
        local rank_name = Config.reward_system.ranks[1].name
        for i = #Config.reward_system.ranks, 1, -1 do
            local rank = Config.reward_system.ranks[i]
            if xp >= rank.xp_required then
                rank_name = rank.name
                break
            end
        end
        return rank_name
    end

    ---@param rank_name string
    ---@return number
    function ExperienceManager:getRequiredXPfromRank(rank_name)
        for i = #Config.reward_system.ranks, 1, -1 do
            local rank = Config.reward_system.ranks[i]
            if rank.name == rank_name then
                return rank.xp_required
            end
        end
        return 0
    end

    --- Called by PersistenceManager to overwrite/merge loaded data
    function ExperienceManager:restoreUserData(data)
        if not Config.reward_system.enable then return end
        if not data then return end
        -- Merge loaded data. We overwrite existing keys.
        for playerName, userData in pairs(data) do
            ExperienceManager.user_data[playerName] = userData
            ExperienceManager.user_data[playerName].unclaimed_xp = 0
            ExperienceManager.user_data[playerName].unclaimed_tokens = 0
            -- ID will be updated when player joins (addUser)
            ExperienceManager.user_data[playerName].id = nil
        end
        MissionLogger:info("User data restored for " .. #data .. " users.")
    end

end