import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';
import '../../models/user_model.dart';
import '../../models/claim_model.dart';
import '../../models/plan_model.dart';
import '../../routes/app_routes.dart';
import '../../services/api_service.dart';
import '../../services/tab_router.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static final ApiService _apiService = ApiService();

  Future<_HomeViewData> _loadHomeViewData() async {
    final user = await _apiService.getProfile('me');
    final policy = await _apiService.getPolicy('me');
    final claims = await _apiService.getClaims('me');

    final maxDaysPerWeek = (policy['maxDaysPerWeek'] as num? ?? 0).toInt();
    final nextBillingRaw = (policy['nextBillingDate'] as String? ?? '').trim();
    final nextBillingDate = DateTime.tryParse(nextBillingRaw);
    final serverNow = nextBillingDate != null
      ? nextBillingDate.toUtc().subtract(const Duration(days: 7))
      : DateTime.now().toUtc();
    final weekStart = serverNow.subtract(Duration(days: serverNow.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 7));

    final claimsThisWeek = claims.where((claim) {
      final claimDate = claim.date.toUtc();
      return !claimDate.isBefore(weekStart) && claimDate.isBefore(weekEnd);
    }).toList();

    final claimsProcessedThisWeek = claimsThisWeek.length;
    final payoutThisWeek = claimsThisWeek
      .where((claim) => claim.status == ClaimStatus.settled)
      .fold<double>(0, (sum, claim) => sum + claim.amount);
    final daysUntilBilling = nextBillingDate != null
      ? nextBillingDate.toUtc().difference(serverNow).inDays.clamp(0, 7)
      : 7;
    final coveredDaysLeft = (maxDaysPerWeek - claimsProcessedThisWeek)
      .clamp(0, maxDaysPerWeek)
      .clamp(0, daysUntilBilling);

    final activePlan = InsurancePlan(
      name: (policy['plan'] as String? ?? user.plan).trim(),
      weeklyPremium: (policy['weeklyPremium'] as num? ?? 0).toInt(),
      perTriggerPayout: (policy['perTriggerPayout'] as num? ?? 0).toInt(),
      maxDaysPerWeek: (policy['maxDaysPerWeek'] as num? ?? 0).toInt(),
      isPopular: false,
    );

    return _HomeViewData(
      user: user,
      claims: claims,
      activePlan: activePlan,
      earningsProtected: (policy['earningsProtected'] as num? ?? 0).toDouble(),
      totalEarnings: (user.totalEarnings > 0 ? user.totalEarnings : null),
      coveredDaysLeft: coveredDaysLeft,
      claimsProcessedThisWeek: claimsProcessedThisWeek,
      payoutThisWeek: payoutThisWeek,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_HomeViewData>(
      future: _loadHomeViewData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.scaffoldBackground,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError || snapshot.data == null) {
          return const Scaffold(
            backgroundColor: AppColors.scaffoldBackground,
            body: Center(
              child: Text(
                'Failed to load home data. Please retry.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          );
        }

        return _buildWithData(context, snapshot.data!);
      },
    );
  }

  Widget _buildWithData(BuildContext context, _HomeViewData data) {
    final user = data.user;
    final claims = data.claims;
    final activePlan = data.activePlan;
    final currencyFormat = NumberFormat('#,##0.00');
    final todayLabel = DateFormat('EEE, d MMM').format(DateTime.now());
    final dateFormat = DateFormat('d MMM');

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final fixedTopHeight = constraints.maxHeight * 0.36;
          final scrollStart = fixedTopHeight + 10;

          return Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _HomeTopBackgroundPainter(
                    topHeight: fixedTopHeight + 40,
                  ),
                ),
              ),
              _buildScrollableLowerLayer(
                context,
                scrollStart,
                user,
                claims,
                currencyFormat,
                dateFormat,
                activePlan,
                data.earningsProtected,
                data.totalEarnings,
                data.coveredDaysLeft,
                data.claimsProcessedThisWeek,
                data.payoutThisWeek,
              ),
              _buildFixedTopLayer(
                context,
                user,
                todayLabel,
                currencyFormat,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFixedTopLayer(
    BuildContext context,
    User user,
    String todayLabel,
    NumberFormat currencyFormat,
  ) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTopHeader(context, user, todayLabel),
            const SizedBox(height: 20),
            _buildPolicyOverview(user),
          ],
        ),
      ),
    );
  }

  Widget _buildScrollableLowerLayer(
    BuildContext context,
    double scrollStart,
    User user,
    List<Claim> claims,
    NumberFormat currencyFormat,
    DateFormat dateFormat,
    InsurancePlan activePlan,
    double earningsProtected,
    double? totalEarnings,
    int coveredDaysLeft,
    int claimsProcessedThisWeek,
    double payoutThisWeek,
  ) {
    return Positioned.fill(
      top: scrollStart,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.scaffoldBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMetricsRow(
                user,
                currencyFormat,
                earningsProtected: earningsProtected,
                totalEarnings: totalEarnings,
              ),
              const SizedBox(height: 18),
              _buildSectionHeader('Quick Actions'),
              const SizedBox(height: 10),
              _buildQuickActions(context),
              const SizedBox(height: 18),
              _buildSectionHeader('This Week'),
              const SizedBox(height: 10),
              _buildWeeklySnapshot(
                currencyFormat,
                coveredDaysLeft: coveredDaysLeft,
                claimsProcessedThisWeek: claimsProcessedThisWeek,
                payoutThisWeek: payoutThisWeek,
              ),
              const SizedBox(height: 18),
              _buildSectionHeader(
                'Recent Claims',
                actionText: 'View all',
                onTap: () {
                  _openClaims(context);
                },
              ),
              const SizedBox(height: 10),
              _buildRecentClaims(claims, currencyFormat, dateFormat),
              const SizedBox(height: 18),
              _buildSectionHeader('Next Billing'),
              const SizedBox(height: 10),
              _buildNextBillingCard(context, activePlan),
              const SizedBox(height: 16),
              _buildPrimaryActions(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopHeader(BuildContext context, User user, String todayLabel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Tooltip(
              message: 'Account options',
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => _showAccountOptions(context, user),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      user.name.substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Row(
              children: [
                _headerIconButton(
                  icon: Icons.notifications_none,
                  tooltip: 'Notifications',
                  onTap: () {
                    _showNotificationsSheet(context);
                  },
                ),
                const SizedBox(width: 10),
                _headerIconButton(
                  icon: Icons.menu,
                  tooltip: 'Menu',
                  onTap: () {
                    _showQuickMenuSheet(context);
                  },
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Hi ${user.name.split(' ').first}, stay covered today.',
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$todayLabel · ${user.zone} zone',
          style: TextStyle(
            fontSize: 13,
            color: Colors.white.withValues(alpha: 0.82),
          ),
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

  Widget _buildPolicyOverview(User user) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            AppColors.primaryDark,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified, size: 14, color: Colors.white),
                    SizedBox(width: 6),
                    Text(
                      'ACTIVE POLICY',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '${user.plan} Plan',
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${user.platform} · ${user.zone}',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.78),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsRow(
    User user,
    NumberFormat currencyFormat, {
    required double earningsProtected,
    required double? totalEarnings,
  }) {
    return Row(
      children: [
        Expanded(
          child: _metricCard(
            title: 'Earnings Protected',
            value: '₹${currencyFormat.format(earningsProtected)}',
            subtitle: 'Parametric coverage active',
            icon: Icons.shield,
            iconBackground: AppColors.accentLight,
            iconColor: AppColors.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _metricCard(
            title: 'Total Earnings',
            value: totalEarnings == null ? 'Not Synced' : '₹${currencyFormat.format(totalEarnings)}',
            subtitle: totalEarnings == null
                ? 'Pending sync from ${user.platform}'
                : 'Synced from ${user.platform}',
            icon: Icons.account_balance_wallet_outlined,
            iconBackground: AppColors.infoLight,
            iconColor: AppColors.info,
          ),
        ),
      ],
    );
  }

  Widget _metricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconBackground,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: iconBackground,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(height: 10),
          Text(
            title.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.textTertiary,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryActions(BuildContext context) {
    return Column(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            _showQuickClaimSheet(context);
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Raise Dispute',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Report missed trigger or payout issue',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
                Icon(Icons.arrow_forward_rounded, color: Colors.white),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  _openCoverage(context);
                },
                icon: const Icon(Icons.description_outlined, size: 18),
                label: const Text('Coverage'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  _openClaims(context);
                },
                icon: const Icon(Icons.history, size: 18),
                label: const Text('History'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _quickActionChip(
          icon: Icons.add_alert_outlined,
          label: 'Raise Dispute',
          onPressed: () => _showQuickClaimSheet(context),
        ),
        _quickActionChip(
          icon: Icons.description_outlined,
          label: 'Policy',
          onPressed: () => _openCoverage(context),
        ),
        _quickActionChip(
          icon: Icons.receipt_long_outlined,
          label: 'Claims',
          onPressed: () => _openClaims(context),
        ),
        _quickActionChip(
          icon: Icons.support_agent,
          label: 'Support',
          onPressed: () => _showSupportSheet(context),
        ),
        _quickActionChip(
          icon: Icons.payments_outlined,
          label: 'Payouts',
          onPressed: () => _openPayouts(context),
        ),
      ],
    );
  }

  Widget _quickActionChip({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return ActionChip(
      avatar: Icon(icon, size: 18, color: AppColors.primary),
      label: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
        ),
      ),
      onPressed: onPressed,
      backgroundColor: AppColors.cardBackground,
      side: const BorderSide(color: AppColors.border),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    );
  }

  Widget _buildWeeklySnapshot(
    NumberFormat currencyFormat, {
    required int coveredDaysLeft,
    required int claimsProcessedThisWeek,
    required double payoutThisWeek,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _miniStatCard(
                title: 'Covered Days Left',
                value: '$coveredDaysLeft',
                icon: Icons.calendar_today_outlined,
                iconColor: AppColors.info,
                iconBackground: AppColors.infoLight,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _miniStatCard(
                title: 'Claims Processed',
                value: '$claimsProcessedThisWeek',
                icon: Icons.verified_outlined,
                iconColor: AppColors.success,
                iconBackground: AppColors.successLight,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _miniStatCard(
          title: 'Payout This Week',
          value: '₹${currencyFormat.format(payoutThisWeek)}',
          icon: Icons.payments_outlined,
          iconColor: AppColors.primary,
          iconBackground: AppColors.accentLight,
        ),
      ],
    );
  }

  Widget _miniStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    required Color iconBackground,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: iconBackground,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentClaims(
    List<Claim> claims,
    NumberFormat currencyFormat,
    DateFormat dateFormat,
  ) {
    final recentClaims = claims.take(1).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...recentClaims.map(
            (claim) => Padding(
              padding: EdgeInsets.zero,
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: claim.typeColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(claim.typeIcon, size: 18, color: claim.typeColor),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${claim.typeShortName} · ${claim.id}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          dateFormat.format(claim.date),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹${currencyFormat.format(claim.amount)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: claim.statusColor.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          claim.statusLabel,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: claim.statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextBillingCard(BuildContext context, InsurancePlan activePlan) {
    final nextDebitDate = DateFormat('EEE, d MMM')
        .format(DateTime.now().add(const Duration(days: 3)));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '₹${activePlan.weeklyPremium} auto-debit on $nextDebitDate',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openCoverage(context),
                  icon: const Icon(Icons.tune, size: 18),
                  label: const Text('Manage Plan'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showSupportSheet(context),
                  icon: const Icon(Icons.chat_bubble_outline, size: 18),
                  label: const Text('Support'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 12),
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

  void _openClaims(BuildContext context) {
    _switchToTab(context, 1);
  }

  void _openCoverage(BuildContext context) {
    _switchToTab(context, 2);
  }

  void _openProfile(BuildContext context) {
    _switchToTab(context, 4);
  }

  void _openPayouts(BuildContext context) {
    _switchToTab(context, 3);
  }

  void _switchToTab(BuildContext context, int index) {
    TabRouter.switchTo(index);
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _showNotificationsSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          children: const [
            ListTile(
              leading: Icon(Icons.cloud_done_outlined),
              title: Text('Today\'s risk data synced'),
              subtitle: Text('Coverage triggers updated 5 min ago'),
            ),
            ListTile(
              leading: Icon(Icons.account_balance_wallet_outlined),
              title: Text('Weekly debit reminder'),
              subtitle: Text('Premium auto-debit due in 3 days'),
            ),
            ListTile(
              leading: Icon(Icons.support_agent_outlined),
              title: Text('Support response available'),
              subtitle: Text('A specialist replied to your last query'),
            ),
          ],
        );
      },
    );
  }

  void _showQuickMenuSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('Profile'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _openProfile(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.receipt_long_outlined),
                title: const Text('Claims'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _openClaims(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.shield_outlined),
                title: const Text('Coverage'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _openCoverage(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.payments_outlined),
                title: const Text('Payouts'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _openPayouts(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSupportSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Support',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                const Text('Choose how you want help with your policy or claims.'),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.call_outlined),
                  title: const Text('Call support'),
                  subtitle: const Text('+91 1800 202 7278'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Dialer integration coming next.')),
                    );
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.chat_outlined),
                  title: const Text('Chat with specialist'),
                  subtitle: const Text('Average response time: under 2 minutes'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Chat opened in support inbox.')),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showQuickClaimSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Raise Dispute',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Tell us what went wrong and we will route it to a claims specialist.',
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _openClaims(context);
                    },
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: const Text('Go to Claims'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(
    String title, {
    String? actionText,
    VoidCallback? onTap,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        if (actionText != null)
          TextButton(
            onPressed: onTap ?? () {},
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              minimumSize: const Size(0, 36),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              actionText,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
      ],
    );
  }

  void _showAccountOptions(BuildContext context, User user) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          height: MediaQuery.of(sheetContext).size.height * 0.82,
          decoration: const BoxDecoration(
            color: AppColors.scaffoldBackground,
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Account',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              user.name.substring(0, 1).toUpperCase(),
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                user.phone,
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'Manage',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        _accountOption(
                          icon: Icons.person_outline,
                          title: 'Profile details',
                          onTap: () {
                            Navigator.pop(sheetContext);
                            _openProfile(context);
                          },
                        ),
                        _accountOption(
                          icon: Icons.description_outlined,
                          title: 'Policy details',
                          onTap: () {
                            Navigator.pop(sheetContext);
                            _openCoverage(context);
                          },
                        ),
                        _accountOption(
                          icon: Icons.receipt_long_outlined,
                          title: 'Claims and disputes',
                          onTap: () {
                            Navigator.pop(sheetContext);
                            _openClaims(context);
                          },
                        ),
                        _accountOption(
                          icon: Icons.payments_outlined,
                          title: 'Plan and pricing',
                          onTap: () {
                            Navigator.pop(sheetContext);
                            _openCoverage(context);
                          },
                        ),
                        _accountOption(
                          icon: Icons.payments_outlined,
                          title: 'Payouts ledger',
                          onTap: () {
                            Navigator.pop(sheetContext);
                            _openPayouts(context);
                          },
                        ),
                        _accountOption(
                          icon: Icons.help_outline,
                          title: 'Help and support',
                          onTap: () {
                            Navigator.pop(sheetContext);
                            _showSupportSheet(context);
                          },
                        ),
                        _accountOption(
                          icon: Icons.language,
                          title: 'Language',
                          onTap: () {
                            Navigator.pop(sheetContext);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Language settings will be added next.'),
                              ),
                            );
                          },
                        ),
                        _accountOption(
                          icon: Icons.logout,
                          title: 'Log out',
                          isDestructive: true,
                          onTap: () {
                            Navigator.pop(sheetContext);
                            Navigator.pushNamedAndRemoveUntil(
                              context,
                              AppRoutes.welcome,
                              (route) => false,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _accountOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final textColor = isDestructive ? AppColors.error : AppColors.textPrimary;

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(vertical: 2),
      leading: Icon(icon, color: textColor, size: 25),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: isDestructive ? AppColors.error : AppColors.textSecondary,
      ),
    );
  }
}

class _HomeTopBackgroundPainter extends CustomPainter {
  const _HomeTopBackgroundPainter({required this.topHeight});

  final double topHeight;

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPath = Path()
      ..moveTo(0, 0)
      ..lineTo(0, topHeight - 8)
      ..cubicTo(
        size.width * 0.12,
        topHeight + 18,
        size.width * 0.28,
        topHeight - 22,
        size.width * 0.44,
        topHeight + 8,
      )
      ..cubicTo(
        size.width * 0.60,
        topHeight + 24,
        size.width * 0.78,
        topHeight - 18,
        size.width,
        topHeight + 4,
      )
      ..lineTo(size.width, 0)
      ..close();

    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.primaryLight,
          AppColors.primary,
          AppColors.primaryDark,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, topHeight + 40));

    canvas.drawPath(backgroundPath, paint);
  }

  @override
  bool shouldRepaint(covariant _HomeTopBackgroundPainter oldDelegate) {
    return oldDelegate.topHeight != topHeight;
  }
}

class _HomeViewData {
  const _HomeViewData({
    required this.user,
    required this.claims,
    required this.activePlan,
    required this.earningsProtected,
    required this.totalEarnings,
    required this.coveredDaysLeft,
    required this.claimsProcessedThisWeek,
    required this.payoutThisWeek,
  });

  final User user;
  final List<Claim> claims;
  final InsurancePlan activePlan;
  final double earningsProtected;
  final double? totalEarnings;
  final int coveredDaysLeft;
  final int claimsProcessedThisWeek;
  final double payoutThisWeek;
}
