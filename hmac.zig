const std = @import("std");
const HmacSha256 = std.crypto.auth.hmac.sha2.HmacSha256;
const Sha256 = std.crypto.hash.sha2.Sha256;

pub fn main() void {
    var hs: [32]u8 = undefined;
    hmacSha256(hs[0..], "key", "message");
    std.debug.print("Custom hash message with secret: {}", .{std.fmt.fmtSliceHexLower(&hs)});
}

//Following https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.198-1.pdf
//MAC(text)t = HMAC(K, text)t = H((K0 ¯ opad )|| H((K0 ¯ ipad) || text))t
fn hmacSha256(out: *[32]u8, key: []const u8, text: []const u8) void {
    var fmKey: [64]u8 = undefined;
    //Copy key to fmKey assuming is lower or equals than 64 bytes
    @memcpy(fmKey[0..key.len], key);
    @memset(fmKey[key.len..64], 0);

    var sha2 = Sha256.init(.{});
    var ipad: [64]u8 = undefined;
    var opad: [64]u8 = undefined;

    //XOR every byte of K with fixed hex 0x5c
    for (fmKey, 0..) |f, i| {
        opad[i] = f ^ 0x5c;
    }

    //XOR every byte of K with fixed hex 0x36
    for (fmKey, 0..) |f, i| {
        ipad[i] = f ^ 0x36;
    }

    //Update ipad and text to hash
    sha2.update(&ipad);
    sha2.update(text);

    var result: [32]u8 = undefined;
    sha2.final(&result);

    sha2 = Sha256.init(.{});

    sha2.update(&opad);
    sha2.update(&result);
    sha2.final(out);
}

test "expect hmach hash result equals to digest expected" {
    //Given
    var hs: [32]u8 = undefined;
    hmacSha256(hs[0..], "key", "message");

    //Then
    var hexHs = std.fmt.bytesToHex(&hs, std.fmt.Case.lower);

    try std.testing.expectEqualStrings("6e9ef29b75fffc5b7abae527d58fdadb2fe42e7219011976917343065f58ed4a", &hexHs);
}
