import 'package:flutter/material.dart';
import '../models/transaction_category.dart';
import '../services/database_helper.dart';
class CategoryManagementPage extends StatefulWidget {
  final VoidCallback onCategoriesChanged;
  const CategoryManagementPage({super.key, required this.onCategoriesChanged});
  @override
  State<CategoryManagementPage> createState() => _CategoryManagementPageState();
}
class _CategoryManagementPageState extends State<CategoryManagementPage> with SingleTickerProviderStateMixin {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  late TabController _tabController;
  
  List<TransactionCategory> _categories = [];
  bool _isLoading = true;
  final List<IconData> _availableIcons = [
    Icons.restaurant,
    Icons.shopping_bag,
    Icons.directions_car,
    Icons.power,
    Icons.movie,
    Icons.medical_services,
    Icons.work,
    Icons.trending_up,
    Icons.card_giftcard,
    Icons.home,
    Icons.coffee,
    Icons.school,
    Icons.flight,
    Icons.fitness_center,
    Icons.payments,
    Icons.more_horiz,
  ];
  final List<Color> _availableColors = [
    Colors.blue,
    Colors.indigo,
    Colors.purple,
    Colors.pink,
    Colors.red,
    Colors.orange,
    Colors.amber,
    Colors.teal,
    Colors.green,
    Colors.brown,
    Colors.blueGrey,
  ];
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadCategories();
  }
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  Future<void> _loadCategories() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final cats = await _dbHelper.getCategories();
      if (mounted) {
        setState(() {
          _categories = cats;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading categories: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  void _showCategoryFormSheet([TransactionCategory? category]) {
    final isEdit = category != null;
    final nameController = TextEditingController(text: category?.name ?? '');
    String type = category?.type ?? (_tabController.index == 0 ? 'expense' : 'income');
    IconData selectedIcon = category != null 
        ? IconData(category.iconCode, fontFamily: 'MaterialIcons')
        : _availableIcons.first;
    Color selectedColor = category != null
        ? Color(category.colorValue)
        : _availableColors.first;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                top: 24,
                left: 24,
                right: 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isEdit ? 'Ubah Kategori' : 'Tambah Kategori Baru',
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: Colors.grey[600]),
                          onPressed: () => Navigator.pop(sheetContext),
                        )
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Type Toggle (Expense / Income)
                    Row(
                      children: [
                        // Expense Button
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setSheetState(() {
                                type = 'expense';
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: type == 'expense'
                                    ? Colors.red.withOpacity(0.1)
                                    : Colors.white,
                                border: Border.all(
                                  color: type == 'expense' ? Colors.red : Colors.grey.shade300,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  'Pengeluaran',
                                  style: TextStyle(
                                    color: type == 'expense' ? Colors.red : Colors.grey[700],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Income Button
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setSheetState(() {
                                type = 'income';
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: type == 'income'
                                    ? Colors.green.withOpacity(0.1)
                                    : Colors.white,
                                border: Border.all(
                                  color: type == 'income' ? Colors.green : Colors.grey.shade300,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  'Pemasukan',
                                  style: TextStyle(
                                    color: type == 'income' ? Colors.green : Colors.grey[700],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Name Input
                    TextField(
                      controller: nameController,
                      style: const TextStyle(color: Colors.black87),
                      decoration: InputDecoration(
                        labelText: 'Nama Kategori',
                        labelStyle: TextStyle(color: Colors.grey[600]),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Color(0xFF118EEA), width: 2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Icon Grid Selection
                    const Text(
                      'Pilih Ikon',
                      style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 110,
                      child: GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 8,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: _availableIcons.length,
                        itemBuilder: (context, idx) {
                          final icon = _availableIcons[idx];
                          final isSel = icon.codePoint == selectedIcon.codePoint;
                          return GestureDetector(
                            onTap: () {
                              setSheetState(() {
                                selectedIcon = icon;
                              });
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSel ? selectedColor.withOpacity(0.2) : Colors.grey.shade100,
                                border: Border.all(
                                  color: isSel ? selectedColor : Colors.transparent,
                                  width: 2,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                icon,
                                color: isSel ? selectedColor : Colors.grey[600],
                                size: 20,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Color Grid Selection
                    const Text(
                      'Pilih Warna',
                      style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 48,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _availableColors.length,
                        separatorBuilder: (context, index) => const SizedBox(width: 8),
                        itemBuilder: (context, idx) {
                          final color = _availableColors[idx];
                          final isSel = color.value == selectedColor.value;
                          return GestureDetector(
                            onTap: () {
                              setSheetState(() {
                                selectedColor = color;
                              });
                            },
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSel ? Colors.black87 : Colors.transparent,
                                  width: 3,
                                ),
                              ),
                              child: isSel
                                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                                  : null,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 28),
                    // Submit Button & Delete Button
                    Row(
                      children: [
                        if (isEdit) ...[
                          Expanded(
                            flex: 1,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () {
                                _deleteCategory(category);
                              },
                              child: const Icon(Icons.delete_outline),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          flex: 3,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF118EEA),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () async {
                              final name = nameController.text.trim();
                              if (name.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Nama kategori tidak boleh kosong')),
                                );
                                return;
                              }
                              final newCat = TransactionCategory(
                                id: category?.id,
                                name: name,
                                iconCode: selectedIcon.codePoint,
                                colorValue: selectedColor.value,
                                type: type,
                              );
                              if (isEdit) {
                                // For SQLite update category
                                final db = await _dbHelper.database;
                                await db.update(
                                  'categories',
                                  newCat.toMap(),
                                  where: 'id = ?',
                                  whereArgs: [category.id],
                                );
                              } else {
                                await _dbHelper.insertCategory(newCat);
                              }
                              Navigator.pop(sheetContext);
                              _loadCategories();
                              widget.onCategoriesChanged();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      isEdit
                                          ? 'Kategori berhasil diperbarui'
                                          : 'Kategori berhasil ditambahkan',
                                    ),
                                    backgroundColor: const Color(0xFF00C853),
                                  ),
                                );
                              }
                            },
                            child: Text(
                              isEdit ? 'Simpan Perubahan' : 'Simpan Kategori',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
  void _deleteCategory(TransactionCategory category) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Hapus Kategori', style: TextStyle(color: Colors.black87)),
        content: Text(
          'Apakah Anda yakin ingin menghapus kategori "${category.name}"?\n\n⚠️ Peringatan: Seluruh transaksi yang dikaitkan dengan kategori ini juga akan terhapus!',
          style: TextStyle(color: Colors.grey[700]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text('Batal', style: TextStyle(color: Colors.grey[700])),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogCtx); // close dialog
              Navigator.pop(context); // close bottom sheet
              await _dbHelper.deleteCategory(category.id!);
              _loadCategories();
              widget.onCategoriesChanged();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Kategori dan transaksi terkait telah dihapus'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    final expenses = _categories.where((c) => c.type == 'expense').toList();
    final incomes = _categories.where((c) => c.type == 'income').toList();
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Kelola Kategori'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Pengeluaran'),
            Tab(text: 'Pemasukan'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF118EEA)))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildCategoryList(expenses),
                _buildCategoryList(incomes),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF118EEA),
        foregroundColor: Colors.white,
        onPressed: () => _showCategoryFormSheet(),
        child: const Icon(Icons.add),
      ),
    );
  }
  Widget _buildCategoryList(List<TransactionCategory> cats) {
    if (cats.isEmpty) {
      return Center(
        child: Text(
          'Belum ada kategori terdaftar',
          style: TextStyle(color: Colors.grey[500], fontSize: 14),
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(18.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 0.95,
      ),
      itemCount: cats.length,
      itemBuilder: (context, idx) {
        final cat = cats[idx];
        return Card(
          margin: EdgeInsets.zero,
          color: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: InkWell(
            onTap: () => _showCategoryFormSheet(cat),
            borderRadius: BorderRadius.circular(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Color(cat.colorValue).withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    IconData(cat.iconCode, fontFamily: 'MaterialIcons'),
                    color: Color(cat.colorValue),
                    size: 26,
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Text(
                    cat.name,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
