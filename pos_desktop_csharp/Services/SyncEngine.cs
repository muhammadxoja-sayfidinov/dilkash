using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using DilkashPos.Data;
using DilkashPos.Models;

namespace DilkashPos.Services
{
    public class SyncStatusEventArgs : EventArgs
    {
        public bool IsOnline { get; set; }
        public int PendingOfflineOrdersCount { get; set; }
        public int OnlineOrdersCount { get; set; }
        public DateTime LastSyncTime { get; set; }
    }

    public class SyncEngine : IDisposable
    {
        private readonly ApiService _api;
        private readonly LocalDatabase _db;
        private readonly EscPosPrinterService _printer;
        private readonly PeriodicTimer _timer;
        private readonly CancellationTokenSource _cts = new();
        private readonly SemaphoreSlim _syncLock = new(1, 1);
        private Task? _syncTask;

        public event EventHandler<SyncStatusEventArgs>? SyncStatusUpdated;
        public event EventHandler<List<Order>>? OnlineOrdersReceived;

        public bool IsOnline => _api.IsOnline;
        public int PendingCount { get; private set; }
        public DateTime LastSyncTime { get; private set; } = DateTime.MinValue;

        public SyncEngine(ApiService api, LocalDatabase db, EscPosPrinterService printer)
        {
            _api = api;
            _db = db;
            _printer = printer;
            _timer = new PeriodicTimer(TimeSpan.FromSeconds(3.5));
            Start();
        }

        public void Start()
        {
            _syncTask = Task.Run(async () =>
            {
                while (!_cts.IsCancellationRequested)
                {
                    try
                    {
                        await RunSyncCycleAsync();
                    }
                    catch { }

                    try
                    {
                        await _timer.WaitForNextTickAsync(_cts.Token);
                    }
                    catch (OperationCanceledException)
                    {
                        break;
                    }
                }
            });
        }

        public async Task RunSyncCycleAsync()
        {
            if (!await _syncLock.WaitAsync(0))
            {
                return;
            }
            try
            {
                // 1. Tekshirish: Offline navbatda buyurtmalar bormi?
                var pending = await _db.GetPendingSyncOrdersAsync();
                PendingCount = pending.Count;

                int onlineOrdersCount = 0;

                // 2. Server bilan aloqa bo'lsa
                var bootstrap = await _api.GetBootstrapAsync();
                if (bootstrap != null && bootstrap.Status == "ok")
                {
                    LastSyncTime = DateTime.Now;

                    // A) Lokal keshni yangilash
                    try
                    {
                        await _db.SaveBootstrapCacheAsync(
                            bootstrap.Departments,
                            bootstrap.Categories,
                            bootstrap.Products,
                            bootstrap.Tables
                        );
                    }
                    catch { }

                    // B) Offline buyurtmalarni serverga yuklash
                    if (pending.Count > 0)
                    {
                        var ordersToPush = pending.ConvertAll(p => p.Order);
                        var syncedIds = await _api.PushOfflineOrdersAsync(ordersToPush);
                        if (syncedIds.Count > 0)
                        {
                            await _db.MarkOrdersSyncedAsync(syncedIds);
                            var remaining = await _db.GetPendingSyncOrdersAsync();
                            PendingCount = remaining.Count;
                        }
                    }

                    // C) Online yangi buyurtmalarni olish
                    var onlineOrders = await _api.GetOnlineOrdersAsync();
                    onlineOrdersCount = onlineOrders.Count;
                    OnlineOrdersReceived?.Invoke(this, onlineOrders);
                }

                SyncStatusUpdated?.Invoke(this, new SyncStatusEventArgs
                {
                    IsOnline = _api.IsOnline,
                    PendingOfflineOrdersCount = PendingCount,
                    OnlineOrdersCount = onlineOrdersCount,
                    LastSyncTime = LastSyncTime
                });
            }
            finally
            {
                _syncLock.Release();
            }
        }

        public void Dispose()
        {
            _cts.Cancel();
            _timer.Dispose();
            _cts.Dispose();
            _syncLock.Dispose();
        }
    }
}

