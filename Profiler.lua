-- Profiler.lua
--
-- A minimal, self-contained performance profiler for the Crossfire framework.
--
-- It works by monkey-patching timer.scheduleFunction. Every scheduled callback
-- in DCS runs on the sim's main thread, so a slow callback is a direct cause of
-- stutters. The patch wraps each callback in an os.clock() measurement and
-- buckets the time by the call site that scheduled it (file:line), so the report
-- tells you which scheduler is eating the most CPU per call and per minute.
--
-- HOW TO USE
--   * Load this file FIRST, before any other framework script, so it sees every
--     timer.scheduleFunction call. (Callbacks scheduled before it loads are not
--     tracked, but anything re-scheduled afterwards is.)
--   * In-game: place an F10 map mark with the text  -profile  to print a sorted
--     report on screen and to the DCS log. Use  -profile reset  to zero counters.
--   * The profiler also dumps the top offenders to dcs.log every REPORT_INTERVAL
--     seconds automatically.

Profiler = Profiler or {}

do
    local REPORT_INTERVAL = 60      -- seconds between automatic log dumps
    local TOP_N           = 20      -- how many entries to show in a report
    local ON_SCREEN_SECS  = 30      -- how long the -profile on-screen text stays

    -- stats[key] = { calls, total, max, src }
    local stats = {}
    local started_at = os.clock()

    -- Build a stable bucket key from the call site that scheduled the function.
    -- Level tuning: getinfo(1)=here, (2)=patched scheduleFunction, (3)=caller.
    local function callSite()
        local info = debug and debug.getinfo and debug.getinfo(3, "Sl")
        if not info then return "unknown" end
        local src = info.short_src or info.source or "?"
        return src .. ":" .. tostring(info.currentline or 0)
    end

    local function record(key, elapsed)
        local s = stats[key]
        if not s then
            s = { calls = 0, total = 0, max = 0 }
            stats[key] = s
        end
        s.calls = s.calls + 1
        s.total = s.total + elapsed
        if elapsed > s.max then s.max = elapsed end
    end

    if not Profiler._patched and timer and timer.scheduleFunction then
        local original = timer.scheduleFunction

        ---@diagnostic disable-next-line: duplicate-set-field
        timer.scheduleFunction = function(fn, args, time)
            local key = callSite()
            local wrapped = function(a, t)
                local t0 = os.clock()
                -- A scheduled fn may return a number (next run time) or nil.
                local ok, ret = pcall(fn, a, t)
                local dt = os.clock() - t0
                record(key, dt)
                if not ok then
                    -- Preserve original error behaviour visibility but don't
                    -- swallow the schedule: surface it to the log.
                    if env and env.error then
                        env.error("[Profiler] scheduled fn error @ " .. key .. ": " .. tostring(ret))
                    end
                    return nil
                end
                return ret
            end
            return original(wrapped, args, time)
        end

        Profiler._patched = true
    end

    -- ----- reporting ----------------------------------------------------------
    local function snapshot()
        local rows = {}
        for key, s in pairs(stats) do
            rows[#rows + 1] = {
                key   = key,
                calls = s.calls,
                total = s.total,
                avg   = s.calls > 0 and (s.total / s.calls) or 0,
                max   = s.max,
            }
        end
        table.sort(rows, function(a, b) return a.total > b.total end)
        return rows
    end

    --- Build a formatted report string (top offenders by total CPU time).
    function Profiler.report(top_n)
        top_n = top_n or TOP_N
        local rows = snapshot()
        local window = os.clock() - started_at
        local lines = {}
        lines[#lines + 1] = string.format(
            "=== Profiler report (%.0fs window) — top %d by total CPU ===",
            window, top_n)
        lines[#lines + 1] = string.format(
            "%-42s %7s %9s %9s %9s %9s",
            "call site", "calls", "total_ms", "avg_ms", "max_ms", "ms/min")
        for i = 1, math.min(top_n, #rows) do
            local r = rows[i]
            local per_min = window > 0 and (r.total / window * 60000) or 0
            lines[#lines + 1] = string.format(
                "%-42s %7d %9.1f %9.3f %9.3f %9.1f",
                r.key:sub(-42), r.calls, r.total * 1000, r.avg * 1000,
                r.max * 1000, per_min)
        end
        return table.concat(lines, "\n")
    end

    --- Zero all counters.
    function Profiler.reset()
        stats = {}
        started_at = os.clock()
    end

    local function logReport()
        local text = Profiler.report(TOP_N)
        if env and env.info then env.info(text) end
        return text
    end

    -- ----- in-game trigger: F10 mark with text "-profile" ---------------------
    -- Listen for mark-panel changes so a player can request a report without any
    -- coupling to the menu system. Text "-profile" prints on screen + to log;
    -- "-profile reset" clears counters.
    if world and world.addEventHandler then
        local handler = {}
        function handler:onEvent(event)
            if not event then return end
            if event.id == world.event.S_EVENT_MARK_ADDED
               or event.id == world.event.S_EVENT_MARK_CHANGE then
                local txt = event.text and tostring(event.text):lower() or ""
                if txt:find("^%=profiler") then
                    if txt:find("reset") then
                        Profiler.reset()
                        if trigger and trigger.action then
                            trigger.action.outText("[Profiler] counters reset", 10)
                        end
                    else
                        local text = logReport()
                        if trigger and trigger.action then
                            trigger.action.outText(text, ON_SCREEN_SECS)
                        end
                    end
                end
            end
        end
        world.addEventHandler(handler)
    end

    -- ----- automatic periodic log dump ----------------------------------------
    if timer and timer.scheduleFunction and timer.getTime then
        -- Use the ORIGINAL scheduler indirectly via the patched one; the small
        -- self-measurement cost is negligible and clearly labelled.
        timer.scheduleFunction(function()
            logReport()
            return timer.getTime() + REPORT_INTERVAL
        end, {}, timer.getTime() + REPORT_INTERVAL)
    end

    if env and env.info then
        env.info("[Profiler] loaded — patched timer.scheduleFunction. "
            .. "Use F10 mark '-profile' for a report.")
    end
end
