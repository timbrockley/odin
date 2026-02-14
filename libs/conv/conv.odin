package conv

//------------------------------------------------------------
// Copyright 2025 Tim Brockley. All rights reserved.
// This software is licensed under the MIT License.
//------------------------------------------------------------

import "core:encoding/base64"
import "core:fmt"
import "core:mem"
import "core:os"
import "core:path/filepath"

//------------------------------------------------------------

Error :: union #shared_nil {
	ConvError,
	mem.Allocator_Error,
}

ConvError :: enum {
	InvalidBaseValue,
	InvalidEscapedBase91Character,
	InvalidEncodedBaseCharacter,
	InvalidEncodedBase91Character,
	InvalidHexValue,
	InvalidHexStringLength,
	InvalidEncodedHexCharacter,
}

//------------------------------------------------------------

base_encode :: proc(data: string, allocator := context.allocator) -> (output: string, err: Error) {
	//---------------------------------------
	if data == "" {return data, nil}
	//---------------------------------------
	padding_length := 0
	if len(data) % 4 > 0 {
		padding_length = (4 - len(data) % 4)
	}
	//---------------------------------------
	output_length := ((len(data) + padding_length) / 4 * 5) - padding_length
	//---------------------------------------
	output_bytes := make([]u8, output_length, allocator) or_return
	//---------------------------------------
	output_index := 0
	//---------------------------------------
	data_index := 0
	//---------------------------------------
	for data_index < len(data) {
		//---------------------------------------
		b0: u32 = data_index < len(data) ? u32(data[data_index]) : 0
		b1: u32 = data_index + 1 < len(data) ? u32(data[data_index + 1]) : 0
		b2: u32 = data_index + 2 < len(data) ? u32(data[data_index + 2]) : 0
		b3: u32 = data_index + 3 < len(data) ? u32(data[data_index + 3]) : 0
		//---------------------------------------
		data_chunk_sum: u32 = b0 << 24 | b1 << 16 | b2 << 8 | b3
		//---------------------------------------
		if data_chunk_sum == 0 {
			//---------------------------------------
			for block_index in 0 ..< 5 {
				if output_index + block_index < output_length {
					output_bytes[output_index + block_index] = '!'
				}
			}
			output_index += 5
			//---------------------------------------
		} else {
			//---------------------------------------
			for block_index in 0 ..< 5 {
				//---------------------------------------
				value: u32 = data_chunk_sum % 85
				data_chunk_sum = (data_chunk_sum - value) / 85
				//---------------------------------------
				reversed_block_index := 5 - block_index - 1
				//---------------------------------------
				if output_index + reversed_block_index < output_length {
					output_bytes[output_index + reversed_block_index] = baseValueEncode(
						u8(value & 0xFF),
					) or_return
				}
				//---------------------------------------
			}
			//---------------------------------------
			output_index += 5
			//---------------------------------------
		}
		//---------------------------------------
		data_index += 4
		//---------------------------------------
	}
	//---------------------------------------
	return string(output_bytes), Error{}
	//---------------------------------------
}

//------------------------------------------------------------

base_decode :: proc(data: string, allocator := context.allocator) -> (output: string, err: Error) {
	//---------------------------------------
	if data == "" {return data, nil}
	//---------------------------------------
	padding_length := 0
	if len(data) % 5 > 0 {
		padding_length = (5 - len(data) % 5)
	}
	//---------------------------------------
	output_length := ((len(data) + padding_length) / 5 * 4) - padding_length
	//---------------------------------------
	output_bytes := make([]u8, output_length, allocator) or_return
	//---------------------------------------
	output_index := 0
	//---------------------------------------
	data_index := 0
	//---------------------------------------
	for data_index < len(data) {
		//---------------------------------------
		b0: u64 =
			data_index < len(data) ? u64(baseValueDecode(data[data_index]) or_return) : u64('z')
		b1: u64 =
			data_index + 1 < len(data) ? u64(baseValueDecode(data[data_index + 1]) or_return) : u64('z')
		b2: u64 =
			data_index + 2 < len(data) ? u64(baseValueDecode(data[data_index + 2]) or_return) : u64('z')
		b3: u64 =
			data_index + 3 < len(data) ? u64(baseValueDecode(data[data_index + 3]) or_return) : u64('z')
		b4: u64 =
			data_index + 4 < len(data) ? u64(baseValueDecode(data[data_index + 4]) or_return) : u64('z')
		//---------------------------------------
		decoded_chunk: u64 = 52200625 * b0 + 614125 * b1 + 7225 * b2 + 85 * b3 + b4
		//---------------------------------------
		if output_index <
		   output_length {output_bytes[output_index] = u8(decoded_chunk >> 24 & 0xFF)}
		if output_index + 1 <
		   output_length {output_bytes[output_index + 1] = u8(decoded_chunk >> 16 & 0xFF)}
		if output_index + 2 <
		   output_length {output_bytes[output_index + 2] = u8(decoded_chunk >> 8 & 0xFF)}
		if output_index + 3 <
		   output_length {output_bytes[output_index + 3] = u8(decoded_chunk & 0xFF)}
		//---------------------------------------
		output_index += 4
		//---------------------------------------
		data_index += 5
		//---------------------------------------
	}
	//---------------------------------------
	return string(output_bytes), nil
	//---------------------------------------
}

//------------------------------------------------------------

baseValueEncode :: proc(value: u8) -> (u8, Error) {
	switch value {
	case 0:
		return '!', nil
	case 1:
		return '#', nil
	case 2:
		return '%', nil
	case 3:
		return '&', nil
	case 4 ..= 55:
		return value + 36, nil
	case 56:
		return ']', nil
	case 57:
		return '^', nil
	case 58:
		return '_', nil
	case 59 ..= 84:
		return value + 38, nil
	case:
		return 0, .InvalidBaseValue
	}
}

//------------------------------------------------------------

baseValueDecode :: proc(char: u8) -> (u8, Error) {
	switch char {
	case '!':
		return 0, nil
	case '#':
		return 1, nil
	case '%':
		return 2, nil
	case '&':
		return 3, nil
	case '(' ..= '[':
		return char - 36, nil
	case ']':
		return 56, nil
	case '^':
		return 57, nil
	case '_':
		return 58, nil
	case 'a' ..= 'z':
		return char - 38, nil
	case:
		return 0, .InvalidEncodedBaseCharacter
	}
}

//------------------------------------------------------------

base64_encode :: proc(data: string, allocator := context.allocator) -> (string, Error) {
	//---------------------------------------
	if data == "" {return data, nil}
	//---------------------------------------
	data_bytes := transmute([]u8)data
	//---------------------------------------
	output_bytes, err := base64.encode(data = data_bytes, allocator = allocator)
	//---------------------------------------
	if err != .None {return "", err}
	//---------------------------------------
	return string(output_bytes), nil
	//---------------------------------------
}

//------------------------------------------------------------

base64_decode :: proc(data: string, allocator := context.allocator) -> (string, Error) {
	//---------------------------------------
	if data == "" {return data, nil}
	//---------------------------------------
	output_bytes, err := base64.decode(data = data, allocator = allocator)
	//---------------------------------------
	if err != .None {return "", err}
	//---------------------------------------
	return string(output_bytes), nil
	//---------------------------------------
}

//------------------------------------------------------------

base64url_encode :: proc(
	data: string,
	allocator := context.allocator,
) -> (
	output: string,
	err: Error,
) {
	//---------------------------------------
	if data == "" {return data, nil}
	//---------------------------------------
	data_bytes := transmute([]u8)data
	//---------------------------------------
	encoded_data := base64.encode(data = data_bytes, allocator = allocator) or_return
	//---------------------------------------
	output_bytes := make([]u8, len(encoded_data), allocator) or_return
	//---------------------------------------
	padding_count := 0
	output_length := len(output_bytes)
	//---------------------------------------
	for output_index in 0 ..< output_length {
		switch encoded_data[output_index] {
		case '+':
			output_bytes[output_index] = '-'
		case '/':
			output_bytes[output_index] = '_'
		case '=':
			padding_count += 1
		case:
			output_bytes[output_index] = encoded_data[output_index]
		}
	}
	//---------------------------------------
	return string(output_bytes[:output_length - padding_count]), nil
	//---------------------------------------
}

//------------------------------------------------------------

base64url_decode :: proc(
	data: string,
	allocator := context.allocator,
) -> (
	output: string,
	err: Error,
) {
	//---------------------------------------
	if data == "" {return data, nil}
	//---------------------------------------
	padding_length := len(data) % 4 > 0 ? (4 - len(data) % 4) : 0
	//---------------------------------------
	encoded_data_bytes := make([]u8, len(data) + padding_length, allocator) or_return
	//---------------------------------------
	for data_index in 0 ..< len(encoded_data_bytes) {
		if data_index < len(data) {
			switch data[data_index] {
			case '-':
				encoded_data_bytes[data_index] = '+'
			case '_':
				encoded_data_bytes[data_index] = '/'
			case:
				encoded_data_bytes[data_index] = data[data_index]
			}
		} else {
			encoded_data_bytes[data_index] = '='
		}
	}
	//---------------------------------------
	decoded_data_bytes := base64.decode(
		data = string(encoded_data_bytes),
		allocator = allocator,
	) or_return
	//---------------------------------------
	return string(decoded_data_bytes), nil
	//---------------------------------------
}

//------------------------------------------------------------

BASE91_CHARSET := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!#\x24%&()*+,./:;<=>?@[]^_\x60{|}~\x22"

BASE91_DECODING_TABLE := "\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x3E\x5A\x3F\x40\x41\x42\x5B\x43\x44\x45\x46\x47\x5B\x48\x49\x34\x35\x36\x37\x38\x39\x3A\x3B\x3C\x3D\x4A\x4B\x4C\x4D\x4E\x4F\x50\x00\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0A\x0B\x0C\x0D\x0E\x0F\x10\x11\x12\x13\x14\x15\x16\x17\x18\x19\x51\x5B\x52\x53\x54\x55\x1A\x1B\x1C\x1D\x1E\x1F\x20\x21\x22\x23\x24\x25\x26\x27\x28\x29\x2A\x2B\x2C\x2D\x2E\x2F\x30\x31\x32\x33\x56\x57\x58\x59\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B\x5B"

//------------------------------------------------------------

base91_encode :: proc(
	data: string,
	escape := false,
	allocator := context.allocator,
) -> (
	output: string,
	err: Error,
) {
	//---------------------------------------
	if data == "" {return data, nil}
	//---------------------------------------
	buffer := make([]u8, len(data) * 2, allocator) or_return
	defer delete(buffer, allocator)
	//---------------------------------------
	queue: u32 = 0
	num_bits: u32 = 0
	//---------------------------------------
	buffer_index := 0
	//---------------------------------------
	data_index := 0
	//---------------------------------------
	for data_index < len(data) {
		//---------------------------------------
		queue |= u32(data[data_index]) << num_bits
		num_bits += 8
		//---------------------------------------
		for num_bits > 13 {
			value := queue & 8191
			if value > 88 {
				queue >>= 13
				num_bits -= 13
			} else {
				value = queue & 16383
				queue >>= 14
				num_bits -= 14
			}
			//---------------------------------------
			if escape {
				base91EscapedOutput(buffer, &buffer_index, BASE91_CHARSET[value % 91])
				base91EscapedOutput(buffer, &buffer_index, BASE91_CHARSET[value / 91])
			} else {
				buffer[buffer_index] = BASE91_CHARSET[value % 91]
				buffer[buffer_index + 1] = BASE91_CHARSET[value / 91]
				buffer_index += 2
			}
		}
		//---------------------------------------
		data_index += 1
		//---------------------------------------
	}
	//---------------------------------------
	if (num_bits > 0) {
		//---------------------------------------
		if (escape) {
			base91EscapedOutput(buffer, &buffer_index, BASE91_CHARSET[queue % 91])
		} else {
			buffer[buffer_index] = BASE91_CHARSET[queue % 91]
			buffer_index += 1
		}
		//---------------------------------------
		if num_bits > 7 || queue > 90 {
			//---------------------------------------
			if (escape) {
				base91EscapedOutput(buffer, &buffer_index, BASE91_CHARSET[queue / 91])
			} else {
				buffer[buffer_index] = BASE91_CHARSET[queue / 91]
				buffer_index += 1
			}
			//---------------------------------------
		}
		//---------------------------------------
	}
	//---------------------------------------
	output_bytes := make([]u8, buffer_index, allocator) or_return
	//---------------------------------------
	for output_index in 0 ..< buffer_index {output_bytes[output_index] = buffer[output_index]}
	//---------------------------------------
	return string(output_bytes), nil
	//---------------------------------------
}

//------------------------------------------------------------

base91_decode :: proc(
	data: string,
	unescape := false,
	allocator := context.allocator,
) -> (
	output: string,
	err: Error,
) {
	//---------------------------------------
	if data == "" {return data, nil}
	//---------------------------------------
	buffer := make([]u8, len(data) * 2, allocator) or_return
	defer delete(buffer, allocator)
	//---------------------------------------
	queue: u32 = 0
	num_bits: u32 = 0
	//---------------------------------------
	value: u32 = 0xFFFFFFFF
	//---------------------------------------
	buffer_index := 0
	//---------------------------------------
	data_index := 0
	//---------------------------------------
	for data_index < len(data) {
		//---------------------------------------
		char: u8 = data[data_index]
		//----------------------------------------
		if unescape && data_index < len(data) - 1 && char == '-' {
			data_index += 1
			char = base91UnescapeChar(data[data_index]) or_return
		}
		//---------------------------------------
		encoded_value := BASE91_DECODING_TABLE[char]
		//----------------------------------------
		if encoded_value == 91 {return "", .InvalidEncodedBase91Character}
		//---------------------------------------
		if value == 0xFFFFFFFF {
			//---------------------------------------
			value = u32(encoded_value)
			//---------------------------------------
		} else {
			//---------------------------------------
			value += u32(encoded_value) * 91
			queue |= value << num_bits
			//---------------------------------------
			num_bits += (value & 8191 > 88) ? 13 : 14
			//---------------------------------------
			for num_bits > 7 {
				buffer[buffer_index] = u8(queue & 0xFF)
				buffer_index += 1
				queue >>= 8
				num_bits -= 8
			}
			//---------------------------------------
			value = 0xFFFFFFFF
			//---------------------------------------
		}
		//---------------------------------------
		data_index += 1
		//---------------------------------------
	}
	//---------------------------------------
	if value != 0xFFFFFFFF {
		buffer[buffer_index] = u8(queue | value << num_bits & 0xFF)
		buffer_index += 1
	}
	//---------------------------------------
	output_bytes := make([]u8, buffer_index, allocator) or_return
	//---------------------------------------
	for output_index in 0 ..< buffer_index {output_bytes[output_index] = buffer[output_index]}
	//---------------------------------------
	return string(output_bytes), nil
	//---------------------------------------
}

//------------------------------------------------------------

base91EscapedOutput :: proc(output_bytes: []u8, output_index: ^int, char: u8) {
	switch char {
	case 0x22:
		output_bytes[output_index^] = '-'
		output_bytes[output_index^ + 1] = 'q'
		output_index^ += 2

	case 0x24:
		output_bytes[output_index^] = '-'
		output_bytes[output_index^ + 1] = 'd'
		output_index^ += 2

	case 0x60:
		output_bytes[output_index^] = '-'
		output_bytes[output_index^ + 1] = 'g'
		output_index^ += 2

	case:
		output_bytes[output_index^] = char
		output_index^ += 1
	}
}

//------------------------------------------------------------

base91UnescapeChar :: proc(char: u8) -> (u8, Error) {
	switch char {
	case 'q':
		return 0x22, nil
	case 'd':
		return 0x24, nil
	case 'g':
		return 0x60, nil
	case:
		return 0, .InvalidEscapedBase91Character
	}
}

//------------------------------------------------------------

hex_encode :: proc(data: string, allocator := context.allocator) -> (output: string, err: Error) {
	//---------------------------------------
	if data == "" {return data, nil}
	//---------------------------------------
	output_bytes := make([]byte, len(data) * 2, allocator) or_return
	//---------------------------------------
	for i, j := 0, 0; i < len(data); i += 1 {
		//---------------------------------------
		output_bytes[j] = hexValueEncode(data[i] >> 4) or_return
		output_bytes[j + 1] = hexValueEncode(data[i] & 0x0F) or_return
		//---------------------------------------
		j += 2
		//---------------------------------------
	}
	//---------------------------------------
	return string(output_bytes), nil
	//---------------------------------------
}

//------------------------------------------------------------

hex_decode :: proc(data: string, allocator := context.allocator) -> (output: string, err: Error) {
	//---------------------------------------
	if data == "" {return data, nil}
	//---------------------------------------
	if len(data) % 2 == 1 {return "", .InvalidHexStringLength}
	//---------------------------------------
	output_bytes := make([]byte, len(data) / 2, allocator) or_return
	//---------------------------------------
	for i, j := 0, 1; j < len(data); j += 2 {
		//---------------------------------------
		hi := hexValueDecode(data[j - 1]) or_return
		lo := hexValueDecode(data[j]) or_return
		//---------------------------------------
		output_bytes[i] = (hi << 4) | lo
		//---------------------------------------
		i += 1
		//---------------------------------------
	}
	//---------------------------------------
	return string(output_bytes), nil
	//---------------------------------------
}

//------------------------------------------------------------

hexValueEncode :: proc(value: u8) -> (u8, Error) {
	switch value {
	case 0 ..= 9:
		return value + '0', nil
	case 10 ..= 15:
		return value + 'A' - 10, nil
	case:
		return 0, .InvalidHexValue
	}
}

//------------------------------------------------------------

hexValueDecode :: proc(char: u8) -> (u8, Error) {
	switch char {
	case '0' ..= '9':
		return char - '0', nil
	case 'A' ..= 'F':
		return char - 'A' + 10, nil
	case 'a' ..= 'f':
		return char - 'a' + 10, nil
	case:
		return 0, .InvalidEncodedHexCharacter
	}
}

//------------------------------------------------------------

main :: proc() {
	//---------------------------------------
	fmt.printfln("%s: main function", filepath.base(os.args[0]))
	//---------------------------------------
}

//------------------------------------------------------------
