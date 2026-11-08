using System;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using System.Windows;
using DilkashPos.Demo;

namespace DilkashPos
{
    public partial class App : Application
    {
        protected override async void OnStartup(StartupEventArgs e)
        {
            base.OnStartup(e);

            bool isDemo = e.Args.Any(a => string.Equals(a, "--demo", StringComparison.OrdinalIgnoreCase));
            int snapIdx = Array.FindIndex(e.Args, a => string.Equals(a, "--snapshots", StringComparison.OrdinalIgnoreCase));
            bool isSnapshots = snapIdx >= 0;
            bool isGallery = e.Args.Any(a => string.Equals(a, "--gallery", StringComparison.OrdinalIgnoreCase));

            if (isSnapshots)
            {
                string outDir = snapIdx + 1 < e.Args.Length && !e.Args[snapIdx + 1].StartsWith("--")
                    ? e.Args[snapIdx + 1]
                    : Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "..", "..", "..", "..", "docs", "design", "snapshots", "before");

                outDir = Path.GetFullPath(outDir);
                await SnapshotRenderer.CaptureAllAsync(outDir);
                Shutdown(0);
                return;
            }

            if (isGallery)
            {
                // In Phase 0/1 we will open gallery or message
                MessageBox.Show("Komponentlar galereyasi Phase 1 da to'liq ochiladi.", "Galereya", MessageBoxButton.OK, MessageBoxImage.Information);
                Shutdown(0);
                return;
            }

            var mainWindow = new MainWindow();
            if (isDemo)
            {
                mainWindow.LoadDemoData();
            }
            mainWindow.Show();
        }
    }
}
