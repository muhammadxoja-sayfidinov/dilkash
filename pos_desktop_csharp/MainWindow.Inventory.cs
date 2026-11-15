using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using DilkashPos.Data;
using DilkashPos.Models;
using DilkashPos.Services;
using DilkashPos.Utils;
using DilkashPos.Views;

namespace DilkashPos
{
    public class ManageStockRow
    {
        public Ingredient Model { get; init; } = new();
        public int Id => Model.Id;
        public string Name => Model.Name;
        public string CategoryDisplay => string.IsNullOrWhiteSpace(Model.CategoryDisplay) ? Model.Category : Model.CategoryDisplay;
        public string Description => string.IsNullOrWhiteSpace(Model.Description) ? "Eslatma kiritilmagan" : Model.Description;
        public string FormattedStock => Model.FormattedStock;
        public string StatusBadge => Model.IsLowStock ? "KAM QOLGAN" : "YETARLI";
        public Brush StatusBg => Model.IsLowStock ? new SolidColorBrush(Color.FromRgb(254, 226, 226)) : new SolidColorBrush(Color.FromRgb(220, 252, 231));
        public Brush StatusFg => Model.IsLowStock ? new SolidColorBrush(Color.FromRgb(185, 28, 28)) : new SolidColorBrush(Color.FromRgb(21, 128, 61));
        public string FormattedCost => Model.FormattedCost;
        public string FormattedValuation => Model.FormattedValuation;
    }

    public class ManageSupplyRow
    {
        public StockSupply Model { get; init; } = new();
        public string DocNumber => Model.DocNumber;
        public string FormattedDate => Model.FormattedDate;
        public string SupplierAndNotes => $"{Model.SupplierName} · {(string.IsNullOrWhiteSpace(Model.Notes) ? "Izoh yoʻq" : Model.Notes)}";
        public string ItemsSummary => $"{Model.ItemsCount} ta xomashyo";
        public string PaymentStatusDisplay => Model.PaymentStatusDisplay;
        public Brush PaymentStatusColor => Model.PaymentStatus == "paid" ? new SolidColorBrush(Color.FromRgb(16, 185, 129)) : new SolidColorBrush(Color.FromRgb(245, 158, 11));
        public string FormattedTotal => Model.FormattedTotal;
    }

    public class ManageWriteOffRow
    {
        public StockWriteOff Model { get; init; } = new();
        public string DocNumber => Model.DocNumber;
        public string FormattedDate => Model.FormattedDate;
        public string ReasonDisplay => Model.ReasonDisplay;
        public string Notes => string.IsNullOrWhiteSpace(Model.Notes) ? $"{Model.ItemsCount} ta mahsulot hisobdan chiqarildi" : Model.Notes;
        public string FormattedTotal => Model.FormattedTotal;
    }

    public class ManageRecipeDishRow
    {
        public Product Dish { get; init; } = new();
        public List<RecipeItem> Recipes { get; init; } = new();
        public int Id => Dish.Id;
        public string Name => Dish.Name;
        public string FormattedPrice => Dish.FormattedPrice;
        public decimal TotalCost => Recipes.Sum(r => r.Cost);
        public string FormattedCost => $"{TotalCost:N0} soʻm";
        public decimal ProfitMargin => Dish.Price - TotalCost;
        public string FormattedProfit => $"{ProfitMargin:N0} soʻm";
        public decimal MarginPercent => Dish.Price > 0 ? (ProfitMargin / Dish.Price) * 100m : 0m;
        public string FormattedMarginPercent => $"{MarginPercent:0.#}%";
        public string RecipeSummary => Recipes.Count > 0 ? $"{Recipes.Count} xomashyo biriktirilgan" : "Retsept yoʻq (1:1 avto chegirish)";
        public Brush RecipeSummaryColor => Recipes.Count > 0 ? new SolidColorBrush(Color.FromRgb(16, 185, 129)) : new SolidColorBrush(Color.FromRgb(156, 163, 175));
    }

    public class ManageSupplierRow
    {
        public Supplier Model { get; init; } = new();
        public int Id => Model.Id;
        public string Name => Model.Name;
        public string ContactAndAddress => $"{(string.IsNullOrWhiteSpace(Model.ContactPerson) ? "Masʼul belgilanmagan" : Model.ContactPerson)} · {(string.IsNullOrWhiteSpace(Model.Address) ? "Manzil kiritilmagan" : Model.Address)}";
        public string PhoneDisplay => string.IsNullOrWhiteSpace(Model.Phone) ? "Telefon yoʻq" : Model.Phone;
        public string FormattedBalance => Model.FormattedBalance;
        public Brush BalanceColor => Model.Balance > 0 ? new SolidColorBrush(Color.FromRgb(239, 68, 68)) : new SolidColorBrush(Color.FromRgb(16, 185, 129));
    }

    public class ManageMovementRow
    {
        public StockMovementLogItem Model { get; init; } = new();
        public string CreatedAtDisplay => Model.CreatedAtDisplay;
        public string IngredientName => $"{Model.IngredientName} ({Model.IngredientUnit})";
        public string MovementTypeDisplay => Model.MovementTypeDisplay;
        public Brush MovementTypeBg => Model.MovementType == "supply" ? new SolidColorBrush(Color.FromRgb(220, 252, 231)) : new SolidColorBrush(Color.FromRgb(254, 226, 226));
        public Brush MovementTypeFg => Model.MovementType == "supply" ? new SolidColorBrush(Color.FromRgb(21, 128, 61)) : new SolidColorBrush(Color.FromRgb(185, 28, 28));
        public string FormattedDelta => Model.FormattedDelta;
        public Brush DeltaBrush => Model.QuantityDelta > 0 ? new SolidColorBrush(Color.FromRgb(16, 185, 129)) : new SolidColorBrush(Color.FromRgb(239, 68, 68));
        public string StockTransitionDisplay => $"{Model.StockBefore:0.###} → {Model.StockAfter:0.###}";
        public string FormattedUnitCost => $"{Model.UnitCost:N0} soʻm";
        public string Notes => Model.Notes;
    }

    public partial class MainWindow
    {
        private void RenderInventoryTab()
        {
            UpdateInventoryKpis();
            UpdateInventoryLowStockBadge();

            // Set sub-tab buttons
            if (InventorySubStockBtn != null) InventorySubStockBtn.IsChecked = _activeInventorySubTab == "stock";
            if (InventorySubSuppliesBtn != null) InventorySubSuppliesBtn.IsChecked = _activeInventorySubTab == "supplies";
            if (InventorySubWriteOffsBtn != null) InventorySubWriteOffsBtn.IsChecked = _activeInventorySubTab == "write_offs";
            if (InventorySubRecipesBtn != null) InventorySubRecipesBtn.IsChecked = _activeInventorySubTab == "recipes";
            if (InventorySubSuppliersBtn != null) InventorySubSuppliersBtn.IsChecked = _activeInventorySubTab == "suppliers";
            if (InventorySubMovementsBtn != null) InventorySubMovementsBtn.IsChecked = _activeInventorySubTab == "movements";

            // Panels visibility
            if (InventoryStockItemsControl != null) InventoryStockItemsControl.Visibility = _activeInventorySubTab == "stock" ? Visibility.Visible : Visibility.Collapsed;
            if (InventorySuppliesItemsControl != null) InventorySuppliesItemsControl.Visibility = _activeInventorySubTab == "supplies" ? Visibility.Visible : Visibility.Collapsed;
            if (InventoryWriteOffsItemsControl != null) InventoryWriteOffsItemsControl.Visibility = _activeInventorySubTab == "write_offs" ? Visibility.Visible : Visibility.Collapsed;
            if (InventoryRecipesItemsControl != null) InventoryRecipesItemsControl.Visibility = _activeInventorySubTab == "recipes" ? Visibility.Visible : Visibility.Collapsed;
            if (InventorySuppliersItemsControl != null) InventorySuppliersItemsControl.Visibility = _activeInventorySubTab == "suppliers" ? Visibility.Visible : Visibility.Collapsed;
            if (InventoryMovementsItemsControl != null) InventoryMovementsItemsControl.Visibility = _activeInventorySubTab == "movements" ? Visibility.Visible : Visibility.Collapsed;

            // Filter button & action button text
            if (InventoryLowStockFilterBtn != null)
                InventoryLowStockFilterBtn.Visibility = _activeInventorySubTab == "stock" ? Visibility.Visible : Visibility.Collapsed;

            if (InventoryMainActionBtn != null)
            {
                InventoryMainActionBtn.Visibility = (_activeInventorySubTab == "movements") ? Visibility.Collapsed : Visibility.Visible;
                InventoryMainActionBtnText.Text = _activeInventorySubTab switch
                {
                    "stock" => "Yangi xomashyo",
                    "supplies" => "Kirim qilish (Prihod)",
                    "write_offs" => "Chiqim qilish (Spisaniye)",
                    "recipes" => "Yangi retsept",
                    "suppliers" => "Yangi taʼminotchi",
                    _ => "Qoʻshish"
                };
            }

            switch (_activeInventorySubTab)
            {
                case "stock":
                    RenderStockList();
                    break;
                case "supplies":
                    RenderSuppliesList();
                    break;
                case "write_offs":
                    RenderWriteOffsList();
                    break;
                case "recipes":
                    RenderRecipesList();
                    break;
                case "suppliers":
                    RenderSuppliersList();
                    break;
                case "movements":
                    RenderMovementsList();
                    break;
            }
        }

        private void UpdateInventoryKpis()
        {
            if (_ingredients.Count > 0)
            {
                decimal totalValuation = _ingredients.Sum(i => i.TotalValuation);
                int lowCount = _ingredients.Count(i => i.IsLowStock);

                _inventoryKpi.TotalIngredients = _ingredients.Count;
                _inventoryKpi.LowStockCount = lowCount;
                _inventoryKpi.TotalValuation = totalValuation;
            }

            if (InventoryKpiTotalItemsText != null) InventoryKpiTotalItemsText.Text = $"{_inventoryKpi.TotalIngredients} tur";
            if (InventoryKpiTotalValuationText != null) InventoryKpiTotalValuationText.Text = _inventoryKpi.FormattedValuation;
            if (InventoryKpiLowStockCountText != null) InventoryKpiLowStockCountText.Text = $"{_inventoryKpi.LowStockCount} ta xomashyo";
            if (InventoryKpiTodaySuppliesText != null) InventoryKpiTodaySuppliesText.Text = _inventoryKpi.FormattedTodaySupplies;
        }

        public void UpdateInventoryLowStockBadge()
        {
            int lowCount = _ingredients.Count(i => i.IsLowStock);
            if (NavInventoryLowStockBadgeBorder != null)
            {
                NavInventoryLowStockBadgeBorder.Visibility = lowCount > 0 ? Visibility.Visible : Visibility.Collapsed;
            }
            if (NavInventoryLowStockBadgeText != null)
            {
                NavInventoryLowStockBadgeText.Text = lowCount.ToString();
            }
        }

        private void RenderStockList()
        {
            var q = (InventorySearchBox?.Text ?? "").Trim();
            var items = _ingredients.AsEnumerable();

            if (_filterLowStockOnly)
            {
                items = items.Where(i => i.IsLowStock);
            }
            if (!string.IsNullOrWhiteSpace(q))
            {
                items = items.Where(i => i.Name.Contains(q, StringComparison.OrdinalIgnoreCase) ||
                                         i.Category.Contains(q, StringComparison.OrdinalIgnoreCase) ||
                                         i.CategoryDisplay.Contains(q, StringComparison.OrdinalIgnoreCase));
            }

            var rows = items.OrderBy(i => !i.IsLowStock).ThenBy(i => i.Name)
                            .Select(i => new ManageStockRow { Model = i })
                            .ToList();

            if (InventoryStockItemsControl != null)
                InventoryStockItemsControl.ItemsSource = rows;
        }

        private void RenderSuppliesList()
        {
            var q = (InventorySearchBox?.Text ?? "").Trim();
            var items = _supplies.AsEnumerable();

            if (!string.IsNullOrWhiteSpace(q))
            {
                items = items.Where(s => s.DocNumber.Contains(q, StringComparison.OrdinalIgnoreCase) ||
                                         s.SupplierName.Contains(q, StringComparison.OrdinalIgnoreCase) ||
                                         s.Notes.Contains(q, StringComparison.OrdinalIgnoreCase));
            }

            var rows = items.OrderByDescending(s => s.Date)
                            .Select(s => new ManageSupplyRow { Model = s })
                            .ToList();

            if (InventorySuppliesItemsControl != null)
                InventorySuppliesItemsControl.ItemsSource = rows;
        }

        private void RenderWriteOffsList()
        {
            var q = (InventorySearchBox?.Text ?? "").Trim();
            var items = _writeOffs.AsEnumerable();

            if (!string.IsNullOrWhiteSpace(q))
            {
                items = items.Where(w => w.DocNumber.Contains(q, StringComparison.OrdinalIgnoreCase) ||
                                         w.Notes.Contains(q, StringComparison.OrdinalIgnoreCase) ||
                                         w.ReasonDisplay.Contains(q, StringComparison.OrdinalIgnoreCase));
            }

            var rows = items.OrderByDescending(w => w.Date)
                            .Select(w => new ManageWriteOffRow { Model = w })
                            .ToList();

            if (InventoryWriteOffsItemsControl != null)
                InventoryWriteOffsItemsControl.ItemsSource = rows;
        }

        private void RenderRecipesList()
        {
            var q = (InventorySearchBox?.Text ?? "").Trim();
            var prods = _products.AsEnumerable();

            if (!string.IsNullOrWhiteSpace(q))
            {
                prods = prods.Where(p => p.Name.Contains(q, StringComparison.OrdinalIgnoreCase) ||
                                         p.CategoryName.Contains(q, StringComparison.OrdinalIgnoreCase));
            }

            var recipeLookup = _recipes.GroupBy(r => r.ProductId).ToDictionary(g => g.Key, g => g.ToList());

            var rows = prods.OrderBy(p => p.CategoryName).ThenBy(p => p.Name)
                            .Select(p => new ManageRecipeDishRow
                            {
                                Dish = p,
                                Recipes = recipeLookup.TryGetValue(p.Id, out var recList) ? recList : new List<RecipeItem>()
                            })
                            .ToList();

            if (InventoryRecipesItemsControl != null)
                InventoryRecipesItemsControl.ItemsSource = rows;
        }

        private void RenderSuppliersList()
        {
            var q = (InventorySearchBox?.Text ?? "").Trim();
            var items = _suppliers.AsEnumerable();

            if (!string.IsNullOrWhiteSpace(q))
            {
                items = items.Where(s => s.Name.Contains(q, StringComparison.OrdinalIgnoreCase) ||
                                         s.ContactPerson.Contains(q, StringComparison.OrdinalIgnoreCase) ||
                                         s.Phone.Contains(q, StringComparison.OrdinalIgnoreCase));
            }

            var rows = items.OrderBy(s => s.Name)
                            .Select(s => new ManageSupplierRow { Model = s })
                            .ToList();

            if (InventorySuppliersItemsControl != null)
                InventorySuppliersItemsControl.ItemsSource = rows;
        }

        private void RenderMovementsList()
        {
            var q = (InventorySearchBox?.Text ?? "").Trim();
            var items = _movements.AsEnumerable();

            if (!string.IsNullOrWhiteSpace(q))
            {
                items = items.Where(m => m.IngredientName.Contains(q, StringComparison.OrdinalIgnoreCase) ||
                                         m.Notes.Contains(q, StringComparison.OrdinalIgnoreCase) ||
                                         m.MovementTypeDisplay.Contains(q, StringComparison.OrdinalIgnoreCase));
            }

            var rows = items.OrderByDescending(m => m.CreatedAt)
                            .Select(m => new ManageMovementRow { Model = m })
                            .ToList();

            if (InventoryMovementsItemsControl != null)
                InventoryMovementsItemsControl.ItemsSource = rows;
        }

        #region Event Handlers
        private void OnInventorySubTabClick(object sender, RoutedEventArgs e)
        {
            if (sender is RadioButton rb && rb.Tag is string tag)
            {
                _activeInventorySubTab = tag;
                RenderInventoryTab();
            }
        }

        private void OnInventorySearchChanged(object sender, TextChangedEventArgs e)
        {
            RenderInventoryTab();
        }

        private void OnInventoryLowStockFilterClick(object sender, RoutedEventArgs e)
        {
            _filterLowStockOnly = InventoryLowStockFilterBtn.IsChecked == true;
            RenderStockList();
        }

        private async void OnInventoryMainActionClick(object sender, RoutedEventArgs e)
        {
            switch (_activeInventorySubTab)
            {
                case "stock":
                    await OpenAddIngredientDialogAsync();
                    break;
                case "supplies":
                    await OpenSupplyDialogAsync();
                    break;
                case "write_offs":
                    await OpenWriteOffDialogAsync();
                    break;
                case "recipes":
                    Toast.Show("Tex-karta tuzish uchun pastdagi taomlardan birini tanlang", ToastTone.Info);
                    break;
                case "suppliers":
                    await OpenAddSupplierDialogAsync();
                    break;
            }
        }

        private async void OnIngredientSupplyQuickClick(object sender, RoutedEventArgs e)
        {
            if (sender is Button b && b.Tag is ManageStockRow row)
            {
                await OpenSupplyDialogAsync(row.Model);
            }
        }

        private async void OnEditIngredientClick(object sender, RoutedEventArgs e)
        {
            if (sender is Button b && b.Tag is ManageStockRow row)
            {
                var dialog = new IngredientEditDialog(row.Model);
                if (Dialogs.ShowModal(dialog, this) == true)
                {
                    row.Model.Name = dialog.IngredientName;
                    row.Model.Category = dialog.SelectedCategory;
                    row.Model.Unit = dialog.SelectedUnit;
                    row.Model.CurrentStock = dialog.CurrentStock;
                    row.Model.MinStockAlert = dialog.MinStockAlert;
                    row.Model.CostPrice = dialog.CostPrice;
                    row.Model.Description = dialog.IngredientDescription;
                    row.Model.IsActive = dialog.IsIngredientActive;

                    await _db.UpsertIngredientAsync(row.Model);
                    await _api.SaveIngredientAsync(new
                    {
                        id = row.Model.Id,
                        name = row.Model.Name,
                        category = row.Model.Category,
                        unit = row.Model.Unit,
                        current_stock = row.Model.CurrentStock,
                        min_stock_alert = row.Model.MinStockAlert,
                        cost_price = row.Model.CostPrice,
                        description = row.Model.Description,
                        is_active = row.Model.IsActive
                    });

                    RenderInventoryTab();
                    Toast.Show("Xomashyo maʼlumotlari saqlandi", ToastTone.Success);
                }
            }
        }

        private async void OnDeleteIngredientClick(object sender, RoutedEventArgs e)
        {
            if (sender is Button b && b.Tag is ManageStockRow row)
            {
                var confirm = new ConfirmDialog($"'{row.Model.Name}' xomashyosini oʻchirmoqchimisiz?", "Xomashyoni oʻchirish");
                if (Dialogs.ShowModal(confirm, this) == true)
                {
                    _ingredients.Remove(row.Model);
                    await _db.DeleteIngredientAsync(row.Model.Id);
                    await _api.DeleteIngredientAsync(row.Model.Id);

                    RenderInventoryTab();
                    Toast.Show("Xomashyo ombordan oʻchirildi", ToastTone.Success);
                }
            }
        }

        private async Task OpenAddIngredientDialogAsync()
        {
            var dialog = new IngredientEditDialog();
            if (Dialogs.ShowModal(dialog, this) == true)
            {
                var newIng = new Ingredient
                {
                    Name = dialog.IngredientName,
                    Category = dialog.SelectedCategory,
                    Unit = dialog.SelectedUnit,
                    CurrentStock = dialog.CurrentStock,
                    MinStockAlert = dialog.MinStockAlert,
                    CostPrice = dialog.CostPrice,
                    Description = dialog.IngredientDescription,
                    IsActive = dialog.IsIngredientActive
                };

                var (netOk, ok, createdIng, err) = await _api.SaveIngredientAsync(new
                {
                    name = newIng.Name,
                    category = newIng.Category,
                    unit = newIng.Unit,
                    current_stock = newIng.CurrentStock,
                    min_stock_alert = newIng.MinStockAlert,
                    cost_price = newIng.CostPrice,
                    description = newIng.Description,
                    is_active = newIng.IsActive
                });

                if (ok && createdIng != null)
                {
                    newIng.Id = createdIng.Id;
                    newIng.CategoryDisplay = createdIng.CategoryDisplay;
                    newIng.UnitDisplay = createdIng.UnitDisplay;
                }

                await _db.UpsertIngredientAsync(newIng);
                _ingredients.Add(newIng);

                RenderInventoryTab();
                Toast.Show("Yangi xomashyo qoʻshildi", ToastTone.Success);
            }
        }

        private async Task OpenSupplyDialogAsync(Ingredient? preselectedIng = null)
        {
            var dialog = new StockSupplyDialog(_ingredients, _suppliers);
            if (Dialogs.ShowModal(dialog, this) == true)
            {
                var itemsPayload = dialog.ResultItems.Select(i => new
                {
                    ingredient_id = i.IngredientId,
                    quantity = i.Quantity,
                    unit_price = i.UnitPrice
                }).ToList();

                var payload = new
                {
                    supplier_id = dialog.SelectedSupplierId,
                    payment_status = dialog.SelectedPaymentStatus,
                    paid_amount = dialog.PaidAmount,
                    notes = dialog.Notes,
                    items = itemsPayload
                };

                var (netOk, ok, supply, err) = await _api.CreateSupplyAsync(payload);

                // Update local ingredient stock in memory and SQLite
                foreach (var itm in dialog.ResultItems)
                {
                    var ing = _ingredients.FirstOrDefault(i => i.Id == itm.IngredientId);
                    if (ing != null)
                    {
                        ing.CurrentStock += itm.Quantity;
                        ing.CostPrice = itm.UnitPrice;
                        await _db.UpsertIngredientAsync(ing);
                    }
                }

                if (supply != null)
                {
                    _supplies.Insert(0, supply);
                    _inventoryKpi.TodaySuppliesTotal += supply.TotalCost;
                }
                else
                {
                    decimal totalCost = dialog.ResultItems.Sum(i => i.Quantity * i.UnitPrice);
                    _supplies.Insert(0, new StockSupply
                    {
                        DocNumber = $"KIR-{DateTime.Now:yyyyMMdd}-{_supplies.Count + 1:D3}",
                        SupplierName = _suppliers.FirstOrDefault(s => s.Id == dialog.SelectedSupplierId)?.Name ?? "Umumiy bozor",
                        Date = DateTime.Now,
                        TotalCost = totalCost,
                        PaymentStatus = dialog.SelectedPaymentStatus,
                        PaymentStatusDisplay = dialog.SelectedPaymentStatus == "paid" ? "Toʻlangan" : "Qisman/Qarz",
                        Notes = dialog.Notes,
                        ItemsCount = dialog.ResultItems.Count
                    });
                    _inventoryKpi.TodaySuppliesTotal += totalCost;
                }

                RenderInventoryTab();
                Toast.Show("Kirim muvaffaqiyatli qabul qilindi", ToastTone.Success);
            }
        }

        private async Task OpenWriteOffDialogAsync()
        {
            var dialog = new StockWriteOffDialog(_ingredients);
            if (Dialogs.ShowModal(dialog, this) == true)
            {
                var itemsPayload = dialog.ResultItems.Select(i => new
                {
                    ingredient_id = i.IngredientId,
                    quantity = i.Quantity
                }).ToList();

                var payload = new
                {
                    reason = dialog.SelectedReason,
                    notes = dialog.Notes,
                    items = itemsPayload
                };

                var (netOk, ok, writeOff, err) = await _api.CreateWriteOffAsync(payload);

                // Deduct from local SQLite and memory
                foreach (var itm in dialog.ResultItems)
                {
                    var ing = _ingredients.FirstOrDefault(i => i.Id == itm.IngredientId);
                    if (ing != null)
                    {
                        ing.CurrentStock = Math.Max(0, ing.CurrentStock - itm.Quantity);
                        await _db.UpsertIngredientAsync(ing);
                    }
                }

                if (writeOff != null)
                {
                    _writeOffs.Insert(0, writeOff);
                }
                else
                {
                    decimal totalCost = 0;
                    foreach (var itm in dialog.ResultItems)
                    {
                        var ing = _ingredients.FirstOrDefault(i => i.Id == itm.IngredientId);
                        totalCost += itm.Quantity * (ing?.CostPrice ?? 0m);
                    }
                    _writeOffs.Insert(0, new StockWriteOff
                    {
                        DocNumber = $"CHIQ-{DateTime.Now:yyyyMMdd}-{_writeOffs.Count + 1:D3}",
                        Date = DateTime.Now,
                        Reason = dialog.SelectedReason,
                        ReasonDisplay = dialog.SelectedReason switch
                        {
                            "spoilage" => "Yaroqsiz / Aynigan",
                            "expired" => "Muddati oʻtgan",
                            "waste" => "Brak / Buzilgan",
                            "staff_meal" => "Xodimlar ovqati",
                            "shortage" => "Kamomad",
                            _ => "Boshqa sabab"
                        },
                        TotalCost = totalCost,
                        Notes = dialog.Notes,
                        ItemsCount = dialog.ResultItems.Count
                    });
                }

                RenderInventoryTab();
                Toast.Show("Mahsulotlar hisobdan chiqarildi (spisaniye)", ToastTone.Success);
            }
        }

        private async void OnEditRecipeClick(object sender, RoutedEventArgs e)
        {
            if (sender is Button b && b.Tag is ManageRecipeDishRow row)
            {
                var dialog = new RecipeEditDialog(row.Dish, row.Recipes, _ingredients);
                if (Dialogs.ShowModal(dialog, this) == true)
                {
                    var itemsPayload = dialog.ResultRecipes.Select(r => new
                    {
                        ingredient_id = r.IngredientId,
                        quantity = r.Quantity,
                        unit = r.Unit,
                        notes = r.Notes
                    }).ToList();

                    var (netOk, ok, savedList, err) = await _api.SaveRecipeAsync(row.Dish.Id, new { items = itemsPayload });

                    var recipesToKeep = (ok && savedList.Count > 0) ? savedList : dialog.ResultRecipes;

                    // Update local database
                    await _db.SaveProductRecipesAsync(row.Dish.Id, recipesToKeep);

                    // Update in-memory recipes list
                    _recipes.RemoveAll(r => r.ProductId == row.Dish.Id);
                    _recipes.AddRange(recipesToKeep);

                    RenderInventoryTab();
                    Toast.Show($"'{row.Dish.Name}' tex-kartasi muvaffaqiyatli saqlandi", ToastTone.Success);
                }
            }
        }

        private async Task OpenAddSupplierDialogAsync()
        {
            var dialog = new SupplierEditDialog();
            if (Dialogs.ShowModal(dialog, this) == true)
            {
                var newSup = new Supplier
                {
                    Name = dialog.SupplierName,
                    Phone = dialog.SupplierPhone,
                    ContactPerson = dialog.ContactPerson,
                    Address = dialog.Address,
                    Notes = dialog.Notes,
                    IsActive = dialog.IsSupplierActive
                };

                var (netOk, ok, createdSup, err) = await _api.SaveSupplierAsync(new
                {
                    name = newSup.Name,
                    phone = newSup.Phone,
                    contact_person = newSup.ContactPerson,
                    address = newSup.Address,
                    notes = newSup.Notes,
                    is_active = newSup.IsActive
                });

                if (ok && createdSup != null)
                {
                    newSup.Id = createdSup.Id;
                }

                await _db.UpsertSupplierAsync(newSup);
                _suppliers.Add(newSup);

                RenderInventoryTab();
                Toast.Show("Yangi taʼminotchi qoʻshildi", ToastTone.Success);
            }
        }

        private async void OnEditSupplierClick(object sender, RoutedEventArgs e)
        {
            if (sender is Button b && b.Tag is ManageSupplierRow row)
            {
                var dialog = new SupplierEditDialog(row.Model);
                if (Dialogs.ShowModal(dialog, this) == true)
                {
                    row.Model.Name = dialog.SupplierName;
                    row.Model.Phone = dialog.SupplierPhone;
                    row.Model.ContactPerson = dialog.ContactPerson;
                    row.Model.Address = dialog.Address;
                    row.Model.Notes = dialog.Notes;
                    row.Model.IsActive = dialog.IsSupplierActive;

                    await _db.UpsertSupplierAsync(row.Model);
                    await _api.SaveSupplierAsync(new
                    {
                        id = row.Model.Id,
                        name = row.Model.Name,
                        phone = row.Model.Phone,
                        contact_person = row.Model.ContactPerson,
                        address = row.Model.Address,
                        notes = row.Model.Notes,
                        is_active = row.Model.IsActive
                    });

                    RenderInventoryTab();
                    Toast.Show("Taʼminotchi maʼlumotlari saqlandi", ToastTone.Success);
                }
            }
        }

        private async void OnDeleteSupplierClick(object sender, RoutedEventArgs e)
        {
            if (sender is Button b && b.Tag is ManageSupplierRow row)
            {
                var confirm = new ConfirmDialog($"'{row.Model.Name}' taʼminotchisini oʻchirmoqchimisiz?", "Taʼminotchini oʻchirish");
                if (Dialogs.ShowModal(confirm, this) == true)
                {
                    _suppliers.Remove(row.Model);
                    await _db.DeleteSupplierAsync(row.Model.Id);
                    await _api.DeleteSupplierAsync(row.Model.Id);

                    RenderInventoryTab();
                    Toast.Show("Taʼminotchi oʻchirildi", ToastTone.Success);
                }
            }
        }
        #endregion
    }
}
