#define IS_PROC(X) (findtext("\ref[X]", "0x26"))

/datum/persistence/serializer
	var/thing_index = 1
	var/var_index = 1
	var/list_index = 1
	var/element_index = 1

	var/list/thing_map = list()
	var/list/reverse_map = list()
	var/list/list_map = list()
	var/list/reverse_list_map = list()

	var/list/thing_inserts = list()
	var/list/var_inserts = list()
	var/list/element_inserts = list()

	var/datum/persistence/load_cache/resolver/resolver = new()
	var/list/ignore_if_empty = list("pixel_x", "pixel_y", "density", "opacity", "blend_mode", "fingerprints", "climbers", "contents", "suit_fibers", "was_bloodied", "last_bumped", "blood_DNA", "id_tag", "x", "y", "z", "loc")
	var/autocommit = TRUE // whether or not to autocommit after a certain number of inserts.
	var/inserts_since_commit = 0
	var/autocommit_threshold = 5000

#ifdef SAVE_DEBUG
	var/verbose_logging = FALSE
#endif

/datum/persistence/serializer/proc/FlattenThing(var/datum/thing)
	var/list/results = list()
	for(var/V in thing.get_saved_vars())
		if(!issaved(thing.vars[V]))
			continue
		var/VV = thing.vars[V]
		if(VV == initial(thing.vars[V]))
			continue
		if(islist(VV))
			results[V] = list()
			for(var/LKEY in _list)
				var/K
				if(istext(LKEY) || isnum(LKEY) || isnull(LKEY))
					K = LKEY
				else if(istype(LKEY, /datum))
					if(should_flatten(LKEY))
						K = "FLAT_OBJ#[FlattenThing(LKEY)]"
					else
						K = "OBJ#[SerializeThing(LKEY)]"
				try
					var/value = _list[LKEY]
					if(istext(value) || isnum(value) || isnull(value))
						_list[K] = value
					else if(istype(value, /datum))
						if(should_flatten(value))
							_list[K] = "FLAT_OBJ#[FlattenThing(value)]"
						else
							_list[K] = "OBJ#[SerializeThing(value)]"
				catch
					results[V].Add(K)
			results[V] = _list
		else if(istext(VV) || isnum(VV) || isnull(VV))
			results[V] = VV
		else if(istype(VV, /datum))
			if(should_flatten(VV))
				results[V] = "FLAT_OBJ#[FlattenThing(VV)]"
			else
				results[V] = "OBJ#[SerializeThing(VV)]"
	return "[thing.type]|[json_encode(results)]"


// This method will look a thing by its ID from the cache and deflate if it.
// This should only be called if the thing was a flattened object. It will not work
// on normal objects.
/datum/persistence/serializer/proc/QueryAndInflateThing(var/thing_json)
	var/list/tokens = splittext(thing_json, "|")
	var/thing_type = text2path(tokens[1])
	var/datum/existing = new thing_type
	var/list/vars = json_decode(jointext(tokens.Copy(2), "|"))
	return InflateThing(existing, vars)

/datum/persistence/serializer/proc/InflateThing(var/datum/thing, var/list/thing_vars)
	for(var/V in thing_vars)
		var/encoded_value = thing_vars[V]
		if(istext(encoded_value) && findtext(encoded_value, "OBJ#", 1, 5))
			// This is an object reference.
			thing.vars[V] = QueryAndDeserializeThing(copytext(encoded_value, 5))
			continue
		if(islist(encoded_value))
			thing.vars[V] = InflateList(encoded_value)
			continue
		thing.vars[V] = encoded_value
	return thing

/datum/persistence/serializer/proc/InflateList(var/list/_list)
	var/list/final_list = list()
	for(var/K in _list)
		var/key = K
		if(istext(K) && findtext(K, "OBJ#", 1, 2))
			key = QueryAndDeserializeThing(copytext(K, 5))
		else if(istext(K) && findtext(K, "FLAT_OBJ#", 1, 2))
			key = QueryAndInflateThing(copytext(K, 10))
		else if(islist(K))
			key = InflateList(K)
		try
			var/V = _list[K]
			if(istext(V) && findtext(V, "OBJ#", 1, 2))
				V = QueryAndDeserializeThing(copytext(V, 5))
			else if(istext(K) && findtext(K, "FLAT_OBJ#", 1, 2))
				V = QueryAndInflateThing(copytext(V, 10))
			else if(islist(V))
				V = InflateList(V)
			final_list[key] = V
		catch
			final_list.Add(key)
	return final_list
