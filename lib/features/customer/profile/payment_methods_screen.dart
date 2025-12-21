import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/animated_widgets.dart';

class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  String _selectedMethod = 'upi';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Methods'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: FadeSlideTransition(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Wallet Balance Card
              _buildWalletCard(context),
              const SizedBox(height: 24),

              // Payment Methods
              Text(
                'Payment Methods',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),

              _buildPaymentOption(
                context,
                id: 'upi',
                icon: Icons.account_balance,
                title: 'UPI',
                subtitle: 'Pay using any UPI app',
              ),
              _buildPaymentOption(
                context,
                id: 'card',
                icon: Icons.credit_card,
                title: 'Credit / Debit Card',
                subtitle: 'Add a new card',
              ),
              _buildPaymentOption(
                context,
                id: 'cash',
                icon: Icons.money,
                title: 'Cash',
                subtitle: 'Pay driver directly',
              ),

              const SizedBox(height: 24),

              // Saved Cards
              Text(
                'Saved Cards',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              _buildSavedCard(
                context,
                cardType: 'visa',
                lastFour: '4242',
                expiry: '12/26',
              ),
              _buildSavedCard(
                context,
                cardType: 'mastercard',
                lastFour: '8888',
                expiry: '03/25',
              ),

              const SizedBox(height: 16),

              // Add Card Button
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add),
                label: const Text('Add New Card'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.secondary,
                  side: BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWalletCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primaryVariant],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Drivo Wallet',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Colors.black87,
                    ),
              ),
              Icon(Icons.account_balance_wallet, color: Colors.black87),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '₹2,450',
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
            ),
            child: const Text('Add Money'),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentOption(
    BuildContext context, {
    required String id,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final isSelected = _selectedMethod == id;

    return GestureDetector(
      onTap: () => setState(() => _selectedMethod = id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.secondary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: AppColors.primary)
            else
              Icon(Icons.circle_outlined, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }

  Widget _buildSavedCard(
    BuildContext context, {
    required String cardType,
    required String lastFour,
    required String expiry,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              cardType == 'visa' ? Icons.credit_card : Icons.credit_card,
              color: cardType == 'visa' ? Colors.blue : Colors.orange,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '•••• •••• •••• $lastFour',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  'Expires $expiry',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: AppColors.textHint),
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}
