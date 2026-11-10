using System;
using System.IO;
using System.Linq;
using System.Windows;
using DilkashPos.Demo;
using DilkashPos.Utils;
using DilkashPos.Views;

namespace DilkashPos
{
    public partial class App : Application
    {
        protected override async void OnStartup(StartupEventArgs e)
        {
            base.OnStartup(e);

            // Verify bundled Inter font glyph support for Uzbek U+02BB (ʻ)
            FontHelper.VerifyBundledFontGlyphs();

            bool isDemo = e.Args.Any(a => string.Equals(a, "--demo", StringComparison.OrdinalIgnoreCase));
            int snapIdx = Array.FindIndex(e.Args, a => string.Equals(a, "--snapshots", StringComparison.OrdinalIgnoreCase));
            bool isSnapshots = snapIdx >= 0;
            bool isGallery = e.Args.Any(a => string.Equals(a, "--gallery", StringComparison.OrdinalIgnoreCase));

            if (isSnapshots)
            {
                string outDir = snapIdx + 1 < e.Args.Length && !e.Args[snapIdx + 1].StartsWith("--")
                    ? e.Args[snapIdx + 1]
                    : Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "..", "..", "..", "..", "docs", "design", "snapshots", "after");

                outDir = Path.GetFullPath(outDir);
                await SnapshotRenderer.CaptureAllAsync(outDir);
                Shutdown(0);
                return;
            }

            if (isGallery)
            {
                var gallery = new GalleryWindow();
                gallery.Show();
                return;
            }

            var mainWindow = new MainWindow();
            if (isDemo)
            {
                mainWindow.PrepareDemoMode();
                mainWindow.LoadDemoData();
            }
            mainWindow.Show();
        }
    }
}
