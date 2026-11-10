using System.Collections.ObjectModel;

namespace DilkashPos.ViewModels
{
    public class TableZoneSectionVM : ObservableObject
    {
        private string _zoneTitle = "";
        private string _zoneSummary = "";
        private int _columns = 4;

        public string ZoneKey { get; set; } = "";

        public string ZoneTitle
        {
            get => _zoneTitle;
            set => SetProperty(ref _zoneTitle, value);
        }

        public string ZoneSummary
        {
            get => _zoneSummary;
            set => SetProperty(ref _zoneSummary, value);
        }

        public int Columns
        {
            get => _columns;
            set => SetProperty(ref _columns, value);
        }

        public ObservableCollection<TableCardVM> Tables { get; } = new();
    }
}
