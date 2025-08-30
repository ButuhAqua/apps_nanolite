// lib/services/api_service.dart
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/customer.dart';
import '../models/employee_profile.dart';
import '../models/garansi_row.dart';
import '../models/order_row.dart';
import '../models/return_row.dart';

/// Item sederhana utk dropdown
class OptionItem {
  final int id;
  final String name;
  final int? categoryId;
  final int? employeeId;
  final int? departmentId;
  final String? phone;
  final String? address;
  final String? programName;
  final int? programId;

  OptionItem({
    required this.id,
    required this.name,
    this.categoryId,
    this.employeeId,
    this.departmentId,
    this.phone,
    this.address,
    this.programName,
    this.programId,
  });

  factory OptionItem.fromJson(Map<String, dynamic> json) {
    // --- id ---
    int idVal = 0;
    final idCandidates = [
      json['id'],
      json['customer_id'],
      json['category_id'],
      json['program_id'],
      json['value'],
    ];
    for (final c in idCandidates) {
      if (c is int) {
        idVal = c;
        break;
      }
      final parsed = int.tryParse('${c ?? ''}');
      if (parsed != null) {
        idVal = parsed;
        break;
      }
    }

    // --- name ---
    final nameCandidates = [
      json['name'],
      json['nama'],
      json['title'],
      json['label'],
      json['text'],
      json['customer_name'],
      '${json['name'] ?? ''} ${json['phone'] ?? ''}',
    ];
    String nameVal = '-';
    for (final c in nameCandidates) {
      final s = (c ?? '').toString();
      if (s.trim().isNotEmpty) {
        nameVal = s;
        break;
      }
    }

    // --- address -> string manusiawi ---
    String addressText = '-';
    if (json['address'] is List && (json['address'] as List).isNotEmpty) {
      final addr = json['address'][0];
      if (addr is Map) {
        final detail = addr['detail_alamat']?.toString() ?? '';
        final kel = addr['kelurahan']?['name']?.toString() ?? '';
        final kec = addr['kecamatan']?['name']?.toString() ?? '';
        final kota = addr['kota_kab']?['name']?.toString() ?? '';
        final prov = addr['provinsi']?['name']?.toString() ?? '';
        final kodePos = addr['kode_pos']?.toString() ?? '';
        final parts = [detail, kel, kec, kota, prov, kodePos]
            .where((e) => e.trim().isNotEmpty && e.toLowerCase() != 'null')
            .toList();
        addressText = parts.isEmpty ? '-' : parts.join(', ');
      }
    } else if (json['alamat_detail'] != null) {
      addressText = json['alamat_detail'].toString();
    } else if (json['address'] is String) {
      addressText = json['address'];
    }

    return OptionItem(
      id: idVal,
      name: nameVal,
      categoryId: ApiService._extractCategoryId(json),
      employeeId: json['employee_id'] != null
          ? int.tryParse('${json['employee_id']}')
          : null,
      departmentId: json['department_id'] != null
          ? int.tryParse('${json['department_id']}')
          : null,
      phone: json['phone']?.toString(),
      address: addressText,
      programName: json['customer_program']?['name'],
      programId: json['customer_program']?['id'],
    );
  }

  @override
  String toString() => 'OptionItem(id: $id, name: $name)';
}

/// Input alamat sesuai repeater di CustomerResource
class AddressInput {
  final String provinsiCode;
  final String kotaKabCode;
  final String kecamatanCode;
  final String kelurahanCode;
  final String? kodePos;
  final String detailAlamat;

  AddressInput({
    required this.provinsiCode,
    required this.kotaKabCode,
    required this.kecamatanCode,
    required this.kelurahanCode,
    required this.detailAlamat,
    this.kodePos,
  });

  Map<String, dynamic> toMap() => {
        'provinsi_code': provinsiCode,
        'kota_kab_code': kotaKabCode,
        'kecamatan_code': kecamatanCode,
        'kelurahan_code': kelurahanCode,
        if (kodePos != null) 'kode_pos': kodePos,
        'detail_alamat': detailAlamat,
      };
}

/// Hasil perhitungan total
class OrderTotals {
  final int total; // jumlah semua subtotal
  final int totalAfterDiscount; // setelah diskon (jika aktif)
  const OrderTotals({required this.total, required this.totalAfterDiscount});
}

class ApiService {
  static const String baseUrl = 'http://localhost/api';

  // ---------- Helpers umum ----------
  static int? _extractCategoryId(Map<String, dynamic> json) {
    if (json['customer_category'] is Map) {
      return int.tryParse('${json['customer_category']['id']}');
    }
    return int.tryParse(
      '${json['customer_categories_id'] ?? json['customer_category_id'] ?? ''}',
    );
  }

  static String formatAddress(dynamic json) {
    // cek alamat_detail
    if (json is Map &&
        json['alamat_detail'] is List &&
        (json['alamat_detail'] as List).isNotEmpty) {
      final addr = json['alamat_detail'][0];
      if (addr is Map) {
        final detail = addr['detail_alamat']?.toString() ?? '';
        final kel = addr['kelurahan']?['name']?.toString() ?? '';
        final kec = addr['kecamatan']?['name']?.toString() ?? '';
        final kota = addr['kota_kab']?['name']?.toString() ?? '';
        final prov = addr['provinsi']?['name']?.toString() ?? '';
        final kodePos = addr['kode_pos']?.toString() ?? '';
        final parts = [detail, kel, kec, kota, prov, kodePos]
            .where((e) => e.trim().isNotEmpty && e.toLowerCase() != 'null')
            .toList();
        return parts.isEmpty ? '-' : parts.join(', ');
      }
    }

    // fallback cek langsung "address"
    if (json is List && json.isNotEmpty) {
      final addr = json[0];
      if (addr is Map) {
        final detail = addr['detail_alamat']?.toString() ?? '';
        final kel = addr['kelurahan']?['name']?.toString() ?? '';
        final kec = addr['kecamatan']?['name']?.toString() ?? '';
        final kota = addr['kota_kab']?['name']?.toString() ?? '';
        final prov = addr['provinsi']?['name']?.toString() ?? '';
        final kodePos = addr['kode_pos']?.toString() ?? '';
        final parts = [detail, kel, kec, kota, prov, kodePos]
            .where((e) => e.trim().isNotEmpty && e.toLowerCase() != 'null')
            .toList();
        return parts.isEmpty ? '-' : parts.join(', ');
      }
    }

    if (json is String && json.trim().isNotEmpty) {
      return json;
    }

    return '-';
  }

  // ====================== PARSER KHUSUS CUSTOMER ======================
  static OptionItem _parseCustomer(Map<String, dynamic> json) {
    final id = int.tryParse('${json['id'] ?? json['customer_id']}') ?? 0;

    // Ambil nama
    final nameCandidates = [
      json['name'],
      json['nama'],
      json['customer_name'],
      '${json['name'] ?? ''} ${json['phone'] ?? ''}',
    ];
    String nameVal = '-';
    for (final c in nameCandidates) {
      final s = (c ?? '').toString();
      if (s.trim().isNotEmpty) {
        nameVal = s;
        break;
      }
    }

    return OptionItem(
      id: id,
      name: nameVal,
      phone: json['phone']?.toString(),
      categoryId: ApiService._extractCategoryId(json),
      address: ApiService.formatAddress(json),
    );
  }

  static Future<Map<String, String>> _authorizedHeaders(
      {bool jsonContent = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    return {
      'Accept': 'application/json',
      if (jsonContent) 'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  static dynamic _safeDecode(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return body;
    }
  }

  static Uri _buildUri(String path, {Map<String, String>? query}) {
    final normalizedBase = baseUrl.replaceAll(RegExp(r'/+$'), '');
    final normalizedPath = path.replaceAll(RegExp(r'^/+'), '');
    final raw = '$normalizedBase/$normalizedPath';
    return (query == null || query.isEmpty)
        ? Uri.parse(raw)
        : Uri.parse(raw).replace(queryParameters: {...query});
  }

  static List<Map<String, dynamic>> _extractList(dynamic decoded) {
    if (decoded is List) {
      return decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (decoded is Map) {
      final d = decoded['data'];

      if (d is List) {
        return d
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }

      if (d is Map && d['data'] is List) {
        return (d['data'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }

      final items = decoded['items'];
      if (items is List) {
        return items
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }

      final cust = decoded['customers'];
      if (cust is List) {
        return cust
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    }
    return <Map<String, dynamic>>[];
  }

  // ---------- AUTH ----------
  /// Simpan info user dari payload login (jika ada)
  static Future<void> _saveUserFromLoginPayload(dynamic body) async {
    try {
      if (body is! Map) return;
      final map = Map<String, dynamic>.from(body);
      final u = (map['user'] is Map)
          ? Map<String, dynamic>.from(map['user'])
          : (map['data'] is Map)
              ? Map<String, dynamic>.from(map['data'])
              : null;
      if (u == null) return;
      final prefs = await SharedPreferences.getInstance();
      if (u['email'] != null) {
        await prefs.setString('user_email', u['email'].toString());
      }
      if (u['name'] != null) {
        await prefs.setString('user_name', u['name'].toString());
      }
    } catch (_) {}
  }

  /// Decode JWT utk ambil email jika memungkinkan
  static Map<String, dynamic>? _decodeJwt(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      String normalized = parts[1];
      // base64url padding
      while (normalized.length % 4 != 0) {
        normalized += '=';
      }
      final payload = utf8.decode(base64Url.decode(normalized));
      final map = jsonDecode(payload);
      if (map is Map<String, dynamic>) return map;
    } catch (_) {}
    return null;
  }

  static Future<bool> login(String email, String password) async {
    try {
      final url = _buildUri('auth/login');
      final res = await http.post(
        url,
        headers: await _authorizedHeaders(jsonContent: true),
        body: jsonEncode({'email': email, 'password': password}),
      );
      final body = _safeDecode(res.body);
      if ((res.statusCode == 200 || res.statusCode == 201) &&
          body is Map &&
          body['token'] != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', body['token']);
        // simpan email dari payload user jika ada
        await _saveUserFromLoginPayload(body);
        // simpan email dari JWT jika tersedia
        final jwt = _decodeJwt(body['token'].toString());
        final jwtEmail = jwt?['email'] ?? jwt?['sub'];
        if (jwtEmail is String && jwtEmail.isNotEmpty) {
          await prefs.setString('user_email', jwtEmail);
        }
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('user_email');
    await prefs.remove('user_name');
  }

  /// Ambil informasi user login:
  /// 1) prefs (user_email) kalau ada
  /// 2) coba beberapa endpoint
  /// 3) decode JWT
  static Future<Map<String, dynamic>?> fetchAuthMe() async {
    // 1) dari prefs
    final prefs = await SharedPreferences.getInstance();
    final cachedEmail = prefs.getString('user_email');
    final cachedName = prefs.getString('user_name');
    if (cachedEmail != null && cachedEmail.isNotEmpty) {
      return {'email': cachedEmail, if (cachedName != null) 'name': cachedName};
    }

    // 2) endpoint yang umum
    final headers = await _authorizedHeaders();
    for (final path in [
      'auth/me',
      'me',
      'user',
      'auth/user',
      'users/me',
      'profile',
    ]) {
      try {
        final uri = _buildUri(path);
        final res = await http.get(uri, headers: headers);
        if (res.statusCode != 200) continue;
        final decoded = _safeDecode(res.body);
        final data = (decoded is Map && decoded['data'] is Map)
            ? Map<String, dynamic>.from(decoded['data'])
            : (decoded is Map ? Map<String, dynamic>.from(decoded) : null);
        if (data != null && (data['email'] ?? data['user']?['email']) != null) {
          // cache supaya panggilan berikutnya cepat
          final email = (data['email'] ?? data['user']?['email']).toString();
          await prefs.setString('user_email', email);
          if (data['name'] != null) {
            await prefs.setString('user_name', data['name'].toString());
          }
          return data;
        }
      } catch (_) {}
    }

    // 3) decode JWT
    final token = prefs.getString('token');
    if (token != null && token.isNotEmpty) {
      final jwt = _decodeJwt(token);
      final email = jwt?['email'] ?? jwt?['sub'];
      if (email is String && email.isNotEmpty) {
        await prefs.setString('user_email', email);
        return {'email': email};
      }
    }

    return null;
  }

  /// Ambil profil employee untuk user yang login (dengan filter email).
  /// Jika email tidak tersedia, fallback: ambil 1 employee aktif supaya UI tidak kosong.
  static Future<EmployeeProfile?> fetchMyEmployeeProfile() async {
    String? email;
    final me = await fetchAuthMe();
    email = (me?['email'] ?? me?['user']?['email'] ?? me?['data']?['email'])
        ?.toString();

    final headers = await _authorizedHeaders();

    // Jika punya email -> filter by email
    if (email != null && email.isNotEmpty) {
      final uri = _buildUri('employees', query: {
        'per_page': '1',
        'filter[email]': email,
      });
      final res = await http.get(uri, headers: headers);
      if (res.statusCode == 200) {
        final decoded = _safeDecode(res.body);
        final list = _extractList(decoded);
        if (list.isNotEmpty) {
          final map = Map<String, dynamic>.from(list.first);
          map['photo'] = _absoluteUrl(map['photo']?.toString());
          return EmployeeProfile.fromJson(map);
        }
      }
      // kalau gagal, lanjut fallback ke bawah
    }

    // Fallback terakhir: ambil 1 employee aktif/random
    try {
      final uri = _buildUri('employees', query: {'per_page': '1'});
      final res = await http.get(uri, headers: headers);
      if (res.statusCode == 200) {
        final decoded = _safeDecode(res.body);
        final list = _extractList(decoded);
        if (list.isNotEmpty) {
          final map = Map<String, dynamic>.from(list.first);
          map['photo'] = _absoluteUrl(map['photo']?.toString());
          return EmployeeProfile.fromJson(map);
        }
      }
    } catch (_) {}
    return null;
  }

  /// Ambil URL gambar banner dari backend (maks 4)
  static Future<List<String>> fetchBannerImages() async {
    final headers = await _authorizedHeaders();
    for (final path in ['banners', 'banner']) {
      try {
        final uri = _buildUri(path, query: {'per_page': '50'});
        final res = await http.get(uri, headers: headers);
        if (res.statusCode != 200) continue;

        final decoded = _safeDecode(res.body);
        final list = _extractList(decoded);

        final urls = <String>[];
        for (final raw in list) {
          if (raw is Map) {
            for (final key in ['image_1', 'image_2', 'image_3', 'image_4']) {
              final v = (raw[key] ?? '').toString().trim();
              if (v.isEmpty || v.toLowerCase() == 'null') continue;
              urls.add(_absoluteUrl(v));
            }
          }
        }
        final uniq = urls.where((e) => e.isNotEmpty).toSet().toList();
        if (uniq.isNotEmpty) return uniq.take(4).toList();
      } catch (_) {}
    }
    return <String>[];
  }

  // ---------- DROPDOWN ----------
  Future<List<OptionItem>> _fetchOptionsTryPaths(
    List<String> paths, {
    Map<String, String>? query,
    bool filterActive = true,
  }) async {
    final headers = await _authorizedHeaders();
    for (final p in paths) {
      final uri =
          _buildUri(p, query: {'per_page': '1000', ...(query ?? const {})});
      try {
        final res = await http.get(uri, headers: headers);
        if (res.statusCode != 200) continue;

        final decoded = _safeDecode(res.body);
        var list = _extractList(decoded);
        if (list.isEmpty) continue;

        if (filterActive) {
          list = list.where((m) {
            final status =
                (m['status'] ?? '').toString().toLowerCase().trim();
            final pengajuan =
                (m['status_pengajuan'] ?? '').toString().toLowerCase().trim();
            final okStatus = status.isEmpty ||
                status == 'active' ||
                status == 'aktif' ||
                status == '1' ||
                status == 'true';
            final okApproved = pengajuan.isEmpty ||
                pengajuan == 'disetujui' ||
                pengajuan == 'approved' ||
                pengajuan == '1' ||
                pengajuan == 'true';
            return okStatus && okApproved;
          }).toList();
        }

        final options = list
            .map(OptionItem.fromJson)
            .where((o) => o.id != 0 && o.name.isNotEmpty)
            .toList();
        if (options.isNotEmpty) return options;
      } catch (_) {}
    }
    return <OptionItem>[];
  }

  // Departments
  static Future<List<OptionItem>> fetchDepartments() =>
      ApiService()._fetchOptionsTryPaths(['departments']);

  // ======================= DROPDOWN =======================

// === CHANGED: sekarang pakai /orders?type=employees, bukan /customers ===
static Future<List<OptionItem>> fetchEmployees({required int departmentId}) async {
  return ApiService()._fetchOptionsTryPaths(
    ['orders'], // << CHANGED
    query: {
      'type': 'employees',          // << CHANGED
      'department_id': '$departmentId',
    },
    filterActive: false,
  );
}

// === CHANGED: sekarang pakai /orders?type=customer-categories & bawa employee_id ===
static Future<List<OptionItem>> fetchCustomerCategories({int? employeeId}) {
  final q = <String, String>{'type': 'customer-categories'}; // << CHANGED
  if (employeeId != null) q['employee_id'] = '$employeeId';  // << CHANGED
  return ApiService()._fetchOptionsTryPaths(
    ['orders'],                 // << CHANGED
    query: q,                   // << CHANGED
    filterActive: true,
  );
}

// === CHANGED (opsional utk konsisten): pakai /orders?type=customer-programs ===
static Future<List<OptionItem>> fetchCustomerPrograms({int? employeeId, int? categoryId}) {
  // Handler backend-mu untuk 'customer-programs' hanya mendukung customer_id.
  // Jadi di sini kita tetap load semua program (tanpa filter), biar kompatibel.
  return ApiService()._fetchOptionsTryPaths(
    ['orders'],                       // << CHANGED
    query: {'type': 'customer-programs'}, // << CHANGED
    filterActive: true,
  );
}
// === ADDED: ambil SEMUA kategori customer (tanpa filter employee)
static Future<List<OptionItem>> fetchCustomerCategoriesAll() {
  return ApiService()._fetchOptionsTryPaths(
    ['customer-categories'],
    filterActive: true,
  );
}

// === ADDED: ambil customers yang sudah terfilter Dept + Employee
static Future<List<OptionItem>> fetchCustomersByDeptEmp({
  required int departmentId,
  required int employeeId,
}) async {
  final headers = await _authorizedHeaders();
  final uri = _buildUri('orders', query: {
    'type': 'customers',
    'department_id': '$departmentId',
    'employee_id': '$employeeId',
    'per_page': '1000',
  });

  final res = await http.get(uri, headers: headers);
  if (res.statusCode != 200) return [];

  final decoded = _safeDecode(res.body);
  final list = _extractList(decoded);
  return list.map<OptionItem>((m) => _parseCustomer(m)).toList();
}


  static Future<List<OptionItem>> fetchCustomerProgramsByCategory(
      int categoryId) async {
    return ApiService()._fetchOptionsTryPaths(
      ['customer-programs'],
      query: {'customer_category_id': '$categoryId'},
      filterActive: true,
    );
  }

  static Future<List<OptionItem>> fetchCustomersByCategory(
      int categoryId) async {
    final headers = await _authorizedHeaders();
    final uri = _buildUri('customers', query: {'per_page': '1000'});
    final res = await http.get(uri, headers: headers);
    if (res.statusCode != 200) {
      // ignore: avoid_print
      print(
          "DEBUG fetchCustomersByCategory failed: ${res.statusCode} ${res.body}");
      return [];
    }

    final decoded = _safeDecode(res.body);
    final list = _extractList(decoded);

    final customers = list.map<OptionItem>((m) => _parseCustomer(m)).toList();

    return customers.where((c) => c.categoryId == categoryId).toList();
  }

  static Future<List<OptionItem>> fetchCustomersFiltered({
    required int departmentId,
    required int employeeId,
    required int categoryId,
  }) async {
    final headers = await _authorizedHeaders();
    final uri = _buildUri('orders', query: {
      'type': 'customers',
      'department_id': '$departmentId',
      'employee_id': '$employeeId',
      'customer_categories_id': '$categoryId',
      'per_page': '1000',
    });

    final res = await http.get(uri, headers: headers);
    if (res.statusCode != 200) return [];

    final decoded = _safeDecode(res.body);
    final list = _extractList(decoded);
    return list.map<OptionItem>((m) => _parseCustomer(m)).toList();
  }

  // ---- Detail customer (model) ----
  static Future<Customer> fetchCustomerDetail(int id) async {
    final headers = await _authorizedHeaders();
    final uri = _buildUri('customers/$id');
    final res = await http.get(uri, headers: headers);
    if (res.statusCode != 200) {
      throw Exception('Failed to load customer detail: ${res.statusCode}');
    }
    final decoded = _safeDecode(res.body);
    Map<String, dynamic>? data;

    if (decoded is Map) {
      if (decoded['data'] is Map) {
        data = Map<String, dynamic>.from(decoded['data']);
      } else {
        data = Map<String, dynamic>.from(decoded);
      }
    }
    if (data == null) throw Exception('Customer detail not found');
    return Customer.fromJson(data);
  }

  // ---- Detail customer RAW map (untuk formatAddress) ----
  static Future<Map<String, dynamic>> fetchCustomerDetailRaw(int id) async {
    final headers = await _authorizedHeaders();
    final uri = _buildUri('customers/$id');
    final res = await http.get(uri, headers: headers);
    if (res.statusCode != 200) {
      throw Exception('Failed to load customer detail: ${res.statusCode}');
    }
    final decoded = _safeDecode(res.body);
    if (decoded is Map && decoded['data'] is Map) {
      return Map<String, dynamic>.from(decoded['data']);
    }
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
    return <String, dynamic>{};
  }

  /// Alias biar kompatibel kalau ada kode lama memanggil fetchCustomerDetailMap
  static Future<Map<String, dynamic>> fetchCustomerDetailMap(int id) =>
      fetchCustomerDetailRaw(id);

  // ---- Produk dependensi ----
  static Future<List<OptionItem>> fetchCategoriesByBrand(int brandId) {
    return ApiService()._fetchOptionsTryPaths(
      ['orders'],
      query: {'type': 'categories-by-brand', 'brand_id': '$brandId'},
      filterActive: true,
    );
  }

  static Future<List<OptionItem>> fetchProductsByBrandCategory(
      int brandId, int categoryId) {
    return ApiService()._fetchOptionsTryPaths(
      ['orders'],
      query: {
        'type': 'products-by-brand-category',
        'brand_id': '$brandId',
        'category_id': '$categoryId',
      },
      filterActive: true,
    );
  }

  static Future<List<OptionItem>> fetchColorsByProductFiltered(
      int productId) {
    return ApiService()._fetchOptionsTryPaths(
      ['orders'],
      query: {'type': 'colors-by-product', 'product_id': '$productId'},
      filterActive: false,
    );
  }

  /// Ambil semua customer aktif + approved
  static Future<List<OptionItem>> fetchCustomersDropdown() async {
    final headers = await _authorizedHeaders();
    final uri = _buildUri('customers', query: {'per_page': '1000'});
    final res = await http.get(uri, headers: headers);
    if (res.statusCode != 200) return [];

    final decoded = _safeDecode(res.body);
    final list = _extractList(decoded);

    final customers = list
        .where((m) {
          final status = (m['status'] ?? '').toString().toLowerCase();
          final pengajuan =
              (m['status_pengajuan'] ?? '').toString().toLowerCase();
          return (status == 'active' ||
                  status == 'aktif' ||
                  status == '1' ||
                  status == 'true') &&
              (pengajuan == 'disetujui' ||
                  pengajuan == 'approved' ||
                  pengajuan == '1' ||
                  pengajuan == 'true');
        })
        .map<OptionItem>((m) => _parseCustomer(m))
        .toList();

    return customers;
  }

  // Categories / Brands / Products
  static Future<List<OptionItem>> fetchProductCategories() =>
      ApiService()._fetchOptionsTryPaths(['categories'], filterActive: true);
  static Future<List<OptionItem>> fetchBrands() =>
      ApiService()._fetchOptionsTryPaths(['brands'], filterActive: true);
  static Future<List<OptionItem>> fetchProducts() =>
      ApiService()._fetchOptionsTryPaths(['products'], filterActive: true);

  // === Wilayah (Indonesia) ===
  static Future<List<OptionItem>> fetchProvinces() =>
      ApiService()._fetchOptionsTryPaths(
        ['customers'],
        query: {'type': 'provinces'},
        filterActive: false,
      );
  static Future<List<OptionItem>> fetchCities(String provinceCode) =>
      ApiService()._fetchOptionsTryPaths(
        ['customers'],
        query: {'type': 'cities', 'province_code': provinceCode},
        filterActive: false,
      );
  static Future<List<OptionItem>> fetchDistricts(String cityCode) =>
      ApiService()._fetchOptionsTryPaths(
        ['customers'],
        query: {'type': 'districts', 'city_code': cityCode},
        filterActive: false,
      );
  static Future<List<OptionItem>> fetchVillages(String districtCode) =>
      ApiService()._fetchOptionsTryPaths(
        ['customers'],
        query: {'type': 'villages', 'district_code': districtCode},
        filterActive: false,
      );
  static Future<String?> fetchPostalCodeByVillage(String villageCode) async {
    final headers = await _authorizedHeaders();
    final uri = _buildUri('customers', query: {
      'type': 'postal_code',
      'village_code': villageCode,
    });
    try {
      final res = await http.get(uri, headers: headers);
      if (res.statusCode == 200) {
        final decoded = _safeDecode(res.body);
        if (decoded is Map && decoded['postal_code'] != null) {
          return decoded['postal_code'].toString();
        }
      }
    } catch (_) {}
    return null;
  }

  // Colors untuk 1 produk (fallback ke berbagai bentuk)
  static Future<List<OptionItem>> fetchColorsByProduct(int productId) async {
    final headers = await _authorizedHeaders();

    final tries = <Uri>[
      _buildUri('products/$productId', query: {'include': 'colors'}),
      _buildUri('products/$productId'),
    ];

    for (final uri in tries) {
      try {
        final res = await http.get(uri, headers: headers);
        if (res.statusCode != 200) continue;

        final decoded = _safeDecode(res.body);
        final data = (decoded is Map && decoded['data'] is Map)
            ? Map<String, dynamic>.from(decoded['data'])
            : (decoded is Map
                ? Map<String, dynamic>.from(decoded)
                : <String, dynamic>{});

        final dynamic raw = data['colors'] ??
            data['warna'] ??
            (data['attributes'] is Map
                ? (data['attributes'] as Map)['colors']
                : null) ??
            data['color_options'];

        List<OptionItem> out = [];

        if (raw is List) {
          if (raw.isNotEmpty && raw.first is! Map) {
            final list = raw
                .map((e) => e.toString())
                .where((s) => s.trim().isNotEmpty)
                .toList();
            out = [
              for (int i = 0; i < list.length; i++)
                OptionItem(id: i + 1, name: list[i]),
            ];
          } else {
            out = raw
                .whereType<Map>()
                .map((m) {
                  final name =
                      (m['name'] ?? m['nama'] ?? m['label'] ?? '').toString();
                  final id = int.tryParse('${m['id'] ?? 0}') ?? 0;
                  return id > 0
                      ? OptionItem(id: id, name: name)
                      : OptionItem(id: name.hashCode, name: name);
                })
                .where((o) => o.name.trim().isNotEmpty)
                .toList();
          }
        } else if (raw is String && raw.trim().isNotEmpty) {
          final parts = raw
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();
          out = [
            for (int i = 0; i < parts.length; i++)
              OptionItem(id: i + 1, name: parts[i]),
          ];
        }

        // ignore: avoid_print
        print('DEBUG colors for product $productId => $out');

        if (out.isNotEmpty) return out;
      } catch (e) {
        // ignore: avoid_print
        print('DEBUG fetchColorsByProduct error: $e');
      }
    }

    return <OptionItem>[];
  }

  // Harga produk
  static Future<int> fetchProductPrice(int productId) async {
    final headers = await _authorizedHeaders();
    final tries = <Uri>[
      _buildUri('products/$productId', query: {'include': 'prices'}),
      _buildUri('products/$productId'),
    ];

    for (final uri in tries) {
      try {
        final res = await http.get(uri, headers: headers);
        if (res.statusCode != 200) continue;

        final decoded = _safeDecode(res.body);
        final data = (decoded is Map && decoded['data'] is Map)
            ? Map<String, dynamic>.from(decoded['data'])
            : (decoded is Map
                ? Map<String, dynamic>.from(decoded)
                : <String, dynamic>{});

        final candidates = [
          data['price'],
          data['harga'],
          (data['prices'] is Map)
              ? ((data['prices'] as Map)['sale'] ??
                  (data['prices'] as Map)['base'])
              : null,
          (data['attributes'] is Map)
              ? (data['attributes'] as Map)['price']
              : null,
        ];

        for (final c in candidates) {
          if (c == null) continue;
          if (c is int) return c;
          if (c is double) return c.round();
          final parsed =
              int.tryParse(c.toString().replaceAll(RegExp(r'[^\d\-]'), ''));
          if (parsed != null) return parsed;
        }
      } catch (_) {}
    }
    return 0;
  }

  // ---------- CUSTOMERS ----------
  static Future<bool> createCustomer({
    required int companyId,
    required int departmentId,
    required int employeeId,
    required String name,
    required String phone,
    String? email,
    required int customerCategoryId,
    int? customerProgramId,
    String? gmapsLink,
    required AddressInput address,
    List<XFile>? photos,
  }) async {
    final url = _buildUri('customers');
    final headers = await _authorizedHeaders();

    var request = http.MultipartRequest('POST', url);
    request.headers.addAll(headers);

    request.fields['company_id'] = companyId.toString();
    request.fields['department_id'] = departmentId.toString();
    request.fields['employee_id'] = employeeId.toString();
    request.fields['name'] = name;
    request.fields['phone'] = phone;
    if (email != null && email.isNotEmpty) request.fields['email'] = email;
    request.fields['customer_categories_id'] = customerCategoryId.toString();
    if (customerProgramId != null) {
      request.fields['customer_program_id'] = customerProgramId.toString();
    }
    if (gmapsLink != null && gmapsLink.isNotEmpty) {
      request.fields['gmaps_link'] = gmapsLink;
    }

    // address
    request.fields['address[0][provinsi_code]'] = address.provinsiCode;
    request.fields['address[0][kota_kab_code]'] = address.kotaKabCode;
    request.fields['address[0][kecamatan_code]'] = address.kecamatanCode;
    request.fields['address[0][kelurahan_code]'] = address.kelurahanCode;
    if (address.kodePos != null) {
      request.fields['address[0][kode_pos]'] = address.kodePos!;
    }
    request.fields['address[0][detail_alamat]'] = address.detailAlamat;

    // upload multi foto
    if (photos != null && photos.isNotEmpty) {
      for (final photo in photos) {
        if (kIsWeb) {
          final bytes = await photo.readAsBytes();
          request.files.add(
            http.MultipartFile.fromBytes('image[]', bytes, filename: photo.name),
          );
        } else {
          request.files.add(
            await http.MultipartFile.fromPath('image[]', photo.path),
          );
        }
      }
    }

    final streamedResponse = await request.send();
    final res = await http.Response.fromStream(streamedResponse);

    // ignore: avoid_print
    print('DEBUG createCustomer => ${res.statusCode} ${res.body}');

    return res.statusCode == 200 || res.statusCode == 201;
  }

  static Future<List<Customer>> fetchCustomers(
      {int page = 1, int perPage = 20, String? q}) async {
    final headers = await _authorizedHeaders();
    final params = <String, String>{
      'page': '$page',
      'per_page': '$perPage',
      if (q != null && q.isNotEmpty) 'filter[search]': q,
    };
    final uri = _buildUri('customers', query: params);
    final res = await http.get(uri, headers: headers);
    if (res.statusCode != 200) {
      throw Exception('GET /customers ${res.statusCode}: ${res.body}');
    }
    final items = _extractList(_safeDecode(res.body));
    return items.map(Customer.fromJson).toList();
  }

  // ---------- SALES ORDERS ----------
  static OrderTotals computeTotals({
    required List<Map<String, dynamic>> products,
    required double diskon1,
    required double diskon2,
    required bool diskonsEnabled,
  }) {
    int total = 0;
    for (final p in products) {
      final qty = (p['quantity'] is int)
          ? (p['quantity'] as int)
          : int.tryParse('${p['quantity'] ?? 0}') ?? 0;
      final price = (p['price'] is int)
          ? (p['price'] as int)
          : (p['price'] is double)
              ? (p['price'] as double).round()
              : int.tryParse('${p['price'] ?? 0}') ?? 0;
      total += price * qty;
    }

    if (!diskonsEnabled) {
      return OrderTotals(total: total, totalAfterDiscount: total);
    }

    double afterDiskon1 = total * (1.0 - (diskon1 / 100.0));
    double afterDiskon2 = afterDiskon1 * (1.0 - (diskon2 / 100.0));

    final int totalAfter =
        afterDiskon2.isNaN || afterDiskon2.isInfinite ? total : afterDiskon2.round();

    return OrderTotals(total: total, totalAfterDiscount: totalAfter);
  }

  // CREATE ORDER
  static Future<bool> createOrder({
    required int companyId,
    required int departmentId,
    required int employeeId,
    required int customerId,
    required int categoryId,
    int? programId,
    required String phone,
    required String addressText,
    bool programEnabled = false,
    bool rewardEnabled = false,
    int programPoint = 0,
    int rewardPoint = 0,
    double diskon1 = 0,
    double diskon2 = 0,
    String? penjelasanDiskon1,
    String? penjelasanDiskon2,
    bool diskonsEnabled = false,
    required List<Map<String, dynamic>> products,
    String paymentMethod = "tempo",
    String statusPembayaran = "belum bayar",
    String status = "pending",
    List<XFile>? files,
  }) async {
    final url = _buildUri('orders');
    final headers = await _authorizedHeaders();

    final totals = computeTotals(
      products: products,
      diskon1: diskon1,
      diskon2: diskon2,
      diskonsEnabled: diskonsEnabled,
    );

    var request = http.MultipartRequest('POST', url);
    request.headers.addAll(headers);

    request.fields['company_id'] = companyId.toString();
    request.fields['department_id'] = departmentId.toString();
    request.fields['employee_id'] = employeeId.toString();
    request.fields['customer_id'] = customerId.toString();
    request.fields['customer_categories_id'] = categoryId.toString();
    if (programId != null) {
      request.fields['customer_program_id'] = programId.toString();
    }
    request.fields['phone'] = phone;
    request.fields['address'] = addressText;

    request.fields['program_enabled'] = programEnabled ? '1' : '0';
    request.fields['reward_enabled'] = rewardEnabled ? '1' : '0';
    request.fields['jumlah_program'] = programPoint.toString();
    request.fields['reward_point'] = rewardPoint.toString();
    request.fields['diskon_1'] = diskon1.toString();
    request.fields['diskon_2'] = diskon2.toString();
    request.fields['diskons_enabled'] = diskonsEnabled ? '1' : '0';
    if (penjelasanDiskon1 != null && penjelasanDiskon1.isNotEmpty) {
      request.fields['penjelasan_diskon_1'] = penjelasanDiskon1;
    }
    if (penjelasanDiskon2 != null && penjelasanDiskon2.isNotEmpty) {
      request.fields['penjelasan_diskon_2'] = penjelasanDiskon2;
    }

    request.fields['payment_method'] = paymentMethod;
    request.fields['status_pembayaran'] = statusPembayaran;
    request.fields['status'] = status;
    request.fields['total_harga'] = totals.total.toString();
    request.fields['total_harga_after_tax'] =
        totals.totalAfterDiscount.toString();

    for (int i = 0; i < products.length; i++) {
      final p = products[i];

      final produkId = (p['produk_id'] ?? '').toString();
      final warnaId  = (p['warna_id'] ?? '').toString();
      final qty      = (p['quantity'] ?? 0).toString();
      final price    = (p['price'] ?? 0).toString();

      request.fields['products[$i][produk_id]'] = produkId;
      if (warnaId.isNotEmpty) {
        request.fields['products[$i][warna_id]'] = warnaId;
      }
      request.fields['products[$i][quantity]'] = qty;
      request.fields['products[$i][price]']    = price;
    }

    if (files != null && files.isNotEmpty) {
      for (final file in files) {
        if (kIsWeb) {
          final bytes = await file.readAsBytes();
          request.files.add(http.MultipartFile.fromBytes(
            'files[]',
            bytes,
            filename: file.name,
          ));
        } else {
          request.files
              .add(await http.MultipartFile.fromPath('files[]', file.path));
        }
      }
    }

    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);

    // ignore: avoid_print
    print("DEBUG createOrder => ${res.statusCode} ${res.body}");

    return res.statusCode == 200 || res.statusCode == 201;
  }

  // FETCH ALL ORDER
  static Future<List<OrderRow>> fetchOrderRows({
    int page = 1,
    int perPage = 20,
    String? q,
    String? status,
  }) async {
    final headers = await _authorizedHeaders();
    final paths = ['orders', 'sales-orders', 'sales_orders'];
    for (final p in paths) {
      final params = <String, String>{
        'page': '$page',
        'per_page': '$perPage',
        if (q != null && q.isNotEmpty) 'filter[search]': q,
        if (status != null && status.isNotEmpty) 'filter[status]': status,
      };
      final uri = _buildUri(p, query: params);
      final res = await http.get(uri, headers: headers);
      if (res.statusCode != 200) continue;
      final items = _extractList(_safeDecode(res.body));
      if (items.isEmpty) continue;

      return items.map((raw) {
        final map = Map<String, dynamic>.from(raw);
        map['file_pdf_url'] = _absoluteUrl(
          (map['file_pdf_url'] ??
                  map['invoice_pdf_url'] ??
                  map['order_file'] ??
                  map['pdf_url'] ??
                  map['document_url'] ??
                  '')
              .toString(),
        );
        return OrderRow.fromJson(map);
      }).toList();
    }
    return <OrderRow>[];
  }

  // FETCH DETAIL ORDER
  static Future<OrderRow> fetchOrderRowDetail(int id) async {
    final headers = await _authorizedHeaders();
    final paths = ['orders/$id', 'sales-orders/$id', 'sales_orders/$id'];
    for (final p in paths) {
      final uri = _buildUri(p);
      final res = await http.get(uri, headers: headers);
      if (res.statusCode != 200) continue;
      final decoded = _safeDecode(res.body);
      final data = (decoded is Map) ? (decoded['data'] ?? decoded) : decoded;
      final map = Map<String, dynamic>.from(data as Map);
      map['file_pdf_url'] = _absoluteUrl(
        (map['file_pdf_url'] ??
                map['invoice_pdf_url'] ??
                map['order_file'] ??
                map['pdf_url'] ??
                map['document_url'] ??
                '')
            .toString(),
      );
      return OrderRow.fromJson(map);
    }
    throw Exception('GET /orders/$id not found');
  }

  // ---------- RETURNS ----------
  static Future<bool> createReturn({
    required int companyId,
    required int departmentId,
    required int employeeId,
    required int customerId,
    required int categoryId,
    required String phone,
    required AddressInput address,
    required int amount,
    required String reason,
    String? note,
    required List<Map<String, dynamic>> products,
    List<XFile>? photos,
  }) async {
    final url = _buildUri('product-returns');
    final headers = await _authorizedHeaders();

    final req = http.MultipartRequest('POST', url);
    req.headers.addAll(headers);

    req.fields['company_id'] = companyId.toString();
    req.fields['department_id'] = departmentId.toString();
    req.fields['employee_id'] = employeeId.toString();
    req.fields['customer_id'] = customerId.toString();
    req.fields['customer_categories_id'] = categoryId.toString();
    req.fields['phone'] = phone;
    req.fields['amount'] = amount.toString();
    req.fields['reason'] = reason;
    if (note != null && note.isNotEmpty) req.fields['note'] = note;

    req.fields['address[0][provinsi_code]'] = address.provinsiCode;
    req.fields['address[0][kota_kab_code]'] = address.kotaKabCode;
    req.fields['address[0][kecamatan_code]'] = address.kecamatanCode;
    req.fields['address[0][kelurahan_code]'] = address.kelurahanCode;
    if (address.kodePos != null && address.kodePos!.isNotEmpty) {
      req.fields['address[0][kode_pos]'] = address.kodePos!;
    }
    req.fields['address[0][detail_alamat]'] = address.detailAlamat;

    req.fields['products'] = jsonEncode(products);

    if (photos != null && photos.isNotEmpty) {
      for (final p in photos) {
        if (kIsWeb) {
          final bytes = await p.readAsBytes();
          req.files.add(http.MultipartFile.fromBytes('image[]', bytes,
              filename: p.name));
        } else {
          req.files.add(await http.MultipartFile.fromPath('image[]', p.path));
        }
      }
    }

    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);

    // ignore: avoid_print
    print('DEBUG createReturn => ${res.statusCode} ${res.body}');

    return res.statusCode == 200 || res.statusCode == 201;
  }

  static Future<List<OptionItem>> fetchColors() async => <OptionItem>[];

  static Future<List<ReturnRow>> fetchReturnRows(
      {int page = 1, int perPage = 20, String? q, String? status}) async {
    final headers = await _authorizedHeaders();
    final paths = ['product-returns', 'product_returns', 'returns'];
    for (final p in paths) {
      final params = <String, String>{
        'page': '$page',
        'per_page': '$perPage',
        if (q != null && q.isNotEmpty) 'filter[search]': q,
        if (status != null && status.isNotEmpty) 'filter[status]': status,
      };
      final uri = _buildUri(p, query: params);
      final res = await http.get(uri, headers: headers);
      if (res.statusCode != 200) continue;
      final items = _extractList(_safeDecode(res.body));
      if (items.isEmpty) continue;
      return items.map((raw) {
        final map = Map<String, dynamic>.from(raw);
        map['file_pdf_url'] = _absoluteUrl((map['file_pdf_url'] ??
                map['pdf_url'] ??
                map['document_url'] ??
                map['invoice_pdf_url'] ??
                '')
            .toString());
        map['image'] =
            _absoluteUrl((map['image'] ?? map['image_url'] ?? '').toString());
        return ReturnRow.fromJson(map);
      }).toList();
    }
    return <ReturnRow>[];
  }

  static Future<ReturnRow> fetchReturnRowDetail(int id) async {
    final headers = await _authorizedHeaders();
    final paths = ['product-returns/$id', 'product_returns/$id', 'returns/$id'];
    for (final p in paths) {
      final uri = _buildUri(p);
      final res = await http.get(uri, headers: headers);
      if (res.statusCode != 200) continue;
      final decoded = _safeDecode(res.body);
      final data = (decoded is Map) ? (decoded['data'] ?? decoded) : decoded;
      final map = Map<String, dynamic>.from(data as Map);
      map['file_pdf_url'] = _absoluteUrl((map['file_pdf_url'] ??
              map['pdf_url'] ??
              map['document_url'] ??
              map['invoice_pdf_url'] ??
              '')
          .toString());
      map['image'] =
          _absoluteUrl((map['image'] ?? map['image_url'] ?? '').toString());
      return ReturnRow.fromJson(map);
    }
    throw Exception('GET /product-returns/$id not found');
  }

  // ---------- WARRANTIES ----------
  /// POST garansi pakai JSON (bukan multipart) agar 'products' & 'address' terbaca sebagai array
  static Future<bool> createWarranty({
    required int companyId,
    required int departmentId,
    required int employeeId,
    required int customerId,
    required int categoryId,
    required String phone,
    required List<Map<String, dynamic>> address,
    required List<Map<String, dynamic>> products,
    required String purchaseDate, // YYYY-MM-DD
    required String claimDate, // YYYY-MM-DD
    String? reason,
    String? note,
    String status = 'pending',
    String? imagePath, // opsional; string path
  }) async {
    final url = _buildUri('garansis'); // sesuaikan jika rute berbeda
    final headers = await _authorizedHeaders(jsonContent: true);

    final payload = <String, dynamic>{
      'company_id': companyId,
      'department_id': departmentId,
      'employee_id': employeeId,
      'customer_id': customerId,
      'customer_categories_id': categoryId,
      'phone': phone,
      'address': address, // array
      'products': products, // array
      'purchase_date': purchaseDate,
      'claim_date': claimDate,
      'status': status,
      if (reason != null && reason.isNotEmpty) 'reason': reason,
      if (note != null && note.isNotEmpty) 'note': note,
      if (imagePath != null && imagePath.isNotEmpty) 'image': imagePath,
    };

    final res = await http.post(url, headers: headers, body: jsonEncode(payload));
    // ignore: avoid_print
    print('DEBUG createWarranty => ${res.statusCode} ${res.body}');
    return res.statusCode == 200 || res.statusCode == 201;
  }

  static Future<List<GaransiRow>> fetchWarrantyRows(
      {int page = 1, int perPage = 20, String? q, String? status}) async {
    final headers = await _authorizedHeaders();
    final paths = [
      'garansis',
      'warranties',
      'garansi',
      'warranty-claims',
      'warranty_claims'
    ];
    for (final p in paths) {
      final params = <String, String>{
        'page': '$page',
        'per_page': '$perPage',
        if (q != null && q.isNotEmpty) 'filter[search]': q,
        if (status != null && status.isNotEmpty) 'filter[status]': status,
      };
      final uri = _buildUri(p, query: params);
      final res = await http.get(uri, headers: headers);
      if (res.statusCode != 200) continue;
      final items = _extractList(_safeDecode(res.body));
      if (items.isEmpty) continue;
      return items.map((raw) {
        final map = Map<String, dynamic>.from(raw);
        map['file_pdf_url'] = _absoluteUrl((map['file_pdf_url'] ??
                map['pdf_url'] ??
                map['document_url'] ??
                map['invoice_pdf_url'] ??
                '')
            .toString());
        map['image'] = _absoluteUrl(
            (map['image'] ?? map['image_url'] ?? '').toString());
        return GaransiRow.fromJson(map);
      }).toList();
    }
    return <GaransiRow>[];
  }

  static Future<GaransiRow> fetchWarrantyRowDetail(int id) async {
    final headers = await _authorizedHeaders();
    final paths = [
      'garansis/$id',
      'warranties/$id',
      'garansi/$id',
      'warranty-claims/$id',
      'warranty_claims/$id'
    ];
    for (final p in paths) {
      final uri = _buildUri(p);
      final res = await http.get(uri, headers: headers);
      if (res.statusCode != 200) continue;
      final decoded = _safeDecode(res.body);
      final data = (decoded is Map) ? (decoded['data'] ?? decoded) : decoded;
      final map = Map<String, dynamic>.from(data as Map);
      map['file_pdf_url'] = _absoluteUrl((map['file_pdf_url'] ??
              map['pdf_url'] ??
              map['document_url'] ??
              map['invoice_pdf_url'] ??
              '')
          .toString());
      map['image'] =
          _absoluteUrl((map['image'] ?? map['image_url'] ?? '').toString());
      return GaransiRow.fromJson(map);
    }
    throw Exception('GET /garansis/$id not found');
  }

  // ---------- Utility ----------
  static String get _origin {
    final u = Uri.parse(baseUrl);
    final port = u.hasPort ? ':${u.port}' : '';
    return '${u.scheme}://${u.host}$port';
  }

  static String _absoluteUrl(String? maybe) {
    if (maybe == null || maybe.isEmpty) return '';
    if (maybe.startsWith('http://') || maybe.startsWith('https://')) {
      return maybe;
    }
    final path = maybe.startsWith('/') ? maybe : '/$maybe';
    return '$_origin$path';
  }
}
