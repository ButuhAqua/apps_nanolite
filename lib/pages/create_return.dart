// lib/pages/create_return.dart
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/api_service.dart';

class CreateReturnScreen extends StatefulWidget {
  const CreateReturnScreen({super.key});

  @override
  State<CreateReturnScreen> createState() => _CreateReturnScreenState();
}

class _CreateReturnScreenState extends State<CreateReturnScreen> {
  // ====== Controllers ======
  final _phoneCtrl = TextEditingController();
  final _addrCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  // ====== Dropdown atas ======
  List<OptionItem> _departments = [];
  List<OptionItem> _employees = [];
  List<OptionItem> _categories = [];
  List<OptionItem> _customers = [];

  int? _deptId;
  int? _empId;
  int? _catId;
  int? _custId;

  bool _loadingOptions = false;
  bool _loadingEmployees = false;
  bool _loadingCustomers = false;
  bool _submitting = false;

  // ====== Detail produk (mengikuti create_garansi) ======
  final List<_ReturnRow> _rows = [ _ReturnRow() ];

  // ====== Foto ======
  final ImagePicker _picker = ImagePicker();
  final List<XFile> _photos = [];

  @override
  void initState() {
    super.initState();
    _loadOptions();
    _rows.first.loadBrands(setState); // muat brand utk baris pertama
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _addrCtrl.dispose();
    _amountCtrl.dispose();
    _reasonCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  // ====== LOAD OPTIONS (atas) ======
  Future<void> _loadOptions() async {
    setState(() => _loadingOptions = true);
    try {
      final depts = await ApiService.fetchDepartments();
      final cats  = await ApiService.fetchCustomerCategoriesAll();
      if (!mounted) return;
      setState(() {
        _departments = depts;
        _categories  = cats; // akan difilter lagi via dept+emp
      });
    } finally {
      if (mounted) setState(() => _loadingOptions = false);
    }
  }

  // Filter kategori berdasarkan Dept + Karyawan (seperti garansi)
  Future<void> _refreshFilteredCategories() async {
    if (_deptId == null || _empId == null) {
      setState(() => _categories = []);
      return;
    }

    final custs = await ApiService.fetchCustomersByDeptEmp(
      departmentId: _deptId!,
      employeeId: _empId!,
    );

    // coba ambil kategori by employee; fallback ke all
    final baseServer = await ApiService.fetchCustomerCategories(employeeId: _empId);
    var baseCats = baseServer.isEmpty
        ? await ApiService.fetchCustomerCategoriesAll()
        : baseServer;

    final usedCatIds = custs.map((c) => c.categoryId).whereType<int>().toSet();
    final filtered = baseCats.where((c) => usedCatIds.contains(c.id)).toList();

    if (!mounted) return;
    setState(() {
      _categories = filtered;
      if (_catId != null && !_categories.any((c) => c.id == _catId)) {
        _catId = null;
      }
    });
  }

  // Load customers: Dept + Karyawan + Kategori
  Future<void> _loadCustomersFiltered() async {
    setState(() {
      _loadingCustomers = true;
      _customers = [];
      _custId = null;
      _phoneCtrl.clear();
      _addrCtrl.clear();
    });

    if (_deptId == null || _empId == null || _catId == null) {
      setState(() => _loadingCustomers = false);
      return;
    }

    final list = await ApiService.fetchCustomersFiltered(
      departmentId: _deptId!,
      employeeId: _empId!,
      categoryId: _catId!,
    );

    if (!mounted) return;
    setState(() {
      _customers = list;
      _loadingCustomers = false;
    });
  }

  Future<void> _onSelectDepartment(int? id) async {
    setState(() {
      _deptId = id;
      _empId = null;
      _catId = null;
      _custId = null;
      _employees = [];
      _customers = [];
      _phoneCtrl.clear();
      _addrCtrl.clear();
      _loadingEmployees = true;
    });

    if (id == null) {
      await _refreshFilteredCategories();
      setState(() => _loadingEmployees = false);
      return;
    }

    final emps = await ApiService.fetchEmployees(departmentId: id);
    if (!mounted) return;
    setState(() {
      _employees = emps;
      _loadingEmployees = false;
    });
    await _refreshFilteredCategories();
  }

  Future<void> _onSelectEmployee(int? id) async {
    setState(() {
      _empId = id;
      _catId = null;
      _custId = null;
      _customers = [];
      _phoneCtrl.clear();
      _addrCtrl.clear();
      _loadingCustomers = false;
    });
    await _refreshFilteredCategories();
  }

  Future<void> _onSelectCategory(int? id) async {
    setState(() {
      _catId = id;
      _custId = null;
      _customers = [];
      _phoneCtrl.clear();
      _addrCtrl.clear();
    });
    await _loadCustomersFiltered();
  }

  Future<void> _onSelectCustomerId(int? id) async {
    setState(() {
      _custId = id;
      _phoneCtrl.clear();
      _addrCtrl.clear();
    });

    if (id == null) return;

    try {
      final detail = await ApiService.fetchCustomerDetail(id);
      if (!mounted) return;
      setState(() {
        _phoneCtrl.text = detail.phone ?? '';
        _addrCtrl.text  = detail.alamatDisplay;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal mengambil detail customer')),
      );
    }
  }

  // ====== Handlers detail produk (berantai, sama seperti garansi) ======
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
      // utamakan endpoint filtered seperti di garansi; fallback ke yang umum
      List<OptionItem> cols = [];
      try {
        cols = await ApiService.fetchColorsByProductFiltered(prod.id);
      } catch (_) {
        cols = await ApiService.fetchColorsByProduct(prod.id);
      }
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

  void _addProduk() {
    setState(() => _rows.add(_ReturnRow()));
    _rows.last.loadBrands(setState);
  }

  void _removeProduk(int i) => setState(() => _rows.removeAt(i));

  // ====== Foto ======
  Future<void> _pickFromGallery() async {
    final files = await _picker.pickMultiImage(imageQuality: 85);
    if (files.isNotEmpty) setState(() => _photos.addAll(files));
  }

  Future<void> _pickFromCamera() async {
    final file = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (file != null) setState(() => _photos.add(file));
  }

  void _removePhoto(int i) => setState(() => _photos.removeAt(i));

  // ====== Submit ======
  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (_deptId == null || _empId == null || _catId == null || _custId == null ||
        _phoneCtrl.text.isEmpty || _addrCtrl.text.isEmpty ||
        _amountCtrl.text.isEmpty || _reasonCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lengkapi field yang wajib *')),
      );
      return;
    }

    // Validasi baris produk (produk + warna wajib, qty >= 1)
    for (final r in _rows) {
      if (r.product == null || r.color == null || (r.qty ?? 0) < 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pastikan setiap baris sudah pilih Produk, Warna, dan Jumlah ≥ 1')),
        );
        return;
      }
    }

    final productsPayload = _rows.map((r) => {
      'produk_id': r.product!.id,
      // di create_garansi warna dikirim name; untuk Return umumnya pakai id — tetap kirim id.
      'warna_id': r.color?.id,
      'quantity': r.qty ?? 0,
      'brand_id': r.brand?.id,
      'kategori_id': r.category?.id,
    }).toList();

    setState(() => _submitting = true);

    try {
      final ok = await ApiService.createReturn(
        companyId: 1,
        departmentId: _deptId!,
        employeeId: _empId!,
        customerId: _custId!,
        categoryId: _catId!,
        phone: _phoneCtrl.text.trim(),
        address: AddressInput(
          provinsiCode: "",
          kotaKabCode: "",
          kecamatanCode: "",
          kelurahanCode: "",
          kodePos: "",
          detailAlamat: _addrCtrl.text.trim(),
        ),
        amount: int.tryParse(_amountCtrl.text.trim()) ?? 0,
        reason: _reasonCtrl.text.trim(),
        note: _noteCtrl.text.trim(),
        products: productsPayload,
        photos: _photos,
      );

      if (!mounted) return;
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Return berhasil dibuat'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal membuat return'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ====== UI ======
  @override
  Widget build(BuildContext context) {
    final disabledAll = _loadingOptions || _submitting;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Return'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      backgroundColor: const Color(0xFF0A1B2D),
      body: _loadingOptions
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isTablet = constraints.maxWidth >= 600;
                    final fieldWidth = isTablet
                        ? (constraints.maxWidth - 60) / 2
                        : (constraints.maxWidth - 20) / 2;

                    return AbsorbPointer(
                      absorbing: disabledAll,
                      child: Opacity(
                        opacity: disabledAll ? 0.6 : 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Data Return',
                                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 16),

                            Wrap(
                              spacing: 20,
                              runSpacing: 16,
                              children: [
                                _dropdownInt('Departemen *',
                                    width: fieldWidth,
                                    value: _deptId,
                                    items: _departments,
                                    onChanged: (v) => _onSelectDepartment(v)),
                                _dropdownInt('Karyawan *',
                                    width: fieldWidth,
                                    value: _empId,
                                    items: _employees,
                                    onChanged: (v) => _onSelectEmployee(v),
                                    loading: _loadingEmployees),
                                _dropdownInt('Kategori Customer *',
                                    width: fieldWidth,
                                    value: _catId,
                                    items: _categories,
                                    onChanged: (v) => _onSelectCategory(v)),
                                _dropdownCustomerOption('Customer *',
                                    width: fieldWidth,
                                    value: _custId,
                                    items: _customers,
                                    onChanged: (id) => _onSelectCustomerId(id),
                                    loading: _loadingCustomers),
                                _textField('Phone *', _phoneCtrl, fieldWidth),
                                _textField('Address', _addrCtrl, fieldWidth, maxLines: 2),
                                _textField('Nominal *', _amountCtrl, fieldWidth,
                                    keyboard: TextInputType.number, prefix: 'Rp '),
                                _textField('Alasan Return *', _reasonCtrl, fieldWidth, maxLines: 2),
                                _textField('Catatan Tambahan', _noteCtrl, fieldWidth, maxLines: 2, hint: 'Opsional'),
                              ],
                            ),

                            const SizedBox(height: 30),
                            const Text('Gambar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 10),
                            _buildPhotos(),

                            const SizedBox(height: 30),
                            const Text('Detail Produk', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 10),

                            Column(children: List.generate(_rows.length, (i) => _productCard(i))),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerRight,
                              child: ElevatedButton.icon(
                                onPressed: _addProduk,
                                icon: const Icon(Icons.add),
                                label: const Text('Tambah Produk'),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                              ),
                            ),

                            const SizedBox(height: 30),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                _formButton('Cancel', Colors.grey, () {
                                  Navigator.pop(context, false);
                                }),
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

  // ====== Helpers UI ======
  Widget _textField(String label, TextEditingController c, double width,
      {int maxLines = 1, TextInputType? keyboard, String? hint, String? prefix}) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white)),
          const SizedBox(height: 6),
          TextFormField(
            controller: c,
            maxLines: maxLines,
            keyboardType: keyboard,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: hint,
              prefixText: prefix,
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
          Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          DropdownButtonFormField<int>(
            value: value,
            items: items.map((o) => DropdownMenuItem(value: o.id, child: Text(o.name))).toList(),
            onChanged: loading ? null : onChanged,
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF22344C),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            dropdownColor: Colors.grey[900],
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }

  // Dropdown Customer (OptionItem)
  Widget _dropdownCustomerOption(String label,
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
          Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          DropdownButtonFormField<int>(
            value: value,
            items: items.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
            onChanged: loading ? null : onChanged,
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF22344C),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            dropdownColor: Colors.grey[900],
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotos() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white30),
        borderRadius: BorderRadius.circular(8),
      ),
      child: _photos.isEmpty
          ? Column(
              children: [
                const Text('Drag & Drop your files or Browse',
                    style: TextStyle(color: Colors.white54)),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _pickFromGallery,
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Pilih Foto'),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                    ),
                    OutlinedButton.icon(
                      onPressed: _pickFromCamera,
                      icon: const Icon(Icons.photo_camera),
                      label: const Text('Kamera'),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                    ),
                  ],
                )
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: List.generate(_photos.length, (i) {
                    final photo = _photos[i];
                    return FutureBuilder<Widget>(
                      future: () async {
                        if (kIsWeb) {
                          final bytes = await photo.readAsBytes();
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(bytes, width: 90, height: 90, fit: BoxFit.cover),
                          );
                        } else {
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(File(photo.path), width: 90, height: 90, fit: BoxFit.cover),
                          );
                        }
                      }(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const SizedBox(
                            width: 90,
                            height: 90,
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        return Stack(
                          children: [
                            snapshot.data!,
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
                      },
                    );
                  }),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _pickFromGallery,
                      icon: const Icon(Icons.add_photo_alternate),
                      label: const Text('Tambah Foto'),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: _pickFromCamera,
                      icon: const Icon(Icons.photo_camera),
                      label: const Text('Kamera'),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                    ),
                  ],
                )
              ],
            ),
    );
  }

  // ---------- Kartu produk (desain + filtering seperti garansi) ----------
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
          // Header bar
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
                  onPressed: () => _removeProduk(i),
                ),
              ],
            ),
          ),

          // Body
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
            child: LayoutBuilder(
              builder: (context, inner) {
                final double itemWidth = (inner.maxWidth - gap) / 2;
                return Wrap(
                  spacing: gap,
                  runSpacing: 16,
                  children: [
                    // Brand
                    SizedBox(
                      width: itemWidth,
                      child: _pillDropdown<OptionItem>(
                        label: 'Brand *',
                        value: _rows[i].brand,
                        items: _rows[i].brands,
                        onChanged: (v) => _onBrandChanged(i, v),
                      ),
                    ),
                    // Kategori by brand
                    SizedBox(
                      width: itemWidth,
                      child: _pillDropdown<OptionItem>(
                        label: 'Kategori *',
                        value: _rows[i].category,
                        items: _rows[i].categories,
                        onChanged: (v) => _onRowCategoryChanged(i, v),
                      ),
                    ),
                    // Produk by brand + kategori
                    SizedBox(
                      width: itemWidth,
                      child: _pillDropdown<OptionItem>(
                        label: 'Produk *',
                        value: _rows[i].product,
                        items: _rows[i].products,
                        onChanged: (v) => _onProductChanged(i, v),
                      ),
                    ),
                    // Warna by produk
                    SizedBox(
                      width: itemWidth,
                      child: _pillDropdown<OptionItem>(
                        label: 'Warna *',
                        value: _rows[i].color,
                        items: _rows[i].colors,
                        onChanged: (v) => _onColorChanged(i, v),
                      ),
                    ),
                    // Qty
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

  // Dropdown "pill" reuse
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

  // Qty field dengan badge
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

  Widget _formButton(String text, Color color, VoidCallback? onPressed, {bool showSpinner=false}) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
          backgroundColor: color, foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14)),
      child: showSpinner
          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
          : Text(text),
    );
  }
}

// ===== Model baris untuk UI (mirip _ProductRow di create_garansi) =====
class _ReturnRow {
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

  Map<String, dynamic> toMap() => {
        'produk_id': product?.id,
        'warna_id': color?.id,
        'quantity': qty ?? 0,
        'brand_id': brand?.id,
        'kategori_id': category?.id,
      };
}
