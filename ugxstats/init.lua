--[[ ugx stats by rud0lf (freenode visitor) for UGX-realms server
     feel free to use it under do whatever you want with this license
--]] 

-- where to keep stats data
local DATA_DB_FILE_NAME = minetest.get_worldpath() .. "/ugxstats_db.json";
-- in this file we store since when the stats are going on
local DATA_SINCE_FILE_NAME = minetest.get_worldpath() .. "/ugxstats_since.txt";
-- save every this # of seconds (don't make it too small)
local SAVE_INTERVAL = 5 * 60;
-- maximum distance (per second) which is _not_ considered a teleport
local MAX_MOVE_DISTANCE = 10;
-- global step interval - too low is CPU intensive, too much makes
-- distance counting too approximative (think of lines between dots,
-- the thicker dots are, the curve is more accurate)
local STEP_INTERVAL = 0.4;
local ustats = {};
local since = 0;
local tstats = {};
local sttime = 0;

local esc = minetest.formspec_escape;

-- timjoin: total times joined
-- charsaid: total letters (characters) said
-- wordsaid: total word said
-- distance: total walked (moved) distance
-- nodesplcd: total nodes placed
-- nodesdug: total nodes dug
-- deaths: total deaths
-- hpgained: total hp gained
-- hplost: total hp lost
-- respawns: total # of respawns
-- crafted: total # of player crafting something
-- timeonline: total time spent online
-- itemseaten: total number of eaten items

-- on join player - set entry if empty, initialize temporary values
minetest.register_on_joinplayer(function(player)
    local name = player:get_player_name();
    if ustats[name] == nil then
        ustats[name] = {
            timjoin = 0,
            charsaid = 0,
            wordsaid = 0,
            distance = 0,
            nodesplcd = 0,
            nodesdug = 0,
            deaths = 0,
            hpgained = 0,
            hplost = 0,
            respawns = 0,
            crafted = 0,
            timeonline = 0,
            itemseaten = 0,
        };
    end
    tstats[name] = {pos = player:get_pos(), joined=os.time()};
    ustats[name].timjoin = ustats[name].timjoin + 1;
end);

-- on player quit - refresh online time
minetest.register_on_leaveplayer(function(player, timed_out)
    local name = player:get_player_name();
    local dtime = os.time() - tstats[name].joined;
    ustats[name].timeonline = ustats[name].timeonline + dtime;
end);

-- on chat - how many letters, how many words
minetest.register_on_chat_message(function(name, message)
    if message:sub(1,1) == "/" then return end;
    ustats[name].charsaid = ustats[name].charsaid + message:len();
    local _, ws = message:gsub("%w+", "");
    ustats[name].wordsaid = ustats[name].wordsaid + ws; 
end);

-- on server step - calc distance
minetest.register_globalstep(function(dtime)
    sttime = sttime + dtime;
    if sttime < STEP_INTERVAL then return end;
    for _, player in pairs(minetest.get_connected_players()) do
        local name = player:get_player_name();
        local newpos = player:get_pos();
        local lastpos = tstats[name].pos;
        tstats[name].pos = newpos;
        local dist = vector.distance(newpos, lastpos);
        if dist <= MAX_MOVE_DISTANCE * sttime then
            ustats[name].distance = ustats[name].distance + dist;
        end      
    end;
    sttime = 0;
end);

-- on node placed
minetest.register_on_placenode(function(pos, newnode, placer, oldnode, itemstack, pointed_thing)
    if placer and placer:is_player() then
        local name = placer:get_player_name();
        ustats[name].nodesplcd = ustats[name].nodesplcd + 1;
    end
end);

-- on node dug
minetest.register_on_dignode(function(pos, oldnode, digger)
    if digger and digger:is_player() then
        local name = digger:get_player_name();
        ustats[name].nodesdug = ustats[name].nodesdug + 1;
    end
end);

-- on player death
minetest.register_on_dieplayer(function(player)
    local name = player:get_player_name();
    ustats[name].deaths = ustats[name].deaths + 1;
end);

-- on hp change
minetest.register_on_player_hpchange(function(player, hp_change, modifier)
    local name = player:get_player_name();
    if hp_change >= 0 then
        ustats[name].hpgained = ustats[name].hpgained + hp_change;
    else
        ustats[name].hplost = ustats[name].hplost - hp_change;
    end        
end);

-- on respawn
minetest.register_on_respawnplayer(function(player)
    local name = player:get_player_name();
    ustats[name].respawns = ustats[name].respawns + 1;    
end);

-- on craft
minetest.register_on_craft(function(itemstack, player, old_craft_grid, craft_inv)
    local name = player:get_player_name();
    ustats[name].crafted = ustats[name].crafted + 1;    
end);

-- on item eat
minetest.register_on_item_eat(function(hp_change, replace_with_item, itemstack, user, pointed_thing)
    local name = user:get_player_name();
    ustats[name].itemseaten = ustats[name].itemseaten + 1;        
end);

function load_stats()
    local dfh = io.open(DATA_SINCE_FILE_NAME, "r");
    if dfh == nil then
        minetest.log("action", "[ugxstats] no 'since' data file, creating it.");
        local dfh = io.open(DATA_SINCE_FILE_NAME, "w");
        since = os.time();
        dfh:write(tostring(since));
        dfh:close();        
    else
        since = tonumber(dfh:read("*l"));
        dfh:close();
    end
    local dbfh = io.open(DATA_DB_FILE_NAME, "r");
    if dbfh == nil then return end;
    local content = dbfh:read("*a");
    dbfh:close();
    ustats = minetest.parse_json(content);
    if type(ustats) ~= "table" then
        ustats = {};
    end    
end

function save_stats()
    local dbfh = io.open(DATA_DB_FILE_NAME, "w");
    if dbfh == nil then return end;
    local content = minetest.write_json(ustats);
    dbfh:write(content);
    dbfh:close();
end

function periodic_save()
    save_stats();
    minetest.after(SAVE_INTERVAL, periodic_save);
end

minetest.register_on_shutdown(function()
    for _, player in pairs(minetest.get_connected_players()) do
        local name = player:get_player_name();
        local dtime = os.time() - tstats[name].joined;
        ustats[name].timeonline = ustats[name].timeonline + dtime;
        -- to avoid duplicates - server triggering on shutdown player_leave?
        tstats[name].joined = os.time();
    end
    save_stats();
end);

function nice_duration(secs)
    local s = secs % 60;
    secs = math.floor(secs / 60);
    local m = secs % 60;
    secs = math.floor(secs / 24);
    local d = secs;
    return ("%dd %dm %ds"):format(d,m,s); 
end

function on_stats(pname, param)
    if ustats[param] == nil then
        minetest.chat_send_player(name, "No stats of such player.");
        return;
    end
        
    local name = param;
    local fs = [[
        size[12,9]
        position[0.5,0.5]        
    ]] .. 
    ("label[0,0;Stats of user %s]"):format(esc(name)) ..
    ("label[0.1,0.5;Since %s]"):format(esc(os.date("%c",since))) ..
    "label[0,1.5;Online time:]" ..
    "label[0,2.0;Times joined:]" ..
    "label[0,2.5;Said characters:]" ..
    "label[0,3.0;Said words:]" ..
    "label[0,3.5;Total deaths:]" ..
    "label[0,4.0;Nodes placed:]" ..
    "label[0,4.5;Nodes dug:]" ..
    "label[0,5.0;Walked distance:]" ..
    "label[0,5.5;HP gained:]" ..
    "label[0,6.0;HP lost:]" ..
    "label[0,6.5;Items crafted:]" ..
    "label[0,7.0;Total respawns:]" ..
    "label[0,7.5;Food eaten:]" ..
    ("label[3,1.5;%s]"):format(nice_duration(ustats[name].timeonline)) ..
    ("label[3,2.0;%d]"):format(ustats[name].timjoin) ..
    ("label[3,2.5;%d]"):format(ustats[name].charsaid) ..
    ("label[3,3.0;%d]"):format(ustats[name].wordsaid) ..
    ("label[3,3.5;%d]"):format(ustats[name].deaths) ..
    ("label[3,4.0;%d]"):format(ustats[name].nodesplcd) ..
    ("label[3,4.5;%d]"):format(ustats[name].nodesdug) ..
    ("label[3,5.0;%.3fkm]"):format(ustats[name].distance / 1000.0) ..
    ("label[3,5.5;%d]"):format(ustats[name].hpgained) ..
    ("label[3,6.0;%d]"):format(ustats[name].hplost) ..
    ("label[3,6.5;%d]"):format(ustats[name].crafted) ..
    ("label[3,7.0;%d]"):format(ustats[name].respawns) ..
    ("label[3,7.5;%d]"):format(ustats[name].itemseaten) ..
    "button_exit[4.5,8.2;3,1;exit;OK]";

    minetest.show_formspec(pname, "ugxstats:form", fs);
    return true;
end

function on_statsme(name, param)
    on_stats(name, name);
    return true;
end

minetest.register_chatcommand("statsme", {
    description = "Show my stats.",
    func = on_statsme,
});

minetest.register_chatcommand("stats", {
    params="<player-name>",
    description = "Show player's stats.",
    func = on_stats,
});

load_stats();
minetest.after(SAVE_INTERVAL, periodic_save);
minetest.log("action", "[ugxstats] stats mod loaded.");
