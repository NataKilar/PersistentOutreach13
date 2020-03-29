#define LANDING_VIEW 10

/mob/observer/eye/shuttle
	name = "Shuttle landing Eye"
	desc = "A visual projection used to assist in the landing of a shuttle."
	var/datum/shuttle/autodock/shuttle/
	var/list/landing_images = list()
	var/list/obfuscation_images = list()
	var/list/valid_landing_turfs = list() // If there are no docking beacons on a Z-level, this will not be used. Otherwise, contains the landing_turfs of allowed docking beacons.
	var/list/docking_beacons = list()

/mob/observer/eye/shuttle/New(var/loc, var/shuttle_tag)
	..()
	shuttle = SSshuttle.shuttles[shuttle_tag]

	var/list/connected_z = GetConnectedZlevels(src.z)
	for(var/dbz in connected_z)
		if(GLOB.docking_beacons["[dbz]"])
			docking_beacons += GLOB.docking_beacons["[dbz]"]

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

/mob/observer/eye/shuttle/Destroy()
	shuttle = null
	if(owner && owner.client)
		owner.client.images -= landing_images
		owner.client.images -= obfuscation_images
	landing_images.Cut()
	obfuscation_images.Cut()
	. = ..()

/mob/observer/eye/shuttle/proc/update_obfuscation() // Emulates visualnet esque obsfucation.

	var/list/obfuscated_turfs = list()
	// Generating the obfuscation images. In all reason, these will be constant, so the normal visualnet system will not be used.

	for(var/turf/T in orange(LANDING_VIEW+2, src)) // 2 tile buffer to prevent lag with moving.
		var/area/A = T.loc

		// Everything but space, exoplanet, and hanger areas should be obscured.
		if(istype(T, /turf/space/))
			continue
		if(istype(A, /area/exoplanet))
			continue
		if(A.hangar)
			continue
		if(A in shuttle.shuttle_area)
			continue

		obfuscated_turfs += T

	obfuscated_turfs -= valid_landing_turfs

	if(owner)
		owner.client.images -= obfuscation_images

	obfuscation_images.Cut()

	for(var/turf/T in obfuscated_turfs)
		var/image/I = new('icons/effects/cameravis.dmi', T, "black")
		I.layer = OBFUSCATION_LAYER
		obfuscation_images += I

	if(owner)
		owner.client.images += obfuscation_images

/mob/observer/eye/shuttle/setLoc(var/turf/T)
	T = get_turf(T)
	if(T.x < TRANSITIONEDGE || T.x > world.maxx - TRANSITIONEDGE || T.y < TRANSITIONEDGE ||  T.y > world.maxy - TRANSITIONEDGE)
		return FALSE
	. = ..()

	update_obfuscation()

	check_landing()

//This is a subset of the actual checks in place for moving the shuttle.
/mob/observer/eye/shuttle/proc/check_landing()
	for(var/i = 1 to landing_images.len)
		var/image/img = landing_images[i]
		var/list/coords = landing_images[img]

		var/turf/origin = get_turf(src)
		var/turf/T = locate(origin.x + coords[1], origin.y + coords[2], origin.z)
		img.loc = T

		img.icon_state = "green"
		. = TRUE

		if(!T || !T.loc || (T.x < TRANSITIONEDGE || T.x > world.maxx - TRANSITIONEDGE) || (T.y < TRANSITIONEDGE || T.y > world.maxy - TRANSITIONEDGE))
			img.icon_state = "red"
			. = FALSE // Cannot collide with the edge of the map.
			continue
		if(T.loc != get_area(src))
			img.icon_state = "red"
			. = FALSE // Cannot cross between two areas.
			continue
		if(T.type != origin.type)
			. = FALSE // Cannot land on two different types of turfs.
			continue
		if(T.density)
			img.icon_state = "red"
			. = FALSE // Cannot land on a dense turf.
			continue
		if(LAZYLEN(docking_beacons) && !(T in valid_landing_turfs))
			img.icon_state = "red"
			. = FALSE // Cannot land outside of a docking beacon landing zone if it exists on the the Z-Levels,
			continue

/mob/observer/eye/shuttle/possess(var/mob/user)
	..()
	update_obfuscation()
	if(owner)
		if(owner.client)
			owner.client.view = LANDING_VIEW

		owner.client.images |= landing_images
		owner.client.images |= obfuscation_images

/mob/observer/eye/shuttle/release(var/mob/user)
	if(owner)
		if(owner.client)
			owner.client.view = world.view
	..()

// The eye can see turfs for landing, but is unable to see anything else.
/mob/observer/eye/shuttle/additional_sight_flags()
	return SEE_TURFS|BLIND

#undef LANDING_VIEW