import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../models/transaction_category.dart';
import '../services/database_helper.dart';
import '../services/preference_service.dart';
import '../utils/formatters.dart';
class TransactionFormPage extends StatefulWidget {
  final TransactionModel? transaction;
  final VoidCallback onSave;
  const TransactionFormPage({super.key, this.transaction, required this.onSave});
  @override
  State<TransactionFormPage> createState() => _TransactionFormPageState();
}
class _TransactionFormPageState extends State<TransactionFormPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final PreferenceService _prefService = PreferenceService();
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _amountController;
  late TextEditingController _notesController;
  late String _type; // 'expense' or 'income'
  late DateTime _selectedDate;
  
  List<TransactionCategory> _categories = [];
  TransactionCategory? _selectedCategory;
  bool _isLoadingCategories = true;
  late String _currency;
  @override
  void initState() {
    super.initState();
    final tx = widget.transaction;
    
    _titleController = TextEditingController(text: tx?.title ?? '');
    _amountController = TextEditingController(
      text: tx != null ? tx.amount.toStringAsFixed(0) : '',
    );
    _notesController = TextEditingController(text: tx?.notes ?? '');
    _type = tx?.type ?? 'expense';
    _selectedDate = tx?.date ?? DateTime.now();
    _currency = _prefService.currencySymbol;
    
    _loadCategories();
  }
  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }
  Future<void> _loadCategories() async {
    setState(() {
      _isLoadingCategories = true;
    });
    
    try {
      final allCats = await _dbHelper.getCategories();
      
      if (mounted) {
        setState(() {
          _categories = allCats;
          _isLoadingCategories = false;
          
          // Auto select category
          final filtered = _categories.where((c) => c.type == _type).toList();
          final tx = widget.transaction;
          
          if (tx != null && tx.type == _type) {
            _selectedCategory = _categories.firstWhere(
              (c) => c.id == tx.categoryId,
              orElse: () => filtered.isNotEmpty ? filtered.first : _categories.first,
            );
          } else {
            _selectedCategory = filtered.isNotEmpty ? filtered.first : null;
          }
        });
      }
    } catch (e) {
      debugPrint("Error loading categories: $e");
      if (mounted) {
        setState(() {
          _isLoadingCategories = false;
        });
      }
    }
  }
  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 3650)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF118EEA),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }
  Future<void> _deleteTransaction() async {
    final tx = widget.transaction;
    if (tx == null || tx.id == null) return;
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Hapus Transaksi', style: TextStyle(color: Colors.black87)),
        content: Text(
          'Apakah Anda yakin ingin menghapus transaksi "${tx.title}"?',
          style: TextStyle(color: Colors.grey[700]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text('Batal', style: TextStyle(color: Colors.grey[700])),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogCtx); // Close dialog
              await _dbHelper.deleteTransaction(tx.id!);
              widget.onSave(); // Trigger dashboard reload
              if (mounted) {
                Navigator.pop(context); // Close form page
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Transaksi berhasil dihapus'),
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
  Future<void> _saveForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harap pilih kategori transaksi')),
      );
      return;
    }
    final amt = double.parse(_amountController.text);
    final title = _titleController.text.trim();
    final notes = _notesController.text.trim();
    final updatedTx = TransactionModel(
      id: widget.transaction?.id,
      title: title,
      amount: amt,
      type: _type,
      categoryId: _selectedCategory!.id!,
      categoryName: _selectedCategory!.name,
      categoryIconCode: _selectedCategory!.iconCode,
      categoryColorValue: _selectedCategory!.colorValue,
      date: _selectedDate,
      notes: notes.isEmpty ? null : notes,
    );
    if (widget.transaction == null) {
      await _dbHelper.insertTransaction(updatedTx);
    } else {
      await _dbHelper.updateTransaction(updatedTx);
    }
    widget.onSave();
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.transaction == null
                ? 'Transaksi berhasil ditambahkan'
                : 'Transaksi berhasil diperbarui',
          ),
          backgroundColor: const Color(0xFF00C853),
        ),
      );
    }
  }
  @override
  Widget build(BuildContext context) {
    final isEdit = widget.transaction != null;
    final filteredCategories = _categories.where((c) => c.type == _type).toList();
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(isEdit ? 'Ubah Transaksi' : 'Tambah Transaksi Baru'),
        actions: [
          if (isEdit)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.white),
              tooltip: 'Hapus Transaksi',
              onPressed: _deleteTransaction,
            ),
        ],
      ),
      body: _isLoadingCategories
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF118EEA)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Type Selector (Income/Expense)
                    Row(
                      children: [
                        // Expense Button
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _type = 'expense';
                                final filtered = _categories.where((c) => c.type == 'expense').toList();
                                _selectedCategory = filtered.isNotEmpty ? filtered.first : null;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: _type == 'expense'
                                    ? Colors.red.withOpacity(0.1)
                                    : Colors.white,
                                border: Border.all(
                                  color: _type == 'expense' ? Colors.red : Colors.grey.shade300,
                                  width: _type == 'expense' ? 2 : 1,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.01),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  )
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  'Pengeluaran',
                                  style: TextStyle(
                                    color: _type == 'expense' ? Colors.red : Colors.grey[700],
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Income Button
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _type = 'income';
                                final filtered = _categories.where((c) => c.type == 'income').toList();
                                _selectedCategory = filtered.isNotEmpty ? filtered.first : null;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: _type == 'income'
                                    ? Colors.green.withOpacity(0.1)
                                    : Colors.white,
                                border: Border.all(
                                  color: _type == 'income' ? Colors.green : Colors.grey.shade300,
                                  width: _type == 'income' ? 2 : 1,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.01),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  )
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  'Pemasukan',
                                  style: TextStyle(
                                    color: _type == 'income' ? Colors.green : Colors.grey[700],
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Amount Field
                    TextFormField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        labelText: 'Nominal Transaksi',
                        labelStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
                        prefixText: '$_currency ',
                        prefixStyle: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Color(0xFF118EEA), width: 2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.red),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.red, width: 2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) {
                          return 'Jumlah nominal tidak boleh kosong';
                        }
                        final amt = double.tryParse(val);
                        if (amt == null || amt <= 0) {
                          return 'Masukkan jumlah nominal yang valid';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    // Title Field
                    TextFormField(
                      controller: _titleController,
                      style: const TextStyle(color: Colors.black87),
                      decoration: InputDecoration(
                        labelText: 'Deskripsi / Judul (misal: Makan Siang)',
                        labelStyle: TextStyle(color: Colors.grey[600]),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Color(0xFF118EEA), width: 2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.red),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.red, width: 2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Judul transaksi tidak boleh kosong';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    // Category Selector
                    DropdownButtonFormField<TransactionCategory>(
                      value: _selectedCategory,
                      dropdownColor: Colors.white,
                      style: const TextStyle(color: Colors.black87),
                      decoration: InputDecoration(
                        labelText: 'Kategori',
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
                      items: filteredCategories.map((cat) {
                        return DropdownMenuItem<TransactionCategory>(
                          value: cat,
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Color(cat.colorValue).withOpacity(0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  IconData(cat.iconCode, fontFamily: 'MaterialIcons'),
                                  color: Color(cat.colorValue),
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(cat.name, style: const TextStyle(fontSize: 15)),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (cat) {
                        setState(() {
                          _selectedCategory = cat;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    // Date Picker Card
                    InkWell(
                      onTap: _selectDate,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Tanggal Transaksi',
                                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  Formatters.formatDate(_selectedDate),
                                  style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                              ],
                            ),
                            Icon(Icons.calendar_today, color: Colors.grey[600], size: 20),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Notes Field
                    TextFormField(
                      controller: _notesController,
                      maxLines: 2,
                      style: const TextStyle(color: Colors.black87),
                      decoration: InputDecoration(
                        labelText: 'Catatan Tambahan (Opsional)',
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
                    const SizedBox(height: 36),
                    // Save Button
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF118EEA),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      onPressed: _saveForm,
                      child: Text(
                        isEdit ? 'Perbarui Transaksi' : 'Simpan Transaksi',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
