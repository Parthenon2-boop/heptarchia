shader_type canvas_item;

// HEPTARCHIA – provinciatérkép
// A maszk piros csatornája a provincia azonosítója (0 = tenger, 255 = semleges, játékon kívüli föld). A zárolt vidékek (Frank Királyság,
// Bretagne, Strathclyde és a kiegészítők zárolt vagy még lakatlan földjei) színének alfája negatív
// (a map_view.gd állítja be).
// Színezi a régiókat, határt rajzol, kiemeli a kijelölt és az egér alatti provinciát.

uniform sampler2D mask_tex : filter_nearest;
uniform vec4 prov_colors[128];
uniform int selected_id = 0;
uniform int hovered_id = 0;
uniform int flash_id = 0;
uniform vec4 flash_color = vec4(0.0);
// Egy egész ország kiemelése (diplomácia → „Mutasd a térképen”): 1.0 = a kiemelt ország
// provinciája. Az alfa a mark_color-ban van, 0 = nincs kiemelés.
uniform float mark_ids[128];
uniform vec4 mark_color = vec4(0.0);
uniform vec4 sea_color = vec4(0.94, 0.91, 0.83, 1.0);
uniform float tint_strength = 0.42;
// A tenger: távolság a parttól (tools/build_seadist.gd; R = képpont × 4 / 255). Ha nincs, a régi pergamen-tenger.
uniform sampler2D sea_dist_tex : filter_linear;
uniform bool has_sea_dist = false;
uniform vec3 sea_shallow = vec3(0.60, 0.72, 0.73);
uniform vec3 sea_deep = vec3(0.33, 0.46, 0.53);
uniform vec3 sea_line = vec3(0.80, 0.87, 0.85);

int id_at(vec2 uv) {
	return int(texture(mask_tex, uv).r * 255.0 + 0.5);
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Egyszerű értékzaj a papírszerű, foltos felülethez
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// Modern, tompa színű tenger: a part mentén világos, a nyílt vízen mélyebb; a partok körül halványuló
// vízvonalak (a régi metszetes térképek „water lining”-ja), a partnál finom árnyék, papírszemcse
vec3 sea(vec2 uv, vec3 tex) {
	vec2 px = uv * vec2(textureSize(mask_tex, 0));
	float d = texture(sea_dist_tex, uv).r * 255.0 / 4.0;
	float grain = vnoise(px * 0.08) * 0.6 + vnoise(px * 0.35) * 0.4;
	vec3 col = mix(sea_shallow, sea_deep, smoothstep(3.0, 48.0, d));
	col *= 0.95 + 0.07 * grain;
	// vízvonalak: a parttól egyre távolabb, egyre halványabban
	float lines = 0.0;
	lines += (1.0 - smoothstep(0.0, 0.75, abs(d - 4.0))) * 0.55;
	lines += (1.0 - smoothstep(0.0, 0.7, abs(d - 8.5))) * 0.35;
	lines += (1.0 - smoothstep(0.0, 0.65, abs(d - 14.0))) * 0.18;
	col = mix(col, sea_line, clamp(lines, 0.0, 1.0));
	// árnyék közvetlenül a part mellett (a szárazföld „kiemelkedik”)
	col *= mix(0.80, 1.0, smoothstep(0.5, 3.0, d));
	// a térkép szélén elhalványuló föld (pergamenszínű kép) finoman beleolvad a tengerbe
	float landness = clamp((tex.r - tex.b) * 5.0, 0.0, 1.0);
	return mix(col, tex, landness);
}

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	vec3 rgb = base.rgb;
	int id = id_at(UV);
	float lum = dot(rgb, vec3(0.299, 0.587, 0.114));

	if (id == 0) {
		rgb = has_sea_dist ? sea(UV, rgb) : rgb * sea_color.rgb;
	} else if (id == 255) {
		// Semleges föld (egy kiegészítő térképén a játékon kívüli vidékek): csak a rajz, színezés,
		// határ és kattintás nélkül
	} else if (id >= 128 || prov_colors[id].a < 0.0) {
		// Zárolt vidék: szürke, sötétebb, egér alatt kissé világosabb
		rgb = vec3(lum) * vec3(0.78, 0.79, 0.82) * ((id == hovered_id) ? 1.08 : 0.92);
		vec2 px = 1.0 / vec2(textureSize(mask_tex, 0));
		for (int k = 0; k < 4; k++) {
			vec2 o = vec2(k == 0 ? 1.0 : (k == 1 ? -1.0 : 0.0), k == 2 ? 1.0 : (k == 3 ? -1.0 : 0.0));
			int n = id_at(UV + o * px);
			if (n > 0 && n != id) rgb *= 0.6;
		}
	} else {
		vec4 pc = prov_colors[id];
		float s = tint_strength * pc.a;
		if (id == hovered_id) s += 0.15;
		if (id == selected_id) s += 0.12;
		rgb = mix(rgb, pc.rgb * lum * 1.25, clamp(s, 0.0, 1.0));
		if (id == hovered_id) rgb *= 1.08;

		// Határ: a kijelölt provincia 2 texel vastag, a tenger felé is körberajzolva;
		// a többi határt csak a kisebb ID-jú oldal rajzolja, így 1 texel marad.
		vec2 px = 1.0 / vec2(textureSize(mask_tex, 0));
		bool is_sel = (id == selected_id);
		int r = is_sel ? 2 : 1;
		bool edge = false;
		for (int dy = -r; dy <= r; dy++) {
			for (int dx = -r; dx <= r; dx++) {
				if (dx == 0 && dy == 0) continue;
				int n = id_at(UV + vec2(float(dx), float(dy)) * px);
				if (is_sel ? (n != id) : (n > id)) edge = true;
			}
		}
		if (edge) {
			if (is_sel) {
				rgb = mix(rgb, vec3(1.0, 0.86, 0.35), 0.75 + 0.25 * sin(TIME * 4.0));
			} else {
				rgb = mix(rgb, pc.rgb * 0.3, 0.5 * pc.a);
			}
		}

		if (id == flash_id) rgb = mix(rgb, flash_color.rgb, flash_color.a);

		// A kiemelt ország: minden provinciája erősen az ország színét kapja (a rajz
		// világossága megmarad), a teljes terület KÜLSŐ határa (ahol a szomszéd már nem
		// az övé) vastag, az ország színében sötétből világosba pulzáló keretet.
		if (mark_color.a > 0.0 && mark_ids[id] > 0.5) {
			rgb = mix(rgb, mark_color.rgb * (0.55 + 0.6 * lum), 0.6 * mark_color.a);
			bool outer = false;
			for (int my = -3; my <= 3; my++) {
				for (int mx = -3; mx <= 3; mx++) {
					int n = id_at(UV + vec2(float(mx), float(my)) * px);
					if (n >= 128 || mark_ids[n] < 0.5) outer = true;
				}
			}
			if (outer) {
				vec3 sotet = mark_color.rgb * 0.35;
				vec3 vilagos = mix(mark_color.rgb, vec3(1.0), 0.35);
				vec3 keret = mix(sotet, vilagos, 0.5 + 0.5 * sin(TIME * 4.0));
				rgb = mix(rgb, keret, 0.9 * mark_color.a);
			}
		}
	}
	// Kiemeléskor minden más (a többi ország és a tenger) elsötétül, hogy az ország kiugorjon.
	if (mark_color.a > 0.0 && (id == 0 || id >= 128 || mark_ids[id] < 0.5)) {
		rgb *= 1.0 - 0.4 * mark_color.a;
	}
	COLOR = vec4(rgb, base.a);
}
