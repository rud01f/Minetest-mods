--minetest.register_privilege("tnt", {description = "Can place tnt with explosion above sea level.",give_to_singleplayer = false})

local old_tnt_place = minetest.registered_items["tnt:tnt"].on_place;

local tnt_radius = tonumber(minetest.settings:get("tnt_radius") or 3) + 1;

minetest.override_item("tnt:tnt", {
	on_place = function(itemstack, placer, pointed_thing)
		if pointed_thing.type == "object" then
			pointed_thing.ref:punch(user, 1.0, { full_punch_interval=1.0 }, nil)
			return user:get_wielded_item()
		elseif pointed_thing.type ~= "node" then
			return
		end
		--node = minetest.get_node(pointed_thing.under)
		if not minetest.check_player_privs(placer:get_player_name(),
				{worldedit = true}) and pointed_thing.under.y >= -1 * tnt_radius then
			minetest.chat_send_player(placer:get_player_name(),"You dont have permission to place tnt with explosion range above sea level (missing privledges: worldedit)")
			return itemstack
		else
			return old_tnt_place(itemstack, placer, pointed_thing)
		end
	end,
})
