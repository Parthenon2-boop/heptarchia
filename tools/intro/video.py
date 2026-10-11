# A bevezető videó összevágása a Blender videószerkesztőjével (a video.ps1 hívja).
#   blender -b --factory-startup --python video.py -- <kockák mappája> <hang mappa> <zene.ogg> <ki.mp4> <borító.jpg> [bitráta kbit/s] [borító kockája]
# A kockák mappájában a felvevo.gd képsora (k00000.jpg …) és az idovonal.json van: abból tudja, melyik
# kockán szólal meg az egyes jelenetek felolvasása. A zene a felolvasás alatt halkan szól (a játékbeli
# arányban), az elején beúszik, a végén elhalkul. Kimenet: 1280×720, 30 kép/mp, H.264 + AAC, MP4.
import bpy, json, os, sys

argv = sys.argv[sys.argv.index("--") + 1:]
kockak, hangmappa, zene, ki, borito = argv[0], argv[1], argv[2], argv[3], argv[4]
bitrata = int(argv[5]) if len(argv) > 5 else 900
terv = json.load(open(os.path.join(kockak, "idovonal.json"), encoding="utf-8"))
FPS = int(terv.get("fps", 30))
borito_kocka = int(argv[6]) if len(argv) > 6 else 0
ZENE_ERO = 0.20      # a felolvasás 0 dB; a zene −14 dB (a játékban is ennyivel halkabb)
HANG_ERO = 1.0

bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene if bpy.context.scene else bpy.data.scenes.new("S")
sc.render.resolution_x = 1280
sc.render.resolution_y = 720
sc.render.resolution_percentage = 100
sc.render.fps = FPS
sc.render.fps_base = 1.0
sc.view_settings.view_transform = "Standard"
for obj, nev, ert in ((sc.view_settings, "look", "None"), (sc.sequencer_colorspace_settings, "name", "sRGB")):
    try:
        setattr(obj, nev, ert)
    except Exception as e:
        print("színbeállítás:", nev, e)
if not sc.sequence_editor:
    sc.sequence_editor_create()
se = sc.sequence_editor
strips = se.strips if hasattr(se, "strips") else se.sequences

fajlok = sorted(f for f in os.listdir(kockak) if f.lower().endswith(".jpg"))
if len(fajlok) != terv["kockak"]:
    print("FIGYELEM: %d kocka van, az idővonal szerint %d kellene" % (len(fajlok), terv["kockak"]))
kep = strips.new_image(name="kepsor", filepath=os.path.join(kockak, fajlok[0]), channel=1, frame_start=1)
for f in fajlok[1:]:
    kep.elements.append(f)
vege = len(fajlok)
sc.frame_start = 1
sc.frame_end = vege
print("KOCKÁK: %d = %.1f mp" % (vege, vege / FPS))

van_hang = 0
for n, j in enumerate(terv["jelenetek"]):
    if j.get("hang_kocka", -1) < 0 or not j.get("hang"):
        continue
    ut = os.path.join(hangmappa, j["hang"])
    if not os.path.exists(ut):
        print("FIGYELEM: nincs meg a hang:", ut)
        continue
    hs = strips.new_sound(name="hang%02d" % n, filepath=ut, channel=3 + (n % 2), frame_start=1 + j["hang_kocka"])
    hs.volume = HANG_ERO
    van_hang += 1
    print("hang", j["hang"], "kocka", 1 + j["hang_kocka"], "hossz", hs.frame_final_duration)

van_zene = False
if zene and os.path.exists(zene):
    h, n = 1, 0
    while h <= vege:
        zs = strips.new_sound(name="zene%d" % n, filepath=zene, channel=6 + (n % 2), frame_start=h)
        hossz = zs.frame_final_duration
        zs.volume = ZENE_ERO
        if n == 0:                                   # beúszás
            zs.volume = 0.0
            zs.keyframe_insert("volume", frame=1)
            zs.volume = ZENE_ERO
            zs.keyframe_insert("volume", frame=1 + 2 * FPS)
        if h + hossz > vege:                         # a végén elhalkul
            zs.volume = ZENE_ERO
            zs.keyframe_insert("volume", frame=max(h, vege - 2 * FPS))
            zs.volume = 0.0
            zs.keyframe_insert("volume", frame=vege)
        print("zene", n, "kocka", h, "hossz", hossz)
        h += hossz
        n += 1
        van_zene = True
    # háttér-módban a hangerő kulcskockái csak így kerülnek a keverésbe (különben néma a sáv)
    try:
        print("hang-animáció sütése:", bpy.ops.sound.bake_animation())
    except Exception as e:
        print("HANG-ANIMÁCIÓ NEM MENT:", e)
else:
    print("FIGYELEM: nincs zene:", zene)

r = sc.render
r.use_sequencer = True
r.use_compositing = False
im = r.image_settings
# a borítókép
if hasattr(im, "media_type"):
    im.media_type = "IMAGE"
im.file_format = "JPEG"
im.quality = 86
im.color_mode = "RGB"
sc.frame_set(max(1, min(vege, borito_kocka if borito_kocka > 0 else 5 * FPS)))
r.filepath = borito
r.use_file_extension = False
bpy.ops.render.render(write_still=True)
print("BORÍTÓ:", borito, os.path.getsize(borito) if os.path.exists(borito) else "NINCS")

if hasattr(im, "media_type"):
    im.media_type = "VIDEO"
im.file_format = "FFMPEG"
ff = r.ffmpeg
ff.format = "MPEG4"
ff.codec = "H264"
ff.constant_rate_factor = "NONE"
ff.video_bitrate = bitrata
ff.minrate = 0
ff.maxrate = int(bitrata * 2.2)
ff.buffersize = int(bitrata * 3)
ff.ffmpeg_preset = "BEST"
ff.gopsize = FPS * 3
ff.use_max_b_frames = True
ff.max_b_frames = 2
if van_hang or van_zene:
    ff.audio_codec = "AAC"
    ff.audio_bitrate = 112
    ff.audio_channels = "STEREO"
    ff.audio_mixrate = 44100
else:
    ff.audio_codec = "NONE"
r.filepath = ki
bpy.ops.render.render(animation=True)
print("KÉSZ: %s  %s bájt  (%d felolvasás, zene: %s)" % (ki, os.path.getsize(ki) if os.path.exists(ki) else "NINCS", van_hang, "van" if van_zene else "nincs"))
