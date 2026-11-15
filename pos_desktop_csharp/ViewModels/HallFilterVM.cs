namespace DilkashPos.ViewModels
{
    public class HallFilterVM : ObservableObject
    {
        private bool _isSelected;
        private int _count;

        public HallFilterVM(string key, string name, int count, bool isSelected = false)
        {
            Key = key;
            Name = name;
            _count = count;
            _isSelected = isSelected;
        }

        public string Key { get; }
        public string Name { get; }

        public int Count
        {
            get => _count;
            set
            {
                if (SetProperty(ref _count, value))
                {
                    OnPropertyChanged(nameof(DisplayLabel));
                }
            }
        }

        public bool IsSelected
        {
            get => _isSelected;
            set => SetProperty(ref _isSelected, value);
        }

        public string DisplayLabel => $"{Name} ({Count})";
    }
}
