// lib/pages/create_garansi.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class CreateGaransiScreen extends StatefulWidget {
  const CreateGaransiScreen({super.key});

  @override
  State<CreateGaransiScreen> createState() => _CreateGaransiScreenState();
}

class _CreateGaransiScreenState extends State<CreateGaransiScreen> {
  // ===== Produk list (minimal 1) =====
  final _items = <_ProductItem>[ _ProductItem() ];

  // ===== Date controllers =====
  final TextEditingController _tglPembelian = TextEditingController();
  final TextEditingController _tglKlaim = TextEditingController();

  // ===== Image picker =====
  final ImagePicker _picker = ImagePicker();
  final List<XFile> _photos = [];

  Future<void> _pickFromGallery() async {
    try {
      final files = await _picker.pickMultiImage(imageQuality: 85);
      if (files.isNotEmpty) setState(() => _photos.addAll(files));
    } catch (_) {}
  }

  Future<void> _pickFromCamera() async {
    try {
      final file = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
      if (file != null) setState(() => _photos.add(file));
    } catch (_) {}
  }

  void _removePhoto(int i) => setState(() => _photos.removeAt(i));
  void _addProduk() => setState(() => _items.add(_ProductItem()));
  void _removeProduk(int i) => setState(() => _items.removeAt(i));

  @override
  void dispose() {
    _tglPembelian.dispose();
    _tglKlaim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('nanopiko'),
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
              final bool isTablet = constraints.maxWidth >= 600;
              // Phone: 2 kolom rapat (gap 20), Tablet: lebih lega
              final double fieldWidth =
                  isTablet ? (constraints.maxWidth - 60) / 2 : (constraints.maxWidth - 20) / 2;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Create Garansi',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),

                  // ===== FORM UTAMA (2 kolom, sama gaya return) =====
                  Wrap(
                    spacing: 20,
                    runSpacing: 16,
                    children: [
                      _buildDropdown('Departemen *', ['Sales', 'Marketing'], fieldWidth),
                      _buildDropdown('Karyawan *', ['Aulia', 'Karina'], fieldWidth),
                      _buildDropdown('Kategori Customer *', ['Retail', 'Wholesale'], fieldWidth),
                      _buildDropdown('Customer *', ['Customer A', 'Customer B'], fieldWidth),
                      _buildTextField('Phone *', fieldWidth),
                      _buildTextField('Address', fieldWidth, maxLines: 2),
                      _dateField('Tanggal Pembelian *', _tglPembelian, fieldWidth),
                      _dateField('Tanggal Klaim *', _tglKlaim, fieldWidth),
                      _buildTextField('Alasan Pengajuan *', fieldWidth, maxLines: 2),
                      _buildTextField('Catatan Tambahan', fieldWidth, maxLines: 2, hint: 'Opsional'),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ===== Gambar (upload + preview) =====
                  const Text('Gambar',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(minHeight: 150),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white54),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _photos.isEmpty
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Drag & Drop your files or Browse',
                                  style: TextStyle(color: Colors.white54)),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                alignment: WrapAlignment.center,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: _pickFromGallery,
                                    icon: const Icon(Icons.photo_library),
                                    label: const Text('Pilih Foto'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      side: const BorderSide(color: Colors.white38),
                                    ),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: _pickFromCamera,
                                    icon: const Icon(Icons.photo_camera),
                                    label: const Text('Kamera'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      side: const BorderSide(color: Colors.white38),
                                    ),
                                  ),
                                ],
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
                                  final f = File(_photos[i].path);
                                  return Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.file(f, width: 90, height: 90, fit: BoxFit.cover),
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
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 12,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: _pickFromGallery,
                                    icon: const Icon(Icons.add_photo_alternate),
                                    label: const Text('Tambah Foto'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      side: const BorderSide(color: Colors.white38),
                                    ),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: _pickFromCamera,
                                    icon: const Icon(Icons.photo_camera),
                                    label: const Text('Kamera'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      side: const BorderSide(color: Colors.white38),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                  ),

                  const SizedBox(height: 20),

                  // ===== DETAIL PRODUK (kartu, 2 kolom + hapus) =====
                  const Text('Detail Produk',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),

                  Column(
                    children: List.generate(_items.length, (i) => _productCard(i)),
                  ),

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

                  // ===== BUTTONS =====
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _formButton(context, 'Cancel', Colors.grey, () {
                        Navigator.pop(context, false);
                      }),
                      const SizedBox(width: 12),
                      _formButton(context, 'Create', Colors.blue, () {
                        // TODO: kirim _items & _photos ke API
                        Navigator.pop(context, true);
                      }),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ---------- Helpers umum (sama gaya return) ----------
  Widget _buildTextField(String label, double width,
      {int maxLines = 1, bool enabled = true, String? hint, String? prefix}) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white)),
          const SizedBox(height: 6),
          TextFormField(
            maxLines: maxLines,
            enabled: enabled,
            style: TextStyle(color: enabled ? Colors.white : Colors.white54),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Colors.white38),
              prefixText: prefix,
              prefixStyle: const TextStyle(color: Colors.white),
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

  Widget _buildDropdown(String label, List<String> options, double width, {bool enabled = true}) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: null,
            items: options.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: enabled ? (val) {} : null,
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

  // ---------- Kartu Detail Produk (2 kolom + hapus) ----------
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
          // Header
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
                // Selalu 2 kolom
                final double itemWidth = (inner.maxWidth - gap) / 2;

                return Wrap(
                  spacing: gap,
                  runSpacing: 16,
                  children: [
                    SizedBox(
                      width: itemWidth,
                      child: _pillDropdown(
                        label: 'Brand *',
                        options: const ['Nanolite', 'Pikolite'],
                        value: _items[i].brand,
                        onChanged: (v) => setState(() => _items[i].brand = v),
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _pillDropdown(
                        label: 'Kategori *',
                        options: const ['Downlight', 'Bulb', 'Strip'],
                        value: _items[i].kategori,
                        onChanged: (v) => setState(() => _items[i].kategori = v),
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _pillDropdown(
                        label: 'Produk *',
                        options: const ['Downlight A', 'Downlight B'],
                        value: _items[i].produk,
                        onChanged: (v) => setState(() => _items[i].produk = v),
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _pillDropdown(
                        label: 'Warna *',
                        options: const ['3000K', '4000K', '6500K'],
                        value: _items[i].warna,
                        onChanged: (v) => setState(() => _items[i].warna = v),
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _qtyField(
                        label: 'Jumlah *',
                        value: _items[i].qty?.toString(),
                        onChanged: (txt) => _items[i].qty = int.tryParse(txt),
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

  // ---------- Komponen input pill (dropdown & qty) ----------
  Widget _pillDropdown({
    required String label,
    required List<String> options,
    required String? value,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: value,
          items: options.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
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

  Widget _formButton(BuildContext context, String text, Color color, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
      child: Text(text),
    );
  }
}

// ===== Model data produk sederhana =====
class _ProductItem {
  String? brand;
  String? kategori;
  String? produk;
  String? warna;
  int? qty;

  _ProductItem({this.brand, this.kategori, this.produk, this.warna, this.qty});
}
