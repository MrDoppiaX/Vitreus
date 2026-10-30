-- Settings > Theme > Pin widgets: the desktop widgets that come with a theme, which are on and where they are. With the switch on, the theme in use
-- keeps the widgets as they are now; choosing a theme that has them puts them back as they were (each one shown or hidden, on its cell and monitor), and
-- leaving it keeps them as they were left, so moving a widget while the theme is in use is remembered too. A theme with none leaves the widgets alone,
-- as before. Nothing is pinned until someone pins it.
--   The widgets: the clock, the system monitor, the calendar and the reminders (their own scenes, asked and told over their sockets, as Settings >
--   Widgets and the desktop editor do), and the audio visualiser (the bottom edge, Vitreus's own `fw_on`). The webcam is left out on purpose: a
--   theme switch never turns a camera on. Sticky notes are what is written on them, not a widget to place.
--   Kept in theme-widgets.json in the data folder: { [theme id] = { [scene] = { [fact or text] = value }, fw_on = bool } }.
--   A widget's monitor is kept by its name (`mon_name`, `cal_mon_name`, `rem_mon_name`). A pinned monitor that is not plugged in when the theme is
--   chosen is left out: each widget only takes a name it has among its monitors, so the widget stays on the monitor it is on, at its pinned cell (on
--   that monitor's grid), shown or hidden as pinned. Plugged in again, the next time the theme is chosen it goes back there.
--   What is kept is brought up to date when the widgets change (the desktop editor closed, a widget switched or sent to another monitor from Settings >
--   Widgets, the launcher or the editor's tiles) and when the theme is left: nothing runs while nothing changes.
-- `w`: what vitreus.luau lends it, as functions (see CLAUDE.md): theme() the theme in use, its id and name; start(scene dir) starts a widget's scene.
return function(w)
    local FILE = "theme-widgets.json"
    -- Each scene, and the facts (and texts: the monitors' names) that say whether it is shown and where, written in this order: the monitor, the place,
    -- then shown.
    local WIDGETS = {
        { scene = "desktopclock", shown = { "shown" }, facts = { "mon_name", "where", "gx", "gy", "shown" } },
        { scene = "desktopsysmon", shown = { "shown" }, facts = { "mon_name", "where", "gx", "gy", "shown" } },
        { scene = "desktopcards", shown = { "cal_shown", "rem_shown" }, facts = { "cal_mon_name", "cal_gx", "cal_gy", "rem_mon_name", "rem_gx", "rem_gy", "cal_shown", "rem_shown" } },
    }
    local TEXTS = { mon_name = true, cal_mon_name = true, rem_mon_name = true, widget_place = true }
    -- And the add-ons' desktop widgets (`[widget]` in their addon.toml), the ones running now: shown or not (`widget_shown`) and where, in the add-on's own words
    -- (`widget_place`, a text it gives and takes back). An add-on is never started from here: it runs while its switch is on.
    local function widgets()
        local out = {}
        for _, wd in ipairs(WIDGETS) do out[#out + 1] = wd end
        for _, a in ipairs(w.addons and w.addons() or {}) do
            out[#out + 1] = { scene = a.sock, shown = { "widget_shown" }, facts = { "widget_place", "widget_shown" }, addon = true }
        end
        return out
    end
    local pins = {}
    local last = nil                 -- the theme the widgets were last put up for (what is kept when it is left)

    local ok, saved = pcall(sys.ask, "files.read", FILE, "json")
    if ok and type(saved) == "table" then
        for id, snap in pairs(saved) do
            if type(id) == "string" and type(snap) == "table" then pins[id] = snap end
        end
    end
    local function save() pcall(sys.call, "files.write", FILE, pins) end
    local function same(a, b)
        if type(a) ~= "table" or type(b) ~= "table" then return a == b end
        for k, v in pairs(a) do if not same(v, b[k]) then return false end end
        for k in pairs(b) do if a[k] == nil then return false end end
        return true
    end
    local function say(scene, cmds, done)
        local args = { "--say", scene }
        for _, c in ipairs(cmds) do args[#args + 1] = c end
        run("pleamar", args, function(out, code) if done then done(out, code) end end)
    end
    local function fw() return fact.fw_on == true or fact.fw_on == 1 end
    local function value(s)
        s = (s or ""):match("^%s*(.-)%s*$")
        if s == "true" then return true elseif s == "false" then return false end
        return tonumber(s) or s
    end

    -- How many of them a snapshot has on the desktop.
    local function count(snap)
        local n = snap.fw_on and 1 or 0
        for _, wd in ipairs(widgets()) do
            local s = snap[wd.scene]
            if type(s) == "table" then for _, k in ipairs(wd.shown) do if s[k] == true then n = n + 1 end end end
        end
        return n
    end

    -- The row on the Theme page.
    local function show()
        local id, name = w.theme()
        if not id then return end
        if not last then last = id end
        local p = pins[id]
        fact.twg_on = p ~= nil
        if p then
            local n = count(p)
            text.twg_sub = n == 1 and "1 widget kept" or (n .. " widgets kept")
        else
            text.twg_sub = "Off"
        end
    end

    -- The widgets as they are now: each scene is asked for its facts (one line each). A scene that does not answer has nothing shown, unless `prev`
    -- (the theme's last snapshot) has it: a widget's scene reloads when the theme rewrites the palette, and one caught reloading keeps what it had.
    local function snapshot(prev, done, quick)
        local snap = { fw_on = fw() }
        local list = widgets()
        local left = #list
        -- an add-on that is off now keeps what it had (it is put back once it is on again)
        if prev then
            for k, v in pairs(prev) do
                if k ~= "fw_on" and type(v) == "table" then
                    local here = false
                    for _, wd in ipairs(list) do if wd.scene == k then here = true end end
                    if not here then snap[k] = v end
                end
            end
        end
        for _, wd in ipairs(list) do
            local cmds = {}
            for _, k in ipairs(wd.facts) do cmds[#cmds + 1] = "get " .. k end
            local tries = 0
            local function ask()
                say(wd.scene, cmds, function(out, code)
                    -- "? the render does not answer": the scene is busy (reloading with a new palette, or drawing a heavy frame); asked again a few times
                    local busy = code == 0 and (out == nil or out:find("?", 1, true) ~= nil)
                    if busy and not quick and tries < 4 then tries = tries + 1; after(700, ask) return end
                    local s = {}
                    if code == 0 and not busy then
                        local i = 0
                        for line in (out .. "\n"):gmatch("([^\n]*)\n") do
                            i = i + 1
                            local k = wd.facts[i]
                            if not k then break end
                            local v = value(line)
                            if v ~= "" then s[k] = v end
                        end
                    elseif prev and type(prev[wd.scene]) == "table" then
                        s = prev[wd.scene]        -- not running, or never answered: what it had (a scene caught restarting keeps its place)
                    end
                    for _, k in ipairs(wd.shown) do if s[k] == nil then s[k] = false end end
                    snap[wd.scene] = s
                    left = left - 1
                    if left == 0 then done(snap) end
                end)
            end
            ask()
        end
    end

    -- Put a snapshot back: a widget that should be shown is started if its scene is not running, then given its place and shown; one that should not
    -- be is hidden (a scene that is not running is already hidden).
    local function restore(snap)
        for _, wd in ipairs(widgets()) do
            local s = snap[wd.scene]
            if type(s) == "table" then
                local want = false
                for _, k in ipairs(wd.shown) do if s[k] == true then want = true end end
                local cmds = {}
                for _, k in ipairs(wd.facts) do
                    if TEXTS[k] then
                        if type(s[k]) == "string" and s[k] ~= "" then cmds[#cmds + 1] = "text " .. k .. " " .. s[k] end       -- (a name the widget has not got is ignored by it)
                    elseif s[k] ~= nil then
                        cmds[#cmds + 1] = "fact " .. k .. " " .. tostring(s[k])
                    end
                end
                local tries = 0
                local function go()
                    say(wd.scene, { "get " .. wd.shown[1] }, function(out, code)
                        if code == 0 and (out or ""):find("?", 1, true) and tries < 4 then tries = tries + 1; after(700, go) return end     -- busy: again in a moment
                        if code == 0 then
                            -- a widget that is running slides to its place: `glide` first, the place once the slower spring has taken over, and back
                            local all = { "fact glide true" }       -- (first, in the same message: the slower spring takes over before the place changes)
                            for _, c in ipairs(cmds) do all[#all + 1] = c end
                            say(wd.scene, all, function()
                                after(2600, function() say(wd.scene, { "fact glide false" }) end)
                            end)
                        elseif want and not wd.addon then
                            w.start(wd.scene)
                            after(2500, function() say(wd.scene, cmds) end)
                        end
                    end)
                end
                go()
            end
        end
        if type(snap.fw_on) == "boolean" and snap.fw_on ~= fw() then say("vitreus", { "emit fw_toggle" }) end
    end

    -- The switch: on keeps the widgets as they are now for the theme in use; off lets it go back to leaving them alone.
    on("twg_toggle", function()
        local id = w.theme()
        if not id then return end
        if pins[id] then
            pins[id] = nil
            save()
            show()
        else
            snapshot(nil, function(snap)
                pins[id] = snap
                last = id
                save()
                show()
            end)
        end
    end)

    -- When the widgets change, the theme in use keeps them as they are now: once, three seconds after the last change (a widget being started takes about
    -- two and a half). Not in the seconds after a theme switch, when the widgets are being put back. The changes: the desktop editor closed
    -- (`widgets_changed`, from desktopedit: what was moved or switched there), and the switches and monitors of Settings > Widgets, the launcher and the
    -- editor's tiles, which all come through Vitreus.
    local quiet_until = 0
    local due = 0
    local function changed()
        due = due + 1
        local mine = due
        after(3000, function()
            local id = last
            if mine ~= due or not id or not pins[id] or os.time() < quiet_until then return end
            snapshot(pins[id], function(snap) if last == id and pins[id] and not same(snap, pins[id]) then pins[id] = snap; save(); show() end end)
        end)
    end
    for _, ev in ipairs({ "widgets_changed", "dclock_toggle", "dsys_toggle", "fw_toggle", "ck_toggle", "sy_toggle", "ck_mon_set", "sy_mon_set" }) do
        on(ev, changed)
    end

    -- A card on the Theme page: the theme being left keeps its widgets as they are (if it has them pinned: asked at once, before the widgets reload
    -- with the new palette), then the new one's are put back once they are back (as `push_look` tells them the look again, a moment later).
    on("theme_pick", function()
        local id = w.theme()                 -- (vitreus.luau's handler has already set it)
        local from = last
        last = id
        show()
        if not id or id == from then return end
        quiet_until = os.time() + 8
        -- at once: the theme being left is looked at first (asked once, no waiting on a busy widget: one that does not answer keeps what it had),
        -- then the new one's widgets set off; and once more a few seconds later, for a widget that was reloading with the new palette the first time
        local function arrive()
            if not pins[id] then return end
            restore(pins[id])
            after(4000, function() if last == id and pins[id] then restore(pins[id]) end end)
        end
        if from and pins[from] then
            local keep = from
            snapshot(pins[keep], function(snap)
                if pins[keep] then pins[keep] = snap; save() end
                if last == id then arrive() end
            end, true)
        else
            arrive()
        end
    end)
    on("themes_refresh", function() after(800, show) end)
    on("fact:set_page", show)
    after(1500, show)          -- once the themes have been read
end
