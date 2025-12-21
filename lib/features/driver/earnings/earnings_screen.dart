import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/animated_widgets.dart';

class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Earnings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.secondary,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Today'),
            Tab(text: 'This Week'),
            Tab(text: 'This Month'),
          ],
        ),
      ),
      body: FadeSlideTransition(
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildEarningsTab(_todayEarnings),
            _buildEarningsTab(_weekEarnings),
            _buildEarningsTab(_monthEarnings),
          ],
        ),
      ),
    );
  }

  Widget _buildEarningsTab(Map<String, dynamic> data) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Earnings Summary Card
          _buildEarningsSummaryCard(data),
          const SizedBox(height: 24),

          // Payout Info
          _buildPayoutCard(),
          const SizedBox(height: 24),

          // Trip Breakdown
          Text(
            'Trip Breakdown',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          ...data['trips'].asMap().entries.map<Widget>((entry) {
            return StaggeredListItem(
              index: entry.key,
              child: _buildTripCard(entry.value),
            );
          }),

          const SizedBox(height: 24),

          // Bonuses Section
          if (data['bonuses'] != null) ...[
            Text(
              'Bonuses & Incentives',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            _buildBonusCard(data['bonuses']),
          ],
        ],
      ),
    );
  }

  Widget _buildEarningsSummaryCard(Map<String, dynamic> data) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primaryVariant],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            'Total Earnings',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.black87,
                ),
          ),
          const SizedBox(height: 8),
          AnimatedCounter(
            value: data['total'],
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('${data['trips'].length}', 'Trips'),
              Container(width: 1, height: 40, color: Colors.black26),
              _buildStatItem('${data['hours']}h', 'Online'),
              Container(width: 1, height: 40, color: Colors.black26),
              _buildStatItem('₹${data['avgPerTrip']}', 'Avg/Trip'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.black87,
              ),
        ),
      ],
    );
  }

  Widget _buildPayoutCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.account_balance, color: AppColors.secondary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Next Payout',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  'Dec 22, 2024 • HDFC ****4521',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          Text(
            '₹8,450',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.success,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripCard(Map<String, dynamic> trip) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.directions_car, color: AppColors.secondary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trip['route'],
                  style: Theme.of(context).textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  trip['time'],
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${trip['fare']}',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              Text(
                trip['duration'],
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBonusCard(Map<String, dynamic> bonus) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.success.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.success.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.star, color: AppColors.success, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bonus['title'],
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.success,
                      ),
                ),
                Text(
                  bonus['description'],
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          Text(
            '+₹${bonus['amount']}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.success,
                ),
          ),
        ],
      ),
    );
  }
}

// Mock Data
final Map<String, dynamic> _todayEarnings = {
  'total': 2450,
  'hours': 6,
  'avgPerTrip': 408,
  'trips': [
    {
      'route': 'Indiranagar → Koramangala',
      'time': '10:30 AM',
      'fare': 550,
      'duration': '45 min'
    },
    {
      'route': 'HSR → Electronic City',
      'time': '12:15 PM',
      'fare': 720,
      'duration': '1h 10m'
    },
    {
      'route': 'Whitefield → MG Road',
      'time': '3:00 PM',
      'fare': 480,
      'duration': '55 min'
    },
    {
      'route': 'JP Nagar → BTM Layout',
      'time': '5:30 PM',
      'fare': 350,
      'duration': '35 min'
    },
    {
      'route': 'Marathahalli → Ulsoor',
      'time': '7:00 PM',
      'fare': 350,
      'duration': '40 min'
    },
  ],
  'bonuses': {
    'title': 'Peak Hour Bonus',
    'description': 'Completed 5 trips during rush hour',
    'amount': 150,
  },
};

final Map<String, dynamic> _weekEarnings = {
  'total': 12850,
  'hours': 38,
  'avgPerTrip': 428,
  'trips': [
    {
      'route': 'Multiple trips on Mon',
      'time': 'Monday',
      'fare': 2100,
      'duration': '6 trips'
    },
    {
      'route': 'Multiple trips on Tue',
      'time': 'Tuesday',
      'fare': 1850,
      'duration': '5 trips'
    },
    {
      'route': 'Multiple trips on Wed',
      'time': 'Wednesday',
      'fare': 2200,
      'duration': '6 trips'
    },
    {
      'route': 'Multiple trips on Thu',
      'time': 'Thursday',
      'fare': 1900,
      'duration': '5 trips'
    },
    {
      'route': 'Multiple trips on Fri',
      'time': 'Friday',
      'fare': 2450,
      'duration': '7 trips'
    },
    {
      'route': 'Multiple trips on Sat',
      'time': 'Saturday',
      'fare': 2350,
      'duration': '6 trips'
    },
  ],
  'bonuses': {
    'title': 'Weekly Target Achieved!',
    'description': 'Completed 30+ trips this week',
    'amount': 500,
  },
};

final Map<String, dynamic> _monthEarnings = {
  'total': 48500,
  'hours': 142,
  'avgPerTrip': 415,
  'trips': [
    {
      'route': 'Week 1',
      'time': 'Dec 1-7',
      'fare': 11200,
      'duration': '28 trips'
    },
    {
      'route': 'Week 2',
      'time': 'Dec 8-14',
      'fare': 12850,
      'duration': '32 trips'
    },
    {
      'route': 'Week 3',
      'time': 'Dec 15-20',
      'fare': 14450,
      'duration': '35 trips'
    },
    {
      'route': 'Week 4 (Ongoing)',
      'time': 'Dec 21-22',
      'fare': 10000,
      'duration': '22 trips'
    },
  ],
  'bonuses': {
    'title': 'Monthly Champion!',
    'description': '100+ trips with 4.8+ rating',
    'amount': 2000,
  },
};
