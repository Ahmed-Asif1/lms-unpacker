using System;
using System.Diagnostics;
using System.IO;
using System.IO.Compression;
using System.Reflection;
using System.Text;
using System.Web.Script.Serialization;
using System.Windows.Forms;

[assembly: AssemblyTitle("LMS Unpacker")]
[assembly: AssemblyDescription("Portable offline ZIP extraction and course organization")]
[assembly: AssemblyCompany("LMS Unpacker contributors")]
[assembly: AssemblyProduct("LMS Unpacker")]
[assembly: AssemblyVersion("1.4.2.0")]

// Both editions carry the same offline payload. No installer or download at startup.
internal static class PortableHost
{
    [STAThread]
    private static int Main(string[] args)
    {
        string temporary = null;
        int result = 1;
        try
        {
            string parent = Path.GetFullPath(Path.GetTempPath());
            temporary = Path.Combine(parent, "lms-unpacker-" + Guid.NewGuid().ToString("N"));
            Directory.CreateDirectory(temporary);
            using (Stream stream = Assembly.GetExecutingAssembly().GetManifestResourceStream("App.zip"))
            using (ZipArchive zip = new ZipArchive(stream, ZipArchiveMode.Read))
            {
                string prefix = temporary + Path.DirectorySeparatorChar;
                foreach (ZipArchiveEntry entry in zip.Entries)
                {
                    string target = Path.GetFullPath(Path.Combine(temporary, entry.FullName));
                    if (!target.StartsWith(prefix, StringComparison.OrdinalIgnoreCase))
                        throw new InvalidDataException("Invalid application package path.");
                    Directory.CreateDirectory(Path.GetDirectoryName(target));
                    if (entry.Name.Length != 0) entry.ExtractToFile(target, false);
                }
            }
            string root = Path.Combine(temporary, "LMS-Unpacker");
            string engine = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Windows),
                @"System32\WindowsPowerShell\v1.0\powershell.exe");
            if (!File.Exists(engine)) throw new FileNotFoundException("Windows PowerShell 5.1 is required.");
            ProcessStartInfo start = new ProcessStartInfo(engine);
#if DESKTOP
            string script = "Start-Desktop.ps1";
            start.CreateNoWindow = true;
            start.WindowStyle = ProcessWindowStyle.Hidden;
            start.RedirectStandardError = true;
#else
            string script = "Start-Cli.ps1";
#endif
            start.UseShellExecute = false;
            start.Arguments = "-NoLogo -NoProfile -STA -ExecutionPolicy Bypass -File \"" + Path.Combine(root, script) + "\"";
            // Arguments are data, never interpolated into a PowerShell command or a shell.
            start.EnvironmentVariables["LMS_ARGUMENTS"] = Convert.ToBase64String(Encoding.UTF8.GetBytes(new JavaScriptSerializer().Serialize(args)));
            start.EnvironmentVariables["LMS_APP_EXE"] = Assembly.GetExecutingAssembly().Location;
            using (Process child = Process.Start(start))
            {
#if DESKTOP
                string diagnostics = child.StandardError.ReadToEnd();
#endif
                child.WaitForExit(); result = child.ExitCode;
#if DESKTOP
                if (result != 0 && !String.IsNullOrWhiteSpace(diagnostics))
                    MessageBox.Show(diagnostics, "LMS Unpacker could not start", MessageBoxButtons.OK, MessageBoxIcon.Error);
#endif
            }
        }
        catch (Exception error)
        {
#if DESKTOP
            MessageBox.Show(error.Message + "\n\nTry a writable local folder. On a managed computer, ask IT about application restrictions.",
                "LMS Unpacker could not open", MessageBoxButtons.OK, MessageBoxIcon.Error);
#else
            Console.Error.WriteLine("[ERROR] " + error.Message);
#endif
        }
        finally
        {
            if (temporary != null)
            {
                string prefix = Path.GetFullPath(Path.GetTempPath()).TrimEnd(Path.DirectorySeparatorChar) + Path.DirectorySeparatorChar;
                string resolved = Path.GetFullPath(temporary);
                if (resolved.StartsWith(prefix, StringComparison.OrdinalIgnoreCase) &&
                    Path.GetFileName(resolved).StartsWith("lms-unpacker-", StringComparison.Ordinal))
                {
                    try { Directory.Delete(resolved, true); }
                    catch (IOException) { /* A viewer may still hold an embedded help file open. */ }
                    catch (UnauthorizedAccessException) { }
                }
            }
        }
        return result;
    }
}
