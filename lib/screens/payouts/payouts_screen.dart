import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:intl/intl.dart';

import '../../theme/app_colors.dart';
import '../../models/user_model.dart';
import '../../models/claim_model.dart';
import '../../services/api_service.dart';
import '../../services/tab_router.dart';

class PayoutsScreen extends StatefulWidget {
  const PayoutsScreen({super.key});

  @override
  State<PayoutsScreen> createState() => _PayoutsScreenState();
}

class _PayoutsScreenState extends State<PayoutsScreen> {
  final ApiService _apiService = ApiService();
  final NumberFormat _currencyFormat = NumberFormat('#,##0');
  final DateFormat _dateFormat = DateFormat('d MMM yyyy');
  final DateFormat _monthFormat = DateFormat('MMMM yyyy');

  List<_PayoutEntry> _payouts = const <_PayoutEntry>[];
  User? _user;
  Map<String, dynamic>? _policy;
  bool _isLoading = true;
  DateTime _lastUpdated = DateTime.now();

  String _primaryUpi = '';
  String? _backupUpi;
  bool _primaryVerified = true;
  bool _backupVerified = false;

  @override
  void initState() {
    super.initState();
    _loadPayoutData();
  }

  Future<void> _loadPayoutData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = await _apiService.getProfile('me');
      final policy = await _apiService.getPolicy('me');
      final claims = await _apiService.getClaims('me');

      final settled = claims.where((c) => c.status == ClaimStatus.settled).toList()
        ..sort((a, b) => b.date.compareTo(a.date));

      final payouts = settled
          .map(
            (c) => _PayoutEntry(
              date: c.date,
              triggerType: c.typeShortName,
              amount: c.amount.round(),
              upiRef: c.id.replaceAll('#', ''),
            ),
          )
          .toList();

      if (!mounted) return;
      setState(() {
        _user = user;
        _policy = policy;
        _payouts = payouts;
        _primaryUpi = '${user.phone}@saatdin';
        _backupUpi = null;
        _lastUpdated = DateTime.now();
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load payouts from backend.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshPayouts() async {
    await _loadPayoutData();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.scaffoldBackground,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final user = _user;
    if (user == null) {
      return const Scaffold(
        backgroundColor: AppColors.scaffoldBackground,
        body: Center(
          child: Text(
            'Payout data unavailable. Please retry.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    final currentMonthData = _monthlyData(DateTime.now());
    final previousMonth = DateTime(DateTime.now().year, DateTime.now().month - 1);
    final previousMonthData = _monthlyData(previousMonth);

    final totalPremiumsPaid = ((_policy?['weeklyPremium'] as num? ?? 0) * 4).round();
    final totalPayoutsReceived = _payouts.fold<int>(0, (sum, item) => sum + item.amount);

    final estimatedWeeklyEarnings = (user.totalEarnings / 4).round();
    final averageWeeklyPayout = _payouts.isEmpty
        ? 0
        : (totalPayoutsReceived / 4).round();

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: Stack(
        children: [
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SizedBox(
              height: 208,
              child: CustomPaint(
                painter: _PayoutsTopBackgroundPainter(),
              ),
            ),
          ),
          SafeArea(
            child: RefreshIndicator(
              onRefresh: _refreshPayouts,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                children: [
                  _buildTopBar(user),
                  const SizedBox(height: 12),
                  _buildHeroSummaryCard(
                    totalPremiumsPaid: totalPremiumsPaid,
                    totalPayoutsReceived: totalPayoutsReceived,
                  ),
                  const SizedBox(height: 12),
                  _buildKpiStrip(
                    currentMonthData: currentMonthData,
                  ),
                  const SizedBox(height: 20),
                  _buildSectionIntro(
                    title: 'Performance',
                    subtitle: 'Monthly trend and protection value for this week',
                  ),
                  const SizedBox(height: 10),
                  _buildPerformanceCard(
                    currentMonthData: currentMonthData,
                    previousMonthData: previousMonthData,
                    estimatedWeeklyEarnings: estimatedWeeklyEarnings,
                    averageWeeklyPayout: averageWeeklyPayout,
                  ),
                  const SizedBox(height: 20),
                  _buildSectionIntro(
                    title: 'Payout Accounts',
                    subtitle: 'Manage and verify where settlements are sent',
                  ),
                  const SizedBox(height: 10),
                  _buildUpiManagementCard(context),
                  const SizedBox(height: 20),
                  _buildSectionIntro(
                    title: 'Statements',
                    subtitle: 'Download payout statements for accounting and tax',
                  ),
                  const SizedBox(height: 10),
                  _buildStatementCard(context),
                  const SizedBox(height: 20),
                  _buildSectionIntro(
                    title: 'Recent Transfers',
                    subtitle: 'Pull down to refresh latest transfer events',
                  ),
                  const SizedBox(height: 4),
                  const SizedBox(height: 8),
                  ..._payouts
                      .map((entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _buildPayoutTile(entry),
                          )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSummaryCard({
    required int totalPremiumsPaid,
    required int totalPayoutsReceived,
  }) {
    final netValue = totalPayoutsReceived - totalPremiumsPaid;
    final isPositive = netValue >= 0;
    final momentumQuote = _payoutMomentumQuote(
      totalPayoutsReceived: totalPayoutsReceived,
      payoutCount: _payouts.length,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            AppColors.primaryDark,
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.22),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Payouts',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Last updated ${DateFormat('h:mm a').format(_lastUpdated)}',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.86),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _heroMetric(
                  label: 'Total received',
                  value: 'Rs ${_currencyFormat.format(totalPayoutsReceived)}',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _heroMetric(
                  label: isPositive ? 'Net value' : 'Momentum note',
                  value: isPositive
                      ? '+Rs ${_currencyFormat.format(netValue.abs())}'
                      : momentumQuote,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroMetric({required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiStrip({
    required _MonthlySummary currentMonthData,
  }) {
    final thisMonth = currentMonthData.totalReceived;
    final avgPayout = currentMonthData.average;

    return Row(
      children: [
        Expanded(
          child: _kpiChip(
            label: 'This month',
            value: 'Rs ${_currencyFormat.format(thisMonth)}',
            icon: Icons.calendar_month_outlined,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _kpiChip(
            label: 'Avg payout',
            value: 'Rs ${_currencyFormat.format(avgPayout)}',
            icon: Icons.show_chart,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _kpiChip(
            label: 'Transfers',
            value: '${_payouts.length}',
            icon: Icons.swap_horiz,
          ),
        ),
      ],
    );
  }

  Widget _kpiChip({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(height: 8),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionIntro({
    required String title,
    required String subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildPerformanceCard({
    required _MonthlySummary currentMonthData,
    required _MonthlySummary previousMonthData,
    required int estimatedWeeklyEarnings,
    required int averageWeeklyPayout,
  }) {
    return Column(
      children: [
        _buildMonthlySummaryCard(
          currentMonthData: currentMonthData,
          previousMonthData: previousMonthData,
        ),
        const SizedBox(height: 10),
        _buildValueRatioCard(
          estimatedWeeklyEarnings: estimatedWeeklyEarnings,
          averageWeeklyPayout: averageWeeklyPayout,
        ),
      ],
    );
  }

  Widget _buildTopBar(User user) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _headerIconButton(
          icon: Icons.arrow_back,
          tooltip: 'Back to Home',
          onTap: () => _switchToTab(0),
        ),
        Row(
          children: [
            _headerIconButton(
              icon: Icons.notifications_none,
              tooltip: 'Notifications',
              onTap: () => _showSimpleInfo('No new payout alerts'),
            ),
            const SizedBox(width: 10),
            _headerIconButton(
              icon: Icons.account_circle_outlined,
              tooltip: 'Account',
              onTap: () => _showAccountSheet(user),
            ),
          ],
        ),
      ],
    );
  }

  Widget _headerIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
          ),
          child: Icon(icon, size: 21, color: AppColors.textPrimary),
        ),
      ),
    );
  }

  Widget _buildMonthlySummaryCard({
    required _MonthlySummary currentMonthData,
    required _MonthlySummary previousMonthData,
  }) {
    final thisMonthAmount = currentMonthData.totalReceived;
    final lastMonthAmount = previousMonthData.totalReceived;
    final maxValue = (thisMonthAmount > lastMonthAmount
            ? thisMonthAmount
            : lastMonthAmount)
        .clamp(1, 999999);

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _metricItem(
                  label: 'Total Received',
                  value: 'Rs ${_currencyFormat.format(thisMonthAmount)}',
                ),
              ),
              Expanded(
                child: _metricItem(
                  label: 'Payout Count',
                  value: '${currentMonthData.count}',
                ),
              ),
              Expanded(
                child: _metricItem(
                  label: 'Avg / Claim',
                  value: 'Rs ${_currencyFormat.format(currentMonthData.average)}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _miniBar(
                  label: 'This month',
                  amount: thisMonthAmount,
                  heightFactor: thisMonthAmount / maxValue,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _miniBar(
                  label: 'Last month',
                  amount: lastMonthAmount,
                  heightFactor: lastMonthAmount / maxValue,
                  color: AppColors.info,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildValueRatioCard({
    required int estimatedWeeklyEarnings,
    required int averageWeeklyPayout,
  }) {
    final maxValue =
        (estimatedWeeklyEarnings > averageWeeklyPayout
                ? estimatedWeeklyEarnings
                : averageWeeklyPayout)
            .clamp(1, 999999);

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your protection value ratio for this week',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: _ratioBar(
                  label: 'Est. earnings',
                  amount: estimatedWeeklyEarnings,
                  factor: estimatedWeeklyEarnings / maxValue,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ratioBar(
                  label: 'Payouts received',
                  amount: averageWeeklyPayout,
                  factor: averageWeeklyPayout / maxValue,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUpiManagementCard(BuildContext context) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _upiRow(
            label: 'Primary UPI',
            upiId: _primaryUpi,
            verified: _primaryVerified,
            onChange: () => _editUpi(
              context,
              title: 'Change primary UPI',
              currentValue: _primaryUpi,
              onSaved: (value) {
                setState(() {
                  _primaryUpi = value;
                  _primaryVerified = false;
                });
              },
            ),
            onVerify: _primaryVerified ? null : () => _verifyPrimary(),
          ),
          const Divider(height: 22, color: AppColors.border),
          _upiRow(
            label: 'Backup UPI',
            upiId: _backupUpi ?? 'Not added',
            verified: _backupVerified,
            onChange: () => _editUpi(
              context,
              title: _backupUpi == null ? 'Add backup UPI' : 'Change backup UPI',
              currentValue: _backupUpi,
              onSaved: (value) {
                setState(() {
                  _backupUpi = value;
                  _backupVerified = false;
                });
              },
            ),
            onVerify: _backupUpi == null ? null : () => _verifyBackup(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatementCard(BuildContext context) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Generate statement as PDF for ${_monthFormat.format(DateTime.now())} or custom date range.',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    _showSimpleInfo('Monthly PDF statement generated');
                  },
                  icon: const Icon(Icons.download_outlined, size: 18),
                  label: const Text('This month'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    _pickCustomRange(context);
                  },
                  icon: const Icon(Icons.date_range_outlined, size: 18),
                  label: const Text('Custom range'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPayoutTile(_PayoutEntry entry) {
    return _card(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.successLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.account_balance_wallet_outlined,
                color: AppColors.success),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.triggerType,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _dateFormat.format(entry.date),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'UPI Ref: ${entry.upiRef}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            'Rs ${_currencyFormat.format(entry.amount)}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.success,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricItem({required String label, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _miniBar({
    required String label,
    required int amount,
    required double heightFactor,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 50,
            child: Align(
              alignment: Alignment.bottomLeft,
              child: FractionallySizedBox(
                widthFactor: 1,
                heightFactor: heightFactor.clamp(0.08, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
          Text(
            'Rs ${_currencyFormat.format(amount)}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _ratioBar({
    required String label,
    required int amount,
    required double factor,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 84,
            child: Align(
              alignment: Alignment.bottomLeft,
              child: FractionallySizedBox(
                widthFactor: 1,
                heightFactor: factor.clamp(0.08, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          Text(
            'Rs ${_currencyFormat.format(amount)}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _upiRow({
    required String label,
    required String upiId,
    required bool verified,
    required VoidCallback onChange,
    VoidCallback? onVerify,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Text(
                upiId,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: verified ? AppColors.successLight : AppColors.warningLight,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                verified ? 'Verified' : 'Unverified',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: verified ? AppColors.success : AppColors.warning,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            OutlinedButton(
              onPressed: onChange,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.border),
              ),
              child: Text(_isUpiAdded(upiId) ? 'Change' : 'Add'),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: onVerify,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.border),
              ),
              child: Text(verified ? 'Verified' : 'Verify'),
            ),
          ],
        ),
      ],
    );
  }

  bool _isUpiAdded(String value) {
    return value.toLowerCase() != 'not added';
  }

  String _payoutMomentumQuote({
    required int totalPayoutsReceived,
    required int payoutCount,
  }) {
    if (payoutCount >= 3) {
      return 'You have rocked this week. Your protection showed up when it mattered.';
    }
    if (totalPayoutsReceived > 0) {
      return 'You are protected and covered. Keep riding confidently.';
    }
    return 'Great week so far. Your safety net is active for every shift.';
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }

  _MonthlySummary _monthlyData(DateTime month) {
    final sameMonthEntries = _payouts.where(
      (entry) =>
          entry.date.year == month.year &&
          entry.date.month == month.month,
    );

    final count = sameMonthEntries.length;
    final total = sameMonthEntries.fold<int>(0, (sum, item) => sum + item.amount);
    final avg = count == 0 ? 0 : (total / count).round();

    return _MonthlySummary(totalReceived: total, count: count, average: avg);
  }

  Future<void> _editUpi(
    BuildContext context, {
    required String title,
    required String? currentValue,
    required ValueChanged<String> onSaved,
  }) async {
    final controller = TextEditingController(text: currentValue);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            math.max(0.0, MediaQuery.of(sheetContext).viewInsets.bottom) + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'UPI ID',
                  hintText: 'name@bank',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final value = controller.text.trim();
                    if (value.isEmpty || !value.contains('@')) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Enter a valid UPI ID')),
                      );
                      return;
                    }
                    onSaved(value);
                    Navigator.pop(sheetContext);
                    _showSimpleInfo('UPI updated successfully');
                  },
                  child: const Text('Save UPI'),
                ),
              ),
            ],
          ),
        );
      },
    );

    controller.dispose();
  }

  void _verifyPrimary() {
    setState(() {
      _primaryVerified = true;
    });
    _showSimpleInfo('Primary UPI verified');
  }

  void _verifyBackup() {
    setState(() {
      _backupVerified = true;
    });
    _showSimpleInfo('Backup UPI verified');
  }

  Future<void> _pickCustomRange(BuildContext context) async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      initialDateRange: DateTimeRange(
        start: DateTime(now.year, now.month, 1),
        end: now,
      ),
    );

    if (range == null) return;

    final from = DateFormat('d MMM').format(range.start);
    final to = DateFormat('d MMM').format(range.end);
    _showSimpleInfo('Custom statement generated for $from - $to');
  }

  void _showSimpleInfo(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _switchToTab(int index) {
    TabRouter.switchTo(index);
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _showAccountSheet(User user) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.primary,
                  child: Text(
                    user.name.isEmpty ? 'U' : user.name.substring(0, 1).toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ),
                title: Text(user.name),
                subtitle: Text(user.phone),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _switchToTab(4);
                },
              ),
              ListTile(
                leading: const Icon(Icons.home_outlined),
                title: const Text('Home'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _switchToTab(0);
                },
              ),
              ListTile(
                leading: const Icon(Icons.receipt_long_outlined),
                title: const Text('Claims'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _switchToTab(1);
                },
              ),
              ListTile(
                leading: const Icon(Icons.shield_outlined),
                title: const Text('Coverage details'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _switchToTab(2);
                },
              ),
              ListTile(
                leading: const Icon(Icons.payments_outlined),
                title: const Text('Payouts'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _switchToTab(3);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PayoutEntry {
  const _PayoutEntry({
    required this.date,
    required this.triggerType,
    required this.amount,
    required this.upiRef,
  });

  final DateTime date;
  final String triggerType;
  final int amount;
  final String upiRef;
}

class _MonthlySummary {
  const _MonthlySummary({
    required this.totalReceived,
    required this.count,
    required this.average,
  });

  final int totalReceived;
  final int count;
  final int average;
}

class _PayoutsTopBackgroundPainter extends CustomPainter {
  const _PayoutsTopBackgroundPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final base = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFE8F7EE),
          Color(0xFFEFFAF4),
          Color(0xFFF8FCFA),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), base);

    final curve = Paint()..color = AppColors.primary.withValues(alpha: 0.08);
    final path = Path()
      ..moveTo(0, size.height * 0.72)
      ..quadraticBezierTo(
        size.width * 0.35,
        size.height * 0.56,
        size.width * 0.72,
        size.height * 0.74,
      )
      ..quadraticBezierTo(
        size.width * 0.88,
        size.height * 0.82,
        size.width,
        size.height * 0.68,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(path, curve);

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = AppColors.accent.withValues(alpha: 0.22);

    canvas.drawCircle(Offset(size.width * 0.16, size.height * 0.24), 26, ringPaint);
    canvas.drawCircle(Offset(size.width * 0.82, size.height * 0.18), 34, ringPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
