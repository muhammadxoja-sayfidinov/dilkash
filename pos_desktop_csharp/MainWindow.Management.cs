using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Linq;
using System.Text.Json;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using System.Windows.Media;
using DilkashPos.Data;
using DilkashPos.Models;
using DilkashPos.Utils;
using DilkashPos.Views;

namespace DilkashPos
{
    public class ManageProductRow
    {
        public Product Model { get; init; } = new();
        public string Name => Model.Name;
        public string Subtitle => string.IsNullOrWhiteSpace(Model.Description) ? "Tavsif kiritilmagan" : Model.Description;
        public string CategoryAndDept => $"{(string.IsNullOrWhiteSpace(Model.CategoryName) ? "Umumiy" : Model.CategoryName)} · {GetDeptDisplay(Model.Department)}";
        public string PriceFormatted => Model.FormattedPrice;
        public string StatusText => Model.IsAvailable ? "Mavjud" : "Stop-list";
        public Brush StatusBg => Model.IsAvailable ? new SolidColorBrush(Color.FromRgb(220, 252, 231)) : new SolidColorBrush(Color.FromRgb(254, 226, 226));
        public Brush StatusFg => Model.IsAvailable ? new SolidColorBrush(Color.FromRgb(21, 128, 61)) : new SolidColorBrush(Color.FromRgb(185, 28, 28));

        internal static string GetDeptDisplay(string dept) => dept switch
        {
            "shashlik" => "Shashlikxona",
            "somsa" => "Somsaxona",
            "fastfood" => "Fast-Food",
            "bar" => "Bar & Desert",
            "kassa" => "Kassa",
            _ => "Oshxona"
        };
    }

    public class ManageCategoryRow
    {
        public Category Model { get; init; } = new();
        public string Name => Model.Name;
        public string Description => string.IsNullOrWhiteSpace(Model.Description) ? "Taomlar guruhi" : Model.Description;
        public string DepartmentLabel => ManageProductRow.GetDeptDisplay(Model.Department);
        public string ProductsCountText => $"{Model.ProductsCount} ta taom";
        public string StatusText => Model.IsActive ? "Faol" : "Nofaol";
    }

    public class ManageStaffRow
    {
        public StaffAccount Model { get; init; } = new();
        public string Name => Model.Name;
        public string RoleLabel => Model.RoleLabel;
        public string StaffCode => Model.StaffCode;
        public string ToggleButtonText => Model.IsActive ? "Faol (Oʻchirish)" : "Nofaol (Yoqish)";
        public string DetailsText
        {
            get
            {
                var parts = new List<string> { string.IsNullOrWhiteSpace(Model.Phone) ? "Telefon yoʻq" : Model.Phone };
                if (!string.IsNullOrWhiteSpace(Model.VehicleInfo)) parts.Add(Model.VehicleInfo);
                if (Model.TelegramId.HasValue) parts.Add("Telegram ulangan");
                return string.Join(" · ", parts);
            }
        }
    }

    public class ManageTableRow
    {
        public RestaurantTable Model { get; init; } = new();
        public string Name => Model.Name;
        public string Zone => Model.Zone;
        public string CapacityText => $"{Model.Capacity} oʻrin";
        public string Subtitle => $"Stol #{Model.Number} · QR kod menyuga tayyor";
        public string StatusText => Model.IsOccupied ? "Band" : (Model.IsActive ? "Faol" : "Nofaol");
    }

    public partial class MainWindow
    {
        private string _activeManageSubTab = "products";
        private readonly ObservableCollection<ManageProductRow> _manageProducts = new();
        private readonly ObservableCollection<ManageCategoryRow> _manageCategories = new();
        private readonly ObservableCollection<ManageStaffRow> _manageStaff = new();
        private readonly ObservableCollection<ManageTableRow> _manageTables = new();

        private void InitializeManagementLists()
        {
            ManageProductsItemsControl.ItemsSource = _manageProducts;
            ManageCategoriesItemsControl.ItemsSource = _manageCategories;
            ManageStaffItemsControl.ItemsSource = _manageStaff;
            ManageTablesItemsControl.ItemsSource = _manageTables;
        }

        private void OnManageSubTabClick(object sender, RoutedEventArgs e)
        {
            if (sender is ToggleButton tb && tb.Tag is string tag)
            {
                _activeManageSubTab = tag;
                RenderManageTab();
            }
        }

        private void OnManageSearchChanged(object sender, TextChangedEventArgs e)
        {
            RenderManageTab();
        }

        private void RenderManageTab()
        {
            if (ManageProductsItemsControl == null) return;

            ManageProductsItemsControl.Visibility = _activeManageSubTab == "products" ? Visibility.Visible : Visibility.Collapsed;
            ManageCategoriesItemsControl.Visibility = _activeManageSubTab == "categories" ? Visibility.Visible : Visibility.Collapsed;
            ManageStaffItemsControl.Visibility = _activeManageSubTab == "staff" ? Visibility.Visible : Visibility.Collapsed;
            ManageTablesItemsControl.Visibility = _activeManageSubTab == "tables" ? Visibility.Visible : Visibility.Collapsed;

            ManageAddBtnText.Text = _activeManageSubTab switch
            {
                "categories" => "Guruh qoʻshish",
                "staff" => "Xodim qoʻshish",
                "tables" => "Stol qoʻshish",
                _ => "Taom qoʻshish"
            };

            string q = (ManageSearchBox.Text ?? "").Trim();

            if (_activeManageSubTab == "products")
            {
                _manageProducts.Clear();
                List<Product> snap;
                lock (_stateLock) snap = _products.ToList();
                foreach (var p in snap)
                {
                    if (!string.IsNullOrEmpty(q) &&
                        !p.Name.Contains(q, StringComparison.OrdinalIgnoreCase) &&
                        !p.CategoryName.Contains(q, StringComparison.OrdinalIgnoreCase))
                        continue;
                    _manageProducts.Add(new ManageProductRow { Model = p });
                }
            }
            else if (_activeManageSubTab == "categories")
            {
                _manageCategories.Clear();
                List<Category> catSnap;
                List<Product> prodSnap;
                lock (_stateLock)
                {
                    catSnap = _categories.ToList();
                    prodSnap = _products.ToList();
                }
                foreach (var c in catSnap)
                {
                    if (!string.IsNullOrEmpty(q) && !c.Name.Contains(q, StringComparison.OrdinalIgnoreCase))
                        continue;
                    c.ProductsCount = prodSnap.Count(p => p.CategoryId == c.Id || string.Equals(p.CategoryName, c.Name, StringComparison.OrdinalIgnoreCase));
                    _manageCategories.Add(new ManageCategoryRow { Model = c });
                }
            }
            else if (_activeManageSubTab == "staff")
            {
                _manageStaff.Clear();
                List<StaffAccount> stSnap;
                lock (_stateLock) stSnap = _staffAccounts.ToList();
                foreach (var s in stSnap)
                {
                    if (!string.IsNullOrEmpty(q) &&
                        !s.Name.Contains(q, StringComparison.OrdinalIgnoreCase) &&
                        !s.Phone.Contains(q, StringComparison.OrdinalIgnoreCase) &&
                        !s.RoleLabel.Contains(q, StringComparison.OrdinalIgnoreCase))
                        continue;
                    _manageStaff.Add(new ManageStaffRow { Model = s });
                }
            }
            else if (_activeManageSubTab == "tables")
            {
                _manageTables.Clear();
                List<RestaurantTable> tSnap;
                lock (_stateLock) tSnap = _tables.OrderBy(t => t.Number).ToList();
                foreach (var t in tSnap)
                {
                    if (!string.IsNullOrEmpty(q) &&
                        !t.Name.Contains(q, StringComparison.OrdinalIgnoreCase) &&
                        !t.Number.ToString().Contains(q, StringComparison.OrdinalIgnoreCase))
                        continue;
                    _manageTables.Add(new ManageTableRow { Model = t });
                }
            }
        }

        private async void OnManageAddClick(object sender, RoutedEventArgs e)
        {
            switch (_activeManageSubTab)
            {
                case "categories":
                    await OpenAndSaveCategoryDialogAsync(null);
                    break;
                case "staff":
                    await OpenAndSaveStaffDialogAsync(null);
                    break;
                case "tables":
                    await OpenAndSaveTableDialogAsync(null);
                    break;
                default:
                    await OpenAndSaveProductDialogAsync(null);
                    break;
            }
        }

        private async void OnManageEditProductClick(object sender, RoutedEventArgs e)
        {
            if (sender is Button btn && btn.Tag is Product p)
                await OpenAndSaveProductDialogAsync(p);
        }

        private async void OnManageDeleteProductClick(object sender, RoutedEventArgs e)
        {
            if (sender is not Button btn || btn.Tag is not Product p) return;
            var confirm = new ConfirmDialog("Taomni oʻchirish", $"'{p.Name}' taomini menyudan oʻchirasizmi?", "Oʻchirish", isDestructive: true);
            if (Dialogs.ShowModal(confirm, this) != true) return;

            if (p.Id > 0)
            {
                var (netOk, ok, doc, err) = await _api.DeleteProductAsync(p.Id);
                if (netOk && !ok)
                {
                    Toast.Show(err, ToastTone.Warning);
                    return;
                }
                if (!netOk)
                {
                    await _db.EnqueueAdminActionAsync($"/api/pos/products/{p.Id}/delete/", "{}");
                }
                else if (doc.ValueKind == JsonValueKind.Object && doc.TryGetProperty("archived", out var arch) && arch.GetBoolean())
                {
                    p.IsAvailable = false;
                    await _db.UpsertLocalProductAsync(p);
                    RefreshAllProductViews();
                    Toast.Show($"'{p.Name}' oldingi buyurtmalarda qatnashgani uchun Stop-listga oʻtkazildi", ToastTone.Info);
                    return;
                }
            }

            lock (_stateLock) _products.RemoveAll(x => x.Id == p.Id);
            await _db.DeleteLocalProductAsync(p.Id);
            RefreshAllProductViews();
            Toast.Show($"'{p.Name}' oʻchirildi", ToastTone.Success);
        }

        private async void OnManageEditCategoryClick(object sender, RoutedEventArgs e)
        {
            if (sender is Button btn && btn.Tag is Category c)
                await OpenAndSaveCategoryDialogAsync(c);
        }

        private async void OnManageDeleteCategoryClick(object sender, RoutedEventArgs e)
        {
            if (sender is not Button btn || btn.Tag is not Category c) return;
            bool hasProds;
            lock (_stateLock) hasProds = _products.Any(p => p.CategoryId == c.Id || string.Equals(p.CategoryName, c.Name, StringComparison.OrdinalIgnoreCase));
            if (hasProds)
            {
                Toast.Show($"'{c.Name}' guruhida taomlar bor. Avval taomlarni oʻchiring yoki koʻchiring.", ToastTone.Warning);
                return;
            }

            var confirm = new ConfirmDialog("Guruhni oʻchirish", $"'{c.Name}' guruhini oʻchirasizmi?", "Oʻchirish", isDestructive: true);
            if (Dialogs.ShowModal(confirm, this) != true) return;

            if (c.Id > 0)
            {
                var (netOk, ok, _, err) = await _api.DeleteCategoryAsync(c.Id);
                if (netOk && !ok)
                {
                    Toast.Show(err, ToastTone.Warning);
                    return;
                }
                if (!netOk)
                    await _db.EnqueueAdminActionAsync($"/api/pos/categories/{c.Id}/delete/", "{}");
            }

            lock (_stateLock) _categories.RemoveAll(x => x.Id == c.Id);
            await _db.DeleteLocalCategoryAsync(c.Id);
            RefreshAllProductViews();
            Toast.Show($"'{c.Name}' guruhi oʻchirildi", ToastTone.Success);
        }

        private async void OnManageEditStaffClick(object sender, RoutedEventArgs e)
        {
            if (sender is Button btn && btn.Tag is StaffAccount s)
                await OpenAndSaveStaffDialogAsync(s);
        }

        private async void OnManageToggleStaffClick(object sender, RoutedEventArgs e)
        {
            if (sender is not Button btn || btn.Tag is not StaffAccount s) return;
            if (s.Id > 0)
            {
                var (netOk, ok, _, err) = await _api.ToggleStaffAsync(s.Role, s.Id);
                if (netOk && !ok)
                {
                    Toast.Show(err, ToastTone.Warning);
                    return;
                }
                if (!netOk)
                    await _db.EnqueueAdminActionAsync($"/api/pos/staff/{s.Role}/{s.Id}/toggle/", "{}");
            }

            lock (_stateLock) s.IsActive = !s.IsActive;
            await _db.ToggleLocalStaffAsync(s.Role, s.Id);
            RenderManageTab();
            Toast.Show($"{s.Name}: {(s.IsActive ? "Faol" : "Nofaol")}", ToastTone.Info);
        }

        private async void OnManageDeleteStaffClick(object sender, RoutedEventArgs e)
        {
            if (sender is not Button btn || btn.Tag is not StaffAccount s) return;
            var confirm = new ConfirmDialog("Xodimni oʻchirish", $"'{s.Name}' ({s.RoleLabel}) ni oʻchirasizmi?", "Oʻchirish", isDestructive: true);
            if (Dialogs.ShowModal(confirm, this) != true) return;

            if (s.Id > 0)
            {
                var (netOk, ok, _, err) = await _api.DeleteStaffAsync(s.Role, s.Id);
                if (netOk && !ok)
                {
                    Toast.Show(err, ToastTone.Warning);
                    return;
                }
                if (!netOk)
                    await _db.EnqueueAdminActionAsync($"/api/pos/staff/{s.Role}/{s.Id}/delete/", "{}");
            }

            lock (_stateLock) _staffAccounts.RemoveAll(x => x.Role == s.Role && x.Id == s.Id);
            await _db.DeleteLocalStaffAsync(s.Role, s.Id);
            RenderManageTab();
            Toast.Show($"'{s.Name}' oʻchirildi", ToastTone.Success);
        }

        private async void OnManageEditTableClick(object sender, RoutedEventArgs e)
        {
            if (sender is Button btn && btn.Tag is RestaurantTable t)
                await OpenAndSaveTableDialogAsync(t);
        }

        private async void OnManageDeleteTableClick(object sender, RoutedEventArgs e)
        {
            if (sender is not Button btn || btn.Tag is not RestaurantTable t) return;
            if (t.IsOccupied || t.ActiveOrder != null)
            {
                Toast.Show($"Stol #{t.Number} hozir band! Avval buyurtmani yoping.", ToastTone.Warning);
                return;
            }

            var confirm = new ConfirmDialog("Stolni oʻchirish", $"Stol #{t.Number} ({t.Name}) ni oʻchirasizmi?", "Oʻchirish", isDestructive: true);
            if (Dialogs.ShowModal(confirm, this) != true) return;

            if (t.Id > 0)
            {
                var (netOk, ok, _, err) = await _api.DeleteTableAsync(t.Id);
                if (netOk && !ok)
                {
                    Toast.Show(err, ToastTone.Warning);
                    return;
                }
                if (!netOk)
                    await _db.EnqueueAdminActionAsync($"/api/pos/tables/{t.Id}/delete/", "{}");
            }

            lock (_stateLock) _tables.RemoveAll(x => x.Number == t.Number);
            await _db.DeleteLocalTableByNumberAsync(t.Number);
            RenderTables();
            RenderManageTab();
            Toast.Show($"Stol #{t.Number} oʻchirildi", ToastTone.Success);
        }

        private async Task OpenAndSaveCategoryDialogAsync(Category? existing)
        {
            var dlg = new CategoryEditDialog(existing);
            if (Dialogs.ShowModal(dlg, this) != true) return;

            var payload = new
            {
                id = dlg.CategoryId > 0 ? (int?)dlg.CategoryId : null,
                name = dlg.CategoryName,
                department = dlg.SelectedDepartment,
                description = dlg.CategoryDescription,
                is_active = dlg.IsCategoryActive,
            };

            var (netOk, ok, serverCat, err) = await _api.SaveCategoryAsync(payload);
            if (netOk && !ok)
            {
                Toast.Show(err, ToastTone.Warning);
                return;
            }

            var saved = serverCat ?? new Category
            {
                Id = dlg.CategoryId,
                Name = dlg.CategoryName,
                Department = dlg.SelectedDepartment,
                Description = dlg.CategoryDescription,
                IsActive = dlg.IsCategoryActive,
            };

            if (!netOk)
            {
                await _db.EnqueueAdminActionAsync("/api/pos/categories/save/", JsonSerializer.Serialize(payload));
            }

            await _db.UpsertLocalCategoryAsync(saved);
            lock (_stateLock)
            {
                var idx = _categories.FindIndex(x => (saved.Id != 0 && x.Id == saved.Id) || string.Equals(x.Name, saved.Name, StringComparison.OrdinalIgnoreCase));
                if (idx >= 0) _categories[idx] = saved;
                else _categories.Add(saved);
            }

            RefreshAllProductViews();
            if (netOk) _syncEngine.TriggerImmediateSync();
            Toast.Show($"'{saved.Name}' guruhi saqlandi", ToastTone.Success);
        }

        private async Task OpenAndSaveProductDialogAsync(Product? existing)
        {
            List<Category> catsSnap;
            lock (_stateLock) catsSnap = _categories.ToList();
            if (catsSnap.Count == 0)
            {
                Toast.Show("Avval Guruhlar boʻlimida kamida bitta guruh yarating", ToastTone.Warning);
                return;
            }

            var dlg = new ProductEditDialog(catsSnap, existing);
            if (Dialogs.ShowModal(dlg, this) != true) return;

            var cat = dlg.SelectedCategory!;
            var payload = new
            {
                id = dlg.ProductId > 0 ? (int?)dlg.ProductId : null,
                category_id = cat.Id > 0 ? (int?)cat.Id : null,
                category_name = cat.Name,
                name = dlg.ProductName,
                price = dlg.ProductPrice,
                description = dlg.ProductDescription,
                is_available = dlg.IsProductAvailable,
                image_base64 = dlg.SelectedImageBase64,
                image_filename = dlg.SelectedImageFilename,
            };

            var (netOk, ok, serverProd, err) = await _api.SaveProductAsync(payload);
            if (netOk && !ok)
            {
                Toast.Show(err, ToastTone.Warning);
                return;
            }

            var saved = serverProd ?? new Product
            {
                Id = dlg.ProductId,
                Name = dlg.ProductName,
                Price = dlg.ProductPrice,
                CategoryId = cat.Id,
                CategoryName = cat.Name,
                Department = cat.Department,
                Description = dlg.ProductDescription,
                IsAvailable = dlg.IsProductAvailable,
                ImageUrl = existing?.ImageUrl,
            };

            if (!netOk)
            {
                await _db.EnqueueAdminActionAsync("/api/pos/products/save/", JsonSerializer.Serialize(payload));
            }

            await _db.UpsertLocalProductAsync(saved);
            lock (_stateLock)
            {
                var idx = _products.FindIndex(x => (saved.Id != 0 && x.Id == saved.Id) || string.Equals(x.Name, saved.Name, StringComparison.OrdinalIgnoreCase));
                if (idx >= 0) _products[idx] = saved;
                else _products.Add(saved);
                _productTileMap.Clear();
            }

            RefreshAllProductViews();
            if (netOk) _syncEngine.TriggerImmediateSync();
            Toast.Show($"'{saved.Name}' saqlandi", ToastTone.Success);
        }

        private async Task OpenAndSaveStaffDialogAsync(StaffAccount? existing)
        {
            var dlg = new StaffEditDialog(existing);
            if (Dialogs.ShowModal(dlg, this) != true) return;

            var payload = new
            {
                id = dlg.StaffId > 0 ? (int?)dlg.StaffId : null,
                role = dlg.SelectedRole,
                name = dlg.StaffName,
                phone = dlg.StaffPhone,
                pin_code = dlg.StaffPin,
                vehicle_info = dlg.StaffVehicle,
                is_active = dlg.IsStaffActive,
            };

            var (netOk, ok, serverStaff, err) = await _api.SaveStaffAsync(payload);
            if (netOk && !ok)
            {
                Toast.Show(err, ToastTone.Warning);
                return;
            }

            var saved = serverStaff ?? new StaffAccount
            {
                Id = dlg.StaffId,
                Role = dlg.SelectedRole,
                Name = dlg.StaffName,
                Phone = dlg.StaffPhone,
                VehicleInfo = dlg.StaffVehicle,
                IsActive = dlg.IsStaffActive,
                PinHash = LocalDatabase.ComputeSha256Hex(string.IsNullOrWhiteSpace(dlg.StaffPin) ? "1234" : dlg.StaffPin),
            };

            if (!netOk)
            {
                await _db.EnqueueAdminActionAsync("/api/pos/staff/save/", JsonSerializer.Serialize(payload));
            }

            await _db.UpsertLocalStaffAsync(saved, string.IsNullOrWhiteSpace(dlg.StaffPin) ? null : dlg.StaffPin);
            lock (_stateLock)
            {
                var idx = _staffAccounts.FindIndex(x => x.Role == saved.Role && ((saved.Id != 0 && x.Id == saved.Id) || LocalDatabase.NormalizePhoneLast9(x.Phone) == LocalDatabase.NormalizePhoneLast9(saved.Phone)));
                if (idx >= 0) _staffAccounts[idx] = saved;
                else _staffAccounts.Add(saved);
            }

            RenderManageTab();
            if (netOk) _syncEngine.TriggerImmediateSync();
            Toast.Show($"'{saved.Name}' ({saved.RoleLabel}) saqlandi", ToastTone.Success);
        }

        private async Task OpenAndSaveTableDialogAsync(RestaurantTable? existing)
        {
            int nextNum = 13;
            lock (_stateLock)
            {
                if (_tables.Count > 0) nextNum = _tables.Max(t => t.Number) + 1;
            }
            var dlg = new TableEditDialog(existing, nextNum);
            if (Dialogs.ShowModal(dlg, this) != true) return;

            var payload = new
            {
                id = dlg.TableId > 0 ? (int?)dlg.TableId : null,
                number = dlg.TableNumber,
                name = dlg.TableName,
                capacity = dlg.TableCapacity,
                is_active = dlg.IsTableActive,
            };

            var (netOk, ok, serverTbl, err) = await _api.SaveTableAsync(payload);
            if (netOk && !ok)
            {
                Toast.Show(err, ToastTone.Warning);
                return;
            }

            var saved = serverTbl ?? new RestaurantTable
            {
                Id = dlg.TableId,
                Number = dlg.TableNumber,
                Name = dlg.TableName,
                Capacity = dlg.TableCapacity,
                IsActive = dlg.IsTableActive,
                Status = "empty",
            };
            AssignTableZones(new List<RestaurantTable> { saved });

            if (!netOk)
            {
                await _db.EnqueueAdminActionAsync("/api/pos/tables/save/", JsonSerializer.Serialize(payload));
            }

            await _db.SaveTableStateAsync(saved);
            lock (_stateLock)
            {
                var idx = _tables.FindIndex(x => (saved.Id > 0 && x.Id == saved.Id) || x.Number == saved.Number);
                if (idx >= 0)
                {
                    saved.ActiveOrder = _tables[idx].ActiveOrder;
                    saved.ActiveCall = _tables[idx].ActiveCall;
                    saved.IsOccupied = _tables[idx].IsOccupied;
                    saved.Status = _tables[idx].Status;
                    _tables[idx] = saved;
                }
                else
                {
                    _tables.Add(saved);
                    _tables = _tables.OrderBy(t => t.Number).ToList();
                }
            }

            RenderTables();
            RenderManageTab();
            if (netOk) _syncEngine.TriggerImmediateSync();
            Toast.Show($"Stol #{saved.Number} ({saved.Name}) saqlandi", ToastTone.Success);
        }

        private void RefreshAllProductViews()
        {
            RenderCategories();
            RenderProducts(ProductSearchBox?.Text);
            RenderStopList(StopListSearchBox?.Text);
            RenderManageTab();
        }
    }
}
