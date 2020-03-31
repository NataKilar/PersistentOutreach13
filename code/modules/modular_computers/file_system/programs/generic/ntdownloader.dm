/datum/computer_file/program/exonetdownload
	filename = "ntndownloader"
	filedesc = "EXONET Software Download Tool"
	program_icon_state = "generic"
	program_key_state = "generic_key"
	program_menu_icon = "arrowthickstop-1-s"
	extended_desc = "This program allows downloads of software from official software repositories"
	unsendable = 1
	undeletable = 1
	size = 4
	requires_exonet = 1
	requires_exonet_feature = NETWORK_SOFTWAREDOWNLOAD
	nanomodule_path = /datum/nano_module/program/computer_exonetdownload/
	ui_header = "downloader_finished.gif"
	var/datum/computer_file/program/downloaded_file = null
	var/hacked_download = 0
	var/download_completion = 0 //GQ of downloaded data.
	var/download_netspeed = 0
	var/downloaderror = ""
	var/list/downloads_queue[0]
	var/file_info //For logging, can be faked by antags.
	var/server
	usage_flags = PROGRAM_ALL
	category = PROG_UTIL

/datum/computer_file/program/exonetdownload/on_shutdown()
	..()
	downloaded_file = null
	download_completion = 0
	download_netspeed = 0
	downloaderror = ""
	ui_header = "downloader_finished.gif"

/datum/computer_file/program/exonetdownload/proc/begin_file_download(var/filename, skill)
	if(downloaded_file)
		return 0

	var/obj/item/weapon/stock_parts/computer/network_card/network_card = computer.get_component(PART_NETWORK)
	var/datum/extension/exonet_device/exonet = get_extension(network_card, /datum/extension/exonet_device)
	var/datum/exonet/network = exonet.get_local_network()
	var/datum/computer_file/program/PRG = network.find_exonet_file_by_name(filename)

	if(!check_file_download(filename))
		return 0

	ui_header = "downloader_running.gif"

	file_info = hide_file_info(PRG)
	generate_network_log("Began downloading file [file_info] from [server].")
	downloaded_file = PRG.clone()

/datum/computer_file/program/exonetdownload/proc/check_file_download(var/filename)
	//returns 1 if file can be downloaded, returns 0 if download prohibited
	var/obj/item/weapon/stock_parts/computer/network_card/network_card = computer.get_component(PART_NETWORK)
	var/datum/extension/exonet_device/exonet = get_extension(network_card, /datum/extension/exonet_device)
	var/datum/exonet/network = exonet.get_local_network()
	var/datum/computer_file/program/PRG = network.find_exonet_file_by_name(filename)

	if(!PRG || !istype(PRG))
		return 0

	// Attempting to download antag only program, but without having emagged computer. No.
	if(PRG.available_on_syndinet && !computer.emagged())
		return 0

	if(!computer || !computer.try_store_file(PRG))
		return 0

	return 1

/datum/computer_file/program/exonetdownload/proc/hide_file_info(datum/computer_file/file, skill)
	//server = (file in ntnet_global.available_station_software) ? "NTNet Software Repository" : "unspecified server"
	if(!hacked_download)
		return "[file.filename].[file.filetype]"
	var/stealth_chance = max(skill - SKILL_BASIC, 0) * 30
	if(!prob(stealth_chance))
		return "**ENCRYPTED**.[file.filetype]"
	//var/datum/computer_file/fake_file = pick(ntnet_global.available_station_software)julie pls fix
	//server = "NTNet Software Repository"
	//return "[fake_file.filename].[fake_file.filetype]"

/datum/computer_file/program/exonetdownload/proc/abort_file_download()
	if(!downloaded_file)
		return
	generate_network_log("Aborted download of file [file_info].")
	downloaded_file = null
	download_completion = 0
	ui_header = "downloader_finished.gif"

/datum/computer_file/program/exonetdownload/proc/complete_file_download()
	if(!downloaded_file)
		return
	generate_network_log("Completed download of file [file_info].")
	if(!computer || !computer.store_file(downloaded_file))
		// The download failed
		downloaderror = "I/O ERROR - Unable to save file. Check whether you have enough free space on your hard drive and whether your hard drive is properly connected. If the issue persists contact your system administrator for assistance."
	downloaded_file = null
	download_completion = 0
	ui_header = "downloader_finished.gif"

/datum/computer_file/program/exonetdownload/process_tick()
	if(!downloaded_file)
		return
	if(download_completion >= downloaded_file.size)
		complete_file_download()
		if(downloads_queue.len > 0)
			begin_file_download(downloads_queue[1], downloads_queue[downloads_queue[1]])
			downloads_queue.Remove(downloads_queue[1])

	// Download speed according to connectivity state. NTNet server is assumed to be on unlimited speed so we're limited by our local connectivity
	download_netspeed = 0
	// Speed defines are found in misc.dm
	switch(computer.get_exonet_status(NETWORK_SOFTWAREDOWNLOAD))
		if(1)
			download_netspeed = NETWORKSPEED_LOWSIGNAL
		if(2)
			download_netspeed = NETWORKSPEED_HIGHSIGNAL
		if(3)
			download_netspeed = NETWORKSPEED_ETHERNET
	download_completion += download_netspeed

/datum/computer_file/program/exonetdownload/Topic(href, href_list)
	if(..())
		return 1
	if(href_list["PRG_downloadfile"])
		if(!downloaded_file)
			begin_file_download(href_list["PRG_downloadfile"], usr.get_skill_value(SKILL_COMPUTER))
		else if(check_file_download(href_list["PRG_downloadfile"]) && !downloads_queue.Find(href_list["PRG_downloadfile"]) && downloaded_file.filename != href_list["PRG_downloadfile"])
			downloads_queue[href_list["PRG_downloadfile"]] = usr.get_skill_value(SKILL_COMPUTER)
		return 1
	if(href_list["PRG_removequeued"])
		downloads_queue.Remove(href_list["PRG_removequeued"])
		return 1
	if(href_list["PRG_reseterror"])
		if(downloaderror)
			download_completion = 0
			download_netspeed = 0
			downloaded_file = null
			downloaderror = ""
		return 1
	return 0

/datum/nano_module/program/computer_exonetdownload
	name = "Network Downloader"

/datum/nano_module/program/computer_exonetdownload/proc/get_functional_network_card()
	var/datum/extension/interactive/ntos/os = get_extension(nano_host(), /datum/extension/interactive/ntos)
	var/obj/item/weapon/stock_parts/computer/network_card/network_card = os && os.get_component(/obj/item/weapon/stock_parts/computer/network_card)
	if(!network_card || !network_card.check_functionality())
		// error = "Error establishing connection. Are you using a functional and NTOSv2-compliant device?"
		return
	return network_card

/datum/nano_module/program/computer_exonetdownload/ui_interact(mob/user, ui_key = "main", var/datum/nanoui/ui = null, var/force_open = 1, var/datum/topic_state/state = GLOB.default_state)
	var/list/data = list()
	var/datum/computer_file/program/exonetdownload/prog = program
	// For now limited to execution by the downloader program
	if(!prog || !istype(prog))
		return
	if(program)
		data = program.get_header_data()

	data["network_unavailable"] = FALSE
	// This IF cuts on data transferred to client, so i guess it's worth it.
	if(prog.downloaderror) // Download errored. Wait until user resets the program.
		data["error"] = prog.downloaderror
	if(prog.downloaded_file) // Download running. Wait please..
		data["downloadname"] = prog.downloaded_file.filename
		data["downloaddesc"] = prog.downloaded_file.filedesc
		data["downloadsize"] = prog.downloaded_file.size
		data["downloadspeed"] = prog.download_netspeed
		data["downloadcompletion"] = round(prog.download_completion, 0.1)

	data["disk_size"] = program.computer.max_disk_capacity()
	data["disk_used"] = program.computer.used_disk_capacity()
	var/list/all_entries[0]
	var/obj/item/weapon/stock_parts/computer/network_card/network_card = get_functional_network_card()
	var/datum/extension/exonet_device/exonet = get_extension(network_card, /datum/extension/exonet_device)
	var/datum/exonet/network = exonet.get_local_network()
	if(!network)
		data["network_unavailable"] = TRUE
	else
		var/list/available_software_by_category = network.get_available_software_by_category()
		for(var/category in available_software_by_category)
			var/list/category_list[0]
			for(var/datum/computer_file/program/P in available_software_by_category[category])
				// Only those programs our user can run will show in the list
				if(!P.can_run(user) && P.requires_access_to_download)
					continue
				if(!P.is_supported_by_hardware(program.computer.get_hardware_flag(), user, TRUE))
					continue
				category_list.Add(list(list(
				"filename" = P.filename,
				"filedesc" = P.filedesc,
				"fileinfo" = P.extended_desc,
				"size" = P.size,
				"icon" = P.program_menu_icon
				)))
			if(category_list.len)
				all_entries.Add(list(list("category"=category, "programs"=category_list)))

	data["hackedavailable"] = 0
	data["downloadable_programs"] = all_entries

	if(prog.downloads_queue.len > 0)
		var/list/queue = list() // Nanoui can't iterate through assotiative lists, so we have to do this
		for(var/item in prog.downloads_queue)
			queue += item
		data["downloads_queue"] = queue

	ui = SSnano.try_update_ui(user, src, ui_key, ui, data, force_open)
	if (!ui)
		ui = new(user, src, ui_key, "ntnet_downloader.tmpl", "EXONET Download Program", 575, 700, state = state)
		ui.auto_update_layout = 1
		ui.set_initial_data(data)
		ui.open()
		ui.set_auto_update(1)
