const std = @import("std");

pub fn main() void {
    var out: [32]u8 = undefined;
    hash(&out, "a message");

    std.debug.print("{}", .{std.fmt.fmtSliceHexLower(&out)});
}

//Implemented following https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.180-4.pdf standard
fn hash(out: *[32]u8, message: []const u8) void {
    //message lenght * 8 bits -> usize type its needed cast later
    var messageSize = message[0..].len * 8;
    var buffer: [64]u8 = undefined;
    var blocks: [64]u32 = undefined;

    // copy message[0..] to avoid end sentinel when pass only message
    @memcpy(buffer[0..message.len], message[0..]);
    buffer[message.len] = 0b10000000;
    @memset(buffer[message.len + 1 ..], 0);
    //i'm assuming here that i can store the size in the las byte of the array
    buffer[buffer.len - 1] = @intCast(messageSize);

    // std.debug.print("Align of buffer: {}\n", .{@alignOf(@TypeOf(blocks))});

    //Parse u8 array to an u32 array
    var idx: usize = 0;
    var idxBuff: usize = 0;
    while (idx < 16) : (idx += 1) {
        blocks[idx] = @as(u32, buffer[idxBuff]) << 24 | @as(u24, buffer[idxBuff + 1]) << 16 | @as(u16, buffer[idxBuff + 2]) << 8 | buffer[idxBuff + 3];
        idxBuff += 4;
    }

    //These words were obtained by taking the first thirty-two bits of the fractional parts of the square roots of the first eight prime numbers
    var H = [8]u32{ 0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19 };

    const K = [64]u32{
        0x428A2F98, 0x71374491, 0xB5C0FBCF, 0xE9B5DBA5, 0x3956C25B, 0x59F111F1, 0x923F82A4, 0xAB1C5ED5,
        0xD807AA98, 0x12835B01, 0x243185BE, 0x550C7DC3, 0x72BE5D74, 0x80DEB1FE, 0x9BDC06A7, 0xC19BF174,
        0xE49B69C1, 0xEFBE4786, 0x0FC19DC6, 0x240CA1CC, 0x2DE92C6F, 0x4A7484AA, 0x5CB0A9DC, 0x76F988DA,
        0x983E5152, 0xA831C66D, 0xB00327C8, 0xBF597FC7, 0xC6E00BF3, 0xD5A79147, 0x06CA6351, 0x14292967,
        0x27B70A85, 0x2E1B2138, 0x4D2C6DFC, 0x53380D13, 0x650A7354, 0x766A0ABB, 0x81C2C92E, 0x92722C85,
        0xA2BFE8A1, 0xA81A664B, 0xC24B8B70, 0xC76C51A3, 0xD192E819, 0xD6990624, 0xF40E3585, 0x106AA070,
        0x19A4C116, 0x1E376C08, 0x2748774C, 0x34B0BCB5, 0x391C0CB3, 0x4ED8AA4A, 0x5B9CCA4F, 0x682E6FF3,
        0x748F82EE, 0x78A5636F, 0x84C87814, 0x8CC70208, 0x90BEFFFA, 0xA4506CEB, 0xBEF9A3F7, 0xC67178F2,
    };
    // var W: [64]u32 = undefined;

    var i: usize = 16;
    while (i < 64) : (i += 1) {
        //+% wraparound addition: if overflows exceeding the max value of u32 it will start from the min valu and viceversa
        blocks[i] = sigma1(blocks[i - 2]) +% blocks[i - 7] +% sigma0(blocks[i - 15]) +% blocks[i - 16];
    }

    //Next step
    var a = H[0];
    var b = H[1];
    var c = H[2];
    var d = H[3];
    var e = H[4];
    var f = H[5];
    var g = H[6];
    var h = H[7];

    for (0..64) |ix| {
        var tOne = h +% capitalSigma1(e) +% ch(e, f, g) +% K[ix] +% blocks[ix];
        var tTwo = capitalSigma0(a) +% maj(a, b, c);
        h = g;
        g = f;
        f = e;
        e = d +% tOne;
        d = c;
        c = b;
        b = a;
        a = tOne +% tTwo;
    }

    //Update H array adding with wraparound sign
    H[0] +%= a;
    H[1] +%= b;
    H[2] +%= c;
    H[3] +%= d;
    H[4] +%= e;
    H[5] +%= f;
    H[6] +%= g;
    H[7] +%= h;

    std.debug.print("\n", .{});
    for (H, 0..) |s, j| {
        std.mem.writeIntBig(u32, out[4 * j ..][0..4], s);
    }
}

fn sigma0(value: u32) u32 {
    return rotateRight(value, 7) ^ rotateRight(value, 18) ^ (value >> 3);
}

fn sigma1(value: u32) u32 {
    return rotateRight(value, 17) ^ rotateRight(value, 19) ^ (value >> 10);
}

fn capitalSigma0(value: u32) u32 {
    return rotateRight(value, 2) ^ rotateRight(value, 13) ^ rotateRight(value, 22);
}

fn capitalSigma1(value: u32) u32 {
    return rotateRight(value, 6) ^ rotateRight(value, 11) ^ rotateRight(value, 25);
}

fn ch(x: u32, y: u32, z: u32) u32 {
    return (x & y) ^ (~x & z);
}

fn maj(x: u32, y: u32, z: u32) u32 {
    return (x & y) ^ (x & z) ^ (y & z);
}

fn rotateRight(out: u32, n: u8) u32 {
    //Shift right N so we move the bits seven positions to the right, then shift left the less significant bits 32 - N. And then a bitwise or is applied
    return std.math.rotr(u32, out, n);
}
