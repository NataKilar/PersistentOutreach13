/datum/visualnet/shuttlenet
	valid_source_types = list(/mob/observer/eye/visualnet/shuttle)
	chunk_type = /datum/chunk/shuttlenet

/datum/chunk/shuttlenet/acquire_visible_turfs(var/list/visible)
// Sight of the mob is adjusted to only see turfs in shuttleeye.dm
	for(var/source in sources)
		var/mob/observer/eye/visualnet/shuttle/eye = source
		if(!eye.owner)
			return
		var/mob/owner = eye.owner

		for(var/turf/T in seen_turfs_in_range(eye, 2 * owner.client.view))
			var/area/A = T.loc
			if((A.area_flags & AREA_FLAG_EXTERNAL) || istype(A, /area/exoplanet) || A in eye.shuttle.shuttle_area || A.hangar)
				visible[T] = T

		for(var/obj/machinery/docking_beacon/dockb in eye.docking_beacons)
			for(var/turf/T in orange(10, dockb)) // A perimeter around the docking area so you know vaguely where you're going.
				visible[T] = T
		for(var/turf/T in eye.valid_landing_turfs)
			visible[T] = T