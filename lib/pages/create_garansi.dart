// lib/pages/create_garansi.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/api_service.dart';

class CreateGaransiScreen extends StatefulWidget {
  const CreateGaransiScreen({super.key});

  @override
  State<CreateGaransiScreen> createState() => _CreateGaransiScreenState();
}

class _CreateGaransiScreenState extends State<CreateGaransiScreen> {
  // ===== Controllers =====
  final _phoneCtrl = TextEditingController();
  final _addrCtrl = TextEditingController();
  final _tglPembelian = TextEditingController();
  final _tglKlaim = TextEditingController();
  final _alasanCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  // ===== Dropdown atas (pakai ID agar aman) =====
  int? _deptId;
  int? _empId;
  int? _catId;
  int? _custId;

  List<OptionItem> _departments = [];
  List<OptionItem> _employees = [];
  List<OptionItem> _custCats = [];   // hasil filter Dept + Emp (+ intersect used)
  List<OptionItem> _customers = [];  // hasil filter Dept + Emp + Cat

  bool _loadingInit = false;
  bool _loadingEmployees = false;
  bool _loadingCategories = false;
  bool _loadingCustomers = false;
  bool _submitting = false;

  // ===== Produk list =====
  final List<_ProductRow> _rows = [ _ProductRow() ];

  // ===== Image (preview; backend minta string) =====
  final ImagePicker _picker = ImagePicker();
  final List<XFile> _photos = [];

  @override
  void initState() {
    super.initState();
    _bootstrap();
    _rows.first.loadBrands(setState);
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _addrCtrl.dispose();
    _tglPembelian.dispose();
    _tglKlaim.dispose();
    _alasanCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  // ---------------- Bootstrap ----------------
  Future<void> _bootstrap() async {
    setState(() => _loadingInit = true);
    try {
      final depts = await ApiService.fetchDepartments();
      if (!mounted) return;
      setState(() => _departments = depts);
    } finally {
      if (mounted) setState(() => _loadingInit = false);
    }
  }

  // ---------------- Filter kategori seperti SO (paling aman) ----------------
  Future<void> _refreshFilteredCategories() async {
    setState(() {
      _loadingCategories = true;
      _catId = null;
      _custId = null;
      _custCats = [];
      _customers = [];
      _phoneCtrl.clear();
      _addrCtrl.clear();
    });

    // butuh dept + emp
    if (_deptId == null || _empId == null) {
      if (mounted) setState(() => _loadingCategories = false);
      return;
    }

    try {
      // Ambil kategori by employee (bila backend support)
      final serverCats = await ApiService.fetchCustomerCategories(employeeId: _empId);

      // Ambil customers by Dept+Emp
      final custDeptEmp = await ApiService.fetchCustomersByDeptEmp(
        departmentId: _deptId!,
        employeeId: _empId!,
      );

      // Kategori yang benar-benar dipakai customer tsb
      final usedCatIds = custDeptEmp.map((c) => c.categoryId).whereType<int>().toSet();

      // Kalau server kasih kategori, ambil yang intersect used; kalau kosong, fallback ambil semua lalu intersect
      List<OptionItem> baseCats = serverCats;
      if (baseCats.isEmpty) {
        baseCats = await ApiService.fetchCustomerCategoriesAll();
      }
      final filtered = baseCats.where((cat) => usedCatIds.contains(cat.id)).toList();

      if (!mounted) return;
      setState(() => _custCats = filtered);
    } catch (_) {
      if (mounted) setState(() => _custCats = <OptionItem>[]);
    } finally {
      if (mounted) setState(() => _loadingCategories = false);
    }
  }

  // ---------------- Handlers dropdown atas ----------------
  Future<void> _onSelectDepartment(int? id) async {
    setState(() {
      _deptId = id;
      _empId = null;
      _catId = null;
      _custId = null;
      _employees = [];
      _custCats = [];
      _customers = [];
      _phoneCtrl.clear();
      _addrCtrl.clear();
      _loadingEmployees = true;
    });

    if (id == null) {
      setState(() => _loadingEmployees = false);
      return;
    }

    try {
      final emps = await ApiService.fetchEmployees(departmentId: id);
      if (!mounted) return;
      setState(() => _employees = emps);
    } finally {
      if (mounted) setState(() => _loadingEmployees = false);
    }

    await _refreshFilteredCategories();
  }

  Future<void> _onSelectEmployee(int? id) async {
    setState(() {
      _empId = id;
      _catId = null;
      _custId = null;
      _custCats = [];
      _customers = [];
      _phoneCtrl.clear();
      _addrCtrl.clear();
    });
    await _refreshFilteredCategories();
  }

  Future<void> _onSelectCustomerCategory(int? id) async {
    setState(() {
      _catId = id;
      _custId = null;
      _customers = [];
      _phoneCtrl.clear();
      _addrCtrl.clear();
      _loadingCustomers = true;
    });

    if (_deptId == null || _empId == null || id == null) {
      setState(() => _loadingCustomers = false);
      return;
    }

    try {
      final custs = await ApiService.fetchCustomersFiltered(
        departmentId: _deptId!,
        employeeId: _empId!,
        categoryId: id,
      );
      if (!mounted) return;
      setState(() => _customers = custs);
    } finally {
      if (mounted) setState(() => _loadingCustomers = false);
    }
  }

  Future<void> _onSelectCustomer(int? id) async {
    setState(() {
      _custId = id;
      _phoneCtrl.clear();
      _addrCtrl.clear();
    });
    if (id == null) return;

    final cust = _customers.firstWhere((c) => c.id == id, orElse: () => OptionItem(id: id, name: '-'));
    if (cust.phone != null && cust.phone!.isNotEmpty) {
      _phoneCtrl.text = cust.phone!;
    }

    if (cust.address != null &&
        cust.address!.trim().isNotEmpty &&
        cust.address!.trim() != '-') {
      _addrCtrl.text = cust.address!;
      return;
    }

    try {
      final raw = await ApiService.fetchCustomerDetailRaw(id);
      final formatted = ApiService.formatAddress(raw);
      if (formatted.isNotEmpty && formatted != '-') {
        _addrCtrl.text = formatted;
      }
    } catch (_) {}
  }

  // ---------------- Handlers detail produk ----------------
  Future<void> _onBrandChanged(int row, OptionItem? brand) async {
    setState(() {
      _rows[row].brand = brand;
      _rows[row].category = null;
      _rows[row].product = null;
      _rows[row].color = null;
      _rows[row].categories = [];
      _rows[row].products = [];
      _rows[row].colors = [];
    });
    if (brand != null) {
      final cats = await ApiService.fetchCategoriesByBrand(brand.id);
      if (!mounted) return;
      setState(() => _rows[row].categories = cats);
    }
  }

  Future<void> _onRowCategoryChanged(int row, OptionItem? cat) async {
    setState(() {
      _rows[row].category = cat;
      _rows[row].product = null;
      _rows[row].color = null;
      _rows[row].products = [];
      _rows[row].colors = [];
    });
    if (cat != null && _rows[row].brand != null) {
      final prods = await ApiService.fetchProductsByBrandCategory(
        _rows[row].brand!.id,
        cat.id,
      );
      if (!mounted) return;
      setState(() => _rows[row].products = prods);
    }
  }

  Future<void> _onProductChanged(int row, OptionItem? prod) async {
    setState(() {
      _rows[row].product = prod;
      _rows[row].color = null;
      _rows[row].colors = [];
    });
    if (prod != null) {
      final cols = await ApiService.fetchColorsByProductFiltered(prod.id);
      if (!mounted) return;
      setState(() => _rows[row].colors = cols);
    }
  }

  void _onColorChanged(int row, OptionItem? color) {
    setState(() => _rows[row].color = color);
  }

  void _onQtyChanged(int row, String txt) {
    setState(() => _rows[row].qty = int.tryParse(txt) ?? 0);
  }

  void _addRow() {
    setState(() => _rows.add(_ProductRow()));
    _rows.last.loadBrands(setState);
  }

  void _removeRow(int i) => setState(() => _rows.removeAt(i));

  // ---------------- Image (preview only) ----------------
  Future<void> _pickFromGallery() async {
    try {
      final files = await _picker.pickMultiImage(imageQuality: 85);
      if (files.isNotEmpty) setState(() => _photos.addAll(files));
    } catch (_) {}
  }

  Future<void> _pickFromCamera() async {
    try {
      final f = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
      if (f != null) setState(() => _photos.add(f));
    } catch (_) {}
  }

  void _removePhoto(int i) => setState(() => _photos.removeAt(i));

  // ---------------- Submit ----------------
  Future<void> _submit() async {
    if (_deptId == null ||
        _empId == null ||
        _catId == null ||
        _custId == null ||
        _tglPembelian.text.isEmpty ||
        _tglKlaim.text.isEmpty ||
        _rows.isEmpty) {
      _snack('Lengkapi form terlebih dahulu.');
      return;
    }

    final address = <Map<String, dynamic>>[
      {
        'provinsi': null,
        'kota_kab': null,
        'kecamatan': null,
        'kelurahan': null,
        'kode_pos': null,
        'detail_alamat': _addrCtrl.text.trim().isEmpty ? '-' : _addrCtrl.text.trim(),
      }
    ];

    final products = <Map<String, dynamic>>[];
    for (final r in _rows) {
      if (r.product == null || (r.qty ?? 0) <= 0) continue;
      products.add({
        'produk_id': r.product!.id,
        'warna_id': r.color?.name,
        'quantity': r.qty ?? 0,
      });
    }
    if (products.isEmpty) {
      _snack('Minimal 1 produk dengan Qty > 0.');
      return;
    }

    // image sebagai base64 string (opsional)
    String? imageStr;
    if (_photos.isNotEmpty) {
      try {
        final first = _photos.first;
        final bytes = await first.readAsBytes();
        final n = (first.name.isNotEmpty ? first.name : first.path).toLowerCase();
        final mime = n.endsWith('.png')
            ? 'image/png'
            : n.endsWith('.webp')
                ? 'image/webp'
                : 'image/jpeg';
        imageStr = 'data:$mime;base64,${base64Encode(bytes)}';
      } catch (_) {}
    }

    setState(() => _submitting = true);
    final ok = await ApiService.createWarranty(
      companyId: 1,
      departmentId: _deptId!,
      employeeId: _empId!,
      customerId: _custId!,
      categoryId: _catId!,
      phone: _phoneCtrl.text.trim(),
      address: address,
      products: products,
      purchaseDate: _toYMD(_tglPembelian.text),
      claimDate: _toYMD(_tglKlaim.text),
      reason: _alasanCtrl.text.trim().isEmpty ? null : _alasanCtrl.text.trim(),
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      status: 'pending',
      imagePath: imageStr,
    );
    if (mounted) setState(() => _submitting = false);

    if (!mounted) return;
    if (ok) {
      _snack('Garansi berhasil dibuat.');
      Navigator.pop(context, true);
    } else {
      _snack('Gagal membuat garansi. Coba lagi.');
    }
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    final disabledAll = _loadingInit || _submitting;
    return Scaffold(
      appBar: AppBar(
        title: const Text('nanopiko'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      backgroundColor: const Color(0xFF0A1B2D),
      body: _loadingInit
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final bool isTablet = constraints.maxWidth >= 600;
                    final double fieldWidth =
                        isTablet ? (constraints.maxWidth - 60) / 2 : (constraints.maxWidth - 20) / 2;

                    return AbsorbPointer(
                      absorbing: disabledAll,
                      child: Opacity(
                        opacity: disabledAll ? 0.6 : 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Create Garansi',
                              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 20),

                            Wrap(
                              spacing: 20,
                              runSpacing: 16,
                              children: [
                                _dropdownInt('Departemen *',
                                  width: fieldWidth,
                                  value: _deptId,
                                  items: _departments,
                                  onChanged: _onSelectDepartment,
                                ),

                                _dropdownInt('Karyawan *',
                                  width: fieldWidth,
                                  value: _empId,
                                  items: _employees,
                                  onChanged: _onSelectEmployee,
                                  loading: _loadingEmployees,
                                ),

                                _dropdownInt('Kategori Customer *',
                                  width: fieldWidth,
                                  value: _catId,
                                  items: _custCats,
                                  onChanged: _onSelectCustomerCategory,
                                  loading: _loadingCategories,
                                ),

                                _dropdownCustomer('Customer *',
                                  width: fieldWidth,
                                  value: _custId,
                                  items: _customers,
                                  onChanged: (cust) => _onSelectCustomer(cust.id),
                                  loading: _loadingCustomers,
                                ),

                                _tf('Phone *', _phoneCtrl, width: fieldWidth),
                                _tf('Address', _addrCtrl, width: fieldWidth, maxLines: 2),
                                _dateField('Tanggal Pembelian *', _tglPembelian, fieldWidth),
                                _dateField('Tanggal Klaim *', _tglKlaim, fieldWidth),
                                _tf('Alasan Pengajuan *', _alasanCtrl, width: fieldWidth, maxLines: 2),
                                _tf('Catatan Tambahan', _noteCtrl, width: fieldWidth, maxLines: 2, hint: 'Opsional'),
                              ],
                            ),

                            const SizedBox(height: 20),
                            _imagePicker(),
                            const SizedBox(height: 20),

                            const Text('Detail Produk',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 10),

                            Column(children: List.generate(_rows.length, (i) => _productCard(i))),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerRight,
                              child: ElevatedButton.icon(
                                onPressed: _addRow,
                                icon: const Icon(Icons.add),
                                label: const Text('Tambah Produk'),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                              ),
                            ),

                            const SizedBox(height: 30),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                _formButton('Cancel', Colors.grey, () => Navigator.pop(context, false)),
                                const SizedBox(width: 12),
                                _formButton('Create', Colors.blue, _submitting ? null : _submit,
                                    showSpinner: _submitting),
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

  // ---------- Widgets kecil ----------
  Widget _tf(String label, TextEditingController c,
      {double? width, int maxLines = 1, String? hint}) {
    final field = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white)),
        const SizedBox(height: 6),
        TextFormField(
          controller: c,
          maxLines: maxLines,
          style: const TextStyle(color: Colors.white),
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
    );
    if (width == null) return field;
    return SizedBox(width: width, child: field);
  }

  Widget _dropdownInt(String label,
      {required double width,
      required int? value,
      required List<OptionItem> items,
      required ValueChanged<int?> onChanged,
      bool loading = false}) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white)),
          const SizedBox(height: 6),
          DropdownButtonFormField<int>(
            value: value,
            items: items
                .map((o) => DropdownMenuItem(value: o.id, child: Text(o.name)))
                .toList(),
            onChanged: loading ? null : onChanged,
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

  Widget _dropdownCustomer(String label,
      {required double width,
      required int? value,
      required List<OptionItem> items,
      required ValueChanged<OptionItem> onChanged,
      bool loading = false}) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white)),
          const SizedBox(height: 6),
          DropdownButtonFormField<int>(
            value: value,
            items: items
                .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                .toList(),
            onChanged: loading
                ? null
                : (v) {
                    if (v == null) {
                      onChanged(OptionItem(id: 0, name: '-'));
                      return;
                      }
                    final cust = items.firstWhere((c) => c.id == v);
                    onChanged(cust);
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
    );
  }

  Widget _dateField(String label, TextEditingController controller, double width) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white)),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            readOnly: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF22344C),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              suffixIcon: IconButton(
                icon: const Icon(Icons.calendar_today, color: Colors.white70),
                onPressed: () => _pickDate(controller),
              ),
            ),
            onTap: () => _pickDate(controller),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2000, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked != null) {
      controller.text = _fmtDate(picked);
      setState(() {});
    }
  }

  String _fmtDate(DateTime d) {
    String two(int n) => n < 10 ? '0$n' : '$n';
    return '${two(d.month)}/${two(d.day)}/${d.year}';
  }

  String _toYMD(String mdY) {
    final p = mdY.split('/');
    if (p.length != 3) return mdY;
    final m = p[0].padLeft(2, '0');
    final d = p[1].padLeft(2, '0');
    final y = p[2];
    return '$y-$m-$d';
  }

  Widget _formButton(String text, Color color, VoidCallback? onPressed, {bool showSpinner = false}) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
      child: showSpinner
          ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
          : Text(text),
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ---------- Image picker ----------
  Widget _imagePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Gambar', style: TextStyle(color: Colors.white)),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white24),
            borderRadius: BorderRadius.circular(8),
          ),
          child: _photos.isEmpty
              ? Wrap(
                  spacing: 10,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _pickFromGallery,
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Pilih Foto'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _pickFromCamera,
                      icon: const Icon(Icons.photo_camera),
                      label: const Text('Kamera'),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: List.generate(_photos.length, (i) {
                        return Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: _thumb(_photos[i]),
                            ),
                            Positioned(
                              right: -6,
                              top: -6,
                              child: IconButton(
                                icon: const Icon(Icons.cancel, color: Colors.redAccent),
                                onPressed: () => _removePhoto(i),
                              ),
                            ),
                          ],
                        );
                      }),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _pickFromGallery,
                          icon: const Icon(Icons.add_photo_alternate),
                          label: const Text('Tambah Foto'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _pickFromCamera,
                          icon: const Icon(Icons.photo_camera),
                          label: const Text('Kamera'),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  /// Thumbnail aman untuk Mobile & Web
  Widget _thumb(XFile file, {double size = 90}) {
    if (kIsWeb) {
      return FutureBuilder<Uint8List>(
        future: file.readAsBytes(),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return Container(
              width: size, height: size,
              color: Colors.black12,
              alignment: Alignment.center,
              child: const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }
          if (!snap.hasData) {
            return Container(width: size, height: size, color: Colors.black12);
          }
          return Image.memory(snap.data!, width: size, height: size, fit: BoxFit.cover);
        },
      );
    } else {
      return Image.file(
        File(file.path),
        width: size,
        height: size,
        fit: BoxFit.cover,
      );
    }
  }

  // ---------- Kartu produk ----------
  Widget _productCard(int i) {
    const gap = 16.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2D44),
        border: Border.all(color: Colors.white24),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFF16283D),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                const Icon(Icons.swap_vert, color: Colors.white54, size: 18),
                const SizedBox(width: 8),
                Text('Produk ${i + 1}', style: const TextStyle(color: Colors.white70)),
                const Spacer(),
                IconButton(
                  tooltip: 'Hapus',
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  onPressed: () => _removeRow(i),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
            child: LayoutBuilder(
              builder: (context, inner) {
                final double itemWidth = (inner.maxWidth - gap) / 2;
                return Wrap(
                  spacing: gap,
                  runSpacing: 16,
                  children: [
                    SizedBox(
                      width: itemWidth,
                      child: _pillDropdown<OptionItem>(
                        label: 'Brand *',
                        value: _rows[i].brand,
                        items: _rows[i].brands,
                        onChanged: (v) => _onBrandChanged(i, v),
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _pillDropdown<OptionItem>(
                        label: 'Kategori *',
                        value: _rows[i].category,
                        items: _rows[i].categories,
                        onChanged: (v) => _onRowCategoryChanged(i, v),
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _pillDropdown<OptionItem>(
                        label: 'Produk *',
                        value: _rows[i].product,
                        items: _rows[i].products,
                        onChanged: (v) => _onProductChanged(i, v),
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _pillDropdown<OptionItem>(
                        label: 'Warna',
                        value: _rows[i].color,
                        items: _rows[i].colors,
                        onChanged: (v) => _onColorChanged(i, v),
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _qtyField(
                        label: 'Jumlah *',
                        value: _rows[i].qty?.toString(),
                        onChanged: (txt) => _onQtyChanged(i, txt),
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

  Widget _pillDropdown<T>({
    required String label,
    required T? value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white)),
        const SizedBox(height: 6),
        DropdownButtonFormField<T>(
          value: value,
          items: items
              .map((e) => DropdownMenuItem<T>(
                    value: e,
                    child: Text((e is OptionItem) ? e.name : e.toString()),
                  ))
              .toList(),
          onChanged: onChanged,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF22344C),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            suffixIcon: value == null
                ? null
                : IconButton(
                    tooltip: 'Clear',
                    icon: const Icon(Icons.close, size: 18, color: Colors.white70),
                    onPressed: () => onChanged(null),
                  ),
          ),
          dropdownColor: Colors.grey[900],
          iconEnabledColor: Colors.white,
          style: const TextStyle(color: Colors.white),
        ),
      ],
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
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF22344C),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white24),
              ),
              child: const Text('Qty', style: TextStyle(color: Colors.white70)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
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
            ),
          ],
        ),
      ],
    );
  }
}

// ===== Model baris untuk UI =====
class _ProductRow {
  OptionItem? brand;
  OptionItem? category;
  OptionItem? product;
  OptionItem? color;
  int? qty;

  List<OptionItem> brands = [];
  List<OptionItem> categories = [];
  List<OptionItem> products = [];
  List<OptionItem> colors = [];

  Future<void> loadBrands(void Function(VoidCallback fn) setState) async {
    final b = await ApiService.fetchBrands();
    setState(() => brands = b);
  }
}
