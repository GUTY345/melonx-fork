using System;
using System.Runtime.InteropServices;
using System.Runtime.Versioning;

namespace Ryujinx.Common.SystemInfo
{
    [SupportedOSPlatform("macos")]
    [SupportedOSPlatform("ios")]
    public static partial class AppleSystemMemory
    {
        private const string SystemLibraryName = "libSystem.dylib";

        [LibraryImport(SystemLibraryName, SetLastError = true)]
        private static partial int sysctlbyname([MarshalAs(UnmanagedType.LPStr)] string name, IntPtr oldValue, ref ulong oldSize, IntPtr newValue, ulong newValueSize);

        private static int SysctlByName(string name, IntPtr oldValue, ref ulong oldSize)
        {
            if (sysctlbyname(name, oldValue, ref oldSize, IntPtr.Zero, 0) == -1)
            {
                return Marshal.GetLastWin32Error();
            }

            return 0;
        }

        public static unsafe ulong GetPhysicalMemory()
        {
            ulong totalRAM = 0;
            ulong size = sizeof(ulong);

            int result = SysctlByName("hw.memsize", (IntPtr)(&totalRAM), ref size);

            return result == 0 ? totalRAM : 0;
        }

        public static ulong GetAvailableMemory()
        {
            var port = mach_host_self();

            uint pageSize = 0;
            var result = host_page_size(port, ref pageSize);

            if (result != 0)
            {
                return 0;
            }

            const int Flavor = 4; // HOST_VM_INFO64
            uint count = (uint)(Marshal.SizeOf<VMStatistics64>() / sizeof(int));
            VMStatistics64 stats = new();
            result = host_statistics64(port, Flavor, ref stats, ref count);

            if (result != 0)
            {
                return 0;
            }

            return (ulong)(stats.FreeCount + stats.InactiveCount) * pageSize;
        }

        [LibraryImport(SystemLibraryName, SetLastError = true)]
        private static partial uint mach_host_self();

        [LibraryImport(SystemLibraryName, SetLastError = true)]
        private static partial int host_page_size(uint host, ref uint out_page_size);

        [StructLayout(LayoutKind.Sequential, Pack = 8)]
        private struct VMStatistics64
        {
            public uint FreeCount;
            public uint ActiveCount;
            public uint InactiveCount;
            public uint WireCount;
            public ulong ZeroFillCount;
            public ulong Reactivations;
            public ulong Pageins;
            public ulong Pageouts;
            public ulong Faults;
            public ulong CowFaults;
            public ulong Lookups;
            public ulong Hits;
            public ulong Purges;
            public uint PurgeableCount;
            public uint SpeculativeCount;
            public ulong Decompressions;
            public ulong Compressions;
            public ulong Swapins;
            public ulong Swapouts;
            public uint CompressorPageCount;
            public uint ThrottledCount;
            public uint ExternalPageCount;
            public uint InternalPageCount;
            public ulong TotalUncompressedPagesInCompressor;
        }

        [LibraryImport(SystemLibraryName, SetLastError = true)]
        private static partial int host_statistics64(uint hostPriv, int hostFlavor, ref VMStatistics64 hostInfo64Out, ref uint hostInfo64OutCnt);
    }
}
