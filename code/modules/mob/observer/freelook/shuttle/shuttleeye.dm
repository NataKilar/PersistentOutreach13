/mob/observer/eye/visualnet/shuttle
	name = "Shuttle landing Eye"
	desc = "A visual projection used to assist in the landing of a shuttle."
	var/datum/shuttle/autodock/shuttle/
	var/list/landing_images = list()
	var/list/docking_beacons = list()
	var/list/valid_landing_turfs = list()

/mob/observer/eye/visualnet/shuttle/New(var/loc, var/net, var/shuttle_tag)
	..()
	visualnet = net
	shuttle = SSshuttle.shuttles[shuttle_tag]

	var/list/connected_z = GetConnectedZlevels(src.z)
	for(var/dbz in connected_z)
		if(GLOB.docking_beacons["[dbz]"])
			docking_beacons += GLOB.docking_beacons["[dbz]"]

	for(var/obj/machinery/docking_beacon/dockb in docking_beacons)
		valid_landing_turfs += dockb.landing_turfs

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

/mob/observer/eye/visualnet/shuttle/Destroy()
	shuttle = null
	if(owner) owner.client.images -= landing_images
	landing_images.Cut()
	. = ..()

/mob/observer/eye/visualnet/shuttle/setLoc(var/turf/T)
	..()
	T = get_turf(T)
	if(T.x < TRANSITIONEDGE || T.x > world.maxx - TRANSITIONEDGE || T.y < TRANSITIONEDGE ||  T.y > world.maxy - TRANSITIONEDGE)
		return FALSE
	. = ..()
	check_landing()

//This is a subset of the actual checks in place for moving the shuttle.
/mob/observer/eye/visualnet/shuttle/proc/check_landing()
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
		if(T.loc != get_area(src))
			img.icon_state = "red"
			. = FALSE // Cannot cross between two areas.
		if(T.type != origin.type)
			. = FALSE // Cannot land on two different types of turfs.
		if(T.density)
			img.icon_state = "red"
			. = FALSE // Cannot land on a dense turf.
		if(LAZYLEN(docking_beacons) && !(T in valid_landing_turfs))
			img.icon_state = "red"
			. = FALSE // Cannot land outside of a docking beacon landing zone if it exists on the the Z-Levels,

/mob/observer/eye/visualnet/shuttle/possess(var/mob/user)
	. = ..()
	if(owner)
		if(owner.client)
			owner.client.view = world.view + 3

		owner.client.images |= landing_images

/mob/observer/eye/visualnet/shuttle/release(var/mob/user)
	if(owner)
		if(owner.client)
			owner.client.view = world.view

		owner.client.images -= landing_images
	. = ..()

// The eye can see turfs for landing, but is unable to see anything else.
/mob/observer/eye/visualnet/shuttle/additional_sight_flags()
	return SEE_TURFS|BLIND