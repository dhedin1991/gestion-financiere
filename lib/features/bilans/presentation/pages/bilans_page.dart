import 'package:flutter/material.dart';

import '../../../../core/navigation/app_back_button.dart';
import '../../../../core/navigation/app_menu_button.dart';
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
          leading: const AppBackButton(),
          title: const Text('Bilans'),
          actions: const [AppMenuButton()],
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
