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
            DilkashPos.Controls.DialogChrome.DisableAnimationsForTests = true;
            Directory.CreateDirectory(outputDir);
            Console.WriteLine($"[SnapshotRenderer] Capturing snapshots to {outputDir}...");

            // 0. Capture Component Gallery
            Application.Current.Dispatcher.Invoke(() =>
            {
                var gal = new GalleryWindow
                {
                    WindowStartupLocation = WindowStartupLocation.Manual,
                    Left = -20000,
                    Top = -20000,
                    Width = 1600,
                    Height = 960
                };
                gal.Show();
                gal.UpdateLayout();

                gal.MainScroll.VerticalScrollBarVisibility = System.Windows.Controls.ScrollBarVisibility.Disabled;
                gal.GalleryContent.Measure(new Size(1552, double.PositiveInfinity));
                int galHeight = (int)Math.Ceiling(gal.GalleryContent.DesiredSize.Height) + 56;
                if (galHeight < 960) galHeight = 960;

                string gPath = Path.Combine(outputDir, "gallery.png");
                RenderWindowToPng(gal, 1600, galHeight, gPath);
                Console.WriteLine($"[SnapshotRenderer] Wrote {gPath} (1600x{galHeight})");
                gal.Close();
            });
            await Task.Delay(50);

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

                        win.PrepareDemoMode();
                        win.Show();
                        win.LoadDemoData();
                        win.UpdateShellLayoutForWidth(width);
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
                static int GetDlgHeight(Window d, int fallback = 540)
                {
                    if (d.ActualHeight > 0) return (int)Math.Ceiling(d.ActualHeight);
                    return !double.IsNaN(d.Height) && d.Height > 0 ? (int)Math.Ceiling(d.Height) : fallback;
                }

                // Payment Dialog (Cash, Card, Split, Success)
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

                    RenderWindowToPng(dlg, (int)dlg.Width, GetDlgHeight(dlg, 672), Path.Combine(resDir, "dialog_payment_cash.png"));

                    if (width == 1366 || width == 1920)
                    {
                        dlg.SetDemoMethod("karta");
                        RenderWindowToPng(dlg, (int)dlg.Width, GetDlgHeight(dlg, 672), Path.Combine(resDir, "dialog_payment_card.png"));

                        dlg.SetDemoMethod("aralash");
                        RenderWindowToPng(dlg, (int)dlg.Width, GetDlgHeight(dlg, 672), Path.Combine(resDir, "dialog_payment_split.png"));

                        dlg.SetDemoMethod("naqd");
                        dlg.SetDemoSuccessState();
                        RenderWindowToPng(dlg, (int)dlg.Width, GetDlgHeight(dlg, 672), Path.Combine(resDir, "dialog_payment_success.png"));
                    }

                    Console.WriteLine($"[SnapshotRenderer] Wrote payment dialog snapshots in {resDir}");
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
                    RenderWindowToPng(dlg, (int)dlg.Width, GetDlgHeight(dlg, 460), path);
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
                    RenderWindowToPng(dlg, (int)dlg.Width, GetDlgHeight(dlg, 480), path);
                    Console.WriteLine($"[SnapshotRenderer] Wrote {path}");
                    dlg.Close();
                });
                await Task.Delay(50);

                // Discount Dialog
                Application.Current.Dispatcher.Invoke(() =>
                {
                    var dlg = new DiscountDialog(10, 418000)
                    {
                        WindowStartupLocation = WindowStartupLocation.Manual,
                        Left = -20000,
                        Top = -20000
                    };
                    dlg.Show();
                    dlg.UpdateLayout();
                    string path = Path.Combine(resDir, "dialog_discount.png");
                    RenderWindowToPng(dlg, (int)dlg.Width, GetDlgHeight(dlg, 600), path);
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
                    RenderWindowToPng(dlg, (int)dlg.Width, GetDlgHeight(dlg, 620), path);
                    Console.WriteLine($"[SnapshotRenderer] Wrote {path}");
                    dlg.Close();
                });
                await Task.Delay(50);

                // Confirm Dialog (Phase 2)
                Application.Current.Dispatcher.Invoke(() =>
                {
                    var dlg = new ConfirmDialog(
                        "Smenani yopish",
                        "Kassa smenasini yopib, Z-hisobot chiqarmoqchimisiz?",
                        "Smenani yopish",
                        "Bekor qilish",
                        isDestructive: true)
                    {
                        WindowStartupLocation = WindowStartupLocation.Manual,
                        Left = -20000,
                        Top = -20000
                    };
                    dlg.Show();
                    dlg.UpdateLayout();
                    string path = Path.Combine(resDir, "dialog_confirm.png");
                    RenderWindowToPng(dlg, (int)dlg.Width, (int)dlg.ActualHeight > 0 ? (int)dlg.ActualHeight : 280, path);
                    Console.WriteLine($"[SnapshotRenderer] Wrote {path}");
                    dlg.Close();
                });
                await Task.Delay(50);

                // Shell States: Offline strip, Lock overlay, Toast (at 1366x768 and 1920x1080)
                if (width == 1366 || width == 1920)
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
                        win.PrepareDemoMode();
                        win.Show();
                        win.LoadDemoData();
                        win.UpdateShellLayoutForWidth(width);

                        // Offline strip
                        win.SetDemoSyncState(false, 3);
                        RenderWindowToPng(win, width, height, Path.Combine(resDir, "shell_offline.png"));

                        // Tables Loading & Empty states
                        win.SetDemoSyncState(true, 0);
                        win.SetDemoTablesState(isLoading: true, forceEmpty: false);
                        RenderWindowToPng(win, width, height, Path.Combine(resDir, "tables_loading.png"));

                        win.SetDemoTablesState(isLoading: false, forceEmpty: true);
                        RenderWindowToPng(win, width, height, Path.Combine(resDir, "tables_empty.png"));
                        win.SetDemoTablesState(isLoading: false, forceEmpty: false);

                        // Order screen empty search state
                        win.SwitchToTabPublic("quick_pos");
                        win.SetDemoQuickPosEmpty(true);
                        RenderWindowToPng(win, width, height, Path.Combine(resDir, "quick_pos_empty.png"));
                        win.SetDemoQuickPosEmpty(false);

                        // Stop-list loading & empty states
                        win.SwitchToTabPublic("stop_list");
                        win.SetDemoStopListState(isLoading: true, forceEmpty: false);
                        RenderWindowToPng(win, width, height, Path.Combine(resDir, "stop_list_loading.png"));
                        win.SetDemoStopListState(isLoading: false, forceEmpty: true);
                        RenderWindowToPng(win, width, height, Path.Combine(resDir, "stop_list_empty.png"));
                        win.SetDemoStopListState(isLoading: false, forceEmpty: false);

                        // Online loading & empty states
                        win.SwitchToTabPublic("online");
                        win.SetDemoOnlineState(isLoading: true, forceEmpty: false);
                        RenderWindowToPng(win, width, height, Path.Combine(resDir, "online_loading.png"));
                        win.SetDemoOnlineState(isLoading: false, forceEmpty: true);
                        RenderWindowToPng(win, width, height, Path.Combine(resDir, "online_empty.png"));
                        win.SetDemoOnlineState(isLoading: false, forceEmpty: false);

                        // Shift loading & empty states
                        win.SwitchToTabPublic("shift");
                        win.SetDemoShiftState(isLoading: true, forceEmpty: false);
                        RenderWindowToPng(win, width, height, Path.Combine(resDir, "shift_loading.png"));
                        win.SetDemoShiftState(isLoading: false, forceEmpty: true);
                        RenderWindowToPng(win, width, height, Path.Combine(resDir, "shift_empty.png"));
                        win.SetDemoShiftState(isLoading: false, forceEmpty: false);

                        // Settings loading & dirty states
                        win.SwitchToTabPublic("settings");
                        win.SetDemoSettingsState(isLoading: true, forceDirty: false);
                        RenderWindowToPng(win, width, height, Path.Combine(resDir, "settings_loading.png"));
                        win.SetDemoSettingsState(isLoading: false, forceDirty: true);
                        RenderWindowToPng(win, width, height, Path.Combine(resDir, "settings_dirty.png"));
                        win.SetDemoSettingsState(isLoading: false, forceDirty: false);

                        win.SwitchToTabPublic("tables");

                        // Toast
                        win.ShowDemoToast("Toʻlov qabul qilindi va kassa cheki chop etildi", Utils.ToastTone.Success, "Qaytarish");
                        RenderWindowToPng(win, width, height, Path.Combine(resDir, "shell_toast.png"));

                        // Lock overlay
                        win.SetLockedState(true);
                        RenderWindowToPng(win, width, height, Path.Combine(resDir, "shell_locked.png"));

                        win.Close();
                    });
                    await Task.Delay(50);
                }
            }

            // Effective DPI viewport checks (1920x1080 @ 125% = 1536x864, 1920x1080 @ 150% = 1280x720)
            foreach (var (dWidth, dHeight, dTag) in DpiEffectiveSizes)
            {
                string dpiDir = Path.Combine(outputDir, dTag);
                Directory.CreateDirectory(dpiDir);
                foreach (var tab in new[] { "tables", "quick_pos", "settings" })
                {
                    Application.Current.Dispatcher.Invoke(() =>
                    {
                        var win = new MainWindow
                        {
                            WindowStartupLocation = WindowStartupLocation.Manual,
                            Left = -20000,
                            Top = -20000,
                            Width = dWidth,
                            Height = dHeight,
                            WindowState = WindowState.Normal
                        };
                        win.PrepareDemoMode();
                        win.Show();
                        win.LoadDemoData();
                        win.UpdateShellLayoutForWidth(dWidth);
                        win.SwitchToTabPublic(tab);
                        string filename = Path.Combine(dpiDir, $"{tab}.png");
                        RenderWindowToPng(win, dWidth, dHeight, filename);
                        Console.WriteLine($"[SnapshotRenderer] Wrote {filename}");
                        win.Close();
                    });
                    await Task.Delay(50);
                }
            }

            Console.WriteLine("[SnapshotRenderer] Completed capturing all snapshots.");
        }

        private static readonly (int Width, int Height, string Tag)[] DpiEffectiveSizes = new[]
        {
            (1536, 864, "1920x1080_dpi125"),
            (1280, 720, "1920x1080_dpi150")
        };

        private static void RenderWindowToPng(Window window, int width, int height, string filePath)
        {
            int renderW = width > 0 ? width : (int)window.ActualWidth;
            int renderH = height > 0 ? height : (int)window.ActualHeight;
            if (renderW <= 0) renderW = 1024;
            if (renderH <= 0) renderH = 768;

            var rtb = new RenderTargetBitmap(renderW, renderH, 96, 96, PixelFormats.Pbgra32);

            if (window.Content is FrameworkElement content)
            {
                window.UpdateLayout();

                var bgBrush = window.Background;
                if (bgBrush == null || (bgBrush is SolidColorBrush scb && scb.Color.A == 0))
                {
                    bgBrush = (Brush)(Application.Current.TryFindResource("BrushBg") ?? Brushes.Black);
                }
                var dc = window.DataContext;
                var winRes = window.Resources;

                // Detach from Win32 Window so Measure/Arrange renders exact virtual target dimensions
                // without being clamped to the host monitor's working area.
                window.Content = null;

                if (content.DataContext == null && dc != null)
                {
                    content.DataContext = dc;
                }
                if (winRes != null && winRes.Count > 0 && !content.Resources.MergedDictionaries.Contains(winRes))
                {
                    content.Resources.MergedDictionaries.Insert(0, winRes);
                }

                var host = new System.Windows.Controls.Border
                {
                    Width = renderW,
                    Height = renderH,
                    Background = bgBrush,
                    Child = content
                };

                InvalidateTreeMeasure(host);
                host.Measure(new Size(renderW, renderH));
                host.Arrange(new Rect(0, 0, renderW, renderH));
                host.UpdateLayout();

                rtb.Render(host);

                host.Child = null;
                window.Content = content;
            }
            else
            {
                rtb.Render(window);
            }

            var encoder = new PngBitmapEncoder();
            encoder.Frames.Add(BitmapFrame.Create(rtb));

            for (int attempt = 0; attempt < 5; attempt++)
            {
                try
                {
                    using var fs = new FileStream(filePath, FileMode.Create, FileAccess.Write, FileShare.ReadWrite);
                    encoder.Save(fs);
                    break;
                }
                catch (IOException) when (attempt < 4)
                {
                    System.Threading.Thread.Sleep(60);
                }
            }
        }

        private static void InvalidateTreeMeasure(DependencyObject obj)
        {
            if (obj is UIElement ui)
            {
                ui.InvalidateMeasure();
            }
            int count = VisualTreeHelper.GetChildrenCount(obj);
            for (int i = 0; i < count; i++)
            {
                InvalidateTreeMeasure(VisualTreeHelper.GetChild(obj, i));
            }
        }
    }
}
