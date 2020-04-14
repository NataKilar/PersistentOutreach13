#define LANDING_VIEW 10

/mob/observer/eye/shuttle
	name = "Shuttle Landing Eye"
	desc = "A visual projection used to assist in the landing of a shuttle."
	name_sufix = "Landing Eye"
	var/datum/shuttle/autodock/shuttle
	var/list/landing_images = list()
	var/list/obfuscation_images = list()

/mob/observer/eye/shuttle/Initialize(var/mapload, var/shuttle_tag)
	shuttle = SSshuttle.shuttles[shuttle_tag]
	// Generates the overlay of the shuttle on turfs.
	var/turf/origin = get_turf(src)
	for(var/area/A in shuttle.shuttle_area)
		for(var/turf/T in A)
			var/image/I = image('icons/effects/alphacolors.dmi', origin, "red")
			// Record the offset of the turfs from the eye. The eye is where the shuttle landmark will be placed, so the resultant images will reflect actual landing.
			var/x_off = T.x - origin.x
			var/y_off = T.y - origin.y

			I.loc = locate(origin.x + x_off, origin.y + y_off, origin.z)
			I.plane = OBSERVER_PLANE
			landing_images[I] = list(x_off, y_off)

	generate_obfuscation()
	. = ..(mapload)

/mob/observer/eye/shuttle/Destroy()
	. = ..()
	shuttle = null
	landing_images.Cut()
	obfuscation_images.Cut()

// The obfuscation of shuttle eyes are on an area basis, not by turf. The obfuscation images will be gen'd in advance and added to the client as needed.
/mob/observer/eye/shuttle/proc/generate_obfuscation()
	var/list/z_levels = (GetConnectedZlevels(z) - GLOB.using_map.mining_areas)	// Generate obfuscation maps for areas not

	for(var/area/A)
		if(A.z in z_levels)
				// Everything but space, exoplanet, and hanger areas should be obscured.
			if(istype(A, /area/space))
				continue
			if(istype(A, /area/exoplanet))
				continue
			if(A.hangar)
				continue
			if(A in shuttle.shuttle_area)
				continue
			var/image/I = new('icons/effects/cameravis.dmi', A, "black")
			I.layer = OBFUSCATION_LAYER
			obfuscation_images[A] = I

// Obfuscation images are not properly added to the owner's screen unless part of area is on the screen. This proc will add all the images as the areas become visible.
/mob/observer/eye/shuttle/proc/add_obfuscation(var/direction)
	if(!owner || !owner.client)
		return

	var/list/turfs_to_check = list()
	var/view_range = owner.client.view

	// The edges of the view will be all that has changed, and therefore are the only turfs to check.
	// in the case of up or down movement, everything in view will be checked.
	switch(direction)
		if(NORTH)
			turfs_to_check = block(locate(x - view_range, y + view_range, z), locate(x + view_range, y + view_range, z))
		if(SOUTH)
			turfs_to_check = block(locate(x - view_range, y - view_range, z), locate(x + view_range, y - view_range, z))
		if(EAST)
			turfs_to_check = block(locate(x + view_range, y - view_range, z), locate(x + view_range, y + view_range, z))
		if(WEST)
			turfs_to_check = block(locate(x - view_range, y - view_range, z), locate(x - view_range, y + view_range, z))
		if(UP || DOWN)
			for(var/turf/T in orange(src, view_range))
				turfs_to_check += T

	for(var/turf/T in turfs_to_check)
		var/area/A = T.loc
		if(!A)
			continue
		if(obfuscation_images[A])
			owner.client.images += obfuscation_images[A]
			obfuscation_images -= A

/mob/observer/eye/shuttle/EyeMove(direct)
	if((direct & (UP|DOWN)))
		var/turf/destination = (direct == UP) ? GetAbove(src) : GetBelow(src)
		if(destination && (destination.z in GLOB.using_map.mining_areas))
			to_chat(owner, SPAN_NOTICE("You cannot land underground."))
			return FALSE
	. = ..()
	if(. && LAZYLEN(obfuscation_images))
		add_obfuscation(direct)

/mob/observer/eye/shuttle/setLoc(var/turf/T)
	T = get_turf(T)
	if(T.x < TRANSITIONEDGE || T.x > world.maxx - TRANSITIONEDGE || T.y < TRANSITIONEDGE ||  T.y > world.maxy - TRANSITIONEDGE)
		return FALSE

	. = ..()

	check_landing()

//This is a subset of the actual checks in place for moving the shuttle.
/mob/observer/eye/shuttle/proc/check_landing()
	for(var/i = 1 to landing_images.len)
		var/image/img = landing_images[i]
		var/list/coords = landing_images[img]

		var/turf/origin = get_turf(src)
		var/turf/T = locate(origin.x + coords[1], origin.y + coords[2], origin.z)
		var/area/A = T.loc
		img.loc = T

		img.icon_state = "green"
		. = TRUE

		if(!T || !T.loc || (T.x < TRANSITIONEDGE || T.x > world.maxx - TRANSITIONEDGE) || (T.y < TRANSITIONEDGE || T.y > world.maxy - TRANSITIONEDGE))
			img.icon_state = "red"
			. = FALSE // Cannot collide with the edge of the map.
			continue
		if(A != get_area(src))
			img.icon_state = "red"
			. = FALSE // Cannot cross between two areas.
			continue
		if(!istype(A, /area/space) && !istype(A, /area/exoplanet) && !(A.hangar)) // Can only land in space, outside, or in hangars.
			img.icon_state = "red"
			. = FALSE
			continue
		if(!istype(T, origin))
			img.icon_state = "red"
			. = FALSE // Cannot land on two different types of turfs.
			continue
		if(T.density)
			img.icon_state = "red"
			. = FALSE // Cannot land on a dense turf.
			continue

/mob/observer/eye/shuttle/possess(var/mob/user)
	..()
	if(owner && owner.client)
		owner.client.view = LANDING_VIEW
		owner.client.images += landing_images

/mob/observer/eye/shuttle/release(var/mob/user)
	if(owner && owner.client)
		owner.client.view = world.view
		owner.client.images.Cut()
	..()

// The eye can see turfs for landing, but is unable to see anything else.
/mob/observer/eye/shuttle/additional_sight_flags()
	return SEE_TURFS|BLIND

#undef LANDING_VIEW