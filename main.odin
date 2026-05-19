package main

import "vendor:wasm/WebGL"
import "core:fmt"
import "core:strings"
import "core:os"
import "core:sort"

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
	Artifact,
	Lantern,
	LitLantern,
	Map,
	Pickaxe,
	Rope
}

Item :: struct {
	id: ItemID,
	name: string,
	description: string,
	location: RoomID,
	in_inventory: bool,
	is_lit: bool
}

GameState :: enum u8 {
	Playing,
	Quit,
	GameOver,
	Victory
}

// === globals ===

print_outputs: bool = true
output_log: [dynamic]string

// === procedures ===

output :: proc (args: ..any)
{ // outputs to the string array, or if none is given, to stdout
	msg: string = fmt.aprintln(..args)
	// why the .. is necessary: when you do println("some msg"), you are passing in a single string
	// but when you pass in args, you are passing in a varadic argument pack, which gets formatted as an array.
	// to avoid that, you need to expand them first with ..
	if print_outputs {
		fmt.print(msg)
	}
	append(&output_log, msg)
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

print_room :: proc(room: Room, world_items: [ItemID]Item)
{
	// name
	output(room.name)
	// description
	desc_line := room.description
	if room.id == .Cottage && world_items[.Map].location == .Cottage {
		desc_line = strings.concatenate({desc_line, " There's a table with a dusty old map."})
	} else if room.id == .Forest && world_items[.Rope].location == .Forest {
		desc_line = strings.concatenate({desc_line, " A rope dangles from a branch."})
	}
	output(desc_line)
	// items
	items_line := "You see:"
	for item in world_items {
		if item.location == room.id {
			items_line, _ = strings.concatenate({items_line, " ", strings.to_lower(item.name)})
		}
	}
	if len(items_line) > 8 {
		output(items_line)
	}
	// exits
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
		output(exits_line)
	}
}

print_help :: proc()
{
	output("Commands: go <north|east|south|west>, take <item>, drop <item>, examine <item>, use <item>, inventory, look, help, quit")
}

go :: proc(direction: Dir, cur_room_id: ^RoomID, world_rooms: [RoomID]Room, world_items: ^[ItemID]Item, game_state: ^GameState)
{
	new_room_id := world_rooms[cur_room_id^].exits[direction]
	if new_room_id == .NullRoom {
		output("You can't go that way.")
	} else if new_room_id == .Quicksand {
		// quicksand event
		output("You sink into quicksand! Everything goes black...")
		for &item in world_items {
			if item.in_inventory {
				item.in_inventory = false
				item.location = .SwampEdge
			}
		}
		world_items[.Lantern].is_lit = false
		cur_room_id^ = .Cottage
		print_room(world_rooms[.Cottage], world_items^)
	} else if new_room_id == .DarkCave && !(world_items[.Lantern].in_inventory && world_items[.Lantern].is_lit) {
		// darkness event
		output("It is utterly dark. You stumble and fall...")
		game_state^ = .GameOver
	} else {
		// normal case: move to room
		cur_room_id^ = new_room_id
		print_room(world_rooms[new_room_id], world_items^)
	}
}

take :: proc(target_item: ItemID, world_items: ^[ItemID]Item, cur_room_id: RoomID, game_state: ^GameState)
{
	if world_items[target_item].location == cur_room_id && !world_items[target_item].in_inventory {
		if target_item == .Artifact {
			// victory case
			output("As you grasp the artifact, light floods the shrine.")
			output("You have retrieved the Artifact of the Ancients. Victory!")
			game_state^ = .Victory
		} else {
			// normal case
			world_items[target_item].in_inventory = true
			world_items[target_item].location = .NullRoom
			output(strings.concatenate({"You take the ", strings.to_lower(world_items[target_item].name), "."}))
		}
	} else {
		output("There is no such item here.")
	}
}

drop :: proc(target_item: ItemID, world_items: ^[ItemID]Item, cur_room_id: RoomID)
{
	for &item in world_items {
		if item.id == target_item && item.in_inventory {
			item.in_inventory = false
			item.location = cur_room_id
			output(strings.concatenate({"You drop the ", strings.to_lower(world_items[target_item].name), "."}))
			return
		}
	}
	output("You aren't carrying that.")
}

use :: proc(item_id: ItemID, cur_room_id: RoomID, world_items: ^[ItemID]Item, world_rooms: ^[RoomID]Room)
{
	if !world_items[item_id].in_inventory {
		//output("You don't have that.")
		output("Nothing happens.")
		return
	}
	if item_id == .Map {
		output("You study the faded map. A river, a cave, and a gate are marked.")
	}
	else if item_id == .Rope && cur_room_id == .Bridge {
		output("You secure the rope and fix the bridge.")
		world_rooms[.Bridge].exits[.South] = .StoneGate
		world_rooms[.Bridge].description = "The bridge appears to be passable now."
		print_room(world_rooms[.Bridge], world_items^)
	} else if item_id == .Pickaxe && cur_room_id == .StoneGate {
		output("You smash the rubble aside. The way is clear.")
		world_rooms[.StoneGate].exits[.East] = .AncientShrine
		world_rooms[.StoneGate].description = "A stone archway."
		print_room(world_rooms[cur_room_id], world_items^)
	} else if item_id == .Lantern {
		if world_items[.Lantern].is_lit == false {
			output("The lantern flickers to life.")
			world_items[.Lantern].is_lit = true
			world_items[.Lantern].description = "An old lantern. It is lit."
		}
	} else {
		output("Nothing happened.")
	}
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
	output(item_list)
}

examine :: proc(item_id: ItemID, world_items: ^[ItemID]Item, cur_room_id: RoomID)
{
	if world_items[item_id].in_inventory || world_items[item_id].location == cur_room_id {
		output(world_items[item_id].description)
	} else {
		output("You don't have that.")
	}
}

run_game :: proc(given_inputs: []string = {}) -> (exit_code: int)
{
	output_log = {}
	use_given_inputs: bool = (len(given_inputs) > 0)

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
			description = "A murky swamp lies south. The ground looks unstable.",
			exits = #partial {
				.North = .Clearing,
				.South = .Quicksand
			}
		},
		.Hill = {
			id = .Hill,
			name = "Hill",
			description = "From the hilltop you see a bridge and, far beyond, a stone gate.",
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
				.North = .Bridge,
			}
		},
		.DarkCave = {
			id = .DarkCave,
			name = "Dark Cave",
			description = "The cave is damp and cold. Shadows dance on the walls.",
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
		.Artifact = {
			id = .Artifact,
			name = "Artifact",
			description = "A crystalline artifact pulsing with energy.",
			location = .AncientShrine
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
		.Map = {
			id = .Map,
			name = "Map",
			description = "A dusty old map, faded but readable.",
			location = .Cottage
		},
		.Pickaxe = {
			id = .Pickaxe,
			name = "Pickaxe",
			description = "A heavy pickaxe embedded in stone.",
			location = .DarkCave
		},
		.Rope = {
			id = .Rope,
			name = "Rope",
			description = "A strong length of rope - long enough to span the bridge.",
			location = .Forest
		},
	}

	cur_room_id: RoomID = .Cottage
	game_state: GameState = .Playing

	print_room(world_rooms[cur_room_id], world_items)

	// === game loop ===

	input_counter: int = 0
	for (game_state == .Playing) {
		// == read input ==

		raw_input: string
		if use_given_inputs {
			if len(given_inputs) > input_counter {
				// if remaining inputs passed to run_game are still there, use those
				raw_input = given_inputs[input_counter]
				input_counter += 1
			} else {
				output("(ran out of inputs")
				return 0
			}
		} else {
			// otherwise get the input from the CLI
			raw_input = get_input()
		}

		// == parsing input ==

		// remove endline from the string, then break it by spaces
		trimmed_input, _ := strings.remove_all(raw_input, "\r\n")
		tokens: []string = strings.split(trimmed_input, " ")
		verb: string
		noun: string
		if len(tokens) > 0 {
			verb = strings.to_lower(tokens[0])
			if len(tokens) > 1 {
				noun = strings.to_lower(tokens[1])
			}
		}

		// === execute command ===

		switch (verb) {
			case "look":
				print_room(world_rooms[cur_room_id], world_items);
			case "help":
				print_help()
			case "exit", "quit":
				game_state = .Quit
			case "go":
				// parse arg to Dir
				dir: Dir
				switch(noun) {
					case "n", "north": dir = .North
					case "s", "south": dir = .South
					case "e", "east" : dir = .East
					case "w", "west" : dir = .West
					case             : dir = .NullDir
				}
				go(dir, &cur_room_id, world_rooms, &world_items, &game_state)
			case "take":
				// parse noun to ItemID
				item_id: ItemID = .NullItem
				for item in world_items {
					if strings.to_lower(item.name) == strings.to_lower(noun) {
						item_id = item.id
						break
					}
				}
				if item_id != .NullItem {
					take(item_id, &world_items, cur_room_id, &game_state)
				} else {
					output("Take what?")
				}
			case "drop":
				// parse noun to ItemID
				item_id: ItemID = .NullItem
				for item in world_items {
					if strings.to_lower(item.name) == strings.to_lower(noun) {
						item_id = item.id
						break
					}
				}
				if item_id != .NullItem {
					drop(item_id, &world_items, cur_room_id)
				} else {
					output("Drop what?")
				}
			case "inventory":
				print_inventory(world_items)
			case "examine":
				// parse noun to ItemID
				item_id: ItemID = .NullItem
				for item in world_items {
					if strings.to_lower(item.name) == noun {
						item_id = item.id
						break
					}
				}
				if item_id != .NullItem {
					examine(item_id, &world_items, cur_room_id)
				} else {
					output("Examine what?")
				}
			case "use":
				// parse noun to ItemID
				item_id: ItemID = .NullItem
				for item in world_items {
					if strings.to_lower(item.name) == noun {
						item_id = item.id
						break
					}
				}
				if item_id != .NullItem {
					use(item_id, cur_room_id, &world_items, &world_rooms)
				} else {
					output("Use what?")
				}
			case "light":
				if noun == "lantern" {
					use(.Lantern, cur_room_id, &world_items, &world_rooms)
				} else {
					output("You can't light that.")
				}
			case "repair":
				if noun == "bridge" {
					use(.Rope, cur_room_id, &world_items, &world_rooms)
				}
			case "hi":
				output("hi")
			case "":
				output("No input given.")
			case:
				output("I don't understand that.")
		}
	}

	if game_state == .GameOver {
		output("Game Over.")
		exit_code = 1
	} else if game_state == .Quit {
		output("Goodbye.")
		exit_code = 0
	} else if game_state == .Victory {
		exit_code = 0
	}

	return exit_code
}

main :: proc()
{
	exit_code: int = run_game()
	os.exit(exit_code)
}