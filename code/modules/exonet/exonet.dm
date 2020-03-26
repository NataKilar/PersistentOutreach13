/datum/exonet
	var/list/relays = list()
	var/list/logs = list()
	var/list/available_software = list()
	var/list/chat_channels = list()
	var/list/file_servers = list()
	var/list/emails = list()
	var/list/banned_nids = list()
	var/list/registered_nids = list()				// list of nid - os datum pairs

	// Amount of logs the system tries to keep in memory. Keep below 999 to prevent byond from acting weirdly.
	// High values make displaying logs much laggier.
	var/setting_maxlogcount = 100

	// These only affect wireless. LAN (consoles) are unaffected since it would be possible to create scenario where someone turns off NTNet, and is unable to turn it back on since it refuses connections
	var/setting_softwaredownload = 1
	var/setting_peertopeer = 1
	var/setting_communication = 1
	var/setting_systemcontrol = 1
	var/setting_disabled = 0					// Setting to 1 will disable all wireless, independently on relays status.

	var/intrusion_detection_enabled = 1 		// Whether the IDS warning system is enabled
	var/intrusion_detection_alarm = 0			// Set when there is an IDS warning due to malicious (antag) software.

	var/list/email_domains = list() 			// registered email domains
	var/list/areas = list()
	var/interface_index = 1
	var/sregistered = FALSE						// Whether or not this is registered and paid for IG.

/datum/exonet/New()
	GLOB.exonets.register_exonet(src)

/datum/exonet/Destroy()
	GLOB.exonets.unregister_exonet(src)

/datum/exonet/proc/get_os_by_nid(var/NID)
	return registered_nids["[NID]"]

/datum/exonet/proc/register(var/NID, var/datum/extension/interactive/ntos/os)
	registered_nids["[NID]"] = os

/datum/exonet/proc/unregister(var/NID)
	registered_nids -= "[NID]"

/datum/exonet/proc/get_next_nid()
	var/nid = interface_index
	interface_index++
	return nid

// Builds lists that contain downloadable software.
/datum/exonet/proc/build_software_lists()
	// for(var/F in typesof(/datum/computer_file/program))
	// 	var/datum/computer_file/program/prog = new F
	// 	// Invalid type (shouldn't be possible but just in case), invalid filetype (not executable program) or invalid filename (unset program)
	// 	if(!prog || !istype(prog) || prog.filename == "UnknownProgram" || prog.filetype != "PRG")
	// 		continue
	// 	// Check whether the program should be available for station/antag download, if yes, add it to lists.
	// 	if(prog.available_on_ntnet)
	// 		var/list/category_list = available_software_by_category[prog.category]
	// 		if(!category_list)
	// 			category_list = list()
	// 			available_software_by_category[prog.category] = category_list
	// 		ADD_SORTED(available_station_software, prog, /proc/cmp_program)

/datum/exonet/proc/check_banned(var/NID)
	if(!relays || !relays.len)
		return FALSE

	for(var/obj/machinery/ntnet_relay/R in relays)
		if(R.operable())
			return (NID in banned_nids)

	return FALSE

// Checks whether NTNet operates. If parameter is passed checks whether specific function is enabled.
/datum/exonet/proc/check_function(var/specific_action = 0)
	if(!relays || !relays.len) // No relays found. NTNet is down
		return 0

	var/operating = 0

	// Check all relays. If we have at least one working relay, network is up.
	for(var/obj/machinery/ntnet_relay/R in relays)
		if(R.operable())
			operating = 1
			break

	if(setting_disabled)
		return 0

	if(specific_action == NTNET_SOFTWAREDOWNLOAD)
		return (operating && setting_softwaredownload)
	if(specific_action == NTNET_PEERTOPEER)
		return (operating && setting_peertopeer)
	if(specific_action == NTNET_COMMUNICATION)
		return (operating && setting_communication)
	if(specific_action == NTNET_SYSTEMCONTROL)
		return (operating && setting_systemcontrol)
	return operating	