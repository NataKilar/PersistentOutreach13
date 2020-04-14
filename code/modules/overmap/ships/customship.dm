// Custom ships create their own shuttles during the initalization process.
/obj/effect/overmap/visitable/ship/landable/customship/
	// Used for initialization of attached shuttle.
	var/base_area
	var/base_turf
	var/shuttle_areas

/obj/effect/overmap/visitable/ship/landable/customship/Initialize(var/mapload, var/shuttle_name, var/num_turfs, var/f_dir, var/in_space, var/saved_x, var/saved_y, var/area/b_area, var/turf/b_turf, var/list/s_areas)
	name = shuttle_name
	shuttle = shuttle_name
	fore_dir = f_dir
	loaded_in_space = in_space
	if(saved_x) start_x = saved_x
	if(saved_y) start_y = saved_y

	base_area = b_area
	base_turf = b_turf
	shuttle_areas = s_areas

	switch(num_turfs)
		if(0 to 90)
			vessel_size = SHIP_SIZE_TINY
			vessel_mass = 6500
		if(91 to 150)
			vessel_size = SHIP_SIZE_SMALL
			vessel_mass = 15000
			max_speed 	= 1/(2 SECONDS)
		else
			vessel_size = SHIP_SIZE_LARGE
			vessel_mass = 30000
			max_speed 	= 1/(3 SECONDS)
	. = ..(mapload)

	SSshuttle.shuttles[shuttle_name].find_parent_ship()

/obj/effect/overmap/visitable/ship/landable/customship/find_z_levels()
	. = ..()

	var/obj/effect/shuttle_landmark/start_landmark
	if(loaded_in_space)
		start_landmark = landmark
	else
		start_landmark = new /obj/effect/shuttle_landmark/temporary/construction(src.loc, name, base_area, base_turf)

	var/datum/shuttle/autodock/overmap/shuttle = new(name, start_landmark, shuttle_areas)
	switch(vessel_size)
		if(SHIP_SIZE_TINY)
			shuttle.fuel_consumption = 2
		if(SHIP_SIZE_SMALL)
			shuttle.fuel_consumption = 4
		if(SHIP_SIZE_LARGE)
			shuttle.fuel_consumption = 6

	shuttle.find_parent_ship()

// Properly sets the turf and area that must be left behind after construction. Normal shuttle landing will do this automatically.
/obj/effect/shuttle_landmark/temporary/construction
	name = "Construction navpoint"
	landmark_tag = "navpoint"
	flags = 0

/obj/effect/shuttle_landmark/temporary/construction/Initialize(var/mapload, var/ship_name, var/area/base_area, var/turf/base_turf)
	. = ..(mapload, ship_name)
	base_area = base_area
	base_turf = base_turf.type
