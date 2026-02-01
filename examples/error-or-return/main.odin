package main

import "core:fmt"

//----------------------------------------
Error :: enum {
	None,
	SomeError,
}
//----------------------------------------
// #shared_nil is used incase other Error types from other packages are used
ErrorUnion :: union #shared_nil {
	SomeErrorEnum,
	// anotherPackage.SomeOtherError,
}
SomeErrorEnum :: enum {
	None,
	AnotherError,
}
//----------------------------------------
main :: proc() {

	fmt.printf("err1: ")
	result1, err1 := foo1()
	fmt.printfln("%d, %v", result1, err1)
	if err1 == nil {fmt.printfln("err1 == nil")}

	fmt.printf("\nerr2: ")
	err2 := foo2()
	fmt.printfln(err2 == .None ? "Pass: %v" : "Fail: %v", err2)
	if err2 == nil {fmt.printfln("err2 == nil")}

	fmt.printf("\nerr3: ")
	result3, err3 := foo3()
	fmt.printfln("%d, %v", result3, err3)
	if err3 == nil {fmt.printfln("err3 == nil")}

}
//----------------------------------------
foo1 :: proc() -> (x: int, err: Error) {
	x = bar1() or_return
	return x, .None
}

bar1 :: proc() -> (int, Error) {
	return 0, .SomeError
	// return 42, .None
}
//----------------------------------------
foo2 :: proc() -> Error {
	bar2() or_return
	return .None
}

bar2 :: proc() -> Error {
	return .SomeError
	// return .None
}
//----------------------------------------
foo3 :: proc() -> (x: int, err: ErrorUnion) {
	x = bar3() or_return
	return x, nil
}

bar3 :: proc() -> (int, ErrorUnion) {
	// return 0, SomeError{}
	return 42, nil
}
//----------------------------------------
