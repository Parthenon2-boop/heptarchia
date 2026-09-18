shader_type canvas_item;

// HEPTARCHIA – tengeri díszek
// A díszítő rajz csak ott látszik, ahol a provinciamaszk tengert (0) mutat, így nem lóg rá a szárazföldre.

uniform sampler2D mask_tex : filter_nearest;
uniform vec2 map_size = vec2(1024.0, 660.0);
uniform vec2 map_origin = vec2(0.0);   // a térkép bal felső sarka (kiegészítő térképen negatív is lehet)

varying vec2 map_pos;

void vertex() {
	map_pos = VERTEX;   // helyi koordináta = térkép-képpont (a díszréteg a térképpel együtt skálázódik)
}

void fragment() {
	vec2 uv = (map_pos - map_origin) / map_size;
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) discard;
	int id = int(texture(mask_tex, uv).r * 255.0 + 0.5);
	if (id != 0) discard;
}
