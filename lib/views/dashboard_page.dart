import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/transaction.dart';
import '../models/transaction_category.dart';
import '../services/database_helper.dart';
import '../services/preference_service.dart';
import '../utils/formatters.dart';
import 'transaction_form_page.dart';
class DashboardPage extends StatefulWidget {
  final VoidCallback onDataChanged;
  const DashboardPage({super.key, required this.onDataChanged});
  @override
  State<DashboardPage> createState() => DashboardPageState();
}
class DashboardPageState extends State<DashboardPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final PreferenceService _prefService = PreferenceService();
  double _totalBalance = 0.0;
  double _totalIncome = 0.0;
  double _totalExpense = 0.0;
  double _currentMonthExpense = 0.0;
  List<TransactionModel> _recentTransactions = [];
  List<double> _weeklyExpenses = List.filled(7, 0.0); // Mon - Sun
  bool _isLoading = true;
  String? _errorMessage;
  // Preferences
  late String _currency;
  late bool _hideBalance;
  late double _budgetLimit;
  late bool _tipsSeen;
  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _loadDashboardData();
  }
  void _loadPreferences() {
    _currency = _prefService.currencySymbol;
    _hideBalance = _prefService.hideBalance;
    _budgetLimit = _prefService.monthlyBudgetLimit;
    _tipsSeen = _prefService.financialTipsSeen;
  }
  Future<void> reload() async {
    _loadPreferences();
    await _loadDashboardData(showLoading: false);
  }
  Future<void> _loadDashboardData({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }
    
    try {
      // Get all transactions
      final allTx = await _dbHelper.getAllTransactions();
      
      // Calculate total stats
      double income = 0.0;
      double expense = 0.0;
      for (var tx in allTx) {
        if (tx.type == 'income') {
          income += tx.amount;
        } else {
          expense += tx.amount;
        }
      }
      // Get current month expense
      final now = DateTime.now();
      final currentMonthTx = await _dbHelper.getTransactionsByMonth(now.year, now.month);
      double curMonthExpense = 0.0;
      for (var tx in currentMonthTx) {
        if (tx.type == 'expense') {
          curMonthExpense += tx.amount;
        }
      }
      // Recent 4 transactions
      final recent = allTx.take(4).toList();
      // Calculate weekly expenses (last 7 days, Mon to Sun of current week)
      final List<double> weeklyDays = List.filled(7, 0.0);
      // Let's get start of the current week (Monday)
      final int currentWeekday = now.weekday; // 1 = Monday, 7 = Sunday
      final DateTime startOfWeek = DateTime(now.year, now.month, now.day).subtract(Duration(days: currentWeekday - 1));
      
      for (var tx in allTx) {
        if (tx.type == 'expense') {
          final txDate = DateTime(tx.date.year, tx.date.month, tx.date.day);
          final difference = txDate.difference(startOfWeek).inDays;
          if (difference >= 0 && difference < 7) {
            weeklyDays[difference] += tx.amount;
          }
        }
      }
      if (mounted) {
        setState(() {
          _totalIncome = income;
          _totalExpense = expense;
          _totalBalance = income - expense;
          _currentMonthExpense = curMonthExpense;
          _recentTransactions = recent;
          _weeklyExpenses = weeklyDays;
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint("Error loading dashboard: $e\n$stackTrace");
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }
  Future<void> _toggleBalanceVisibility() async {
    final newValue = !_hideBalance;
    await _prefService.setHideBalance(newValue);
    setState(() {
      _hideBalance = newValue;
    });
    widget.onDataChanged();
  }
  Future<void> _dismissTips() async {
    await _prefService.setFinancialTipsSeen(true);
    setState(() {
      _tipsSeen = true;
    });
    widget.onDataChanged();
  }
  Future<void> _deleteTransaction(int id) async {
    await _dbHelper.deleteTransaction(id);
    await _loadDashboardData();
    widget.onDataChanged();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaksi berhasil dihapus')),
      );
    }
  }
  void _showAddTransactionSheet() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TransactionFormPage(
          onSave: reload,
        ),
      ),
    );
  }
  void _navigateToEditTransaction(TransactionModel tx) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TransactionFormPage(
          transaction: tx,
          onSave: reload,
        ),
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFF118EEA)),
        ),
      );
    }
    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 64),
                const SizedBox(height: 16),
                const Text(
                  'Gagal memuat data dashboard',
                  style: TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => _loadDashboardData(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF118EEA),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Coba Lagi'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final budgetPercentage = _budgetLimit > 0 ? _currentMonthExpense / _budgetLimit : 0.0;
    final isBudgetExceeded = _currentMonthExpense > _budgetLimit;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        color: const Color(0xFF118EEA),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              // Balance Card with Custom Gradient
              Container(
                padding: const EdgeInsets.all(24.0),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF118EEA), Color(0xFF0056A6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF118EEA).withOpacity(0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Saldo Anda',
                          style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                        IconButton(
                          icon: Icon(
                            _hideBalance ? Icons.visibility_off : Icons.visibility,
                            color: Colors.white,
                            size: 20,
                          ),
                          onPressed: _toggleBalanceVisibility,
                        )
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _hideBalance ? '••••••' : Formatters.formatCurrency(_totalBalance, _currency),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Income Stats
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.arrow_downward, color: Color(0xFF10B981), size: 18),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Pemasukan', style: TextStyle(color: Colors.white60, fontSize: 11)),
                                Text(
                                  _hideBalance ? '••••••' : Formatters.formatCurrency(_totalIncome, _currency),
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ],
                            ),
                          ],
                        ),
                        // Expense Stats
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.arrow_upward, color: Color(0xFFF43F5E), size: 18),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Pengeluaran', style: TextStyle(color: Colors.white60, fontSize: 11)),
                                Text(
                                  _hideBalance ? '••••••' : Formatters.formatCurrency(_totalExpense, _currency),
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Monthly Budget Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isBudgetExceeded ? Colors.red.withOpacity(0.3) : Colors.grey.shade200,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ]
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Batas Anggaran Bulanan',
                          style: TextStyle(color: Colors.grey[700], fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          Formatters.formatCurrency(_budgetLimit, _currency),
                          style: const TextStyle(color: Color(0xFF118EEA), fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: budgetPercentage > 1.0 ? 1.0 : budgetPercentage,
                        backgroundColor: Colors.grey.shade200,
                        color: isBudgetExceeded ? Colors.red : const Color(0xFF118EEA),
                        minHeight: 10,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Telah terpakai: ${Formatters.formatCurrency(_currentMonthExpense, _currency)}',
                          style: TextStyle(color: Colors.grey[600], fontSize: 11),
                        ),
                        Text(
                          '${(budgetPercentage * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                            color: isBudgetExceeded ? Colors.red : Colors.black87,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    if (isBudgetExceeded) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: const [
                          Icon(Icons.warning_amber_rounded, color: Colors.red, size: 16),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Peringatan: Pengeluaran bulan ini melebihi limit anggaran!',
                              style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.w500),
                            ),
                          )
                        ],
                      )
                    ]
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Weekly Graph Section
              const Text(
                'Pengeluaran Minggu Ini',
                style: TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Container(
                height: 200,
                padding: const EdgeInsets.only(top: 24, bottom: 8, right: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ]
                ),
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: _getMaxWeeklyExpense() * 1.2 == 0 ? 1000 : _getMaxWeeklyExpense() * 1.2,
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (_) => const Color(0xFF118EEA),
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          return BarTooltipItem(
                            Formatters.formatCurrency(rod.toY, _currency),
                            const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          );
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            const days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                days[value.toInt() % 7],
                                style: TextStyle(color: Colors.grey[600], fontSize: 10),
                              ),
                            );
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 45,
                          getTitlesWidget: (value, meta) {
                            if (value == 0) return const SizedBox();
                            String formatted = value >= 1000000
                                ? '${(value / 1000000).toStringAsFixed(1)}jt'
                                : value >= 1000
                                    ? '${(value / 1000).toStringAsFixed(0)}rb'
                                    : value.toStringAsFixed(0);
                            return Text(
                              formatted,
                              style: TextStyle(color: Colors.grey[600], fontSize: 9),
                            );
                          },
                        ),
                      ),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (value) {
                        return FlLine(color: Colors.grey.shade200, strokeWidth: 1);
                      },
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: List.generate(7, (index) {
                      return BarChartGroupData(
                        x: index,
                        barRods: [
                          BarChartRodData(
                            toY: _weeklyExpenses[index],
                            color: const Color(0xFF118EEA),
                            width: 14,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                          )
                        ],
                      );
                    }),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Dismissible Financial Tips Banner
              if (!_tipsSeen) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade50, Colors.white],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF118EEA).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.tips_and_updates, color: Color(0xFF118EEA), size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Tips Hari Ini: Cobalah untuk selalu menyisihkan minimal 20% dari gaji bulanan Anda langsung ke dalam Target Tabungan!',
                          style: TextStyle(color: Colors.black87, fontSize: 12),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey, size: 18),
                        onPressed: _dismissTips,
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
              // Recent Transactions List
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Transaksi Terakhir',
                    style: TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  TextButton(
                    onPressed: _showAddTransactionSheet,
                    child: const Text('Tambah Baru', style: TextStyle(color: Color(0xFF118EEA))),
                  )
                ],
              ),
              const SizedBox(height: 8),
              if (_recentTransactions.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      'Belum ada transaksi di bulan ini',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _recentTransactions.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final tx = _recentTransactions[index];
                    final isExpense = tx.type == 'expense';
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          )
                        ]
                      ),
                      child: ListTile(
                        onTap: () => _navigateToEditTransaction(tx),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Color(tx.categoryColorValue).withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            IconData(tx.categoryIconCode, fontFamily: 'MaterialIcons'),
                            color: Color(tx.categoryColorValue),
                          ),
                        ),
                        title: Text(
                          tx.title,
                          style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tx.categoryName,
                              style: TextStyle(color: Colors.grey[600], fontSize: 12),
                            ),
                            if (tx.notes != null)
                              Text(
                                tx.notes!,
                                style: TextStyle(color: Colors.grey[500], fontSize: 11, fontStyle: FontStyle.italic),
                              ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${isExpense ? "-" : "+"}${Formatters.formatCurrency(tx.amount, _currency)}',
                              style: TextStyle(
                                color: isExpense ? Colors.red : const Color(0xFF00C853),
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (dialogCtx) => AlertDialog(
                                    backgroundColor: Colors.white,
                                    title: const Text('Hapus Transaksi', style: TextStyle(color: Colors.black87)),
                                    content: Text(
                                      'Apakah Anda yakin ingin menghapus transaksi ini?',
                                      style: TextStyle(color: Colors.grey[700]),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(dialogCtx),
                                        child: Text('Batal', style: TextStyle(color: Colors.grey[700])),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pop(dialogCtx);
                                          _deleteTransaction(tx.id!);
                                        },
                                        child: const Text('Hapus', style: TextStyle(color: Colors.red)),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            )
                          ],
                        ),
                      ),
                    );
                  },
                ),
              const SizedBox(height: 80), // extra padding for bottom bar
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF118EEA),
        foregroundColor: Colors.white,
        onPressed: _showAddTransactionSheet,
        child: const Icon(Icons.add),
      ),
    );
  }
  double _getMaxWeeklyExpense() {
    double maxVal = 0.0;
    for (var val in _weeklyExpenses) {
      if (val > maxVal) maxVal = val;
    }
    return maxVal;
  }
}
