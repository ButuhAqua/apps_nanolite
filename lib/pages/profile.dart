import 'package:flutter/material.dart';
import 'package:apps_nanolite/pages/home.dart';

import 'login.dart';
import 'create_sales_order.dart';
import 'sales_order.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key}); // <-- penting biar bisa dipanggil const

  @override
  Widget build(BuildContext context) {
    final bool isTablet = MediaQuery.of(context).size.width >= 600;

    return Scaffold(
      backgroundColor: const Color(0xFF0A1B2D),
      appBar: AppBar(
        title: const Text('nanopiko', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.grey[200],
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => HomeScreen()),
            );
          },
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                ClipPath(
                  clipper: const TopCurveClipper(), // <-- const
                  child: Container(
                    height: 180,
                    color: Colors.grey[300],
                  ),
                ),
                Transform.translate(
                  offset: const Offset(0, 60),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          spreadRadius: 3,
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: isTablet ? 80 : 60,
                      backgroundImage: const AssetImage('assets/images/avatar.jpg'),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 80),

            Text(
              'SALES',
              style: TextStyle(
                fontSize: isTablet ? 26 : 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Karina Indah Puspa',
              style: TextStyle(
                fontSize: isTablet ? 22 : 18,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(isTablet ? 20 : 15),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabelValue('Departemen', 'Sales', isTablet),
                    _buildLabelValue('Email', 'karina@gmail.com', isTablet),
                    _buildLabelValue('Phone', '0123456', isTablet),
                    _buildLabelValue('Status', 'Active', isTablet),
                    _buildLabelValue('Address', 'Jl. Raya Sudirman, RT 01 / RW 01, 1678', isTablet),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),

            ElevatedButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => LoginScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF061F3D),
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 120 : 100,
                  vertical: isTablet ? 18 : 15,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text('Logout', style: TextStyle(fontSize: isTablet ? 20 : 18)),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),

      bottomNavigationBar: Container(
        color: const Color(0xFF0A1B2D),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(40),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(context, Icons.home, 'Home', () {
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomeScreen()));
              }),
              _navItem(context, Icons.shopping_cart, 'Create Order', () async {
                final created = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => const CreateSalesOrderScreen()), // <-- const
                );
                if (created == true) {
                  if (!context.mounted) return;
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SalesOrderScreen(showCreatedSnack: true),
                    ),
                  );
                }
              }),
              _navItem(context, Icons.person, 'Profile', () {
                // stay
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(BuildContext context, IconData icon, String label, VoidCallback onPressed) {
    final bool isTablet = MediaQuery.of(context).size.shortestSide >= 600;
    final double iconSize = isTablet ? 32 : 28;
    final double fontSize = isTablet ? 14 : 12;

    return InkWell(
      onTap: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize, color: const Color(0xFF0A1B2D)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: const Color(0xFF0A1B2D), fontSize: fontSize)),
        ],
      ),
    );
  }

  Widget _buildLabelValue(String label, String value, bool isTablet) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF061F3D),
              fontSize: isTablet ? 16 : 14,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: isTablet ? 16 : 14,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

class TopCurveClipper extends CustomClipper<Path> {
  const TopCurveClipper(); // <-- bikin const

  @override
  Path getClip(Size size) {
    final Path path = Path();
    path.lineTo(0, size.height - 60);
    path.quadraticBezierTo(size.width / 2, size.height, size.width, size.height - 60);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
