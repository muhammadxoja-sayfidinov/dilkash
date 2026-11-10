using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using DilkashPos.Controls;
using DilkashPos.Utils;

namespace DilkashPos.Views
{
    public partial class GalleryWindow : Window
    {
        public GalleryWindow()
        {
            InitializeComponent();
            FontCheckText.Text = FontHelper.VerifyBundledFontGlyphs();

            MoneyDemo1.Text = MoneyFormatter.Format(28000);
            MoneyDemo2.Text = MoneyFormatter.Format(125000);
            MoneyDemo3.Text = MoneyFormatter.FormatWithSign(14650000);

            PopulateIconGrid();
        }

        private void PopulateIconGrid()
        {
            string[] iconKeys =
            {
                "IconTables", "IconQuickSale", "IconStop", "IconOnline", "IconReport", "IconSettings",
                "IconLock", "IconUnlock", "IconUser", "IconTag", "IconCard", "IconCash",
                "IconSplit", "IconPrinter", "IconWifi", "IconWifiOff", "IconClock", "IconSearch",
                "IconPlus", "IconMinus", "IconTrash", "IconEdit", "IconReceipt", "IconSendToKitchen",
                "IconCheck", "IconClose", "IconAlert", "IconRefresh", "IconFullscreen",
                "IconChevronDown", "IconChevronRight",
                "IconGrill", "IconChef", "IconBowl", "IconBurger", "IconCoffee"
            };

            foreach (var key in iconKeys)
            {
                if (TryFindResource(key) is Geometry geo)
                {
                    var card = new Border
                    {
                        Width = 92,
                        Height = 72,
                        Margin = new Thickness(4),
                        CornerRadius = new CornerRadius(10),
                        Padding = new Thickness(4),
                        BorderThickness = new Thickness(1)
                    };
                    card.SetResourceReference(Border.BackgroundProperty, "BrushBg");
                    card.SetResourceReference(Border.BorderBrushProperty, "BrushBorderSubtle");

                    var sp = new StackPanel { VerticalAlignment = VerticalAlignment.Center, HorizontalAlignment = HorizontalAlignment.Center };
                    sp.Children.Add(new Icon { Data = geo, Size = 24, HorizontalAlignment = HorizontalAlignment.Center });
                    sp.Children.Add(new TextBlock
                    {
                        Text = key.Replace("Icon", ""),
                        FontSize = 13,
                        Margin = new Thickness(0, 6, 0, 0),
                        HorizontalAlignment = HorizontalAlignment.Center
                    });
                    card.Child = sp;
                    IconsWrapPanel.Children.Add(card);
                }
            }
        }
    }
}
