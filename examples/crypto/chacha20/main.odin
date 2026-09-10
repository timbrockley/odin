package main

import "core:crypto"
import "core:crypto/chacha20poly1305"
import "core:fmt"
//------------------------------------------------------------
main :: proc() {
	//------------------------------------------------------------
	fmt.println("--------------------------------------------------------------------------------")
	//------------------------------------------------------------
	// zero values for testing purposes
	key: [32]u8
	nonce: [12]u8
	//------------------------------------------------------------
	data := []u8{'t', 'e', 's', 't', '1', '2', '3', '4'}
	//------------------------------------------------------------
	{
		fmt.printfln("data:      %s", string(data))

		encrypted := make([]u8, len(data))
		defer delete(encrypted)

		aad := []u8{}

		tag: [16]u8

		ctx: chacha20poly1305.Context
		chacha20poly1305.init(&ctx, key[:])
		chacha20poly1305.seal(&ctx, encrypted, tag[:], nonce[:], aad, data)

		fmt.printfln("encrypted: %d", encrypted)
		fmt.printfln("tag:       %d", tag)

		decrypted := make([]u8, len(encrypted))
		defer delete(decrypted)

		success := chacha20poly1305.open(&ctx, decrypted, nonce[:], aad, encrypted, tag[:])
		if success {
			fmt.printfln("decrypted: %s", string(decrypted))
		} else {
			fmt.println("decryption failed: the data or tag was tampered with")
		}
	}
	//------------------------------------------------------------
	fmt.println("--------------------------------------------------------------------------------")
	//------------------------------------------------------------
	{
		crypto.rand_bytes(key[:])
		crypto.rand_bytes(nonce[:])

		fmt.printfln("data:      %s", string(data))

		encrypted := make([]u8, len(data))
		defer delete(encrypted)

		aad := []u8{'S', 'e', 's', 's', 'i', 'o', 'n', '-', 'I', 'D', '-', '4', '2'}

		tag: [16]u8

		ctx: chacha20poly1305.Context
		chacha20poly1305.init(&ctx, key[:])
		chacha20poly1305.seal(&ctx, encrypted, tag[:], nonce[:], aad, data)

		fmt.printfln("encrypted: %d", encrypted)
		fmt.printfln("tag:       %d", tag)

		decrypted := make([]u8, len(encrypted))
		defer delete(decrypted)

		success := chacha20poly1305.open(&ctx, decrypted, nonce[:], aad, encrypted, tag[:])
		if success {
			fmt.printfln("decrypted: %s", string(decrypted))
		} else {
			fmt.println("decryption failed: the data or tag was tampered with")
		}
		//------------------------------------------------------------
	}
	//------------------------------------------------------------
	fmt.println("--------------------------------------------------------------------------------")
	//------------------------------------------------------------
}

//--------------------------------------------------------------------------------
