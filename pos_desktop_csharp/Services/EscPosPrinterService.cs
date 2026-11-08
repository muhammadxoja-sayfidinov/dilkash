using System;
using System.IO;
using System.Net.Sockets;
using System.Text;
using System.Threading.Tasks;
using DilkashPos.Models;

namespace DilkashPos.Services
{
    public class EscPosPrinterService
    {
        private static readonly byte[] EscInit = { 0x1B, 0x40 };
        private static readonly byte[] EscAlignLeft = { 0x1B, 0x61, 0x00 };
        private static readonly byte[] EscAlignCenter = { 0x1B, 0x61, 0x01 };
        private static readonly byte[] EscAlignRight = { 0x1B, 0x61, 0x02 };
        private static readonly byte[] EscBoldOn = { 0x1B, 0x45, 0x01 };
        private static readonly byte[] EscBoldOff = { 0x1B, 0x45, 0x00 };
        private static readonly byte[] GsDoubleSize = { 0x1D, 0x21, 0x11 };
        private static readonly byte[] GsDoubleHeight = { 0x1D, 0x21, 0x01 };
        private static readonly byte[] GsNormalSize = { 0x1D, 0x21, 0x00 };
        private static readonly byte[] GsCutPaper = { 0x1D, 0x56, 0x42, 0x00 };

        /// <summary>
        /// Tarmoq printeri bilan aloqani tezkor tekshirish (Ping/Connect check)
        /// </summary>
        public async Task<bool> CheckPrinterConnectivityAsync(string endpoint, int timeoutMs = 700)
        {
            if (string.IsNullOrWhiteSpace(endpoint)) return false;
            string ip = endpoint.Trim();
            int port = 9100;

            if (ip.Contains(':'))
            {
                var parts = ip.Split(':');
                ip = parts[0];
                if (parts.Length > 1 && int.TryParse(parts[1], out int p)) port = p;
            }

            try
            {
                using var client = new TcpClient();
                var connectTask = client.ConnectAsync(ip, port);
                return await Task.WhenAny(connectTask, Task.Delay(timeoutMs)) == connectTask && client.Connected;
            }
            catch
            {
                return false;
            }
        }

        /// <summary>
        /// Tarmoq printeriga (IP:9100) xom ESC/POS baytlarini to'g'ridan-to'g'ri TCP orqali yuborish
        /// </summary>
        public async Task<(bool Success, string Message)> SendRawBytesAsync(string endpoint, byte[] data, int timeoutMs = 1500)
        {
            if (string.IsNullOrWhiteSpace(endpoint))
                return (false, "Printer IP manzili kiritilmagan");

            string ip = endpoint.Trim();
            int port = 9100;

            if (ip.Contains(':'))
            {
                var parts = ip.Split(':');
                ip = parts[0];
                if (parts.Length > 1 && int.TryParse(parts[1], out int p)) port = p;
            }

            try
            {
                using var client = new TcpClient();
                var connectTask = client.ConnectAsync(ip, port);
                if (await Task.WhenAny(connectTask, Task.Delay(timeoutMs)) != connectTask)
                {
                    return (false, $"Printer bilan aloqa vaqti tugadi (Timeout {timeoutMs}ms) - {ip}:{port}");
                }

                using var stream = client.GetStream();
                stream.WriteTimeout = timeoutMs;
                await stream.WriteAsync(data, 0, data.Length);
                await stream.FlushAsync();
                return (true, $"Chek muvaffaqiyatli yuborildi ({ip}:{port})");
            }
            catch (Exception ex)
            {
                return (false, $"Printerga ulanishda xatolik ({ip}:{port}): {ex.Message}");
            }
        }

        /// <summary>
        /// Bo'limlar bo'yicha oshxona/bar/shashlik/somsa/fast-food buyurtma chiptasi
        /// </summary>
        public async Task<(bool Success, string Message)> PrintDepartmentSlipAsync(Order order, string deptCode, string deptName, string printerIp)
        {
            using var ms = new MemoryStream();
            void Write(byte[] bytes) => ms.Write(bytes, 0, bytes.Length);
            void WriteText(string text) => ms.Write(Encoding.UTF8.GetBytes(text));

            Write(EscInit);
            Write(EscAlignCenter);
            Write(GsDoubleSize);
            Write(EscBoldOn);
            WriteText($"*** {deptName.ToUpper()} ***\n");
            Write(GsNormalSize);
            Write(EscBoldOff);

            WriteText("--------------------------------\n");
            Write(EscAlignLeft);
            Write(GsDoubleHeight);
            Write(EscBoldOn);
            if (!string.IsNullOrEmpty(order.TableNumber))
                WriteText($"STOL: #{order.TableNumber}  (Mehmon: {order.GuestsCount})\n");
            else
                WriteText($"TEZKOR SABOY (OLIB KETISH)\n");
            Write(GsNormalSize);
            Write(EscBoldOff);

            WriteText($"Buyurtma: #{order.OrderNumber ?? order.Id.ToString()}\n");
            if (!string.IsNullOrEmpty(order.WaiterName))
                WriteText($"Ofitsiant: {order.WaiterName}\n");

            WriteText($"Vaqt: {DateTime.Now:dd.MM.yyyy HH:mm:ss}\n");
            WriteText("================================\n");

            int count = 0;
            foreach (var item in order.Items)
            {
                if (item.Department.Equals(deptCode, StringComparison.OrdinalIgnoreCase) || deptCode == "kassa")
                {
                    count++;
                    Write(GsDoubleHeight);
                    Write(EscBoldOn);
                    WriteText($"{count}. {item.ProductName}\n");
                    WriteText($"   >>> {item.Quantity} dona <<<\n");
                    Write(GsNormalSize);
                    Write(EscBoldOff);

                    if (!string.IsNullOrWhiteSpace(item.Notes))
                    {
                        WriteText($"   [!] Izoh: {item.Notes}\n");
                    }
                    WriteText("--------------------------------\n");
                }
            }

            if (!string.IsNullOrEmpty(order.Notes))
            {
                Write(EscBoldOn);
                WriteText($"UMUMIY IZOH: {order.Notes}\n");
                Write(EscBoldOff);
                WriteText("================================\n");
            }

            Write(EscAlignCenter);
            WriteText("ILTIMOS, TEZ VA MAZALI TAYYORLANG!\n\n\n\n");
            Write(GsCutPaper);

            return await SendRawBytesAsync(printerIp, ms.ToArray());
        }

        /// <summary>
        /// Stol mijozi uchun oraliq hisob cheki (Pre-chek)
        /// </summary>
        public async Task<(bool Success, string Message)> PrintPreChekAsync(Order order, string printerIp)
        {
            using var ms = new MemoryStream();
            void Write(byte[] bytes) => ms.Write(bytes, 0, bytes.Length);
            void WriteText(string text) => ms.Write(Encoding.UTF8.GetBytes(text));

            Write(EscInit);
            Write(EscAlignCenter);
            Write(GsDoubleSize);
            Write(EscBoldOn);
            WriteText("DILKASH RESTORANI\n");
            Write(GsNormalSize);
            WriteText("HISOB CHIQARTIRISH (PRE-CHEK)\n");
            Write(EscBoldOff);
            WriteText("--------------------------------\n");

            Write(EscAlignLeft);
            Write(EscBoldOn);
            WriteText($"Stol: #{order.TableNumber}  |  Mehmonlar: {order.GuestsCount}\n");
            Write(EscBoldOff);
            if (!string.IsNullOrEmpty(order.WaiterName))
                WriteText($"Ofitsiant: {order.WaiterName}\n");
            WriteText($"Sana: {DateTime.Now:dd.MM.yyyy HH:mm}\n");
            WriteText("================================\n");

            foreach (var item in order.Items)
            {
                WriteText($"{item.ProductName}\n");
                string qtyPrice = $"{item.Quantity} x {item.Price:N0}";
                string tot = $"{item.Total:N0} so'm";
                int space = Math.Max(1, 32 - qtyPrice.Length - tot.Length);
                WriteText(qtyPrice + new string(' ', space) + tot + "\n");
            }

            WriteText("--------------------------------\n");
            Write(EscAlignRight);
            WriteText($"Taomlar summasi: {order.ProductsTotal:N0} so'm\n");
            if (order.DiscountAmount > 0)
                WriteText($"Chegirma ({order.DiscountPercent}%): -{order.DiscountAmount:N0} so'm\n");
            if (order.ServiceFeeAmount > 0)
                WriteText($"Xizmat haqi: {order.ServiceFeeAmount:N0} so'm\n");

            Write(GsDoubleSize);
            Write(EscBoldOn);
            WriteText($"JAMI: {order.TotalAmount:N0} so'm\n");
            Write(GsNormalSize);
            Write(EscBoldOff);

            WriteText("--------------------------------\n");
            Write(EscAlignCenter);
            WriteText("Xizmat haqidan mamnun bo'lsangiz,\nchoychaqa (choy puli) uchun rahmat!\n\n\n\n");
            Write(GsCutPaper);

            return await SendRawBytesAsync(printerIp, ms.ToArray());
        }

        /// <summary>
        /// Kassa uchun to'liq to'lov hisob cheki
        /// </summary>
        public async Task<(bool Success, string Message)> PrintKassaReceiptAsync(Order order, string printerIp, decimal paidCash = 0, decimal paidCard = 0, decimal change = 0)
        {
            using var ms = new MemoryStream();
            void Write(byte[] bytes) => ms.Write(bytes, 0, bytes.Length);
            void WriteText(string text) => ms.Write(Encoding.UTF8.GetBytes(text));

            Write(EscInit);
            Write(EscAlignCenter);
            Write(GsDoubleSize);
            Write(EscBoldOn);
            WriteText("DILKASH RESTORANI\n");
            Write(GsNormalSize);
            Write(EscBoldOff);
            WriteText("FISKAL HISOB CHEKI\n");
            WriteText("--------------------------------\n");

            Write(EscAlignLeft);
            WriteText($"Chek: #{order.OrderNumber ?? order.Id.ToString()}\n");
            if (!string.IsNullOrEmpty(order.TableNumber))
                WriteText($"Stol: #{order.TableNumber} | Mehmon: {order.GuestsCount}\n");
            else
                WriteText("Xizmat turi: TEZKOR SABOY\n");

            if (!string.IsNullOrEmpty(order.WaiterName))
                WriteText($"Kassir/Ofitsiant: {order.WaiterName}\n");

            WriteText($"Sana: {DateTime.Now:dd.MM.yyyy HH:mm:ss}\n");
            WriteText("================================\n");

            foreach (var item in order.Items)
            {
                WriteText($"{item.ProductName}\n");
                string line = $"{item.Quantity} x {item.Price:N0}";
                string tot = $"{item.Total:N0} so'm";
                int space = Math.Max(1, 32 - line.Length - tot.Length);
                WriteText(line + new string(' ', space) + tot + "\n");
            }

            WriteText("--------------------------------\n");
            Write(EscAlignRight);
            WriteText($"Taomlar: {order.ProductsTotal:N0} so'm\n");
            if (order.DiscountAmount > 0)
                WriteText($"Chegirma: -{order.DiscountAmount:N0} so'm\n");
            if (order.ServiceFeeAmount > 0)
                WriteText($"Xizmat haqi: {order.ServiceFeeAmount:N0} so'm\n");

            Write(GsDoubleSize);
            Write(EscBoldOn);
            WriteText($"JAMI: {order.TotalAmount:N0} so'm\n");
            Write(GsNormalSize);
            Write(EscBoldOff);

            WriteText("--------------------------------\n");
            Write(EscAlignLeft);
            WriteText($"To'lov usuli: {order.PaymentMethod.ToUpper()}\n");
            if (paidCash > 0)
                WriteText($"Naqd: {paidCash:N0} so'm\n");
            if (paidCard > 0)
                WriteText($"Karta: {paidCard:N0} so'm\n");
            if (change > 0)
                WriteText($"Qaytim: {change:N0} so'm\n");

            Write(EscAlignCenter);
            WriteText("\nTashrifingiz uchun rahmat!\n");
            WriteText("Dilkash bilan hayot yanada mazali!\n\n\n\n");
            Write(GsCutPaper);

            return await SendRawBytesAsync(printerIp, ms.ToArray());
        }

        /// <summary>
        /// Kassa X-Hisoboti yoki Z-Hisoboti (Smena xulosasi)
        /// </summary>
        public async Task<(bool Success, string Message)> PrintShiftReportAsync(ShiftReport report, bool isZReport, string printerIp)
        {
            using var ms = new MemoryStream();
            void Write(byte[] bytes) => ms.Write(bytes, 0, bytes.Length);
            void WriteText(string text) => ms.Write(Encoding.UTF8.GetBytes(text));

            Write(EscInit);
            Write(EscAlignCenter);
            Write(GsDoubleSize);
            Write(EscBoldOn);
            WriteText(isZReport ? "*** Z-HISOBOT (SMENA YOPILDI) ***\n" : "*** X-HISOBOT (ORALIQ) ***\n");
            Write(GsNormalSize);
            Write(EscBoldOff);
            WriteText("DILKASH RESTORAN KASSASI\n");
            WriteText("--------------------------------\n");

            Write(EscAlignLeft);
            WriteText($"Kassir: {report.CashierName}\n");
            WriteText($"Smena ochildi: {report.OpenedAt:dd.MM.yyyy HH:mm}\n");
            WriteText($"Hisobot vaqti: {DateTime.Now:dd.MM.yyyy HH:mm:ss}\n");
            WriteText("================================\n");

            WriteText($"Jami buyurtmalar: {report.TotalOrdersCount} ta\n");
            WriteText("--------------------------------\n");

            WriteText($"💵 Naqd pul tushumi: {report.CashRevenue:N0} so'm\n");
            WriteText($"💳 Karta/Terminal:   {report.CardRevenue:N0} so'm\n");
            WriteText($"📱 Online/Payme:     {report.OnlineRevenue:N0} so'm\n");
            WriteText("--------------------------------\n");
            WriteText($"🍽 Zaldagi savdo:     {report.DineInRevenue:N0} so'm\n");
            WriteText($"🛍 Saboy savdosi:     {report.TakeawayRevenue:N0} so'm\n");
            WriteText($"💼 Yig'ilgan xizmat: {report.ServiceFeesCollected:N0} so'm\n");
            WriteText($"🏷 Berilgan chegirma: {report.DiscountsGiven:N0} so'm\n");
            WriteText("================================\n");

            Write(GsDoubleSize);
            Write(EscBoldOn);
            Write(EscAlignRight);
            WriteText($"JAMI SAVDO: {report.TotalRevenue:N0} so'm\n");
            Write(GsNormalSize);
            Write(EscBoldOff);

            Write(EscAlignCenter);
            WriteText(isZReport ? "\nKUN MUVAFFARIYATLI YAKUNLANDI!\n\n\n\n" : "\nORALIQ MONITORING MAQSADIDA\n\n\n\n");
            Write(GsCutPaper);

            return await SendRawBytesAsync(printerIp, ms.ToArray());
        }

        /// <summary>
        /// Printer aloqasini tekshirish sinov cheki
        /// </summary>
        public async Task<(bool Success, string Message)> PrintTestSlipAsync(string title, string printerIp)
        {
            using var ms = new MemoryStream();
            void Write(byte[] bytes) => ms.Write(bytes, 0, bytes.Length);
            void WriteText(string text) => ms.Write(Encoding.UTF8.GetBytes(text));

            Write(EscInit);
            Write(EscAlignCenter);
            Write(GsDoubleSize);
            Write(EscBoldOn);
            WriteText("*** SINOV CHEKI ***\n");
            Write(GsNormalSize);
            Write(EscBoldOff);
            WriteText($"{title}\n");
            WriteText("================================\n");
            Write(EscAlignLeft);
            WriteText($"Printer IP: {printerIp}\n");
            WriteText($"Sinov vaqti: {DateTime.Now:dd.MM.yyyy HH:mm:ss}\n");
            WriteText("Tarmoq aloqasi: ALO DARAJADA (OK)\n");
            WriteText("================================\n");
            Write(EscAlignCenter);
            WriteText("DILKASH RESTORAN POS TIZIMI\n\n\n\n");
            Write(GsCutPaper);

            return await SendRawBytesAsync(printerIp, ms.ToArray());
        }
    }
}
