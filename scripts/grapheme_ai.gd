## grapheme_ai.gd
## Generates weighted-random grapheme strings — translated from AMGArtificialIntelligence.h/.m
## Instantiated as a plain object (GraphemeAI.new()), one per GraphemeSlider.
class_name GraphemeAI

const VOWELS := ["a", "e", "i", "o", "u"]
const FALLBACK_CONSONANTS := ["b","c","d","f","g","h","j","k","l","m","n","p","r","s","t","v","w"]
const FALLBACK_MORPHEMES  := ["ing","ed","er","ly","est","tion","al","ness","able"]

var _frequencies: Dictionary = {}   # grapheme → float frequency
var _words_used: Array[String] = []
var _vowels_found: int = 0

func _init() -> void:
    _load_frequencies()

# ── Frequency loading ─────────────────────────────────────────────────────────

func _load_frequencies() -> void:
    var file := FileAccess.open(Constants.GRAPHEME_FREQ_PATH, FileAccess.READ)
    if file:
        var parsed = JSON.parse_string(file.get_as_text())
        if parsed is Dictionary:
            _frequencies = parsed
        file.close()
    else:
        push_error("GraphemeAI: cannot open " + Constants.GRAPHEME_FREQ_PATH)

# ── Scoring ───────────────────────────────────────────────────────────────────

## Score = round(1/frequency + 0.5).  Rarer graphemes score higher.
func get_morpheme_score(morpheme: String) -> int:
    if _frequencies.has(morpheme) and _frequencies[morpheme] > 0.0:
        return roundi(1.0 / float(_frequencies[morpheme]) + 0.5)
    return 1

# ── Generation ────────────────────────────────────────────────────────────────

## Returns a random grapheme string of the requested type.
## Translated from -getRelativeFrequencyRandomMorpheme:maxlength:
func get_random_morpheme(type: Constants.GraphemeType, max_length: int) -> String:
    var grapheme := ""

    if type == Constants.GraphemeType.VOWEL:
        # Pick a vowel not yet used this round
        var attempts := 0
        while grapheme.is_empty() and _vowels_found < VOWELS.size() and attempts < 20:
            attempts += 1
            var candidate: String = VOWELS[randi() % VOWELS.size()]
            if not _words_used.has(candidate):
                grapheme = candidate
                _vowels_found += 1
        if grapheme.is_empty():
            grapheme = VOWELS[randi() % VOWELS.size()]
        _words_used.append(grapheme)
        return grapheme

    # Consonant or Morpheme — uniform random pick filtered by type/length/duplicate limit
    if _frequencies.is_empty():
        grapheme = _fallback(type)
        _words_used.append(grapheme)
        return grapheme

    var keys := _frequencies.keys()
    var found := false
    var attempts := 0
    const MAX_ATTEMPTS := 500

    while not found and attempts < MAX_ATTEMPTS:
        attempts += 1
        var candidate: String = keys[randi() % keys.size()]

        # Check duplicate cap
        var count := _words_used.count(candidate)
        if count >= Leveller.max_same_graphemes(type):
            continue

        match type:
            Constants.GraphemeType.CONSONANT:
                if candidate.length() == 1 and not VOWELS.has(candidate):
                    grapheme = candidate
                    found = true
            Constants.GraphemeType.MORPHEME:
                if candidate.length() > 1 and candidate.length() <= max_length:
                    grapheme = candidate
                    found = true

    if grapheme.is_empty():
        grapheme = _fallback(type)

    _words_used.append(grapheme)
    return grapheme

func _fallback(type: Constants.GraphemeType) -> String:
    match type:
        Constants.GraphemeType.CONSONANT:
            return FALLBACK_CONSONANTS[randi() % FALLBACK_CONSONANTS.size()]
        Constants.GraphemeType.MORPHEME:
            return FALLBACK_MORPHEMES[randi() % FALLBACK_MORPHEMES.size()]
        _:
            return VOWELS[randi() % VOWELS.size()]

func reset() -> void:
    _words_used.clear()
    _vowels_found = 0
