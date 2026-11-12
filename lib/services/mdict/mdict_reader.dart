import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'mdict_crypto.dart';
import 'mdict_header.dart';

class KeyBlockMeta {
  final int numEntries;
  final String firstKey;
  final String lastKey;
  final int compSize;
  final int decompSize;
  final int fileOffset;

  const KeyBlockMeta({
    required this.numEntries,
    required this.firstKey,
    required this.lastKey,
    required this.compSize,
    required this.decompSize,
    required this.fileOffset,
  });
}

class RecordBlockMeta {
  final int compSize;
  final int decompSize;
  final int compOffset;
  final int decompAccumOffset;

  const RecordBlockMeta({
    required this.compSize,
    required this.decompSize,
    required this.compOffset,
    required this.decompAccumOffset,
  });
}

class KeyEntry {
  final String key;
  final int recordOffset;
  int recordLength;

  KeyEntry({
    required this.key,
    required this.recordOffset,
    this.recordLength = -1,
  });
}

/// Pure Dart MDict Reader for MDX and MDD v2.0 files.
class MDictReader {
  final String filePath;
  final RandomAccessFile _file;
  final MDictHeader header;
  final bool isMdd;

  final int numKeyBlocks;
  final int numEntries;
  final int totalDecompRecordsSize;
  final List<KeyBlockMeta> keyBlockMetas;
  final List<RecordBlockMeta> recordBlockMetas;

  // Small LRU cache for decompressed key blocks and record blocks
  final Map<int, List<KeyEntry>> _keyBlockCache = {};
  final Map<int, Uint8List> _recordBlockCache = {};
  static const int _maxCacheSize = 16;

  MDictReader._({
    required this.filePath,
    required RandomAccessFile file,
    required this.header,
    required this.isMdd,
    required this.numKeyBlocks,
    required this.numEntries,
    required this.totalDecompRecordsSize,
    required this.keyBlockMetas,
    required this.recordBlockMetas,
  }) : _file = file;

  /// Open an MDX or MDD file and load its sparse index into memory.
  static Future<MDictReader> open(String filePath) async {
    final file = await File(filePath).open(mode: FileMode.read);
    final isMdd = filePath.toLowerCase().endsWith('.mdd');

    // 1. Read header (4 bytes size, UTF-16LE XML, 4 bytes checksum)
    final headerSizeBytes = await file.read(4);
    final headerSize = ByteData.sublistView(headerSizeBytes).getUint32(0, Endian.big);

    final headerBytes = await file.read(headerSize);
    final headerXml = _decodeUtf16Le(headerBytes);
    await file.read(4); // Adler32 checksum
    final header = MDictHeader.fromXml(headerXml);

    // 2. Read key block header (40 bytes for v2.0)
    final kbhBytes = await file.read(40);
    final kbhData = ByteData.sublistView(kbhBytes);
    final numKeyBlocks = kbhData.getUint64(0, Endian.big);
    final numEntries = kbhData.getUint64(8, Endian.big);
    // bytes 16..23: kbiDecompLen
    final kbiCompLen = kbhData.getUint64(24, Endian.big);
    // bytes 32..39: keyBlocksTotalLen
    await file.read(4); // Checksum

    // 3. Read key block info (KBI)
    final kbiComp = await file.read(kbiCompLen);
    Uint8List kbiDecomp;

    // Encrypted == 2 -> decrypt with RIPEMD-128 key derived from kbiComp[4:8] + 0x3695
    if ((header.encrypted & 2) != 0 && kbiComp.length >= 8) {
      final checksumSlice = kbiComp.sublist(4, 8);
      final keySeed = Uint8List.fromList([...checksumSlice, 0x95, 0x36, 0x00, 0x00]);
      final key = MDictCrypto.ripemd128(keySeed);
      final decryptedPayload = MDictCrypto.fastDecrypt(kbiComp.sublist(8), key);
      kbiDecomp = Uint8List.fromList(zlib.decode(decryptedPayload));
    } else {
      kbiDecomp = Uint8List.fromList(zlib.decode(kbiComp.sublist(8)));
    }

    final isUtf16 = isMdd || header.encoding.toUpperCase().contains('UTF-16');

    // Parse KBI into KeyBlockMeta list
    final keyBlockMetas = <KeyBlockMeta>[];
    int currentOffset = 0;
    int keyBlockFileOffset = await file.position();

    final kbiData = ByteData.sublistView(kbiDecomp);
    for (int i = 0; i < numKeyBlocks; i++) {
      final blockEntries = kbiData.getUint64(currentOffset, Endian.big);
      currentOffset += 8;

      // first key
      final firstKeyChars = kbiData.getUint16(currentOffset, Endian.big);
      currentOffset += 2;
      final firstKeyByteLen = isUtf16 ? firstKeyChars * 2 : firstKeyChars;
      final firstKeyBytes = kbiDecomp.sublist(currentOffset, currentOffset + firstKeyByteLen);
      final firstKey = isUtf16 ? _decodeUtf16Le(firstKeyBytes) : utf8.decode(firstKeyBytes, allowMalformed: true);
      currentOffset += firstKeyByteLen + (isUtf16 ? 2 : 1); // skip null term

      // last key
      final lastKeyChars = kbiData.getUint16(currentOffset, Endian.big);
      currentOffset += 2;
      final lastKeyByteLen = isUtf16 ? lastKeyChars * 2 : lastKeyChars;
      final lastKeyBytes = kbiDecomp.sublist(currentOffset, currentOffset + lastKeyByteLen);
      final lastKey = isUtf16 ? _decodeUtf16Le(lastKeyBytes) : utf8.decode(lastKeyBytes, allowMalformed: true);
      currentOffset += lastKeyByteLen + (isUtf16 ? 2 : 1);

      final compSize = kbiData.getUint64(currentOffset, Endian.big);
      currentOffset += 8;
      final decompSize = kbiData.getUint64(currentOffset, Endian.big);
      currentOffset += 8;

      keyBlockMetas.add(KeyBlockMeta(
        numEntries: blockEntries,
        firstKey: firstKey,
        lastKey: lastKey,
        compSize: compSize,
        decompSize: decompSize,
        fileOffset: keyBlockFileOffset,
      ));

      keyBlockFileOffset += compSize;
    }

    // Move file position past all key blocks to record block header
    await file.setPosition(keyBlockFileOffset);

    // 4. Read record block header
    final rbhBytes = await file.read(32);
    final rbhData = ByteData.sublistView(rbhBytes);
    final numRecordBlocks = rbhData.getUint64(0, Endian.big);
    // bytes 8..15: numRecords
    final recordBlockInfoSize = rbhData.getUint64(16, Endian.big);
    // bytes 24..31: recordBlocksTotalSize

    // Read record block info
    final rbiComp = await file.read(recordBlockInfoSize);
    final rbiData = ByteData.sublistView(rbiComp);

    final recordBlockMetas = <RecordBlockMeta>[];
    int rbiOffset = 0;
    int recordFileOffset = await file.position();
    int accumDecomp = 0;

    for (int i = 0; i < numRecordBlocks; i++) {
      final compSize = rbiData.getUint64(rbiOffset, Endian.big);
      rbiOffset += 8;
      final decompSize = rbiData.getUint64(rbiOffset, Endian.big);
      rbiOffset += 8;

      recordBlockMetas.add(RecordBlockMeta(
        compSize: compSize,
        decompSize: decompSize,
        compOffset: recordFileOffset,
        decompAccumOffset: accumDecomp,
      ));

      recordFileOffset += compSize;
      accumDecomp += decompSize;
    }

    return MDictReader._(
      filePath: filePath,
      file: file,
      header: header,
      isMdd: isMdd,
      numKeyBlocks: numKeyBlocks,
      numEntries: numEntries,
      totalDecompRecordsSize: accumDecomp,
      keyBlockMetas: keyBlockMetas,
      recordBlockMetas: recordBlockMetas,
    );
  }

  /// Look up definition HTML for a word in an .mdx file.
  Future<String?> lookup(String word) async {
    final entry = await _findKeyEntry(word);
    if (entry == null) return null;

    final recordData = await _readRecordData(entry.recordOffset, length: entry.recordLength);
    if (recordData == null) return null;

    final textEncoding = header.encoding.isEmpty ? 'UTF-8' : header.encoding;
    String text = _decodeString(recordData, textEncoding);

    // Handle @@@LINK= redirect in MDX
    if (text.startsWith('@@@LINK=')) {
      final target = text.substring(8).trim();
      return lookup(target);
    }
    return text;
  }

  /// Look up raw binary bytes for a resource path in an .mdd file.
  Future<Uint8List?> lookupResource(String rawPath) async {
    String normalized = rawPath.replaceAll('/', '\\');
    if (!normalized.startsWith('\\')) {
      normalized = '\\$normalized';
    }

    final entry = await _findKeyEntry(normalized);
    if (entry == null) return null;

    return _readRecordData(entry.recordOffset, length: entry.recordLength);
  }

  /// Locate KeyEntry matching [query] using binary search on Key Block Info + Key Block.
  Future<KeyEntry?> _findKeyEntry(String query) async {
    final qLower = query.toLowerCase().trim();

    // 1. Binary search Key Block Info
    int low = 0;
    int high = keyBlockMetas.length - 1;
    int targetBlockIdx = -1;

    while (low <= high) {
      final mid = (low + high) >> 1;
      final meta = keyBlockMetas[mid];
      final firstLower = meta.firstKey.toLowerCase();
      final lastLower = meta.lastKey.toLowerCase();

      if (qLower.compareTo(firstLower) < 0) {
        high = mid - 1;
      } else if (qLower.compareTo(lastLower) > 0) {
        low = mid + 1;
      } else {
        targetBlockIdx = mid;
        break;
      }
    }

    if (targetBlockIdx == -1) return null;

    // 2. Load or get cached key entries of this block
    final entries = await _loadKeyBlockEntries(targetBlockIdx);

    // 3. Binary search entries within the block
    low = 0;
    high = entries.length - 1;
    while (low <= high) {
      final mid = (low + high) >> 1;
      final item = entries[mid];
      final cmp = qLower.compareTo(item.key.toLowerCase());

      if (cmp == 0) {
        return item;
      } else if (cmp < 0) {
        high = mid - 1;
      } else {
        low = mid + 1;
      }
    }

    return null;
  }

  Future<List<KeyEntry>> _loadKeyBlockEntries(int blockIdx) async {
    if (_keyBlockCache.containsKey(blockIdx)) {
      return _keyBlockCache[blockIdx]!;
    }

    final meta = keyBlockMetas[blockIdx];
    await _file.setPosition(meta.fileOffset);
    final compBytes = await _file.read(meta.compSize);
    final decompBytes = Uint8List.fromList(zlib.decode(compBytes.sublist(8)));

    final entries = <KeyEntry>[];
    final byteData = ByteData.sublistView(decompBytes);
    final isUtf16 = isMdd || header.encoding.toUpperCase().contains('UTF-16');

    int offset = 0;
    final totalLen = decompBytes.length;

    while (offset < totalLen) {
      if (offset + 8 > totalLen) break;
      final recordOffset = byteData.getUint64(offset, Endian.big);
      offset += 8;

      int keyStart = offset;
      int keyEnd = offset;

      if (isUtf16) {
        while (keyEnd + 1 < totalLen) {
          if (decompBytes[keyEnd] == 0 && decompBytes[keyEnd + 1] == 0) break;
          keyEnd += 2;
        }
      } else {
        while (keyEnd < totalLen && decompBytes[keyEnd] != 0) {
          keyEnd++;
        }
      }

      final keyBytes = decompBytes.sublist(keyStart, keyEnd);
      final key = isUtf16 ? _decodeUtf16Le(keyBytes) : utf8.decode(keyBytes, allowMalformed: true);
      offset = keyEnd + (isUtf16 ? 2 : 1);

      entries.add(KeyEntry(key: key, recordOffset: recordOffset));
    }

    // Populate recordLength for each entry
    for (int i = 0; i < entries.length; i++) {
      if (i + 1 < entries.length) {
        entries[i].recordLength = entries[i + 1].recordOffset - entries[i].recordOffset;
      } else {
        // Last entry in key block: estimate with total or next block
        entries[i].recordLength = -1;
      }
    }

    if (_keyBlockCache.length >= _maxCacheSize) {
      _keyBlockCache.remove(_keyBlockCache.keys.first);
    }
    _keyBlockCache[blockIdx] = entries;

    return entries;
  }

  Future<Uint8List?> _readRecordData(int globalRecordOffset, {int length = -1}) async {
    // 1. Find record block containing globalRecordOffset
    int low = 0;
    int high = recordBlockMetas.length - 1;
    int blockIdx = -1;

    while (low <= high) {
      final mid = (low + high) >> 1;
      final meta = recordBlockMetas[mid];
      final blockStart = meta.decompAccumOffset;
      final blockEnd = blockStart + meta.decompSize;

      if (globalRecordOffset < blockStart) {
        high = mid - 1;
      } else if (globalRecordOffset >= blockEnd) {
        low = mid + 1;
      } else {
        blockIdx = mid;
        break;
      }
    }

    if (blockIdx == -1) return null;

    final blockMeta = recordBlockMetas[blockIdx];
    Uint8List decompBlock;

    if (_recordBlockCache.containsKey(blockIdx)) {
      decompBlock = _recordBlockCache[blockIdx]!;
    } else {
      await _file.setPosition(blockMeta.compOffset);
      final compBytes = await _file.read(blockMeta.compSize);
      decompBlock = Uint8List.fromList(zlib.decode(compBytes.sublist(8)));

      if (_recordBlockCache.length >= _maxCacheSize) {
        _recordBlockCache.remove(_recordBlockCache.keys.first);
      }
      _recordBlockCache[blockIdx] = decompBlock;
    }

    final localOffset = globalRecordOffset - blockMeta.decompAccumOffset;
    if (localOffset >= decompBlock.length) return null;

    if (length > 0 && localOffset + length <= decompBlock.length) {
      return Uint8List.fromList(decompBlock.sublist(localOffset, localOffset + length));
    }

    // If length not bounded or spans block, take till null byte or end
    int end = localOffset;
    while (end < decompBlock.length && decompBlock[end] != 0) {
      end++;
    }
    return Uint8List.fromList(decompBlock.sublist(localOffset, end));
  }

  static String _decodeString(Uint8List bytes, String encoding) {
    try {
      if (encoding.toUpperCase().contains('UTF-16')) {
        return _decodeUtf16Le(bytes);
      }
      return utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      return utf8.decode(bytes, allowMalformed: true);
    }
  }

  static String _decodeUtf16Le(Uint8List bytes) {
    final buffer = StringBuffer();
    for (int i = 0; i + 1 < bytes.length; i += 2) {
      final codeUnit = bytes[i] | (bytes[i + 1] << 8);
      if (codeUnit != 0) {
        buffer.writeCharCode(codeUnit);
      }
    }
    return buffer.toString();
  }

  Future<void> dispose() async {
    _keyBlockCache.clear();
    _recordBlockCache.clear();
    await _file.close();
  }
}
