//Shuttle controller computer for shuttles going between sectors
/obj/machinery/computer/shuttle_control/explore
	name = "general shuttle control console"
	ui_template = "shuttle_control_console_exploration.tmpl"
	base_type = /obj/machinery/computer/shuttle_control/explore

	// Custom landing locations.
	var/eye_type = /mob/observer/eye/shuttle/
	var/mob/observer/eye/shuttle/eyeobj = null

	var/datum/action/shuttle/finish_landing/finish_landing_action
	var/datum/action/shuttle/end_landing/end_landing_action
	var/mob/current_user

/obj/machinery/computer/shuttle_control/explore/Initialize()
	. = ..()
	finish_landing_action = new(src)
	end_landing_action = new(src)

/obj/machinery/computer/shuttle_control/explore/Destroy()
	end_landing()
	current_user = null
	QDEL_NULL(finish_landing_action)
	QDEL_NULL(end_landing_action)

/obj/machinery/computer/shuttle_control/explore/get_ui_data(var/datum/shuttle/autodock/overmap/shuttle)
	. = ..()
	if(istype(shuttle))
		shuttle.refresh_fuel_ports_list()
		var/total_gas = 0
		for(var/obj/structure/fuel_port/FP in shuttle.fuel_ports) //loop through fuel ports
			var/obj/item/weapon/tank/fuel_tank = locate() in FP
			if(fuel_tank)
				total_gas += fuel_tank.air_contents.total_moles

		var/fuel_span = "good"
		if(total_gas < shuttle.fuel_consumption * 2)
			fuel_span = "bad"

		. += list(
			"destination_name" = shuttle.get_destination_name(),
			"can_pick" = shuttle.moving_status == SHUTTLE_IDLE,
			"fuel_usage" = shuttle.fuel_consumption * 100,
			"remaining_fuel" = round(total_gas, 0.01) * 100,
			"fuel_span" = fuel_span
		)

/obj/machinery/computer/shuttle_control/explore/handle_topic_href(var/datum/shuttle/autodock/overmap/shuttle, var/list/href_list, var/usr)
	if(ismob(usr))
		var/mob/user = usr
		shuttle.operator_skill = user.get_skill_value(SKILL_PILOT)

	if((. = ..()) != null)
		return

	if(href_list["pick"])
		var/list/possible_d = shuttle.get_possible_destinations()
		var/D
		if(possible_d.len)
			D = input("Choose shuttle destination", "Shuttle Destination") as null|anything in possible_d
		else
			to_chat(usr,SPAN_WARNING("No valid landing sites in range."))
		possible_d = shuttle.get_possible_destinations()
		if(CanInteract(usr, GLOB.default_state) && (D in possible_d))
			shuttle.set_destination(possible_d[D])
		return TOPIC_REFRESH

	if(href_list["custom_landing"])
		if(current_user && current_user != usr)
			to_chat(usr, SPAN_WARNING("Someone is already performing a landing maneuver!"))
			return TOPIC_REFRESH
		if(eyeobj)
			end_landing()
		else
			start_landing(usr, shuttle)
		return TOPIC_REFRESH

/obj/machinery/computer/shuttle_control/explore/CouldNotUseTopic(var/mob/user)
	end_landing()
	..()

/obj/machinery/computer/shuttle_control/explore/proc/start_landing(var/mob/user, var/datum/shuttle/autodock/overmap/shuttle)
	var/obj/effect/overmap/visitable/ship/landable/ship = shuttle.parent_ship

	var/obj/effect/overmap/visitable/sector
	if(!ship)
		to_chat(user, SPAN_WARNING("Error! Could not begin landing procedure!"))
		return
	if(ship.status == SHIP_STATUS_TRANSIT)
		to_chat(user, SPAN_WARNING("Wait for the ship to complete its current movement!"))
		return
	if(ship.status == SHIP_STATUS_OVERMAP)
		var/list/available_sectors = list()
		for(var/obj/effect/overmap/visitable/S in get_turf(ship))
			if(S == ship)	// We can't perform landing on our own ship's z-level
				continue
			available_sectors += S

		sector = input("Choose sector to land in.", "Sectors") as null|anything in available_sectors

		if(!sector || !istype(sector))
			to_chat(user, SPAN_WARNING("No valid landing areas!"))
			return

	GLOB.moved_event.register(user, src, /obj/machinery/computer/shuttle_control/explore/proc/end_landing)
	GLOB.stat_set_event.register(user, src, /obj/machinery/computer/shuttle_control/explore/proc/end_landing)
	GLOB.logged_out_event.register(user, src, /obj/machinery/computer/shuttle_control/explore/proc/end_landing)	// Prevents easy abuse of log-in/log-out to remove
																											// obfuscation images.
	var/turf/eye_turf = sector ? locate(world.maxx/2, world.maxy/2, sector.map_z[sector.map_z.len]) : get_turf(shuttle.current_location)

	eyeobj = new eye_type(eye_turf, shuttle_tag)

	eyeobj.possess(user)
	eyeobj.setLoc(eye_turf)
	eyeobj.add_obfuscation(UP) // Ensures that the immediate area around the eye on possession has obfuscation properly added.

	finish_landing_action.Grant(user)
	end_landing_action.Grant(user)

/obj/machinery/computer/shuttle_control/explore/proc/finish_landing(var/mob/user)
	if(!eyeobj.check_landing()) // If the eye says we can't land, keep us in the landing view.
		return
	var/turf/lm_turf = get_turf(eyeobj)
	var/datum/shuttle/autodock/overmap/shuttle = SSshuttle.shuttles[shuttle_tag]
	var/obj/effect/shuttle_landmark/temporary/LZ = new(lm_turf, shuttle_tag)
	if(LZ.is_valid(shuttle) && !(lm_turf.z in GLOB.using_map.mining_areas)) // Checking that the shuttle fits, and that we're not landing undeground.
		shuttle.set_destination(LZ)
	else
		qdel(LZ)
		to_chat(user, SPAN_WARNING("Invalid landing zone!"))
	end_landing()

/obj/machinery/computer/shuttle_control/explore/proc/end_landing(var/mob/user)
	GLOB.moved_event.unregister(user, src, /obj/machinery/computer/shuttle_control/explore/proc/end_landing)
	GLOB.stat_set_event.unregister(user, src, /obj/machinery/computer/shuttle_control/explore/proc/end_landing)
	GLOB.logged_out_event.unregister(user, src, /obj/machinery/computer/shuttle_control/explore/proc/end_landing)
	if(current_user)
		finish_landing_action.Remove(current_user)
		end_landing_action.Remove(current_user)
	QDEL_NULL(eyeobj)
	current_user = null

/datum/action/shuttle/
	action_type = AB_GENERIC
	check_flags = AB_CHECK_STUNNED|AB_CHECK_LYING

/datum/action/shuttle/CheckRemoval(mob/living/user)
	if(!user.eyeobj || !istype(user.eyeobj, /mob/observer/eye/shuttle))
		return TRUE

/datum/action/shuttle/finish_landing
	name = "Set landing location"
	procname = "finish_landing"
	button_icon_state = "shuttle_land"

/datum/action/shuttle/end_landing
	name = "Exit landing mode"
	procname = "end_landing"
	button_icon_state = "shuttle_cancel"
