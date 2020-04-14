#define MAX_DIST_FROM_CORE  30
#define MAX_SHIP_TILES	   250
/obj/machinery/computer/exonet/shipcore
	name = "ship core"
	desc = "A twisting mass of wires and consoles, working in tangent to coordinate the ship's systems."
	active_power_usage = 20 KILOWATTS
	ui_template = "ship_core.tmpl"
	var/finalized = FALSE		 // After the ship has been finalized and created, this is set to true.
	var/ship_name				 // Name and tag of both the ship and shuttle.

	// Ship construction
	var/list/ship_areas = list() // All areas of the ship. Unable to be modified post-finalization.
	var/list/errors = list()	 // Given to the ui to let players know what went wrong.
	var/list/turf_count			 // Turf count is used to give a rough idea of the size and mass of the ship.
	var/fore_dir = NORTH		 // Which way the ship is pointing. Engines need to be pointing the opposite direction to work.

	var/base_area 				 // Used to determine what the ship will leave behind on takeoff. Passed on to construction landmark.
	var/base_turf

	// Ship loading
	var/in_space = FALSE		 // Used to determine if the ship is in it's own z-level used for overmap travel on load. Always false if the ship has not been finalized.
	var/ship_saved_x
	var/ship_saved_y

/obj/machinery/computer/exonet/shipcore/Initialize()
	. = ..()
	return INITIALIZE_HINT_LATELOAD

/obj/machinery/computer/exonet/shipcore/LateInitialize()
	if(finalized)
		finalize() // Remake the ship on load.

/obj/machinery/computer/exonet/shipcore/ui_interact(var/mob/user, ui_key = "main", var/datum/nanoui/ui = null, var/force_open = 1)
	if(ui_template)		// Refreshing the list of errors.
		var/list/data = build_ui_data()
		ui = SSnano.try_update_ui(user, src, ui_key, ui, data, force_open)
		if (!ui)
			ui = new(user, src, ui_key, ui_template, "Ship Core", 640, 500)
			ui.set_initial_data(data)
			ui.open()

/obj/machinery/computer/exonet/shipcore/build_ui_data()
	. = ..()
	find_ship_areas()
	.["can_finalize"] = check_finalize()

	if(errors.len)
		.["errors"] = errors

	.["ship_name"] = ship_name

	var/list/area_names = list()
	for(var/area/A in ship_areas)
		area_names += A.name

	.["ship_areas"] = area_names
	var/ship_class = ""
	switch(turf_count)
		if(0 to 90)
			ship_class = "Transport"
		if(91 to 150)
			ship_class = "Cruiser"
		if(151 to MAX_SHIP_TILES)
			ship_class = "Freighter"
		else
			ship_class = "Invalid ship size"

	.["ship_class"] = ship_class
	.["fore_dir"] = dir_name(fore_dir)
	.["finalized"] = finalized

/obj/machinery/computer/exonet/shipcore/Topic(href, href_list)
	if(..())
		return TOPIC_HANDLED
	if(href_list["change_ship_name"])

		var/new_ship_name = sanitize(input(usr, "Enter a new ship name:", "Change ship name.") as null|text)
		if(!new_ship_name)
			return TOPIC_HANDLED

		ship_name = new_ship_name
		return TOPIC_REFRESH
	if(href_list["change_fore_dir"])
		var/list/directions = list("North", "South", "East", "West")
		var/new_fore_dir = input(usr, "Enter a new helm direction:", "Change helm direction.") as null|anything in directions

		if(!new_fore_dir)
			return TOPIC_HANDLED

		fore_dir = dir_flag(new_fore_dir)

		return TOPIC_REFRESH

	if(href_list["finalize"])
		if(check_finalize())
			var/confirm = alert(usr, "This will permanently finalize the ship, are you sure?", "Ship finalization", "Yes", "No")
			if(confirm == "No")
				return TOPIC_HANDLED
			else
				finalize()
				return TOPIC_REFRESH

/obj/machinery/computer/exonet/shipcore/proc/find_ship_areas()
	if(!ship_name)
		return
	ship_areas.Cut() // No lingering areas if something changes.
	turf_count = 0

	finding_ship_areas:
		for(var/area/A)
			if(A.construction_ship && A.construction_ship == ship_name) // Marked through blueprints.
				if(A.z != z)
					continue
				if(isspace(A))
					continue
				if(istype(A, /area/exoplanet/))
					continue
				if(A in SSshuttle.shuttle_areas)
					continue

				var/temp_turf_count = 0
				for(var/turf/T in A.contents)
					if(T.x > (x + MAX_DIST_FROM_CORE) || T.y > (y + MAX_DIST_FROM_CORE)) continue finding_ship_areas
					temp_turf_count++

				ship_areas |= A
				turf_count += temp_turf_count

// This will ensure the ship can be safely finalized.
/obj/machinery/computer/exonet/shipcore/proc/check_finalize()
	errors.Cut()
	. = TRUE
	if(!ship_name)
		errors |= "The ship must have a name."
		. = FALSE
	else if(length(ship_name) < 5)
		errors |= "The ship name must be at least 5 characters in length."
		. = FALSE
	else if(ship_name in SSshuttle.shuttles)
		errors |= "A ship with an identical name has already been registered."
		. = FALSE
	else	// In case a non-landable ship has an identical name.
		for(var/obj/effect/overmap/visitable/ship/ship_effect in SSshuttle.ships)
			if(ship_name == ship_effect.name)
				errors |= "A ship with an identical name has already been registered."
				. = FALSE
	if(!find_base_area())
		errors |= "A ship cannot be constructed indoors."
		. = FALSE
	if(!LAZYLEN(ship_areas))
		errors |= "The ship does not have any assigned areas."
		. = FALSE
	if(turf_count > MAX_SHIP_TILES)
		errors |= "The ship is too large."
		. = FALSE
	else
		var/list/area/area_errors = check_areas()
		if(area_errors && area_errors.len)
			for(var/msg in area_errors)
				errors |= msg
			. = FALSE

/obj/machinery/computer/exonet/shipcore/proc/check_areas()
	for(var/area/A in ship_areas)
		for(var/turf/T in A.contents)
			if(istype(T, /turf/space/) || istype(T, /turf/simulated/floor/exoplanet))
				. |= "There is a problem with area [A.name]"

// Finds the first non-ship turf and checks if it's outside, or in space. Returns either the proper type of area, or null if it cannot locate one within range.
// May not the cleanest way to do this, but generally players will be building 'outside' regardless.
/obj/machinery/computer/exonet/shipcore/proc/find_base_area()
	for(var/dir in GLOB.cardinal)
		var/turf/outsideturf = get_turf(src)
		for(var/d = 0 to MAX_DIST_FROM_CORE)
			outsideturf = get_step(outsideturf, dir)
			if(outsideturf && outsideturf.loc && (istype(outsideturf.loc, /area/exoplanet/) || istype(outsideturf.loc, /area/space/)))
				base_area = outsideturf.loc
				base_turf = outsideturf
				return TRUE

	return FALSE

// Finalizes and creates the ship and shuttle. This should always generate the new ship and shuttle. All necessary checks go in check_finalize().
/obj/machinery/computer/exonet/shipcore/proc/finalize()
	// The custom ship object handles the necessary initialization of the shuttle and initial landmark.
	new /obj/effect/overmap/visitable/ship/landable/customship(null, ship_name, turf_count, fore_dir, in_space, ship_saved_x, ship_saved_y, base_area, base_turf, ship_areas)

	finalized = TRUE

/area
	var/construction_ship // Matches an area as part of a *planned* ship by shuttle_tag.

#undef MAX_DIST_FROM_CORE
#undef MAX_SHIP_TILES