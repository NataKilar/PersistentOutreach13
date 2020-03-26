/datum/computer_file/program/ntnetmonitor
	filename = "ntmonitor"
	filedesc = "EXONET Diagnostics and Monitoring"
	program_icon_state = "comm_monitor"
	program_key_state = "generic_key"
	program_menu_icon = "wrench"
	extended_desc = "This program monitors the local EXONET network, provides access to logging systems, and allows for configuration changes"
	size = 12
	requires_exonet = 1
	required_access = access_network
	available_on_exonet = 1
	nanomodule_path = /datum/nano_module/program/computer_ntnetmonitor/
	category = PROG_ADMIN

/datum/nano_module/program/computer_ntnetmonitor
	name = "EXONET Diagnostics and Monitoring"
	available_to_ai = TRUE

/datum/nano_module/program/computer_ntnetmonitor/ui_interact(mob/user, ui_key = "main", var/datum/nanoui/ui = null, var/force_open = 1, var/datum/topic_state/state = GLOB.default_state)
	if(!exonet)
		return
	var/list/data = host.initial_data()

	data += "skill_fail"
	if(!user.skill_check(SKILL_COMPUTER, SKILL_BASIC))
		var/datum/extension/fake_data/fake_data = get_or_create_extension(src, /datum/extension/fake_data, 20)
		data["skill_fail"] = fake_data.update_and_return_data()
	data["terminal"] = !!program

	data["ntnetstatus"] = exonet.check_function()
	data["ntnetrelays"] = exonet.relays.len
	data["idsstatus"] = exonet.intrusion_detection_enabled
	data["idsalarm"] = exonet.intrusion_detection_alarm

	data["config_softwaredownload"] = exonet.setting_softwaredownload
	data["config_peertopeer"] = exonet.setting_peertopeer
	data["config_communication"] = exonet.setting_communication
	data["config_systemcontrol"] = exonet.setting_systemcontrol

	data["ntnetlogs"] = exonet.logs
	data["ntnetmaxlogs"] = exonet.setting_maxlogcount

	data["banned_nids"] = list(exonet.banned_nids)

	ui = SSnano.try_update_ui(user, src, ui_key, ui, data, force_open)
	if (!ui)
		ui = new(user, src, ui_key, "ntnet_monitor.tmpl", "EXONET Diagnostics and Monitoring Tool", 575, 700, state = state)
		if(host.update_layout())
			ui.auto_update_layout = 1
		ui.set_initial_data(data)
		ui.open()
		ui.set_auto_update(1)

/datum/nano_module/program/computer_ntnetmonitor/Topic(href, href_list, state)
	var/mob/user = usr
	if(..())
		return 1

	if(!user.skill_check(SKILL_COMPUTER, SKILL_BASIC))
		return 1

	if(href_list["resetIDS"])
		if(exonet)
			exonet.resetIDS()
		return 1
	if(href_list["toggleIDS"])
		if(exonet)
			exonet.toggleIDS()
		return 1
	if(href_list["toggleWireless"])
		if(!exonet)
			return 1

		// exonet is disabled. Enabling can be done without user prompt
		if(exonet.setting_disabled)
			exonet.setting_disabled = 0
			return 1

		// exonet is enabled and user is about to shut it down. Let's ask them if they really want to do it, as wirelessly connected computers won't connect without exonet being enabled (which may prevent people from turning it back on)
		if(!user)
			return 1
		var/response = alert(user, "Really disable EXONET wireless? If your computer is connected wirelessly you won't be able to turn it back on! This will affect all connected wireless devices.", "EXONET shutdown", "Yes", "No")
		if(response == "Yes")
			exonet.setting_disabled = 1
		return 1
	if(href_list["purgelogs"])
		if(exonet)
			exonet.purge_logs()
		return 1
	if(href_list["updatemaxlogs"])
		var/logcount = text2num(input(user,"Enter amount of logs to keep in memory ([MIN_NTNET_LOGS]-[MAX_NTNET_LOGS]):"))
		if(exonet)
			exonet.update_max_log_count(logcount)
		return 1
	if(href_list["toggle_function"])
		if(!exonet)
			return 1
		exonet.toggle_function(href_list["toggle_function"])
		return 1
	if(href_list["ban_nid"])
		if(!exonet)
			return 1
		var/nid = input(user,"Enter NID of device which you want to block from the network:", "Enter NID") as null|num
		if(nid && CanUseTopic(user, state))
			exonet.banned_nids |= nid
		return 1
	if(href_list["unban_nid"])
		if(!exonet)
			return 1
		var/nid = input(user,"Enter NID of device which you want to unblock from the network:", "Enter NID") as null|num
		if(nid && CanUseTopic(user, state))
			exonet.banned_nids -= nid
		return 1