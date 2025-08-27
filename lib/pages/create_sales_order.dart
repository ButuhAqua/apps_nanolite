// lib/pages/create_sales_order.dart
import 'package:flutter/material.dart';

import '../services/api_service.dart';

class CreateSalesOrderScreen extends StatefulWidget {
  const CreateSalesOrderScreen({super.key});

  @override
  State<CreateSalesOrderScreen> createState() => _CreateSalesOrderScreenState();
}

class _CreateSalesOrderScreenState extends State<CreateSalesOrderScreen> {
  // Toggles
  bool _rewardAktif = false;
  bool _programAktif = false;
  bool _diskonAktif = false;

  // Selected IDs
  int? _deptId;
  int? _empId;
  int? _categoryId;
  int? _customerId;
  int? _programId; // opsional

  // Payment & status
  String _paymentMethod = 'cash'; // cash/transfer/tempo
  String _statusPembayaran = 'belum bayar'; // sudah bayar/belum bayar
  String _statusOrder = 'pending'; // pending/processing/completed/cancelled

  // Controllers
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _diskon1Ctrl = TextEditingController(text: '0');
  final _diskon2Ctrl = TextEditingController(text: '0');
  final _penjelasanDiskon1Ctrl = TextEditingController();
  final _penjelasanDiskon2Ctrl = TextEditingController();
  final _programCtrl = TextEditingController(); // display program (read-only)

  // Data Customers
  List<OptionItem> _customers = [];

  // Product rows
  final _items = <_ProductItem>[ _ProductItem() ];

  // Totals
  int _total = 0;
  int _totalAfter = 0;

  bool _submitting = false;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _diskon1Ctrl.dispose();
    _diskon2Ctrl.dispose();
    _penjelasanDiskon1Ctrl.dispose();
    _penjelasanDiskon2Ctrl.dispose();
    _programCtrl.dispose();
    super.dispose();
  }

  void _notify(String msg, {Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  void _recomputeTotals() {
    final d1 = double.tryParse(_diskon1Ctrl.text.replaceAll(',', '.')) ?? 0.0;
    final d2 = double.tryParse(_diskon2Ctrl.text.replaceAll(',', '.')) ?? 0.0;

    final enriched = _items.map((it) => {
      'produk_id': it.produkId,
      'warna_id' : it.warnaName(),
      'quantity' : it.qty ?? 0,
      'price'    : it.hargaPerProduk ?? 0,
    }).toList();

    final totals = ApiService.computeTotals(
      products: enriched,
      diskon1: d1,
      diskon2: d2,
      diskonsEnabled: _diskonAktif,
    );

    setState(() {
      _total = totals.total;
      _totalAfter = totals.totalAfterDiscount;
    });
  }

  Future<void> _loadCustomers() async {
    if (_deptId == null || _empId == null || _categoryId == null) {
      setState(() => _customers = []);
      return;
    }
    final list = await ApiService.fetchCustomersFiltered(
      departmentId: _deptId!,
      employeeId: _empId!,
      categoryId: _categoryId!,
    );
    setState(() => _customers = list);
  }

  String _formatRp(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final idxFromEnd = s.length - i;
      buf.write(s[i]);
      if (idxFromEnd > 1 && idxFromEnd % 3 == 1) buf.write('.');
    }
    return 'Rp $buf';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Sales Order'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      backgroundColor: const Color(0xFF0A1B2D),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isTablet = constraints.maxWidth >= 600;
              final fieldWidth = isTablet
                  ? (constraints.maxWidth - 60) / 2
                  : (constraints.maxWidth - 20) / 2;

              return AbsorbPointer(
                absorbing: _submitting,
                child: Opacity(
                  opacity: _submitting ? 0.6 : 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Data Order',
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),

                      Wrap(
                        spacing: 20,
                        runSpacing: 16,
                        children: [
                          _dropdownFuture(
                            label: 'Department *',
                            future: ApiService.fetchDepartments(),
                            value: _deptId,
                            width: fieldWidth,
                            onChanged: (v) {
                              setState(() {
                                _deptId = v;
                                _empId = null;
                              });
                              _loadCustomers();
                            },
                          ),
                          _dropdownFuture(
                            label: 'Karyawan *',
                            future: _deptId != null
                                ? ApiService.fetchEmployees(departmentId: _deptId!)
                                : Future.value([]),
                            value: _empId,
                            width: fieldWidth,
                            onChanged: (v) {
                              setState(() => _empId = v);
                              _loadCustomers();
                            },
                          ),
                          _dropdownFuture(
                            label: 'Kategori Customer *',
                            future: ApiService.fetchCustomerCategories(),
                            value: _categoryId,
                            width: fieldWidth,
                            onChanged: (v) {
                              setState(() {
                                _categoryId = v;
                                _customerId = null;
                              });
                              _loadCustomers();
                            },
                          ),

                          // Customer
                          SizedBox(
                            width: fieldWidth,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Customer *', style: TextStyle(color: Colors.white)),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<int>(
                                  value: _customerId,
                                  items: _customers
                                      .map((c) => DropdownMenuItem<int>(value: c.id, child: Text(c.name)))
                                      .toList(),
                                  onChanged: (v) {
                                    setState(() {
                                      _customerId = v;
                                      final c = _customers.firstWhere(
                                        (e) => e.id == v,
                                        orElse: () => OptionItem(id: 0, name: '-', address: '-', phone: '', programName: '-', programId: null),
                                      );
                                      _phoneCtrl.text   = c.phone ?? '';
                                      _addressCtrl.text = c.address ?? '';
                                      _programCtrl.text = c.programName ?? '-';
                                      _programId        = c.programId;
                                    });
                                  },
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: const Color(0xFF22344C),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  ),
                                  dropdownColor: Colors.grey[900],
                                  iconEnabledColor: Colors.white,
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ],
                            ),
                          ),

                          _darkTextField(
                            label: 'Phone *',
                            width: fieldWidth,
                            controller: _phoneCtrl,
                          ),
                          _darkTextField(
                            label: 'Address',
                            width: fieldWidth,
                            controller: _addressCtrl,
                            maxLines: 2,
                          ),

                          // Reward & Program toggles
                          _switchTile(
                            width: fieldWidth,
                            title: 'Reward',
                            value: _rewardAktif,
                            onChanged: (v) => setState(() => _rewardAktif = v),
                          ),
                          _switchTile(
                            width: fieldWidth,
                            title: 'Program',
                            value: _programAktif,
                            onChanged: (v) => setState(() => _programAktif = v),
                          ),

                          _darkTextField(
                            label: 'Program Pelanggan',
                            width: fieldWidth,
                            controller: _programCtrl,
                            enabled: false,
                          ),

                          // Diskon
                          _switchTile(
                            width: fieldWidth,
                            title: 'Diskon',
                            value: _diskonAktif,
                            onChanged: (v) {
                              setState(() => _diskonAktif = v);
                              _recomputeTotals();
                            },
                          ),
                          _darkTextField(
                            label: 'Diskon 1 (%)',
                            width: fieldWidth,
                            controller: _diskon1Ctrl,
                            hint: '0',
                            enabled: _diskonAktif,
                            onChanged: (_) => _recomputeTotals(),
                          ),
                          _darkTextField(
                            label: 'Penjelasan Diskon 1',
                            width: fieldWidth,
                            controller: _penjelasanDiskon1Ctrl,
                            hint: 'Opsional',
                            enabled: _diskonAktif,
                          ),
                          _darkTextField(
                            label: 'Diskon 2 (%)',
                            width: fieldWidth,
                            controller: _diskon2Ctrl,
                            hint: '0',
                            enabled: _diskonAktif,
                            onChanged: (_) => _recomputeTotals(),
                          ),
                          _darkTextField(
                            label: 'Penjelasan Diskon 2',
                            width: fieldWidth,
                            controller: _penjelasanDiskon2Ctrl,
                            hint: 'Opsional',
                            enabled: _diskonAktif,
                          ),

                          // Pembayaran & status
                          _darkDropdown<String>(
                            label: 'Metode Pembayaran *',
                            width: fieldWidth,
                            value: _paymentMethod,
                            items: const [
                              DropdownMenuItem(value: 'cash', child: Text('Cash')),
                              DropdownMenuItem(value: 'transfer', child: Text('Transfer')),
                              DropdownMenuItem(value: 'tempo', child: Text('Tempo')),
                            ],
                            onChanged: (v) => setState(() => _paymentMethod = v ?? 'cash'),
                          ),
                          _darkDropdown<String>(
                            label: 'Status Pembayaran *',
                            width: fieldWidth,
                            value: _statusPembayaran,
                            items: const [
                              DropdownMenuItem(value: 'sudah bayar', child: Text('Sudah Bayar')),
                              DropdownMenuItem(value: 'belum bayar', child: Text('Belum Bayar')),
                            ],
                            onChanged: (v) => setState(() => _statusPembayaran = v ?? 'belum bayar'),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),
                      const Text('Detail Produk', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),

                      Column(children: List.generate(_items.length, (i) => _productCard(i))),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            setState(() => _items.add(_ProductItem()));
                            _recomputeTotals();
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Tambah Produk'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Ringkasan total
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A2D44),
                          border: Border.all(color: Colors.white24),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _rowSummary('Total', _formatRp(_total)),
                            const SizedBox(height: 6),
                            _rowSummary('Total Akhir', _formatRp(_totalAfter)),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          _formButton('Cancel', Colors.grey, () => Navigator.pop(context, false)),
                          const SizedBox(width: 12),
                          _formButton('Create', Colors.blue, _submitting ? null : _submit),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _productCard(int i) {
    const gap = 16.0;
    final it = _items[i];
    final subtotal = (it.hargaPerProduk ?? 0) * (it.qty ?? 0);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2D44),
        border: Border.all(color: Colors.white24),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFF16283D),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Text('Produk ${i + 1}', style: const TextStyle(color: Colors.white70)),
                const Spacer(),
                IconButton(
                  tooltip: 'Hapus',
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  onPressed: () {
                    setState(() => _items.removeAt(i));
                    _recomputeTotals();
                  },
                ),
              ],
            ),
          ),

          // Body
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
            child: LayoutBuilder(
              builder: (context, inner) {
                final itemWidth = (inner.maxWidth - gap) / 2;
                return Wrap(
                  spacing: gap,
                  runSpacing: 16,
                  children: [
                    _dropdownFuture(
                      label: 'Brand *',
                      future: ApiService.fetchBrands(),
                      value: it.brandId,
                      width: itemWidth,
                      onChanged: (v) => setState(() => it.brandId = v),
                    ),
                    _dropdownFuture(
                      label: 'Kategori *',
                      future: ApiService.fetchProductCategories(),
                      value: it.kategoriId,
                      width: itemWidth,
                      onChanged: (v) => setState(() => it.kategoriId = v),
                    ),
                    _dropdownFuture(
                      label: 'Produk *',
                      future: ApiService.fetchProducts(),
                      value: it.produkId,
                      width: itemWidth,
                      onChanged: (v) async {
                        setState(() {
                          it.produkId = v;
                          it.warnaId = null;
                          it.availableColors = const [];
                          it.hargaPerProduk = null;
                        });

                        if (v != null) {
                          final cols = await ApiService.fetchColorsByProduct(v);
                          final price = await ApiService.fetchProductPrice(v);

                          setState(() {
                            it.availableColors = cols;
                            it.hargaPerProduk = price;
                          });
                          _recomputeTotals();
                        }
                      },
                    ),

                    // Warna
                    SizedBox(
                      width: itemWidth,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Warna *', style: TextStyle(color: Colors.white)),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<int>(
                            value: it.warnaId,
                            items: (it.availableColors)
                                .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                                .toList(),
                            onChanged: (v) => setState(() {
                              it.warnaId = v;
                            }),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: const Color(0xFF22344C),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                            dropdownColor: Colors.grey[900],
                            iconEnabledColor: Colors.white,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),

                    // Harga / Produk (read-only, auto fetch)
                    SizedBox(
                      width: itemWidth,
                      child: _displayBox(
                        label: 'Harga / Produk',
                        value: it.hargaPerProduk == null ? '-' : _formatRp(it.hargaPerProduk!),
                      ),
                    ),

                    // Qty
                    SizedBox(
                      width: itemWidth,
                      child: _qtyField(
                        label: 'Jumlah',
                        value: it.qty?.toString(),
                        onChanged: (txt) {
                          setState(() => it.qty = int.tryParse(txt) ?? 0);
                          _recomputeTotals();
                        },
                      ),
                    ),

                    // Subtotal
                    SizedBox(
                      width: itemWidth,
                      child: _displayBox(
                        label: 'Subtotal',
                        value: _formatRp(subtotal),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ===== reusable widgets =====
  Widget _switchTile({
    required double width,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.only(top: 28),
        child: Row(
          children: [
            Switch.adaptive(value: value, onChanged: onChanged, activeColor: Colors.blue),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget _rowSummary(String label, String value) {
    return Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(color: Colors.white70))),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _formButton(String text, Color color, VoidCallback? onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
      child: onPressed == null
          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
          : Text(text),
    );
  }

  Widget _dropdownFuture({
    required String label,
    required Future<List<OptionItem>> future,
    required int? value,
    required double width,
    required ValueChanged<int?> onChanged,
    bool enabled = true,
  }) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white)),
          const SizedBox(height: 6),
          FutureBuilder<List<OptionItem>>(
            future: future,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SizedBox(height: 48, child: Center(child: CircularProgressIndicator()));
              }
              final items = snapshot.data!;
              return DropdownButtonFormField<int>(
                value: value,
                items: items
                    .map((opt) => DropdownMenuItem(value: opt.id, child: Text(opt.name)))
                    .toList(),
                onChanged: enabled ? onChanged : null,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF22344C),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                dropdownColor: Colors.grey[900],
                iconEnabledColor: Colors.white,
                style: const TextStyle(color: Colors.white),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _darkTextField({
    required String label,
    required double width,
    TextEditingController? controller,
    int maxLines = 1,
    bool enabled = true,
    String? hint,
    ValueChanged<String>? onChanged,
  }) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white)),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            onChanged: onChanged,
            maxLines: maxLines,
            enabled: enabled,
            style: TextStyle(color: enabled ? Colors.white : Colors.white54),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: const Color(0xFF22344C),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _darkDropdown<T>({
    required String label,
    required double width,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white)),
          const SizedBox(height: 6),
          DropdownButtonFormField<T>(
            value: value,
            items: items,
            onChanged: onChanged,
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF22344C),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            dropdownColor: Colors.grey[900],
            iconEnabledColor: Colors.white,
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _qtyField({
    required String label,
    String? value,
    required ValueChanged<String> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white)),
        const SizedBox(height: 6),
        TextFormField(
          initialValue: value,
          keyboardType: TextInputType.number,
          onChanged: onChanged,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF22344C),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _displayBox({required String label, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF22344C),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white24),
          ),
          child: Text(value, style: const TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  // ===== Submit =====
  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (_deptId == null || _empId == null || _categoryId == null || _customerId == null) {
      _notify('Lengkapi field Department, Karyawan, Kategori, Customer', color: Colors.red);
      return;
    }

    if (_items.isEmpty) {
      _notify('Minimal 1 produk', color: Colors.red);
      return;
    }
    for (final it in _items) {
      if (it.produkId == null || (it.qty ?? 0) < 1) {
        _notify('Pastikan setiap baris punya Produk & Jumlah >= 1', color: Colors.red);
        return;
      }
      if (it.hargaPerProduk == null || it.hargaPerProduk == 0) {
        if (it.produkId != null) {
          it.hargaPerProduk = await ApiService.fetchProductPrice(it.produkId!);
        }
      }
    }

    setState(() => _submitting = true);

    try {
      final d1 = double.tryParse(_diskon1Ctrl.text.replaceAll(',', '.')) ?? 0.0;
      final d2 = double.tryParse(_diskon2Ctrl.text.replaceAll(',', '.')) ?? 0.0;

      final ok = await ApiService.createOrder(
        companyId: 1, // sesuaikan
        departmentId: _deptId!,
        employeeId: _empId!,
        customerId: _customerId!,
        categoryId: _categoryId!,
        programId: _programId,
        phone: _phoneCtrl.text.trim(),
        addressText: _addressCtrl.text.trim(),
        programEnabled: _programAktif,
        rewardEnabled: _rewardAktif,
        diskon1: d1,
        diskon2: d2,
        penjelasanDiskon1: _penjelasanDiskon1Ctrl.text.trim().isEmpty ? null : _penjelasanDiskon1Ctrl.text.trim(),
        penjelasanDiskon2: _penjelasanDiskon2Ctrl.text.trim().isEmpty ? null : _penjelasanDiskon2Ctrl.text.trim(),
        diskonsEnabled: _diskonAktif,
        paymentMethod: _paymentMethod,
        statusPembayaran: _statusPembayaran,
        status: _statusOrder,
        products: _items.map((it) => {
          'produk_id' : it.produkId,
          'warna_id'  : it.warnaName(),
          'quantity'  : it.qty ?? 0,
          'price'     : it.hargaPerProduk ?? 0,
        }).toList(),
      );

      if (!mounted) return;

      if (ok) {
        _notify('Order berhasil dibuat', color: Colors.green);
        Navigator.pop(context, true);
      } else {
        _notify('Gagal membuat order', color: Colors.red);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

// ===== Model data produk (untuk UI) =====
class _ProductItem {
  int? brandId;
  int? kategoriId;
  int? produkId;
  int? warnaId;                     // id OptionItem
  List<OptionItem> availableColors; // daftar warna utk produk terpilih
  int? hargaPerProduk;              // harga int (Rupiah)
  int? qty;

  _ProductItem({
    this.brandId,
    this.kategoriId,
    this.produkId,
    this.warnaId,
    this.hargaPerProduk,
    this.qty,
    this.availableColors = const [],
  });

  String? warnaName() {
    if (warnaId == null) return null;
    try {
      final opt = availableColors.firstWhere((c) => c.id == warnaId);
      return opt.name;
    } catch (_) {
      return null;
    }
  }
}
