using DilkashPos.Models;

namespace DilkashPos.ViewModels
{
    public class CategoryChipVM : ObservableObject
    {
        private bool _isSelected;
        private int _count;

        public CategoryChipVM(int id, string name, string department, int count, bool isSelected = false)
        {
            Id = id;
            Name = name;
            Department = department;
            _count = count;
            _isSelected = isSelected;
        }

        public int Id { get; }
        public string Name { get; }
        public string Department { get; }

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

        public string IconResourceKey => Department.ToLowerInvariant() switch
        {
            "shashlik" => "IconGrill",
            "somsa" => "IconChef",
            "fastfood" => "IconBurger",
            "bar" => "IconCoffee",
            "kitchen" => "IconBowl",
            _ => "IconTables"
        };
    }
}
