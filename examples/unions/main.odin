package main

import "core:fmt"
import "core:reflect"

//------------------------------------------------------------
null :: struct {}
//------------------------------------------------------------
ColumnValue1 :: union {
	null,
	i64,
	f64,
	string,
	[]u8,
}
//------------------------------------------------------------
ColumnValue2 :: struct {
	type:  enum {
		null,
		integer,
		float,
		string,
		bytes,
	},
	value: union {
		i64,
		f64,
		string,
		[]u8,
	},
}
//------------------------------------------------------------
main :: proc() {
	//------------------------------------------------------------
	fmt.println()
	//------------------------------------------------------------
	{
		//------------------------------------------------------------
		cv1: ColumnValue1 = 1

		fmt.printfln("reflect.union_variant_typeid: %v", reflect.union_variant_typeid(cv1))

		variant := reflect.get_union_variant(cv1) // any{data, typeid_of(i64)}
		fmt.printfln("reflect.get_union_variant: %v (%v)", variant, typeid_of(type_of(variant)))
		v, ok := variant.(i64)
		fmt.printfln("v, ok := variant.(i64) => ok=%v, value=%d", ok, v)
		//------------------------------------------------------------
	}
	//------------------------------------------------------------
	fmt.println()
	//------------------------------------------------------------
	{
		//------------------------------------------------------------
		integer_value := ColumnValue2 {
			type  = .integer,
			value = i64(42),
		}
		float_value := ColumnValue2 {
			type  = .float,
			value = f64(3.14),
		}
		string_value := ColumnValue2 {
			type  = .string,
			value = string("hello"),
		}
		bytes_value := ColumnValue2 {
			type  = .bytes,
			value = []u8{0x01, 0x02, 0x03},
		}
		null_value := ColumnValue2 {
			type = .null,
		}
		//------------------------------------------------------------
		fmt.println(integer_value)
		fmt.println(float_value)
		fmt.println(string_value)
		fmt.println(bytes_value)
		fmt.println(null_value)
		//------------------------------------------------------------
	}
	//------------------------------------------------------------
	fmt.println()
	//------------------------------------------------------------

}
//------------------------------------------------------------
