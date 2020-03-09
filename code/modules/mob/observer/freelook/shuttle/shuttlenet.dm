/datum/visualnet/shuttlenet
	valid_source_types = list(/obj/machinery/computer/)
	chunk_type = /datum/chunk/shuttlenet

/datum/chunk/shuttlenet/acquire_visible_turfs(var/list/visible)
	// Shuttles "see" from the console. Sight of the mob is adjusted to only see turfs in shuttle_navigation_console.dm.
	for(var/source in sources)
		for(var/turf/t in orange(source, 50))
			visible[t] = t