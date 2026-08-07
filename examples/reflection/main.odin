package main

import "core:fmt"
import "core:mem"
import "core:reflect"

//----------------------------------------

Error :: union {
	ReflectError,
}

ReflectError :: enum {
	InvalidValue,
	InvalidValueType,
	FieldNotFound,
	FieldTypeMismatch,
}

//----------------------------------------
main :: proc() {
	//----------------------------------------
	Foo :: struct {
		x: int `tag1`,
		y: string `json:"y_field"`,
		z: bool,
	}

	id := typeid_of(Foo)
	names := reflect.struct_field_names(id)
	types := reflect.struct_field_types(id)
	tags := reflect.struct_field_tags(id)

	assert(len(names) == len(types) && len(names) == len(tags))

	fmt.println()
	fmt.println("Foo :: struct {")
	for tag, i in tags {
		name, type := names[i], types[i]
		if tag != "" {
			fmt.printf("\t%s: %T `%s`,\n", name, type, tag)
		} else {
			fmt.printf("\t%s: %T,\n", name, type)
		}
	}
	fmt.println("}")
	fmt.println()

	for tag, i in tags {
		if val, ok := reflect.struct_tag_lookup(tag, "json"); ok {
			fmt.printf("json tag: %s -> %s\n", names[i], val)
		}
	}
	fmt.println()
	//----------------------------------------
	foo := Foo {
		x = 42,
		y = "string_value",
		z = true,
	}
	//----------------------------------------
	count := reflect.struct_field_count(id)
	//----------------------------------------
	for index := 0; index < count; index += 1 {
		//----------------------------------------
		field := reflect.struct_field_at(id, index)

		name := field.name
		value := reflect.struct_field_value(foo, field)
		fmt.printfln("%s: %v", name, value)

		switch v in value {
		case int:
			fmt.printfln("%s: %v", name, value)
		case string:
			fmt.printfln("%s: %v", name, value)
		case bool:
			fmt.printfln("%s: %v", name, value)
		case:
			fmt.printfln("unknown value: %v (%v)", value, reflect.type_kind(value.id))
			fmt.printfln("unknown value: %v (%v)", value, typeid_of(type_of(value)))
			fmt.printfln("unknown value: %v (%v)", value, typeid_of(type_of(v)))
			fmt.printfln("unknown value: %v (%T)", value, value)
		}

		if _, ok := value.(int); ok {
			fmt.printfln("%s: %v", name, value)
		} else if v, ok := value.(string); ok {
			fmt.printfln("%s: %v", name, value)
		} else if v, ok := value.(bool); ok {
			fmt.printfln("%s: %v", name, value)
		} else {
			fmt.printfln("unknown value: %v (%v)", value, reflect.type_kind(value.id))
			fmt.printfln("unknown value: %v (%v)", value, typeid_of(type_of(value)))
			fmt.printfln("unknown value: %v (%v)", value, typeid_of(type_of(v)))
			fmt.printfln("unknown value: %v (%T)", value, value)
		}

		if value.id == typeid_of(int) {
			fmt.printfln("%s: %v", name, value)
		} else if value.id == typeid_of(string) {
			fmt.printfln("%s: %v", name, value)
		} else if value.id == typeid_of(bool) {
			fmt.printfln("%s: %v", name, value)
		} else {
			fmt.printfln("unknown value: %v (%v)", value, reflect.type_kind(value.id))
			fmt.printfln("unknown value: %v (%v)", value, typeid_of(type_of(value)))
			fmt.printfln("unknown value: %v (%T)", value, value)
		}
		//----------------------------------------
		err: Error
		//----------------------------------------
		switch name {
		case "x":
			err = setStructFieldValue(&foo, field.name, 0)
		case "y":
			err = setStructFieldValue(&foo, field.name, "new_value")
		case "z":
			err = setStructFieldValue(&foo, field.name, false)
		}
		//----------------------------------------
		if err != nil {fmt.eprintf("\n%v\n", err)}
		//----------------------------------------
	}
	//----------------------------------------
	fmt.println()
	fmt.println(foo)
	fmt.println()
	//----------------------------------------
}
//----------------------------------------

@(require_results)
setStructFieldValue :: proc(struct_instance: ^$T, field_name: string, value: any) -> Error {
	//----------------------------------------
	struct_field := reflect.struct_field_by_name(typeid_of(T), field_name)
	//----------------------------------------
	if struct_field.type == nil {return .FieldNotFound}
	//----------------------------------------
	struct_field_ptr := rawptr(uintptr(struct_instance) + struct_field.offset)
	//----------------------------------------
	if value == nil || value.data == nil {
		//----------------------------------------
		mem.set(struct_field_ptr, 0, struct_field.type.size)
		//----------------------------------------
	} else {
		//----------------------------------------
		if struct_field.type.id != value.id {return .FieldTypeMismatch}
		//----------------------------------------
		mem.copy(struct_field_ptr, value.data, struct_field.type.size)
		//----------------------------------------
	}
	//----------------------------------------
	return nil
	//----------------------------------------
}

//------------------------------------------------------------
