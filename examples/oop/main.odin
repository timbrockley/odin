package main

import "core:fmt"

User :: struct {
	name: string,
}

update_name :: proc(u: ^User, name: string) {
	u.name = name
}

get_name :: proc(u: ^User) -> string {
	return u.name
}

main :: proc() {
	//----------------------------------------
	u := User {
		name = "NO_NAME",
	}
	//----------------------------------------
	fmt.println(get_name(&u))
	//----------------------------------------
	update_name(&u, "NEW_NAME")
	//----------------------------------------
	fmt.println(get_name(&u))
	//----------------------------------------
}
