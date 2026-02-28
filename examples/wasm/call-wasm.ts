#!/usr/bin/env -S deno run --allow-read

const wasmBytes = await Deno.readFile("./math.wasm");

const { instance } = await WebAssembly.instantiate(wasmBytes, {
	env: {
		print: (result: number) => {
			console.log(`The result is ${result}`);
		},
	},
});

const add = instance.exports.add as (a: number, b: number) => number;

console.log("result =", add(11, 22));
