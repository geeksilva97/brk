# `pack` / `unpack` — the cheatsheet (binary length prefixes)

Ruby encodes integers to raw bytes with `Array#pack` and decodes them with `String#unpack` /
`String#unpack1`. You need exactly one directive: **`"N"` — a 32-bit unsigned integer, big-endian**
(network byte order). Full `ri` in `docs/ri-Array-pack.txt` and `docs/ri-String-unpack.txt`.

## The two calls you need

```ruby
# integer -> 4 raw bytes, big-endian
prefix = [payload.bytesize].pack("N")     # e.g. 300 -> "\x00\x00\x01\x2C"

# 4 raw bytes -> integer
len = header.unpack1("N")                 # "\x00\x00\x01\x2C" -> 300
```

- `pack("N")` always produces **exactly 4 bytes**, regardless of the number's size (up to 2**32-1).
- `unpack1("N")` reads the first `N` and returns a single Integer. (`unpack("N")` returns a
  one-element array — `unpack1` is the convenience.)
- Directives: `"N"` = 32-bit unsigned big-endian, `"n"` = 16-bit unsigned big-endian. Use `"N"`.

## Why big-endian?
"Network byte order" is big-endian by convention, so any peer — in any language — agrees on how to
read the length. It's a shared contract, not a Ruby detail.

## What this is and isn't
This gives you the *encoding* of a length value. Deciding to put a length in front of each message,
reading it back, and using it to carve whole messages out of the byte stream is the framing logic —
that part is yours to write. `pack`/`unpack` is just the byte-level primitive underneath it.

## Measuring length correctly
Use **`bytesize`**, not `length`, for the prefix — `length` counts characters, `bytesize` counts
bytes, and they differ for multibyte strings. The wire cares about bytes.
