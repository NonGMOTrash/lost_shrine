package main

import "core:testing"
import "core:os"
import "core:strings"
import "core:fmt"

parse_test_file :: proc(test_path: string) -> []string
{
	input_data, read_err := os.read_entire_file(test_path, context.allocator)
	if read_err != nil {
		fmt.eprintln("could not find file at", test_path)
	}
	defer delete(input_data)
	string_input_data: string = string(input_data)

	// actually parse

	commands, split_err := strings.split_lines(string_input_data)
	if split_err != nil {
		fmt.eprintln("could not split string_input_data")
	}

	return commands
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
	defer os.file_info_slice_delete(test_infos, context.allocator)
	
	num_tests: int = 0
	num_passed: int = 0
	for test_info in test_infos {
		name, extension := os.split_filename(test_info.name)
		if extension != "in" {
			continue
		}

		// read input file 

		inputs: []string = parse_test_file(test_info.fullpath)
		defer delete(inputs)

		// run game and generate outputs 
		
		run_game(inputs[:]) // writes to the outputs global

		// read actual outputs 

		path: string = strings.trim_right(test_info.fullpath, ".in")
		path = strings.concatenate({path, ".out"})
		defer delete(path)
		expected_outputs: []string = parse_test_file(path)
		defer delete(expected_outputs)

		// compare outputs to expected 

		failed: bool = false
		header_line := strings.center_justify(test_info.name, 80, "=")
		defer delete(header_line)
		fmt.eprintln('\n', header_line)

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
			expected_line := strings.concatenate({"expected: ", expected})
			defer delete(expected_line)
			actual_line := strings.concatenate({"actual  : ", actual})
			defer delete(actual_line)
			fmt.eprintln(expected_line)
			fmt.eprintln(actual_line)
			
			// fail if there was a mismatch
			if actual != expected {
				failed = true
				break
			}
		}

		if failed {
			fmt.eprint("\n\n")
			testing.expect(t, false, "output mismatch")
		} else {
			testing.expect(t, true, "outputs match :D")
			num_passed += 1
		}
		num_tests += 1
	}

	final_header_txt := fmt.aprint(" passed ", num_passed, " / ", num_tests, " tests ")
	defer delete(final_header_txt)
	final_header := strings.center_justify(final_header_txt, 80, "=")
	defer delete(final_header)
	fmt.eprintln("\n", final_header, "\n\n\n", sep="")

	clean_output_log()
}