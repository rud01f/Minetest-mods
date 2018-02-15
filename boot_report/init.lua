boot_report = {}

-- filename of flag file - if present, the reboot was automated
local REBOOT_FLAG_FILE = minetest.get_worldpath() .. "/daily_reboot_flag.txt";

-- tries to create file with "dummy" content - it can be anything
-- i guess including no content, but *shrug* i'm too lazy to check it
local function flag_it()
    local fh = io.open(REBOOT_FLAG_FILE, "wt");
    fh:write("dummy");
    fh:close();
end

-- this function is exposed for daily reboot mod, calling it
-- means "hey, no report after the following reboot"
-- call it from your mod, namely: boot_report.flag_daily_reboot()
function boot_report.flag_daily_reboot()
    local stat, errmsg = pcall(flag_it);
    if not stat then
        minetest.log("warning", "[boot_report] Failed to create reboot flag file: " .. errmsg);
    else
        minetest.log("action", "[boot_report] Successfully created reboot flag file.");
    end 
end

-- checks for presence of flag file, if present removes it and does nothing,
-- if not present, report it
local function check_stuff()
    local fh = io.open(REBOOT_FLAG_FILE, "rt");
    if fh == nil then
        -- message must be longer than 25 characters (report mod needs that)
        report.send(".[SERVER].", "Server started after a maintenance reboot.")
        minetest.log("action", "[boot_report] Report about reboot sent.");   
    else
        fh:close();
        os.remove(REBOOT_FLAG_FILE);
        minetest.log("action", "[boot_report] Not sending report due to server reboot flag.");
    end    
end

check_stuff();

