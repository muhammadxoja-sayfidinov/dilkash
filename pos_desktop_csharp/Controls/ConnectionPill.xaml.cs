using System;
using System.Windows;
using System.Windows.Controls;

namespace DilkashPos.Controls
{
    public partial class ConnectionPill : UserControl
    {
        public ConnectionPill()
        {
            InitializeComponent();
        }

        public void Update(bool isOnline, int pendingCount, DateTime lastSyncTime)
        {
            if (isOnline)
            {
                PillBorder.SetResourceReference(Border.BackgroundProperty, "BrushPrimaryTint");
                PillBorder.SetResourceReference(Border.BorderBrushProperty, "BrushPrimary");
                StatusDot.SetResourceReference(System.Windows.Shapes.Shape.FillProperty, "BrushPrimaryBright");
                StatusIcon.Data = (System.Windows.Media.Geometry)FindResource("IconWifi");
                StatusIcon.SetResourceReference(Icon.ForegroundProperty, "BrushPrimaryBright");
                StatusText.Text = "Onlayn";
                StatusText.SetResourceReference(TextBlock.ForegroundProperty, "BrushPrimaryBright");

                if (pendingCount > 0)
                {
                    MetaText.Text = $"· Navbat: {pendingCount}";
                    MetaText.SetResourceReference(TextBlock.ForegroundProperty, "BrushAmberBright");
                    MetaText.Visibility = Visibility.Visible;
                }
                else if (lastSyncTime > DateTime.MinValue)
                {
                    MetaText.Text = $"· {lastSyncTime:HH:mm}";
                    MetaText.SetResourceReference(TextBlock.ForegroundProperty, "BrushTextSecondary");
                    MetaText.Visibility = Visibility.Visible;
                }
                else
                {
                    MetaText.Visibility = Visibility.Collapsed;
                }
            }
            else
            {
                PillBorder.SetResourceReference(Border.BackgroundProperty, "BrushAmberTintSoft");
                PillBorder.SetResourceReference(Border.BorderBrushProperty, "BrushAmber");
                StatusDot.SetResourceReference(System.Windows.Shapes.Shape.FillProperty, "BrushAmberBright");
                StatusIcon.Data = (System.Windows.Media.Geometry)FindResource("IconWifiOff");
                StatusIcon.SetResourceReference(Icon.ForegroundProperty, "BrushAmberBright");
                StatusText.Text = "Oflayn";
                StatusText.SetResourceReference(TextBlock.ForegroundProperty, "BrushAmberBright");

                if (pendingCount > 0)
                {
                    MetaText.Text = $"· Navbat: {pendingCount}";
                    MetaText.SetResourceReference(TextBlock.ForegroundProperty, "BrushTextPrimary");
                    MetaText.Visibility = Visibility.Visible;
                }
                else
                {
                    MetaText.Visibility = Visibility.Collapsed;
                }
            }
        }
    }
}
