using System;
using System.IO;
using System.Security.Cryptography;

// Standard ZIP directory fields and CRC-32, per PKWARE APPNOTE 6.3.10:
// https://pkware.cachefly.net/webdocs/casestudies/APPNOTE.TXT
// .NET Framework's ZipArchive does not check CRCs while reading entry data.
namespace LmsUnpacker {
    public static class ZipIntegrity {
        private static readonly uint[] Table = CreateTable();
        private static uint[] CreateTable() {
            uint[] table = new uint[256];
            for (uint i = 0; i < 256; i++) {
                uint value = i;
                for (int bit = 0; bit < 8; bit++)
                    value = (value & 1) != 0 ? 0xEDB88320U ^ (value >> 1) : value >> 1;
                table[i] = value;
            }
            return table;
        }
        private static byte[] ReadExactly(BinaryReader reader, int count) {
            byte[] bytes = reader.ReadBytes(count);
            if (bytes.Length != count) throw new InvalidDataException("ZIP metadata is truncated.");
            return bytes;
        }
        public static uint[] ReadChecksums(string path, int maxEntries) {
            using (FileStream stream = File.OpenRead(path))
            using (BinaryReader reader = new BinaryReader(stream)) {
                int tailLength = (int)Math.Min(stream.Length, 65557);
                stream.Position = stream.Length - tailLength;
                byte[] tail = ReadExactly(reader, tailLength);
                int end = -1;
                for (int i = tail.Length - 22; i >= 0; i--) {
                    if (BitConverter.ToUInt32(tail, i) == 0x06054b50 &&
                        i + 22 + BitConverter.ToUInt16(tail, i + 20) == tail.Length) { end = i; break; }
                }
                if (end < 0) throw new InvalidDataException("ZIP end record is missing or invalid.");
                if (BitConverter.ToUInt16(tail, end + 4) != 0 || BitConverter.ToUInt16(tail, end + 6) != 0)
                    throw new InvalidDataException("Split ZIP archives are not supported.");
                ulong entries = BitConverter.ToUInt16(tail, end + 10);
                ulong size = BitConverter.ToUInt32(tail, end + 12);
                ulong offset = BitConverter.ToUInt32(tail, end + 16);
                if (entries == 65535 || size == uint.MaxValue || offset == uint.MaxValue) {
                    long locator = stream.Length - tailLength + end - 20;
                    if (locator < 0) throw new InvalidDataException("Missing ZIP64 locator.");
                    stream.Position = locator;
                    if (reader.ReadUInt32() != 0x07064b50 || reader.ReadUInt32() != 0)
                        throw new InvalidDataException("Invalid or split ZIP64 archive.");
                    ulong zip64 = reader.ReadUInt64();
                    if (reader.ReadUInt32() != 1 || zip64 > (ulong)Math.Max(0, stream.Length - 56))
                        throw new InvalidDataException("Invalid ZIP64 offset.");
                    stream.Position = (long)zip64;
                    byte[] record = ReadExactly(reader, 56);
                    if (BitConverter.ToUInt32(record, 0) != 0x06064b50 ||
                        BitConverter.ToUInt32(record, 16) != 0 || BitConverter.ToUInt32(record, 20) != 0)
                        throw new InvalidDataException("Invalid ZIP64 directory.");
                    entries = BitConverter.ToUInt64(record, 32);
                    size = BitConverter.ToUInt64(record, 40);
                    offset = BitConverter.ToUInt64(record, 48);
                }
                if (entries > (ulong)maxEntries) throw new InvalidDataException("ZIP exceeds the entry count limit.");
                if (offset > (ulong)stream.Length || size > (ulong)stream.Length - offset)
                    throw new InvalidDataException("ZIP directory is out of bounds.");
                uint[] checksums = new uint[(int)entries];
                stream.Position = (long)offset;
                long directoryEnd = (long)(offset + size);
                for (int i = 0; i < checksums.Length; i++) {
                    byte[] header = ReadExactly(reader, 46);
                    if (BitConverter.ToUInt32(header, 0) != 0x02014b50)
                        throw new InvalidDataException("Invalid ZIP directory entry.");
                    if ((BitConverter.ToUInt16(header, 8) & 1) != 0)
                        throw new InvalidDataException("Password-protected ZIPs are not supported.");
                    ushort method = BitConverter.ToUInt16(header, 10);
                    if (method != 0 && method != 8)
                        throw new InvalidDataException("Only Stored and Deflate ZIP compression are supported.");
                    checksums[i] = BitConverter.ToUInt32(header, 16);
                    int extra = BitConverter.ToUInt16(header, 28) + BitConverter.ToUInt16(header, 30) + BitConverter.ToUInt16(header, 32);
                    if (stream.Position + extra > directoryEnd) throw new InvalidDataException("ZIP directory entry is out of bounds.");
                    stream.Position += extra;
                }
                return checksums;
            }
        }
        public static string CopyChecked(Stream input, Stream output, long expectedLength, uint expectedCrc) {
            byte[] buffer = new byte[81920];
            long total = 0;
            uint crc = uint.MaxValue;
            using (SHA256 sha = SHA256.Create()) {
                int read;
                while ((read = input.Read(buffer, 0, buffer.Length)) > 0) {
                    total += read;
                    if (total > expectedLength) throw new InvalidDataException("Expanded entry exceeds its declared size.");
                    for (int i = 0; i < read; i++) crc = Table[(crc ^ buffer[i]) & 255] ^ (crc >> 8);
                    sha.TransformBlock(buffer, 0, read, buffer, 0);
                    if (output != null) output.Write(buffer, 0, read);
                }
                if (total != expectedLength || (crc ^ uint.MaxValue) != expectedCrc)
                    throw new InvalidDataException("ZIP integrity check failed (size or CRC mismatch).");
                sha.TransformFinalBlock(buffer, 0, 0);
                return BitConverter.ToString(sha.Hash).Replace("-", "");
            }
        }
    }
}
