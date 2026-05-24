import 'package:flutter/material.dart';
import '../services/preference_service.dart';
import '../utils/formatters.dart';
import 'category_management_page.dart';
class SettingsPage extends StatefulWidget {
  final VoidCallback onSettingsChanged;
  const SettingsPage({super.key, required this.onSettingsChanged});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}
class _SettingsPageState extends State<SettingsPage> {
  final PreferenceService _prefService = PreferenceService();
  late String _currency;
  late bool _hideBalance;
  late double _budgetLimit;
  late bool _isPinSet;
  late String _savedPin;
  late bool _syncToCloud;
  late bool _tipsSeen;
  late String _defaultView;
  final List<String> _currencies = ['Rp', '\$', '€', '¥', '£'];
  final List<String> _accountViews = ['Dompet Utama', 'Kartu Kredit'];
  @override
  void initState() {
    super.initState();
    _loadSettings();
  }
  void _loadSettings() {
    setState(() {
      _currency = _prefService.currencySymbol;
      _hideBalance = _prefService.hideBalance;
      _budgetLimit = _prefService.monthlyBudgetLimit;
      _isPinSet = _prefService.isPinSet;
      _savedPin = _prefService.savedPin;
      _syncToCloud = _prefService.syncToCloud;
      _tipsSeen = _prefService.financialTipsSeen;
      _defaultView = _prefService.defaultAccountView;
    });
  }
  Future<void> _updateCurrency(String symbol) async {
    await _prefService.setCurrencySymbol(symbol);
    _loadSettings();
    widget.onSettingsChanged();
  }
  Future<void> _updateHideBalance(bool value) async {
    await _prefService.setHideBalance(value);
    _loadSettings();
    widget.onSettingsChanged();
  }
  Future<void> _updateBudgetLimit(double limit) async {
    await _prefService.setMonthlyBudgetLimit(limit);
    _loadSettings();
    widget.onSettingsChanged();
  }
  Future<void> _updateSyncToCloud(bool value) async {
    await _prefService.setSyncToCloud(value);
    _loadSettings();
    widget.onSettingsChanged();
  }
  Future<void> _updateTipsSeen(bool value) async {
    await _prefService.setFinancialTipsSeen(value);
    _loadSettings();
    widget.onSettingsChanged();
  }
  Future<void> _updateDefaultView(String view) async {
    await _prefService.setDefaultAccountView(view);
    _loadSettings();
    widget.onSettingsChanged();
  }
  Future<void> _handlePinToggle(bool value) async {
    if (value) {
      // Prompt for pin code
      final pinController = TextEditingController();
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogCtx) => AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('Atur PIN Baru', style: TextStyle(color: Colors.black87)),
          content: TextField(
            controller: pinController,
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 4,
            style: const TextStyle(color: Colors.black87, fontSize: 24, letterSpacing: 8),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: 'xxxx',
              hintStyle: TextStyle(color: Colors.grey[300]),
              counterStyle: TextStyle(color: Colors.grey[600]),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogCtx);
                _loadSettings();
              },
              child: Text('Batal', style: TextStyle(color: Colors.grey[700])),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF118EEA)),
              onPressed: () async {
                final pin = pinController.text.trim();
                if (pin.length == 4) {
                  await _prefService.setIsPinSet(true);
                  await _prefService.setSavedPin(pin); // For demo, storing as plain string. Usually encrypt it
                  Navigator.pop(dialogCtx);
                  _loadSettings();
                  widget.onSettingsChanged();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('PIN berhasil diaktifkan')),
                    );
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('PIN harus 4 angka')),
                  );
                }
              },
              child: const Text('Simpan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    } else {
      // Disable PIN
      await _prefService.setIsPinSet(false);
      await _prefService.setSavedPin('');
      _loadSettings();
      widget.onSettingsChanged();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PIN dinonaktifkan')),
        );
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const SizedBox(height: 12),
          _buildSectionHeader('Preferensi Finansial (Assesment Key)'),
          
          // Currency Symbol Preference
          _buildSettingTile(
            title: 'Simbol Mata Uang',
            subtitle: 'Mata uang default aplikasi: $_currency',
            trailing: DropdownButton<String>(
              value: _currency,
              dropdownColor: Colors.white,
              style: const TextStyle(color: Colors.black87),
              underline: const SizedBox(),
              items: _currencies.map((symbol) {
                return DropdownMenuItem<String>(
                  value: symbol,
                  child: Text(symbol, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) _updateCurrency(val);
              },
            ),
          ),
          
          // Hide Balance Preference
          _buildSettingTile(
            title: 'Sembunyikan Saldo',
            subtitle: 'Sembunyikan saldo di dashboard secara default',
            trailing: Switch(
              value: _hideBalance,
              activeColor: const Color(0xFF118EEA),
              onChanged: _updateHideBalance,
            ),
          ),
          // Monthly Budget Limit Preference
          _buildSettingTile(
            title: 'Batas Anggaran Bulanan',
            subtitle: 'Limit: ${Formatters.formatCurrency(_budgetLimit, _currency)}',
            trailing: IconButton(
              icon: const Icon(Icons.edit, color: Color(0xFF118EEA)),
              onPressed: () {
                final limitController = TextEditingController(text: _budgetLimit.toStringAsFixed(0));
                showDialog(
                  context: context,
                  builder: (dialogCtx) => AlertDialog(
                    backgroundColor: Colors.white,
                    title: const Text('Batas Anggaran Bulanan', style: TextStyle(color: Colors.black87)),
                    content: TextField(
                      controller: limitController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.black87),
                      decoration: InputDecoration(
                        prefixText: '$_currency ',
                        prefixStyle: const TextStyle(color: Colors.black87),
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogCtx),
                        child: Text('Batal', style: TextStyle(color: Colors.grey[700])),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF118EEA)),
                        onPressed: () {
                          final limit = double.tryParse(limitController.text);
                          if (limit != null && limit >= 0) {
                            _updateBudgetLimit(limit);
                            Navigator.pop(dialogCtx);
                          }
                        },
                        child: const Text('Simpan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          // Kelola Kategori Setting Tile
          _buildSettingTile(
            title: 'Kelola Kategori',
            subtitle: 'Tambah, ubah, atau hapus kategori transaksi',
            trailing: IconButton(
              icon: const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFF118EEA)),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CategoryManagementPage(
                      onCategoriesChanged: widget.onSettingsChanged,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          _buildSectionHeader('Keamanan & Aplikasi'),
          // Is PIN Set & Saved PIN Preference
          _buildSettingTile(
            title: 'Kunci Aplikasi PIN',
            subtitle: _isPinSet ? 'PIN aktif (PIN: $_savedPin)' : 'PIN tidak aktif',
            trailing: Switch(
              value: _isPinSet,
              activeColor: const Color(0xFF118EEA),
              onChanged: _handlePinToggle,
            ),
          ),
          // Sync to Cloud Preference
          _buildSettingTile(
            title: 'Sinkronisasi Cloud',
            subtitle: 'Simpan & cadangkan data ke cloud otomatis',
            trailing: Switch(
              value: _syncToCloud,
              activeColor: const Color(0xFF118EEA),
              onChanged: _updateSyncToCloud,
            ),
          ),
          // Default Account View Preference
          _buildSettingTile(
            title: 'Tampilan Default Akun',
            subtitle: 'Dibuka di: $_defaultView',
            trailing: DropdownButton<String>(
              value: _defaultView,
              dropdownColor: Colors.white,
              style: const TextStyle(color: Colors.black87),
              underline: const SizedBox(),
              items: _accountViews.map((view) {
                return DropdownMenuItem<String>(
                  value: view,
                  child: Text(view, style: const TextStyle(color: Colors.black87)),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) _updateDefaultView(val);
              },
            ),
          ),
          // Financial Tips Seen Preference (Reset button)
          _buildSettingTile(
            title: 'Pop-up Tips Finansial',
            subtitle: _tipsSeen ? 'Disembunyikan (Sudah dilihat)' : 'Tampil di dashboard',
            trailing: TextButton(
              onPressed: () => _updateTipsSeen(!_tipsSeen),
              child: Text(
                _tipsSeen ? 'Tampilkan' : 'Sembunyikan',
                style: const TextStyle(color: Color(0xFF118EEA), fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Center(
            child: Text(
              'Aplikasi Finansial v1.0.0\nProject Akhtar & Partner',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[400], fontSize: 11),
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, bottom: 12.0),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
  Widget _buildSettingTile({
    required String title,
    required String subtitle,
    required Widget trailing,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
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
        contentPadding: EdgeInsets.zero,
        title: Text(
          title,
          style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: Colors.grey[600], fontSize: 11),
        ),
        trailing: trailing,
      ),
    );
  }
}
