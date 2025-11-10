package main

import "core:fmt"
import "core:os"
import "core:strings"
import "core:strconv"

Track :: struct {
	mute: bool,
	volume: f32,
	pan: f32,
	items: [dynamic]Item,
}

Item :: struct {
	// type: ... (union?)
	mute: bool,
	position_sec: f32,
	length_sec: f32,
	volume: f32,
	pan: f32,
	source: Source,
}

SourceType :: enum {
	UNKNOWN = -1,
	MIDI,
	WAVE,
	MP3,
	SECTION,
}

Source :: struct {
	type: SourceType,
	filename: string, // Not used when type is MIDI or SECTION
}

trim_left :: proc(s: string) -> string {
	for i := 0; i < len(s); i += 1 {
		if s[i] != ' ' do return s[i:]
	}

	return ""
}

// This function is only safe to use for lines without quoted strings in them
// TODO: Parse quoted strings, so field index won't mess up...
get_field :: proc(s: string, fieldIndex: int) -> string {
	split, err := strings.split(s, " ")
	if err != nil {
		return ""
	}

	return split[fieldIndex]
}

get_field_f32 :: proc(s: string, fieldIndex: int, default: f32 = 1.0) -> f32 {
	num, ok := strconv.parse_f32(get_field(s, fieldIndex))
	return ok ? num : default
}

source_type :: proc(s: string) -> SourceType {
	if s == "WAVE" {
		return .WAVE
	} else if s == "MIDI" {
		return .MIDI
	} else if s == "MP3" {
		return .MP3
	} else if s == "SECTION" {
		return .SECTION
	}

	return .UNKNOWN
}

// Remember to delete() the returned list!
// Also remember to delete() all the tracks .items lists
parse_rpp :: proc(fileData: []u8) -> [dynamic]Track {
	tracks := [dynamic]Track{}

	inSource := false
	inItem := false
	inTrack := false

	sourceCount := 0

	currentSource := Source{}
	currentItem := Item{}
	currentTrack := Track{}

	lineNumber := 0
	it := string(fileData)
	for line in strings.split_lines_iterator(&it) {
		//fmt.println(line)

		lineNumber += 1
		trim := trim_left(line)

		if inSource {
			if line == "      >" { // End of source scope (3 indentations)
				currentItem.source = currentSource
				currentSource = Source{}
				inSource = false
				continue
			}

			if strings.starts_with(trim, "FILE") {
				currentSource.filename = get_field(trim[5:], 0) // FIXME: Parse string
			}
		} else if inItem {
			if line == "    >" { // End of item scope (2 indentations)
				append(&currentTrack.items, currentItem)
				currentItem = Item{}
				inItem = false
				sourceCount = 0
				continue
			}

			if strings.starts_with(trim, "<SOURCE") {
				currentSource.type = source_type(trim[8:])

				inSource = true
				sourceCount += 1
				if sourceCount > 1 {
					fmt.println("Multiple sources found in item on line", lineNumber)
					panic("")
				}
				continue
			}

			if strings.starts_with(trim, "POSITION") {
				currentItem.position_sec = get_field_f32(trim[9:], 0)
			} else if strings.starts_with(trim, "LENGTH") {
				currentItem.length_sec = get_field_f32(trim[6:], 0)
			} else if strings.starts_with(trim, "MUTE") {
				currentItem.mute = get_field(trim[5:], 0) == "1"
			}
		} else {
			if inTrack {
				if line == "  >" { // End of track scope (1 indentation)
					append(&tracks, currentTrack)
					currentTrack = Track{}
					inTrack = false
					continue
				}

				if trim == "<ITEM" {
					inItem = true
					continue
				}

				if strings.starts_with(trim, "MUTESOLO") {
					currentTrack.mute = trim[9:10] == "1"
				} else if strings.starts_with(trim, "VOLPAN") {
					currentTrack.volume = get_field_f32(trim[7:], 0)
					currentTrack.pan    = get_field_f32(trim[7:], 1)
				}
			} else {
				if strings.starts_with(trim, "<TRACK") {
					inTrack = true
				}
			}
		}
	}

	return tracks
}

main :: proc() {
	if len(os.args) < 2 {
		fmt.println("Usage: rpp-preview [file.RPP]")
		os.exit(0)
	}

	filename := os.args[1]
	fmt.println(filename)

	data, ok := os.read_entire_file(filename)
	if !ok {
		fmt.println("Unable to read file ", filename)
		os.exit(1)
	}
	defer delete(data)

	tracks := parse_rpp(data)
	defer {
		for &track in tracks {
			delete(track.items)
		}
	}
	defer delete(tracks)

	i := 0
	for track in tracks {
		i += 1
		fmt.println(i, ":", track)
	}

	nestingCounter := 0
	maxNestingCounter := 0
	lineNumber := 0

	it := string(data)
	for line in strings.split_lines_iterator(&it) {
		lineNumber += 1

		if strings.starts_with(trim_left(line), "<") {
			nestingCounter += 1
			if nestingCounter > maxNestingCounter {
				fmt.println("new deepest nesting at line", lineNumber)
			}
			maxNestingCounter = max(maxNestingCounter, nestingCounter)
		} else if trim_left(line) == ">" {
			nestingCounter -= 1
		}
	}

	fmt.println("nestingCounter: ", nestingCounter)
	fmt.println("maxNestingCounter: ", maxNestingCounter)
	if nestingCounter != 0 {
		panic("temporary panic")
	}
}
