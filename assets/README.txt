Térkép fájlok:
  res://terkep.png                     – az eredeti, rajzolt térkép (1024 x 559), csak forrás
  res://assets/terkep_mask.png         – az eredeti provinciamaszk, csak forrás
  res://assets/map/terkep_ext.png      – a JÁTÉKBAN használt térkép (1024 x 660):
                                         a fenti térkép kiegészítve a kontinens partjával
                                         (Bretagne – Normandia – Flandria – Hollandia)
  res://assets/map/terkep_mask_ext.png – a JÁTÉKBAN használt provinciamaszk.
                                         Piros csatorna = terület ID:
                                         0 = tenger
                                         1 Exeter, 2 Wilton, 3 Winchester, 4 Canterbury, 5 London,
                                         6 Oxford, 7 Tamworth, 8 Nottingham, 9 York, 10 Carlisle,
                                         11 Bamburgh, 12 Thetford, 13 Ipswich,
                                         14 Gwynedd, 15 Powys, 16 Dyfed, 17 Morgannwg,
                                         18 Dublin, 19 Man, 24 Rouen, 25 Bayeux, 26 Orkney
                                         zárolt vidékek: 21 Skócia, 22 Írország,
                                         27 Nyugati Frank Királyság, 28 Bretagne

A két játékbeli fájlt a tools/build_map.gd állítja elő az eredetiekből (kontinens megrajzolása,
Wales felosztása, Dublin, Man és Orkney kivágása). Újragenerálás a projekt mappájából:
  godot --headless --path . -s res://tools/build_map.gd
  godot --headless --path . --import
A szkript kiírja az új provinciák középpontját (városhely) és a szomszédságokat is.

A maszkot kézzel is lehet javítani bármilyen rajzprogramban (élsimítás NÉLKÜL,
pontosan az ID értékű piros színnel, G = B = 0) – de a build_map.gd felülírja.

Városok helye: scripts/GameManager.gd (CITY_POS), térkép-képpontokban.
Provincia ID-k, zárolt vidékek feliratai: scripts/map_view.gd.
Tengeri díszek (hullám, delfin, bálna, hosszúhajó, szélrózsa): scripts/sea_decor.gd;
a shaders/sea_decor.gdshader vágja le róluk azt, ami szárazföldre esne.

UI grafika (assets/ui): a tools/build_ui.gd generálja (panelek, gombok, pergamen,
ikonok, anglo_saxon_theme.tres). Újragenerálás a projekt mappájából:
  godot --headless --path . -s res://tools/build_ui.gd -- images
  godot --headless --path . --import
  godot --headless --path . -s res://tools/build_ui.gd -- theme

Betűtípusok (assets/fonts, SIL Open Font License – lásd OFL-*.txt):
  Uncial Antiqua (címek), EB Garamond (szöveg, krónika), Noto Sans Runic (rúnák)

Többjátékos dedikált szerver (nyilvános gépen, UDP port nyitva):
  godot --headless --path . -- --server --port=7777 [--upnp]
