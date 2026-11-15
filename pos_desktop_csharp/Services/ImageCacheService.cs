using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Security.Cryptography;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using System.Windows.Media.Imaging;
using DilkashPos.Data;
using DilkashPos.Models;

namespace DilkashPos.Services
{
    public static class ImageCacheService
    {
        private static readonly string CacheDir = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "image_cache");
        private static readonly ConcurrentDictionary<string, BitmapImage> BitmapCache = new(StringComparer.OrdinalIgnoreCase);

        public static string? ActiveBaseUrl { get; set; } = "https://dilkash-django-production.up.railway.app";

        static ImageCacheService()
        {
            try
            {
                Directory.CreateDirectory(CacheDir);
            }
            catch { }
        }

        public static string? ResolveUrl(string? urlOrPath, string? baseUrl)
        {
            if (string.IsNullOrWhiteSpace(urlOrPath)) return null;
            var trimmed = urlOrPath.Trim();
            if (trimmed.StartsWith("http://", StringComparison.OrdinalIgnoreCase) ||
                trimmed.StartsWith("https://", StringComparison.OrdinalIgnoreCase))
            {
                return trimmed;
            }
            if (File.Exists(trimmed)) return trimmed;
            if (string.IsNullOrWhiteSpace(baseUrl)) return null;
            return $"{baseUrl.TrimEnd('/')}/{trimmed.TrimStart('/')}";
        }

        public static string ComputeShortHash(string input)
        {
            var bytes = MD5.HashData(Encoding.UTF8.GetBytes(input ?? ""));
            var sb = new StringBuilder(bytes.Length * 2);
            foreach (var b in bytes) sb.Append(b.ToString("x2"));
            return sb.ToString();
        }

        public static string ComputeBytesHash(byte[] data)
        {
            var bytes = MD5.HashData(data);
            var sb = new StringBuilder(bytes.Length * 2);
            foreach (var b in bytes) sb.Append(b.ToString("x2"));
            return sb.ToString();
        }

        public static (string LocalPath, string Hash) SaveBytesToCache(int productId, byte[] bytes, string? hashHint = null)
        {
            Directory.CreateDirectory(CacheDir);
            string hash = !string.IsNullOrWhiteSpace(hashHint) ? SanitizeFilePart(hashHint) : ComputeBytesHash(bytes);
            string path = Path.Combine(CacheDir, $"prod_{productId}_{hash}.img");
            if (!File.Exists(path) || new FileInfo(path).Length != bytes.Length)
            {
                File.WriteAllBytes(path, bytes);
            }
            BitmapCache.TryRemove(path, out _);
            return (path, hash);
        }

        public static async Task<bool> SyncProductImagesAsync(
            List<Product> products,
            ApiService api,
            LocalDatabase db,
            CancellationToken ct = default)
        {
            bool anyUpdated = false;
            using var gate = new SemaphoreSlim(4, 4);

            var tasks = products.Select(async prod =>
            {
                if (ct.IsCancellationRequested) return;

                if (string.IsNullOrWhiteSpace(prod.ImageUrl))
                {
                    if (!string.IsNullOrWhiteSpace(prod.ImageLocalPath))
                    {
                        prod.ImageLocalPath = null;
                        anyUpdated = true;
                    }
                    return;
                }

                string verKey = !string.IsNullOrWhiteSpace(prod.ImageHash)
                    ? SanitizeFilePart(prod.ImageHash)
                    : ComputeShortHash(prod.ImageUrl);
                string expectedPath = Path.Combine(CacheDir, $"prod_{prod.Id}_{verKey}.img");

                if (File.Exists(expectedPath) && new FileInfo(expectedPath).Length > 0)
                {
                    if (!string.Equals(prod.ImageLocalPath, expectedPath, StringComparison.OrdinalIgnoreCase))
                    {
                        prod.ImageLocalPath = expectedPath;
                        anyUpdated = true;
                    }
                    return;
                }

                // 1. Try restoring from SQLite image_blob if file cache was wiped
                try
                {
                    var (dbHash, dbBlob) = await db.GetProductImageBlobAsync(prod.Id);
                    if (dbBlob != null && dbBlob.Length > 0 &&
                        (string.IsNullOrWhiteSpace(prod.ImageHash) || string.Equals(dbHash, prod.ImageHash, StringComparison.OrdinalIgnoreCase)))
                    {
                        var (savedPath, _) = SaveBytesToCache(prod.Id, dbBlob, verKey);
                        prod.ImageLocalPath = savedPath;
                        anyUpdated = true;
                        return;
                    }
                }
                catch { }

                // 2. Download from Django DB / server endpoint
                string? fullUrl = ResolveUrl(prod.ImageUrl, api.BaseUrl);
                if (string.IsNullOrWhiteSpace(fullUrl)) return;

                await gate.WaitAsync(ct);
                try
                {
                    var bytes = await api.DownloadBytesAsync(fullUrl);
                    if (bytes != null && bytes.Length > 0)
                    {
                        var (savedPath, savedHash) = SaveBytesToCache(prod.Id, bytes, verKey);
                        await db.UpdateProductImageCacheAsync(prod.Id, savedPath, string.IsNullOrWhiteSpace(prod.ImageHash) ? savedHash : prod.ImageHash, bytes);
                        prod.ImageLocalPath = savedPath;
                        anyUpdated = true;
                    }
                }
                catch { }
                finally
                {
                    gate.Release();
                }
            });

            await Task.WhenAll(tasks);
            return anyUpdated;
        }

        public static BitmapImage? LoadBitmap(string? localPath, string? remoteUrl = null, string? baseUrl = null)
        {
            if (!string.IsNullOrWhiteSpace(localPath) && File.Exists(localPath))
            {
                if (BitmapCache.TryGetValue(localPath, out var cached))
                {
                    return cached;
                }
                try
                {
                    var bytes = File.ReadAllBytes(localPath);
                    if (bytes.Length > 0)
                    {
                        using var ms = new MemoryStream(bytes);
                        var bmp = new BitmapImage();
                        bmp.BeginInit();
                        bmp.CacheOption = BitmapCacheOption.OnLoad;
                        bmp.StreamSource = ms;
                        bmp.EndInit();
                        bmp.Freeze();
                        BitmapCache[localPath] = bmp;
                        return bmp;
                    }
                }
                catch { }
            }

            var resolved = ResolveUrl(remoteUrl, baseUrl);
            if (!string.IsNullOrWhiteSpace(resolved))
            {
                if (BitmapCache.TryGetValue(resolved, out var cachedRemote))
                {
                    return cachedRemote;
                }
                try
                {
                    var bmp = new BitmapImage();
                    bmp.BeginInit();
                    bmp.UriSource = new Uri(resolved, UriKind.Absolute);
                    bmp.CacheOption = BitmapCacheOption.OnLoad;
                    bmp.EndInit();
                    return bmp;
                }
                catch { }
            }

            return null;
        }

        public static byte[]? GetCachedBytesForProduct(int productId, string? localPath)
        {
            try
            {
                if (!string.IsNullOrWhiteSpace(localPath) && File.Exists(localPath))
                    return File.ReadAllBytes(localPath);

                if (Directory.Exists(CacheDir))
                {
                    var match = Directory.GetFiles(CacheDir, $"prod_{productId}_*.img").FirstOrDefault();
                    if (!string.IsNullOrEmpty(match) && File.Exists(match))
                        return File.ReadAllBytes(match);
                }
            }
            catch { }
            return null;
        }

        private static string SanitizeFilePart(string s)
        {
            var sb = new StringBuilder(s.Length);
            foreach (char ch in s)
            {
                if (char.IsLetterOrDigit(ch) || ch == '_' || ch == '-')
                    sb.Append(ch);
            }
            return sb.Length > 0 ? sb.ToString() : "1";
        }
    }
}
