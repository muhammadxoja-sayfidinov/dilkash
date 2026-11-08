using System;
using System.IO;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Threading;
using DilkashPos.Views;

namespace DilkashPos.Demo
{
    public static class SnapshotRenderer
    {
        private static readonly (int Width, int Height)[] Resolutions = new[]
        {
            (1366, 768),
            (1600, 900),
            (1920, 1080),
            (2560, 1440)
        };

        public static async Task CaptureAllAsync(string outputDir)
        {
            Application.Current.ShutdownMode = ShutdownMode.OnExplicitShutdown;
            Directory.CreateDirectory(outputDir);
            Console.WriteLine($"[SnapshotRenderer] Capturing snapshots to {outputDir}...");

            foreach (var (width, height) in Resolutions)
            {
                string resTag = $"{width}x{height}";
                string resDir = Path.Combine(outputDir, resTag);
                Directory.CreateDirectory(resDir);

                // 1. MainWindow Tabs
                var tabs = new[] { "tables", "quick_pos", "stop_list", "online", "shift", "settings" };
                foreach (var tab in tabs)
                {
                    Application.Current.Dispatcher.Invoke(() =>
                    {
                        var win = new MainWindow
                        {
                            WindowStartupLocation = WindowStartupLocation.Manual,
                            Left = -20000,
                            Top = -20000,
                            Width = width,
                            Height = height,
                            WindowState = WindowState.Normal
                        };

                        win.Show();
                        win.LoadDemoData();
                        win.SwitchToTabPublic(tab);

                        win.Measure(new Size(width, height));
                        win.Arrange(new Rect(0, 0, width, height));
                        win.UpdateLayout();

                        string filename = Path.Combine(resDir, $"{tab}.png");
                        RenderWindowToPng(win, width, height, filename);
                        Console.WriteLine($"[SnapshotRenderer] Wrote {filename}");
                        win.Close();
                    });
                    await Task.Delay(50);
                }

                // 2. Dialogs
                // Payment Dialog (Cash)
                Application.Current.Dispatcher.Invoke(() =>
                {
                    var dlg = new PaymentDialog(285000, "D-2026", "4", 4)
                    {
                        WindowStartupLocation = WindowStartupLocation.Manual,
                        Left = -20000,
                        Top = -20000
                    };
                    dlg.Show();
                    dlg.UpdateLayout();
                    string path = Path.Combine(resDir, "dialog_payment_cash.png");
                    RenderWindowToPng(dlg, (int)dlg.Width, (int)dlg.Height, path);
                    Console.WriteLine($"[SnapshotRenderer] Wrote {path}");
                    dlg.Close();
                });
                await Task.Delay(50);

                // Open Table Dialog
                Application.Current.Dispatcher.Invoke(() =>
                {
                    var dlg = new OpenTableDialog(1, "Stol #1", "Jasur")
                    {
                        WindowStartupLocation = WindowStartupLocation.Manual,
                        Left = -20000,
                        Top = -20000
                    };
                    dlg.Show();
                    dlg.UpdateLayout();
                    string path = Path.Combine(resDir, "dialog_open_table.png");
                    RenderWindowToPng(dlg, (int)dlg.Width, (int)dlg.Height, path);
                    Console.WriteLine($"[SnapshotRenderer] Wrote {path}");
                    dlg.Close();
                });
                await Task.Delay(50);

                // Item Modifier Dialog
                Application.Current.Dispatcher.Invoke(() =>
                {
                    var dlg = new ItemModifierDialog("Qoʻy goʻshti shashlik", "Piyozi koʻproq boʻlsin")
                    {
                        WindowStartupLocation = WindowStartupLocation.Manual,
                        Left = -20000,
                        Top = -20000
                    };
                    dlg.Show();
                    dlg.UpdateLayout();
                    string path = Path.Combine(resDir, "dialog_item_modifier.png");
                    RenderWindowToPng(dlg, (int)dlg.Width, (int)dlg.Height, path);
                    Console.WriteLine($"[SnapshotRenderer] Wrote {path}");
                    dlg.Close();
                });
                await Task.Delay(50);

                // Discount Dialog
                Application.Current.Dispatcher.Invoke(() =>
                {
                    var dlg = new DiscountDialog(10)
                    {
                        WindowStartupLocation = WindowStartupLocation.Manual,
                        Left = -20000,
                        Top = -20000
                    };
                    dlg.Show();
                    dlg.UpdateLayout();
                    string path = Path.Combine(resDir, "dialog_discount.png");
                    RenderWindowToPng(dlg, (int)dlg.Width, (int)dlg.Height, path);
                    Console.WriteLine($"[SnapshotRenderer] Wrote {path}");
                    dlg.Close();
                });
                await Task.Delay(50);

                // Shift Report Dialog
                var (_, _, _, _, _, shift, _) = DemoData.GetDemoDataset();
                Application.Current.Dispatcher.Invoke(() =>
                {
                    var dlg = new ShiftReportDialog(shift, new Services.EscPosPrinterService(), "192.168.1.100:9100")
                    {
                        WindowStartupLocation = WindowStartupLocation.Manual,
                        Left = -20000,
                        Top = -20000
                    };
                    dlg.Show();
                    dlg.UpdateLayout();
                    string path = Path.Combine(resDir, "dialog_shift_report.png");
                    RenderWindowToPng(dlg, (int)dlg.Width, (int)dlg.Height, path);
                    Console.WriteLine($"[SnapshotRenderer] Wrote {path}");
                    dlg.Close();
                });
                await Task.Delay(50);
            }

            Console.WriteLine("[SnapshotRenderer] Completed capturing all snapshots.");
        }

        private static void RenderWindowToPng(Window window, int width, int height, string filePath)
        {
            int renderW = width > 0 ? width : (int)window.ActualWidth;
            int renderH = height > 0 ? height : (int)window.ActualHeight;
            if (renderW <= 0) renderW = 1024;
            if (renderH <= 0) renderH = 768;

            var rtb = new RenderTargetBitmap(renderW, renderH, 96, 96, PixelFormats.Pbgra32);
            rtb.Render(window);

            var encoder = new PngBitmapEncoder();
            encoder.Frames.Add(BitmapFrame.Create(rtb));

            using var fs = File.Create(filePath);
            encoder.Save(fs);
        }
    }
}
