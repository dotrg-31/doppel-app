// Doppel for Windows (formerly DuplicateGPT): launches a second, isolated instance of
// the installed ChatGPT desktop app (Microsoft Store package "OpenAI.Codex") with its own
// browser profile and its own Codex home. It never modifies the installed app or its
// data, and it ships none of OpenAI's files. Personal use only.
//
// After launching, a hidden companion stays alive while the second instance runs and
// gives its windows the Doppel icon and their own taskbar group.
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Management;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using System.Windows.Forms;
using Microsoft.Win32;

[assembly: System.Reflection.AssemblyTitle("Doppel")]
[assembly: System.Reflection.AssemblyProduct("Doppel")]
[assembly: System.Reflection.AssemblyCompany("RG Development")]
[assembly: System.Reflection.AssemblyVersion("1.2.0.0")]
[assembly: System.Reflection.AssemblyFileVersion("1.2.0.0")]

static class Doppel
{
    const string AppName = "Doppel";
    const string PackageName = "OpenAI.Codex";
    const string PublisherId = "2p2nqsd0c76g0";
    const string AppUserModelId = "RGDevelopment.Doppel";
    const string RepoKey =
        @"Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\Repository\Packages";

    [STAThread]
    static int Main(string[] args)
    {
        try
        {
            string home = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
            string local = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
            // Data lives in %LOCALAPPDATA%\Doppel\profile and %USERPROFILE%\.codex-doppel.
            // Installs made under the earlier name (DuplicateGPT) keep using their existing
            // folders, so nobody is signed out by the rename.
            string profile = Env("DOPPEL_PROFILE", "DUPLICATEGPT_PROFILE");
            if (string.IsNullOrEmpty(profile))
                profile = PreferExisting(Path.Combine(local, "Doppel", "profile"),
                                         Path.Combine(local, "DuplicateGPT", "profile"));
            string codexHome = Env("DOPPEL_CODEX_HOME", "DUPLICATEGPT_CODEX_HOME");
            if (string.IsNullOrEmpty(codexHome))
                codexHome = PreferExisting(Path.Combine(home, ".codex-doppel"),
                                           Path.Combine(home, ".codex-duplicategpt"));

            string appDir = FindChatGptAppDir();
            if (appDir == null)
            {
                Fail("ChatGPT desktop app not found.\n\nInstall ChatGPT from the Microsoft Store (or chatgpt.com/download), open it once, then try again.");
                return 2;
            }
            string exe = Path.Combine(appDir, "ChatGPT.exe");

            if (Array.Exists(args, a => a == "--print"))
            {
                Console.WriteLine("app:        " + exe);
                Console.WriteLine("profile:    " + profile);
                Console.WriteLine("CODEX_HOME: " + codexHome);
                return 0;
            }

            Directory.CreateDirectory(profile);
            Directory.CreateDirectory(codexHome);

            var psi = new ProcessStartInfo(exe);
            psi.UseShellExecute = false;
            psi.WorkingDirectory = appDir;
            psi.Arguments = "--user-data-dir=\"" + profile + "\"";
            foreach (string a in args) psi.Arguments += " " + Quote(a);
            psi.EnvironmentVariables["CODEX_HOME"] = codexHome;
            Process.Start(psi);

            // One companion per user: a second launch only focuses the open instance (Chromium does that).
            bool first;
            using (var m = new Mutex(true, @"Local\Doppel.Companion", out first))
            {
                if (first) RunCompanion(profile);
            }
            return 0;
        }
        catch (Exception ex)
        {
            Fail("Could not start the second ChatGPT:\n\n" + ex.Message);
            return 1;
        }
    }

    // ---------- companion: icon + taskbar identity for the duplicate's windows ----------

    static void RunCompanion(string profile)
    {
        string self = Process.GetCurrentProcess().MainModule.FileName;
        IntPtr bigIcon = LoadIconFromSelf(self, 256);
        IntPtr smallIcon = LoadIconFromSelf(self, 32);
        var done = new HashSet<IntPtr>();
        int mainPid = 0;
        DateTime start = DateTime.UtcNow;

        while (true)
        {
            if (mainPid == 0 || !IsAlive(mainPid))
            {
                mainPid = FindDuplicateMainPid(profile);
                if (mainPid == 0)
                {
                    if ((DateTime.UtcNow - start).TotalSeconds > 60) return; // never appeared / has exited
                    Thread.Sleep(1000);
                    continue;
                }
                done.Clear();
            }

            foreach (IntPtr h in TopLevelWindows(mainPid))
            {
                if (!IsWindowVisible(h)) continue;
                // Re-applied every pass: the app may reset its window icon (e.g. on theme change).
                if (smallIcon != IntPtr.Zero) SendMessage(h, WM_SETICON, (IntPtr)ICON_SMALL, smallIcon);
                if (bigIcon != IntPtr.Zero) SendMessage(h, WM_SETICON, (IntPtr)ICON_BIG, bigIcon);
                if (done.Add(h)) SetTaskbarIdentity(h, self);
                // Window title (Alt+Tab, taskbar label): show "Doppel" instead of the app's "ChatGPT".
                var title = new StringBuilder(64);
                GetWindowText(h, title, 64);
                if (title.ToString() == "ChatGPT") SetWindowText(h, AppName);
            }
            Thread.Sleep(done.Count == 0 ? 500 : 2000);
        }
    }

    static int FindDuplicateMainPid(string profile)
    {
        string needle = profile.ToLowerInvariant();
        try
        {
            using (var s = new ManagementObjectSearcher(
                "SELECT ProcessId, CommandLine FROM Win32_Process WHERE Name = 'ChatGPT.exe'"))
            {
                foreach (ManagementObject o in s.Get())
                {
                    string cmd = (o["CommandLine"] as string ?? "").ToLowerInvariant();
                    if (cmd.Contains(needle) && !cmd.Contains("--type=")) return Convert.ToInt32(o["ProcessId"]);
                }
            }
        }
        catch { }
        return 0;
    }

    static bool IsAlive(int pid)
    {
        try { return !Process.GetProcessById(pid).HasExited; } catch { return false; }
    }

    static List<IntPtr> TopLevelWindows(int pid)
    {
        var list = new List<IntPtr>();
        EnumWindows((h, l) =>
        {
            uint p; GetWindowThreadProcessId(h, out p);
            if (p == (uint)pid)
            {
                var cls = new StringBuilder(64); GetClassName(h, cls, 64);
                if (cls.ToString() == "Chrome_WidgetWin_1") list.Add(h);
            }
            return true;
        }, IntPtr.Zero);
        return list;
    }

    // Own AppUserModelID => separate taskbar button from the main ChatGPT; relaunch/pin
    // properties point back at DuplicateGPT.exe with its icon.
    static void SetTaskbarIdentity(IntPtr hwnd, string self)
    {
        IPropertyStore store;
        Guid iid = typeof(IPropertyStore).GUID;
        if (SHGetPropertyStoreForWindow(hwnd, ref iid, out store) != 0 || store == null) return;
        try
        {
            SetString(store, PKEY_AppUserModel_ID, AppUserModelId);
            SetString(store, PKEY_RelaunchCommand, "\"" + self + "\"");
            SetString(store, PKEY_RelaunchDisplayNameResource, AppName);
            SetString(store, PKEY_RelaunchIconResource, self + ",0");
            store.Commit();
        }
        catch { }
        finally { Marshal.ReleaseComObject(store); }
    }

    static void SetString(IPropertyStore store, PROPERTYKEY key, string value)
    {
        var pv = new PROPVARIANT { vt = 31 /* VT_LPWSTR */, p = Marshal.StringToCoTaskMemUni(value) };
        try { store.SetValue(ref key, ref pv); }
        finally { Marshal.FreeCoTaskMem(pv.p); }
    }

    static IntPtr LoadIconFromSelf(string path, int size)
    {
        IntPtr[] large = new IntPtr[1];
        uint[] ids = new uint[1];
        return PrivateExtractIcons(path, 0, size, size, large, ids, 1, 0) > 0 ? large[0] : IntPtr.Zero;
    }

    // ---------- locating the installed app ----------

    // The Store package's install folder changes with every update, so it is resolved
    // on each launch from the per-user package repository (no copy, no refresh step).
    static string FindChatGptAppDir()
    {
        string best = null;
        Version bestVer = null;
        using (RegistryKey root = Registry.CurrentUser.OpenSubKey(RepoKey))
        {
            if (root == null) return null;
            foreach (string full in root.GetSubKeyNames())
            {
                // e.g. OpenAI.Codex_26.1106.6628.0_x64__2p2nqsd0c76g0
                string[] parts = full.Split('_');
                if (parts.Length < 5 || parts[0] != PackageName || parts[parts.Length - 1] != PublisherId) continue;
                Version v;
                if (!Version.TryParse(parts[1], out v)) continue;
                string folder = null;
                using (RegistryKey k = root.OpenSubKey(full))
                    if (k != null) folder = k.GetValue("PackageRootFolder") as string;
                if (string.IsNullOrEmpty(folder)) folder = Path.Combine(@"C:\Program Files\WindowsApps", full);
                string app = Path.Combine(folder, "app");
                if (!File.Exists(Path.Combine(app, "ChatGPT.exe"))) continue;
                if (bestVer == null || v > bestVer) { bestVer = v; best = app; }
            }
        }
        return best;
    }

    static string Quote(string a)
    {
        return a.IndexOfAny(new[] { ' ', '"' }) < 0 ? a : "\"" + a.Replace("\"", "\\\"") + "\"";
    }

    static void Fail(string msg)
    {
        MessageBox.Show(msg, AppName, MessageBoxButtons.OK, MessageBoxIcon.Error);
    }

    static string PreferExisting(string current, string legacy)
    {
        return !Directory.Exists(current) && Directory.Exists(legacy) ? legacy : current;
    }

    static string Env(string name, string legacyName)
    {
        string v = Environment.GetEnvironmentVariable(name);
        return string.IsNullOrEmpty(v) ? Environment.GetEnvironmentVariable(legacyName) : v;
    }

    // ---------- interop ----------

    const uint WM_SETICON = 0x0080;
    const int ICON_SMALL = 0, ICON_BIG = 1;

    delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
    [DllImport("user32.dll")] static extern bool EnumWindows(EnumWindowsProc cb, IntPtr lParam);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint pid);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetClassName(IntPtr hWnd, StringBuilder s, int n);
    [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetWindowText(IntPtr hWnd, StringBuilder s, int n);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern bool SetWindowText(IntPtr hWnd, string s);
    [DllImport("user32.dll")] static extern IntPtr SendMessage(IntPtr hWnd, uint msg, IntPtr w, IntPtr l);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    static extern uint PrivateExtractIcons(string file, int index, int cx, int cy, IntPtr[] icons, uint[] ids, uint n, uint flags);
    [DllImport("shell32.dll")]
    static extern int SHGetPropertyStoreForWindow(IntPtr hwnd, ref Guid iid, [MarshalAs(UnmanagedType.Interface)] out IPropertyStore store);

    [StructLayout(LayoutKind.Sequential, Pack = 4)]
    struct PROPERTYKEY { public Guid fmtid; public uint pid; public PROPERTYKEY(Guid g, uint p) { fmtid = g; pid = p; } }

    [StructLayout(LayoutKind.Sequential)]
    struct PROPVARIANT { public ushort vt; public ushort r1, r2, r3; public IntPtr p; public IntPtr p2; }

    static readonly Guid AppUserModelFmt = new Guid("9F4C2855-9F79-4B39-A8D0-E1D42DE1D5F3");
    static readonly PROPERTYKEY PKEY_AppUserModel_ID = new PROPERTYKEY(AppUserModelFmt, 5);
    static readonly PROPERTYKEY PKEY_RelaunchCommand = new PROPERTYKEY(AppUserModelFmt, 2);
    static readonly PROPERTYKEY PKEY_RelaunchIconResource = new PROPERTYKEY(AppUserModelFmt, 3);
    static readonly PROPERTYKEY PKEY_RelaunchDisplayNameResource = new PROPERTYKEY(AppUserModelFmt, 4);

    [ComImport, Guid("886D8EEB-8CF2-4446-8D02-CDBA1DBDCF99"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IPropertyStore
    {
        void GetCount(out uint c);
        void GetAt(uint i, out PROPERTYKEY k);
        void GetValue(ref PROPERTYKEY k, out PROPVARIANT v);
        void SetValue(ref PROPERTYKEY k, ref PROPVARIANT v);
        void Commit();
    }
}
