--[[        telemenu by Dawid "rud0lf" Lekawski
            (xxrud0lf (at) gmail (dot) com)
            (rud0lf on IRC:freenode)

            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
            Everyone is permitted to copy and distribute verbatim or modified
            copies of this license document, and changing it is allowed as long
            as the name is changed.


            ###
            
            use /telemenu or /tm command to open telemenu dialog
--]]


-- priviledge needed to use /telemenu (and /tm) command
local TELE_PRIV_NEEDED = "teleport";

local tele = {};

telemenu = {};

tele.locations = {};
tele.runtime_data = {};

function telemenu.receive_fields(player, formname, fields)
    if formname == "telemenu:teledialog" and minetest.check_player_privs(player, TELE_PRIV_NEEDED) then
        telemenu.serve_tele_dialog(player, fields);
        return true;
    elseif formname == "telemenu:confirmation" and minetest.check_player_privs(player, TELE_PRIV_NEEDED) then
        telemenu.serve_confirmation_dialog(player, fields);
        return true;
    elseif formname == "telemenu:edit" and minetest.check_player_privs(player, TELE_PRIV_NEEDED) then
        telemenu.serve_edit_dialog(player, fields);
        return true;
    end
    return false;
end

function telemenu.serve_tele_dialog(player, fields)
    local pname = player:get_player_name();
    if fields.new_ then 
        local ppos = player:get_pos();
        local ppos_round = player:get_pos();
        -- round it nicely for description
        ppos_round.x = math.floor(ppos_round.x * 100)/100;
        ppos_round.y = math.floor(ppos_round.y * 100)/100;
        ppos_round.z = math.floor(ppos_round.z * 100)/100;
        local desc = minetest.pos_to_string(ppos_round);
        local entry = {position=ppos, description=desc};
        table.insert(tele.locations[pname], entry);        
        telemenu.store_player_locations(pname);
        local npages = math.floor(math.max(0, #(tele.locations[pname]) - 1)/ 12);
        tele.runtime_data[pname].page = npages;   
        telemenu.display_dialog(pname);    
    elseif fields.prev then
        assert(tele.runtime_data[pname].page > 0, "Ooops! Tried to go to page 0.");
        tele.runtime_data[pname].page = tele.runtime_data[pname].page - 1;
        telemenu.display_dialog(pname);
    elseif fields.next then
        local npages = math.floor(math.max(0, #(tele.locations[pname]) - 1)/ 12) + 1;
        assert(tele.runtime_data[pname].page < npages, "Ooops! Tried to reach next non-existing page.");
        tele.runtime_data[pname].page = tele.runtime_data[pname].page + 1;
        telemenu.display_dialog(pname);        
    else
        local btn, item = telemenu.parse_button(fields);
        if btn == "go__" then
            player:set_pos(tele.locations[pname][item].position);
            local ppos_round = player:get_pos();
            -- round it nicely for description
            ppos_round.x = math.floor(ppos_round.x * 100)/100;
            ppos_round.y = math.floor(ppos_round.y * 100)/100;
            ppos_round.z = math.floor(ppos_round.z * 100)/100;
            local coords = minetest.pos_to_string(ppos_round);
            local desc = tele.locations[pname][item].description;
            minetest.chat_send_player(pname, ("Teleported to %s %s"):format(desc,coords));
        elseif btn == "del_" then
            local desc = tele.locations[pname][item].description;
            tele.runtime_data[pname].item_number = item;
            telemenu.display_confirmation(pname, desc);            
        elseif btn == "aim_" then
            tele.locations[pname][item].position = player:get_pos();
            telemenu.store_player_locations(pname);            
            local ppos_round = player:get_pos();
            -- round it nicely for description
            ppos_round.x = math.floor(ppos_round.x * 100)/100;
            ppos_round.y = math.floor(ppos_round.y * 100)/100;
            ppos_round.z = math.floor(ppos_round.z * 100)/100;
            local coords = minetest.pos_to_string(ppos_round);
            local desc = tele.locations[pname][item].description;
            minetest.chat_send_player(pname, ("Changed teleport postion of %s to %s"):format(desc,coords));                                            
        elseif btn == "up__" then
            local entry = tele.locations[pname][item];
            table.remove(tele.locations[pname], item);
            table.insert(tele.locations[pname], item - 1, entry);        
            telemenu.store_player_locations(pname);
            local npages = math.floor(math.max(0, item - 2)/ 12);
            tele.runtime_data[pname].page = npages;   
            telemenu.display_dialog(pname);    
        elseif btn == "down" then
            local entry = tele.locations[pname][item];
            table.remove(tele.locations[pname], item);
            table.insert(tele.locations[pname], item + 1,entry);        
            telemenu.store_player_locations(pname);
            local npages = math.floor(math.max(0, item)/ 12);
            tele.runtime_data[pname].page = npages;   
            telemenu.display_dialog(pname);    
        elseif btn == "edit" then
            telemenu.display_edit(pname, item);
        end
    end
end

function telemenu.serve_confirmation_dialog(player, fields)
    local pname = player:get_player_name();
    if fields.remove then
        local locname = tele.locations[pname][tele.runtime_data[pname].item_number].description;
        table.remove(tele.locations[pname], tele.runtime_data[pname].item_number);
        telemenu.store_player_locations(pname);
        local npages = math.floor(math.max(0, #(tele.locations[pname]) - 1)/ 12) + 1;
        if tele.runtime_data[pname].page > npages - 1 then
            tele.runtime_data[pname].page = npages - 1;
        end 
        minetest.chat_send_player(pname, ("Removed teleport location %s"):format(locname));
    end
    telemenu.display_dialog(pname);                         
end

function telemenu.serve_edit_dialog(player, fields)
    local pname = player:get_player_name();
    if fields.confirm or fields.key_enter_field then
        tele.locations[pname][tele.runtime_data[pname].item].description = fields.edit;
        telemenu.store_player_locations(pname);
        minetest.chat_send_player(pname, ("Location name changed to %s"):format(fields.edit));
        telemenu.display_dialog(pname);
    else
        telemenu.display_dialog(pname);
    end
end

-- up__, down, aim_, del_, edit, go__ + item_number
function telemenu.parse_button(fields) 
    local butt = nil;
    local fbtn = nil;
    for k, v in pairs(fields) do
        local btn = k:sub(1,4); 
        if btn == "up__" or btn == "down" or btn == "aim_" or btn == "del_" or btn == "edit" or btn == "go__" then 
            fbtn = k;
            butt = btn;
        end
    end
    if not fbtn then
        return nil, nil
    else
        return butt, tonumber(fbtn:sub(5));
    end
end

function telemenu.telemenu_cmd(player_name, param)
    if not minetest.get_player_by_name(player_name) then
        return false, "You need to be online to use telemenu!";
    end
    telemenu.read_player_locations(player_name);
    -- 0 - based page number
    tele.runtime_data[player_name] = {page = 0};
    telemenu.display_dialog(player_name);
    return true;
end

function telemenu.display_dialog(player_name)

    local locations = tele.locations[player_name];
    local page = tele.runtime_data[player_name].page;
    
    local dialog = [[
    size[12,8]
    position[0.05,0.1]
    anchor[0.0,0.0]
    ]]
        
    if page * 12 > #locations - 1 then
        page = math.floor(math.max(0, #locations - 1) / 12);
        tele.runtime_data[player_name].page = page;
    end
    
    for item = 0, 11 do
        local offset = item + page * 12 + 1;
        if offset > #locations then
            break
        end    
        local vpos = item * 0.5;
        
        -- keep names 4-characters long so it's easier to parse
        
        -- don't display "move up" if it's first item
        if offset > 1 then 
            dialog = dialog .. ("image_button_exit[0.0,%f;0.5,0.5;btn_up.png;%s;;false;false;btn_up_down.png]"):format(vpos, "up__"..offset);
        end
        -- don't display "move down" if it's last item
        if offset < #locations then
            dialog = dialog .. ("image_button_exit[0.4,%f;0.5,0.5;btn_down.png;%s;;false;false;btn_down_down.png]"):format(vpos, "down"..offset);
        end
        dialog = dialog .. ("image_button_exit[1.0,%f;0.5,0.5;btn_aim.png;%s;;false;false;btn_aim_down.png]"):format(vpos, "aim_"..offset);
        dialog = dialog .. ("image_button_exit[1.5,%f;0.5,0.5;btn_del.png;%s;;false;false;btn_del_down.png]"):format(vpos, "del_"..offset);
        dialog = dialog .. ("image_button_exit[2.0,%f;0.5,0.5;btn_edit.png;%s;;false;false;btn_edit_down.png]"):format(vpos, "edit"..offset);
        dialog = dialog .. ("image_button_exit[2.5,%f;0.5,0.5;btn_go.png;%s;;false;false;btn_go_down.png]"):format(vpos, "go__"..offset);
        dialog = dialog .. ("label[3,%f;%s]"):format(vpos, minetest.formspec_escape(locations[offset].description));
    end
    local npages = math.floor(math.max(0, #locations - 1) / 12) + 1;
    if page + 1 > 1 then
        dialog = dialog .. "image_button_exit[0.5,6.25;1,1;btn_left.png;prev;;false;false;btn_left_down.png]";
    end
    if page + 1 < npages then 
        dialog = dialog .. "image_button_exit[1.5,6.25;1,1;btn_right.png;next;;false;false;btn_right_down.png]";
    end
    dialog = dialog .. ("label[2.5,6.5;Page %d of %d]"):format(page + 1, npages);
    dialog = dialog .. "button_exit[5.0,7.25;3.0,1.0;new_;New at place]";
        
    minetest.show_formspec(player_name, "telemenu:teledialog", dialog);    
end

function telemenu.display_confirmation(player_name, description)
    local dialog = [[
    size[10,4]
    label[1,0.5;Remove this location?]
    ]]
    dialog = dialog .. ("label[1,1.5;%s]"):format(minetest.formspec_escape(description));
    dialog = dialog .. [[
    button_exit[2,3;2,1;remove;Remove]
    button_exit[6,3;2,1;cancel;Cancel]
    ]]
    
    minetest.show_formspec(player_name, "telemenu:confirmation", dialog);
end

function telemenu.display_edit(player_name, item_number)
    tele.runtime_data[player_name].item = item_number;
    local desc = tele.locations[player_name][item_number].description;
    local dialog = "size[10,3]";
    dialog = dialog .. ("field[1,1;8,1;edit;New name of teleport location;%s]"):format(minetest.formspec_escape(desc));
    dialog = dialog .. [[
        button_exit[2,2;2,1;confirm;Confirm]
        button_exit[6,2;2,1;cancel;Cancel]
    ]]    
    
    minetest.show_formspec(player_name, "telemenu:edit", dialog);
end

-- change it if you want to store player data elsewhere
-- data is stored per-player, cached in tele.locations[player_name]
-- removed on player exit
function telemenu.read_player_locations(player_name)
    if tele.locations[player_name] == nil then
        local player_ref = minetest.get_player_by_name(player_name);
        assert(player_ref ~= nil, "Player object not found, but should be there!");
        local data = player_ref:get_attribute("telemenu_locations");
        if data ~= nil then
            tele.locations[player_name] = minetest.deserialize(data);
        else
            tele.locations[player_name] = {};
        end
    end

end

-- stores player data (tele locations)
function telemenu.store_player_locations(player_name)
    local data;
    if tele.locations[player_name] == nil then
        data = minetest.serialize({});
    else
        data = minetest.serialize(tele.locations[player_name]);
    end
    local player_ref = minetest.get_player_by_name(player_name);
    assert(player_ref ~= nil, "Player object not found as expected.");
    player_ref:set_attribute("telemenu_locations", data);
end

-- cleanup (not really neccessary, unless you have a LOT of people
-- using telemenu with many locations)
function telemenu.cleanup(player, timed_out)
    local pname = player:get_player_name();
    assert(pname, "Player had no name?");
    if tele.locations[pname] then
        tele.locations[pname] = nil;
    end
    if tele.runtime_data[pname] then
        tele.runtime_data[pname] = nil
    end
end

local privs = {};
privs[TELE_PRIV_NEEDED] = true;

minetest.register_chatcommand("telemenu", {
    privs,
    func = telemenu.telemenu_cmd
});

-- comment the one below (/tm command) if it conflicts with other mods
minetest.register_chatcommand("tm", {
    privs,
    func = telemenu.telemenu_cmd
});


minetest.register_on_player_receive_fields(telemenu.receive_fields);
minetest.register_on_leaveplayer(telemenu.cleanup);
