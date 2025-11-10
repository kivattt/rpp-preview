package main

import "core:fmt"
import "core:os"
import "core:strings"

trim_left :: proc(s: string) -> string {
	for i := 0; i < len(s); i += 1 {
		if s[i] != ' ' do return s[i:]
	}

	return ""
}

starts_with :: proc(s: string, c: byte) -> bool {
	for i := 0; i < len(s); i += 1 {
		if s[i] != ' ' {
			return s[i] == c
		}
	}

	return false
}

Track :: struct {
	mute: bool,
	volume: f32,
	pan: f32,
	items: []Item,
}

Item :: struct {
	// type: ... (union?)
	mute: bool,
	filename: string,
	position_sec: f32,
	length_sec: f32,
	volume: f32,
	pan: f32,
}

// This function is only safe to use for lines without quoted strings in them
// TODO: Parse quoted strings, so field index won't mess up...
parse_field :: proc(s: string, fieldIndex: int) -> string {
	currentFieldIndex := 0

	for i := 0; i < len(s); i += 1 {
		if s[i] == ' ' {
			currentFieldIndex += 1
		}
	}
}

// Remember to delete() the returned list!
parse_rpp :: proc(fileData: []u8) -> [dynamic]Track {
	inTrack := false

	tracks := [dynamic]Track{}
	currentTrack := Track{}

	it := string(fileData)
	for line in strings.split_lines_iterator(&it) {
		trim := trim_left(line)

		if inTrack {
			if trim == ">" {
				append(&tracks, currentTrack)
				currentTrack = Track{}
				inTrack = false
				continue
			}

			if strings.starts_with(trim, "MUTESOLO") {
				currentTrack.mute = trim[9:10] == "1"
			} else if strings.starts_with(trim, "VOLPAN") {
				currentTrack.volume = read_field(trim[7:], 0)
				currentTrack.volume = trim[7:]
			}
		} else {
			if strings.starts_with(trim, "<TRACK") {
				inTrack = true
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
