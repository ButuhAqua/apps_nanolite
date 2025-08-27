import 'dart:async';
import 'package:flutter/material.dart';

import 'categories_nano.dart';
import 'categories_piko.dart';
import 'create_sales_order.dart';
import 'customer.dart';
import 'garansi.dart';
import 'profile.dart';
import 'return.dart';
import 'sales_order.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _timer;

  final List<String> _bannerImages = [
    'assets/images/bannernanolite1.png',
    'assets/images/bannernanolite.jpg',
    'assets/images/bannerpikooo.jpg',
    'assets/images/bannerpikolite.jpg',
  ];

  @override
  void initState() {
    super.initState();
    _startAutoScroll();
  }

  void _startAutoScroll() {
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      final nextPage = (_currentPage + 1) % _bannerImages.length;
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;
    final double padding = isTablet ? 40.0 : 20.0;

    return Scaffold(
      backgroundColor: const Color(0xFF0A1B2D),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('nanopiko', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.grey[200],
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              AspectRatio(
                aspectRatio: 16 / 6,
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _bannerImages.length,
                  onPageChanged: (index) => setState(() => _currentPage = index),
                  itemBuilder: (context, index) {
                    return Image.asset(
                      _bannerImages[index],
                      fit: BoxFit.contain,
                      width: double.infinity,
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _bannerImages.length,
                  (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentPage == index ? 12 : 8,
                    height: _currentPage == index ? 12 : 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentPage == index
                          ? Colors.white
                          : Colors.white.withOpacity(0.3),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // BUTTON NANOLITE & PIKOLITE
              Padding(
                padding: EdgeInsets.all(padding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 20,
                      runSpacing: 20,
                      alignment: WrapAlignment.center,
                      children: [
                        _buildCircleIcon(
                          Icons.lightbulb,
                          'Nanolite',
                          () => Navigator.push(context, MaterialPageRoute(builder: (_) => CategoriesNanoScreen())),
                          isTablet,
                        ),
                        _buildCircleIcon(
                          Icons.lightbulb_outline,
                          'Pikolite',
                          () => Navigator.push(context, MaterialPageRoute(builder: (_) => CategoriesPikoScreen())),
                          isTablet,
                        ),
                      ],
                    ),

                    const SizedBox(height: 30),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Operational',
                        style: TextStyle(
                          fontSize: isTablet ? 28 : 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // GRID MENU
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: isTablet ? 1.8 : 1.6,
                      children: [
                        _buildBoxIcon(Icons.account_box, 'Customer', () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerScreen()));
                        }, isTablet),
                        _buildBoxIcon(Icons.shopping_cart, 'Sales Order', () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => SalesOrderScreen()));
                        }, isTablet),
                        _buildBoxIcon(Icons.history, 'Return', () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => ReturnScreen()));
                        }, isTablet),
                        _buildBoxIcon(Icons.workspace_premium, 'Garansi', () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => GaransiScreen()));
                        }, isTablet),
                      ],
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),

      // BOTTOM NAVIGATION FIXED
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
              _navItem(Icons.home, 'Home', onPressed: () {
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomeScreen()));
              }),
              _navItem(Icons.shopping_cart, 'Create Order', onPressed: () async {
                final created = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => CreateSalesOrderScreen()),
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
              _navItem(Icons.person, 'Profile', onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen()));
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCircleIcon(IconData icon, String label, VoidCallback onPressed, bool isTablet) {
    final double iconSize = isTablet ? 24 : 20;
    final double fontSize = isTablet ? 18 : 14;
    final double containerHeight = isTablet ? 60 : 50;
    final double containerPadding = isTablet ? 18 : 14;
    final double iconCircleSize = isTablet ? 36 : 32;

    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: containerPadding),
        height: containerHeight,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: iconCircleSize,
              height: iconCircleSize,
              decoration: const BoxDecoration(
                color: Color(0xFF0A1B2D),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: iconSize, color: Colors.white),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: const Color(0xFF0A1B2D),
                fontSize: fontSize,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBoxIcon(IconData icon, String label, VoidCallback onPressed, bool isTablet) {
    final double iconSize = isTablet ? 64 : 44;
    final double fontSize = isTablet ? 18 : 15;
    final double boxWidth = isTablet ? 180 : 160;
    final double boxHeight = isTablet ? 120 : 100;

    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: boxWidth,
        height: boxHeight,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 4,
              spreadRadius: 1,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: iconSize, color: const Color(0xFF0A1B2D)),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: const Color(0xFF0A1B2D), fontSize: fontSize)),
          ],
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, {VoidCallback? onPressed}) {
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
}
