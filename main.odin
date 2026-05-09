package main

import "vendor:wasm/WebGL"
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
	location: RoomID,
	in_inventory: bool,
	is_lit: bool
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

print_room :: proc(room: Room, world_items: [ItemID]Item)
{
	fmt.println(room.name)
	fmt.println(room.description)
	items_line := "You see:"
	for item in world_items {
		if item.location == room.id {
			items_line, _ = strings.concatenate({items_line, " ", strings.to_lower(item.name)})
		}
	}
	if len(items_line) > 8 {
		fmt.println(items_line)
	}
	exits_line := "Exits:"
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

go :: proc(direction: Dir, cur_room_id: ^RoomID, world_rooms: [RoomID]Room, world_items: ^[ItemID]Item)
{
	new_room_id := world_rooms[cur_room_id^].exits[direction]
	if new_room_id == .NullRoom {
		fmt.println("You can't go there.")
	} else if new_room_id == .Quicksand {
		fmt.println("You sink into quicksand! Everything goes black...")
		for &item in world_items {
			if item.in_inventory {
				item.in_inventory = false
				item.location = .SwampEdge
			}
		}
		cur_room_id^ = .Cottage
		print_room(world_rooms[.Cottage], world_items^)
	} else {
		cur_room_id^ = new_room_id
		print_room(world_rooms[new_room_id], world_items^)
	}
}

take :: proc(target_item: ItemID, world_items: ^[ItemID]Item, cur_room_id: RoomID)
{
	if world_items[target_item].location == cur_room_id && !world_items[target_item].in_inventory {
		world_items[target_item].in_inventory = true
		world_items[target_item].location = .NullRoom
		fmt.println("You took the", strings.to_lower(world_items[target_item].name))
	} else {
		fmt.println("There is no such item here.")
	}
}

drop :: proc(target_item: ItemID, world_items: ^[ItemID]Item, cur_room_id: RoomID)
{
	for &item in world_items {
		if item.id == target_item && item.in_inventory {
			item.in_inventory = false
			item.location = cur_room_id
			fmt.println("You drop the", strings.to_lower(item.name))
			return
		}
	}
	fmt.println("You don't have that.")
}

print_inventory :: proc(world_items: [ItemID]Item)
{
	item_list := "You are carrying:"
	for item in world_items {
		if item.in_inventory {
			item_list = strings.concatenate({item_list, " ", strings.to_lower(item.name)})
		}
	}
	if item_list == "You are carrying:" {
		item_list = "You are carrying nothing."
	}
	fmt.println(item_list)
}

main :: proc()
{
	// ==== initialize rooms and items ====

	world_rooms: [RoomID]Room = {
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
			name = "Swamp Edge",
			description = "A murky swamp lies south.",
			exits = #partial {
				.North = .Clearing,
				.South = .Quicksand
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

	world_items: [ItemID]Item = {
		.NullItem = {},
		.Map = {
			id = .Map,
			name = "Map",
			description = "A dusty old map.",
			location = .Cottage
		},
		.Rope = {
			id = .Rope,
			name = "Rope",
			description = "A strong length of rope - long enough to span the bridge.",
			location = .Forest
		},
		.Lantern = {
			id = .Lantern,
			name = "Lantern",
			description = "A brass lantern.",
			location = .Clearing
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

	print_room(world_rooms[cur_room_id], world_items)

	// === game loop ===

	for true {
		
		// == parsing input ==

		// remove endline from the string, then break it by spaces
		trimmed_input, _ := strings.remove_all(get_input(), "\r\n")
		tokens: []string = strings.split(trimmed_input, " ")
		cmd: string
		arg: string 
		if len(tokens) > 0 {
			cmd = tokens[0]
			if len(tokens) > 1 {
				arg = tokens[1]
			}
		}
		switch (tokens[0]) {
			case "look":
				print_room(world_rooms[cur_room_id], world_items);
			case "help":
				print_help()
			case "exit", "quit":
				fmt.println("Goodbye.")
				return
			case "go":
				// parse arg to Dir
				dir: Dir
				switch(arg) {
					case "n", "north": dir = .North
					case "s", "south": dir = .South
					case "e", "east" : dir = .East
					case "w", "west" : dir = .West
					case             : dir = .NullDir
				}
				go(dir, &cur_room_id, world_rooms, &world_items)
			case "take":
				// parse arg to ItemID
				item_id: ItemID = .NullItem
				for item in world_items {
					if strings.to_lower(item.name) == strings.to_lower(arg) {
						item_id = item.id
						break
					}
				}
				if item_id != .NullItem {
					take(item_id, &world_items, cur_room_id)
				} else {
					fmt.println("Take what?")
				}
			case "drop":
				// parse arg to ItemID
				item_id: ItemID = .NullItem
				for item in world_items {
					if strings.to_lower(item.name) == strings.to_lower(arg) {
						item_id = item.id
						break
					}
				}
				if item_id != .NullItem {
					drop(item_id, &world_items, cur_room_id)
				} else {
					fmt.println("Drop what?")
				}
			case "inventory":
				print_inventory(world_items)
			case "hi":
				fmt.println("hi")
			case:
				fmt.println("I don't understand that.")
		}
	}
}