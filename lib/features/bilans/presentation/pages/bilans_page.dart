import 'package:flutter/material.dart';

import '../widgets/net_worth_tab.dart';
import '../widgets/revenue_expense_tab.dart';

class BilansPage extends StatelessWidget {
  const BilansPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Bilans'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Revenus / Dépenses'),
              Tab(text: 'Patrimoine net'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            RevenueExpenseTab(),
            NetWorthTab(),
          ],
        ),
      ),
    );
  }
}
