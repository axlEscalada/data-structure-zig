const std = @import("std");
const builtin = @import("builtin");
const mem = std.mem;
const math = std.math;

const v4u32 = @Vector(4, u32);

pub fn main() void {
    var sha = Sha256.init(.{});
    var out: [32]u8 = undefined;
    // sha.update("a message");
    sha.update("a message of a significant length that maybe broke my hash algorithm");
    std.debug.print("final\n", .{});
    sha.final(&out);
    for (out) |value| {
        std.debug.print("{x}", .{value});
    }
}

const RoundParam256 = struct {
    a: usize,
    b: usize,
    c: usize,
    d: usize,
    e: usize,
    f: usize,
    g: usize,
    h: usize,
    i: usize,
};

const Sha2Params32 = struct {
    iv0: u32,
    iv1: u32,
    iv2: u32,
    iv3: u32,
    iv4: u32,
    iv5: u32,
    iv6: u32,
    iv7: u32,
    digest_bits: usize,
};

pub const Sha256 = Sha2x32(Sha256Params);

const Sha256Params = Sha2Params32{
    .iv0 = 0x6A09E667,
    .iv1 = 0xBB67AE85,
    .iv2 = 0x3C6EF372,
    .iv3 = 0xA54FF53A,
    .iv4 = 0x510E527F,
    .iv5 = 0x9B05688C,
    .iv6 = 0x1F83D9AB,
    .iv7 = 0x5BE0CD19,
    .digest_bits = 256,
};

fn roundParam256(a: usize, b: usize, c: usize, d: usize, e: usize, f: usize, g: usize, h: usize, i: usize) RoundParam256 {
    return RoundParam256{
        .a = a,
        .b = b,
        .c = c,
        .d = d,
        .e = e,
        .f = f,
        .g = g,
        .h = h,
        .i = i,
    };
}

fn Sha2x32(comptime params: Sha2Params32) type {
    return struct {
        const Self = @This();
        pub const block_length = 64;
        pub const digest_length = params.digest_bits / 8;
        pub const Options = struct {};

        s: [8]u32 align(16),
        // Streaming Cache
        buf: [64]u8 = undefined,
        buf_len: u8 = 0,
        total_len: u64 = 0,

        pub fn init(options: Options) Self {
            _ = options;
            return Self{
                .s = [_]u32{
                    params.iv0,
                    params.iv1,
                    params.iv2,
                    params.iv3,
                    params.iv4,
                    params.iv5,
                    params.iv6,
                    params.iv7,
                },
            };
        }

        pub fn hash(b: []const u8, out: *[digest_length]u8, options: Options) void {
            var d = Self.init(options);
            d.update(b);
            d.final(out);
        }

        pub fn update(d: *Self, b: []const u8) void {
            var off: usize = 0;

            // Partial buffer exists from previous update. Copy into buffer then hash.
            if (d.buf_len != 0 and d.buf_len + b.len >= 64) {
                off += 64 - d.buf_len;
                @memcpy(d.buf[d.buf_len..][0..off], b[0..off]);

                d.round(&d.buf);
                d.buf_len = 0;
            }

            // Full middle blocks.
            while (off + 64 <= b.len) : (off += 64) {
                d.round(b[off..][0..64]);
            }

            // Copy any remainder for next pass.
            const b_slice = b[off..];
            @memcpy(d.buf[d.buf_len..][0..b_slice.len], b_slice);
            d.buf_len += @as(u8, @intCast(b[off..].len));

            d.total_len += b.len;
        }

        pub fn peek(d: Self) [digest_length]u8 {
            var copy = d;
            return copy.finalResult();
        }

        pub fn final(d: *Self, out: *[digest_length]u8) void {
            // The buffer here will never be completely full.
            @memset(d.buf[d.buf_len..], 0);

            // Append padding bits.
            d.buf[d.buf_len] = 0x80;
            d.buf_len += 1;

            // > 448 mod 512 so need to add an extra round to wrap around.
            if (64 - d.buf_len < 8) {
                d.round(&d.buf);
                @memset(d.buf[0..], 0);
            }

            // Append message length.
            var i: usize = 1;
            var len = d.total_len >> 5;
            d.buf[63] = @as(u8, @intCast(d.total_len & 0x1f)) << 3;
            while (i < 8) : (i += 1) {
                d.buf[63 - i] = @as(u8, @intCast(len & 0xff));
                len >>= 8;
            }
            // for (&d.buf) |*value| {
            //     std.debug.print("{b}\n", .{value.*});
            // }

            d.round(&d.buf);
            for (d.s) |val| {
                std.debug.print("{x}\n", .{val});
            }

            // May truncate for possible 224 output
            const rr = d.s[0 .. params.digest_bits / 32];

            for (rr, 0..) |s, j| {
                mem.writeIntBig(u32, out[4 * j ..][0..4], s);
            }
        }

        pub fn finalResult(d: *Self) [digest_length]u8 {
            var result: [digest_length]u8 = undefined;
            d.final(&result);
            return result;
        }

        const W = [64]u32{
            0x428A2F98, 0x71374491, 0xB5C0FBCF, 0xE9B5DBA5, 0x3956C25B, 0x59F111F1, 0x923F82A4, 0xAB1C5ED5,
            0xD807AA98, 0x12835B01, 0x243185BE, 0x550C7DC3, 0x72BE5D74, 0x80DEB1FE, 0x9BDC06A7, 0xC19BF174,
            0xE49B69C1, 0xEFBE4786, 0x0FC19DC6, 0x240CA1CC, 0x2DE92C6F, 0x4A7484AA, 0x5CB0A9DC, 0x76F988DA,
            0x983E5152, 0xA831C66D, 0xB00327C8, 0xBF597FC7, 0xC6E00BF3, 0xD5A79147, 0x06CA6351, 0x14292967,
            0x27B70A85, 0x2E1B2138, 0x4D2C6DFC, 0x53380D13, 0x650A7354, 0x766A0ABB, 0x81C2C92E, 0x92722C85,
            0xA2BFE8A1, 0xA81A664B, 0xC24B8B70, 0xC76C51A3, 0xD192E819, 0xD6990624, 0xF40E3585, 0x106AA070,
            0x19A4C116, 0x1E376C08, 0x2748774C, 0x34B0BCB5, 0x391C0CB3, 0x4ED8AA4A, 0x5B9CCA4F, 0x682E6FF3,
            0x748F82EE, 0x78A5636F, 0x84C87814, 0x8CC70208, 0x90BEFFFA, 0xA4506CEB, 0xBEF9A3F7, 0xC67178F2,
        };

        fn round(d: *Self, b: *const [64]u8) void {
            var s: [64]u32 align(16) = undefined;
            for (@as(*align(1) const [16]u32, @ptrCast(b)), 0..) |*elem, i| {
                s[i] = mem.readIntBig(u32, mem.asBytes(elem));
                std.debug.print("{b}\n", .{s[i]});
            }

            var i: usize = 16;
            while (i < 64) : (i += 1) {
                // std.debug.print("1: {b}, 2: {b}\n", .{ s[i - 15], s[i - 2] });
                var r = (math.rotr(u32, s[i - 15], @as(u32, 7)) ^ math.rotr(u32, s[i - 15], @as(u32, 18)) ^ (s[i - 15] >> 3));
                var t = (math.rotr(u32, s[i - 2], @as(u32, 17)) ^ math.rotr(u32, s[i - 2], @as(u32, 19)) ^ (s[i - 2] >> 10));

                // std.debug.print("r {x} t {x}\n", .{ r, t });
                s[i] = s[i - 16] +% s[i - 7] +% r +% t;
                // std.debug.print("s {x}\n", .{s[i]});
            }

            var v: [8]u32 = [_]u32{
                d.s[0],
                d.s[1],
                d.s[2],
                d.s[3],
                d.s[4],
                d.s[5],
                d.s[6],
                d.s[7],
            };

            const round0 = comptime [_]RoundParam256{
                roundParam256(0, 1, 2, 3, 4, 5, 6, 7, 0),
                roundParam256(7, 0, 1, 2, 3, 4, 5, 6, 1),
                roundParam256(6, 7, 0, 1, 2, 3, 4, 5, 2),
                roundParam256(5, 6, 7, 0, 1, 2, 3, 4, 3),
                roundParam256(4, 5, 6, 7, 0, 1, 2, 3, 4),
                roundParam256(3, 4, 5, 6, 7, 0, 1, 2, 5),
                roundParam256(2, 3, 4, 5, 6, 7, 0, 1, 6),
                roundParam256(1, 2, 3, 4, 5, 6, 7, 0, 7),
                roundParam256(0, 1, 2, 3, 4, 5, 6, 7, 8),
                roundParam256(7, 0, 1, 2, 3, 4, 5, 6, 9),
                roundParam256(6, 7, 0, 1, 2, 3, 4, 5, 10),
                roundParam256(5, 6, 7, 0, 1, 2, 3, 4, 11),
                roundParam256(4, 5, 6, 7, 0, 1, 2, 3, 12),
                roundParam256(3, 4, 5, 6, 7, 0, 1, 2, 13),
                roundParam256(2, 3, 4, 5, 6, 7, 0, 1, 14),
                roundParam256(1, 2, 3, 4, 5, 6, 7, 0, 15),
                roundParam256(0, 1, 2, 3, 4, 5, 6, 7, 16),
                roundParam256(7, 0, 1, 2, 3, 4, 5, 6, 17),
                roundParam256(6, 7, 0, 1, 2, 3, 4, 5, 18),
                roundParam256(5, 6, 7, 0, 1, 2, 3, 4, 19),
                roundParam256(4, 5, 6, 7, 0, 1, 2, 3, 20),
                roundParam256(3, 4, 5, 6, 7, 0, 1, 2, 21),
                roundParam256(2, 3, 4, 5, 6, 7, 0, 1, 22),
                roundParam256(1, 2, 3, 4, 5, 6, 7, 0, 23),
                roundParam256(0, 1, 2, 3, 4, 5, 6, 7, 24),
                roundParam256(7, 0, 1, 2, 3, 4, 5, 6, 25),
                roundParam256(6, 7, 0, 1, 2, 3, 4, 5, 26),
                roundParam256(5, 6, 7, 0, 1, 2, 3, 4, 27),
                roundParam256(4, 5, 6, 7, 0, 1, 2, 3, 28),
                roundParam256(3, 4, 5, 6, 7, 0, 1, 2, 29),
                roundParam256(2, 3, 4, 5, 6, 7, 0, 1, 30),
                roundParam256(1, 2, 3, 4, 5, 6, 7, 0, 31),
                roundParam256(0, 1, 2, 3, 4, 5, 6, 7, 32),
                roundParam256(7, 0, 1, 2, 3, 4, 5, 6, 33),
                roundParam256(6, 7, 0, 1, 2, 3, 4, 5, 34),
                roundParam256(5, 6, 7, 0, 1, 2, 3, 4, 35),
                roundParam256(4, 5, 6, 7, 0, 1, 2, 3, 36),
                roundParam256(3, 4, 5, 6, 7, 0, 1, 2, 37),
                roundParam256(2, 3, 4, 5, 6, 7, 0, 1, 38),
                roundParam256(1, 2, 3, 4, 5, 6, 7, 0, 39),
                roundParam256(0, 1, 2, 3, 4, 5, 6, 7, 40),
                roundParam256(7, 0, 1, 2, 3, 4, 5, 6, 41),
                roundParam256(6, 7, 0, 1, 2, 3, 4, 5, 42),
                roundParam256(5, 6, 7, 0, 1, 2, 3, 4, 43),
                roundParam256(4, 5, 6, 7, 0, 1, 2, 3, 44),
                roundParam256(3, 4, 5, 6, 7, 0, 1, 2, 45),
                roundParam256(2, 3, 4, 5, 6, 7, 0, 1, 46),
                roundParam256(1, 2, 3, 4, 5, 6, 7, 0, 47),
                roundParam256(0, 1, 2, 3, 4, 5, 6, 7, 48),
                roundParam256(7, 0, 1, 2, 3, 4, 5, 6, 49),
                roundParam256(6, 7, 0, 1, 2, 3, 4, 5, 50),
                roundParam256(5, 6, 7, 0, 1, 2, 3, 4, 51),
                roundParam256(4, 5, 6, 7, 0, 1, 2, 3, 52),
                roundParam256(3, 4, 5, 6, 7, 0, 1, 2, 53),
                roundParam256(2, 3, 4, 5, 6, 7, 0, 1, 54),
                roundParam256(1, 2, 3, 4, 5, 6, 7, 0, 55),
                roundParam256(0, 1, 2, 3, 4, 5, 6, 7, 56),
                roundParam256(7, 0, 1, 2, 3, 4, 5, 6, 57),
                roundParam256(6, 7, 0, 1, 2, 3, 4, 5, 58),
                roundParam256(5, 6, 7, 0, 1, 2, 3, 4, 59),
                roundParam256(4, 5, 6, 7, 0, 1, 2, 3, 60),
                roundParam256(3, 4, 5, 6, 7, 0, 1, 2, 61),
                roundParam256(2, 3, 4, 5, 6, 7, 0, 1, 62),
                roundParam256(1, 2, 3, 4, 5, 6, 7, 0, 63),
            };
            for (round0, 0..) |r, l| {
                std.debug.print("a {x} b {x} c {x} d {x} e {x} f {x} g {x} h {x}\n", .{ v[0], v[1], v[2], v[3], v[4], v[5], v[6], v[7] });
                v[r.h] = v[r.h] +% (math.rotr(u32, v[r.e], @as(u32, 6)) ^ math.rotr(u32, v[r.e], @as(u32, 11)) ^ math.rotr(u32, v[r.e], @as(u32, 25))) +% (v[r.g] ^ (v[r.e] & (v[r.f] ^ v[r.g]))) +% W[l] +% s[l];

                v[r.d] = v[r.d] +% v[r.h];

                v[r.h] = v[r.h] +% (math.rotr(u32, v[r.a], @as(u32, 2)) ^ math.rotr(u32, v[r.a], @as(u32, 13)) ^ math.rotr(u32, v[r.a], @as(u32, 22))) +% ((v[r.a] & (v[r.b] | v[r.c])) | (v[r.b] & v[r.c]));
            }

            d.s[0] +%= v[0];
            d.s[1] +%= v[1];
            d.s[2] +%= v[2];
            d.s[3] +%= v[3];
            d.s[4] +%= v[4];
            d.s[5] +%= v[5];
            d.s[6] +%= v[6];
            d.s[7] +%= v[7];
        }

        pub const Error = error{};
        pub const Writer = std.io.Writer(*Self, Error, write);

        fn write(self: *Self, bytes: []const u8) Error!usize {
            self.update(bytes);
            return bytes.len;
        }

        pub fn writer(self: *Self) Writer {
            return .{ .context = self };
        }
    };
}
