shader_type canvas_item;

// HEPTARCHIA – provinciatérkép
// A maszk piros csatornája a provincia azonosítója (0 = tenger, 255 = semleges, játékon kívüli föld). A zárolt vidékek (Frank Királyság,
// Bretagne, Strathclyde és a kiegészítők zárolt vagy még lakatlan földjei) színének alfája negatív
// (a map_view.gd állítja be).
// Színezi a régiókat, határt rajzol, kiemeli a kijelölt és az egér alatti provinciát.

uniform sampler2D mask_tex : filter_nearest;
// A provinciák adatai egy 256×2-es, 8 bites (RGBA8) keresőtextúrában (a régi uniform-tömbök 128 azonosítóig
// értek, és a régebbi videokártyák uniform-keretét is kimerítették; a korábbi lebegőpontos textúra helyett
// 8 bites, mert azt minden böngésző és telefon biztosan tudja mintavételezni – a map_view.gd írja):
//   0. sor: a provincia színe, A = a színezés erőssége
//   1. sor: R = 255, ha az ország ki van emelve (diplomácia → „Mutasd a térképen”)
//           G = állapot: 0 játékban lévő, 1 zárolt vidék
//           B + 256 · A = az „ország” csoportja (ugyanaz a nép és ugyanaz a szín; 0 = nincs gazdája)
uniform sampler2D prov_tex : filter_nearest;
// Az országhatár színes szegélyének szélessége oldalanként, KÉPERNYŐ-képpontban (Beállítások → Kép →
// Országhatárok vastagsága; a map_view.gd adja át)
uniform float border_px = 4.0;
uniform int selected_id = 0;
uniform int hovered_id = 0;
uniform int flash_id = 0;
uniform vec4 flash_color = vec4(0.0);
// Az alfa a mark_color-ban van, 0 = nincs kiemelés.
uniform vec4 mark_color = vec4(0.0);
uniform vec4 sea_color = vec4(0.94, 0.91, 0.83, 1.0);
uniform float tint_strength = 0.42;
// A tenger: távolság a parttól (tools/build_seadist.gd; R = képpont × 4 / 255). Ha nincs, a régi pergamen-tenger.
uniform sampler2D sea_dist_tex : filter_linear;
uniform bool has_sea_dist = false;
uniform vec3 sea_shallow = vec3(0.60, 0.72, 0.73);
uniform vec3 sea_deep = vec3(0.33, 0.46, 0.53);
uniform vec3 sea_line = vec3(0.80, 0.87, 0.85);

// (textureLod: a maszkot mindig a 0. szinten olvassuk – elágazásban és ciklusban is jól meghatározott,
// a telefonok GLES-fordítóin is)
int id_at(vec2 uv) {
	return int(textureLod(mask_tex, uv, 0.0).r * 255.0 + 0.5);
}

vec4 prov_color(int id) {
	return texelFetch(prov_tex, ivec2(clamp(id, 0, 255), 0), 0);
}

// A provincia adatsora (1. sor): R kiemelés, G állapot, B + 256 · A az ország csoportja
vec4 prov_info(int id) {
	return texelFetch(prov_tex, ivec2(clamp(id, 0, 255), 1), 0);
}

bool marked(int id) {
	return prov_info(id).r > 0.5;
}

int allapot(vec4 inf) {
	return int(inf.g * 255.0 + 0.5);
}

int csoport(vec4 inf) {
	return int(inf.b * 255.0 + 0.5) + 256 * int(inf.a * 255.0 + 0.5);
}

// ── Országhatárok ──────────────────────────────────────────────
// A népek (országok) közti határ vastag, színes sáv: a határ mindkét oldalán a saját nép telítettebb,
// sötétebb színű belső szegélye fut, a kettő között vékony sötét elválasztó vonal (mint a történelmi
// atlaszokon). A népen belüli tartományhatár vékony és halvány marad; a tengerpart és a gazdátlan föld
// felé halványabb (a part felé keskenyebb) a szegély. A szélességek KÉPERNYŐ-képpontban értendők: a
// nagyítást a shader a deriváltból tudja (tpp = maszk-képpont / képernyő-képpont), így közelről a határ
// nem ormótlan, távolról nem tűnik el. Rögzített számú minta (8 + 8 + 4), a tartomány belsejében csak 8.

// Egy képpont „országa”: -1 tenger, -2 gazdátlan / zárolt / játékon kívüli föld, különben a nép csoportja
int orszag(int n) {
	if (n == 0) return -1;
	vec4 inf = prov_info(n);
	int g = csoport(inf);
	return (n >= 255 || allapot(inf) != 0 || g == 0) ? -2 : g;
}

const vec2 KOR[8] = vec2[8](vec2(1.0, 0.0), vec2(-1.0, 0.0), vec2(0.0, 1.0), vec2(0.0, -1.0),
	vec2(0.7071, 0.7071), vec2(-0.7071, 0.7071), vec2(0.7071, -0.7071), vec2(-0.7071, -0.7071));

// A határ az (uv) pont körül, az „en” országából nézve. Vissza:
//   x = a színes szegély erőssége (0–1), y = a sötét elválasztó vonal erőssége (0–1),
//   z = 1, ha a pont egy népen belüli tartományhatáron van
vec3 hatar(vec2 uv, int id, int en, vec2 px, float tpp) {
	// közelről kicsit szélesebb, távolról kicsit keskenyebb (képernyő-képpontban)
	float nagyitas = clamp(pow(tpp, -0.3), 0.8, 1.5);
	float rb = border_px * nagyitas * tpp;      // a szegély szélessége maszk-képpontban
	float sav = 0.0;
	float vonal = 0.0;
	float belso = 0.0;
	bool van = false;
	// külső kör: a szegély külső, halványabb fele (a tenger felé nincs: ott a szegély fele ilyen széles)
	for (int k = 0; k < 8; k++) {
		int n = id_at(uv + KOR[k] * rb * px);
		if (n == id) continue;
		van = true;
		int o = orszag(n);
		if (o != en && o != -1) sav = max(sav, o == -2 ? 0.42 : 0.55);
	}
	// a tartomány belsejében (a képpontok nagy része) itt vége
	if (!van) return vec3(0.0);
	// belső kör: a szegély határ menti, erős fele
	for (int k = 0; k < 8; k++) {
		int n = id_at(uv + KOR[k] * rb * 0.5 * px);
		if (n == id) continue;
		int o = orszag(n);
		if (o != en) sav = max(sav, o == -1 ? 0.6 : (o == -2 ? 0.8 : 1.0));
	}
	// közvetlenül a határon: az elválasztó vonal (országok között), illetve a vékony tartományhatár
	float dd = 0.7 * nagyitas * tpp;
	for (int k = 0; k < 4; k++) {
		int n = id_at(uv + KOR[k] * dd * px);
		if (n == id) continue;
		int o = orszag(n);
		if (o == en) belso = 1.0;
		else vonal = max(vonal, o == -1 ? 0.35 : (o == -2 ? 0.7 : 1.0));
	}
	return vec3(sav, vonal, belso);
}

// A szegély színe: a nép színe telítettebben és sötétebben (hasonló színű szomszédok is elváljanak)
vec3 szegely_szin(vec3 c) {
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	return clamp(mix(vec3(l), c, 1.6), 0.0, 1.0) * 0.68;
}

// A kijelölt provincia kerete: van-e más provincia (vagy tenger) r maszk-képponton belül
bool szelen(vec2 uv, int id, vec2 px, float r) {
	bool szel = false;
	for (int k = 0; k < 8; k++) {
		if (id_at(uv + KOR[k] * r * px) != id) szel = true;
		if (id_at(uv + KOR[k] * r * 0.5 * px) != id) szel = true;
	}
	return szel;
}

const vec3 ELVALASZTO = vec3(0.10, 0.07, 0.05);

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
	// a maszk mérete, és hogy egy képernyő-képpont hány maszk-képpont (a nagyítás és az ablak nyújtása együtt)
	vec2 msize = vec2(textureSize(mask_tex, 0));
	vec2 px = 1.0 / msize;
	float tpp = clamp(max(abs(dFdx(UV.x)) * msize.x, abs(dFdy(UV.y)) * msize.y), 0.02, 64.0);
	vec4 inf = prov_info(id);

	if (id == 0) {
		rgb = has_sea_dist ? sea(UV, rgb) : rgb * sea_color.rgb;
	} else if (id == 255) {
		// Semleges föld (egy kiegészítő térképén a játékon kívüli vidékek): csak a rajz, színezés
		// és kattintás nélkül; csak a szomszédos országok határvonala látszik rajta
		float v = hatar(UV, id, -2, px, tpp).y;
		if (v > 0.5) rgb = mix(rgb, ELVALASZTO, 0.85 * v);
	} else if (allapot(inf) != 0) {
		// Zárolt vidék: szürke, sötétebb, egér alatt kissé világosabb
		rgb = vec3(lum) * vec3(0.78, 0.79, 0.82) * ((id == hovered_id) ? 1.08 : 0.92);
		for (int k = 0; k < 4; k++) {
			int n = id_at(UV + KOR[k] * px);
			if (n > 0 && n != id) rgb *= 0.6;
		}
		float v = hatar(UV, id, -2, px, tpp).y;
		if (v > 0.5) rgb = mix(rgb, ELVALASZTO, 0.85 * v);
	} else {
		vec4 pc = prov_color(id);
		float s = tint_strength * pc.a;
		if (id == hovered_id) s += 0.15;
		if (id == selected_id) s += 0.12;
		rgb = mix(rgb, pc.rgb * lum * 1.25, clamp(s, 0.0, 1.0));
		if (id == hovered_id) rgb *= 1.08;

		// Határok (lásd fent): népen belül vékony, halvány vonal (távolról még halványabb, hogy a térkép ne
		// legyen zsúfolt); országok között a nép színének erős szegélye és a sötét elválasztó vonal
		vec3 h = hatar(UV, id, csoport(inf), px, tpp);
		if (h.z > 0.0) rgb = mix(rgb, pc.rgb * 0.3, 0.42 * pc.a * mix(1.0, 0.4, smoothstep(1.0, 3.0, tpp)));
		if (h.x > 0.0) rgb = mix(rgb, szegely_szin(pc.rgb) * (0.72 + 0.4 * lum), 0.9 * h.x * pc.a);
		// (a színezetlen földön – alfa 0 – csak a szomszédos ország határvonala, a partvonal nem)
		if (h.y > (pc.a > 0.0 ? 0.0 : 0.5)) rgb = mix(rgb, ELVALASZTO, 0.9 * h.y);
		// A kijelölt provincia kerete: kb. 3 képernyő-képpont, a tenger felé is körberajzolva
		if (id == selected_id && szelen(UV, id, px, max(3.0 * tpp, 0.75))) {
			rgb = mix(rgb, vec3(1.0, 0.86, 0.35), 0.75 + 0.25 * sin(TIME * 4.0));
		}

		if (id == flash_id) rgb = mix(rgb, flash_color.rgb, flash_color.a);

		// A kiemelt ország: minden provinciája erősen az ország színét kapja (a rajz
		// világossága megmarad), a teljes terület KÜLSŐ határa (ahol a szomszéd már nem
		// az övé) vastag, az ország színében sötétből világosba pulzáló keretet.
		if (mark_color.a > 0.0 && marked(id)) {
			rgb = mix(rgb, mark_color.rgb * (0.55 + 0.6 * lum), 0.6 * mark_color.a);
			bool outer = false;
			for (int my = -3; my <= 3; my++) {
				for (int mx = -3; mx <= 3; mx++) {
					int n = id_at(UV + vec2(float(mx), float(my)) * px);
					if (!marked(n)) outer = true;
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
	if (mark_color.a > 0.0 && (id == 0 || !marked(id))) {
		rgb *= 1.0 - 0.4 * mark_color.a;
	}
	COLOR = vec4(rgb, base.a);
}
