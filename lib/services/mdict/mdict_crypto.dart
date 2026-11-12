import 'dart:typed_data';

/// Pure Dart RIPEMD-128 and MDict fast decryption implementations.
/// MDict v2.0 with Encrypted="2" encrypts the key block info using
/// a key derived from RIPEMD-128(checksum + \x95\x36\x00\x00).
class MDictCrypto {
  /// Compute 128-bit RIPEMD hash of [data].
  static Uint8List ripemd128(Uint8List data) {
    const k0 = 0x00000000;
    const k1 = 0x5a827999;
    const k2 = 0x6ed9eba1;
    const k3 = 0x8f1bbcdc;

    const kp0 = 0x50a28be6;
    const kp1 = 0x5c4dd124;
    const kp2 = 0x6d703ef3;
    const kp3 = 0x00000000;

    int f0(int x, int y, int z) => (x ^ y ^ z) & 0xffffffff;
    int f1(int x, int y, int z) => ((x & y) | (~x & z)) & 0xffffffff;
    int f2(int x, int y, int z) => ((x | ~y) ^ z) & 0xffffffff;
    int f3(int x, int y, int z) => ((x & z) | (y & ~z)) & 0xffffffff;

    int rol(int x, int n) => (((x << n) | (x >> (32 - n)))) & 0xffffffff;

    final length = data.length;
    final paddedList = <int>[...data, 0x80];
    while (paddedList.length % 64 != 56) {
      paddedList.add(0);
    }

    final bitLen = length * 8;
    for (int i = 0; i < 8; i++) {
      paddedList.add((bitLen >> (i * 8)) & 0xff);
    }

    final padded = Uint8List.fromList(paddedList);

    int h0 = 0x67452301;
    int h1 = 0xefcdab89;
    int h2 = 0x98badcfe;
    int h3 = 0x10325476;

    const r = [
      0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15,
      7, 4, 13, 1, 10, 6, 15, 3, 12, 0, 9, 5, 2, 14, 11, 8,
      3, 10, 14, 4, 9, 15, 8, 1, 2, 7, 0, 6, 13, 11, 5, 12,
      1, 9, 11, 10, 0, 8, 12, 4, 13, 3, 7, 15, 14, 5, 6, 2,
    ];
    const rp = [
      5, 14, 7, 0, 9, 2, 11, 4, 13, 6, 15, 8, 1, 10, 3, 12,
      6, 11, 3, 7, 0, 13, 5, 10, 14, 15, 8, 12, 4, 9, 1, 2,
      15, 5, 1, 3, 7, 14, 6, 9, 11, 8, 12, 2, 10, 0, 4, 13,
      8, 6, 4, 1, 3, 11, 15, 0, 5, 12, 2, 13, 9, 7, 10, 14,
    ];
    const s = [
      11, 14, 15, 12, 5, 8, 7, 9, 11, 13, 14, 15, 6, 7, 9, 8,
      7, 6, 8, 13, 11, 9, 7, 15, 7, 12, 15, 9, 11, 7, 13, 12,
      11, 13, 6, 7, 14, 9, 13, 15, 14, 8, 13, 6, 5, 12, 7, 5,
      11, 12, 14, 15, 14, 15, 9, 8, 9, 14, 5, 6, 8, 6, 5, 12,
    ];
    const sp = [
      8, 9, 9, 11, 13, 15, 15, 5, 7, 7, 8, 11, 14, 14, 12, 6,
      9, 13, 15, 7, 12, 8, 9, 11, 7, 7, 12, 7, 6, 15, 13, 11,
      9, 7, 15, 11, 8, 6, 6, 14, 12, 13, 5, 14, 13, 13, 7, 5,
      15, 5, 8, 11, 14, 14, 6, 14, 6, 9, 12, 9, 12, 5, 15, 8,
    ];

    final byteData = ByteData.sublistView(padded);

    for (int offset = 0; offset < padded.length; offset += 64) {
      final x = List<int>.generate(16, (i) => byteData.getUint32(offset + i * 4, Endian.little));

      int a = h0;
      int b = h1;
      int c = h2;
      int d = h3;

      int ap = h0;
      int bp = h1;
      int cp = h2;
      int dp = h3;

      for (int j = 0; j < 16; j++) {
        int t = (a + f0(b, c, d) + x[r[j]] + k0) & 0xffffffff;
        a = d;
        d = c;
        c = b;
        b = (rol(t, s[j])) & 0xffffffff;

        int tp = (ap + f3(bp, cp, dp) + x[rp[j]] + kp0) & 0xffffffff;
        ap = dp;
        dp = cp;
        cp = bp;
        bp = (rol(tp, sp[j])) & 0xffffffff;
      }

      for (int j = 16; j < 32; j++) {
        int t = (a + f1(b, c, d) + x[r[j]] + k1) & 0xffffffff;
        a = d;
        d = c;
        c = b;
        b = (rol(t, s[j])) & 0xffffffff;

        int tp = (ap + f2(bp, cp, dp) + x[rp[j]] + kp1) & 0xffffffff;
        ap = dp;
        dp = cp;
        cp = bp;
        bp = (rol(tp, sp[j])) & 0xffffffff;
      }

      for (int j = 32; j < 48; j++) {
        int t = (a + f2(b, c, d) + x[r[j]] + k2) & 0xffffffff;
        a = d;
        d = c;
        c = b;
        b = (rol(t, s[j])) & 0xffffffff;

        int tp = (ap + f1(bp, cp, dp) + x[rp[j]] + kp2) & 0xffffffff;
        ap = dp;
        dp = cp;
        cp = bp;
        bp = (rol(tp, sp[j])) & 0xffffffff;
      }

      for (int j = 48; j < 64; j++) {
        int t = (a + f3(b, c, d) + x[r[j]] + k3) & 0xffffffff;
        a = d;
        d = c;
        c = b;
        b = (rol(t, s[j])) & 0xffffffff;

        int tp = (ap + f0(bp, cp, dp) + x[rp[j]] + kp3) & 0xffffffff;
        ap = dp;
        dp = cp;
        cp = bp;
        bp = (rol(tp, sp[j])) & 0xffffffff;
      }

      int t = (h1 + c + dp) & 0xffffffff;
      h1 = (h2 + d + ap) & 0xffffffff;
      h2 = (h3 + a + bp) & 0xffffffff;
      h3 = (h0 + b + cp) & 0xffffffff;
      h0 = t;
    }

    final out = ByteData(16);
    out.setUint32(0, h0, Endian.little);
    out.setUint32(4, h1, Endian.little);
    out.setUint32(8, h2, Endian.little);
    out.setUint32(12, h3, Endian.little);
    return out.buffer.asUint8List();
  }

  /// MDict fast decrypt algorithm using bit swizzling and XOR key loop.
  static Uint8List fastDecrypt(Uint8List data, Uint8List key) {
    final b = Uint8List.fromList(data);
    int prev = 0x36;
    for (int i = 0; i < b.length; i++) {
      int t = ((b[i] >> 4) | ((b[i] << 4) & 0xff)) & 0xff;
      t = (t ^ prev ^ (i & 0xff) ^ key[i % key.length]) & 0xff;
      prev = b[i];
      b[i] = t;
    }
    return b;
  }
}
