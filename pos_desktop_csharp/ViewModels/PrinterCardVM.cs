using DilkashPos.Models;

namespace DilkashPos.ViewModels
{
    public class PrinterCardVM : ObservableObject
    {
        private string _printerIp;
        private bool _isOnline;

        public PrinterCardVM(string code, string name, string subtitle, string iconKey, string printerIp, bool isOnline)
        {
            Code = code;
            Name = name;
            Subtitle = subtitle;
            IconKey = iconKey;
            _printerIp = printerIp;
            _isOnline = isOnline;
        }

        public string Code { get; }
        public string Name { get; }
        public string Subtitle { get; }
        public string IconKey { get; }

        public string PrinterIp
        {
            get => _printerIp;
            set => SetProperty(ref _printerIp, value);
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

        public string StatusLabel => _isOnline ? "Onlayn" : "Oflayn";
    }
}
