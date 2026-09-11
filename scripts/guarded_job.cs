// Task-local Windows job. Closing the owning runner also closes its child tree.
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;

public sealed class AlpineValidationJob : IDisposable {
    [StructLayout(LayoutKind.Sequential)] struct BasicLimits {
        public long ProcessTime, JobTime;
        public uint Flags;
        public UIntPtr MinWorkingSet, MaxWorkingSet;
        public uint ActiveProcesses;
        public UIntPtr Affinity;
        public uint Priority, Scheduling;
    }
    [StructLayout(LayoutKind.Sequential)] struct IoCounters {
        public ulong ReadOperations, WriteOperations, OtherOperations;
        public ulong ReadBytes, WriteBytes, OtherBytes;
    }
    [StructLayout(LayoutKind.Sequential)] struct ExtendedLimits {
        public BasicLimits Basic;
        public IoCounters Io;
        public UIntPtr LimitA, LimitB, LimitC, LimitD;
    }
    [DllImport("kernel32.dll", SetLastError=true)] static extern IntPtr CreateJobObject(IntPtr attributes, string name);
    [DllImport("kernel32.dll", SetLastError=true)] static extern bool SetInformationJobObject(IntPtr job, int kind, IntPtr info, uint size);
    [DllImport("kernel32.dll", SetLastError=true)] static extern bool AssignProcessToJobObject(IntPtr job, IntPtr process);
    [DllImport("kernel32.dll", SetLastError=true)] static extern bool TerminateJobObject(IntPtr job, uint code);
    [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr handle);
    IntPtr handle;
    public AlpineValidationJob() {
        handle = CreateJobObject(IntPtr.Zero, null);
        if (handle == IntPtr.Zero) throw new Win32Exception();
        try {
            Set(9, new ExtendedLimits { Basic = new BasicLimits { Flags = 0x2000 } });
        } catch { Dispose(); throw; }
    }
    void Set<T>(int kind, T value) where T : struct {
        int size = Marshal.SizeOf<T>();
        IntPtr buffer = Marshal.AllocHGlobal(size);
        try {
            Marshal.StructureToPtr(value, buffer, false);
            if (!SetInformationJobObject(handle, kind, buffer, (uint)size)) throw new Win32Exception();
        } finally { Marshal.FreeHGlobal(buffer); }
    }
    public void Assign(IntPtr process) {
        if (!AssignProcessToJobObject(handle, process)) throw new Win32Exception();
    }
    public void Stop() { if (handle != IntPtr.Zero) TerminateJobObject(handle, 1); }
    public void Dispose() { if (handle != IntPtr.Zero) { CloseHandle(handle); handle = IntPtr.Zero; } }
}
