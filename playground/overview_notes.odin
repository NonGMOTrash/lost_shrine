package main

import "core:fmt"
import "core:strings"

count: int : 4 

Num :: enum {
	A, B, C, D
}

not_main :: proc() {
	// for i := 0; i < count; i += 1 {
	// 	fmt.println(i)
	// }

	#unroll for i in 0..=10 {
		fmt.println(i)
	}

	if b := true; count < 1000 {
		fmt.println(b)
	}

	num: Num = .A
	defer num = .B
	// #partial disables exhaustive match
	#partial switch (num) {
		case .A:
			fmt.println("A")
		case .B:
			fmt.println("B")
	}

	outer: if num == .A {
		for true {
			break outer;
		}
		fmt.println("!")
	}

	fmt.println(addition(9.0, 10.0))

	n := 5
	fmt.println(n)
	
	multi_return :: proc() -> (a: int = 5, b: int = 10)
	{
		return
	}
	x, y: int = multi_return()
	fmt.println(x+y)

	inside_func :: proc() -> int
	{
		return 5
	}

	s: string = "my name is grat michael 😜\n"
	for character in s {
		fmt.print(character);
	}

	list: [3]int = {1, 2, 3}
	fmt.println(list)
	list[2] = 9 
	// list[99] out of bounds access checked at compile time
	fmt.println(list)
	
	msgs := [?]string{"hi", "hello", "hellope"}
	for msg in msgs {
		fmt.print(msg)
	}

	l: int
	l = 2
	slice := list[1:3]
	slice[4] = 99;
	// list[4] out of bounds access checked at runtime (but it's chill)
}
// test := inside_func()
// doesn't work


addition :: proc(a: f32, b:f32) -> f32
{
	return a + b
}

//             named return value  \/
add_many :: proc(nums: ..int) -> (result: int)
{
	for n in nums {
		result += n
	}
	return // same as return result 
}

main :: proc()
{
	// fmt.println("hi" == "die")
}