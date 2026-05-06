package main

import "core:fmt"
import "core:strings"
import "core:os"

Dir :: enum u8 {
	NullDir,
	North,
	South,
	East,
	West	
}

RoomID :: enum u8 {
	NullRoom,
	Cottage,
	Forest,
	Clearing,
	SwampEdge,
	Hill,
	Riverbank,
	Bridge,
	StoneGate,
	DarkCave,
	AncientShrine,
	Quicksand
}

Room :: struct {
	id: RoomID,
	name: string,
	description: string,
	exits: [Dir]RoomID
}

ItemID :: enum u8 {
	NullItem,
	Map,
	Rope,
	Lantern,
	LitLantern,
	Pickaxe,
	Artifact
}

Item :: struct {
	id: ItemID,
	name: string,
	description: string,
	location: RoomID
}

str_to_dir :: proc(s: string) -> Dir
{
	switch(s) {
	case "n", "north": return .North
	case "s", "south": return .South
	case "e", "east" : return .East
	case "w", "west" : return .West
	case             : return .NullDir
	}
}

print_room :: proc(room: Room)
{
	fmt.println(room.name)
	fmt.println(room.description)
	exits_line := "exits:"
	if room.exits[.North] != .NullRoom {
		exits_line = strings.concatenate( []string{exits_line, " north"} )
	}
	if room.exits[.East] != .NullRoom {
		exits_line = strings.concatenate( []string{exits_line, " east"} )
	}
	if room.exits[.South] != .NullRoom {
		exits_line = strings.concatenate( []string{exits_line, " south"} )
	}
	if room.exits[.West] != .NullRoom {
		exits_line = strings.concatenate( []string{exits_line, " west"} )
	}
	if len(exits_line) > 6 {
		fmt.println(exits_line)
	}
}

print_help :: proc()
{
	fmt.println("<help text>")
}

get_input :: proc() -> string
{
	buffer: [256]byte
	// we have a (known size) array here. however, procedure parameters typically take slices instead, because they want
	// they want to be able to take in an array of any length. therefore we have to pass in buffer as a slice, hence buffer[:]
	n, err := os.read(os.stdin, buffer[:])
	if err != nil {
		fmt.eprintln("error reading stdin: ", err)
		return ""
	}
	// string([]byte) gives an alias to the original string on the stack. that can't be returned because that string
	// will go out of scope so there will just be nothing there. instead you have to return a copy, hence strings.clone().
	return strings.clone(string(buffer[:n]))
}

travel :: proc(cur_room_id: RoomID, rooms: [RoomID]Room, direction: Dir) -> (new_room_id: RoomID)
{
	new_room_id = rooms[cur_room_id].exits[direction]
	if new_room_id == .NullRoom {
		fmt.println("You can't go there.")
		return cur_room_id
	} else if new_room_id == .Quicksand {
		// ...
		return .Cottage
	} else {
		print_room(rooms[new_room_id])
		return new_room_id
	}
}

main :: proc()
{
	// ==== initialize rooms and items ====

	rooms: [RoomID]Room = {
		.NullRoom = {},
		.Cottage = {
			id = .Cottage,
			name = "Cottage",
			description = "A cozy wooden cottage.",
			exits = #partial {
				.North = .Forest,
				.East = .Riverbank,
				.South = .Hill
			}
		},
		.Forest = {
			id = .Forest,
			name = "Forest",
			description = "Tall trees surround you.",
			exits = #partial {
				.East = .Clearing,
				.South = .Cottage
			}
		},
		.Clearing = {
			id = .Clearing,
			name = "Clearing",
			description = "Sunlight filters through the leaves.",
			exits = #partial {
				.South = .SwampEdge,
				.West = .Forest
			}
		},
		.SwampEdge = {
			id = .SwampEdge,
			name = "SwampEdge",
			description = "A murky swamp lies south.",
			exits = #partial {
				.North = .Clearing,
				//.South = .Quicksand
			}
		},
		.Hill = {
			id = .Hill,
			name = "Hill",
			description = "From the hilltop you see a bridge and far beyond, a stone gate.",
			exits = #partial {
				.North = .Cottage,
				.East = .DarkCave
			}
		},
		.Riverbank = {
			id = .Riverbank,
			name = "Riverbank",
			description = "Rapids block the river. A bridge lies east.",
			exits = #partial {
				.East = .Bridge,
				.West = .Cottage
			}
		},
		.Bridge = {
			id = .Bridge,
			name = "Bridge",
			description = "Planks are missing. It might be repaired with something sturdy.",
			exits = #partial {
				.West = .Riverbank,
			}
		},
		.StoneGate = {
			id = .StoneGate,
			name = "Stone Gate",
			description = "A stone archway blocked by rubble.",
			exits = #partial {
				.North = .Bridge
			}
		},
		.DarkCave = {
			id = .DarkCave,
			name = "Dark Cave",
			description = "Pitch black darkness.",
			exits = #partial {
				.West = .Hill
			}
		},
		.AncientShrine = {
			id = .AncientShrine,
			name = "Ancient Shrine",
			description = "A silent shrine. On a pedestal rests a glowing artifact.",
			exits = #partial {
				.West = .StoneGate
			}
		},
		.Quicksand = {}
	}

	items: [ItemID]Item = {
		.NullItem = {},
		.Map = {
			id = .Map,
			name = "Map",
			description = "A dusty old map."
		},
		.Rope = {
			id = .Rope,
			name = "Rope",
			description = "A strong length of rope - long enough to span the bridge."
		},
		.Lantern = {
			id = .Lantern,
			name = "Lantern",
			description = "A brass lantern."
		},
		.LitLantern = {
			id = .LitLantern,
			name = "Lantern",
			description = "A brass lantern. It is lit."
		},
		.Pickaxe = {
			id = .Pickaxe,
			name = "Pickaxe",
			description = "A heavy pickaxe embedded in stone."
		},
		.Artifact = {
			id = .Artifact,
			name = "Artifact",
			description = "A crystalline artifact pulsing with energy."
		}
	}

	cur_room_id: RoomID = .Cottage

	print_room(rooms[cur_room_id])

	// game loop
	for true {
		
		// === parsing input ===

		input := strings.split(get_input(), " ")
		trimmed_last_token, was_allocation := strings.remove_all(input[len(input)-1], "\r\n")
		input[len(input)-1] = trimmed_last_token

		switch (input[0]) {
			case "look":
				print_room(rooms[cur_room_id]);
			case "help":
				print_help()
			case "exit", "quit":
				fmt.println("Goodbye.")
				return
			case "go":
				cur_room_id = travel(cur_room_id, rooms, str_to_dir(input[1]))
			//case "take":
			case:
				fmt.println("I don't understand that.")
		}
	}
}