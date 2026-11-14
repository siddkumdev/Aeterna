class_name UiFonts
extends RefCounted
## The game's two typefaces (the user, 2026-11-14: the default font was not suitable). Both SIL OFL 1.1, from Google
## Fonts, logged in assets/ASSETS.md: Cinzel (titles, chapter names, the gilded words) and EB Garamond (captions,
## the ledger, cards, plaques). install() makes EB Garamond the fallback for every Label3D and Control.

const TEXT_PATH := "res://assets/fonts/ebgaramond/EBGaramond.ttf"
const ITALIC_PATH := "res://assets/fonts/ebgaramond/EBGaramond-Italic.ttf"
const TITLE_PATH := "res://assets/fonts/cinzel/Cinzel.ttf"

static var _cache := {}


static func _make(path: String, weight: int) -> Font:
	var key := "%s@%d" % [path, weight]
	if _cache.has(key):
		return _cache[key]
	var base: FontFile = load(path)
	var f := FontVariation.new()
	f.base_font = base
	f.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	_cache[key] = f
	return f


static func text() -> Font:
	return _make(TEXT_PATH, 500)


static func bold() -> Font:
	return _make(TEXT_PATH, 650)


static func italic() -> Font:
	return _make(ITALIC_PATH, 500)


static func title() -> Font:
	return _make(TITLE_PATH, 600)


static func install() -> void:
	ThemeDB.fallback_font = text()
