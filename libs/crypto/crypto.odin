package crypto

//------------------------------------------------------------
// Copyright 2023-2025 Tim Brockley. All rights obfuscated_dataerved.
// This software is licensed under the MIT License.
//------------------------------------------------------------

import "../conv"
import "core:fmt"
import "core:mem"
import "core:os"
import "core:path/filepath"
import "core:strings"

//------------------------------------------------------------

Error :: union #shared_nil {
	conv.Error,
	mem.Allocator_Error,
}

//------------------------------------------------------------

obfuscateV0 :: proc(data: string, allocator := context.allocator) -> (output: string, err: Error) {
	//---------------------------------------
	if data == "" {
		return data, nil
	}
	//---------------------------------------
	data_length := len(data)
	//---------------------------------------
	output_bytes := make([]u8, data_length, allocator) or_return
	//---------------------------------------
	for index in 0 ..< data_length {
		output_bytes[index] = slideByteV0(data[index])
	}
	//---------------------------------------
	return string(output_bytes), nil
	//---------------------------------------
}

//------------------------------------------------------------

slideByteV0 :: proc(byte: u8) -> u8 {
	//---------------------------------------
	switch byte {
	case 0x00 ..= 0x1F:
		return 0x1F - byte
	case 0x20 ..= 0x7E:
		return 0x7E - (byte - 0x20)
	case 0x7F:
		return byte
	case 0x80 ..= 0xFF:
		return 0xFF - (byte - 0x80)
	case:
		return byte // catch all for compiler
	}
	//---------------------------------------
}

//------------------------------------------------------------

obfuscateV0_encode :: proc(
	data: string,
	encoding := "",
	allocator := context.allocator,
) -> (
	output: string,
	err: Error,
) {
	//---------------------------------------
	if data == "" {
		return data, nil
	}
	//---------------------------------------
	obfuscated_data := obfuscateV0(data = data, allocator = allocator) or_return
	//---------------------------------------
	switch encoding {
	case "base":
		return conv.base_encode(data = obfuscated_data, allocator = allocator)
	case "base64":
		return conv.base64_encode(data = obfuscated_data, allocator = allocator)
	case "base64url":
		return conv.base64url_encode(data = obfuscated_data, allocator = allocator)
	case "base91":
		return conv.base91_encode(data = obfuscated_data, escape = true, allocator = allocator)
	case "hex":
		return conv.hex_encode(data = obfuscated_data, allocator = allocator)
	case:
		//---------------------------------------
		obfuscated_data, _ = strings.replace_all(obfuscated_data, "-", "--", allocator)
		obfuscated_data, _ = strings.replace_all(obfuscated_data, "\x09", "-t", allocator)
		obfuscated_data, _ = strings.replace_all(obfuscated_data, "\x0A", "-n", allocator)
		obfuscated_data, _ = strings.replace_all(obfuscated_data, "\x0D", "-r", allocator)
		obfuscated_data, _ = strings.replace_all(obfuscated_data, "\x20", "-s", allocator)
		obfuscated_data, _ = strings.replace_all(obfuscated_data, "\x22", "-q", allocator)
		obfuscated_data, _ = strings.replace_all(obfuscated_data, "\x24", "-d", allocator)
		obfuscated_data, _ = strings.replace_all(obfuscated_data, "\x27", "-a", allocator)
		obfuscated_data, _ = strings.replace_all(obfuscated_data, "\x5C", "-b", allocator)
		obfuscated_data, _ = strings.replace_all(obfuscated_data, "\x60", "-g", allocator)
		//---------------------------------------
		return obfuscated_data, nil
	//---------------------------------------
	}
	//---------------------------------------
}

//------------------------------------------------------------

obfuscateV0_decode :: proc(
	data: string,
	encoding := "",
	allocator := context.allocator,
) -> (
	output: string,
	err: Error,
) {
	//---------------------------------------
	if data == "" {
		return data, nil
	}
	//---------------------------------------
	decoded_data: string
	//---------------------------------------
	switch encoding {
	case "base":
		decoded_data = conv.base_decode(data = data, allocator = allocator) or_return
	case "base64":
		decoded_data = conv.base64_decode(data = data, allocator = allocator) or_return
	case "base64url":
		decoded_data = conv.base64url_decode(data = data, allocator = allocator) or_return
	case "base91":
		decoded_data = conv.base91_decode(
			data = data,
			unescape = true,
			allocator = allocator,
		) or_return
	case "hex":
		decoded_data = conv.hex_decode(data = data, allocator = allocator) or_return
	case:
		//---------------------------------------
		decoded_data = data
		//---------------------------------------
		decoded_data, _ = strings.replace_all(decoded_data, "--", "-SUB", allocator)
		decoded_data, _ = strings.replace_all(decoded_data, "-g", "\x60", allocator)
		decoded_data, _ = strings.replace_all(decoded_data, "-b", "\x5C", allocator)
		decoded_data, _ = strings.replace_all(decoded_data, "-a", "\x27", allocator)
		decoded_data, _ = strings.replace_all(decoded_data, "-d", "\x24", allocator)
		decoded_data, _ = strings.replace_all(decoded_data, "-q", "\x22", allocator)
		decoded_data, _ = strings.replace_all(decoded_data, "-s", "\x20", allocator)
		decoded_data, _ = strings.replace_all(decoded_data, "-r", "\x0D", allocator)
		decoded_data, _ = strings.replace_all(decoded_data, "-n", "\x0A", allocator)
		decoded_data, _ = strings.replace_all(decoded_data, "-t", "\x09", allocator)
		decoded_data, _ = strings.replace_all(decoded_data, "-SUB", "-", allocator)
	//---------------------------------------
	}
	//---------------------------------------
	return obfuscateV0(data = decoded_data, allocator = allocator)
	//---------------------------------------
}

//------------------------------------------------------------

obfuscateV4 :: proc(
	data: string,
	mix_chars := true,
	allocator := context.allocator,
) -> (
	output: string,
	err: Error,
) {
	//---------------------------------------
	if data == "" {
		return data, nil
	}
	//---------------------------------------
	data_length := len(data)
	//---------------------------------------
	output_bytes := make([]u8, data_length, allocator) or_return
	//---------------------------------------
	if !mix_chars || data_length < 4 {
		for index in 0 ..< data_length {
			output_bytes[index] = slideByteV4(data[index])
		}
		return string(output_bytes), nil
	}
	//---------------------------------------
	mixed_length := data_length
	mixed_half := mixed_length / 2
	//----------------------------------------
	if (mixed_half % 2 != 0) {
		mixed_half -= 1
		mixed_length = mixed_half * 2
	}
	//----------------------------------------
	for index in 0 ..< data_length {
		if index < mixed_length && index % 2 != 0 {
			if (index < mixed_half) {
				output_bytes[index + mixed_half] = slideByteV4(data[index])
			} else {
				output_bytes[index - mixed_half] = slideByteV4(data[index])
			}
		} else {
			output_bytes[index] = slideByteV4(data[index])
		}
	}
	//---------------------------------------
	return string(output_bytes), nil
	//---------------------------------------
}

//------------------------------------------------------------

slideByteV4 :: proc(byte: u8) -> u8 {
	//---------------------------------------
	switch byte {
	case 0x20 ..= 0x7E:
		return 0x7E - (byte - 0x20)
	case:
		return byte
	}
	//---------------------------------------
}

//------------------------------------------------------------


obfuscateV4_encode :: proc(
	data: string,
	mix_chars := true,
	encoding := "",
	allocator := context.allocator,
) -> (
	output: string,
	err: Error,
) {
	//---------------------------------------
	if data == "" {
		return data, nil
	}
	//---------------------------------------
	obfuscated_data := obfuscateV4(
		data = data,
		mix_chars = mix_chars,
		allocator = allocator,
	) or_return
	//---------------------------------------
	switch encoding {
	case "base":
		return conv.base_encode(data = obfuscated_data, allocator = allocator)
	case "base64":
		return conv.base64_encode(data = obfuscated_data, allocator = allocator)
	case "base64url":
		return conv.base64url_encode(data = obfuscated_data, allocator = allocator)
	case "base91":
		return conv.base91_encode(data = obfuscated_data, escape = true, allocator = allocator)
	case "hex":
		return conv.hex_encode(data = obfuscated_data, allocator = allocator)
	case:
		//---------------------------------------
		obfuscated_data, _ = strings.replace_all(obfuscated_data, "\\", "\\\\", allocator)
		obfuscated_data, _ = strings.replace_all(obfuscated_data, "\x09", "\\t", allocator)
		obfuscated_data, _ = strings.replace_all(obfuscated_data, "\x0A", "\\n", allocator)
		obfuscated_data, _ = strings.replace_all(obfuscated_data, "\x0D", "\\r", allocator)
		obfuscated_data, _ = strings.replace_all(obfuscated_data, "\x22", "\\q", allocator)
		obfuscated_data, _ = strings.replace_all(obfuscated_data, "\x27", "\\a", allocator)
		obfuscated_data, _ = strings.replace_all(obfuscated_data, "\x60", "\\g", allocator)
		//---------------------------------------
		return obfuscated_data, nil
	//---------------------------------------
	}
	//---------------------------------------
}

//------------------------------------------------------------

obfuscateV4_decode :: proc(
	data: string,
	mix_chars := true,
	encoding := "",
	allocator := context.allocator,
) -> (
	output: string,
	err: Error,
) {
	//---------------------------------------
	if data == "" {
		return data, nil
	}
	//---------------------------------------
	decoded_data: string
	//---------------------------------------
	switch encoding {
	case "base":
		decoded_data = conv.base_decode(data = data, allocator = allocator) or_return
	case "base64":
		decoded_data = conv.base64_decode(data = data, allocator = allocator) or_return
	case "base64url":
		decoded_data = conv.base64url_decode(data = data, allocator = allocator) or_return
	case "base91":
		decoded_data = conv.base91_decode(
			data = data,
			unescape = true,
			allocator = allocator,
		) or_return
	case "hex":
		decoded_data = conv.hex_decode(data = data, allocator = allocator) or_return
	case:
		//---------------------------------------
		decoded_data = data
		//---------------------------------------
		decoded_data, _ = strings.replace_all(decoded_data, "\\\\", "\\SUB", allocator)
		decoded_data, _ = strings.replace_all(decoded_data, "\\g", "\x60", allocator)
		decoded_data, _ = strings.replace_all(decoded_data, "\\a", "\x27", allocator)
		decoded_data, _ = strings.replace_all(decoded_data, "\\q", "\x22", allocator)
		decoded_data, _ = strings.replace_all(decoded_data, "\\r", "\x0D", allocator)
		decoded_data, _ = strings.replace_all(decoded_data, "\\n", "\x0A", allocator)
		decoded_data, _ = strings.replace_all(decoded_data, "\\t", "\x09", allocator)
		decoded_data, _ = strings.replace_all(decoded_data, "\\SUB", "\\", allocator)
	//---------------------------------------
	}
	//---------------------------------------
	return obfuscateV4(data = decoded_data, mix_chars = mix_chars, allocator = allocator)
	//---------------------------------------
}

//------------------------------------------------------------

obfuscateV5 :: proc(data: string, allocator := context.allocator) -> (output: string, err: Error) {
	//---------------------------------------
	if data == "" {
		return data, nil
	}
	//---------------------------------------
	data_length := len(data)
	//---------------------------------------
	output_bytes := make([]u8, data_length, allocator) or_return
	//---------------------------------------
	if len(data) < 4 {
		for index in 0 ..< data_length {
			output_bytes[index] = slideByteV5(data[index])
		}
		return string(output_bytes), nil
	}
	//---------------------------------------
	mixed_length := data_length
	mixed_half := mixed_length / 2
	//----------------------------------------
	if (mixed_half % 2 != 0) {
		mixed_half -= 1
		mixed_length = mixed_half * 2
	}
	//----------------------------------------
	for index in 0 ..< data_length {
		if index < mixed_length && index % 2 != 0 {
			if (index < mixed_half) {
				output_bytes[index + mixed_half] = slideByteV5(data[index])
			} else {
				output_bytes[index - mixed_half] = slideByteV5(data[index])
			}
		} else {
			output_bytes[index] = slideByteV5(data[index])
		}
	}
	//---------------------------------------
	return string(output_bytes), nil
	//---------------------------------------
}

//------------------------------------------------------------

slideByteV5 :: proc(byte: u8) -> u8 {
	//---------------------------------------
	switch byte {
	case 0x00 ..= 0x1F:
		return 0x1F - byte
	case 0x20 ..= 0x7E:
		return 0x7E - (byte - 0x20)
	case 0x7F:
		return byte
	case 0x80 ..= 0xFF:
		return 0xFF - (byte - 0x80)
	case:
		return byte // catch all for compiler
	}
	//---------------------------------------
}

//------------------------------------------------------------


obfuscateV5_encode :: proc(
	data: string,
	encoding := "",
	allocator := context.allocator,
) -> (
	output: string,
	err: Error,
) {
	//---------------------------------------
	if data == "" {
		return data, nil
	}
	//---------------------------------------
	obfuscated_data := obfuscateV5(data = data, allocator = allocator) or_return
	//---------------------------------------
	switch encoding {
	case "base":
		return conv.base_encode(data = obfuscated_data, allocator = allocator)
	case "base64":
		return conv.base64_encode(data = obfuscated_data, allocator = allocator)
	case "base64url":
		return conv.base64url_encode(data = obfuscated_data, allocator = allocator)
	case "base91":
		return conv.base91_encode(data = obfuscated_data, escape = true, allocator = allocator)
	case "hex":
		return conv.hex_encode(data = obfuscated_data, allocator = allocator)
	case:
		//---------------------------------------
		obfuscated_data, _ = strings.replace_all(obfuscated_data, "-", "--", allocator)
		obfuscated_data, _ = strings.replace_all(obfuscated_data, "\x09", "-t", allocator)
		obfuscated_data, _ = strings.replace_all(obfuscated_data, "\x0A", "-n", allocator)
		obfuscated_data, _ = strings.replace_all(obfuscated_data, "\x0D", "-r", allocator)
		obfuscated_data, _ = strings.replace_all(obfuscated_data, "\x20", "-s", allocator)
		obfuscated_data, _ = strings.replace_all(obfuscated_data, "\x22", "-q", allocator)
		obfuscated_data, _ = strings.replace_all(obfuscated_data, "\x24", "-d", allocator)
		obfuscated_data, _ = strings.replace_all(obfuscated_data, "\x27", "-a", allocator)
		obfuscated_data, _ = strings.replace_all(obfuscated_data, "\x5C", "-b", allocator)
		obfuscated_data, _ = strings.replace_all(obfuscated_data, "\x60", "-g", allocator)
		//---------------------------------------
		return obfuscated_data, nil
	//---------------------------------------
	}
	//---------------------------------------
}

//------------------------------------------------------------

obfuscateV5_decode :: proc(
	data: string,
	encoding := "",
	allocator := context.allocator,
) -> (
	output: string,
	err: Error,
) {
	//---------------------------------------
	if data == "" {
		return data, nil
	}
	//---------------------------------------
	decoded_data: string
	//---------------------------------------
	switch encoding {
	case "base":
		decoded_data = conv.base_decode(data = data, allocator = allocator) or_return
	case "base64":
		decoded_data = conv.base64_decode(data = data, allocator = allocator) or_return
	case "base64url":
		decoded_data = conv.base64url_decode(data = data, allocator = allocator) or_return
	case "base91":
		decoded_data = conv.base91_decode(
			data = data,
			unescape = true,
			allocator = allocator,
		) or_return
	case "hex":
		decoded_data = conv.hex_decode(data = data, allocator = allocator) or_return
	case:
		//---------------------------------------
		decoded_data = data
		//---------------------------------------
		decoded_data, _ = strings.replace_all(decoded_data, "--", "-SUB", allocator)
		decoded_data, _ = strings.replace_all(decoded_data, "-g", "\x60", allocator)
		decoded_data, _ = strings.replace_all(decoded_data, "-b", "\x5C", allocator)
		decoded_data, _ = strings.replace_all(decoded_data, "-a", "\x27", allocator)
		decoded_data, _ = strings.replace_all(decoded_data, "-d", "\x24", allocator)
		decoded_data, _ = strings.replace_all(decoded_data, "-q", "\x22", allocator)
		decoded_data, _ = strings.replace_all(decoded_data, "-s", "\x20", allocator)
		decoded_data, _ = strings.replace_all(decoded_data, "-r", "\x0D", allocator)
		decoded_data, _ = strings.replace_all(decoded_data, "-n", "\x0A", allocator)
		decoded_data, _ = strings.replace_all(decoded_data, "-t", "\x09", allocator)
		decoded_data, _ = strings.replace_all(decoded_data, "-SUB", "-", allocator)
	//---------------------------------------
	}
	//---------------------------------------
	return obfuscateV5(data = decoded_data, allocator = allocator)
	//---------------------------------------
}

//------------------------------------------------------------

obfuscateXOR :: proc(
	data: string,
	value: u8,
	allocator := context.allocator,
) -> (
	output: string,
	err: Error,
) {
	//---------------------------------------
	if data == "" {
		return data, nil
	}
	//---------------------------------------
	data_length := len(data)
	//---------------------------------------
	output_bytes := make([]u8, data_length, allocator) or_return
	//---------------------------------------
	for index in 0 ..< data_length {
		output_bytes[index] = data[index] ~ value
	}
	//---------------------------------------
	return string(output_bytes), nil
	//---------------------------------------
}

//------------------------------------------------------------

obfuscateXOR_encode :: proc(
	data: string,
	value: u8,
	encoding := "",
	allocator := context.allocator,
) -> (
	output: string,
	err: Error,
) {
	//---------------------------------------
	if data == "" {
		return data, nil
	}
	//---------------------------------------
	obfuscated_data := obfuscateXOR(data = data, value = value, allocator = allocator) or_return
	//---------------------------------------
	switch encoding {
	case "base":
		return conv.base_encode(data = obfuscated_data, allocator = allocator)
	case "base64":
		return conv.base64_encode(data = obfuscated_data, allocator = allocator)
	case "base64url":
		return conv.base64url_encode(data = obfuscated_data, allocator = allocator)
	case "base91":
		return conv.base91_encode(data = obfuscated_data, escape = true, allocator = allocator)
	case "hex":
		return conv.hex_encode(data = obfuscated_data, allocator = allocator)
	case:
		//---------------------------------------
		obfuscated_data, _ = strings.replace_all(obfuscated_data, "-", "--", allocator)
		obfuscated_data, _ = strings.replace_all(obfuscated_data, "\x09", "-t", allocator)
		obfuscated_data, _ = strings.replace_all(obfuscated_data, "\x0A", "-n", allocator)
		obfuscated_data, _ = strings.replace_all(obfuscated_data, "\x0D", "-r", allocator)
		obfuscated_data, _ = strings.replace_all(obfuscated_data, "\x20", "-s", allocator)
		obfuscated_data, _ = strings.replace_all(obfuscated_data, "\x22", "-q", allocator)
		obfuscated_data, _ = strings.replace_all(obfuscated_data, "\x24", "-d", allocator)
		obfuscated_data, _ = strings.replace_all(obfuscated_data, "\x27", "-a", allocator)
		obfuscated_data, _ = strings.replace_all(obfuscated_data, "\x5C", "-b", allocator)
		obfuscated_data, _ = strings.replace_all(obfuscated_data, "\x60", "-g", allocator)
		//---------------------------------------
		return obfuscated_data, nil
	//---------------------------------------
	}
	//---------------------------------------
}

//------------------------------------------------------------

obfuscateXOR_decode :: proc(
	data: string,
	value: u8,
	encoding := "",
	allocator := context.allocator,
) -> (
	output: string,
	err: Error,
) {
	//---------------------------------------
	if data == "" {
		return data, nil
	}
	//---------------------------------------
	decoded_data: string
	//---------------------------------------
	switch encoding {
	case "base":
		decoded_data = conv.base_decode(data = data, allocator = allocator) or_return
	case "base64":
		decoded_data = conv.base64_decode(data = data, allocator = allocator) or_return
	case "base64url":
		decoded_data = conv.base64url_decode(data = data, allocator = allocator) or_return
	case "base91":
		decoded_data = conv.base91_decode(
			data = data,
			unescape = true,
			allocator = allocator,
		) or_return
	case "hex":
		decoded_data = conv.hex_decode(data = data, allocator = allocator) or_return
	case:
		//---------------------------------------
		decoded_data = data
		//---------------------------------------
		decoded_data, _ = strings.replace_all(decoded_data, "--", "-SUB", allocator)
		decoded_data, _ = strings.replace_all(decoded_data, "-g", "\x60", allocator)
		decoded_data, _ = strings.replace_all(decoded_data, "-b", "\x5C", allocator)
		decoded_data, _ = strings.replace_all(decoded_data, "-a", "\x27", allocator)
		decoded_data, _ = strings.replace_all(decoded_data, "-d", "\x24", allocator)
		decoded_data, _ = strings.replace_all(decoded_data, "-q", "\x22", allocator)
		decoded_data, _ = strings.replace_all(decoded_data, "-s", "\x20", allocator)
		decoded_data, _ = strings.replace_all(decoded_data, "-r", "\x0D", allocator)
		decoded_data, _ = strings.replace_all(decoded_data, "-n", "\x0A", allocator)
		decoded_data, _ = strings.replace_all(decoded_data, "-t", "\x09", allocator)
		decoded_data, _ = strings.replace_all(decoded_data, "-SUB", "-", allocator)
	//---------------------------------------
	}
	//---------------------------------------
	return obfuscateXOR(data = decoded_data, value = value, allocator = allocator)
	//---------------------------------------
}

//------------------------------------------------------------

main :: proc() {
	//---------------------------------------
	fmt.printfln("%s: main function", filepath.base(os.args[0]))
	//---------------------------------------
}

//------------------------------------------------------------
