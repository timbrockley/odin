#+feature global-context

package crypto

//------------------------------------------------------------

import "core:mem/virtual"
import "core:testing"

//------------------------------------------------------------

arena: virtual.Arena
allocator := virtual.arena_allocator(&arena)

//------------------------------------------------------------

@(fini)
deinit_test :: proc() {virtual.arena_destroy(&arena)}

//------------------------------------------------------------

@(test)
test_obfuscateV0 :: proc(t: ^testing.T) {
	//----------------------------------------
	test_cases := []struct {
		data:     string,
		expected: string,
	} {
		{data = "", expected = ""},
		{data = "hello", expected = "6922/"},
		{data = "6922/", expected = "hello"},
		{
			data = "test BBB>>>www|||qqqzzz 123 \x00\x09\x0A ~~~",
			expected = "\x2A\x39\x2B\x2A\x7E\x5C\x5C\x5C\x60\x60\x60\x27\x27\x27\x22\x22\x22\x2D\x2D\x2D\x24\x24\x24\x7E\x6D\x6C\x6B\x7E\x1F\x16\x15\x7E\x20\x20\x20",
		},
		{
			data = "\x2A\x39\x2B\x2A\x7E\x5C\x5C\x5C\x60\x60\x60\x27\x27\x27\x22\x22\x22\x2D\x2D\x2D\x24\x24\x24\x7E\x6D\x6C\x6B\x7E\x1F\x16\x15\x7E\x20\x20\x20",
			expected = "test BBB>>>www|||qqqzzz 123 \x00\x09\x0A ~~~",
		},
	}
	//----------------------------------------
	for test_case in test_cases {
		result, err := obfuscateV0(data = test_case.data, allocator = allocator)
		testing.expect_value(t, result, test_case.expected)
		testing.expect_value(t, err, nil)
		// delete(result)
	}
	//----------------------------------------
}

//------------------------------------------------------------

@(test)
test_slideByteV0 :: proc(t: ^testing.T) {
	//----------------------------------------
	test_cases := []struct {
		byte:     u8,
		expected: u8,
	} {
		{byte = 0, expected = 31},
		{byte = 31, expected = 0},
		{byte = 32, expected = 126},
		{byte = 126, expected = 32},
		{byte = 127, expected = 127},
		{byte = 128, expected = 255},
		{byte = 255, expected = 128},
	}
	//----------------------------------------
	for test_case in test_cases {
		result := slideByteV0(test_case.byte)
		testing.expect_value(t, result, test_case.expected)
	}
	//----------------------------------------
}

//------------------------------------------------------------

@(test)
test_obfuscateV0_encode :: proc(t: ^testing.T) {
	//----------------------------------------
	test_cases := []struct {
		data:         string,
		encoding:     string,
		expected:     string,
		expected_err: Error,
	} {
		{data = "", encoding = "", expected = "", expected_err = nil},
		{data = "ABC", encoding = "", expected = "]-b[", expected_err = nil},
		{data = "hello", encoding = "", expected = "6922/", expected_err = nil},
		{
			data = "Aq\x16\x15\x12~|zwB>qF",
			encoding = "",
			expected = "]---t-n-r-s-q-d-a-b-g--X",
			expected_err = nil,
		},
		{
			data = "ABC\U0001F427",
			encoding = "",
			expected = "\x5D\x2D\x62\x5B\x8F\xE0\xEF\xD8",
			expected_err = nil,
		},
		{data = "ABC\U0001F427", encoding = "base", expected = "B!OWun=%=", expected_err = nil},
		{
			data = "ABC\U0001F427",
			encoding = "base64",
			expected = "XVxbj+Dv2A==",
			expected_err = nil,
		},
		{
			data = "ABC\U0001F427",
			encoding = "base64url",
			expected = "XVxbj-Dv2A",
			expected_err = nil,
		},
		{data = "ABC\U0001F427", encoding = "base91", expected = ".?x;](ZyN", expected_err = nil},
		{
			data = "ABC\U0001F427",
			encoding = "hex",
			expected = "5D5C5B8FE0EFD8",
			expected_err = nil,
		},
	}
	//----------------------------------------
	for test_case in test_cases {
		result, err := obfuscateV0_encode(
			data = test_case.data,
			encoding = test_case.encoding,
			allocator = allocator,
		)
		testing.expect_value(t, result, test_case.expected)
		testing.expect_value(t, err, nil)
		// delete(result)
	}
	//----------------------------------------
}

//------------------------------------------------------------

@(test)
test_obfuscateV0_decode :: proc(t: ^testing.T) {
	//----------------------------------------
	test_cases := []struct {
		data:         string,
		encoding:     string,
		expected:     string,
		expected_err: Error,
	} {
		{data = "", encoding = "", expected = "", expected_err = nil},
		{data = "]-b[", encoding = "", expected = "ABC", expected_err = nil},
		{data = "6922/", encoding = "", expected = "hello", expected_err = nil},
		{
			data = "]---t-n-r-s-q-d-a-b-g--X",
			encoding = "",
			expected = "Aq\x16\x15\x12~|zwB>qF",
			expected_err = nil,
		},
		{
			data = "\x5D\x2D\x62\x5B\x8F\xE0\xEF\xD8",
			encoding = "",
			expected = "ABC\U0001F427",
			expected_err = nil,
		},
		{data = "B!OWun=%=", encoding = "base", expected = "ABC\U0001F427", expected_err = nil},
		{
			data = "XVxbj+Dv2A==",
			encoding = "base64",
			expected = "ABC\U0001F427",
			expected_err = nil,
		},
		{
			data = "XVxbj-Dv2A",
			encoding = "base64url",
			expected = "ABC\U0001F427",
			expected_err = nil,
		},
		{data = ".?x;](ZyN", encoding = "base91", expected = "ABC\U0001F427", expected_err = nil},
		{
			data = "5D5C5B8FE0EFD8",
			encoding = "hex",
			expected = "ABC\U0001F427",
			expected_err = nil,
		},
	}
	//----------------------------------------
	for test_case in test_cases {
		result, err := obfuscateV0_decode(
			data = test_case.data,
			encoding = test_case.encoding,
			allocator = allocator,
		)
		testing.expect_value(t, result, test_case.expected)
		testing.expect_value(t, err, nil)
		// delete(result)
	}
	//----------------------------------------
}

//------------------------------------------------------------

@(test)
test_obfuscateV4 :: proc(t: ^testing.T) {
	//----------------------------------------
	test_cases := []struct {
		data:      string,
		expected:  string,
		mix_chars: bool,
	} {
		{data = "", expected = "", mix_chars = false},
		{data = "", expected = "", mix_chars = true},
		{data = "ABC", expected = "]\\[", mix_chars = false},
		{data = "ABC", expected = "]\\[", mix_chars = true},
		{data = "hello", expected = "6922/", mix_chars = false},
		{data = "hello", expected = "6229/", mix_chars = true},
		{data = "6922/", expected = "hello", mix_chars = false},
		{data = "6229/", expected = "hello", mix_chars = true},
		{
			data = "test BBB>>>www|||qqq 123XXX",
			expected = "*\x27+\x22~-\x5C-\x60m\x60k\x279\x22*\x22\x5C-\x5C~\x60l\x27FFF",
			mix_chars = true,
		},
		{
			data = "*\x27+\x22~-\x5C-\x60m\x60k\x279\x22*\x22\x5C-\x5C~\x60l\x27FFF",
			expected = "test BBB>>>www|||qqq 123XXX",
			mix_chars = true,
		},
	}

	//----------------------------------------
	for test_case in test_cases {
		result, err := obfuscateV4(
			data = test_case.data,
			mix_chars = test_case.mix_chars,
			allocator = allocator,
		)
		testing.expect_value(t, result, test_case.expected)
		testing.expect_value(t, err, nil)
		// delete(result)
	}
	//----------------------------------------
}

//------------------------------------------------------------

@(test)
test_slideByteV4 :: proc(t: ^testing.T) {
	//----------------------------------------
	test_cases := []struct {
		byte:     u8,
		expected: u8,
	} {
		{byte = 0, expected = 0},
		{byte = 31, expected = 31},
		{byte = 32, expected = 126},
		{byte = 126, expected = 32},
		{byte = 127, expected = 127},
		{byte = 128, expected = 128},
		{byte = 255, expected = 255},
	}
	//----------------------------------------
	for test_case in test_cases {
		result := slideByteV4(test_case.byte)
		testing.expect_value(t, result, test_case.expected)
	}
	//----------------------------------------
}

//------------------------------------------------------------

@(test)
test_obfuscateV4_encode :: proc(t: ^testing.T) {
	//----------------------------------------
	test_cases := []struct {
		data:         string,
		mix_chars:    bool,
		encoding:     string,
		expected:     string,
		expected_err: Error,
	} {
		{data = "", mix_chars = false, encoding = "", expected = "", expected_err = nil},
		{data = "", mix_chars = true, encoding = "", expected = "", expected_err = nil},
		{data = "ABC", mix_chars = false, encoding = "", expected = "]\\\\[", expected_err = nil},
		{data = "ABC", mix_chars = true, encoding = "", expected = "]\\\\[", expected_err = nil},
		{data = "hello", mix_chars = false, encoding = "", expected = "6922/", expected_err = nil},
		{data = "hello", mix_chars = true, encoding = "", expected = "6229/", expected_err = nil},
		{
			data = "ABC\U0001F427",
			mix_chars = true,
			encoding = "",
			expected = "\x5D\xF0\x5B\x5C\x5C\x9F\x90\xA7",
			expected_err = nil,
		},
		{
			data = "test BBB>>>www|||qqq 123",
			mix_chars = true,
			encoding = "base",
			expected = "1RTdoLS#jYBz<=j0WQD%/&^c,LXKyA",
			expected_err = nil,
		},
		{
			data = "test BBB>>>www|||qqq 123",
			mix_chars = true,
			encoding = "base64",
			expected = "KicrIn4tXC1gbWBrJzkiKiJcLVx+YGwn",
			expected_err = nil,
		},
		{
			data = "test BBB>>>www|||qqq 123",
			mix_chars = true,
			encoding = "base64url",
			expected = "KicrIn4tXC1gbWBrJzkiKiJcLVx-YGwn",
			expected_err = nil,
		},
		{
			data = "test BBB>>>www|||qqq 123",
			mix_chars = true,
			encoding = "base91",
			expected = "OU/w-d}u)}H;#-ql>NXG%w.-du)TWm!&B",
			expected_err = nil,
		},
		{
			data = "test BBB>>>www|||qqq 123",
			mix_chars = true,
			encoding = "hex",
			expected = "2A272B227E2D5C2D606D606B2739222A225C2D5C7E606C27",
			expected_err = nil,
		},
	}
	//----------------------------------------
	for test_case in test_cases {
		result, err := obfuscateV4_encode(
			data = test_case.data,
			mix_chars = test_case.mix_chars,
			encoding = test_case.encoding,
			allocator = allocator,
		)
		testing.expect_value(t, result, test_case.expected)
		testing.expect_value(t, err, nil)
		// delete(result)
	}
	//----------------------------------------
}

// //------------------------------------------------------------

@(test)
test_obfuscateV4_decode :: proc(t: ^testing.T) {
	//----------------------------------------
	test_cases := []struct {
		data:         string,
		mix_chars:    bool,
		encoding:     string,
		expected:     string,
		expected_err: Error,
	} {
		{data = "", mix_chars = false, encoding = "", expected = "", expected_err = nil},
		{data = "", mix_chars = true, encoding = "", expected = "", expected_err = nil},
		{data = "]\\[", mix_chars = false, encoding = "", expected = "ABC", expected_err = nil},
		{data = "]\\[", mix_chars = true, encoding = "", expected = "ABC", expected_err = nil},
		{data = "6922/", mix_chars = false, encoding = "", expected = "hello", expected_err = nil},
		{data = "6229/", mix_chars = true, encoding = "", expected = "hello", expected_err = nil},
		{
			data = "\x5D\xF0\x5B\x5C\x5C\x9F\x90\xA7",
			mix_chars = true,
			encoding = "",
			expected = "ABC\U0001F427",
			expected_err = nil,
		},
		{
			data = "1RTdoLS#jYBz<=j0WQD%/&^c,LXKyA",
			mix_chars = true,
			encoding = "base",
			expected = "test BBB>>>www|||qqq 123",
			expected_err = nil,
		},
		{
			data = "KicrIn4tXC1gbWBrJzkiKiJcLVx+YGwn",
			mix_chars = true,
			encoding = "base64",
			expected = "test BBB>>>www|||qqq 123",
			expected_err = nil,
		},
		{
			data = "KicrIn4tXC1gbWBrJzkiKiJcLVx-YGwn",
			mix_chars = true,
			encoding = "base64url",
			expected = "test BBB>>>www|||qqq 123",
			expected_err = nil,
		},
		{
			data = "OU/w-d}u)}H;#-ql>NXG%w.-du)TWm!&B",
			mix_chars = true,
			encoding = "base91",
			expected = "test BBB>>>www|||qqq 123",
			expected_err = nil,
		},
		{
			data = "2A272B227E2D5C2D606D606B2739222A225C2D5C7E606C27",
			mix_chars = true,
			encoding = "hex",
			expected = "test BBB>>>www|||qqq 123",
			expected_err = nil,
		},
	}
	//----------------------------------------
	for test_case in test_cases {
		result, err := obfuscateV4_decode(
			data = test_case.data,
			mix_chars = test_case.mix_chars,
			encoding = test_case.encoding,
			allocator = allocator,
		)
		testing.expect_value(t, result, test_case.expected)
		testing.expect_value(t, err, nil)
		// delete(result)
	}
	//----------------------------------------
}

//------------------------------------------------------------

@(test)
test_obfuscateV5 :: proc(t: ^testing.T) {
	//----------------------------------------
	test_cases := []struct {
		data:     string,
		expected: string,
	} {
		{data = "", expected = ""},
		{data = "ABC", expected = "]\\["},
		{data = "hello", expected = "6229/"},
		{data = "6229/", expected = "hello"},
		{
			data = "test BBB>>>www|||qqqzzz 123 \x00\x09\x0A ~~~",
			expected = "\x2A\x2D\x2B\x2D\x7E\x24\x5C\x7E\x60\x6C\x60\x7E\x27\x16\x22\x7E\x22\x39\x2D\x2A\x24\x5C\x24\x5C\x6D\x60\x6B\x27\x1F\x27\x15\x22\x20\x20\x20",
		},
		{
			data = "\x2A\x2D\x2B\x2D\x7E\x24\x5C\x7E\x60\x6C\x60\x7E\x27\x16\x22\x7E\x22\x39\x2D\x2A\x24\x5C\x24\x5C\x6D\x60\x6B\x27\x1F\x27\x15\x22\x20\x20\x20",
			expected = "test BBB>>>www|||qqqzzz 123 \x00\x09\x0A ~~~",
		},
	}
	//----------------------------------------
	for test_case in test_cases {
		result, err := obfuscateV5(data = test_case.data, allocator = allocator)
		testing.expect_value(t, result, test_case.expected)
		testing.expect_value(t, err, nil)
		// delete(result)
	}
	//----------------------------------------
}

//------------------------------------------------------------

@(test)
test_slideByteV5 :: proc(t: ^testing.T) {
	//----------------------------------------
	test_cases := []struct {
		byte:     u8,
		expected: u8,
	} {
		{byte = 0, expected = 31},
		{byte = 31, expected = 0},
		{byte = 32, expected = 126},
		{byte = 126, expected = 32},
		{byte = 127, expected = 127},
		{byte = 128, expected = 255},
		{byte = 255, expected = 128},
	}
	//----------------------------------------
	for test_case in test_cases {
		result := slideByteV5(test_case.byte)
		testing.expect_value(t, result, test_case.expected)
	}
	//----------------------------------------
}

//------------------------------------------------------------

@(test)
test_obfuscateV5_encode :: proc(t: ^testing.T) {
	//----------------------------------------
	test_cases := []struct {
		data:         string,
		encoding:     string,
		expected:     string,
		expected_err: Error,
	} {
		{data = "", encoding = "", expected = "", expected_err = nil},
		{data = "ABC", encoding = "", expected = "]-b[", expected_err = nil},
		{data = "hello", encoding = "", expected = "6229/", expected_err = nil},
		{
			data = "test BBB>>>www|||qqqzzz 123 ~~~",
			encoding = "",
			expected = "*-q+--~---b-d-g~-gl-a~-q9-q*---b-d-b-d-gm-ak-a-s-s-s",
			expected_err = nil,
		},
		{
			data = "ABC\U0001F427",
			encoding = "",
			expected = "\x5D\x8F\x5B\x2D\x62\xE0\xEF\xD8",
			expected_err = nil,
		},
		{
			data = "ABC\U0001F427",
			encoding = "",
			expected = "\x5D\x8F\x5B\x2D\x62\xE0\xEF\xD8",
			expected_err = nil,
		},
		{data = "ABC\U0001F427", encoding = "base", expected = "B)w5un=%=", expected_err = nil},
		{
			data = "ABC\U0001F427",
			encoding = "base64",
			expected = "XY9bXODv2A==",
			expected_err = nil,
		},
		{
			data = "ABC\U0001F427",
			encoding = "base64url",
			expected = "XY9bXODv2A",
			expected_err = nil,
		},
		{data = "ABC\U0001F427", encoding = "base91", expected = "UrEI+(ZyN", expected_err = nil},
		{
			data = "ABC\U0001F427",
			encoding = "hex",
			expected = "5D8F5B5CE0EFD8",
			expected_err = nil,
		},
	}
	//----------------------------------------
	for test_case in test_cases {
		result, err := obfuscateV5_encode(
			data = test_case.data,
			encoding = test_case.encoding,
			allocator = allocator,
		)
		testing.expect_value(t, result, test_case.expected)
		testing.expect_value(t, err, nil)
		// delete(result)
	}
	//----------------------------------------
}

//------------------------------------------------------------

@(test)
test_obfuscateV5_decode :: proc(t: ^testing.T) {
	//----------------------------------------
	test_cases := []struct {
		data:         string,
		encoding:     string,
		expected:     string,
		expected_err: Error,
	} {
		{data = "", encoding = "", expected = "", expected_err = nil},
		{data = "]-b[", encoding = "", expected = "ABC", expected_err = nil},
		{data = "6229/", encoding = "", expected = "hello", expected_err = nil},
		{
			data = "*-q+--~---b-d-g~-gl-a~-q9-q*---b-d-b-d-gm-ak-a-s-s-s",
			encoding = "",
			expected = "test BBB>>>www|||qqqzzz 123 ~~~",
			expected_err = nil,
		},
		{
			data = "\x5D\x8F\x5B\x2D\x62\xE0\xEF\xD8",
			encoding = "",
			expected = "ABC\U0001F427",
			expected_err = nil,
		},
		{data = "B)w5un=%=", encoding = "base", expected = "ABC\U0001F427", expected_err = nil},
		{
			data = "XY9bXODv2A==",
			encoding = "base64",
			expected = "ABC\U0001F427",
			expected_err = nil,
		},
		{
			data = "XY9bXODv2A",
			encoding = "base64url",
			expected = "ABC\U0001F427",
			expected_err = nil,
		},
		{data = "UrEI+(ZyN", encoding = "base91", expected = "ABC\U0001F427", expected_err = nil},
		{
			data = "5D8F5B5CE0EFD8",
			encoding = "hex",
			expected = "ABC\U0001F427",
			expected_err = nil,
		},
	}
	//----------------------------------------
	for test_case in test_cases {
		result, err := obfuscateV5_decode(
			data = test_case.data,
			encoding = test_case.encoding,
			allocator = allocator,
		)
		testing.expect_value(t, result, test_case.expected)
		testing.expect_value(t, err, nil)
		// delete(result)
	}
	//----------------------------------------
}

//------------------------------------------------------------

@(test)
test_obfuscateXOR :: proc(t: ^testing.T) {
	//----------------------------------------
	value :: 0b10101010
	//----------------------------------------
	test_cases := []struct {
		data:     string,
		expected: string,
	} {
		{data = "", expected = ""},
		{data = "hello", expected = "\xC2\xCF\xC6\xC6\xC5"},
		{data = "\xC2\xCF\xC6\xC6\xC5", expected = "hello"},
	}
	//----------------------------------------
	for test_case in test_cases {
		result, err := obfuscateXOR(data = test_case.data, value = value, allocator = allocator)
		testing.expect_value(t, result, test_case.expected)
		testing.expect_value(t, err, nil)
		// delete(result)
	}
	//----------------------------------------
}

//------------------------------------------------------------


@(test)
test_obfuscateXOR_encode :: proc(t: ^testing.T) {
	//----------------------------------------
	value :: 0b10101010
	//----------------------------------------
	test_cases := []struct {
		data:         string,
		encoding:     string,
		expected:     string,
		expected_err: Error,
	} {
		{data = "", encoding = "", expected = "", expected_err = nil},
		{data = "ABC", encoding = "", expected = "\xEB\xE8\xE9", expected_err = nil},
		{data = "hello", encoding = "", expected = "\xC2\xCF\xC6\xC6\xC5", expected_err = nil},
		{
			data = "ABC\U0001F427",
			encoding = "",
			expected = "\xEB\xE8\xE9\x5A\x35\x3A\x2D\x72",
			expected_err = nil,
		},
		{data = "ABC\U0001F427", encoding = "base", expected = "qkiV=5-,3", expected_err = nil},
		{
			data = "ABC\U0001F427",
			encoding = "base64",
			expected = "6+jpWjU6DQ==",
			expected_err = nil,
		},
		{
			data = "ABC\U0001F427",
			encoding = "base64url",
			expected = "6-jpWjU6DQ",
			expected_err = nil,
		},
		{data = "ABC\U0001F427", encoding = "base91", expected = "IZ0%vlm:A", expected_err = nil},
		{
			data = "ABC\U0001F427",
			encoding = "hex",
			expected = "EBE8E95A353A0D",
			expected_err = nil,
		},
	}
	//----------------------------------------
	for test_case in test_cases {
		result, err := obfuscateXOR_encode(
			data = test_case.data,
			value = value,
			encoding = test_case.encoding,
			allocator = allocator,
		)
		testing.expect_value(t, result, test_case.expected)
		testing.expect_value(t, err, nil)
		// delete(result)
	}
	//----------------------------------------
}

//------------------------------------------------------------

@(test)
test_obfuscateXOR_decode :: proc(t: ^testing.T) {
	//----------------------------------------
	value :: 0b10101010
	//----------------------------------------
	test_cases := []struct {
		data:         string,
		encoding:     string,
		expected:     string,
		expected_err: Error,
	} {
		{data = "", encoding = "", expected = "", expected_err = nil},
		{data = "\xEB\xE8\xE9", encoding = "", expected = "ABC", expected_err = nil},
		{data = "\xC2\xCF\xC6\xC6\xC5", encoding = "", expected = "hello", expected_err = nil},
		{
			data = "\xEB\xE8\xE9\x5A\x35\x3A\x2D\x72",
			encoding = "",
			expected = "ABC\U0001F427",
			expected_err = nil,
		},
		{data = "qkiV=5-,3", encoding = "base", expected = "ABC\U0001F427", expected_err = nil},
		{
			data = "6+jpWjU6DQ==",
			encoding = "base64",
			expected = "ABC\U0001F427",
			expected_err = nil,
		},
		{
			data = "6-jpWjU6DQ",
			encoding = "base64url",
			expected = "ABC\U0001F427",
			expected_err = nil,
		},
		{data = "IZ0%vlm:A", encoding = "base91", expected = "ABC\U0001F427", expected_err = nil},
		{
			data = "EBE8E95A353A0D",
			encoding = "hex",
			expected = "ABC\U0001F427",
			expected_err = nil,
		},
	}
	//----------------------------------------
	for test_case in test_cases {
		result, err := obfuscateXOR_decode(
			data = test_case.data,
			value = value,
			encoding = test_case.encoding,
			allocator = allocator,
		)
		testing.expect_value(t, result, test_case.expected)
		testing.expect_value(t, err, nil)
		// delete(result)
	}
	//----------------------------------------
}

//------------------------------------------------------------
