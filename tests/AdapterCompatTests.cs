using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;

class AdapterCompatTests {
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
    static extern IntPtr LoadLibraryW(string path);
    [DllImport("kernel32.dll", CharSet=CharSet.Ansi)]
    static extern IntPtr GetProcAddress(IntPtr module, string name);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate uint Query(IntPtr info, ref uint size);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate uint TableQuery(IntPtr info, ref uint size, bool sorted);

    static void Check(bool ok, string description) {
        if (!ok) throw new Exception(description);
    }
    static T Function<T>(IntPtr module, string name) {
        IntPtr fn = GetProcAddress(module, name);
        Check(fn != IntPtr.Zero, "Missing export " + name);
        return (T)(object)Marshal.GetDelegateForFunctionPointer(fn, typeof(T));
    }
    static bool Inside(IntPtr ptr, IntPtr start, uint size, int length) {
        long offset = ptr.ToInt64() - start.ToInt64();
        return offset >= 0 && offset <= (long)size - length;
    }
    static Dictionary<int,string> Rows(Query query, bool requireIPv4) {
        uint size = 0;
        Check(query(IntPtr.Zero, ref size) == 111 && size > 0, "Size query failed");
        IntPtr allocation = Marshal.AllocHGlobal((int)size + 64);
        try {
            for (int i=0; i<size+64; i++) Marshal.WriteByte(allocation,i,0xa5);
            IntPtr data = IntPtr.Add(allocation,32);
            uint shortSize = size - 1;
            Check(query(data,ref shortSize)==111 && shortSize==size,"Short buffer handling failed");
            for (int i=0; i<size+64; i++) Check(Marshal.ReadByte(allocation,i)==0xa5,"Short-buffer write");
            uint capacity=size;
            Check(query(data,ref capacity)==0 && capacity<=size,"Exact-size query failed");
            for (int i=0;i<32;i++) {
                Check(Marshal.ReadByte(allocation,i)==0xa5,"Underrun");
                Check(Marshal.ReadByte(allocation,(int)size+32+i)==0xa5,"Overrun");
            }
            var rows=new Dictionary<int,string>();
            IntPtr row=data;
            int guard=0;
            while(row!=IntPtr.Zero) {
                Check(++guard<=128 && Inside(row,data,size,640),"Invalid adapter pointer");
                bool hasIPv4=false;
                foreach(int offset in new int[]{428,468,508,552,592}) {
                    IntPtr ip=IntPtr.Add(row,offset); int nodes=0;
                    while(ip!=IntPtr.Zero) {
                        Check(++nodes<=128 && Inside(ip,data,size,40),"Invalid IP list pointer");
                        string address=Marshal.PtrToStringAnsi(IntPtr.Add(ip,4),16).Split('\0')[0];
                        if(offset==428 && address.Length>0 && address!="0.0.0.0") hasIPv4=true;
                        ip=Marshal.ReadIntPtr(ip);
                    }
                }
                IntPtr current=Marshal.ReadIntPtr(row,424);
                Check(current==IntPtr.Zero || Inside(current,data,size,40),"Invalid current-address pointer");
                if(requireIPv4) Check(hasIPv4,"Non-IPv4 adapter returned");
                int macLength=Marshal.ReadInt32(row,400);
                Check(macLength>=0 && macLength<=8,"Invalid MAC length");
                byte[] mac=new byte[macLength]; Marshal.Copy(IntPtr.Add(row,404),mac,0,macLength);
                string identity=Marshal.PtrToStringAnsi(IntPtr.Add(row,8),260).Split('\0')[0]+"|"+
                    Marshal.PtrToStringAnsi(IntPtr.Add(row,268),132).Split('\0')[0]+"|"+
                    Convert.ToBase64String(mac)+"|"+Marshal.ReadInt32(row,416)+"|"+Marshal.ReadInt32(row,420);
                if(hasIPv4) rows.Add(Marshal.ReadInt32(row,412),identity);
                row=Marshal.ReadIntPtr(row);
            }
            Console.WriteLine("Adapters="+guard+", IPv4 adapters="+rows.Count+", required bytes="+size);
            return rows;
        } finally { Marshal.FreeHGlobal(allocation); }
    }
    static int Main(string[] args) {
        try {
            Check(IntPtr.Size==4,"Expected 32-bit ABI");
            IntPtr stock=LoadLibraryW(args[0]);
            Check(stock!=IntPtr.Zero,"Could not load stock DLL, error="+Marshal.GetLastWin32Error());
            IntPtr compat=LoadLibraryW(args[1]);
            Check(compat!=IntPtr.Zero,"Could not load compatibility DLL, error="+Marshal.GetLastWin32Error());
            Check(GetProcAddress(stock,"GetAdaptersInfo")!=GetProcAddress(compat,"GetAdaptersInfo"),"Wine bypassed the compatibility DLL");
            var expected=Rows(Function<Query>(stock,"GetAdaptersInfo"),false);
            var actual=Rows(Function<Query>(compat,"GetAdaptersInfo"),true);
            Check(expected.Count==actual.Count,"Lost an IPv4 adapter");
            foreach(var pair in expected) Check(actual.ContainsKey(pair.Key) && actual[pair.Key]==pair.Value,"Adapter identity changed");
            uint a=0,b=0;
            uint sa=Function<TableQuery>(stock,"GetIpAddrTable")(IntPtr.Zero,ref a,false);
            uint sb=Function<TableQuery>(compat,"GetIpAddrTable")(IntPtr.Zero,ref b,false);
            Check(sa==sb && a==b && a>0,"Forwarded function differs");
            Console.WriteLine("PASS: exact/undersized buffers, canaries, all list pointers, IPv4 identities, forwarded API.");
            return 0;
        } catch(Exception e) { Console.WriteLine("FAIL: "+e.Message); return 1; }
    }
}
