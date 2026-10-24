import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/courier_order.dart';
import '../services/staff_api_service.dart';
import '../services/courier_api_service.dart';
import '../theme/staff_theme.dart';
import 'staff_login_screen.dart';

class CourierAccountScreen extends StatefulWidget {
  final CourierUser courier;
  final VoidCallback? onLogout;
  final int completedToday;
  final double earnedToday;
  final double tipsToday;
  final bool initialIsOnline;
  final ValueChanged<bool>? onOnlineChanged;

  const CourierAccountScreen({
    super.key,
    required this.courier,
    this.onLogout,
    this.completedToday = 6,
    this.earnedToday = 120000.0,
    this.tipsToday = 24000.0,
    this.initialIsOnline = true,
    this.onOnlineChanged,
  });

  @override
  State<CourierAccountScreen> createState() => _CourierAccountScreenState();
}

class _CourierAccountScreenState extends State<CourierAccountScreen> {
  late bool _isOnline;
  String _vehicleType = 'scooter'; // 'car', 'scooter', 'bike', 'walk'
  String _vehiclePlate = 'Honda Dio (01 | 777 AAA)';
  String _navApp = 'yandex_navi'; // 'yandex_navi', 'yandex_maps', 'google_maps', 'in_app'
  bool _autoOpenNav = true;
  bool _autoAcceptOrders = false;
  bool _soundAlerts = true;
  bool _vibration = true;
  double _maxRadius = 10.0; // km
  String _selectedLanguage = 'uz'; // 'uz', 'ru', 'en'

  @override
  void initState() {
    super.initState();
    _isOnline = widget.initialIsOnline;
    if (widget.courier.vehicleInfo.isNotEmpty) {
      _vehiclePlate = widget.courier.vehicleInfo;
    }
  }

  void _toggleOnline(bool value) {
    setState(() => _isOnline = value);
    widget.onOnlineChanged?.call(value);
    DilkashFeedback.showInfo(
      context,
      value
          ? 'Smena yoqildi. Yangi buyurtmalar qabul qilinmoqda'
          : 'Smena toʻxtatildi. Dam olish rejimi',
    );
  }

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hisobdan chiqish'),
        content: const Text(
          'Haqiqatan ham smenani yakunlab kuryer hisobidan chiqmoqchimisiz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Bekor qilish'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const StaffLoginScreen()),
                (route) => false,
              );
              widget.onLogout?.call();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: DilkashColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Chiqish'),
          ),
        ],
      ),
    );
  }

  void _showVehicleDialog() {
    final controller = TextEditingController(text: _vehiclePlate);
    String tempType = _vehicleType;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: const Text('Transport Vositasini Sozlash'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Yetkazib berish usulini tanlang:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildVehicleChoice(
                    type: 'car',
                    label: 'Mashina',
                    icon: Icons.directions_car_rounded,
                    isSelected: tempType == 'car',
                    onTap: () => setDlgState(() => tempType = 'car'),
                  ),
                  const SizedBox(width: 8),
                  _buildVehicleChoice(
                    type: 'scooter',
                    label: 'Skuter',
                    icon: Icons.two_wheeler_rounded,
                    isSelected: tempType == 'scooter',
                    onTap: () => setDlgState(() => tempType = 'scooter'),
                  ),
                  const SizedBox(width: 8),
                  _buildVehicleChoice(
                    type: 'bike',
                    label: 'Velo',
                    icon: Icons.pedal_bike_rounded,
                    isSelected: tempType == 'bike',
                    onTap: () => setDlgState(() => tempType = 'bike'),
                  ),
                  const SizedBox(width: 8),
                  _buildVehicleChoice(
                    type: 'walk',
                    label: 'Piyoda',
                    icon: Icons.directions_walk_rounded,
                    isSelected: tempType == 'walk',
                    onTap: () => setDlgState(() => tempType = 'walk'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Model / Davlat raqami:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: 'Masalan: Honda Dio (01 | 777 AAA)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Bekor qilish'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _vehicleType = tempType;
                  if (controller.text.trim().isNotEmpty) {
                    _vehiclePlate = controller.text.trim();
                  }
                });
                Navigator.pop(ctx);
                DilkashFeedback.showSuccess(
                  context,
                  'Transport maʼlumotlari saqlandi',
                );
              },
              child: const Text('Saqlash'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleChoice({
    required String type,
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: DilkashRadii.radiusSm,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? DilkashColors.primary500.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: DilkashRadii.radiusSm,
            border: Border.all(
              color: isSelected ? DilkashColors.primary500 : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 24,
                color: isSelected ? DilkashColors.primary500 : Colors.grey.shade600,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? DilkashColors.primary500 : Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showServerSettingsDialog() {
    final controller = TextEditingController(text: StaffApiService.baseUrl);
    bool isTesting = false;
    String? pingResult;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: const Text('Server Manzili & Aloqa Sinovi'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Django REST API server manzili:',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: 'http://127.0.0.1:8000',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.dns_rounded),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  ActionChip(
                    label: const Text('Localhost (USB)'),
                    onPressed: () => setDlgState(
                        () => controller.text = 'http://127.0.0.1:8000'),
                  ),
                  ActionChip(
                    label: const Text('Wi-Fi IP'),
                    onPressed: () => setDlgState(
                        () => controller.text = 'http://10.40.4.94:8000'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (isTesting)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else if (pingResult != null)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: pingResult!.startsWith('✅')
                        ? DilkashColors.success.withValues(alpha: 0.1)
                        : DilkashColors.error.withValues(alpha: 0.1),
                    borderRadius: DilkashRadii.radiusSm,
                  ),
                  child: Text(
                    pingResult!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: pingResult!.startsWith('✅')
                          ? DilkashColors.success
                          : DilkashColors.error,
                    ),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                setDlgState(() {
                  isTesting = true;
                  pingResult = null;
                });
                final stopwatch = Stopwatch()..start();
                try {
                  StaffApiService.setBaseUrl(controller.text.trim());
                  CourierApiService.setBaseUrl(controller.text.trim());
                  await CourierApiService.fetchAvailableOrders(widget.courier.token);
                  stopwatch.stop();
                  setDlgState(() {
                    isTesting = false;
                    pingResult = '✅ Server bilan aloqa muvaffaqiyatli! (${stopwatch.elapsedMilliseconds} ms)';
                  });
                } catch (e) {
                  stopwatch.stop();
                  setDlgState(() {
                    isTesting = false;
                    pingResult = '❌ Ulanish xatosi: $e';
                  });
                }
              },
              child: const Text('Aloqani sinash'),
            ),
            ElevatedButton(
              onPressed: () {
                final newUrl = controller.text.trim();
                StaffApiService.setBaseUrl(newUrl);
                CourierApiService.setBaseUrl(newUrl);
                Navigator.pop(ctx);
                DilkashFeedback.showSuccess(
                  context,
                  'Server manzili oʻrnatildi: $newUrl',
                );
              },
              child: const Text('Saqlash'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDispatcherCallDialog() async {
    final Uri telUri = Uri.parse('tel:+998712000000');
    if (await canLaunchUrl(telUri)) {
      await launchUrl(telUri);
    } else {
      if (mounted) {
        DilkashFeedback.showInfo(
          context,
          'Dispetcher raqami: +998 (71) 200-00-00',
        );
      }
    }
  }

  void _showCourierGuideSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    DilkashBottomSheet.show(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.menu_book_rounded, color: DilkashColors.primary500),
              const SizedBox(width: 8),
              Text(
                'Dilkash Kuryer Qoʻllanmasi',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: DilkashColors.textPrimary(isDark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildGuideItem(
            '1. Termosomka va Issiqlik Saqlash',
            'Oshxona buyurtmani topshirgach, taomlarni zudlik bilan termosomkaga joylang va fermuarni toʻliq yoping.',
            Icons.shield_outlined,
          ),
          const SizedBox(height: 12),
          _buildGuideItem(
            '2. Mijoz Bilan Muloqot va Madaniyat',
            'Manzilga yetganda xushmuomala boʻling: "Assalomu alaykum, Dilkash restoranidan buyurtmangizni keltirdim. Yoqimli ishtaha!"',
            Icons.sentiment_satisfied_alt_rounded,
          ),
          const SizedBox(height: 12),
          _buildGuideItem(
            '3. Yoʻl Harakati Xavfsizligi',
            'Kaskani har doim taqing. Yoʻlda tezlik meʼyoriga rioya qiling. Sizning xavfsizligingiz har qanday buyurtmadan ustun!',
            Icons.health_and_safety_rounded,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: DilkashColors.primary500,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: DilkashRadii.radiusSm),
              ),
              child: const Text('Tushundim'),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildGuideItem(String title, String desc, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: DilkashColors.primary500.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: DilkashColors.primary500, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: DilkashColors.textPrimary(isDark),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: TextStyle(
                  fontSize: 13,
                  color: DilkashColors.textSecondary(isDark),
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showEarningsBreakdownSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalWeek = widget.earnedToday * 6 + widget.tipsToday * 6;

    DilkashBottomSheet.show(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet_rounded,
                  color: DilkashColors.primary500),
              const SizedBox(width: 8),
              Text(
                'Daromad va Hisob-Kitob Tafsiloti',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: DilkashColors.textPrimary(isDark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildEarningsRow('Bugun yetkazilgan buyurtmalar', '${widget.completedToday} ta'),
          _buildEarningsRow('Standart yetkazish tarifi (20 000 soʻm x ${widget.completedToday})',
              UzbekFormatters.formatCurrency(widget.earnedToday)),
          _buildEarningsRow('Mijozlar bergan choychaqa (Tips)',
              UzbekFormatters.formatCurrency(widget.tipsToday)),
          _buildEarningsRow('Tigʻiz vaqt koeffitsiyenti bonusi', '15 000 soʻm'),
          const Divider(height: 24),
          _buildEarningsRow(
            'Bugungi sof daromad',
            UzbekFormatters.formatCurrency(widget.earnedToday + widget.tipsToday + 15000),
            isBold: true,
            isHighlight: true,
          ),
          _buildEarningsRow(
            'Haftalik kutilayotgan toʻlov',
            UzbekFormatters.formatCurrency(totalWeek),
            isBold: true,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: DilkashColors.primary500.withValues(alpha: 0.08),
              borderRadius: DilkashRadii.radiusSm,
              border: Border.all(color: DilkashColors.primary500.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    color: DilkashColors.primary500, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Toʻlovlar har dushanba kuni kuryer bank kartasiga avtomatik oʻtkaziladi.',
                    style: TextStyle(
                      fontSize: 12,
                      color: DilkashColors.textPrimary(isDark),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: DilkashColors.primary500,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: DilkashRadii.radiusSm),
              ),
              child: const Text('Yopish'),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildEarningsRow(String label, String value,
      {bool isBold = false, bool isHighlight = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
                color: isHighlight
                    ? (isDark ? DilkashColors.primary400 : DilkashColors.primary500)
                    : DilkashColors.textSecondary(isDark),
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
              color: isHighlight
                  ? (isDark ? DilkashColors.primary400 : DilkashColors.primary500)
                  : DilkashColors.textPrimary(isDark),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final initials = widget.courier.name.isNotEmpty
        ? widget.courier.name
            .trim()
            .split(' ')
            .take(2)
            .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
            .join()
        : 'K';

    return Scaffold(
      backgroundColor: DilkashColors.background(isDark),
      appBar: AppBar(
        title: const Text('Kuryer Profili & Sozlamalar'),
        actions: [
          // Shift badge in appbar
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _isOnline
                  ? DilkashColors.success.withValues(alpha: 0.15)
                  : Colors.grey.withValues(alpha: 0.2),
              borderRadius: DilkashRadii.radiusFull,
              border: Border.all(
                color: _isOnline ? DilkashColors.success : Colors.grey,
                width: 1.2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _isOnline ? DilkashColors.success : Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _isOnline ? 'Online' : 'Offline',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _isOnline ? DilkashColors.success : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. HERO PROFILE CARD
            _buildProfileHero(isDark, initials),
            const SizedBox(height: 16),

            // 2. FINANCIAL STATS CARD
            _buildStatsCard(isDark),
            const SizedBox(height: 20),

            // SECTION TITLE: TRANSPORT & DELIVERY
            _buildSectionHeader('TRANSPORT VA YETKAZIB BERISH', isDark),
            const SizedBox(height: 8),
            _buildSettingsCard(
              isDark: isDark,
              children: [
                _buildSettingTile(
                  icon: _getVehicleIcon(_vehicleType),
                  title: 'Yetkazib berish usuli & Vosita',
                  subtitle: '$_vehiclePlate (${_getVehicleLabel(_vehicleType)})',
                  trailing: const Icon(Icons.edit_outlined, size: 20),
                  onTap: _showVehicleDialog,
                  isDark: isDark,
                ),
                const Divider(height: 1),
                _buildSettingTile(
                  icon: Icons.map_outlined,
                  title: 'Asosiy navigatsiya ilovasi',
                  subtitle: _getNavLabel(_navApp),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _showNavAppPicker,
                  isDark: isDark,
                ),
                const Divider(height: 1),
                SwitchListTile.adaptive(
                  value: _autoOpenNav,
                  activeTrackColor: DilkashColors.primary500,
                  secondary: const Icon(Icons.explore_outlined,
                      color: DilkashColors.primary500),
                  title: const Text(
                    'Marshrutni avtomatik ochish',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Buyurtmani qabul qilganda Yandex/Google ochiladi',
                    style: TextStyle(fontSize: 12),
                  ),
                  onChanged: (val) => setState(() => _autoOpenNav = val),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Maksimal xizmat radiusi',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '${_maxRadius.toInt()} km',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: DilkashColors.primary500,
                            ),
                          ),
                        ],
                      ),
                      Slider.adaptive(
                        value: _maxRadius,
                        min: 3.0,
                        max: 25.0,
                        divisions: 22,
                        activeColor: DilkashColors.primary500,
                        onChanged: (val) => setState(() => _maxRadius = val),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // SECTION TITLE: WORK PREFERENCES
            _buildSectionHeader('ISH TARTIBI VA SOZLAMALAR', isDark),
            const SizedBox(height: 8),
            _buildSettingsCard(
              isDark: isDark,
              children: [
                SwitchListTile.adaptive(
                  value: _autoAcceptOrders,
                  activeTrackColor: DilkashColors.primary500,
                  secondary: const Icon(Icons.flash_on_rounded,
                      color: DilkashColors.amber500),
                  title: const Text(
                    'Avtomatik qabul qilish (Tezkor)',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Yangi buyurtmalarni taym-auts hisoblanmasdan olish',
                    style: TextStyle(fontSize: 12),
                  ),
                  onChanged: (val) => setState(() => _autoAcceptOrders = val),
                ),
                const Divider(height: 1),
                SwitchListTile.adaptive(
                  value: _soundAlerts,
                  activeTrackColor: DilkashColors.primary500,
                  secondary: const Icon(Icons.volume_up_outlined,
                      color: DilkashColors.primary500),
                  title: const Text(
                    'Ovozli signal (Baland ovoz)',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Yangi buyurtma tushganda baland signal chalish',
                    style: TextStyle(fontSize: 12),
                  ),
                  onChanged: (val) => setState(() => _soundAlerts = val),
                ),
                const Divider(height: 1),
                SwitchListTile.adaptive(
                  value: _vibration,
                  activeTrackColor: DilkashColors.primary500,
                  secondary: const Icon(Icons.vibration_rounded,
                      color: DilkashColors.primary500),
                  title: const Text(
                    'Vibratsiya (Tebranish)',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  onChanged: (val) => setState(() => _vibration = val),
                ),
                const Divider(height: 1),
                _buildSettingTile(
                  icon: Icons.verified_outlined,
                  title: 'Termosomka holati',
                  subtitle: 'Tasdiqlangan va dezinfeksiya qilingan ✅',
                  trailing: const Icon(Icons.check_circle_rounded,
                      color: DilkashColors.success),
                  onTap: () {
                    DilkashFeedback.showSuccess(
                      context,
                      'Termosomka sanitariya talablariga mos',
                    );
                  },
                  isDark: isDark,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // SECTION TITLE: APP APPEARANCE & SYSTEM
            _buildSectionHeader('ILOVA VA TIZIM SOZLAMALARI', isDark),
            const SizedBox(height: 8),
            _buildSettingsCard(
              isDark: isDark,
              children: [
                _buildSettingTile(
                  icon: isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                  title: 'Tungi rejim / Mavzu',
                  subtitle: _getThemeLabel(),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _showThemePicker,
                  isDark: isDark,
                ),
                const Divider(height: 1),
                _buildSettingTile(
                  icon: Icons.language_rounded,
                  title: 'Ilova tili',
                  subtitle: _getLanguageLabel(_selectedLanguage),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _showLanguagePicker,
                  isDark: isDark,
                ),
                const Divider(height: 1),
                _buildSettingTile(
                  icon: Icons.dns_rounded,
                  title: 'Server manzili (IP / URL)',
                  subtitle: StaffApiService.baseUrl,
                  trailing: const Icon(Icons.tune_rounded, size: 20),
                  onTap: _showServerSettingsDialog,
                  isDark: isDark,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // SECTION TITLE: SUPPORT & SAFETY
            _buildSectionHeader('YORDAM VA XAVFSIZLIK', isDark),
            const SizedBox(height: 8),
            _buildSettingsCard(
              isDark: isDark,
              children: [
                _buildSettingTile(
                  icon: Icons.support_agent_rounded,
                  title: 'Restoran dispetcheriga qoʻngʻiroq',
                  subtitle: '+998 (71) 200-00-00 (Tezkor yordam)',
                  trailing: const Icon(Icons.phone_in_talk_rounded,
                      color: DilkashColors.primary500),
                  onTap: _showDispatcherCallDialog,
                  isDark: isDark,
                ),
                const Divider(height: 1),
                _buildSettingTile(
                  icon: Icons.menu_book_rounded,
                  title: 'Kuryer xavfsizlik qoʻllanmasi',
                  subtitle: 'Gigiyena, xushmuomalalik va yoʻl qoidalari',
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _showCourierGuideSheet,
                  isDark: isDark,
                ),
                const Divider(height: 1),
                _buildSettingTile(
                  icon: Icons.info_outline_rounded,
                  title: 'Ilova versiyasi',
                  subtitle: 'Dilkash Courier v2.4.0 (2026.10 Pro)',
                  trailing: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: DilkashColors.primary500.withValues(alpha: 0.1),
                      borderRadius: DilkashRadii.radiusFull,
                    ),
                    child: const Text(
                      'Yangilangan',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: DilkashColors.primary500,
                      ),
                    ),
                  ),
                  onTap: () {},
                  isDark: isDark,
                ),
              ],
            ),
            const SizedBox(height: 28),

            // 7. LOGOUT BUTTON
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _handleLogout,
                icon: const Icon(Icons.logout_rounded, color: DilkashColors.error),
                label: const Text(
                  'Tizimdan chiqish (Smenani yakunlash)',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: DilkashColors.error,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: DilkashColors.error, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: DilkashRadii.radiusSm),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // --- SUB-WIDGETS ---

  Widget _buildProfileHero(bool isDark, String initials) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? DilkashColors.surfaceDark : Colors.white,
        borderRadius: DilkashRadii.radiusMd,
        boxShadow: DilkashShadows.card(isDark),
        border: Border.all(
          color: isDark ? DilkashColors.borderDark : DilkashColors.borderLight,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: isDark
                        ? DilkashColors.primary400.withValues(alpha: 0.2)
                        : DilkashColors.primary50,
                    child: Text(
                      initials,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: isDark
                            ? DilkashColors.primary400
                            : DilkashColors.primary500,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: _isOnline
                            ? DilkashColors.success
                            : Colors.grey.shade600,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? DilkashColors.surfaceDark : Colors.white,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        _getVehicleIcon(_vehicleType),
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            widget.courier.name,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: DilkashColors.textPrimary(isDark),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.verified_rounded,
                          size: 18,
                          color: DilkashColors.primary500,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.courier.phone,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: DilkashColors.textSecondary(isDark),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark
                                ? DilkashColors.surfaceDarkElevated
                                : Colors.grey.shade100,
                            borderRadius: DilkashRadii.radiusFull,
                          ),
                          child: Text(
                            'ID: #KUR-${widget.courier.id.toString().padLeft(3, '0')}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: DilkashColors.textSecondary(isDark),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Row(
                          children: [
                            Icon(Icons.star_rounded,
                                size: 16, color: DilkashColors.amber500),
                            SizedBox(width: 2),
                            Text(
                              '4.96',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),
          // Online Toggle Switch Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isOnline ? 'Kuryer smenada faol' : 'Smena yakunlangan',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: DilkashColors.textPrimary(isDark),
                    ),
                  ),
                  Text(
                    _isOnline
                        ? 'Yangi buyurtmalar kelib tushmoqda'
                        : 'Buyurtmalar qabul qilinmaydi',
                    style: TextStyle(
                      fontSize: 12,
                      color: DilkashColors.textSecondary(isDark),
                    ),
                  ),
                ],
              ),
              Switch.adaptive(
                value: _isOnline,
                activeTrackColor: DilkashColors.primary500,
                onChanged: _toggleOnline,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? DilkashColors.surfaceDark : Colors.white,
        borderRadius: DilkashRadii.radiusMd,
        boxShadow: DilkashShadows.card(isDark),
        border: Border.all(
          color: isDark ? DilkashColors.borderDark : DilkashColors.borderLight,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.insights_rounded,
                      size: 20, color: DilkashColors.primary500),
                  const SizedBox(width: 8),
                  Text(
                    'Bugungi Koʻrsatkichlar',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: DilkashColors.textPrimary(isDark),
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: _showEarningsBreakdownSheet,
                child: const Text(
                  'Batafsil',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: DilkashColors.primary500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildStatColumn(
                label: 'Yetkazildi',
                value: '${widget.completedToday} ta',
                icon: Icons.check_circle_outline_rounded,
                color: DilkashColors.success,
                isDark: isDark,
              ),
              Container(width: 1, height: 40, color: Colors.grey.withValues(alpha: 0.2)),
              _buildStatColumn(
                label: 'Ishlab topildi',
                value: UzbekFormatters.formatCurrency(widget.earnedToday),
                icon: Icons.payments_outlined,
                color: DilkashColors.primary500,
                isDark: isDark,
              ),
              Container(width: 1, height: 40, color: Colors.grey.withValues(alpha: 0.2)),
              _buildStatColumn(
                label: 'Choychaqa',
                value: UzbekFormatters.formatCurrency(widget.tipsToday),
                icon: Icons.volunteer_activism_outlined,
                color: DilkashColors.amber500,
                isDark: isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: DilkashColors.textPrimary(isDark),
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: DilkashColors.textSecondary(isDark),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
          color: DilkashColors.textSecondary(isDark),
        ),
      ),
    );
  }

  Widget _buildSettingsCard({required bool isDark, required List<Widget> children}) {
    return Material(
      color: isDark ? DilkashColors.surfaceDark : Colors.white,
      borderRadius: DilkashRadii.radiusMd,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: DilkashRadii.radiusMd,
          boxShadow: DilkashShadows.card(isDark),
          border: Border.all(
            color: isDark ? DilkashColors.borderDark : DilkashColors.borderLight,
          ),
        ),
        child: Column(children: children),
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: DilkashColors.primary500.withValues(alpha: 0.1),
          borderRadius: DilkashRadii.radiusSm,
        ),
        child: Icon(icon, color: DilkashColors.primary500, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: DilkashColors.textPrimary(isDark),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: DilkashColors.textSecondary(isDark),
        ),
      ),
      trailing: trailing,
      onTap: onTap,
    );
  }

  // --- HELPERS & MODALS ---

  IconData _getVehicleIcon(String type) {
    switch (type) {
      case 'car':
        return Icons.directions_car_rounded;
      case 'scooter':
        return Icons.two_wheeler_rounded;
      case 'bike':
        return Icons.pedal_bike_rounded;
      case 'walk':
      default:
        return Icons.directions_walk_rounded;
    }
  }

  String _getVehicleLabel(String type) {
    switch (type) {
      case 'car':
        return 'Avtomobil';
      case 'scooter':
        return 'Skuter / Moped';
      case 'bike':
        return 'Velosiped';
      case 'walk':
      default:
        return 'Piyoda';
    }
  }

  String _getNavLabel(String app) {
    switch (app) {
      case 'yandex_navi':
        return 'Yandex Navigator (Tavsiya etiladi)';
      case 'yandex_maps':
        return 'Yandex Xaritalar';
      case 'google_maps':
        return 'Google Maps';
      case 'in_app':
      default:
        return 'Ilova ichki xaritasi (OpenStreetMap)';
    }
  }

  void _showNavAppPicker() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    DilkashBottomSheet.show(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Navigatsiya Ilovasini Tanlang',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: DilkashColors.textPrimary(isDark),
            ),
          ),
          const SizedBox(height: 16),
          _buildNavTile(ctx, 'yandex_navi', 'Yandex Navigator',
              'Ovozli yoʻnaltirish va tirbandliklar nazorati', Icons.navigation_rounded),
          const SizedBox(height: 8),
          _buildNavTile(ctx, 'yandex_maps', 'Yandex Maps',
              'Toshkent va viloyatlar uchun batafsil xaritalar', Icons.map_rounded),
          const SizedBox(height: 8),
          _buildNavTile(ctx, 'google_maps', 'Google Maps',
              'Global Google xaritalari', Icons.pin_drop_rounded),
          const SizedBox(height: 8),
          _buildNavTile(ctx, 'in_app', 'Ilova ichki xaritasi',
              'Tashqi ilovalarsiz toʻgʻridan-toʻgʻri ilovada', Icons.layers_rounded),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildNavTile(
      BuildContext ctx, String key, String title, String subtitle, IconData icon) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    final isSelected = _navApp == key;
    return Material(
      color: isSelected
          ? DilkashColors.primary500.withValues(alpha: 0.1)
          : Colors.transparent,
      borderRadius: DilkashRadii.radiusSm,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: DilkashRadii.radiusSm,
          border: Border.all(
            color: isSelected ? DilkashColors.primary500 : Colors.grey.withValues(alpha: 0.3),
          ),
        ),
        child: ListTile(
          leading: Icon(icon, color: isSelected ? DilkashColors.primary500 : Colors.grey),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              color: DilkashColors.textPrimary(isDark),
            ),
          ),
          subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
          trailing: isSelected
              ? const Icon(Icons.check_circle_rounded, color: DilkashColors.primary500)
              : null,
          onTap: () {
            setState(() => _navApp = key);
            Navigator.pop(ctx);
          },
        ),
      ),
    );
  }

  String _getThemeLabel() {
    switch (StaffThemeController.instance.themeMode) {
      case ThemeMode.light:
        return 'Kunduzgi rejim (Yorugʻ)';
      case ThemeMode.dark:
        return 'Tungi rejim (Qorongʻi)';
      case ThemeMode.system:
        return 'Tizimga mos (Avtomatik)';
    }
  }

  void _showThemePicker() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final current = StaffThemeController.instance.themeMode;
    DilkashBottomSheet.show(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ilova Mavzusini Tanlang',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: DilkashColors.textPrimary(isDark),
            ),
          ),
          const SizedBox(height: 16),
          _buildThemeChoiceTile(
              ctx, ThemeMode.light, 'Kunduzgi rejim (Yorugʻ)', Icons.light_mode_rounded, current),
          const SizedBox(height: 8),
          _buildThemeChoiceTile(
              ctx, ThemeMode.dark, 'Tungi rejim (Qorongʻi)', Icons.dark_mode_rounded, current),
          const SizedBox(height: 8),
          _buildThemeChoiceTile(
              ctx, ThemeMode.system, 'Tizimga mos (Avtomatik)', Icons.brightness_auto_rounded, current),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildThemeChoiceTile(BuildContext ctx, ThemeMode mode, String label,
      IconData icon, ThemeMode current) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    final isSelected = mode == current;
    return Material(
      color: isSelected
          ? DilkashColors.primary500.withValues(alpha: 0.1)
          : Colors.transparent,
      borderRadius: DilkashRadii.radiusSm,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: DilkashRadii.radiusSm,
          border: Border.all(
            color: isSelected ? DilkashColors.primary500 : Colors.grey.withValues(alpha: 0.3),
          ),
        ),
        child: ListTile(
          leading: Icon(icon, color: isSelected ? DilkashColors.primary500 : Colors.grey),
          title: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              color: DilkashColors.textPrimary(isDark),
            ),
          ),
          trailing: isSelected
              ? const Icon(Icons.check_circle_rounded, color: DilkashColors.primary500)
              : null,
          onTap: () {
            setState(() {
              StaffThemeController.instance.setThemeMode(mode);
            });
            Navigator.pop(ctx);
          },
        ),
      ),
    );
  }

  String _getLanguageLabel(String lang) {
    switch (lang) {
      case 'ru':
        return 'Русский язык';
      case 'en':
        return 'English';
      case 'uz':
      default:
        return 'Oʻzbekcha (Lotin)';
    }
  }

  void _showLanguagePicker() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    DilkashBottomSheet.show(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ilova Tilini Tanlang',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: DilkashColors.textPrimary(isDark),
            ),
          ),
          const SizedBox(height: 16),
          _buildLangTile(ctx, 'uz', 'Oʻzbekcha (Lotin)', '🇺🇿'),
          const SizedBox(height: 8),
          _buildLangTile(ctx, 'ru', 'Русский язык', '🇷🇺'),
          const SizedBox(height: 8),
          _buildLangTile(ctx, 'en', 'English', '🇬🇧'),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildLangTile(
      BuildContext ctx, String code, String label, String flag) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    final isSelected = _selectedLanguage == code;
    return Material(
      color: isSelected
          ? DilkashColors.primary500.withValues(alpha: 0.1)
          : Colors.transparent,
      borderRadius: DilkashRadii.radiusSm,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: DilkashRadii.radiusSm,
          border: Border.all(
            color: isSelected ? DilkashColors.primary500 : Colors.grey.withValues(alpha: 0.3),
          ),
        ),
        child: ListTile(
          leading: Text(flag, style: const TextStyle(fontSize: 24)),
          title: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              color: DilkashColors.textPrimary(isDark),
            ),
          ),
          trailing: isSelected
              ? const Icon(Icons.check_circle_rounded, color: DilkashColors.primary500)
              : null,
          onTap: () {
            setState(() => _selectedLanguage = code);
            Navigator.pop(ctx);
            DilkashFeedback.showSuccess(context, '$label tanlandi');
          },
        ),
      ),
    );
  }
}
