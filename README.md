## Hello wasmtime

This section of the tutorial introduces [wasmtime](https://wasmtime.dev/), a Wasm runtime and one of the Bytecode Alliance's reference implementations for the WebAssembly System Interface ([WASI](https://wasi.dev/)) standards[^1]. We're going to clone an example repository, build a WebAssembly component, and then **serve** it using `wasmtime`.

### Prerequisites
> [!NOTE]
> This first example is Rust-focused, but we'll move onto working with other languages (Go, TypeScript, Python) in a later tutorial stage.

> [!NOTE]
> If you prefer to not clone and install things locally, feel free to work from a Docker container with `docker run --rm -it rust:1-slim-buster`.

- Clone Dan Gohman's [hello-wasi-http](https://github.com/sunfishcode/hello-wasi-http/) repository
- Install [Rust](https://www.rust-lang.org/tools/install)
- Install wasmtime: `curl https://wasmtime.dev/install.sh -sSf | bash`
- Install wasm-tools and cargo component: `cargo install wasm-tools cargo-component`

### What the Wit
From the **hello-wasi-http** repository you cloned locally, take a look at the WebAssembly Interface Types in `wit/world.wit`:
```go
package sunfishcode:hello-wasi-http;

world target-world {
  include wasi:http/proxy@0.2.0;
}
```

This `world` defines all of the interfaces (and functions) that this component will import and export. To make it fully compliant with the `wasi:http` standard it includes all of the interfaces in the `wasi:http/proxy` world, most notably `wasi:http/incoming-handler@0.2.0` which is for handling an incoming HTTP request.

The `world` is also embedded into every component you build; you can inspect every Wasm component to see exactly what its capabilities are before running it. This is a game-changer for security with fine-grained allow lists of capabilities, and it lets you understand a component without seeing the source code. Think of the tools we have to inspect containers, their contents, and what they do, it's very difficult to inspect binaries and containers for what they'll do at runtime before running them.

Feel free to take a look in `src/lib.rs` as well, where you can find the implementation code for this component directly using the WASI interface.

```rust
// ...imports

impl bindings::exports::wasi::http::incoming_handler::Guest for Component {
    fn handle(_request: IncomingRequest, outparam: ResponseOutparam) {
        let hdrs = Fields::new();
        let resp = OutgoingResponse::new(hdrs);
        let body = resp.body().expect("outgoing response");

        ResponseOutparam::set(outparam, Ok(resp));

        let out = body.write().expect("outgoing stream");
        out.blocking_write_and_flush(b"Hello, wasi:http/proxy worldddd!\n")
            .expect("writing response");

        drop(out);
        OutgoingBody::finish(body, None).unwrap();
    }
}
```

This looks pretty similar in each language, and the use of the interface directly here is a good learning exercise.[^2]

### Build your component
Building your component is similar to building a Rust binary, simply run:
```bash
cargo component build
```

This will create a component in `target/wasm32-wasi/debug`, you can use the **wasm-tools** CLI to inspect its wit:
```bash
➜ wasm-tools component wit target/wasm32-wasi/debug/hello_wasi_http.wasm
package root:component;

world root {
  import wasi:io/error@0.2.0;
  import wasi:io/streams@0.2.0;
  import wasi:cli/stdout@0.2.0;
  import wasi:cli/stderr@0.2.0;
  import wasi:cli/stdin@0.2.0;
  import wasi:http/types@0.2.0;

  export wasi:http/incoming-handler@0.2.0;
}
```

As you can see, this component **import**s standard libraries for IO and standard output/error/in, and **export**s the HTTP incoming handler. You know that this component will _never_ be able to access files, make requests of its own, run arbitrary commands, etc without ever looking at the source code.

### Run your component
You can run your component using **wasmtime serve**, which provides the implementation for the HTTP world.

```bash
wasmtime serve -Scommon ./target/wasm32-wasi/debug/hello_wasi_http.wasm
```

In another terminal, try to `curl localhost:8080` and see the hello!

#### Footnotes

[^1]: [jco](https://github.com/bytecodealliance/jco), a NodeJS runtime and JavaScript tooling project, is another reference implementation for WASI.
[^2]: There are multiple tools that abstract this interface usage, like [wasm-http-tools](https://github.com/yoshuawuyts/wasm-http-tools) which supports generating a component from OpenAPI / Swagger specifications.
