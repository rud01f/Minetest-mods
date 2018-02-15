
local DEF_DB_FILENAME = minetest.get_worldpath().."/xban.db"
local DB_FILENAME = minetest.setting_get("xban.db_filename")
if (not DB_FILENAME) or (DB_FILENAME == "") then
	DB_FILENAME = DEF_DB_FILENAME
end
local banlist = {};
local sel = {};

local fesc = minetest.formspec_escape;

function fmt(form, ...)
    return form:format(...);
end

function tf(bool)
    if bool then
        return "true";
    else
        return "false";
    end;
end

function ban_expires(tstamp)
    if tstamp ~= nil then
        return os.date("%Y-%m-%d %H:%M:%S", tstamp);
    else
        return "Never"
    end
end

function load_banlist()
--[[    local f, e = io.open(DB_FILENAME, "rt");
    if not f then
        local warn = ("Unable to load database: %s"):format(e);
        minetest.log("warning", warn);
        return false, warn;
    end
    local content = f:read("*a");
    if not content then
        local warn = "Unable to load database: Read failed";
        minetest.log("warning", warn);
        return false, warn;
    end
    local t, e = minetest.deserialize(content);
    if not t then
        local warn = ("Unable to load database: Deserialization failed: %s"):format(e);
        minetest.log("warning", warn);
        return false, warn;
    end
    banlist = {};
    for _, entry in ipairs(t) do
        if entry.banned and #(entry.record) > 0 then
            table.insert(banlist, entry);
        end
    end
--]]
    banlist = {};
    for _, entry in ipairs(xban.db) do
        if entry.banned and #(entry.record) > 0 then
            table.insert(banlist, entry);
        end
    end
    return true, nil;
end

function show_entries(name)
    local selected, banfilter, matchesonly = sel[name].pos, sel[name].filter, sel[name].matchonly
    local bans = {};
    local ctable = {"#c0c000", "#c0c0c0"};
    local cc = 1;
    local filt = banfilter:gsub("%%", "%%%%");
    local filt = filt:gsub("*", ".*");
    local filt = filt:gsub("?", ".?");
    local filt = filt:gsub("%[", "%%[");
    local filt = filt:gsub("%]", "%%]");
    local filt = filt:gsub("(%.)", "%%.");
    for _, e in ipairs(banlist) do
        if not matchesonly then
            local matched = false;
            for e2, v in pairs(e.names) do
                if v and e2:match(filt) then
                    matched = true;
                end
            end
            if matched then
                for e2, v in pairs(e.names) do
                    if v then 
                        table.insert(bans, {name=ctable[cc]..e2, records=e.record});
                    end
                end
                cc = 3 - cc;
            end
        else
            for e2, v in pairs(e.names) do
                if v and e2:match(filt) then
                    table.insert(bans, {name=e2, records=e.record});
                end
            end
        end
    end

    local bannames = {};
    for _, entry in pairs(bans) do
        table.insert(bannames, fesc(entry.name));
    end
    
    local fs = "size[16.1,9.5]" ..
        "label[0.2,0.2;Filter]" ..
        fmt("field[1.6,0.3;8.5,1;filter;;%s]", fesc(banfilter)) ..
        "field_close_on_enter[filter;false]" ..
        fmt("checkbox[10,0.0;matchonly;List matches only;%s]", tf(matchesonly)) ..
        "button[14,0.0;2,1;search;Search]" ..
        fmt("textlist[0,1;4,8.5;entries;%s;%d;0]", table.concat(bannames, ","), selected);
        if not bans[selected] then
            fs = fs .. "textlist[4.2,1;11.7,8.5;entry;;0]";            
        else
            local entries = {};
            for _, entry in pairs(bans[selected].records) do
                table.insert(entries, fesc("Reason: " .. entry.reason or "??")); 
                table.insert(entries, fesc("Issued by: " .. entry.source or "??"));
                table.insert(entries, fesc("Ban time: " .. os.date("%Y-%m-%d %H:%M:%S", entry.time or 0)));
                table.insert(entries, fesc("Expires: " .. ban_expires(entry.expires))); 
                table.insert(entries, "");
            end
            fs = fs .. fmt("textlist[4.2,1;11.7,8.5;entry;%s;0]", table.concat(entries, ","));
        end
    minetest.show_formspec(name, "listxban2:bans", fs);                
end

function xbl_command(name)
    local status, err = load_banlist();
    if not status then
        minetest.chat_send_player(name, err); 
        return; 
    end
    if #banlist == 0 then
        minetest.chat_send_player(name, "Ban list is empty!"); 
        return;     
    end
    sel[name] = {pos=1, filter="", matchonly=false};
    show_entries(name, 1, "", false);
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= "listxban2:bans" then return end
	if not minetest.check_player_privs(player, { ban=true }) then
		minetest.log("warning", "[listxban2] Received fields from unauthorized user: "..name)
		return
	end
	local name = player:get_player_name();
    if fields.entries then
        local t = minetest.explode_textlist_event(fields.entries);
        if (t.type == "CHG") or (t.type == "DCL") then
            sel[name].pos = t.index;
        end 
        show_entries(name);
        return;
    elseif (fields.key_enter_field == "filter") or fields.search then
        sel[name].filter = fields.filter;
        sel[name].pos = 1;
        show_entries(name);
        return;
    elseif fields.matchonly then
        if fields.matchonly == "false" then
            sel[name].matchonly = false
        else
            sel[name].matchonly = true
        end
        sel[name].pos = 1;
        show_entries(name);
        return;
    end
end);
	
minetest.register_chatcommand("xbl", {
    description = "Show XBan List Gui",
    params = "",
    privs = { ban=true },
    func = xbl_command
});
