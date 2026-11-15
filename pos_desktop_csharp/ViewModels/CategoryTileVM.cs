using DilkashPos.Models;

namespace DilkashPos.ViewModels
{
    public class CategoryTileVM : ObservableObject
    {
        public CategoryTileVM(Category model, int directProductsCount, int subcategoriesCount, int recursiveProductsCount)
        {
            Model = model;
            DirectProductsCount = directProductsCount;
            SubcategoriesCount = subcategoriesCount;
            RecursiveProductsCount = recursiveProductsCount;
        }

        public Category Model { get; }
        public int Id => Model.Id;
        public string Name => Model.Name;
        public string Department => (Model.Department ?? "kitchen").ToLowerInvariant();
        public string Description => Model.Description ?? "";
        public int DirectProductsCount { get; }
        public int SubcategoriesCount { get; }
        public int RecursiveProductsCount { get; }

        public string CountLabel
        {
            get
            {
                if (SubcategoriesCount > 0 && DirectProductsCount > 0)
                    return $"{SubcategoriesCount} boʻlim · {RecursiveProductsCount} taom";
                if (SubcategoriesCount > 0)
                    return $"{SubcategoriesCount} ta ichki boʻlim · {RecursiveProductsCount} taom";
                return $"{DirectProductsCount} ta taom";
            }
        }

        public string DepartmentLabel => Department switch
        {
            "shashlik" => "Shashlikxona",
            "somsa" => "Somsaxona",
            "fastfood" => "Fast-Food",
            "bar" => "Bar & Desert",
            "kassa" => "Kassa",
            _ => "Oshxona"
        };
    }

    public class CategoryBreadcrumbVM
    {
        public CategoryBreadcrumbVM(int id, string name, bool isLast)
        {
            Id = id;
            Name = name;
            IsLast = isLast;
        }

        public int Id { get; }
        public string Name { get; }
        public bool IsLast { get; }
    }
}
