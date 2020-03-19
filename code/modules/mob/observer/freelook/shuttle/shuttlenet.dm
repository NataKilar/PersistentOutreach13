/datum/visualnet/shuttlenet
	valid_source_types = list(/mob/observer/eye/shuttle)
	chunk_type = /datum/chunk/shuttlenet

/datum/chunk/shuttlenet/acquire_visible_turfs(var/list/visible)
	// Sight of the mob is adjusted to only see turfs in shuttleeye.dm
	for(var/source in sources)
		for(var/turf/T in range(source, world.maxx/2))
			// Only show turf and plating so that this can't be used for spying.
			if(istype(T, /turf/space))
				visible[T] = T
				continue
			var/turf/simulated/floor/TF = T
			if(TF.is_plating())
				visible[T] = T
