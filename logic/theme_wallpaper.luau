-- Settings > Theme > Pin wallpaper: a wallpaper of the gallery that comes with a theme. With one pinned, choosing that theme (a card on the Theme
-- page) puts it up too; a theme with none keeps whatever wallpaper is up, as before. Nothing is pinned until someone pins it, so the shell behaves
-- as it always has until then.
--   The switch pins the wallpaper up now to the theme in use (off: unpins it); Change opens a picker over the page (the gallery, every wallpaper in
--   the folder, sixteen at a time) and the one pressed is pinned and put up.
--   Kept in theme-wallpapers.json in the data folder: { [theme id] = path }.
-- `w`: what vitreus.luau lends it, as functions, since a module reads the shell's own state only through them (see CLAUDE.md):
--   apply(path)   put a wallpaper up (wp_apply)
--   cur()         the wallpaper up now
--   files()       every wallpaper in the folder (not narrowed by the colour filter)
--   crop(fs, done) make the gallery's 16:9 thumbnails of `fs`;  thumb(f): the one to show for `f`
--   theme()       the theme in use: its id and its name
return function(w)
    local FILE = "theme-wallpapers.json"
    local PER = 16
    local pins = {}
    local page = 0
    local list = {}

    local ok, saved = pcall(sys.ask, "files.read", FILE, "json")
    if ok and type(saved) == "table" then
        for id, path in pairs(saved) do
            if type(id) == "string" and type(path) == "string" and path ~= "" then pins[id] = path end
        end
    end
    local function save() pcall(sys.call, "files.write", FILE, pins) end
    local function base(path) return path:match("([^/]+)$") or path end

    -- The row on the Theme page: the pinned wallpaper's thumbnail and a line about it.
    local function show()
        local id, name = w.theme()
        if not id then return end
        local p = pins[id]
        fact.tpw_on = p ~= nil
        text.tpw_title = "Wallpaper for " .. name
        if p then
            text.tpw_sub = base(p)
            w.crop({ p }, function() if pins[id] == p then text.tpw_path = w.thumb(p) end end)
        else
            text.tpw_sub = "Off · " .. name .. " keeps the wallpaper up"
            text.tpw_path = ""
        end
    end

    -- The picker: a page of the folder's wallpapers, the pinned one ringed.
    local function pages() return math.max(1, math.ceil(#list / PER)) end
    local function fill()
        if page >= pages() then page = pages() - 1 end
        if page < 0 then page = 0 end
        local id = w.theme()
        local on = {}
        for i = 1, PER do
            local f = list[page * PER + i]
            if not f then break end
            on[#on + 1] = f
        end
        local at = page
        w.crop(on, function()
            if at ~= page then return end
            local rows = {}
            for i, f in ipairs(on) do rows[i] = { thumb = w.thumb(f), sel = id ~= nil and pins[id] == f } end
            model.tpw = rows
            text.tpw_pager = string.format("%d / %d", page + 1, pages())
        end)
    end

    local function choose()
        list = w.files() or {}
        local id = w.theme()
        local want = (id and pins[id]) or w.cur()
        page = 0
        for i, f in ipairs(list) do
            if f == want then page = (i - 1) // PER break end
        end
        fill()
    end
    on("tpw_choose", choose)
    on("tpw_prev", function() page = page - 1; if page < 0 then page = pages() - 1 end; fill() end)
    on("tpw_next", function() page = page + 1; if page >= pages() then page = 0 end; fill() end)
    on("tpw_pick", function(i)
        local f = list[page * PER + math.floor((tonumber(i) or -1) + 0.5) + 1]
        local id = w.theme()
        if not f or not id then return end
        pins[id] = f
        save()
        show()
        if f ~= w.cur() then w.apply(f) end
    end)
    -- The switch: on pins the wallpaper up now, off lets the theme go back to keeping whatever is up.
    on("tpw_toggle", function()
        local id = w.theme()
        if not id then return end
        if pins[id] then
            pins[id] = nil
        else
            local f = w.cur()
            if not f then fact.tpw_open = true; choose() return end      -- no wallpaper known to be up: pick one instead
            pins[id] = f
        end
        save()
        show()
    end)

    -- A card on the Theme page: once the theme is set (vitreus.luau's handler runs first), its wallpaper, if it has one.
    on("theme_pick", function()
        after(60, function()
            show()
            local id = w.theme()
            local p = id and pins[id]
            if p and p ~= w.cur() then w.apply(p) end
        end)
    end)
    on("themes_refresh", function() after(800, show) end)
    on("fact:set_page", show)
    after(1500, show)          -- once the themes have been read
end
