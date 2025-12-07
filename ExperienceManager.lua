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

    ExperienceManager.user_data = {}

    function ExperienceManager.EventHandler:onEvent(event)
        if not Config.reward_system.enable then return end

        if event.id == world.event.S_EVENT_PLAYER_ENTER_UNIT then
            if event.initiator and event.initiator.getPlayerName then

                ExperienceManager:addUser(event.initiator)
                local group = event.initiator:getGroup()
                if not group then return end
                local group_id = group:getID()
                missionCommands.addCommandForGroup(group_id, "XP/Rank", nil, function()
                    local user = ExperienceManager:fetchUser(event.initiator)
                    if user then
                        local rank_name = "Unranked"
                        local next_rank_xp = 999999
                        local next_rank = "..."
                        for i = #Config.reward_system.ranks, 1, -1 do
                            local rank = Config.reward_system.ranks[i]
                            if user.xp >= rank.xp_required then
                                rank_name = rank.name
                                if i < #Config.reward_system.ranks then
                                    next_rank_xp = Config.reward_system.ranks[i + 1].xp_required
                                    next_rank = Config.reward_system.ranks[i + 1].name
                                end
                                break
                            end
                        end
                        local out_text = string.format("/*/*/*/ User Stats /*/*/*/\n> Rank: %s\n\n> Tokens: %d (+%d)\n> XP: %d (+%d)\n> Missions Completed: %d\n\n> Next Rank: %s\n  %s XP",
                            rank_name, user.tokens, user.unclaimed_tokens, user.xp, user.unclaimed_xp, user.missions_completed, next_rank, next_rank_xp)
                        trigger.action.outTextForGroup(group_id, out_text, 15)
                    end
                end)

                CommandHandler.initTaskingRequests(group)
                CommandHandler.resourcesRequests(group)
            end

        elseif event.id == world.event.S_EVENT_KILL then
            -- Adds XP to the player who made the kill
            local target = event.target
            local initiator = event.initiator
            if target and initiator.getPlayerName and initiator then
                
                local user = ExperienceManager:fetchUser(initiator)
                if not user then return end

                local tokens_added = 0

                if target:hasAttribute('Planes') then
                    trigger.action.outTextForUnit(user.id,"Aircraft destroyed, +" .. Config.reward_system.xp_per_aircraft_destroyed .. "XP",5)
                    user.unclaimed_xp = user.unclaimed_xp + Config.reward_system.xp_per_aircraft_destroyed
                    tokens_added = tokens_added + math.random(0,2)
                elseif target:hasAttribute('Helicopters') then
                    trigger.action.outTextForUnit(user.id,"Helicopter destroyed, +" .. Config.reward_system.xp_per_helicopter_destroyed .. "XP",5)
                    user.unclaimed_xp = user.unclaimed_xp + Config.reward_system.xp_per_helicopter_destroyed
                    tokens_added = tokens_added + math.random(0,1)
                elseif target:hasAttribute('Infantry') then
                    trigger.action.outTextForUnit(user.id,"Infantry kill, +" .. Config.reward_system.xp_per_infantry_kill .. "XP",5)
                    user.unclaimed_xp = user.unclaimed_xp + Config.reward_system.xp_per_infantry_kill

                elseif (target:hasAttribute('SAM SR') or target:hasAttribute('SAM TR') or target:hasAttribute('IR Guided SAM')) then
                    trigger.action.outTextForUnit(user.id,"SAM unit kill, +" .. Config.reward_system.xp_per_sam_destroyed .. "XP",5)
                    user.unclaimed_xp = user.unclaimed_xp + Config.reward_system.xp_per_sam_destroyed
                    tokens_added = tokens_added + math.random(0,1)
                elseif target:hasAttribute('Ships') then
                    trigger.action.outTextForUnit(user.id,"Ship destroyed, +" .. Config.reward_system.xp_per_ship_sunk .. "XP",5)
                    user.unclaimed_xp = user.unclaimed_xp + Config.reward_system.xp_per_ship_sunk
                    tokens_added = tokens_added + 3
                elseif target:hasAttribute('Ground Units') then
                    trigger.action.outTextForUnit(user.id,"Vehicle destroyed, +" .. Config.reward_system.xp_per_vehicle_destroyed .. "XP",5)
                    user.unclaimed_xp = user.unclaimed_xp + Config.reward_system.xp_per_vehicle_destroyed
                    tokens_added = tokens_added + math.random(0,1)
                elseif target:hasAttribute('Buildings') then
                    trigger.action.outTextForUnit(user.id,"Structure destroyed, +" .. Config.reward_system.xp_per_structure_destroyed .. "XP",5)
                    user.unclaimed_xp = user.unclaimed_xp + Config.reward_system.xp_per_structure_destroyed
                    tokens_added = tokens_added + 2
                else return end

                if tokens_added > 0 then
                    user.unclaimed_tokens = user.unclaimed_tokens + tokens_added
                    trigger.action.outTextForUnit(user.id,"+" .. tokens_added .. " Tokens",5)
                end
            end
        elseif event.id == world.event.S_EVENT_LAND then
            if event.initiator and event.initiator.getPlayerName then
                
                local user = ExperienceManager:fetchUser(event.initiator)
                if not user then return end
                local unit_name = event.initiator:getName()

                timer.scheduleFunction(function()
              
                    local unit_check = Unit.getByName(unit_name)
                    if unit_check and unit_check:isExist() and unit_check:getLife() > 0 and unit_check.getCoalition then
                        local user = ExperienceManager:fetchUser(unit_check)
                        if user and (user.unclaimed_xp>0 or user.unclaimed_tokens>0)then
                            ExperienceManager:addXP(user, user.unclaimed_xp) -- to check for rank up
                            user.tokens = user.tokens + user.unclaimed_tokens
                            


                            local out_text = "> "
                            if user.unclaimed_xp > 0 then
                                out_text = out_text .. " +" .. user.unclaimed_xp .. " XP"
                            end
                            if user.unclaimed_tokens > 0 then
                                out_text = out_text .. " +" .. user.unclaimed_tokens .. " Tokens"
                            end

                            trigger.action.outTextForCoalition(unit_check:getCoalition(), out_text,10)
                            user.unclaimed_xp = 0
                            user.unclaimed_tokens = 0
                        end
                    end
                end, {}, timer.getTime() + Config.reward_system.landing_time)


            end
        end

    end

    ---@param unit Unit
    function ExperienceManager:addUser(unit)
        if not Config.reward_system.enable then return end
        if not unit.getPlayerName then return end

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
        if not unit.getPlayerName then return end
        local user_name = unit:getPlayerName()
        ExperienceManager.user_data[user_name] = nil
    end

    ---@param unit Unit
    ---@return UserData|nil
    function ExperienceManager:fetchUser(unit)
        if not Config.reward_system.enable then return nil end
        if not unit.getPlayerName then return nil end
        local user_name = unit:getPlayerName()
        return ExperienceManager.user_data[user_name]
    end

    function ExperienceManager:addTokens(unit, amount)
        local user = ExperienceManager:fetchUser(unit)
        if user then
            user.tokens = user.tokens + amount
        end
    end

    function ExperienceManager:deductTokens(unit, amount)
        local user = ExperienceManager:fetchUser(unit)
        if user then
            user.tokens = math.max(0, user.tokens - amount)
        end
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
                local tokens_awarded = math.max(0, Config.reward_system.tokens_on_rank_up + math.random(-Config.reward_system.tokens_on_rank_up_variance, Config.reward_system.tokens_on_rank_up_variance))
                user.tokens = user.tokens + tokens_awarded

                trigger.action.outSoundForUnit(user.id,"rank_up.ogg")
                trigger.action.outTextForUnit(user.id,"Rank Up! New Rank: " .. new_rank..", +" .. tokens_awarded .. " Tokens",10)
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