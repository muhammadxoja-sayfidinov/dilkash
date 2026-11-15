using DilkashPos.Models;

namespace DilkashPos.ViewModels
{
    public class PrinterCardVM : ObservableObject
    {
        private string _printerIp;
        private bool _isOnline;

        public PrinterCardVM(PosPrinter model, bool isOnline)
        {
            Model = model;
            _printerIp = string.IsNullOrWhiteSpace(model.IpAddress) ? "" : model.EffectiveAddress;
            _isOnline = isOnline;
        }

        public PrinterCardVM(string code, string name, string subtitle, string iconKey, string printerIp, bool isOnline)
        {
            Model = new PosPrinter
            {
                Name = name,
                Department = code,
                Subtitle = subtitle,
                IpAddress = printerIp,
                Port = 9100,
                PaperWidth = 80,
                IsActive = true
            };
            _printerIp = printerIp;
            _isOnline = isOnline;
        }

        public PosPrinter Model { get; }
        public int Id => Model.Id;
        public string Code => Model.Department;
        public string Name => Model.Name;
        public string Subtitle => string.IsNullOrWhiteSpace(Model.Subtitle) ? DepartmentLabel : Model.Subtitle;
        public int PaperWidth => Model.PaperWidth > 0 ? Model.PaperWidth : 80;
        public string PaperWidthLabel => $"{PaperWidth} mm";
        public bool IsActive => Model.IsActive;

        public string DepartmentLabel => (Model.Department ?? "kitchen").ToLowerInvariant() switch
        {
            "kassa" => "Kassa",
            "shashlik" => "Shashlikxona",
            "somsa" => "Somsaxona",
            "fastfood" => "Fast-Food",
            "bar" => "Bar & Desert",
            _ => "Oshxona"
        };

        public string PrinterIp
        {
            get => _printerIp;
            set
            {
                if (SetProperty(ref _printerIp, value))
                {
                    var trimmed = (value ?? "").Trim();
                    if (trimmed.Contains(':'))
                    {
                        var parts = trimmed.Split(':', 2);
                        Model.IpAddress = parts[0].Trim();
                        if (int.TryParse(parts[1].Trim(), out int p) && p > 0)
                            Model.Port = p;
                    }
                    else
                    {
                        Model.IpAddress = trimmed;
                    }
                    IsOnline = Model.IsActive && !string.IsNullOrWhiteSpace(Model.IpAddress);
                }
            }
        }

        public bool IsOnline
        {
            get => _isOnline;
            set
            {
                if (SetProperty(ref _isOnline, value))
                {
                    OnPropertyChanged(nameof(StatusLabel));
                }
            }
        }

        public string StatusLabel => !Model.IsActive ? "Oʻchirilgan" : (_isOnline ? "Onlayn" : "Oflayn");
    }
}
