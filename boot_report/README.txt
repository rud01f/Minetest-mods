boot_report mod
===============
See license.txt for additional information.

Short installation:
-------------------

* in your mod, create depends.txt if not present, add "boot_report" there
* before you reboot (shutdown to be precise) the server, call: 
> boot_report.flag_daily_reboot()
* it's done!

Details:
--------
boot_report exposes flag_daily_reboot() function, which creates dummy file with path REBOOT_FLAG_FILE.
Every server startup (or more precisely: when mod is loaded) it launches function which checks for
presence of said flag file and removes it afterwards. If file wasn't present, sends report to all mods.

WARNING
-------
Due to limitation (or rather - form) of report mod, the report message should be not shorter than 25 characters.
