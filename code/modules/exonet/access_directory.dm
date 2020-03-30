/obj/machinery/computer/exonet/access_directory
	name = "EXONET Access Controller"
	desc = "A very complex machine that manages the security for an EXONET system. Looks fragile."
	active_power_usage = 4 KILOWATTS
	ui_template = "exonet_access_directory.tmpl"

	// These are program stateful variables.
	var/file_server				// What file_server we're viewing. This is a net_tag or other.
	var/editing_user			// If we're editing a user, it's assigned here.
	var/awaiting_cortical_scan	// If this is true, we're waiting for someone to touch the stupid interface so that'll add a new user record.
	var/last_scan				// The UID of the person last scanned by this machine. Do not deserialize this. It's worthless.
	var/list/initial_grants		// List of initial grants the machine can try to make on first loadup.
	var/error					// Currently displayed error.

/obj/machinery/computer/exonet/access_directory/on_update_icon()
	if(operable())
		icon_state = "bus"
	else
		icon_state = "bus_off"

/obj/machinery/computer/exonet/access_directory/LateInitialize()
	. = ..()
	if(initial_grants)
		var/datum/extension/exonet_device/exonet = get_extension(src, /datum/extension/exonet_device)
		if(!file_server)
			var/list/mainframes = exonet.get_mainframes()
			if(mainframes.len <= 0)
				.["error"] = "NETWORK ERROR: No mainframes are available for storing security records."
				return .
			var/obj/machinery/computer/exonet/mainframe/MF = mainframes[1]
			file_server = exonet.get_network_tag(MF)
			for(var/initial_grant in initial_grants)
				var/datum/computer_file/data/grant_record/GR = new()
				GR.set_value(initial_grant)
				MF.store_file(GR)
		initial_grants = null

// Gets all grants on the machine we're currently linked to.
/obj/machinery/computer/exonet/access_directory/proc/get_all_grants()
	var/datum/extension/exonet_device/exonet = get_extension(src, /datum/extension/exonet_device)
	var/obj/machinery/computer/exonet/mainframe/mainframe = exonet.get_device_by_tag(file_server)
	if(!mainframe)
		return // No connection.
	var/list/grants = list()
	for(var/datum/computer_file/data/grant_record/GR in mainframe.stored_files)
		grants.Add(GR)
	return grants

// Get the access record for the user we're *currently* editing.
/obj/machinery/computer/exonet/access_directory/proc/get_access_record(var/for_specific_id)
	var/datum/extension/exonet_device/exonet = get_extension(src, /datum/extension/exonet_device)
	var/obj/machinery/computer/exonet/mainframe/mainframe = exonet.get_device_by_tag(file_server)
	if(!mainframe)
		return
	var/for_user = for_specific_id
	if(!for_user)
		for_user = editing_user
	for(var/datum/computer_file/data/access_record/AR in mainframe.stored_files)
		if(AR.user_id != for_user)
			continue
		return AR

/obj/machinery/computer/exonet/access_directory/Topic(href, href_list)
	if(..())
		return TOPIC_HANDLED

	var/datum/extension/exonet_device/exonet = get_extension(src, /datum/extension/exonet_device)

	if(href_list["PRG_back"])
		error = null
		editing_user = null

	if(href_list["PRG_changefileserver"])
		var/old_value = file_server
		var/list/file_servers = list()
		for(var/obj/machinery/computer/exonet/mainframe/mainframe in exonet.get_mainframes())
			LAZYDISTINCTADD(file_servers, exonet.get_network_tag(mainframe))
		file_server = sanitize(input(usr, "Choose a fileserver to view access records on:", "Select File Server") as null|anything in file_servers)
		if(!file_server)
			file_server = old_value // Safety check.

	if(href_list["PRG_assigngrant"])
		var/list/all_grants = get_all_grants()
		// Resolve our selection back to a file.
		var/datum/computer_file/data/grant_record/grant
		for(var/datum/computer_file/data/grant_record/GR in all_grants)
			if(href_list["PRG_assigngrant"] == GR.stored_data)
				grant = GR
				break
		var/datum/computer_file/data/access_record/AR = get_access_record()
		if(!AR)
			error = "ERROR: Access record not found."
			return TOPIC_HANDLED
		AR.add_grant(grant) // Add the grant to the record.
	if(href_list["PRG_removegrant"])
		var/datum/computer_file/data/access_record/AR = get_access_record()
		if(!AR)
			error = "ERROR: Access record not found."
			return TOPIC_HANDLED
		AR.remove_grant(href_list["PRG_removegrant"]) // Add the grant to the record.
	if(href_list["PRG_creategrant"])
		var/new_grant_name = uppertext(sanitize(input(usr, "Enter the name of the new grant:", "Create Grant")))
		if(!new_grant_name)
			return TOPIC_HANDLED
		var/obj/machinery/computer/exonet/mainframe/mainframe = exonet.get_device_by_tag(file_server)
		if(!mainframe)
			error = "NETWORK ERROR: Lost connection to mainframe. Unable to save new grant."
			return TOPIC_HANDLED
		var/datum/computer_file/data/grant_record/new_grant = new()
		new_grant.stored_data = new_grant_name
		new_grant.filename = new_grant_name
		new_grant.calculate_size()
		if(!mainframe.store_file(new_grant))
			error = "MAINFRAME ERROR: Unable to store grant on mainframe."
			return TOPIC_HANDLED
	if(href_list["PRG_deletegrant"])
		var/obj/machinery/computer/exonet/mainframe/mainframe = exonet.get_device_by_tag(file_server)
		if(!mainframe)
			error = "NETWORK ERROR: Lost connection to mainframe."
			return TOPIC_HANDLED
		mainframe.delete_file_by_name(href_list["PRG_deletegrant"])
	if(href_list["PRG_adduser"])
		var/new_user_id = sanitize(input(usr, "Enter user's PLEXUS ID or leave blank to cancel:", "Add New User"))
		if(!new_user_id)
			return TOPIC_HANDLED
		var/new_user_name = sanitize(input(usr, "Enter user's desired name or leave blank to cancel:", "Add New User"))
		if(!new_user_name)
			return TOPIC_HANDLED
		// TODO: Add a check to see if this user actually exists if PLEXUS is online.
		// Add the record.
		var/obj/machinery/computer/exonet/mainframe/mainframe = exonet.get_device_by_tag(file_server)
		if(!mainframe)
			error = "NETWORK ERROR: Lost connection to mainframe. Unable to save user access record."
			return TOPIC_HANDLED
		var/datum/computer_file/data/access_record/new_record = new()
		new_record.filename = "[replacetext(new_user_name, " ", "_")]"
		new_record.user_id = new_user_id
		new_record.desired_name = new_user_name
		new_record.ennid = ennid
		new_record.calculate_size()
		if(!mainframe.store_file(new_record))
			error = "MAINFRAME ERROR: Unable to store record on mainframe."
			return TOPIC_HANDLED
		editing_user = new_user_id
	if(href_list["PRG_viewuser"])
		editing_user = href_list["PRG_viewuser"]
	if(href_list["PRG_deleteuser"])
		var/obj/machinery/computer/exonet/mainframe/mainframe = exonet.get_device_by_tag(file_server)
		if(!mainframe)
			error = "NETWORK ERROR: Lost connection to mainframe."
			return TOPIC_HANDLED
		var/datum/computer_file/data/access_record/AR = get_access_record(href_list["PRG_rename"])
		if(!AR)
			return TOPIC_HANDLED
		mainframe.delete_file_by_name(AR.filename)
	if(href_list["PRG_rename"])
		var/obj/machinery/computer/exonet/mainframe/mainframe = exonet.get_device_by_tag(file_server)
		if(!mainframe)
			error = "NETWORK ERROR: Lost connection to mainframe."
			return TOPIC_HANDLED
		var/new_user_name = sanitize(input(usr, "Enter user's new desired name or leave blank to cancel:", "Rename User"))
		if(!new_user_name)
			return TOPIC_HANDLED
		var/datum/computer_file/data/access_record/AR = get_access_record(href_list["PRG_rename"])
		if(!AR)
			return TOPIC_HANDLED
		AR.desired_name = new_user_name
	. = TOPIC_REFRESH


/obj/machinery/computer/exonet/access_directory/build_ui_data()
	. = ..()

	if(error)
		.["error"] = error
		return .

	var/datum/extension/exonet_device/exonet = get_extension(src, /datum/extension/exonet_device)
	if(!file_server)
		var/list/mainframes = exonet.get_mainframes()
		if(length(mainframes) <= 0)
			.["error"] = "NETWORK ERROR: No mainframes are available for storing security records."
			return .
		file_server = exonet.get_network_tag(mainframes[1])

	.["file_server"] = file_server
	.["editing_user"] = editing_user
	.["awaiting_cortical_scan"] = awaiting_cortical_scan
	if(awaiting_cortical_scan)
		return .

	// Let's build some data.
	var/obj/machinery/computer/exonet/mainframe/mainframe = exonet.get_device_by_tag(file_server)
	if(!mainframe || !mainframe.operable())
		.["error"] = "NETWORK ERROR: Mainframe is offline."
		return .
	if(editing_user)
		.["user_id"] = editing_user
		var/datum/computer_file/data/access_record/AR = get_access_record()
		var/list/grants[0]
		var/list/assigned_grants = AR.get_valid_grants()
		// We're editing a user, so we only need to build a subset of data.
		.["desired_name"]	= AR.desired_name
		.["grant_count"] 	= length(assigned_grants)
		.["size"] 			= AR.size
		for(var/datum/computer_file/data/grant_record/GR in get_all_grants())
			grants.Add(list(list(
				"grant_name" = GR.stored_data,
				"assigned" = (GR in assigned_grants)
			)))
		.["grants"] = grants
	else
		// We're looking at all records. Or lack thereof.
		var/list/users[0]
		for(var/datum/computer_file/data/access_record/AR in mainframe.stored_files)
			users.Add(list(list(
				"desired_name" = AR.desired_name,
				"user_id" = AR.user_id,
				"grant_count" = length(AR.get_valid_grants()),
				"size" = AR.size
			)))
		.["users"] = users