GLOBAL_LIST_INIT(docking_beacons, list())  // List of docking beacons by Z-level.

#define BEACON_OFF			0		// Beacon cannot be used for landing or for construction
#define BEACON_LANDING		1		// Beacon is open for landing in defined area
#define BEACON_CONSTRUCTION 2		// Beacon is in construction mode

#define MAX_LANDING_SIZE	25
#define MIN_LANDING_SIZE	9

/obj/machinery/docking_beacon
	name = "docking beacon"
	desc = "A device used to aid in the piloting of spacecraft. Can be used to construct and designate landing zones for shuttles and ships."
	icon = 'icons/obj/machines/power/fusion.dmi'
	icon_state = "injector1"
	use_power = POWER_USE_OFF
	anchored = FALSE
	interact_offline = TRUE

	var/docking_mode = BEACON_OFF
	var/list/turf/landing_turfs = list()
	var/landing_size_width = MIN_LANDING_SIZE
	var/landing_size_length = MIN_LANDING_SIZE

	var/error_message = ""

/obj/machinery/docking_beacon/Destroy()
	LAZYREMOVE(GLOB.docking_beacons["[z]"], src)
	landing_turfs.Cut()
	. = ..()

/obj/machinery/docking_beacon/attackby(obj/item/I, mob/user)
	if(isWrench(I))
		playsound(src.loc, 'sound/items/Ratchet.ogg', 50, 1)
		if(do_after(user, 20, src))
			to_chat(user, "<span class='notice'>You wrench the docking beacon [anchored ? "out of" : "into"] place.</span>")
			anchored = !anchored
			change_mode(BEACON_OFF)
			LAZYDISTINCTADD(GLOB.docking_beacons["[z]"], src)
	..()

/obj/machinery/docking_beacon/Move()
	change_mode(BEACON_OFF)			 	// Prevent lingering valid landing zones when moving the beacon around
	LAZYREMOVE(GLOB.docking_beacons["[z]"], src) // In case a docking_beacon is moved into a new Z-level.
	. = ..()

/obj/machinery/docking_beacon/interface_interact(user)
	ui_interact(user)
	return TRUE

/obj/machinery/docking_beacon/ui_interact(mob/user, ui_key = "main", var/datum/nanoui/ui = null, var/force_open = 1)
	var/data[0]

	data["mode"] = docking_mode
	data["width"] = landing_size_width
	data["length"] = landing_size_length
	data["error_message"] = error_message
	if(docking_mode == BEACON_CONSTRUCTION)
		data["check_finalize"] = check_finalize()

	ui = SSnano.try_update_ui(user, src, ui_key, ui, data, force_open)
	if (!ui)
		ui = new(user, src, ui_key, "docking_beacon.tmpl", "Docking Beacon Control", 520, 410)
		ui.set_initial_data(data)
		ui.open()

/obj/machinery/docking_beacon/OnTopic(user, href_list, state)
	if(href_list["change_mode"])
		change_mode(text2num(href_list["change_mode"]))

		return TOPIC_REFRESH

	if(href_list["set_width"])
		var/new_width = input("Input new odd-valued width (Between [MIN_LANDING_SIZE] and [MAX_LANDING_SIZE]", "Area size input", landing_size_width) as num|null
		if(!CanInteract(user, state))
			return TOPIC_HANDLED

		if(new_width)
			new_width = Clamp(new_width, MIN_LANDING_SIZE, MAX_LANDING_SIZE)
			landing_size_width = IsOdd(new_width) ? new_width : new_width + 1	// Width of the landing area must be odd to align with beacon.
			landing_turfs = find_landing_turfs()
			return TOPIC_REFRESH

	if(href_list["set_length"])
		var/new_length = input("Input new length (Between [MIN_LANDING_SIZE] and [MAX_LANDING_SIZE]", "Area size input", landing_size_length) as num|null
		if(!CanInteract(user, state))
			return TOPIC_HANDLED

		if(new_length)
			landing_size_length = Clamp(new_length, MIN_LANDING_SIZE, MAX_LANDING_SIZE)
			landing_turfs = find_landing_turfs()
			return TOPIC_REFRESH
	if(href_list["preview_area"])
		if(LAZYLEN(landing_turfs))
			for(var/turf/T in landing_turfs)
				new/obj/effect/temporary(T, 100, 'icons/effects/alphacolors.dmi', "green") // Briefly highlight the area for landing or construction.

		return TOPIC_HANDLED

/obj/machinery/docking_beacon/proc/change_mode(var/new_mode)
	docking_mode = new_mode
	if(docking_mode > 0)
		landing_turfs = find_landing_turfs()
	else
		landing_turfs.Cut()

/obj/machinery/docking_beacon/proc/find_landing_turfs()
	// Finds all the turfs that the docking beacon currently allows for landing or construction.
	var/mod_width = (landing_size_width - 1)/2
	var/list/turf/turfs = list()
	switch(dir)
		if(NORTH)
			turfs = block(locate(max(1, x - mod_width), min(world.maxy, y+1), z), locate(min(world.maxx, x+mod_width), min(world.maxy, y + landing_size_length), z))
		if(SOUTH)
			turfs = block(locate(max(1, x - mod_width), max(1, y - landing_size_length), z), locate(min(world.maxx, x + mod_width), max(1, y-1), z))
		if(EAST)
			turfs = block(locate(min(world.maxx, x+1), max(1, y - mod_width), z), locate(min(world.maxx, x + landing_size_length), min(world.maxy, y + mod_width), z))
		if(WEST)
			turfs = block(locate(max(1, x - landing_size_length), max(1, y - mod_width), z), locate(max(1, x-1), min(world.maxy, y + mod_width), z))

	for(var/turf/T in turfs)
		if(!IsValidLandingTurf(T))
			LAZYREMOVE(turfs, T)
	return turfs

/obj/machinery/docking_beacon/proc/check_finalize()


// Finalizes and creates the ship and shuttle. This can never fail, and will always generate the new ship and shuttle.
/obj/machinery/docking_beacon/proc/finalize()
	// First, create and initialize the shuttle
	var/list/shuttle_areas = list()
	for(var/turf/T in landing_turfs)
		if(!T.loc)
			continue
		if(istype(T, /turf/simulated/floor/exoplanet)) // Let's not pull up the ground with us
			continue
		if(istype(T.loc, /area/space))			   // Or the space-time fabric of the universe.
			message_admins("Bruh")

/proc/IsValidLandingTurf(var/turf/simulated/floor/T)
	if(istype(T, /turf/space))
		return TRUE
	if(!istype(T))
		return FALSE
	if(T.is_plating() || istype(T, /turf/simulated/floor/exoplanet))
		return TRUE

	return FALSE