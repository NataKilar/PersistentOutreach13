GLOBAL_LIST_EMPTY(exonets)

/datum/exonet
	var/ennid										// This is the name of the network. Its unique ID.
	var/list/network_devices 	= list()			// Devices utilizing the network.
	var/list/mainframes 		= list()			// File servers serving files.
	var/list/modems				= list()			// Modems capable of connecting to PLEXUS, the space internet.
	var/list/broadcasters		= list()			// A list of anything broadcasting the good signal. Only one will be the /router.

	var/obj/machinery/computer/exonet/mainframe/email_server	// A mainframe that's configured to be the email server. This doesn't take a special mainframe.
	var/obj/machinery/computer/exonet/mainframe/log_server	// A mainframe that's the chosen main-log server.
	var/obj/machinery/computer/exonet/mainframe/report_server// A mainframe that's the chosen main-report server.
	var/obj/machinery/computer/exonet/broadcaster/router/router // The router that hosts the network. There can be only ONE!

	var/default_domain								// OPTIONAL: If this is set, this is the default email domain for the exonet, allowing emails to be setup.
	var/list/email_accounts 	= list()			// A list of emails configured for this exonet.

	var/list/banned_nids		= list()			// A list of identification_ids on network devices that are banned from joining this network.
	var/intrusion_detection_enabled					// LEGACY.
	var/intrusion_detection_alarm					// LEGACY.


/datum/exonet/New(var/new_ennid)
	if(new_ennid)
		ennid = new_ennid
		GLOB.exonets[new_ennid] = src

/datum/exonet/proc/change_ennid(var/new_ennid)
	// aw god. pls never call this...
	for(var/datum/network_device in network_devices)
		if("ennid" in network_device.vars)
			network_device.vars["ennid"] = new_ennid
			// Try to get their extension, too.
			var/datum/extension/exonet_device/device = get_extension(network_device, /datum/extension/exonet_device)
			device.ennid = new_ennid
	GLOB.exonets.Remove(ennid)
	GLOB.exonets[new_ennid] = src
	ennid = new_ennid	

/datum/exonet/proc/create_email(var/mob/user, var/desired_name, var/domain_override, var/assignment)
	desired_name = sanitize_for_email(desired_name)
	var/domain
	if(domain_override)
		domain = domain_override
	else
		domain = default_domain
	var/login = "[desired_name]@[domain]"
	// It is VERY unlikely that we'll have two players, in the same round, with the same name and branch, but still, this is here.
	// If such conflict is encountered, a random number will be appended to the email address. If this fails too, no email account will be created.
	if(find_email_by_name(login))
		login = "[desired_name][random_id(/datum/computer_file/data/email_account/, 100, 999)]@[domain]"
	// If even fallback login generation failed, just don't give them an email. The chance of this happening is astronomically low.
	if(find_email_by_name(login))
		to_chat(user, "You were not assigned an email address.")
		user.StoreMemory("You were not assigned an email address.", /decl/memory_options/system)
	else
		var/datum/computer_file/data/email_account/EA = new/datum/computer_file/data/email_account(login, user.real_name, assignment)
		EA.password = GenerateKey()
		if(user.mind)
			user.mind.initial_email_login["login"] = EA.login
			user.mind.initial_email_login["password"] = EA.password
			user.StoreMemory("Your email account address is [EA.login] and the password is [EA.password].", /decl/memory_options/system)
		if(issilicon(user))
			var/mob/living/silicon/S = user
			var/datum/nano_module/email_client/my_client = S.get_subsystem_from_path(/datum/nano_module/email_client)
			if(my_client)
				my_client.stored_login = EA.login
				my_client.stored_password = EA.password

/datum/exonet/proc/find_email_by_name(var/login)
	for(var/datum/computer_file/data/email_account/A in email_accounts)
		if(A.login == login)
			return A
	return 0

/datum/exonet/proc/add_device(var/device, var/keydata)
	if(!router)
		return 0 // Uh?? No router? Guess the network is busted.
	if(router.lockdata != keydata)
		return 0 // Authentication failed.

	if(istype(device, /obj/machinery/computer/exonet/mainframe))
		LAZYDISTINCTADD(mainframes, device)
	else if(istype(device, /obj/machinery/computer/exonet/broadcaster))
		LAZYDISTINCTADD(broadcasters, device)
	else if(istype(device, /obj/machinery/computer/exonet/modem))
		LAZYDISTINCTADD(modems, device)
	else if(istype(device, /obj/machinery/computer/exonet/broadcaster/router) && !router)
		router = device // Special setty-uppy-timy for routers.
	LAZYDISTINCTADD(network_devices, device)

/datum/exonet/proc/remove_device(var/device)
	if(istype(device, /obj/machinery/computer/exonet/mainframe))
		LAZYREMOVE(mainframes, device)
	else if(istype(device, /obj/machinery/computer/exonet/broadcaster))
		LAZYREMOVE(broadcasters, device)
	else if(istype(device, /obj/machinery/computer/exonet/modem))
		LAZYREMOVE(modems, device)
	LAZYREMOVE(network_devices, device)

/datum/exonet/proc/set_router(var/device)
	router = device
	LAZYADD(network_devices, device)
	LAZYADD(broadcasters, device)

/datum/exonet/proc/check_banned(var/nid)
	return nid in banned_nids

// Simplified logging: Adds a log. log_string is mandatory parameter, source is optional.
/datum/exonet/proc/add_log(var/log_string, var/obj/item/weapon/stock_parts/computer/network_card/source = null)
	if(!log_server)
		return // No log server? No logs.
	var/datum/computer_file/data/logfile/logfile = log_server.get_log_file()
	if(!istype(logfile))
		return // No log file, or no space to create one. Or some other error.

	var/log_text = "[stationtime2text()] - "
	if(source)
		log_text += "[source.get_network_tag()] - "
	else
		log_text += "*SYSTEM* - "
	log_text += log_string
	var/list/logs = splittext(logfile.stored_data, "\[br\]")
	if(length(logs) >= log_server.setting_max_log_count)
		logs.Cut(1, 2)
	logs.Add(log_text)
	logfile.stored_data = jointext(logs, "\[br\]")

/datum/exonet/proc/get_signal_strength(var/obj/device, var/netspeed)
	var/best_signal = -1
	var/turf/device_turf = get_turf(device)
	if(!device_turf)
		return best_signal
	for(var/obj/machinery/computer/exonet/broadcaster/broadcaster in broadcasters)
		if(broadcaster.z != device_turf.z || !broadcaster.operable())
			continue // We only check same level.
		var/strength = (broadcaster.signal_strength * netspeed) - get_dist(broadcaster, device_turf)
		if(strength <= 0)
			continue
		best_signal = max(strength, best_signal)
	return best_signal

// Whether or not a specific function is capable on this network.
/datum/exonet/proc/check_function(var/specific_action = 0)
	return TRUE

/datum/exonet/proc/get_available_software_by_category()
	var/list/results = list()
	for(var/obj/machinery/computer/exonet/mainframe/mainframe in mainframes)
		for(var/datum/computer_file/program/prog in mainframe.get_available_software())
			LAZYDISTINCTADD(results[prog.category], prog)
	return results

/datum/exonet/proc/find_exonet_file_by_name(var/filename)
	for(var/obj/machinery/computer/exonet/mainframe/mainframe in mainframes)
		var/find_file = mainframe.find_file_by_name(filename)
		if(find_file)
			return find_file

/datum/exonet/proc/fetch_reports(access)
	var/list/available_reports = list()
	if(!report_server)
		return available_reports // There is no reporting server. No reports.
	for(var/datum/computer_file/report/report in report_server.stored_files)
		available_reports.Add(report)

	if(!access)
		return available_reports
	. = list()
	for(var/datum/computer_file/report/report in available_reports)
		if(report.verify_access_edit(access))
			. += report

/datum/exonet/proc/rename_email(mob/user, old_login, desired_name, domain)
	var/datum/computer_file/data/email_account/account = find_email_by_name(old_login)
	var/new_login = sanitize_for_email(desired_name)
	new_login += "@[domain]"
	if(new_login == old_login)
		return	//If we aren't going to be changing the login, we quit silently.
	if(find_email_by_name(new_login))
		to_chat(user, "Your email could not be updated: the new username is invalid.")
		return
	account.login = new_login
	to_chat(user, "Your email account address has been changed to <b>[new_login]</b>. This information has also been placed into your notes.")
	add_log("Email address changed for [user]: [old_login] changed to [new_login]")
	if(user.mind)
		user.mind.initial_email_login["login"] = new_login
		user.StoreMemory("Your email account address has been changed to [new_login].", /decl/memory_options/system)
	if(issilicon(user))
		var/mob/living/silicon/S = user
		var/datum/nano_module/email_client/my_client = S.get_subsystem_from_path(/datum/nano_module/email_client)
		if(my_client)
			my_client.stored_login = new_login

/mob/proc/create_or_rename_email(newname, domain)
	if(!mind || !GLOB.using_map.station_ennid)
		return

	var/datum/exonet/network = GLOB.exonets[GLOB.using_map.station_ennid]
	var/old_email = mind.initial_email_login["login"]
	if(!old_email)
		network.create_email(src, newname, domain)
	else
		network.rename_email(src, old_email, newname, domain)
