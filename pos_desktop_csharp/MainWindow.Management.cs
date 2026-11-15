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
using System.Windows.Media.Imaging;
using DilkashPos.Data;
using DilkashPos.Models;
using DilkashPos.Services;
using DilkashPos.Utils;
using DilkashPos.ViewModels;
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
        public BitmapImage? Thumbnail => ImageCacheService.LoadBitmap(Model.ImageLocalPath, Model.ImageUrl, ImageCacheService.ActiveBaseUrl);
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
        public string ParentName { get; init; } = "";
        public string Name => Model.Name;
        public string DisplayTitle => string.IsNullOrWhiteSpace(ParentName) ? Model.Name : $"{ParentName} › {Model.Name}";
        public string Description => string.IsNullOrWhiteSpace(Model.Description) ? "Taomlar guruhi" : Model.Description;
        public string DepartmentLabel => ManageProductRow.GetDeptDisplay(Model.Department);
        public string ProductsCountText => $"{Model.ProductsCount} ta taom";
        public string StatusText => Model.IsActive ? "Faol" : "Nofaol";
    }

    public class ManageHallRow
    {
        public Hall Model { get; init; } = new();
        public string Name => Model.Name;
        public string Description => string.IsNullOrWhiteSpace(Model.Description) ? "Restoran zali" : Model.Description;
        public string TablesCountText => $"{Model.TablesCount} ta stol";
        public string SortOrderText => $"Tartib: #{Model.SortOrder}";
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
        private readonly ObservableCollection<ManageHallRow> _manageHalls = new();
        private readonly ObservableCollection<ManageHallRow> _settingsHalls = new();

        private void InitializeManagementLists()
        {
            ManageProductsItemsControl.ItemsSource = _manageProducts;
            ManageCategoriesItemsControl.ItemsSource = _manageCategories;
            ManageStaffItemsControl.ItemsSource = _manageStaff;
            ManageTablesItemsControl.ItemsSource = _manageTables;
            ManageHallsItemsControl.ItemsSource = _manageHalls;
            SettingsHallsItemsControl.ItemsSource = _settingsHalls;
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
            ManageHallsItemsControl.Visibility = _activeManageSubTab == "halls" ? Visibility.Visible : Visibility.Collapsed;

            ManageAddBtnText.Text = _activeManageSubTab switch
            {
                "categories" => "Guruh qoʻshish",
                "staff" => "Xodim qoʻshish",
                "tables" => "Stol qoʻshish",
                "halls" => "Zal qoʻshish",
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
                var byId = catSnap.ToDictionary(x => x.Id, x => x.Name);
                foreach (var c in catSnap)
                {
                    if (!string.IsNullOrEmpty(q) && !c.Name.Contains(q, StringComparison.OrdinalIgnoreCase))
                        continue;
                    c.ProductsCount = prodSnap.Count(p => p.CategoryId == c.Id || string.Equals(p.CategoryName, c.Name, StringComparison.OrdinalIgnoreCase));
                    string parentName = (c.ParentId.HasValue && byId.TryGetValue(c.ParentId.Value, out var pn)) ? pn : "";
                    _manageCategories.Add(new ManageCategoryRow { Model = c, ParentName = parentName });
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
                        !t.Zone.Contains(q, StringComparison.OrdinalIgnoreCase) &&
                        !t.Number.ToString().Contains(q, StringComparison.OrdinalIgnoreCase))
                        continue;
                    _manageTables.Add(new ManageTableRow { Model = t });
                }
            }
            else if (_activeManageSubTab == "halls")
            {
                _manageHalls.Clear();
                List<Hall> hSnap;
                List<RestaurantTable> tSnap;
                lock (_stateLock)
                {
                    hSnap = _halls.OrderBy(h => h.SortOrder).ThenBy(h => h.Id).ToList();
                    tSnap = _tables.ToList();
                }
                foreach (var h in hSnap)
                {
                    if (!string.IsNullOrEmpty(q) && !h.Name.Contains(q, StringComparison.OrdinalIgnoreCase))
                        continue;
                    h.TablesCount = tSnap.Count(t => t.HallId == h.Id || string.Equals(t.Zone, h.Name, StringComparison.OrdinalIgnoreCase));
                    _manageHalls.Add(new ManageHallRow { Model = h });
                }
            }
            RenderSettingsHallsList();
        }

        private void RenderSettingsHallsList()
        {
            if (SettingsHallsItemsControl == null) return;
            _settingsHalls.Clear();
            List<Hall> hSnap;
            List<RestaurantTable> tSnap;
            lock (_stateLock)
            {
                hSnap = _halls.OrderBy(h => h.SortOrder).ThenBy(h => h.Id).ToList();
                tSnap = _tables.ToList();
            }
            foreach (var h in hSnap)
            {
                h.TablesCount = tSnap.Count(t => t.HallId == h.Id || string.Equals(t.Zone, h.Name, StringComparison.OrdinalIgnoreCase));
                _settingsHalls.Add(new ManageHallRow { Model = h });
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
                case "halls":
                    await OpenAndSaveHallDialogAsync(null);
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

        private async Task<(bool Proceed, JsonElement Doc)> TryConfirmAndDeleteAsync(
            string title,
            string message,
            int remoteId,
            Func<Task<(bool NetworkOk, bool Success, JsonElement Doc, string Error)>> callApi,
            string offlineEndpoint)
        {
            var confirm = new ConfirmDialog(title, message, "Oʻchirish", isDestructive: true);
            if (Dialogs.ShowModal(confirm, this) != true)
                return (false, default);

            if (remoteId > 0)
            {
                var (netOk, ok, doc, err) = await callApi();
                if (netOk && !ok)
                {
                    Toast.Show(err, ToastTone.Warning);
                    return (false, doc);
                }
                if (!netOk)
                    await _db.EnqueueAdminActionAsync(offlineEndpoint, "{}");
                return (true, doc);
            }
            return (true, default);
        }

        private async void OnManageDeleteProductClick(object sender, RoutedEventArgs e)
        {
            if (sender is not Button btn || btn.Tag is not Product p) return;
            var (proceed, doc) = await TryConfirmAndDeleteAsync(
                "Taomni oʻchirish",
                $"'{p.Name}' taomini menyudan oʻchirasizmi?",
                p.Id,
                () => _api.DeleteProductAsync(p.Id),
                $"/api/pos/products/{p.Id}/delete/");
            if (!proceed) return;

            if (doc.ValueKind == JsonValueKind.Object && doc.TryGetProperty("archived", out var arch) && arch.GetBoolean())
            {
                p.IsAvailable = false;
                await _db.UpsertLocalProductAsync(p);
                RefreshAllProductViews();
                Toast.Show($"'{p.Name}' oldingi buyurtmalarda qatnashgani uchun Stop-listga oʻtkazildi", ToastTone.Info);
                return;
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

            var (proceed, _) = await TryConfirmAndDeleteAsync(
                "Guruhni oʻchirish",
                $"'{c.Name}' guruhini oʻchirasizmi?",
                c.Id,
                () => _api.DeleteCategoryAsync(c.Id),
                $"/api/pos/categories/{c.Id}/delete/");
            if (!proceed) return;

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
            var (proceed, _) = await TryConfirmAndDeleteAsync(
                "Xodimni oʻchirish",
                $"'{s.Name}' ({s.RoleLabel}) ni oʻchirasizmi?",
                s.Id,
                () => _api.DeleteStaffAsync(s.Role, s.Id),
                $"/api/pos/staff/{s.Role}/{s.Id}/delete/");
            if (!proceed) return;

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

            var (proceed, _) = await TryConfirmAndDeleteAsync(
                "Stolni oʻchirish",
                $"Stol #{t.Number} ({t.Name}) ni oʻchirasizmi?",
                t.Id,
                () => _api.DeleteTableAsync(t.Id),
                $"/api/pos/tables/{t.Id}/delete/");
            if (!proceed) return;

            lock (_stateLock) _tables.RemoveAll(x => x.Number == t.Number);
            await _db.DeleteLocalTableByNumberAsync(t.Number);
            RenderTables();
            RenderManageTab();
            Toast.Show($"Stol #{t.Number} oʻchirildi", ToastTone.Success);
        }

        private async Task OpenAndSaveCategoryDialogAsync(Category? existing)
        {
            List<Category> catsSnap;
            lock (_stateLock) catsSnap = _categories.ToList();
            var dlg = new CategoryEditDialog(existing, catsSnap);
            if (Dialogs.ShowModal(dlg, this) != true) return;

            var payload = new
            {
                id = dlg.CategoryId > 0 ? (int?)dlg.CategoryId : null,
                name = dlg.CategoryName,
                parent_id = dlg.SelectedParentId,
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
                ParentId = dlg.SelectedParentId,
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
                remove_image = dlg.RemoveImage,
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
                ImageUrl = dlg.RemoveImage ? null : existing?.ImageUrl,
                ImageLocalPath = dlg.RemoveImage ? null : existing?.ImageLocalPath,
                ImageHash = dlg.RemoveImage ? null : existing?.ImageHash,
            };

            if (!netOk)
            {
                await _db.EnqueueAdminActionAsync("/api/pos/products/save/", JsonSerializer.Serialize(payload));
            }

            int localId = await _db.UpsertLocalProductAsync(saved, dlg.SelectedImageBytes);
            saved.Id = localId;

            if (dlg.SelectedImageBytes != null && dlg.SelectedImageBytes.Length > 0)
            {
                var (locPath, imgHash) = ImageCacheService.SaveBytesToCache(saved.Id, dlg.SelectedImageBytes, saved.ImageHash);
                saved.ImageLocalPath = locPath;
                if (string.IsNullOrWhiteSpace(saved.ImageHash)) saved.ImageHash = imgHash;
                await _db.UpdateProductImageCacheAsync(saved.Id, locPath, saved.ImageHash, dlg.SelectedImageBytes);
            }
            else if (dlg.RemoveImage)
            {
                saved.ImageUrl = null;
                saved.ImageLocalPath = null;
                saved.ImageHash = null;
                await _db.UpdateProductImageCacheAsync(saved.Id, null, null, null);
            }

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
            List<Hall> hallsSnap;
            lock (_stateLock)
            {
                if (_tables.Count > 0) nextNum = _tables.Max(t => t.Number) + 1;
                hallsSnap = _halls.OrderBy(h => h.SortOrder).ThenBy(h => h.Id).ToList();
            }
            var dlg = new TableEditDialog(existing, nextNum, hallsSnap);
            if (Dialogs.ShowModal(dlg, this) != true) return;

            var chosenHall = dlg.SelectedHall;
            string zoneName = chosenHall?.Name ?? (existing?.Zone ?? "Zal");
            var payload = new
            {
                id = dlg.TableId > 0 ? (int?)dlg.TableId : null,
                number = dlg.TableNumber,
                name = dlg.TableName,
                capacity = dlg.TableCapacity,
                hall_id = chosenHall?.Id > 0 ? (int?)chosenHall.Id : null,
                zone = zoneName,
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
                HallId = chosenHall?.Id,
                Zone = zoneName,
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

        private async void OnAddHallClick(object sender, RoutedEventArgs e)
        {
            await OpenAndSaveHallDialogAsync(null);
        }

        private async void OnManageEditHallClick(object sender, RoutedEventArgs e)
        {
            if (sender is Button btn && btn.Tag is Hall h)
                await OpenAndSaveHallDialogAsync(h);
        }

        private async void OnManageDeleteHallClick(object sender, RoutedEventArgs e)
        {
            if (sender is not Button btn || btn.Tag is not Hall h) return;
            bool hasTables;
            lock (_stateLock) hasTables = _tables.Any(t => t.HallId == h.Id || string.Equals(t.Zone, h.Name, StringComparison.OrdinalIgnoreCase));
            if (hasTables)
            {
                Toast.Show($"'{h.Name}' zalida stollar mavjud. Avval stollarni boshqa zalga oʻtkazing.", ToastTone.Warning);
                return;
            }

            var (proceed, _) = await TryConfirmAndDeleteAsync(
                "Zalni oʻchirish",
                $"'{h.Name}' zalini oʻchirasizmi?",
                h.Id,
                () => _api.DeleteHallAsync(h.Id),
                $"/api/pos/halls/{h.Id}/delete/");
            if (!proceed) return;

            lock (_stateLock) _halls.RemoveAll(x => x.Id == h.Id);
            await _db.DeleteLocalHallAsync(h.Id);
            RenderTables();
            RenderManageTab();
            Toast.Show($"'{h.Name}' zali oʻchirildi", ToastTone.Success);
        }

        private async Task OpenAndSaveHallDialogAsync(Hall? existing)
        {
            int nextOrder = 1;
            lock (_stateLock)
            {
                if (_halls.Count > 0) nextOrder = _halls.Max(h => h.SortOrder) + 1;
            }
            var dlg = new HallEditDialog(existing, nextOrder);
            if (Dialogs.ShowModal(dlg, this) != true) return;

            var payload = new
            {
                id = dlg.HallId > 0 ? (int?)dlg.HallId : null,
                name = dlg.HallName,
                description = dlg.HallDescription,
                sort_order = dlg.HallSortOrder,
                is_active = dlg.IsHallActive,
            };

            var (netOk, ok, serverHall, err) = await _api.SaveHallAsync(payload);
            if (netOk && !ok)
            {
                Toast.Show(err, ToastTone.Warning);
                return;
            }

            var saved = serverHall ?? new Hall
            {
                Id = dlg.HallId,
                Name = dlg.HallName,
                Description = dlg.HallDescription,
                SortOrder = dlg.HallSortOrder,
                IsActive = dlg.IsHallActive,
            };

            if (!netOk)
            {
                await _db.EnqueueAdminActionAsync("/api/pos/halls/save/", JsonSerializer.Serialize(payload));
            }

            saved.Id = await _db.UpsertLocalHallAsync(saved);
            lock (_stateLock)
            {
                if (existing != null && !string.Equals(existing.Name, saved.Name, StringComparison.OrdinalIgnoreCase))
                {
                    foreach (var tbl in _tables.Where(t => t.HallId == saved.Id || string.Equals(t.Zone, existing.Name, StringComparison.OrdinalIgnoreCase)))
                    {
                        tbl.Zone = saved.Name;
                        tbl.HallId = saved.Id;
                    }
                }
                var idx = _halls.FindIndex(x => (saved.Id != 0 && x.Id == saved.Id) || string.Equals(x.Name, saved.Name, StringComparison.OrdinalIgnoreCase));
                if (idx >= 0) _halls[idx] = saved;
                else _halls.Add(saved);
                _halls = _halls.OrderBy(h => h.SortOrder).ThenBy(h => h.Id).ToList();
            }

            RenderTables();
            RenderManageTab();
            if (netOk) _syncEngine.TriggerImmediateSync();
            Toast.Show($"'{saved.Name}' zali saqlandi", ToastTone.Success);
        }

        private async void OnAddPrinterClick(object sender, RoutedEventArgs e)
        {
            await OpenAndSavePrinterDialogAsync(null);
        }

        private async void OnPrinterCardEditClick(object? sender, PrinterCardVM vm)
        {
            await OpenAndSavePrinterDialogAsync(vm.Model);
        }

        private async void OnPrinterCardDeleteClick(object? sender, PrinterCardVM vm)
        {
            var pr = vm.Model;
            var (proceed, _) = await TryConfirmAndDeleteAsync(
                "Printerni oʻchirish",
                $"'{pr.Name}' printerini oʻchirasizmi?",
                pr.Id,
                () => _api.DeletePrinterAsync(pr.Id),
                $"/api/pos/printers/{pr.Id}/delete/");
            if (!proceed) return;

            lock (_stateLock) _printers.RemoveAll(x => x.Id == pr.Id && string.Equals(x.Name, pr.Name, StringComparison.OrdinalIgnoreCase));
            if (pr.Id > 0) await _db.DeleteLocalPrinterAsync(pr.Id);
            SyncPrintersToSettingsDict();
            RebuildPrinterCards();
            if (_api.IsOnline) _syncEngine.TriggerImmediateSync();
            Toast.Show($"'{pr.Name}' printeri oʻchirildi", ToastTone.Success);
        }

        private async Task OpenAndSavePrinterDialogAsync(PosPrinter? existing)
        {
            int nextOrder = 1;
            lock (_stateLock)
            {
                if (_printers.Count > 0) nextOrder = _printers.Max(p => p.SortOrder) + 1;
            }
            var dlg = new PrinterEditDialog(existing, nextOrder);
            if (Dialogs.ShowModal(dlg, this) != true) return;

            var payload = new
            {
                id = dlg.PrinterId > 0 ? (int?)dlg.PrinterId : null,
                name = dlg.PrinterName,
                department = dlg.SelectedDepartment,
                ip_address = dlg.IpAddress,
                port = dlg.Port,
                paper_width = dlg.PaperWidth,
                subtitle = dlg.PrinterSubtitle,
                is_active = dlg.IsPrinterActive,
                sort_order = dlg.SortOrder,
            };

            var (netOk, ok, serverPrinter, err) = await _api.SavePrinterAsync(payload);
            if (netOk && !ok)
            {
                Toast.Show(err, ToastTone.Warning);
                return;
            }

            var saved = serverPrinter ?? new PosPrinter
            {
                Id = dlg.PrinterId,
                Name = dlg.PrinterName,
                Department = dlg.SelectedDepartment,
                IpAddress = dlg.IpAddress,
                Port = dlg.Port,
                PaperWidth = dlg.PaperWidth,
                Subtitle = dlg.PrinterSubtitle,
                IsActive = dlg.IsPrinterActive,
                SortOrder = dlg.SortOrder,
            };

            if (!netOk)
            {
                await _db.EnqueueAdminActionAsync("/api/pos/printers/save/", JsonSerializer.Serialize(payload));
            }

            saved.Id = await _db.UpsertLocalPrinterAsync(saved);
            lock (_stateLock)
            {
                var idx = _printers.FindIndex(x => (saved.Id != 0 && x.Id == saved.Id) || (existing != null && ReferenceEquals(x, existing)));
                if (idx >= 0) _printers[idx] = saved;
                else _printers.Add(saved);
                _printers = _printers.OrderBy(p => p.SortOrder).ThenBy(p => p.Id).ToList();
            }

            SyncPrintersToSettingsDict();
            await _db.SaveFullSettingsLocalAsync(_settings);
            RebuildPrinterCards();
            if (netOk) _syncEngine.TriggerImmediateSync();
            Toast.Show($"'{saved.Name}' printeri saqlandi", ToastTone.Success);
        }

        private void RefreshAllProductViews()
        {
            RenderQuickPosLevel();
            RenderStopList(StopListSearchBox?.Text);
            RenderManageTab();
        }
    }
}
