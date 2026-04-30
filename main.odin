package main

import "core:fmt"
import "core:strings"
import "core:os"

Dir :: enum u8 {
	North,
	South,
	East,
	West	
}

RoomID :: enum u8 {
	Cottage,
	Forest,
	Clearing,
	SwampEdge,
	Hill,
	Riverbank,
	Bridge,
	StoneGate,
	DarkCave,
	AncientShrine
}

Room :: struct {
	id: RoomID,
	name: string,
	description: string,
	exits: [Dir]RoomID
}

ItemID :: enum u8 {
	Map,
	Rope,
	Lantern,
	Pickaxe,
	Artifact
}

Item :: struct {
	id: ItemID,
	name: string,
	description: string,
	location: RoomID
}

print_room :: proc(room: Room)
{
	fmt.println(room.name)
	fmt.println(room.description)
	fmt.println("exits:", "...")
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

main :: proc()
{
	// ==== initialize rooms and items ====

	rooms: [RoomID]Room = {
		.Cottage = {
			id = .Cottage,
			name = "Cottage",
			description = "A cozy wooden cottage."
		},
		.Forest = {
			id = .Forest,
			name = "Forest",
			description = "Tall trees surround you."
		},
		.Clearing = {
			id = .Clearing,
			name = "Clearing",
			description = "Sunlight filters through the leaves."
		},
		.SwampEdge = {
			id = .SwampEdge,
			name = "SwampEdge",
			description = "A murky swamp lies south."
		},
		.Hill = {
			id = .Hill,
			name = "Hill",
			description = "From the hilltop you see a bridge and far beyond, a stone gate."
		},
		.Riverbank = {
			id = .Riverbank,
			name = "Riverbank",
			description = "Rapids block the river. A bridge lies east."
		},
		.Bridge = {
			id = .Bridge,
			name = "Bridge",
			description = "Planks are missing. It might be repaired with something sturdy."
		},
		.StoneGate = {
			id = .StoneGate,
			name = "Stone Gate",
			description = "A stone archway blocked by rubble."
		},
		.DarkCave = {
			id = .DarkCave,
			name = "Dark Cave",
			description = "Pitch black darkness."
		},
		.AncientShrine = {
			id = .AncientShrine,
			name = "Ancient Shrine",
			description = "A silent shrine. On a pedestal rests a glowing artifact."
		}
	}

	items: [ItemID]Item = {
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

	current_room: RoomID = .Cottage

	// game loop
	for true {
		print_room(rooms[current_room])
		input = get_input()
	}
}