using System;
using System.Collections.Generic;
using System.Linq;
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
        public event EventHandler<BootstrapResponse>? BootstrapSynced;

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

        public void TriggerImmediateSync()
        {
            _ = Task.Run(() => RunSyncCycleAsync(waitIfBusy: true));
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

        public async Task RunSyncCycleAsync(bool waitIfBusy = false)
        {
            if (waitIfBusy)
            {
                if (!await _syncLock.WaitAsync(TimeSpan.FromSeconds(15), _cts.Token))
                    return;
            }
            else if (!await _syncLock.WaitAsync(0))
            {
                return;
            }
            try
            {
                // 1. Offline navbatdagi buyurtma va hal qilingan chaqiruvlarni tekshirish
                var pending = await _db.GetPendingSyncOrdersAsync();
                var dismissedCallIds = await _db.GetPendingCallDismissalsAsync();
                var localCalls = await _db.GetCachedWaiterCallsAsync(includeResolved: false);
                var localBillTables = localCalls
                    .Where(c => c.Id < 0 && (c.Reason.Contains("Hisob", StringComparison.OrdinalIgnoreCase) || c.Reason.Contains("Chek", StringComparison.OrdinalIgnoreCase)))
                    .Select(c => c.TableNumber)
                    .Distinct()
                    .ToList();
                var localBillCallIds = localCalls.Where(c => c.Id < 0).Select(c => c.Id).ToList();

                PendingCount = pending.Count;
                int onlineOrdersCount = 0;

                // 2. AVVAL Offline navbatni Cloud Django ga yuklash (Push before Pull!)
                if (pending.Count > 0 || dismissedCallIds.Count > 0 || localBillTables.Count > 0)
                {
                    var ordersToPush = pending.ConvertAll(p => p.Order);
                    var pushRes = await _api.PushSyncStateAsync(ordersToPush, dismissedCallIds, localBillTables);
                    if (pushRes != null && pushRes.Status == "ok")
                    {
                        if (pushRes.SyncedIds.Count > 0)
                        {
                            await _db.MarkOrdersSyncedAsync(pushRes.SyncedIds);
                        }
                        if (dismissedCallIds.Count > 0)
                        {
                            await _db.MarkCallDismissalsSyncedAsync(dismissedCallIds);
                        }
                        foreach (var lcid in localBillCallIds)
                        {
                            await _db.DismissWaiterCallOfflineAsync(lcid);
                        }
                        var remaining = await _db.GetPendingSyncOrdersAsync();
                        PendingCount = remaining.Count;
                    }
                }

                // 3. KEYIN Cloud Django dan joriy holatni tortib olish (QR buyurtmalar, QR chaqiruvlar, menyu, xodimlar)
                var bootstrap = await _api.GetBootstrapAsync();
                if (bootstrap != null && bootstrap.Status == "ok")
                {
                    LastSyncTime = DateTime.Now;

                    try
                    {
                        var preserveTables = await _db.GetPendingTableNumbersAsync();
                        await _db.SaveBootstrapStateAsync(bootstrap, preserveTables);
                        BootstrapSynced?.Invoke(this, bootstrap);
                    }
                    catch { }

                    // 4. Online / Telegram / Web yetkazish buyurtmalari navbatini olish
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

