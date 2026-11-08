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
        private static readonly byte[] GsNormalSize = { 0x1D, 0x21, 0x00 };
        private static readonly byte[] GsCutPaper = { 0x1D, 0x56, 0x42, 0x00 };

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
                if (parts.Length > 1 && int.TryParse(parts[1], out int p))
                    port = p;
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
        /// Bo'limlar bo'yicha oshxona/bar/shashlik buyurtma cheki
        /// </summary>
        public async Task<(bool Success, string Message)> PrintDepartmentSlipAsync(Order order, string deptCode, string deptName, string printerIp)
        {
            using var ms = new MemoryStream();
            void Write(byte[] bytes) => ms.Write(bytes, 0, bytes.Length);
            void WriteText(string text)
            {
                var bytes = Encoding.UTF8.GetBytes(text);
                ms.Write(bytes, 0, bytes.Length);
            }

            // Initsializatsiya
            Write(EscInit);
            Write(EscAlignCenter);
            Write(GsDoubleSize);
            Write(EscBoldOn);
            WriteText($"*** {deptName.ToUpper()} ***\n");
            Write(GsNormalSize);
            Write(EscBoldOff);

            WriteText("--------------------------------\n");
            Write(EscAlignLeft);
            WriteText($"Buyurtma: #{order.OrderNumber ?? order.Id.ToString()}\n");
            if (!string.IsNullOrEmpty(order.TableNumber))
                WriteText($"Stol: #{order.TableNumber} (Mehmonlar: {order.GuestsCount})\n");
            else
                WriteText($"Xizmat turi: {order.ServiceType.ToUpper()} (SABOY)\n");

            if (!string.IsNullOrEmpty(order.WaiterName))
                WriteText($"Ofitsiant: {order.WaiterName}\n");

            WriteText($"Vaqt: {DateTime.Now:dd.MM.yyyy HH:mm:ss}\n");
            WriteText("================================\n");

            // Faqat ushbu bo'limga tegishli taomlar
            int count = 0;
            foreach (var item in order.Items)
            {
                if (item.Department.Equals(deptCode, StringComparison.OrdinalIgnoreCase) || deptCode == "kassa")
                {
                    count++;
                    Write(EscBoldOn);
                    WriteText($"{count}. {item.ProductName}\n");
                    Write(EscBoldOff);
                    WriteText($"   {item.Quantity} x {item.Price:N0} = {item.Total:N0} so'm\n");
                }
            }

            WriteText("================================\n");
            if (!string.IsNullOrEmpty(order.Notes))
            {
                Write(EscBoldOn);
                WriteText($"Izoh: {order.Notes}\n");
                Write(EscBoldOff);
            }

            Write(EscAlignCenter);
            WriteText("\nILTIMOS, TEZ VA SIFATLI TAYYORLANG!\n");
            WriteText("\n\n\n\n");
            Write(GsCutPaper);

            return await SendRawBytesAsync(printerIp, ms.ToArray());
        }

        /// <summary>
        /// Kassa uchun to'liq hisob-kitob cheki
        /// </summary>
        public async Task<(bool Success, string Message)> PrintKassaReceiptAsync(Order order, string printerIp, decimal paidCash = 0, decimal paidCard = 0, decimal change = 0)
        {
            using var ms = new MemoryStream();
            void Write(byte[] bytes) => ms.Write(bytes, 0, bytes.Length);
            void WriteText(string text)
            {
                var bytes = Encoding.UTF8.GetBytes(text);
                ms.Write(bytes, 0, bytes.Length);
            }

            Write(EscInit);
            Write(EscAlignCenter);
            Write(GsDoubleSize);
            Write(EscBoldOn);
            WriteText("DILKASH RESTORANI\n");
            Write(GsNormalSize);
            Write(EscBoldOff);
            WriteText("Xush Kelibsiz!\n");
            WriteText("--------------------------------\n");

            Write(EscAlignLeft);
            WriteText($"Chek raqami: #{order.OrderNumber ?? order.Id.ToString()}\n");
            if (!string.IsNullOrEmpty(order.TableNumber))
                WriteText($"Stol: #{order.TableNumber} | Mehmon: {order.GuestsCount}\n");
            else
                WriteText("Xizmat turi: TEZKOR SABOY\n");

            WriteText($"Sana: {DateTime.Now:dd.MM.yyyy HH:mm}\n");
            WriteText("================================\n");

            foreach (var item in order.Items)
            {
                WriteText($"{item.ProductName}\n");
                string line = $"{item.Quantity} dona x {item.Price:N0}";
                string tot = $"{item.Total:N0} so'm";
                int space = Math.Max(1, 32 - line.Length - tot.Length);
                WriteText(line + new string(' ', space) + tot + "\n");
            }

            WriteText("--------------------------------\n");
            Write(EscAlignRight);
            WriteText($"Taomlar: {order.ProductsTotal:N0} so'm\n");
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
                WriteText($"Naqd to'landi: {paidCash:N0} so'm\n");
            if (paidCard > 0)
                WriteText($"Karta orqali: {paidCard:N0} so'm\n");
            if (change > 0)
                WriteText($"Qaytim: {change:N0} so'm\n");

            Write(EscAlignCenter);
            WriteText("\nTashrifingiz uchun rahmat!\n");
            WriteText("Biz yana sizni kutamiz!\n");
            WriteText("\n\n\n\n");
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

