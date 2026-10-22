extends RefCounted

# TAKTIKAI CSATA – nyomkövetés a böngészős változatban. Ha a böngésző (főleg az iPhone Safarija) csata közben
# leállítja és újratölti a lapot, a játékon belül ebből semmi nem látszik. Ezért a csata alatt néhány
# másodpercenként a lap tárába (localStorage, „hep_nyom”) írjuk az utolsó ismert állapotot – a csata idejét,
# a csapatok számát, a memóriát, és hogy a böngésző elvette-e a rajzolást (webglcontextlost) –, a csata végén
# pedig töröljük. Ha a következő induláskor még ott van, a csata nem ért véget rendesen: a főmenü kiírja.

const KULCS := "hep_nyom"
const IDOKOZ := 2.0

static var _ido: float = 0.0

static func _web() -> bool:
	return OS.has_feature("web")

## A csata alatt minden képkockában (csak böngészőben ír, IDOKOZ másodpercenként)
static func frissit(delta: float, adat: Dictionary) -> void:
	if not _web(): return
	_ido -= delta
	if _ido > 0.0: return
	_ido = IDOKOZ
	adat["t"] = int(Time.get_unix_time_from_system())
	adat["video"] = int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0)
	JavaScriptBridge.eval("""(function(){try{
		var d=%s;
		var e=(typeof engine!=='undefined'&&engine.rtenv&&engine.rtenv.HEAPU8)?engine.rtenv.HEAPU8.byteLength:0;
		d.heap=Math.round(e/1048576);
		if(performance.memory)d.js=Math.round(performance.memory.usedJSHeapSize/1048576);
		var r=JSON.parse(localStorage.getItem('%s')||'{}');
		if(r.gl)d.gl=r.gl;
		localStorage.setItem('%s',JSON.stringify(d));
		if(!window.__hepNyomGl){window.__hepNyomGl=1;var c=document.getElementById('canvas');
			if(c)c.addEventListener('webglcontextlost',function(){try{var x=JSON.parse(localStorage.getItem('%s')||'{}');
				x.gl=1;localStorage.setItem('%s',JSON.stringify(x));}catch(z){}});}
	}catch(z){}})()""" % [JSON.stringify(adat), KULCS, KULCS, KULCS, KULCS], true)

## A csata rendben véget ért
static func vege() -> void:
	_ido = 0.0
	if _web(): JavaScriptBridge.eval("try{localStorage.removeItem('%s')}catch(z){}" % KULCS, true)

## Induláskor: a félbeszakadt csata nyoma (és törlés), vagy üres, ha nem volt
static func felbeszakadt() -> Dictionary:
	if not _web(): return {}
	var s := str(JavaScriptBridge.eval("(function(){try{var v=localStorage.getItem('%s')||'';localStorage.removeItem('%s');return v}catch(z){return ''}})()" % [KULCS, KULCS], true))
	var d: Variant = JSON.parse_string(s) if s != "" else null
	return d if typeof(d) == TYPE_DICTIONARY else {}
