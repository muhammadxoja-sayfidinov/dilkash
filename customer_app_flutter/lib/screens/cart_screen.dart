import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:dilkash_design_system/dilkash_design_system.dart';
import '../services/cart_provider.dart';
import '../services/auth_provider.dart';
import '../services/api_service.dart';
import 'order_tracking_screen.dart';

class CartScreen extends StatefulWidget {
  final bool isRootTab;

  const CartScreen({super.key, this.isRootTab = false});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _promoController = TextEditingController();

  String _serviceType = 'delivery'; // 'delivery' or 'pickup'
  String _paymentMethod = 'naqd'; // 'naqd', 'click', 'payme'
  String _deliveryTime = 'asap'; // 'asap' or scheduled
  double _tipAmount = 0.0;
  bool _isSubmitting = false;

  // Real Map coordinates
  double _selectedLat = 41.311081;
  double _selectedLng = 69.240562;

  final List<double> _tipOptions = [0, 5000, 10000, 20000];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.user != null) {
        _nameController.text = auth.user!.fullName;
        _phoneController.text = auth.user!.phone;
        _addressController.text = auth.user!.defaultAddress.isNotEmpty
            ? auth.user!.defaultAddress
            : 'Toshkent sh., Yunusobod 4-mavze';
      } else {
        _nameController.text = 'Mijoz';
        _phoneController.text = '+998 90 123 45 67';
        _addressController.text = 'Toshkent sh., Chilonzor 9-mavze';
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    _promoController.dispose();
    super.dispose();
  }

  Future<void> _submitOrder(CartProvider cart) async {
    if (cart.items.isEmpty) {
      DilkashFeedback.showError(context, 'Savatchangiz boʻsh!');
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final itemsPayload = cart.items
          .map((item) => {
                'dish_id': item.dish.id,
                'product_id': item.dish.id,
                'quantity': item.quantity,
              })
          .toList();

      final res = await ApiService.createOrder(
        customerName: _nameController.text.trim(),
        customerPhone: _phoneController.text.trim(),
        serviceType: _serviceType,
        deliveryAddress: _serviceType == 'delivery' ? _addressController.text.trim() : '',
        latitude: _serviceType == 'delivery' ? _selectedLat : null,
        longitude: _serviceType == 'delivery' ? _selectedLng : null,
        paymentMethod: _paymentMethod,
        tipAmount: _tipAmount,
        notes: _notesController.text.trim(),
        items: itemsPayload,
      );

      final orderId = res['order_id'] ?? res['id'] ?? 0;
      final orderNumber = (res['order_number'] ?? orderId).toString();

      cart.clearCart();
      if (!mounted) return;

      setState(() => _isSubmitting = false);
      DilkashFeedback.showSuccess(context, 'Buyurtmangiz qabul qilindi!');

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OrderTrackingScreen(
            orderId: orderId,
            orderNumber: orderNumber,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        DilkashFeedback.showError(
          context,
          e.toString().replaceAll('Exception: ', ''),
        );
      }
    }
  }

  void _openInteractiveMapPicker() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final MapController pickerMapController = MapController();
    double tempLat = _selectedLat;
    double tempLng = _selectedLng;
    String tempAddress = _addressController.text;
    bool isReverseGeocoding = false;

    final districts = [
      {'name': 'Chilonzor', 'lat': 41.2721, 'lng': 69.2045},
      {'name': 'Yunusobod', 'lat': 41.3650, 'lng': 69.2890},
      {'name': 'Mirobod', 'lat': 41.2980, 'lng': 69.2780},
      {'name': 'Yakkasaroy', 'lat': 41.2840, 'lng': 69.2450},
      {'name': 'Shayxontohur', 'lat': 41.3250, 'lng': 69.2310},
      {'name': 'Mirzo Ulugʻbek', 'lat': 41.3320, 'lng': 69.3240},
    ];

    DilkashBottomSheet.show(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          Future<void> reverseGeocode(double lat, double lng) async {
            setSheetState(() => isReverseGeocoding = true);
            try {
              final url = Uri.parse(
                'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1',
              );
              final response = await http.get(
                url,
                headers: {'User-Agent': 'DilkashRestaurantApp/1.0'},
              );
              if (response.statusCode == 200) {
                final data = jsonDecode(utf8.decode(response.bodyBytes));
                final displayName = data['display_name'] as String?;
                if (displayName != null && displayName.isNotEmpty) {
                  final parts = displayName.split(',');
                  final shortAddr = parts.take(3).join(', ').trim();
                  setSheetState(() {
                    tempAddress = shortAddr;
                    isReverseGeocoding = false;
                  });
                  return;
                }
              }
            } catch (_) {}
            setSheetState(() => isReverseGeocoding = false);
          }

          return SizedBox(
            height: MediaQuery.of(context).size.height * 0.82,
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark ? DilkashColors.surfaceDarkElevated : DilkashColors.primary50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.map_rounded,
                          size: 20,
                          color: isDark ? DilkashColors.primary400 : DilkashColors.primary500,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Manzilni Xaritada Belgilang',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: DilkashColors.textPrimary(isDark),
                              ),
                            ),
                            Text(
                              'Xaritadagi kerakli joyga bosing',
                              style: TextStyle(
                                fontSize: 12,
                                color: DilkashColors.textSecondary(isDark),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),

                // District quick chips
                SizedBox(
                  height: 38,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: districts.length,
                    itemBuilder: (context, idx) {
                      final dist = districts[idx];
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(
                          label: Text(dist['name'] as String),
                          onPressed: () {
                            final lat = dist['lat'] as double;
                            final lng = dist['lng'] as double;
                            setSheetState(() {
                              tempLat = lat;
                              tempLng = lng;
                              tempAddress = 'Toshkent sh., ${dist['name']} tumani';
                            });
                            pickerMapController.move(LatLng(lat, lng), 15.0);
                            reverseGeocode(lat, lng);
                          },
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),

                // Interactive Map View
                Expanded(
                  child: Stack(
                    children: [
                      FlutterMap(
                        mapController: pickerMapController,
                        options: MapOptions(
                          initialCenter: LatLng(tempLat, tempLng),
                          initialZoom: 14.5,
                          onTap: (tapPosition, point) {
                            setSheetState(() {
                              tempLat = point.latitude;
                              tempLng = point.longitude;
                            });
                            reverseGeocode(point.latitude, point.longitude);
                          },
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://a.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                            userAgentPackageName: 'uz.dilkash.customer',
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: LatLng(tempLat, tempLng),
                                width: 50,
                                height: 50,
                                child: const Icon(
                                  Icons.location_on_rounded,
                                  color: Colors.redAccent,
                                  size: 46,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      // Coordinates badge
                      Positioned(
                        top: 12,
                        left: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.75),
                            borderRadius: DilkashRadii.radiusFull,
                          ),
                          child: Text(
                            'GPS: ${tempLat.toStringAsFixed(4)}, ${tempLng.toStringAsFixed(4)}',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Bottom address confirmation card
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                  decoration: BoxDecoration(
                    color: DilkashColors.surface(isDark),
                    border: Border(
                      top: BorderSide(
                        color: isDark ? DilkashColors.borderDark : DilkashColors.borderLight,
                      ),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.place_rounded,
                            color: DilkashColors.primary(isDark),
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: isReverseGeocoding
                                ? Row(
                                    children: [
                                      const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Manzil aniqlanmoqda...',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: DilkashColors.textSecondary(isDark),
                                        ),
                                      ),
                                    ],
                                  )
                                : Text(
                                    tempAddress,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: DilkashColors.textPrimary(isDark),
                                    ),
                                  ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      DilkashButton(
                        label: 'Ushbu manzilni tasdiqlash',
                        leadingIcon: Icons.check_circle_outline_rounded,
                        onPressed: () {
                          setState(() {
                            _selectedLat = tempLat;
                            _selectedLng = tempLng;
                            _addressController.text = tempAddress;
                          });
                          Navigator.pop(ctx);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (cart.items.isEmpty) {
      return Scaffold(
        backgroundColor: DilkashColors.background(isDark),
        appBar: AppBar(
          title: const Text('Savatcha'),
        ),
        body: DilkashEmptyState(
          icon: Icons.shopping_bag_outlined,
          title: 'Savatchangiz hozircha boʻsh',
          message: 'Menyudan xohlagan milliy taom yoki ichimliklarni tanlab, buyurtma bering',
          actionLabel: 'Menyuga oʻtish',
          onAction: () {
            if (widget.isRootTab) {
              // Main navigation will switch to menu
            } else {
              Navigator.pop(context);
            }
          },
        ),
      );
    }

    final deliveryCost = _serviceType == 'delivery' ? 15000.0 : 0.0;
    final finalPayable = cart.totalPrice + deliveryCost + _tipAmount;

    return Scaffold(
      backgroundColor: DilkashColors.background(isDark),
      appBar: AppBar(
        title: const Text('Savatcha va Rasmiylashtirish'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded),
            tooltip: 'Savatni tozalash',
            onPressed: () {
              cart.clearCart();
              DilkashFeedback.showInfo(context, 'Savatcha tozalandi');
            },
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Service Type Selector (Yetkazib berish vs Olib ketish)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark ? DilkashColors.surfaceDarkElevated : const Color(0xFFF1F5F9),
                  borderRadius: DilkashRadii.radiusMd,
                  border: Border.all(
                    color: isDark ? DilkashColors.borderDark : DilkashColors.borderLight,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildServiceTypeTab(
                        isDark,
                        label: 'Yetkazib berish',
                        icon: Icons.delivery_dining_rounded,
                        isSelected: _serviceType == 'delivery',
                        onTap: () => setState(() => _serviceType = 'delivery'),
                      ),
                    ),
                    Expanded(
                      child: _buildServiceTypeTab(
                        isDark,
                        label: 'Olib ketish',
                        icon: Icons.shopping_bag_outlined,
                        isSelected: _serviceType == 'pickup',
                        onTap: () => setState(() => _serviceType = 'pickup'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 2. Order Items List
              Text(
                'Buyurtma tarkibi (${cart.totalCount} ta)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  color: DilkashColors.textPrimary(isDark),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: DilkashColors.surface(isDark),
                  borderRadius: DilkashRadii.radiusLg,
                  border: Border.all(
                    color: isDark ? DilkashColors.borderDark : DilkashColors.borderLight,
                  ),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: cart.items.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    color: isDark ? DilkashColors.borderDark : DilkashColors.borderLight,
                  ),
                  itemBuilder: (context, index) {
                    final item = cart.items[index];
                    return Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          // Thumbnail
                          ClipRRect(
                            borderRadius: DilkashRadii.radiusSm,
                            child: SizedBox(
                              width: 56,
                              height: 56,
                              child: item.dish.imageUrl.isNotEmpty
                                  ? Image.network(
                                      item.dish.imageUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Icon(Icons.restaurant),
                                    )
                                  : const Icon(Icons.restaurant),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Name and details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  UzbekFormatters.fixUzbekApostrophes(item.dish.name),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: DilkashColors.textPrimary(isDark),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${item.selectedPortion}${item.selectedExtras.isNotEmpty ? " • ${item.selectedExtras.join(', ')}" : ""}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: DilkashColors.textSecondary(isDark),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  UzbekFormatters.formatCurrency(item.totalPrice),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? DilkashColors.primary400 : DilkashColors.primary600,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Quantity Stepper
                          DilkashQuantityStepper(
                            value: item.quantity,
                            isCompact: true,
                            onChanged: (newQty) {
                              cart.updateQuantity(item.dish.id, newQty);
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),

              // 3. Delivery Time (Schedule)
              Text(
                'Yetkazish vaqti',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  color: DilkashColors.textPrimary(isDark),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildTimeChip(
                      isDark,
                      label: 'Tezkor (25-35 daq)',
                      isSelected: _deliveryTime == 'asap',
                      onTap: () => setState(() => _deliveryTime = 'asap'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildTimeChip(
                      isDark,
                      label: 'Bugun 19:30 - 20:00',
                      isSelected: _deliveryTime == 'scheduled',
                      onTap: () => setState(() => _deliveryTime = 'scheduled'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 4. Delivery Address & Interactive Map (if delivery)
              if (_serviceType == 'delivery') ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Yetkazib berish manzili',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        color: DilkashColors.textPrimary(isDark),
                      ),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.map_outlined, size: 16),
                      label: const Text('Xaritada tanlash'),
                      onPressed: _openInteractiveMapPicker,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                DilkashTextField(
                  controller: _addressController,
                  hintText: 'Koʻcha, uy, xonadon raqami...',
                  prefixIcon: Icons.location_on_outlined,
                ),
                const SizedBox(height: 10),

                // Mini Map Preview
                Container(
                  height: 140,
                  decoration: BoxDecoration(
                    borderRadius: DilkashRadii.radiusMd,
                    border: Border.all(
                      color: isDark ? DilkashColors.borderDark : DilkashColors.borderLight,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: DilkashRadii.radiusMd,
                    child: Stack(
                      children: [
                        FlutterMap(
                          options: MapOptions(
                            initialCenter: LatLng(_selectedLat, _selectedLng),
                            initialZoom: 15.0,
                            interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  'https://a.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                              userAgentPackageName: 'uz.dilkash.customer',
                            ),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: LatLng(_selectedLat, _selectedLng),
                                  width: 36,
                                  height: 36,
                                  child: const Icon(
                                    Icons.location_on,
                                    color: Colors.redAccent,
                                    size: 36,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: InkWell(
                            onTap: _openInteractiveMapPicker,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.8),
                                borderRadius: DilkashRadii.radiusFull,
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.crop_free_rounded, color: Colors.white, size: 14),
                                  SizedBox(width: 4),
                                  Text(
                                    'Xaritani ochish',
                                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // 5. Contact Details
              Text(
                'Qabul qiluvchi maʻlumotlari',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  color: DilkashColors.textPrimary(isDark),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DilkashTextField(
                      controller: _nameController,
                      label: 'Ismingiz',
                      hintText: 'Ism',
                      prefixIcon: Icons.person_outline_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DilkashTextField(
                      controller: _phoneController,
                      label: 'Telefon',
                      hintText: '+998 90 ...',
                      keyboardType: TextInputType.phone,
                      prefixIcon: Icons.phone_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DilkashTextField(
                controller: _notesController,
                label: 'Kuryer yoki buyurtma uchun izoh',
                hintText: 'Masalan: Domofon kodi 45, eshik oldida qoldiring...',
              ),
              const SizedBox(height: 20),

              // 6. Promo Code Input
              Text(
                'Promokod & Chegirma',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  color: DilkashColors.textPrimary(isDark),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DilkashTextField(
                      controller: _promoController,
                      hintText: 'Promokod kiriting (DILKASH5)',
                      prefixIcon: Icons.confirmation_number_outlined,
                    ),
                  ),
                  const SizedBox(width: 10),
                  DilkashButton(
                    label: cart.promoCode != null ? 'Oʻchirish' : 'Qoʻllash',
                    isFullWidth: false,
                    size: DilkashButtonSize.md,
                    variant: cart.promoCode != null ? DilkashButtonVariant.outline : DilkashButtonVariant.primary,
                    onPressed: () {
                      if (cart.promoCode != null) {
                        cart.removePromoCode();
                        _promoController.clear();
                        DilkashFeedback.showInfo(context, 'Promokod bekor qilindi');
                      } else {
                        final success = cart.applyPromoCode(_promoController.text);
                        if (success) {
                          DilkashFeedback.showSuccess(context, 'Promokod muvaffaqiyatli qoʻllandi!');
                        } else {
                          DilkashFeedback.showError(context, 'Notoʻgʻri promokod. Sinab koʻring: DILKASH5 yoki YANGI');
                        }
                      }
                    },
                  ),
                ],
              ),
              if (cart.promoCode != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: DilkashColors.successLight,
                    borderRadius: DilkashRadii.radiusSm,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_rounded, color: DilkashColors.success, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Aksiya: ${cart.promoCode} (-${UzbekFormatters.formatCurrency(cart.promoDiscount)})',
                        style: const TextStyle(
                          color: DilkashColors.success,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // 7. Tip / Choychaqa Selector
              if (_serviceType == 'delivery') ...[
                Text(
                  'Kuryerga choychaqa (Ixtiyoriy)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: DilkashColors.textPrimary(isDark),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: _tipOptions.map((tip) {
                    final isSelected = _tipAmount == tip;
                    final label = tip == 0 ? 'Yoʻq' : UzbekFormatters.formatCurrency(tip);
                    return ChoiceChip(
                      label: Text(label),
                      selected: isSelected,
                      onSelected: (_) => setState(() => _tipAmount = tip),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
              ],

              // 8. Payment Method Selector
              Text(
                'Toʻlov usuli',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  color: DilkashColors.textPrimary(isDark),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildPaymentTile(
                      isDark,
                      id: 'naqd',
                      title: 'Naqd pul',
                      icon: Icons.payments_outlined,
                      isSelected: _paymentMethod == 'naqd',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildPaymentTile(
                      isDark,
                      id: 'payme',
                      title: 'Payme',
                      icon: Icons.credit_card_rounded,
                      isSelected: _paymentMethod == 'payme',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildPaymentTile(
                      isDark,
                      id: 'click',
                      title: 'Click',
                      icon: Icons.account_balance_wallet_outlined,
                      isSelected: _paymentMethod == 'click',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 9. Order Summary Breakdown
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: DilkashColors.surface(isDark),
                  borderRadius: DilkashRadii.radiusLg,
                  border: Border.all(
                    color: isDark ? DilkashColors.borderDark : DilkashColors.borderLight,
                  ),
                ),
                child: Column(
                  children: [
                    _buildSummaryRow(isDark, 'Taomlar qiymati', UzbekFormatters.formatCurrency(cart.subtotalPrice)),
                    const SizedBox(height: 8),
                    _buildSummaryRow(
                      isDark,
                      'Yetkazib berish',
                      _serviceType == 'delivery' ? UzbekFormatters.formatCurrency(deliveryCost) : 'Bepul',
                    ),
                    if (cart.promoDiscount > 0) ...[
                      const SizedBox(height: 8),
                      _buildSummaryRow(
                        isDark,
                        'Chegirma (${cart.promoCode})',
                        '-${UzbekFormatters.formatCurrency(cart.promoDiscount)}',
                        isGreen: true,
                      ),
                    ],
                    if (_tipAmount > 0) ...[
                      const SizedBox(height: 8),
                      _buildSummaryRow(
                        isDark,
                        'Kuryerga choychaqa',
                        '+${UzbekFormatters.formatCurrency(_tipAmount)}',
                      ),
                    ],
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Divider(
                        height: 1,
                        color: isDark ? DilkashColors.borderDark : DilkashColors.borderLight,
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Jami toʻlov',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: DilkashColors.textPrimary(isDark),
                          ),
                        ),
                        Text(
                          UzbekFormatters.formatCurrency(finalPayable),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isDark ? DilkashColors.primary400 : DilkashColors.primary600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Submit Order Button
              DilkashButton(
                label: 'Buyurtmani Tasdiqlash • ${UzbekFormatters.formatCurrency(finalPayable)}',
                leadingIcon: Icons.check_circle_rounded,
                isLoading: _isSubmitting,
                onPressed: () => _submitOrder(cart),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildServiceTypeTab(
    bool isDark, {
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: isSelected
          ? (isDark ? DilkashColors.surfaceDark : Colors.white)
          : Colors.transparent,
      borderRadius: DilkashRadii.radiusSm,
      child: InkWell(
        onTap: onTap,
        borderRadius: DilkashRadii.radiusSm,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected
                    ? (isDark ? DilkashColors.primary400 : DilkashColors.primary500)
                    : DilkashColors.textSecondary(isDark),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? DilkashColors.textPrimary(isDark)
                      : DilkashColors.textSecondary(isDark),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeChip(
    bool isDark, {
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: isSelected
          ? (isDark ? DilkashColors.surfaceDarkElevated : DilkashColors.primary50)
          : DilkashColors.surface(isDark),
      borderRadius: DilkashRadii.radiusSm,
      child: InkWell(
        onTap: onTap,
        borderRadius: DilkashRadii.radiusSm,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: DilkashRadii.radiusSm,
            border: Border.all(
              color: isSelected
                  ? DilkashColors.primary(isDark)
                  : (isDark ? DilkashColors.borderDark : DilkashColors.borderLight),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.schedule_rounded,
                size: 16,
                color: isSelected
                    ? DilkashColors.primary(isDark)
                    : DilkashColors.textSecondary(isDark),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? DilkashColors.primary(isDark)
                        : DilkashColors.textPrimary(isDark),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentTile(
    bool isDark, {
    required String id,
    required String title,
    required IconData icon,
    required bool isSelected,
  }) {
    return Material(
      color: isSelected
          ? (isDark ? DilkashColors.surfaceDarkElevated : DilkashColors.primary50)
          : DilkashColors.surface(isDark),
      borderRadius: DilkashRadii.radiusSm,
      child: InkWell(
        onTap: () => setState(() => _paymentMethod = id),
        borderRadius: DilkashRadii.radiusSm,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: DilkashRadii.radiusSm,
            border: Border.all(
              color: isSelected
                  ? DilkashColors.primary(isDark)
                  : (isDark ? DilkashColors.borderDark : DilkashColors.borderLight),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 22,
                color: isSelected
                    ? DilkashColors.primary(isDark)
                    : DilkashColors.textSecondary(isDark),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? DilkashColors.primary(isDark)
                      : DilkashColors.textPrimary(isDark),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(bool isDark, String label, String value, {bool isGreen = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: DilkashColors.textSecondary(isDark),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isGreen
                ? DilkashColors.success
                : DilkashColors.textPrimary(isDark),
          ),
        ),
      ],
    );
  }
}
