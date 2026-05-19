package main

import "core:testing"
import "core:os"
import "core:strings"
import "core:fmt"

parse_test_file :: proc(test_path: string) -> []string
{
	input_data, err := os.read_entire_file(test_path, context.allocator)
	if err != os.General_Error.None {
		fmt.eprintln(strings.concatenate({"could not read test file at", test_path}))
	}
	defer delete(input_data, context.allocator)
	string_input_data := string(input_data)

	// actually parse

	commands: [dynamic]string
	for line in strings.split_lines_iterator(&string_input_data) {
		append(&commands, line)
	}

	return commands[:]
}

@(test)
verify_against_test_files :: proc(t: ^testing.T)
{
	print_outputs = false

	test_infos, err := os.read_directory_by_path("./tests", -1, context.allocator)
	if err != os.General_Error.None {
		fmt.eprintln("could not read the ./tests directory")
		return
	}
	defer delete(test_infos)
	
	num_tests: int = 0
	num_passed: int = 0
	for test_info in test_infos {
		name, extension := os.split_filename(test_info.name)
		if extension != "in" {
			continue
		}

		// read input file 

		inputs: []string = parse_test_file(test_info.fullpath)

		// run game and generate outputs 
		
		run_game(inputs[:]) // writes to the outputs global

		// read actual outputs 

		path: string = strings.trim_right(test_info.fullpath, ".in")
		path = strings.concatenate({path, ".out"})
		expected_outputs: []string = parse_test_file(path)

		// compare outputs to expected 

		failed: bool = false
		fmt.eprintln("")
		fmt.eprintln(strings.center_justify(test_info.name, 80, "="))
		// fmt.eprintln(inputs)
		// fmt.eprintln(output_log)
		for i := 0; i < len(expected_outputs); i += 1 {
			actual: string
			if i < len(output_log) {
				actual = strings.trim_space(output_log[i])
			} else {
				actual = "(output log ended)"
			}
			expected: string = strings.trim_space(expected_outputs[i])
			// note: using trim_space is necessary to normalize differences in endline characters
			// that would otherwise cause the strings to appear different when comparing with ==

			// print input and output
			
			fmt.eprintln(strings.concatenate({"expected: ", expected}))
			fmt.eprintln(strings.concatenate({"actual  : ", actual}))
			
			// fail if there was a mismatch
			if actual != expected {
				failed = true
				break
			}
		}

		if failed {
			fmt.eprintln("")
			testing.expect(t, false, "test failed")
		} else {
			fmt.eprintln("(test passed :D)")
			num_passed += 1
		}
		num_tests += 1
		fmt.eprintln("")
	}

	fmt.eprintln("")
	fmt.eprintln("")
	s := fmt.aprint(" passed ", num_passed, " / ", num_tests, " tests ")
	fmt.eprintln(strings.center_justify(s, 80, "="))
	fmt.eprintln("")
	fmt.eprintln("")
}