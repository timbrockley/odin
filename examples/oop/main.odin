package main

import "core:fmt"

User :: struct {
	name: string,
}

updateName :: proc(u: ^User, name: string) {
	u.name = name
}

getName :: proc(u: ^User) -> string {
	return u.name
}

main :: proc() {
	//----------------------------------------
	u := User {
		name = "NO_NAME",
	}
	//----------------------------------------
	fmt.println(getName(&u))
	//----------------------------------------
	updateName(&u, "NEW_NAME")
	//----------------------------------------
	fmt.println(getName(&u))
	//----------------------------------------
}
