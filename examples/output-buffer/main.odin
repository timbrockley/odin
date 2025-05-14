package main

import "core:fmt"
import "core:strings"

//------------------------------------------------------------

processToken :: proc(
	token: string,
	value: string,
	template: string,
	template_index: ^int,
	output: []u8,
	output_index: ^int,
) -> bool {
	//---------------------------------------
	if len(token) == 0 {return false}
	if template_index^ >= len(template) {return false}
	if template_index^ + len(token) > len(template) {return false}
	if output_index^ >= len(output) {return false}
	//---------------------------------------
	substring, ok := strings.substring(template, template_index^, template_index^ + len(token))
	//---------------------------------------
	if ok && substring == token {
		//---------------------------------------
		for i in 0 ..< len(value) {
			if output_index^ < len(output) {
				output[output_index^] = value[i]
				output_index^ += 1
			}
		}
		//---------------------------------------
		template_index^ += len(token)
		//---------------------------------------
		return true
		//---------------------------------------
	}
	//---------------------------------------
	return false
	//---------------------------------------
}

//------------------------------------------------------------

format :: proc(template: string, output: []u8) -> int {
	//---------------------------------------
	if len(output) == 0 {return 0}
	//---------------------------------------
	template_index: int = 0
	output_index: int = 0
	//---------------------------------------
	for template_index < len(template) {
		//---------------------------------------
		if processToken("a", "A", template, &template_index, output, &output_index) {continue}
		if processToken("b", "B", template, &template_index, output, &output_index) {continue}
		if processToken("c", "C", template, &template_index, output, &output_index) {continue}
		//---------------------------------------
		// if no token match then copy chars from template
		if output_index < len(output) {
			output[output_index] = template[template_index]
			output_index += 1
		}
		//---------------------------------------
		template_index += 1
		//---------------------------------------
	}
	//---------------------------------------
	return output_index
	//---------------------------------------
}

//------------------------------------------------------------

main :: proc() {
	//----------------------------------------
	output := [100]u8{}
	//----------------------------------------
	bytes_written := format("abcde", output[:])
	//----------------------------------------
	fmt.printfln("bytes written = %d", bytes_written)
	fmt.printfln("output = %s", output)
	fmt.printfln(
		"result = %s",
		strings.compare(string(output[:bytes_written]), "ABCde") == 0 ? "PASS" : "FAIL",
	)
	//----------------------------------------
}

//------------------------------------------------------------
